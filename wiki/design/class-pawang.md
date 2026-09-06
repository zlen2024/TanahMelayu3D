# Pawang — STATUS: PLAN

> *"Bukan hamba pada iblis, cuma mengutip janji yang ditabur tanah."*

**Archetype:** occultist. Mid-to-long range, mind manipulation, blood curses
(DoT / debuff).

Maps onto the existing `mage` class.

## Identity

| | |
|---|---|
| **Weapons** | Keris Lilit Pusaka (talisman catalyst), Tongkat Kayu Nibong Keramat, Mangkuk Setanggi Bara |
| **Style** | Slow inner-mantra movement threaded with mystic blade sweeps carried on breath |
| **Resource** | **Nafs**, plus HP sacrifice |
| **Scaling stat** | INT (as today) |

## Nafs & Korban

Not generic mana. Certain forbidden techniques demand a **sacrifice of the
Pawang's own HP** to amplify a curse or trigger *santau maut*.

Mechanically this is the most interesting resource in the brief: a second
currency the player spends *against their own survivability*. It creates a real
decision at low HP that no other class has, and it pairs naturally with a
support role — someone else has to keep you alive.

The risk: paired with the current passive HP regen (`player.gd:160`, scaling
with VIT), HP-as-a-resource becomes free given ten idle seconds. **If Korban
ships, VIT-scaled regen has to be reconsidered for this class**, or the cost
is illusory.

## Skills

| Skill | Effect |
|---|---|
| **Santau Angin** | Cone of poisoned black-incense dust — HP drain over time, sustained defence reduction |
| **Pukau Sendeng** | Charm a weak-willed enemy — stun, or turn them on their allies |
| **Seru Bayang Mayat** | Summon a small earth entity from a slain enemy's spilled blood — decoy / minion |

## Systems required

**1. DoT and debuff.** Santau Angin needs damage-over-time *and* a stat debuff
with duration. Same system Perisik's bleed needs — build once.

**2. Charm / AI redirection.** `Pukau Sendeng` turning an enemy on its allies
means monsters need to be able to target *monsters*. `_find_nearest_player()`
(`monster.gd:173`) searches the `players` group only. Adding a faction/target
field to `Monster` is not hard, but it is a change to the AI's core assumption.

**3. Summoned minions — this one collides with a known bug.**

`Seru Bayang Mayat` spawns a new entity at runtime. The wire protocol addresses
monsters by **their index in the `Monsters` container**
([../pages/known-gaps.md](../pages/known-gaps.md) G4):

```gdscript
"mob_idx": get_index()          # monster.gd:264
monsters.get_child(idx)         # network_manager.gd
```

Every client spawns the identical monster list in the identical order, and
that is the *only* reason index addressing works. **A minion spawned mid-match
by one player shifts every subsequent index on that client**, so damage would
start landing on the wrong monster on every other client — silently, with no
error.

So Seru Bayang Mayat is blocked on **replacing index addressing with stable
monster IDs**. That is a protocol change worth doing regardless — G4 has been
flagged as fragile since the first ingest — but it must land before any
runtime spawning.

## Cheapest honest version

- **Nafs** as the existing energy bar renamed, with **Korban** as an optional
  HP cost on two skills. This is the one class whose resource ships almost free.
- **Santau Angin** on the shared DoT system (build it for Perisik first).
- **Pukau Sendeng** as pure stun initially — `apply_stun()` already exists
  (`entity.gd:69`). The "attack their allies" half waits for monster factions.
- **Seru Bayang Mayat** deferred until stable monster IDs land. A cheap stand-in
  meanwhile: a **stationary decoy** that pulls aggro without being a monster —
  a node in a `decoys` group that `_find_nearest_player` also considers. No new
  monster, no index shift.

## The sensitivity question

This class is where [setting.md](setting.md)'s concern about real folk-religious
material lands hardest. Santau, seru, pawang and bomoh practice are live belief,
and *santau* in particular is understood as real harm caused to real people —
not a fantasy spell school.

The brief's own framing is the right instinct: transactional with the land,
explicitly **not** in service to the devil. Worth turning that instinct into a
written rule the whole team writes against, rather than re-deciding per skill.
See [decisions.md](decisions.md) Q9.

## Related

- [decisions.md](decisions.md) — D1 (Semangat), D5 (monster IDs), D9 (the rule)
- [../pages/mage-class.md](../pages/mage-class.md) · [../pages/known-gaps.md](../pages/known-gaps.md) G4
