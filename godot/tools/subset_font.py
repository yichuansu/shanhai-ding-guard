#!/usr/bin/env python3
"""把 Noto Sans SC 裁剪成游戏用的子集字体。

保留：ASCII、常用标点和全角符号、GB2312 一级字库（3755 个常用汉字）、
以及工程里 .gd / .tres / .tscn 实际用到的所有字符。新增文案出现生僻字时重跑一次。

用法（需要 pip install fonttools）：
    python3 godot/tools/subset_font.py <NotoSansSC-Regular.ttf> godot/assets/fonts/NotoSansSC-Subset.ttf

源字体可从 Google Fonts（Noto Sans SC，SIL OFL 1.1）获取，不入库。
"""
import pathlib
import sys

from fontTools import subset


def gb2312_level1() -> set[str]:
    chars = set()
    for hi in range(0xB0, 0xD8):
        for lo in range(0xA1, 0xFF):
            try:
                chars.add(bytes([hi, lo]).decode("gb2312"))
            except UnicodeDecodeError:
                pass
    return chars


def project_chars(root: pathlib.Path) -> set[str]:
    chars = set()
    for ext in ("*.gd", "*.tres", "*.tscn", "*.godot"):
        for path in root.rglob(ext):
            if ".godot" in path.parts:
                continue
            chars.update(path.read_text(encoding="utf-8"))
    return chars


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    src, dst = sys.argv[1], sys.argv[2]
    root = pathlib.Path(__file__).resolve().parent.parent
    chars = set(chr(c) for c in range(0x20, 0x7F))
    chars |= set(chr(c) for c in range(0x3000, 0x3040))  # CJK 标点
    chars |= set(chr(c) for c in range(0xFF00, 0xFFF0))  # 全角字符
    chars |= set("·—…‘’“”★☆✓✗←→↑↓×÷°%")
    chars |= gb2312_level1()
    chars |= {c for c in project_chars(root) if ord(c) >= 0x20}
    options = subset.Options()
    options.layout_features = ["*"]
    options.name_IDs = ["*"]
    options.notdef_outline = True
    font = subset.load_font(src, options)
    subsetter = subset.Subsetter(options)
    subsetter.populate(text="".join(sorted(chars)))
    subsetter.subset(font)
    subset.save_font(font, dst, options)
    print(f"{len(chars)} 个字符 → {dst} ({pathlib.Path(dst).stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
