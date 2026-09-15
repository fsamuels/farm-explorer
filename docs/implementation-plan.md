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
- [x] Add fence lines and pasture divisions as simple planes/lines — fence now traces the real parcel boundary polygon (13 segments); no pasture-division lines yet
- [ ] Walk the blockout and compare against memory/photos of the real property

## Phase 3 — First-person exploration

- [x] Add built-in first-person/walking character controller — WASD movement, mouse look, jump, and gravity in `player.gd`
- [x] Add collision to terrain, buildings, fences — `StaticBody3D`/`CollisionShape3D` on the ground plane, every building, and every fence segment
- [ ] Confirm free exploration of full property bounds — not yet walked end-to-end in-editor; fence segment collision shapes were previously skewed (see `parcel-data.md`), now fixed, but a walkthrough is still pending

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

## Phase 6 — Chores / gameplay (lowest priority)

- [ ] Task list matching real farm chores (feeding, turnout, mucking, pasture rotation)
- [ ] Simple time-of-day / task-scheduling loop

## Fallback

If this becomes too involved before Phase 3's milestone, fall back to a smaller
2D Lemmings-clone project to maintain momentum (see project overview for context).
