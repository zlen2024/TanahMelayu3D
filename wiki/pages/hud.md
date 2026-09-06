# `scripts/ui/hud.gd`

extends `CanvasLayer` · 209 LOC.

The in-game overlay: HP/energy/stamina/XP bars, level, online roster, skill
bar, quick-slot hotbar, and the toggles for
[`StatsPanel`](stats-panel.md) and [`InventoryUI`](inventory-ui.md), both of
which are children of this scene (`:23-24`).

## Half authored, half built in code

`@onready` paths (`:5-24`) bind 17 nodes from the scene. But three UI
elements are constructed at runtime:

- **`_build_stamina_bar_ui()`** (`:61`) — creates the STA label, bar and
  counter, then splices the row in **immediately after** the energy row using
  `move_child(hbox, energy_idx + 1)` (`:88-90`).
- **`_build_quick_slots_ui()`** (`:92`) — creates the `[Q]` and `[E]` buttons
  and inserts them at the **start** of the skill bar (`:111-112`).

Both are load-bearing: `stamina_bar`, `stamina_label`, `quick_q_btn` and
`quick_e_btn` are plain `var`s (`:26-29`), null until these run. Every method
touching them null-checks first (`:141-146`).

This split means the scene file alone does not describe the HUD — a reader
looking only at `main.tscn` will not find the stamina bar or the hotbar.

## Finding the local player

The HUD cannot connect to the player's signals at `_ready()`, because the
player node does not exist yet — it is spawned later by
[`NetworkManager`](network-manager.md) after auth succeeds.

The solution (`:55-59`) is to subscribe to the container:

```gdscript
players_container.child_entered_tree.connect(_on_player_spawned)
```

`_on_player_spawned` (`:114`) filters for `is_local == true` and then connects
the four player signals — `stats_changed`, `energy_changed`, `stamina_changed`
and `skill_cooldown_started` — caching the node in `local_player_node`.

That cached reference is what the skill buttons call into (`:47-49`), each
guarded by `if local_player_node`.

**It is never cleared.** If the local player node is freed — `disconnect_network()`
frees every child of the `Players` container (`network_manager.gd:117-119`) —
`local_player_node` keeps pointing at the freed node. The skill-button lambdas
check only that it is non-null, not `is_instance_valid`, so pressing a skill
button after disconnecting and reconnecting can touch a freed object.

## GameState subscriptions

`_ready()` (`:34-39`) connects five: `player_registered`,
`player_unregistered`, `player_stat_changed`, `stats_updated` and
`quick_slots_updated`, plus `pk_mode_changed` via a lambda.

`_on_players_changed` and `_on_stat_changed` (`:187-191`) both take throwaway
arguments and just call `_refresh_player_list()` — the signals carry payloads
the HUD does not use.

## Roster

`_refresh_player_list()` (`:193`) rebuilds the whole `ItemList` from
`GameState.players` on every registration, deregistration and stat change.
With `stat_sync` arriving on every HP change of every player, that is a full
list rebuild per damage tick. Fine at POC scale; the first thing to look at if
the HUD ever stutters.

## Skill cooldowns

`_on_skill_cooldown(idx, duration)` (`:166`) is driven by the player's
`skill_cooldown_started` signal, which each class strategy emits when a skill
fires (e.g. `warrior_class.gd:47`).

`_update_skill_labels()` (`:172`) refreshes button text from
`GameState.hero_class`, so the labels follow the class.

## Related

- [player.md](player.md) — the signal source
- [game-state.md](game-state.md) — roster and quick slots
- [stats-panel.md](stats-panel.md) · [inventory-ui.md](inventory-ui.md)
