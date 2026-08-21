"""重建 BlackOhm 的"像素小屋 G"图标源图（assets/icon_source.png）。

在 32x32 逻辑画布上绘制黑色像素小屋（三角屋顶 + 矩形屋身），
屋身中央为粗笔画字母 G，随后按最近邻放大到 256x256 保存。
运行后再执行 tool/generate_app_icons.py 即可同步 tray.ico 与 app_icon.ico。

依赖：Pillow    运行：python tool/gen_icon_source.py
"""
import random
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "icon_source.png"

S = 32          # 逻辑画布边长
SCALE = 8       # 最近邻放大倍数 → 256x256

img = Image.new("L", (S, S), 255)


def fill(x0, y0, x1, y1, color=0):
    """闭区间矩形填充（含端点，自动裁剪到画布内）。"""
    for y in range(max(0, y0), min(S - 1, y1) + 1):
        for x in range(max(0, x0), min(S - 1, x1) + 1):
            img.putpixel((x, y), color)


def tri_contains(px, py, ax, ay, bx, by, cx, cy):
    def sign(x0, y0, x1, y1):
        return (px - x1) * (y0 - y1) - (x0 - x1) * (py - y1)

    d1 = sign(ax, ay, bx, by)
    d2 = sign(bx, by, cx, cy)
    d3 = sign(cx, cy, ax, ay)
    has_neg = d1 < 0 or d2 < 0 or d3 < 0
    has_pos = d1 > 0 or d2 > 0 or d3 > 0
    return not (has_neg and has_pos)


def triangle(a, b, c, color=0):
    xs = [a[0], b[0], c[0]]
    ys = [a[1], b[1], c[1]]
    for y in range(max(0, min(ys)), min(S - 1, max(ys)) + 1):
        for x in range(max(0, min(xs)), min(S - 1, max(xs)) + 1):
            if tri_contains(x, y, *a, *b, *c):
                img.putpixel((x, y), color)


# ── 屋顶：实心外三角 − 内三角 = 厚屋顶轮廓，天然形成阶梯状像素斜边 ──
triangle((16, 0), (-1, 17), (32, 17))
triangle((16, 5), (6, 13), (25, 13), color=255)

# ── 屋身：2px 黑描边矩形，内部留白 ──
fill(4, 17, 27, 30)
fill(6, 19, 25, 28, color=255)

# ── 字母 G：2px 笔画，占据屋身内部 ──
fill(9, 19, 22, 20)     # 上横
fill(9, 19, 10, 28)     # 左竖
fill(9, 27, 22, 28)     # 下横
fill(20, 23, 21, 28)    # 右竖（下半）
fill(14, 23, 21, 24)    # 中横伸入

# ── 屋顶边缘随机噪点：复刻参考图的锯齿/抖动质感 ──
rng = random.Random(20260821)
for y in range(0, 17):
    for x in range(0, S):
        if img.getpixel((x, y)) == 0:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (-1, 1), (1, 1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < S and 0 <= ny < S and img.getpixel((nx, ny)) == 255:
                    if rng.random() < 0.06:
                        img.putpixel((nx, ny), 0)

OUT.parent.mkdir(parents=True, exist_ok=True)
img.resize((S * SCALE, S * SCALE), Image.Resampling.NEAREST).convert("RGB").save(OUT)
print(f"已生成 {OUT} ({S * SCALE}x{S * SCALE})")
