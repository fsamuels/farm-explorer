# Parcel Data

Source data gathered ahead of drone capture, to support scale validation and the
Phase 2 layout blockout. See [docs/implementation-plan.md](implementation-plan.md).

## Confirmed

| Field | Value | Source |
| --- | --- | --- |
| Parcel ID | 340732310005 | provided |
| Address | Lowden Gardena Rd, Touchet, WA 99360 | web search (property record aggregator) |
| Acreage | 24.06 acres (~97,340 m²) | web search (property record aggregator) |

These figures come from a third-party property data aggregator, not the county
assessor directly — treat as provisional until cross-checked.

## Still needed (not fetchable without an interactive map session)

Walla Walla County's GIS parcel viewer and the county property search
(`propertysearch.co.walla-walla.wa.us`) are both JS-driven interactive apps —
they don't return parcel data to a plain page fetch. To get the real boundary
polygon and confirm siting, pull these manually and drop the export into this
repo (or transcribe coordinates below):

- [ ] Exact parcel boundary polygon (shapefile/GeoJSON export from the county
      GIS viewer, or Regrid/Acres if they offer a free export for this parcel)
- [ ] Building footprint positions relative to the boundary (house, barn,
      outbuildings) — county GIS often has building outlines; otherwise this
      waits for the orthomosaic
- [ ] Confirm acreage/boundary against the county assessor record directly
      (`wallawallacountygis-wwcgis.hub.arcgis.com` or `wwcowa.gov/government/gis`)

## How this is used until then

The Phase 2 blockout (`project/scenes/main.tscn`) uses a **provisional square
boundary** sized to match the confirmed 24.06-acre total (≈312m × 312m) and a
placeholder building box at the field center — not real positions or shape.
Once the real boundary/building data lands, replace the boundary mesh and
reposition the placeholder buildings to match; nothing else in the scene
depends on their current placement.
