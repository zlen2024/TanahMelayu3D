# `scripts/entities/entity.gd`

`class_name Entity` · extends `CharacterBody2D` · 91 LOC.

The shared base for every living thing. Two subclasses:
[`Player`](player.md) and [`Monster`](monster.md).

## What it owns

| Concern | Members |
|---|---|
| Health | `max_hp`, `current_hp` (`:14-15`, both `@export`) |
| Movement | `move_speed` (`:16`) |
| Mitigation | `defense` (`:17`) |
| Death | `is_dead` (`:19`), `_die()` (`:89`) |
| Stun | `is_stunned`, `stun_timer` (`:20-21`), `apply_stun()` (`:69`) |

Signals: `health_changed(current_hp, max_hp)`, `entity_died()`,
`stun_state_changed(is_stunned)` (`:10-12`).

`_ready()` adds every instance to the `entities` group (`:26`). Subclasses
call `super._ready()` and add their own group — `players` (`player.gd:68`) or
`monsters` (`monster.gd:48`). Group membership is how combat finds targets
throughout the codebase.

## `process_entity_status(delta) -> bool`

`:28` — the shared top-of-frame guard. Returns `true` when the caller should
**skip its own movement and AI** this frame.

Both subclasses open `_physics_process` with it:

```gdscript
if process_entity_status(delta):
    return
```

(`player.gd:127`, `monster.gd:106`)

It handles two interrupt states: dead entities zero their velocity and return
`true` (`:29-31`); stunned entities count down `stun_timer`, call
`move_and_slide()` so physics still resolves, and restore sprite tint when
the stun expires (`:33-42`).

Returning a bool rather than using a state enum keeps the contract small, but
it does mean the caller must remember to check it — nothing enforces that.

## `take_damage(amount, attacker_id) -> int`

`:46` — the single damage entry point. Applies
[`CombatFormula.calc_defense_mitigation`](combat-formula.md), clamps HP at
zero, emits `health_changed`, plays feedback, and calls `_die()` on reaching
zero. Returns the **mitigated** amount, so callers can display the real
number.

Both subclasses override it and both call `super.take_damage(...)`, but they
wrap it for different reasons:

- [`Player`](player.md) `:323` — checks `is_invulnerable` first (dodge-roll
  i-frames) and broadcasts a `stat_sync` afterwards.
- [`Monster`](monster.md) `:258` — broadcasts `monster_hit` **first**, then
  delegates to `apply_damage_from_network()`, which is what calls
  `super.take_damage`. The split exists so inbound network damage can skip
  re-broadcasting and avoid an echo loop.

Mitigation is applied **once**, inside this base method. Damage arriving over
the network is already raw, and `apply_damage_from_network` routes it through
here — so remote and local hits mitigate identically.

## `heal`, `apply_stun`, `play_damage_feedback`

All three spawn a [`FloatingText`](floating-text.md) on the **parent** node
rather than on `self` (`:66-67`, `:77-78`, `:86-87`):

```gdscript
var parent_node = get_parent() if get_parent() else self
FloatingText.spawn(parent_node, global_position, ...)
```

Parenting to the container rather than the entity means the popup is not
destroyed when the entity is freed, and does not inherit its scale or
rotation. The `if get_parent()` fallback covers entities not yet in the tree.

`apply_stun` (`:69`) takes `max(stun_timer, duration)` (`:73`) — a longer stun
extends a shorter one, but a shorter one never truncates a longer one.

`play_damage_feedback` (`:80`) tweens a red flash and restores to white *or*
the stun tint depending on `is_stunned` (`:85`), so damaging a stunned entity
does not clear its visual state.

## `_die`

`:89` — minimal by design: sets `is_dead`, emits `entity_died`. Both
subclasses override with substantially more (loot, respawn timers,
networking) and both call `super._die()` first.

## Notes

- `entity_sprite` (`:23`) uses `get_node_or_null("Sprite2D")`, so an `Entity`
  without a sprite child still works. Every guard that touches it is
  null-checked.
- `Monster` re-exposes `max_hp`/`current_hp` as `max_health`/`current_health`
  property aliases for test compatibility — not duplicated state. See
  [decisions.md](decisions.md) D6.

## Related

- [player.md](player.md) · [monster.md](monster.md) — the subclasses
- [combat-formula.md](combat-formula.md) — the mitigation maths
- [floating-text.md](floating-text.md) — the popup helper
