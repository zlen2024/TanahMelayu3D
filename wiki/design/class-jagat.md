# Jagat — STATUS: PLAN

> *"Bayang tak berdarah, tetapi belati tak pernah pulang lapar."*

**Archetype:** extreme close-quarters assassin. High mobility, ambush openers,
bleed specialist.

**This is a brand-new class.** The other three map onto existing ones; this one
does not.

## Identity

| | |
|---|---|
| **Weapons** | Kerambit Berkembar, Lawi Ayam, Belati Tumbuk Lada |
| **Silat** | Kera Hitam & Cekak — low weaving movement, blind-side entry, chained arterial thrusts |
| **Resource** | **Langkah Halimunan** |
| **Scaling stat** | AGI (probably — see below) |

## Langkah Halimunan

Move soundlessly across rooftops, undergrowth, or behind an enemy. Attacks from
behind deal doubled critical damage and apply **Pancung Urat**, reducing enemy
movement speed.

## Skills

| Skill | Effect |
|---|---|
| **Ricih Karotis** | Twin-kerambit spin across the throat — applies **Bisa Darah** (bleed DoT) |
| **Langkah Silap Mata** | Throw slaked-lime powder to break targeting, instantly slide behind the enemy |
| **Gunting Kaki** | Sliding scissor takedown — knockdown, opening a ground execution |

## The naming question

**"Jagat" reads oddly for this archetype.** In Malay (via Sanskrit) *jagat*
means *world / universe* — it carries scale and totality, not concealment.
It is a striking word, but it points away from what the class does.

If the intent is a proper noun — a title, an order, a specific historical or
invented group — that works and should be stated, because the page currently
reads as a common noun. If it is meant descriptively, alternatives that carry
the right sense: **Perisik** (spy/scout), **Pengintai** (one who watches),
**Bayangan** (shadow), **Cindai**.

Flagging as a question, not a correction — there may be a reason not stated.

## Systems required — none of these exist

**1. Stealth.** There is no stealth concept anywhere. Monster targeting is
`_find_nearest_player()` (`monster.gd:173`), which takes the nearest living
player inside `aggro_radius` with no visibility check. Stealth needs a
detection model, which raises the multiplayer question immediately: **hidden
from monsters, from other players, or both?** Hiding from other humans in a
PvP-capable game is a very different feature from hiding from AI.

**2. Real facing — the blocker.** Backstab requires knowing whether the
attacker is *behind* the target. Facing today is `sprite.flip_h` — left or
right, nothing else (see [../pages/animation.md](../pages/animation.md)). The
data exists (`facing_dir` is a full `Vector2`), but nothing renders or
transmits it: the `move` packet carries only `flip`
([../pages/wire-protocol.md](../pages/wire-protocol.md)).

So backstab **cannot be implemented correctly for remote players today** — you
cannot tell which way another player is facing beyond left/right. That needs a
protocol change and directional animation first.

**3. Bleed / DoT.** No damage-over-time system exists. Damage is instantaneous
through `take_damage()`. Bisa Darah and Pancung Urat both need per-entity
status effects with duration, tick, stacking rules and sync.

**4. Knockdown.** `Gunting Kaki` needs a prone state distinct from stun.

## Cheapest honest version

- **Bleed** as the first real status-effect system — it is the most reusable
  piece here, and the bestiary wants DoT anyway (Tok Begal Phase 2, Santau).
- **Backstab against monsters only**, using the monster's own `flip_h`. Correct
  enough against AI, and sidesteps the protocol gap. Explicitly no backstab
  bonus in PvP until facing is transmitted.
- **Langkah Silap Mata** as a blink — the existing Tumble Dash
  (`archer_class.gd:52`) is already a teleport; retarget it to land *behind*
  the nearest enemy.
- **Stealth** as a short "monsters drop aggro" window rather than true
  invisibility. Avoids rendering and sync work entirely.

Ordering note: **build the status-effect system first.** Bleed is needed by
Jagat, the Pawang's Santau, and at least three bestiary entries. It is the
single highest-leverage system in this whole plan.

## Related

- [open-questions.md](open-questions.md) — Q1, Q6 (facing/backstab), Q11 (PvP)
- [../pages/wire-protocol.md](../pages/wire-protocol.md) — why facing is not transmitted
