# `scripts/ui/stats_panel.gd`

extends `PanelContainer` · 112 LOC. Child of the [HUD](hud.md) scene
(`hud.gd:23`).

Attribute allocation (STR/VIT/AGI/INT) and the PK-mode toggle. Opened with
`C` (`:41-44`) or the HUD's Stats button.

## Allocation

Four buttons, each a one-line lambda to
`NetworkManager.send_allocate_stat(...)` (`:25-28`):

```gdscript
str_btn.pressed.connect(func(): NetworkManager.send_allocate_stat("str"))
```

The panel does **not** check `unspent_stat_points` before sending — it always
fires. Validation lives at the other end: the server's
`db.allocateStat` rejects with `No stat points available.`
(`db.js:222-224`), and the solo branch checks
`GameState.unspent_stat_points > 0` (`network_manager.gd:442`).

That means a networked click with zero points produces an `error_msg` reply
that **no client handles** ([known-gaps.md](known-gaps.md) G2) — the button
appears to do nothing and no message is shown.

`_refresh_ui()` (`:57`) redraws values from `GameState` and is connected to
`stats_updated`, so the display updates when the server confirms.

## Modal focus

`set_open()` (`:49`) calls `GameState.set_ui_modal_open(visible)` with the
same guard as [`inventory_ui.gd`](inventory-ui.md) — early-return when the
state is unchanged (`:50-51`), keeping the modal counter balanced so player
movement is restored correctly.

## PK toggle

`pk_btn` is created in `_ready()` (`:31-37`), not authored in the scene, and
inserted second-from-last in the `VBox` (`:37`).

`_on_pk_btn_pressed()` (`:105`) resolves the local player's level by scanning
the `players` group:

```gdscript
for p in get_tree().get_nodes_in_group("players"):
    if p.get("is_local") == true:
        local_player_level = p.get("level")
        break
```

then calls `GameState.toggle_pk_mode(level)`, which gates on level 10
(`game_state.gd:227`).

**This is the pattern [`inventory_ui.gd:148`](inventory-ui.md) should have
used** and did not — it hardcodes level 1 instead, which is why no
level-gated item can be equipped. The correct approach already exists in the
codebase, six lines away.

`toggle_pk_mode` returns `false` when under level 10, but `_on_pk_btn_pressed`
ignores the return value and calls `_refresh_ui()` unconditionally (`:111`).
The refresh reads the unchanged `is_pk_enabled`, so the button silently stays
OFF with no explanation to the player.

## Related

- [game-state.md](game-state.md) — attributes and `toggle_pk_mode`
- [network-manager.md](network-manager.md) — `send_allocate_stat` and its
  solo/networked split
- [db-js.md](db-js.md) — server-side allocation
