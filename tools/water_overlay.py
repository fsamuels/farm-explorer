"""Draw the traced ditch/pond (docs/gis/water-features-*.json) over the imagery for review.

Composites the NAIP base and both drone orthomosaics at the exact transforms in
main.tscn (same pixel<->world convention as ortho_fence_trace.py), then draws the
traced geometry with numbered vertices so corrections can be given by id.

Usage (requires Pillow + numpy):
    python3 tools/water_overlay.py [out_dir]
Writes overview.png and pond.png, ditch_east.png, ditch_south.png to out_dir (default: cwd).
"""
import json
import math
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

Image.MAX_IMAGE_PIXELS = None
ROOT = Path(__file__).resolve().parent.parent
SCENE = (ROOT / "project/scenes/main.tscn").read_text()
TEX = ROOT / "project/textures/ground"
DATA = ROOT / "docs/gis/water-features-340732310005.json"
PARCEL = ROOT / "docs/gis/parcel-340732310005.geojson"


def plane(node, mesh):
    size = re.search(r'id="%s"\]\nsize = Vector2\(([^)]*)\)' % mesh, SCENE).group(1)
    xf = re.search(r'name="%s".*?\ntransform = Transform3D\(([^)]*)\)' % node, SCENE, re.S).group(1)
    sw, sh = (float(v) for v in size.split(","))
    t = [float(v) for v in xf.split(",")]
    return sw, sh, np.array(t[:9]).reshape(3, 3), np.array(t[9:])


def layer(path, sw, sh, basis, origin, box, res):
    x0, z0, x1, z1 = box
    im = Image.open(path).convert("RGBA")
    W, H = im.size
    bi = np.linalg.inv(np.array([[basis[0, 0], basis[0, 2]], [basis[2, 0], basis[2, 2]]]))
    o2 = np.array([origin[0], origin[2]])

    def uv(i, j):
        loc = bi @ (np.array([x0 + i * res, z0 + j * res]) - o2)
        return (loc[0] / sw + .5) * W, (loc[1] / sh + .5) * H

    a, b, c = uv(0, 0), uv(1, 0), uv(0, 1)
    coef = (b[0] - a[0], c[0] - a[0], a[0], b[1] - a[1], c[1] - a[1], a[1])
    return im.transform((int((x1 - x0) / res), int((z1 - z0) / res)), Image.AFFINE, coef, Image.BILINEAR)


def base(box, res):
    x0, z0, x1, z1 = box
    out = Image.new("RGBA", (int((x1 - x0) / res), int((z1 - z0) / res)), (0, 0, 0, 255))
    out.alpha_composite(layer(TEX / "naip-340732310005.png", 520, 520, np.eye(3),
                              np.array([49.4, 0, -33.7]), box, res))
    for node, mesh, f in [("FrontSectionOrthomosaic", "PlaneMesh_front_section", "orthomosaic-front-section"),
                          ("MiddleSectionOrthomosaic", "PlaneMesh_middle_section", "orthomosaic-middle-section")]:
        sw, sh, b, o = plane(node, mesh)
        out.alpha_composite(layer(TEX / (f + ".png"), sw, sh, b, o, box, res))
    return out


def parcel_ring():
    ring = json.loads(PARCEL.read_text())["features"][0]["geometry"]["coordinates"][0]
    cx, cy = -118.58959936153114, 46.03902780511042
    k = math.radians(1) * 6371000
    return [((lo - cx) * k * math.cos(math.radians(cy)), -(la - cy) * k) for lo, la in ring]


def pond_sdf(spine, box, res, size):
    """Signed distance (m, negative inside) to the pond outline on the image's pixel grid.

    The pond is a union of tapered circles along its spine, the same shape
    project/scripts/terrain_math.gd cuts into the ground.
    """
    x0, z0 = box[0], box[1]
    xs = x0 + (np.arange(size[0]) + 0.5) * res
    zs = z0 + (np.arange(size[1]) + 0.5) * res
    X, Z = np.meshgrid(xs, zs)
    best = np.full(X.shape, np.inf)
    for a, b in zip(spine, spine[1:]):
        dx, dz = b[0] - a[0], b[1] - a[1]
        t = np.clip(((X - a[0]) * dx + (Z - a[1]) * dz) / (dx * dx + dz * dz), 0, 1)
        d = np.hypot(X - (a[0] + t * dx), Z - (a[1] + t * dz)) - (a[2] + (b[2] - a[2]) * t)
        best = np.minimum(best, d)
    return best


