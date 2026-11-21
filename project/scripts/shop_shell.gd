extends Node3D
## The walk-in Shop (D-98). The solid placeholder box (`../Shop`, still the map's
## footprint) is hidden and its collision disabled in main.tscn; this node
## builds a hollow replacement over the same footprint: blue corrugated walls
## with door and window openings, a floor, an inside ceiling and gable ends
## under the existing roof planes, three working doors and a concrete pad.
##
## Everything is built in the box's own frame (+X east, +Z south, origin at
## the footprint centre on the ground), so the slight rotation of the real
## building carries through. Door positions are given in world X / Z — the
## numbers read off the map grid (D-97) — and converted into that frame.

const WallLayout := preload("res://scripts/wall_layout.gd")
const Corrugated := preload("res://scripts/corrugated.gd")
const DoorScript := preload("res://scripts/shop_door.gd")

const WALL_T := 0.15
const SKIN_T := 0.03
const FLOOR_TOP := 0.05  # above the 0.03-0.04 ortho patches

## World X / Z of the main door's centre on the east wall; it hinges on the
## north edge (the right, seen from outside) and swings inward.
@export var main_door_world := Vector2(210.2, -50.6)
const MAIN_DOOR_W := 0.91
const MAIN_DOOR_H := 2.1

## World X / Z of the roll-up garage door's centre on the south wall.
@export var garage_world := Vector2(207.3, -47.0)
const GARAGE_W := 3.0
const GARAGE_H := 2.7
const PAD_W := 4.0
const PAD_DEPTH := 5.0

## World X / Z of the far-right (south) edge of the sliding barn door on the
## west wall, seen from outside. It slides north until even with the north wall.
@export var barn_door_world := Vector2(194.5, -50.6)
const BARN_LEAF_W := 3.2
const BARN_LEAF_H := 3.5
const BARN_OPEN_W := 3.0
const BARN_OPEN_H := 3.4

const WINDOW_W := 1.5
const WINDOW_H := 1.1
const WINDOW_SILL := 1.0

var width := 1.0
var depth := 1.0
var height := 1.0
var rise := 3.0

var _walls: StaticBody3D
var _skin_material: StandardMaterial3D
var _liner_material: StandardMaterial3D
var _trim_material: StandardMaterial3D
var _concrete_material: StandardMaterial3D
var _glass_material: StandardMaterial3D

func _ready() -> void:
	add_to_group("front_door_spot")
	var shop := get_node("../Shop") as Node3D
	var b := shop.global_transform.basis
	width = b.x.length()
	depth = b.z.length()
	height = b.y.length()
	var x_axis := (b.x / width).normalized()
	# Same yaw as the box (re-orthogonalised: its basis is slightly skewed), but unscaled and sitting on the ground.
	global_transform = Transform3D(
			Basis(x_axis, Vector3.UP, x_axis.cross(Vector3.UP)),
			Vector3(shop.global_position.x, 0.0, shop.global_position.z))
	_make_materials()
	_walls = StaticBody3D.new()
	_walls.name = "Walls"
	add_child(_walls)
	_build()
	# The gable triangles are built by their own scripts in _ready, which runs
	# after this node's; re-skin them once they exist.
	_skin_gables.call_deferred()

## The building this shell belongs to, for the map's teleport (D-118).
func spot_building() -> String:
	return "Shop"

## World position `clearance` metres outside the main door. The main door is
## on the east wall (see main_door_world and _build), so the offset is along +X;
## test_map_scene.gd pins the result to the door.
func front_door_spot(clearance: float) -> Variant:
	var along := to_local(Vector3(main_door_world.x, 0, main_door_world.y)).z
	return to_global(Vector3(width / 2.0 + clearance, 0.0, along))

func _skin_gables() -> void:
	for gable_name in ["Shop_Gable_West", "Shop_Gable_East"]:
		var gable := get_node_or_null("../" + gable_name) as MeshInstance3D
		if gable:
			gable.material_override = _skin_material

func _make_materials() -> void:
	_skin_material = Corrugated.material()

	_liner_material = StandardMaterial3D.new()
	_liner_material.albedo_color = Color(0.86, 0.87, 0.86)
	_liner_material.roughness = 0.6
	_liner_material.metallic = 0.2
	_liner_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	_trim_material = StandardMaterial3D.new()
	_trim_material.albedo_color = Color(0.93, 0.93, 0.91)
	_trim_material.roughness = 0.5
	_trim_material.metallic = 0.3

	_concrete_material = StandardMaterial3D.new()
	_concrete_material.albedo_color = Color(0.56, 0.56, 0.54)
	_concrete_material.roughness = 0.95

	_glass_material = StandardMaterial3D.new()
	_glass_material.albedo_color = Color(0.7, 0.85, 0.95, 0.3)
	_glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass_material.roughness = 0.05
	_glass_material.metallic = 0.1

