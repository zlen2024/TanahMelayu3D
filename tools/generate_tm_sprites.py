"""
Tanah Melayu (Zaman Melaka) sprites — playable classes and folklore creatures.

Separate from generate_sprites.py because this is a distinct art direction, not
a variant of the existing placeholder set.

Design constraints from wiki/design/decisions.md D8:
  - restricted humid palette, low saturation, high value contrast
  - silhouette first: shape reads before detail
  - light is the mood tool, not texture

Frame size is 48x48, raised from 32 after reference review: 32px could not hold
the shading, ragged hems and hair mass the folklore designs need. That is 2.25x
the pixel area, and it still reads as pixel art at the game's 1.8x camera zoom.

Run:  python tools/generate_tm_sprites.py
"""
import math
import os
from PIL import Image, ImageDraw

OUT_SPRITES = "assets/sprites/tm"
OUT_FRAMES = "assets/spriteframes/tm"
FRAME = 48
FRAMES_PER_SHEET = 6          # 2 idle + 4 walk, matching the existing pipeline

# Restricted humid palette. Everything is drawn from this and nothing else.
TM = {
    "skin":        (176, 130, 92),
    "skin_mid":    (150, 108, 76),
    "skin_dark":   (118, 84, 58),
    "mud":         (100, 78, 56),
    "mud_mid":     (78, 60, 44),
    "mud_dark":    (54, 42, 32),
    "brass":       (172, 132, 64),
    "brass_dark":  (118, 88, 40),
    "silver":      (158, 160, 156),
    "silver_dark": (100, 102, 100),
    "blood":       (118, 44, 42),
    "blood_mid":   (92, 34, 32),
    "blood_dark":  (62, 24, 24),
    "lamp":        (222, 148, 62),
    "ember":       (236, 108, 46),
    "swamp":       (80, 94, 60),
    "swamp_mid":   (62, 74, 46),
    "swamp_dark":  (42, 52, 34),
    "cloth":       (74, 68, 78),
    "cloth_mid":   (54, 50, 60),
    "cloth_dark":  (36, 33, 42),
    "shroud":      (196, 188, 168),
    "shroud_mid":  (162, 154, 136),
    "shroud_dark": (120, 114, 100),
    "bone":        (206, 196, 172),
    "ink":         (22, 20, 26),
    "rot":         (96, 104, 64),
    "rot_dark":    (66, 72, 44),
}


# --- drawing helpers -------------------------------------------------------

def _col(name, alpha=255):
    r, g, b = TM[name]
    return (r, g, b, alpha)


