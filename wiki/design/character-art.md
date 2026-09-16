# Character Art — STATUS: PLAN (art exists, not wired into the game)

**The full visual set: 4 classes, 10 bestiary commons, 2 bosses.** Rebuilt at
48x48 on 2026-09-16 after reference review — 32px could not hold the shading,
ragged hems and hair mass the folklore designs need. **Bosses are 64x64**, so
they read as bosses by size before any detail lands.

**The sprites and `SpriteFrames` exist on disk but nothing loads them.** The
game still ships the old blue/red/green knights. Swapping them in is a separate
step, and it should wait until the class *systems* are decided enough to be
worth rebuilding scenes for.

## Where things are

| Thing | Path |
|---|---|
| Palette, helpers, render infra | `tools/tm_art.py` |
| Drawing code | `tools/generate_tm_sprites.py` |
| Frame strips | `assets/sprites/tm/{pendekar,perisik,pawang,pemanah}_sheet.png` |
| SpriteFrames | `assets/spriteframes/tm/*.tres` |
| Lineups | `_classes.png`, `_manusia.png`, `_jin.png`, `_bosses.png` |
| **Walk animations** | `_classes_walk.gif`, `_manusia_walk.gif`, `_jin_walk.gif`, `_bosses_walk.gif` |

The generator was split in two once the bestiary arrived: `tm_art.py` holds the
palette, drawing helpers and render infrastructure, `generate_tm_sprites.py` is
pure drawing code.

## The set

**Manusia track** — escalation is carried by silhouette, not just stats:

| Lv | Who | Silhouette read |
|---|---|---|
| 1 | Penyamun Laluan | small, rusted parang |
| 5 | Pencuri Saku | smallest; cap and satchel say thief, not fighter |
| 10 | Pemungut Ufti | **widest common**; mass plus a studded club |
| 15 | Pelontar Minyak Api | the raised flame is the whole read |
| 19 | Kepala Begal | twin blades held wide; better cloth than the grunts |

**Jin track** — Jin Tanah, Toyol Belaan, Hantu Jerut, Pelesit Bangkai,
Jin Belian Liar.

**Bosses (64x64)** — Tok Begal Belah Retak, Saka Askar Perang Lama.

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

## Second pass fixes

Three sprites failed on first render and were reworked:

- **Jin Belian read as a slug**, not a boar. The body and head ellipses merged
  and the bristles floated above the back. Rebuilt as a true quadruped: four
  legs, a barrel body heaviest at the shoulder, a bristle ridge sitting *on*
  the back, and a distinct snout with tusks curving up out of the jaw.
- **Tok Begal was a brown rectangle with a face.** A straight box torso gives
  no silhouette, so it now tapers from heavy shoulder caps to the waist, with a
  neck so head and torso are not one block.
- **The Saka's stoop did not read** — upright at that height it was just a tall
  man. The whole upper body is now offset forward of the feet (`lean`), with
  the legs trailing behind it.

It also **clipped the frame edge**: the boar's tusks ran past 48px. Worth
checking programmatically rather than by eye — a few lines reading the alpha of
column 0 and column 47 catches it instantly.

## Known rough edges

- The Pendekar's tengkolok peak still reads a little like a cone. Distinctive,
  but not quite a folded cloth.
- Tok Begal's hair is a flat block, and his head still sits close to the torso.
- The Saka's legs are nearly invisible under the robe hem.
- No attack or death frames — only idle and walk.
- Still no directional frames; facing remains `flip_h`
  ([decisions.md](decisions.md) D6).
- **48x48 is larger than the 32x32 the scenes assume.** Wiring these in means
  revisiting collision shapes, the attack-area offset and nameplate positions
  in `player.tscn` / `monster.tscn`.

## Next

1. Attack and death frames, once [decisions.md](decisions.md) D2 (Tangkis)
   settles what the animations must sync with.
2. Directional frames, which need D6 (real facing) first.
3. Wire into the scenes — after class systems, not before. Note the sprites are
   48x48 and 64x64 against the 32x32 the scenes assume, so this means revisiting
   collision shapes, attack-area offsets and nameplate positions.

## Related

- [decisions.md](decisions.md) D8 · [index.md](index.md)
- [../pages/animation.md](../pages/animation.md) — the pipeline these match
- [../pages/tools.md](../pages/tools.md)