func _build() -> void:
	var half_w := width / 2.0
	var half_d := depth / 2.0
	var main_c := to_local(Vector3(main_door_world.x, 0, main_door_world.y)).z
	var garage_c := to_local(Vector3(garage_world.x, 0, garage_world.y)).x
	var barn_south := to_local(Vector3(barn_door_world.x, 0, barn_door_world.y)).z

	# Windows share the stretch of east wall between the door and the north
	# corner, with equal gaps at both ends and between them.
	var door_north := main_c - MAIN_DOOR_W / 2.0 - 0.02
	var stretch := door_north - (-half_d + WALL_T)
	var gap := (stretch - 2.0 * WINDOW_W) / 3.0
	var window_cs: Array[float] = []
	for i in 2:
		window_cs.append(door_north - gap * (i + 1) - WINDOW_W * (i + 0.5))

	var east: Array = [{c = main_c, w = MAIN_DOOR_W + 0.04, y0 = 0.0, y1 = MAIN_DOOR_H}]
	for wc in window_cs:
		east.append({c = wc, w = WINDOW_W, y0 = WINDOW_SILL, y1 = WINDOW_SILL + WINDOW_H})
	_build_wall(Vector3.RIGHT, east)
	_build_wall(Vector3.BACK, [{c = garage_c, w = GARAGE_W, y0 = 0.0, y1 = GARAGE_H}])
	# The leaf is wider than the opening so it overlaps the wall on both sides.
	_build_wall(Vector3.LEFT, [{c = barn_south - 0.1 - BARN_OPEN_W / 2.0, w = BARN_OPEN_W, y0 = 0.0, y1 = BARN_OPEN_H}])
	_build_wall(Vector3.FORWARD, [])

	for wc in window_cs:
		_build_window(wc)
	_build_corner_trim()
	_build_floor_and_pad(garage_c)
	_build_ceiling()
	_build_lights()

	# East door: hinge on the north edge, leaf runs south, swings inward (-X).
	_add_door(Vector3(half_w - WALL_T / 2.0, 0, main_c - MAIN_DOOR_W / 2.0 - 0.02), -90.0, {
		kind = DoorScript.Kind.SWING, width = MAIN_DOOR_W, height = MAIN_DOOR_H - 0.02,
		label = "door", window_pane = true, swing_time = 0.8})
	# South wall: origin at the opening's east edge, leaf extends west.
	_add_door(Vector3(garage_c + GARAGE_W / 2.0, 0, half_d - WALL_T / 2.0), 180.0, {
		kind = DoorScript.Kind.ROLLUP, width = GARAGE_W, height = GARAGE_H,
		label = "garage door", color = Color(0.9, 0.9, 0.88), swing_time = 1.2})
	# West wall: origin at the leaf's south edge, hung outside, slides north
	# (local +X) until its far edge is even with the north wall.
	var leaf_north := barn_south - BARN_LEAF_W
	_add_door(Vector3(-half_w, 0, barn_south), 90.0, {
		kind = DoorScript.Kind.SLIDE, width = BARN_LEAF_W, height = BARN_LEAF_H,
		thickness = 0.06, offset_z = -0.06 / 2.0 - 0.01, slide = leaf_north + half_d,
		label = "barn door", ribbed = true, color = Color(0.9, 0.93, 1.0), swing_time = 1.2})

func _add_door(pos: Vector3, yaw_deg: float, props: Dictionary) -> void:
	var door := DoorScript.new()
	for key in props:
		door.set(key, props[key])
	door.position = pos
	door.rotation_degrees.y = yaw_deg
	match props.label:
		"door": door.name = "MainDoor"
		"garage door": door.name = "GarageDoor"
		_: door.name = "BarnDoor"
	add_child(door)

## One wall, cut around `openings`, on the side `outward` (a unit axis vector).
func _build_wall(outward: Vector3, openings: Array) -> void:
	var along_east_west := absf(outward.x) > 0.5
	var length := depth if along_east_west else width
	var offset := (width if along_east_west else depth) / 2.0
	for r in WallLayout.pieces(length, height, openings):
		var along := r.position.x + r.size.x / 2.0
		var y := r.position.y + r.size.y / 2.0
		var body_t := WALL_T - SKIN_T
		var body_off := offset - SKIN_T - body_t / 2.0
		var skin_off := offset - SKIN_T / 2.0
		if along_east_west:
			_add_box(Vector3(outward.x * body_off, y, along), Vector3(body_t, r.size.y, r.size.x), _liner_material, true)
			_add_box(Vector3(outward.x * skin_off, y, along), Vector3(SKIN_T, r.size.y, r.size.x), _skin_material, true)
		else:
			_add_box(Vector3(along, y, outward.z * body_off), Vector3(r.size.x, r.size.y, body_t), _liner_material, true)
			_add_box(Vector3(along, y, outward.z * skin_off), Vector3(r.size.x, r.size.y, SKIN_T), _skin_material, true)

