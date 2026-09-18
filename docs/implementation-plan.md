# Implementation Plan

Built on Godot 4 — the engine decision is finalized (D-2; see
[docs/engine-decision.md](engine-decision.md) for the tradeoffs considered).
Steps are ordered by recognition-impact-per-hour, not by conventional game dev
milestones — the priority is fast, visible progress toward "that's clearly the farm."

## Current priority — realism pass

The user's stated next focus, ahead of finishing out any one phase in full:
make the property look and feel more like the real place, rather than a
placeholder blockout. Tracked as new items in their respective phases below;
listed together here since they're the immediate priority as a group:

1. **Missing buildings** (Phase 2) — the current 7 buildings are all Overture
   Maps' ML-detected footprints (D-5); an ML model trained on satellite
   imagery can miss small/irregular real structures (sheds, coops, run-ins).
   Needs a real on-the-ground inventory of what's out there but not yet placed.
   Partial progress: a `Sally's House Garage` wing, a third turnout shed, and
   a red shipping container were added from what's visible in the orthomosaic
   itself (D-32–D-34) — still not a full ground-truth inventory pass.
2. **Fence gates** (Phase 2) — the boundary fence (13 segments, D-11) is
   currently one fully closed loop with no openings anywhere, including at
   the real driveway entrance near Lowden-Gardena Road the player already
   spawns next to ([docs/parcel-data.md](parcel-data.md)). Needs real gate
   locations.
3. **Building wall textures** (Phase 4) — only roofs have real photo textures
   so far (5 of 7 buildings, D-20 through D-23), and only because the drone
   orthomosaic happened to cover them from above; every wall is still the
   placeholder box color.
4. ~~**Building/overlay alignment** (Phase 4)~~ — done for the 5 buildings
   covered by the front-section orthomosaic: position, size, and rotation
   all re-derived from the orthomosaic pixels rather than the ML footprints
   (D-30–D-34). House and Back Barn still use the ML-approximated positions,
   pending the second drone flight (item 7 below).
5. **Missing animals** (Phase 5) — current roster is 2 horses, a flock (6
   hens + 1 rooster), 1 coyote, 3 ducks, 10 geese, 6 quail. Needs the real
   list of what's actually kept on the property today.
6. **Trees and other foliage** (Phase 4) — the only vegetation so far is the
   D-11 boundary treeline, which exists as a hard map-edge limit 20m *outside*
   the real property, not as real foliage placement; the property itself
   (yard trees, wooded areas, brush) has none yet.
7. **Drone coverage for the back of the property** (Phase 0/1) — the only
   real drone capture so far is D-19's single flight over the "front
   section" (Front Barn/Shop/Sally's House, all near the Lowden-Gardena Road
   entrance); House and Back Barn sit much farther from the road and are
   still on the NAIP stand-in with no orthomosaic, which is also why they're
   still flat-topped with no roof texture (item 4 above, Phase 4). Needs a
   second drone flight over that back section, then the same OpenDroneMap
   processing D-19 already proved out.

## Phase 0 — Source data

