#!/usr/bin/env python3
"""从冀州 01 正图外扩一张 2520×1440 出血图。

中间 1920×1080 与正图逐像素相同。外圈先按边缘条做镜像拉伸（近处延续画面，
远处拉成色带），再按离开安全区的距离由内向外加重高斯模糊，并稍微压暗、降饱和。
接缝外侧的第一圈像素等于正图边缘。PPU 120 下整张是 21×12 world：正交 size 4.5
的 21:9 可视宽正好 21；4:3 把 size 放到 6 时可视高正好 12。

用法（仓库根目录）：
    python3 tools/generate_jizhou01_bleed.py
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

SRC_NAME = "bg_jizhou01_battle.png"
DST_NAME = "bg_jizhou01_battle_bleed.png"
OUT_W = 2520
OUT_H = 1440
SAFE_W = 1920
SAFE_H = 1080
# 只镜像很窄的边缘条，避免把石柱、骨架整段翻到画面外。
# 远处改用更窄的色带，再交给模糊压成连续的色晕。
MIRROR_STRIP = 24
SMEAR_STRIP = 6
# 安全区外多少像素内保持不模糊，保证接缝连续。
SHARP_PAD = 2


def repo_root() -> Path:
    here = Path(__file__).resolve()
    for parent in here.parents:
        if (parent / "Assets" / "Game").is_dir():
            return parent
    raise SystemExit("找不到仓库根目录")


def sample(src: np.ndarray, sy: np.ndarray, sx: np.ndarray) -> np.ndarray:
    height, width, _ = src.shape
    x0 = np.floor(sx).astype(np.int32)
    y0 = np.floor(sy).astype(np.int32)
    wx = (sx - x0).astype(np.float32)[..., None]
    wy = (sy - y0).astype(np.float32)[..., None]
    x0 = np.clip(x0, 0, width - 1)
    y0 = np.clip(y0, 0, height - 1)
    x1 = np.clip(x0 + 1, 0, width - 1)
    y1 = np.clip(y0 + 1, 0, height - 1)
    c00 = src[y0, x0].astype(np.float32)
    c10 = src[y0, x1].astype(np.float32)
    c01 = src[y1, x0].astype(np.float32)
    c11 = src[y1, x1].astype(np.float32)
    return (c00 * (1 - wx) + c10 * wx) * (1 - wy) + (c01 * (1 - wx) + c11 * wx) * wy


def axis_coord(content: np.ndarray, dist: np.ndarray, size: int, margin: int, strip: int) -> np.ndarray:
    inside = (content >= 0) & (content < size)
    span = max(margin - 1, 1)
    t = np.clip((dist - 1) / span, 0, 1)
    inset = np.sqrt(t) * (strip - 1)
    on_start = content < 0
    outside = np.where(on_start, inset, (size - 1) - inset)
    return np.where(inside, content.astype(np.float32), outside.astype(np.float32))


def extend(src: np.ndarray, left: int, top: int, strip: int) -> np.ndarray:
    height, width, _ = src.shape
    ys = np.arange(OUT_H, dtype=np.float32)[:, None]
    xs = np.arange(OUT_W, dtype=np.float32)[None, :]
    content_x = xs - left
    content_y = ys - top
    dx = np.maximum(np.maximum(left - xs, 0), xs - (left + width - 1))
    dy = np.maximum(np.maximum(top - ys, 0), ys - (top + height - 1))
    sx = axis_coord(content_x, dx, width, left, strip)
    sy = axis_coord(content_y, dy, height, top, strip)
    return sample(src, sy, sx)


def blur(image: np.ndarray, radius: float) -> np.ndarray:
    pil = Image.fromarray(np.clip(np.round(image), 0, 255).astype(np.uint8), "RGB")
    return np.asarray(pil.filter(ImageFilter.GaussianBlur(radius=radius)), dtype=np.float32)


def mix_blur(image: np.ndarray, amount: np.ndarray) -> np.ndarray:
    """amount 为 0 时保持原像素，为 1 时用最大模糊。按像素在相邻两级之间线性混合。"""
    levels = [image]
    for radius in (3, 9, 20, 42):
        levels.append(blur(image, radius))
    steps = len(levels) - 1
    idx = np.clip(amount, 0, 1) * steps
    idx = np.minimum(idx, steps - 1e-4)
    i0 = np.floor(idx).astype(np.int32)
    frac = (idx - i0).astype(np.float32)
    acc = np.zeros_like(image)
    for i in range(steps):
        mask = i0 == i
        if not np.any(mask):
            continue
        weight = frac[mask][..., None]
        acc[mask] = levels[i][mask] * (1 - weight) + levels[i + 1][mask] * weight
    return acc


def grade(image: np.ndarray, amount: np.ndarray) -> np.ndarray:
    t = amount[..., None]
    luma = image[..., 0] * 0.2126 + image[..., 1] * 0.7152 + image[..., 2] * 0.0722
    desat = np.clip(0.48 * t, 0, 1)
    colored = image * (1 - desat) + luma[..., None] * desat
    return colored * (1 - 0.22 * np.power(np.clip(t, 0, 1), 1.05))


def generate(src_path: Path, dst_path: Path) -> None:
    src_img = Image.open(src_path).convert("RGB")
    if src_img.size != (SAFE_W, SAFE_H):
        raise SystemExit("正图不是 1920×1080：%s" % (src_img.size,))
    src = np.asarray(src_img)
    left = (OUT_W - SAFE_W) // 2
    top = (OUT_H - SAFE_H) // 2
    if left * 2 + SAFE_W != OUT_W or top * 2 + SAFE_H != OUT_H:
        raise SystemExit("出血尺寸与安全区不能居中对齐")

    mirror = extend(src, left, top, MIRROR_STRIP)
    smear = extend(src, left, top, SMEAR_STRIP)
    ys = np.arange(OUT_H)[:, None]
    xs = np.arange(OUT_W)[None, :]
    dx = np.maximum(np.maximum(left - xs, 0), xs - (left + SAFE_W - 1))
    dy = np.maximum(np.maximum(top - ys, 0), ys - (top + SAFE_H - 1))
    dist = np.maximum(dx, dy).astype(np.float32)
    # 大约 50px 外就不再延续可辨认的形状，改成边缘色带。
    fade = np.clip((dist - 1) / 48.0, 0, 1) ** 0.85
    extended = mirror * (1 - fade[..., None]) + smear * fade[..., None]
    blur_amount = np.clip((dist - SHARP_PAD) / 64.0, 0, 1) ** 0.75
    blurred = mix_blur(extended, blur_amount)
    graded = grade(blurred, blur_amount)

    center = graded[top : top + SAFE_H, left : left + SAFE_W]
    # 接缝第一圈应等于正图边缘。模糊从第 SHARP_PAD 像素外才开始。
    seam = graded[top : top + SAFE_H, left - 1]
    edge = src[:, 0].astype(np.float32)
    seam_err = float(np.max(np.abs(seam - edge)))
    if seam_err > 0.6:
        raise SystemExit("左接缝不连续，最大差 %.3f" % seam_err)

    out = np.clip(np.round(graded), 0, 255).astype(np.uint8)
    out[top : top + SAFE_H, left : left + SAFE_W] = src
    if not np.array_equal(out[top : top + SAFE_H, left : left + SAFE_W], src):
        raise SystemExit("中间安全区与正图不一致")

    dst_path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(out, "RGB").save(dst_path, format="PNG", optimize=True)
    print("wrote %s  seam_max_delta=%.3f" % (dst_path, seam_err))


def main() -> None:
    root = repo_root()
    art = root / "Assets" / "Game" / "Art" / "Backgrounds"
    src = art / SRC_NAME
    dst = art / DST_NAME
    if len(sys.argv) == 3:
        src = Path(sys.argv[1])
        dst = Path(sys.argv[2])
    generate(src, dst)


if __name__ == "__main__":
    main()
