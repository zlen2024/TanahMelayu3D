# Known Gaps

Every documented limitation, confirmed bug, and tooling blind spot in one
place. Security findings live separately in
[security-notes.md](security-notes.md).

Each entry is graded **Confirmed** (traced to lines, both sides checked) or
**Suspected** (looks wrong, not yet proven). Do not promote one without doing
the work.

---

## G1 — `db.getUserInventory` does not exist; PK deaths throw

**Confirmed. This is the most consequential bug found.**

`server.js:291` calls `db.getUserInventory(ws.userId)`. That function is
**not defined anywhere in `db.js`** and is **not exported** — `module.exports`
(`db.js:331-340`) lists `getFullInventory`, and the eight functions defined in
the file are `hashPassword`, `registerUser`, `loginUser`, `saveCharacter`,
`allocateStat`, `addInventoryItem`, `useInventoryItem`, `getFullInventory`.

Consequence chain, in the `player_died` handler (`server.js:285-311`):

1. A player dies with `msg.is_pk` and `msg.attacker_id` truthy.
2. `db.getUserInventory(...)` raises `TypeError: db.getUserInventory is not a function`.
3. The `try` wrapping the whole message loop catches it (`server.js:318-320`)
   and logs `[!] Error parsing message from <id>`.
4. Execution never reaches `broadcast(msg, ws)` at `server.js:310`.

So a PK death is **not relayed at all** — no `loot_dropped`, no system chat
line, and no `player_died` broadcast. The failure is silent apart from a log
line that misattributes it to a parse error.

Note this is *only* on the PK path; a normal (non-PK) death skips the block
and broadcasts fine.

*Fix shape:* rename the call to `getFullInventory`, then check its return
shape — the code expects an array it can `.filter(it => it != null)` and index
by `.slot`.

## G2 — Seven server→client message types have no client handler

**Confirmed.** Full table in [wire-protocol.md](wire-protocol.md). The
gameplay-visible consequences:

| Type | What silently does not happen |
|---|---|
| `roll` | Remote dodge rolls are never animated |
| `pk_toggle` | **PK status is invisible to everyone but the toggling player** |
| `player_died` | Remote deaths are not rendered |
| `loot_dropped` | PK loot never appears (and G1 means it is never sent) |
| ~~`error_msg`~~ | **Handled since 2026-09-06** — surfaced as a SYSTEM chat line |

`take_damage` and `heal` have server `case` arms (`server.js:265-266`) that
no client ever sends — dead on both ends.

## G3 — `stat_sync` for `xp` is sent but never applied

**Confirmed.** `player.gd:186-190` broadcasts `{"stat": "xp"}` on every XP
gain. The client handler (`network_manager.gd:278-286`) branches only on
`level`, `hp` and `max_hp`. Remote XP values are relayed and dropped.

The server *does* record it (`server.js:248`) and persists it on disconnect,
so this is a display gap, not a data-loss gap.

## G4 — Monsters are addressed by array index

**Confirmed.** `monster_hit` sends `get_index()` (`monster.gd:264`) and
`monsters_sync` sends a positional `idx` (`network_manager.gd:136`). Both are
resolved with `monsters.get_child(idx)` (`network_manager.gd:298`, `:336`).

There is no stable monster id in the protocol. This works only while every
client's `Monsters` container holds identical children in identical order.
`world.gd:23-40` spawns deterministically today, so it holds — but nothing
enforces it, and any future feature that spawns, despawns or reorders
monsters at runtime will silently desynchronise combat: damage will land on
the wrong monster rather than erroring.

## G5 — Every client simulates the full monster set

**Confirmed.** `world.gd:16` gates spawning on `multiplayer.is_server()`,
which is `true` on every client here: no `MultiplayerPeer` is ever assigned,
so Godot 4's default `OfflineMultiplayerPeer` reports peer id 1.

Non-host clients then short-circuit their AI (`monster.gd:112-115`) and lerp
toward host-supplied positions, so behaviour is correct. But the physics
bodies, state machines and `_draw()` telegraphs all still exist on every
client. It is wasted work, and it is the reason G4 matters.

## G6 — Loot spawns independently on every client

**Confirmed.** `monster._die()` calls `_spawn_loot()` unconditionally
(`monster.gd:294`), and remote clients reach `_die` through
`apply_sync_state` when the host reports `dead: true`
(`monster.gd:92-93`).

