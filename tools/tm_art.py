"""
Shared palette, drawing helpers and render infrastructure for the Tanah Melayu
sprite set.

Split out of generate_tm_sprites.py once the bestiary arrived: that file is now
purely drawing code, and this one holds everything reused across it.

Design constraints from wiki/design/decisions.md D8:
  - restricted humid palette, low saturation, high value contrast
  - silhouette first: shape reads before detail
  - light is the mood tool, not texture
"""
import math
import os
from PIL import Image, ImageDraw

OUT_SPRITES = "assets/sprites/tm"
OUT_FRAMES = "assets/spriteframes/tm"

FRAME = 48          # commons and playable classes
BOSS_FRAME = 64     # bosses read as bosses by size before anything else
FRAMES_PER_SHEET = 6

# [idle x2, walk x4] — same frame order as the existing player sheets.
POSES = [(0, 0), (-1, 0), (0, 0), (-1, 2), (0, 0), (-1, -2)]

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
    "rust":        (140, 116, 96),
    "blood":       (118, 44, 42),
    "blood_mid":   (92, 34, 32),
    "blood_dark":  (62, 24, 24),
    "lamp":        (222, 148, 62),
    "ember":       (236, 108, 46),
    "flame":       (246, 186, 92),
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
    "miasma":      (40, 34, 44),
}


def col(name, alpha=255):
    r, g, b = TM[name]
    return (r, g, b, alpha)


