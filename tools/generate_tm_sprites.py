"""
Tanah Melayu (Zaman Melaka) character sprites.

Separate from generate_sprites.py because this is a distinct art direction, not
a variant of the existing placeholder set.

Design constraints from wiki/design/decisions.md D8:
  - restricted humid palette, low saturation, high value contrast
  - silhouette first: at 32px, shape reads before detail
  - light is the mood tool, not texture

Each class is built around one silhouette-defining element so the four read
apart instantly even as 32px thumbnails:

  Pendekar       tengkolok peak + shield mass   (widest)
  Perisik        crouched, hooded, narrow       (smallest)
  Pawang         staff taller than the figure   (vertical line)
  Pemanah Rimba  the bow arc                    (only curved silhouette)

Run:  python tools/generate_tm_sprites.py
"""
import os
from PIL import Image, ImageDraw

OUT_SPRITES = "assets/sprites/tm"
OUT_FRAMES = "assets/spriteframes/tm"
FRAME = 32
FRAMES_PER_SHEET = 6          # 2 idle + 4 walk, matching the existing pipeline

# Restricted humid palette. Everything below is drawn from this and nothing else.
TM = {
    "skin":        (176, 130, 92),
    "skin_shade":  (146, 104, 72),
    "mud":         (92, 72, 52),
    "mud_dark":    (64, 50, 38),
    "brass":       (168, 128, 62),
    "brass_dark":  (120, 90, 42),
    "silver":      (150, 152, 148),
    "silver_dark": (104, 106, 104),
    "blood":       (112, 42, 40),
    "blood_dark":  (78, 28, 28),
    "lamp":        (214, 140, 58),
    "swamp":       (74, 88, 56),
    "swamp_dark":  (52, 62, 40),
    "cloth_dark":  (48, 44, 52),
    "cloth_mid":   (72, 66, 76),
    "bone":        (198, 188, 162),
    "ink":         (26, 24, 28),
}


# --- shared body parts -----------------------------------------------------

def _shadow(d, ox):
    # Never bobs: it anchors the character to the ground.
    d.ellipse([ox + 9, 26, ox + 23, 30], fill=(0, 0, 0, 90))


def _legs(d, ox, b, step, col, dark):
    lx, rx = ox + 11 + step, ox + 17 - step
    d.rectangle([lx, 21 + b, lx + 4, 27], fill=col)
    d.rectangle([rx, 21 + b, rx + 4, 27], fill=col)
    d.rectangle([lx, 26, lx + 4, 27], fill=dark)
    d.rectangle([rx, 26, rx + 4, 27], fill=dark)


def _head(d, ox, b):
    d.rectangle([ox + 12, 8 + b, ox + 19, 15 + b], fill=TM["skin"])
    d.rectangle([ox + 12, 13 + b, ox + 19, 15 + b], fill=TM["skin_shade"])


def _arm(d, sx, sy, hx, hy, col, shade=None):
    """Shoulder-to-hand limb. Without these the weapons read as floating."""
    d.line([sx, sy, hx, hy], fill=col, width=2)
    if shade:
        d.line([sx, sy + 1, hx, hy + 1], fill=shade, width=1)


def _eyes(d, ox, b, col=None):
    col = col or TM["ink"]
    d.rectangle([ox + 13, 11 + b, ox + 14, 12 + b], fill=col)
    d.rectangle([ox + 17, 11 + b, ox + 18, 12 + b], fill=col)


# --- Pendekar / Hulubalang -------------------------------------------------

