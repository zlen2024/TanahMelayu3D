# Open Questions — STATUS: PLAN

Unresolved decisions in the Tanah Melayu brief, ordered by how much they change
the work. Each is a real fork, not a nitpick.

The brief is strong on **fantasy** and thin on **systems cost**. That is the
normal shape of a first design pass — this page exists to close that gap before
anything gets built.

---

## Q1 — Four distinct resources, or one bar wearing four costumes?

**The single most expensive decision in the document.**

The brief gives each class its own resource: Semangat Waja (fills on parry),
Langkah Halimunan (a stealth state), Nafs + HP sacrifice, Petua Pemburu (a focus
mode). These are not four names for one bar — they are **four different
mechanics** with different fill rules, spend rules, and UI.

Today there is one shared `energy` bar plus `stamina`, refilling passively for
everyone (`combat_formula.gd:73`).

- **(a) Four real resources.** Best identity. Costs four HUD treatments, four
  balance passes, and breaks every shared assumption — including
  `Pelesit Bangkai`, which drains "Nafs/Semangat" and has nothing to drain from
  a stealth-based Jagat.
- **(b) One bar, reskinned per class.** Nearly free. Classes end up feeling
  similar under the names.
- **(c) One bar with a per-class *fill rule*.** Middle path: same bar and UI,
  but Pendekar fills on being hit, Pawang can convert HP into it, Pemanah drains
  it while focusing. **Recommended** — most of the identity, a fraction of the
  cost.

**Which one?**

## Q2 — Does the game get a block/parry verb?

Pendekar's entire loop assumes perfect parry. Pemungut Ufti Pasar's
"unblockable overhead" is meaningless without blocking. Kepala Begal
counter-parries the player.

There is no block or parry today — only a dodge roll with i-frames.

Adding it means a defensive input, a timing window, telegraphs precise enough
to read, and three feedback states. It also changes every existing enemy, which
was tuned against dodge-only.

**Ship parry, or rewrite Pendekar and two enemies around dodge?** A Pendekar
without parry may just be today's warrior in better clothes — which is an
argument for paying the cost, not avoiding it.

## Q3 — Posture / stagger: real system or reskinned stun?

Pancung Jejak, Kebal Batin and Tok Begal Phase 1 all reference posture damage.
Entities have HP and a boolean `is_stunned` — no posture bar.

A real posture system is a **second health bar on every entity**, plus HUD, plus
sync, plus retuning every enemy. A reskin maps "posture damage" onto the
existing `apply_stun()` and loses the accumulate-and-break tension that makes
posture interesting.

**Which?**

## Q4 — Petua Pemburu: what happens to time in multiplayer?

`Engine.time_scale` is global. Slowing time for one player either freezes
everyone else, or desyncs that client from the server.

Proposed substitution ([class-pemanah-rimba.md](class-pemanah-rimba.md)): slow
**the player**, not the world. Same tension — commit to the shot, become
vulnerable — and it works in multiplayer.

**Accept the substitution, or is time-slow non-negotiable to the fantasy?** If
non-negotiable, the honest answer is that Pemanah works in single-player and
degrades in multiplayer, and that should be a stated design position rather
than a bug discovered later.

## Q5 — Runtime spawning breaks monster sync

`Seru Bayang Mayat` summons an entity mid-match. Monsters are addressed **by
index in the `Monsters` container** ([../pages/known-gaps.md](../pages/known-gaps.md) G4).
A minion spawned by one player shifts every later index on that client, so
damage lands on the **wrong monster** on every other client — silently.

This blocks minions, and it will block region-based enemy spawning in the
bestiary too.

**Stable monster IDs should land before either.** It is a protocol change, it
has been flagged as fragile since the first ingest, and it only gets more
expensive as more depends on it. Recommend doing it early regardless of what
else is decided.

## Q6 — Backstab needs facing the protocol does not send

Jagat's identity is attacking from behind. Facing is `sprite.flip_h` — left or
right. `facing_dir` holds a real vector but the `move` packet transmits only
`flip` ([../pages/wire-protocol.md](../pages/wire-protocol.md)).

**Backstab against other players is not implementable today.** Against monsters
it is, using their `flip_h`.

Options: PvE-only backstab (cheap, ships now), or transmit real facing and add
directional animation (also unlocks the 8-directional rendering gap already
open in [../pages/animation.md](../pages/animation.md)).

## Q7 — The XP curve makes Lv20 a grind, not an early game

The brief calls Lv1–20 the **early** game. On the current curve
(`xp_to_next *= 1.5`, starting 40):

| Milestone | Cumulative XP |
|---|---|
| Lv10 | 4,533 |
| Lv15 | 34,951 |
| **Lv20** | **177,267** |

