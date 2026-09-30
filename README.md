# Hikayat: Tanah Melayu

## Planned 3D edition

This branch preserves the playable 2D baseline and proposes the next 3D development phase. **No 3D implementation has started.** Read the [3D migration plan](docs/3d/MIGRATION_PLAN.md) and [Blender MCP asset pipeline](docs/3d/BLENDER_ASSET_PIPELINE.md).

## Current playable game

A Godot 4.3 top-down action RPG in a fictional, sultanate-inspired Tanah Melayu. The world blends a Malay kampung setting with folklore fantasy; it is not a historical reconstruction.

## The experience

- Illustrated moonlit kampung entrance, emerald-and-gold interface, and bundled Cormorant Garamond display typography.
- Select a **Pendekar** (melee), **Pawang** (magic), or **Pemanah** (ranged), with class portraits and descriptions.
- Start solo without an account. Expand the online section to connect, sign in, or create an adventurer.
- Explore timber stilt houses, palms, lantern-lit paths, and regions inhabited by Toyol, Pelesit, and the Jin Belian boss.
- Read live skill cooldowns, health, energy, stamina, experience, and your current region in the HUD.
- Open Ilmu (attributes) or Bekal (inventory); panels are mutually exclusive and release gameplay input when closed.

The existing combat, progression, inventory, terrain generation, and multiplayer protocol are retained. Internal class identifiers remain `warrior`, `mage`, and `archer` for save compatibility.

## Play locally

Open `project.godot` in Godot 4.3 and run the main scene. Choose **Begin your journey** for solo play.

For the browser version, serve the exported `dist/` directory:

```powershell
node server/serve_web.js
```

Open http://localhost:8080. This static server supports solo play. For online play, install the backend dependencies and run the unified game server instead:

```powershell
npm --prefix server install
node server/server.js
```

## Controls

| Action | Key |
|---|---|
| Move | WASD / arrows |
| Basic attack | Space / left click |
| Dodge | Shift |
| Class skills | 1 / 2 / 3 |
| Quick items | Q / E (assign in inventory) |
| Attributes / inventory | C / B |
| Chat | Enter |

## Build and verify

Full web export (requires Godot 4.3 web export templates):

```powershell
./tools/build_web.ps1
```

If the existing Godot 4.3 web runtime is already in `dist/`, the game pack can be regenerated with `--export-pack Web dist/index.pck`. Update `GODOT_CONFIG.fileSizes` in the HTML when refreshing a pack manually.

```powershell
./bin/Godot_v4.3-stable_win64_console.exe --headless --path . tests/test_runner.tscn
./bin/Godot_v4.3-stable_win64_console.exe --headless --path . tests/test_heritage_ui.tscn
./bin/Godot_v4.3-stable_win64_console.exe --path . tools/screenshot_harness.tscn -- --out=./artifacts/heritage
```

The gameplay suite contains 134 assertions. The additional interface suite checks class selection, offline entry, sprite selection, cooldown feedback, and modal input release. Screenshot capture requires a real renderer.

## Art and typography

The kampung title illustration was generated for this project. Character sprite sources and generators are in `assets/sprites/tm/` and `tools/generate_tm_sprites.py`. Landmarks are deterministic Godot vector drawings. Cormorant Garamond is bundled under the SIL Open Font License; see `assets/fonts/OFL.txt`.
