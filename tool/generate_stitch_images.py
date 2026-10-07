#!/usr/bin/env python3
"""プレミアム編み目の記号画像を生成する。

既存の assets/images/*.png と同じ見た目（200x200・透過背景・角丸の枠・太い線）で、
JIS L 0201 のかぎ針編目記号などを描く。編み目を追加・修正する時は、下の
SYMBOLS に描画関数を足して、このスクリプトを実行する。

    python3 tool/generate_stitch_images.py

必要なもの: Pillow (pip install pillow)
"""

import math
import os

from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, 'assets', 'images')
FONT_PATH = os.path.join(ROOT, 'assets', 'fonts', 'NotoSansJP-Bold.ttf')

SIZE = 200  # 出力サイズ
SCALE = 4  # なめらかに描くため、この倍率で描いてから縮小する
INK = (27, 27, 27, 255)  # 既存画像の線の色
LINE = 12  # 既存画像の主な線の太さ
FRAME_WIDTH = 7
FRAME_RADIUS = 19


class Pen:
    """200x200 の座標で描ける、拡大キャンバス上のペン。"""

    def __init__(self):
        self.image = Image.new('RGBA', (SIZE * SCALE, SIZE * SCALE), (0, 0, 0, 0))
        self.draw = ImageDraw.Draw(self.image)

    def frame(self):
        edge = SIZE * SCALE - 1
        self.draw.rounded_rectangle(
            [0, 0, edge, edge],
            radius=FRAME_RADIUS * SCALE,
            outline=INK,
            width=FRAME_WIDTH * SCALE,
        )

    def line(self, start, end, width=LINE):
        """端を直角に切った太い直線。"""
        (x1, y1), (x2, y2) = start, end
        length = math.hypot(x2 - x1, y2 - y1)
        if length == 0:
            return
        nx = -(y2 - y1) / length * width / 2
        ny = (x2 - x1) / length * width / 2
        points = [
            (x1 + nx, y1 + ny),
            (x2 + nx, y2 + ny),
            (x2 - nx, y2 - ny),
            (x1 - nx, y1 - ny),
        ]
        self.draw.polygon([(x * SCALE, y * SCALE) for x, y in points], fill=INK)

    def dot(self, center, radius):
        cx, cy = center
        self.draw.ellipse(
            [(cx - radius) * SCALE, (cy - radius) * SCALE,
             (cx + radius) * SCALE, (cy + radius) * SCALE],
            fill=INK,
        )

    def arc(self, center, radius, start_deg, end_deg, width=LINE, round_ends=False):
        """円弧。角度は右向きを0度として時計回り（start から end へ時計回りに描く）。"""
        cx, cy = center
        sweep = (end_deg - start_deg) % 360 or 360
        steps = max(8, int(sweep / 3))
        points = []
        for i in range(steps + 1):
            angle = math.radians(start_deg + sweep * i / steps)
            points.append((cx + radius * math.cos(angle), cy + radius * math.sin(angle)))
        for a, b in zip(points, points[1:]):
            self.line(a, b, width)
        # 折れ目のすき間を埋める
        joints = points if round_ends else points[1:-1]
        for point in joints:
            self.dot(point, width / 2)

    def ellipse(self, center, rx, ry, width=LINE, fill=False, rotate=0):
        """だ円（rotate は度。反時計回り）。"""
        pad = max(rx, ry) + width
        layer = Image.new('RGBA', (int(pad * 2 * SCALE), int(pad * 2 * SCALE)), (0, 0, 0, 0))
        box = [(pad - rx) * SCALE, (pad - ry) * SCALE, (pad + rx) * SCALE, (pad + ry) * SCALE]
        layer_draw = ImageDraw.Draw(layer)
        if fill:
            layer_draw.ellipse(box, fill=INK)
        else:
            layer_draw.ellipse(box, outline=INK, width=int(width * SCALE))
        if rotate:
            layer = layer.rotate(rotate, resample=Image.BICUBIC)
        cx, cy = center
        self.image.alpha_composite(
            layer, (int((cx - pad) * SCALE), int((cy - pad) * SCALE)))

    def text(self, center, text, size):
        font = ImageFont.truetype(FONT_PATH, size * SCALE)
        left, top, right, bottom = self.draw.textbbox((0, 0), text, font=font)
        cx, cy = center
        self.draw.text(
            (cx * SCALE - (left + right) / 2, cy * SCALE - (top + bottom) / 2),
            text, font=font, fill=INK)

    def save(self, name):
        self.frame()
        result = self.image.resize((SIZE, SIZE), Image.LANCZOS)
        result.save(os.path.join(OUT_DIR, name))


