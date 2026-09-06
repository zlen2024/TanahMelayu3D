# `scripts/entities/player.gd`

`class_name Player` · extends [`Entity`](entity.md) · 478 LOC.

The local hero and every remote hero — one script, split by the `is_local`
flag (`:17`). Instantiated only by
`NetworkManager.spawn_player_node()` (`network_manager.gd:340`), which names
the node after the peer id.

## The `is_local` split

Almost every behaviour branches on it:

| | `is_local == true` | `is_local == false` |
|---|---|---|
| Camera | enabled (`:71`) | disabled (`:78`) |
| Movement | keyboard input (`:170`) | lerp to `target_sync_pos` (`:172`) |
| Nameplate tint | cyan (`:72`) | white (`:79`) |
| Stat signals | emitted | suppressed |
| Network sends | yes | mostly no — but see `_die` below |

`_ready()` also wires three `GameState` signals for local players only
(`:79-81`), so equipment changes and stat allocation trigger
`recalculate_stats()`.

## Derived stats

`recalculate_stats()` (`:89`) is the single place stats are computed. It
rebuilds the class strategy, gathers four equipment bonuses from
[`GameState`](game-state.md), and calls
[`CombatFormula.calc_player_stats`](combat-formula.md).

It clamps current HP and energy to the new maxima (`:107-108`), so unequipping
a `+hp` item cannot leave you above your maximum.

Called from `_ready()` (local only), on `stats_updated`, on
`equipped_gear_updated`, and from `network_manager.gd:198` after a server
`stat_allocated`.

## Movement and input

`_physics_process` (`:126`) opens with
[`Entity.process_entity_status`](entity.md) and returns early if dead or
stunned, then ticks the three skill cooldowns (`:131-133`).

For local players it does four things before handing off to
`_handle_local_input`:

1. **UI focus lock** (`:137-140`) — if `GameState.is_ui_focused()`, zero
   velocity and return. This is what stops WASD driving the character while
   chat or a panel has focus.
2. **Energy regen** (`:143-151`) — rate from
   `CombatFormula.calc_energy_regen(stat_int, +mp_regen gear)`.
3. **Stamina regen** (`:154-157`) — flat `stamina_regen_rate`, suppressed
   while rolling.
4. **Health regen** (`:160-168`) — rate from `calc_health_regen(stat_vit, ...)`.

All three regens use a **fractional accumulator** (`energy_regen_accum`,
`health_regen_accum`) and only apply whole points (`:146-149`). That keeps HP
and energy integral without losing sub-point-per-second rates.

`_handle_local_input` (`:174`) reads the four movement actions, normalises,
and flips the sprite plus the attack-area and slash offsets together
(`:191-195`) so the hitbox tracks facing.

## Attack charging

`:200-213`. Holding `attack` accumulates `attack_charge_time`; crossing 0.4 s
**at level 11 or higher** sets `is_charging_attack` and tints the sprite. On
release, ≥0.4 s and level ≥11 runs `_execute_charged_attack()`, otherwise
`_execute_basic_attack()`.

Both delegate to the class strategy (`:297-313`) — see
[hero-class.md](hero-class.md).

> **The README is wrong about this.** It documents "Cast Spell: `Shift` +
> `Spacebar`". In the code, `Shift` is the dodge roll (`:240`) and the
> charged attack is a held `Spacebar` gated on level 11.

## Movement sync

`:223-233` — 20 Hz (`send_sync_timer = 0.05`), and only when actually moving
or when position has drifted more than 2 px from the last sent value
(`:227`). A stationary player sends nothing.

Remote players interpolate toward `target_sync_pos` at `16.0 * delta`
(`:287-288`).

## Dodge roll

`dodge_roll()` (`:256`) costs 25 stamina, sets `is_rolling` and
`is_invulnerable`, tweens a ghost tint, sends a `roll` packet, and clears both
flags after 0.35 s via a timer callback (`:296-300`). While rolling, movement
is locked to `roll_dir` at 1.85× speed (`:175-178`).

`take_damage` returns 0 and shows a "DODGE!" popup while invulnerable
(`:328-331`).

**Two problems here:**

- The `roll` packet is broadcast and **no client handles it**
  ([known-gaps.md](known-gaps.md) G2) — nobody sees anyone else roll.
- `:240` calls `event.is_action_pressed("dodge")`, but **`dodge` is not
  defined** in `project.godot`'s input map (defined actions are `move_*`,
  `attack`, `chat_toggle`, `scoreboard`, `skill_1..3`). Godot logs an error
  for a nonexistent action on every input event. The roll only works because
  of the explicit `KEY_SHIFT` fallback in the same condition.

## Skills are bound twice

`_handle_local_input` handles `skill_1/2/3` via the action map (`:216-221`),
and `_unhandled_input` **also** handles raw `KEY_1/2/3` (`:249-254`). Those
actions are bound to keycodes 49/50/51 — the same keys.

Pressing `1` therefore calls `_execute_skill(1)` twice. It is harmless today
because the strategy checks `skill1_cd <= 0` (`warrior_class.gd:43`) and the
first call sets the cooldown, so the second is a no-op. It is still a
redundant double-dispatch that would misbehave if cooldowns were ever removed
or reordered.

`_unhandled_input` also binds Q and E to `GameState.use_quick_slot(0/1)`
(`:245-248`).

## Damage, XP and death

- **`take_damage`** (`:323`) — i-frame check, `super.take_damage`, then for
  local players emit `stats_changed` and send `stat_sync hp`.
- **`gain_xp`** (`:378`) — accumulates, levels up on threshold, sends
  `stat_sync xp` which **no client applies** ([known-gaps.md](known-gaps.md)
  G3).
- **`_level_up`** (`:390`) — `+1` level, `xp_to_next * 1.5`, `+25` max HP
  (full heal), `+6` attack, `+3` stat points, then three `stat_sync` packets
  and a system chat line.
- **`_die`** (`:432`) — hides the node, sends `player_died` and a chat line,
  schedules `_respawn` after 3.5 s.
- **`_respawn`** (`:451`) — full HP/energy/stamina, random position near
  origin.

> **`_die` is not gated on `is_local`.** A remote player's node can die on
> your client (a projectile resolves locally, `projectile.gd:55`), and your
> client then sends a `player_died` packet and a "was defeated!" chat line for
> someone else's death. The server overwrites `victim_id` with your client id
> (`server.js:286`), so identity is not forgeable — but the chat line is
> duplicated per client that witnessed the death, and each of those clients
> also runs its own local `_respawn` timer on that remote node.

## Level-gated features

Three thresholds, none surfaced in the UI: charged attack at **11** (`:202`),
PK mode at **10** (`game_state.gd:227`), skills from **1**.

## Related

- [entity.md](entity.md) — base class
- [hero-class.md](hero-class.md) — where attacks and skills actually execute
- [game-state.md](game-state.md) — stat and inventory source
- [combat-formula.md](combat-formula.md) — stat derivation
