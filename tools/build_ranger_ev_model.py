#!/usr/bin/env python3
"""Builds project/models/ranger_ev.glb from the Sketchfab download of
"Polaris RANGER EV Li-Ion (2018)" by geyges (Sketchfab Standard license).

The download is a textured, mostly black Ranger EV (126k triangles, 40 MB). This
script (numpy only, no Blender) reads the .glb, bakes every node transform into the
vertices and:
  * scales it by SCALE, puts the ground at y=0, centres it between the axles and
    turns it to face -Z (the way vehicle.gd drives);
  * drops the textures, the ground shadow, the speedometer, the hidden motor and
    the tiny decals; every other part gets one flat material, Cub Cadet yellow
    for the body panels and bed, black for the rest, by the source material name;
  * splits the four wheels into "Wheel_Tyres" / "Wheel_Rims" meshes (vehicle.gd
    spins and steers them);
  * puts the cargo box under a "Bed" node whose origin is its hinge (the rear
    bottom edge), so vehicle.gd can tip it about X.
Built for the 2018 download whose 49 meshes hold the 126,211 triangles checked
below; another export fails loudly.
Usage: python3 tools/build_ranger_ev_model.py <polaris_ranger_ev_li-ion_2018.glb> [out.glb]
"""
import json, struct, sys
import numpy as np

SCALE = 1.1
YELLOW = (0.98, 0.78, 0.04)
BLACK = (0.07, 0.07, 0.08)
SILVER = (0.62, 0.64, 0.68)
TYRE = (0.04, 0.04, 0.04)
LENS = (0.92, 0.93, 0.85)
AMBER = (0.85, 0.5, 0.0)
TAIL = (0.55, 0.05, 0.05)

# Source material name prefix -> part. Anything not listed is black body.
DROP = ("EVShadow", "Speedometer", "Glass_11032222", "LIONPC", "Engine_Copy",
        "Diesel_Exhaust", "Ornament_Blue")
YELLOW_PARTS = ("StockBodyPanels", "Body2SeatPanels", "Front_", "EVRear_11033311",
                "Pursuit_Camo")
BED_PARTS = ("Bed_Copy", "BackLight")
COLOURS = {"Chrome": SILVER, "Ornament_Silver": SILVER, "Light_Copy": SILVER,
           "Glass_Copy": LENS, "TurningLight": AMBER, "BackLight": TAIL,
           "Bed_Copy": YELLOW}
EXPECT_TRIS = 126211


