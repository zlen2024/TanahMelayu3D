# Design Decisions — STATUS: PLAN (decided, not built)

Every fork from the first design pass, now resolved. Decisions made 2026-09-06.

**Q1 (the class name) was decided by the project owner: the assassin class is
"Perisik", not "Jagat".** The remaining fourteen were delegated, with the brief
*"decide based on which is more suitable for the Tanah Melayu fantasy."* They
are answered on that basis, with reasoning, so any of them can be overturned by
disagreeing with the reasoning rather than by re-deriving the problem.

The governing principle used throughout:

> **Keep what silat and Malay folk belief make distinctive. Cut what is
> borrowed from other games' vocabulary and costs the most.**

---

## D1 — One resource bar, named **Semangat**, with per-class fill rules

**Decided: option (c).** One bar, one HUD slot, four different ways to fill it.

*Reasoning — this is where theme and cost point the same way.* **Semangat** is a
genuinely pan-Malay concept: semangat padi, semangat in silat, the vital force a
thing possesses and can lose. It is not a translation of "mana" — it is the
right word already, and it is shared across the culture the game is set in.
Giving every class the same *substance* with a different *relationship* to it is
more thematically coherent than four unrelated meters, and it happens to be the
cheap option.

| Class | How Semangat fills |
|---|---|
| **Pendekar** | Taking and landing hits — rewards holding the line |
| **Perisik** | Approaching unseen, and on the first strike from concealment |
| **Pawang** | Passive, plus **Korban** — convert HP into Semangat deliberately |
| **Pemanah Rimba** | Passive, but *drains* while holding focus |

Nafs is retained as the Pawang's *name* for it in dialogue and flavour, since a
pawang would not call it semangat. The bar is the same bar.

This also fixes the brief's own inconsistency: Pelesit Bangkai drains
"Nafs/Semangat", which had nothing to drain from a stealth-resource Perisik.
Now it drains one thing from everyone.

## D2 — Ship the parry. Call it **Tangkis**

**Decided: yes, build it.** This is the one expensive system worth paying for.

*Reasoning.* Silat is built on *tangkis* (deflect) and *elak* (evade). A Malay
martial-arts game whose only defensive verb is a roll is missing the half of the
art that makes it silat rather than generic action-RPG dodging. The brief's
enemy design already assumes it — the unblockable overhead at Lv10 and the
counter-parrying duelist at Lv19 are both *teaching* parry.

Scope it tightly: **no hold-to-block state.** Tangkis is a tap with a timing
window. Inside the window, damage is negated and Semangat fills; outside it,
you eat the hit. That is one input, one window, three feedback states — far
cheaper than block + parry, and it keeps the game committed rather than turtled.

The existing dodge roll stays. Tangkis and elak are both silat; having both is
correct.

## D3 — Posture is a hidden accumulator, not a second bar

**Decided: reskin.** No posture HUD, no second synced health bar.

*Reasoning.* Posture-as-a-visible-resource is a Sekiro idiom, not a Malay one.
What the brief actually wants from it is *terhuyung* — an enemy losing footing
under sustained pressure. That can be an invisible accumulator feeding the
`apply_stun()` that already exists (`entity.gd:69`): hits add stability damage,
crossing a threshold staggers, and it decays over time.

That delivers the accumulate-and-break tension at a fraction of the cost, and
avoids putting a second bar on every enemy nameplate in a game already showing
HP bars over nine monsters at once.

**Kebal Batin** becomes immunity to that stagger plus damage reduction, which is
the same promise.

## D4 — Petua Pemburu slows the player, not the world

**Decided: the substitution.** No time dilation.

*Reasoning.* `Engine.time_scale` is global; there is no version of it that works
in a shared session. And the substitution is arguably *better* theme: a hunter
with a sumpit does not slow time, they **go still**. Holding breath, planting
the feet, accepting that you cannot move while you aim — that is the real thing
being dramatised, and it costs nothing to build.

Mechanically: hold to enter focus — movement drops sharply, aim tightens, a
crit meter fills, Semangat drains. Release or run out and it ends.

