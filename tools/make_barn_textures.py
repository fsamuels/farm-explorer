"""Generate the tileable Front Barn textures (D-125), all under
project/textures/buildings/:

  barn_siding_tan.png / barn_siding_tan_normal.png
      Beige vertical T1-11 siding: four 8 in panels (a 0.8 m tile) with a
      routed groove between them, painted-wood grain and speckle.
  barn_post_wood.png
      Weathered tan pole / post lumber with a vertical grain.

Everything is periodic in both axes so it tiles. The blue-grey skirt uses the
Shop's corrugated texture (make_corrugated_texture.py). Run from the repo root:
    python3 tools/make_barn_textures.py
"""
import numpy as np
from PIL import Image

OUT = "project/textures/buildings/"
rng = np.random.default_rng(124)


def smooth_noise(shape, cells_y, cells_x):
    """Periodic value noise: random lattice, cosine-interpolated."""
    h, w = shape
    lat = rng.random((cells_y, cells_x))
    ys = np.arange(h) / h * cells_y
    xs = np.arange(w) / w * cells_x
    y0, x0 = ys.astype(int) % cells_y, xs.astype(int) % cells_x
    y1, x1 = (y0 + 1) % cells_y, (x0 + 1) % cells_x
    fy = (1 - np.cos((ys - np.floor(ys)) * np.pi)) / 2
    fx = (1 - np.cos((xs - np.floor(xs)) * np.pi)) / 2
    a = lat[np.ix_(y0, x0)]
    b = lat[np.ix_(y0, x1)]
    c = lat[np.ix_(y1, x0)]
    d = lat[np.ix_(y1, x1)]
    top = a * (1 - fx)[None, :] + b * fx[None, :]
    bot = c * (1 - fx)[None, :] + d * fx[None, :]
    return top * (1 - fy)[:, None] + bot * fy[:, None]


def save_rgb(arr, name):
    Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8)).save(OUT + name)


# ---- Siding: 4 panels across a 256 px tile (64 px = 8 in). -------------------
N, PANELS = 256, 4
x = np.arange(N)
px = (x % (N // PANELS)).astype(float)  # 0..63 within a panel
# Groove: a 5 px dark channel centred on the panel edge, soft shoulders.
d = np.minimum(px, (N // PANELS) - px)  # distance to the nearest panel edge
groove = np.clip(1.0 - d / 3.0, 0.0, 1.0)  # 1 in the channel .. 0
row_groove = groove[None, :].repeat(N, 0)

# Grain: stretched noise (long in y), plus a finer layer; each panel differs.
grain = smooth_noise((N, N), 3, 48) * 0.6 + smooth_noise((N, N), 6, 96) * 0.4
panel_id = (x // (N // PANELS))
panel_shift = rng.normal(0, 0.035, PANELS)[panel_id][None, :]
speckle = rng.normal(0, 0.018, (N, N))
weather = smooth_noise((N, N), 2, 4)  # broad stains
shade = 1.0 + (grain - 0.5) * 0.16 + panel_shift + speckle + (weather - 0.5) * 0.08
shade = shade * (1.0 - 0.55 * row_groove)
base = np.array([0.80, 0.70, 0.53])  # the photo's warm beige paint
save_rgb(base[None, None, :] * shade[..., None], "barn_siding_tan.png")

# Normal map: the groove is a channel, so the normal tilts away from its
# centre (x only, the grooves run vertically).
height = 1.0 - row_groove
dx = np.gradient(height, axis=1) * 2.0
nx, nz = -dx * 0.6, np.ones_like(dx)
ln = np.sqrt(nx**2 + nz**2)
normal = np.stack([nx / ln, np.zeros_like(nx), nz / ln], -1)
save_rgb(normal * 0.5 + 0.5, "barn_siding_tan_normal.png")

# ---- Post lumber: 128 x 256, long vertical grain, darker checks. -------------
W, H = 128, 256
g = smooth_noise((H, W), 2, 24) * 0.55 + smooth_noise((H, W), 4, 64) * 0.45
checks = (smooth_noise((H, W), 5, 20) > 0.82).astype(float) * 0.25
stain = smooth_noise((H, W), 3, 3)
shade = 0.9 + (g - 0.5) * 0.35 - checks + (stain - 0.5) * 0.15 + rng.normal(0, 0.015, (H, W))
base = np.array([0.66, 0.55, 0.40])  # weathered tan
save_rgb(base[None, None, :] * shade[..., None], "barn_post_wood.png")
print("wrote barn_siding_tan.png, barn_siding_tan_normal.png, barn_post_wood.png")
