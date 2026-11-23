#!/usr/bin/env python3
"""Build project/scripts/horizon_data.gd: the distant terrain and wind turbines
around the farm (D-133).

Two public-domain US Government sources, both fetched headlessly:

* USGS 3DEP elevation (the National Map `3DEPElevation` ImageServer), exported
  as one float32 GeoTIFF over a box ~80 km around the parcel. It is sampled on a
  polar grid centred on the parcel centroid (the scene origin, D-6/D-12): one
  column every BEARING_STEP degrees and RING_COUNT rings whose spacing grows
  with distance, so the near flats get fine rings and the Blue Mountains,
  35-65 km out, coarse ones. Each cell stores a blend of the mean and the
  highest elevation in its footprint, so ridgelines survive the coarse grid.
* The US Wind Turbine Database (USGS / LBNL / ACP, `energy.usgs.gov/api/uswtdb`):
  every turbine within MAX_RADIUS, with its hub height and rotor diameter.

Heights are written as real elevations (decimetres, int16, base64) and turbine
positions as scene metres. Everything game-specific (vertical exaggeration,
flattening near the farm, earth curvature, squeezing it all inside the camera's
far plane) happens at run time in scripts/horizon_math.gd, so this file stays
plain data and can be regenerated without touching the look.

Usage (network needed; numpy and Pillow):
    python3 tools/build_horizon_data.py [--dem cached.tif] [--turbines cached.json]
"""
import argparse
import base64
import json
import math
import os
import sys
import urllib.request

import numpy as np
from PIL import Image

# Parcel 340732310005's area-weighted centroid: the scene origin (D-12).
LON0, LAT0 = -118.58959936, 46.03902781
M_PER_DEG_LAT = 111320.0
M_PER_DEG_LON = 111320.0 * math.cos(math.radians(LAT0))

BEARING_STEP = 0.5          # degrees per column
INNER_RADII = [150.0, 350.0]
RING_START, MAX_RADIUS, GEOMETRIC_RINGS = 500.0, 80000.0, 62
RING_COUNT = len(INNER_RADII) + GEOMETRIC_RINGS

# DEM box: a little over MAX_RADIUS each way.
DEM_BBOX = (-119.68, 45.29, -117.50, 46.79)  # lon_min, lat_min, lon_max, lat_max
DEM_SIZE = (2600, 1700)
DEM_URL = ("https://elevation.nationalmap.gov/arcgis/rest/services/3DEPElevation/ImageServer/exportImage"
           "?bbox={},{},{},{}&bboxSR=4326&imageSR=4326&size={},{}&format=tiff&pixelType=F32"
           "&noDataInterpretation=esriNoDataMatchAny&interpolation=RSP_BilinearInterpolation"
           "&compression=None&f=image")
TURBINE_URL = ("https://energy.usgs.gov/api/uswtdb/v1/turbines?xlong=gte.{}&xlong=lte.{}&ylat=gte.{}&ylat=lte.{}"
               "&select=case_id,p_name,xlong,ylat,t_hh,t_rd")
# Turbines the database lists without a size get a typical 2000s machine.
DEFAULT_HUB, DEFAULT_ROTOR = 65.0, 80.0

OUT = os.path.join(os.path.dirname(__file__), "..", "project", "scripts", "horizon_data.gd")


def ring_radii():
    k = (MAX_RADIUS / RING_START) ** (1.0 / (GEOMETRIC_RINGS - 1))
    return INNER_RADII + [RING_START * k ** i for i in range(GEOMETRIC_RINGS)]


def fetch(url, path):
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


class Dem:
    def __init__(self, tif_path):
        self.a = np.array(Image.open(tif_path), dtype=np.float32)
        self.h, self.w = self.a.shape
        if self.a.max() < 100 or self.a.min() < -100:
            sys.exit("DEM looks wrong (min %.1f, max %.1f)" % (self.a.min(), self.a.max()))

    def at(self, x, z):
        """Elevation (m) at scene metres x (east), z (south), bilinear."""
        lon = LON0 + x / M_PER_DEG_LON
        lat = LAT0 - z / M_PER_DEG_LAT
        x0, y0, x1, y1 = DEM_BBOX
        px = (lon - x0) / (x1 - x0) * self.w - 0.5
        py = (y1 - lat) / (y1 - y0) * self.h - 0.5
        px = min(max(px, 0.0), self.w - 1.001)
        py = min(max(py, 0.0), self.h - 1.001)
        i, j = int(py), int(px)
        fy, fx = py - i, px - j
        a = self.a
        return float(a[i, j] * (1 - fx) * (1 - fy) + a[i, j + 1] * fx * (1 - fy)
                     + a[i + 1, j] * (1 - fx) * fy + a[i + 1, j + 1] * fx * fy)


