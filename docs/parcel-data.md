# Parcel Data

Source data gathered ahead of drone capture, to support scale validation and the
Phase 2 layout blockout. See [docs/implementation-plan.md](implementation-plan.md).

## Confirmed

| Field | Value | Source |
| --- | --- | --- |
| Parcel ID | 340732310005 | provided |
| Address | 1280 Lowden Gardena Rd, Touchet, WA 99360 | county assessor record (via state parcels service) |
| Acreage | 24.06 acres (24.01 acres computed from the real boundary polygon, ~97,155 m²) | county assessor record |
| Boundary polygon | [`docs/gis/parcel-340732310005.geojson`](gis/parcel-340732310005.geojson) | WA State Geospatial Open Data Portal `Current_Parcels` FeatureServer (statewide layer sourced from county assessor data), queried directly by `PARCEL_ID_NR='071-340732310005'` |
| Land value / building value | $205,300 / $523,900 | same source, `VALUE_LAND` / `VALUE_BLDG` fields |
| Building footprints (approximate) | [`docs/gis/buildings-340732310005.geojson`](gis/buildings-340732310005.geojson) — 7 footprints, 32–340 m² (344–3,656 ft²), 2 with height estimates (~3.9m, ~4.5m) | Overture Maps `buildings` theme (ML-derived from satellite/aerial imagery, aggregating Microsoft Building Footprints + Google Open Buildings + OSM), queried by intersection with the real parcel polygon |

The boundary and acreage above are now confirmed against the county assessor
record directly (not a third-party aggregator) — the earlier web-search figures
matched closely (24.06 vs. 24.01 acres, rounding from a bounding estimate).

The building footprints are **ML-derived approximations, not surveyed data** —
good enough for Phase 2 blockout positioning/rough scale, but expect shape and
placement to be off by some margin. Each is now named after the real
structure it represents (House, Shop, Sally's House, Back Barn, Front Barn,
Turn Out Shed 1, Turn Out Shed 2 — see the scene node names in `main.tscn`),
based on on-the-ground knowledge rather than a footprint-size guess.

## Still needed

- [x] Attribute each of the 7 footprints to a real structure — named in the
      scene (House, Shop, Sally's House, Back Barn, Front Barn, Turn Out Shed 1,
      Turn Out Shed 2) based on on-the-ground knowledge of the property, not
      footprint size
- [ ] Replace with surveyed/orthomosaic-derived footprints once available, for
      accurate shape and placement (ML footprints are approximate) — the
      building-to-structure mapping above should carry over even once the
      footprint geometry itself is replaced
- [ ] Replace the NAIP ground texture with the drone-derived orthomosaic once
      processed — NAIP is lower-resolution and possibly dated

## How the boundary polygon was obtained

The county's own GIS viewer (`wallawallacountygis-wwcgis.hub.arcgis.com`) and the
property search site (`propertysearch.co.walla-walla.wa.us`) are both JS-driven
Esri apps with no visible "download" button in their interactive map UI. Rather
than fight that UI, the same parcel data is available from the **Washington
State Geospatial Open Data Portal**, which republishes county assessor parcel
data as a public ArcGIS `FeatureServer` (no login required):

```
https://services.arcgis.com/jsIt88o09Q0r1j8h/arcgis/rest/services/Current_Parcels/FeatureServer/0/query
    ?where=PARCEL_ID_NR='071-340732310005'
    &outFields=*
    &outSR=4326
    &f=geojson
```

(`071` is Walla Walla County's statewide FIPS prefix; the assessor's own
`340732310005` is preserved in the `ORIG_PARCEL_ID` field.) This same
query-by-REST-API trick works for any Esri/ArcGIS-based GIS site: find the
underlying `FeatureServer`/`MapServer` URL (browser dev tools' Network tab,
filtering for "FeatureServer", usually reveals it) and append `/query` with a
`where` clause and `f=geojson`.

## How the building footprints were obtained

No county-level building footprint layer was found for this parcel — OSM has
nothing mapped in this rural area, and the one `Building_Footprints`
ArcGIS service discovered under a shared regional GIS org
(`services1.arcgis.com/1Wj8xAact2ptcedL`, which also hosts Walla Walla's own
parcels layer) turned out to cover Idaho's Lewis-Clark valley, not this parcel.

Instead, pulled from **Overture Maps** (`overturemaps-us-west-2` S3 bucket,
public, no auth), which aggregates Microsoft's and Google's ML building
detection plus OSM into one buildings theme, via DuckDB's spatial + httpfs
extensions:

```sql
INSTALL spatial; INSTALL httpfs; LOAD spatial; LOAD httpfs;
SET s3_region='us-west-2';

SELECT id, height, ST_AsGeoJSON(geometry)
FROM read_parquet(
    's3://overturemaps-us-west-2/release/<latest-release>/theme=buildings/type=building/*',
    filename=true, hive_partitioning=1
)
WHERE bbox.xmin BETWEEN <lon_min> AND <lon_max>
  AND bbox.ymin BETWEEN <lat_min> AND <lat_max>
  AND ST_Intersects(geometry, ST_GeomFromText('<parcel WKT polygon>'));
```

