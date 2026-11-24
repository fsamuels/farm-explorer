#!/usr/bin/env python3
"""Build the driveable world around the farm (D-148): real ground elevation,
named roads, and aerial imagery, out to 5.6 km from the scene origin.

Three public-domain US Government sources, all fetched headlessly:

* USGS 3DEP elevation (the National Map `3DEPElevation` ImageServer), one float32
  GeoTIFF over a 11.2 km square centred on the parcel centroid (the scene origin,
  D-6/D-12), resampled to a 20 m grid of heights (int16 decimetres, base64) and
  written to project/scripts/world_data.gd.
* Census TIGERweb roads (`TIGERweb/Transportation` MapServer, layers 2, 6 and 8), each
  point of which is also marked asphalt or gravel from the full-resolution NAIP photo
  (see classify_surfaces):
  every road that has a name and is a highway or local road (MTFCC S1100, S1200,
  S1400), clipped to the square, projected to scene metres and written to
  project/scripts/road_data.gd. Unnamed roads, driveways, parking aisles and
  private service roads are left out on purpose ("main named roads").
* USDA NAIP aerial imagery (the National Map `USGSNAIPPlus` ImageServer), one
  2048 px JPEG over the same square, written to
  project/textures/world/naip_world.jpg and draped over the ground beyond the farm.

The roads are also cut into the ground: each road's profile is smoothed and capped
at a 9% grade, and the elevation grid is pulled to it along the road (a bench with
shoulders), because a 20 m grid of raw hillside would make some hill roads steeper
than a road is ever built.

Scene coordinates are the same equirectangular projection as everywhere else:
metres east (x) and south (z) of the parcel centroid.

Usage (network needed; numpy and Pillow):
    python3 tools/build_world_data.py [--cache DIR]
"""
import argparse
import base64
import concurrent.futures
import io
import json
import math
import os
import sys
import urllib.parse
import urllib.request

import numpy as np
from PIL import Image

LON0, LAT0 = -118.58959936, 46.03902781
M_PER_DEG_LAT = 111320.0
M_PER_DEG_LON = 111320.0 * math.cos(math.radians(LAT0))

HALF = 5600.0          # half the side of the world square, m
CELL = 20.0            # DEM grid spacing, m
NODES = int(round(2 * HALF / CELL)) + 1
DEM_PX = 1200
NAIP_PX = 2048

BBOX = (LON0 - HALF / M_PER_DEG_LON, LAT0 - HALF / M_PER_DEG_LAT,
        LON0 + HALF / M_PER_DEG_LON, LAT0 + HALF / M_PER_DEG_LAT)

DEM_URL = ("https://elevation.nationalmap.gov/arcgis/rest/services/3DEPElevation/ImageServer/exportImage"
           "?bbox={},{},{},{}&bboxSR=4326&imageSR=4326&size={},{}&format=tiff&pixelType=F32"
           "&noDataInterpretation=esriNoDataMatchAny&interpolation=RSP_BilinearInterpolation"
           "&compression=None&f=image")
NAIP_URL = ("https://imagery.nationalmap.gov/arcgis/rest/services/USGSNAIPPlus/ImageServer/exportImage"
            "?bbox={},{},{},{}&bboxSR=4326&imageSR=4326&size={},{}&format=jpg&compressionQuality=85&f=image")
TIGER = "https://tigerweb.geo.census.gov/arcgis/rest/services/TIGERweb/Transportation/MapServer"
TIGER_LAYERS = (2, 6, 8)
# MTFCC feature classes kept: primary highway, secondary highway, local road.
KINDS = {"S1100": 0, "S1200": 1, "S1400": 2}
WIDTHS = {0: 7.4, 1: 7.4, 2: 6.4}

# Road surfaces come from the aerial photo at full resolution (about 1 m a pixel),
# fetched in NAIP_TILES x NAIP_TILES tiles of NAIP_TILE_PX pixels.
NAIP_TILE_PX = 1400
NAIP_TILES = int(2 * HALF / NAIP_TILE_PX)
SURFACE_PAVED, SURFACE_GRAVEL = 0, 1
ROAD_SPACING = 8.0

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "project")
OUT_WORLD = os.path.join(ROOT, "scripts", "world_data.gd")
OUT_ROADS = os.path.join(ROOT, "scripts", "road_data.gd")
OUT_NAIP = os.path.join(ROOT, "textures", "world", "naip_world.jpg")


