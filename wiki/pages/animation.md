# Animation

Added 2026-09-06. Before this, all 11 sprites were single-frame and the
`AnimationPlayer` nodes in the entity scenes contained **zero animations** —
dead scaffolding that read as working animation.

## Pipeline

| Piece | Where |
|---|---|
| Frame strips | `assets/sprites/*_sheet.png` — `create_player_sheet()` / `create_slime_sheet()` in [`generate_sprites.py`](tools.md) |
| SpriteFrames | `assets/spriteframes/*.tres` — `create_spriteframes()`, also generated |
| Playback | `AnimatedSprite2D` in `player.tscn` / `monster.tscn` |

Everything is generated, so the whole set regenerates with
`python tools/generate_sprites.py`. No hand-authored resources.

## Frames

Players get a 6-frame horizontal strip: `[idle x2, walk x4]`.
`_draw_player_frame()` takes a `bob` and a `step`, so the walk cycle swings the
boots, the sword arm and the shield arm in opposition while the body lifts on
mid-stride frames. **The shadow does not bob** — it anchors the character to
the ground.

Slimes get 4 frames of squash-and-stretch (wide+flat, neutral, tall+narrow,
neutral). They carry both an `idle` and a `walk` clip over the same frames,
differing only in speed, so entity code can switch by name without
special-casing monsters.

## AnimatedSprite2D, not AnimationPlayer

Per the research in [art-and-ux-roadmap.md](art-and-ux-roadmap.md):
`AnimatedSprite2D` has lower per-instance overhead, which matters with nine
monsters plus every connected player on screen. `AnimationPlayer` earns its
place only where a frame must be synchronised with something else — a hitbox
toggle or a sound cue — which nothing here needs yet.

The two empty `AnimationPlayer` nodes still sit in the scenes, still unused.

## What changed in the scripts

The node kept the name `Sprite2D` (so scene paths and `flip_h` uses still
resolve) but its **type** changed, which broke three things:

- `entity.gd:23` was typed `Sprite2D`. It only touches `modulate`, so it is now
  typed `CanvasItem` — the widest type that still carries what it uses.
- `monster.gd` swapped `sprite.texture = ...` for `sprite.sprite_frames = ...`
  when configuring the King Slime.
- `player.gd:_apply_skin()` now loads a whole `SpriteFrames` resource per skin
  instead of a texture, and replays the current clip so a skin change does not
  snap back to idle.

`loot_drop.gd` still uses a plain `Sprite2D` — loot has no animation.

## Driving the clip

`_set_anim(name)` on both `Player` and `Monster` **only calls `play()` on
change**. Calling it every frame would restart the animation and freeze it on
frame 0.

| Entity | Walk condition |
|---|---|
| Local player | `input_vec != Vector2.ZERO` |
| Remote player | still more than 1.5 px from `target_sync_pos` |
| Monster | `velocity.length() > 1.0` |

Remote players have no input to read, so movement is inferred from how far they
still have to interpolate.

## Not done

- **No directional frames.** Facing is still just `flip_h`, so movement is
  8-directional while rendering stays 2-directional. `AnimationTree` +
  `BlendSpace2D` fed by `facing_dir` is the route — see
  [art-and-ux-roadmap.md](art-and-ux-roadmap.md).
- No attack or death clips; attacks are still a `Tween` on the slash sprite.

## Related

- [tools.md](tools.md) · [player.md](player.md) · [monster.md](monster.md)
- [scenes.md](scenes.md) — where the sprite nodes live
