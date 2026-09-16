"""
Tanah Melayu (Zaman Melaka) sprites — playable classes, bestiary, bosses.

Pure drawing code. Palette, helpers and render infrastructure live in tm_art.py.

Commons and classes are 48x48; bosses are 64x64 so they read as bosses by size
before any detail lands. Frame layout is [idle x2, walk x4] throughout, matching
the existing pipeline, so every sheet drops into AnimatedSprite2D unchanged.

Run:  python tools/generate_tm_sprites.py
"""
import math
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from tm_art import (  # noqa: E402
    FRAME, BOSS_FRAME, col, shaded_box, ragged_hem, eyes, glow_eyes, shadow,
    hair_strands, legs, head, arm, scar,
    write_sheets, write_lineup, write_walk_gif, write_spriteframes,
)


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
    shadow(d, cx, 41)
    legs(d, cx, b, step, "mud", "mud_mid", "mud_dark")

    shaded_box(d, cx - 9, 19 + b, cx + 8, 32 + b, "blood", "blood_mid", "blood_dark")
    shaded_box(d, cx - 9, 28 + b, cx + 8, 32 + b, "mud", "mud_mid", "mud_dark")
    d.rectangle([cx - 7, 29 + b, cx + 6, 29 + b], fill=col("brass_dark"))

    head(d, cx, b)
    # tengkolok: wrapped band and the folded peak that defines the silhouette
    shaded_box(d, cx - 8, 6 + b, cx + 7, 12 + b, "mud", "mud_mid", "mud_dark")
    d.rectangle([cx - 8, 10 + b, cx + 7, 11 + b], fill=col("brass_dark"))
    d.polygon([(cx + 6, 5 + b), (cx + 13, 1 + b), (cx + 9, 10 + b)], fill=col("mud_mid"))
    d.polygon([(cx + 6, 5 + b), (cx + 11, 3 + b), (cx + 8, 8 + b)], fill=col("mud"))
    eyes(d, cx, 16 + b)
    d.rectangle([cx - 3, 20 + b, cx + 2, 20 + b], fill=col("skin_dark"))

    sy = b - step
    arm(d, cx + 7, 22 + b, cx + 13, 27 + sy, "blood", "blood_dark")
    d.rectangle([cx + 13, 10 + sy, cx + 15, 28 + sy], fill=col("silver"))
    d.rectangle([cx + 15, 10 + sy, cx + 15, 28 + sy], fill=col("silver_dark"))
    d.rectangle([cx + 11, 28 + sy, cx + 17, 30 + sy], fill=col("brass"))
    d.rectangle([cx + 13, 30 + sy, cx + 15, 34 + sy], fill=col("mud_dark"))

    hy = b + step
    d.ellipse([cx - 20, 18 + hy, cx - 7, 34 + hy], fill=col("mud_dark"))
    d.ellipse([cx - 19, 19 + hy, cx - 8, 33 + hy], fill=col("mud_mid"))
    d.ellipse([cx - 18, 20 + hy, cx - 11, 29 + hy], fill=col("mud"))
    d.ellipse([cx - 16, 24 + hy, cx - 11, 29 + hy], fill=col("brass"))
    d.ellipse([cx - 15, 25 + hy, cx - 13, 27 + hy], fill=col("brass_dark"))
    arm(d, cx - 8, 22 + b, cx - 12, 25 + hy, "blood", "blood_dark")


def draw_perisik(d, ox, b, step):
    cx = ox + 24
    c = 3                                   # crouched: the whole figure sits lower
    shadow(d, cx, 41, w=12)
    legs(d, cx, b, step, "cloth", "cloth_mid", "cloth_dark", top=31 + c)

    shaded_box(d, cx - 8, 21 + b + c, cx + 7, 33 + b, "cloth", "cloth_mid", "cloth_dark")
    d.rectangle([cx - 8, 28 + b, cx + 7, 30 + b], fill=col("swamp_dark"))

    shaded_box(d, cx - 7, 12 + b + c, cx + 6, 23 + b + c, "cloth_mid", "cloth_dark", "ink")
    d.rectangle([cx - 7, 17 + b + c, cx + 6, 19 + b + c], fill=col("skin_dark"))
    glow_eyes(d, cx, 18 + b + c, col("lamp"), spread=4)
    d.line([cx - 7, 15 + b + c, cx - 14, 22 + b + c], fill=col("cloth_dark"), width=2)
    ragged_hem(d, cx - 15, cx - 12, 22 + b + c, col("cloth_dark"), depth=3)

    sy = b - step + c
    arm(d, cx + 7, 25 + b + c, cx + 12, 29 + sy, "cloth_mid", "cloth_dark")
    d.arc([cx + 10, 26 + sy, cx + 20, 36 + sy], 250, 30, fill=col("ink"), width=3)
    d.arc([cx + 10, 26 + sy, cx + 19, 35 + sy], 250, 30, fill=col("bone"), width=1)
    hy = b + step + c
    arm(d, cx - 8, 25 + b + c, cx - 13, 29 + hy, "cloth_mid", "cloth_dark")
    d.arc([cx - 20, 26 + hy, cx - 10, 36 + hy], 150, 290, fill=col("ink"), width=3)
    d.arc([cx - 19, 26 + hy, cx - 10, 35 + hy], 150, 290, fill=col("bone"), width=1)


