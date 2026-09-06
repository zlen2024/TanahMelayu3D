# `scripts/ui/lobby_ui.gd`

extends `Control` · 128 LOC.

The entry screen: username, password, class selector, server address, and
three buttons — Login, Register, Guest.

## Auto-connect

`_ready()` (`:16`) does more than wire buttons. It **connects to the server
immediately** (`:51` → `_auto_connect_ws`), before the player has typed
anything, so that the socket is warm by the time they press Login.

`is_socket_ready` (`:14`) tracks that, set by `_on_connected` (`:112`).

## Web host detection

`:39-48` uses `JavaScriptBridge` to read the page's own location when running
as a web export:

```gdscript
var host = JavaScriptBridge.eval("window.location.host")
var protocol = JavaScriptBridge.eval("window.location.protocol")
var ws_proto = "wss://" if str(protocol) == "https:" else "ws://"
address_input.text = ws_proto + str(host)
```

This is what makes the single-port design work in practice — the client
derives its WebSocket URL from wherever it was served, so a deploy to Render
needs no configuration. It correctly upgrades to `wss://` on HTTPS pages, and
falls back to `ws://127.0.0.1:8080` off the web or when the eval returns
empty (`:45-48`).

Note the guard checks `str(host) != "null"` — a string comparison, because
`JavaScriptBridge.eval` returns a Godot `Variant` whose null case can
stringify that way.

## The three entry paths

| Button | Handler | Calls |
|---|---|---|
| Login | `_on_login_pressed` (`:67`) | `NetworkManager.send_login(u, p)` |
| Register | `_on_register_pressed` (`:79`) | `NetworkManager.send_register(u, p, class, skin)` |
| Guest | `_on_guest_pressed` (`:93`) | `NetworkManager.start_guest(class)` |

Guest bypasses the socket entirely — `start_guest` sets `is_solo_mode` and
builds character state locally (`network_manager.gd:395`), so a guest is a
single-player session even when the server is reachable.

`_get_selected_class()` (`:61`) maps the dropdown index to
`"warrior"`/`"mage"`/`"archer"`. The dropdown labels also document each
class's stat focus (`:22-24`), which is the only place in the UI that
information appears.

## Outcome handling

`_on_auth_succeeded` (`:103`) hides the lobby. `_on_auth_failed` (`:108`)
shows the server's error string. `_on_connect_failed` (`:117`) and
`_on_disconnected` (`:123`) report transport problems.

The status label is the only feedback channel, and it does double duty for
transport state and auth state.

## Note: credentials are pre-filled

`:18-19`:

```gdscript
username_input.text = "Hero_%d" % randi_range(100, 999)
password_input.text = "123456"
```

A random username and the literal password `123456`, so the POC can be tested
in two browser tabs without typing. Combined with the 3-character minimum in
`db.js:82-84` and no rate limiting, this is fine for local testing and
unacceptable for any public deployment — see
[security-notes.md](security-notes.md) S8.

## Related

- [network-manager.md](network-manager.md) — `start_client`, `start_guest`
- [game-state.md](game-state.md) — `auth_succeeded` / `auth_failed`
- [build-and-deploy.md](build-and-deploy.md) — why host detection matters
