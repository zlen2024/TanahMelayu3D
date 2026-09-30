# Tanah Melayu 3D — migration and production plan

Status: PROPOSED — planning only; no 3D gameplay or Blender assets have been implemented.
Date: 2026-09-30
Delivery branch: `codex/3d-migration-plan`
Destination: https://github.com/zlen2024/TanahMelayu3D

## 1. Outcome and recommended direction

Turn Hikayat into a fully 3D, third-person Malay folklore action RPG. Keep the existing game as a playable reference while building a separate 3D entry scene. Use Blender through the user's selected Blender MCP for asset authoring, and Godot for gameplay, physics, lighting, audio, interface, and deployment.

Recommended direction, subject to the owner's review:

- **Camera:** elevated third-person perspective, approximately 35–50 degrees downward, with bounded orbit and zoom. Preserve readable action-RPG combat while allowing the village, clothing, and weapons to be appreciated in 3D. Prototype camera distance and field of view before detailed assets.
- **Visual language:** stylized realism, strong silhouettes, carved timber, woven cloth, weathered brass, humid vegetation, and warm lamp light against cool forest shadows. Avoid relying on expensive effects to make an otherwise empty world feel finished.
- **Initial target:** Windows desktop, keyboard/mouse. Retain a browser build as a measured lower-quality target after the slice works; do not promise desktop lighting parity in WebGL.
- **First deliverable:** one polished 10–15 minute offline vertical slice. Prove movement, camera, combat, asset import, and performance before converting the entire bestiary or multiplayer.
- **Preservation:** retain the 2D scene and its tests until the new slice passes its acceptance gates. No automatic conversion of the whole project and no change to the current main scene in this planning delivery.

These are production recommendations, not newly approved historical facts or claims that the current game already has these features.

## 2. Canon and setting

Use the existing [setting](../../wiki/design/setting.md), [decisions](../../wiki/design/decisions.md), [character art](../../wiki/design/character-art.md), and [bestiary](../../wiki/design/bestiary.md) as the design baseline. They describe a fictional dark-fantasy setting inspired by fifteenth-century Melaka, with a lordless hulubalang at the neglected edges of prosperity.

The first location should be **Pinggir Muara Hangus**: timber stilt houses beside an estuary, an abandoned landing, a forest route, and a disturbed clearing. Reuse the entrance artwork as a mood reference, not a literal architectural blueprint or a texture to project onto every surface.

Reference gathering must distinguish period evidence from modern reconstructions and fantasy inventions. Build reference sheets for roof construction, tanjak silhouettes, sampin, keris proportions, vegetation, boats, and material wear before final modeling. Have a Malay cultural/visual review before locking the hero and village kit. Avoid generic East Asian temple roofs, European armor, and unrelated ornamental motifs.

Preserve design decision D9's treatment of belief as folklore; do not turn real sacred texts or rituals into gameplay instructions. Existing planned mechanics such as Semangat, Tangkis, Perisik, reputation, and the full level 1–20 progression are **not implemented features**. The 3D migration must not silently add all of them to its first milestone.

## 3. Current implementation and reuse boundaries

The repository currently runs Godot 4.3 with GDScript, a 2D procedural map, sprite characters, three playable class identifiers, and a Node.js WebSocket backend. The latest 2D verification recorded 134 gameplay assertions and 18 interface assertions passing. That is not evidence of 3D or end-to-end multiplayer correctness.

| Existing system | 3D treatment | Reason / concrete work |
|---|---|---|
| `scripts/combat/combat_formula.gd` | Reuse with regression tests | Pure damage/stat math can remain independent of dimension. |
| `scripts/items/item_database.gd`, inventory data | Reuse data, adapt presentation | Stable item IDs and quantities should survive. |
| `scripts/network/game_state.gd` | Retain stable data contracts; remove scene assumptions where encountered | Stats, equipment, quick slots, and UI events are useful. Audit position and player references. |
| `Entity`, `Player`, `Monster` | Build 3D actor implementations | They inherit `CharacterBody2D`, use `Vector2`, sprite modulation, and 2D collision. They cannot be reused by renaming nodes. |
| `HeroClass` and class strategies | Extract dimension-independent rules; implement 3D targeting/abilities | Current targeting is explicitly typed to `CharacterBody2D` / `Node2D`; hit detection and aim vectors need replacement. |
| `world.gd`, terrain, wading | New 3D level and surface-query provider | Replace `TileMapLayer` painting and 2D obstacles. Retain deterministic identities and spawn intent. |
| Lobby, HUD, inventory, chat | Reuse Control-based UI; bind to 3D-facing interfaces | Replace 2D player lookups, projected nameplates, minimap coordinates, and camera-dependent placement. |
| Floating text and positional sound | Rebuild 3D integration | Project world positions to screen; use spatial audio where appropriate. |
| Node.js server/database | Keep accounts and stat schema initially; version spatial messages | Current transport carries two-component positions and host-controlled enemies. It is not a secure authoritative 3D server. |
| Character sprites | Keep as reference and 2D baseline | New meshes, UVs, rigs, and animations are required. |

