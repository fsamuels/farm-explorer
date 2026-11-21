"""Build project/models/player.glb — the player character (Forrest) — from
Quaternius's CC0 Universal Base Characters + Universal Animation Library packs.

Run with Blender's Python module (pip install bpy pillow numpy), not system Python:

    python tools/build_player_model.py <UBC_STANDARD_DIR> <UAL_STANDARD_DIR> [out.glb]

where the two dirs are the unzipped "Universal Base Characters[Standard]" and
"Universal Animation Library[Standard]" folders (free CC0 downloads from
quaternius.itch.io). See D-89 in docs/project/decisions.md.

What it does:
  * Superhero_Male_FullBody base mesh (light skin) + Hair_SimpleParted, joined
    into one skinned mesh on the shared UE-style skeleton. The superhero sculpt
    is softened (less shredded, a little thicker through the middle) to read as
    an ordinary 5'9", 185 lb build.
  * Repaints the body texture in UV space, per pixel, from a rasterised rest-pose
    position map: plaid flannel shirt (long sleeves, collar, button placket),
    brown belt with buckle, blue jeans.
  * Muck boots as real geometry (rubber foot shell + neoprene calf shell to
    mid-calf), so bare toes don't show.
  * Blonde hair/eyebrows, blue irises.
  * A brown ball cap skinned 100% to the Head bone, with "FARM DADDY / FORREST"
    lettered on the front panel.
  * Idle / Walk / Jog / Sprint / Jump animations from the in-place (non
    root-motion) Universal Animation Library.

The mesh is exported at the pack's native scale (~1.81m to the top of the
head); player.tscn scales the Model node to the real 5'9" (1.753m).
"""

import math
import os
import sys

import bpy
import bmesh
import numpy as np
from mathutils import Vector
from mathutils.kdtree import KDTree
from PIL import Image, ImageDraw, ImageFilter, ImageFont

# Bold serif for the cap lettering; first one found wins, else Pillow's default.
FONT_CANDIDATES = (
    "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf",   # Linux
    "/Library/Fonts/Georgia Bold.ttf",                          # macOS
    "/System/Library/Fonts/Supplemental/Georgia Bold.ttf",      # macOS
    "C:/Windows/Fonts/georgiab.ttf",                            # Windows
    "DejaVuSerif-Bold.ttf",                                     # Pillow search path
)


def cap_font(size):
    for path in FONT_CANDIDATES:
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default(size)

# Region heights (rest pose, metres, Blender Z-up, model faces -Y, ~1.81m tall).
BOOT_TOP = 0.40      # muck boots come to mid-calf
BELT_BOTTOM = 1.000
BELT_TOP = 1.042
COLLAR_TOP = 1.560   # shirt collar on the neck

SKIN_BONES_PREFIX = ("Head", "hand_", "index_", "middle_", "ring_", "pinky_", "thumb_")

KEEP_ACTIONS = {
    "Idle_Loop": "Idle",
    "Walk_Loop": "Walk",
    "Jog_Fwd_Loop": "Jog",
    "Sprint_Loop": "Sprint",
    "Jump_Start": "Jump_Start",
    "Jump_Loop": "Jump_Loop",
    "Jump_Land": "Jump_Land",
}


def srgb(r, g, b):
    """sRGB 0-255 -> linear RGBA for node default values."""
    f = lambda c: (c / 255) / 12.92 if c / 255 <= 0.04045 else ((c / 255 + 0.055) / 1.055) ** 2.4
    return (f(r), f(g), f(b), 1.0)


