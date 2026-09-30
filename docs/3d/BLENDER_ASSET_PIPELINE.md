# Blender MCP asset pipeline — Tanah Melayu 3D

Status: proposed work orders; no assets have been produced through Blender MCP yet.
Parent plan: [MIGRATION_PLAN.md](MIGRATION_PLAN.md)

## Connection and pilot

At the beginning of implementation, identify the actual Blender MCP tools and running Blender version. Test scene inspection, object creation or script execution, file saving, viewport/render capture, and glTF export. If a capability is missing, report it and use an agreed supported workflow; do not invent tool names or claim an export succeeded.

Save work in project-local source files. Inspect any existing open scene before changing it, and create a dedicated Tanah Melayu scene/file rather than clearing unrelated work. Do not install a different MCP or download external generated assets just because a connector has an optional integration.

The first pilot must include a 1 m cube, a 1.7 m height reference, an asymmetric forward marker, and one material. Export to GLB, import into Godot, and check dimensions, orientation, pivots, normals, color, and collision placement. Record exact Blender, MCP, Godot, and exporter versions.

## Art direction

- Style: crafted, grounded stylized realism. Readable silhouettes at the third-person gameplay distance.
- Palette: humid green, aged timber, muddy earth, woven off-white, faded indigo, tarnished brass, and warm lamp light.
- Architecture: reviewed Malay stilt-house references with modular timber construction and attap roofing. Roof profiles, joinery, and ornaments should come from the reference sheet, not a generic fantasy kit.
- Hero: Pendekar with an approved tanjak, sampin, practical cloth layers, and a keris. Make costume readable from behind. Do not permanently merge weapon geometry into the hand.
- Supernatural: expressive silhouettes and restrained material effects. Model forms first; particles cannot compensate for an unreadable creature.
- Review against the game's existing [setting](../../wiki/design/setting.md) and decision D9 in [decisions](../../wiki/design/decisions.md).

## Source and export contract

| Item | Required convention |
|---|---|
| Units | Metres; 1 runtime unit = 1 m. Include a documented scale reference. |
| Axes | Blender is Z-up; exported Godot scene is Y-up. Godot actor forward is -Z. Validate conversion with the pilot instead of manually rotating every import. |
| Origin | Ground-contact/base centre for characters and props; agreed grid corner for modular pieces; hinge for doors; grip point for loose weapons. |
| Transforms | Apply mesh scale/rotation before rig binding where appropriate. Do not blindly apply armature transforms after animation; inspect the round-trip. |
| Naming | Stable ASCII snake_case; e.g. `chr_pendekar_v001`, `env_rumah_wall_2m_a`, `prop_pelita_a`. Avoid absolute machine paths. |
| Source | `.blend` plus reconstructable recipes when practical; no dependency on a single unsaved Blender session. |
| Runtime | glTF 2.0 `.glb`; export only the intended collection. Keep unnecessary cameras, lights, helper meshes, and references out. |
| Materials | Small, named PBR material set, compatible with the chosen renderer. Bake nonportable procedural nodes into textures. Verify alpha/culling rather than relying on Blender defaults. |
| Textures | Relative, portable sources; consistent UV density. 1K shared environment sheets and 2K hero sheets initially. No unnecessary 4K-per-prop textures. |
| Collision | Simple primitives or convex proxies for moving actors. Static concave collision only where justified. Keep gameplay collision on Godot wrappers so reimport is safe. |
| LOD | Supply or generate at least two meaningful reductions for expensive assets; verify silhouette and transitions in Godot. |
| Review output | Neutral front/side/back images, gameplay-camera view, wireframe, dimensions, triangle/material counts, and Godot import capture. |
| Metadata | Asset ID/version, intended use, source/export paths, authoring versions, dimensions, triangle counts, textures, clips, dependencies, provenance, and review status. |

Godot recommends glTF 2.0 and can import GLB. Direct `.blend` import invokes Blender; use explicit GLB exports here so runtime builds do not depend on every builder having Blender installed. See the [official format documentation](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html).

## Rigging and animation contract

A mesh is not a completed playable character until its rig and required clips pass the engine test.

- One documented humanoid rest pose and shared skeleton layout for compatible human classes.
- Roughly 60 deform bones or fewer and at most four bone influences per vertex as initial budgets; confirm renderer/exporter support and actual needs.
- Keep control-rig helpers out of the runtime skeleton where possible; bake constraints/IK into exportable animation.
- Export sockets or stable attachment bones for right hand, left hand, weapon stow, and effects. Validate a keris attachment during walk and attack.
- Initial clips: `idle`, `walk`, `run`, `attack_01`, `attack_02`, `dodge`, `hit`, `death`. Player clips loop only where intended. Boss additionally needs `telegraph`, `attack_heavy`, and `recover`.
- Start with in-place locomotion and 30 FPS sampled animation; movement distance, gameplay hit windows, and invulnerability live in the controller. Confirm feet stay grounded at the chosen speed.
- Preview joint extremes, cloth intersections, weapon grip, skin weighting, and transitions. A static render does not validate skinning.
- Additional class clips (bow draw/release, staff cast) belong to the class-coverage milestone, not the first Pendekar asset gate.