Do not change stored `warrior`, `mage`, and `archer` identifiers simply because the displayed names are Pendekar, Pawang, and Pemanah.

## 4. Engine, renderer, and platform gate

The current project is pinned to 4.3. Godot now marks that documentation/version unsupported. During implementation, first validate a supported stable Godot version in the isolated 3D branch, pin its exact editor and export-template versions, and run the existing tests. If an engine upgrade is needed, make it a separate reviewable commit, not part of art import.

Recommended renderer decision:

- Desktop presentation prototype: evaluate Forward+ for the desired lighting against the actual test hardware.
- Lower-spec and browser prototype: evaluate Compatibility with simpler lighting, materials, water, and particles.
- If maintaining two quality paths is too expensive, prefer one measured Compatibility baseline rather than silently dropping browser support.

Do not choose a final renderer from screenshots alone. Record GPU, driver, resolution, quality profile, and frame times. The existing native checks used Intel UHD graphics; that machine is an important low-end test candidate, not a demonstrated 3D performance baseline. Browser export must be tested on the chosen engine version; the existing 4.3 web path uses WebAssembly/WebGL 2.0 and Compatibility.

## 5. Scene and code architecture

Planned structure (directories below are proposals, not created game systems):

```text
scenes/3d/main_3d.tscn
scenes/3d/actors/{player_3d,enemy_3d}.tscn
scenes/3d/levels/muara_hangus_slice.tscn
scenes/3d/interactables/
scripts/3d/{actors,combat,camera,world,network}/
scripts/shared/                 # extracted rules only when needed
assets/3d/{characters,enemies,environment,props}/
assets/materials/3d/
art_source/blender/             # .blend sources; excluded from Godot imports
art_source/recipes/             # repeatable authoring/export scripts
art_source/references/          # reviewed references with provenance
```

### Actor and camera contract

- `CharacterBody3D` root; capsule body; separate visual pivot; skeleton and `AnimationTree`; health/combat component; `Area3D` hit/hurt volumes.
- World motion uses X/Z, with +Y up. The gameplay actor's forward convention is -Z. Validate exported mesh orientation with an asymmetric calibration object before batch production.
- Use 1 Godot unit = 1 metre. Suggested initial conversion is 32 old pixels = 1 metre; this is a tuning seed, not a guarantee of identical feel. Map old `(x, y)` ground coordinates to `(x / 32, ground_height, y / 32)` with an explicit adapter.
- Camera-relative movement, acceleration, deceleration, slopes, steps, ledge handling, and dodge direction must work before combat polish. No jumping or climbing in the first slice unless required by the greybox.
- `SpringArm3D`/ray checks handle camera obstruction. Fade foreground roofs/foliage through a deliberate occlusion system; do not let nearby walls reveal invisible enemies through all geometry.
- Keep mouse capture optional and reversible with Escape. Preserve keyboard UI navigation, configurable sensitivity, and a camera-shake reduction option.

### Combat and AI

- Separate gameplay timing from animation playback. Hit windows are explicit attack phases; damage applies once per target per attack ID. Test missed, interrupted, repeated, and overlapping attacks.
- Use in-place locomotion initially; authoritative movement remains in the controller. Add root motion only after movement and network ownership are defined.
- Implement melee arcs and swept checks; projectiles need continuous/swept collision to avoid tunneling. Define vertical tolerance and line-of-sight so enemies on other elevations are not hit accidentally.
- Keep existing health, energy, stamina, leveling, and three-skill behavior for parity. Prototype Tangkis separately after parity; the proposed Semangat redesign requires an explicit later gameplay milestone.
- Bake `NavigationRegion3D` data for the village and forest. `NavigationAgent3D` follows paths; actor code still moves the body. Closed passages must affect navigable geometry, not only avoidance.
- Define spawn clearance, leash radius, obstacle recovery, unreachable-target handling, death, loot, and respawn. First slice has one regular enemy and one boss; variants come later.

### UI and environment

- Preserve the emerald/gold visual identity. Project world nameplates with the 3D camera; hide behind-camera labels and decide occlusion rules.
- Minimap uses the world X/Z footprint and the actual level bounds. Do not reuse the 2D one-pixel-per-tile terrain image as a fake 3D map.
- Use readable attack silhouettes, a restrained directional light, believable fill light, and inexpensive local lamp accents. Test inside doorways and beneath trees, not only at the village vista.
- Start with a static time of day, simple water, and restrained foliage motion. Dynamic weather, full day/night, and volumetric effects are later enhancements.

