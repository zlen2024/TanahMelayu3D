# `server/server.js`

Node.js · 377 LOC · one runtime dependency (`ws`). Entry point:
`npm start` → `node server.js`.

Three jobs in one process, on **one port** (`PORT || 8080`, `:13`):

1. Static host for the exported game in `dist/`
2. WebSocket relay for gameplay
3. Auth and persistence front-end over [`db.js`](db-js.md)

The single-port design is deliberate and is what makes the deploy story work —
the client derives its socket URL from the page it was served from
([`lobby_ui.gd:39-44`](lobby-ui.md)), so no configuration is needed on Render
or a dev tunnel. It supersedes [`serve_web.js`](serve-web-js.md).

## HTTP layer — `:36-92`

- Wide-open CORS (`:37-39`), plus an `OPTIONS` short-circuit.
- `/health` (`:49-61`) returns JSON with client count, active players and the
  current `host_id`. Useful for uptime checks, and the network test suite
  asserts on it (`test_server_network.js:47`).
- Everything else maps to a file under `DIST_DIR`, with `/` rewritten to
  `/index.html` (`:63-65`).

Two things to know about the static path:

- The traversal guard `filePath.startsWith(DIST_DIR)` (`:69`) is a prefix
  compare without a separator, so sibling directories sharing the `dist`
  prefix pass it — see [security-notes.md](security-notes.md) S6.
- `Cross-Origin-Opener-Policy: same-origin` and
  `Cross-Origin-Embedder-Policy: require-corp` are set on every file response
  (`:85-86`), **contradicting the README**, which sells the single-threaded
  export as needing neither. See [known-gaps.md](known-gaps.md) G10.

## WebSocket layer — `:95-368`

`WebSocketServer({ server })` shares the HTTP server, which is what puts both
protocols on one port.

State is three module-level values (`:31-33`): a `players` Map keyed by client
id, an incrementing `nextClientId` starting at 100, and `hostClientId`.

Client ids start at 100 and are never reused. `local_id` defaults to 1 on the
client (`network_manager.gd:22`), so ids below 100 mean "solo/guest" and ids
at or above 100 mean "server-assigned" — an implicit convention nothing
enforces.

## Host election

On connect, the first client with `hostClientId === null` is elected
(`:111-114`) and told via `welcome.is_host` (`:120-124`).

On disconnect of the host, the first remaining open client is promoted and
sent `host_promoted` (`:352-362`). There is a window between the two where no
client broadcasts monster state; monsters simply keep running their local
simulations until the new host takes over.

## Message dispatch — `:130-317`

A `switch` on `msg.type`. Three categories:

- **Auth / persistence** (`register`, `login`, `stat_allocate`,
  `item_pickup`, `item_use`) — call into [`db.js`](db-js.md) and reply
  directly to the sender.
- **Relayed with identity stamping** — `player_join`, `move`, `stat_sync`,
  `attack`, `roll`, `pk_toggle`, `player_died` all get `msg.id` or
  `msg.sender_id` overwritten with the true `clientId` before broadcast.
- **Relayed as-is** — `chat`, `monsters_sync`, and the `default` arm
  (`:314-316`), which forwards **any unrecognised JSON** to every other
  client.

Full table in [wire-protocol.md](wire-protocol.md).

`broadcast(data, excludeWs)` (`:97`) serialises once and sends to every open
client except the excluded one. `chat` is the one message broadcast to
*everyone* including the sender (`:261`), which is why the client does not
echo its own chat locally except in solo mode.

## Confirmed bug: the PK death path throws

`:291` calls `db.getUserInventory(ws.userId)`. **That function does not
exist** — `db.js` defines and exports `getFullInventory`, not
`getUserInventory`.

Any death with `msg.is_pk` and `msg.attacker_id` truthy therefore raises a
`TypeError`, which the enclosing `try` swallows (`:318-320`) with a message
that misreports it as a parse error. Execution never reaches the
`broadcast(msg, ws)` at `:310`, so **PK deaths are not relayed at all** — no
loot drop, no system message, no death notification.

Detail in [known-gaps.md](known-gaps.md) G1.

## Persistence timing

`db.saveCharacter` has exactly one call site: the `close` handler
(`:323-342`). Progress is written only on a clean disconnect, so a crash or
container restart loses everything since login ([known-gaps.md](known-gaps.md)
G12).

What it writes comes from the in-memory `players` entry — which the client
populates through `stat_sync` with **no validation** (`:248`). That is the
mechanism behind [security-notes.md](security-notes.md) S1.

Inventory is different: it writes through immediately on every pickup and use.

## Related

- [db-js.md](db-js.md) — the persistence layer
- [wire-protocol.md](wire-protocol.md) · [security-notes.md](security-notes.md)
- [serve-web-js.md](serve-web-js.md) — the file this replaced
