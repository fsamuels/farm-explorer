# Implementation Plan

Engine-agnostic until the engine decision is made (see engine-decision.md).
Steps are ordered by recognition-impact-per-hour, not by conventional game dev
milestones — the priority is fast, visible progress toward "that's clearly the farm."

## Phase 0 — Source data

- [ ] Fly drone in a structured overlapping grid pattern (not just a few shots) over the full property, to support photogrammetry terrain generation later
- [ ] Fly a straight-down pass for a clean top-down orthomosaic (aerial texture)
- [x] Gather any existing parcel boundary / measurement data (check water rights project docs — parcel is 340732310005) — confirmed acreage, real boundary polygon, and approximate (ML-derived) building footprints, all via public GIS REST APIs, see [docs/parcel-data.md](parcel-data.md)
- [ ] Note real-world dimensions of key structures (barn, key fences) for scale validation later

## Phase 1 — Terrain

- [ ] Process drone photos into an orthomosaic (top-down stitched image) — tool TBD pending engine choice (e.g. WebODM, Meshroom, or engine-specific plugin)
- [ ] Optionally process into a heightmap/DEM if photogrammetry is used
- [ ] Import terrain into engine, scaled to match real property dimensions
- [~] Apply orthomosaic as terrain texture — interim stand-in applied early: public NAIP aerial imagery textures the ground plane (see [docs/parcel-data.md](parcel-data.md)); still pending replacement with the real drone-derived orthomosaic
- [ ] Validate scale: confirm walking speed vs. known real-world distances (e.g. barn to fence line) feels correct

## Phase 2 — Layout blockout

- [~] Place boxy placeholder geometry for every building at correct position, orientation, and rough scale — 7 boxes placed at real (approximate, ML-derived) positions/sizes; not yet attributed to specific structures or rotated to true orientation (see [docs/parcel-data.md](parcel-data.md))
- [x] Add fence lines and pasture divisions as simple planes/lines — fence now traces the real parcel boundary polygon (13 segments) as a procedurally-generated wire/post fence rather than a placeholder box (see D-11); no pasture-division lines yet
- [x] Edge-of-map treatment — a treeline 20m outside the real boundary (`scenes/tree_line_segment.tscn`) is the actual hard limit on exploration, rather than the property fence itself (see D-11); not an item from the original plan, added at the user's request. Known rough edge: corners look a bit off since each segment is offset independently with no mitering (D-11) — acceptable for now, flagged by the user as something to revisit later, not a blocker
- [ ] Walk the blockout and compare against memory/photos of the real property

## Phase 3 — First-person exploration

- [x] Add built-in first-person/walking character controller — WASD movement, mouse look, jump, and gravity in `player.gd`
- [x] Add collision to terrain, buildings, fences — `StaticBody3D`/`CollisionShape3D` on the ground plane, every building, and every fence segment
- [ ] Confirm free exploration of full property bounds — not yet walked end-to-end in-editor; the boundary itself has now been wrong twice (skewed collision shapes, then wrong edge directions entirely — see `parcel-data.md` and D-12) and caught both times by inspection rather than an actual walkthrough, so this is worth doing for real before trusting the boundary further
- [x] Minimap overlay — corner HUD reusing the NAIP ground texture with a rotating position marker (see D-13); debug window bumped from Godot's 1152x648 default to 1600x900, not an item from the original plan, added at the user's request

**Milestone: first "show someone" build.** This is the target for the first
recognizable, shareable version.

## Phase 4 — Detail pass

- [ ] Ground-level textures (grass, dirt, gravel) blended into terrain
- [ ] Vegetation scatter (grass shader/tool)
- [ ] Dynamic lighting / time-of-day
- [ ] Hero building detail pass (start with barn) — hand-modeled or photogrammetry
- [ ] Ambient effects (wind, sound) — cheap realism wins

## Phase 5 — Animals

