# `scripts/network/sound_manager.gd`

**Autoload** (`SoundManager`) · extends `Node` · 29 LOC. The smallest system
in the project.

Despite living in `scripts/network/`, it has nothing to do with networking —
it sits there because all three autoloads were grouped in one directory.

## Loading

`_ready()` (`:8`) preloads five effects by name (`:9-13`):

| Key | File |
|---|---|
| `slash` | `assets/sounds/slash.wav` |
| `hit` | `assets/sounds/hit.wav` |
| `pickup` | `assets/sounds/pickup.wav` |
| `levelup` | `assets/sounds/levelup.wav` |
| `chat` | `assets/sounds/chat.wav` |

`_load_sound` (`:15`) guards with `ResourceLoader.exists(path)` before
loading, so a missing `.wav` is skipped silently rather than crashing. That
makes the whole subsystem fail-soft: `play()` on an unregistered key just
returns (`:22-23`).

Handy for a POC, but it also means a typo'd asset path produces no error
anywhere — the sound simply never plays.

## Playback

`play(sound_name, volume_db)` (`:21`) creates a **new `AudioStreamPlayer` per
call**, adds it as a child, and frees it on `finished` (`:24-29`):

```gdscript
var player = AudioStreamPlayer.new()
player.stream = sounds[sound_name]
player.volume_db = volume_db
player.autoplay = true
add_child(player)
player.finished.connect(func(): player.queue_free())
```

Allocating a node per sound effect is not how you would do this at scale — a
pool of players, or a single player with polyphony, would avoid the churn.
At POC volumes it is fine, and it does give unlimited overlapping playback for
free, which a single player would not.

Note `autoplay = true` is set *before* the node enters the tree, so playback
begins on `add_child`.

## Callers

The most widely used autoload after `GameState`, called from nine files:

| Sound | Called from |
|---|---|
| `hit` | `entity.gd:81`, `projectile.gd:50,56` |
| `slash` | all three class strategies, `player.gd:283` (dodge) |
| `pickup` | `loot_drop.gd:53,88` |
| `levelup` | `player.gd:397`, skill heals, `inventory_ui.gd:151` |
| `chat` | `chat_box.gd:67` |

`levelup` doubles as the generic "something good happened" cue — it plays on
level-up, on every class's heal skill, and on a successful equip.

The only call passing a non-default volume is `chat_box.gd:67`, at `-6.0` dB,
so chat pings sit under combat audio.

## Related

- [entity.md](entity.md) · [chat-box.md](chat-box.md)
- `tools/generate_sfx.py` — how the `.wav` files are produced
  ([tools.md](tools.md))
