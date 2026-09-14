# Implementation Plan

Engine-agnostic until the engine decision is made (see engine-decision.md).
Steps are ordered by recognition-impact-per-hour, not by conventional game dev
milestones — the priority is fast, visible progress toward "that's clearly the farm."

## Phase 0 — Source data

- [ ] Fly drone in a structured overlapping grid pattern (not just a few shots) over the full property, to support photogrammetry terrain generation later
- [ ] Fly a straight-down pass for a clean top-down orthomosaic (aerial texture)
- [x] Gather any existing parcel boundary / measurement data (check water rights project docs — parcel is 340732310005) — confirmed acreage via public records, see [docs/parcel-data.md](parcel-data.md); exact boundary polygon and building footprints still need a manual GIS export
- [ ] Note real-world dimensions of key structures (barn, key fences) for scale validation later

## Phase 1 — Terrain

- [ ] Process drone photos into an orthomosaic (top-down stitched image) — tool TBD pending engine choice (e.g. WebODM, Meshroom, or engine-specific plugin)
- [ ] Optionally process into a heightmap/DEM if photogrammetry is used
- [ ] Import terrain into engine, scaled to match real property dimensions
- [ ] Apply orthomosaic as terrain texture
- [ ] Validate scale: confirm walking speed vs. known real-world distances (e.g. barn to fence line) feels correct

## Phase 2 — Layout blockout

- [~] Place boxy placeholder geometry for every building at correct position, orientation, and rough scale — one placeholder building box added at a provisional position; real siting waits on parcel/building GIS data or the orthomosaic (see [docs/parcel-data.md](parcel-data.md))
- [~] Add fence lines and pasture divisions as simple planes/lines — provisional square boundary fence added, sized to match confirmed 24.06-acre total; not the real parcel shape
- [ ] Walk the blockout and compare against memory/photos of the real property

## Phase 3 — First-person exploration

- [ ] Add built-in first-person/walking character controller
- [ ] Add collision to terrain, buildings, fences
- [ ] Confirm free exploration of full property bounds

**Milestone: first "show someone" build.** This is the target for the first
recognizable, shareable version.

## Phase 4 — Detail pass

- [ ] Ground-level textures (grass, dirt, gravel) blended into terrain
- [ ] Vegetation scatter (grass shader/tool)
- [ ] Dynamic lighting / time-of-day
- [ ] Hero building detail pass (start with barn) — hand-modeled or photogrammetry
- [ ] Ambient effects (wind, sound) — cheap realism wins

## Phase 5 — Animals

- [ ] Static horse models placed in pastures
- [ ] Simple wander/movement AI (deferred until base environment is solid)

## Phase 6 — Chores / gameplay (lowest priority)

- [ ] Task list matching real farm chores (feeding, turnout, mucking, pasture rotation)
- [ ] Simple time-of-day / task-scheduling loop

## Fallback

If this becomes too involved before Phase 3's milestone, fall back to a smaller
2D Lemmings-clone project to maintain momentum (see project overview for context).
