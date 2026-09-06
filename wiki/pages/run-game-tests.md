# `tests/run_game_tests.gd`

extends `Node` · 578 LOC — the second-largest file in the project. Script on
[`test_runner.tscn`](scenes.md), run headless by `tools/run_all_tests.ps1`.

> **Executed 2026-09-05** (second pass): **94 assertions, 94 passed, exit 0**,
> via `bin/Godot_v4.3-stable_win64_console.exe --headless res://tests/test_runner.tscn`.
> T2 in [known-gaps.md](known-gaps.md) is now resolved for this suite. The Node
> suite still has not been run.

## Harness

Hand-rolled, no framework. `assert_true(condition, test_name)` (`:54`)
increments `total_tests` and one of `passed_tests`/`failed_tests` and prints a
line. `_ready()` (`:17`) calls each test in sequence and exits with a non-zero
code on failure, which is what `run_all_tests.ps1` checks.

Preloads the six pure-logic scripts directly (`:3-8`) —
[`CombatFormula`](combat-formula.md), [`ItemDatabase`](item-database.md),
[`HeroClass`](hero-class.md) and the three subclasses — and `load()`s scenes
inside individual tests.

## The 19 tests

| Test | Line | Covers |
|---|---|---|
| `_test_chat_system` | 64 | `chat_received` signal round-trip |
| `_test_map_and_boundaries` | 85 | `world.tscn` loads; arena bounds |
| `_test_hit_detection_and_combat` | 108 | Monster/player damage |
| `_test_monster_death_and_zero_damage_fix` | 137 | Death path; the min-1-damage clamp |
| `_test_monster_respawn` | 171 | **Respawn cycle** — added 2026-09-05 with the fix |
| `_test_player_attack_and_projectiles` | 228 | Projectile spawn and hit |
| `_test_xp_and_leveling` | 252 | `gain_xp`, `_level_up` thresholds |
| `_test_level_tally_and_nameplate_sync` | 272 | `register_player_info`, `sync_player_stat` |
| `_test_monster_movement_synchronization` | 290 | `apply_sync_state` |
| `_test_loot_drop` | 316 | `_spawn_loot` |
| `_test_hud_leaderboard_level_sync` | 327 | Roster updates |
| `_test_classic_classes_and_base_stats` | 354 | Per-class `calc_player_stats` |
| `_test_energy_and_regeneration` | 384 | `calc_energy_regen`, `use_energy` |
| `_test_class_skills_execution` | 411 | All three classes' skills |
| `_test_inventory_and_item_use` | 447 | `GameState` inventory ops |
| `_test_oop_strategy_and_combat_formulas` | 484 | `HeroClass.create`, mitigation, crit |
| `_test_stamina_dodge_roll_and_iframes` | 505 | `dodge_roll`, invulnerability |
| `_test_charged_attacks_and_stun` | 527 | Charged variants, `apply_stun` |
| `_test_item_database_paperdoll_and_ui_lock` | 556 | `create_item`, equip, modal counter |

The names are unusually descriptive, and two of them —
`_test_monster_death_and_zero_damage_fix` and
`_test_level_tally_and_nameplate_sync` — are named after **specific bugs**.
They are regression tests, and worth reading before touching those paths.

## What it covers well

The pure-logic layer. [`CombatFormula`](combat-formula.md) and
[`ItemDatabase`](item-database.md) are static and side-effect free, and the
suite exercises them directly — mitigation curves, crit chance, per-class stat
derivation, item creation.

It also drives real scene instantiation for entities, so it catches broken
`@onready` paths and scene wiring, not just arithmetic.

## What it does not cover

The gaps line up almost exactly with the confirmed bugs in
[known-gaps.md](known-gaps.md), which is why those bugs are still present:

- **No protocol conformance test.** Nothing asserts that every message type
  the server sends has a client handler. G2 (seven unhandled types) would be
  caught by a single table-driven test.
- **`_test_item_database_paperdoll_and_ui_lock` calls `GameState.equip_item`
  directly**, not through the UI. G14 — the hardcoded level `1` in
  `inventory_ui.gd:148` — lives in the layer this test skips.
- **No test asserts `can_equip` is used**; it is dead code
  ([item-database.md](item-database.md)) and no test notices.
- **Server-side JS is out of scope** — G1 (`db.getUserInventory` does not
  exist) is a Node-side error this suite structurally cannot see. It belongs
  to [`test_server_network.js`](testing.md), which also misses it.
- **No test covers the solo/networked duplication** (G11), so guest and
  logged-in stat divergence goes unnoticed.

## Note on the alias dependency

`monster.gd`'s `max_health` / `current_health` aliases exist specifically for
this suite — the comment at `monster.gd:19` says so. Removing them would break
tests rather than gameplay. See [decisions.md](decisions.md) D6.

## Related

- [testing.md](testing.md) — both suites together
- [combat-formula.md](combat-formula.md) · [item-database.md](item-database.md)