## D5 — Stable monster IDs, before anything else

**Decided: do it first**, ahead of all class and bestiary work.

*Reasoning.* Not really a design question. Monsters are addressed by container
index ([../pages/known-gaps.md](../pages/known-gaps.md) G4), which blocks
summons, blocks region-based spawning, and silently corrupts damage targeting
the moment anything spawns at runtime. Everything downstream in this plan needs
it. It has been flagged as fragile since the first ingest and only gets more
expensive.

## D6 — Transmit real facing

**Decided: yes**, sequenced after the status-effect system.

*Reasoning.* It is needed twice over: Perisik's backstab cannot work against
players without it, and 8-directional rendering — already an open gap in
[../pages/animation.md](../pages/animation.md) — needs the same data. One change,
two features. `facing_dir` already holds the vector; the `move` packet just
does not send it.

**Interim:** backstab works against monsters only, using their `flip_h`. Ships
now, correct against AI, no protocol change.

## D7 — Retune the XP curve

**Decided.** Replace `40 × 1.5ⁿ` with **`60 × 1.28ⁿ`**, and scale enemy XP by
tier as **`12 × 1.16^(level−1)`**.

*Reasoning.* The current curve puts "early game" Lv20 at **177,267 XP ≈ 9,800
kills**. The new one:

| Milestone | Current total | Proposed total |
|---|---|---|
| Lv10 | 4,533 | 1,762 |
| Lv15 | 34,951 | 6,576 |
| **Lv20** | **177,267** | **23,119** |

Enemy XP becomes 12 at Lv1, 21 at Lv5, 45 at Lv10, 95 at Lv15, 173 at Lv19.
Fighting level-appropriate enemies throughout, that is **≈267 kills** to reach
Lv20 — a few hours of meaningful fights rather than ten thousand slimes.

Bosses should award roughly 5× a same-tier enemy.

## D8 — Stylise to what the pipeline can actually reach

**Decided: do not target Nirnama fidelity.** Target a *restricted, readable,
moody* pixel style the generator can produce, and treat commissioned art as an
upgrade path rather than a dependency.

*Reasoning.* No art budget has been confirmed, and a Malay setting has
essentially no off-the-shelf CC0 packs — keris, tengkolok, kampung stilt houses
and a Melaka wharf are not in Kenney. Aiming at a reference the pipeline cannot
hit produces something that reads as a failed imitation. Aiming at a *coherent*
restricted style produces something that reads as a choice.

Concretely:

- **Palette:** mud brown, brass, tarnished silver, dried blood, lamp-oil orange,
  swamp green. Low saturation, high value contrast. The current saturated greens
  go.
- **Silhouette first.** At 32px, shape reads before detail — a kerambit
  silhouette differs from a parang silhouette even when both are eight pixels.
- **Light is the mood tool**, not texture. Lamp pools, fog, and darkness at the
  frame edges do more for "gritty" than sprite detail can at this resolution.

The generator can do all of that. It cannot do rendered, painterly grit.

## D9 — The rule for folk-religious material

**Decided.** Adopted as a standing constraint, written here so it is decided
once:

> **The game depicts folk belief as folklore and consequence — never as
> instruction, and never with the player in service to a devil.**
>
> 1. No ritual is depicted in reproducible detail. Naming *setanggi*, *kapur
>    sirih* or *kemenyan* as objects is fine; showing a working procedure is not.
> 2. The Pawang bargains with **the land and the dead**, not with Iblis or
>    Syaitan. The brief's own line — *"bukan hamba pada iblis"* — is the
>    canonical framing.
> 3. Jin are treated as **inhabitants with claims**, not demons to be exorcised.
>    They are territorial and hungry, which is why they are dangerous.
> 4. **Santau always costs the user.** It is depicted as harm that damages
>    whoever sends it — this is what keeps it folklore rather than a spell.
> 5. No Quranic text, no real du'a, no reproduced ayat used as game mechanics.

*Reasoning.* This is a Malaysian setting for an audience that mostly holds these
beliefs as live rather than fictional. The constraint is not squeamishness — it
is what lets the game use this material *seriously*. Rules 1 and 5 are also
what keep it releasable and rateable in Malaysia.

