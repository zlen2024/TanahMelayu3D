# `tools/`

Six scripts: four PowerShell (setup, build, test) and two Python (asset
generation). All are Windows-first — there are no shell equivalents.

## `setup_godot.ps1`

Downloads the portable Godot 4.3-stable Windows binary from the official
GitHub release and extracts it into `bin/` (which is gitignored).

Pinned to `4.3-stable` by the `$GodotVersion` variable. Both
`Godot_v4.3-stable_win64.exe` and the `_console` variant end up in `bin/`; the
console build is what the other scripts invoke, because it writes to stdout
where PowerShell can see it.

## `setup_templates.ps1`

Downloads the ~490 MB Godot export-template bundle (`.tpz`) into
`%APPDATA%\Godot\export_templates\4.3.stable\`.

Idempotent — exits early if `web_nothreads_release.zip` is already present.
That specific filename is the check, and it is also the template the web
export needs: **nothreads**, i.e. the single-threaded WebAssembly build that
avoids requiring COOP/COEP headers. See
[build-and-deploy.md](build-and-deploy.md).

## `build_web.ps1`

The build entry point. Chains the setup scripts when their outputs are missing
(`:11-21`), then runs:

```powershell
& $GodotExe --headless --export-release "Web" $OutputHtml
```

`"Web"` must match a preset name in `export_presets.cfg`. Output goes to
`dist/index.html` plus the `.js`, `.wasm` and `.pck` siblings, and the script
then packs the whole `dist/` into `dist/godot_web_rpg_itch.zip` for itch.io
upload.

Note the zip is created **from `$DistDir\*` into a path inside `dist/`**
(`:36-40`). It deletes any previous zip first, so it does not nest — but a
re-run without that delete would pack the previous zip into the new one.

## `run_all_tests.ps1`

Two stages, `$ErrorActionPreference = "Stop"` and an explicit `$LASTEXITCODE`
check after each:

1. `& $GodotExe --headless res://tests/test_runner.tscn` —
   [`run_game_tests.gd`](run-game-tests.md)
2. `node tests/test_server_network.js` — the multiplayer integration suite

Both must exit 0. See [testing.md](testing.md).

## `screenshot_harness.gd` / `.tscn`

Visual verification. Loads `main.tscn`, arranges a deliberate scene, and writes
PNGs so rendering and UI changes can be *checked* rather than assumed:

```bash
./bin/Godot_v4.3-stable_win64_console.exe --path . tools/screenshot_harness.tscn -- --out=<dir>
```

Captures the lobby (theme), an in-world Y-sort arrangement against a pillar,
and the stats/inventory panels over the world.

**It cannot run under `--headless`** — the dummy driver renders nothing and the
capture comes out blank. It needs a real renderer, which is why it is not part
of `run_all_tests.ps1`.

Added 2026-09-05 to verify the Y-sort and theme work; kept because the project
otherwise has no way to confirm a visual change.

## `generate_sprites.py`

Draws all 11 PNGs in `assets/sprites/` procedurally with **Pillow** — player
skins in three tunic colours, slimes, the king slime, projectile, slash, XP
gem, HP potion, and the grass and wall tiles.

This is the one place in the repo with a third-party Python dependency
(`PIL`), and there is no `requirements.txt` — running it needs
`pip install Pillow` first.

## `generate_tm_sprites.py`

The four Tanah Melayu class sprites — Pendekar, Perisik, Pawang, Pemanah Rimba
— plus their `SpriteFrames` and two preview images.

Kept separate from `generate_sprites.py` because it is a different art
direction, not a variant of the placeholder set. Frame layout matches
(6 frames, `[idle x2, walk x4]`), so the output drops into `AnimatedSprite2D`
with no new code.

**Nothing in the game loads these yet** — see
[../design/character-art.md](../design/character-art.md).

Two things worth knowing before editing it: `ImageDraw` *replaces* alpha rather
than blending, so any preview compositing onto an opaque background must draw
to a transparent layer and `alpha_composite`; and weapons need an explicit
shoulder-to-hand limb or they read as floating.

## `generate_sfx.py`

Synthesises the five `.wav` files in `assets/sounds/` using **only the
standard library** (`wave`, `struct`, `math`) at 22050 Hz mono 16-bit — no
dependency to install.

The assets it produces are what [`sound_manager.gd`](sound-manager.md) loads
by name.

## Why the generators matter

Both scripts write into `assets/`, which **is** tracked — so the generated
PNGs and WAVs are committed and the scripts do not need to run in a normal
build. They exist to regenerate assets from scratch, and they are the reason
this project has no binary art dependencies to source.

Neither is wired into `build_web.ps1`, so changing a generator has no effect
until it is run manually and the output committed.

## Related

- [build-and-deploy.md](build-and-deploy.md) · [testing.md](testing.md)
- [sound-manager.md](sound-manager.md) — consumer of the generated audio
