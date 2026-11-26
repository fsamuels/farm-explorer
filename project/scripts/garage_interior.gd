extends Node3D
## The House Garage's inside (D-201), after the "Rick n Morty Garage Cel Shaded"
## room (moonvrhome.com, by Elin and Vince Crusty): a cluttered mad-scientist
## workshop drawn like a cartoon, every prop with a thick black outline.
##
## Built in the garage shell's frame (building_shell.gd `frame_for`: x west to
## east, z north to south, y up). The shell gives the walls, the pitched wood
## ceiling, the floor, the wall paint and the two roll-up doors in the north
## end; this node adds, west wall first (where the photos' long counter is):
##  - the long counter of dark navy cabinets with hex knobs and one door hanging
##    open, a lilac top, and on it the parts cabinet, the three-drawer chest, a
##    pickle, a mug of pencils, a hammer and screwdriver, tripod flasks of
##    coloured liquid, the tan electronics box and the green radio;
##  - above it the pegboard (gears, hooks, spools, a fire extinguisher, two
##    posters), the big corkboard of notes joined by red-pinned string, a wall
##    clock and a mountain calendar;
##  - two gas cylinders in the north-west corner, a free-standing work table
##    with a vise, a clipboard and a box under it, the utility sink in the
##    south-west corner;
##  - on the east wall the wood stud frame, the slatted shutter, an orange lamp
##    on a bent pipe, the metal shelving ("TIME TRAVEL STUFF", an eyeball, a
##    spiked mace, a crown, a monster mask, a jar), a trash bucket, a shovel and
##    a broom, and the washer and dryer;
##  - heavy grey beams and two fluorescent fixtures overhead, puddles, a sock
##    and a yellow note on the floor.
##
## The stairs hatch (bunker.gd), the two north doors and the two doorways in the
## south wall are kept clear: `colliders` lists every solid prop's footprint so
## a test can check that.

const Shell := preload("res://scripts/building_shell.gd")

@export var building_name := "House Garage"

const FLOOR_Y := Shell.FLOOR_TOP
## How far the black outline stands out round a prop, metres.
const INK := 0.014
const COUNTER_H := 0.91
const COUNTER_D := 0.62
const COUNTER_Z0 := -3.1
const COUNTER_Z1 := 3.0
const TABLE_AT := Vector2(-1.5, -1.0)
const TABLE_SIZE := Vector2(0.8, 1.8)
const BEAM_Y := 2.45
const BEAM_ZS := [-2.2, 0.1, 2.4]

const NAVY := Color(0.2, 0.25, 0.3)
const CAB_DOOR := Color(0.3, 0.36, 0.37)
const LILAC := Color(0.8, 0.8, 0.9)
const OLIVE := Color(0.5, 0.53, 0.42)
const WOOD := Color(0.5, 0.38, 0.29)
const WOOD_DARK := Color(0.32, 0.26, 0.2)
const BOARD := Color(0.72, 0.65, 0.45)
const CREAM := Color(0.84, 0.86, 0.68)
const GREY := Color(0.55, 0.57, 0.55)
const RED := Color(0.72, 0.22, 0.2)
## Every flat colour a prop can wear, by name.
const PALETTE := {
	navy = NAVY, cab_door = CAB_DOOR, lilac = LILAC, olive = OLIVE, wood = WOOD, wood_dark = WOOD_DARK,
	board = BOARD, cream = CREAM, grey = GREY, red = RED, knob = Color(0.66, 0.69, 0.68),
	paper = Color(0.9, 0.88, 0.8), green = Color(0.35, 0.6, 0.25), tank = Color(0.55, 0.62, 0.65),
	steel = Color(0.5, 0.52, 0.52), black = Color(0.06, 0.06, 0.07), orange = Color(0.93, 0.55, 0.2),
	yellow = Color(0.93, 0.78, 0.25), glass = Color(0.72, 0.85, 0.82), pink = Color(0.85, 0.55, 0.65),
	white = Color(0.93, 0.93, 0.9), beam = Color(0.56, 0.57, 0.53), vise = Color(0.55, 0.3, 0.17),
	pale = Color(0.8, 0.82, 0.74), puddle = Color(0.62, 0.66, 0.6), mask = Color(0.3, 0.55, 0.3),
	jar = Color(0.5, 0.52, 0.3), bucket = Color(0.3, 0.34, 0.36),
}

var half_x := 4.0
var half_z := 3.8
var wall_h := 2.7
## Plan footprints (x, z in the garage's frame) of every solid prop.
var colliders: Array[Rect2] = []
## Named props, for the tests.
var props := {}
var _body: StaticBody3D
var _mats := {}
var _ink: StandardMaterial3D
## Primitive meshes already made, by shape and size, so props share them; and
## the outline meshes made from them.
var _meshes := {}
var _outlines := {}

func _ready() -> void:
	var box := get_node_or_null("../" + building_name) as Node3D
	if box == null:
		push_warning("garage_interior: no building named '%s'" % building_name)
		return
	global_transform = Shell.frame_for(box)
	half_x = box.global_transform.basis.x.length() / 2.0 - Shell.WALL_T
	half_z = box.global_transform.basis.z.length() / 2.0 - Shell.WALL_T
	wall_h = box.global_transform.basis.y.length()
	_body = StaticBody3D.new()
	_body.name = "Solid"
	add_child(_body)
	_ink = StandardMaterial3D.new()
	_ink.albedo_color = Color(0.03, 0.03, 0.04)
	_ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ink.cull_mode = BaseMaterial3D.CULL_FRONT
	_make_materials()
	_build_counter()
	_build_counter_tops()
	_build_wall_boards()
	_build_tanks()
	_build_table()
	_build_sink()
	_build_east_wall()
	_build_rack()
	_build_laundry()
	_build_ceiling()
	_build_litter()