def point_on(start, end, t):
    return (start[0] + (end[0] - start[0]) * t, start[1] + (end[1] - start[1]) * t)


def tick(pen, start, end, t, length, width):
    """線 start-end 上の位置 t に、線と直角の短い斜線を引く（長編みの巻き数の印）。"""
    cx, cy = point_on(start, end, t)
    dx, dy = end[0] - start[0], end[1] - start[1]
    norm = math.hypot(dx, dy)
    nx, ny = -dy / norm, dx / norm
    half = length / 2
    pen.line((cx - nx * half, cy - ny * half), (cx + nx * half, cy + ny * half), width)


# ---- 引き上げ編み（JIS 3100-3112）----
# 表引き上げは下端のかぎが左に開き（数字の5の形）、裏引き上げは右に開く。

def post_stitch(name, back, wraps):
    """中長編み(wraps=0)・長編み(wraps=1)の引き上げ編み。"""
    pen = Pen()
    bar_y = 38 if wraps else 42
    stem_bottom = 108 if wraps else 105
    bowl_center_y = stem_bottom + 30
    radius = 29
    pen.line((48, bar_y), (152, bar_y))
    pen.line((100, bar_y), (100, stem_bottom + 2))
    if wraps:
        pen.line((76, 62), (124, 82), 10)
    if back:
        # 右に開く「C」の形
        pen.arc((96, bowl_center_y), radius, 10, 278, round_ends=True)
    else:
        # 左に開く「5」の下の丸の形
        pen.arc((104, bowl_center_y), radius, 262, 530, round_ends=True)
    pen.save(name)


def sc_post_stitch(name, back):
    """細編みの引き上げ編み。×の片方の線がそのまま下のかぎにつながる。"""
    pen = Pen()
    radius = 30
    if back:
        pen.line((66, 40), (134, 108))
        pen.line((134, 40), (76, 98))
        pen.arc((97.2, 119.2), radius, 15, 225, round_ends=True)
    else:
        pen.line((134, 40), (66, 108))
        pen.line((66, 40), (124, 98))
        pen.arc((102.8, 119.2), radius, 315, 525, round_ends=True)
    pen.save(name)


# ---- 編み入れる・一度（JIS 3084, 3094 と松編み）----

def fan_increase(name, tops, width):
    """1目に長編みを複数編み入れる（下の1点から上へ広がる）。"""
    pen = Pen()
    base = (100, 176)
    # 目数が多いと1目ずつの横棒は読みにくいので、JISの図と同じく1本につなげる
    pen.line((tops[0] - 10, 36), (tops[-1] + 10, 36), width)
    for x in tops:
        top = (x, 36)
        pen.line(base, top, width)
        cx, cy = point_on(base, top, 0.7)
        pen.line((cx - 11, cy - 4), (cx + 11, cy + 4), width - 1)
    pen.dot(base, width / 2)
    pen.save(name)


def fan_decrease(name, bottoms, width):
    """長編みを複数まとめて1目にする（上の1点から下へ広がる）。"""
    pen = Pen()
    apex = (100, 34)
    pen.line((56, 30), (144, 30), width + 1)
    for x in bottoms:
        bottom = (x, 174)
        pen.line(apex, bottom, width)
        cx, cy = point_on(apex, bottom, 0.6)
        pen.line((cx - 11, cy - 4), (cx + 11, cy + 4), width - 1)
    pen.save(name)


# ---- 交差・クロス（JIS 3062, 3070, 3071）----

def crossed(name, wraps):
    """2目の交差。既存の「長編み１目交差」と同じく、下になる線を交点で切って描く。"""
    pen = Pen()
    width = 10
    pen.line((26, 38), (74, 38), width)
    pen.line((126, 38), (174, 38), width)
    over_start, over_end = (150, 38), (48, 166)
    under_start, under_end = (50, 38), (152, 166)
    pen.line(over_start, over_end, width)
    pen.line(under_start, point_on(under_start, under_end, 0.40), width)
    pen.line(point_on(under_start, under_end, 0.60), under_end, width)
    for i in range(wraps):
        t = 0.14 + 0.13 * i
        tick(pen, over_start, over_end, t, 30, 8)
        tick(pen, under_start, under_end, t, 30, 8)
    pen.save(name)