- [x] Static horse models placed in pastures — one CC0 rigged/animated horse model (Quaternius, see [decisions.md](project/decisions.md) D-9) placed near Turn Out Shed 1
- [x] Simple wander/movement AI — done ahead of the plan's stated ordering, at the user's request; picks a random point within a radius of its home position, walks to it, idles, repeats (`scripts/horse.gd`, generalized as `scripts/wander.gd` for the animals below)
- [x] A loose flock (6 hens + 1 rooster, CC-BY — see D-10 and [docs/credits.md](credits.md)) that wanders the farmyard together — each bird micro-wanders near a shared, slower-wandering flock center, so the group drifts as a unit without moving in lockstep
- [x] One coyote (CC-BY, same source) wandering a fixed area in the back section of the property, away from the horse and flock
- [x] 3 ducks (CC-BY — see D-15/D-17 and [docs/credits.md](credits.md)) wandering independently south of the Back Barn
- [x] 10 geese (CC-BY, same source — see D-16) in their own cluster ~30m south of the ducks
- [x] 6 quail (CC-BY, same source — see D-17) wandering near the player's spawn point
- The horse (D-9) was found to be ~6.9m tall — `horse.tscn` had never applied a scale correction at all — and fixed to ~1.6m (D-18). Every animal in the scene has now been re-verified with an engine-instanced bounding-box check rather than an assumed or hand-parsed scale
- The flock's hens were floating with their feet buried — `hen.glb`'s origin was at the model's vertical center rather than its feet (unlike the rooster) — fixed with a Y-offset in `hen.tscn`, and the flock moved 20 ft north at the user's request (D-24)
- [ ] Upgrade the horse model to something more realistic with a richer action set (current CC0 Quaternius horse only has Idle/Walk/Run/etc., see D-9) — not started, no asset chosen yet. Research so far (2026-09-15), prompted by [this Godot horse-locomotion demo](https://www.reddit.com/r/godot/comments/1td8uzx/testing_two_different_horse_locomotion_systems/):
  - The Reddit demo's variety traces back to a [Sketchfab "Armored Horse" by naminoff](https://sketchfab.com/3d-models/armored-horse-98c3f1c40a6b422dba76bf5403e0a3d8) (CC BY 4.0, free, 44k tris, medieval/fantasy armor) via its creator's own [Horse-Riding-Simulator](https://github.com/Lakshman-YT/Horse-Riding-Simulator) repo — but the extra actions were **hand-animated in Blender by that developer**, not shipped with the download, so there's no ready-made rich-animation asset to just pull from there
  - Considered as free/CC alternatives: [abhayexe's "Horse Rigged (Game Ready)"](https://sketchfab.com/3d-models/horse-riggedgame-ready-bc64f4ff7966474ca9bacd42fa73a754) (CC BY, free, but low-poly/stylized at 2.9k tris — not more realistic than what we have); more Quaternius horse variants exist on poly.pizza but are almost certainly the same limited animation set as the current model
  - Considered as paid options, not yet vetted for Godot import or license terms: Synty Studios' "POLYGON Horse" (~$4, stylized, on poly.pizza) and a "Realistic Rigged and Animated 3D Horse Model" listing on Fab (price/animation list/license unconfirmed — page blocked automated fetch)
  - Also considered a real Unity Asset Store package, [Stylized Low Poly Animated Horse Pack](https://assetstore.unity.com/packages/3d/characters/animals/mammals/stylized-low-poly-animated-horse-pack-137631) (free, Standard Unity Asset Store EULA) — technically extractable (raw FBX + animation clips import fine into Godot 4.7's native FBX importer, bypassing the Unity-only Animator/prefab parts) but its EULA's terms on non-Unity use weren't confirmed, and it's stylized rather than realistic
  - No clear winner yet — either spend a little on a paid pack and verify it imports cleanly, or hand-animate 1-2 more actions (grazing, rearing) onto the existing CC0 horse

## Phase 6 — Chores / gameplay (lowest priority)

- [ ] Task list matching real farm chores (feeding, turnout, mucking, pasture rotation)
- [ ] Simple time-of-day / task-scheduling loop

## Fallback

If this becomes too involved before Phase 3's milestone, fall back to a smaller
2D Lemmings-clone project to maintain momentum (see project overview for context).
