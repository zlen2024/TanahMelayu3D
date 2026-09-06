# Scenes (`scenes/*.tscn`)

Seven `.tscn` files — six game scenes plus a test harness. Godot scenes are
the *other* half of this codebase's structure: they wire node trees that the
GDScript `@onready` paths depend on, and they are invisible to any
code-only analysis.

Extracted by `build_graph.py` into `graph.json` under `scenes` — node names
and `ext_resource` paths per file.

## `main.tscn` — the entry point

Set as the main scene in `project.godot`. Composes everything:

| Child | Script / scene |
|---|---|
| `World` | instance of `world.tscn` |
| `HUD` | [`hud.gd`](hud.md) |
| `ChatBox` | [`chat_box.gd`](chat-box.md) |
| `LobbyUI` | [`lobby_ui.gd`](lobby-ui.md) |
| `StatsPanel` | [`stats_panel.gd`](stats-panel.md) |
| `InventoryUI` | [`inventory_ui.gd`](inventory-ui.md) |

`StatsPanel` and `InventoryUI` are children of the HUD subtree, which is how
`hud.gd:23-24` reaches them with `$StatsPanel` / `$InventoryUI`.

The `TopLeft/VBoxContainer` chain (`LevelLabel`, `HBoxHP`, `HBoxEnergy`,
`HBoxXP`, `HBoxButtons`) is what every `@onready` path in `hud.gd:5-14`
resolves against. Note the stamina row is **not** here — `hud.gd:61` builds
and splices it at runtime, so the scene tree at rest is missing a row the
running game shows.

## `world.tscn`

Root of gameplay, script [`world.gd`](world.md). Structure:

- `Map/Ground` — grass tiling
- `Map/Borders/{WallTop,WallBottom,WallLeft,WallRight}` — the arena bounds
- `Map/Obstacles/Pillar*` — static obstacles
- `Monsters`, `Players`, `Loot` — the three runtime containers

**Y-sorting** (added 2026-09-05) is enabled on `World`, `Map`,
`Map/Obstacles`, `Loot`, `Monsters` and `Players`. Every node between the
sorting root and the sprites needs it, or a container is sorted as one unit at
its own Y and its children never interleave with the others.

`Map/Ground` is pinned to `z_index = -100` instead. It sits at Y=0, so left in
the sort it would occlude anything standing above the origin — `z_index` groups
resolve before Y-sorting, keeping it at the back unconditionally.

Those three containers are the anchors for nearly all runtime lookups.
[`NetworkManager`](network-manager.md) finds them by name on almost every
inbound packet (`find_child("World", ...)` then `find_child("Players", ...)`),
so **renaming any of them silently breaks multiplayer** — the lookups return
null and the code returns early rather than erroring.

The `Monsters` container's child *order* is also protocol-significant: it is
the index space used by `monster_hit` and `monsters_sync`
([known-gaps.md](known-gaps.md) G4).

## Entity scenes

| Scene | Script | Notable nodes |
|---|---|---|
| `player.tscn` | [`player.gd`](player.md) | `Sprite2D`, `SlashSprite`, `Camera2D`, `AttackArea/CollisionShape2D`, `UI/NameLabel`, `UI/HealthBar` |
| `monster.tscn` | [`monster.gd`](monster.md) | `Sprite2D`, `CollisionShape2D`, `UI/NameLabel`, `UI/HealthBar` |
| `projectile.tscn` | [`projectile.gd`](projectile.md) | `Sprite2D`, `CollisionShape2D` |
| `loot_drop.tscn` | [`loot_drop.gd`](loot-drop.md) | `Sprite2D`, `CollisionShape2D` |

`player.tscn` carries a `Camera2D` on **every** instance; `player.gd:71,78`
enables it only when `is_local`. So a session with N players has N cameras in
the tree with exactly one active.

`AttackArea` is the warrior's melee hitbox — the only consumer is
`warrior_class.gd:19`, and its x-offset is flipped with facing by
`player.gd:193`.

Both `player.tscn` and `monster.tscn` include an `AnimationPlayer` that no
script references. All visual feedback is done with runtime `Tween`s instead
(`entity.gd:83`, `floating_text.gd:36`, `player.gd:286`). The
`AnimationPlayer` nodes appear to be unused scaffolding.

## `test_runner.tscn`

A single `TestRunner` node with [`run_game_tests.gd`](run-game-tests.md).
Invoked headless by `tools/run_all_tests.ps1`.

## Why scenes matter to this wiki

Three coupling points that no code search will show you:

1. **`@onready` paths** are string paths into the scene tree. A node rename
   breaks them at runtime, not at parse time.
2. **Container names** (`World`, `Players`, `Monsters`, `Loot`) are looked up
   by string from `network_manager.gd` and `hud.gd`.
3. **Child order** in `Monsters` is part of the wire protocol.

## Related

- [world.md](world.md) · [architecture-overview.md](architecture-overview.md)
- `wiki/graph/symbol_index.md` — the extracted node lists