def shaded_box(d, x0, y0, x1, y1, base, mid, dark):
    """Block with a lit left edge, a body, and a shaded right edge + underside."""
    d.rectangle([x0, y0, x1, y1], fill=col(mid))
    d.rectangle([x0, y0, x0 + max(1, (x1 - x0) // 3), y1], fill=col(base))
    d.rectangle([x1 - 1, y0, x1, y1], fill=col(dark))
    d.rectangle([x0, y1 - 1, x1, y1], fill=col(dark))


def ragged_hem(d, x0, x1, y, c, depth=4, seed=0):
    """Torn cloth edge — what separates a ghost from a person in a dress."""
    for x in range(x0, x1 + 1):
        n = (math.sin((x + seed) * 1.7) + math.sin((x + seed) * 0.6)) * 0.5
        drop = int((n + 1) * depth * 0.5)
        if drop > 0:
            d.line([x, y, x, y + drop], fill=c)


def eyes(d, cx, y, spread=3):
    """Plain dark eyes for the living. Two pixels wide: any larger and they
    merge into a single band across a 12px face."""
    for sx in (-spread - 1, spread - 1):
        d.rectangle([cx + sx, y, cx + sx + 1, y + 2], fill=col("ink"))


def glow_eyes(d, cx, y, c, spread=3, size=2):
    """Bright eyes in a dark socket — the whole read in low light."""
    for sx in (-spread - 1, spread - 1):
        d.rectangle([cx + sx - 1, y - 1, cx + sx + size, y + size + 1], fill=col("ink"))
        d.rectangle([cx + sx, y, cx + sx + size - 1, y + size], fill=c)


def shadow(d, cx, y, w=14, alpha=95):
    d.ellipse([cx - w, y, cx + w, y + 6], fill=(0, 0, 0, alpha))


def hair_strands(d, cx, top, length, c, count=9, seed=0, spread=10):
    for i in range(count):
        x = cx - spread + int(i * (spread * 2 / max(1, count - 1)))
        wob = int(math.sin((i + seed) * 1.3) * 2)
        d.line([x, top, x + wob, top + length - abs(x - cx) // 2], fill=c)


def legs(d, cx, b, step, base, mid, dark, top=30, bottom=41, w=5, gap=7):
    lx, rx = cx - gap + step, cx + (gap - 5) - step
    shaded_box(d, lx, top + b, lx + w, bottom, base, mid, dark)
    shaded_box(d, rx, top + b, rx + w, bottom, base, mid, dark)
    d.rectangle([lx - 1, bottom, lx + w, bottom + 1], fill=col("mud_dark"))
    d.rectangle([rx - 1, bottom, rx + w, bottom + 1], fill=col("mud_dark"))


def head(d, cx, b, top=10, h=11, w=6):
    shaded_box(d, cx - w, top + b, cx + w - 1, top + h + b, "skin", "skin_mid", "skin_dark")


def arm(d, sx, sy, hx, hy, base, dark, width=3):
    """Weapons without a connecting limb read as floating."""
    d.line([sx, sy, hx, hy], fill=col(base), width=width)
    d.line([sx, sy + 1, hx, hy + 1], fill=col(dark), width=1)


def scar(d, x0, y0, x1, y1):
    d.line([x0, y0, x1, y1], fill=col("blood_dark"), width=1)


# --- render infrastructure -------------------------------------------------

def render(entry, bob, step):
    """One frame. Entries are (key, label, fn, size)."""
    _key, _label, fn, size = entry
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    fn(ImageDraw.Draw(img), 0, bob, step)
    return img


def write_sheets(entries):
    os.makedirs(OUT_SPRITES, exist_ok=True)
    for e in entries:
        key, _label, _fn, size = e
        sheet = Image.new("RGBA", (FRAMES_PER_SHEET * size, size), (0, 0, 0, 0))
        for i, (bob, step) in enumerate(POSES):
            sheet.paste(render(e, bob, step), (i * size, 0))
        sheet.save("%s/%s_sheet.png" % (OUT_SPRITES, key))
    print("Saved %d sheets" % len(entries))


def compose(entries, bob, step, pad=4, extra_h=0):
    """ImageDraw REPLACES alpha rather than blending, so the semi-transparent
    shadow must be composited, not drawn straight onto an opaque background."""
    w = sum(e[3] + pad for e in entries) + pad
    h = max(e[3] for e in entries) + pad * 2 + extra_h
    bg = Image.new("RGBA", (w, h), (26, 24, 30, 255))
    layer = Image.new("RGBA", bg.size, (0, 0, 0, 0))
    x = pad
    for e in entries:
        cell = render(e, bob, step)
        # bottom-align so mixed 48px and 64px sprites share a ground line
        layer.paste(cell, (x, h - extra_h - pad - e[3]), cell)
        x += e[3] + pad
    return Image.alpha_composite(bg, layer)


def write_lineup(entries, name, scale=5):
    img = compose(entries, 0, 0, extra_h=10)
    big = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
    d = ImageDraw.Draw(big)
    x = 4
    for e in entries:
        d.text((x * scale, big.height - 16), e[1], fill=(210, 198, 176))
        x += e[3] + 4
    big.save("%s/_%s.png" % (OUT_SPRITES, name))
    print("Saved _%s.png" % name)


def write_walk_gif(entries, name, scale=5, ms=120):
    """Animated GIF — the only way to actually judge motion."""
    frames = []
    for bob, step in POSES[2:]:                    # frames 2-5 are the walk cycle
        img = compose(entries, bob, step)
        frames.append(img.resize((img.width * scale, img.height * scale),
                                 Image.NEAREST).convert("P"))
    path = "%s/_%s_walk.gif" % (OUT_SPRITES, name)
    frames[0].save(path, save_all=True, append_images=frames[1:],
                   duration=ms, loop=0, optimize=False)
    print("Saved _%s_walk.gif (%d frames)" % (name, len(frames)))


def write_spriteframes(entries):
    os.makedirs(OUT_FRAMES, exist_ok=True)
    anims = [("idle", 3.0, [0, 1]), ("walk", 9.0, [2, 3, 4, 5])]
    for key, _label, _fn, size in entries:
        subs = "".join(
            '[sub_resource type="AtlasTexture" id="f%d"]\n'
            'atlas = ExtResource("1_sheet")\n'
            'region = Rect2(%d, 0, %d, %d)\n\n' % (i, i * size, size, size)
            for i in range(FRAMES_PER_SHEET))
        blocks = ", ".join(
            '{\n"frames": [%s],\n"loop": true,\n"name": &"%s",\n"speed": %s\n}' % (
                ", ".join('{"duration": 1.0, "texture": SubResource("f%d")}' % i
                          for i in idxs), nm, sp)
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
    print("Saved %d SpriteFrames resources" % len(entries))