So each client instantiates its **own** copy of the drop. Pickup is
server-authoritative (`item_pickup` → `db.addInventoryItem`), so this is not
an inventory duplication exploit against one player — but it does mean loot
is **not contested**: two players can each walk over their own local copy of
the same drop and both receive the item.

Whether that is a bug or a design choice is undecided; it is recorded here
because the code does not say which.

## G7 — `npm run dev` cannot work

**Confirmed.** `server/package.json:9`:

```json
"dev": "node server.js & node serve_web.js"
```

`server.js` binds `process.env.PORT || 8080` (`server.js:13`) and
`serve_web.js` binds `process.env.WEB_PORT || 8080` (`serve_web.js:10`). With
neither variable set, the second process fails with `EADDRINUSE`.

The `&` is also POSIX background syntax, which does not background on
`cmd.exe` — and this is a Windows-first project (all tooling is PowerShell).

*Fix shape:* the script is vestigial. See G8.

## G8 — `serve_web.js` is superseded and unreferenced

**Confirmed.** `code2graph module-deps` over `server/` reports exactly one
edge — `server.js -> db.js`. `serve_web.js` has no inbound edges from code;
the only references anywhere in the repo are the two npm scripts
(`package.json:8-9`).

It is a standalone static file server from before `server.js` was unified to
serve `dist/` and WebSockets on one port — which the README now presents as
the headline design ("Single port"). Its `MIME_TYPES` map and request handler
are near-duplicates of `server.js:16-92`.

*Fix shape:* delete the file and the `serve` / `dev` scripts, or document it
as an intentional standalone.

## G9 — README describes a different, smaller game

**Confirmed.** The README documents skins, melee/projectile attacks,
monsters, XP, chat, HUD and loot. The code additionally implements, with no
README mention:

- Account **auth** and SQLite persistence (`db.js`, `lobby_ui.gd`)
- Three **classes** with distinct stats and three skills each
  ([hero-class.md](hero-class.md))
- **Stat allocation** across STR/VIT/AGI/INT ([stats-panel.md](stats-panel.md))
- **Inventory**, equipment paperdoll and quick slots
  ([inventory-ui.md](inventory-ui.md))
- **Energy**, **stamina**, **dodge roll** with i-frames ([player.md](player.md))
- **Charged attacks** and **stun** ([entity.md](entity.md))
- **PK mode** (`game_state.gd:226`)
- An **item database** with rarity and level gating
  ([item-database.md](item-database.md))

It also actively contradicts the code in two places:

- It claims high-level `@rpc` synchronisation. The transport is raw
  `WebSocketPeer` + JSON. See [decisions.md](decisions.md).
- It claims COOP/COEP headers are unnecessary. `server.js:85-86` sets both.
  See G10.

## G10 — COOP/COEP headers are set despite the README saying they are not needed

**Confirmed.** `server.js:85-86` sets `Cross-Origin-Opener-Policy: same-origin`
and `Cross-Origin-Embedder-Policy: require-corp` on every static response. The
README explicitly sells the single-threaded export as needing neither.

Everything is served same-origin from `dist/`, so it works today. But
`require-corp` demands that *cross-origin* subresources carry
`Cross-Origin-Resource-Policy`, and the server never sets that header — so the
moment any asset moves to a CDN, loading breaks. On itch.io, where the game is
served by their infrastructure rather than this server, these headers do not
apply at all.

**Suspected:** these were added while debugging a threaded export and never
removed. Not verified — no git history to check (single initial commit).

## G11 — Solo/guest mode duplicates networked logic

**Confirmed.** `send_allocate_stat` (`network_manager.gd:440-462`),
`send_item_pickup` (`:464-486`) and `send_item_use` (`:488-503`) each carry a
full `is_solo_mode` branch that mutates `GameState` directly, mirroring what
the server would otherwise do in `db.js`.

The two implementations already disagree: the solo branch of
`send_allocate_stat` recomputes `max_energy` as `30 + stat_int * 5`
(`network_manager.gd:451`), while the server adds `+5` incrementally
(`db.js:230`) on top of a class-dependent base (`db.js:45`). Guest and
logged-in characters therefore diverge in max energy for the same stats.

## G12 — Character progress is saved only on disconnect

