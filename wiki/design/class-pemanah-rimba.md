# Pemanah Rimba — STATUS: PLAN

> *"Sebelum hembusan damak sampai ke telinga, rohmu sudah berpisah dari raga."*

**Archetype:** long-range marksman. Ground-trap specialist, scout, kiter.

Maps onto the existing `archer` class.

## Identity

| | |
|---|---|
| **Weapons** | Busur Besar Kayu Bakau, Sumpit (long segmented bamboo blowpipe), Belati Pisau Raut as an emergency sidearm |
| **Style** | Distance and terrain height; varied arrow types and ipoh-sap poisoned darts |
| **Resource** | **Petua Pemburu** |
| **Scaling stat** | AGI + STR (as today) |

## Petua Pemburu

An aim mode that enters a **focus state**, briefly slowing the perception of
time to place a shot into a weak point — a gap in armour, a giant's eye, a
joint.

## Skills

| Skill | Effect |
|---|---|
| **Damak Getah Ipoh** | Silent blowpipe dart — drains stamina, cripples movement |
| **Hujan Panah Api Minyak** | Arcing volley that splashes burning oil, denying ground |
| **Ranjau Buluh Pasak** | Hidden bamboo stake trap — roots and bleeds whoever steps on it |

## Systems required

**1. Time dilation — the hard one, and it is hard specifically because of
multiplayer.**

Godot offers `Engine.time_scale`, but that is **global**. In a session with
other players there are only bad options:

| Option | Problem |
|---|---|
| Slow time for everyone | One player's aim button freezes everyone else. Unacceptable. |
| Slow only the local client | Client and server disagree about where everything is. The player's own shot lands where nothing was. |
| Slow only the *visuals* | Doable, but the mechanical benefit is gone — it becomes pure decoration. |

The honest reframing: **Petua Pemburu should not slow time in multiplayer.**
It can instead be a *focus* mode that gives what time-slow was there to give —
precision — without touching the clock:

- Enemy weak points become visible/highlighted
- Aim assist tightens, or a charge meter fills toward a guaranteed critical
- Movement slows *the player* (a real trade: precision for mobility)

That last one is the key substitution. Slowing the player instead of the world
delivers the same tension — commit to the shot, become vulnerable — and works
perfectly in multiplayer. Recommended.

**2. Weak points.** "Gap in armour, giant's eye, joint" implies per-enemy
hittable sub-regions. Nothing like that exists; monsters are one `take_damage`
call with a single collision shape. This is real work and it is what would make
the class feel distinct — worth costing properly rather than dropping quietly.

**3. Ground hazards.** Both Hujan Panah Api Minyak and Ranjau Buluh Pasak need
**persistent world objects that damage over time in an area** — burning ground,
armed traps. Nothing exists; projectiles are transient and free themselves on
hit (`projectile.gd:51`). Needs a hazard entity, ownership, duration, and sync.

Note the trap is also a *stealth* object — hidden until triggered — which
brushes against the same visibility questions as [class-perisik.md](class-perisik.md).

**4. Ammo types.** The brief implies distinct arrow types. The current model has
one projectile scene with `@export` fields
([../pages/projectile.md](../pages/projectile.md)) — extensible, but there is no
selection UI or ammo economy.

## Cheapest honest version

This class is closest to shippable today, because
[../pages/archer-class.md](../pages/archer-class.md) already has auto-aim, range
limits and piercing shots.

- **Petua Pemburu** as the focus-not-time-slow version above: hold to slow
  *yourself*, tighten aim, build toward a guaranteed crit. No engine changes.
- **Damak Getah Ipoh** — a slow debuff on hit; reuses the same status system as
  Perisik's bleed.
- **Ranjau Buluh Pasak** as the first ground hazard: a static `Area2D` in a
  `hazards` group that applies the shared DoT. Simpler than burning oil because
  it is a single trigger, and it proves the hazard pattern.
- **Hujan Panah Api Minyak** second, once hazards are proven — it is the same
  entity with a duration and a larger radius.

## Related

- [decisions.md](decisions.md) — D1 (Semangat), D4 (focus, not time-slow), D12 (weak points)
- [../pages/archer-class.md](../pages/archer-class.md) · [../pages/projectile.md](../pages/projectile.md)
