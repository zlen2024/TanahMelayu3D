# Pendekar / Hulubalang — STATUS: PLAN

> *"Biar robek kulit di dada, langkah pantang berundur ke belakang."*

**Archetype:** melee frontliner. Balanced between physical durability and
sustained offensive pressure.

Maps onto the existing `warrior` class.

## Identity

| | |
|---|---|
| **Weapons** | Keris Lok Sembilan, Pedang Jenawi, Parang Lading, brass-inlaid wooden shield |
| **Silat** | Gayong & Harimau — rooted strikes, joint locks, high-impact shoulder charges |
| **Resource** | **Semangat Waja** |
| **Scaling stat** | STR (as today) |

## Semangat Waja

Fills on **successful perfect parry** or on absorbing an enemy attack. At full,
the Pendekar may enter **Kebal Batin**: brief stagger immunity, and every swing
deals maximum posture damage.

This is the best-designed resource in the brief. It is *earned by engaging*,
not by waiting — the exact opposite of the current energy bar, which refills
passively whether you fight or stand still. It pushes the Pendekar toward the
front line, which is what a frontliner should be pushed toward.

## Skills

| Skill | Effect |
|---|---|
| **Pancung Jejak** | Horizontal sweep that cuts the enemy's footing — stagger |
| **Kunci Sendi Melorot** | Lock the arm on parry, kick the knee down, finish with a keris thrust to the ribs |
| **Langkah Benteng** | Raise the brass shield, deflect ranged fire, shove forward through a line |

## Systems required — none of these exist

This class is the **most systems-expensive** of the four, because its whole
identity rests on two verbs the game does not have.

**1. Perfect parry.** There is no block or parry. The only defensive verb is
`dodge_roll()` (`player.gd:256`) — 25 stamina, 0.35 s of i-frames. A parry
needs: a timing window, a distinct input, a success/failure branch, an enemy
attack telegraph precise enough to read, and feedback on all three outcomes.

**2. Posture / stagger.** `Pancung Jejak` and Kebal Batin both deal *posture*
damage. Entities have HP and a boolean `is_stunned` (`entity.gd:20`) — there is
no posture bar, no accumulation, no break state. Adding one touches every
entity, the HUD, and all enemy AI.

`Kunci Sendi Melorot` additionally needs a **grapple/execute** state — the
enemy held, animated through a sequence, and made invulnerable to others
mid-animation. In multiplayer that is a synchronised cutscene between two
entities, which is a genuinely hard problem.

## Cheapest honest version

Shippable with today's systems, keeping the fantasy mostly intact:

- **Semangat Waja** as a reskinned resource that fills on *damage taken and
  damage dealt* rather than on parry. Keeps "earned by engaging", drops the
  parry dependency.
- **Kebal Batin** as temporary damage reduction + immunity to the existing
  `apply_stun`, rather than posture immunity.
- **Pancung Jejak** uses the existing `apply_stun()` instead of posture damage.
- **Langkah Benteng** as a forward dash with damage reduction — the existing
  Shield Charge (`warrior_class.gd:43`) already does the dash half.
- **Kunci Sendi Melorot** deferred. It is the one skill that cannot be faked.

That gets a recognisable Pendekar without parry or posture. Whether that is
acceptable is a real question — parry *is* the fantasy here, and a Pendekar
without it may just be the current warrior in better clothes.

## Related

- [decisions.md](decisions.md) — D1 (Semangat), D2 (Tangkis), D3 (stagger)
- [../pages/warrior-class.md](../pages/warrior-class.md) — what exists today