def draw_pendekar(d, ox, b, step):
    _shadow(d, ox)
    _legs(d, ox, b, step, TM["mud"], TM["mud_dark"])

    # baju melayu, blood-dyed; darker on the shaded side
    d.rectangle([ox + 10, 14 + b, ox + 21, 22 + b], fill=TM["blood"])
    d.rectangle([ox + 10, 14 + b, ox + 13, 22 + b], fill=TM["blood_dark"])
    # samping at the hips, brass-shot
    d.rectangle([ox + 10, 19 + b, ox + 21, 21 + b], fill=TM["mud_dark"])
    d.rectangle([ox + 12, 20 + b, ox + 19, 20 + b], fill=TM["brass_dark"])

    _head(d, ox, b)
    # tengkolok: wrapped band plus the peak that defines the silhouette
    d.rectangle([ox + 11, 5 + b, ox + 20, 9 + b], fill=TM["mud"])
    d.rectangle([ox + 11, 7 + b, ox + 20, 8 + b], fill=TM["brass_dark"])
    d.polygon([(ox + 19, 5 + b), (ox + 25, 1 + b), (ox + 21, 8 + b)], fill=TM["mud"])
    _eyes(d, ox, b)

    # pedang jenawi, right hand; swings against the leading leg
    sy = b - step
    _arm(d, ox + 20, 16 + b, ox + 23, 19 + sy, TM["blood"], TM["blood_dark"])
    d.rectangle([ox + 23, 9 + sy, ox + 24, 20 + sy], fill=TM["silver"])
    d.rectangle([ox + 23, 9 + sy, ox + 23, 20 + sy], fill=TM["silver_dark"])
    d.rectangle([ox + 22, 20 + sy, ox + 25, 21 + sy], fill=TM["brass"])

    # wooden shield with a brass boss - the mass on the left
    hy = b + step
    _arm(d, ox + 11, 16 + b, ox + 8, 18 + hy, TM["blood"], TM["blood_dark"])
    d.ellipse([ox + 3, 13 + hy, ox + 10, 22 + hy], fill=TM["mud"])
    d.ellipse([ox + 4, 14 + hy, ox + 9, 21 + hy], fill=TM["mud_dark"])
    d.ellipse([ox + 5, 16 + hy, ox + 8, 19 + hy], fill=TM["brass"])


# --- Perisik ---------------------------------------------------------------

def draw_perisik(d, ox, b, step):
    _shadow(d, ox)
    c = 2                                    # crouched: everything sits lower
    lx, rx = ox + 11 + step, ox + 17 - step
    d.rectangle([lx, 22 + b, lx + 4, 27], fill=TM["cloth_dark"])
    d.rectangle([rx, 22 + b, rx + 4, 27], fill=TM["cloth_dark"])

    d.rectangle([ox + 11, 15 + b + c, ox + 20, 23 + b], fill=TM["cloth_dark"])
    d.rectangle([ox + 11, 15 + b + c, ox + 13, 23 + b], fill=TM["ink"])
    d.rectangle([ox + 11, 20 + b, ox + 20, 21 + b], fill=TM["swamp_dark"])

    # head wrapped: only an eye slit shows
    d.rectangle([ox + 12, 9 + b + c, ox + 19, 16 + b + c], fill=TM["cloth_mid"])
    d.rectangle([ox + 11, 8 + b + c, ox + 20, 12 + b + c], fill=TM["cloth_dark"])
    d.rectangle([ox + 12, 12 + b + c, ox + 19, 13 + b + c], fill=TM["skin_shade"])
    _eyes(d, ox, b + c + 1, TM["lamp"])
    d.line([ox + 11, 10 + b + c, ox + 7, 14 + b + c], fill=TM["cloth_dark"], width=1)

    # twin kerambit: small curved claws, held low
    sy = b - step + c
    _arm(d, ox + 20, 17 + b + c, ox + 23, 19 + sy, TM["cloth_dark"], TM["ink"])
    d.arc([ox + 22, 17 + sy, ox + 28, 23 + sy], 250, 30, fill=TM["ink"], width=2)
    d.arc([ox + 22, 17 + sy, ox + 27, 22 + sy], 250, 30, fill=TM["bone"], width=1)
    d.rectangle([ox + 21, 18 + sy, ox + 22, 19 + sy], fill=TM["mud_dark"])
    hy = b + step + c
    _arm(d, ox + 11, 17 + b + c, ox + 8, 19 + hy, TM["cloth_dark"], TM["ink"])
    d.arc([ox + 3, 17 + hy, ox + 9, 23 + hy], 150, 290, fill=TM["ink"], width=2)
    d.arc([ox + 4, 17 + hy, ox + 9, 22 + hy], 150, 290, fill=TM["bone"], width=1)
    d.rectangle([ox + 9, 18 + hy, ox + 10, 19 + hy], fill=TM["mud_dark"])


# --- Pawang ----------------------------------------------------------------

