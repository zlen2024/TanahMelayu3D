# Wiki Index

Catalogue of every page. Read this first, then drill in. Conventions and
maintenance rules are in [CLAUDE.md](CLAUDE.md).

**Project**: Godot 4.3 / GDScript web multiplayer RPG (WebAssembly client) +
Node.js WebSocket server + SQLite.

## Design (proposals, not implemented)

`wiki/design/` holds the **Tanah Melayu (Zaman Melaka)** plan — setting, four
classes, bestiary. None of it is built. Start at
[design/index.md](design/index.md), and read
[design/open-questions.md](design/open-questions.md) before committing to any
of it.

## Start here

| Page | What it covers |
|---|---|
| [architecture-overview](pages/architecture-overview.md) | How the layers fit; autoloads; authority model; the three session modes |
| [wire-protocol](pages/wire-protocol.md) | Every message type in both directions, and where they mismatch |
| [known-gaps](pages/known-gaps.md) | 16 confirmed bugs/limitations (1 fixed) + 2 tooling gaps (1 resolved) |
| [security-notes](pages/security-notes.md) | 9 trust-boundary findings |
| [decisions](pages/decisions.md) | Superseded designs still visible in the code |
| [art-and-ux-roadmap](pages/art-and-ux-roadmap.md) | Animation, map and UI/UX: current state, asset sources, suggested order |

## Client — network and state

| Page | File |
|---|---|
| [network-manager](pages/network-manager.md) | `scripts/network/network_manager.gd` (527 LOC) |
| [game-state](pages/game-state.md) | `scripts/network/game_state.gd` (236 LOC) |
| [sound-manager](pages/sound-manager.md) | `scripts/network/sound_manager.gd` (29 LOC) |

## Client — entities

| Page | File |
|---|---|
| [entity](pages/entity.md) | `scripts/entities/entity.gd` — base class |
| [player](pages/player.md) | `scripts/entities/player.gd` (478 LOC) |
| [monster](pages/monster.md) | `scripts/entities/monster.gd` (350 LOC) |
| [projectile](pages/projectile.md) | `scripts/entities/projectile.gd` |
| [loot-drop](pages/loot-drop.md) | `scripts/entities/loot_drop.gd` |
| [world](pages/world.md) | `scripts/world.gd` |

## Client — classes and combat

| Page | File |
|---|---|
| [hero-class](pages/hero-class.md) | `scripts/classes/hero_class.gd` — Strategy base + factory |
| [warrior-class](pages/warrior-class.md) | `scripts/classes/warrior_class.gd` |
| [mage-class](pages/mage-class.md) | `scripts/classes/mage_class.gd` |
| [archer-class](pages/archer-class.md) | `scripts/classes/archer_class.gd` |
| [combat-formula](pages/combat-formula.md) | `scripts/combat/combat_formula.gd` — all damage/stat maths |
| [item-database](pages/item-database.md) | `scripts/items/item_database.gd` — 13 items |

## Client — UI

| Page | File |
|---|---|
| [hud](pages/hud.md) | `scripts/ui/hud.gd` (209 LOC) |
| [chat-box](pages/chat-box.md) | `scripts/ui/chat_box.gd` |
| [inventory-ui](pages/inventory-ui.md) | `scripts/ui/inventory_ui.gd` |
| [stats-panel](pages/stats-panel.md) | `scripts/ui/stats_panel.gd` |
| [lobby-ui](pages/lobby-ui.md) | `scripts/ui/lobby_ui.gd` |
| [floating-text](pages/floating-text.md) | `scripts/ui/floating_text.gd` |
| [minimap](pages/minimap.md) | `scripts/ui/minimap.gd` — top-right minimap |

## Scenes

| Page | Covers |
|---|---|
| [animation](pages/animation.md) | Generated frame strips, SpriteFrames, and how clips are driven |
| [terrain](pages/terrain.md) | Tile atlas, TileSet and procedural map generation |
| [scenes](pages/scenes.md) | All 7 `.tscn` files; the container names and child order the protocol depends on |
| [ui-theme](pages/ui-theme.md) | `assets/ui/rpg_theme.tres` — palette, what it governs, and the 72 overrides it replaced |

## Server

| Page | File |
|---|---|
| [server-js](pages/server-js.md) | `server/server.js` (377 LOC) |
| [db-js](pages/db-js.md) | `server/db.js` (340 LOC) |
| [serve-web-js](pages/serve-web-js.md) | `server/serve_web.js` (68 LOC) — **dead** |

## Tests, tooling, deployment

| Page | Covers |
|---|---|
| [testing](pages/testing.md) | Both suites and the seam neither tests |
| [run-game-tests](pages/run-game-tests.md) | `tests/run_game_tests.gd` — 21 tests, 134 assertions (all passing) |
| [tools](pages/tools.md) | `tools/*.ps1` and `tools/*.py` |
| [build-and-deploy](pages/build-and-deploy.md) | Web export, itch.io, Render, persistence caveats |

## The graph layer

Regenerable — never hand-edit.

| File | What |
|---|---|
| `graph/build_graph.py` | Two extractors: regex for GDScript, `code2graph` CLI for JS |
| `graph/graph.json` | Full extracted facts |
| `graph/symbol_index.md` | Browsable catalogue: 22 GDScript files / 199 funcs, 37 JS symbols, 7 scenes |

## Highest-priority findings

Pulled forward so they are not buried:

0. ~~Monsters never respawned~~ — **fixed 2026-09-05**, see
   [monster](pages/monster.md) and G17.
1. **[G1](pages/known-gaps.md)** — `db.getUserInventory` does not exist;
   every PK death throws and is never relayed.
2. **[G14](pages/known-gaps.md)** — equip level hardcoded to `1`; **all five
   level-gated items — every boss drop — are unequippable.**
3. **[S1](pages/security-notes.md)** — `stat_sync` writes arbitrary keys that
   get persisted to SQLite; a client can save itself any level.
4. **[S2](pages/security-notes.md)** — `item_pickup` trusts the entire
   client-supplied item.
5. **[G2](pages/known-gaps.md)** — seven server→client message types have no
   client handler.