At 18 XP per common enemy that is **~9,800 kills** to finish the "early" game.

The curve needs retuning, or XP values raised an order of magnitude, or both.
**What is the intended time-to-Lv20?** Everything else follows from that number.

## Q8 — The art direction is a reversal, and the pipeline caps it

"Dark Fantasy Melayu / Silat Gritty (ala Nirnama)" against what exists: bright
saturated greens, a cheerful knight, cartoon slimes.

All art is procedurally generated by `tools/generate_sprites.py`
([../pages/tools.md](../pages/tools.md)). That was the right call for a POC and
it keeps the licensing story clean, but **Pillow rectangles and ellipses will
not produce gritty dark fantasy.** The generator caps the ceiling.

Reaching this tone means hand-authored or externally sourced art. The CC0
options are in [../pages/art-and-ux-roadmap.md](../pages/art-and-ux-roadmap.md),
but a *Malay* setting — keris, tengkolok, kampung architecture, Melaka wharf —
has essentially no off-the-shelf asset packs. This likely needs a commissioned
artist.

**Is that budgeted?** If not, the honest move is to pick a stylisation the
generator *can* reach — heavy silhouettes, restricted palette, high contrast —
rather than aiming at Nirnama and landing short.

## Q9 — How far into real belief does this go?

Toyol, saka, santau, pelesit, pawang and bomoh practice are **live folk belief**
in Malaysia and the region, entangled with Islamic teaching on the unseen.
*Santau* especially is understood as real harm done to real people, not a
fantasy spell school.

The brief already shows the right instinct — *"Bukan hamba pada iblis, cuma
mengutip janji yang ditabur tanah"* deliberately positions the Pawang as
transactional with the land rather than in service to the devil.

Worth making that an **explicit written rule** the whole team writes against,
rather than re-deciding per skill. Something like: *the game depicts folk
practice as folklore and consequence, never as instruction, and never frames
the player as serving a devil.* That is a design constraint with real teeth —
it rules out certain skill names and framings up front, which is cheaper than
discovering them in review.

Relevant to the Malaysian audience specifically, and to age ratings.

**Where is the line, and who decides it?**

## Q10 — There is no story yet

The brief covers world, classes and enemies. It does not say **who the player
is**, **why they are at the burnt estuary**, or **what the Lv20 bosses conclude**.

A frame is proposed in [setting.md](setting.md) — a hulubalang without a lord,
with the human and jin tracks as two symptoms of the same neglect. Offered to
be argued with.

**Is that the story, or is there a different one?** It determines the opening,
whether social tier is mechanical, and what the bosses mean.

## Q11 — Do these classes have to work in PvP?

PK mode exists at level 10 (`game_state.gd:227`). Assassin backstab, charm, and
traps are all much harder to balance against humans than against AI — and
several are currently *impossible* against humans (Q6).

**Is PvP a supported mode for the new classes, or a legacy feature to retire?**
Answering "retire it" makes Jagat and Pawang meaningfully cheaper.

## Q12 — Weak points: real feature or flavour text?

Pemanah's focus targets "a gap in armour, a giant's eye, a joint". Monsters
have one collision shape and one `take_damage()` call.

Per-enemy hittable sub-regions are real work, and they are also **the thing that
would make the class feel distinct**. Worth costing properly rather than
quietly dropping to "extra crit chance".

## Q13 — Two Lv20 bosses: both, or a choice?

The brief gives one boss per track without saying whether the player fights
both, picks one, or meets them in separate regions.

Affects level structure, pacing, and whether the tracks converge. **Which?**

## Q14 — Grabs and locks in multiplayer

`Kunci Sendi Melorot` (Pendekar) and `Hantu Jerut`'s choke are both **two-entity
locked states**: one holds the other through an animation, with an escape input.

In multiplayer that is a synchronised sequence between two clients, with
agreement on when it started, whether it broke, and who took damage. It is the
hardest single mechanic in the brief.

**Are grabs worth that cost, or should both be re-designed as strong knockdowns?**

---

## Recommended order, if it were up to me

Independent of most answers above:

1. **Stable monster IDs** (Q5) — unblocks minions and the bestiary; already
   overdue as G4.
2. **A status-effect system** — bleed/DoT/debuff. Needed by Jagat, Pawang,
   Pemanah and at least four bestiary entries. Highest leverage single system.
3. **Data-driven monster definitions** — the if/elif chain cannot hold 12
   enemies.
4. **Answer Q1 and Q2**, because the class work cannot start without them.
5. Then classes, then bestiary, then art.

Steps 1–3 are worth doing whatever is decided about the rest.
