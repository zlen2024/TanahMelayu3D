# `scripts/ui/chat_box.gd`

extends `Control` · 77 LOC.

The chat window: a `RichTextLabel` log, a `LineEdit`, a send button and a
minimise toggle.

## Sending

`_on_text_submitted` (`:51`) strips the text, sends a `chat` packet with
`sender` set to `GameState.local_player_name` (`:54-60`), and clears the
input.

In solo mode nothing is echoed back by a server, so it emits
`chat_received` locally instead (`:61-62`).

`release_focus()` is called unconditionally at `:64` — even on an empty
submit — which is what lets Enter-on-empty close the chat rather than trapping
focus.

## Receiving

`_on_chat_received(sender, message, is_system)` (`:66`) plays a sound and
appends one of three BBCode-formatted lines depending on whether the message
is a system message, your own, or another player's (`:68-73`).

The signal is emitted from four places — the server relay
(`network_manager.gd:326`), join and leave notices
(`network_manager.gd:243`, `game_state.gd:110`), and the solo echo above.

## Two problems in the render path

`:69-73` interpolates both `sender` and `message` into a BBCode string:

```gdscript
chat_log.append_text("[color=#aed6f1][b]%s[/b]:[/color] %s\n" % [sender, message])
```

1. **Neither field is escaped**, so any BBCode a player types is interpreted
   as markup rather than shown as text.
2. **`sender` is never verified.** The server relays `chat` without stamping
   the sender id, unlike every other player message (`server.js:259-262`), and
   `is_sys` is likewise client-supplied — so a client can post as `SYSTEM` in
   the privileged orange style.

Together these are a convincing fake-system-message primitive. Detail and fix
shape in [security-notes.md](security-notes.md) S3 and S4.

## Focus interaction

`_unhandled_input` (`:26`) handles the `chat_toggle` action (Enter): it
un-minimises, then toggles focus on the input, and marks the event handled
(`:27-34`) so it does not fall through to gameplay.

Movement locking is wired differently here than in the other panels. Rather
than calling `GameState.set_ui_modal_open()` from an open/close method,
`_ready()` binds it to the `LineEdit`'s own focus signals (`:23-24`):

```gdscript
message_input.focus_entered.connect(func(): GameState.set_ui_modal_open(true))
message_input.focus_exited.connect(func(): GameState.set_ui_modal_open(false))
```

This matters because `player.gd` polls `Input.is_action_pressed` in
`_physics_process` (`player.gd:181-184`), and polling ignores UI focus
entirely — a focused `LineEdit` does not stop WASD on its own. The modal
counter is what actually blocks it (`player.gd:137-140`).

Tying it to focus rather than to visibility is the right call for chat
specifically: the window can stay open and readable while the player moves,
and the lock engages only while the caret is in the input.

[`inventory_ui.gd`](inventory-ui.md) and [`stats_panel.gd`](stats-panel.md)
use the visibility-based variant instead, since those panels should lock
movement whenever they are open.

## Related

- [game-state.md](game-state.md) — `chat_received`, `is_ui_focused`
- [security-notes.md](security-notes.md) — S3, S4
- [wire-protocol.md](wire-protocol.md) — the `chat` message
