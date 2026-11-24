#!/usr/bin/env python3
"""Builds project/models/ranger_xp.glb (D-138) from the Sketchfab download of
"Polaris Ranger Xp 1000 Ff" by Buthull (CC-BY-4.0).

The download is one vertex-coloured mesh of a crew-cab fire/rescue Ranger with a
water-tank unit on the back. This script (numpy only, no Blender):
  * turns the Y-up glTF node transform into plain coordinates, scales to
    SCALE, puts the ground at y=0, centres it between the axles and turns it
    to face -Z (the way vehicle.gd drives);
  * cuts the rear tank unit out (utv_builder.gd builds a dump bed in its place);
  * splits the four wheels into their own meshes "Wheel_Tyres" / "Wheel_Rims"
    (vehicle.gd spins and steers them);
  * recolours it Cub Cadet yellow and black, one flat material per colour.
Built for the download whose two meshes hold 87,526 vertices in total (checked
below); a different export fails loudly, because the axle, wheel and tank-cut
numbers are measured from this exact file.
Usage: python3 tools/build_ranger_model.py <dir with scene.gltf + scene.bin> [out.glb]
"""
import json, struct, sys
import numpy as np

SCALE = 0.9
# Measured in the source file's own (converted) coordinates.
FRONT_AXLE_Z, REAR_AXLE_Z = -9.03, -11.75
WHEEL_Y, WHEEL_R, WHEEL_MIN_X = -1.229, 0.40, 0.6
TANK_CUT_Z, TANK_MIN_Y = -10.9, -1.15   # rear unit: behind the cab, above the frame

YELLOW = (0.98, 0.78, 0.04)
BLACK = (0.07, 0.07, 0.08)
SILVER = (0.62, 0.64, 0.68)
TYRE = (0.04, 0.04, 0.04)
GLASS = (0.55, 0.7, 0.8)


def load(src):
    j = json.load(open(f"{src}/scene.gltf"))
    b = open(f"{src}/scene.bin", "rb").read()

    def acc(i):
        a = j["accessors"][i]
        bv = j["bufferViews"][a["bufferView"]]
        n = {"VEC3": 3, "VEC4": 4, "SCALAR": 1}[a["type"]]
        dt = {5126: "<f4", 5125: "<u4"}[a["componentType"]]
        off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        return np.frombuffer(b, dt, a["count"] * n, off).reshape(-1, n)

    Ps, Ns, Cs, Is, off = [], [], [], [], 0
    for m in j["meshes"]:
        at = m["primitives"][0]["attributes"]
        P = acc(at["POSITION"])
        Ps.append(P)
        Ns.append(acc(at["NORMAL"]))
        Cs.append(acc(at["COLOR_0"])[:, :3])
        Is.append(acc(m["primitives"][0]["indices"]).reshape(-1) + off)
        off += len(P)
    conv = lambda A: np.stack([A[:, 0], A[:, 2], -A[:, 1]], 1)  # the Sketchfab_model node matrix
    return conv(np.vstack(Ps)), conv(np.vstack(Ns)), np.vstack(Cs), np.concatenate(Is).reshape(-1, 3)


def recolour(c):
    """Cub Cadet yellow and black from the source's palette. c = (r, g, b)."""
    r, g, b = c
    if r - max(g, b) > 0.3 or (r > 0.9 and b < 0.2):
        return YELLOW  # red bodywork, yellow and orange accents
    if b > r + 0.1:
        return GLASS
    v = (r + g + b) / 3
    if v >= 0.95:
        return YELLOW  # white panels
    if v >= 0.6 and abs(r - b) < 0.1:
        return SILVER  # rims
    return BLACK


