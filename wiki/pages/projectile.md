# `scripts/entities/projectile.gd`

extends `Area2D` · 60 LOC · no `class_name` — instantiated from
`res://scenes/projectile.tscn`.

Every ranged attack in the game: mage bolts, archer arrows, and the two
charged variants.

## Configuration

All six behaviour knobs are `@export` (`:5-10`), set by the spawner **before**
`add_child`, so `_ready()` sees the final values:

| Field | Default | Overridden by |
|---|---|---|
| `speed` | 380.0 | `archer_class.gd:27` → 520 |
| `damage` | 25 | `mage_class.gd:28` → 1.6× · `archer_class.gd:29` → 1.7× |
| `lifetime` | 1.5 | `archer_class.gd:28` → 2.0 |
| `is_piercing` | false | `archer_class.gd:30` → true |
| `causes_stun` | false | `mage_class.gd:29` → true |
| `stun_duration` | 1.5 | `mage_class.gd:30` |

Plus `direction` and `shooter_id` (`:12-13`), always set by the spawner.

## Two spawn paths

1. **`NetworkManager._spawn_projectile()`** (`network_manager.gd:379`) —
   defaults only. Used for basic attacks
   ([`mage_class.gd:10`](mage-class.md),
   [`archer_class.gd:10`](archer-class.md)), the archer's Triple Shot
   (`archer_class.gd:50`), and — importantly — for **remote** players' spells
   on the `attack` protocol arm (`network_manager.gd:320`).
2. **Direct instantiation** in the class strategies for charged attacks, which
   need the non-default fields (`mage_class.gd:23-32`,
   `archer_class.gd:23-33`).

Path 2 is local-only: a charged shot is transmitted as a plain
`"attack"` with `spell: true`, so **remote viewers see a default projectile**,
not the piercing or stun-bolt variant. Cosmetic divergence — damage is applied
by the shooter's client either way.

## Hit resolution

`_handle_hit(target)` (`:33`) runs for both `body_entered` and
`area_entered`; the area path resolves to `area.get_parent()` (`:31`).

Order of checks:

1. **Self-hit guard** (`:38-39`) — skip if the target is in `players` and its
   `peer_id` equals `shooter_id`.
2. **Double-hit guard** (`:41-43`) — `hit_targets` array, so a piercing shot
   damages each target at most once.
3. **Dispatch by group** — `monsters` (`:46`), then `players` (`:54`), then
   `obstacles` (`:59`, despawn only).

Non-piercing projectiles `queue_free()` after a hit; piercing ones continue.

Lifetime is a one-shot `SceneTreeTimer` connected straight to `queue_free`
(`:21-22`).

## Notes

- **PvP is unconditional here.** The `players` branch (`:54-58`) applies
  damage to any player who is not the shooter, with no check of
  `GameState.is_pk_enabled`. PK mode gates the nameplate and the death-drop
  logic, but not whether a projectile can hurt you.
- **Stun is monster-only.** `apply_stun` is called in the monster branch
  (`:48-49`) but not the player branch, so the mage's Stun Bolt cannot stun
  another player.
- **No crit.** Projectile damage never consults
  [`CombatFormula.is_critical_hit`](combat-formula.md) — see
  [known-gaps.md](known-gaps.md) G13.
- Movement is direct position integration (`:25`), not `move_and_slide`, so
  projectiles pass through walls; only `obstacles`-group areas stop them.

## Related

- [mage-class.md](mage-class.md) · [archer-class.md](archer-class.md)
- [entity.md](entity.md) — the `take_damage` contract it calls
