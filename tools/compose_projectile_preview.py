#!/usr/bin/env python3
"""离线合成飞剑飞行与命中预览。不是 Unity Game 视图。"""

import math
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "Assets", "Game", "Resources", "BattleArt")
BG = os.path.join(ROOT, "Assets", "Game", "Art", "Backgrounds", "bg_jizhou01_battle.png")
OUT = os.environ.get("PROJECTILE_PREVIEW_DIR", os.path.join(ROOT, "artifacts"))
LABEL = "离线合成预览，非 Unity Game 视图"
FONT = "/usr/share/fonts/truetype/wqy/wqy-microhei.ttc"


def px_of(x, y):
    wx = (x - 0.889) * 9.0
    wy = (y - 0.5) * 9.0
    return 960.0 + wx * 120.0, 540.0 - wy * 120.0


def paste_pivot(canvas, sprite, anchor, pivot_norm, angle_deg=0, alpha=255):
    image = sprite.convert("RGBA")
    if angle_deg:
        image = image.rotate(angle_deg, resample=Image.BICUBIC, expand=True)
        # 旋转后 pivot 仍按画布中心近似；飞剑 pivot 在中心，expand 后中心不变。
        px = image.size[0] * 0.5
        py = image.size[1] * 0.5
    else:
        px = image.size[0] * pivot_norm[0]
        py = image.size[1] * (1.0 - pivot_norm[1])
    if alpha < 255:
        band = image.getchannel("A").point(lambda a: a * alpha // 255)
        image.putalpha(band)
    canvas.alpha_composite(image, (int(round(anchor[0] - px)), int(round(anchor[1] - py))))


def caption(image):
    draw = ImageDraw.Draw(image)
    font = ImageFont.truetype(FONT, 36)
    text = LABEL
    box = draw.textbbox((0, 0), text, font=font)
    tw, th = box[2] - box[0], box[3] - box[1]
    pad = 14
    x, y = 36, 28
    draw.rectangle((x - pad, y - pad, x + tw + pad, y + th + pad), fill=(20, 16, 12, 210))
    draw.text((x, y), text, font=font, fill=(254, 245, 233, 255))


def main():
    os.makedirs(OUT, exist_ok=True)
    bg = Image.open(BG).convert("RGBA")
    tower = Image.open(os.path.join(ART, "tower_jin_body.png")).convert("RGBA")
    enemy = Image.open(os.path.join(ART, "enemy_dangkang_walk.png")).convert("RGBA")
    # 行走条是 8 帧横排，取第 0 帧。
    enemy = enemy.crop((0, 0, 128, 128))
    sword = Image.open(os.path.join(ART, "proj_jin_sword.png")).convert("RGBA")
    hit = Image.open(os.path.join(ART, "proj_jin_hit_strip.png")).convert("RGBA")
    hit = hit.crop((128, 0, 256, 128))

    cell = (0.660, 0.690)
    enemy_pt = (0.700, 0.790)
    cell_px = px_of(*cell)
    enemy_px = px_of(*enemy_pt)
    start = (cell_px[0], cell_px[1] - 0.6 * 120.0)
    end = (enemy_px[0], enemy_px[1] - 0.37 * 120.0)

    def frame(progress, show_hit):
        image = bg.copy()
        paste_pivot(image, tower, cell_px, (0.5, 0.227))
        paste_pivot(image, enemy, enemy_px, (0.5, 0.031))
        sx = start[0] + (end[0] - start[0]) * progress
        sy = start[1] + (end[1] - start[1]) * progress
        angle = math.degrees(math.atan2(-(end[1] - start[1]), end[0] - start[0]))
        if not show_hit:
            for i, fade in enumerate((50, 90, 140)):
                t = max(0.0, progress - (3 - i) * 0.06)
                tx = start[0] + (end[0] - start[0]) * t
                ty = start[1] + (end[1] - start[1]) * t
                paste_pivot(image, sword, (tx, ty), (0.5, 0.5), angle, fade)
            paste_pivot(image, sword, (sx, sy), (0.5, 0.5), angle, 255)
        else:
            paste_pivot(image, hit, end, (0.5, 0.5))
        caption(image)
        return image

    flight = frame(0.55, False)
    impact = frame(1.0, True)
    flight_path = os.path.join(OUT, "projectile_flight_preview.png")
    hit_path = os.path.join(OUT, "projectile_hit_preview.png")
    flight.save(flight_path)
    impact.save(hit_path)
    print(flight_path)
    print(hit_path)


if __name__ == "__main__":
    main()
