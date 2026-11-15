#!/usr/bin/env python3
"""把 palette.py 导出成 Krita / GIMP 能直接导入的 .gpl 色板，以及一张色板预览图。

    pip install pillow
    python3 tools/art/export_palette.py

输出：art_src/shanhai_palette.gpl、art_src/shanhai_palette.png
Krita：设置 → 管理资源 → 导入资源 → 选 .gpl。
"""
import pathlib
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import palette  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "art_src"


def main():
    OUT.mkdir(exist_ok=True)
    colors = palette.all_colors()
    lines = ["GIMP Palette", "Name: 山海守鼎", "Columns: 6", "#"]
    lines += [f"{r:3d} {g:3d} {b:3d}\t{name}" for name, (r, g, b) in colors]
    (OUT / "shanhai_palette.gpl").write_text("\n".join(lines) + "\n", encoding="utf-8")
    cell, cols = 120, 6
    rows = (len(colors) + cols - 1) // cols
    img = Image.new("RGB", (cols * cell, rows * (cell + 28)), palette.hex_to_rgb(palette.PAPER["paper"]))
    draw = ImageDraw.Draw(img)
    font = ImageFont.load_default()
    for i, (name, rgb) in enumerate(colors):
        x, y = (i % cols) * cell, (i // cols) * (cell + 28)
        draw.rectangle([x + 6, y + 6, x + cell - 6, y + cell - 6], fill=rgb, outline=(28, 36, 33))
        draw.text((x + 8, y + cell - 2), name, fill=(28, 36, 33), font=font)
    img.save(OUT / "shanhai_palette.png")
    print(f"{len(colors)} 色 → {OUT / 'shanhai_palette.gpl'}、{OUT / 'shanhai_palette.png'}")


if __name__ == "__main__":
    main()