def fetch(url, path=None):
    if path and os.path.exists(path):
        with open(path, "rb") as f:
            return f.read()
    req = urllib.request.Request(url, headers={"User-Agent": "farm-explorer-build"})
    with urllib.request.urlopen(req, timeout=300) as r:
        data = r.read()
    if path:
        with open(path, "wb") as f:
            f.write(data)
    return data


def to_scene(lon, lat):
    return (lon - LON0) * M_PER_DEG_LON, -(lat - LAT0) * M_PER_DEG_LAT


def dem_grid(tif_path):
    a = np.array(Image.open(tif_path), dtype=np.float32)
    if a.shape != (DEM_PX, DEM_PX) or a.max() < 50 or a.min() < -50 or np.isnan(a).any():
        sys.exit("DEM looks wrong: shape %s, min %.1f, max %.1f" % (a.shape, a.min(), a.max()))
    xs = -HALF + CELL * np.arange(NODES)
    px = np.clip((xs + HALF) / (2 * HALF) * DEM_PX - 0.5, 0, DEM_PX - 1.001)
    i0 = px.astype(int)
    f = (px - i0).astype(np.float32)
    # Rows run north (z = -HALF) to south, columns west to east, so scene z index
    # i maps to image row i directly.
    rows = a[i0] * (1 - f)[:, None] + a[i0 + 1] * f[:, None]
    grid = rows[:, i0] * (1 - f)[None, :] + rows[:, i0 + 1] * f[None, :]
    origin = float(grid[NODES // 2, NODES // 2])
    return grid, origin


# Road beds: the 20 m grid can't show a road cut into a hillside, and the raw
# ground makes some roads in the hills (Butler Grade, the Touchet bluffs) steeper
# than a road is built. Each road's profile is smoothed and capped at MAX_GRADE,
# and the grid nodes along it are pulled to that profile: fully within BED_FULL
# metres of the centreline (every point of a road is within 14.2 m of a node),
# fading back to the natural ground by BED_FADE.
MAX_GRADE = 0.09
PROFILE_STEP = 10.0
BED_FULL = 14.5
BED_FADE = 34.0


def smooth_profile(e, ds):
    """`e` (elevations every `ds` m along a road) smoothed, then capped at MAX_GRADE."""
    e = np.array(e, dtype=np.float64)
    if len(e) >= 7:
        pad = np.pad(e, 3, mode="edge")
        for _ in range(2):
            pad = np.pad(np.convolve(pad, np.ones(7) / 7.0, mode="valid"), 3, mode="edge")
        e = pad[3:-3]
    cap = MAX_GRADE * ds
    for k in range(1, len(e)):
        e[k] = min(max(e[k], e[k - 1] - cap), e[k - 1] + cap)
    for k in range(len(e) - 2, -1, -1):
        e[k] = min(max(e[k], e[k + 1] - cap), e[k + 1] + cap)
    return e


def carve_roads(grid, rs):
    """Pull the grid nodes near each road to its smoothed, grade-capped profile."""
    num = np.zeros_like(grid, dtype=np.float64)
    den = np.zeros_like(grid, dtype=np.float64)
    reach = int(math.ceil(BED_FADE / CELL)) + 1

    def sample(x, z):
        gx = min(max((x + HALF) / CELL, 0.0), NODES - 1.001)
        gz = min(max((z + HALF) / CELL, 0.0), NODES - 1.001)
        i, j = int(gx), int(gz)
        u, v = gx - i, gz - j
        return float(grid[j, i] * (1 - u) * (1 - v) + grid[j, i + 1] * u * (1 - v)
                     + grid[j + 1, i] * (1 - u) * v + grid[j + 1, i + 1] * u * v)

    moved = 0.0
    for _, _, part in rs:
        # Resample every PROFILE_STEP m along the road.
        pts = [np.array(part[0], dtype=np.float64)]
        carry = 0.0
        for a, b in zip(part, part[1:]):
            a, b = np.array(a, dtype=np.float64), np.array(b, dtype=np.float64)
            seg = float(np.linalg.norm(b - a))
            if seg < 1e-6:
                continue
            at = PROFILE_STEP - carry
            while at < seg:
                pts.append(a + (b - a) * (at / seg))
                at += PROFILE_STEP
            carry = seg - (at - PROFILE_STEP)
        pts.append(np.array(part[-1], dtype=np.float64))
        elev = smooth_profile([sample(p[0], p[1]) for p in pts], PROFILE_STEP)
        for p, target in zip(pts, elev):
            ci = int(round((p[0] + HALF) / CELL))
            cj = int(round((p[1] + HALF) / CELL))
            for j in range(max(cj - reach, 0), min(cj + reach + 1, NODES)):
                for i in range(max(ci - reach, 0), min(ci + reach + 1, NODES)):
                    d = math.hypot(-HALF + i * CELL - p[0], -HALF + j * CELL - p[1])
                    if d >= BED_FADE:
                        continue
                    w = 1.0 if d <= BED_FULL else 1.0 - (d - BED_FULL) / (BED_FADE - BED_FULL)
                    w = w * w * (3 - 2 * w)
                    num[j, i] += w * target
                    den[j, i] += w
    hit = den > 0
    out = grid.astype(np.float64).copy()
    blend = np.minimum(den[hit], 1.0)
    out[hit] = grid[hit] * (1 - blend) + (num[hit] / den[hit]) * blend
    moved = np.abs(out - grid)
    return out.astype(np.float32), float(moved.max()), int(hit.sum())


def clip_polyline(pts):
    """Split a scene-metre polyline into the parts inside the world square."""
    parts, cur = [], []
    for x, z in pts:
        if abs(x) <= HALF - 5 and abs(z) <= HALF - 5:
            cur.append((x, z))
        elif cur:
            parts.append(cur)
            cur = []
    if cur:
        parts.append(cur)
    return [p for p in parts if len(p) >= 2]


def roads(cache):
    seen, out = set(), []
    env = "%f,%f,%f,%f" % BBOX
    for layer in TIGER_LAYERS:
        q = urllib.parse.urlencode(dict(
            where="1=1", geometry=env, geometryType="esriGeometryEnvelope", inSR=4326, outSR=4326,
            spatialRel="esriSpatialRelIntersects", outFields="OID,NAME,MTFCC", returnGeometry="true", f="json"))
        path = os.path.join(cache, "tiger_%d.json" % layer) if cache else None
        d = json.loads(fetch("%s/%d/query?%s" % (TIGER, layer, q), path))
        if "error" in d or d.get("exceededTransferLimit"):
            sys.exit("TIGER layer %d: %s" % (layer, d.get("error", "too many records")))
        for feat in d["features"]:
            a = feat["attributes"]
            if not a.get("NAME") or a["MTFCC"] not in KINDS or a["OID"] in seen:
                continue
            seen.add(a["OID"])
            for path_ll in feat["geometry"]["paths"]:
                for part in clip_polyline([to_scene(lo, la) for lo, la in path_ll]):
                    out.append((a["NAME"], KINDS[a["MTFCC"]], part))
    out.sort(key=lambda r: (r[0], r[1], r[2][0]))
    return out


def write_world(grid, origin):
    dm = np.round(grid * 10.0).astype("<i2")
    lines = [
        "## Generated by tools/build_world_data.py (D-148). Do not edit by hand.",
        "## Real ground elevation around the farm from USGS 3DEP, on a regular grid",
        "## over a square centred on the scene origin. US Government, public domain.",
        "",
        "## Half the side of the square (m); it runs from -HALF to +HALF in x and z.",
        "const HALF := %s" % HALF,
        "## Metres between grid nodes.",
        "const CELL := %s" % CELL,
        "## Nodes along each side (cells + 1).",
        "const NODES := %d" % NODES,
        "## Ground elevation (m above sea level) at the scene origin.",
        "const ORIGIN_ELEVATION := %.1f" % origin,
        "## NODES x NODES little-endian int16 elevations in decimetres, row by row,",
        "## north (z = -HALF) first, west (x = -HALF) first within a row.",
        "const HEIGHTS_B64 := \"%s\"" % base64.b64encode(dm.tobytes()).decode(),
    ]
    with open(OUT_WORLD, "w") as f:
        f.write("\n".join(lines) + "\n")


def naip_mosaic(cache):
    """The whole square as 1 m (R, G, B) uint8 arrays: rows run north to south, columns west to east,
    so pixel (row, col) is scene (x = col - HALF, z = row - HALF)."""
    size = NAIP_TILES * NAIP_TILE_PX
    mosaic = np.zeros((size, size, 3), dtype=np.uint8)

    def one(ij):
        i, j = ij  # tile column, tile row
        x0, z0 = -HALF + i * NAIP_TILE_PX, -HALF + j * NAIP_TILE_PX
        bb = (LON0 + x0 / M_PER_DEG_LON, LAT0 - (z0 + NAIP_TILE_PX) / M_PER_DEG_LAT,
              LON0 + (x0 + NAIP_TILE_PX) / M_PER_DEG_LON, LAT0 - z0 / M_PER_DEG_LAT)
        url = NAIP_URL.format(*bb, NAIP_TILE_PX, NAIP_TILE_PX).replace("compressionQuality=85", "compressionQuality=92")
        path = os.path.join(cache, "naip_%d_%d.jpg" % (i, j)) if cache else None
        data = fetch(url, path)
        return i, j, np.array(Image.open(io.BytesIO(data)).convert("RGB"))

    jobs = [(i, j) for j in range(NAIP_TILES) for i in range(NAIP_TILES)]
    with concurrent.futures.ThreadPoolExecutor(4) as pool:
        for i, j, a in pool.map(one, jobs):
            mosaic[j * NAIP_TILE_PX:(j + 1) * NAIP_TILE_PX, i * NAIP_TILE_PX:(i + 1) * NAIP_TILE_PX] = a
    return mosaic


def resample_part(part, spacing=ROAD_SPACING):
    """`part` (scene metres) resampled to a point every `spacing` m along the line, ends kept."""
    out = [part[0]]
    carry = 0.0
    for a, b in zip(part, part[1:]):
        seg = math.dist(a, b)
        if seg < 1e-6:
            continue
        at = spacing - carry
        while at < seg:
            t = at / seg
            out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
            at += spacing
        carry = seg - (at - spacing)
    if math.dist(out[-1], part[-1]) > 1e-3:
        out.append(part[-1])
    return out


# A point of road is paved when the photo shows a grey ribbon on it: a 3 px strip,
# found within +-SEARCH m across the road (TIGER's centreline is a few metres off),
# whose colour is nearly neutral (saturation under PAVED_SAT) and not pale
# (luminance under PAVED_LUM, so a light-grey gravel road doesn't count). The
# land beside it is green or tan, so the neutral ribbon stands out. Anything else
# is gravel or dirt: a gravel road is a pale tan strip about as coloured as the
# fields, which isn't reliably separable from them, but a road with no ribbon at
# all is far more likely to be unsurfaced than paved. The U.S. highways (kinds 0
# and 1) are always paved: the TIGER lines for them sit tens of metres off the
# real road in places, so the photo can't be checked there.
SEARCH = 8
PAVED_SAT = 0.10
PAVED_LUM = 150.0
SMOOTH = 7


def photo_planes(mosaic):
    """Luminance and saturation (0..1) of the mosaic as float16, built band by band."""
    lum = np.zeros(mosaic.shape[:2], dtype=np.float16)
    sat = np.zeros(mosaic.shape[:2], dtype=np.float16)
    for r in range(0, mosaic.shape[0], 1000):
        band = mosaic[r:r + 1000].astype(np.float32)
        lum[r:r + 1000] = 0.299 * band[..., 0] + 0.587 * band[..., 1] + 0.114 * band[..., 2]
        sat[r:r + 1000] = (band.max(-1) - band.min(-1)) / np.maximum(band.max(-1), 1.0)
    return lum, sat


def paved_points(lum, sat, pts):
    """True for each point of the resampled road `pts` that has a grey ribbon on it."""
    n = len(pts)
    out = []
    for k in range(n):
        a, b = pts[max(k - 2, 0)], pts[min(k + 2, n - 1)]
        t = np.array([b[0] - a[0], b[1] - a[1]])
        norm = np.linalg.norm(t)
        t = t / norm if norm > 1e-6 else np.array([1.0, 0.0])
        right = np.array([-t[1], t[0]])
        c = np.array(pts[k])
        best = None
        for shift in range(-SEARCH, SEARCH + 1):
            ss, ls = [], []
            for al in (-4, 0, 4):
                for d in (-1, 0, 1):
                    p = c + right * (shift + d) + t * al
                    col, row = int(round(p[0] + HALF)), int(round(p[1] + HALF))
                    if 0 <= row < sat.shape[0] and 0 <= col < sat.shape[1]:
                        ss.append(float(sat[row, col]))
                        ls.append(float(lum[row, col]))
            if ss and (best is None or np.mean(ss) < best[0]):
                best = (np.mean(ss), np.mean(ls))
        out.append(best is not None and best[0] < PAVED_SAT and best[1] < PAVED_LUM)
    return out


def majority(flags, window=SMOOTH):
    """`flags` with each value replaced by the majority in a window around it, so a driveway or a
    shadow doesn't flip a road's surface for one point."""
    n, half = len(flags), window // 2
    return [sum(flags[max(i - half, 0):i + half + 1]) * 2 > len(flags[max(i - half, 0):i + half + 1]) for i in range(n)]


def classify_surfaces(rs, mosaic):
    """`rs` with each road resampled to ROAD_SPACING and given a surface per point:
    [(name, kind, points, surfaces)], surfaces being SURFACE_PAVED or SURFACE_GRAVEL."""
    lum, sat = photo_planes(mosaic)
    out = []
    for name, kind, part in rs:
        pts = resample_part(part)
        if kind <= 1:
            paved = [True] * len(pts)
        else:
            paved = majority(paved_points(lum, sat, pts))
        out.append((name, kind, pts, [SURFACE_PAVED if p else SURFACE_GRAVEL for p in paved]))
    return out


def write_roads(rs):
    names = sorted({r[0] for r in rs})
    pts = []
    surfaces = []
    rows = []
    for name, kind, part, surface in rs:
        rows.append("\t[%d, %d, %s, %d, %d]," % (names.index(name), kind, WIDTHS[kind], len(pts) // 2, len(part)))
        for x, z in part:
            pts.extend((x, z))
        surfaces.extend(surface)
    blob = base64.b64encode(np.array(pts, dtype="<f4").tobytes()).decode()
    lines = [
        "## Generated by tools/build_world_data.py (D-148, D-150). Do not edit by hand.",
        "## The named roads within the world square, from Census TIGERweb (US",
        "## Government, public domain): highways and local roads that have a name,",
        "## resampled to a point every %d m, with each point's surface read off the" % ROAD_SPACING,
        "## NAIP aerial photo.",
        "",
        "## Road names, indexed by a road's first field.",
        "const NAMES := [%s]" % ", ".join(json.dumps(n) for n in names),
        "## One polyline per row: NAMES index, kind (0 primary highway, 1 secondary",
        "## highway, 2 local road), width of asphalt (m), index of its first point, point count.",
        "const ROADS := [",
    ] + rows + [
        "]",
        "## Little-endian float32 (x east, z south) scene metres, all roads' points in order.",
        "const POINTS_B64 := \"%s\"" % blob,
        "## One byte per point, in the same order: 0 asphalt, 1 gravel.",
        "const SURFACE_B64 := \"%s\"" % base64.b64encode(bytes(surfaces)).decode(),
    ]
    with open(OUT_ROADS, "w") as f:
        f.write("\n".join(lines) + "\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cache", help="directory to keep the downloads in (reused if present)")
    args = ap.parse_args()
    if args.cache:
        os.makedirs(args.cache, exist_ok=True)
    c = (lambda n: os.path.join(args.cache, n)) if args.cache else (lambda n: None)

    tif = c("dem.tif")
    if tif is None:
        tif = os.path.join(os.environ.get("TMPDIR", "/tmp"), "world_dem.tif")
    fetch(DEM_URL.format(*BBOX, DEM_PX, DEM_PX), tif)
    grid, origin = dem_grid(tif)
    rs = roads(args.cache)
    grid, deepest, touched = carve_roads(grid, rs)
    write_world(grid, origin)
    classified = classify_surfaces(rs, naip_mosaic(args.cache))
    write_roads(classified)

    os.makedirs(os.path.dirname(OUT_NAIP), exist_ok=True)
    naip = fetch(NAIP_URL.format(*BBOX, NAIP_PX, NAIP_PX), c("naip.jpg"))
    with open(OUT_NAIP, "wb") as f:
        f.write(naip)

    km = sum(math.dist(p[i], p[i + 1]) for _, _, p in rs for i in range(len(p) - 1)) / 1000
    gravel_km = sum(ROAD_SPACING * sum(sf) for _, _, _, sf in classified) / 1000
    print("origin %.1f m, relief %.0f..%.0f m; %d roads (%d names), %.1f km; road beds touch %d nodes, "
          "deepest cut or fill %.1f m; %.0f km of the roads read as gravel; imagery %d KB"
          % (origin, grid.min(), grid.max(), len(rs), len({r[0] for r in rs}), km, touched, deepest, gravel_km, len(naip) // 1024))


if __name__ == "__main__":
    main()
