# `scripts/ui/floating_text.gd`

`class_name FloatingText` · extends `Node2D` · 44 LOC.

Damage numbers, heal popups, crit callouts and status text. Every combat
number the player sees comes from here.

## Scriptless instantiation

`static func spawn(parent, world_pos, display_text, text_color, crit)` (`:8`)
builds the node without a scene file:

```gdscript
var ft_script = load("res://scripts/ui/floating_text.gd")
var node = Node2D.new()
node.set_script(ft_script)
```

The script **loads itself by path** (`:11`). That is unusual enough to flag:
it works, but `load()` on every spawn relies on Godot's resource cache to
avoid disk I/O, and the self-reference means renaming this file breaks it at
runtime rather than at parse time.

Using `new()` on the class directly would be equivalent and safer — the
`class_name FloatingText` declaration (`:1`) already makes the type available.

Properties are set **before** `add_child` (`:14-18`) so `_ready()` sees the
final values. `_ready` (`:21`) then constructs the `Label`, applies an outline,
and starts the tween.

## Positioning

`spawn` jitters the position by ±10 px horizontally and −8/+6 vertically
(`:17`) so simultaneous hits do not stack into an unreadable pile.

The `parent` argument is important: every caller passes the entity's **parent
container**, not the entity —
e.g. `entity.gd:66-67`, `:77-78`, `:86-87`. This keeps popups alive when the
entity dies and stops them inheriting its transform.

`spawn` returns `null` for an invalid parent (`:9-10`), so callers on freed
nodes fail quietly.

## Animation

`_ready` (`:36-44`) runs a parallel tween: rise (42 px for crits, 28 px
otherwise) and fade to alpha 0 over 0.65 s, both `TRANS_QUAD`. Crits also
punch in from 1.35× scale with `TRANS_BACK` (`:41-43`), and use a larger font
and heavier outline (`:29-31`).

`tween.chain().tween_callback(queue_free)` (`:44`) frees the node when the
animation completes — so these are fire-and-forget and nothing tracks them.

## Callers

| Caller | Purpose |
|---|---|
| `entity.gd:67` | Heal `+N` (green) |
| `entity.gd:78` | `STUNNED!` (crit style) |
| `entity.gd:87` | Damage `-N` (red) |
| `warrior_class.gd:79` | `CRIT! N` (yellow, crit style) |

Note the warrior's crit popup is spawned **in addition to** the ordinary
damage number that `play_damage_feedback` already produced, so a crit shows
two overlapping labels.

[`Player`](player.md) does **not** use this for its own notifications — it has
a separate `show_notification()` (`player.gd:360`) that parents a `Label` to
the player node itself, plus `show_levelup_fanfare()` (`player.gd:421`). Three
overlapping implementations of "floating label" exist in the codebase.

## Related

- [entity.md](entity.md) — the main caller
- [warrior-class.md](warrior-class.md) — crit popups
