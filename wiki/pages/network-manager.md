# `scripts/network/network_manager.gd`

**Autoload** (`NetworkManager`, declared in `project.godot`) · extends `Node` ·
527 LOC — the largest non-test file in the project.

Transport and protocol dispatch. Everything that crosses the network passes
through here.

## Responsibilities

Four jobs, which is why it is the biggest file:

1. **Socket lifecycle** — connect, poll, detect open/close (`_process`, `:31`)
2. **Protocol dispatch** — the inbound `match` (`_handle_network_message`, `:149`)
3. **Scene management** — spawning and despawning player and projectile nodes
4. **Offline emulation** — a parallel `is_solo_mode` implementation of what
   the server would otherwise do

## State

| Field | Line | Meaning |
|---|---|---|
| `socket: WebSocketPeer` | 17 | `null` until `start_client()` |
| `is_connected_to_server` | 18 | Socket reached `STATE_OPEN` |
| `was_connected` | 19 | Distinguishes "dropped" from "never connected" (`:59-71`) |
| `is_solo_mode` | 20 | Guest/solo — suppresses all socket traffic |
| `is_room_host` | 21 | Elected authority; set from `welcome` / `host_promoted` |
| `local_id` | 22 | Server-assigned client id (default 1) |
| `monster_sync_timer` | 24 | 10 Hz countdown for host broadcasts |

`_ready()` sets `process_mode = PROCESS_MODE_ALWAYS` (`:29`) so networking
keeps running while the tree is paused.

## Connection

`start_client(url)` (`:73`) normalises the address before connecting: strips
whitespace and trailing slashes, prepends `ws://` when no scheme is present,
and appends `:8080` when the address has no port (`:79-83`).

That last rule is worth knowing — entering a bare hostname for a cloud host
produces `ws://host:8080`, not `wss://host:443`. Deployments behind TLS must
be entered with an explicit `wss://` prefix, which the README's Render
instructions do say.

`_process` (`:31`) drives everything: `socket.poll()`, then drain all
available packets through `_handle_network_message`, then — if host — tick the
monster broadcast timer.

## Inbound dispatch

`_handle_network_message(msg)` (`:149`) is a single `match` on `msg.type` with
16 arms. Full table in [wire-protocol.md](wire-protocol.md).

This `match` **is** the client's protocol surface, and it is invisible to
static analysis — no tool will report that `game_state.gd` is reachable from
here, because the edge is a string comparison.

Two arms carry more than routing:

- **`auth_success`** (`:157-184`) is the whole login completion path: loads
  character stats and inventory into `GameState`, registers the local player,
  picks a random spawn point, spawns the node, then sends `player_join`.
- **`monsters_sync`** (`:288-306`) applies host state, guarded by
  `if not is_room_host` so the host ignores its own echo.

A recurring pattern across arms: `get_tree().root.find_child("World", true, false)`
followed by `find_child("Players", ...)`. This runs on **every** `move`,
`stat_sync` and `attack` packet — a recursive name-based tree search per
packet, per frame, at whatever rate players are moving. Caching the two
container references would be a cheap win.

## Host authority

Only when `is_room_host` does `_broadcast_monsters_state()` (`:125`) run, at
10 Hz (`:53-57`). It walks the `Monsters` container and emits one entry per
child with **positional index**, rounded position, sprite flip, HP and dead
flag (`:134-142`).

That index-based addressing is the fragile part — see
[known-gaps.md](known-gaps.md) G4.

The host also pushes an immediate sync when a new player joins (`:246-247`)
so the newcomer does not wait up to 100 ms for monsters to appear.

## Solo / guest mode

`start_solo()` (`:94`) and `start_guest(class_type)` (`:395`) both set
`is_solo_mode = true` and `is_room_host = true`, then hand-build the state the
server would normally send.

`start_guest` carries a hardcoded stat table for the three classes
(`:400-404`) and seeds a starting inventory of potions (`:413-416`).

**These base stats are a third source of truth.** `db.js:96-140` defines class
baselines for registered users, `combat_formula.gd:48-68` derives stats from
attributes, and this table defines guest baselines. They are not derived from
each other and they do not agree — see [known-gaps.md](known-gaps.md) G11.

`send_allocate_stat` (`:440`), `send_item_pickup` (`:464`) and `send_item_use`
(`:488`) each branch on `is_solo_mode`, mutating `GameState` directly instead
of sending a packet. Each branch reimplements server logic from `db.js`.

## Scene management

- `spawn_player_node` (`:340`) — idempotent: if a node with that peer id
  already exists it refreshes level/HP and returns (`:348-355`). Nodes are
  named by peer id as a string, which is how every other lookup finds them.
- `despawn_player_node` (`:370`)
- `_spawn_projectile` (`:379`) — adds to `World` directly, not to a container.
  Called both locally (by [`MageClass`](mage-class.md) /
  [`ArcherClass`](archer-class.md)) and on the `attack` arm for remote spells.

## `_apply_item_effect`

`:505` resolves the local player node through a three-step fallback: scan the
`players` group for a matching `peer_id`/name/`is_local`, then fall back to a
tree search. The redundancy suggests it was hardened against a real bug.

Effects are hardcoded to two ids — `potion_hp` heals 60, `potion_mp` restores
50 (`:522-526`) — while [`ItemDatabase`](item-database.md) defines richer
consumable data that this function ignores.

## `_get_class_for_skin`

`:389` maps skin index to class name (0→warrior, 1→mage, 2→archer). **It has
no callers.** Class now comes from `GameState.hero_class`, set at login or
guest start. Dead code, though the skin↔class convention it encodes is still
honoured by `start_guest`'s table (`:401-403`).

## Related

- [wire-protocol.md](wire-protocol.md) — the message table
- [game-state.md](game-state.md) — what this writes into
- [architecture-overview.md](architecture-overview.md) — authority model
- [known-gaps.md](known-gaps.md) — G4, G5, G11
