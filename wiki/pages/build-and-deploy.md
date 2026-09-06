# Build and Deploy

## Local development

```powershell
cd server; npm install; cd ..
node server/server.js
```

Then open `http://localhost:8080` in two tabs. One process serves both the
game files and the WebSocket endpoint — see [server-js.md](server-js.md).

`npm start` is equivalent. **`npm run dev` and `npm run serve` are broken** —
see [known-gaps.md](known-gaps.md) G7 and [serve-web-js.md](serve-web-js.md).

## Building the web export

```powershell
powershell -ExecutionPolicy Bypass -File tools/build_web.ps1
```

Chains `setup_godot.ps1` and `setup_templates.ps1` when needed, then exports
the `"Web"` preset from `export_presets.cfg` into `dist/`:
`index.html`, `index.js`, `index.wasm`, `index.pck`, plus
`godot_web_rpg_itch.zip`.

## The stale-build trap

**`dist/` is what the browser runs, not `scripts/`.** Editing GDScript changes
nothing at `localhost:8080` until `tools/build_web.ps1` (or the raw
`--export-release "Web"` command above) regenerates `dist/index.pck`.

This bit us on 2026-09-05: a respawn fix looked broken in the browser purely
because the `.pck` was 18 hours old.

Compounding it, the exported filenames are stable (`index.pck`, `index.wasm`,
`index.js`), so browsers cache them aggressively. `server.js:92` now sends
`Cache-Control: no-cache, must-revalidate` for this reason — before that, even
a correct rebuild could be masked by the cache and needed a hard refresh.

Two habits worth keeping:

- Rebuild after **any** GDScript or scene change before testing in the browser.
- Restart `node server/server.js` after any change to `server/` — the running
  process holds the old code.

## The single-threaded export decision

The export uses Godot 4.3's **nothreads** web template —
`setup_templates.ps1` checks for `web_nothreads_release.zip` specifically.

That choice is what lets the game run on any static host: a threaded
WebAssembly build needs `SharedArrayBuffer`, which requires
`Cross-Origin-Opener-Policy: same-origin` and
`Cross-Origin-Embedder-Policy: require-corp`, and most static hosts (itch.io
included) will not set those. The single-threaded build has no such
requirement.

**But `server.js:85-86` sets both headers anyway**, contradicting the README's
claim that they are unnecessary. Harmless today because everything is
same-origin, and it would break the moment assets moved to a CDN — the server
never sets the matching `Cross-Origin-Resource-Policy`. See
[known-gaps.md](known-gaps.md) G10.

## How the client finds the server

There is no configuration step, because
[`lobby_ui.gd:39-44`](lobby-ui.md) derives the socket URL from the page it was
served from:

```gdscript
var host = JavaScriptBridge.eval("window.location.host")
var protocol = JavaScriptBridge.eval("window.location.protocol")
var ws_proto = "wss://" if str(protocol) == "https:" else "ws://"
```

So an HTTPS deploy automatically gets `wss://`, and localhost gets
`ws://`. Off the web, or if the eval returns empty, it falls back to
`ws://127.0.0.1:8080`.

This is why the single-port design matters: game and socket share an origin,
so detection is a one-liner and no build-time server address is baked in.

## Deployment targets

**Render (or any Node host)** — root directory `server`, build
`npm install`, start `node server.js`. The service must serve `dist/`, so
`dist/` has to be present in the deployed tree.

> `dist/` is **not** gitignored, but it is also **not committed** — it sits
> untracked (~43 MB of build output). If the repo is deployed straight from
> git, the build output will not be there and every request will 404 —
> `/health` will still answer, which makes this fail in a confusing way.
>
> So decide deliberately: build on the host, or commit `dist/` and accept
> ~40 MB of binary churn per rebuild. An earlier revision of this page claimed
> `dist/` was gitignored; that was wrong.

**itch.io** — upload `dist/godot_web_rpg_itch.zip` as an HTML project, tick
"play in browser", viewport 1024×576. Here itch serves the files and
`server.js` is not involved, so the COOP/COEP headers it sets do not apply at
all. Multiplayer then needs a separately hosted server, entered as a `wss://`
address in the lobby.

**Address entry caveat**: `start_client` appends `:8080` to any address with
no port and defaults the scheme to `ws://` (`network_manager.gd:79-83`). A
bare cloud hostname therefore becomes `ws://host:8080`, not
`wss://host:443` — cloud addresses must be typed with an explicit `wss://`
prefix.

## Persistence in deployment

SQLite lives at `server/data/rpg.db`, overridable with `DB_PATH`
(`db.js:17`). On hosts with ephemeral filesystems — Render's free tier
included — that file is lost on every restart, taking all accounts with it.
A persistent volume or a different backend is needed for anything real.

Character progress is additionally written **only on clean disconnect**
([known-gaps.md](known-gaps.md) G12), so a restart also loses any progress
made since login even when the file survives.

## Related

- [tools.md](tools.md) — the build scripts
- [server-js.md](server-js.md) · [lobby-ui.md](lobby-ui.md)
- [testing.md](testing.md)