## Prioritized asset backlog

All entries start as **not started**. Quantities and budgets are planning targets and may change after the pilot.

| Priority / ID | Deliverable | Initial scope | Completion evidence |
|---|---|---|---|
| P0 CAL-001 | Calibration scene | Cube, height marker, forward marker, one PBR material | GLB imports at intended scale/orientation. |
| P0 KIT-001 | Kampung modular prototype | One 2 m wall, floor, roof bay, support post, stairs, door | Assemble one house in Godot without scale gaps; camera/door clearances pass. |
| P0 CHR-001 | Pendekar pilot | One hero mesh, rig, costume, 8 clips | In-engine movement/combat review; no missing clips or detached equipment. |
| P0 WPN-001 | Keris | Separate grip-pivot mesh and sheath | Correct hand/stow attachment and readable silhouette. |
| P0 ENM-001 | Toyol | One rigged regular enemy with idle/move/attack/hit/death | Navigation, attack timing, and respawn reviewed in game. |
| P1 KIT-002 | Village expansion | 2–3 house variations from shared kit, jetty, fences, landing | Shared material counts and traversal clearances meet the budget. |
| P1 VEG-001 | Tropical foliage kit | 2 palms, 2 broadleaf trees, ferns, ground cover | LOD/alpha/shadow behavior and camera visibility verified. |
| P1 PRP-001 | Village props | Pelita, basket, fishing gear, clay jar, crates, cloth bundles | Scale/pivots and repeated-instance cost reviewed. |
| P1 ENV-001 | Terrain/clearing kit | Ground materials, rocks, bank edges, simple water surface | No visible material seams at normal camera distance; walkable surface verified. |
| P1 BOS-001 | Jin Belian | One boss with two readable attacks and supporting clips | Silhouette, telegraphs, collision, and death flow pass the encounter test. |
| P2 CHR-002 | Pawang | Adapted humanoid rig, clothing/staff, casting clips | Complete slice using the 3D magic kit. |
| P2 CHR-003 | Pemanah | Adapted rig, bow/quiver, draw/release/evade clips | Projectile origin/aim and bow deformation verified. |
| Later | Perisik, other bestiary, towns | Follow the existing design bible after the slice | Separate scope and asset briefs; do not mark sprite references as finished 3D models. |

## Asset metadata template

Store a JSON record alongside each source batch. The values below are placeholders, not completed output.

```json
{
  "asset_id": "chr_pendekar",
  "version": "v001",
  "status": "not_started",
  "source": "art_source/blender/characters/chr_pendekar_v001.blend",
  "export": "assets/3d/characters/chr_pendekar.glb",
  "blender_version": null,
  "mcp_implementation_version": null,
  "godot_version_tested": null,
  "dimensions_metres": null,
  "triangle_counts_by_lod": [],
  "material_names": [],
  "animation_clips": [],
  "source_references": [],
  "license_provenance": null,
  "review_images": [],
  "import_validation": "pending"
}
```

## First Blender MCP work order

Use this only after the user starts the implementation stage:

> Inspect the connected Blender MCP and report the Blender version and supported scene/save/export capabilities. Create a dedicated Tanah Melayu calibration file without modifying unrelated work. Build a 1 m scale cube, a 1.7 m person-height marker, and an asymmetric forward marker with one simple PBR material. Save the `.blend` source and export only this collection as GLB to the project's pilot asset directory. Show front/side/perspective views and report dimensions, object names, material names, file paths, and export results. Stop asset expansion at this pilot until Godot confirms correct scale, orientation, material appearance, and reimport behavior. If export or file access is unavailable, report that capability gap without claiming success.

After the pilot passes, commission `KIT-001` and `CHR-001` against the approved reference sheets. Complete one representative piece fully before issuing large batches.

## Git and reproducibility

- Keep `.blend` source outside runtime asset folders and exclude `art_source/` from Godot imports using `.gdignore` when those folders are created.
- Configure Git LFS before the first substantial `.blend`/large texture batch; confirm collaborators can fetch the objects. Do not introduce LFS pointers without uploading the corresponding objects.
- Runtime GLBs and required textures must be available in a clean checkout or a documented asset retrieval step.
- Keep `.blend1` backups, renders, temporary bakes, local caches, and intermediate exports out of version control unless deliberately needed as review artifacts.
- Save asset-generation scripts with explicit inputs/seeds and a versioned export preset. MCP command history alone is not a reliable build recipe.

## Reject and revise an asset when

It has the wrong scale, unreviewed cultural details, unintended dependencies, missing textures, excessive material slots, broken pivots, broken skinning, or an unreadable gameplay silhouette. Reimport must preserve runtime behavior. Export success and attractive Blender renders are necessary evidence, but neither is sufficient for game integration.