def draw_pawang(d, ox, b, step):
    cx = ox + 24
    shadow(d, cx, 41, w=15)
    d.polygon([(cx - 8, 19 + b), (cx + 7, 19 + b), (cx + 12, 41), (cx - 13, 41)],
              fill=col("swamp_mid"))
    d.polygon([(cx - 8, 19 + b), (cx - 1, 19 + b), (cx - 4, 41), (cx - 13, 41)],
              fill=col("swamp_dark"))
    d.polygon([(cx + 3, 19 + b), (cx + 7, 19 + b), (cx + 12, 41), (cx + 7, 41)],
              fill=col("ink"))
    ragged_hem(d, cx - 13, cx + 12, 41, col("swamp_dark"), depth=4, seed=3)

    head(d, cx, b)
    shaded_box(d, cx - 8, 7 + b, cx + 7, 13 + b, "shroud_mid", "shroud_dark", "mud_dark")
    d.rectangle([cx - 10, 12 + b, cx - 6, 26 + b], fill=col("mud_dark"))
    d.rectangle([cx + 6, 12 + b, cx + 10, 26 + b], fill=col("mud_dark"))
    hair_strands(d, cx, 24 + b, 5, col("ink"), count=5, spread=9)
    glow_eyes(d, cx, 16 + b, col("lamp"), spread=3)
    d.line([cx - 4, 22 + b, cx + 3, 22 + b], fill=col("brass"), width=1)

    # tongkat kayu nibong: taller than the figure. Planted, so it does NOT bob.
    arm(d, cx + 7, 23 + b, cx + 13, 21 + b, "swamp_mid", "swamp_dark")
    d.rectangle([cx + 13, 2, cx + 15, 41], fill=col("mud_mid"))
    d.rectangle([cx + 15, 2, cx + 15, 41], fill=col("mud_dark"))
    d.ellipse([cx + 10, -2, cx + 18, 6], fill=col("mud_dark"))
    d.ellipse([cx + 11, -1, cx + 17, 5], fill=col("blood"))
    d.ellipse([cx + 13, 1, cx + 15, 3], fill=col("ember"))

    hy = b + step
    arm(d, cx - 8, 23 + b, cx - 14, 26 + hy, "swamp_mid", "swamp_dark")
    d.rectangle([cx - 18, 26 + hy, cx - 11, 30 + hy], fill=col("brass_dark"))
    d.rectangle([cx - 17, 25 + hy, cx - 12, 26 + hy], fill=col("ember"))
    for sx, sy2, a in ((0, 4, 150), (-1, 8, 110), (1, 12, 60)):
        d.point((cx - 14 + sx, 22 - sy2 + hy), fill=(170, 170, 170, a))


def draw_pemanah(d, ox, b, step):
    cx = ox + 24
    shadow(d, cx, 41, w=13)
    legs(d, cx, b, step, "swamp_mid", "swamp_dark", "ink")

    shaded_box(d, cx - 8, 19 + b, cx + 7, 31 + b, "swamp", "swamp_mid", "swamp_dark")
    d.rectangle([cx - 8, 27 + b, cx + 7, 29 + b], fill=col("mud_mid"))

    head(d, cx, b)
    d.rectangle([cx - 7, 10 + b, cx + 6, 13 + b], fill=col("mud_dark"))
    shaded_box(d, cx - 6, 6 + b, cx + 5, 11 + b, "mud_mid", "mud_dark", "ink")
    d.line([cx + 6, 12 + b, cx + 12, 17 + b], fill=col("mud_dark"), width=2)
    eyes(d, cx, 16 + b)

    shaded_box(d, cx + 8, 16 + b, cx + 12, 29 + b, "mud", "mud_mid", "mud_dark")
    for i, fx in enumerate((9, 11)):
        d.line([cx + fx, 9 + b + i * 2, cx + fx, 16 + b], fill=col("bone"))
        d.line([cx + fx, 9 + b + i * 2, cx + fx + 1, 11 + b + i * 2], fill=col("shroud_dark"))

    hy = b + step
    d.arc([cx - 22, 8 + hy, cx - 6, 38 + hy], 60, 300, fill=col("mud_dark"), width=3)
    d.arc([cx - 21, 9 + hy, cx - 7, 37 + hy], 60, 300, fill=col("mud"), width=1)
    d.line([cx - 14, 9 + hy, cx - 14, 37 + hy], fill=col("bone"))
    arm(d, cx - 8, 22 + b, cx - 14, 22 + hy, "swamp", "swamp_dark")
    arm(d, cx + 7, 22 + b, cx + 6, 25 + b - step, "swamp", "swamp_dark")