def load(path):
    d = open(path, "rb").read()
    jl = struct.unpack("<I", d[12:16])[0]
    j = json.loads(d[20:20 + jl])
    bo = 20 + jl + 8

    def acc(i):
        a = j["accessors"][i]
        bv = j["bufferViews"][a["bufferView"]]
        n = {"VEC3": 3, "SCALAR": 1}[a["type"]]
        dt = {5126: "<f4", 5125: "<u4", 5123: "<u2"}[a["componentType"]]
        off = bo + bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        return np.frombuffer(d, dt, a["count"] * n, off).reshape(-1, n).astype(np.float64 if n == 3 else np.int64)

    def local(n):
        if "matrix" in n:
            return np.array(n["matrix"]).reshape(4, 4).T
        M = np.eye(4)
        if "scale" in n:
            M = np.diag([*n["scale"], 1]) @ M
        if "rotation" in n:
            x, y, z, w = n["rotation"]
            T = np.eye(4)
            T[:3, :3] = [[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                         [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                         [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]]
            M = T @ M
        if "translation" in n:
            T = np.eye(4)
            T[:3, 3] = n["translation"]
            M = T @ M
        return M

    parts = []  # (material name, P (n,3), N (n,3), I (t,3))

    def walk(i, parent):
        n = j["nodes"][i]
        M = parent @ local(n)
        if "mesh" in n:
            for p in j["meshes"][n["mesh"]]["primitives"]:
                P = acc(p["attributes"]["POSITION"])
                N = acc(p["attributes"]["NORMAL"])
                P = (np.c_[P, np.ones(len(P))] @ M.T)[:, :3]
                N = N @ np.linalg.inv(M[:3, :3])  # inverse-transpose for row vectors
                N /= np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-12)
                parts.append((j["materials"][p["material"]]["name"], P, N, acc(p["indices"]).reshape(-1, 3)))
        for c in n.get("children", []):
            walk(c, M)

    for r in j["scenes"][0]["nodes"]:
        walk(r, np.eye(4))
    return parts


def colour(name):
    for k, c in COLOURS.items():
        if name.startswith(k):
            return c
    return YELLOW if name.startswith(YELLOW_PARTS) else BLACK


def main():
    out = sys.argv[2] if len(sys.argv) > 2 else "project/models/ranger_ev.glb"
    parts = load(sys.argv[1])
    tris = sum(len(p[3]) for p in parts)
    if tris != EXPECT_TRIS:
        sys.exit(f"unexpected source: {tris} triangles, expected {EXPECT_TRIS} (a different export of the model?)")

    # Frame: ground at the tyre bottoms, middle of the wheelbase at the origin,
    # facing -Z. The source faces +Z with x to the driver's right, so turn 180
    # degrees about Y.
    tyres = [p[1] for p in parts if p[0].startswith("EV_Tire")]
    lo = np.min([t.min(0) for t in tyres], 0)
    hi = np.max([t.max(0) for t in tyres], 0)
    floor, mid_z = lo[1], (lo[2] + hi[2]) / 2

    def fx(P):
        P = P - [0, floor, mid_z]
        return np.c_[-P[:, 0], P[:, 1], -P[:, 2]] * SCALE

    def fn(N):
        return np.c_[-N[:, 0], N[:, 1], -N[:, 2]]

    # The wheels: per tyre mesh, the centre of its bounds gives the axle.
    wheel_centres = [(t.min(0) + t.max(0)) / 2 for t in tyres]
    groups = {}  # (mesh name, colour) -> list of (P, N, I)
    bed_hinge = None
    for name, P, N, I in parts:
        if name.startswith(DROP):
            continue
        P2, N2 = fx(P), fn(N)
        if name.startswith("EV_Tire"):
            key = ("Wheel_Tyres", TYRE)
        elif name.startswith(("Stock_Rim", "Chrome_11033460")):
            key = ("Wheel_Rims", BLACK if name.startswith("Stock_Rim") else SILVER)
        elif name.startswith(BED_PARTS):
            key = ("Bed", colour(name))
            h = np.array([0.0, P2[:, 1].min(), P2[:, 2].max()])
            bed_hinge = h if bed_hinge is None else np.array([0.0, min(bed_hinge[1], h[1]), max(bed_hinge[2], h[2])])
        else:
            key = ("Body", colour(name))
        groups.setdefault(key, []).append((P2, N2, I))
    # Bed vertices are relative to the hinge, which becomes the Bed node's origin.
    for key, lst in groups.items():
        if key[0] == "Bed":
            groups[key] = [(P - bed_hinge, N, I) for P, N, I in lst]

    prims = []
    for (nm, col), lst in groups.items():
        off, Ps, Ns, Is = 0, [], [], []
        for P, N, I in lst:
            Ps.append(P)
            Ns.append(N)
            Is.append(I.reshape(-1) + off)
            off += len(P)
        P, N, I = np.vstack(Ps), np.vstack(Ns), np.concatenate(Is).reshape(-1, 3)
        # Drop vertices no triangle uses (sources keep a shared buffer per mesh).
        u, inv = np.unique(I.reshape(-1), return_inverse=True)
        shiny = col in (SILVER, YELLOW)
        prims.append(dict(name=nm, P=P[u], N=N[u], I=inv.reshape(-1, 3), color=col,
                          rough=0.4 if shiny else 0.8, metal=0.5 if col == SILVER else 0.0))
    write_glb(out, prims, bed_hinge)
    print(f"{out}: {sum(len(p['I']) for p in prims)} triangles, {len(prims)} primitives, bed hinge {np.round(bed_hinge, 3)}")


def write_glb(path, prims, bed_hinge):
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
    bed_children = []
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
        meshes.append({"name": name + "Mesh" if name == "Bed" else name, "primitives": prs})
        node = {"name": "BedShell" if name == "Bed" else name, "mesh": len(meshes) - 1}
        nodes.append(node)
        if name == "Bed":
            bed_children.append(len(nodes) - 1)
    top = [i for i in range(len(nodes)) if i not in bed_children]
    # The Bed node: origin at the hinge, the shell hanging off it.
    nodes.append({"name": "Bed", "translation": [float(x) for x in bed_hinge], "children": bed_children})
    top.append(len(nodes) - 1)
    j = {"asset": {"version": "2.0", "generator": "tools/build_ranger_ev_model.py"}, "scene": 0,
         "scenes": [{"nodes": top}], "nodes": nodes, "meshes": meshes, "materials": mats,
         "accessors": accs, "bufferViews": views, "buffers": [{"byteLength": len(bin_)}]}
    jb = json.dumps(j).encode()
    while len(jb) % 4:
        jb += b" "
    body = struct.pack("<II", len(jb), 0x4E4F534A) + jb + struct.pack("<II", len(bin_), 0x004E4942) + bytes(bin_)
    open(path, "wb").write(struct.pack("<III", 0x46546C67, 2, 12 + len(body)) + body)


if __name__ == "__main__":
    main()
