# `scripts/entities/monster.gd`

`class_name Monster` · extends [`Entity`](entity.md) · 350 LOC.

Slime AI with a telegraphed attack state machine. Spawned only by
[`world.gd`](world.md) `_create_monster()`.

## Three variants, configured in `_ready()`

`enum MonsterType { GREEN_SLIME, RED_SLIME, KING_SLIME }` (`:10`), with stats
assigned by branch in `_ready()` (`:52-81`):

| | Green (default) | Red / Magma | King (boss) |
|---|---|---|---|
| HP | 60 | 85 | 220 |
| Attack | 12 | 18 | 26 |
| Attack radius | 35 | **140** (ranged) | 95 |
| Defense | 2 | 6 | 12 |
| Windup | 0.55 s | 0.65 s | 0.75 s |

Stats are hardcoded here rather than exported per-instance, so `world.gd` only
chooses king vs. not (`world.gd:42-46`). **Nothing spawns a `RED_SLIME`** —
`world.gd` passes only `is_king`, and `monster_type` defaults to
`GREEN_SLIME`. The Magma Slime branch and its loot table
(`:330-333`) are unreachable in the current build.

## HP field aliases

`max_health` / `current_health` (`:20-25`) are **property aliases** with
getters and setters onto `Entity`'s `max_hp` / `current_hp`. The comment says
why: test compatibility. There is one storage location, not two — see
[decisions.md](decisions.md) D6.

## State machine

`enum State { IDLE, CHASE, TELEGRAPH_WINDUP, ATTACK_STRIKE, RECOVERY, DEAD }`
(`:9`), dispatched in `_physics_process` (`:118-124`).

```
IDLE/CHASE ──player in aggro_radius──▶ CHASE
    │                                    │ in attack_radius
    │  wander on timer                   ▼
    └──────────────────────── TELEGRAPH_WINDUP  (draws red cone)
                                         │ windup_timer elapsed
                                         ▼
                                   ATTACK_STRIKE
                                         │
                                         ▼
                                     RECOVERY ──▶ IDLE
```

`_draw()` (`:232`) renders the red ground telegraph during windup — a filled
polygon fanning ±28° over 38 px (`:251-256`), with `queue_redraw()` called
every frame (`:126`). This is the "tell" that makes attacks dodgeable.

`ATTACK_STRIKE` and `DEAD` have no `match` arm; they are transitional, set and
then immediately advanced by `_execute_attack_strike()` (`:189`) and `_die()`.

## Authority gating

`_physics_process` short-circuits for non-host clients (`:112-115`):

```gdscript
if not NetworkManager.is_room_host and not NetworkManager.is_solo_mode:
    global_position = global_position.lerp(target_sync_pos, 15.0 * delta)
    queue_redraw()
    return
```

So AI runs only on the elected host (or in solo), and everyone else
interpolates toward host-supplied positions.

Note the ordering: `process_entity_status(delta)` runs **before** this check
(`:106`), so a stunned remote monster stops interpolating. Since stun is
applied locally by projectiles (`projectile.gd:49`) and never synchronised,
a stunned monster can briefly diverge from the host's view.

`apply_sync_state()` (`:85`) is the inbound side: sets `target_sync_pos`,
sprite flip, HP, and handles death/resurrection transitions (`:92-103`). The
resurrection branch — re-enabling collision and visibility when the host says
a monster is alive again — exists because monsters are never actually removed
from the tree, only hidden.

## Damage: the two-method split

```
take_damage()                    ← local hit; broadcasts, then delegates
    └─▶ apply_damage_from_network()  ← inbound hit; no broadcast
            └─▶ Entity.take_damage()     ← mitigation, HP, death
```

`take_damage` (`:258`) sends a `monster_hit` packet **first** (`:262-267`)
carrying `get_index()`, damage and attacker, then calls
`apply_damage_from_network`. Remote clients receive `monster_hit` and call
`apply_damage_from_network` directly (`network_manager.gd:337-338`), which
does **not** re-broadcast — that is what prevents an echo loop.

