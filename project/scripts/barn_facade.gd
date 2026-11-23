extends Node3D
## The Front Barn's outside (D-125), rebuilt from the user's photo of its north
## end: the cross-section in barn_profile.gd (a tall central section with a
## low-pitched roof and a lower wing each side), tan T1-11 siding over every
## open bay, the big middle opening with a header beam, a closed west wing
## with a blue corrugated skirt, wood posts, red roof trim, and the roofs
## themselves. The two ends (north and south) are alike. Everything is
## generated textures and meshes; the roofs keep the drone-imagery crops that
## were on the old roof planes.
##
## It sits in the barn shell's frame (`shell` is the FrontBarnShell node; +X
## east, +Z south, origin at the footprint centre on the ground) and follows
## the shell's width and depth. Walls, posts and the interior fittings carry
## the collision; the siding, trim and roofs are visual only.

const Profile := preload("res://scripts/barn_profile.gd")
const Corrugated := preload("res://scripts/corrugated.gd")

const SIDING := "res://textures/buildings/barn_siding_tan.png"
const SIDING_NORMAL := "res://textures/buildings/barn_siding_tan_normal.png"
const POST_WOOD := "res://textures/buildings/barn_post_wood.png"
const ROOF_WEST := preload("res://textures/roofs/front_barn_west.png")
const ROOF_EAST := preload("res://textures/roofs/front_barn_east.png")

## One siding tile holds four 8 in panels, 0.8 m.
const SIDING_SCALE := 1.25
## Where the wing meets the central slope in the roof crops (the crops hold
## the central slope on top and the wing below).
const ROOF_SPLIT := 0.595
const SKIN := 0.015
const TRIM_H := 0.28
const POST := 0.25
const BEAM := 0.2
const ROOF_T := 0.12
const OVERHANG := 0.1

@export var shell_path: NodePath = ^"../FrontBarnShell"

var width := 1.0
var depth := 1.0
var _body: StaticBody3D
var _siding: StandardMaterial3D
var _skirt: StandardMaterial3D
var _wood: StandardMaterial3D
var _red: StandardMaterial3D
var _under: StandardMaterial3D
## The posts and the siding / skirt pieces on each end, for the tests.
var posts: Array[Node3D] = []
var siding_pieces := 0
var skirt_pieces := 0

func _ready() -> void:
	var shell := get_node_or_null(shell_path) as Node3D
	if shell == null:
		push_warning("barn_facade: no shell at %s" % shell_path)
		return
	width = shell.width
	depth = shell.depth
	global_transform = shell.global_transform
	_siding = _textured(SIDING, SIDING_NORMAL, SIDING_SCALE)
	_skirt = Corrugated.material()
	_skirt.cull_mode = BaseMaterial3D.CULL_DISABLED
	_wood = _textured(POST_WOOD, "", 2.0)
	_wood.cull_mode = BaseMaterial3D.CULL_BACK
	_red = _flat(Color(0.56, 0.12, 0.11))
	_red.metallic = 0.35
	_red.roughness = 0.45
	_under = _flat(Color(0.34, 0.25, 0.18))
	_body = StaticBody3D.new()
	_body.name = "Posts"
	add_child(_body)
	for end in [-1.0, 1.0]:
		_build_end(end)
	_build_west_wall()
	_build_roofs()

func _flat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

