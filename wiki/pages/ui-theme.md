# `assets/ui/rpg_theme.tres`

The project's single UI `Theme`, added 2026-09-05. Before it, there was no
theme at all and every widget rendered in Godot's default grey.

## Why a theme alone was not enough

`main.tscn` carried **72 `theme_override_*` entries**, and a scene-level
override beats a theme. Dropping in a theme without touching them would have
changed almost nothing.

The overrides broke down as:

| Kind | Count | Disposition |
|---|---|---|
| `font_sizes/font_size` at **10–11 px** | 39 | **Removed** — this was the real readability problem |
| `font_sizes/font_size` at 14 / 17 (titles) | 4 | Raised to 22 (one was the HUD level readout, set to 17) |
| `styles/panel`, `styles/background` | 8 | **Removed** — the theme owns panel and bar chrome |
| `styles/fill` (HP red, energy blue, XP green) | 3 | **Kept** — semantic, not styling |
| `colors/font_color` | 10 | **Kept** — deliberate accents |
| `constants/separation` | 8 | **Kept** — layout, not styling |

Three now-orphaned `StyleBoxFlat` sub-resources were deleted from `main.tscn`
and `load_steps` recomputed.

## Palette

Tuned against the project's clear colour, `Color(0.12, 0.14, 0.18)`
(`project.godot`), so panels read as *deeper than the world* rather than as a
separate design language.

| Role | Colour |
|---|---|
| Panel background | `0.078, 0.09, 0.125` @ 94% |
| Panel border | `0.38, 0.32, 0.19` (muted gold) |
| Accent / focus | `0.95, 0.80, 0.38` (gold) |
| Body text | `0.88, 0.90, 0.94` |
| Button normal → hover | `0.16,0.185,0.25` → `0.26,0.30,0.39` |

Base size is 16 px. With the 1024×576 viewport and `canvas_items` stretch, that
renders around 30 px on a 1080p display — the earlier 10–11 px was roughly
19 px effective, and genuinely cramped at native resolution.

## Assignment

`CanvasLayer` is not a `Control` and cannot hold a theme, so it is assigned to
each of the **8 root Controls** — `TopLeft`, `TopRight`, `SkillBar`,
`ControlsHint`, `ChatBox`, `StatsPanel`, `InventoryUI` under `HUD`, and
`LobbyUI` under `LobbyLayer`. Themes cascade, so nothing below them needs it.

Types styled: `Button`, `OptionButton`, `Label`, `Panel`, `PanelContainer`,
`ProgressBar`, `LineEdit`, `ItemList`, `RichTextLabel`, `HSeparator`,
`ScrollContainer`.

## Known limitation

No custom font — the theme sets sizes and colours but uses Godot's default
face. Dropping a pixel font into `assets/ui/` and setting `default_font` on the
theme is a one-line change and would be the next visible improvement.

## Verified

Rendered with `tools/screenshot_harness.gd` ([tools.md](tools.md)) across the
lobby, the in-world HUD, and the stats/inventory panels.

## Related

- [art-and-ux-roadmap.md](art-and-ux-roadmap.md) · [hud.md](hud.md)
- [scenes.md](scenes.md) — where the roots live
