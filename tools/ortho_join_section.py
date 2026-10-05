"""Join a newly stitched ODM orthophoto onto the front-section orthomosaic (D-83).

Takes a second flight's `odm_orthophoto.tif` and makes it sit next to the
front-section patch as if it were shot in the same pass:

1. Register -- GPS drift between flights leaves the two orthos a few metres apart,
   and not by a constant amount. The offset is measured in windows across the
   overlap and fitted as a smooth field: exact near the seam, fading to a plain
   shift further out, where there is no front imagery to say otherwise.
2. Match light -- per-channel tone curve fitted on overlap surfaces that do not
   change with the season (roofing, concrete, gravel, bare dirt), so a dusk flight
   is lifted to the front section's exposure and white balance while grass and
   leaves keep whatever colour they really were that day.
3. Feather -- the new patch fades out over the first few metres *inside* the front
   section's coverage, so it must be drawn above the front patch.

The front ortho is the fixed reference: it is never resampled or recoloured, so
everything already traced off it (D-71) stays valid. The output grid is UTM-aligned
like the front one, so the new node reuses the front node's basis unchanged.

Usage (requires Pillow + numpy; takes a couple of minutes):
    python3 tools/ortho_join_section.py odm-middle-section orthomosaic-middle-section.png
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

Image.MAX_IMAGE_PIXELS = None
REPO = Path(__file__).resolve().parent.parent
SRC = REPO / "assets/drone-source"
sys.path.insert(0, str(Path(__file__).resolve().parent))
import ortho_fence_trace as front  # noqa: E402  (the front node's plane size / transform)

PX = 0.05          # output metres per pixel, same as the front ortho
FADE_M = 80.0      # distance west of the overlap over which the local correction fades out
FEATHER_M = 6.0    # width of the cross-fade inside the front section's coverage


def load(project):
    d = SRC / project / "odm_orthophoto"
    tfw = [float(v) for v in (d / "odm_orthophoto.tfw").read_text().split()]
    return np.asarray(Image.open(d / "odm_orthophoto.tif")), tfw


def utm2scene(e, n, tf):
    """UTM -> scene (x, z), by way of the front ortho's pixel grid and its node transform."""
    lx = (((e - tf[4]) / tf[0] + 0.5) / front.W - 0.5) * front.SW
    lz = (((n - tf[5]) / tf[3] + 0.5) / front.H - 0.5) * front.SH
    b, o = front.BASIS, front.ORIGIN
    return b[0, 0] * lx + b[0, 2] * lz + o[0], b[2, 0] * lx + b[2, 2] * lz + o[2]


