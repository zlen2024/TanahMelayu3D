"""
Generates clean 2D pixel-art style sprites for the Godot Web RPG POC.
"""
from PIL import Image, ImageDraw
import os

os.makedirs("assets/sprites", exist_ok=True)

def create_player(filename, tunic_color=(52, 152, 219), hair_color=(230, 126, 34)):
    # 32x32 player sprite
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Shadow
    draw.ellipse([8, 25, 24, 30], fill=(0, 0, 0, 80))
    
    # Boots
    draw.rectangle([10, 23, 14, 27], fill=(50, 40, 30, 255))
    draw.rectangle([17, 23, 21, 27], fill=(50, 40, 30, 255))
    
    # Body / Tunic
    draw.rectangle([10, 14, 21, 23], fill=tunic_color + (255,))
    draw.rectangle([13, 14, 18, 23], fill=(min(255, tunic_color[0]+30), min(255, tunic_color[1]+30), min(255, tunic_color[2]+30), 255))
    # Belt
    draw.rectangle([10, 20, 21, 21], fill=(211, 84, 0, 255))
    draw.rectangle([14, 20, 17, 21], fill=(241, 196, 15, 255))
    
    # Head / Skin
    draw.rectangle([11, 7, 20, 14], fill=(255, 219, 187, 255))
    
    # Hair
    draw.rectangle([10, 4, 21, 8], fill=hair_color + (255,))
    draw.rectangle([9, 6, 11, 11], fill=hair_color + (255,))
    draw.rectangle([20, 6, 22, 11], fill=hair_color + (255,))
    
    # Eyes
    draw.rectangle([12, 10, 14, 12], fill=(40, 40, 40, 255))
    draw.rectangle([17, 10, 19, 12], fill=(40, 40, 40, 255))
    draw.point((13, 10), fill=(255, 255, 255, 255))
    draw.point((18, 10), fill=(255, 255, 255, 255))
    
    # Shield (left) / Sword (right)
    # Sword blade
    draw.rectangle([22, 10, 24, 20], fill=(220, 220, 230, 255))
    draw.rectangle([21, 20, 25, 21], fill=(241, 196, 15, 255))
    draw.rectangle([22, 21, 24, 24], fill=(120, 60, 20, 255))
    
    # Shield
    draw.rectangle([7, 15, 10, 21], fill=(189, 195, 199, 255))
    draw.rectangle([8, 16, 9, 20], fill=(127, 140, 141, 255))
    
    img.save(filename)
    print(f"Saved {filename}")