def main():
    src = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else "project/models/ranger_xp.glb"
    P, N, C, I = load(src)
    if len(P) != 87526:
        sys.exit(f"unexpected source: {len(P)} vertices, expected 87526 (a different export of the model?)")
    cen = P[I].mean(1)
    wheel = np.zeros(len(I), bool)
    for zc in (FRONT_AXLE_Z, REAR_AXLE_Z):
        d = np.hypot(cen[:, 1] - WHEEL_Y, cen[:, 2] - zc)
        wheel |= (d < WHEEL_R) & (np.abs(cen[:, 0]) > WHEEL_MIN_X)
    tank = ~wheel & (cen[:, 2] < TANK_CUT_Z) & (cen[:, 1] > TANK_MIN_Y)
    keep = ~tank

    # Ground at y=0, centred between the axles, facing -Z, scaled.
    mid_z = (FRONT_AXLE_Z + REAR_AXLE_Z) / 2
    floor = P[:, 1].min()
    def xform(A, pos=True):
        A = A.copy()
        if pos:
            A[:, 1] -= floor
            A[:, 2] -= mid_z
        A[:, 0] *= -1
        A[:, 2] *= -1  # 180 degrees about Y
        return A * (SCALE if pos else 1.0)
    P2, N2 = xform(P), xform(N, False)

    tri_col = np.array([recolour(c) for c in C[I].mean(1)])
    groups = {}
    for mask, name in ((keep & ~wheel, "Body"), (wheel, None)):
        for idx in np.nonzero(mask)[0]:
            col = tuple(tri_col[idx])
            nm = name or ("Wheel_Rims" if col == SILVER else "Wheel_Tyres")
            if name is None and col != SILVER:
                col = TYRE
            groups.setdefault((nm, col), []).append(idx)

    prims = []
    for (nm, col), idxs in groups.items():
        ii = I[idxs]
        u, inv = np.unique(ii.reshape(-1), return_inverse=True)
        prims.append(dict(name=nm, P=P2[u], N=N2[u], I=inv.reshape(-1, 3), color=col,
                          rough=0.4 if col in (SILVER, YELLOW) else 0.8, metal=0.5 if col == SILVER else 0.0))
    write_glb(out, prims)
    print(f"{out}: {sum(len(p['I']) for p in prims)} triangles, {len(prims)} materials")


def write_glb(path, prims):
    bin_, views, accs, meshes, nodes, mats, matidx = bytearray(), [], [], [], [], [], {}

    def add(arr, target, typ, ctype, minmax=False):
        off = len(bin_)
        bin_.extend(arr.tobytes())
        while len(bin_) % 4:
            bin_.append(0)
        views.append({"buffer": 0, "byteOffset": off, "byteLength": arr.nbytes, "target": target})
        a = {"bufferView": len(views) - 1, "componentType": ctype, "count": int(arr.shape[0] if arr.ndim > 1 else arr.size), "type": typ}
        if minmax:
            a["min"], a["max"] = arr.min(0).tolist(), arr.max(0).tolist()
        accs.append(a)
        return len(accs) - 1

    byname = {}
    for p in prims:
        byname.setdefault(p["name"], []).append(p)
    for name, plist in byname.items():
        prs = []
        for p in plist:
            # glTF colours are linear; the palette above is sRGB (as in Godot's colour picker).
            lin = [((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in p["color"]]
            key = (tuple(round(float(x), 4) for x in lin), p["rough"], p["metal"])
            if key not in matidx:
                matidx[key] = len(mats)
                mats.append({"name": f"mat{len(mats)}", "pbrMetallicRoughness": {
                    "baseColorFactor": [*key[0], 1.0], "metallicFactor": key[2], "roughnessFactor": key[1]}})
            pa = add(p["P"].astype("<f4"), 34962, "VEC3", 5126, True)
            na = add(p["N"].astype("<f4"), 34962, "VEC3", 5126)
            ia = add(p["I"].reshape(-1).astype("<u4"), 34963, "SCALAR", 5125)
            prs.append({"attributes": {"POSITION": pa, "NORMAL": na}, "indices": ia, "material": matidx[key]})
        meshes.append({"name": name, "primitives": prs})
        nodes.append({"name": name, "mesh": len(meshes) - 1})
    j = {"asset": {"version": "2.0", "generator": "tools/build_ranger_model.py"}, "scene": 0,
         "scenes": [{"nodes": list(range(len(nodes)))}], "nodes": nodes, "meshes": meshes, "materials": mats,
         "accessors": accs, "bufferViews": views, "buffers": [{"byteLength": len(bin_)}]}
    jb = json.dumps(j).encode()
    while len(jb) % 4:
        jb += b" "
    body = struct.pack("<II", len(jb), 0x4E4F534A) + jb + struct.pack("<II", len(bin_), 0x004E4942) + bytes(bin_)
    open(path, "wb").write(struct.pack("<III", 0x46546C67, 2, 12 + len(body)) + body)


if __name__ == "__main__":
    main()
