"""Generate the tileable blue corrugated-metal albedo + normal map used by the
Shop walls (project/textures/buildings/corrugated_blue*.png).

Ribs run vertically; one 256 px tile is 8 ribs. Run from the repo root:
    python3 tools/make_corrugated_texture.py
"""
import numpy as np
from PIL import Image

N, RIBS = 256, 8
rng = np.random.default_rng(7)
x = (np.arange(N) / N * RIBS) % 1.0  # 0..1 across one rib
# Trapezoid rib profile: raised crown, flat valley, sloped flanks.
profile = np.clip(np.abs(x - 0.5) * 4.0 - 0.25, 0.0, 1.0)  # 0 crown .. 1 valley
height = 1.0 - profile
row = height[None, :].repeat(N, 0)

# Slope -> normal (x only, ribs are vertical).
dx = np.gradient(row, axis=1) * N / RIBS
nx, nz = -dx * 0.35, np.ones_like(dx)
ln = np.sqrt(nx**2 + nz**2)
normal = np.stack([nx / ln, np.zeros_like(nx), nz / ln], -1)
Image.fromarray(((normal * 0.5 + 0.5) * 255).astype(np.uint8)).save(
    "project/textures/buildings/corrugated_blue_normal.png")

# Albedo: base blue, lighter crowns / darker valleys, vertical weathering
# streaks and a little grain. All periodic in both axes so it tiles.
base = np.array([0.42, 0.54, 0.68])
shade = 0.82 + 0.28 * row
streak = rng.normal(0, 1, N)
streak = np.convolve(np.r_[streak[-8:], streak, streak[:8]], np.ones(9) / 9, "same")[8:-8]
shade = shade * (1.0 + 0.07 * streak[None, :])
grime = np.linspace(0.0, 1.0, N)[:, None] ** 3  # darker toward the bottom edge
shade = shade * (1.0 - 0.06 * grime)
grain = rng.normal(0, 0.012, (N, N))
img = np.clip(base[None, None, :] * (shade + grain)[..., None], 0, 1)
Image.fromarray((img * 255).astype(np.uint8)).save(
    "project/textures/buildings/corrugated_blue.png")