## World-space triplanar, like the Shop's corrugated metal: the panel grooves
## stay vertical on every wall and line up across separate pieces.
func _textured(albedo: String, normal: String, scale: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = Corrugated.mipmapped(albedo)
	if normal != "":
		m.normal_enabled = true
		m.normal_texture = Corrugated.mipmapped(normal)
	m.roughness = 0.85
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(scale, scale, scale)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

## The x of the wing / centre junction posts, from the barn's middle.
func junction() -> float:
	return width / 2.0 - Profile.WING_W

## One end face (`end` -1 north, +1 south): siding over every bay, the closed
## west wing down to the ground with its skirt, header beams, trim and posts.
func _build_end(end: float) -> void:
	var half := width / 2.0
	var jn := junction()
	var ow := Profile.OPENING_W / 2.0
	var z := end * (depth / 2.0 + SKIN)
	# The east wing and the two side bays are open below the clearance line.
	_band(z, end, jn, half, Profile.CLEARANCE, _siding)
	_band(z, end, ow, jn, Profile.CLEARANCE, _siding)
	_band(z, end, -jn, -ow, Profile.CLEARANCE, _siding)
	# Above the big opening: from its header to the roof.
	_band(z, end, -ow, ow, Profile.HEADER, _siding)
	# The closed west wing: skirt at the bottom, siding above.
	_band(z, end, -half, -jn, Profile.SKIRT, _siding)
	_rect(z, end, -half, -jn, 0.05, Profile.SKIRT, _skirt)
	skirt_pieces += 1
	# Header beams, and the rail the siding sits on over the open bays.
	var bz := end * (depth / 2.0 - BEAM / 2.0)
	_box(Vector3(0.0, Profile.HEADER - BEAM / 2.0, bz), Vector3(Profile.OPENING_W + POST, BEAM, BEAM), _wood, false)
	_box(Vector3((jn + half) / 2.0, Profile.CLEARANCE - BEAM / 2.0, bz), Vector3(half - jn, BEAM, BEAM), _wood, false)
	_box(Vector3((jn + ow) / 2.0, Profile.CLEARANCE - BEAM / 2.0, bz), Vector3(jn - ow, BEAM, BEAM), _wood, false)
	_box(Vector3(-(jn + ow) / 2.0, Profile.CLEARANCE - BEAM / 2.0, bz), Vector3(jn - ow, BEAM, BEAM), _wood, false)
	# Red trim along the roof edge of the face.
	_trim(z + end * SKIN, end, [Vector2(half, Profile.WING_LOW), Vector2(jn, Profile.WING_HIGH)])
	_trim(z + end * SKIN, end, [Vector2(jn, Profile.EAVE), Vector2(0.0, Profile.RIDGE), Vector2(-jn, Profile.EAVE)])
	_trim(z + end * SKIN, end, [Vector2(-jn, Profile.WING_HIGH), Vector2(-half, Profile.WING_LOW)])
	# Posts: the wing's middle, the two junctions and the opening's two sides.
	var pz := end * (depth / 2.0 - POST / 2.0)
	for px in [(half + jn) / 2.0, jn, ow, -ow, -jn]:
		var tall: float = Profile.HEADER if absf(px) == ow else Profile.CLEARANCE
		_post(Vector3(px, 0.0, pz), tall)

## The west side wall's outside: skirt below, siding above, up to the wing's
## low eave. The shell's wall behind it is the collider.
func _build_west_wall() -> void:
	var x := -(width / 2.0 + SKIN)
	var lo := 0.05
	_side_rect(x, lo, Profile.SKIRT, _skirt)
	_side_rect(x, Profile.SKIRT, Profile.WING_LOW, _siding)
	skirt_pieces += 1
	siding_pieces += 1
	# The step where the central roof stands above the wing roof, both sides.
	var jn := junction()
	for sx in [-1.0, 1.0]:
		_side_rect(sx * jn, Profile.WING_HIGH - ROOF_T, Profile.EAVE, _siding, OVERHANG)
		siding_pieces += 1

## A siding quad on the plane x = `x`, from y0 to y1, along the whole depth
## plus `extra` at each end.
func _side_rect(x: float, y0: float, y1: float, material: Material, extra := 0.0) -> void:
	var h := depth / 2.0 + extra
	var n := Vector3(signf(x), 0.0, 0.0)
	_add_mesh(_quad_mesh([Vector3(x, y0, -h), Vector3(x, y0, h), Vector3(x, y1, h), Vector3(x, y1, -h)], n), material)

## A rectangle on an end face, from x0 to x1 and y0 to y1.
func _rect(z: float, end: float, x0: float, x1: float, y0: float, y1: float, material: Material) -> void:
	var n := Vector3(0.0, 0.0, end)
	_add_mesh(_quad_mesh([Vector3(x0, y0, z), Vector3(x1, y0, z), Vector3(x1, y1, z), Vector3(x0, y1, z)], n), material)

## A band of an end face between x0 and x1: flat bottom at y0, top following
## the roof. Never crosses a junction, so it is a convex polygon.
func _band(z: float, end: float, x0: float, x1: float, y0: float, material: Material) -> void:
	var pts: Array[Vector3] = [Vector3(x0, y0, z), Vector3(x1, y0, z)]
	var top: Array[float] = [x1]
	if x0 < 0.0 and x1 > 0.0:
		top.append(0.0)
	top.append(x0)
	for x in top:
		pts.append(Vector3(x, _top_at(x, x0, x1), z))
	_add_mesh(_polygon_mesh(pts, Vector3(0.0, 0.0, end)), material)
	siding_pieces += 1

## The roof height over a face piece: on the wing slope or the central one
## according to which side of the junction the piece lies, so the value at the
## junction is the piece's own side.
func _top_at(x: float, x0: float, x1: float) -> float:
	var jn := junction()
	var mid := (x0 + x1) / 2.0
	if absf(mid) > jn:
		return Profile.roof_y(x, width)
	# Central pieces: clamp so a point on the junction takes the central eave.
	return Profile.roof_y(clampf(x, -jn + 0.0001, jn - 0.0001), width)

## A red band TRIM_H tall under the roofline given as (x, y) points.
func _trim(z: float, end: float, line: Array) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := Vector3(0.0, 0.0, end)
	for i in line.size() - 1:
		var a: Vector2 = line[i]
		var b: Vector2 = line[i + 1]
		_tri_quad(st, Vector3(a.x, a.y - TRIM_H, z), Vector3(b.x, b.y - TRIM_H, z), Vector3(b.x, b.y, z), Vector3(a.x, a.y, z), n)
	_add_mesh(st.commit(), _red)

func _post(at: Vector3, height: float) -> void:
	var m := _box(at + Vector3(0.0, height / 2.0, 0.0), Vector3(POST, height, POST), _wood, true)
	posts.append(m)

## The roofs, as three separate sections (D-129): the main middle roof (both
## slopes, one mesh) and a wing roof each side, which stands STEP below the
## middle roof's eave with a siding riser between them, as in the photo. Each
## has a dark underside (what you see from inside), and the low edges get a red
## fascia: the wings' outer edges and the middle roof's eaves over the step.
func _build_roofs() -> void:
	var half := width / 2.0
	var jn := junction()
	var z0 := -depth / 2.0 - OVERHANG
	var z1 := depth / 2.0 + OVERHANG
	var under := SurfaceTool.new()
	under.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The middle: ridge to eave on each side, with the east and west crops.
	var middle := MeshInstance3D.new()
	middle.name = "RoofMiddle"
	var mesh := ArrayMesh.new()
	for side in [1.0, -1.0]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_roof_slab(st, under, Vector3(0.0, Profile.RIDGE, 0.0), Vector3(side * jn, Profile.EAVE, 0.0), 0.0, ROOF_SPLIT, z0, z1)
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _roof_material(side))
	middle.mesh = mesh
	add_child(middle)
	# Each wing: high edge at the middle's riser, low edge at the outer wall.
	for side in [1.0, -1.0]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_roof_slab(st, under, Vector3(side * jn, Profile.WING_HIGH, 0.0), Vector3(side * half, Profile.WING_LOW, 0.0), ROOF_SPLIT, 1.0, z0, z1)
		var wing := MeshInstance3D.new()
		wing.name = "RoofWing_%s" % ("East" if side > 0.0 else "West")
		wing.mesh = st.commit()
		wing.material_override = _roof_material(side)
		add_child(wing)
		# Red fascia on the wing's outer edge, and under the middle roof's eave.
		_fascia(side * half, Profile.WING_LOW, side, z0, z1)
		_fascia(side * jn, Profile.EAVE, side, z0, z1)
	var under_mesh := MeshInstance3D.new()
	under_mesh.name = "RoofUnderside"
	under_mesh.mesh = under.commit()
	under_mesh.material_override = _under
	add_child(under_mesh)

