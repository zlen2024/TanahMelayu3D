# Art, Animation and UX Roadmap

Research pass, 2026-09-05. Where the presentation layer actually stands, and
what to do about it.

Everything in the "current state" column was verified against the repo, not
assumed.

## Current state

| Area | What exists | Verdict |
|---|---|---|
| Sprites | 11 PNGs, all **single-frame** — 32×32 characters, 16×16 items, 48×48 boss | No animation frames exist at all |
| Animation | `AnimatedSprite2D` + generated `SpriteFrames` | **Done 2026-09-06** — the empty `AnimationPlayer` nodes remain unused |
| Motion | Runtime `Tween`s only (`entity.gd:83`, `floating_text.gd:36`, `player.gd:286`) | Works, but covers only flashes and popups |
| Map | `TileMapLayer` Ground + Detail, procedurally painted | **Done 2026-09-06** — see [terrain.md](terrain.md) |
| UI theme | `assets/ui/rpg_theme.tres`, on all 8 root Controls | **Done 2026-09-05** |
| Pixel-art render settings | `default_texture_filter=0` (Nearest), `gl_compatibility`, 1024×576, `canvas_items` stretch | **Already correct** — no change needed |

The last row matters: the foundation is right. Nearest-neighbour filtering and
the compatibility renderer are exactly what a pixel-art web export wants, so
none of the work below is fighting the engine.

## Where the assets come from today

`tools/generate_sprites.py` draws all 11 PNGs procedurally with Pillow —
rectangles and ellipses, no source art. That is why everything is single-frame:
the generator has no concept of an animation strip.

This is genuinely useful as a fallback (zero licensing risk, regenerable), but
it caps the ceiling on visual quality hard.

---

## Answering "where do I get good assets?"

### Recommended: Kenney