- [~] Fly drone in a structured overlapping grid pattern over the full property, to support photogrammetry terrain generation later — first capture done for one section only (129 nadir, GPS-tagged photos over the Front Barn/Shop/Sally's House area, D-19); **next up: a second flight over the back section (House, Back Barn) — current priority, see above**
- [x] Fly a straight-down pass for a clean top-down orthomosaic (aerial texture) — done for that same front section (D-19); repeat for the back section next
- [x] Gather any existing parcel boundary / measurement data (check water rights project docs — parcel is 340732310005) — confirmed acreage, real boundary polygon, and approximate (ML-derived) building footprints, all via public GIS REST APIs, see [docs/parcel-data.md](parcel-data.md)
- [ ] Note real-world dimensions of key structures (barn, key fences) for scale validation later

## Phase 1 — Terrain

- [x] Process drone photos into an orthomosaic (top-down stitched image) — OpenDroneMap (`opendronemap/odm` Docker image, `--fast-orthophoto --skip-report`) processed the D-19 capture into a real orthophoto; proven for one section, repeatable as more sections are flown
- [ ] Optionally process into a heightmap/DEM if photogrammetry is used — explicitly skipped for the D-19 run (orthophoto only, no 3D mesh was needed for a ground texture)
- [ ] Import terrain into engine, scaled to match real property dimensions — still a flat ground plane; no real terrain geometry yet, only ground *texture* has improved
- [~] Apply orthomosaic as terrain texture — the front section (Front Barn/Shop/Sally's House area) now uses the real drone-derived orthomosaic as a higher-resolution ground patch layered over the base texture, positioned via its own UTM georeferencing (D-19); the back section (House, Back Barn) and rest of the property are still the public-NAIP-imagery stand-in (see [docs/parcel-data.md](parcel-data.md)) — current priority, see above
- [ ] Validate scale: confirm walking speed vs. known real-world distances (e.g. barn to fence line) feels correct

## Phase 2 — Layout blockout

- [~] Place boxy placeholder geometry for every building at correct position, orientation, and rough scale — 11 boxes now (the original 7 plus a Sally's House garage wing, a third turnout shed, a red shipping container (D-32), and a white-walled Pump House east of Sally's House (D-35)), with the 5 orthomosaic-covered buildings re-positioned/sized/rotated from real drone imagery rather than ML approximations (D-30–D-34); the 3 turnout sheds and the Pump House use single-slope lean-to roofs (D-35), the rest use sloped gable roofs/gable-end fills (Phase 4, D-20 through D-23/D-25); House and Back Barn remain flat-topped, axis-aligned ML approximations, not yet covered by a drone pass (see [docs/parcel-data.md](parcel-data.md))
- [x] Add fence lines and pasture divisions as simple planes/lines — fence now traces the real parcel boundary polygon (13 segments) as a procedurally-generated wire/post fence rather than a placeholder box (see D-11); no pasture-division lines yet
- [x] Edge-of-map treatment — a treeline 20m outside the real boundary (`scenes/tree_line_segment.tscn`) is the actual hard limit on exploration, rather than the property fence itself (see D-11); not an item from the original plan, added at the user's request. Known rough edge: corners look a bit off since each segment is offset independently with no mitering (D-11) — acceptable for now, flagged by the user as something to revisit later, not a blocker
- [ ] Walk the blockout and compare against memory/photos of the real property
- [ ] Add any real buildings not yet represented — current 7 are Overture Maps' ML-detected footprints (D-5); small/irregular structures (sheds, coops, run-ins) an ML model can miss may be unrepresented. Needs a real inventory from the user — current priority, see above
- [ ] Add gate openings to the boundary fence at real vehicle/pedestrian access points (e.g. the driveway near Lowden-Gardena Road the player already spawns next to) — the fence is currently one fully closed 13-segment loop with no way through it anywhere (D-11) — current priority, see above

## Phase 3 — First-person exploration

- [x] Add built-in first-person/walking character controller — WASD movement, mouse look, jump, and gravity in `player.gd`
- [x] Add collision to terrain, buildings, fences — `StaticBody3D`/`CollisionShape3D` on the ground plane, every building, and every fence segment
- [ ] Confirm free exploration of full property bounds — not yet walked end-to-end in-editor; the boundary itself has now been wrong twice (skewed collision shapes, then wrong edge directions entirely — see `parcel-data.md` and D-12) and caught both times by inspection rather than an actual walkthrough, so this is worth doing for real before trusting the boundary further
- [x] Minimap overlay — corner HUD reusing the NAIP ground texture with a rotating position marker (see D-13), now also showing a live X/Z coordinate readout above the map to make repositioning other objects during development easier (D-27); debug window bumped from Godot's 1152x648 default to 1920x1080 (an initial bump to 1600x900 was later bumped again), not an item from the original plan, added at the user's request

**Milestone: first "show someone" build.** This is the target for the first
recognizable, shareable version.

## Phase 4 — Detail pass

- [ ] Ground-level textures (grass, dirt, gravel) blended into terrain
- [ ] Vegetation scatter (grass shader/tool) — ground-cover only (grass/dirt shading); see the separate discrete-tree/foliage item below
- [ ] Dynamic lighting / time-of-day
- [ ] Hero building detail pass (start with barn) — hand-modeled or photogrammetry
- [ ] Ambient effects (wind, sound) — cheap realism wins
- [x] Higher-resolution ground patch over the front section (Front Barn/Shop/Sally's House area) from the first real drone capture, layered over the base NAIP ground plane (D-19) — not an item from the original plan, pulled forward once drone photos became available
- [x] Sloped roof geometry and gable-end fills for the 5 buildings covered by that orthomosaic — roof crops textured per building/slope, plus a shared procedural gable-fill script (D-20 through D-23, D-25); House and Back Barn remain flat-topped, not yet covered by a drone pass — not an item from the original plan
- [x] One decorative parked prop — a Triumph TR6 east of the Shop, facing south (CC BY 4.0, Configcars via Sketchfab, D-26); simplified from a 32MB/879k-triangle download to 7.7MB since it's a static background object — not an item from the original plan, added at the user's request
- [x] A second decorative parked prop — a BMW 2002 tii in Sally's House's driveway, facing north (Sketchfab, D-40); simplified from a 22.63MB/1.79M-vertex download to 5.6MB — not an item from the original plan, added at the user's request
- [ ] Texture each building's exterior walls — only roofs have real photo textures so far (5 of 7 buildings, D-20 through D-23); the `Red Shipping Container` now has a real corrugated-metal texture on its top *and* sides, triplanar-tiled from a clean crop of its own top-down photo (D-39, no side-elevation photos existed for any building at the time). Sally's House and its garage now have 5 of their 8 walls (house north/south/east, garage north/east) textured from the user's own ground-level phone photos, re-cropped with a proper perspective correction rather than a stretch (D-44, D-46) — using a new project tool, `tools/elevation-rectifier.html`, for the corner-picking; not yet verified with an in-engine screenshot. The remaining 3 walls on those two buildings, and every wall on every other building, are still the placeholder box color — current priority, see above
- [ ] Model the east side of Sally's House as a real covered porch/entry addition (its own volume, roofline, windows, and door) instead of the flat triangular gable-end placeholder — the user's own east-side photo shows a full porch structure there, not a plain gable wall (D-47). Wired in as a stopgap anyway at the user's request (D-48, `sallys_house_east_wall.png` on a flat `SallysHouse_Wall_East` decal), so it's visibly wrong around the roofline/gable rather than plain placeholder color until this gets real geometry (like the north porch already implies)
- [x] Re-align building placement (and their roof-texture overlays) against the real drone orthomosaic/ground imagery — the 5 buildings under the front-section orthomosaic had position, size, and rotation re-derived directly from the orthomosaic pixels (D-30–D-34); House and Back Barn are unchanged, still the ML-approximated positions, pending the second drone flight
- [ ] Add trees and other foliage scattered around the property itself (yard trees, wooded areas, brush) — distinct from the D-11 boundary treeline, which is a hard map-edge limit 20m *outside* the property, not real vegetation placement — current priority, see above

## Phase 5 — Animals

- [x] Static horse models placed in pastures — CC0 rigged/animated horse model (Quaternius, see [decisions.md](project/decisions.md) D-9), now 2 instances (`Horse`, `Horse2`) roaming a shared rectangular pasture area near Turn Out Shed 1 (`163.2,30.6`–`249.1,39.8`) rather than circling one fixed home point (D-28)
- [x] Simple wander/movement AI — done ahead of the plan's stated ordering, at the user's request; picks a random point within a radius of its home position, walks to it, idles, repeats (`scripts/horse.gd`, generalized as `scripts/wander.gd` for the animals below)
- [x] A loose flock (6 hens + 1 rooster, CC-BY — see D-10 and [docs/credits.md](credits.md)) that wanders the farmyard together — each bird micro-wanders near a shared, slower-wandering flock center, so the group drifts as a unit without moving in lockstep
- [x] One coyote (CC-BY, same source) wandering a fixed area in the back section of the property, away from the horse and flock
- [x] 3 ducks (CC-BY — see D-15/D-17 and [docs/credits.md](credits.md)) wandering independently, recentered near `(37.5, 17.9)` using the new minimap coordinate readout (D-27)
- [x] 10 geese (CC-BY, same source — see D-16) in their own cluster, kept 15 ft (4.572m) south of the ducks — tightened from the original 30m gap at the user's request (D-27)
- [x] 6 quail (CC-BY, same source — see D-17) wandering near the player's spawn point
- The horse (D-9) was found to be ~6.9m tall — `horse.tscn` had never applied a scale correction at all — and fixed to ~1.6m (D-18). Every animal in the scene has now been re-verified with an engine-instanced bounding-box check rather than an assumed or hand-parsed scale
- The flock's hens were floating with their feet buried — `hen.glb`'s origin was at the model's vertical center rather than its feet (unlike the rooster) — fixed with a Y-offset in `hen.tscn`, and the flock moved 20 ft north at the user's request (D-24)
- The horses were found facing 180° backwards while walking ("moonwalking" per the user) — `horse.gd`'s `look_at()` was correctly orienting them toward their direction of travel, but the model's own local forward axis didn't match, so the body faced away from the direction of movement while the walk animation kept cycling; fixed with a rotation correction in `horse.tscn` (D-28)
- [ ] Add any real animals not yet represented — current roster is 2 horses, a flock (6 hens + 1 rooster), 1 coyote, 3 ducks, 10 geese, 6 quail. Needs the real list of what's actually kept on the property today — current priority, see above
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