CAP_RGB = (92, 60, 36)
BILL_RGB = (78, 50, 30)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    ubc, ual = argv[0], argv[1]
    out = argv[2] if len(argv) > 2 else os.path.join(
        os.path.dirname(__file__), "..", "project", "models", "player.glb")

    bpy.ops.wm.read_factory_settings(use_empty=True)
    body, arm = import_body(ubc)
    hair = import_hair(ubc)
    paint_body(body, ubc)          # uses the original sculpt's rest positions
    boots = build_boots(body)
    soften_body(body)
    recolor_eyes_and_hair()
    cap = build_cap()
    tuck_hair_under_cap(hair)
    shrink_textures()

    # Join hair, boots and cap into the body so the export is one skinned mesh.
    bpy.ops.object.select_all(action="DESELECT")
    for o in (hair, boots, cap, body):
        o.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    body.name = "Forrest"
    for o in list(bpy.data.objects):
        if o.type == "ARMATURE" and o is not arm:
            bpy.data.objects.remove(o)

    add_animations(arm, ual)
    arm.name = "Armature"

    bpy.ops.object.select_all(action="DESELECT")
    bpy.ops.export_scene.gltf(
        filepath=os.path.abspath(out),
        export_format="GLB",
        export_animation_mode="ACTIONS",
        export_image_format="JPEG",
        export_image_quality=88,
        export_yup=True,
        export_apply=False,
    )
    fix_icc_chunk_numbers(out)
    print("WROTE", os.path.abspath(out))


def fix_icc_chunk_numbers(path):
    """Blender's JPEG export tags the sRGB textures' ICC profile as chunk 0 of 1.
    Chunks are 1-based; Godot's libjpeg-turbo rejects chunk 0, fails the image,
    then crashes the editor importing the scene. Same length, so offsets hold."""
    with open(path, "rb") as f:
        data = f.read()
    bad, good = b"ICC_PROFILE\x00\x00\x01", b"ICC_PROFILE\x00\x01\x01"
    if bad in data:
        print(f"fixed {data.count(bad)} ICC chunk number(s)")
        with open(path, "wb") as f:
            f.write(data.replace(bad, good))


# --------------------------------------------------------------------------- import

def import_body(ubc):
    bpy.ops.import_scene.gltf(filepath=os.path.join(
        ubc, "Base Characters", "Godot - UE", "Superhero_Male_FullBody.gltf"))
    body = bpy.data.objects["SuperHero_Male"]
    arm = body.find_armature()
    for o in list(bpy.data.objects):
        if o.type == "MESH" and o.name == "Icosphere":
            bpy.data.objects.remove(o)
    return body, arm


def import_hair(ubc):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(
        ubc, "Hairstyles", "Rigged to Head Bone", "glTF (Godot -Unreal)",
        "Hair_SimpleParted.gltf"))
    new = [o for o in bpy.data.objects if o not in before]
    hair = next(o for o in new if o.type == "MESH")
    hair.name = "Hair"
    return hair


def base_color_node(mat):
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    stack = [l.from_node for l in bsdf.inputs["Base Color"].links]
    while stack:
        node = stack.pop()
        if node.type == "TEX_IMAGE":
            return node
        stack += [l.from_node for i in node.inputs for l in i.links]
    raise LookupError(f"no base-colour texture on {mat.name}")


def dominant_bone(v, gnames):
    if not v.groups:
        return ""
    return gnames[max(v.groups, key=lambda x: x.weight).group]


# --------------------------------------------------------------------------- body paint

