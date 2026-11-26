extends Node3D
## The front of the main House (D-199), after the owner's drone photos
## (Downloads/RCR - Main House Front): the covered porch on the east wall, with
## the white front door in the middle of it.
##
## Like the back yard (house_backyard.gd) it builds in the House's own frame
## (building_shell.gd's `frame_for`: +x east-ish, +z south-ish, the front wall at
## x = +width / 2). It adds:
##  - a low concrete porch slab along the front, `REACH` deep;
##  - two steps down in front of the door;
##  - six white posts under a shallow porch roof of dark shingles with a white
##    fascia, placed as in the photo (`POST_ZS`).
## The windows and the pale blue siding on that wall come from the House's
## building_shell node (`windows`, `siding`), as on the back.
##
## The slab and steps are visual only (the slab 5 cm proud of the ground, the steps lower), so
## the player walks straight over them to the door; the posts are solid.

const Shell := preload("res://scripts/building_shell.gd")

## Where the front door is along the wall, z in the House's frame (the House
## shell's `front door`, u 0.637 of a 14.24 m wall), and the steps' width.
const DOOR_Z := 1.95
const STEP_WIDTH := 1.8
## The six posts, z in the House's frame, measured off the drone photo from the
## door (about 61 px a metre on the wall; south, on your left as you face the
## house, is +z). The photo's porch reaches 4.5 m north of the door and, south of
## it, to the end of the wall; the southmost post is pulled in to stand on it.
const POST_ZS := [7.0, 5.9, 3.6, 1.1, -1.3, -4.1]
## The slab's north end; its south end is the wall's own.
const SPAN_NORTH := -4.6
const REACH := 2.3
const SLAB := 0.05
const STEP_TREAD := 0.35
const POST := 0.13
const POST_TOP := 2.4
const ROOF_T := 0.12
const FASCIA := 0.2
const POST_COLOR := Color(0.95, 0.95, 0.93)
const SLAB_COLOR := Color(0.66, 0.50, 0.43)
const STEP_COLOR := Color(0.55, 0.50, 0.46)
const ROOF_COLOR := Color(0.24, 0.25, 0.29)
## The concrete apron in front of the garage doors, in the garage's own frame:
## as wide as the garage plus a little, `APRON_REACH` out from its north wall.
const APRON_REACH := 6.5
const APRON_MARGIN := 0.6
const APRON_TOP := 0.04
const APRON_COLOR := Color(0.62, 0.61, 0.58)

var wall_x := 5.885
var wall_len := 14.24
var wall_h := 2.7
var _body: StaticBody3D

func _ready() -> void:
	var house := get_node_or_null("../House") as Node3D
	if house == null:
		push_warning("house_porch: no House under Buildings")
		return
	global_transform = Shell.frame_for(house)
	var b := house.global_transform.basis
	wall_x = b.x.length() / 2.0
	wall_len = b.z.length()
	wall_h = b.y.length()
	_body = StaticBody3D.new()
	_body.name = "Body"
	add_child(_body)
	_build_slab()
	_build_steps()
	_build_posts()
	_build_roof()
	_build_apron()

## The slab's rectangle in the House's (x, z), from `SPAN_NORTH` to the south
## end of the wall.
static func slab_rect(wall: float, length: float) -> Rect2:
	return Rect2(wall, SPAN_NORTH, REACH, length / 2.0 - SPAN_NORTH)

## The two steps, top one first, in the House's (x, z): each reaches a tread
## further out than the one above and is as wide as `STEP_WIDTH`.
static func step_rects(wall: float, length: float) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for k in 2:
		out.append(Rect2(wall + REACH + k * STEP_TREAD, DOOR_Z - STEP_WIDTH / 2.0, STEP_TREAD, STEP_WIDTH))
	return out

## Post positions, z in the House's frame.
static func post_zs() -> PackedFloat32Array:
	return PackedFloat32Array(POST_ZS)

func _material(color: Color, rough := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m

func _box(node_name: String, centre: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = centre
	add_child(mi)
	return mi

func _build_slab() -> void:
	var r := slab_rect(wall_x, wall_len)
	var c := r.get_center()
	_box("PorchSlab", Vector3(c.x, SLAB / 2.0, c.y), Vector3(r.size.x, SLAB, r.size.y), _material(SLAB_COLOR))

func _build_steps() -> void:
	var rects := step_rects(wall_x, wall_len)
	for k in rects.size():
		var r := rects[k]
		var h := SLAB * float(2 - k) / 3.0
		var c := r.get_center()
		_box("PorchStep%d" % (k + 1), Vector3(c.x, h / 2.0, c.y), Vector3(r.size.x, h, r.size.y), _material(STEP_COLOR))

func _build_posts() -> void:
	var m := _material(POST_COLOR, 0.6)
	var x := wall_x + REACH - POST
	var h := POST_TOP - SLAB
	var i := 0
	for z in post_zs():
		i += 1
		_box("Post%d" % i, Vector3(x, SLAB + h / 2.0, z), Vector3(POST, h, POST), m)
		var shape := BoxShape3D.new()
		shape.size = Vector3(POST, h, POST)
		var cs := CollisionShape3D.new()
		cs.name = "PostShape%d" % i
		cs.shape = shape
		cs.position = Vector3(x, SLAB + h / 2.0, z)
		_body.add_child(cs)

## A shallow shingle roof from the House's eave out over the posts, falling
## toward the yard, with a white fascia along its edge.
func _build_roof() -> void:
	var r := slab_rect(wall_x, wall_len)
	var fall := atan2(wall_h - POST_TOP, REACH)
	var run := REACH / cos(fall)
	var roof := _box("PorchRoof", Vector3(wall_x + REACH / 2.0, (wall_h + POST_TOP) / 2.0 + ROOF_T / 2.0, r.get_center().y),
			Vector3(run, ROOF_T, r.size.y), _material(ROOF_COLOR, 0.95))
	roof.rotation.z = -fall
	_box("PorchFascia", Vector3(wall_x + REACH, POST_TOP + ROOF_T / 2.0 - FASCIA / 2.0 + 0.04, r.get_center().y),
			Vector3(0.05, FASCIA, r.size.y), _material(POST_COLOR, 0.6))

## The concrete in front of the garage's two doors, in the garage's own frame
## (it leans a little from the House's). Visual only.
func _build_apron() -> void:
	var garage := get_node_or_null("../House Garage") as Node3D
	if garage == null:
		return
	var b := garage.global_transform.basis
	var half_w := b.x.length() / 2.0 + APRON_MARGIN
	var half_d := b.z.length() / 2.0
	var apron := Node3D.new()
	apron.name = "GarageApron"
	add_child(apron)
	apron.global_transform = Shell.frame_for(garage)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(half_w * 2.0, APRON_TOP, APRON_REACH)
	var mi := MeshInstance3D.new()
	mi.name = "Concrete"
	mi.mesh = mesh
	mi.material_override = _material(APRON_COLOR, 0.95)
	mi.position = Vector3(0.0, APRON_TOP / 2.0, -half_d - APRON_REACH / 2.0)
	apron.add_child(mi)