[kenney.nl](https://kenney.nl) — 40,000+ assets, all **CC0** (public domain):
no attribution required, commercial use fine, no license propagation. For a POC
that may go on itch.io, CC0 removes every licensing question at once.

Kenney's top-down and roguelike packs match this project's grid and style
closely, and his UI packs are the fastest path to a non-default HUD.

### Also CC0

- **0x72's DungeonTileset II** (itch.io) — CC0 dungeon tiles *and* animated
  characters. The animation frames are the part this project lacks.
- **Pixel Frog**, **Ansimuz** (itch.io) — full CC0 packs.
- **Cainos** (itch.io) — top-down RPG tiles specifically.
- Filter itch.io directly: [CC0 + top-down assets](https://itch.io/game-assets/assets-cc0/tag-top-down).

### One to be careful with

**LPC (Liberated Pixel Cup)** on OpenGameArt has excellent top-down RPG
character animation, but it is dual-licensed **CC-BY-SA 3.0 / GPLv3**. That
means attribution *and* share-alike — derivative art must carry the same
license. Fine for a hobby project, a real constraint if this ever goes
commercial. Check the license per pack before committing.

### Or generate them

Keep `generate_sprites.py` and extend it to emit **horizontal strips** instead
of single frames — e.g. a 4-frame 128×32 walk cycle instead of one 32×32 pose.
`AnimatedSprite2D` reads that directly. This keeps the zero-dependency,
zero-license story and is the lowest-risk option if the current look is
acceptable.

Realistically: use Kenney/CC0 packs for the map and UI where quality matters
most, and keep the generator for placeholder and effect sprites.

---

## 1. Animation

**Use `AnimatedSprite2D`, not the existing empty `AnimationPlayer` nodes.**

The distinction that matters:

- `AnimatedSprite2D` plays one sequence of frames. Lower overhead per
  instance, and measurably faster with many animated entities on screen —
  which this game has, with 9 monsters plus every connected player.
- `AnimationPlayer` drives multiple tracks on one timeline — sprite frames
  *plus* position, hitbox toggles, sound cues — synchronised.

For idle/walk/attack/death on players and slimes, `AnimatedSprite2D` is the
right default. Reach for `AnimationPlayer` only where a frame must line up with
something else — e.g. enabling `AttackArea` on the exact frame the warrior's
sword connects, which is currently done with a plain `Tween` and no frame
sync (`player.gd:371`).

A hybrid is possible: an `AnimationPlayer` track can drive an
`AnimatedSprite2D`'s current frame, combining easy frame grouping with timeline
control.

**Concrete steps for this codebase:**

1. Swap `Sprite2D` → `AnimatedSprite2D` in `player.tscn` and `monster.tscn`.
   Both scripts reference `$Sprite2D` (`player.gd:59`, `monster.gd:41`), and
   `entity.gd:23` does `get_node_or_null("Sprite2D")` — so either keep the node
   name or update those three references.
2. Delete the two empty `AnimationPlayer` nodes, or actually populate them.
   Leaving them empty is what made them look like working animation.
3. Drive state from what the code already tracks — `monster.gd`'s `State` enum
   (`:9`) is already a clean animation state machine, and `player.gd` already
   has `is_rolling`, `is_charging_attack`, `is_dead`.
4. `_apply_skin()` (`player.gd:116`) currently swaps a texture; it would swap a
   `SpriteFrames` resource instead.

The `Monster.TELEGRAPH_WINDUP` state is the highest-value animation target —
it already draws a red cone via `_draw()` (`monster.gd:232`), and a wind-up
animation on top of it would make the tell far more readable.

## 2. Map — **done 2026-09-06**

Implemented via the generated-atlas route: see [terrain.md](terrain.md) for the
result. The original plan follows, kept because the cautions still apply.

**Replace the 5 `Sprite2D` quads with `TileMapLayer` + terrain autotiling.**

Note the node: `TileMap` was deprecated in Godot 4.3 in favour of
**`TileMapLayer`**, one node per layer. This project is on 4.3, so build on
`TileMapLayer` directly — do not follow older `TileMap` tutorials.

A sensible layer stack here:

| Layer | Contents |
|---|---|
| Ground | grass, paths, water |
| Detail | decoration, props |
| Collision | walls, obstacles (replaces the current `StaticBody2D` rectangles) |

Terrain sets ("autotiling") pick the correct edge and corner tiles as you
paint. Worth knowing before you rely on it: **Godot 4's terrain matching is
less reliable than Godot 3's autotiles** and can pick wrong tiles in complex
neighbourhoods — expect some manual correction on intricate areas.

Two project-specific cautions:

- `world.gd` and `network_manager.gd` find containers by the names `World`,
  `Monsters`, `Players`, `Loot`. **Do not rename them** while restructuring —
  the lookups fail silently and return early ([scenes.md](scenes.md)).
- Y-sorting will matter once the map has depth, so players walk behind
  obstacles correctly. The current flat quad hides the issue.

`set_cells_terrain_connect()` allows procedural generation from GDScript if
you later want generated maps rather than a hand-painted one.

## 3. UI / UX

**The single highest-leverage change: create one `Theme` resource.**

There is no theme at all right now, so every `Button`, `Panel` and
`ProgressBar` renders in Godot's default grey — which is most of why the game
reads as a prototype regardless of how good the sprites get.

Create a `Theme`, set default font, font sizes, colours and `StyleBox`es for
`Button`/`Label`/`Panel`/`ProgressBar`, and assign it to the root `Control`
of the HUD. Everything inherits.

`NinePatchRect` is the companion technique: define corner margins so panel
borders keep their proportions at any size instead of stretching. Essential
for pixel-art panels.

**Guidelines worth applying here:**

- HUD label font size **18–24**, tested at the target resolution. Currently
  [`floating_text.gd:29`](floating-text.md) uses 12 (16 for crits) — likely
  too small at 1024×576, and it already compensates with a heavy outline.
- High contrast: light text on dark semi-transparent panels, so the HUD stays
  readable over a busy map.
- Animation timing: panel entrances **≤150–200 ms**; feedback (button press,
  damage, pickup) **80–120 ms**. Opening the inventory should feel instant.
- Anchors and margins so the HUD survives resizing — the project already has
  `resizable=true` and `aspect="expand"`, so this will show up as soon as
  anyone resizes the window.

**Specific UX debt in this codebase**, independent of styling:

- Three level-gated features are invisible to the player: charged attack at
  level 11 (`player.gd:202`), PK mode at level 10 (`game_state.gd:227`), and
  the equip level gate. Nothing in the UI mentions any of them.
- Failed actions fail silently — the server's `error_msg` has no client
  handler ([known-gaps.md](known-gaps.md) G2), so a stat-allocate with zero
  points does nothing with no explanation.
- The PK button reports nothing when refused under level 10
  ([stats-panel.md](stats-panel.md)).
- Quick slots can be bound but never unbound
  ([inventory-ui.md](inventory-ui.md)).
- `hud.gd` builds the stamina bar and hotbar in code (`:61`, `:92`), so the
  HUD cannot be laid out visually in the editor. Moving them into the scene
  would make future UI work far easier.

---

## 4. Engine features this project is leaving on the table

Godot 4's 2D engine is pixel-coordinate native rather than a flattened 3D
camera, and several built-ins map directly onto gaps already present in this
codebase. Each was checked against the repo.

### Y-sorting — **done 2026-09-05**

Was not used anywhere; `grep` for `y_sort` returned nothing.

`world.tscn` has four pillars under `Map/Obstacles`, so draw order
between a player and a pillar is decided by scene-tree position, not by
position on the map. Walking "behind" a pillar does not put you behind it.

`Y-Sort Enabled` on the `World` node (and later on the `TileMapLayer`) sorts
draw order by Y automatically — no sorting script needed. This is a
one-checkbox fix and should probably land before the tilemap work, since it
makes the current map immediately less flat.

### Directional animation — **movement is 8-way, rendering is 2-way**

`player.gd:45` stores a full `facing_dir: Vector2`, and input is genuinely
8-directional (`:181-186`). But the only visual expression of facing is
`sprite.flip_h` (`:192`) — left or right.

So a character walking straight up looks identical to one walking right. The
README's "8-directional player movement" is true of the movement and false of
the presentation.

`AnimationTree` + `BlendSpace2D` is the built-in answer: feed the movement
vector in, and it blends between directional animations automatically.
`facing_dir` is already exactly the vector a `BlendSpace2D` wants, so the
wiring is short once directional sprite frames exist.

Also worth knowing for this codebase: an `AnimationPlayer` track can toggle the
`AttackArea` hitbox on the precise frame the sword connects. Right now
`play_slash_effect()` (`player.gd:371`) is a `Tween` with no relationship to
the hitbox at all — the damage is applied instantly on the same frame the
attack is triggered (`warrior_class.gd:19-22`), independent of the visual.

### Pathfinding — **monsters walk straight into walls**

`_process_chase` (`monster.gd:142`) is:

```gdscript
var dir = (target_player.global_position - global_position).normalized()
velocity = dir * move_speed
```

A straight line at the player, with no obstacle awareness. There are no
`Navigation*` nodes anywhere in the project. A slime chasing you around a
pillar will press into it until you move.

`NavigationRegion2D` + `NavigationAgent2D` gives real pathfinding, and the
agents include obstacle avoidance so monsters do not stack on top of each
other — which they currently do, since nothing separates them.

One project-specific caution: pathfinding must stay **host-authoritative**.
`monster.gd:112-115` already short-circuits AI on non-host clients, so the
`NavigationAgent2D` calls belong inside the same gate — otherwise every client
runs its own navigation queries for monsters it does not control.

### Custom Resources for RPG data — with one caveat

[`ItemDatabase`](item-database.md) is a `const ITEMS = { ... }` dictionary
inside a GDScript file (`item_database.gd:6`). That means items cannot be
edited in the Inspector, cannot be tweaked without touching code, and get no
type checking.

`class_name Item extends Resource` with one `.tres` per item is the idiomatic
Godot answer, and would be a clear improvement for editor workflow and for
adding items later.

**But it does not solve this project's actual item problem.** The root issue
is that the server cannot validate items because the catalogue lives in
GDScript ([security-notes.md](security-notes.md) S2), and `.tres` is *also*
unreadable by Node. Item facts are currently duplicated in four places
([item-database.md](item-database.md)), and moving to `.tres` would leave that
untouched.

If item data is reworked, the version that fixes both problems is a **shared
JSON manifest** that both sides read — or `.tres` as the editor-facing source
of truth with a build step exporting JSON for the server. Worth deciding
deliberately rather than defaulting to `.tres` because it is the Godot-native
answer.

### Control containers and the focus system

The UI already uses `VBoxContainer`/`HBoxContainer`/`GridContainer`, so the
auto-layout half is in place. What is missing is the `Theme` (section 3) and
**gamepad/keyboard focus**: nothing in the project sets `focus_neighbor` or a
focus chain, so the inventory and stats panels are mouse-only. For a web game
that is a real accessibility and controller gap, and Godot's built-in focus
system handles it without custom navigation code.

---

## Suggested order

Ordered by gain-per-effort, cheapest first:

1. ~~**Enable Y-sort**~~ — **done 2026-09-05**.
2. ~~**Theme resource**~~ — **done 2026-09-05**.
3. **Fix the silent-failure UX** (level gates, `error_msg`, PK refusal) —
   small, and these are real usability bugs rather than polish.
4. ~~**`AnimatedSprite2D`**~~ — **done 2026-09-06** with generated frames
   ([animation.md](animation.md)). `AnimationTree`/`BlendSpace2D` for
   8-directional facing is still open.
5. **`NavigationAgent2D` for monsters** — independent of all art work, and
   fixes slimes pressing into pillars. Keep it inside the host-authority gate.
6. ~~**`TileMapLayer` map**~~ — **done 2026-09-06** via the generated-atlas
   route ([terrain.md](terrain.md)).

Steps 1–3 are worth doing before any asset sourcing: they are independent of
which pack you choose, and they make the result of steps 4–6 look better when
it lands. Step 5 is pure gameplay and can run in parallel with the art track.

## Related

- [scenes.md](scenes.md) — node names the protocol depends on; do not rename
- [known-gaps.md](known-gaps.md) — the silent-failure findings
- [hud.md](hud.md) · [inventory-ui.md](inventory-ui.md) · [stats-panel.md](stats-panel.md)
- [tools.md](tools.md) — `generate_sprites.py`, the current asset source

## Sources

- [Kenney](https://kenney.nl) · [itch.io CC0 top-down assets](https://itch.io/game-assets/assets-cc0/tag-top-down) · [Free 2D sprites & tilesets guide](https://app.cinevva.com/guides/free-2d-sprites-tilesets)
- [Godot 2D sprite animation docs](https://docs.godotengine.org/en/stable/tutorials/2d/2d_sprite_animation.html) · [AnimatedSprite2D vs AnimationPlayer](https://uhiyama-lab.com/en/notes/godot/animatedsprite2d-vs-animationplayer-comparison/)
- [TileMapLayer migration guide](https://ziva.sh/blogs/godot-tilemap) · [Terrains/autotile setup](https://uhiyama-lab.com/en/notes/godot/terrains-autotile-setup/)
- [Nine-patching in Godot](https://medium.com/codex/the-power-of-nine-patching-in-godot-aae89679d3cb) · [UI system and HUD design](https://gamineai.com/courses/build-complete-game-godot-4/lessons/lesson-8-ui-system-hud-design)
