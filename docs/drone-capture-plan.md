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
- Avoid high wind days (vegetation movement between photos hurts stitching)
- Check WA drone regulations / FAA Part 107 if applicable for your drone class (informational — confirm current rules before flying)

## Processing tools (candidates, not yet decided)

- **WebODM** — open source, handles both orthomosaic and 3D mesh/point cloud generation from drone photos
- **Meshroom** — free, photogrammetry-focused, good for individual structures too (later, for hero buildings)
- Engine-specific import plugins may simplify parts of this pipeline once engine is chosen

## Output checklist

- [ ] Orthomosaic image (for terrain texture)
- [ ] Heightmap/DEM (if doing photogrammetry terrain)
- [ ] Raw photo set retained (useful later for photogrammetry on individual buildings)
