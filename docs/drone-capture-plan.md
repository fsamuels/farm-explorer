# Drone Capture Plan

## Two separate flights, two purposes

**1. Orthomosaic pass (aerial texture)**
- Straight-down camera angle
- Single high-altitude pass or light grid, prioritizing even lighting and coverage
- Output: one clean stitched top-down image for terrain texturing

**2. Photogrammetry grid (3D terrain mesh, optional but recommended)**
- Structured grid pattern with high overlap between photos (~70-80% front/side overlap is typical for photogrammetry)
- Multiple altitudes/angles if possible (nadir + oblique) for better mesh reconstruction
- More photos than feels necessary — photogrammetry quality is very sensitive to overlap

## Conditions

- Fly on an overcast day or consistent lighting if possible — harsh shadows complicate both stitching and texture quality
- Leave enough light: the middle-section flight ran just after sunset and came
  back at ISO 840–1300 and 1/8–1/15s. It stitched and could be colour-matched
  (D-83), but fine detail is softer than the front section's
- Overlap the previous section by a strip that includes hard surfaces (roof,
  concrete, gravel) — `tools/ortho_join_section.py` uses them to align and
  colour-match the new section to the existing one
- Avoid high wind days (vegetation movement between photos hurts stitching)
- Check WA drone regulations / FAA Part 107 if applicable for your drone class (informational — confirm current rules before flying)

## Processing tools (candidates, not yet decided)

- **WebODM** — open source, handles both orthomosaic and 3D mesh/point cloud generation from drone photos
- **Meshroom** — free, photogrammetry-focused, good for individual structures too (later, for hero buildings)
- Engine-specific import plugins may simplify parts of this pipeline once engine is chosen

## Output checklist

- [x] Orthomosaic image (for terrain texture) — Front Barn/Shop/Sally's House
      section done via ODM `--fast-orthophoto`, see `docs/parcel-data.md`.
      Middle section (House, Back Barn, pond) added the same way and joined
      to the front patch with `tools/ortho_join_section.py` (D-83); shot at
      dusk, so worth re-flying in daylight. Back of the property still needs
      its own flight(s).
- [ ] Heightmap/DEM (if doing photogrammetry terrain)
- [x] Raw photo set retained — `assets/drone-source/front-section/` and
      `middle-section/` (gitignored)
