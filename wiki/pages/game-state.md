# `scripts/network/game_state.gd`

**Autoload** (`GameState`) · extends `Node` · 236 LOC.

The client-side model of the session, and the signal bus the UI listens on.
Holds the local character's attributes, inventory, equipped gear and quick
slots, plus a roster of every known player.

## Why it is a bus, not just a store

12 signals (`:6-17`), and almost every UI script connects to some of them:

| Signal | Emitted from | Consumed by |
|---|---|---|
| `player_registered` / `player_unregistered` | `:101`, `:109` | [`hud.gd`](hud.md) roster |
| `chat_received` | `:110`, `:114`, `network_manager.gd:243,326` | [`chat_box.gd`](chat-box.md) |
| `player_stat_changed` | `:120` | [`hud.gd`](hud.md) |
| `auth_succeeded` / `auth_failed` | `network_manager.gd:184,188,422` | [`lobby_ui.gd`](lobby-ui.md) |
| `inventory_updated` | `:73`, `:176`, `:197` | [`inventory_ui.gd`](inventory-ui.md) |
| `stats_updated` | `:84`, `:177`, `:198` | [`stats_panel.gd`](stats-panel.md), [`player.gd`](player.md) |
| `equipped_gear_updated` | `:175`, `:196` | [`inventory_ui.gd`](inventory-ui.md), [`player.gd`](player.md) |
| `quick_slots_updated` | `:209` | [`hud.gd`](hud.md) |
| `pk_mode_changed` | `:230` | [`player.gd`](player.md) nameplate |
| `system_banner` | — | **never emitted** |

`system_banner` (`:10`) is declared and unused — no emitter, no listener.

Because signals decouple emitter from receiver, this file is the hub of the
client and almost none of that shows up as a static edge.

## The four `@rpc` decoys

`register_player_info` (`:92`), `unregister_player` (`:105`), `send_chat`
(`:113`) and `sync_player_stat` (`:117`) all carry
`@rpc("any_peer", "call_local", "reliable")`.

**No RPC ever happens.** There are zero `.rpc()` / `.rpc_id()` call sites in
the repository; all four are invoked as ordinary function calls. `send_chat`
has no callers at all. This is leftover from an abandoned high-level
multiplayer design — the full story is in [decisions.md](decisions.md) D1.

Treat the annotations as noise when reading this file.

## Character attributes

`stat_str`, `stat_vit`, `stat_agi`, `stat_int` and `unspent_stat_points`
(`:26-30`) are the source of truth the client uses when recomputing derived
stats. `player.gd:89-107` feeds them into
[`CombatFormula.calc_player_stats`](combat-formula.md) together with equipment
bonuses.

`load_character_stats(data)` (`:75`) fills them from a server `character`
payload, defaulting `max_energy` to `30 + stat_int * 5` (`:82`) when absent —
one of the three disagreeing energy formulas noted in
[known-gaps.md](known-gaps.md) G11.

## Inventory

A fixed 16-slot array, null-padded, initialised in `_ready()` (`:59-61`) and
re-initialised by `init_inventory()` (`:63`) from the server's
`inventory_sync`. Items are placed **by their `slot` field**, not by array
order (`:69-72`), so server slot indices are authoritative.

## Equipment

`equipped_gear` (`:42`) holds three slots — `weapon`, `armor`, `accessory`.

`equip_item(slot_idx, player_level)` (`:150`) validates in four steps before
swapping: the item exists, its `slot_type` is a known slot, its `class_req`
matches `hero_class` or is `any`, and `player_level` meets `lvl_req`
(`:157-169`). The swap itself puts the previously equipped item back into the
vacated inventory slot (`:171-173`), so equipping never loses an item.

`get_equipment_bonus(stat_name)` (`:141`) sums a named stat across all three
slots. `player.gd:92-97` calls it for `atk`, `def`, `hp` and `mp`.

**Equipment is client-only.** Nothing sends the equipped set to the server and
`db.js` has no column for it, so what you wear is lost on disconnect while
what you carry is persisted.

`unequip_slot` (`:180`) refuses when the bag is full (`:190-191`) rather than
dropping the item — correct, and it returns `false` so the UI can report it.

## Quick slots

Two slots (`:47`), bound to Q and E. `assign_quick_slot` (`:202`) stores a
**reference to the item dictionary**, not a slot index.

`use_quick_slot` (`:211`) therefore has to search the inventory by item `id`
to recover the current index before calling `NetworkManager.send_item_use(i)`
(`:219-223`). If the stored item is no longer in the bag the loop simply falls
through and nothing happens — silent, but not incorrect.

## UI focus

`ui_modal_open_count` (`:50`) with `set_ui_modal_open()` / `is_ui_focused()`
(`:131-138`) is a **counter, not a boolean**, so two overlapping panels
release focus correctly.

[`player.gd`](player.md) checks `is_ui_focused()` before handling movement and
attack input, which is what stops WASD from driving the character while the
user is typing in chat or clicking through the inventory.

## PK mode

`toggle_pk_mode(player_level)` (`:226`) gates on level 10, flips
`is_pk_enabled`, emits `pk_mode_changed`, and sends a `pk_toggle` packet.

The packet is broadcast by the server and **no client handles it** — so
another player's PK status is never visible to you. The `[PK]` nameplate
prefix is gated on `is_local` (`player.gd:268`). See
[known-gaps.md](known-gaps.md) G2.

## Related

- [network-manager.md](network-manager.md) — the writer of most of this state
- [player.md](player.md) — the main consumer
- [decisions.md](decisions.md) — D1, the `@rpc` story
