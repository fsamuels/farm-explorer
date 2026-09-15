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
- [x] 3 ducks (CC-BY — see D-15 and [docs/credits.md](credits.md)) wandering independently near the Back Barn

## Phase 6 — Chores / gameplay (lowest priority)

- [ ] Task list matching real farm chores (feeding, turnout, mucking, pasture rotation)
- [ ] Simple time-of-day / task-scheduling loop

## Fallback

If this becomes too involved before Phase 3's milestone, fall back to a smaller
2D Lemmings-clone project to maintain momentum (see project overview for context).
