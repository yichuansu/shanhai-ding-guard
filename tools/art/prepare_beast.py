#!/usr/bin/env python3
"""把一张 AI 生成（或手绘）的异兽图处理成游戏可用的 body.png。

    pip install pillow
    python3 tools/art/prepare_beast.py art_src/beasts/dangkang/raw.png dangkang --element tu
    python3 tools/art/prepare_beast.py --all          # 处理 art_src/beasts/*/raw.png（五行从内容数据读）

步骤：
  1. 去背景：图片自带透明就保留；否则从四角取背景色，相近颜色连片抠掉（--tolerance 调灵敏度）
  2. 裁掉空白，等比缩放进 512×512 画布，脚底贴画布底部（游戏里以底边中点为落脚点）
  3. 压色板：每个像素换成该异兽可用色板里最近的颜色（墨色 + 自己五行三档 + 可选 --accent 点缀五行）
  4. 加墨线外轮廓（--outline 像素，0 关闭），保证缩小后轮廓仍清楚
  5. 输出 art/beasts/<id>/body.png，以及 art_src/beasts/<id>/preview.png（原图 / 处理后 / 战斗尺寸对照）
"""
import argparse
import pathlib
import re
import sys
from collections import deque

from PIL import Image, ImageFilter

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import palette  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[2]
CANVAS = 512
MARGIN = 0.06
# 战斗中的显示高度（像素，1080p），预览图按这个缩小给你看实际效果
BATTLE_HEIGHT = 120


def remove_background(img, tolerance):
    img = img.convert("RGBA")
    alpha = img.getchannel("A")
    if alpha.getextrema()[0] < 250:
        return img
    w, h = img.size
    px = img.load()
    corners = [px[0, 0], px[w - 1, 0], px[0, h - 1], px[w - 1, h - 1]]
    bg = tuple(sum(c[i] for c in corners) // 4 for i in range(3))
    tol2 = tolerance * tolerance
    seen = bytearray(w * h)
    queue = deque([(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)])
    while queue:
        x, y = queue.popleft()
        if x < 0 or y < 0 or x >= w or y >= h or seen[y * w + x]:
            continue
        seen[y * w + x] = 1
        r, g, b, a = px[x, y]
        if (r - bg[0]) ** 2 + (g - bg[1]) ** 2 + (b - bg[2]) ** 2 > tol2:
            continue
        px[x, y] = (r, g, b, 0)
        queue.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    return img


def fit_to_canvas(img):
    bbox = img.getchannel("A").point(lambda a: 255 if a > 24 else 0).getbbox()
    if bbox is None:
        raise SystemExit("图里没有找到异兽（背景抠完什么都不剩）。试试调小 --tolerance。")
    img = img.crop(bbox)
    inner = int(CANVAS * (1 - 2 * MARGIN))
    scale = min(inner / img.width, inner / img.height)
    img = img.resize((max(1, round(img.width * scale)), max(1, round(img.height * scale))), Image.LANCZOS)
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    canvas.paste(img, ((CANVAS - img.width) // 2, CANVAS - img.height - int(CANVAS * 0.02)), img)
    return canvas


def quantize(img, colors):
    rgb = [c for _, c in colors]
    cache = {}
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a < 24:
                px[x, y] = (0, 0, 0, 0)
                continue
            key = (r >> 2, g >> 2, b >> 2)
            best = cache.get(key)
            if best is None:
                # 加权距离，人眼对绿色更敏感
                best = min(rgb, key=lambda c: 2 * (c[0] - r) ** 2 + 4 * (c[1] - g) ** 2 + 3 * (c[2] - b) ** 2)
                cache[key] = best
            px[x, y] = (*best, 255 if a > 160 else a)
    return img


def add_outline(img, width):
    if width <= 0:
        return img
    alpha = img.getchannel("A").point(lambda a: 255 if a > 80 else 0)
    grown = alpha.filter(ImageFilter.MaxFilter(width * 2 + 1))
    ink = Image.new("RGBA", img.size, (*palette.hex_to_rgb(palette.INK["ink"]), 0))
    ink.putalpha(grown)
    ink.alpha_composite(img)
    return ink


def preview(raw, body, out_path):
    paper = palette.hex_to_rgb(palette.PAPER["paper"])
    small_h = BATTLE_HEIGHT
    small = body.resize((small_h * body.width // body.height, small_h), Image.LANCZOS)
    raw_fit = raw.convert("RGBA")
    raw_fit.thumbnail((CANVAS, CANVAS))
    sheet = Image.new("RGBA", (CANVAS * 2 + 260, CANVAS), (*paper, 255))
    sheet.alpha_composite(raw_fit, (0, (CANVAS - raw_fit.height) // 2))
    sheet.alpha_composite(body, (CANVAS, 0))
    sheet.alpha_composite(small, (CANVAS * 2 + 130 - small.width // 2, CANVAS // 2 - small_h // 2))
    sheet.convert("RGB").save(out_path)


def element_of(beast_id):
    tres = ROOT / "content" / "beasts" / f"{beast_id}.tres"
    if tres.exists():
        m = re.search(r'^element = &"(\w+)"', tres.read_text(encoding="utf-8"), re.M)
        # Godot 不写默认值：BeastDef 的五行默认是土
        return m.group(1) if m else "tu"
    return None


def process(raw_path, beast_id, element, accent, tolerance, outline):
    if element not in palette.ELEMENTS:
        raise SystemExit(f"五行 {element!r} 无效，可选：{', '.join(palette.ELEMENTS)}")
    raw = Image.open(raw_path)
    img = remove_background(raw, tolerance)
    img = fit_to_canvas(img)
    img = quantize(img, palette.beast_palette(element, accent))
    img = add_outline(img, outline)
    out_dir = ROOT / "art" / "beasts" / beast_id
    out_dir.mkdir(parents=True, exist_ok=True)
    img.save(out_dir / "body.png")
    src_dir = ROOT / "art_src" / "beasts" / beast_id
    src_dir.mkdir(parents=True, exist_ok=True)
    preview(raw, img, src_dir / "preview.png")
    used = len({img.getpixel((x, y)) for y in range(img.height) for x in range(img.width) if img.getpixel((x, y))[3] > 0})
    print(f"{beast_id}：{palette.ELEMENT_NAMES[element]}，{used} 色 → {out_dir / 'body.png'}（对照图 {src_dir / 'preview.png'}）")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("raw", nargs="?")
    ap.add_argument("beast_id", nargs="?")
    ap.add_argument("--element", help="五行：mu/huo/tu/jin/shui，缺省从内容数据读")
    ap.add_argument("--accent", help="点缀用的第二个五行")
    ap.add_argument("--tolerance", type=int, default=48, help="抠背景的颜色容差（默认 48）")
    ap.add_argument("--outline", type=int, default=4, help="墨线外轮廓宽度，0 关闭（默认 4）")
    ap.add_argument("--all", action="store_true", help="处理 art_src/beasts/*/raw.png")
    args = ap.parse_args()
    if args.all:
        raws = sorted((ROOT / "art_src" / "beasts").glob("*/raw.png"))
        if not raws:
            raise SystemExit("art_src/beasts/ 下没有 raw.png")
        for raw in raws:
            bid = raw.parent.name
            process(raw, bid, args.element or element_of(bid), args.accent, args.tolerance, args.outline)
        return
    if not args.raw or not args.beast_id:
        ap.error("需要 raw 图片路径和 beast_id，或者用 --all")
    process(args.raw, args.beast_id, args.element or element_of(args.beast_id), args.accent, args.tolerance, args.outline)


if __name__ == "__main__":
    main()
