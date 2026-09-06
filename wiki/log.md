# Wiki Log

Append-only. One entry per pass. Greppable: `grep "^## \[" log.md`.

## [2026-09-06] ingest | Animation, wading, cliffs, minimap terrain + zoom

**Trigger**: user asked for character animation, water slowing by depth,
impassable cliffs, and a real map picture with zoom on the minimap.

### Animation

Extended `generate_sprites.py` with frame strips and generated
`SpriteFrames` resources, then swapped both entity scenes to
`AnimatedSprite2D`. Changing the node type broke three script assumptions —
`entity.gd` was typed `Sprite2D` (now `CanvasItem`, the widest type covering
what it uses), and both `monster.gd` and `player.gd:_apply_skin()` assigned
`.texture`. Full notes in [animation.md](pages/animation.md).

`_set_anim()` only calls `play()` on change; calling it per frame restarts the
clip and freezes it on frame 0.

### Wading

`_compute_water_depth()` BFS from every dry cell, so depth 1 is the shoreline.
Multiplier lands at ~0.84x shallow, ~0.52x deep, floored at 0.35. Applied to
players **and** monsters, so a pond is not a shortcut only the player respects.

### Cliffs

Impassable corner regions. Two constraints found while placing them: they must
stay outside the monster spawn ring, and any cliff cell landing on the
crossroads is cleared back to grass — otherwise a blob can cut the arena in
half. Collision merges adjacent cells into horizontal runs: **86 shapes for 610
cells**.

### Minimap

Now draws real terrain from a one-pixel-per-tile `Image` built by `world.gd`,
rather than a black background. Zoom at x1/x2/x4 via scroll wheel or click,
with the view centre clamped so it never scrolls past the map edge.

### Tests

Added `_test_water_cliffs_and_minimap` (15 assertions) covering depth
gradients, the slow floor, cliff collision merging, that no cliff blocks the
roads, and that the terrain image is populated.

**Totals: Godot 134/134, Node network 23/23, Node db 18/18.**

### Note

`--import` must be run twice after adding new textures that a `.tres`
references: the first pass fails to resolve the not-yet-imported PNG.

## [2026-09-06] ingest | Stat fixes, ranged rework, minimap, procedural terrain

**Trigger**: user report — stats not settable, archer using the warrior's basic
attack, request for a minimap and a livelier map.

### Attribute points (G19, G20)

Levelling granted points client-side only, so `characters.stat_points` in
SQLite stayed at 0 and every allocation was rejected — silently, because
`error_msg` had no handler. The server now derives points from the reported
level (`db.grantLevelPoints`), and `error_msg` is surfaced as a SYSTEM chat
line.

Found while fixing it: the `stat_allocated` payload omitted `class_type`, and
the client defaults a missing one to `"warrior"` — so the first successful
allocation would have silently re-classed any mage or archer. Latent only
because allocation never succeeded. All character payloads now go through one
`characterPayload()` helper.

**Backfill** added on user request: `reconcileStatPoints()` runs on login and
tops up `(level-1)*3` minus what has already been spent. Idempotent by
construction.

### Ranged classes (G21)

Mage and archer called `play_slash_effect()` — the warrior's melee swing.
`_spawn_projectile()` also never set damage, so every ranged basic attack dealt
the projectile default of 25 regardless of ATK. Added `aim_dir()` auto-aim
(320 px), per-class range limits, correct damage, and extracted
`Player.face_direction()` so auto-aim and input share one facing path.

### Minimap

`scripts/ui/minimap.gd`, top-right; roster panel moved below it.

### Terrain

User chose the generated-atlas route over an external CC0 pack. Added
`create_terrain_atlas()` to `generate_sprites.py`, `assets/tilesets/terrain.tres`,
and procedural painting in `world.gd`. Autotiling is done with an explicit
neighbour mask rather than Godot terrain sets — testable without the editor.

First attempt darkened the nine-slice edges and looked like coloured
rectangles; rewritten to blend terrain into grass with a ragged per-scanline
boundary.

### Tests

