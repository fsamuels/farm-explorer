"""Trace fence lines off the front-section orthomosaic into scene-local meters.

The pixel<->world mapping is read straight from the `FrontSectionOrthomosaic`
node's own PlaneMesh size and Transform3D in main.tscn, so a traced point lands
exactly on the white line the player sees on the ground in-engine (D-71). Do not
re-derive it from building positions (D-61/D-68) -- that adds metres of error.

Usage (requires Pillow + numpy):
    from ortho_fence_trace import *
    pts = detect((650, 3135), (1620, 2440))   # rough pixel endpoints of one fence side
    line = fitline(pts)                       # (center, direction, residuals, n)
    corner = inter(line_a, line_b)            # pixel corner where two sides meet
    px2w(*corner)                             # -> (x, z) scene meters for a Curve3D point
"""
import re
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent / "project"
IMAGE = ROOT / "textures/ground/orthomosaic-front-section.png"


def _plane():
    s = (ROOT / "scenes/main.tscn").read_text()
    size = re.search(r'id="PlaneMesh_front_section"\]\nsize = Vector2\(([^)]*)\)', s).group(1)
    xf = re.search(r'name="FrontSectionOrthomosaic".*?\ntransform = Transform3D\(([^)]*)\)', s, re.S).group(1)
    sw, sh = (float(v) for v in size.split(","))
    t = [float(v) for v in xf.split(",")]
    # Godot's text Transform3D stores the basis row-major (D-21).
    return sw, sh, np.array(t[:9]).reshape(3, 3), np.array(t[9:])


SW, SH, BASIS, ORIGIN = _plane()
W, H = Image.open(IMAGE).size


def px2w(u, v):
    """Image pixel -> scene (x, z) meters."""
    w = BASIS @ np.array([(u / W - 0.5) * SW, 0.0, (v / H - 0.5) * SH]) + ORIGIN
    return float(w[0]), float(w[2])


def w2px(x, z):
    """Scene (x, z) meters -> image pixel."""
    loc = np.linalg.solve(BASIS, np.array([x, ORIGIN[1], z]) - ORIGIN)
    return float((loc[0] / SW + 0.5) * W), float((loc[2] / SH + 0.5) * H)


_score = None


def score():
    """Per-pixel 'looks like a white/grey fence rail' weight in [0, 1]."""
    global _score
    if _score is None:
        im = np.asarray(Image.open(IMAGE).convert("RGB")).astype(float)
        mx, mn = im.max(2), im.min(2)
        sat = (mx - mn) / (mx + 1)
        _score = np.clip((mx - 110) / 80, 0, 1) * np.clip((0.25 - sat) / 0.15, 0, 1)
    return _score


def detect(p, q, half=22, step=6, band=2):
    """Sample along the rough segment p->q and return the brightest-line pixel at each step."""
    sc = score()
    p, q = np.array(p, float), np.array(q, float)
    length = np.linalg.norm(q - p)
    t = (q - p) / length
    n = np.array([-t[1], t[0]])
    offs = np.arange(-half, half + 1)
    pts = []
    for s in np.arange(10, length - 10, step):
        c = p + t * s
        vals = [sum(sc[int(round(y)), int(round(x))] for b in range(-band, band + 1)
                    for x, y in [c + n * o + t * b]) for o in offs]
        vals = np.convolve(vals, [1, 2, 1], "same")
        k = int(np.argmax(vals))
        if vals[k] > 1.5:
            pts.append(c + n * offs[k])
    return np.array(pts)


def fitline(pts):
    """Total-least-squares line fit with one outlier-rejection pass."""
    def fit(p):
        c = p.mean(0)
        d = np.linalg.svd(p - c)[2][0]
        return c, d, (p - c) @ np.array([-d[1], d[0]])
    c, d, r = fit(pts)
    pts = pts[np.abs(r) < max(3, 2.5 * np.std(r))]
    c, d, r = fit(pts)
    return c, d, r, len(pts)


def inter(l1, l2):
    """Intersection of two fitted lines (pixel space)."""
    (c1, d1), (c2, d2) = l1[:2], l2[:2]
    ts = np.linalg.solve(np.array([d1, -d2]).T, c2 - c1)
    return c1 + d1 * ts[0]