def x_stitch(name, wraps):
    """クロス編み。X の上に鎖があり、上下の足それぞれに巻き数の印が付く。"""
    pen = Pen()
    width = 10
    pen.line((24, 44), (66, 44), width)
    pen.line((134, 44), (176, 44), width)
    pen.ellipse((88, 40), 11, 7, width=5)
    pen.ellipse((112, 40), 11, 7, width=5)
    right_start, right_end = (150, 44), (46, 170)
    left_start, left_end = (50, 44), (154, 170)
    pen.line(right_start, right_end, width)
    pen.line(left_start, left_end, width)
    for i in range(wraps):
        upper = 0.13 + 0.11 * i
        lower = 0.87 - 0.11 * i
        for start, end in ((right_start, right_end), (left_start, left_end)):
            tick(pen, start, end, upper, 26, 7)
            tick(pen, start, end, lower, 26, 7)
    pen.save(name)


# ---- リング編み（JIS 3120, 3121）----

def sc_loop(name):
    pen = Pen()
    pen.line((62, 34), (62, 120))
    pen.line((138, 34), (138, 120))
    pen.arc((100, 120), 38, 0, 180)
    pen.line((76, 42), (124, 90), 10)
    pen.line((124, 42), (76, 90), 10)
    pen.save(name)


def dc_loop(name):
    pen = Pen()
    pen.line((48, 36), (152, 36))
    pen.line((60, 36), (60, 126))
    pen.line((140, 36), (140, 126))
    pen.arc((100, 126), 40, 0, 180)
    pen.line((100, 36), (100, 140), 10)
    pen.line((80, 74), (120, 92), 9)
    pen.save(name)


# ---- 輪編みの始まり・ピコット・玉編み ----

def magic_ring(name):
    """輪の作り目。編み図では中心の円に「わ」と書いて表す。"""
    pen = Pen()
    pen.ellipse((100, 100), 64, 64)
    pen.text((100, 98), 'わ', 74)
    pen.save(name)


def picot(name, base):
    """鎖3目のピコット。根元が引き抜き編み(●)か細編み(×)かで2種類。"""
    pen = Pen()
    pen.ellipse((62, 100), 31, 16, width=10, rotate=62)
    pen.ellipse((100, 56), 31, 16, width=10)
    pen.ellipse((138, 100), 31, 16, width=10, rotate=-62)
    if base == 'slip':
        pen.ellipse((100, 152), 24, 14, fill=True)
    else:
        pen.line((80, 132), (120, 172), 10)
        pen.line((120, 132), (80, 172), 10)
    pen.save(name)


def bobble_2(name, wraps):
    """2目の玉編み。3目の玉編みから中央の線を除いた形。"""
    pen = Pen()
    pen.line((52, 32), (148, 32))
    pen.arc((137.3, 106), 79.3, 118.1, 241.9)
    pen.arc((62.7, 106), 79.3, 298.1, 421.9)
    if wraps:
        pen.line((44, 98), (74, 110), 10)
        pen.line((126, 98), (156, 110), 10)
    pen.save(name)


def mirrored(name, source):
    """既存の記号を左右反転する（右上交差 → 左上交差）。"""
    image = Image.open(os.path.join(OUT_DIR, source)).convert('RGBA')
    ImageOps.mirror(image).save(os.path.join(OUT_DIR, name))


SYMBOLS = [
    lambda: sc_post_stitch('sc_front_post.png', back=False),
    lambda: sc_post_stitch('sc_back_post.png', back=True),
    lambda: post_stitch('hdc_front_post.png', back=False, wraps=0),
    lambda: post_stitch('hdc_back_post.png', back=True, wraps=0),
    lambda: post_stitch('dc_front_post.png', back=False, wraps=1),
    lambda: post_stitch('dc_back_post.png', back=True, wraps=1),
    lambda: fan_increase('dc_4_increase.png', [28, 76, 124, 172], 10),
    lambda: fan_increase('dc_5_shell.png', [24, 62, 100, 138, 176], 9),
    lambda: fan_decrease('dc_4_together.png', [26, 76, 124, 174], 10),
    lambda: crossed('tc_cross.png', wraps=2),
    lambda: x_stitch('dc_x_stitch.png', wraps=1),
    lambda: x_stitch('tc_x_stitch.png', wraps=2),
    lambda: sc_loop('sc_loop.png'),
    lambda: dc_loop('dc_loop.png'),
    lambda: magic_ring('magic_ring.png'),
    lambda: picot('picot_slip.png', base='slip'),
    lambda: picot('picot_sc.png', base='sc'),
    lambda: bobble_2('hdc_2_bobble.png', wraps=0),
    lambda: bobble_2('dc_2_bobble.png', wraps=1),
    lambda: mirrored('dc_left_cross.png', '長編み１目右上交差.png'),
]


if __name__ == '__main__':
    for draw_symbol in SYMBOLS:
        draw_symbol()
    print(f'{len(SYMBOLS)} 個の記号画像を {OUT_DIR} に書き出しました')