New: `_test_ranged_autoaim_and_range`, `_test_procedural_map` (asserts the map
is deterministic across instances — clients generate their own and nothing
syncs it), and a whole new `tests/test_db_stats.js` suite for the attribute
logic. `run_all_tests.ps1` is now three stages.

**Totals: Godot 119/119, Node network 23/23, Node db 18/18.**

### Correction

`security-notes.md` S8 claimed password comparison used a plain `===`. It uses
`crypto.timingSafeEqual`. The original claim was inferred without reading the
comparison; corrected.

## [2026-09-05] ingest | Y-sort + UI theme implemented and visually verified

**Trigger**: user asked for the two cheapest wins from the roadmap.

### Y-sort

Enabled on `World`, `Map`, `Map/Obstacles`, `Loot`, `Monsters`, `Players` —
every node between the sorting root and the sprites, since a container without
it is sorted as a single unit and its children never interleave.

`Map/Ground` pinned to `z_index = -100` rather than included in the sort: it
sits at Y=0 and would otherwise occlude anything standing above the origin.

Enabling Y-sort would have let entities draw over combat text, so
`floating_text.gd` gets `z_index = 100`, the two `player.gd` notification
labels the same, and the `UI` nameplate/health-bar node in `player.tscn` and
`monster.tscn` gets `z_index = 50`. Those were regressions the change itself
would have introduced.

### Theme

The finding that shaped the work: `main.tscn` carried **72
`theme_override_*` entries**, and overrides beat a theme — so adding one alone
would have been a near no-op. **39 of 42 font-size overrides were 10–11 px**,
which was the actual readability problem.

Added `assets/ui/rpg_theme.tres`, removed the cramped size overrides and the
structural style overrides, kept the semantic ones (HP/energy/XP bar fills,
accent font colours) and the layout constants, deleted three orphaned
`StyleBoxFlat` sub-resources and recomputed `load_steps`. Assigned to the 8
root Controls (`CanvasLayer` cannot hold a theme).

### Verification

Wrote `tools/screenshot_harness.gd` — the project had no way to confirm a
visual change. Rendered the lobby, an in-world Y-sort arrangement, and the
panels.

Caught one regression from the screenshots that tests could not have: the
14→22 title bump also hit the HUD level readout, rendering "Level 1 Warrior"
oversized. Set to 17.

Confirmed in-frame: the hero draws over a slime at lower Y, and a slime below
the pillar draws in front of it. Suite still **94/94, exit 0**.

## [2026-09-05] ingest | Monster respawn bug fixed; art/animation/UX research

**Trigger**: user reported monsters not respawning, and asked for research on
animation, map design, UI/UX and where to source game assets.

### Bug fixed — G17

Confirmed the report and found it was three compounding problems, not one:
`Monster._die()` scheduled no respawn, never freed or hid the node (leaving a
frozen corpse), and `world.gd`'s fallback respawn was unreachable because dead
monsters stayed in the container. `Entity.entity_died` — the obvious intended
hook — had zero listeners.

The sync protocol's resurrection branch (`monster.gd:92-103`) already existed
and had never been reachable; only the host-side countdown was missing. Fixed
with an authority-gated timer, and the countdown deliberately placed ahead of
`process_entity_status()` which early-returns for dead entities.

**Tests**: added `_test_monster_respawn` (11 assertions). Full suite now
**94/94 passing, exit 0**. One assertion in the new test was wrong on the first
run — it asserted the respawned monster sits in `IDLE`, but it legitimately
aggros the test's adjacent player in the same frame; corrected to assert it
left the terminal `DEAD` state.

**T2 resolved**: the Godot suite does run in this environment. The earlier
entry was written before it had been attempted. The Node suite still has not
been run.

### Research — new page

Added [art-and-ux-roadmap.md](pages/art-and-ux-roadmap.md), grounded in an
audit rather than generic advice. Verified findings:

- All 11 sprites are **single-frame**; no animation frames exist anywhere.
- The `AnimationPlayer` nodes in `player.tscn` / `monster.tscn` contain
  **zero animations** — dead scaffolding that reads as working animation.