## 6. Blender MCP production workflow

See [BLENDER_ASSET_PIPELINE.md](BLENDER_ASSET_PIPELINE.md) for the asset contract, first batch, and ready-to-use work order.

The exact Blender MCP implementation, connection, and tool capabilities have **not been verified** in this session. At implementation kickoff, inspect the actual exposed tools and Blender version. Do not assume a particular third-party MCP package, tool name, rigging capability, or external generation service.

Pipeline:

1. Connect and inspect Blender without altering an unrelated open scene.
2. Save a project-local source file, create a scale/orientation calibration asset, export `.glb`, and verify it in Godot.
3. Produce one representative house module, one material set, and one rigged hero as quality gates.
4. Review them in the gameplay camera and target renderer before producing the remaining assets.
5. Iterate from named, saved source versions. Keep rebuild scripts, material names, export settings, and asset metadata with each batch.
6. Export clean runtime assets; keep Blender source and Godot scene wrappers separate. Reimport must not erase collisions, gameplay scripts, or material overrides.
7. Check licenses/provenance for imported references and third-party content. Do not assume that access through an MCP grants redistribution rights.

## 7. First playable slice

Proposed playable footprint: approximately 100–150 metres across, sized by the camera and performance prototype.

Sequence:

1. Spawn beside two or three stilt houses and a jetty. Learn movement, camera, interact, attack, and dodge with short contextual prompts.
2. Follow a readable trail past palms and abandoned trade goods.
3. Fight a small Toyol group in a clearing with enough room for camera and dodge testing.
4. Find a simple recovery supply and unlock a return shortcut.
5. Enter the Jin Belian clearing, face a clearly telegraphed two-pattern boss, and return to the village.

Use the existing Jin Belian for this slice, not the full planned level-20 boss arc. Story text must not claim this is the completed campaign. The slice ends with a clear completion state; quests, vendors, large towns, mounts, crafting, procedural open worlds, and all bestiary variants are outside this gate.

## 8. Implementation stages and acceptance gates

| Stage | Deliverable | Exit gate |
|---|---|---|
| 0 — Freeze baseline | Isolated branch, reproducible 2D snapshot, version/renderer decision, Blender MCP capability check | Existing gameplay/UI tests pass; 2D still launches; one GLB round-trip succeeds. |
| 1 — Greybox | 3D entry scene, capsule hero, camera, ground, obstacles, stairs, mouse/UI behavior | Five-minute traversal without stuck camera, falling through geometry, or input being trapped by UI. |
| 2 — Combat parity | Pendekar, one enemy, hit/hurt volumes, health/stamina/energy, loot/death/respawn | Tests cover hit-once behavior, dodge protection, blocked line of sight, cooldowns, and repeat respawns. |
| 3 — Blender art gate | Reviewed hero rig, house kit, palm, lamp, material palette | Scales/pivots match; clips and equipment sockets import; visual quality and performance meet agreed targets in Godot. |
| 4 — Vertical slice | Village–forest–boss route, integrated assets, sound, onboarding, settings | Complete the 10–15 minute loop from a clean save; review final gameplay captures and measured frame times. |
| 5 — Class coverage | Pawang and Pemanah, 3D ranged skills and aim UX | Every existing class ability has an intentional 3D equivalent and can complete the slice. |
| 6 — Multiplayer | Versioned 3D state, interpolation, host lifecycle, save migrations | Two clients agree on damage/death/loot; reconnect and host departure tested under simulated latency. |
| 7 — Release hardening | Desktop package, browser quality path if viable, docs, optimization | Clean-machine launch, repeated play sessions, export checks, no missing assets, and documented target hardware results. |

Work in this order. Do not commission the full asset library before stage 3 passes. Estimates should be based on the first representative rig and environment kit; no fixed delivery date is assumed.

## 9. Multiplayer and persistence migration

- Introduce a distinct protocol version and a world/level version handshake. A 2D client must not join a 3D room and reinterpret its positions.
- Define position `[x, y, z]`, yaw, velocity, animation state, actor IDs, sequence/tick number, and timestamps. Choose precision and update frequency from measured bandwidth, not inherited rounded pixel coordinates.
- Preserve stable enemy IDs already in the working code. Authority allocates runtime spawn IDs and communicates them explicitly.
- Separate rendering/interpolation from combat authority. Keep the existing room-host model only as a prototype; do not claim it prevents cheating. Decide a trusted server model before competitive or untrusted public play.
- Keep account IDs, item IDs, and class IDs stable. Version save data and migrate positions per-world. Old positions need ground projection and spawn-safety checks; unknown world versions fall back to a valid spawn.
- Define disconnect, host departure, duplicate packets, stale snapshots, death/respawn synchronization, inventory writes, and reconnection recovery before enabling the public multiplayer route.
- Test with isolated temporary databases and rooms; never repurpose the user's existing player database as a test fixture.

