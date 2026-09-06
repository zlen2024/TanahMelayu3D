# `scripts/classes/archer_class.gd`

`class_name ArcherClass` · extends [`HeroClass`](hero-class.md) · 69 LOC.

Mobile ranged class. Fastest base movement and the only class whose attack
damage scales off AGI ([`combat_formula.gd:59-63`](combat-formula.md)).
Selected by skin index 2 (`network_manager.gd:392`, `:403`).

## Basic attack — `:7`

Identical to [`MageClass`](mage-class.md)'s: local
`NetworkManager._spawn_projectile()` plus an `"attack"` packet with
`spell: true` (`:10-15`). The two implementations are line-for-line the same;
only the charged attack and skills differ.

## Charged attack — `:17`

"PIERCING SHOT" — direct instantiation (`:23-33`) with four overrides:

| Field | Value | vs. default |
|---|---|---|
| `speed` | 520.0 | 380.0 |
| `lifetime` | 2.0 s | 1.5 s |
| `damage` | `attack_damage * 1.7` | 25 |
| `is_piercing` | `true` | `false` |

Range is `speed * lifetime` — 1040 px versus the default 570 px, nearly double.

`is_piercing` means the projectile is not freed on hit
(`projectile.gd:51-52`, `:57-58`) and keeps travelling. Its `hit_targets`
array (`projectile.gd:41-43`) guarantees each target is damaged at most once,
so a piercing shot cannot multi-hit the same monster.

As with the mage's charged attack, the packet sent afterwards (`:35-39`)
carries no charge marker, so remote clients render a plain default projectile
— no gold tint, no pierce, shorter range.

## Skills — `:41`

| Idx | Name | Energy | CD | Effect |
|---|---|---|---|---|
| 1 | Triple Shot | 18 | 1.5 s | Three projectiles at −15°, 0°, +15° |
| 2 | Tumble Dash | 15 | 2.5 s | Teleport 130 px along facing |
| 3 | Field Bandage | 20 | 6.0 s | Heal `45 + VIT*1.2` |

**Triple Shot is the outlier in this codebase.** It is the only attack that
spawns projectiles without also sending an `"attack"` packet (`:48-50`) — the
loop calls `_spawn_projectile` three times and returns. Remote clients see
*nothing at all*: no slash effect, no arrows. Damage still lands, because the
archer's own projectiles resolve locally and each hit broadcasts
`monster_hit` (`monster.gd:262`). So monsters take damage from an invisible
source on every other screen.

**Tumble Dash is a raw position assignment** (`:58`), not a physics move, so
it passes through walls and any obstacle. `WarriorClass`'s Shield Charge has
the same property (`warrior_class.gd:49`).

Field Bandage scales off VIT (`:66`) despite VIT not being an archer's
primary stat — the same `+VIT` heal shape as the warrior's Iron Will, at a
lower base.

## Note on the class's stat curve

`combat_formula.gd:63` gives the archer
`attack_damage = 14 + AGI*2.0 + STR*1.0 + gear`, the only two-stat attack
formula in the game. Since AGI also drives crit chance (`combat_formula.gd:23`)
— which archers never roll, because projectiles do not crit
([known-gaps.md](known-gaps.md) G13) — half of AGI's intended value is
currently unrealised for this class.

## Related

- [hero-class.md](hero-class.md) · [projectile.md](projectile.md)
- [combat-formula.md](combat-formula.md) — AGI scaling and crit
