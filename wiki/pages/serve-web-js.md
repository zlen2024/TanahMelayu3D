# `server/serve_web.js`

Node.js · 68 LOC · **superseded and effectively dead.**

A standalone static file server for `dist/`, from before
[`server.js`](server-js.md) was unified to serve both files and WebSockets on
a single port.

## Evidence that it is dead

- `code2graph module-deps` over `server/` reports exactly one edge:
  `server.js -> db.js`. Nothing imports this file.
- A repo-wide search for `serve_web` finds only two hits, both npm scripts in
  `package.json:8-9`.
- Its entire job is a strict subset of `server.js:36-92`. The `MIME_TYPES` map
  (`:13-24` vs `server.js:16-28`) and the request handler are near-duplicates.

## What it does not have

Compared to `server.js`, this file lacks the `/health` endpoint, the CORS
headers, the COOP/COEP headers, and — most importantly — any WebSocket
handling at all. A client served by it can load the game but cannot connect
to multiplayer unless a separate `server.js` is also running on another port.

That two-process arrangement is what the `dev` npm script attempts, and it
does not work (see below).

## Both npm scripts referencing it are broken

`package.json:8-9`:

```json
"serve": "node serve_web.js",
"dev": "node server.js & node serve_web.js"
```

- **`dev`** starts both processes, but `server.js` binds `PORT || 8080`
  (`server.js:13`) and `serve_web.js` binds `WEB_PORT || 8080`
  (`serve_web.js:10`). With neither variable set they collide and the second
  fails with `EADDRINUSE`.
- The `&` is POSIX background syntax and does not background on `cmd.exe` —
  and this is a Windows-first project, where every other tool is PowerShell.
- **`serve`** works in isolation but produces a game that cannot reach a
  server.

## Recommendation

Delete the file along with the `serve` and `dev` scripts. The README documents
only `node server/server.js`, so nothing user-facing depends on either.

If it is kept deliberately — as a way to serve `dist/` without touching the
database — say so in a comment and give it a non-colliding default port.

## Related

- [server-js.md](server-js.md) — the replacement
- [decisions.md](decisions.md) D3 — the unification
- [known-gaps.md](known-gaps.md) G7, G8
