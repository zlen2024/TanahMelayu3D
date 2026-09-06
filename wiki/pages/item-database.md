# `scripts/items/item_database.gd`

`class_name ItemDatabase` · extends `RefCounted` · 186 LOC · all members
`static`.

The item registry: a single `const ITEMS` dictionary (`:6`) plus three static
helpers.

## The catalogue

13 items, keyed by id:

| Category | Ids |
|---|---|
| Consumable | `potion_hp` (heal 60) · `potion_mp` (energy 50) |
| Weapon | `sword_iron` · `sword_steel` · `wand_mystic` · `wand_archmage` · `bow_hunting` · `bow_composite` |
| Armor | `armor_plate` · `robe_cloth` · `armor_king` |
| Accessory | `ring_vitality` · `amulet_agility` |

Each entry carries `id`, `name`, `slot_type`, `rarity`, `class_req`,
`lvl_req`, `description`, and then either `effect` (consumables) or `stats`
(gear).

`stats` keys are the same four that
[`GameState.get_equipment_bonus`](game-state.md) sums and that
[`CombatFormula.calc_player_stats`](combat-formula.md) consumes: `atk`, `def`,
`hp`, `mp`. The best-in-slot `armor_king` gives `def 25 / hp 120 / mp 30`
(`:119`).

Two `stats` keys are read by `player.gd` but **defined by no item**:
`mp_regen` and `hp_regen` (`player.gd:143`, `:160`). Those lookups always
return 0 today, so gear can never modify regeneration.

## `create_item(item_id, quantity)` — `:146`

Deep-duplicates the template and stamps `quantity`. The deep copy matters:
without it every instance of a sword would share one `stats` dictionary.

**Unknown ids do not fail.** They produce a synthetic Common consumable named
by capitalising the id (`:147-156`). That is why a typo'd drop id yields a
plausible-looking junk item rather than an error — worth knowing when
debugging loot.

Callers: `monster.gd:344` (loot) and `run_game_tests.gd:500`.

## `get_rarity_color(rarity)` — `:163`

Maps Uncommon→green, Rare→blue, Epic→purple, everything else→grey. Used only
by [`inventory_ui.gd`](inventory-ui.md) (`:94`, `:99`, `:104`, `:125`) to tint
slot buttons.

No item in `ITEMS` uses the rarity `"Legendary"`, and the match has no arm for
it — a Legendary item would render grey.

## `can_equip(item, hero_class, player_level)` — `:174`

Validates slot type, class requirement and level requirement.

**It has no callers.** [`GameState.equip_item`](game-state.md) performs the
same three checks inline (`game_state.gd:157-169`) rather than calling this,
and no test covers it.

The two implementations already differ: `can_equip` requires `slot_type` to be
one of `weapon`/`armor`/`accessory` (`:177-178`), while `equip_item` instead
checks membership in the `equipped_gear` dictionary (`game_state.gd:158`).
Those agree today only because `equipped_gear` happens to have exactly those
three keys (`game_state.gd:42`). Whichever is meant to be canonical, the
duplicate should go.

## The four-way duplication of item data

This file is the intended source of truth, but item facts are written down in
four places that nothing keeps in sync:

1. **Here** — the canonical registry.
2. **`loot_drop.gd:65-77`** — a fallback name/type table for drops without an
   `item_payload`, with its own hardcoded names like `"Iron Blade (+5 STR)"`.
3. **`network_manager.gd:522-526`** — `_apply_item_effect` hardcodes heal 60 /
   energy 50 for `potion_hp` / `potion_mp` instead of reading `effect`.
4. **`db.js`** — the server stores `item_id`, `item_name` and `item_type` as
   free text and validates nothing against this list, because it is GDScript
   and the server cannot read it.

Point 4 is the root of [security-notes.md](security-notes.md) S2: the server
cannot verify an item because the catalogue lives on the client.

## Related

- [game-state.md](game-state.md) — equipment slots and stat bonuses
- [inventory-ui.md](inventory-ui.md) — the only consumer of rarity colour
- [monster.md](monster.md) — drop tables referencing these ids
