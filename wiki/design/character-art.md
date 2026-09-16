# Character Art — STATUS: PLAN (art exists, not wired into the game)

Four playable classes and the first five bestiary creatures. Rebuilt at
**48x48** on 2026-09-16 after reference review — 32px could not hold the
shading, ragged hems and hair mass the folklore designs need.

**The sprites and `SpriteFrames` exist on disk but nothing loads them.** The
game still ships the old blue/red/green knights. Swapping them in is a separate
step, and it should wait until the class *systems* are decided enough to be
worth rebuilding scenes for.

## Where things are

| Thing | Path |
|---|---|
| Generator | `tools/generate_tm_sprites.py` |
| Frame strips | `assets/sprites/tm/{pendekar,perisik,pawang,pemanah}_sheet.png` |
| SpriteFrames | `assets/spriteframes/tm/*.tres` |
| Lineups | `assets/sprites/tm/_classes.png`, `_creatures.png` |
| **Walk animations** | `assets/sprites/tm/_classes_walk.gif`, `_creatures_walk.gif` |

Creatures drawn so far: Penyamun Laluan, Jin Tanah, Toyol Belaan, Hantu Jerut,
Pelesit Bangkai. Five of the bestiary's ten commons; the Lv19 elites and both
Lv20 bosses are not started.

Kept in a **separate module** from `generate_sprites.py`: this is a different
art direction, not a variant of the placeholder set, and mixing them would make
both harder to change.

Frame layout matches the existing pipeline exactly — 6 frames,
`[idle x2, walk x4]` — so these drop into `AnimatedSprite2D` with no new code
([../pages/animation.md](../pages/animation.md)).

## Applying D8

[decisions.md](decisions.md) D8 said: stop targeting Nirnama fidelity the
generator cannot reach; target a restricted, readable, moody style it can.
Concretely that meant three rules.

**1. One palette, nothing outside it.** 17 colours — mud, brass, tarnished
silver, dried blood, lamp-oil orange, swamp green, bone, ink. Low saturation,
high value contrast. The old set's saturated primaries are gone entirely.

**2. Silhouette first.** Each class is built around a single shape that reads at
32px before any detail does:

| Class | Silhouette anchor |
|---|---|
| **Pendekar** | Tengkolok peak + shield mass — the widest figure |
| **Perisik** | Crouched, hooded, narrow — the smallest |
| **Pawang** | A staff taller than the figure — the only strong vertical |
| **Pemanah Rimba** | The bow arc — the only curve in the set |

The test is squinting at the lineup: if two are confusable at that size, the
silhouette failed. These are not.

**3. Light as the mood tool.** Lamp-orange is used sparingly and only where it
should draw the eye — the Perisik's eyes in shadow, the Pawang's ember bowl and
gaze. Everything else sits in the mud-to-swamp range.

## Malay visual markers

Deliberate, and doing status work as well as decoration:

- **Tengkolok** on the Pendekar alone — headwear as rank. The Pemanah gets a
  plain **headband** instead, which reads as lower status without a word of text.
- **Samping** over the hips on the Pendekar.
- **Kerambit** as small curved claws, not knives — the curve is the whole point.
- **Tongkat kayu nibong** and **mangkuk setanggi** with a wisp of smoke.
- **Face-wrap** on the Perisik with only an eye slit.

## Two bugs found while drawing

Worth recording, because both will recur:

**`ImageDraw` replaces alpha, it does not blend.** The first lineup drew the
semi-transparent shadow straight onto an opaque background and **punched a hole
in it** — the shadows rendered as bright grey. Fixed by drawing characters onto
a transparent layer and `Image.alpha_composite`-ing that onto the background.
Any future preview that composites must do the same.

**Weapons without arms read as floating.** The first pass had swords, kerambit
and bows with no limb connecting them to the body. Adding a two-pixel
shoulder-to-hand line to each class was the single biggest improvement in the
whole pass.

## What the reference changed

A reference sheet of folklore pixel art (pocong, pontianak, penanggalan, toyol)
set the bar and drove four changes:

1. **48x48 instead of 32x32.** The single biggest improvement. 2.25x the pixel
   area, which is what makes shading and ragged hems possible at all.
2. **Three-tone shading** on every block (`_shaded_box`) — lit edge, body,
   shaded edge and underside — rather than flat fills.
3. **Ragged hems** (`_ragged_hem`) on every cloth edge. The reference leans on
   torn silhouettes for every spirit, and it is what separates a ghost from a
   person in a dress.
4. **Glowing eyes in a dark socket** as the primary read in low light.

## Bugs found while drawing

All four were caught by rendering a single sprite at 10x on a mid-grey
background. Worth repeating that diagnostic before trusting any lineup:

- **Eyes were 4x4 sockets at spread 3**, which merged into one dark band across
  a 12px face. Split into a plain `_eyes` for the living and a smaller
  `_glow_eyes` for spirits.
- **Hantu Jerut's head floated** — the body ran flat along the ground while the
  head sat high and detached. The coil now rises into the head, so they read as
  one creature.
- **Pelesit's hair was drawn over its face**, covering the eyes — the only
  expressive part of the sprite. Hair now draws behind the head.
- Earlier: `ImageDraw` **replaces alpha rather than blending**, so compositing
  onto an opaque background must go through a transparent layer, and weapons
  need an explicit shoulder-to-hand limb or they read as floating.

## Known rough edges

- The Pendekar's tengkolok peak still reads a little like a cone. Distinctive,
  but not quite a folded cloth.
- The Toyol's arms are thin sticks against a bulky body.
- No attack or death frames — only idle and walk.
- Still no directional frames; facing remains `flip_h`
  ([decisions.md](decisions.md) D6).
- **48x48 is larger than the 32x32 the scenes assume.** Wiring these in means
  revisiting collision shapes, the attack-area offset and nameplate positions
  in `player.tscn` / `monster.tscn`.

## Next

1. Enemy sprites — the bestiary's ten commons plus two bosses, same palette.
2. Attack frames, once [decisions.md](decisions.md) D2 (Tangkis) settles what
   the animations must sync with.
3. Wire into the scenes — after class systems, not before.

## Related

- [decisions.md](decisions.md) D8 · [index.md](index.md)
- [../pages/animation.md](../pages/animation.md) — the pipeline these match
- [../pages/tools.md](../pages/tools.md)
