# `scripts/world.gd`

extends `Node2D` · 46 LOC. Script on the root of
[`world.tscn`](scenes.md).

Small file, disproportionate importance: it owns the three containers every
other system looks up by name, and it decides where monsters are.

## The three containers

```gdscript
@onready var monsters_container = $Monsters
@onready var players_container  = $Players
@onready var loot_container     = $Loot
```

(`:8-10`)

Curiously, **none of these three variables is ever read** in this file beyond
`monsters_container` in `_on_match_started` (`:20`) and `_create_monster`
(`:46`). `players_container` and `loot_container` are declared and unused
here.

Everything else reaches the same nodes by string search from elsewhere —
[`NetworkManager`](network-manager.md) does
`find_child("World", true, false).find_child("Players", ...)` on nearly every
packet, and `hud.gd:55-59` does the same to watch for player spawns. Loot is
parented to the monster's own parent instead (`monster.gd:314`), never to
`loot_container`.

So the container the script holds a reference to is not the one most callers
use to find it. Consolidating on this script's references would remove a lot
of repeated tree searching.

## Map generation

`_ready()` calls `_build_map()` before spawning monsters. Terrain layout,
nine-slice painting and prop scattering all live here — full detail in
[terrain.md](terrain.md).

`ground_layer` and `detail_layer` are `TileMapLayer` nodes; the old single
`Sprite2D` grass quad is gone.

## Spawning

`_ready()` (`:12`) connects `NetworkManager.match_started` and — if
`multiplayer.is_server()` — spawns monsters immediately.

`_on_match_started()` (`:19`) repeats the spawn, guarded on the container
being empty, for the case where the match starts after `_ready`.

`_spawn_initial_monsters()` (`:23`) places 8 slimes at hardcoded coordinates
(`:25-34`) plus one King Slime at `(0, -450)` (`:40`).

The spawn list is **fixed and ordered**, which is what makes the protocol's
index-based monster addressing work at all — every client runs this same
function and produces the same list in the same order. Nothing states that
dependency; it is load-bearing and undocumented in the code.
See [known-gaps.md](known-gaps.md) G4.

`_create_monster(pos, is_king)` (`:42`) instantiates and sets `is_king_slime`
**before** `add_child`, so `monster.gd:_ready` sees it and applies boss stats
(`monster.gd:52-63`). Only two variants are reachable this way —
`RED_SLIME` is never spawned ([monster.md](monster.md)).

## The `multiplayer.is_server()` check

`:16` and `:20` gate spawning on `multiplayer.is_server()`. This reads like an
authority check and is not one.

The game never assigns a `MultiplayerPeer` — transport is a raw
`WebSocketPeer` ([decisions.md](decisions.md) D1) — so Godot 4's default
`OfflineMultiplayerPeer` reports peer id 1 and `is_server()` returns `true`
on **every** client.

The practical result: all clients spawn the full monster set locally, and the
elected host's `monsters_sync` then drives everyone else's positions
(`monster.gd:112-115`). It works, but not for the reason the code appears to
claim, and the check is doing nothing. See
[known-gaps.md](known-gaps.md) G5.

Genuine authority lives in `NetworkManager.is_room_host`, which is what
`monster.gd` actually tests.

## Related

- [scenes.md](scenes.md) — the node tree this script sits on
- [monster.md](monster.md) — what gets spawned
- [network-manager.md](network-manager.md) — `match_started`, host authority