- The map is **5 `Sprite2D` quads**, not a TileMap.
- There is **no `Theme` resource** in the project at all.
- Render settings are **already correct** for pixel art
  (`default_texture_filter=0`, `gl_compatibility`) — an assumption checked
  before it was written down, and it disproved the expected finding.

## [2026-09-05] ingest | Initial wiki build from full-codebase structural pass

**Scope**: entire repository — 22 GDScript files, 3 server JS files, 1 JS test
suite, 7 scenes, 6 tool scripts.

**Graph layer built.** `code2graph` was already installed
(`~/.cargo/bin/code2graph.exe`, v0.0.0-beta.17) but not on the shell PATH.

Critical finding on the tooling itself: **`code2graph index .` inside
`scripts/` admits 0 files** — it is tree-sitter based with no GDScript
grammar, making 21 of 22 GDScript files invisible to it. Only `server/`
(3 files, 37 symbols, 26 edges) is genuinely queryable.

Wrote `graph/build_graph.py` to compensate: a regex extractor for GDScript
plus the real `code2graph` CLI at `--tier scope` for JS, merged into one
`graph.json`. Added top-level-only filtering after the first run captured
function-local variables as members.

**Pages written**: 34 pages plus `index.md`, `log.md` and the `CLAUDE.md`
schema. One page per source file, plus five cross-cutting pages
(architecture, wire protocol, known gaps, security notes, decisions).

**Method note**: the wire protocol was reconstructed by reading both
dispatchers — `server.js`'s `switch` and `network_manager.gd`'s `match` — and
reconciling them message by message. That reconciliation is what surfaced the
seven unhandled types (G2) and the dead `take_damage`/`heal` arms.

### Confirmed findings

- **G1** — `server.js:291` calls `db.getUserInventory`, which is defined and
  exported nowhere. Every PK death throws a `TypeError` swallowed by the
  message-loop `try`, so PK deaths are never relayed. Most serious bug found.
- **G14** — `inventory_ui.gd:148` passes a literal `1` as the player level to
  `equip_item`. All five items with `lvl_req > 1` — every King Slime and Magma
  Slime drop — are permanently unequippable.
- **G2** — seven server→client message types have no client handler
  (`roll`, `pk_toggle`, `player_died`, `loot_dropped`, `error_msg`, plus the
  doubly-dead `take_damage` and `heal`).
- **S1** — `server.js:248` writes `p[msg.stat] = msg.val` with both key and
  value client-controlled; that object is persisted to SQLite on disconnect.
- **S2** — `item_pickup` passes the client's item dictionary straight to the
  database.
- **S3/S4** — `chat` is relayed without identity stamping and rendered as
  unescaped BBCode.
- **D1** — four `@rpc`-annotated functions in `game_state.gd` are never
  invoked over RPC; transport is raw `WebSocketPeer` + JSON. `send_chat` has
  zero callers.
- **G8** — `serve_web.js` is superseded and unreferenced; `npm run dev` cannot
  work (both processes default to port 8080).
- **G9/G16** — the README describes a smaller, different game and documents
  the wrong controls.

### Corrections made during the pass

Three suspicions were investigated and **disproved** before being written
down; they are recorded under "Not findings" in
[security-notes.md](pages/security-notes.md) so they are not re-flagged:

- `monster.gd:303` looked like per-client chat spam on kills — it is correctly
  nested inside `if killer_id == NetworkManager.local_id`.
- `Monster.max_health`/`current_health` looked like duplicated HP state —
  they are property aliases onto `Entity`'s fields.
- `chat_box.gd` appeared not to lock movement while typing — it does, via
  `focus_entered`/`focus_exited` on the `LineEdit` (`:23-24`). The
  chat-box page was corrected after this was checked.

### Not done

- **Neither test suite was executed.** All claims about tests come from
  reading `run_game_tests.gd` and `test_server_network.js`. Nothing in this
  wiki asserts the tests pass.
- No code was modified. The wiki is documentation only; every finding is
  recorded with a fix shape, none applied.
