# `scripts/entities/loot_drop.gd`

extends `Area2D` · 89 LOC · no `class_name` — instantiated from
`res://scenes/loot_drop.tscn`.

A collectible on the ground. Spawned by
[`monster._spawn_loot()`](monster.md) (`monster.gd:310`).

## Loot types

`enum LootType { XP_GEM, HP_POTION, MP_POTION, SWORD, ARMOR, WAND, GOLD }`
(`:5`).

`_ready()` matches on it to pick sprite and tint (`:21-42`). The sprite set is
thin — `potion_hp.png` is reused for `MP_POTION` and `ARMOR`,
`gem_xp.png` for `GOLD`, `slash.png` for `SWORD`, and `projectile.png` for
`WAND` — recoloured via `modulate`.

## The two collection paths

`_on_body_entered` (`:48`) splits on whether the drop is an XP gem:

**XP gem** (`:50-54`) — calls `body.gain_xp(value)` directly on the player and
frees. Purely local; no server round-trip, because XP lives in the client's
`player.gd` and is only pushed via `stat_sync`.

**Everything else** (`:55-89`) — builds an item dictionary and calls
`NetworkManager.send_item_pickup(final_payload)` (`:85`), then frees
immediately.

## `item_payload` overrides the enum

`item_payload` (`:9`) is the real mechanism. When a monster drops gear it
sets both `loot_type = 1` **and** `item_payload = ItemDatabase.create_item(id)`
(`monster.gd:343-344`).

`_ready()` only ever looks at `loot_type` for the sprite, so **every gear drop
renders as a health potion** — the payload carries the true item, the visual
does not. `_on_body_entered` prefers `item_payload` when non-empty
(`:60-63`, `:79-84`) and falls back to the enum-derived defaults
(`:65-77`) otherwise.

The fallback table is a **fourth** place item names and types are written
down, duplicating [`ItemDatabase`](item-database.md) — e.g. `"Iron Blade (+5
STR)"` at `:71` versus the database's own `sword_iron` entry. Nothing keeps
them in sync.

## Notes

- **Pickup is optimistic.** The node frees itself (`:88`) without waiting for
  the server's `inventory_sync`. If `addInventoryItem` fails — bag full
  (`db.js` returns an error) — the server replies `error_msg`, which
  **no client handles** ([known-gaps.md](known-gaps.md) G2). The item is gone
  from the world and never arrives in the bag.
- **Drops are per-client.** Each client spawns its own copy of every drop
  ([known-gaps.md](known-gaps.md) G6), so two players can each collect "the
  same" item.
- `_process` (`:44`) bobs the sprite with a sine wave — cosmetic only, but it
  runs every frame for every drop on the ground, and drops are never
  garbage-collected on a timer.

## Related

- [monster.md](monster.md) — the only spawner
- [item-database.md](item-database.md) — the canonical item definitions
- [network-manager.md](network-manager.md) — `send_item_pickup`