def plaid(size):
    """Blue flannel plaid: navy/royal blocks with thin light-blue and white lines."""
    p = 96
    y, x = np.mgrid[0:size, 0:size]
    a, b = x % p, y % p
    base = np.array([52, 92, 160], float)
    img = np.ones((size, size, 3)) * base
    navy = np.array([24, 38, 78], float)
    wide_x, wide_y = (a < 36), (b < 36)
    img[wide_x] = img[wide_x] * 0.45 + navy * 0.55
    img[wide_y] = img[wide_y] * 0.45 + navy * 0.55
    img[wide_x & wide_y] = navy * 0.9
    for off, col, w in ((52, (150, 185, 230), 4), (70, (235, 240, 245), 2)):
        lx, ly = (a >= off) & (a < off + w), (b >= off) & (b < off + w)
        img[lx | ly] = img[lx | ly] * 0.35 + np.array(col, float) * 0.65
    rng = np.random.default_rng(7)
    img *= (0.93 + 0.07 * (((x + y) // 2) % 2))[..., None]
    img *= (0.94 + 0.12 * rng.random((size, size)))[..., None]
    return img


def denim(size):
    rng = np.random.default_rng(11)
    y, x = np.mgrid[0:size, 0:size]
    img = np.ones((size, size, 3)) * np.array([40, 62, 104], float)
    img *= (0.9 + 0.1 * (((x - y) // 2) % 3 == 0))[..., None]
    img *= (0.88 + 0.2 * rng.random((size, size)))[..., None]
    return img


def flat(size, rgb, noise=0.06, seed=3):
    rng = np.random.default_rng(seed)
    img = np.ones((size, size, 3)) * np.array(rgb, float)
    img *= (1 - noise + 2 * noise * rng.random((size, size)))[..., None]
    return img


def rasterize_position_map(o, size):
    """Per-texel rest-pose world position + a per-face class, by rasterising
    every UV triangle. cls: 0 = no face, 1 = head/hand skin, 2 = neck, 3 = other."""
    me = o.data
    me.calc_loop_triangles()
    mw = o.matrix_world
    pos = np.full((size, size, 3), np.nan, np.float32)
    cls = np.zeros((size, size), np.int8)
    gnames = {vg.index: vg.name for vg in o.vertex_groups}
    world = [mw @ v.co for v in me.vertices]
    vclass = []
    for v in me.vertices:
        b = dominant_bone(v, gnames)
        vclass.append(1 if b.startswith(SKIN_BONES_PREFIX) else 2 if b == "neck_01" else 3)
    uv = me.uv_layers[0].data
    for tri in me.loop_triangles:
        P = np.array([[uv[l].uv.x * size, (1 - uv[l].uv.y) * size] for l in tri.loops])
        W = np.array([world[i][:] for i in tri.vertices])
        votes = [vclass[i] for i in tri.vertices]
        c = max(set(votes), key=votes.count)
        x0, y0 = np.floor(P.min(0)).astype(int) - 1
        x1, y1 = np.ceil(P.max(0)).astype(int) + 1
        x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, size - 1), min(y1, size - 1)
        if x1 < x0 or y1 < y0:
            continue
        gy, gx = np.mgrid[y0:y1 + 1, x0:x1 + 1] + 0.5
        (ax, ay), (bx, by), (cx, cy) = P
        den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(den) < 1e-9:
            continue
        l0 = ((by - cy) * (gx - cx) + (cx - bx) * (gy - cy)) / den
        l1 = ((cy - ay) * (gx - cx) + (ax - cx) * (gy - cy)) / den
        l2 = 1 - l0 - l1
        inside = (l0 >= -0.02) & (l1 >= -0.02) & (l2 >= -0.02)
        if not inside.any():
            continue
        p = l0[..., None] * W[0] + l1[..., None] * W[1] + l2[..., None] * W[2]
        sub = pos[y0:y1 + 1, x0:x1 + 1]
        sub[inside] = p[inside]
        cls[y0:y1 + 1, x0:x1 + 1][inside] = c
    return pos, cls


def paint_body(body, ubc):
    src = Image.open(os.path.join(
        ubc, "Base Characters", "Textures", "T_Superhero_Male_Ligh.png")).convert("RGB")
    size = src.size[0]
    pos, cls = rasterize_position_map(body, size)
    x, y, z = pos[..., 0], pos[..., 1], pos[..., 2]
    covered = cls > 0
    with np.errstate(invalid="ignore"):
        skin = (cls == 1) | ((cls == 2) & (z >= COLLAR_TOP))
        cloth = covered & ~skin
        boot = cloth & (z < BOOT_TOP)
        jeans = cloth & (z >= BOOT_TOP) & (z < BELT_BOTTOM)
        belt = cloth & (z >= BELT_BOTTOM) & (z < BELT_TOP)
        shirt = cloth & (z >= BELT_TOP)
        front = y < -0.02
        buckle = belt & front & (np.abs(x) < 0.028)
        placket = shirt & front & (np.abs(x) < 0.011) & (z < COLLAR_TOP - 0.06)
        button = placket & (np.abs(x) < 0.006) & (np.mod(z - BELT_TOP, 0.085) < 0.012) \
            & (z > BELT_TOP + 0.05)

    base = np.asarray(src, float)
    lum = base.mean(axis=2)
    shade = (lum / max(lum.mean(), 1)).clip(0.6, 1.4)[..., None]
    shade = 1 + (shade - 1) * 0.3  # a little of the sculpt's shading, not the six-pack
    layers = [
        (boot, flat(size, (24, 24, 26), 0.05)),
        (jeans, denim(size)),
        (belt, flat(size, (84, 52, 28), 0.08)),
        (buckle, flat(size, (178, 170, 150), 0.04)),
        (shirt, plaid(size)),
        (placket, plaid(size)[::-1] * 0.85),
        (button, flat(size, (225, 225, 215), 0.03)),
    ]
    out = base.copy()
    for mask, layer in layers:
        m = Image.fromarray((mask * 255).astype(np.uint8))
        if mask is boot or mask is jeans or mask is belt or mask is shirt:
            m = m.filter(ImageFilter.MaxFilter(5))  # bleed over UV seams
        m = np.asarray(m, float)[..., None] / 255
        out = out * (1 - m) + (layer * shade).clip(0, 255) * m
    img = bpy.data.images.new("T_Forrest_Body", size, size)
    rgba = np.concatenate([out / 255, np.ones((size, size, 1))], axis=2)
    img.pixels.foreach_set(np.flipud(rgba).astype(np.float32).ravel())
    img.pack()
    base_color_node(body.data.materials[0]).image = img

    # Flatten the normal map under the clothes so fabric doesn't show every muscle.
    nmat = body.data.materials[0]
    bsdf = next(n for n in nmat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    nlinks = bsdf.inputs["Normal"].links
    if nlinks:
        nt = nlinks[0].from_node.inputs["Color"].links[0].from_node
        npx = np.array(nt.image.pixels[:], np.float32).reshape(
            nt.image.size[1], nt.image.size[0], 4)
        cm = np.asarray(Image.fromarray((cloth * 255).astype(np.uint8))
                        .resize((nt.image.size[0], nt.image.size[1]))
                        .filter(ImageFilter.MaxFilter(5)), np.float32)
        cm = np.flipud(cm)[..., None] / 255 * 0.7
        flatn = np.array([0.5, 0.5, 1.0], np.float32)
        npx[..., :3] = npx[..., :3] * (1 - cm) + flatn * cm
        nt.image.pixels.foreach_set(npx.ravel())
        nt.image.pack()


def soften_body(body):
    """Tone down the superhero sculpt: smooth clothed areas a little and add
    some thickness through the waist/belly for a 185 lb build."""
    gnames = {vg.index: vg.name for vg in body.vertex_groups}
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bm.verts.ensure_lookup_table()
    me_verts = body.data.vertices
    cloth = [bv for bv in bm.verts
             if not dominant_bone(me_verts[bv.index], gnames).startswith(SKIN_BONES_PREFIX)
             and dominant_bone(me_verts[bv.index], gnames) != "neck_01"
             and 0.42 < bv.co.z < 1.52]
    # glTF meshes split vertices along UV seams; keep each co-located set
    # together or smoothing tears visible cracks along every seam.
    welds = {}
    for bv in bm.verts:
        welds.setdefault(tuple(round(c, 5) for c in bv.co), []).append(bv)
    welds = [g for g in welds.values() if len(g) > 1]

    def reweld():
        for g in welds:
            mean = sum((v.co for v in g), Vector()) / len(g)
            for v in g:
                v.co = mean.copy()

    for _ in range(4):
        bmesh.ops.smooth_vert(bm, verts=cloth, factor=0.45,
                              use_axis_x=True, use_axis_y=True, use_axis_z=True)
        reweld()
    bm.normal_update()
    normals = {bv: bv.normal.copy() for bv in bm.verts}
    for g in welds:
        n = sum((normals[v] for v in g), Vector()).normalized()
        for v in g:
            normals[v] = n
    for bv in cloth:
        z = bv.co.z
        # Gaussian thickening centred on the belly, strongest at the front.
        w = math.exp(-((z - 1.12) / 0.14) ** 2)
        fwd = max(0.0, -normals[bv].y)
        bv.co += normals[bv] * (0.006 + 0.016 * w * (0.4 + 0.6 * fwd))
    reweld()
    bm.to_mesh(body.data)
    bm.free()


# --------------------------------------------------------------------------- boots

def build_boots(body):
    """Muck boots: a convex rubber shell over each foot (hides the toes) plus an
    inflated neoprene shell over the lower calf. Skin weights copied from the
    nearest body vertex so the boots follow the feet."""
    me = body.data
    mw = body.matrix_world
    gnames = {vg.index: vg.name for vg in body.vertex_groups}
    kd = KDTree(len(me.vertices))
    for v in me.vertices:
        kd.insert(mw @ v.co, v.index)
    kd.balance()

    bm = bmesh.new()
    # Rubber foot shells: convex hull per side of everything below the ankle.
    for side in (1, -1):
        pts = [mw @ v.co for v in me.vertices
               if (mw @ v.co).z < 0.13 and (mw @ v.co).x * side > 0.04]
        vs = [bm.verts.new(p) for p in pts]
        res = bmesh.ops.convex_hull(bm, input=vs)
        loose = {v for v in res["geom_interior"] + res["geom_unused"]
                 if isinstance(v, bmesh.types.BMVert)}
        bmesh.ops.delete(bm, geom=list(loose), context="VERTS")
    bm.normal_update()
    for v in bm.verts:
        v.co += v.normal * 0.007
        v.co.z = max(v.co.z, -0.012)
    for f in bm.faces:
        f.material_index = 0
        f.smooth = True
    n_foot = len(bm.verts)

    # Neoprene calf shells: copy of the body's lower-leg faces, pushed outward.
    src = bmesh.new()
    src.from_mesh(me)
    src.transform(mw)
    leg = [f for f in src.faces
           if 0.07 < f.calc_center_median().z < BOOT_TOP + 0.01]
    vmap = {}
    for f in leg:
        for v in f.verts:
            if v not in vmap:
                vmap[v] = bm.verts.new(v.co + v.normal * 0.012)
        nf = bm.faces.new([vmap[v] for v in f.verts])
        nf.material_index = 1 if f.calc_center_median().z > 0.13 else 0
        nf.smooth = True
    # A level, slightly flared top cuff (the face selection leaves it ragged).
    for v_old, v_new in vmap.items():
        if v_old.co.z > BOOT_TOP - 0.03:
            v_new.co += v_old.normal * 0.004
        if v_new.co.z > BOOT_TOP - 0.012:
            v_new.co.z = BOOT_TOP
    src.free()

    boot_me = bpy.data.meshes.new("Boots")
    bm.to_mesh(boot_me)
    bm.free()
    boots = bpy.data.objects.new("Boots", boot_me)
    bpy.context.collection.objects.link(boots)
    boot_me.materials.append(make_mat("M_Boot_Rubber", srgb(46, 36, 28), rough=0.6))
    boot_me.materials.append(make_mat("M_Boot_Neoprene", srgb(20, 20, 22), rough=0.75))

    groups = {}
    for v in boot_me.vertices:
        _, idx, _ = kd.find(v.co)
        for g in me.vertices[idx].groups:
            name = gnames[g.group]
            if name not in groups:
                groups[name] = boots.vertex_groups.new(name=name)
            groups[name].add([v.index], g.weight, "REPLACE")
    return boots


# --------------------------------------------------------------------------- eyes / hair

def recolor_eyes_and_hair():
    for mat in bpy.data.materials:
        if mat.name.startswith("MI_Eyes"):
            node = base_color_node(mat)
            px = np.array(node.image.pixels[:], float).reshape(
                node.image.size[1], node.image.size[0], 4)
            r, g, b = px[..., 0], px[..., 1], px[..., 2]
            iris = (r > g * 1.15) & (g > b) & (r < 0.75) & (px.mean(axis=2) < 0.55)
            h, w = r.shape
            yy, xx = np.mgrid[0:h, 0:w]
            iris &= (xx - w / 2) ** 2 + (yy - h / 2) ** 2 < (0.16 * w) ** 2
            l = (r + g + b)[iris] / 3
            px[iris, 0] = l * 0.55
            px[iris, 1] = l * 1.05
            px[iris, 2] = np.minimum(l * 2.1 + 0.08, 1)
            img = bpy.data.images.new("T_Eye_Blue", w, h)
            img.pixels.foreach_set(px.astype(np.float32).ravel())
            img.pack()
            node.image = img
        if mat.name.startswith("MI_Hair"):
            bake_tint(base_color_node(mat).image, (0.98, 0.78, 0.42), 1.35)  # blonde


def bake_tint(image, rgb, gain):
    if image.get("forrest_tinted"):
        return
    px = np.array(image.pixels[:], np.float32).reshape(-1, 4)
    px[:, :3] = (px[:, :3] * np.array(rgb, np.float32) * gain).clip(0, 1)
    image.pixels.foreach_set(px.ravel())
    image.pack()
    image["forrest_tinted"] = True


def shrink_textures():
    """Keep the GLB small: colour maps 1024, normal/roughness/hair 512-1024."""
    for img in bpy.data.images:
        if img.size[0] > 1024:
            img.scale(1024, 1024)
            img.pack()


# --------------------------------------------------------------------------- cap

def cap_front_texture():
    w, h = 512, 256
    im = Image.new("RGB", (w, h), CAP_RGB)
    d = ImageDraw.Draw(im)
    cream = (236, 222, 190)
    for text, cy, size in (("FARM DADDY", 100, 50), ("FORREST", 168, 56)):
        f = cap_font(size)
        tw = d.textlength(text, font=f)
        d.text(((w - tw) / 2, cy - size / 2 - 6), text, font=f, fill=cream)
    img = bpy.data.images.new("T_Cap_Front", w, h)
    rgba = np.concatenate([np.asarray(im, float) / 255, np.ones((h, w, 1))], axis=2)
    img.pixels.foreach_set(np.flipud(rgba).astype(np.float32).ravel())
    img.pack()
    return img


def make_mat(name, rgba, image=None, rough=0.85):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = rgba
    bsdf.inputs["Roughness"].default_value = rough
    if image:
        t = m.node_tree.nodes.new("ShaderNodeTexImage")
        t.image = image
        m.node_tree.links.new(t.outputs["Color"], bsdf.inputs["Base Color"])
    return m


# Crown: a dome over the head/hair, tilted so the bill side sits just above the
# eyebrows and the back sits lower over the hair. The front is flattened and
# raised a bit like a structured ball-cap panel.
CROWN_C = Vector((0.0, 0.006, 1.722))
CROWN_R = Vector((0.104, 0.118, 0.118))
TILT = math.radians(-8)  # rotate about X: front (-Y) up, back down


def rot_x(v, ang):
    c, s = math.cos(ang), math.sin(ang)
    return Vector((v.x, v.y * c - v.z * s, v.y * s + v.z * c))


def crown_point(th, phi):
    """th: 0 at front (-Y); phi: 0 at rim, pi/2 at top."""
    cp, sp = math.cos(phi), math.sin(phi)
    # Squarer profile: superellipse in the vertical so the panels stand up.
    cp_s = math.copysign(abs(cp) ** 0.8, cp)
    sp_s = math.copysign(abs(sp) ** 1.15, sp)
    front = max(0.0, math.cos(th))
    rz = CROWN_R.z * (1 + 0.08 * front)
    return Vector((CROWN_R.x * cp_s * math.sin(th),
                   -CROWN_R.y * cp_s * math.cos(th) * (1 - 0.10 * front * sp),
                   rz * sp_s))


def build_cap():
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    seg, rings = 36, 12
    verts = []
    for j in range(rings):
        phi = (math.pi / 2) * j / rings
        verts.append([bm.verts.new(CROWN_C + rot_x(crown_point(2 * math.pi * i / seg, phi), TILT))
                      for i in range(seg)])
    top = bm.verts.new(CROWN_C + rot_x(Vector((0, 0, CROWN_R.z * 1.0)), TILT))
    faces = []
    for j in range(rings):
        for i in range(seg):
            a, b = verts[j][i], verts[j][(i + 1) % seg]
            if j == rings - 1:
                f = bm.faces.new((a, b, top))
            else:
                f = bm.faces.new((a, b, verts[j + 1][(i + 1) % seg], verts[j + 1][i]))
            faces.append((f, i, j))
    for f, i, j in faces:
        th = 2 * math.pi * (i + 0.5) / seg
        uvs = []
        for loop in f.loops:
            local = rot_x(loop.vert.co - CROWN_C, -TILT)
            uvs.append((0.5 + local.x / 0.15, (local.z - 0.006) / 0.092))
        # Only faces wholly inside the lettering box on the front panel get the
        # lettering material; everything else is plain brown.
        inside = all(0.0 <= u <= 1.0 and 0.0 <= v <= 1.0 for u, v in uvs)
        f.material_index = 1 if (inside and math.cos(th) > 0.3) else 0
        for loop, uv in zip(f.loops, uvs):
            loop[uvl].uv = uv

    # Button on top.
    btn = bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=6, radius=0.009)
    for v in btn["verts"]:
        v.co = CROWN_C + rot_x(Vector((v.co.x, v.co.y, v.co.z * 0.45 + CROWN_R.z)), TILT)
    for f in {f for v in btn["verts"] for f in v.link_faces}:
        f.material_index = 0

    # Bill: curved, sloping down at the front and more so at the sides.
    n = 16
    inner, outer = [], []
    for k in range(n + 1):
        th = math.radians(-82 + 164 * k / n)
        rim = crown_point(th, 0.0)
        reach = 0.092 * math.cos(th) ** 0.55
        out = Vector((rim.x * 1.1, rim.y - reach,
                      -0.010 - 0.022 * math.sin(th) ** 2))
        inner.append(bm.verts.new(CROWN_C + rot_x(rim + Vector((0, 0, 0.003)), TILT)))
        outer.append(bm.verts.new(CROWN_C + rot_x(out, TILT)))
    for k in range(n):
        f = bm.faces.new((inner[k], outer[k], outer[k + 1], inner[k + 1]))
        f.material_index = 2

    bm.normal_update()
    me = bpy.data.meshes.new("Cap")
    bm.to_mesh(me)
    bm.free()
    cap = bpy.data.objects.new("Cap", me)
    bpy.context.collection.objects.link(cap)
    me.materials.append(make_mat("M_Cap", srgb(*CAP_RGB)))
    me.materials.append(make_mat("M_Cap_Front", srgb(*CAP_RGB), cap_front_texture()))
    me.materials.append(make_mat("M_Cap_Bill", srgb(*BILL_RGB)))
    for p in me.polygons:
        p.use_smooth = True
    sol = cap.modifiers.new("Solidify", "SOLIDIFY")
    sol.thickness = 0.005
    sol.offset = 1.0
    bpy.context.view_layer.objects.active = cap
    bpy.ops.object.modifier_apply(modifier="Solidify")
    vg = cap.vertex_groups.new(name="Head")
    vg.add(list(range(len(me.vertices))), 1.0, "REPLACE")
    return cap


def tuck_hair_under_cap(hair):
    """Pull any hair above the cap rim back inside the crown so it can't poke
    through (the parted hairstyle stands up on one side)."""
    mw, inv = hair.matrix_world, hair.matrix_world.inverted()
    for v in hair.data.vertices:
        local = rot_x(mw @ v.co - CROWN_C, -TILT)
        if local.z <= 0:
            continue
        r = math.sqrt((local.x / CROWN_R.x) ** 2 + (local.y / CROWN_R.y) ** 2
                      + (local.z / CROWN_R.z) ** 2)
        if r > 0.9:
            local *= 0.9 / r
            v.co = inv @ (CROWN_C + rot_x(local, TILT))


# --------------------------------------------------------------------------- animation

def add_animations(arm, ual):
    before_actions = set(bpy.data.actions)
    before_objs = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(
        ual, "Unreal-Godot", "UAL1_Standard.glb"))
    for o in set(bpy.data.objects) - before_objs:
        bpy.data.objects.remove(o)
    for act in set(bpy.data.actions) - before_actions:
        if act.name not in KEEP_ACTIONS:
            bpy.data.actions.remove(act)
            continue
        act.name = KEEP_ACTIONS[act.name]
        act.use_fake_user = True
    for act in list(bpy.data.actions):
        if act.name not in KEEP_ACTIONS.values():
            bpy.data.actions.remove(act)

    ad = arm.animation_data or arm.animation_data_create()
    for act in sorted(bpy.data.actions, key=lambda a: a.name):
        track = ad.nla_tracks.new()
        track.name = act.name
        strip = track.strips.new(act.name, int(act.frame_range[0]), act)
        if hasattr(strip, "action_slot") and act.slots:
            strip.action_slot = act.slots[0]
        track.mute = True
    ad.action = None


if __name__ == "__main__":
    main()
