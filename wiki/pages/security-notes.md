# Security Notes

Trust-boundary findings from the 2026-09-05 ingest. **This is a
proof-of-concept**, and several of these are reasonable POC shortcuts rather
than mistakes — but they are written down here so nobody has to rediscover
them, and so none of them reach a public deployment unnoticed.

The trust boundary is a single line: **`server.js` accepts JSON from any
WebSocket client.** There is no schema validation, no rate limiting, and no
session token beyond `ws.userId` held in memory.

---

## S1 — `stat_sync` writes arbitrary keys, and they get persisted

**Confirmed.** `server.js:244-252`:

```js
case 'stat_sync':
  msg.id = clientId;
  if (players.has(clientId)) {
    const p = players.get(clientId);
    p[msg.stat] = msg.val;      // key AND value both client-controlled
  }
  broadcast(msg, ws);
```

`msg.stat` is an unvalidated client string and `msg.val` an unvalidated
client value. That object is then read back on disconnect and written to
SQLite (`server.js:328-341`), which reads exactly the fields an attacker can
set — `level`, `xp`, `str`, `vit`, `agi`, `int`, `stat_points`, `hp`,
`max_hp`, `energy`, `max_energy`.

So a modified client sending `{"type":"stat_sync","stat":"level","val":9999}`
before disconnecting has that level **saved to the database**. The same route
sets stat points, which `allocateStat` then honours.

Assigning the literal key `__proto__` is also reachable here. It mutates only
that per-client object's prototype rather than `Object.prototype`, so it is
not a global pollution vector — but it is an unvalidated key write into an
object that is later serialised.

*Fix shape:* allowlist `msg.stat` against the columns `saveCharacter` writes,
and validate `msg.val` is a number in range.

## S2 — `item_pickup` trusts the entire client-supplied item

**Confirmed.** `server.js:185-187` passes `msg.item` straight into
`db.addInventoryItem(ws.userId, msg.item)`. The client decides the item's
`id`, `name`, `type` and `quantity` — `loot_drop.gd:79-85` builds that
dictionary locally and `network_manager.gd:483-486` ships it as-is.

A modified client can mint any item, in any quantity, without a monster ever
dying. Nothing cross-checks the item against `ItemDatabase.ITEMS`
(`item_database.gd:6`), which is the obvious server-side source of truth —
except that it lives in GDScript, so the server has no access to it. That
duplication is the root cause, not the symptom.

## S3 — `chat` is relayed without identity stamping

**Confirmed.** Every other player-identifying message has its id overwritten
by the server. `chat` does not (`server.js:259-262`): `msg.sender` is
whatever the client sent.

Any client can post as any name, **including `SYSTEM`** — and `is_sys: true`
is likewise client-supplied, so the impersonation renders in the privileged
system style (`chat_box.gd:69`).

## S4 — Chat messages are rendered as BBCode

**Confirmed.** `chat_box.gd:66-73` passes the message body through
`append_text()` on a `RichTextLabel` with BBCode enabled:

```gdscript
chat_log.append_text("[color=#aed6f1][b]%s[/b]:[/color] %s\n" % [sender, message])
```

Neither `sender` nor `message` is escaped, so both are interpreted as markup.
A message containing `[color=...]`, `[img]`, `[url=...]` or `[font_size=...]`
renders as formatting rather than text. Combined with **S3** this is a
convincing fake-system-message primitive.

Godot's BBCode is not HTML and there is no script execution — the realistic
impact is spoofing and chat-window griefing, not RCE. `[img]` with a remote
path is the one to look at hardest.

*Fix shape:* escape the BBCode in the message body, or use `add_text()` for
the user-controlled portion.

## S5 — `monsters_sync` is relayed from any client, not just the host

**Confirmed.** The server relays `monsters_sync` unconditionally
(`server.js:254-256`) and never checks `clientId === hostClientId`, even
though it is the authority on who the host is.