**Confirmed.** `db.saveCharacter` has exactly one caller, in the `close`
handler (`server.js:323-342`). A server crash, container restart or network
drop that skips a clean close loses all level/XP/stat progress since login.

Inventory is unaffected — it writes through immediately on every pickup and
use.

## G13 — Crit chance applies to warrior melee only

**Confirmed.** `CombatFormula.is_critical_hit` has exactly one caller:
`WarriorClass._deal_player_damage` (`warrior_class.gd:74`).

Mage and archer damage flows through `projectile.gd:47` / `:55`, which calls
`take_damage` with a flat value and never consults the crit formula. So AGI's
crit contribution (`combat_formula.gd:23-25`) is dead for two of the three
classes, and for warrior skills — `damage_enemies_in_radius`
(`player.gd:315-321`) also bypasses it.

**Suspected** intent: crit was meant to be global. Not verified.

## G14 — Every level-gated item is permanently unequippable

**Confirmed.** [`inventory_ui.gd:148`](inventory-ui.md) passes a literal `1`
where the player's level belongs:

```gdscript
var success = GameState.equip_item(slot_idx, 1) # Checked against level
```

`GameState.equip_item` compares that argument against the item's `lvl_req`
(`game_state.gd:167-169`) and returns `false` when it is lower. With the
argument pinned to 1, **any item requiring level 2+ can never be equipped**,
at any level.

Five of thirteen items in [`ItemDatabase`](item-database.md) are affected —
and they are exactly the rare drops:

| Item | `lvl_req` | Dropped by |
|---|---|---|
| `sword_steel` | 5 | Magma Slime |
| `bow_composite` | 5 | Magma Slime |
| `amulet_agility` | 5 | King Slime |
| `wand_archmage` | 6 | King Slime |
| `armor_king` | 10 | King Slime |

So **every boss reward in the game is dead loot.** The UI reports
"Cannot equip … (Level/Class mismatch)" (`inventory_ui.gd:153`) regardless of
the player's real level, which makes it read as a class restriction rather
than a bug.

Combined with G1 (PK deaths throw before dropping loot) and G6 (loot is
uncontested), the entire itemisation end-game is currently non-functional.

*Fix shape:* resolve the local player's level the way
[`stats_panel.gd:106-110`](stats-panel.md) already does — scan the `players`
group for `is_local` and read `.level`. The correct pattern exists six lines
away in a sibling file.

## G15 — `dodge` is not a defined input action

**Confirmed.** `player.gd:240` calls `event.is_action_pressed("dodge")`, but
`project.godot`'s `[input]` section defines only `move_left`, `move_right`,
`move_up`, `move_down`, `attack`, `chat_toggle`, `scoreboard`, `skill_1`,
`skill_2` and `skill_3`. There is no `dodge`.

Godot logs an error for a nonexistent input action, and this is evaluated on
input events, so it produces recurring log noise. The dodge roll still works
only because the same condition has an explicit `KEY_SHIFT` fallback.

Related: skills are bound twice — `skill_1/2/3` via the action map
(`player.gd:216-221`) and raw `KEY_1/2/3` in `_unhandled_input`
(`player.gd:249-254`), where the actions are themselves bound to keycodes
49/50/51. Pressing `1` dispatches `_execute_skill(1)` twice; the cooldown
check absorbs the second call, so it is currently harmless.

## G16 — README documents the wrong controls

**Confirmed.** The README's control table lists "Cast Spell: `Shift` +
`Spacebar`".

In the code, `Shift` is the **dodge roll** (`player.gd:240`) and the charged
attack is a **held `Spacebar`** for 0.4 s, gated on level 11
(`player.gd:200-213`). The README also omits `C` (stats), `B`/`I`
(inventory), `Q`/`E` (quick slots) and `1`/`2`/`3` (skills) entirely.

## G17 — ~~Monsters never respawned~~ (fixed)

**Fixed 2026-09-05.** Reported by the user; confirmed and fixed in the same
pass.

`Monster._die()` set `is_dead`, disabled collision and spawned loot — but
scheduled no respawn, never called `queue_free()`, and never hid the sprite.
Three consequences:

1. A dead slime remained in the tree as a **frozen, un-hittable corpse**,
   still visible on the map.