func _build_window(c: float) -> void:
	var x := width / 2.0 - WALL_T / 2.0
	var y := WINDOW_SILL + WINDOW_H / 2.0
	var f := 0.06
	# Frame: four bars around the opening, proud of the skin by a little.
	_add_box(Vector3(x, WINDOW_SILL + f / 2.0, c), Vector3(WALL_T + 0.04, f, WINDOW_W + 2 * f), _trim_material, false)
	_add_box(Vector3(x, WINDOW_SILL + WINDOW_H - f / 2.0, c), Vector3(WALL_T + 0.04, f, WINDOW_W + 2 * f), _trim_material, false)
	for side in [-1.0, 1.0]:
		_add_box(Vector3(x, y, c + side * (WINDOW_W / 2.0 - f / 2.0)), Vector3(WALL_T + 0.04, WINDOW_H, f), _trim_material, false)
	_add_box(Vector3(x, y, c), Vector3(0.02, WINDOW_H - 2 * f, WINDOW_W - 2 * f), _glass_material, false, false)
	# Collision spans the whole wall thickness so nothing can clip through.
	var glass_shape := BoxShape3D.new()
	glass_shape.size = Vector3(WALL_T, WINDOW_H - 2 * f, WINDOW_W - 2 * f)
	var glass_cs := CollisionShape3D.new()
	glass_cs.shape = glass_shape
	glass_cs.position = Vector3(x, y, c)
	_walls.add_child(glass_cs)
	# Centre mullion splits the pane into two sashes.
	_add_box(Vector3(x, y, c), Vector3(WALL_T + 0.02, WINDOW_H - 2 * f, 0.04), _trim_material, false)

func _build_corner_trim() -> void:
	var t := 0.12
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_add_box(Vector3(sx * (width / 2.0 + 0.01 - t / 2.0 + 0.03), height / 2.0, sz * (depth / 2.0 + 0.01 - t / 2.0 + 0.03)),
					Vector3(t, height, t), _trim_material, false)
	# Low base trim, like the kick plate on a metal building.
	for sz in [-1.0, 1.0]:
		_add_box(Vector3(0, 0.08, sz * (depth / 2.0 + 0.01)), Vector3(width, 0.16, 0.04), _trim_material, false)
	for sx in [-1.0, 1.0]:
		_add_box(Vector3(sx * (width / 2.0 + 0.01), 0.08, 0), Vector3(0.04, 0.16, depth), _trim_material, false)

func _build_floor_and_pad(garage_c: float) -> void:
	# Visual only: the player walks on the ground's own collision, so there is
	# no lip at the doorways.
	_add_box(Vector3(0, FLOOR_TOP / 2.0, 0), Vector3(width - 2 * WALL_T, FLOOR_TOP, depth - 2 * WALL_T), _concrete_material, false)
	_add_box(Vector3(garage_c, FLOOR_TOP / 2.0, depth / 2.0 + PAD_DEPTH / 2.0 - WALL_T),
			Vector3(PAD_W, FLOOR_TOP, PAD_DEPTH), _concrete_material, false)

func _build_ceiling() -> void:
	var hw := width / 2.0 - WALL_T
	var hd := depth / 2.0
	var h := height
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Underside of each roof slope, nudged down so it never z-fights the roof.
	var n_north := Vector3(0, -hd, -rise).normalized() * -1.0
	var n_south := Vector3(0, -hd, rise).normalized() * -1.0
	var drop := -0.04
	_quad(st, Vector3(-hw, h + drop, -hd), Vector3(hw, h + drop, -hd), Vector3(hw, h + rise + drop, 0), Vector3(-hw, h + rise + drop, 0), n_north)
	_quad(st, Vector3(-hw, h + rise + drop, 0), Vector3(hw, h + rise + drop, 0), Vector3(hw, h + drop, hd), Vector3(-hw, h + drop, hd), n_south)
	# Inside faces of the two gable ends, facing the middle of the room.
	for sx in [-1.0, 1.0]:
		var n := Vector3(sx, 0, 0)
		st.set_normal(n); st.add_vertex(Vector3(sx * hw, h, -hd))
		st.set_normal(n); st.add_vertex(Vector3(sx * hw, h, hd))
		st.set_normal(n); st.add_vertex(Vector3(sx * hw, h + rise + drop, 0))
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Ceiling"
	mesh_instance.mesh = st.commit()
	mesh_instance.material_override = _liner_material
	add_child(mesh_instance)

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	for p in [a, b, c, a, c, d]:
		st.set_normal(n)
		st.add_vertex(p)

func _build_lights() -> void:
	for x in [-width / 4.0, width / 4.0]:
		var light := OmniLight3D.new()
		light.position = Vector3(x, height + rise * 0.55, 0)
		light.omni_range = width * 0.7
		light.light_energy = 1.1
		light.light_color = Color(1.0, 0.96, 0.88)
		light.shadow_enabled = false
		add_child(light)

func _add_box(pos: Vector3, size: Vector3, material: Material, collide: bool, cast_shadow := true) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	if not cast_shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	if collide:
		var shape := BoxShape3D.new()
		shape.size = size
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position = pos
		_walls.add_child(cs)