def blocks(a, k):
    """k x k block means of RGB, plus a mask of blocks that are fully covered."""
    h, w = a.shape[0] // k * k, a.shape[1] // k * k
    rgb = a[:h, :w, :3].astype(np.float32).reshape(h // k, k, w // k, k, 3).mean((1, 3))
    return rgb, (a[:h, :w, 3] == 255).reshape(h // k, k, w // k, k).all((1, 3))


def onto_grid(a, tf, e, n):
    """Nearest-neighbour resample of ortho `a` onto the pixel centres e (cols) x n (rows)."""
    x, y = np.round((e - tf[4]) / tf[0]).astype(int), np.round((n - tf[5]) / tf[3]).astype(int)
    kx, ky = (x >= 0) & (x < a.shape[1]), (y >= 0) & (y < a.shape[0])
    out = np.zeros((len(n), len(e), 4), np.uint8)
    out[np.ix_(ky, kx)] = a[np.ix_(y[ky], x[kx])]
    return out


def edges(lum, mask):
    z = np.where(mask, lum, lum[mask].mean())
    for _ in range(2):
        for ax in (0, 1):
            z = (np.roll(z, 1, ax) + 2 * z + np.roll(z, -1, ax)) / 4
    gy, gx = np.gradient(z)
    return np.where(mask, np.hypot(gx, gy), np.nan)


def measure_offsets(new, tn, ref, tr, k=3, win_m=24.0, search_m=6.6):
    """Per-window shift (m, UTM) that moves `new` onto `ref`, by edge-map correlation."""
    g = PX * k
    nb, nm = blocks(new, k)
    e = tn[4] + (np.arange(nb.shape[1]) * k + (k - 1) / 2) * tn[0]
    n = tn[5] + (np.arange(nb.shape[0]) * k + (k - 1) / 2) * tn[3]
    rb, rm = blocks(onto_grid(ref, tr, e, n), 1)
    a, b = edges(nb.mean(2), nm), edges(rb.mean(2), rm)
    ys, xs = np.nonzero(nm & rm)
    t, r, rows = int(win_m / g), int(search_m / g), []
    for ya in range(ys.min(), ys.max() - t, t // 2):
        for xa in range(xs.min(), xs.max() - t, t // 2):
            wa = a[ya:ya + t, xa:xa + t]
            if np.isnan(wa).mean() > 0.1:
                continue
            ncc = np.full((2 * r + 1, 2 * r + 1), -1.0)
            for dy in range(-r, r + 1):
                for dx in range(-r, r + 1):
                    if ya + dy < 0 or xa + dx < 0:
                        continue
                    wb = b[ya + dy:ya + t + dy, xa + dx:xa + t + dx]
                    if wb.shape != wa.shape:
                        continue
                    m = ~np.isnan(wa) & ~np.isnan(wb)
                    if m.sum() < 0.8 * wa.size:
                        continue
                    u, v = wa[m] - wa[m].mean(), wb[m] - wb[m].mean()
                    ncc[dy + r, dx + r] = (u * v).sum() / np.sqrt((u * u).sum() * (v * v).sum() + 1e-9)
            iy, ix = np.unravel_index(ncc.argmax(), ncc.shape)
            pk = ncc[iy, ix]
            if not (0 < iy < 2 * r and 0 < ix < 2 * r):
                continue
            sy = (ncc[iy - 1, ix] - ncc[iy + 1, ix]) / (2 * (ncc[iy - 1, ix] - 2 * pk + ncc[iy + 1, ix]) - 1e-12)
            sx = (ncc[iy, ix - 1] - ncc[iy, ix + 1]) / (2 * (ncc[iy, ix - 1] - 2 * pk + ncc[iy, ix + 1]) - 1e-12)
            # A long fence or track only pins the shift across itself; `spread` flags those.
            spread = np.abs(np.argwhere(ncc > 0.8 * pk) - [iy, ix]).max() * g
            rows.append((e[xa + t // 2], n[ya + t // 2], (ix - r + sx) * g, -(iy - r + sy) * g, pk, spread))
    return np.array(rows)


def fit_field(rows):
    """Robust affine fit of the offsets: d = c0 + c1*(E-E0) + c2*(N-N0) for each of dE, dN."""
    e, n, de, dn, pk, spread = rows.T
    e0, n0 = e.mean(), n.mean()
    x = np.c_[np.ones(len(e)), e - e0, n - n0]
    w = pk * (spread < 2.5)
    keep = w > 0
    for _ in range(6):
        sw = np.sqrt(w * keep)[:, None]
        ce = np.linalg.lstsq(x * sw, de * sw[:, 0], rcond=None)[0]
        cn = np.linalg.lstsq(x * sw, dn * sw[:, 0], rcond=None)[0]
        res = np.hypot(x @ ce - de, x @ cn - dn)
        keep = (w > 0) & (res < max(0.6, 2.5 * np.median(res[keep])))
    print(f"registration: {keep.sum()} of {len(e)} windows, shift ({ce[0]:+.2f}, {cn[0]:+.2f}) m E/N, "
          f"residual {np.sqrt((res[keep] ** 2).mean()):.2f} m")
    return e0, n0, ce, cn, e.min()


def warp(new, tn, field):
    """Resample `new` onto a fresh UTM-aligned grid, shifted by the fitted field."""
    e0, n0, ce, cn, e_overlap = field

    def shift(e, n):
        w = np.clip((e - (e_overlap - FADE_M)) / FADE_M, 0, 1)
        w = w * w * (3 - 2 * w)
        return (ce[0] + w * (ce[1] * (e - e0) + ce[2] * (n - n0)),
                cn[0] + w * (cn[1] * (e - e0) + cn[2] * (n - n0)))

    h, w_ = new.shape[:2]
    emin = tn[4] - 0.5 * tn[0] + ce[0] - 3
    nmax = tn[5] - 0.5 * tn[3] + cn[0] + 3
    ow = int(round((w_ * tn[0] + 6) / PX))
    oh = int(round((h * -tn[3] + 6) / PX))
    out, src = np.zeros((oh, ow, 4), np.uint8), new.astype(np.float32)
    for r0 in range(0, oh, 256):
        rr = np.arange(r0, min(oh, r0 + 256))
        e, n = np.meshgrid(emin + (np.arange(ow) + 0.5) * PX, nmax - (rr + 0.5) * PX)
        de, dn = shift(e, n)
        de, dn = shift(e - de, n - dn)
        x, y = (e - de - tn[4]) / tn[0], (n - dn - tn[5]) / tn[3]
        x0, y0 = np.floor(x).astype(int), np.floor(y).astype(int)
        fx, fy = (x - x0)[..., None].astype(np.float32), (y - y0)[..., None].astype(np.float32)
        ok = (x0 >= 0) & (x0 < w_ - 1) & (y0 >= 0) & (y0 < h - 1)
        x0, y0 = np.clip(x0, 0, w_ - 2), np.clip(y0, 0, h - 2)
        p = ((src[y0, x0] * (1 - fx) + src[y0, x0 + 1] * fx) * (1 - fy)
             + (src[y0 + 1, x0] * (1 - fx) + src[y0 + 1, x0 + 1] * fx) * fy)
        solid = np.minimum(np.minimum(new[y0, x0, 3], new[y0, x0 + 1, 3]),
                           np.minimum(new[y0 + 1, x0, 3], new[y0 + 1, x0 + 1, 3])) == 255
        p[..., 3] = np.where(ok & solid, 255, 0)
        out[rr] = np.round(p).astype(np.uint8)
    return out, emin, nmax


def match_light(new, ref, k=4):
    """Fit and apply a per-channel tone curve from season-invariant overlap surfaces."""
    nb, nm = blocks(new, k)
    rb, rm = blocks(ref, k)
    m, f = nb[nm & rm], rb[nm & rm]
    sat = (f.max(1) - f.min(1)) / (f.max(1) + 1)
    msat = (m.max(1) - m.min(1)) / (m.max(1) + 1)
    green = (f[:, 1] > f[:, 0] * 1.04) & (f[:, 1] > f[:, 2] * 1.04)
    earth = (f[:, 0] > f[:, 1] * 1.03) & (f[:, 1] > f[:, 2] * 1.03)
    sel = ((sat < 0.13) | earth) & ~green & (msat < 0.3)
    # Quantile-to-quantile over the range the reference surfaces actually span. Below
    # it the curve runs straight to the origin (a plain exposure gain -- extrapolating
    # the fitted shape instead lifts shadows into a haze); above it the last slope holds.
    q = np.linspace(5, 99.5, 24)
    out = new.copy()
    for c in range(3):
        x, y = np.percentile(m[sel][:, c], q), np.percentile(f[sel][:, c], q)
        top = (y[-1] - y[-4]) / (x[-1] - x[-4])
        lut = np.interp(np.arange(256), np.r_[0, x, 255], np.r_[0, y, y[-1] + top * (255 - x[-1])])
        print(f"light match {'RGB'[c]}: x{y[0] / x[0]:.2f} in shadow, x{y[12] / x[12]:.2f} midtone, "
              f"x{y[-1] / x[-1]:.2f} highlight ({sel.sum()} reference cells)")
        out[..., c] = np.clip(np.round(lut), 0, 255).astype(np.uint8)[new[..., c]]
    return out


def feather(new, ref, k=8):
    """Fade `new` out over FEATHER_M inside `ref`'s coverage; fully opaque everywhere else."""
    h, w = new.shape[0] // k * k, new.shape[1] // k * k
    cover = (ref[:h, :w, 3] == 255).reshape(h // k, k, w // k, k).mean((1, 3))
    r = int(round(FEATHER_M / (PX * k)))
    for ax in (0, 1):  # box blur: 0.5 on the coverage edge, 1 once FEATHER_M inside it
        c = np.cumsum(np.pad(cover, [(r + 1, r) if a == ax else (0, 0) for a in (0, 1)], mode="edge"), ax)
        cover = (np.take(c, np.arange(2 * r + 1, c.shape[ax]), ax) - np.take(c, np.arange(0, c.shape[ax] - 2 * r - 1), ax)) / (2 * r + 1)
    fade = np.clip(2 - 2 * cover, 0, 1)
    fade = fade * fade * (3 - 2 * fade)
    big = np.asarray(Image.fromarray((fade * 255).astype(np.uint8)).resize((new.shape[1], new.shape[0]), Image.BILINEAR))
    out = new.copy()
    out[..., 3] = (new[..., 3].astype(np.uint16) * big // 255).astype(np.uint8)
    return out


def main(project, out_name):
    new, tn = load(project)
    ref, tr = load("odm-project")
    field = fit_field(measure_offsets(new, tn, ref, tr))
    img, emin, nmax = warp(new, tn, field)
    e = emin + (np.arange(img.shape[1]) + 0.5) * PX
    n = nmax - (np.arange(img.shape[0]) + 0.5) * PX
    ref_on = onto_grid(ref, tr, e, n)
    img = feather(match_light(img, ref_on), ref_on)
    ys, xs = np.nonzero(img[..., 3])
    img = img[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    emin, nmax = emin + xs.min() * PX, nmax - ys.min() * PX
    h, w = img.shape[:2]
    Image.fromarray(img).save(REPO / "project/textures/ground" / out_name, optimize=True)
    cx, cz = utm2scene(emin + w * PX / 2, nmax - h * PX / 2, tr)
    sw = w * PX * front.SW / (front.W * tr[0])
    sh = h * PX * front.SH / (front.H * -tr[3])
    print(f"{out_name}: {w}x{h} px")
    print(f"PlaneMesh size = Vector2({sw:.4f}, {sh:.4f})")
    print(f"node origin = ({cx:.2f}, <y above the front patch>, {cz:.2f}), basis = FrontSectionOrthomosaic's")


if __name__ == "__main__":
    main(*sys.argv[1:3])