## 10. Performance budgets to validate

These are initial budget proposals, not measured results or shipping guarantees.

| Category | Initial budget / target |
|---|---|
| Desktop target | 60 FPS at 1080p on a named mid-range test PC; p95 frame time at or below 16.7 ms in the stress scene. |
| Lower-spec/browser | 30 FPS at 720p on an agreed integrated-GPU machine; p95 at or below 33.3 ms. Review target feasibility at stage 1 and stage 3. |
| Test encounter | One player, 8 active regular enemies, a boss in a separate encounter, village props/foliage and UI visible. |
| Hero | 12k–25k triangles LOD0, reduced LODs, roughly 60 deform bones or fewer, 2–4 materials. |
| Regular enemy | 4k–12k triangles; boss 15k–30k, adjusted to camera distance. |
| House kit | 8k–20k triangles for one assembled house, shared materials/trim textures. |
| Textures | 1K shared environment sheets; 2K hero maximum initially; pack compatible roughness/metallic/occlusion channels after import validation. |
| Visible geometry / draw calls | Start under 500k triangles and 250 draw calls for desktop slice; lower browser profile target under 200k / 150. Treat shadow passes and transparency as additional measured costs. |
| Browser first-play transfer | Target under 60 MB compressed including engine, code, textures, audio, and starter zone; measure network bytes, not only source asset size. |

Use LODs, shared materials, batched foliage where appropriate, bounded shadow distance, and capped transparent effects. Avoid cloth simulation, hair grooms, and large numbers of dynamic shadow-casting lamps for the initial slice.

## 11. Validation and definition of done

- Preserve 2D regression tests while extracting shared rules; add focused 3D tests rather than replacing 2D types in old tests and assuming parity.
- Test move/stop/turn, slopes, narrow doors, steps, collision corners, camera occlusion, and menu input release.
- Test enemy navigation through village routes, interrupted attack phases, projectile collision, repeated death/respawn, and save reload.
- Asset checks: dimensions, transforms, normals, UVs, missing textures, material count, LODs, skeleton rest pose, clip names, loop flags, equipment sockets, and license metadata.
- Capture a fixed village vista, hero front/back/side, combat encounter, boss telegraph, dark doorway, and UI views in the actual Godot renderer. Blender beauty renders are not acceptance evidence by themselves.
- Export and run on a clean machine. Check initial loading, fullscreen/window resize, readable UI, audio start, and quality fallback in browser if that target remains in scope.
- A stage is complete only after its exit gate is recorded with evidence. Unavailable Blender capabilities or failing web performance are explicit blockers, not silently skipped requirements.

## 12. Branch and delivery policy

This delivery publishes the **current 2D working snapshot plus the plan** on `codex/3d-migration-plan`. It does not start the 3D conversion. Preserve the target repository's initial commit and Apache license and leave its `main` branch untouched.

Once the plan is accepted, start implementation from this published branch, e.g. `codex/3d-vertical-slice`. Keep engine upgrade, shared-rule extraction, controller, asset imports, and multiplayer migration in separate commits. Keep release builds, machine caches, live databases, credentials, and dependency directories out of Git. Before committing large `.blend`/texture batches, configure Git LFS and verify clone/pull behavior and hosting limits.

## 13. Decisions to resolve at kickoff

The plan can be reviewed now without these answers; implementation should confirm them before locking dependent work:

1. Elevated third-person camera as proposed, or a closer shoulder camera?
2. Is browser support required for the first 3D release, or is desktop-first acceptable?
3. Which exact Blender MCP and Blender version will be connected, and what modeling/rigging/export tools does it expose?
4. Which physical PCs and browsers define the performance floor?
5. Who signs off on Malay architecture, costume, and folklore presentation?

## Technical references

Checked 2026-09-30. Use version-matched docs after selecting the implementation engine; stable docs can change.

- [Godot 3D formats](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html): glTF/GLB import, Blender dependency considerations, and material/export caveats.
- [Godot 4.3 3D navigation](https://docs.godotengine.org/en/4.3/tutorials/navigation/navigation_introduction_3d.html): navigation regions/agents and initialization behavior for the current baseline.
- [Godot 4.3 web export](https://docs.godotengine.org/en/4.3/tutorials/export/exporting_for_web.html): current project's browser/runtime constraints.
- [Godot 4.3 import overview](https://docs.godotengine.org/en/4.3/tutorials/assets_pipeline/importing_3d_scenes/index.html): baseline import workflow; the page also flags 4.3 as unsupported.