def draw_pawang(d, ox, b, step):
    _shadow(d, ox)
    # robe to the ankles: one vertical mass, no separated legs
    d.polygon([(ox + 11, 14 + b), (ox + 20, 14 + b), (ox + 22, 27), (ox + 9, 27)],
              fill=TM["swamp_dark"])
    d.polygon([(ox + 11, 14 + b), (ox + 15, 14 + b), (ox + 14, 27), (ox + 9, 27)],
              fill=TM["ink"])
    d.rectangle([ox + 9, 25, ox + 22, 26], fill=TM["swamp"])

    _head(d, ox, b)
    # loose headcloth and long hair - deliberately softer than a tengkolok
    d.rectangle([ox + 11, 6 + b, ox + 20, 10 + b], fill=(150, 140, 118))
    d.rectangle([ox + 10, 9 + b, ox + 12, 17 + b], fill=TM["mud_dark"])
    d.rectangle([ox + 19, 9 + b, ox + 21, 17 + b], fill=TM["mud_dark"])
    _eyes(d, ox, b, TM["lamp"])
    d.line([ox + 13, 16 + b, ox + 18, 16 + b], fill=TM["brass"], width=1)

    _arm(d, ox + 20, 16 + b, ox + 24, 15 + b, TM["swamp_dark"], TM["ink"])

    # tongkat kayu nibong: taller than the figure - the silhouette
    d.rectangle([ox + 24, 2 + b, ox + 25, 27], fill=TM["mud"])
    d.rectangle([ox + 24, 2 + b, ox + 24, 27], fill=TM["mud_dark"])
    d.ellipse([ox + 22, 0 + b, ox + 27, 5 + b], fill=TM["mud_dark"])
    d.ellipse([ox + 23, 1 + b, ox + 26, 4 + b], fill=TM["blood"])

    # mangkuk setanggi in the left hand, with a wisp of smoke
    hy = b + step
    _arm(d, ox + 11, 16 + b, ox + 7, 18 + hy, TM["swamp_dark"], TM["ink"])
    d.rectangle([ox + 4, 18 + hy, ox + 8, 20 + hy], fill=TM["brass_dark"])
    d.rectangle([ox + 5, 17 + hy, ox + 7, 18 + hy], fill=TM["lamp"])
    d.point((ox + 6, 15 + hy), fill=(160, 160, 160, 150))
    d.point((ox + 5, 13 + hy), fill=(160, 160, 160, 90))


# --- Pemanah Rimba ---------------------------------------------------------

def draw_pemanah(d, ox, b, step):
    _shadow(d, ox)
    _legs(d, ox, b, step, TM["swamp_dark"], TM["ink"])

    d.rectangle([ox + 11, 14 + b, ox + 20, 22 + b], fill=TM["swamp"])
    d.rectangle([ox + 11, 14 + b, ox + 13, 22 + b], fill=TM["swamp_dark"])
    d.rectangle([ox + 11, 19 + b, ox + 20, 20 + b], fill=TM["mud"])

    _head(d, ox, b)
    # headband, not a tengkolok - practical, reads as lower status
    d.rectangle([ox + 11, 7 + b, ox + 20, 9 + b], fill=TM["mud_dark"])
    d.rectangle([ox + 12, 5 + b, ox + 19, 8 + b], fill=(58, 46, 34))
    d.line([ox + 20, 8 + b, ox + 23, 11 + b], fill=TM["mud_dark"], width=1)
    _eyes(d, ox, b)

    # quiver over the shoulder, fletching showing above it
    d.rectangle([ox + 20, 12 + b, ox + 23, 20 + b], fill=TM["mud_dark"])
    for i, fx in enumerate((21, 22)):
        d.line([ox + fx, 8 + b + i, ox + fx, 12 + b], fill=TM["bone"])

    # busur kayu bakau: the only curved silhouette in the set
    hy = b + step
    _arm(d, ox + 11, 16 + b, ox + 7, 16 + hy, TM["swamp"], TM["swamp_dark"])
    _arm(d, ox + 20, 16 + b, ox + 22, 18 + b - step, TM["swamp"], TM["swamp_dark"])
    d.arc([ox + 1, 6 + hy, ox + 11, 26 + hy], 60, 300, fill=TM["mud"], width=2)
    d.line([ox + 6, 7 + hy, ox + 6, 25 + hy], fill=TM["bone"])


CLASSES = [
    ("pendekar", "Pendekar", draw_pendekar),
    ("perisik", "Perisik", draw_perisik),
    ("pawang", "Pawang", draw_pawang),
    ("pemanah", "Pemanah Rimba", draw_pemanah),
]

# [idle x2, walk x4] - same frame order as the existing player sheets.
POSES = [(0, 0), (-1, 0), (0, 0), (-1, 2), (0, 0), (-1, -2)]