2. It never came back. There was no respawn timer anywhere in the class, and
   `Entity`'s `entity_died` signal (`entity.gd:11`, emitted `:91`) had **zero
   listeners** — that was the intended hook, never wired up.
3. `world.gd:20`'s fallback re-spawn is guarded on
   `monsters_container.get_child_count() == 0`, which could never become true
   because the dead monsters were still children.

Net effect: clear the arena once and it stayed empty for the rest of the
session, littered with frozen corpses.

**The receiving half already existed.** `apply_sync_state`'s resurrection
branch (`monster.gd:92-103`) restores visibility, collision, state and
`can_attack` when the host reports a monster alive again — written for exactly
this cycle, but nothing ever triggered it. Only the host-side countdown was
missing.

Fix: `RESPAWN_TIME` 8 s / `RESPAWN_TIME_BOSS` 30 s (`monster.gd:38-39`), armed
in `_die()` (`:304`), counted down at the top of `_physics_process`
(`:113-118`), and applied by a new `_respawn()` (`:331`).

Two details that matter:

- The countdown runs **before** `process_entity_status()`, which early-returns
  for dead entities — a timer ticked after it would never advance.
- It is gated on `is_room_host or is_solo_mode`, matching the AI gate. Remote
  clients do not count down independently; they resurrect from the host's next
  `monsters_sync`, so every client's respawn moment is identical rather than
  drifting.

Regression test: `_test_monster_respawn` (11 assertions), covering the hidden
corpse, the countdown threshold, HP/position/state restoration, re-killability,
and the longer boss timer.

**Follow-up worth considering:** respawn re-runs the full death path, so
`_spawn_loot()` now fires every cycle. Combined with G6 (loot spawns
per-client and is uncontested) this makes farming considerably more generous
than it probably should be. A balance pass is warranted; it was out of scope
for the bug fix.

## G18 — ~~Idle lobby tab could hold host authority~~ (fixed)

**Fixed 2026-09-05.** Surfaced while diagnosing a "monsters still don't
respawn" report.

Authority was claimed on **connect** (`server.js:116-119`), but
[`lobby_ui.gd`](lobby-ui.md) auto-connects in `_ready()` — before the player
logs in. So a tab parked on the login screen became host and stayed host,
while never entering the world.

Two things made that actively harmful:

1. The idle tab still runs `world.gd`, spawns monsters and broadcasts
   `monsters_sync` — so it *was* driving simulation, just for a session nobody
   was playing.
2. **Browsers throttle background tabs.** With the host tab backgrounded,
   `_physics_process` slows to a crawl or stops, stalling monster AI and the
   new respawn countdown (G17) for every other player. Respawn appears broken
   even though the logic is correct.

Fix: on `player_join`, if the current host is not in the `players` map, hand
authority to the joining client (`server.js:224-243`). The previous holder is
told via a new **`host_revoked`** message
([wire-protocol.md](wire-protocol.md)) — without it the old host keeps
broadcasting and fights the new one over monster state.

Regression test: `testHostAuthorityTransfer` in `tests/test_server_network.js`
(3 assertions) — an idle client connects first, a second client joins, and the
test asserts the joiner is promoted and the idle client revoked.

**Still open:** if the *only* player backgrounds their tab, they are the host
and their own simulation still stalls. That is inherent to client-authoritative
monsters in a browser and would need server-side simulation to fix properly.

## G19 — ~~Attribute points could never be spent~~ (fixed)

**Fixed 2026-09-06.** Reported as "stats seem not set well".

Levelling granted points **client-side only** (`player.gd:405`,
`GameState.unspent_stat_points += 3`). Nothing ever told the server, so
`characters.stat_points` in SQLite stayed at its registration value of 0.

`db.allocateStat` gates on exactly that column (`db.js:222-224`), so every
allocation was rejected with `No stat points available.` — returned as
`error_msg`, which **had no client handler** (G2). The panel showed "Unspent
Points: 12" and the `+` buttons did nothing, silently.

Fix: the server now derives points from the level it is told about.
`db.grantLevelPoints()` awards `3 × (newLevel − storedLevel)` and updates the
stored level; `server.js` calls it on `stat_sync` for `level` and replies with
the authoritative character. Deriving from level rather than accepting a point
count keeps the client from simply handing itself points.

`error_msg` is now handled too, so a rejection is visible instead of silent.