The client-side guard `if not is_room_host` (`network_manager.gd:289`) stops
a *host* from applying inbound sync, but does nothing to stop a non-host from
**sending** it. Any client can therefore teleport every monster, set their HP,
or mark them all dead on every other client.

## S6 — Static-file path check is a prefix comparison

**Confirmed, low severity.** `server.js:69`:

```js
const filePath = path.join(DIST_DIR, reqPath);
if (!filePath.startsWith(DIST_DIR)) { /* 403 */ }
```

`path.join` normalises away `..`, so traversal *above* the parent is blocked.
But `startsWith` on a path without a trailing separator also accepts **sibling
directories sharing the prefix**: with `DIST_DIR = .../lively-meitner/dist`, a
request for `/../dist-backup/secrets.txt` resolves to
`.../lively-meitner/dist-backup/secrets.txt`, which passes the check.

Exploitable only if such a sibling directory exists. `dist/` is gitignored and
build tooling writes only to `dist/` today.

*Fix shape:* compare against `DIST_DIR + path.sep`, or use
`path.relative(DIST_DIR, filePath)` and reject results starting with `..`.

## S7 — Raw string interpolation in `allocateStat`

**Confirmed as a latent pattern; not currently exploitable.** `db.js:233-238`
is the one SQL statement in the file built by interpolation instead of a
prepared statement:

```js
db.exec(`UPDATE characters SET ${updateCol}, stat_points = stat_points - 1
         WHERE user_id = ${userId}`);
```

`updateCol` comes from a four-way allowlist (`db.js:227-231`), so it is safe.
`userId` is `ws.userId`, set only from a database row id (`server.js:136,152`),
so it is an integer and not client-controlled today.

It is flagged because it is the sole deviation from the parameterised style
used everywhere else in `db.js` — it becomes a real injection the moment
anything else is allowed to influence `userId`.

## S8 — Password policy is effectively absent

**Confirmed, deliberate for a POC.** `db.js:82-84` requires a password of
**3 characters**; usernames need 2 (`db.js:76-78`).

Hashing itself is sound in shape: `crypto.scryptSync(password, salt, 32)` with
a 16-byte per-user random salt (`db.js:70-72`, `:88-89`). Two caveats worth
recording:

- `scryptSync` runs with **default parameters** (N=16384, r=8, p=1) — fine
  for a POC, below current guidance for production.
- Password comparison **is** constant-time — `crypto.timingSafeEqual` over the
  decoded hex buffers. (An earlier revision of this page claimed a plain `===`;
  that was wrong, inferred without reading the comparison.)

There is no rate limiting on `login`, so the 3-character minimum is the real
exposure, not the hash.

## S9 — CORS is fully open

**Confirmed.** `server.js:37-39` sets `Access-Control-Allow-Origin: *` with
all methods and all headers, and the `WebSocketServer` performs no origin
check on upgrade (`server.js:95`, `:106`).

Any web page can open a socket to a deployed server and speak the protocol.
Given S1–S3 and S5, that is the amplifier that makes them cheap to reach.

---

## Not findings

Recorded so a future pass does not re-flag them:

- **`_die` on remote nodes.** A remote player node dying locally does emit a
  `player_died` packet (`player.gd:237`), but the server overwrites
  `msg.victim_id = clientId` (`server.js:286`), so identity cannot be forged
  this way.
- **Kill announcements.** `monster.gd:303` looked like it would spam one chat
  line per client; it is correctly nested inside
  `if killer_id == NetworkManager.local_id:` (`monster.gd:296`). Only the
  killer announces.
- **`max_health` / `current_health` on `Monster`.** These look like a second
  copy of `Entity`'s HP fields but are property aliases with getters and
  setters onto `max_hp` / `current_hp` (`monster.gd:20-25`). No divergence.

## Related

- [wire-protocol.md](wire-protocol.md) — where each of these messages enters
- [known-gaps.md](known-gaps.md) — non-security bugs and limitations
- [db-js.md](db-js.md) · [server-js.md](server-js.md)