Combat is therefore fully client-authoritative: whoever swung decides the
damage and tells everyone. See [security-notes.md](security-notes.md).

## Index-based identity

`monster_hit` addresses the target by `get_index()` (`:264`) — its position in
the `Monsters` container. There is no stable id. Correctness depends on every
client having spawned identical monsters in identical order. See
[known-gaps.md](known-gaps.md) G4.

## Respawn

**Fixed 2026-09-05.** Monsters previously died permanently: `_die()` scheduled
nothing, never freed the node, and never hid it — leaving a frozen, un-hittable
corpse standing on the map. Once every slime was killed the arena stayed empty
for the rest of the session. `world.gd:20`'s re-spawn guard
(`get_child_count() == 0`) could never fire either, because dead monsters were
still children.

The sync protocol already had the receiving half: `apply_sync_state`'s
resurrection branch (`:92-103`) restores visibility, collision and state when
the host reports a monster alive again. Only the host-side countdown was
missing.

Now:

| Piece | Where |
|---|---|
| `RESPAWN_TIME` 8 s / `RESPAWN_TIME_BOSS` 30 s | `:38-39` |
| `respawn_timer` armed on death | `:304` |
| Countdown, authority-gated | `:113-118` |
| `_respawn()` | `:331` |

The countdown runs at the **top** of `_physics_process`, before
`process_entity_status()` — that method early-returns for dead entities, so a
timer ticked after it would never advance.

It is gated on `is_room_host or is_solo_mode`, matching the AI gate below it.
Remote clients do not count down independently; they are resurrected when the
host's next `monsters_sync` reports `dead: false`, which keeps every client's
respawn moment identical instead of drifting.

`_respawn()` returns the monster to `spawn_pos` rather than reviving it where
it fell, so the arena layout stays as [`world.gd`](world.md) arranged it.

Because respawn re-runs the full death path on the next kill, `_spawn_loot()`
fires every cycle — monsters are now a renewable loot source. Combined with G6
(loot spawns per-client, uncontested) that makes farming considerably more
generous than it likely should be; worth a balance pass.

Covered by `_test_monster_respawn` ([run-game-tests.md](run-game-tests.md)).

## Death and loot

`_die()` (`:281`) disables collision, calls `_spawn_loot()`, and — **only for
the killer** (`:296`) — awards XP (50 for king, 18 otherwise) and broadcasts
the "was slain!" chat line. That gating is correct; it is not the duplicate
announcement it first looks like.

`_spawn_loot()` (`:310`) is **not** gated, and runs on every client that
processes the death, including remote clients reaching `_die` through
`apply_sync_state` (`:92-93`). Each client spawns its own copy of the drop —
see [known-gaps.md](known-gaps.md) G6.

Every kill drops an XP gem (`:317-321`) plus one rolled item
(`:324-345`), built through
[`ItemDatabase.create_item`](item-database.md):

| Source | Roll table |
|---|---|
| King Slime | 40% `armor_king` · 30% `wand_archmage` · 30% `amulet_agility` |
| Magma Slime | 35% `sword_steel` · 30% `bow_composite` · 35% `potion_hp` *(unreachable)* |
| Forest Slime | 45% `potion_hp` · 30% `potion_mp` · 15% `sword_iron` · 10% `ring_vitality` |

The gear drop is instantiated with `loot_type = 1`, which is
`LootType.HP_POTION` in [`loot_drop.gd`](loot-drop.md)'s enum — the payload
carries the real item, but the **sprite shown is the potion sprite** for every
gear drop. A visual bug, not a functional one.

## Related

- [entity.md](entity.md) · [world.md](world.md) · [loot-drop.md](loot-drop.md)
- [item-database.md](item-database.md) — the drop tables' item definitions
- [wire-protocol.md](wire-protocol.md) — `monster_hit`, `monsters_sync`