def polar(bearing_deg, r):
    b = math.radians(bearing_deg)
    return r * math.sin(b), -r * math.cos(b)


def sample_grid(dem, radii):
    cols = int(round(360.0 / BEARING_STEP))
    heights = np.zeros((len(radii), cols), dtype=np.int16)
    for i, r in enumerate(radii):
        r_in = radii[i - 1] if i > 0 else r * 0.7
        r_out = radii[i + 1] if i + 1 < len(radii) else r * 1.1
        depth = 0.5 * (r_out - r_in)
        for j in range(cols):
            b = j * BEARING_STEP
            vals = []
            for db in (-0.35, 0.0, 0.35):
                for dr in (-0.35, 0.0, 0.35):
                    vals.append(dem.at(*polar(b + db * BEARING_STEP, max(r + dr * depth, 1.0))))
            e = 0.5 * (sum(vals) / len(vals) + max(vals))
            heights[i, j] = int(round(e * 10.0))
    return heights


def turbines(data):
    rows = json.loads(data)
    out = []
    for t in rows:
        x = (t["xlong"] - LON0) * M_PER_DEG_LON
        z = -(t["ylat"] - LAT0) * M_PER_DEG_LAT
        if math.hypot(x, z) > MAX_RADIUS - 2000:
            continue
        hub = t.get("t_hh") or DEFAULT_HUB
        rotor = t.get("t_rd") or DEFAULT_ROTOR
        out.append((round(x, 1), round(z, 1), round(float(hub), 1), round(float(rotor), 1), t.get("p_name") or "unknown"))
    out.sort(key=lambda r: (r[4], r[0], r[1]))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dem", help="cache the DEM GeoTIFF here (reused if present)")
    ap.add_argument("--turbines", help="cache the turbine JSON here (reused if present)")
    args = ap.parse_args()

    dem_path = args.dem or "/tmp/horizon_dem.tif"
    fetch(DEM_URL.format(*DEM_BBOX, *DEM_SIZE), dem_path)
    dem = Dem(dem_path)
    radii = ring_radii()
    observer = dem.at(0.0, 0.0)
    heights = sample_grid(dem, radii)

    lat_pad = MAX_RADIUS / M_PER_DEG_LAT
    lon_pad = MAX_RADIUS / M_PER_DEG_LON
    t_data = fetch(TURBINE_URL.format(round(LON0 - lon_pad, 3), round(LON0 + lon_pad, 3),
                                      round(LAT0 - lat_pad, 3), round(LAT0 + lat_pad, 3)), args.turbines)
    tur = turbines(t_data)
    projects = sorted({t[4] for t in tur})

    b64 = base64.b64encode(heights.astype("<i2").tobytes()).decode()
    lines = [
        "## Generated by tools/build_horizon_data.py (D-133). Do not edit by hand.",
        "## Real elevations around the parcel from USGS 3DEP, on a polar grid centred",
        "## on the scene origin, and every turbine in the US Wind Turbine Database",
        "## within %d km. Both sources are US Government, public domain." % int(MAX_RADIUS / 1000),
        "",
        "## Ground elevation (m) at the scene origin.",
        "const OBSERVER_ELEVATION := %.1f" % observer,
        "## Degrees between grid columns; column 0 points north, then clockwise.",
        "const BEARING_STEP := %s" % BEARING_STEP,
        "const COLUMNS := %d" % heights.shape[1],
        "## Ring distances (m) from the origin, near to far.",
        "const RINGS := [%s]" % ", ".join("%.1f" % r for r in radii),
        "## RINGS.size() x COLUMNS little-endian int16 elevations in decimetres,",
        "## ring by ring (ring 0's columns first).",
        "const HEIGHTS_B64 := \"%s\"" % b64,
        "## Wind farm names, indexed by a turbine's last field.",
        "const PROJECTS := [%s]" % ", ".join(json.dumps(p) for p in projects),
        "## One turbine per row: scene x (east), scene z (south), hub height (m),",
        "## rotor diameter (m), PROJECTS index.",
        "const TURBINES := [",
    ]
    for t in tur:
        lines.append("\t[%s, %s, %s, %s, %d]," % (t[0], t[1], t[2], t[3], projects.index(t[4])))
    lines.append("]")
    with open(OUT, "w") as f:
        f.write("\n".join(lines) + "\n")
    print("observer %.1f m, %d rings x %d columns, %d turbines in %d projects -> %s"
          % (observer, len(radii), heights.shape[1], len(tur), len(projects), os.path.normpath(OUT)))


if __name__ == "__main__":
    main()