# --- materials and primitives ----------------------------------------------

func _mat(color: Color, rough := 0.9, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metallic
	return m

func _make_materials() -> void:
	for key: String in PALETTE:
		_mats[key] = _mat(PALETTE[key], 0.85)
	var tube := _mat(Color(0.95, 0.97, 1.0), 0.3)
	tube.emission_enabled = true
	tube.emission = Color(0.9, 0.95, 1.0)
	tube.emission_energy_multiplier = 1.6
	_mats.tube = tube
	var lamp := _mat(Color(0.93, 0.55, 0.2), 0.7)
	lamp.emission_enabled = true
	lamp.emission = Color(1.0, 0.6, 0.2)
	lamp.emission_energy_multiplier = 0.5
	_mats.lamp = lamp

func _m(key: String) -> StandardMaterial3D:
	return _mats[key]

## A slightly larger copy of a primitive mesh, for the outline (its back faces
## are drawn in black behind the prop).
func _expand(mesh: Mesh) -> Mesh:
	if _outlines.has(mesh):
		return _outlines[mesh]
	var out := _expand_new(mesh)
	_outlines[mesh] = out
	return out

func _expand_new(mesh: Mesh) -> Mesh:
	if mesh is BoxMesh:
		var b := BoxMesh.new()
		b.size = (mesh as BoxMesh).size + Vector3.ONE * INK * 2.0
		return b
	if mesh is CylinderMesh:
		var c := mesh as CylinderMesh
		var e := CylinderMesh.new()
		e.top_radius = c.top_radius + INK if c.top_radius > 0.0 else 0.0
		e.bottom_radius = c.bottom_radius + INK if c.bottom_radius > 0.0 else 0.0
		e.height = c.height + INK * 2.0
		e.radial_segments = c.radial_segments
		e.rings = 1
		return e
	var s := mesh as SphereMesh
	var o := SphereMesh.new()
	o.radius = s.radius + INK
	o.height = s.height + INK * 2.0
	o.radial_segments = s.radial_segments
	o.rings = s.rings
	return o

func _add(node_name: String, mesh: Mesh, pos: Vector3, mat: Material, ink: bool, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	(parent if parent else self).add_child(mi)
	if ink:
		var o := MeshInstance3D.new()
		o.name = "Ink"
		o.mesh = _expand(mesh)
		o.material_override = _ink
		o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_child(o)
	return mi

func _box(node_name: String, pos: Vector3, size: Vector3, key: String, solid := false, ink := true, parent: Node3D = null) -> MeshInstance3D:
	var cache_key := "box%s" % size
	var mesh: BoxMesh = _meshes.get(cache_key)
	if mesh == null:
		mesh = BoxMesh.new()
		mesh.size = size
		_meshes[cache_key] = mesh
	var mi := _add(node_name, mesh, pos, _m(key), ink, parent)
	if solid:
		_collide(pos, size)
	return mi

func _cyl(node_name: String, pos: Vector3, radius: float, height: float, key: String, ink := true, top := -1.0, segments := 12) -> MeshInstance3D:
	var cache_key := "cyl%s/%s/%s/%s" % [radius, top, height, segments]
	var mesh: CylinderMesh = _meshes.get(cache_key)
	if mesh == null:
		mesh = CylinderMesh.new()
		mesh.bottom_radius = radius
		mesh.top_radius = radius if top < 0.0 else top
		mesh.height = height
		mesh.radial_segments = segments
		mesh.rings = 1
		_meshes[cache_key] = mesh
	return _add(node_name, mesh, pos, _m(key), ink)

func _ball(node_name: String, pos: Vector3, radius: float, key: String, ink := true) -> MeshInstance3D:
	var cache_key := "ball%s" % radius
	var mesh: SphereMesh = _meshes.get(cache_key)
	if mesh == null:
		mesh = SphereMesh.new()
		mesh.radius = radius
		mesh.height = radius * 2.0
		mesh.radial_segments = 12
		mesh.rings = 6
		_meshes[cache_key] = mesh
	return _add(node_name, mesh, pos, _m(key), ink)

func _collide(pos: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = pos
	_body.add_child(cs)
	colliders.append(Rect2(pos.x - size.x / 2.0, pos.z - size.z / 2.0, size.x, size.z))

## A flat picture on a wall: `facing` is the wall's outward normal's yaw in
## degrees (90 faces +x, -90 faces -x, 180 faces -z).
func _panel(node_name: String, tex: Texture2D, pos: Vector3, size: Vector2, facing: float) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = size
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.alpha_scissor_threshold = 0.5
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	var mi := _add(node_name, mesh, pos, m, false)
	mi.rotation_degrees.y = facing
	return mi

func _label(text: String, pos: Vector3, size: int, facing: float, color := Color(0.12, 0.1, 0.08)) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.0016
	l.modulate = color
	l.outline_size = 0
	l.position = pos
	l.rotation_degrees.y = facing
	add_child(l)
	return l

# --- the long counter ----------------------------------------------------------

func _build_counter() -> void:
	var wx := -half_x
	var len_z := COUNTER_Z1 - COUNTER_Z0
	var zc := (COUNTER_Z0 + COUNTER_Z1) / 2.0
	var h := COUNTER_H - 0.05
	_box("CounterBase", Vector3(wx + COUNTER_D / 2.0, FLOOR_Y + h / 2.0, zc), Vector3(COUNTER_D, h, len_z), "navy", true)
	var segs := int(round(len_z / 0.6))
	var seg_len := len_z / segs
	var face_x := wx + COUNTER_D + 0.012
	for i in segs:
		var z := COUNTER_Z0 + seg_len * (i + 0.5)
		for side in [-1.0, 1.0]:
			var dz: float = z + side * seg_len * 0.25
			var open: bool = i == 6 and side < 0.0
			var door := _box("CabDoor%d" % i, Vector3(face_x, FLOOR_Y + 0.46, dz), Vector3(0.024, 0.66, seg_len * 0.46), "cab_door", false, true)
			if open:
				# One door hangs open on its hinge, swung out into the room.
				door.position = Vector3(face_x + 0.17, FLOOR_Y + 0.46, dz - seg_len * 0.16)
				door.rotation_degrees.y = 70.0
				props["open_door"] = door
				continue
			var knob := _cyl("Knob%d" % i, Vector3(face_x + 0.02, FLOOR_Y + 0.7, dz - side * seg_len * 0.14), 0.022, 0.02, "knob", false, -1.0, 6)
			knob.rotation_degrees.z = 90.0
	# A double power outlet on the front of the cabinet run, as in the photos.
	_box("Outlet", Vector3(face_x + 0.01, FLOOR_Y + 0.78, COUNTER_Z0 + seg_len * 7.5), Vector3(0.02, 0.2, 0.09), "pale", false, true)
	for k in 2:
		_cyl("OutletHex%d" % k, Vector3(face_x + 0.025, FLOOR_Y + 0.82 - k * 0.08, COUNTER_Z0 + seg_len * 7.5), 0.025, 0.01, "steel", false, -1.0, 6).rotation_degrees.z = 90.0

func _build_counter_tops() -> void:
	var wx := -half_x
	var top_y := FLOOR_Y + COUNTER_H
	var len_z := COUNTER_Z1 - COUNTER_Z0
	_box("CounterTop", Vector3(wx + COUNTER_D / 2.0 + 0.03, top_y - 0.025, (COUNTER_Z0 + COUNTER_Z1) / 2.0), Vector3(COUNTER_D + 0.06, 0.05, len_z + 0.04), "lilac", false)
	var x := wx + 0.34
	# The parts cabinet: three columns of four small drawers.
	var cab := _box("PartsCabinet", Vector3(x, top_y + 0.16, -2.75), Vector3(0.3, 0.32, 0.8), "olive")
	for r in 4:
		for c in 3:
			_box("PartsDrawer", Vector3(x + 0.152, top_y + 0.05 + c * 0.1, -3.05 + r * 0.2 + 0.1), Vector3(0.01, 0.075, 0.16), "steel", false, false)
			_cyl("PartsKnob", Vector3(x + 0.162, top_y + 0.05 + c * 0.1, -3.05 + r * 0.2 + 0.1), 0.012, 0.01, "knob", false, -1.0, 6).rotation_degrees.z = 90.0
	props["parts_cabinet"] = cab
	# The three-drawer chest, a pickle, a mug of pencils, a hammer, a screwdriver.
	var chest := _box("Chest", Vector3(x, top_y + 0.11, -1.95), Vector3(0.32, 0.22, 0.5), "grey")
	for k in 3:
		_box("ChestDrawer", Vector3(x + 0.165, top_y + 0.04 + k * 0.07, -1.95), Vector3(0.01, 0.055, 0.44), "olive", false, false)
	props["chest"] = chest
	var pickle := _cyl("Pickle", Vector3(x + 0.1, top_y + 0.05, -1.5), 0.05, 0.28, "green", true, -1.0, 8)
	pickle.rotation_degrees.x = 90.0
	pickle.rotation_degrees.z = 12.0
	props["pickle"] = pickle
	_cyl("Mug", Vector3(x + 0.12, top_y + 0.06, -1.15), 0.045, 0.12, "pale")
	for k in 3:
		_cyl("Pencil", Vector3(x + 0.12 + (k - 1) * 0.014, top_y + 0.17, -1.15 + (k - 1) * 0.012), 0.006, 0.12, "yellow", false)
	var hammer := _box("HammerHandle", Vector3(x + 0.12, top_y + 0.015, -0.9), Vector3(0.03, 0.03, 0.26), "wood", false, false)
	hammer.rotation_degrees.y = 20.0
	_box("HammerHead", Vector3(x + 0.16, top_y + 0.03, -0.78), Vector3(0.12, 0.06, 0.05), "steel", false)
	var driver := _box("Screwdriver", Vector3(x + 0.14, top_y + 0.012, -1.05), Vector3(0.022, 0.022, 0.2), "red", false, false)
	driver.rotation_degrees.y = -12.0
	# Two tripods with flasks, a row of small flasks, the tan box and the radio.
	_tripod("Tripod1", Vector3(x + 0.04, top_y, -0.55), 0.55, "pink")
	for k in 4:
		var colour: String = ["yellow", "orange", "red", "glass"][k]
		_flask("SmallFlask%d" % k, Vector3(x + 0.12, top_y, -0.15 + k * 0.17), 0.07, colour)
	var box := _box("TanBox", Vector3(x, top_y + 0.17, 1.15), Vector3(0.42, 0.34, 0.7), "board", false)
	props["tan_box"] = box
	for k in 4:
		_box("BoxDigit", Vector3(x + 0.215, top_y + 0.07, 0.95 + k * 0.07), Vector3(0.01, 0.045, 0.045), "black", false, false)
	_cyl("BoxDial", Vector3(x + 0.22, top_y + 0.2, 1.3), 0.04, 0.02, "steel", false).rotation_degrees.z = 90.0
	_tripod("Tripod2", Vector3(x, top_y + 0.34, 1.15), 0.6, "glass")
	var radio := _box("Radio", Vector3(x, top_y + 0.1, 2.15), Vector3(0.34, 0.2, 0.72), "olive")
	props["radio"] = radio
	_box("RadioScreen", Vector3(x + 0.176, top_y + 0.13, 1.98), Vector3(0.01, 0.05, 0.14), "pale", false, false)
	_cyl("RadioDial", Vector3(x + 0.178, top_y + 0.1, 2.35), 0.045, 0.02, "steel").rotation_degrees.z = 90.0

## Three thin legs under a ring, a conical flask on top and a cork.
func _tripod(node_name: String, base: Vector3, height: float, liquid: String) -> void:
	for k in 3:
		var a := TAU * k / 3.0 + 0.4
		var leg := _box("%sLeg%d" % [node_name, k], base + Vector3(cos(a) * 0.06, height / 2.0, sin(a) * 0.06), Vector3(0.025, height, 0.025), "steel", false, false)
		leg.rotation = Vector3(-sin(a) * 0.12, 0.0, cos(a) * 0.12)
	_cyl(node_name + "Ring", base + Vector3(0, height, 0), 0.11, 0.025, "steel", false)
	_flask(node_name + "Flask", base + Vector3(0, height + 0.012, 0), 0.12, liquid)

## A conical flask: wide body, narrow neck, cork.
func _flask(node_name: String, base: Vector3, size: float, liquid: String) -> void:
	_cyl(node_name, base + Vector3(0, size * 0.5, 0), size * 0.62, size, liquid, true, size * 0.15)
	_cyl(node_name + "Neck", base + Vector3(0, size * 1.2, 0), size * 0.15, size * 0.55, "glass")
	_cyl(node_name + "Cork", base + Vector3(0, size * 1.55, 0), size * 0.17, size * 0.2, "wood", false)

# --- the west wall above the counter ------------------------------------------

func _build_wall_boards() -> void:
	var wx := -half_x + 0.04
	# Pegboard with a shelf of spools and the fire extinguisher on top.
	_panel("Pegboard", pegboard_texture(), Vector3(wx, 1.65, -2.3), Vector2(1.7, 0.95), 90.0)
	_box("PegboardEdge", Vector3(wx - 0.005, 1.65, -2.3), Vector3(0.012, 0.97, 1.72), "board", false, true)
	_box("SpoolShelf", Vector3(wx + 0.06, 2.17, -2.3), Vector3(0.14, 0.03, 1.7), "wood")
	for k in 3:
		_cyl("Spool%d" % k, Vector3(wx + 0.07, 2.24, -2.95 + k * 0.22), 0.04, 0.07, ["red", "yellow", "pale"][k], true)
	var ext := _cyl("Extinguisher", Vector3(wx + 0.08, 2.4, -1.65), 0.055, 0.34, "red")
	_cyl("ExtinguisherTop", Vector3(wx + 0.08, 2.6, -1.65), 0.025, 0.07, "black", false)
	props["extinguisher"] = ext
	for k in 4:
		var gear := _cyl("Gear%d" % k, Vector3(wx + 0.03, 1.45 + (k % 2) * 0.35, -2.9 + k * 0.38), 0.1 + 0.02 * (k % 3), 0.04, "steel", true, -1.0, 10)
		gear.rotation_degrees.z = 90.0
	_panel("PosterTarget", poster_texture(0), Vector3(wx + 0.01, 1.9, -3.4), Vector2(0.3, 0.38), 90.0)
	_panel("PosterBeer", poster_texture(1), Vector3(wx + 0.01, 1.85, -1.45), Vector2(0.28, 0.34), 90.0)
	_label("BEER", Vector3(wx + 0.016, 1.72, -1.45), 40, 90.0, Color(0.85, 0.7, 0.35))
	# The big corkboard in a pale pink frame.
	_box("CorkFrame", Vector3(wx + 0.005, 1.72, 0.55), Vector3(0.035, 1.12, 2.48), "pale")
	var cork := _panel("Corkboard", corkboard_texture(), Vector3(wx + 0.03, 1.72, 0.55), Vector2(2.36, 1.0), 90.0)
	props["corkboard"] = cork
	# The wall clock and the mountain calendar.
	_cyl("ClockRim", Vector3(wx + 0.03, 2.1, 2.35), 0.19, 0.04, "steel", true, -1.0, 8).rotation_degrees.z = 90.0
	_panel("ClockFace", clock_texture(), Vector3(wx + 0.055, 2.1, 2.35), Vector2(0.34, 0.34), 90.0)
	_panel("Calendar", calendar_texture(), Vector3(wx + 0.03, 1.58, 2.35), Vector2(0.32, 0.46), 90.0)

func _build_tanks() -> void:
	var wx := -half_x
	for k in 2:
		var pos := Vector3(wx + 0.2, FLOOR_Y + 0.6, -3.62 + k * 0.3)
		var tank := _cyl("GasTank%d" % k, pos, 0.14, 1.2, "tank", true, 0.12)
		_collide(Vector3(pos.x, pos.y, pos.z), Vector3(0.28, 1.2, 0.28))
		_ball("TankDome%d" % k, pos + Vector3(0, 0.6, 0), 0.12, "tank", true)
		var valve := _cyl("TankValve%d" % k, pos + Vector3(0, 0.75, 0), 0.04, 0.1, "steel", false)
		valve.rotation_degrees.z = 0.0
		var gauge := _cyl("TankGauge%d" % k, pos + Vector3(0.05, 0.78, 0), 0.04, 0.03, "pale", true)
		gauge.rotation_degrees.z = 90.0
		props["tank%d" % k] = tank
	# A blue bottle on the near one, as in the photos.
	_cyl("BlueBottle", Vector3(wx + 0.2, FLOOR_Y + 1.5, -3.32), 0.05, 0.2, "glass", true, 0.02)

# --- the work table -------------------------------------------------------------

func _build_table() -> void:
	var c := TABLE_AT
	var top_y := FLOOR_Y + COUNTER_H
	var top := _box("TableTop", Vector3(c.x, top_y - 0.03, c.y), Vector3(TABLE_SIZE.x, 0.06, TABLE_SIZE.y), "lilac", true)
	props["table"] = top
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var lp := Vector3(c.x + sx * (TABLE_SIZE.x / 2.0 - 0.07), FLOOR_Y + (COUNTER_H - 0.06) / 2.0, c.y + sz * (TABLE_SIZE.y / 2.0 - 0.07))
			_box("TableLeg", lp, Vector3(0.09, COUNTER_H - 0.06, 0.09), "wood", true)
	_box("TableRailN", Vector3(c.x, FLOOR_Y + 0.28, c.y - TABLE_SIZE.y / 2.0 + 0.07), Vector3(TABLE_SIZE.x - 0.1, 0.07, 0.05), "wood", false)
	_box("TableRailS", Vector3(c.x, FLOOR_Y + 0.28, c.y + TABLE_SIZE.y / 2.0 - 0.07), Vector3(TABLE_SIZE.x - 0.1, 0.07, 0.05), "wood", false)
	# The vise clamped on the south end, with its T handle.
	_box("Vise", Vector3(c.x + 0.1, top_y + 0.07, c.y + TABLE_SIZE.y / 2.0 + 0.06), Vector3(0.3, 0.2, 0.12), "vise")
	_box("ViseHandle", Vector3(c.x + 0.1, top_y + 0.07, c.y + TABLE_SIZE.y / 2.0 + 0.2), Vector3(0.03, 0.03, 0.2), "pale", false)
	_box("ViseBar", Vector3(c.x + 0.1, top_y + 0.07, c.y + TABLE_SIZE.y / 2.0 + 0.3), Vector3(0.22, 0.03, 0.03), "pale", false)
	# A clipboard on the top, a cardboard box and tissue box under it.
	_box("Clipboard", Vector3(c.x - 0.1, top_y + 0.012, c.y - 0.5), Vector3(0.28, 0.02, 0.36), "board", false)
	_box("ClipboardPaper", Vector3(c.x - 0.1, top_y + 0.025, c.y - 0.5), Vector3(0.22, 0.006, 0.3), "white", false, false)
	_box("TableBox", Vector3(c.x - 0.05, FLOOR_Y + 0.15, c.y + 0.3), Vector3(0.5, 0.2, 0.6), "board", false)
	_box("Tissues", Vector3(c.x - 0.05, FLOOR_Y + 0.28, c.y + 0.3), Vector3(0.16, 0.06, 0.1), "pale", false)

func _build_sink() -> void:
	# The utility sink in the south-west corner: a pale basin on wooden legs
	# with a tap between two wheel handles, and a shelf below.
	var c := Vector3(-half_x + 0.45, 0.0, half_z - 0.28)
	var top_y := FLOOR_Y + 0.88
	var basin := _box("SinkBasin", Vector3(c.x, top_y - 0.1, c.z), Vector3(0.62, 0.2, 0.5), "pale")
	_box("SinkWater", Vector3(c.x, top_y + 0.0, c.z), Vector3(0.5, 0.01, 0.38), "wood_dark", false, false)
	_box("SinkBack", Vector3(c.x, top_y + 0.1, half_z - 0.03), Vector3(0.62, 0.2, 0.05), "pale")
	for sx in [-1.0, 1.0]:
		_cyl("SinkTap", Vector3(c.x + sx * 0.2, top_y + 0.22, half_z - 0.07), 0.05, 0.03, "pale", true, -1.0, 8).rotation_degrees.x = 90.0
		for sz in [-1.0, 1.0]:
			_box("SinkLeg", Vector3(c.x + sx * 0.27, FLOOR_Y + 0.38, c.z + sz * 0.2), Vector3(0.06, 0.76, 0.06), "wood_dark", false)
	_cyl("SinkSpout", Vector3(c.x, top_y + 0.22, half_z - 0.1), 0.02, 0.1, "steel", false).rotation_degrees.x = 90.0
	_collide(Vector3(c.x, FLOOR_Y + 0.5, c.z), Vector3(0.66, 1.0, 0.54))
	props["sink"] = basin

# --- the east wall ----------------------------------------------------------------

func _build_east_wall() -> void:
	var ex := half_x - 0.04
	# The exposed wood studs and two rails, floor to ceiling.
	for z in [-3.4, -2.2, -1.0, 0.2, 1.4, 2.6]:
		_box("Stud", Vector3(ex, FLOOR_Y + wall_h / 2.0, z), Vector3(0.07, wall_h - 0.1, 0.1), "wood_dark", false)
	for y in [1.05, 1.75]:
		_box("Rail", Vector3(ex - 0.01, y, 0.0), Vector3(0.05, 0.08, 6.6), "wood_dark", false)
	# The slatted olive shutter on the north end of the wall, with its box above.
	var slats := 13
	for k in slats:
		_box("Slat", Vector3(ex - 0.015, 0.95 + k * 0.095, -2.5), Vector3(0.025, 0.08, 1.9), "olive", false, false)
	_box("ShutterBox", Vector3(ex - 0.03, 2.28, -2.5), Vector3(0.1, 0.12, 2.0), "pale", false)
	# The orange lamp on a bent pipe, above the stairs.
	_box("LampPipe", Vector3(ex - 0.03, 1.85, 0.0), Vector3(0.04, 0.5, 0.04), "steel", false, false)
	var arm := _box("LampArm", Vector3(ex - 0.12, 2.08, 0.0), Vector3(0.24, 0.04, 0.04), "steel", false, false)
	arm.rotation_degrees.z = 8.0
	var shade := _cyl("LampShade", Vector3(ex - 0.26, 2.0, 0.0), 0.13, 0.2, "lamp", true, 0.05, 8)
	shade.rotation_degrees.z = 14.0
	props["lamp"] = shade

# --- the metal shelving ------------------------------------------------------------

func _build_rack() -> void:
	var c := Vector3(half_x - 0.3, 0.0, 1.35)
	var size := Vector2(0.5, 1.35)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box("RackPost", Vector3(c.x + sx * (size.x / 2.0 - 0.02), FLOOR_Y + 0.92, c.z + sz * (size.y / 2.0 - 0.02)), Vector3(0.04, 1.84, 0.04), "steel", false)
	var levels := [0.18, 0.62, 1.06, 1.5]
	for y in levels:
		_box("RackShelf", Vector3(c.x, FLOOR_Y + y, c.z), Vector3(size.x, 0.03, size.y), "wood_dark", false)
	_collide(Vector3(c.x, FLOOR_Y + 0.92, c.z), Vector3(size.x, 1.84, size.y))
	props["rack"] = true
	var x := c.x - 0.02
	var y0 := FLOOR_Y + 0.195
	# Bottom shelf: a dark tool chest and a flat cardboard box.
	_box("ToolChest", Vector3(x, y0 + 0.11, c.z - 0.38), Vector3(0.34, 0.22, 0.45), "mask", false)
	_box("FlatBox", Vector3(x, y0 + 0.04, c.z + 0.25), Vector3(0.38, 0.08, 0.5), "board", false)
	# Second shelf: the spiked mace, a green monster mask and a crown.
	var y1 := FLOOR_Y + 0.635
	var ball := _ball("MaceHead", Vector3(x, y1 + 0.1, c.z - 0.42), 0.1, "steel")
	for k in 8:
		var a := TAU * k / 8.0
		var spike := _cyl("MaceSpike", Vector3(x + cos(a) * 0.11, y1 + 0.1 + sin(a * 2.0) * 0.06, c.z - 0.42 + sin(a) * 0.11), 0.03, 0.08, "steel", false, 0.0, 5)
		spike.rotation = Vector3(sin(a) * 1.2, 0.0, -cos(a) * 1.2)
	props["mace"] = ball
	_cyl("MaceHandle", Vector3(x, y1 + 0.02, c.z - 0.14), 0.014, 0.4, "pale", false).rotation_degrees.x = 90.0
	var mask := _box("Mask", Vector3(x, y1 + 0.13, c.z + 0.08), Vector3(0.2, 0.26, 0.22), "mask")
	props["mask"] = mask
	for k in 2:
		_ball("MaskEye", Vector3(x + 0.1, y1 + 0.18, c.z + 0.02 + k * 0.12), 0.035, "pink", false)
	var crown := _cyl("Crown", Vector3(x, y1 + 0.07, c.z + 0.4), 0.11, 0.14, "pale", true, 0.1, 8)
	_cyl("CrownJam", Vector3(x, y1 + 0.16, c.z + 0.4), 0.1, 0.05, "red", false, 0.07, 8)
	props["crown"] = crown
	# Third shelf: the TIME TRAVEL STUFF box with its eyeball, and a grey tool box.
	var y2 := FLOOR_Y + 1.075
	var ttbox := _box("TimeBox", Vector3(x, y2 + 0.14, c.z - 0.3), Vector3(0.3, 0.28, 0.4), "board")
	props["time_box"] = ttbox
	_label("TIME\nTRAVEL\nSTUFF", Vector3(x - 0.155, y2 + 0.15, c.z - 0.3), 36, -90.0)
	_ball("Eyeball", Vector3(x - 0.04, y2 + 0.06, c.z - 0.06), 0.045, "white")
	_ball("EyeIris", Vector3(x - 0.085, y2 + 0.06, c.z - 0.06), 0.022, "pink", false)
	_box("ToolBox", Vector3(x, y2 + 0.1, c.z + 0.3), Vector3(0.3, 0.2, 0.5), "steel")
	_box("ToolBoxHandle", Vector3(x, y2 + 0.23, c.z + 0.3), Vector3(0.04, 0.05, 0.3), "black", false, false)
	# Top shelf: the jar of green blobs, and a bucket of tools.
	var y3 := FLOOR_Y + 1.515
	var jar := _cyl("Jar", Vector3(x, y3 + 0.16, c.z - 0.3), 0.13, 0.32, "jar")
	_cyl("JarLid", Vector3(x, y3 + 0.34, c.z - 0.3), 0.13, 0.04, "pale", false)
	props["jar"] = jar
	_cyl("TopBucket", Vector3(x, y3 + 0.13, c.z + 0.3), 0.16, 0.26, "bucket", true, 0.19)
	# On the floor beside it: the trash bucket, a shovel and a broom.
	var bucket := _cyl("TrashBucket", Vector3(half_x - 0.8, FLOOR_Y + 0.17, 1.2), 0.17, 0.34, "bucket", true, 0.2)
	props["bucket"] = bucket
	var shovel := _box("ShovelBlade", Vector3(half_x - 0.1, FLOOR_Y + 0.2, -3.4), Vector3(0.03, 0.34, 0.26), "vise", false, true)
	shovel.rotation_degrees.x = 10.0
	_box("ShovelHandle", Vector3(half_x - 0.1, FLOOR_Y + 0.9, -3.4), Vector3(0.025, 1.3, 0.025), "wood_dark", false, false)
	_box("BroomHandle", Vector3(half_x - 0.08, FLOOR_Y + 0.85, -3.1), Vector3(0.025, 1.3, 0.025), "wood", false, false)
	_box("BroomHead", Vector3(half_x - 0.1, FLOOR_Y + 0.1, -3.1), Vector3(0.05, 0.2, 0.22), "yellow", false)

func _build_laundry() -> void:
	var ex := half_x - 0.36
	for k in 2:
		var z := 2.45 + k * 0.7
		var unit := _box("Washer" if k == 0 else "Dryer", Vector3(ex, FLOOR_Y + 0.46, z), Vector3(0.68, 0.92, 0.66), "cream", true)
		props["washer" if k == 0 else "dryer"] = unit
		# Control strip with dials and buttons along the back.
		_box("ControlStrip", Vector3(half_x - 0.1, FLOOR_Y + 1.02, z), Vector3(0.16, 0.18, 0.66), "olive", false)
		for d in 2:
			_cyl("Dial", Vector3(half_x - 0.19, FLOOR_Y + 1.03, z - 0.2 + d * 0.15), 0.035, 0.02, "pale", true, -1.0, 8).rotation_degrees.z = 90.0
		for b in 2:
			_box("Button", Vector3(half_x - 0.19, FLOOR_Y + 1.03, z + 0.1 + b * 0.1), Vector3(0.015, 0.03, 0.03), "black", false, false)
	# The dryer's grey door and the tissue box on top.
	_box("DryerDoor", Vector3(ex - 0.345, FLOOR_Y + 0.5, 3.15), Vector3(0.012, 0.6, 0.5), "grey", false, true)
	_box("TissueBox", Vector3(ex, FLOOR_Y + 0.97, 3.1), Vector3(0.2, 0.07, 0.12), "pink", false)

# --- the ceiling ---------------------------------------------------------------------

func _build_ceiling() -> void:
	for z in BEAM_ZS:
		_box("Beam", Vector3(0.0, BEAM_Y, z), Vector3(half_x * 2.0 - 0.1, 0.2, 0.17), "beam", false)
	# Two fluorescent fixtures along the west half, hung from the beams.
	for k in 2:
		var z := -1.0 + k * 2.6
		_box("Fixture", Vector3(-2.0, 2.3, z), Vector3(0.3, 0.1, 2.0), "beam", false)
		_box("FixtureTube", Vector3(-2.0, 2.24, z), Vector3(0.1, 0.03, 1.8), "tube", false, false)
	props["fixture"] = true

# --- floor litter -----------------------------------------------------------------------

func _build_litter() -> void:
	# Puddles: a dark ring under a pale grey blob.
	for spot in [Vector3(1.0, 0.0, -1.6), Vector3(-0.2, 0.0, 2.3), Vector3(0.9, 0.0, 1.5)]:
		var ring := _cyl("PuddleRing", Vector3(spot.x, FLOOR_Y + 0.002, spot.z), 0.5, 0.003, "black", false, -1.0, 16)
		ring.scale = Vector3(1.0, 1.0, 0.65)
		var blob := _cyl("Puddle", Vector3(spot.x, FLOOR_Y + 0.004, spot.z), 0.46, 0.003, "puddle", false, -1.0, 16)
		blob.scale = Vector3(1.0, 1.0, 0.65)
	# A sock, a yellow note and a crumpled paper.
	_box("Sock", Vector3(-0.8, FLOOR_Y + 0.02, 1.2), Vector3(0.22, 0.03, 0.08), "white", false, true).rotation_degrees.y = 35.0
	_box("SockStripe", Vector3(-0.76, FLOOR_Y + 0.04, 1.17), Vector3(0.03, 0.02, 0.085), "red", false, false).rotation_degrees.y = 35.0
	_box("YellowNote", Vector3(-0.2, FLOOR_Y + 0.006, -2.6), Vector3(0.16, 0.006, 0.12), "yellow", false, true).rotation_degrees.y = 20.0

# --- drawn textures ----------------------------------------------------------------------

## A line, `t` pixels thick.
static func _line(img: Image, a: Vector2, b: Vector2, color: Color, t := 2) -> void:
	var steps := int(maxf(absf(b.x - a.x), absf(b.y - a.y))) + 1
	for i in steps + 1:
		var p := a.lerp(b, float(i) / steps)
		img.fill_rect(Rect2i(int(p.x) - t / 2, int(p.y) - t / 2, t, t), color)

static func _frame(img: Image, r: Rect2i, color: Color) -> void:
	img.fill_rect(Rect2i(r.position.x, r.position.y, r.size.x, 2), color)
	img.fill_rect(Rect2i(r.position.x, r.end.y - 2, r.size.x, 2), color)
	img.fill_rect(Rect2i(r.position.x, r.position.y, 2, r.size.y), color)
	img.fill_rect(Rect2i(r.end.x - 2, r.position.y, 2, r.size.y), color)

static func _texture(img: Image) -> ImageTexture:
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

## The corkboard: tan cork, pale notes with lines of "writing", and red pins
## joined by black string to one pin in the middle.
static func corkboard_texture() -> ImageTexture:
	var img := Image.create(512, 220, true, Image.FORMAT_RGBA8)
	img.fill(Color(0.72, 0.65, 0.45))
	var notes := [
		Rect2i(22, 22, 70, 86), Rect2i(46, 90, 60, 66), Rect2i(150, 20, 92, 56), Rect2i(150, 120, 70, 82),
		Rect2i(262, 14, 108, 78), Rect2i(300, 100, 90, 82), Rect2i(404, 26, 70, 90), Rect2i(430, 130, 54, 70),
		Rect2i(236, 126, 54, 60),
	]
	var colours := [Color(0.82, 0.88, 0.8), Color(0.9, 0.9, 0.62), Color(0.92, 0.9, 0.82), Color(0.9, 0.88, 0.8),
			Color(0.92, 0.9, 0.82), Color(0.62, 0.8, 0.8), Color(0.88, 0.9, 0.78), Color(0.92, 0.9, 0.82), Color(0.88, 0.8, 0.62)]
	var pins: Array[Vector2] = []
	for i in notes.size():
		var r: Rect2i = notes[i]
		img.fill_rect(r, colours[i])
		_frame(img, r, Color(0.2, 0.2, 0.18))
		for ln in range(8, r.size.y - 8, 10):
			_line(img, Vector2(r.position.x + 8, r.position.y + ln), Vector2(r.end.x - 8 - (ln * 7) % 18, r.position.y + ln), Color(0.3, 0.3, 0.28), 1)
		pins.append(Vector2(r.position.x + r.size.x * 0.5, r.position.y + 6))
	var hub := Vector2(330, 128)
	for p in pins:
		_line(img, p, hub, Color(0.05, 0.05, 0.05), 2)
	for p in pins:
		img.fill_rect(Rect2i(int(p.x) - 4, int(p.y) - 4, 9, 9), Color(0.05, 0.05, 0.05))
		img.fill_rect(Rect2i(int(p.x) - 3, int(p.y) - 3, 7, 7), Color(0.75, 0.2, 0.2))
	img.fill_rect(Rect2i(int(hub.x) - 5, int(hub.y) - 5, 11, 11), Color(0.75, 0.2, 0.2))
	return _texture(img)

## A beige pegboard: a grid of dark holes.
static func pegboard_texture() -> ImageTexture:
	var img := Image.create(256, 144, true, Image.FORMAT_RGBA8)
	img.fill(Color(0.85, 0.81, 0.68))
	for y in range(8, 144, 14):
		for x in range(8, 256, 14):
			img.fill_rect(Rect2i(x, y, 3, 3), Color(0.25, 0.22, 0.18))
	return _texture(img)

## The calendar: a mountain scene over a grid of days.
static func calendar_texture() -> ImageTexture:
	var img := Image.create(96, 140, true, Image.FORMAT_RGBA8)
	img.fill(Color(0.88, 0.88, 0.82))
	img.fill_rect(Rect2i(6, 6, 84, 56), Color(0.55, 0.68, 0.72))
	_line(img, Vector2(8, 56), Vector2(30, 24), Color(0.15, 0.25, 0.2), 2)
	_line(img, Vector2(30, 24), Vector2(46, 44), Color(0.15, 0.25, 0.2), 2)
	_line(img, Vector2(46, 44), Vector2(62, 18), Color(0.15, 0.25, 0.2), 2)
	_line(img, Vector2(62, 18), Vector2(88, 56), Color(0.15, 0.25, 0.2), 2)
	img.fill_rect(Rect2i(8, 52, 80, 8), Color(0.3, 0.5, 0.3))
	_frame(img, Rect2i(6, 6, 84, 56), Color(0.1, 0.1, 0.1))
	for r in 5:
		for c in 7:
			_frame(img, Rect2i(8 + c * 11, 70 + r * 13, 11, 13), Color(0.2, 0.2, 0.2))
	_frame(img, Rect2i(0, 0, 96, 140), Color(0.1, 0.1, 0.1))
	return _texture(img)

## The clock: a pale face, tick marks and two hands.
static func clock_texture() -> ImageTexture:
	var s := 128
	var img := Image.create(s, s, true, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(s / 2.0, s / 2.0)
	for y in s:
		for x in s:
			var d := Vector2(x, y).distance_to(c)
			if d < 60.0:
				img.set_pixel(x, y, Color(0.1, 0.1, 0.1) if d > 56.0 else Color(0.88, 0.9, 0.84))
	for k in 12:
		var a := TAU * k / 12.0
		_line(img, c + Vector2(sin(a), -cos(a)) * 48.0, c + Vector2(sin(a), -cos(a)) * 54.0, Color(0.1, 0.1, 0.1), 3)
	_line(img, c, c + Vector2(sin(2.1), -cos(2.1)) * 34.0, Color(0.1, 0.1, 0.1), 3)
	_line(img, c, c + Vector2(sin(0.2), -cos(0.2)) * 46.0, Color(0.1, 0.1, 0.1), 2)
	return _texture(img)

## A small poster: 0 is a target, 1 is a bottle on a brown field.
static func poster_texture(kind: int) -> ImageTexture:
	var img := Image.create(64, 80, true, Image.FORMAT_RGBA8)
	img.fill(Color(0.9, 0.88, 0.8) if kind == 0 else Color(0.5, 0.42, 0.25))
	if kind == 0:
		for y in 80:
			for x in 64:
				var d := Vector2(x, y).distance_to(Vector2(32, 40))
				if d < 22.0:
					img.set_pixel(x, y, Color(0.75, 0.2, 0.2) if int(d / 7.0) % 2 == 0 else Color(0.9, 0.88, 0.8))
		_line(img, Vector2(32, 40), Vector2(52, 14), Color(0.1, 0.1, 0.1), 2)
	else:
		img.fill_rect(Rect2i(0, 40, 64, 40), Color(0.3, 0.45, 0.3))
		_line(img, Vector2(4, 40), Vector2(30, 8), Color(0.2, 0.3, 0.2), 2)
	_frame(img, Rect2i(0, 0, 64, 80), Color(0.1, 0.1, 0.1))
	return _texture(img)