func _roof_material(side: float) -> StandardMaterial3D:
	var rm := StandardMaterial3D.new()
	rm.albedo_texture = ROOF_EAST if side > 0.0 else ROOF_WEST
	rm.roughness = 0.7
	rm.cull_mode = BaseMaterial3D.CULL_DISABLED
	return rm

## One roof slope from `a` (high) to `b` (low), z0 to z1 long: the top into
## `top` with the crop's v running from `va` to `vb`, the underside (ROOF_T
## lower) into `under`.
func _roof_slab(top: SurfaceTool, under: SurfaceTool, a: Vector3, b: Vector3, va: float, vb: float, z0: float, z1: float) -> void:
	var pa := Vector3(a.x, a.y, z0)
	var pb := Vector3(b.x, b.y, z0)
	var pc := Vector3(b.x, b.y, z1)
	var pd := Vector3(a.x, a.y, z1)
	var n := (pb - pa).cross(pd - pa).normalized()
	if n.y < 0.0:
		n = -n
	_tri_quad_uv(top, pa, pb, pc, pd, n, Vector2(0.0, va), Vector2(0.0, vb), Vector2(1.0, vb), Vector2(1.0, va))
	var d := Vector3(0.0, -ROOF_T, 0.0)
	_tri_quad(under, pa + d, pb + d, pc + d, pd + d, -n)

## A red band under a roof's low edge at x, facing `side`.
func _fascia(x: float, y: float, side: float, z0: float, z1: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_tri_quad(st, Vector3(x, y - ROOF_T - 0.05, z0), Vector3(x, y - ROOF_T - 0.05, z1), Vector3(x, y, z1), Vector3(x, y, z0), Vector3(side, 0.0, 0.0))
	_add_mesh(st.commit(), _red)

func _quad_mesh(p: Array, n: Vector3) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_tri_quad(st, p[0], p[1], p[2], p[3], n)
	return st.commit()

## A convex polygon, fan-triangulated from its first point.
func _polygon_mesh(pts: Array[Vector3], n: Vector3) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1, pts.size() - 1):
		_tri(st, pts[0], pts[i], pts[i + 1], n, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
	return st.commit()

## One triangle whose front face (clockwise in Godot) looks along `n`. The
## materials are double sided, and a back face gets its normal flipped, so
## the winding has to agree with the normal or the lighting is upside down.
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b
		b = c
		c = t
		var tu := ub
		ub = uc
		uc = tu
	for pair in [[a, ua], [b, ub], [c, uc]]:
		st.set_normal(n)
		st.set_uv(pair[1])
		st.add_vertex(pair[0])

func _tri_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	_tri(st, a, b, c, n, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
	_tri(st, a, c, d, n, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)

func _tri_quad_uv(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2) -> void:
	_tri(st, a, b, c, n, ua, ub, uc)
	_tri(st, a, c, d, n, ua, uc, ud)

func _add_mesh(mesh: Mesh, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	add_child(mi)
	return mi

func _box(pos: Vector3, size: Vector3, material: Material, collide: bool) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	add_child(mi)
	if collide:
		var shape := BoxShape3D.new()
		shape.size = size
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position = pos
		_body.add_child(cs)
	return mi