# ===========================================================================
# BESTIARY — MANUSIA TRACK
# ===========================================================================

def draw_penyamun(d, ox, b, step):
    """Lv1 grunt — road bandit, rusted parang, wild telegraphed swings."""
    cx = ox + 24
    shadow(d, cx, 41)
    legs(d, cx, b, step, "mud_mid", "mud_dark", "ink")
    shaded_box(d, cx - 8, 20 + b, cx + 7, 32 + b, "mud", "mud_mid", "mud_dark")
    ragged_hem(d, cx - 8, cx + 7, 32 + b, col("mud_dark"), depth=3, seed=5)
    d.rectangle([cx - 8, 28 + b, cx + 7, 30 + b], fill=col("blood_dark"))

    head(d, cx, b)
    d.rectangle([cx - 7, 9 + b, cx + 6, 12 + b], fill=col("blood_mid"))
    d.rectangle([cx - 6, 18 + b, cx + 5, 21 + b], fill=col("shroud_dark"))
    eyes(d, cx, 14 + b)

    sy = b - step
    arm(d, cx + 7, 23 + b, cx + 12, 27 + sy, "mud", "mud_dark")
    d.polygon([(cx + 12, 26 + sy), (cx + 20, 12 + sy), (cx + 22, 15 + sy),
               (cx + 15, 28 + sy)], fill=col("silver_dark"))
    d.polygon([(cx + 13, 25 + sy), (cx + 19, 14 + sy), (cx + 20, 16 + sy),
               (cx + 15, 26 + sy)], fill=col("rust"))
    d.rectangle([cx + 11, 26 + sy, cx + 15, 29 + sy], fill=col("mud_dark"))
    arm(d, cx - 8, 23 + b, cx - 12, 28 + b + step, "mud", "mud_dark")


def draw_pencuri(d, ox, b, step):
    """Lv5 skirmisher — wharf pickpocket. Small, light, hit-and-run."""
    cx = ox + 24
    c = 2
    shadow(d, cx, 42, w=10)
    legs(d, cx, b, step, "cloth_mid", "cloth_dark", "ink", top=32 + c, w=4, gap=6)
    shaded_box(d, cx - 6, 23 + b + c, cx + 5, 33 + b, "mud_mid", "mud_dark", "ink")
    ragged_hem(d, cx - 6, cx + 5, 33 + b, col("ink"), depth=3, seed=8)

    # satchel: the tell that this one steals rather than fights
    d.rectangle([cx - 12, 26 + b + c, cx - 6, 32 + b + c], fill=col("mud"))
    d.rectangle([cx - 12, 26 + b + c, cx - 6, 27 + b + c], fill=col("mud_dark"))
    d.line([cx - 9, 24 + b + c, cx + 2, 20 + b + c], fill=col("mud_dark"), width=1)

    head(d, cx, b + c, top=13, h=9, w=5)
    d.rectangle([cx - 6, 12 + b + c, cx + 5, 15 + b + c], fill=col("cloth_dark"))
    d.polygon([(cx + 5, 13 + b + c), (cx + 10, 11 + b + c), (cx + 5, 17 + b + c)],
              fill=col("cloth_dark"))
    eyes(d, cx, 18 + b + c, spread=2)

    sy = b - step + c
    arm(d, cx + 5, 26 + b + c, cx + 10, 29 + sy, "mud_mid", "mud_dark")
    # short badik
    d.polygon([(cx + 10, 28 + sy), (cx + 16, 22 + sy), (cx + 17, 24 + sy),
               (cx + 12, 30 + sy)], fill=col("silver"))
    d.rectangle([cx + 9, 28 + sy, cx + 12, 30 + sy], fill=col("mud_dark"))
    arm(d, cx - 6, 26 + b + c, cx - 10, 30 + b + step + c, "mud_mid", "mud_dark")


def draw_pemungut(d, ox, b, step):
    """Lv10 heavy bruiser — tribute collector. Mass first: widest common."""
    cx = ox + 24
    shadow(d, cx, 41, w=17)
    legs(d, cx, b, step, "mud", "mud_mid", "mud_dark", top=31, w=7, gap=9)
    # thick torso, deliberately wider than any other common
    shaded_box(d, cx - 13, 17 + b, cx + 12, 33 + b, "mud_mid", "mud_dark", "ink")
    d.rectangle([cx - 13, 27 + b, cx + 12, 30 + b], fill=col("blood_dark"))
    d.rectangle([cx - 13, 17 + b, cx + 12, 19 + b], fill=col("mud"))

    head(d, cx, b, top=8, h=10)
    d.rectangle([cx - 6, 7 + b, cx + 5, 9 + b], fill=col("cloth_dark"))
    eyes(d, cx, 13 + b, spread=3)
    d.rectangle([cx - 4, 17 + b, cx + 3, 18 + b], fill=col("skin_dark"))
    scar(d, cx + 2, 10 + b, cx + 5, 16 + b)

    # nail-studded club, raised — the unblockable overhead is its whole threat
    sy = b - step
    arm(d, cx + 12, 20 + b, cx + 17, 22 + sy, "mud_mid", "mud_dark", width=4)
    shaded_box(d, cx + 15, 2 + sy, cx + 21, 24 + sy, "mud", "mud_mid", "mud_dark")
    for yy in range(5, 22, 4):
        d.rectangle([cx + 14, yy + sy, cx + 15, yy + 1 + sy], fill=col("silver"))
        d.rectangle([cx + 21, yy + 2 + sy, cx + 22, yy + 3 + sy], fill=col("silver"))
    arm(d, cx - 13, 20 + b, cx - 17, 26 + b + step, "mud_mid", "mud_dark", width=4)