def render(box, res, out, grid=10):
    d = json.loads(DATA.read_text())
    img = base(box, res)
    sdf = pond_sdf(d["pond"]["spine_x_z_halfwidth_m"], box, res, img.size)
    layer_px = np.zeros((img.size[1], img.size[0], 4), np.uint8)
    layer_px[sdf < 0] = (40, 120, 255, 40)
    layer_px[np.abs(sdf) < max(res, 0.12)] = (40, 120, 255, 255)
    img.alpha_composite(Image.fromarray(layer_px, "RGBA"))
    dr = ImageDraw.Draw(img, "RGBA")
    x0, z0, x1, z1 = box
    P = lambda x, z: ((x - x0) / res, (z - z0) / res)
    for g in range(int(math.ceil(x0 / grid) * grid), int(x1), grid):
        dr.line([P(g, z0), P(g, z1)], fill=(255, 255, 0, 70)); dr.text((P(g, z0)[0] + 2, 2), str(g), fill=(255, 255, 0, 255))
    for g in range(int(math.ceil(z0 / grid) * grid), int(z1), grid):
        dr.line([P(x0, g), P(x1, g)], fill=(0, 255, 255, 70)); dr.text((2, P(x0, g)[1] + 2), str(g), fill=(0, 255, 255, 255))
    dr.line([P(*q) for q in parcel_ring()], fill=(255, 40, 40, 255), width=2)
    for i, s in enumerate(d["pond"]["spine_x_z_halfwidth_m"]):
        c = P(s[0], s[1]); dr.ellipse([c[0] - 3, c[1] - 3, c[0] + 3, c[1] + 3], fill=(255, 255, 255, 255))
        dr.text((c[0] + 5, c[1] - 5), "P%d" % i, fill=(255, 255, 255, 255))
    col = {"high": (0, 255, 120, 255), "medium": (255, 200, 0, 255), "low": (255, 90, 0, 255)}
    n = 0
    for seg in d["ditch"]["segments"]:
        pts = [P(*q) for q in seg["points"]]
        if seg.get("buried"):
            for a, b in zip(pts, pts[1:]):  # dashed magenta = buried pipe
                L = math.hypot(b[0] - a[0], b[1] - a[1]); k = max(int(L / 8), 1)
                for j in range(0, k, 2):
                    dr.line([(a[0] + (b[0] - a[0]) * j / k, a[1] + (b[1] - a[1]) * j / k),
                             (a[0] + (b[0] - a[0]) * min(j + 1, k) / k, a[1] + (b[1] - a[1]) * min(j + 1, k) / k)],
                            fill=(255, 0, 255, 255), width=3)
        else:
            band = max(3, int(d["ditch"]["width_m"] / res))   # the carved top-of-bank width
            dr.line(pts, fill=col[seg["confidence"]][:3] + (60,), width=band)
            dr.line(pts, fill=col[seg["confidence"]], width=3)
        for q in pts:
            dr.ellipse([q[0] - 3, q[1] - 3, q[0] + 3, q[1] + 3], outline=(255, 255, 255, 255))
            dr.text((q[0] + 5, q[1] - 5), "D%d" % n, fill=(255, 255, 255, 255)); n += 1
    w = P(*d["weir"]["pos"]); dr.rectangle([w[0] - 5, w[1] - 5, w[0] + 5, w[1] + 5], outline=(255, 0, 255, 255), width=2)
    dr.text((w[0] + 8, w[1] - 5), "WEIR", fill=(255, 0, 255, 255))
    img.convert("RGB").save(out)
    return img.size


if __name__ == "__main__":
    out = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    out.mkdir(parents=True, exist_ok=True)
    render((-70, -100, 275, 85), 0.25, out / "overview.png", 20)
    render((-70, -20, 145, 55), 0.1, out / "pond.png", 10)
    render((225, -95, 270, 75), 0.1, out / "ditch_east.png", 10)
    render((30, 40, 270, 80), 0.15, out / "ditch_south.png", 10)
    print("wrote overlays to", out)
