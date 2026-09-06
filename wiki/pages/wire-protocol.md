# Wire Protocol

The contract between the Godot client and `server/server.js`. Plain JSON over
a WebSocket, one object per frame, dispatched on a `type` string.

- **Client → server**: `NetworkManager.send_packet()` (`network_manager.gd:121`)
- **Server dispatch**: `switch (msg.type)` (`server.js:130`)
- **Server → client**: `NetworkManager._handle_network_message()` `match` (`network_manager.gd:151`)

There is no schema, no versioning, and no validation on either side. This page
*is* the schema — it was reconstructed by reading both dispatchers, so keep it
in sync when either changes.

## Client → server

| `type` | Sent from | Server handler | Effect |
|---|---|---|---|
| `register` | `network_manager.gd:425` | `server.js:131` | `db.registerUser`, replies `auth_success`/`auth_error` |
| `login` | `network_manager.gd:434` | `server.js:147` | `db.loginUser`, replies `auth_success`/`auth_error` |
| `player_join` | `network_manager.gd:173` | `server.js:214` | Stores raw msg as player state; replies `existing_players`; relays |
| `move` | `player.gd:229` | `server.js:234` | Updates `pos`/`flip`; relays with server-stamped `id` |
| `attack` | `warrior_class.gd:13`, `mage_class.gd:11,34,48`, `archer_class.gd:11,35` | `server.js:264` | Relays with `sender_id` |
| `monster_hit` | `monster.gd:262` | `server.js:267` | Relays |
| `monsters_sync` | `network_manager.gd:144` | `server.js:254` | Relays (10 Hz from host) |
| `stat_sync` | `player.gd:337,384,411-413` | `server.js:244` | **Writes `p[msg.stat] = msg.val`**, relays |
| `chat` | `chat_box.gd:55`, `player.gd:414,441`, `monster.gd:303` | `server.js:259` | Relays to **all** including sender |
| `roll` | `player.gd:274` | `server.js:272` | Relays with `id` |
| `pk_toggle` | `game_state.gd:231` | `server.js:277` | Records `is_pk`; relays to all |
| `player_died` | `player.gd:435` | `server.js:285` | PK loot roll, then relays |
| `stat_allocate` | `network_manager.gd:459` | `server.js:163` | `db.allocateStat`, replies `stat_allocated` |
| `item_pickup` | `network_manager.gd:483` | `server.js:185` | `db.addInventoryItem`, replies `inventory_sync` |
| `item_use` | `network_manager.gd:500` | `server.js:200` | `db.useInventoryItem`, replies `item_used` |

Anything unrecognised hits `default:` (`server.js:314`) and is relayed
verbatim — the server is an open relay for arbitrary JSON.

## Server → client

| `type` | Sent from | Client handler | Status |
|---|---|---|---|
| `welcome` | `server.js:120` | `network_manager.gd:152` | ✅ assigns `local_id`, `is_room_host` |
| `auth_success` | `server.js:137,153` | `:157` | ✅ loads character, spawns player |
| `auth_error` | `server.js:134,150` | `:186` | ✅ |
| `stat_allocated` | `server.js:167` | `:190` | ✅ |
| `inventory_sync` | `server.js:189` | `:200` | ✅ |
| `item_used` | `server.js:204` | `:204` | ✅ |
| `host_promoted` | `server.js:357`, `:239` | `:210` | ✅ |
| `host_revoked` | `server.js:234` | `:214` | ✅ added 2026-09-05 — demotes a client that held authority without joining |
| `existing_players` | `server.js:226` | `:214` | ✅ |
| `player_join` | relay | `:230` | ✅ |
| `player_leave` | `server.js:344` | `:249` | ✅ |
| `move` | relay | `:255` | ✅ |
| `stat_sync` | relay | `:267` | ⚠️ only `level`/`hp`/`max_hp` applied — `xp` is sent (`player.gd:186`) and dropped |
| `monsters_sync` | relay | `:288` | ✅ (ignored when `is_room_host`) |
| `attack` | relay | `:308` | ✅ |
| `chat` | `server.js:299`, relay | `:322` | ✅ |
| `monster_hit` | relay | `:328` | ✅ |
| `error_msg` | `server.js:179,194` | — | ❌ **no handler** |
| `loot_dropped` | `server.js:297` | — | ❌ **no handler** |
| `roll` | relay `server.js:273` | — | ❌ **no handler** |
| `pk_toggle` | relay `server.js:282` | — | ❌ **no handler** |
| `player_died` | relay `server.js:310` | — | ❌ **no handler** |
| `take_damage` | relay `server.js:265` | — | ❌ no handler, and no client ever sends it |
| `heal` | relay `server.js:266` | — | ❌ no handler, and no client ever sends it |

## Mismatches, in plain terms

Seven server→client types are broadcast and then silently dropped. Each is a
feature that half-exists:

- **`roll`** — remote players' dodge rolls are transmitted but never
  rendered. Other players see no roll animation and no i-frame cue.
- **`pk_toggle`** — a player flipping PK on is broadcast, and the server even
  records `is_pk` (`server.js:279-281`), but no client reacts. The `[PK]`
  nameplate prefix is gated on `is_local` (`player.gd:268`), so **PK status is
  only ever visible to the player who enabled it**.
- **`player_died`** — remote deaths are not shown; the victim's client hides
  its own node (`player.gd:236`) and everyone else keeps a live-looking body
  until `stat_sync hp` happens to arrive.
- **`loot_dropped`** — the PK-death item drop never materialises for anyone.
  It is doubly dead: the handler that emits it crashes first (see below).
- **`error_msg`** — failed stat allocation and failed item pickup fail
  silently in the UI.

**`take_damage` and `heal` are dead on both ends**: the server has `case`
arms for them (`server.js:265-266`) but no client ever sends either type.
Damage propagates instead through `stat_sync hp` (`player.gd:339-343`).

## Identity stamping is inconsistent

The server overwrites the sender id on `move`, `stat_sync`, `player_join`,
`attack`, `roll`, `pk_toggle` and `player_died` — so those cannot be spoofed.

It does **not** stamp `chat`: `msg.sender` is relayed exactly as the client
supplied it (`server.js:259-262`). See [security-notes.md](security-notes.md).

## Monster addressing

Both `monster_hit` and `monsters_sync` identify a monster by its **index in
the `Monsters` container** (`monster.gd:264` sends `get_index()`;
`network_manager.gd:296-298` and `:335-336` index back into
`monsters.get_child(idx)`).

There is no stable monster id anywhere in the protocol. Correctness depends
entirely on every client having spawned the identical monster list in the
identical order — which `world.gd:23-40` does deterministically today, but
which nothing enforces or verifies.
