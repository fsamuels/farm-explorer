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

The boundary and acreage above are now confirmed against the county assessor
record directly (not a third-party aggregator) — the earlier web-search figures
matched closely (24.06 vs. 24.01 acres, rounding from a bounding estimate).

## Still needed

- [ ] Building footprint positions relative to the boundary (house, barn,
      outbuildings) — county GIS often has building outlines; otherwise this
      waits for the orthomosaic
- [ ] Land value/building value above (from the assessor extract) don't include
      a building footprint layer — check `wallawallacountygis-wwcgis.hub.arcgis.com`
      for a separate buildings/structures dataset, or wait for the orthomosaic

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

## How this is used until then

The Phase 2 blockout (`project/scenes/main.tscn`) uses a **provisional square
boundary** sized to match the confirmed 24.06-acre total (≈312m × 312m) and a
placeholder building box at the field center — not real positions or shape.
Once the real boundary/building data lands, replace the boundary mesh and
reposition the placeholder buildings to match; nothing else in the scene
depends on their current placement.