def create_slime(filename, size=(32, 32), color=(46, 204, 113), is_king=False):
    w, h = size
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Shadow
    draw.ellipse([4, h-8, w-4, h-2], fill=(0, 0, 0, 80))
    
    # Slime body
    body_box = [4, 10 if is_king else 8, w-4, h-5]
    draw.ellipse(body_box, fill=color + (240,))
    # Inner gradient / highlight
    inner_box = [body_box[0]+3, body_box[1]+2, body_box[2]-3, body_box[3]-4]
    draw.ellipse(inner_box, fill=(min(255, color[0]+40), min(255, color[1]+40), min(255, color[2]+40), 255))
    
    # Gloss shine top-left
    draw.ellipse([body_box[0]+4, body_box[1]+4, body_box[0]+10, body_box[1]+8], fill=(255, 255, 255, 190))
    
    # Eyes
    eye_y = h // 2
    draw.ellipse([w//2 - 7, eye_y - 2, w//2 - 3, eye_y + 4], fill=(20, 20, 20, 255))
    draw.ellipse([w//2 + 2, eye_y - 2, w//2 + 6, eye_y + 4], fill=(20, 20, 20, 255))
    # Eye highlights
    draw.point((w//2 - 5, eye_y - 1), fill=(255, 255, 255, 255))
    draw.point((w//2 + 4, eye_y - 1), fill=(255, 255, 255, 255))
    
    # Crown for King Slime
    if is_king:
        crown_points = [
            (w//2 - 10, 10),
            (w//2 - 6, 4),
            (w//2, 8),
            (w//2 + 6, 4),
            (w//2 + 10, 10),
            (w//2 + 8, 14),
            (w//2 - 8, 14)
        ]
        draw.polygon(crown_points, fill=(241, 196, 15, 255), outline=(212, 172, 13, 255))
        # Ruby in crown
        draw.rectangle([w//2 - 2, 9, w//2 + 2, 13], fill=(231, 76, 60, 255))
        
    img.save(filename)
    print(f"Saved {filename}")

def create_projectile(filename):
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Glowing orb
    draw.ellipse([2, 2, 14, 14], fill=(52, 152, 219, 120))
    draw.ellipse([4, 4, 12, 12], fill=(41, 128, 185, 220))
    draw.ellipse([6, 6, 10, 10], fill=(236, 240, 241, 255))
    img.save(filename)
    print(f"Saved {filename}")

def create_xp_gem(filename):
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    points = [(8, 2), (14, 8), (8, 14), (2, 8)]
    draw.polygon(points, fill=(46, 204, 113, 255), outline=(39, 174, 96, 255))
    # Shine
    draw.polygon([(8, 4), (12, 8), (8, 12)], fill=(200, 255, 200, 200))
    img.save(filename)
    print(f"Saved {filename}")

def create_potion(filename):
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Cork
    draw.rectangle([6, 2, 10, 4], fill=(180, 130, 80, 255))
    # Neck
    draw.rectangle([7, 4, 9, 6], fill=(200, 220, 240, 200))
    # Bottle bulb
    draw.ellipse([3, 6, 13, 15], fill=(231, 76, 60, 230), outline=(192, 57, 43, 255))
    # Liquid highlight
    draw.ellipse([5, 8, 8, 11], fill=(255, 200, 200, 180))
    img.save(filename)
    print(f"Saved {filename}")

def create_tiles():
    # Grass tile 32x32
    grass = Image.new("RGBA", (32, 32), (58, 142, 60, 255))
    draw_g = ImageDraw.Draw(grass)
    # Subtle grass specks
    speckles = [(4, 5), (5, 6), (12, 18), (13, 19), (24, 8), (25, 9), (18, 27), (19, 28), (28, 22)]
    for x, y in speckles:
        draw_g.point((x, y), fill=(76, 175, 80, 255))
        draw_g.point((x+1, y-1), fill=(46, 125, 50, 255))
    # Border pattern for tile readability
    for i in range(32):
        draw_g.point((i, 0), fill=(50, 125, 52, 255))
        draw_g.point((0, i), fill=(50, 125, 52, 255))
    grass.save("assets/sprites/tile_grass.png")
    print("Saved assets/sprites/tile_grass.png")
    
    # Wall stone tile 32x32
    wall = Image.new("RGBA", (32, 32), (100, 110, 120, 255))
    draw_w = ImageDraw.Draw(wall)
    # Stone bricks
    # Row 1
    draw_w.rectangle([1, 1, 15, 14], fill=(120, 130, 140, 255), outline=(70, 80, 90, 255))
    draw_w.rectangle([17, 1, 31, 14], fill=(115, 125, 135, 255), outline=(70, 80, 90, 255))
    # Row 2 (offset)
    draw_w.rectangle([1, 16, 7, 30], fill=(110, 120, 130, 255), outline=(70, 80, 90, 255))
    draw_w.rectangle([9, 16, 23, 30], fill=(125, 135, 145, 255), outline=(70, 80, 90, 255))
    draw_w.rectangle([25, 16, 31, 30], fill=(110, 120, 130, 255), outline=(70, 80, 90, 255))
    wall.save("assets/sprites/tile_wall.png")
    print("Saved assets/sprites/tile_wall.png")

def create_slash(filename):
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Curved slash arc
    draw.arc([4, 4, 28, 28], start=200, end=350, fill=(255, 255, 255, 240), width=3)
    draw.arc([6, 6, 26, 26], start=210, end=340, fill=(241, 196, 15, 200), width=2)
    img.save(filename)
    print(f"Saved {filename}")


# ---------------------------------------------------------------------------
# Terrain atlas
# ---------------------------------------------------------------------------
# One 32px-grid atlas used by scenes/world.tscn's TileMapLayers.
#
# Layout (column, row), see scripts/world.gd for the matching constants:
#   grass variants ....... (0..3, 0)
#   dirt   3x3 block ..... (0..2, 1..3)
#   water  3x3 block ..... (4..6, 1..3)
#   stone  3x3 block ..... (8..10, 1..3)
#   props ................ (0..5, 4)
#
# The 3x3 blocks are nine-slices: NW N NE / W C E / SW S SE. world.gd picks the
# offset from a 4-bit neighbour mask, so no Godot terrain bitmask setup is
# needed and the logic stays unit-testable.

TILE = 32
ATLAS_COLS, ATLAS_ROWS = 12, 5


def _noise(draw, x0, y0, colors, rng, density=90):
    for _ in range(density):
        px = x0 + rng.randrange(TILE)
        py = y0 + rng.randrange(TILE)
        draw.point((px, py), fill=colors[rng.randrange(len(colors))])


def _fill_grass(draw, x0, y0, rng):
    draw.rectangle([x0, y0, x0 + TILE - 1, y0 + TILE - 1], fill=(74, 154, 68))
    _noise(draw, x0, y0, [(84, 168, 76), (66, 140, 62), (92, 178, 84)], rng, 90)


def _blit_block(draw, ox, oy, base, edge, rng, speckle, grass_bg=True):
    """Nine-slice block at atlas cell (ox, oy), laid out NW N NE / W C E / SW S SE.

    Edge and corner tiles blend the terrain INTO grass with a ragged boundary,
    which is what makes a patch read as part of the world rather than as a
    coloured rectangle. Centre tiles are solid terrain.
    """
    for ty in range(3):
        for tx in range(3):
            x0, y0 = (ox + tx) * TILE, (oy + ty) * TILE
            if grass_bg:
                _fill_grass(draw, x0, y0, rng)

            # How far the terrain is inset from each side (0 = runs to the edge).
            top = 9 if ty == 0 else 0
            bottom = 9 if ty == 2 else 0
            left = 9 if tx == 0 else 0
            right = 9 if tx == 2 else 0

            # Ragged boundary: walk each scanline and jitter the inset a little.
            for py in range(TILE):
                if py < top - rng.randrange(0, 4):
                    continue
                if py > TILE - 1 - bottom + rng.randrange(0, 4):
                    continue
                xa = x0 + (left - rng.randrange(0, 4) if left else 0)
                xb = x0 + TILE - 1 - (right - rng.randrange(0, 4) if right else 0)
                draw.line([xa, y0 + py, xb, y0 + py], fill=base)

            _noise(draw, x0 + left, y0 + top, speckle, rng, 45)

            # Darker lip where the terrain meets grass, for a bit of depth.
            if top:
                draw.line([x0 + left, y0 + top, x0 + TILE - 1 - right, y0 + top], fill=edge)
            if bottom:
                yb = y0 + TILE - 1 - bottom
                draw.line([x0 + left, yb, x0 + TILE - 1 - right, yb], fill=edge)
            if left:
                draw.line([x0 + left, y0 + top, x0 + left, y0 + TILE - 1 - bottom], fill=edge)
            if right:
                xr = x0 + TILE - 1 - right
                draw.line([xr, y0 + top, xr, y0 + TILE - 1 - bottom], fill=edge)



def create_terrain_atlas(filename="assets/sprites/tileset_terrain.png"):
    import random
    rng = random.Random(20260906)  # fixed seed -> regenerating is reproducible

    img = Image.new("RGBA", (ATLAS_COLS * TILE, ATLAS_ROWS * TILE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # --- grass variants -----------------------------------------------------
    grass_base = (74, 154, 68)
    grass_spec = [(84, 168, 76), (66, 140, 62), (92, 178, 84), (70, 148, 66)]
    for v in range(4):
        x0, y0 = v * TILE, 0
        draw.rectangle([x0, y0, x0 + TILE - 1, y0 + TILE - 1], fill=grass_base)
        _noise(draw, x0, y0, grass_spec, rng, 110)
        # a few blades so the ground is not pure noise
        for _ in range(6 + v * 3):
            bx = x0 + rng.randrange(2, TILE - 2)
            by = y0 + rng.randrange(3, TILE - 3)
            draw.line([bx, by, bx, by - rng.randrange(2, 4)], fill=(96, 186, 88))

    # --- dirt / water / stone nine-slices ------------------------------------
    _blit_block(draw, 0, 1, (146, 110, 72), (120, 88, 56), rng,
                [(160, 124, 84), (132, 98, 62), (152, 118, 78)])
    _blit_block(draw, 4, 1, (48, 118, 176), (36, 92, 142), rng,
                [(62, 138, 196), (40, 104, 158), (78, 158, 210)])
    _blit_block(draw, 8, 1, (128, 128, 138), (96, 96, 106), rng,
                [(142, 142, 152), (112, 112, 122), (152, 152, 160)])

    # water highlights
    for ty in range(3):
        for tx in range(3):
            x0, y0 = (4 + tx) * TILE, (1 + ty) * TILE
            for _ in range(3):
                wx = x0 + rng.randrange(4, TILE - 12)
                wy = y0 + rng.randrange(6, TILE - 6)
                draw.line([wx, wy, wx + 8, wy], fill=(120, 190, 230))

    # --- props (row 4), drawn over transparent so they overlay the ground ----
    py = 4 * TILE

    # rock
    draw.ellipse([6, py + 14, 26, py + 27], fill=(122, 122, 132))
    draw.ellipse([9, py + 11, 21, py + 21], fill=(150, 150, 158))
    draw.ellipse([12, py + 13, 17, py + 17], fill=(176, 176, 182))

    # bush
    bx = TILE
    draw.ellipse([bx + 5, py + 12, bx + 27, py + 28], fill=(38, 108, 52))
    draw.ellipse([bx + 8, py + 8, bx + 22, py + 22], fill=(52, 134, 64))
    draw.ellipse([bx + 12, py + 10, bx + 19, py + 16], fill=(68, 158, 78))

    # flowers
    fx = 2 * TILE
    for cx, cy, col in ((10, 16, (232, 92, 108)), (20, 12, (238, 212, 96)), (16, 24, (196, 128, 232))):
        draw.line([fx + cx, py + cy, fx + cx, py + cy + 5], fill=(58, 132, 62))
        draw.ellipse([fx + cx - 2, py + cy - 3, fx + cx + 2, py + cy + 1], fill=col)

    # stump
    sx = 3 * TILE
    draw.rectangle([sx + 10, py + 14, sx + 22, py + 27], fill=(104, 74, 44))
    draw.ellipse([sx + 9, py + 10, sx + 23, py + 18], fill=(146, 108, 66))
    draw.ellipse([sx + 13, py + 13, sx + 19, py + 16], fill=(112, 82, 50))

    # tall grass
    tx = 4 * TILE
    for i in range(7):
        gx = tx + 5 + i * 3
        draw.line([gx, py + 26, gx + rng.randrange(-2, 3), py + 26 - rng.randrange(7, 15)],
                  fill=(58, 142, 68))

    # cliff / wall block (opaque, used by the collision layer)
    wx = 5 * TILE
    draw.rectangle([wx, py, wx + TILE - 1, py + TILE - 1], fill=(96, 92, 88))
    _noise(draw, wx, py, [(110, 106, 100), (82, 78, 74), (120, 116, 110)], rng, 70)
    draw.rectangle([wx, py, wx + TILE - 1, py + 4], fill=(132, 128, 120))
    draw.rectangle([wx, py + TILE - 5, wx + TILE - 1, py + TILE - 1], fill=(70, 66, 62))

    img.save(filename)
    print(f"Saved {filename} ({ATLAS_COLS * TILE}x{ATLAS_ROWS * TILE}, {TILE}px grid)")


# ---------------------------------------------------------------------------
# Animation sheets
# ---------------------------------------------------------------------------
# Horizontal strips consumed by AnimatedSprite2D via the SpriteFrames resources
# in assets/spriteframes/. Frame order is fixed and mirrored in
# create_spriteframes(): [idle x2, walk x4].

PLAYER_FRAMES = 6          # 2 idle + 4 walk
SLIME_FRAMES = 4


def _draw_player_frame(draw, ox, tunic, hair, bob, step):
    """One 32x32 player frame at x-offset ox.

    bob  - vertical body offset in px (shadow stays put, so the body lifts)
    step - -1 / 0 / +1 leg swing
    """
    b = bob
    # Shadow (never bobs; it anchors the character to the ground)
    draw.ellipse([ox + 8, 25, ox + 24, 30], fill=(0, 0, 0, 80))

    # Boots swing opposite each other
    lx, rx = ox + 10 + step, ox + 17 - step
    draw.rectangle([lx, 23 + b, lx + 4, 27 + b], fill=(50, 40, 30, 255))
    draw.rectangle([rx, 23 + b, rx + 4, 27 + b], fill=(50, 40, 30, 255))

    # Body / tunic
    draw.rectangle([ox + 10, 14 + b, ox + 21, 23 + b], fill=tunic + (255,))
    draw.rectangle([ox + 13, 14 + b, ox + 18, 23 + b],
                   fill=(min(255, tunic[0] + 30), min(255, tunic[1] + 30), min(255, tunic[2] + 30), 255))
    draw.rectangle([ox + 10, 20 + b, ox + 21, 21 + b], fill=(211, 84, 0, 255))
    draw.rectangle([ox + 14, 20 + b, ox + 17, 21 + b], fill=(241, 196, 15, 255))

    # Head
    draw.rectangle([ox + 11, 7 + b, ox + 20, 14 + b], fill=(255, 219, 187, 255))
    draw.rectangle([ox + 10, 4 + b, ox + 21, 8 + b], fill=hair + (255,))
    draw.rectangle([ox + 9, 6 + b, ox + 11, 11 + b], fill=hair + (255,))
    draw.rectangle([ox + 20, 6 + b, ox + 22, 11 + b], fill=hair + (255,))

    # Eyes
    draw.rectangle([ox + 12, 10 + b, ox + 14, 12 + b], fill=(40, 40, 40, 255))
    draw.rectangle([ox + 17, 10 + b, ox + 19, 12 + b], fill=(40, 40, 40, 255))
    draw.point((ox + 13, 10 + b), fill=(255, 255, 255, 255))
    draw.point((ox + 18, 10 + b), fill=(255, 255, 255, 255))

    # Sword arm swings with the opposite leg
    sy = b - step
    draw.rectangle([ox + 22, 10 + sy, ox + 24, 20 + sy], fill=(220, 220, 230, 255))
    draw.rectangle([ox + 21, 20 + sy, ox + 25, 21 + sy], fill=(241, 196, 15, 255))
    draw.rectangle([ox + 22, 21 + sy, ox + 24, 24 + sy], fill=(120, 60, 20, 255))

    # Shield arm
    hy = b + step
    draw.rectangle([ox + 7, 15 + hy, ox + 10, 21 + hy], fill=(189, 195, 199, 255))
    draw.rectangle([ox + 8, 16 + hy, ox + 9, 20 + hy], fill=(127, 140, 141, 255))


def create_player_sheet(filename, tunic_color, hair_color):
    img = Image.new("RGBA", (PLAYER_FRAMES * 32, 32), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # idle: a gentle two-frame breath
    poses = [(0, 0), (-1, 0),
             # walk: bob up on the mid-stride frames, legs alternating
             (0, 0), (-1, 2), (0, 0), (-1, -2)]
    for i, (bob, step) in enumerate(poses):
        _draw_player_frame(draw, i * 32, tunic_color, hair_color, bob, step)
    img.save(filename)
    print(f"Saved {filename} ({PLAYER_FRAMES} frames)")


def create_slime_sheet(filename, size=(32, 32), color=(46, 204, 113), is_king=False):
    w, h = size
    img = Image.new("RGBA", (SLIME_FRAMES * w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Squash-and-stretch bounce: wide+flat, neutral, tall+narrow, neutral.
    squashes = [(2, -2), (0, 0), (-2, 2), (0, 0)]
    for i, (sx, sy) in enumerate(squashes):
        ox = i * w
        draw.ellipse([ox + 4, h - 8, ox + w - 4, h - 2], fill=(0, 0, 0, 80))

        top = (10 if is_king else 8) - sy
        body = [ox + 4 - sx, top, ox + w - 4 + sx, h - 5]
        draw.ellipse(body, fill=color + (240,))
        inner = [body[0] + 3, body[1] + 2, body[2] - 3, body[3] - 4]
        draw.ellipse(inner, fill=(min(255, color[0] + 40), min(255, color[1] + 40), min(255, color[2] + 40), 255))
        draw.ellipse([body[0] + 4, body[1] + 4, body[0] + 10, body[1] + 8], fill=(255, 255, 255, 190))

        eye_y = h // 2 - sy // 2
        draw.ellipse([ox + w // 2 - 7, eye_y - 2, ox + w // 2 - 3, eye_y + 4], fill=(20, 20, 20, 255))
        draw.ellipse([ox + w // 2 + 2, eye_y - 2, ox + w // 2 + 6, eye_y + 4], fill=(20, 20, 20, 255))
        draw.point((ox + w // 2 - 5, eye_y - 1), fill=(255, 255, 255, 255))
        draw.point((ox + w // 2 + 4, eye_y - 1), fill=(255, 255, 255, 255))

        if is_king:
            cx = ox + w // 2
            draw.polygon([(cx - 10, top), (cx - 6, top - 6), (cx, top - 2),
                          (cx + 6, top - 6), (cx + 10, top), (cx + 8, top + 4), (cx - 8, top + 4)],
                         fill=(241, 196, 15, 255), outline=(212, 172, 13, 255))
            draw.rectangle([cx - 2, top - 1, cx + 2, top + 3], fill=(231, 76, 60, 255))

    img.save(filename)
    print(f"Saved {filename} ({SLIME_FRAMES} frames)")


def _spriteframes_tres(sheet_res_path, frame_w, frame_h, anims, uid):
    """Build a SpriteFrames .tres over a horizontal strip.

    anims: list of (name, speed, loop, [frame_index, ...])
    """
    used = sorted({i for _, _, _, idxs in anims for i in idxs})
    subs = []
    for i in used:
        subs.append(
            f'[sub_resource type="AtlasTexture" id="f{i}"]\n'
            f'atlas = ExtResource("1_sheet")\n'
            f'region = Rect2({i * frame_w}, 0, {frame_w}, {frame_h})\n'
        )

    blocks = []
    for name, speed, loop, idxs in anims:
        frames = ", ".join(
            '{"duration": 1.0, "texture": SubResource("f%d")}' % i for i in idxs
        )
        blocks.append(
            '{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}'
            % (frames, "true" if loop else "false", name, speed)
        )

    return (
        f'[gd_resource type="SpriteFrames" load_steps={len(subs) + 2} format=3 uid="uid://{uid}"]\n\n'
        f'; Generated by tools/generate_sprites.py :: create_spriteframes().\n'
        f'; Frame strip: {sheet_res_path}\n\n'
        f'[ext_resource type="Texture2D" path="{sheet_res_path}" id="1_sheet"]\n\n'
        + "\n".join(subs)
        + '\n[resource]\nanimations = ['
        + ", ".join(blocks)
        + ']\n'
    )


def create_spriteframes():
    """Write the SpriteFrames resources for every animated entity."""
    import os
    out_dir = "assets/spriteframes"
    os.makedirs(out_dir, exist_ok=True)

    # Players: frames 0-1 idle, 2-5 walk.
    player_anims = [("idle", 3.0, True, [0, 1]), ("walk", 9.0, True, [2, 3, 4, 5])]
    for name, uid in (("blue", "cpfblue001"), ("red", "cpfred0001"), ("green", "cpfgreen01")):
        path = f"{out_dir}/player_{name}.tres"
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(_spriteframes_tres(
                f"res://assets/sprites/player_{name}_sheet.png", 32, 32, player_anims, uid))
        print(f"Saved {path}")

    # Slimes bounce continuously; idle and walk differ only in speed so the
    # entity code can switch animation by name without special-casing monsters.
    slime_anims = [("idle", 4.0, True, [0, 1, 2, 3]), ("walk", 8.0, True, [0, 1, 2, 3])]
    for fname, sheet, uid in (
        ("slime.tres", "res://assets/sprites/slime_sheet.png", "cpfslime001"),
        ("slime_king.tres", "res://assets/sprites/slime_king_sheet.png", "cpfsking001"),
    ):
        size = 48 if "king" in fname else 32
        path = f"{out_dir}/{fname}"
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(_spriteframes_tres(sheet, size, size, slime_anims, uid))
        print(f"Saved {path}")

if __name__ == "__main__":
    create_player("assets/sprites/player.png", (52, 152, 219), (230, 126, 34))
    create_player("assets/sprites/player_red.png", (231, 76, 60), (52, 73, 94))
    create_player("assets/sprites/player_green.png", (46, 204, 113), (243, 156, 18))
    create_slime("assets/sprites/slime.png", (32, 32), (46, 204, 113), False)
    create_slime("assets/sprites/slime_king.png", (48, 48), (241, 196, 15), True)
    create_projectile("assets/sprites/projectile.png")
    create_xp_gem("assets/sprites/gem_xp.png")
    create_potion("assets/sprites/potion_hp.png")
    create_tiles()
    create_slash("assets/sprites/slash.png")
    create_terrain_atlas()
    create_player_sheet("assets/sprites/player_blue_sheet.png", (52, 152, 219), (230, 126, 34))
    create_player_sheet("assets/sprites/player_red_sheet.png", (231, 76, 60), (52, 73, 94))
    create_player_sheet("assets/sprites/player_green_sheet.png", (46, 204, 113), (243, 156, 18))
    create_slime_sheet("assets/sprites/slime_sheet.png", (32, 32), (46, 204, 113), False)
    create_slime_sheet("assets/sprites/slime_king_sheet.png", (48, 48), (241, 196, 15), True)
    create_spriteframes()
    print("All sprites created successfully!")
