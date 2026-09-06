# `server/db.js`

Node.js · 340 LOC · **zero external dependencies** — uses Node 22+/24's
built-in `node:sqlite` (`DatabaseSync`) and `node:crypto`.

The only module [`server.js`](server-js.md) imports
(`code2graph module-deps`: `server.js -> db.js`, the project's single JS
module edge).

## Storage

`DB_PATH` defaults to `server/data/rpg.db`, overridable via the `DB_PATH`
environment variable (`:17`) — which is how the test suite gets an isolated
database.

Three tables, created idempotently at import time (`:21-62`):

| Table | Key columns |
|---|---|
| `users` | `id`, `username` (UNIQUE, `COLLATE NOCASE`), `password_hash`, `salt` |
| `characters` | `user_id` (UNIQUE), `name`, `class_type`, `skin`, `level`, `xp`, `stat_str/vit/agi/int`, `stat_points`, `hp`, `max_hp`, `energy`, `max_energy`, `pos_x`, `pos_y` |
| `inventory` | `user_id`, `slot_index`, `item_id`, `item_name`, `item_type`, `quantity` |

`COLLATE NOCASE` on `username` means logins are case-insensitive and
`Hero` and `hero` cannot both register.

`characters.user_id` is UNIQUE — **one character per account**, by schema.

## The one migration

`:64-68` — an idempotent `ALTER TABLE` in a try/catch, adding `class_type`
with a `'warrior'` default. It tells us the class system was added after the
schema first shipped, and existing characters were silently defaulted rather
than prompted. See [decisions.md](decisions.md) D4.

There is no migration framework and no schema version; a second migration
would have to follow the same pattern.

## Auth

`hashPassword(password, salt)` (`:70`) — `crypto.scryptSync(password, salt, 32)`
hex-encoded, with default scrypt parameters.

`registerUser` (`:74`) validates length (username ≥ 2, password ≥ 3),
rejects duplicates, generates a 16-byte random salt, inserts the user, then
seeds a character and starter potions.

Class baselines are assigned here (`:96-119`), and they are **a different set
of numbers** from both `combat_formula.gd` and `network_manager.gd`'s guest
table:

| | STR | VIT | AGI | INT | HP | Energy | Potions (HP/MP) |
|---|---|---|---|---|---|---|---|
| Warrior | 14 | 12 | 9 | 5 | 180 | 60 | 3 / 1 |
| Mage | 5 | 8 | 9 | 16 | 120 | 120 | 1 / 3 |
| Archer | 10 | 10 | 15 | 7 | 140 | 80 | 2 / 2 |

The guest table (`network_manager.gd:400-404`) matches these stats but ships a
flat 3 HP / 2 MP potions for every class — so a guest warrior starts with a
different bag than a registered one.

`registerUser` ends by **calling `loginUser`** (`:141`) to build its response,
which re-verifies the just-set password. Slightly wasteful, but it guarantees
register and login return an identical payload shape.

`loginUser` (`:144`) looks up the user, re-hashes with the stored salt, and
compares with `===` (`:151-155`) — not a constant-time comparison. See
[security-notes.md](security-notes.md) S8.

## Character and inventory operations

- **`saveCharacter(userId, charData)`** (`:202`) — bulk update. One caller:
  `server.js:328`, on disconnect only.
- **`allocateStat(userId, statName)`** (`:220`) — checks `stat_points > 0`,
  maps the stat name through a four-way allowlist to a SQL fragment
  (`:227-231`), decrements the point, returns the fresh character.

  VIT also grants `+10 max_hp` and `+10 hp`; INT grants `+5 max_energy` and
  `+5 energy` (`:228`, `:230`) — increments that do not match the client's
  formula in [`combat_formula.gd`](combat-formula.md).

  This is the **one** statement in the file built by string interpolation
  rather than a prepared statement (`:233-238`). Not currently exploitable —
  see [security-notes.md](security-notes.md) S7.
- **`addInventoryItem(userId, item)`** (`:257`) — stacks `consumable` and
  `currency` types into an existing slot, otherwise finds the first free slot.
  Trusts the item wholesale ([security-notes.md](security-notes.md) S2).
- **`useInventoryItem(userId, slotIndex)`** (`:289`) — decrements quantity or
  deletes the row. Also used by `server.js:295` to *remove* an item on PK
  death, i.e. as a generic "delete one item" primitive rather than a "use".
- **`getFullInventory(userId)`** (`:314`) — reads all slots. Called internally
  after mutations (`:263`, `:286`, `:306`).

## Exports

`module.exports` (`:331-340`) lists `db`, `registerUser`, `loginUser`,
`saveCharacter`, `allocateStat`, `addInventoryItem`, `useInventoryItem`,
`getFullInventory`.

**`getUserInventory` is not among them, and is defined nowhere** — yet
`server.js:291` calls it. That is [known-gaps.md](known-gaps.md) G1.

Exporting the raw `db` handle is worth noting: it lets any importer run
arbitrary SQL, bypassing every validation in this module. Only the test suite
would have reason to, and it does not.

## Related

- [server-js.md](server-js.md) — the sole consumer
- [security-notes.md](security-notes.md) — S1, S2, S7, S8
- [combat-formula.md](combat-formula.md) — the client's competing stat model