def _shaded_box(d, x0, y0, x1, y1, base, mid, dark):
    """Block with a lit left edge, a body, and a shaded right edge + underside."""
    d.rectangle([x0, y0, x1, y1], fill=_col(mid))
    d.rectangle([x0, y0, x0 + max(1, (x1 - x0) // 3), y1], fill=_col(base))
    d.rectangle([x1 - 1, y0, x1, y1], fill=_col(dark))
    d.rectangle([x0, y1 - 1, x1, y1], fill=_col(dark))


def _ragged_hem(d, x0, x1, y, col, depth=4, seed=0):
    """Torn cloth edge. The reference leans on these for every spirit."""
    for x in range(x0, x1 + 1):
        n = (math.sin((x + seed) * 1.7) + math.sin((x + seed) * 0.6)) * 0.5
        drop = int((n + 1) * depth * 0.5)
        if drop > 0:
            d.line([x, y, x, y + drop], fill=col)


def _eyes(d, cx, y, spread=3):
    """Plain dark eyes for living humans. Two pixels wide: any larger and they
    merge into a single band across a 12px face."""
    for sx in (-spread - 1, spread - 1):
        d.rectangle([cx + sx, y, cx + sx + 1, y + 2], fill=_col("ink"))


def _glow_eyes(d, cx, y, col, spread=3, size=2):
    """Bright eyes in a dark socket — the whole read in low light."""
    for sx in (-spread - 1, spread - 1):
        d.rectangle([cx + sx - 1, y - 1, cx + sx + size, y + size + 1], fill=_col("ink"))
        d.rectangle([cx + sx, y, cx + sx + size - 1, y + size], fill=col)


def _shadow(d, cx, y, w=14, alpha=95):
    d.ellipse([cx - w, y, cx + w, y + 6], fill=(0, 0, 0, alpha))


def _hair_strands(d, cx, top, length, col, count=9, seed=0, spread=10):
    for i in range(count):
        x = cx - spread + int(i * (spread * 2 / max(1, count - 1)))
        wob = int(math.sin((i + seed) * 1.3) * 2)
        d.line([x, top, x + wob, top + length - abs(x - cx) // 2], fill=col)


def _legs(d, cx, b, step, base, mid, dark, top=30, bottom=41):
    lx, rx = cx - 7 + step, cx + 2 - step
    _shaded_box(d, lx, top + b, lx + 5, bottom, base, mid, dark)
    _shaded_box(d, rx, top + b, rx + 5, bottom, base, mid, dark)
    d.rectangle([lx - 1, bottom, lx + 5, bottom + 1], fill=_col("mud_dark"))
    d.rectangle([rx - 1, bottom, rx + 5, bottom + 1], fill=_col("mud_dark"))


def _head(d, cx, b, top=10):
    _shaded_box(d, cx - 6, top + b, cx + 5, top + 11 + b, "skin", "skin_mid", "skin_dark")


def _arm(d, sx, sy, hx, hy, base, dark):
    """Weapons without a connecting limb read as floating."""
    d.line([sx, sy, hx, hy], fill=_col(base), width=3)
    d.line([sx, sy + 1, hx, hy + 1], fill=_col(dark), width=1)


# ===========================================================================
# PLAYABLE CLASSES
# ===========================================================================
# Each is built around one silhouette anchor that reads before any detail:
#   Pendekar  tengkolok peak + shield   (widest)
#   Perisik   crouched, hooded, narrow  (smallest)
#   Pawang    staff taller than figure  (strong vertical)
#   Pemanah   the bow arc               (only curve)

def draw_pendekar(d, ox, b, step):
    cx = ox + 24
    _shadow(d, cx, 41)
    _legs(d, cx, b, step, "mud", "mud_mid", "mud_dark")

    _shaded_box(d, cx - 9, 19 + b, cx + 8, 32 + b, "blood", "blood_mid", "blood_dark")
    _shaded_box(d, cx - 9, 28 + b, cx + 8, 32 + b, "mud", "mud_mid", "mud_dark")
    d.rectangle([cx - 7, 29 + b, cx + 6, 29 + b], fill=_col("brass_dark"))

    _head(d, cx, b)
    # tengkolok: wrapped band and the folded peak that defines the silhouette
    _shaded_box(d, cx - 8, 6 + b, cx + 7, 12 + b, "mud", "mud_mid", "mud_dark")
    d.rectangle([cx - 8, 10 + b, cx + 7, 11 + b], fill=_col("brass_dark"))
    d.polygon([(cx + 6, 5 + b), (cx + 13, 1 + b), (cx + 9, 10 + b)], fill=_col("mud_mid"))
    d.polygon([(cx + 6, 5 + b), (cx + 11, 3 + b), (cx + 8, 8 + b)], fill=_col("mud"))
    _eyes(d, cx, 16 + b)
    d.rectangle([cx - 3, 20 + b, cx + 2, 20 + b], fill=_col("skin_dark"))

    sy = b - step
    _arm(d, cx + 7, 22 + b, cx + 13, 27 + sy, "blood", "blood_dark")
    d.rectangle([cx + 13, 10 + sy, cx + 15, 28 + sy], fill=_col("silver"))
    d.rectangle([cx + 15, 10 + sy, cx + 15, 28 + sy], fill=_col("silver_dark"))
    d.rectangle([cx + 11, 28 + sy, cx + 17, 30 + sy], fill=_col("brass"))
    d.rectangle([cx + 13, 30 + sy, cx + 15, 34 + sy], fill=_col("mud_dark"))

    hy = b + step
    d.ellipse([cx - 20, 18 + hy, cx - 7, 34 + hy], fill=_col("mud_dark"))
    d.ellipse([cx - 19, 19 + hy, cx - 8, 33 + hy], fill=_col("mud_mid"))
    d.ellipse([cx - 18, 20 + hy, cx - 11, 29 + hy], fill=_col("mud"))
    d.ellipse([cx - 16, 24 + hy, cx - 11, 29 + hy], fill=_col("brass"))
    d.ellipse([cx - 15, 25 + hy, cx - 13, 27 + hy], fill=_col("brass_dark"))
    _arm(d, cx - 8, 22 + b, cx - 12, 25 + hy, "blood", "blood_dark")


def draw_perisik(d, ox, b, step):
    cx = ox + 24
    c = 3                                   # crouched: the whole figure sits lower
    _shadow(d, cx, 41, w=12)
    _legs(d, cx, b, step, "cloth", "cloth_mid", "cloth_dark", top=31 + c)

    _shaded_box(d, cx - 8, 21 + b + c, cx + 7, 33 + b, "cloth", "cloth_mid", "cloth_dark")
    d.rectangle([cx - 8, 28 + b, cx + 7, 30 + b], fill=_col("swamp_dark"))

    _shaded_box(d, cx - 7, 12 + b + c, cx + 6, 23 + b + c, "cloth_mid", "cloth_dark", "ink")
    d.rectangle([cx - 7, 17 + b + c, cx + 6, 19 + b + c], fill=_col("skin_dark"))
    _glow_eyes(d, cx, 18 + b + c, _col("lamp"), spread=4)
    d.line([cx - 7, 15 + b + c, cx - 14, 22 + b + c], fill=_col("cloth_dark"), width=2)
    _ragged_hem(d, cx - 15, cx - 12, 22 + b + c, _col("cloth_dark"), depth=3)

    sy = b - step + c
    _arm(d, cx + 7, 25 + b + c, cx + 12, 29 + sy, "cloth_mid", "cloth_dark")
    d.arc([cx + 10, 26 + sy, cx + 20, 36 + sy], 250, 30, fill=_col("ink"), width=3)
    d.arc([cx + 10, 26 + sy, cx + 19, 35 + sy], 250, 30, fill=_col("bone"), width=1)
    hy = b + step + c
    _arm(d, cx - 8, 25 + b + c, cx - 13, 29 + hy, "cloth_mid", "cloth_dark")
    d.arc([cx - 20, 26 + hy, cx - 10, 36 + hy], 150, 290, fill=_col("ink"), width=3)
    d.arc([cx - 19, 26 + hy, cx - 10, 35 + hy], 150, 290, fill=_col("bone"), width=1)


def draw_pawang(d, ox, b, step):
    cx = ox + 24
    _shadow(d, cx, 41, w=15)
    d.polygon([(cx - 8, 19 + b), (cx + 7, 19 + b), (cx + 12, 41), (cx - 13, 41)],
              fill=_col("swamp_mid"))
    d.polygon([(cx - 8, 19 + b), (cx - 1, 19 + b), (cx - 4, 41), (cx - 13, 41)],
              fill=_col("swamp_dark"))
    d.polygon([(cx + 3, 19 + b), (cx + 7, 19 + b), (cx + 12, 41), (cx + 7, 41)],
              fill=_col("ink"))
    _ragged_hem(d, cx - 13, cx + 12, 41, _col("swamp_dark"), depth=4, seed=3)

    _head(d, cx, b)
    _shaded_box(d, cx - 8, 7 + b, cx + 7, 13 + b, "shroud_mid", "shroud_dark", "mud_dark")
    d.rectangle([cx - 10, 12 + b, cx - 6, 26 + b], fill=_col("mud_dark"))
    d.rectangle([cx + 6, 12 + b, cx + 10, 26 + b], fill=_col("mud_dark"))
    _hair_strands(d, cx, 24 + b, 5, _col("ink"), count=5, spread=9)
    _glow_eyes(d, cx, 16 + b, _col("lamp"), spread=3)
    d.line([cx - 4, 22 + b, cx + 3, 22 + b], fill=_col("brass"), width=1)

    # tongkat kayu nibong: taller than the figure. Planted, so it does NOT bob.
    _arm(d, cx + 7, 23 + b, cx + 13, 21 + b, "swamp_mid", "swamp_dark")
    d.rectangle([cx + 13, 2, cx + 15, 41], fill=_col("mud_mid"))
    d.rectangle([cx + 15, 2, cx + 15, 41], fill=_col("mud_dark"))
    d.ellipse([cx + 10, -2, cx + 18, 6], fill=_col("mud_dark"))
    d.ellipse([cx + 11, -1, cx + 17, 5], fill=_col("blood"))
    d.ellipse([cx + 13, 1, cx + 15, 3], fill=_col("ember"))

    hy = b + step
    _arm(d, cx - 8, 23 + b, cx - 14, 26 + hy, "swamp_mid", "swamp_dark")
    d.rectangle([cx - 18, 26 + hy, cx - 11, 30 + hy], fill=_col("brass_dark"))
    d.rectangle([cx - 17, 25 + hy, cx - 12, 26 + hy], fill=_col("ember"))
    for sx, sy2, a in ((0, 4, 150), (-1, 8, 110), (1, 12, 60)):
        d.point((cx - 14 + sx, 22 - sy2 + hy), fill=(170, 170, 170, a))


def draw_pemanah(d, ox, b, step):
    cx = ox + 24
    _shadow(d, cx, 41, w=13)
    _legs(d, cx, b, step, "swamp_mid", "swamp_dark", "ink")

    _shaded_box(d, cx - 8, 19 + b, cx + 7, 31 + b, "swamp", "swamp_mid", "swamp_dark")
    d.rectangle([cx - 8, 27 + b, cx + 7, 29 + b], fill=_col("mud_mid"))

    _head(d, cx, b)
    d.rectangle([cx - 7, 10 + b, cx + 6, 13 + b], fill=_col("mud_dark"))
    _shaded_box(d, cx - 6, 6 + b, cx + 5, 11 + b, "mud_mid", "mud_dark", "ink")
    d.line([cx + 6, 12 + b, cx + 12, 17 + b], fill=_col("mud_dark"), width=2)
    _eyes(d, cx, 16 + b)

    # quiver sits behind the torso, so the draw arm does not blob into it
    _shaded_box(d, cx + 8, 16 + b, cx + 12, 29 + b, "mud", "mud_mid", "mud_dark")
    for i, fx in enumerate((9, 11)):
        d.line([cx + fx, 9 + b + i * 2, cx + fx, 16 + b], fill=_col("bone"))
        d.line([cx + fx, 9 + b + i * 2, cx + fx + 1, 11 + b + i * 2], fill=_col("shroud_dark"))

    hy = b + step
    d.arc([cx - 22, 8 + hy, cx - 6, 38 + hy], 60, 300, fill=_col("mud_dark"), width=3)
    d.arc([cx - 21, 9 + hy, cx - 7, 37 + hy], 60, 300, fill=_col("mud"), width=1)
    d.line([cx - 14, 9 + hy, cx - 14, 37 + hy], fill=_col("bone"))
    _arm(d, cx - 8, 22 + b, cx - 14, 22 + hy, "swamp", "swamp_dark")
    _arm(d, cx + 7, 22 + b, cx + 6, 25 + b - step, "swamp", "swamp_dark")


# ===========================================================================
# FOLKLORE CREATURES  (bestiary Lv1-19)
# ===========================================================================
# Built to the supplied reference: ragged silhouettes, glowing eyes, hair as
# mass rather than as strands.

def draw_penyamun(d, ox, b, step):
    """Lv1 human grunt — road bandit with a rusted parang."""
    cx = ox + 24
    _shadow(d, cx, 41)
    _legs(d, cx, b, step, "mud_mid", "mud_dark", "ink")
    _shaded_box(d, cx - 8, 20 + b, cx + 7, 32 + b, "mud", "mud_mid", "mud_dark")
    _ragged_hem(d, cx - 8, cx + 7, 32 + b, _col("mud_dark"), depth=3, seed=5)
    d.rectangle([cx - 8, 28 + b, cx + 7, 30 + b], fill=_col("blood_dark"))

    _head(d, cx, b)
    d.rectangle([cx - 7, 9 + b, cx + 6, 12 + b], fill=_col("blood_mid"))
    d.rectangle([cx - 6, 18 + b, cx + 5, 21 + b], fill=_col("shroud_dark"))
    _eyes(d, cx, 14 + b)

    sy = b - step
    _arm(d, cx + 7, 23 + b, cx + 12, 27 + sy, "mud", "mud_dark")
    d.polygon([(cx + 12, 26 + sy), (cx + 20, 12 + sy), (cx + 22, 15 + sy),
               (cx + 15, 28 + sy)], fill=_col("silver_dark"))
    d.polygon([(cx + 13, 25 + sy), (cx + 19, 14 + sy), (cx + 20, 16 + sy),
               (cx + 15, 26 + sy)], fill=(140, 116, 96, 255))
    d.rectangle([cx + 11, 26 + sy, cx + 15, 29 + sy], fill=_col("mud_dark"))
    _arm(d, cx - 8, 23 + b, cx - 12, 28 + b + step, "mud", "mud_dark")


def draw_jin_tanah(d, ox, b, step):
    """Lv1 ranged nuisance — clay figure bound in rotted shroud cloth."""
    cx = ox + 24
    _shadow(d, cx, 42, w=11)
    # bound shroud, no legs: it hops rather than walks
    d.polygon([(cx - 9, 14 + b), (cx + 8, 14 + b), (cx + 11, 41 + b), (cx - 12, 41 + b)],
              fill=_col("shroud_mid"))
    d.polygon([(cx - 9, 14 + b), (cx - 2, 14 + b), (cx - 5, 41 + b), (cx - 12, 41 + b)],
              fill=_col("shroud"))
    d.polygon([(cx + 4, 14 + b), (cx + 8, 14 + b), (cx + 11, 41 + b), (cx + 6, 41 + b)],
              fill=_col("shroud_dark"))
    d.rectangle([cx - 10, 24 + b, cx + 9, 26 + b], fill=_col("mud_mid"))
    d.rectangle([cx - 9, 14 + b, cx + 8, 16 + b], fill=_col("mud_mid"))
    _ragged_hem(d, cx - 12, cx + 11, 41 + b, _col("shroud_dark"), depth=4, seed=1)

    d.ellipse([cx - 8, 4 + b, cx + 7, 18 + b], fill=_col("shroud_mid"))
    d.ellipse([cx - 7, 5 + b, cx + 3, 15 + b], fill=_col("shroud"))
    d.polygon([(cx - 3, 4 + b), (cx, -2 + b), (cx + 3, 4 + b)], fill=_col("shroud_dark"))
    d.ellipse([cx - 5, 8 + b, cx + 4, 15 + b], fill=_col("ink"))
    _glow_eyes(d, cx, 11 + b, _col("ember"), spread=3, size=2)


def draw_toyol(d, ox, b, step):
    """Lv5 fast melee crippler — green slimy dwarf, red eyes."""
    cx = ox + 24
    _shadow(d, cx, 43, w=10)
    _legs(d, cx, b, step, "rot", "rot_dark", "ink", top=34, bottom=42)
    _shaded_box(d, cx - 7, 24 + b, cx + 6, 35 + b, "rot", "rot_dark", "ink")
    d.rectangle([cx - 7, 31 + b, cx + 6, 34 + b], fill=_col("mud_dark"))

    d.ellipse([cx - 10, 8 + b, cx + 9, 26 + b], fill=_col("rot"))
    d.ellipse([cx - 9, 9 + b, cx + 3, 21 + b], fill=(112, 120, 76, 255))
    d.polygon([(cx - 10, 14 + b), (cx - 16, 10 + b), (cx - 9, 19 + b)], fill=_col("rot_dark"))
    d.polygon([(cx + 9, 14 + b), (cx + 15, 10 + b), (cx + 8, 19 + b)], fill=_col("rot_dark"))
    d.line([cx, 8 + b, cx - 1, 1 + b], fill=_col("ink"), width=2)
    d.line([cx + 1, 8 + b, cx + 4, 2 + b], fill=_col("ink"), width=1)
    _glow_eyes(d, cx, 16 + b, _col("blood"), spread=4, size=3)
    d.rectangle([cx - 4, 21 + b, cx + 3, 22 + b], fill=_col("ink"))
    d.point((cx - 3, 21 + b), fill=_col("bone"))
    d.point((cx + 2, 21 + b), fill=_col("bone"))

    sy = b - step
    _arm(d, cx + 6, 27 + b, cx + 12, 31 + sy, "rot", "rot_dark")
    _arm(d, cx - 7, 27 + b, cx - 13, 31 + b + step, "rot", "rot_dark")


def draw_hantu_jerut(d, ox, b, step):
    """Lv10 grabber — giant python-form jin, double-fanged."""
    cx = ox + 24
    _shadow(d, cx, 43, w=16)
    # The coil rises from the ground into the raised head, so body and head
    # read as one creature. A flat body with a floating head does not.
    for i in range(30):
        t = i / 29.0
        x = cx - 16 + int(t * 26) + int(math.sin(t * math.pi * 2 + step * 0.5) * 3)
        y = 40 - int(t * t * 22) + b
        r = 7 - int(t * 2)
        d.ellipse([x - r, y - r // 2, x + r, y + r], fill=_col("swamp_mid"))
        d.ellipse([x - r + 1, y - r // 2, x + r - 3, y + r - 3], fill=_col("swamp"))

    hx, hy = cx + 10, 18 + b
    d.ellipse([hx - 8, hy - 6, hx + 8, hy + 8], fill=_col("swamp_mid"))
    d.ellipse([hx - 7, hy - 5, hx + 2, hy + 3], fill=_col("swamp"))
    _glow_eyes(d, hx, hy, _col("ember"), spread=4, size=2)
    d.polygon([(hx - 4, hy + 6), (hx - 3, hy + 12), (hx - 1, hy + 6)], fill=_col("bone"))
    d.polygon([(hx + 1, hy + 6), (hx + 3, hy + 12), (hx + 4, hy + 6)], fill=_col("bone"))
    d.polygon([(hx - 6, hy + 5), (hx - 5, hy + 9), (hx - 3, hy + 5)], fill=_col("shroud_dark"))
    d.polygon([(hx + 3, hy + 5), (hx + 5, hy + 9), (hx + 6, hy + 5)], fill=_col("shroud_dark"))


def draw_pelesit(d, ox, b, step):
    """Lv15 flying harasser — human-headed locust jin."""
    cx = ox + 24
    _shadow(d, cx, 43, w=8, alpha=55)
    wing = int(math.sin(step * 1.6 + b) * 3)
    for sgn in (-1, 1):
        d.polygon([(cx + sgn * 5, 20 + b), (cx + sgn * 21, 10 + b - wing),
                   (cx + sgn * 17, 26 + b + wing)], fill=(120, 126, 92, 210))
        d.polygon([(cx + sgn * 5, 20 + b), (cx + sgn * 16, 13 + b - wing),
                   (cx + sgn * 13, 23 + b + wing)], fill=(150, 156, 112, 170))

    d.ellipse([cx - 7, 22 + b, cx + 6, 40 + b], fill=_col("rot"))
    d.ellipse([cx - 6, 23 + b, cx + 1, 34 + b], fill=(114, 122, 78, 255))
    for yy in range(26, 39, 4):
        d.line([cx - 6, yy + b, cx + 5, yy + b], fill=_col("rot_dark"))

    # Hair BEHIND the head: drawn over the face it read as a fringe covering
    # the eyes, which killed the only expressive part of the sprite.
    d.ellipse([cx - 9, 6 + b, cx + 8, 20 + b], fill=_col("ink"))
    _hair_strands(d, cx, 14 + b, 9, _col("ink"), count=9, spread=10)
    d.ellipse([cx - 7, 8 + b, cx + 6, 22 + b], fill=_col("skin_mid"))
    d.ellipse([cx - 6, 9 + b, cx + 1, 18 + b], fill=_col("skin"))
    _glow_eyes(d, cx, 13 + b, _col("blood"), spread=3, size=2)
    d.rectangle([cx - 2, 19 + b, cx + 1, 20 + b], fill=_col("ink"))
    d.line([cx - 4, 8 + b, cx - 9, 1 + b], fill=_col("rot_dark"), width=1)
    d.line([cx + 3, 8 + b, cx + 8, 1 + b], fill=_col("rot_dark"), width=1)
    for sgn in (-1, 1):
        d.line([cx + sgn * 4, 38 + b, cx + sgn * 8, 44 + b], fill=_col("rot_dark"), width=1)


CLASSES = [
    ("pendekar", "Pendekar", draw_pendekar),
    ("perisik", "Perisik", draw_perisik),
    ("pawang", "Pawang", draw_pawang),
    ("pemanah", "Pemanah Rimba", draw_pemanah),
]

CREATURES = [
    ("penyamun", "Penyamun", draw_penyamun),
    ("jin_tanah", "Jin Tanah", draw_jin_tanah),
    ("toyol", "Toyol Belaan", draw_toyol),
    ("hantu_jerut", "Hantu Jerut", draw_hantu_jerut),
    ("pelesit", "Pelesit Bangkai", draw_pelesit),
]

ALL = CLASSES + CREATURES

# [idle x2, walk x4] — same frame order as the existing player sheets.
POSES = [(0, 0), (-1, 0), (0, 0), (-1, 2), (0, 0), (-1, -2)]


def _render(fn, bob, step):
    img = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    fn(ImageDraw.Draw(img), 0, bob, step)
    return img


def create_sheets():
    os.makedirs(OUT_SPRITES, exist_ok=True)
    for key, _label, fn in ALL:
        sheet = Image.new("RGBA", (FRAMES_PER_SHEET * FRAME, FRAME), (0, 0, 0, 0))
        for i, (bob, step) in enumerate(POSES):
            sheet.paste(_render(fn, bob, step), (i * FRAME, 0))
        sheet.save("%s/%s_sheet.png" % (OUT_SPRITES, key))
    print("Saved %d sheets" % len(ALL))


def _compose(items, bob, step, pad=4, extra_h=0):
    """ImageDraw REPLACES alpha rather than blending, so the semi-transparent
    shadow must be composited, not drawn straight onto an opaque background."""
    w = len(items) * (FRAME + pad) + pad
    h = FRAME + pad * 2 + extra_h
    bg = Image.new("RGBA", (w, h), (26, 24, 30, 255))
    layer = Image.new("RGBA", bg.size, (0, 0, 0, 0))
    for i, (_key, _label, fn) in enumerate(items):
        cell = _render(fn, bob, step)
        layer.paste(cell, (pad + i * (FRAME + pad), pad), cell)
    return Image.alpha_composite(bg, layer)


def create_lineup(items, name, scale=5):
    img = _compose(items, 0, 0, extra_h=10)
    big = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
    d = ImageDraw.Draw(big)
    for i, (_key, label, _fn) in enumerate(items):
        d.text(((4 + i * (FRAME + 4)) * scale, big.height - 16), label, fill=(210, 198, 176))
    path = "%s/_%s.png" % (OUT_SPRITES, name)
    big.save(path)
    print("Saved %s" % path)


def create_walk_gif(items, name, scale=5, ms=120):
    """Animated GIF — the only way to actually judge motion."""
    frames = []
    for bob, step in POSES[2:]:                    # frames 2-5 are the walk cycle
        img = _compose(items, bob, step)
        frames.append(img.resize((img.width * scale, img.height * scale),
                                 Image.NEAREST).convert("P"))
    path = "%s/_%s_walk.gif" % (OUT_SPRITES, name)
    frames[0].save(path, save_all=True, append_images=frames[1:],
                   duration=ms, loop=0, optimize=False)
    print("Saved %s (%d frames @ %dms)" % (path, len(frames), ms))


def create_spriteframes():
    os.makedirs(OUT_FRAMES, exist_ok=True)
    anims = [("idle", 3.0, [0, 1]), ("walk", 9.0, [2, 3, 4, 5])]
    for key, _label, _fn in ALL:
        subs = "".join(
            '[sub_resource type="AtlasTexture" id="f%d"]\n'
            'atlas = ExtResource("1_sheet")\n'
            'region = Rect2(%d, 0, %d, %d)\n\n' % (i, i * FRAME, FRAME, FRAME)
            for i in range(FRAMES_PER_SHEET))
        blocks = ", ".join(
            '{\n"frames": [%s],\n"loop": true,\n"name": &"%s",\n"speed": %s\n}' % (
                ", ".join('{"duration": 1.0, "texture": SubResource("f%d")}' % i for i in idxs),
                nm, sp)
            for nm, sp, idxs in anims)
        uid = key.replace("_", "")[:7]
        body = (
            '[gd_resource type="SpriteFrames" load_steps=%d format=3 uid="uid://ctm%s1"]\n\n'
            '; Generated by tools/generate_tm_sprites.py\n\n'
            '[ext_resource type="Texture2D" path="res://%s/%s_sheet.png" id="1_sheet"]\n\n'
            '%s[resource]\nanimations = [%s]\n'
            % (FRAMES_PER_SHEET + 2, uid, OUT_SPRITES, key, subs, blocks))
        with open("%s/%s.tres" % (OUT_FRAMES, key), "w", encoding="utf-8") as fh:
            fh.write(body)
    print("Saved %d SpriteFrames resources" % len(ALL))


if __name__ == "__main__":
    create_sheets()
    create_spriteframes()
    create_lineup(CLASSES, "classes")
    create_lineup(CREATURES, "creatures")
    create_walk_gif(CLASSES, "classes")
    create_walk_gif(CREATURES, "creatures")
    print("Tanah Melayu sprites generated at %dx%d." % (FRAME, FRAME))
