"""项目色板（唯一来源）。改色只改这里，然后运行 export_palette.py 同步 Krita / GIMP 色板和预览图。

规则：
- 纸色和墨色是全作的底，所有异兽都能用；
- 五行色只给玩法信息用：一只异兽主要用自己五行的三档色，最多再借一个五行做点缀；
- 青铜色给铜鼎、法宝、界面用。
"""

PAPER = {
    "paper": "efe9dc",
    "paper_shade": "d8cfbb",
}

INK = {
    "ink": "1c2421",
    "ink_soft": "3b4540",
    "ink_wash": "6b736e",
    "highlight": "f5f1e8",
}

# 每个五行三档：深、本色、浅。顺序与 core/elements.gd 一致，本色与游戏里的五行色相同。
ELEMENTS = {
    "mu": ["1f5a3f", "2f7d5a", "7fb595"],
    "huo": ["7d2a1d", "b9402c", "e08a72"],
    "tu": ["7a5a1e", "b8892e", "e2c07a"],
    "jin": ["8e989d", "c9d0d4", "eef1f2"],
    "shui": ["1a2735", "26384d", "5b7491"],
}

BRONZE = {
    "bronze_dark": "6d5a3a",
    "bronze": "9c6a27",
    "bronze_light": "c9a25a",
    "patina": "2f7d6d",
}

ELEMENT_NAMES = {"mu": "木", "huo": "火", "tu": "土", "jin": "金", "shui": "水"}


def hex_to_rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def all_colors():
    """[(名字, (r, g, b)), ...]"""
    out = []
    for group in (PAPER, INK, BRONZE):
        out += [(k, hex_to_rgb(v)) for k, v in group.items()]
    for el, shades in ELEMENTS.items():
        for name, h in zip(("dark", "base", "light"), shades):
            out.append((f"{el}_{name}", hex_to_rgb(h)))
    return out


def beast_palette(element, accent=None):
    """一只异兽可用的颜色：墨色 + 高光 + 纸影 + 自己五行三档 + 可选点缀五行三档。"""
    colors = [(k, hex_to_rgb(v)) for k, v in INK.items()]
    colors.append(("paper_shade", hex_to_rgb(PAPER["paper_shade"])))
    for el in [element] + ([accent] if accent and accent != element else []):
        for name, h in zip(("dark", "base", "light"), ELEMENTS[el]):
            colors.append((f"{el}_{name}", hex_to_rgb(h)))
    return colors
