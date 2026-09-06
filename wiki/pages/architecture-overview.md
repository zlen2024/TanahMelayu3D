# Architecture Overview

A 2D top-down multiplayer action RPG: a **Godot 4.3 / GDScript** client
exported to WebAssembly, talking to a **Node.js** server over a hand-rolled
JSON-over-WebSocket protocol, with **SQLite** persistence.

## The one thing to understand first

**Godot's high-level multiplayer is not used for transport.** No
`MultiplayerPeer` is ever assigned. `network_manager.gd:17` holds a raw
`WebSocketPeer`, and every message goes through `send_packet()`
(`network_manager.gd:121`) as `JSON.stringify`'d text.

This matters because the README advertises the opposite ("High-Level
Multiplayer RPC synchronization (`@rpc`)"), and because four `@rpc`-annotated
functions survive in `game_state.gd` as decoys. See
[decisions.md](decisions.md) and [known-gaps.md](known-gaps.md).

## Layers

```
┌─────────────────────────────────────────────────────────────┐
│ UI (CanvasLayer / Control)                                  │
│   hud · chat-box · inventory-ui · stats-panel · lobby-ui     │
└───────────────┬─────────────────────────────────────────────┘
                │ Godot signals
┌───────────────▼─────────────────────────────────────────────┐
│ GameState  (autoload) — client-side model of the session     │
│   stats, inventory, equipped gear, roster, 12 signals        │
└───────────────┬─────────────────────────────────────────────┘
                │
┌───────────────▼─────────────────────────────────────────────┐
│ NetworkManager (autoload) — transport + protocol dispatch    │
│   WebSocketPeer · send_packet() · match on msg.type          │
└───────────────┬─────────────────────────────────────────────┘
                │ JSON over WebSocket  ── see wire-protocol.md
┌───────────────▼─────────────────────────────────────────────┐
│ server/server.js — relay, auth, host election, static host   │
│ server/db.js     — node:sqlite persistence                   │
└─────────────────────────────────────────────────────────────┘
```

Entities sit beside this stack, not inside it: [`Entity`](entity.md) is the
shared base for [`Player`](player.md) and [`Monster`](monster.md), and both
reach into `NetworkManager` / `GameState` directly.

## Autoloads

Three, declared in `project.godot`:

| Autoload | Script | Role |
|---|---|---|
| `SoundManager` | [`sound_manager.gd`](sound-manager.md) | Global SFX playback |
| `GameState` | [`game_state.gd`](game-state.md) | Session model + signal bus |
| `NetworkManager` | [`network_manager.gd`](network-manager.md) | Transport + dispatch |

Because they are autoloads, nearly every script references them by bare
global name. That is why a grep for `GameState` returns hits everywhere while
the *import* graph looks almost empty — there are no import edges to find.

## Authority model

Authority is **elected, not centralized**. The server picks the first
connected client as host (`server.js:111-114`) and tells it via
`welcome.is_host`; on host disconnect it promotes another
(`server.js:352-362`).

The elected host is the only client that **broadcasts** monster state —
`_broadcast_monsters_state()` at 10 Hz (`network_manager.gd:53-57`). Non-hosts
apply it (`network_manager.gd:288-306`) and skip their own AI
(`monster.gd:112-115`).

Two consequences worth holding onto:

1. **Every client simulates monsters locally.** `world.gd:16` gates spawning
   on `multiplayer.is_server()`, which is `true` for everyone here because
   Godot 4's default `OfflineMultiplayerPeer` reports peer id 1 and no real
   peer is ever set. So all clients spawn the full monster set; the host's
   sync then overwrites positions on everyone else.
2. **Monsters are addressed by child index, not by id.** Both
   `monsters_sync` and `monster_hit` use the node's `get_index()`
   (`monster.gd:264`, `network_manager.gd:296-298`). This is only correct
   while every client's `Monsters` container holds the same children in the
   same order. See [known-gaps.md](known-gaps.md).

Combat itself is **client-authoritative**: a client computes damage locally
and tells everyone (`monster.gd:258-268`). The server never simulates.

## Persistence

`server/db.js` owns three SQLite tables — `users`, `characters`, `inventory`
(`db.js:21-62`) — via Node's built-in `node:sqlite`, so the server has exactly
one runtime dependency (`ws`).

Character progress is written **only on disconnect** (`server.js:323-342`),
from an in-memory `players` Map that the client itself populates through
`stat_sync`. Inventory, by contrast, is written immediately on every pickup
and use. See [db-js.md](db-js.md) and [security-notes.md](security-notes.md).

## Three ways to start a session

All three land in the same `World` scene:

| Mode | Entry | Networked | Persisted |
|---|---|---|---|
| **Login / Register** | `lobby_ui.gd:67,79` → `send_login`/`send_register` | yes | yes (SQLite) |
| **Guest** | `lobby_ui.gd:93` → `start_guest()` (`network_manager.gd:395`) | no — `is_solo_mode` | no |
| **Solo** | `start_solo()` (`network_manager.gd:94`) | no | no |

`is_solo_mode` makes `send_packet()` a no-op path and forces several
functions to mutate `GameState` directly instead — compare the two branches
of `send_allocate_stat` (`network_manager.gd:440-462`), `send_item_pickup`
(`:464`) and `send_item_use` (`:488`). That duplicated logic is a standing
maintenance hazard, noted in [known-gaps.md](known-gaps.md).

## Related pages

- [wire-protocol.md](wire-protocol.md) — every message type, both directions
- [security-notes.md](security-notes.md) — trust boundary findings
- [known-gaps.md](known-gaps.md) — confirmed bugs and limitations
- [decisions.md](decisions.md) — superseded designs still visible in the code
- [testing.md](testing.md) · [build-and-deploy.md](build-and-deploy.md)
