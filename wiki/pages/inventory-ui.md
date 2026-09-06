# `scripts/ui/inventory_ui.gd`

extends `PanelContainer` · 169 LOC. A child of the
[HUD](hud.md) scene (`hud.gd:24`).

The 16-slot bag plus the three-slot equipment paperdoll.

## Structure

`_ready()` (`:15`) hides itself, connects `inventory_updated` and
`equipped_gear_updated` from [`GameState`](game-state.md), builds the
paperdoll, then creates **16 buttons in code** (`:24-33`) — the grid is not
authored in the scene.

Each button gets three connections, all capturing `slot_idx` in a lambda:
`pressed` → `_on_slot_clicked`, `gui_input` → `_on_slot_gui_input`,
`mouse_entered` → `_on_slot_hover`.

`_build_paperdoll_ui()` (`:37`) likewise builds the weapon/armour/accessory
buttons at runtime and appends them to the `VBox`.

## Opening and closing

`toggle()` / `set_open()` (`:75-85`) and `B` or `I` via `_unhandled_input`
(`:70-73`).

`set_open` is the important one: it calls
`GameState.set_ui_modal_open(visible)` (`:82`), which increments the modal
counter that [`player.gd`](player.md) checks before accepting movement input.
The early return when `visible == open` (`:79-80`) keeps that counter balanced
— without it, a redundant open would leak a count and permanently lock
movement.

## Slot interaction

`_on_slot_clicked` (`:140`) branches on `slot_type`:

- **Gear** (`weapon`/`armor`/`accessory`) → `GameState.equip_item(...)`
- **Anything else** → `NetworkManager.send_item_use(slot_idx)`

Right-click (`_on_slot_gui_input`, `:159`) binds the item to a quick slot —
`[Q]` if free, otherwise `[E]` (`:163-168`). There is no way to *unbind* a
quick slot through the UI, and no way to choose `[E]` while `[Q]` is empty.

Hover (`:132`) writes a one-line description into `info_label`.

## Bug: equip level is hardcoded to 1

`:148`:

```gdscript
var success = GameState.equip_item(slot_idx, 1) # Checked against level
```

The literal `1` is passed as `player_level`. `GameState.equip_item` compares
it against the item's `lvl_req` (`game_state.gd:167-169`), so **every item
requiring level 2 or higher can never be equipped**.

Five of the thirteen items in [`ItemDatabase`](item-database.md) are affected
— and they are precisely the rare drops:

| Item | `lvl_req` | Dropped by |
|---|---|---|
| `sword_steel` | 5 | Magma Slime |
| `bow_composite` | 5 | Magma Slime |
| `amulet_agility` | 5 | King Slime |
| `wand_archmage` | 6 | King Slime |
| `armor_king` | 10 | King Slime |

So **every boss reward in the game is unequippable**, and the UI reports
"Cannot equip … (Level/Class mismatch)" (`:153`) regardless of the player's
actual level. The trailing comment shows the intent was to pass the real
level.

*Fix shape:* the local player node is reachable the same way
[`stats_panel.gd`](stats-panel.md) does it (`stats_panel.gd:106-110`) — scan
the `players` group for `is_local` and read `.level`.

## Rarity colouring

`_refresh_slots()` (`:106`) and `_on_equipped_updated()` (`:90`) tint buttons
via [`ItemDatabase.get_rarity_color`](item-database.md) — the only consumer of
that function.

## Related

- [game-state.md](game-state.md) — inventory, equipment, quick slots
- [item-database.md](item-database.md) · [hud.md](hud.md)
- [known-gaps.md](known-gaps.md) — G14