def create_sheets():
    os.makedirs(OUT_SPRITES, exist_ok=True)
    for key, _label, fn in CLASSES:
        img = Image.new("RGBA", (FRAMES_PER_SHEET * FRAME, FRAME), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        for i, (bob, step) in enumerate(POSES):
            fn(d, i * FRAME, bob, step)
        path = "%s/%s_sheet.png" % (OUT_SPRITES, key)
        img.save(path)
        print("Saved %s (%d frames)" % (path, FRAMES_PER_SHEET))


def create_lineup(scale=8):
    """One wide preview of all four, upscaled. 32px is unreadable at 1:1."""
    pad, label_h = 6, 12
    w = len(CLASSES) * (FRAME + pad) + pad
    bg = Image.new("RGBA", (w, FRAME + pad * 2), (30, 28, 32, 255))

    # Characters go on a transparent layer first: ImageDraw REPLACES alpha
    # rather than blending, so drawing the semi-transparent shadow straight
    # onto the background would punch a hole in it instead of darkening it.
    layer = Image.new("RGBA", bg.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for i, (_key, _label, fn) in enumerate(CLASSES):
        fn(d, pad + i * (FRAME + pad), 0, 0)
    img = Image.alpha_composite(bg, layer)

    big = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
    d2 = ImageDraw.Draw(big)
    for i, (_key, label, _fn) in enumerate(CLASSES):
        x = (pad + i * (FRAME + pad)) * scale
        d2.text((x, big.height - label_h - 2), label, fill=(214, 200, 176))
    path = "%s/_lineup.png" % OUT_SPRITES
    big.save(path)
    print("Saved %s (%dx%d)" % (path, big.width, big.height))


def create_frames_preview(scale=6):
    """All frames of all classes, upscaled. Columns 1-2 idle, 3-6 walk."""
    pad = 4
    cols, rows = FRAMES_PER_SHEET, len(CLASSES)
    w = cols * (FRAME + pad) + pad
    h = rows * (FRAME + pad) + pad
    bg = Image.new("RGBA", (w, h), (30, 28, 32, 255))
    layer = Image.new("RGBA", bg.size, (0, 0, 0, 0))

    for r, (_key, _label, fn) in enumerate(CLASSES):
        for c, (bob, step) in enumerate(POSES):
            cell = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
            fn(ImageDraw.Draw(cell), 0, bob, step)
            layer.paste(cell, (pad + c * (FRAME + pad), pad + r * (FRAME + pad)), cell)

    img = Image.alpha_composite(bg, layer)
    big = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
    d = ImageDraw.Draw(big)
    # separate the idle pair from the walk cycle
    x = (pad + 2 * (FRAME + pad) - pad // 2) * scale
    d.line([x, 0, x, big.height], fill=(90, 84, 96))
    path = "%s/_frames.png" % OUT_SPRITES
    big.save(path)
    print("Saved %s (%dx%d)" % (path, big.width, big.height))


def create_spriteframes():
    """SpriteFrames resources matching the existing generated ones."""
    os.makedirs(OUT_FRAMES, exist_ok=True)
    anims = [("idle", 3.0, [0, 1]), ("walk", 9.0, [2, 3, 4, 5])]
    for key, _label, _fn in CLASSES:
        subs = "".join(
            '[sub_resource type="AtlasTexture" id="f%d"]\n'
            'atlas = ExtResource("1_sheet")\n'
            'region = Rect2(%d, 0, %d, %d)\n\n' % (i, i * FRAME, FRAME, FRAME)
            for i in range(FRAMES_PER_SHEET))
        blocks = ", ".join(
            '{\n"frames": [%s],\n"loop": true,\n"name": &"%s",\n"speed": %s\n}' % (
                ", ".join('{"duration": 1.0, "texture": SubResource("f%d")}' % i for i in idxs),
                name, speed)
            for name, speed, idxs in anims)
        body = (
            '[gd_resource type="SpriteFrames" load_steps=%d format=3 uid="uid://ctm%s01"]\n\n'
            '; Generated by tools/generate_tm_sprites.py\n\n'
            '[ext_resource type="Texture2D" path="res://%s/%s_sheet.png" id="1_sheet"]\n\n'
            '%s[resource]\nanimations = [%s]\n'
            % (FRAMES_PER_SHEET + 2, key[:6], OUT_SPRITES, key, subs, blocks))
        path = "%s/%s.tres" % (OUT_FRAMES, key)
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(body)
        print("Saved %s" % path)


if __name__ == "__main__":
    create_sheets()
    create_spriteframes()
    create_lineup()
    create_frames_preview()
    print("Tanah Melayu class sprites generated.")
