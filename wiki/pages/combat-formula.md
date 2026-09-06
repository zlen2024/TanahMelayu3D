# `scripts/combat/combat_formula.gd`

`class_name CombatFormula` · extends `RefCounted` · 78 LOC · all members
`static`.

Pure functions — no state, no side effects, no node access. This is the one
file in the project that is trivially unit-testable, and
[`run_game_tests.gd`](run-game-tests.md) does test it.

The header calls the model "Ragnarok-inspired" (`:4`).

## Defence mitigation — `:12`

```
damage = raw * (100 / (100 + DEF))
```

Hyperbolic, so defence has diminishing returns and can never reach immunity:

| DEF | Multiplier |
|---|---|
| 0 | 100% |
| 50 | 66.7% |
| 100 | 50% |
| 200 | 33.3% |

Two clamps worth knowing: zero or negative raw damage returns 0 (`:13-14`),
and any positive hit returns **at least 1** (`:18`). So a heavily armoured
target still takes chip damage — which is what stops the fight stalling.

Called from exactly one place: [`Entity.take_damage`](entity.md)
(`entity.gd:50`). Every damage source in the game funnels through there, so
mitigation is applied exactly once per hit.

## Crit — `:23`

```
chance = min(0.75, 0.05 + AGI * 0.004)
```

5% base, +0.4% per AGI, hard-capped at 75% (reached at AGI 175).

`is_critical_hit(agi)` (`:27`) rolls `randf()` against it — and has **one
caller in the entire codebase**: `WarriorClass._deal_player_damage`
(`warrior_class.gd:74`). Projectile damage, AoE skill damage and all monster
damage bypass it. See [known-gaps.md](known-gaps.md) G13.

Crit multiplier is 1.5×, and it is hardcoded at the call site
(`warrior_class.gd:76`), not here.

## Player stats — `:31`

`calc_player_stats(hero_class, str, vit, agi, int, bonus_gear) -> Dictionary`
returns `max_hp`, `max_energy`, `move_speed`, `attack_damage`, `defense`.

Defence is class-independent: `int(VIT * 0.5) + gear_def` (`:46`).

The rest is per-class (`:48-68`):

| | HP | Energy | Speed | Attack |
|---|---|---|---|---|
| **Warrior** | `60 + VIT*12` | `30 + INT*5` | `165 + AGI*2.2` | `16 + STR*2.8` |
| **Mage** | `40 + VIT*8` | `40 + INT*5` | `155 + AGI*2.0` | `12 + INT*2.2` |
| **Archer** | `50 + VIT*9` | `35 + INT*5` | `180 + AGI*2.6` | `14 + AGI*2.0 + STR*1.0` |
| *(default)* | `50 + VIT*10` | `30 + INT*5` | `170 + AGI*2.0` | `15 + STR*2.0` |

Gear bonuses (`atk`, `def`, `hp`, `mp`) are added on top of every branch.

Each class scales attack off a different stat — STR, INT, and AGI+STR
respectively — which is what makes stat allocation class-dependent. The
archer is the only two-stat formula.

## Regeneration — `:73`

```
energy_regen = 5.0 + INT * 0.6 + gear_mp_regen   (per second)
health_regen = 1.0 + VIT * 0.25 + gear_hp_regen  (per second)
```

Consumed by `player.gd:143` and `:160`, which accumulate fractionally and
apply whole points only.

The `bonus_*_regen` arguments are always 0 in practice —
`GameState.get_equipment_bonus("mp_regen")` finds no item defining that stat
(see [item-database.md](item-database.md)).

## Where these formulas are contradicted

`calc_player_stats` is the client's derivation, but it is not the only place
character numbers are decided:

- **`db.js:96-140`** sets class baselines at registration (e.g. warrior
  `hp 180`), and `db.js:228-230` increments `max_hp` by a flat `+10` per VIT
  point and `max_energy` by `+5` per INT point.
- **`network_manager.gd:400-404`** has a third table for guest characters.
- **`player.gd:396`** adds a flat `+25` max HP per level-up, outside this
  formula entirely.

So the server's stored `max_hp` and the client's recomputed `max_hp` are
derived by different rules and will disagree. The client's value wins in play,
because `recalculate_stats()` overwrites it (`player.gd:101`). See
[known-gaps.md](known-gaps.md) G11.

## Related

- [entity.md](entity.md) — the only mitigation caller
- [player.md](player.md) — the only `calc_player_stats` caller
- [run-game-tests.md](run-game-tests.md) — coverage of these functions