The `bbox.*` filter first narrows the scan via Overture's Hive-style
partitioning (fast, avoids reading unrelated Parquet row groups); `ST_Intersects`
against the real parcel polygon (not just its bounding box) then excludes
neighboring buildings. Find the current release folder name by listing
`s3://overturemaps-us-west-2/release/` (no credentials needed).

## How the ground texture was obtained

Real satellite/aerial imagery for the ground plane, pulled before drone capture,
same "headless public source now, replace with the real thing later" pattern as
the boundary polygon and building footprints above.

Source: **NAIP** (National Agriculture Imagery Program, USDA) — public domain,
~0.6–1m resolution aerial imagery, refreshed every 2–3 years. Pulled headlessly
from the USGS National Map's public `USGSNAIPPlus` ArcGIS `ImageServer` (no
auth) as a single PNG export sized to match the ground plane's real-world
extent exactly:

```
https://imagery.nationalmap.gov/arcgis/rest/services/USGSNAIPPlus/ImageServer/exportImage
    ?bbox=<lon_min>,<lat_min>,<lon_max>,<lat_max>
    &bboxSR=4326&imageSR=4326&size=1024,1024&format=png&f=image
```

(`gis.apfo.usda.gov`, USDA's own NAIP ImageServer, was unreachable from this
session — the USGS National Map mirror worked instead and serves the same NAIP
data.) The bbox was derived by inverse-projecting the ground plane's local
meter rectangle (position + size from `main.tscn`) back through the same
equirectangular projection used to place the boundary/buildings (D-6), so the
image lines up with the plane 1:1 without needing to touch the plane's
existing position/size.

Saved to `project/textures/ground/naip-340732310005.png` (not `assets/orthomosaic/`
— Godot's `res://` can't reach outside `project/`, see D-7) and applied as
`albedo_texture` on the ground plane's material in `main.tscn`.

Like the building footprints, this is a stand-in: real resolution is coarser
than drone imagery and the capture date is unknown/dated, but it beats a flat
color for getting oriented on the case map. Replace wholesale with the drone
orthomosaic once that's processed (see `assets/orthomosaic/`).

## How this is used in the scene

The Phase 2 blockout (`project/scenes/main.tscn`) now uses the **real parcel
boundary** (13 fence segments tracing the actual polygon edges from
`parcel-340732310005.geojson`) and **7 real building footprints** (boxes
positioned/sized from `buildings-340732310005.geojson`), converted from
lat/lon to local meters via a simple equirectangular projection centered on
the parcel's area centroid (local origin `(0,0)` = that centroid; `+X` = east,
`+Z` = south, matching the scene's existing convention). The ground plane
(520m × 520m, centered on the boundary's bounding-box center) was resized to
fit — the real parcel's bounding box (~430m × 435m) is notably larger and less
square than the old 312m × 312m placeholder because the parcel shape is
irregular, not because the acreage changed.

Buildings are still axis-aligned boxes (not rotated to each structure's real
orientation) and unattributed to specific structures (house/barn/shed) — see
"Still needed" above. The old provisional-square/single-placeholder-box setup
this section used to describe is gone, superseded now that real boundary and
building data are both available (see D-3, D-5 in
[decisions.md](project/decisions.md)).

Each fence segment and building is an **instance of a shared scene**
(`scenes/fence_segment.tscn`, `scenes/building.tscn`) rather than an inline
node subtree in `main.tscn` — only the per-instance `transform` (position,
rotation, non-uniform scale) lives in `main.tscn` itself (see D-8). The player
is likewise its own `scenes/player.tscn`, instanced once.

The player's spawn point (`Player` node in `main.tscn`) sits just inside the
parcel boundary near where the property actually fronts **Lowden-Gardena
Road**, rather than at the parcel's centroid — found by pulling the road's
real geometry from OpenStreetMap (Overpass API, way "Lowden-Gardena Road")
and projecting it into the same local coordinate frame as the boundary/
buildings, then locating the closest boundary edge to the road and offsetting
~15m inward (clear of every building). Facing direction was set by hand in
the editor afterward.

### Fence segment transforms were fixed after being originally computed skewed

Each fence segment's transform (D-6) encodes its length along whichever of the
box's local X/Z axes is longer, and its ~0.15m thickness along the other. When
the boundary data first went in, that thickness axis wasn't actually
perpendicular to the length axis for any of the 13 segments — several were
close enough to look right, but two (originally `Fence_10` and `Fence_13`)
were skewed almost to the point of collapsing into a flat sliver in the ground
plane. Re-derived directly from each segment's own length axis (rotate it 90°
in the XZ plane, normalize, keep everything else — position, length, and
height — unchanged), so every segment is now a proper straight rectangular
rail rather than a sheared parallelogram.
