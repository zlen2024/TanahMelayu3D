# `scripts/classes/mage_class.gd`

`class_name MageClass` · extends [`HeroClass`](hero-class.md) · 72 LOC.

Ranged caster. Highest energy pool, lowest HP
([`combat_formula.gd:54-58`](combat-formula.md)). Selected by skin index 1
(`network_manager.gd:391`, `:402`).

## Basic attack — `:7`

Spawns a default projectile locally via
`NetworkManager._spawn_projectile()` (`:10`), then sends an `"attack"` packet
with `spell: true` (`:11-15`).

The local spawn and the packet are separate: remote clients receive the packet
and spawn their own projectile on the `attack` arm
(`network_manager.gd:317-320`). The server excludes the sender from that
broadcast (`server.js:269`), so there is no double-spawn on the caster's
screen.

Projectiles are spawned 18 px ahead of the caster along `facing_dir` (`:10`)
to clear their own collision shape.

## Charged attack — `:17`

"STUN BOLT" — instantiates `projectile.tscn` **directly** (`:23-32`) rather
than going through `NetworkManager`, because it needs non-default fields:

| Field | Value |
|---|---|
| `damage` | `attack_damage * 1.6` |
| `causes_stun` | `true` |
| `stun_duration` | 1.5 s |
| `modulate` | arcane cyan `(0.4, 0.8, 2.5)` |

It then sends the same generic `"attack"` packet as the basic attack
(`:34-38`) — **with no indication that it was charged**. Remote viewers
therefore spawn a plain default projectile: no cyan tint, no stun, different
damage. The stun that matters is applied by the caster's own projectile
(`projectile.gd:48-49`), so gameplay is consistent; only the visual on other
screens is wrong.

Stun applies to monsters only — `projectile.gd`'s player branch (`:54-58`)
never calls `apply_stun`.

## Skills — `:40`

| Idx | Name | Energy | CD | Effect |
|---|---|---|---|---|
| 1 | Arcane Fireball | 15 | 1.0 s | One default projectile + `attack` packet |
| 2 | Frost Nova | 25 | 4.0 s | 90 px 360° AoE for `22 + INT*2.5` |
| 3 | Mana Surge | 10 | 7.0 s | Heal 60 **and** restore 25 energy |

Skill 1 is the shortest cooldown in the game (1.0 s) and duplicates the basic
attack exactly (`:47-52` versus `:10-15`) for 15 energy — it deals identical
damage. As written there is no reason to press it.

Skill 3 costs 10 energy and returns 25 (`:65-69`), a **net gain of 15** on a
7-second cooldown, alongside a 60 HP heal. Combined with passive INT-scaled
regen (`player.gd:143`), a mage's energy economy is effectively unbounded.

Frost Nova is named for freezing but applies no stun or slow — it is pure AoE
damage through `player.damage_enemies_in_radius()` (`:61`), which does not
crit.

## Related

- [hero-class.md](hero-class.md) · [projectile.md](projectile.md)
- [combat-formula.md](combat-formula.md) — INT scaling