def draw_pelontar(d, ox, b, step):
    """Lv15 area denial — firebomb thrower. The flame is the read."""
    cx = ox + 24
    shadow(d, cx, 41, w=12)
    legs(d, cx, b, step, "mud_mid", "mud_dark", "ink")
    shaded_box(d, cx - 8, 20 + b, cx + 7, 32 + b, "swamp_dark", "ink", "ink")
    ragged_hem(d, cx - 8, cx + 7, 32 + b, col("ink"), depth=3, seed=2)

    # bandolier of clay bottles across the chest
    d.line([cx - 8, 22 + b, cx + 7, 28 + b], fill=col("mud_dark"), width=2)
    for i, (bx, by) in enumerate(((-5, 24), (-1, 26), (3, 27))):
        d.rectangle([cx + bx, by + b, cx + bx + 2, by + 3 + b], fill=col("mud"))

    head(d, cx, b)
    d.rectangle([cx - 7, 9 + b, cx + 6, 12 + b], fill=col("mud_dark"))
    d.rectangle([cx - 6, 18 + b, cx + 5, 20 + b], fill=col("shroud_dark"))
    eyes(d, cx, 14 + b)

    # raised bottle with a lit wick
    sy = b - step
    arm(d, cx + 7, 22 + b, cx + 13, 14 + sy, "swamp_dark", "ink")
    d.ellipse([cx + 11, 8 + sy, cx + 18, 16 + sy], fill=col("mud"))
    d.ellipse([cx + 12, 9 + sy, cx + 16, 14 + sy], fill=col("mud_mid"))
    d.rectangle([cx + 13, 5 + sy, cx + 15, 9 + sy], fill=col("mud_dark"))
    d.ellipse([cx + 12, 0 + sy, cx + 16, 6 + sy], fill=col("ember"))
    d.ellipse([cx + 13, 1 + sy, cx + 15, 4 + sy], fill=col("flame"))
    arm(d, cx - 8, 22 + b, cx - 12, 27 + b + step, "swamp_dark", "ink")


def draw_kepala_begal(d, ox, b, step):
    """Lv19 elite duelist — twin silver goloks, counter-parries the player."""
    cx = ox + 24
    shadow(d, cx, 41, w=14)
    legs(d, cx, b, step, "cloth", "cloth_mid", "cloth_dark")
    # better cloth than the grunts: this one has done well out of the estuary
    shaded_box(d, cx - 9, 19 + b, cx + 8, 32 + b, "blood_mid", "blood_dark", "ink")
    shaded_box(d, cx - 9, 28 + b, cx + 8, 32 + b, "cloth_mid", "cloth_dark", "ink")
    d.rectangle([cx - 7, 29 + b, cx + 6, 29 + b], fill=col("brass"))

    head(d, cx, b)
    d.rectangle([cx - 8, 7 + b, cx + 7, 11 + b], fill=col("cloth_dark"))
    d.polygon([(cx + 7, 7 + b), (cx + 12, 4 + b), (cx + 8, 11 + b)], fill=col("cloth_mid"))
    eyes(d, cx, 15 + b)
    scar(d, cx - 5, 12 + b, cx - 2, 19 + b)
    d.rectangle([cx - 3, 19 + b, cx + 2, 19 + b], fill=col("skin_dark"))

    # two blades held wide — the silhouette says duelist at a glance
    sy = b - step
    arm(d, cx + 8, 22 + b, cx + 14, 25 + sy, "blood_dark", "ink")
    d.polygon([(cx + 14, 24 + sy), (cx + 22, 10 + sy), (cx + 24, 13 + sy),
               (cx + 17, 26 + sy)], fill=col("silver"))
    d.rectangle([cx + 13, 24 + sy, cx + 17, 27 + sy], fill=col("brass_dark"))
    hy = b + step
    arm(d, cx - 9, 22 + b, cx - 15, 25 + hy, "blood_dark", "ink")
    d.polygon([(cx - 15, 24 + hy), (cx - 23, 10 + hy), (cx - 25, 13 + hy),
               (cx - 18, 26 + hy)], fill=col("silver"))
    d.rectangle([cx - 18, 24 + hy, cx - 14, 27 + hy], fill=col("brass_dark"))