## D10 — The story frame is adopted

**Decided: the hulubalang without a lord.**

> Sworn service ended badly, by death or disgrace. Melaka's prosperity has no
> place for a warrior with no master, so they work the estuary edge. The human
> track is what desperate people do to each other when the court stops looking.
> The jin track is what moves in when a place stops being tended. **Both are
> symptoms of the same neglect** — which is what makes them one story instead
> of two.

*Reasoning.* It makes the three social tiers load-bearing instead of
decorative: the player has fallen out of Hulubalang, serves Orang Kampung, and
is used by Orang Istana. It explains why one character fights both tracks. And
it gives the Lv20 pair a shared meaning — **a man who became a monster, and a
monster that was once a man's weapon** — which is free thematic weight the
brief already set up without naming.

**Social tier is narrative, not mechanical, for now.** A reputation system is a
good idea and a large one; it is not in the Lv1–20 scope.

## D11 — PK mode is shelved

**Decided: disable, keep the code.**

*Reasoning.* PK is already half-broken — `pk_toggle` is broadcast and **no
client handles it**, so another player's PK state is invisible
([../pages/known-gaps.md](../pages/known-gaps.md) G2). Beyond that, the Tanah
Melayu framing is PvE and narrative; Perisik's backstab, Pawang's charm and
Pemanah's traps are all far harder to balance against humans, and two of them
are currently impossible against humans anyway (D6).

Shelving it removes a whole balance axis from four new classes. Revisit after
the campaign works.

## D12 — One weak point per enemy, revealed by focus

**Decided: minimal version.** Not per-region hitboxes.

*Reasoning.* Each enemy type gets a single designated weak point — the eye, the
joint, the gap in the mail — which is *invisible until* Pemanah's focus reveals
it, and which takes bonus damage from anyone once revealed.

That keeps the interesting part (the hunter finds the opening, the party
exploits it, and it makes the archer valuable to the group rather than just to
themselves) without building a hit-region system on twelve enemies.

## D13 — Both bosses, different regions, either order

**Decided: both, player chooses the order.**

*Reasoning.* The two-track structure is the brief's best idea, and fighting only
one boss wastes half of it. Making them parallel rather than sequential also
means the mirror lands: whichever you fight second, you have already met its
opposite. Tok Begal in the Pangkalan warehouse, the Saka in the Paya — the
regions already exist in the brief.

## D14 — Grabs become knockdowns and roots

**Decided: no two-entity locked states.**

*Reasoning.* A synchronised grab is the single hardest mechanic in the brief —
two clients agreeing on when a hold started, whether it broke, and who took
damage — for the least payoff. And silat's *kuncian* reads perfectly well as a
hard takedown; the fantasy survives the simplification.

- **Kunci Sendi Melorot** → hard knockdown plus a follow-up damage window.
  Still a lock in animation, just not a shared state machine.
- **Hantu Jerut's choke** → a pull-in and **root** (held in place, stamina
  draining, breakable by attacking) rather than a locked hold.

---

## Build order

Unchanged by any of the above, and everything depends on it:

1. **Stable monster IDs** (D5)
2. **Status-effect system** — bleed, DoT, debuff, root. Needed by three classes
   and at least four bestiary entries. Highest leverage single system.
3. **Data-driven monster definitions** — the `if/elif` chain in
   `monster.gd:_ready()` cannot hold twelve enemies.
4. **Semangat** (D1) and **Tangkis** (D2) — class work cannot start before these.
5. **Real facing** (D6), which also unlocks 8-directional animation.
6. Classes → bestiary → art.

## Still genuinely open

Not decided here because they need play, not reasoning:

- Tuning numbers for Tangkis's window, stagger thresholds, and Korban's HP cost.
- Whether VIT-scaled HP regen has to be reduced for the Pawang so that Korban
  costs anything real ([class-pawang.md](class-pawang.md)).
- Whether the Perisik's stealth hides from *monsters only* or eventually from
  players too, if D11 is ever reversed.
