# `scripts/ui/minimap.gd`

extends `Control` · added 2026-09-06. Lives at `HUD/MiniMap/Canvas` in
`main.tscn`, anchored to the top-right corner; the roster panel
([hud.md](hud.md)) was pushed down to `offset_top = 206` to make room.

## Approach

**Terrain** comes from a one-pixel-per-tile `Image` that [`world.gd`](world.md)
builds once after generation (`build_terrain_image()`), converted to an
`ImageTexture` and drawn with `draw_texture_rect_region`. Panning and zooming
are then source-rect maths rather than thousands of per-cell draw calls on
every refresh. Deeper water is darkened in the image, so ponds read as having
a bottom.

**Entities** are still dots drawn in `_draw()`, through the same world-to-widget
transform as the terrain (`_to_map`), so they stay aligned at every zoom level.
Anything outside the visible window is culled with `box.has_point`.

## Zoom

`ZOOM_STEPS = [1.0, 2.0, 4.0]`. At `1.0` the whole arena is framed; higher
levels follow the local player.

| Input | Action |
|---|---|
| Scroll wheel over the map | zoom in / out |
| Left click | cycle zoom, so it works without a wheel |

When zoomed in, the view centre is clamped to `map_extent - view_extent`, so it
never scrolls past the map edge into empty space. The current level is drawn
bottom-left as `x1` / `x2` / `x4`.

`mouse_filter` is set to `STOP` in `_ready()`, otherwise the Control never
receives `_gui_input`.

## What it shows

| Mark | Meaning |
|---|---|
| Cyan dot + ring | the local player |
| White dot | other players |
| Red dot | monster |
| Gold dot (larger) | King Slime |
| Cyan speck | loot on the ground |
| Grey square | pillar / obstacle |

Dead monsters are skipped via `mob.get("is_dead")`.

Note the monster loop also checks `is_in_group("loot")`: loot drops are
parented to the **`Monsters`** container, not `Loot`, because
`monster._spawn_loot()` adds them to its own parent
(`monster.gd:314`) — see [world.md](world.md).

## Refresh rate

`REFRESH_INTERVAL` is 1/15 s. A minimap does not need per-frame precision, and
throttling keeps the container lookups off the hot path.

`_rebind()` re-resolves `World`/`Players`/`Monsters`/`Obstacles` lazily rather
than caching once in `_ready()`: the world is built after the HUD, and
`disconnect_network()` frees player nodes, so a cached reference would go
stale.

## Related

- [hud.md](hud.md) · [scenes.md](scenes.md) · [ui-theme.md](ui-theme.md)