# ===========================================================================
# BESTIARY — JIN TRACK
# ===========================================================================

def draw_jin_tanah(d, ox, b, step):
    """Lv1 ranged nuisance — clay figure bound in rotted shroud cloth."""
    cx = ox + 24
    shadow(d, cx, 42, w=11)
    # bound shroud, no legs: it hops rather than walks
    d.polygon([(cx - 9, 14 + b), (cx + 8, 14 + b), (cx + 11, 41 + b), (cx - 12, 41 + b)],
              fill=col("shroud_mid"))
    d.polygon([(cx - 9, 14 + b), (cx - 2, 14 + b), (cx - 5, 41 + b), (cx - 12, 41 + b)],
              fill=col("shroud"))
    d.polygon([(cx + 4, 14 + b), (cx + 8, 14 + b), (cx + 11, 41 + b), (cx + 6, 41 + b)],
              fill=col("shroud_dark"))
    d.rectangle([cx - 10, 24 + b, cx + 9, 26 + b], fill=col("mud_mid"))
    d.rectangle([cx - 9, 14 + b, cx + 8, 16 + b], fill=col("mud_mid"))
    ragged_hem(d, cx - 12, cx + 11, 41 + b, col("shroud_dark"), depth=4, seed=1)

    d.ellipse([cx - 8, 4 + b, cx + 7, 18 + b], fill=col("shroud_mid"))
    d.ellipse([cx - 7, 5 + b, cx + 3, 15 + b], fill=col("shroud"))
    d.polygon([(cx - 3, 4 + b), (cx, -2 + b), (cx + 3, 4 + b)], fill=col("shroud_dark"))
    d.ellipse([cx - 5, 8 + b, cx + 4, 15 + b], fill=col("ink"))
    glow_eyes(d, cx, 11 + b, col("ember"), spread=3, size=2)


def draw_toyol(d, ox, b, step):
    """Lv5 fast melee crippler — green slimy dwarf, red eyes."""
    cx = ox + 24
    shadow(d, cx, 43, w=10)
    legs(d, cx, b, step, "rot", "rot_dark", "ink", top=34, bottom=42)
    shaded_box(d, cx - 7, 24 + b, cx + 6, 35 + b, "rot", "rot_dark", "ink")
    d.rectangle([cx - 7, 31 + b, cx + 6, 34 + b], fill=col("mud_dark"))

    d.ellipse([cx - 10, 8 + b, cx + 9, 26 + b], fill=col("rot"))
    d.ellipse([cx - 9, 9 + b, cx + 3, 21 + b], fill=(112, 120, 76, 255))
    d.polygon([(cx - 10, 14 + b), (cx - 16, 10 + b), (cx - 9, 19 + b)], fill=col("rot_dark"))
    d.polygon([(cx + 9, 14 + b), (cx + 15, 10 + b), (cx + 8, 19 + b)], fill=col("rot_dark"))
    d.line([cx, 8 + b, cx - 1, 1 + b], fill=col("ink"), width=2)
    d.line([cx + 1, 8 + b, cx + 4, 2 + b], fill=col("ink"), width=1)
    glow_eyes(d, cx, 16 + b, col("blood"), spread=4, size=3)
    d.rectangle([cx - 4, 21 + b, cx + 3, 22 + b], fill=col("ink"))
    d.point((cx - 3, 21 + b), fill=col("bone"))
    d.point((cx + 2, 21 + b), fill=col("bone"))

    sy = b - step
    # thicker arms: thin sticks read as broken against a bulky body
    arm(d, cx + 6, 27 + b, cx + 12, 31 + sy, "rot", "rot_dark", width=4)
    arm(d, cx - 7, 27 + b, cx - 13, 31 + b + step, "rot", "rot_dark", width=4)