## G20 — ~~Allocating a stat silently re-classed the character~~ (fixed)

**Fixed 2026-09-06.** Found while fixing G19, and almost certainly the cause of
the reported "archer has warrior basic attack".

The `stat_allocated` payload omitted `class_type` (`db.js`, old inline object
in `allocateStat`). The client's
`GameState.load_character_stats()` (`game_state.gd:76`) defaults a missing
`class_type` to `"warrior"` — so the first successful allocation converted a
mage or archer into a warrior, and `recalculate_stats()` then rebuilt the
strategy as `WarriorClass`.

It was latent only because G19 meant allocation never succeeded. Fixing G19
alone would have exposed it immediately.

Fix: a single `characterPayload()` helper in `db.js` now builds every character
response and always includes `class_type` and `level`.

## G21 — ~~Ranged classes used the warrior's melee swing and flat damage~~ (fixed)

**Fixed 2026-09-06.**

Three separate problems in the mage and archer basic attacks:

1. Both called `player.play_slash_effect()` — the warrior's melee sword swing —
   so a ranged class visibly meleed while also firing.
2. `NetworkManager._spawn_projectile()` never set `damage`, so every ranged
   basic attack dealt the projectile's `@export` default of **25**, ignoring
   the player's ATK entirely. (A level-5 archer with ATK 54 hit for 25.)
3. No auto-aim and no distinct range: shots always flew along `facing_dir`.

Fix: `HeroClass.acquire_target()` / `aim_dir()` (`hero_class.gd`) pick the
nearest living monster within `AUTO_AIM_RANGE` (320) and fall back to
`facing_dir` when nothing is in range. `_spawn_projectile()` takes optional
`damage` and `max_range` (defaults preserved for relayed remote shots).
`Player.face_direction()` was extracted so auto-aim and keyboard input share
one facing path.

Archer basic shots travel 380 px, mage bolts 330 px.

**Still open:** the mage's Frost Nova (`mage_class.gd:68`) still uses the melee
slash sprite as its only visual. It needs its own effect rather than simply
removing the feedback.

---

## Tooling gaps

## T1 — code2graph cannot see GDScript

**Confirmed.** `code2graph` is tree-sitter based with no GDScript grammar.
`code2graph index .` inside `scripts/` reports:

```
indexed 0 files; 0 changed, 0 deleted; complete
admitted files=0 bytes=0 omitted=0
```

That is **21 of 22** GDScript files — the overwhelming majority of this
codebase — invisible to `symbols`, `callers`, `usages` and `impact`. Only
`server/` (3 JS files, 37 symbols) is genuinely queryable.

`wiki/graph/build_graph.py` fills the hole with a regex extractor. Its
limits, which are real and worth knowing before trusting its output:

- **No scope awareness.** Members are recognised by column-0 indentation
  alone, so a member declared inside an `if` block would be missed, and any
  future nested function would be misfiled.
- **No call graph for GDScript.** It extracts declarations and
  `load()`/`preload()` edges only. Every "who calls X" claim about GDScript in
  this wiki came from `grep`, not from a resolved graph.
- **Dynamic dispatch is invisible either way.** `HeroClass.create()`
  (`hero_class.gd:22-32`) selects a subclass by string, and the entire
  protocol dispatches on a string `match`. No static tool sees those edges.

## T2 — ~~Godot tests cannot run in this environment~~ (resolved)

**Resolved 2026-09-05.** The suite runs fine here: 94 assertions, 94 passed,
exit 0. The original entry was written before it had been attempted.

Run it directly with:

```bash
./bin/Godot_v4.3-stable_win64_console.exe --headless res://tests/test_runner.tscn
```

(It prints two harmless shutdown warnings about leaked `ObjectDB` instances
and one resource still in use — the tests `queue_free()` nodes that never get
a frame to be collected in. Exit code is still 0.)

The **Node** suite (`tests/test_server_network.js`) has still not been run.

Original entry: `tools/run_all_tests.ps1` invokes
`bin/Godot_v4.3-stable_win64_console.exe --headless res://tests/test_runner.tscn`.
The binary is present but the suite was **not executed** during this ingest,
so every claim in [testing.md](testing.md) about the GDScript tests is drawn
from reading `tests/run_game_tests.gd`, not from a passing run.

Nothing in this wiki asserts that the tests pass.
