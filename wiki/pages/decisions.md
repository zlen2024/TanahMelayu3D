# Decision Log

The graph shows only the *current* state of the code. This page records
choices that were made, reversed, or left half-finished — the things a
structural query can never tell you.

There is **no git history to consult**: the repository has a single initial
commit and everything else is untracked. So every entry here is inferred from
artefacts left in the code, and is labelled with how confident that inference
is.

---

## D1 — Godot high-level multiplayer was abandoned for raw WebSockets

**Confirmed by artefact. Superseded.**

`game_state.gd` declares four `@rpc`-annotated functions
(`game_state.gd:91`, `:104`, `:112`, `:116`), all with the same
`@rpc("any_peer", "call_local", "reliable")` configuration. That is the
signature of a design built on Godot's high-level multiplayer.

**None of them are ever invoked over RPC.** A repo-wide search for `.rpc(`,
`.rpc_id(` and `rpc("` returns only the four annotation lines themselves —
zero call sites. Every one is instead called as a **plain function**:

| Function | Called from |
|---|---|
| `register_player_info` | `network_manager.gd:99,168,227,241,418`; `run_game_tests.gd:273-274` |
| `unregister_player` | `network_manager.gd:252` |
| `sync_player_stat` | `player.gd:335,407-409`; `network_manager.gd:272`; `run_game_tests.gd:280` |
| `send_chat` | **nothing — zero call sites anywhere** |

The transport that actually exists is a raw `WebSocketPeer`
(`network_manager.gd:17`) carrying JSON, documented in
[wire-protocol.md](wire-protocol.md).

**Why the switch is plausible:** Godot's `WebSocketMultiplayerPeer` works in
browsers, but a high-level-multiplayer session needs a Godot instance acting
as server. The Node relay in `server/server.js` lets the backend be a
20-line-dependency Node process deployable to Render's free tier — which the
README's deployment section is built around. Trading `@rpc` for hand-rolled
JSON buys a backend that does not require running the game engine on a server.

**What survives as debris:**

- The four `@rpc` annotations, which now do nothing but mislead.
- `send_chat`, which is entirely dead — chat is sent as a `chat` packet from
  `chat_box.gd:55` and received via the `chat_received` signal
  (`network_manager.gd:326`), never through this function.
- `world.gd:16`'s `multiplayer.is_server()` check, which now means "always
  true" rather than "am I the authority" (see
  [known-gaps.md](known-gaps.md) G5).
- The README's claim of "High-Level Multiplayer RPC synchronization (`@rpc`)",
  which is simply no longer true.

*If picking this up:* deleting the four annotations and `send_chat` is safe
and removes the trap. Leaving them means every future reader re-derives this.

## D2 — Authority was moved to an elected client, not the server

**Confirmed by artefact. Current design.**

The Node server never simulates the game. It relays, authenticates, and
persists. Monster AI runs on an **elected host client**, chosen by the server
as the first connection (`server.js:111-114`) and re-elected on disconnect
(`server.js:352-362`).

This follows from D1: once the backend is a generic relay rather than a Godot
instance, something still has to run monster AI deterministically, and the
only things running Godot are the clients.

The cost is a trust model with no server-side authority over combat at all —
see [security-notes.md](security-notes.md) S1, S2 and S5.

## D3 — `serve_web.js` was superseded by unifying onto one port

**Confirmed by artefact. Superseded.**

`serve_web.js` is a standalone static file server. `server.js` now serves
`dist/` **and** WebSockets on the same port, which its own header comment
calls out (`server.js:2-3`) and which the README presents as the headline
benefit ("Single port: works with local browsers, VS Code dev tunnels, and
cloud hosting!").

`serve_web.js` has no inbound code edges — `code2graph module-deps` over
`server/` finds only `server.js -> db.js`. Its remaining references are the
`serve` and `dev` npm scripts, and `dev` is broken because both files default
to port 8080 ([known-gaps.md](known-gaps.md) G7).

## D4 — `class_type` was added to an existing schema, in place

**Confirmed by artefact.** `db.js:64-68`:

```js
try {
  db.exec("ALTER TABLE characters ADD COLUMN class_type TEXT DEFAULT 'warrior'");
} catch (e) {
  // column already exists
}
```

An idempotent migration guarded by try/catch, run at import time. It tells us
the class system (D5) arrived **after** the first schema shipped, and that
existing characters were defaulted to warrior rather than being asked to
choose.

This is the only migration in the codebase. There is no migration framework
and no schema version — a second one would have to follow the same pattern.

## D5 — Classes use the Strategy pattern with a string-keyed factory

**Confirmed by artefact. Current design.**

`HeroClass` (`hero_class.gd`) is an abstract base with three virtual methods,
and `HeroClass.create(class_type)` (`hero_class.gd:22-32`) is a factory that
`load()`s one of three subclass scripts by matching a lowercase string.

The dispatch is deliberate and it is invisible to static analysis. A tool
asking "what constructs `MageClass`" finds nothing, because the only
construction site is `script.new()` on a dynamically loaded path
(`hero_class.gd:25-26`). Any future subclass must be registered in that
`match` or it will never be reachable — noted in the schema's verification
rules ([CLAUDE.md](../CLAUDE.md)).

`Player` re-creates its strategy on every `recalculate_stats()`
(`player.gd:89-90`), so a class change takes effect without respawning.

## D6 — Two health field names coexist on `Monster`, deliberately

**Confirmed by artefact.** `monster.gd:19-25`:

```gdscript
# Compatibility aliases for existing test cases
var max_health: int:
    get: return max_hp
    set(val): max_hp = val
```

`Entity` names the fields `max_hp` / `current_hp`; `Monster` exposes
`max_health` / `current_health` as property aliases onto them. The comment
says why: existing tests referenced the older names.

This is worth recording precisely because it *looks* like a duplicated-state
bug on a skim and is not — there is one storage location. `run_game_tests.gd`
and `network_manager.gd:140-141` use the alias names; everything else uses the
`Entity` names.

---

## Open questions

Things the code does not answer, and that a person on this project would
have to decide:

- **Is uncontested loot intended?** Each client spawns its own copy of every
  drop ([known-gaps.md](known-gaps.md) G6), so two players can both collect
  "the same" item. Nothing in the code indicates whether this is the design.
- **Should crit apply to ranged and skill damage?** Currently warrior melee
  only (G13).
- **Were the COOP/COEP headers intentional?** They contradict the README (G10)
  and there is no history to check.
