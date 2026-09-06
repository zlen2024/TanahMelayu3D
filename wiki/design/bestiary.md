# Bestiary, Level 1–20 — STATUS: PLAN

**Regions:** Pinggir Muara Hangus · Pangkalan Pasar Gelap · Paya Keramat Lama

Enemies split into two tracks:

- **Manusia** — street gangs and criminals
- **Jin** — wild subterranean entities and lesser folk-supernatural

That split is the strongest structural idea in the brief. Two tracks give
different counterplay, a tonal contrast, and a natural axis for gear
(steel vs. warding).

## Common enemies

| Lv | Manusia | Jin |
|---|---|---|
| **1** | **Penyamun Laluan** — basic melee grunt, rusted parang, wild telegraphed swings. Teaches parry/dodge timing. | **Jin Tanah** — ranged nuisance. Clay figure wrapped in rotted shroud cloth; lobs earth and stone to break focus. |
| **5** | **Pencuri Saku Pangkalan** — agile skirmisher with a short badik. Ambushes from stall gaps, stabs and leaps back (hit-and-run). | **Toyol Belaan** — fast melee crippler. Green slimy dwarf, red eyes; scurries low and claws ankles to slow movement. |
| **10** | **Pemungut Ufti Pasar** — heavy bruiser/tank. Nail-studded club, high poise. **Overhead swing is unblockable — must be dodged.** | **Hantu Jerut** — crowd control / grabber. Giant python-form jin; silent glide from the swamp into a choke grab that drains stamina. |
| **15** | **Penjenayah Pelontar Minyak Api** — ranged area denial. Clay firebombs create persistent burn zones that force repositioning. | **Pelesit Bangkai** — flying harasser. Human-headed locust jin; dive-claws the face, its drone blurs vision and drains Nafs/Semangat. |
| **19** | **Kepala Begal Liku Gelap** — elite pre-boss duelist. Twin silver goloks, street silat, **counter-parries the player** and answers with fast combos. | **Jin Belian Liar** — heavy charger. Wild jin riding a great iron-bristled boar; unstoppable straight-line charge that launches on full impact. |

### Design observations

**The difficulty curve is well built.** Lv1 teaches reading a telegraph; Lv10
introduces the unblockable that punishes pure blocking; Lv19 puts a
counter-parrying duelist in front of the boss so the player must stop mashing.
That is a deliberate teaching order and it should be preserved.

**But three enemies depend on systems the game does not have:**

- **Pemungut Ufti Pasar** — "unblockable, must dodge" only means something if
  blocking exists. It does not ([class-pendekar.md](class-pendekar.md) Q2).
  Without a block verb, this enemy is just a slow heavy hitter.
- **Hantu Jerut** — a choke *grab* is a two-entity locked state with an escape
  input. Same synchronised-cutscene problem as Kunci Sendi Melorot, and in
  multiplayer it needs the grabbed player's client to agree.
- **Kepala Begal Liku Gelap** — counter-parry requires enemy AI that reads
  *incoming* player attacks and reacts inside a window. Current AI is a
  chase/windup/strike state machine ([../pages/monster.md](../pages/monster.md))
  with no notion of what the player is doing.

**Pelesit Bangkai drains "Nafs/Semangat"** — that assumes every class has a
drainable class resource. If the resources diverge per class
([open-questions.md](open-questions.md) Q1), what does this drain from a Jagat
whose resource is a stealth state rather than a bar?

## Level 20 bosses

Two, one per track. **The brief does not say whether the player fights both,
picks one, or meets them in different regions** — see Q13.

### Tok Begal Belah Retak (Manusia)

Ex-convict from a penal colony, body scarred from old death sentences. Runs
smuggling, estuary robbery and extortion of the fishing villages on Melaka's
edge.

**Arena:** a half-collapsed timber dock warehouse at the saltwater line.
**Gear:** giant rusted parang lading; a tiger-claw kerambit hidden at the left
wrist.

| Phase | Behaviour |
|---|---|
| **1 — Kudrat Algojo Jalanan** | Wide parang swings that grind posture. Heel-kicks the chest if the player turtles in front of him too long. |
| **2 — Helah Kotor Samseng** (50% HP) | Smashes a lime-powder jar; white fog blinds the player. He then slides in from blind spots with rapid bleeding kerambit thrusts. |

The **anti-turtling kick** is a good detail — it punishes the exact defensive
habit Phase 1 encourages. The hidden second weapon revealed in Phase 2 is
strong: the *reveal* is a mechanic, not a cutscene.

Systems needed: posture, bleed, and a **vision-obscuring effect**. That last one
raises a multiplayer question — does the fog blind only the players in the
arena, or everyone?

### Saka Askar Perang Lama (Jin)

A military saka bound generations ago, its master long dead. Left without an
owner it went feral, blood-hungry, tethered to the bones of old battle dead.

**Arena:** a muddy swamp valley bristling with broken weapon blades.
**Form:** tall stooped figure in rotted mail scraps and a blood-dried tengkolok
fused to its flesh; a broken pedang jenawi weeping black fluid.

| Phase | Behaviour |
|---|---|
| **1 — Hayunan Mayat Berperisai** | Slow broken-sword swings with **full super-armour** — player hits do not interrupt. Each swing leaves black miasma on the ground. |
| **2 — Amukan Saka Rimba** (40% HP) | Throws the sword away, drops to all fours, moves like an animal. An inner howl applies an attack-power debuff, then repeated claw lunges. |

The phase transition is excellent: **discarding the weapon to become faster and
more animal** is a legible visual promise, and armour-to-feral is a real
behavioural inversion rather than a stat change.

Systems needed: super-armour (poise), persistent ground hazard (miasma —
shares the hazard system with
[class-pemanah-rimba.md](class-pemanah-rimba.md)), and stat debuffs.

**Thematic note.** A weapon-spirit outliving its master and turning on the
world is a strong fit for [setting.md](setting.md)'s proposed frame — the
player is also a warrior whose master is gone. The boss is what the player
could become. That parallel is free and worth using.

## Implementation reality

**Monster stats are hardcoded in an if/elif chain** in `_ready()`
(`monster.gd:59-88`), and only **two** of the three existing types are even
reachable — `RED_SLIME` is never spawned
([../pages/monster.md](../pages/monster.md)).

Twelve new enemies cannot go through that chain. This needs a **data-driven
monster definition** — the same shape as `ItemDatabase`, or better, a shared
JSON both GDScript and the Node server can read (which would also address
[../pages/security-notes.md](../pages/security-notes.md) S2's root cause).

Also: monsters are currently addressed by container index, so **spawn order is
protocol** ([../pages/known-gaps.md](../pages/known-gaps.md) G4). Region-based
spawning with varied enemy types makes that far more fragile. Stable IDs should
land before the bestiary does.

## Related

- [open-questions.md](open-questions.md) — Q2, Q3, Q5, Q13, Q14
- [../pages/monster.md](../pages/monster.md) · [../pages/terrain.md](../pages/terrain.md)
