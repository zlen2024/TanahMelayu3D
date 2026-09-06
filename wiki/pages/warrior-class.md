# `scripts/classes/warrior_class.gd`

`class_name WarriorClass` · extends [`HeroClass`](hero-class.md) · 79 LOC.

The melee class, and the only one whose damage passes through a crit roll.
Default for any unrecognised class string (`hero_class.gd:30-32`).

Preloads [`FloatingText`](floating-text.md) and
[`CombatFormula`](combat-formula.md) (`:4-5`).

## Basic attack — `:10`

Plays the slash effect and sound, sends an `"attack"` packet with
`spell: false`, then reads
`player.attack_area.get_overlapping_bodies()` (`:19`) and damages every
overlapping node in the `monsters` group (`:20-22`).

This is the **only** attack in the game that uses the `attack_area` hitbox.
Its position is kept in sync with facing by `player.gd:193`.

Note the target filter is `monsters` only — the warrior's basic attack
**cannot hit other players**, so melee PvP does not work. Projectiles can
(`projectile.gd:54`).

## Charged attack — `:24`

"HEAVY CLEAVE" at 1.8× damage (`:28`). Rather than using the hitbox it scans
`get_nodes_in_group("monsters")` and takes anything within 85 px (`:31-34`),
then applies knockback by teleporting the target 60 px along the away-vector
(`:37-40`).

The knockback is a direct `global_position` assignment, not a physics impulse,
so it passes through walls. It also happens only on the attacker's client and
is never synchronised — remote viewers see the monster snap back on the next
`monsters_sync` from the host.

The `is_instance_valid` / `is_queued_for_deletion` / `is_dead` guard chain at
`:33` recurs verbatim in `player.damage_enemies_in_radius` (`player.gd:120`) —
it defends against acting on monsters freed earlier in the same frame.

## Skills — `:42`

| Idx | Name | Energy | CD | Effect |
|---|---|---|---|---|
| 1 | Shield Charge | 15 | 2.0 s | Dash 90 px forward, then 65 px AoE for `25 + STR*2.5` |
| 2 | Whirlwind Spin | 22 | 3.5 s | 85 px 360° AoE for `30 + STR*3.5` |
| 3 | Iron Will | 20 | 8.0 s | Heal `50 + VIT*1.5` |

All three scale off `GameState` attributes directly (`:50`, `:60`, `:67`) —
not off the player's derived `attack_damage`. So skill damage ignores weapon
`atk` bonuses entirely, while basic attacks (which use
`player.attack_damage`) do not.

Skills 1 and 2 route through `player.damage_enemies_in_radius()`
(`player.gd:315`), which applies flat damage — **no crit**, unlike the basic
attack. Within one class, whether you crit depends on which button you pressed.

## `_deal_player_damage` — `:72`

The crit wrapper, and the sole caller of `CombatFormula.is_critical_hit`
anywhere in the codebase:

```gdscript
var is_crit = CombatFormula.is_critical_hit(GameState.stat_agi)
if is_crit:
    final_dmg = int(final_dmg * 1.5)
var dealt = target.take_damage(final_dmg, player.peer_id)
if is_crit:
    FloatingText.spawn(player.get_parent(), target.global_position, "CRIT! %d" % dealt, Color.YELLOW, true)
```

Called from the basic attack (`:22`) and the charged cleave (`:35`) only.

Note the crit popup is spawned **in addition** to the ordinary damage number
that `Entity.play_damage_feedback` already spawns (`entity.gd:87`), so a crit
produces two overlapping floating labels.

## Related

- [hero-class.md](hero-class.md) — the contract and cross-class comparison
- [combat-formula.md](combat-formula.md) — crit chance and mitigation
- [known-gaps.md](known-gaps.md) — G13, crit coverage
