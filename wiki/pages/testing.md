# Testing

Two suites, both driven by `tools/run_all_tests.ps1`, both required to exit 0.

| Suite | File | Runner | Scope |
|---|---|---|---|
| Game mechanics | [`tests/run_game_tests.gd`](run-game-tests.md) | Godot headless | Client logic, scenes, combat maths |
| Network integration | `tests/test_server_network.js` | Node | Server, protocol, auth, persistence |

> **Both suites now run and pass** (2026-09-05): Godot **94/94**, Node
> **23/23**, both exit 0.

## `tests/test_server_network.js`

305 LOC, no test framework — same hand-rolled `assert(condition, name)` shape
as the GDScript suite (`:20`).

It spawns a **real server process** (`:31`) with `PORT=8099` and waits for the
`running on port` line on stdout before proceeding — a startup barrier rather
than a fixed sleep, which is the right call.

Three test groups:

| Function | Line | Covers |
|---|---|---|
| `testHealthEndpoint` | 47 | `/health` JSON shape and fields |
| `testMultiplayerFlow` | 71 | Multi-client connect, `welcome`, host election, `player_join`, `move`, `chat`, `monsters_sync` |
| `testAuthAndInventoryFlow` | 185 | `register`, `login`, `stat_allocate`, `item_pickup`, `item_use` |
| `testHostAuthorityTransfer` | 277 | Authority moves off an idle lobby client (G18) |

It imports `ws` through a relative path into the server's own
`node_modules` (`:7`) rather than declaring its own dependency — so the suite
only runs after `npm install` has been done inside `server/`.

## The gap both suites share

Neither suite tests the **seam** between them.

`run_game_tests.gd` runs in Godot with no server. `test_server_network.js`
speaks the protocol to a real server, but with hand-written JSON — it does not
drive the Godot client. Nothing anywhere asserts that the message types the
server sends are the message types the client handles.

That is precisely the class of bug that dominates
[known-gaps.md](known-gaps.md):

- **G2** — seven server→client types with no client handler. A table-driven
  test comparing `server.js`'s emitted `type:` strings against
  `network_manager.gd`'s `match` arms would catch all seven at once.
- **G3** — `stat_sync` for `xp` sent and dropped. Same test.
- **G1** — `db.getUserInventory` does not exist. This one *is* in
  `test_server_network.js`'s territory: it is a server-side `TypeError` on the
  `player_died` PK path. The suite never sends a `player_died` message with
  `is_pk` set, so it never fires. **One added assertion would have caught the
  most serious bug in the codebase.**

## Suggested additions, in priority order

1. **A `player_died` PK-path test** in `test_server_network.js` — sends
   `{type:'player_died', is_pk:true, attacker_id:<id>}` and asserts a
   broadcast arrives. Catches G1.
2. **A protocol conformance test** — parse the `type:` literals out of
   `server.js` and the `match` arms out of `network_manager.gd`, assert the
   sets reconcile. Catches G2 and G3, and keeps
   [wire-protocol.md](wire-protocol.md) honest.
3. **An equip test through the UI layer** rather than through `GameState`
   directly. Catches G14.
4. **A `stat_sync` validation test** — send
   `{type:'stat_sync', stat:'level', val:9999}`, disconnect, reconnect, assert
   the level was not persisted. Catches [security-notes.md](security-notes.md)
   S1.

## Running them

```powershell
powershell -ExecutionPolicy Bypass -File tools/run_all_tests.ps1
```

Requires `bin/Godot_v4.3-stable_win64_console.exe` (via
`tools/setup_godot.ps1`) and `npm install` in `server/`.

The Node suite uses `PORT=8099`, so it will not collide with a dev server on
8080. It writes to the default `server/data/rpg.db` unless `DB_PATH` is set —
worth setting to a temp path before running against a database you care about.

## Related

- [run-game-tests.md](run-game-tests.md) — the GDScript suite in detail
- [tools.md](tools.md) — the runner
- [known-gaps.md](known-gaps.md) — what the gaps let through
