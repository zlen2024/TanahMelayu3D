# `scripts/classes/hero_class.gd`

`class_name HeroClass` · extends `RefCounted` · 32 LOC.

The Strategy-pattern base for the three playable classes, and the factory
that builds them.

## The contract

Three virtual methods, all no-ops in the base (`:12-19`):

```gdscript
func execute_basic_attack(_player: CharacterBody2D) -> void
func execute_charged_attack(_player: CharacterBody2D) -> void
func execute_skill(_player: CharacterBody2D, _idx: int) -> bool
```

`execute_skill` returns `bool` — `true` when the skill actually fired, `false`
when it was on cooldown or unaffordable. The other two return nothing, so a
basic attack cannot report failure.

Each implementation receives the `Player` node as an argument rather than
holding a reference, which is why every subclass reaches through it
(`player.attack_area`, `player.skill1_cd`, `player.use_energy(...)`). The
strategy is stateless apart from `class_name_str` (`:6`).

## The factory

`static func create(class_type: String) -> HeroClass` (`:22`) matches a
lowercased string and `load()`s one of three scripts (`:23-32`), defaulting to
warrior for anything unrecognised.

**This dispatch is invisible to static analysis.** Nothing "constructs"
`MageClass` in a way a call graph can see — the only construction is
`script.new()` on a dynamically loaded path. Any new subclass must be added
to this `match` or it can never be reached. Noted in the wiki schema's
verification rules ([CLAUDE.md](../CLAUDE.md)) precisely because it is the
kind of edge a graph query will tell you does not exist.

Callers: `player.gd:73` (in `_ready`) and `player.gd:90` (in
`recalculate_stats`, so a class change takes effect without respawning).

## The three implementations

| | [Warrior](warrior-class.md) | [Mage](mage-class.md) | [Archer](archer-class.md) |
|---|---|---|---|
| Basic | melee arc via `attack_area` | projectile | projectile |
| Charged | AoE cleave + knockback | stun bolt (1.5 s) | piercing shot |
| Skill 1 | Shield Charge — dash + AoE | Arcane Fireball | Triple Shot (3-arrow fan) |
| Skill 2 | Whirlwind — 360° AoE | Frost Nova — 360° AoE | Tumble Dash — 130 px leap |
| Skill 3 | Iron Will — heal 50+VIT | Mana Surge — heal 60 + 25 MP | Field Bandage — heal 45+VIT |
| Scaling stat | STR | INT | AGI |

Every skill follows the same shape: check `idx` and the matching cooldown,
call `player.use_energy(cost)`, set the cooldown, emit
`skill_cooldown_started` for the HUD, act, return `true`.

## Inconsistencies across implementations

Worth knowing before editing any one of them:

- **Only the warrior applies crits.** `WarriorClass._deal_player_damage`
  (`warrior_class.gd:72`) is the sole caller of
  `CombatFormula.is_critical_hit`. Mage and archer damage goes through
  [`projectile.gd`](projectile.md), which never crits. See
  [known-gaps.md](known-gaps.md) G13.
- **Only the warrior's basic attack uses the hitbox.** It reads
  `player.attack_area.get_overlapping_bodies()` (`warrior_class.gd:19`);
  the others spawn projectiles and ignore the area entirely.
- **Skill damage bypasses the strategy.** Warrior and mage AoE skills call
  `player.damage_enemies_in_radius()` (`player.gd:315`) directly, which
  applies flat damage with no crit and no `_deal_player_damage` wrapper.
- **The archer's charged attack does not consume energy**; neither do the
  other charged attacks. Only skills cost energy.

## Related

- [player.md](player.md) — owns `hero_strategy` and calls into it
- [combat-formula.md](combat-formula.md) — per-class stat curves
