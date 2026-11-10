#!/usr/bin/env python3
"""离线合成冀州 01 战斗预览。不是 Unity Game 视图。

按 ARCHITECTURE.md 里的最终 PPU，把出血图、正图、三座建造格、当康、剑阵、铜鼎和 HUD 图标
摆进 19.5×12 world，再裁成 16:9、19.5:9，以及正交 size 6 的 4:3。

    python3 tools/compose_jizhou01_preview.py [输出目录]
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

OUT_W = 2340
OUT_H = 1440
PPW = 120.0
TOWER_PPU = 160.0
DANGKANG_PPU = 160.0
DING_PPU = 170.0
SLOT_PPU = 200.0
TOWER_PIVOT = (0.5, 0.021)
DANGKANG_PIVOT = (0.5, 0.031)
DING_PIVOT = (0.5, 0.016)
SLOT_PIVOT = (0.5, 0.5)
FX_PIVOT = (0.5, 0.5)
FOOT_DROP = 0.03
FONT = "/usr/share/fonts/truetype/wqy/wqy-microhei.ttc"
LABEL = "离线合成预览，非 Unity Game 视图"


def repo_root() -> Path:
    here = Path(__file__).resolve()
    for parent in here.parents:
        if (parent / "Assets" / "Game").is_dir():
            return parent
    raise SystemExit("找不到仓库根目录")


def to_world(x: float, y: float) -> tuple[float, float]:
    return ((x - 0.889) * 9.0, (y - 0.5) * 9.0)


def path_segments(level: dict) -> tuple[list, float]:
    points = [to_world(p["x"], p["y"]) for p in level["waypoints"]]
    segments = []
    total = 0.0
    for i in range(len(points) - 1):
        ax, ay = points[i]
        bx, by = points[i + 1]
        length = ((bx - ax) ** 2 + (by - ay) ** 2) ** 0.5
        segments.append((total, total + length, (ax, ay), (bx, by)))
        total += length
    return segments, total


def sample_path(segments: list, distance: float) -> tuple[tuple[float, float], tuple[float, float]]:
    distance = max(0.0, min(distance, segments[-1][1]))
    for start, end, a, b in segments:
        if distance <= end or end == segments[-1][1]:
            span = end - start
            t = 0.0 if span <= 1e-9 else (distance - start) / span
            pos = (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
            return pos, (b[0] - a[0], b[1] - a[1])
    last = segments[-1]
    return last[3], (0.0, 0.0)


def world_px(x: float, y: float) -> tuple[float, float]:
    return (OUT_W * 0.5 + x * PPW, OUT_H * 0.5 - y * PPW)


def scaled(image: Image.Image, ppu: float, flip: bool) -> Image.Image:
    im = image.convert("RGBA")
    if flip:
        im = im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    scale = PPW / ppu
    size = (max(1, int(round(im.width * scale))), max(1, int(round(im.height * scale))))
    return im.resize(size, Image.Resampling.BILINEAR)


def dest_of(sprite: Image.Image, pivot: tuple[float, float], world: tuple[float, float], flip: bool) -> tuple[int, int]:
    px, py = world_px(world[0], world[1])
    piv_x = (1.0 - pivot[0] if flip else pivot[0]) * sprite.width
    piv_y = sprite.height - pivot[1] * sprite.height
    return int(round(px - piv_x)), int(round(py - piv_y))


def blit(base: Image.Image, sprite: Image.Image, pivot: tuple[float, float], world: tuple[float, float], ppu: float, flip: bool = False) -> Image.Image:
    scaled_sprite = scaled(sprite, ppu, flip)
    paste(base, scaled_sprite, dest_of(scaled_sprite, pivot, world, flip))
    return scaled_sprite


def paste(base: Image.Image, sprite: Image.Image, xy: tuple[int, int]) -> None:
    x, y = xy
    src_x = 0
    src_y = 0
    if x < 0:
        src_x = -x
        x = 0
    if y < 0:
        src_y = -y
        y = 0
    if src_x >= sprite.width or src_y >= sprite.height or x >= base.width or y >= base.height:
        return
    cropped = sprite.crop((src_x, src_y, sprite.width, sprite.height))
    cropped = cropped.crop((0, 0, min(cropped.width, base.width - x), min(cropped.height, base.height - y)))
    base.alpha_composite(cropped, (x, y))


def blit_additive(base: Image.Image, sprite: Image.Image, pivot: tuple[float, float], world: tuple[float, float], ppu: float) -> None:
    scaled_sprite = scaled(sprite, ppu, False)
    x, y = dest_of(scaled_sprite, pivot, world, False)
    src_x = 0
    src_y = 0
    if x < 0:
        src_x = -x
        x = 0
    if y < 0:
        src_y = -y
        y = 0
    if src_x >= scaled_sprite.width or src_y >= scaled_sprite.height or x >= base.width or y >= base.height:
        return
    cropped = scaled_sprite.crop((src_x, src_y, scaled_sprite.width, scaled_sprite.height))
    cropped = cropped.crop((0, 0, min(cropped.width, base.width - x), min(cropped.height, base.height - y)))
    region = np.asarray(base.crop((x, y, x + cropped.width, y + cropped.height))).astype(np.float32)
    src = np.asarray(cropped).astype(np.float32)
    alpha = src[:, :, 3:4] / 255.0
    rgb = np.clip(region[:, :, :3] + src[:, :, :3] * alpha, 0, 255)
    merged = np.concatenate([rgb, region[:, :, 3:4]], axis=2).astype(np.uint8)
    base.paste(Image.fromarray(merged, "RGBA"), (x, y))


def frame(strip: Image.Image, index: int, count: int) -> Image.Image:
    width = strip.width // count
    return strip.crop((index * width, 0, (index + 1) * width, strip.height))


def decorate(image: Image.Image, art: Path) -> Image.Image:
    canvas = image.convert("RGBA")
    font = ImageFont.truetype(FONT, 28)
    small = ImageFont.truetype(FONT, 22)
    overlay = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    icons = [
        (art / "hud_lingshi.png", "灵石 20"),
        (art / "hud_wave.png", "波次 2/8"),
    ]
    x = 28
    y = 18
    size = 42
    for path, text in icons:
        icon = Image.open(path).convert("RGBA").resize((size, size), Image.Resampling.BILINEAR)
        overlay.alpha_composite(icon, (x, y))
        draw.text((x + size + 8, y + 8), text, font=small, fill=(255, 255, 255, 255))
        x += size + 8 + int(small.getlength(text)) + 22
    heart = Image.open(art / "hud_heart.png").convert("RGBA").resize((size, size), Image.Resampling.BILINEAR)
    for i in range(3):
        icon = heart
        if i == 2:
            arr = np.asarray(heart).astype(np.float32)
            arr[:, :, :3] *= 0.55
            arr[:, :, 3] *= 0.4
            icon = Image.fromarray(arr.astype(np.uint8), "RGBA")
        overlay.alpha_composite(icon, (x, y))
        x += size + 4
    draw.text((x + 8, y + 8), "1/3", font=small, fill=(255, 255, 255, 255))

    bbox = font.getbbox(LABEL)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]
    pad = 12
    plate = (canvas.width - text_w - pad * 2 - 16, 16, canvas.width - 16, 16 + text_h + pad * 2)
    draw.rectangle(plate, fill=(16, 22, 16, 180))
    draw.text((plate[0] + pad, plate[1] + pad - bbox[1]), LABEL, font=font, fill=(255, 255, 255, 255))
    return Image.alpha_composite(canvas, overlay).convert("RGB")


def main() -> None:
    root = repo_root()
    out_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("/opt/cursor/artifacts")
    out_dir.mkdir(parents=True, exist_ok=True)
    art_dir = root / "Assets" / "Game" / "Art" / "Backgrounds"
    unit_dir = root / "Assets" / "Game" / "Resources" / "BattleArt"
    main_img = Image.open(art_dir / "bg_jizhou01_battle.png").convert("RGB")
    bleed = Image.open(art_dir / "bg_jizhou01_battle_bleed.png").convert("RGB")
    if bleed.size != (OUT_W, OUT_H) or main_img.size != (1920, 1080):
        raise SystemExit("背景尺寸不对")
    center = bleed.crop((210, 180, 2130, 1260))
    if np.any(np.asarray(center) != np.asarray(main_img)):
        raise SystemExit("出血图中间和正图不一致")

    level = json.loads((root / "content" / "levels" / "level_jizhou_01.json").read_text())
    segments, length = path_segments(level)
    canvas = bleed.convert("RGBA")
    slots = Image.open(unit_dir / "buildslot_states.png").convert("RGBA")
    slot_frames = [frame(slots, i, 3) for i in range(3)]
    cells = level["buildCells"]
    # 0 选中（塔盖在上面）、1 普通、2 禁用。三态都要能在预览里看见。
    slot_state = [1, 0, 2]
    cell_world = []
    for cell, state in zip(cells, slot_state):
        world = to_world(cell["x"], cell["y"])
        cell_world.append(world)
        blit(canvas, slot_frames[state], SLOT_PIVOT, world, SLOT_PPU)

    actors = []
    ding = to_world(level["waypoints"][-1]["x"], level["waypoints"][-1]["y"])
    actors.append((ding[1], "ding", ding, False, 0))
    tower_cell = cell_world[0]
    tower_foot_y = tower_cell[1] - FOOT_DROP
    tower_world = (tower_cell[0], tower_foot_y + TOWER_PIVOT[1] * (192.0 / TOWER_PPU))
    actors.append((tower_world[1], "tower", tower_world, False, 0))

    # 折线长度在 world 里约是高度单位的 9 倍。按路径比例铺开，帧号仍用高度单位 / speed。
    speed = 0.006
    placements = [
        (0.08, "walk"),
        (0.22, "walk"),
        (0.36, "flash"),
        (0.50, "walk"),
        (0.66, "death"),
        (0.82, "walk"),
    ]
    for fraction, kind in placements:
        distance = fraction * length
        pos, tangent = sample_path(segments, distance)
        frame_index = int((distance / 9.0) / speed) % 8
        actors.append((pos[1], kind, pos, tangent[0] < 0, frame_index))

    actors.sort(key=lambda item: -item[0])
    body = Image.open(unit_dir / "tower_jin_body.png").convert("RGBA")
    walk = Image.open(unit_dir / "enemy_dangkang_walk.png").convert("RGBA")
    flash = Image.open(unit_dir / "enemy_dangkang_hit_flash_white.png").convert("RGBA")
    death = Image.open(unit_dir / "enemy_dangkang_death.png").convert("RGBA")
    ding_img = Image.open(unit_dir / "ding_bronze.png").convert("RGBA")
    fx = frame(Image.open(unit_dir / "tower_jin_fx.png").convert("RGBA"), 2, 4)
    for _, kind, world, flip, frame_index in actors:
        if kind == "ding":
            blit(canvas, ding_img, DING_PIVOT, world, DING_PPU)
        elif kind == "tower":
            blit(canvas, body, TOWER_PIVOT, world, TOWER_PPU)
        elif kind == "walk":
            blit(canvas, frame(walk, frame_index, 8), DANGKANG_PIVOT, world, DANGKANG_PPU, flip)
        elif kind == "flash":
            blit(canvas, flash, DANGKANG_PIVOT, world, DANGKANG_PPU, flip)
        elif kind == "death":
            blit(canvas, death, DANGKANG_PIVOT, world, DANGKANG_PPU, flip)

    body_height = 192.0 / TOWER_PPU
    fx_world = (tower_world[0], tower_world[1] + (0.5 - TOWER_PIVOT[1]) * body_height)
    blit_additive(canvas, fx, FX_PIVOT, fx_world, TOWER_PPU)

    view_16 = canvas.crop((210, 180, 2130, 1260))
    view_wide = canvas.crop((0, 180, 2340, 1260))
    view_4x3 = canvas.crop((210, 0, 2130, 1440)).resize((1440, 1080), Image.Resampling.LANCZOS)
    outputs = {
        "jizhou01_preview_16x9.png": decorate(view_16, unit_dir),
        "jizhou01_preview_19_5x9.png": decorate(view_wide, unit_dir),
        "jizhou01_preview_4x3.png": decorate(view_4x3, unit_dir),
    }
    for name, image in outputs.items():
        path = out_dir / name
        image.save(path, format="PNG", optimize=True)
        print(path, image.size)

    print("path_length %.3f" % length)
    print("dangkang canvas %.3f world, torso about %.2f-%.2f" % (128 / DANGKANG_PPU, 85 / DANGKANG_PPU, 100 / DANGKANG_PPU))
    print("slot canvas %.3f world, opaque stone %.3f" % (128 / SLOT_PPU, 116 / SLOT_PPU))
    print("ding canvas %.3f world, base %.3f" % (256 / DING_PPU, 210 / DING_PPU))
    print("tower canvas %.3f world, sword half-width %.3f" % (192 / TOWER_PPU, 76 / TOWER_PPU))


if __name__ == "__main__":
    main()