def draw_hantu_jerut(d, ox, b, step):
    """Lv10 grabber — giant python-form jin, double-fanged."""
    cx = ox + 24
    shadow(d, cx, 43, w=16)
    # The coil rises from the ground into the raised head, so body and head read
    # as one creature. A flat body with a floating head does not.
    for i in range(30):
        t = i / 29.0
        x = cx - 16 + int(t * 26) + int(math.sin(t * math.pi * 2 + step * 0.5) * 3)
        y = 40 - int(t * t * 22) + b
        r = 7 - int(t * 2)
        d.ellipse([x - r, y - r // 2, x + r, y + r], fill=col("swamp_mid"))
        d.ellipse([x - r + 1, y - r // 2, x + r - 3, y + r - 3], fill=col("swamp"))

    hx, hy = cx + 10, 18 + b
    d.ellipse([hx - 8, hy - 6, hx + 8, hy + 8], fill=col("swamp_mid"))
    d.ellipse([hx - 7, hy - 5, hx + 2, hy + 3], fill=col("swamp"))
    glow_eyes(d, hx, hy, col("ember"), spread=4, size=2)
    d.polygon([(hx - 4, hy + 6), (hx - 3, hy + 12), (hx - 1, hy + 6)], fill=col("bone"))
    d.polygon([(hx + 1, hy + 6), (hx + 3, hy + 12), (hx + 4, hy + 6)], fill=col("bone"))


def draw_pelesit(d, ox, b, step):
    """Lv15 flying harasser — human-headed locust jin."""
    cx = ox + 24
    shadow(d, cx, 43, w=8, alpha=55)
    wing = int(math.sin(step * 1.6 + b) * 3)
    for sgn in (-1, 1):
        d.polygon([(cx + sgn * 5, 20 + b), (cx + sgn * 21, 10 + b - wing),
                   (cx + sgn * 17, 26 + b + wing)], fill=(120, 126, 92, 210))
        d.polygon([(cx + sgn * 5, 20 + b), (cx + sgn * 16, 13 + b - wing),
                   (cx + sgn * 13, 23 + b + wing)], fill=(150, 156, 112, 170))

    d.ellipse([cx - 7, 22 + b, cx + 6, 40 + b], fill=col("rot"))
    d.ellipse([cx - 6, 23 + b, cx + 1, 34 + b], fill=(114, 122, 78, 255))
    for yy in range(26, 39, 4):
        d.line([cx - 6, yy + b, cx + 5, yy + b], fill=col("rot_dark"))

    # Hair BEHIND the head: over the face it read as a fringe covering the eyes,
    # which killed the only expressive part of the sprite.
    d.ellipse([cx - 9, 6 + b, cx + 8, 20 + b], fill=col("ink"))
    hair_strands(d, cx, 14 + b, 9, col("ink"), count=9, spread=10)
    d.ellipse([cx - 7, 8 + b, cx + 6, 22 + b], fill=col("skin_mid"))
    d.ellipse([cx - 6, 9 + b, cx + 1, 18 + b], fill=col("skin"))
    glow_eyes(d, cx, 13 + b, col("blood"), spread=3, size=2)
    d.rectangle([cx - 2, 19 + b, cx + 1, 20 + b], fill=col("ink"))
    d.line([cx - 4, 8 + b, cx - 9, 1 + b], fill=col("rot_dark"), width=1)
    d.line([cx + 3, 8 + b, cx + 8, 1 + b], fill=col("rot_dark"), width=1)
    for sgn in (-1, 1):
        d.line([cx + sgn * 4, 38 + b, cx + sgn * 8, 44 + b], fill=col("rot_dark"), width=1)


def draw_jin_belian(d, ox, b, step):
    """Lv19 heavy charger — wild jin in a great iron-bristled boar.

    Quadruped and low, mass carried forward over the shoulders so the
    silhouette reads as a charge before it has moved.
    """
    # Trimmed to span cx-14 to cx+28 (43px) so it clears the 48px frame edges
    # with room either side; flush-to-edge looked cramped in a lineup.
    cx = ox + 17
    shadow(d, cx + 4, 42, w=18)

    # four legs, front pair driving
    for lx, off, h in ((cx - 11, step, 9), (cx - 6, -step, 8),
                       (cx + 9, -step, 9), (cx + 14, step, 8)):
        shaded_box(d, lx, 41 - h + b + off, lx + 3, 41, "rot_dark", "ink", "ink")

    # barrel body, heaviest at the shoulder
    d.ellipse([cx - 14, 20 + b, cx + 11, 38 + b], fill=col("rot_dark"))
    d.ellipse([cx - 12, 21 + b, cx + 2, 32 + b], fill=col("rot"))
    d.ellipse([cx + 2, 18 + b, cx + 16, 36 + b], fill=col("rot_dark"))
    d.ellipse([cx + 4, 19 + b, cx + 13, 29 + b], fill=col("rot"))

    # iron bristles: a dense ridge sitting ON the back, not floating above it
    for i in range(13):
        bx = cx - 12 + i * 2
        top = 20 + b - (5 + (i % 3) * 2)
        d.line([bx, 21 + b, bx - 1, top], fill=col("silver_dark"), width=1)
        d.point((bx - 1, top), fill=col("silver"))

    # head low and forward, with a real snout
    d.ellipse([cx + 12, 26 + b, cx + 26, 38 + b], fill=col("rot_dark"))
    d.ellipse([cx + 13, 27 + b, cx + 21, 34 + b], fill=col("rot"))
    d.ellipse([cx + 22, 31 + b, cx + 28, 37 + b], fill=col("mud_dark"))
    d.point((cx + 24, 33 + b), fill=col("ink"))
    d.point((cx + 26, 34 + b), fill=col("ink"))
    glow_eyes(d, cx + 17, 29 + b, col("ember"), spread=3, size=2)
    d.polygon([(cx + 13, 26 + b), (cx + 16, 18 + b), (cx + 20, 26 + b)], fill=col("rot_dark"))

    # tusks curving up out of the jaw — the threat read
    d.polygon([(cx + 21, 37 + b), (cx + 27, 28 + b), (cx + 28, 30 + b),
               (cx + 24, 38 + b)], fill=col("bone"))
    d.polygon([(cx + 21, 38 + b), (cx + 26, 30 + b), (cx + 27, 31 + b),
               (cx + 23, 38 + b)], fill=col("shroud_dark"))


# ===========================================================================
# BOSSES (64x64)
# ===========================================================================

def draw_tok_begal(d, ox, b, step):
    """Lv20 human boss — Tok Begal Belah Retak, Straits crime lord.

    Bare scarred torso tapering from heavy shoulders, and an oversized parang
    lading. A straight box read as a brown rectangle with a face, so the
    silhouette is built from a taper plus shoulder caps instead.
    """
    cx = ox + 32
    shadow(d, cx, 55, w=22)
    legs(d, cx, b, step, "mud", "mud_mid", "mud_dark", top=42, bottom=55, w=8, gap=11)
    d.rectangle([cx - 14, 42 + b, cx + 13, 47 + b], fill=col("mud_dark"))
    d.rectangle([cx - 14, 44 + b, cx + 13, 45 + b], fill=col("brass_dark"))

    d.polygon([(cx - 16, 24 + b), (cx + 15, 24 + b), (cx + 11, 43 + b), (cx - 12, 43 + b)],
              fill=col("skin_dark"))
    d.polygon([(cx - 16, 24 + b), (cx - 2, 24 + b), (cx - 1, 43 + b), (cx - 12, 43 + b)],
              fill=col("skin_mid"))
    d.ellipse([cx - 19, 23 + b, cx - 8, 33 + b], fill=col("skin_mid"))
    d.ellipse([cx + 8, 23 + b, cx + 19, 33 + b], fill=col("skin_dark"))
    for y0, x0, x1 in ((29, -11, -3), (34, 2, 11), (38, -8, 4), (27, 4, 12), (32, -13, -6)):
        scar(d, cx + x0, y0 + b, cx + x1, y0 + 3 + b)

    # a neck, so head and torso are not one block
    d.rectangle([cx - 4, 20 + b, cx + 3, 25 + b], fill=col("skin_dark"))
    head(d, cx, b, top=8, h=12, w=8)
    hair_strands(d, cx, 8 + b, 4, col("ink"), count=9, spread=8)
    d.rectangle([cx - 8, 6 + b, cx + 7, 9 + b], fill=col("blood_dark"))
    glow_eyes(d, cx, 14 + b, col("blood"), spread=4, size=2)
    scar(d, cx - 7, 11 + b, cx - 3, 19 + b)
    d.rectangle([cx - 5, 18 + b, cx + 4, 20 + b], fill=col("ink"))
    for tx in range(cx - 4, cx + 4, 3):
        d.point((tx, 18 + b), fill=col("bone"))

    # oversized parang lading, dark-backed so it does not wash out
    sy = b - step
    arm(d, cx + 15, 27 + b, cx + 21, 33 + sy, "skin_mid", "skin_dark", width=5)
    d.polygon([(cx + 18, 34 + sy), (cx + 30, 4 + sy), (cx + 38, 11 + sy),
               (cx + 27, 38 + sy)], fill=col("ink"))
    d.polygon([(cx + 20, 33 + sy), (cx + 30, 7 + sy), (cx + 35, 12 + sy),
               (cx + 26, 36 + sy)], fill=col("silver_dark"))
    d.polygon([(cx + 22, 32 + sy), (cx + 30, 11 + sy), (cx + 32, 14 + sy),
               (cx + 25, 33 + sy)], fill=col("rust"))
    d.rectangle([cx + 17, 32 + sy, cx + 25, 38 + sy], fill=col("mud_dark"))

    # kerambit hidden at the left wrist — the Phase 2 reveal
    hy = b + step
    arm(d, cx - 16, 27 + b, cx - 22, 35 + hy, "skin_mid", "skin_dark", width=5)
    d.arc([cx - 30, 31 + hy, cx - 18, 43 + hy], 150, 290, fill=col("ink"), width=4)
    d.arc([cx - 29, 31 + hy, cx - 19, 42 + hy], 150, 290, fill=col("bone"), width=2)


def draw_saka_askar(d, ox, b, step):
    """Lv20 jin boss — Saka Askar Perang Lama, a masterless war-saka.

    Too tall and leaning forward. The whole upper body is offset ahead of the
    feet: upright at this height it just reads as a tall man.
    """
    cx = ox + 30
    lean = 5
    shadow(d, cx, 55, w=20, alpha=110)

    # long thin legs trailing BEHIND the lean
    for sgn, off in ((-1, step), (1, -step)):
        lx = cx + sgn * 6 - lean // 2
        d.line([lx, 38 + b, lx + sgn * 3, 55 + off], fill=col("ink"), width=5)
        d.line([lx + sgn * 3, 55 + off, lx + sgn * 6, 55 + off], fill=col("ink"), width=3)

    d.polygon([(cx - 10 + lean, 18 + b), (cx + 11 + lean, 16 + b),
               (cx + 12, 40 + b), (cx - 11, 40 + b)], fill=col("cloth_mid"))
    d.polygon([(cx - 10 + lean, 18 + b), (cx - 2 + lean, 17 + b),
               (cx - 2, 40 + b), (cx - 11, 40 + b)], fill=col("cloth_dark"))
    for yy in range(21, 39, 3):
        for xx in range(cx - 9, cx + 11, 4):
            d.point((xx + (yy // 3 % 2) * 2 + lean // 2, yy + b), fill=col("silver_dark"))
    ragged_hem(d, cx - 11, cx + 12, 40 + b, col("cloth_dark"), depth=7, seed=4)

    # head thrust forward and sunk between the shoulders
    hx = cx + lean + 2
    d.ellipse([hx - 9, 5 + b, hx + 8, 21 + b], fill=col("skin_dark"))
    d.ellipse([hx - 8, 6 + b, hx + 1, 17 + b], fill=col("skin_mid"))
    shaded_box(d, hx - 10, 2 + b, hx + 9, 9 + b, "blood_dark", "ink", "ink")
    d.polygon([(hx + 7, 2 + b), (hx + 16, -3 + b), (hx + 10, 10 + b)], fill=col("blood_dark"))
    for sx in (-6, -2, 3, 7):
        d.line([hx + sx, 9 + b, hx + sx, 13 + b + (sx % 3)], fill=col("blood_dark"))
    glow_eyes(d, hx, 13 + b, col("ember"), spread=4, size=2)

    # broken pedang jenawi, weeping black
    sy = b - step
    arm(d, cx + 11 + lean, 23 + b, cx + 20, 31 + sy, "cloth_mid", "cloth_dark", width=5)
    d.polygon([(cx + 19, 31 + sy), (cx + 25, 7 + sy), (cx + 30, 9 + sy),
               (cx + 26, 34 + sy)], fill=col("ink"))
    d.polygon([(cx + 21, 30 + sy), (cx + 25, 10 + sy), (cx + 28, 11 + sy),
               (cx + 25, 32 + sy)], fill=col("silver_dark"))
    d.polygon([(cx + 24, 9 + sy), (cx + 30, 8 + sy), (cx + 26, 17 + sy)], fill=col("ink"))
    d.rectangle([cx + 18, 30 + sy, cx + 25, 35 + sy], fill=col("mud_dark"))
    for dx, dy in ((22, 37), (24, 42), (21, 47)):
        d.rectangle([cx + dx, dy + sy, cx + dx + 2, dy + 4 + sy], fill=col("miasma"))

    arm(d, cx - 10 + lean, 23 + b, cx - 19, 36 + b + step, "cloth_mid", "cloth_dark", width=5)
    for i in range(4):
        d.line([cx - 19 - i * 2, 36 + b + step, cx - 22 - i * 2, 45 + b + step],
               fill=col("ink"), width=1)

CLASSES = [
    ("pendekar", "Pendekar", draw_pendekar, FRAME),
    ("perisik", "Perisik", draw_perisik, FRAME),
    ("pawang", "Pawang", draw_pawang, FRAME),
    ("pemanah", "Pemanah Rimba", draw_pemanah, FRAME),
]

MANUSIA = [
    ("penyamun", "Penyamun Lv1", draw_penyamun, FRAME),
    ("pencuri", "Pencuri Lv5", draw_pencuri, FRAME),
    ("pemungut", "Pemungut Lv10", draw_pemungut, FRAME),
    ("pelontar", "Pelontar Lv15", draw_pelontar, FRAME),
    ("kepala_begal", "Kepala Begal Lv19", draw_kepala_begal, FRAME),
]

JIN = [
    ("jin_tanah", "Jin Tanah Lv1", draw_jin_tanah, FRAME),
    ("toyol", "Toyol Lv5", draw_toyol, FRAME),
    ("hantu_jerut", "Hantu Jerut Lv10", draw_hantu_jerut, FRAME),
    ("pelesit", "Pelesit Lv15", draw_pelesit, FRAME),
    ("jin_belian", "Jin Belian Lv19", draw_jin_belian, FRAME),
]

BOSSES = [
    ("tok_begal", "Tok Begal Belah Retak", draw_tok_begal, BOSS_FRAME),
    ("saka_askar", "Saka Askar Perang Lama", draw_saka_askar, BOSS_FRAME),
]

ALL = CLASSES + MANUSIA + JIN + BOSSES


if __name__ == "__main__":
    write_sheets(ALL)
    write_spriteframes(ALL)
    for group, name in ((CLASSES, "classes"), (MANUSIA, "manusia"),
                        (JIN, "jin"), (BOSSES, "bosses")):
        write_lineup(group, name)
        write_walk_gif(group, name)
    print("Tanah Melayu sprites: %d entries." % len(ALL))
