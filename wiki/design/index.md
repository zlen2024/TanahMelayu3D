# Design Documents — STATUS: PLAN

> **Nothing in this directory is implemented.** These are proposals.
>
> `wiki/pages/` documents the game **as it actually is**. `wiki/design/`
> documents what it is **meant to become**. Never let a claim cross between
> them without the code changing first — the moment a design page reads as
> fact, the whole wiki stops being trustworthy.

Drafted 2026-09-06 from the *Dokumen Reka Bentuk Game: Tanah Melayu (Zaman
Melaka)* brief.

## Contents

| Page | Covers |
|---|---|
| [setting.md](setting.md) | Era, place, social strata, tone, story frame |
| [class-pendekar.md](class-pendekar.md) | Warrior / bruiser — Semangat Waja |
| [class-jagat.md](class-jagat.md) | Assassin — Langkah Halimunan |
| [class-pawang.md](class-pawang.md) | Occultist — Nafs & sacrifice |
| [class-pemanah-rimba.md](class-pemanah-rimba.md) | Marksman — Petua Pemburu |
| [bestiary.md](bestiary.md) | Enemies Lv1–19, two Lv20 bosses |
| [open-questions.md](open-questions.md) | **Read this one.** Unresolved decisions and cost |

## What this replaces

The current game is a generic fantasy POC: Warrior / Mage / Archer, green
slimes, a King Slime, `sword_iron` and `potion_hp`. The brief replaces
**all** of it — setting, classes, enemies, items, tone.

That is a reskin *and* a systems change. The reskin is cheap. The systems are
not, and that is the part worth deciding carefully.

## Gap summary: brief vs. what exists

| Brief asks for | Today | Cost |
|---|---|---|
| 4 classes | 3 (`warrior`/`mage`/`archer`) | Moderate — new class touches 6 places |
| 4 **distinct** class resources | 1 shared energy bar + stamina | **Large** — see [open-questions.md](open-questions.md) Q1 |
| Perfect parry (Pendekar core loop) | No block or parry at all | **Large** — new combat verb |
| Posture / stagger damage | HP + a boolean stun flag | **Large** — second health bar on every entity |
| Stealth + backstab | No stealth; facing is `flip_h` only | **Large** — needs real angular facing |
| Focus mode / time dilation | None | **Large in multiplayer** — Q4 |
| Summoned minion (Pawang) | — | **Breaks monster sync** — Q5 |
| 10 enemy types + 2 bosses | 3 monster types, 1 unreachable | Moderate — needs data-driven monsters |
| Level 1–20 as "early game" | Curve reaches Lv20 at ~177k XP | Retune — Q7 |
| Dark, gritty tone | Bright cartoon slimes, cheerful knight | Art direction reversal — Q8 |

## How to read the class pages

Each carries the brief's own fantasy first (that part is good and should not be
diluted), then a **Systems required** section listing what the engine does not
have yet, and a **Cheapest honest version** — what this class could be *now*
without new combat systems. That last section matters most: it is the
difference between shipping four classes this month and four classes next
quarter.

## Related

- [../index.md](../index.md) — the as-built wiki
- [../pages/known-gaps.md](../pages/known-gaps.md) — existing debt this plan sits on top of
