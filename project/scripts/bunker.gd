extends Node3D
## The bomb shelter under the House (D-145, D-186, D-194): a wooden trap door
## in the House Garage's floor opens on concrete stairs down to a short tunnel
## that turns east and then south, under the House's north end, to a steel
## blast door. Past it a long corridor runs west under the back yard, with nine
## rooms off it, each behind a steel door with a name plate: on the north side
## the command room, pantry, armory and munitions store; on the south side the
## mess hall, medical bay, bathroom, bunk room and utility room. Sleeping and
## eating are kept rooms apart.
##
## Everything is built in code from boxes and cylinders, in the same frame as
## the garage's shell (building_shell.gd `frame_for`): x across the garage, z
## along it (south is +z), y up from the ground. The garage is turned about 2.8
## degrees from the House, so the rooms are too. Layout numbers are in the
## constants below. Rooms are Rect2s in (x, z), each with its own four walls set
## just inside its edges, so two rooms that share an edge stand back to back. A
## door on a shared edge cuts both walls and hangs on the edge line.
##
## It also cuts the ground (terrain.gd, `terrain_holes`) where the stairs go down
## and asks the garage's shell to cut its floor there (`hatch_rect`). The ground
## stays whole over the rest of the shelter, which sits below it with its own
## floors, walls and ceilings.

const Shell := preload("res://scripts/building_shell.gd")
const WallLayout := preload("res://scripts/wall_layout.gd")
const DoorScript := preload("res://scripts/shop_door.gd")
const TrapDoor := preload("res://scripts/trap_door.gd")

const WALL_T := 0.15
## Top of the shelter's floors and the rooms' clear height.
const FLOOR_Y := -3.2
const ROOM_H := 2.6
## Top of the garage's floor (building_shell.gd FLOOR_TOP).
const HOUSE_FLOOR := 0.05
## The stairs: inner width, where the top step starts (z), the run and how many
## risers. The hatch over them is `HATCH_LEN` long.
const STAIR_X0 := 2.25
const STAIR_W := 1.2
const STAIR_Z0 := -2.85
const STAIR_RUN := 4.2
const RISERS := 16
const HATCH_LEN := 3.0
## How far the cut in the ground reaches past the hatch, hidden under the floor.
const HOLE_MARGIN := 0.25
const DOOR_H := 2.1

## Rooms: name -> Rect2(x, z, width, depth) of the outside of the walls.
const ROOMS := {
	"stairwell": Rect2(2.1, -3.0, 1.5, 6.0),
	"tunnel": Rect2(2.1, 3.0, 6.1, 2.0),
	"passage": Rect2(6.7, 5.0, 1.5, 4.5),
	"corridor": Rect2(-17.15, 9.5, 26.0, 2.2),
	"munitions": Rect2(-1.15, 5.0, 7.85, 4.5),
	"armory": Rect2(-5.65, 5.0, 4.5, 4.5),
	"pantry": Rect2(-9.15, 5.0, 3.5, 4.5),
	"command": Rect2(-17.15, 5.0, 8.0, 4.5),
	"utility": Rect2(4.35, 11.7, 4.5, 6.0),
	"bunks": Rect2(-1.15, 11.7, 5.5, 6.0),
	"bathroom": Rect2(-5.15, 11.7, 4.0, 6.0),
	"medical": Rect2(-9.15, 11.7, 4.0, 6.0),
	"mess": Rect2(-17.15, 11.7, 8.0, 6.0),
}
## What each room's door plate says.
const ROOM_TITLES := {
	"munitions": "Munitions", "armory": "Armory", "pantry": "Pantry", "command": "Command",
	"utility": "Utility", "bunks": "Bunks", "bathroom": "Bathroom", "medical": "Medical",
	"mess": "Mess hall",
}
## Doors on shared edges: x along the edge, z the edge line (all on z lines),
## which room the leaf swings into and that room's wall. An `open` entry is a
## doorless opening (the tunnel from the stairs to the blast door).
const DOORS := [
	{x = 2.85, z = 3.0, w = 1.2, room = "tunnel", wall = "north", label = "tunnel", open = true},
	{x = 7.45, z = 5.0, w = 1.2, room = "passage", wall = "north", label = "passage", open = true},
	{x = 7.45, z = 9.5, w = 1.2, room = "corridor", wall = "north", label = "blast door", blast = true},
	{x = 2.85, z = 9.5, w = 1.0, room = "munitions", wall = "south", label = "munitions store door"},
	{x = 1.85, z = 11.7, w = 1.0, room = "bunks", wall = "north", label = "bunk room door"},
	{x = -3.4, z = 9.5, w = 1.0, room = "armory", wall = "south", label = "armory door"},
	{x = -7.4, z = 9.5, w = 1.0, room = "pantry", wall = "south", label = "pantry door"},
	{x = -13.15, z = 9.5, w = 1.0, room = "command", wall = "south", label = "command room door"},
	{x = 6.6, z = 11.7, w = 1.0, room = "utility", wall = "north", label = "utility room door"},
	{x = -3.15, z = 11.7, w = 1.0, room = "bathroom", wall = "north", label = "bathroom door"},
	{x = -7.15, z = 11.7, w = 1.0, room = "medical", wall = "north", label = "medical bay door"},
	{x = -13.15, z = 11.7, w = 1.0, room = "mess", wall = "north", label = "mess hall door"},
]

## The building whose floor the hatch is in (building_shell.gd reads this).
@export var hatch_building := "House Garage"

var trap_door: Node3D
var _box: Node3D
var _walls_body: StaticBody3D
var _lights: Array[OmniLight3D] = []
var _mats := {}

func _enter_tree() -> void:
	add_to_group("terrain_hole")
	add_to_group("floor_hatch")

## The hatch in the garage's floor, in the garage shell's (x, z).
func hatch_rect() -> Rect2:
	return Rect2(STAIR_X0, STAIR_Z0, STAIR_W, HATCH_LEN)

## How long each step's tread is and how high each riser.
static func tread() -> float:
	return STAIR_RUN / RISERS

static func rise() -> float:
	return (HOUSE_FLOOR - FLOOR_Y) / RISERS

## The walking ramp's slope (rise over run). It leaves the garage's floor level
## with the top step's edge, so there is no lip to catch on at the top, and
## reaches the stairwell floor half a tread before the last step ends, so
## lower down it runs a little under the nosings and feet land on the treads.
static func ramp_slope() -> float:
	return (HOUSE_FLOOR - FLOOR_Y) / (STAIR_RUN - tread() / 2.0)

## The hole in the ground (TerrainMath.in_hole's six numbers), world space.
func terrain_holes() -> PackedFloat32Array:
	var box := _find_box()
	if box == null:
		return PackedFloat32Array()
	var frame := Shell.frame_for(box)
	var r := hatch_rect().grow(HOLE_MARGIN)
	var c := frame * Vector3(r.get_center().x, 0.0, r.get_center().y)
	var u := frame.basis.x.normalized()
	return PackedFloat32Array([c.x, c.z, u.x, u.z, r.size.x / 2.0, r.size.y / 2.0])

## The shelter's footprint (x, z in the shell frame) around all its rooms.
static func footprint() -> Rect2:
	var r: Rect2 = ROOMS.values()[0]
	for room: Rect2 in ROOMS.values():
		r = r.merge(room)
	return r

## Whether a point in the shell frame is inside the shelter's rooms or stairwell.
func contains_local(p: Vector3) -> bool:
	if p.y < FLOOR_Y - 0.2 or p.y > HOUSE_FLOOR:
		return false
	for room: Rect2 in ROOMS.values():
		if room.has_point(Vector2(p.x, p.z)):
			return true
	return false

func _find_box() -> Node3D:
	return get_node_or_null("../" + hatch_building) as Node3D

func _ready() -> void:
	_box = _find_box()
	if _box == null:
		push_warning("bunker: no building named '%s'" % hatch_building)
		return
	global_transform = Shell.frame_for(_box)
	_make_materials()
	_walls_body = StaticBody3D.new()
	_walls_body.name = "Walls"
	add_child(_walls_body)
	_build_rooms()
	_build_stairs()
	_build_doors()
	_build_trap_door()
	_furnish_corridor()
	_furnish_munitions()
	_furnish_armory()
	_furnish_pantry()
	_furnish_command()
	_furnish_mess()
	_furnish_medical()
	_furnish_bathroom()
	_furnish_bunks()
	_furnish_utility()
	_build_lights()
	_build_probe()

## Lights only while the camera is down here or near the hatch: unshadowed,
## they would otherwise light the garage's walls from below.
func _process(_delta: float) -> void:
	if _lights.is_empty():
		return
	var cam := get_viewport().get_camera_3d()
	var on := false
	if cam:
		var p := to_local(cam.global_position)
		var flat := Vector2(p.x, p.z)
		on = (p.y < -0.2 and footprint().grow(1.0).has_point(flat)) \
				or (p.y < 3.0 and hatch_rect().grow(2.5).has_point(flat))
	if _lights[0].visible != on:
		for light in _lights:
			light.visible = on

# --- materials -------------------------------------------------------------

func _make_materials() -> void:
	_mats.wall = _mat(Color(0.86, 0.87, 0.88), 0.8)
	_mats.floor = _mat(Color(0.46, 0.47, 0.49), 0.45)
	_mats.dark_floor = _mat(Color(0.2, 0.21, 0.23), 0.7)
	_mats.concrete = _mat(Color(0.62, 0.62, 0.6), 0.9)
	_mats.steel = _mat(Color(0.5, 0.52, 0.55), 0.35, 0.75)
	_mats.dark_steel = _mat(Color(0.24, 0.26, 0.28), 0.4, 0.7)
	_mats.olive = _mat(Color(0.3, 0.34, 0.2), 0.7, 0.2)
	_mats.wood = _mat(Color(0.6, 0.45, 0.28), 0.85)
	_mats.dark_wood = _mat(Color(0.42, 0.3, 0.18), 0.85)
	_mats.yellow = _mat(Color(0.95, 0.75, 0.08), 0.6)
	_mats.black = _mat(Color(0.06, 0.06, 0.07), 0.6)
	_mats.mattress = _mat(Color(0.3, 0.38, 0.48), 0.95)
	_mats.pillow = _mat(Color(0.92, 0.92, 0.9), 0.95)
	_mats.cardboard = _mat(Color(0.62, 0.48, 0.32), 0.95)
	_mats.tank = _mat(Color(0.78, 0.84, 0.9), 0.4, 0.3)
	_mats.red = _mat(Color(0.75, 0.1, 0.08), 0.5)
	_mats.led = _glow(Color(0.95, 0.97, 1.0), 2.5)
	_mats.screen = _glow(Color(0.15, 0.55, 0.9), 1.5)
	_mats.green_led = _glow(Color(0.2, 1.0, 0.3), 2.0)
	_mats.red_led = _glow(Color(1.0, 0.2, 0.1), 2.0)
	_mats.screen_green = _glow(Color(0.2, 0.75, 0.4), 1.2)
	_mats.tile = _mat(Color(0.82, 0.87, 0.9), 0.3)
	_mats.locker = _mat(Color(0.35, 0.45, 0.55), 0.45, 0.6)
	_mats.tin = _mat(Color(0.72, 0.73, 0.75), 0.3, 0.8)
	_mats.sack = _mat(Color(0.8, 0.74, 0.6), 0.95)
	_mats.mirror = _mat(Color(0.85, 0.9, 0.95), 0.03, 1.0)
	_mats.water = _mat(Color(0.35, 0.6, 0.95, 0.55), 0.1)
	_mats.water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats.glass = _mat(Color(0.8, 0.9, 0.95, 0.25), 0.05)
	_mats.glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

func _mat(color: Color, roughness: float, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m

func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var m := _mat(color, 0.5)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m

# --- shell -----------------------------------------------------------------

func _room_height(room: String) -> float:
	return HOUSE_FLOOR - FLOOR_Y if room == "stairwell" else ROOM_H

func _build_rooms() -> void:
	for room: String in ROOMS:
		var r: Rect2 = ROOMS[room]
		var h := _room_height(room)
		var floor_mat: Material = _mats.dark_floor if room == "corridor" else _mats.floor
		_add_box(Vector3(r.get_center().x, FLOOR_Y - 0.1, r.get_center().y), Vector3(r.size.x, 0.2, r.size.y), floor_mat, true)
		if room != "stairwell":
			_add_box(Vector3(r.get_center().x, FLOOR_Y + h + 0.1, r.get_center().y), Vector3(r.size.x, 0.2, r.size.y), _mats.wall, true)
		for wall in ["north", "south", "east", "west"]:
			_build_wall(room, wall, r, h)
	# The stairwell's ceiling where the garage's floor is over it (past the hatch).
	var s: Rect2 = ROOMS.stairwell
	var z0 := STAIR_Z0 + HATCH_LEN
	_add_box(Vector3(s.get_center().x, -0.05, (z0 + s.end.y) / 2.0), Vector3(s.size.x, 0.1, s.end.y - z0), _mats.wall, true)

## The openings a room's wall needs: every door on that wall's line.
func _openings(wall: String, r: Rect2) -> Array:
	var out := []
	if wall != "north" and wall != "south":
		return out
	var line := r.position.y if wall == "north" else r.end.y
	for d: Dictionary in DOORS:
		if absf(float(d.z) - line) < 0.01 and float(d.x) > r.position.x and float(d.x) < r.end.x:
			out.append({c = float(d.x) - r.get_center().x, w = float(d.w) + 0.04, y0 = 0.0, y1 = DOOR_H})
	return out

func _build_wall(room: String, wall: String, r: Rect2, h: float) -> void:
	var along_x := wall == "north" or wall == "south"
	# North and south walls run the full width; east and west fit between them.
	var length := r.size.x if along_x else r.size.y - 2.0 * WALL_T
	var line: float
	match wall:
		"north": line = r.position.y + WALL_T / 2.0
		"south": line = r.end.y - WALL_T / 2.0
		"west": line = r.position.x + WALL_T / 2.0
		_: line = r.end.x - WALL_T / 2.0
	for piece in WallLayout.pieces(length, h, _openings(wall, r)):
		var along := piece.get_center().x
		var y := FLOOR_Y + piece.get_center().y
		if along_x:
			_add_box(Vector3(r.get_center().x + along, y, line), Vector3(piece.size.x, piece.size.y, WALL_T), _mats.wall, true)
		else:
			_add_box(Vector3(line, y, r.get_center().y + along), Vector3(WALL_T, piece.size.y, piece.size.x), _mats.wall, true)

# --- stairs ----------------------------------------------------------------

func _build_stairs() -> void:
	var x := STAIR_X0 + STAIR_W / 2.0
	for k in RISERS - 1:
		var top := HOUSE_FLOOR - (k + 1) * rise()
		var z := STAIR_Z0 + (k + 0.5) * tread()
		_add_box(Vector3(x, (top + FLOOR_Y) / 2.0, z), Vector3(STAIR_W, top - FLOOR_Y, tread()), _mats.concrete, false)
		# A yellow anti-slip strip on each nosing.
		_add_box(Vector3(x, top + 0.003, z - tread() / 2.0 + 0.04), Vector3(STAIR_W, 0.006, 0.05), _mats.yellow, false)
	# One smooth ramp to walk on (see ramp_slope).
	var slope := ramp_slope()
	var top := Vector3(x, HOUSE_FLOOR, STAIR_Z0)
	var bottom := Vector3(x, FLOOR_Y, STAIR_Z0 + (HOUSE_FLOOR - FLOOR_Y) / slope)
	var length := top.distance_to(bottom)
	var thick := 0.3
	var angle := atan(slope)
	var shape := BoxShape3D.new()
	shape.size = Vector3(STAIR_W, thick, length)
	var cs := CollisionShape3D.new()
	cs.name = "StairRamp"
	cs.shape = shape
	cs.rotation.x = angle
	cs.position = (top + bottom) / 2.0 + Vector3(0, -cos(angle), -sin(angle)) * (thick / 2.0)
	_walls_body.add_child(cs)
	# A steel handrail down the west wall, 0.9 m over the nosings; it starts
	# where it is under the garage's floor, so a closed trap door clears it.
	var rail_x := STAIR_X0 + 0.07
	var rail_start := 1.45
	var a := Vector3(rail_x, HOUSE_FLOOR - rail_start * rise() / tread() + 0.9, STAIR_Z0 + rail_start)
	var b := Vector3(rail_x, FLOOR_Y + 0.9, STAIR_Z0 + STAIR_RUN)
	_add_rod(a, b, 0.025, _mats.steel)
	for t in [0.15, 0.5, 0.85]:
		var p: Vector3 = a.lerp(b, t)
		_add_box(Vector3(STAIR_X0 + 0.02, p.y, p.z), Vector3(0.04, 0.03, 0.06), _mats.steel, false)

func _build_trap_door() -> void:
	trap_door = TrapDoor.new()
	trap_door.name = "TrapDoor"
	trap_door.width = STAIR_W
	trap_door.length = HATCH_LEN
	trap_door.position = Vector3(STAIR_X0 + STAIR_W / 2.0, HOUSE_FLOOR, STAIR_Z0 + HATCH_LEN / 2.0)
	add_child(trap_door)

# --- doors -----------------------------------------------------------------

func _build_doors() -> void:
	for d: Dictionary in DOORS:
		if d.get("open", false):
			continue
		var spec: Dictionary = Shell.WALLS[d.wall]
		var door := DoorScript.new()
		var w := float(d.w)
		door.width = w + 0.04
		door.height = DOOR_H - 0.02
		door.label = d.label
		door.window_pane = false
		door.color = Color(0.36, 0.39, 0.42) if d.get("blast", false) else Color(0.62, 0.65, 0.68)
		door.thickness = 0.14 if d.get("blast", false) else 0.05
		door.swing_time = 1.6 if d.get("blast", false) else 0.8
		var start := float(d.x) - float(spec.dir) * (w / 2.0 + 0.02)
		door.position = Vector3(start, FLOOR_Y, float(d.z))
		door.rotation_degrees.y = float(spec.yaw)
		door.name = "Door_%s" % d.room
		door.set_meta("room", d.room)
		add_child(door)
		if d.get("blast", false):
			# A yellow-and-black frame round the blast door, on the corridor side.
			for side in [-1.0, 1.0]:
				_add_box(Vector3(float(d.x) + side * (w / 2.0 + 0.1), FLOOR_Y + DOOR_H / 2.0, float(d.z) + WALL_T + 0.01),
						Vector3(0.12, DOOR_H + 0.2, 0.02), _mats.yellow, false)
			_add_box(Vector3(float(d.x), FLOOR_Y + DOOR_H + 0.1, float(d.z) + WALL_T + 0.01), Vector3(w + 0.32, 0.12, 0.02), _mats.yellow, false)

## The doors, for tests: room name -> door node.
func doors() -> Dictionary:
	var out := {}
	for c in get_children():
		if c.has_meta("room"):
			out[c.get_meta("room")] = c
	return out

# --- furniture -------------------------------------------------------------

## A room's clear floor area (inside its walls), Rect2 in (x, z).
static func inner(room: String) -> Rect2:
	return (ROOMS[room] as Rect2).grow(-WALL_T)

func _furnish_corridor() -> void:
	var r: Rect2 = ROOMS.corridor
	var i := inner("corridor")
	# A painted guide stripe low on the south wall, broken at each doorway.
	var face := r.end.y - WALL_T - 0.005
	var cuts: Array = []
	for d: Dictionary in DOORS:
		if absf(float(d.z) - r.end.y) < 0.01:
			cuts.append(float(d.x))
	cuts.sort()
	var x := i.position.x + 0.2
	for c: float in cuts + [i.end.x - 0.2 + 0.7]:
		var stop := c - 0.7
		if stop > x + 0.05:
			_add_box(Vector3((x + stop) / 2.0, FLOOR_Y + 1.0, face), Vector3(stop - x, 0.12, 0.01), _mats.yellow, false)
		x = c + 0.7
	# Fire extinguishers at both ends.
	_add_cyl(Vector3(i.position.x + 0.25, FLOOR_Y + 0.35, i.position.y + 0.2), 0.09, 0.6, _mats.red)
	_add_cyl(Vector3(i.end.x - 0.25, FLOOR_Y + 0.35, i.end.y - 0.2), 0.09, 0.6, _mats.red)
	# A name plate over every room's door, on the corridor side.
	for d: Dictionary in DOORS:
		if d.get("blast", false) or d.get("open", false):
			continue
		var north := float(d.z) < r.get_center().y
		var z := float(d.z) + (WALL_T + 0.012 if north else -WALL_T - 0.012)
		var y := FLOOR_Y + DOOR_H + 0.22
		var title := String(ROOM_TITLES[d.room]).to_upper()
		_add_box(Vector3(float(d.x), y, z + (-0.006 if north else 0.006)), Vector3(0.25 + 0.1 * title.length(), 0.24, 0.012), _mats.yellow, false)
		var label := Label3D.new()
		label.text = title
		label.font_size = 40
		label.outline_size = 0
		label.pixel_size = 0.004
		label.modulate = Color(0.08, 0.08, 0.09)
		label.position = Vector3(float(d.x), y, z + (0.002 if north else -0.002))
		label.rotation_degrees.y = 0.0 if north else 180.0
		label.name = "Sign_%s" % d.room
		add_child(label)
	# The stairwell gets a strip over the foot of the stairs.
	var s: Rect2 = ROOMS.stairwell
	_add_box(Vector3(s.get_center().x, -0.12, s.end.y - 0.6), Vector3(0.12, 0.03, 0.8), _mats.led, false)

## Ammo: shelving of olive cans, crates on pallets, long mortar boxes and a table.
func _furnish_munitions() -> void:
	var i := inner("munitions")
	for cx in [i.position.x + 1.05, i.position.x + 3.05, i.position.x + 5.05]:
		_shelf_unit(Vector3(cx, FLOOR_Y, i.position.y + 0.32), Vector2(1.8, 0.55), 2.0, 4, "ammo")
	for row in 2:
		var pz := i.end.y - 0.9 - row * 1.45
		_add_box(Vector3(i.end.x - 0.65, FLOOR_Y + 0.07, pz), Vector3(1.2, 0.14, 1.2), _mats.wood, true)
		for layer in 2 - row:
			for col in 2:
				var c := Vector3(i.end.x - 0.95 + col * 0.6, FLOOR_Y + 0.14 + 0.25 + layer * 0.5, pz)
				_crate(c, Vector3(0.56, 0.48, 1.1), (col + layer + row) % 2 == 0)
	# Long olive mortar-round boxes stacked on the west wall.
	for layer in 3:
		for k in 2:
			var c := Vector3(i.position.x + 0.3, FLOOR_Y + 0.16 + layer * 0.3, i.position.y + 1.8 + k * 1.2)
			_add_box(c, Vector3(0.5, 0.28, 1.1), _mats.olive, true)
			_add_box(c + Vector3(0.0, 0.0, 0.0), Vector3(0.52, 0.04, 1.12), _mats.yellow if layer == 2 else _mats.dark_steel, false)
	var t := Vector3(-1.6, FLOOR_Y, i.position.y + 2.3)
	_table(t, Vector2(1.6, 0.8), 0.9, _mats.steel)
	_add_box(t + Vector3(-0.3, 0.9 + 0.1, 0.0), Vector3(0.32, 0.2, 0.16), _mats.olive, false)
	for k in 5:
		_add_cyl(t + Vector3(0.2 + k * 0.09, 0.9 + 0.08, 0.1), 0.025, 0.16, _mats.yellow)

## Guns: a long-gun rack, a pistol pegboard, a workbench with a vise and a safe.
func _furnish_armory() -> void:
	var i := inner("armory")
	var x0 := i.position.x
	var zc := i.get_center().y
	_add_box(Vector3(x0 + 0.12, FLOOR_Y + 0.15, zc), Vector3(0.24, 0.3, 2.4), _mats.dark_steel, true)
	_add_box(Vector3(x0 + 0.05, FLOOR_Y + 1.3, zc), Vector3(0.1, 0.06, 2.4), _mats.dark_steel, false)
	for k in 9:
		var z := zc - 1.05 + k * 0.26
		_add_box(Vector3(x0 + 0.13, FLOOR_Y + 0.45, z), Vector3(0.07, 0.3, 0.05), _mats.black, false)
		_add_box(Vector3(x0 + 0.1, FLOOR_Y + 0.85, z), Vector3(0.05, 0.55, 0.04), _mats.black, false)
		_add_rod(Vector3(x0 + 0.08, FLOOR_Y + 1.1, z), Vector3(x0 + 0.08, FLOOR_Y + 1.55, z), 0.012, _mats.dark_steel)
	# Pegboard of pistols on the north wall.
	var pz := i.position.y + 0.02
	var px := i.get_center().x - 0.9
	_add_box(Vector3(px, FLOOR_Y + 1.45, pz), Vector3(2.0, 1.0, 0.02), _mats.dark_wood, false)
	for row in 2:
		for col in 4:
			var p := Vector3(px - 0.72 + col * 0.48, FLOOR_Y + 1.2 + row * 0.45, pz + 0.04)
			_add_box(p + Vector3(0.04, 0.05, 0), Vector3(0.2, 0.05, 0.03), _mats.black, false)
			_add_box(p + Vector3(-0.04, -0.03, 0), Vector3(0.05, 0.12, 0.03), _mats.black, false)
	# Gun safe in the north-east corner.
	var safe := Vector3(i.end.x - 0.5, FLOOR_Y + 0.9, i.position.y + 0.32)
	_add_box(safe, Vector3(0.9, 1.8, 0.6), _mats.dark_steel, true)
	_add_cyl(safe + Vector3(0.1, 0.1, 0.31), 0.1, 0.03, _mats.steel)
	# Workbench with a vise on the east wall.
	var b := Vector3(i.end.x - 0.35, FLOOR_Y, i.get_center().y + 0.3)
	_table(b, Vector2(0.7, 1.6), 0.9, _mats.wood)
	_add_box(b + Vector3(0.0, 0.98, -0.5), Vector3(0.2, 0.12, 0.15), _mats.dark_steel, false)
	_add_box(b + Vector3(0.0, 0.94, 0.3), Vector3(0.12, 0.03, 0.35), _mats.black, false)

## Food and water: shelves of tins and water jugs, and stacked sacks.
func _furnish_pantry() -> void:
	var i := inner("pantry")
	var zc := i.get_center().y - 0.4
	_shelf_unit(Vector3(i.position.x + 0.3, FLOOR_Y, zc), Vector2(0.5, 2.8), 2.0, 5, "cans", true)
	_shelf_unit(Vector3(i.end.x - 0.3, FLOOR_Y, zc), Vector2(0.5, 2.8), 2.0, 4, "water", true)
	for layer in 4:
		for k in 2:
			_add_box(Vector3(i.get_center().x - 0.3 + k * 0.62, FLOOR_Y + 0.08 + layer * 0.16, i.position.y + 0.35),
					Vector3(0.58, 0.15, 0.42), _mats.sack, layer == 0)

## Command: a wall of screens over a console desk, chairs, a map table and a radio rack.
func _furnish_command() -> void:
	var i := inner("command")
	var zn := i.position.y
	var screens := [_mats.screen, _mats.screen_green, _mats.screen]
	for k in 3:
		var sx: float = i.get_center().x - 2.1 + k * 2.1
		_add_box(Vector3(sx, FLOOR_Y + 1.75, zn + 0.03), Vector3(1.7, 0.95, 0.05), _mats.black, false)
		_add_box(Vector3(sx, FLOOR_Y + 1.75, zn + 0.058), Vector3(1.6, 0.85, 0.01), screens[k], false)
	var desk := Vector3(i.get_center().x, FLOOR_Y, zn + 0.4)
	_table(desk, Vector2(6.4, 0.7), 0.75, _mats.dark_steel)
	for k in 3:
		var kx: float = i.get_center().x - 2.1 + k * 2.1
		_add_box(desk + Vector3(kx - desk.x, 0.77, 0.1), Vector3(0.45, 0.02, 0.15), _mats.black, false)
		_add_box(desk + Vector3(kx - desk.x + 0.4, 0.95, -0.15), Vector3(0.35, 0.3, 0.03), _mats.screen_green, false)
		_chair(Vector3(kx, FLOOR_Y, zn + 1.15))
	# Map table: a lit green plan of the farm under glass.
	var m := Vector3(i.get_center().x, FLOOR_Y, i.end.y - 1.75)
	_table(m, Vector2(2.0, 1.0), 0.95, _mats.dark_steel)
	_add_box(m + Vector3(0, 0.955, 0), Vector3(1.8, 0.01, 0.8), _mats.screen_green, false)
	# Radio rack on the west wall.
	var rack := Vector3(i.position.x + 0.3, FLOOR_Y + 0.9, i.end.y - 0.8)
	_add_box(rack, Vector3(0.55, 1.8, 0.8), _mats.black, true)
	for k in 4:
		_add_box(rack + Vector3(0.28, 0.55 - k * 0.35, -0.2), Vector3(0.01, 0.04, 0.04), _mats.green_led if k != 2 else _mats.red_led, false)
		_add_box(rack + Vector3(0.28, 0.55 - k * 0.35, 0.1), Vector3(0.01, 0.12, 0.3), _mats.dark_steel, false)
	# A red alert beacon over the door.
	_add_cyl(Vector3(i.get_center().x + 0.3, FLOOR_Y + ROOM_H - 0.12, i.end.y - 0.2), 0.08, 0.12, _mats.red_led)

## Mess hall: the kitchen on the west wall, two long tables with benches, a water cooler.
func _furnish_mess() -> void:
	var i := inner("mess")
	var x0 := i.position.x
	var kz0 := i.position.y + 0.5
	var kz1 := i.end.y - 1.2
	var kc := (kz0 + kz1) / 2.0
	_add_box(Vector3(x0 + 0.3, FLOOR_Y + 0.45, kc), Vector3(0.6, 0.9, kz1 - kz0), _mats.wood, true)
	_add_box(Vector3(x0 + 0.3, FLOOR_Y + 0.92, kc), Vector3(0.62, 0.04, kz1 - kz0 + 0.02), _mats.dark_steel, false)
	_add_box(Vector3(x0 + 0.3, FLOOR_Y + 0.93, kz0 + 0.7), Vector3(0.4, 0.02, 0.6), _mats.steel, false)
	var stove := Vector3(x0 + 0.3, FLOOR_Y + 0.945, kc + 0.6)
	_add_box(stove, Vector3(0.58, 0.01, 0.6), _mats.black, false)
	for bx in [-0.13, 0.13]:
		for bz in [-0.14, 0.14]:
			_add_cyl(stove + Vector3(bx, 0.008, bz), 0.08, 0.006, _mats.dark_steel)
	_add_box(Vector3(x0 + 0.18, FLOOR_Y + 1.85, kc), Vector3(0.36, 0.7, kz1 - kz0), _mats.wood, false)
	var fridge := Vector3(x0 + 0.38, FLOOR_Y + 0.95, i.end.y - 0.4)
	_add_box(fridge, Vector3(0.72, 1.9, 0.7), _mats.steel, true)
	_add_box(fridge + Vector3(0.37, 0.2, -0.25), Vector3(0.02, 0.6, 0.03), _mats.dark_steel, false)
	for k in 2:
		var t := Vector3(i.get_center().x + 0.6, FLOOR_Y, i.position.y + 2.3 + k * 1.85)
		_table(t, Vector2(2.6, 0.9), 0.75, _mats.wood)
		for side in [-1.0, 1.0]:
			_add_box(t + Vector3(0, 0.45, side * 0.68), Vector3(2.6, 0.05, 0.3), _mats.wood, false)
			_add_box(t + Vector3(0, 0.21, side * 0.68), Vector3(2.4, 0.42, 0.06), _mats.dark_steel, false)
			_add_collider(t + Vector3(0, 0.23, side * 0.68), Vector3(2.6, 0.46, 0.3))
	var cooler := Vector3(i.end.x - 0.25, FLOOR_Y, i.position.y + 0.9)
	_add_box(cooler + Vector3(0, 0.5, 0), Vector3(0.35, 1.0, 0.35), _mats.pillow, true)
	_add_cyl(cooler + Vector3(0, 1.22, 0), 0.14, 0.42, _mats.water)
	# A wall clock over the tables.
	_add_cyl(Vector3(i.end.x - 0.02, FLOOR_Y + 2.0, i.get_center().y), 0.18, 0.03, _mats.pillow, false, true)

## Bathroom: two showers, two toilets and two sinks under a mirror, on a tiled floor.
func _furnish_bathroom() -> void:
	var i := inner("bathroom")
	_add_box(Vector3(i.get_center().x, FLOOR_Y + 0.005, i.get_center().y), Vector3(i.size.x, 0.01, i.size.y), _mats.tile, false)
	# Showers along the south wall, glass between and in front.
	for k in 2:
		var c := Vector3(i.position.x + 0.55 + k * 1.1, FLOOR_Y, i.end.y - 0.55)
		_add_box(c + Vector3(0, 0.03, 0), Vector3(1.0, 0.06, 1.0), _mats.pillow, false)
		_add_rod(c + Vector3(0, 2.05, 0.5), c + Vector3(0, 2.05, 0.3), 0.015, _mats.steel)
		_add_cyl(c + Vector3(0, 2.02, 0.3), 0.08, 0.03, _mats.steel)
		_add_box(c + Vector3(0.53, 1.0, 0), Vector3(0.02, 2.0, 1.0), _mats.glass, true)
		_add_box(c + Vector3(-0.2, 1.0, -0.5), Vector3(0.6, 2.0, 0.02), _mats.glass, true)
	# Toilets along the west wall with a partition between.
	for k in 2:
		var c := Vector3(i.position.x + 0.35, FLOOR_Y, i.position.y + 1.8 + k * 1.1)
		_add_box(c + Vector3(-0.22, 0.6, 0), Vector3(0.18, 0.4, 0.45), _mats.pillow, false)
		_add_cyl(c + Vector3(0.05, 0.2, 0), 0.19, 0.4, _mats.pillow, true)
		_add_cyl(c + Vector3(0.05, 0.41, 0), 0.2, 0.03, _mats.pillow)
	_add_box(Vector3(i.position.x + 0.5, FLOOR_Y + 0.9, i.position.y + 2.35), Vector3(1.0, 1.8, 0.03), _mats.wall, true)
	# Sinks and a mirror on the east wall.
	var sz := i.position.y + 2.4
	_add_box(Vector3(i.end.x - 0.25, FLOOR_Y + 0.82, sz), Vector3(0.5, 0.08, 1.6), _mats.pillow, false)
	_add_collider(Vector3(i.end.x - 0.25, FLOOR_Y + 0.43, sz), Vector3(0.5, 0.86, 1.6))
	for k in [-0.4, 0.4]:
		_add_box(Vector3(i.end.x - 0.25, FLOOR_Y + 0.85, sz + k), Vector3(0.36, 0.03, 0.42), _mats.tile, false)
		_add_rod(Vector3(i.end.x - 0.08, FLOOR_Y + 0.86, sz + k), Vector3(i.end.x - 0.2, FLOOR_Y + 1.0, sz + k), 0.015, _mats.steel)
	_add_box(Vector3(i.end.x - 0.01, FLOOR_Y + 1.55, sz), Vector3(0.02, 0.8, 1.5), _mats.mirror, false)

## Medical bay: two hospital beds with drips, a monitor, a medicine cabinet and a trolley.
func _furnish_medical() -> void:
	var i := inner("medical")
	for k in 2:
		var b := Vector3(i.position.x + 0.5, FLOOR_Y, i.position.y + 2.1 + k * 2.3)
		_add_box(b + Vector3(0, 0.55, 0), Vector3(0.9, 0.08, 2.0), _mats.steel, false)
		_add_box(b + Vector3(0, 0.66, 0.2), Vector3(0.86, 0.14, 1.55), _mats.pillow, false)
		var head := MeshInstance3D.new()
		var hm := BoxMesh.new()
		hm.size = Vector3(0.86, 0.12, 0.6)
		head.mesh = hm
		head.material_override = _mats.pillow
		head.position = b + Vector3(0, 0.82, -0.72)
		head.rotation_degrees.x = 35.0
		add_child(head)
		for cx in [-0.4, 0.4]:
			for cz in [-0.95, 0.95]:
				_add_box(b + Vector3(cx, 0.27, cz), Vector3(0.04, 0.54, 0.04), _mats.steel, false)
		_add_box(b + Vector3(0.47, 0.85, 0.3), Vector3(0.03, 0.2, 1.0), _mats.steel, false)
		_add_collider(b + Vector3(0, 0.45, 0), Vector3(0.9, 0.9, 2.0))
		# A drip stand beside each bed.
		var iv := b + Vector3(0.75, 0, -0.6)
		_add_cyl(iv + Vector3(0, 0.02, 0), 0.22, 0.04, _mats.steel)
		_add_rod(iv + Vector3(0, 0.04, 0), iv + Vector3(0, 1.9, 0), 0.015, _mats.steel)
		_add_box(iv + Vector3(0, 1.75, 0), Vector3(0.12, 0.2, 0.05), _mats.water, false)
	# A heart monitor on a stand between the beds.
	var mon := Vector3(i.position.x + 1.25, FLOOR_Y, i.position.y + 3.25)
	_add_rod(mon, mon + Vector3(0, 1.2, 0), 0.02, _mats.steel)
	_add_box(mon + Vector3(0, 1.35, 0), Vector3(0.1, 0.3, 0.4), _mats.black, false)
	_add_box(mon + Vector3(0.051, 1.35, 0), Vector3(0.01, 0.24, 0.34), _mats.screen_green, false)
	# Medicine cabinet with a red cross on the east wall.
	var cab := Vector3(i.end.x - 0.22, FLOOR_Y + 1.0, i.get_center().y - 0.3)
	_add_box(cab, Vector3(0.44, 2.0, 1.4), _mats.pillow, true)
	_add_box(cab + Vector3(-0.225, 0.4, 0), Vector3(0.01, 0.4, 0.12), _mats.red, false)
	_add_box(cab + Vector3(-0.225, 0.4, 0), Vector3(0.01, 0.12, 0.4), _mats.red, false)
	_add_box(cab + Vector3(-0.225, -0.1, 0), Vector3(0.01, 0.01, 1.3), _mats.dark_steel, false)
	# A steel trolley.
	var t := Vector3(i.end.x - 0.5, FLOOR_Y, i.end.y - 0.6)
	_table(t, Vector2(0.5, 0.8), 0.85, _mats.steel)
	_add_box(t + Vector3(0, 0.3, 0), Vector3(0.48, 0.02, 0.78), _mats.steel, false)
	_add_box(t + Vector3(0, 0.9, 0.15), Vector3(0.25, 0.1, 0.3), _mats.red, false)

## Bunk room, now just for sleeping: four steel bunks and a row of lockers.
func _furnish_bunks() -> void:
	var i := inner("bunks")
	for z in [i.position.y + 1.25, i.position.y + 3.75]:
		_bunk(Vector3(i.position.x + 0.5, FLOOR_Y, z))
	for z in [i.position.y + 1.7, i.position.y + 4.1]:
		_bunk(Vector3(i.end.x - 0.5, FLOOR_Y, z))
	for k in 6:
		var c := Vector3(i.get_center().x - 1.125 + k * 0.45, FLOOR_Y + 0.95, i.end.y - 0.25)
		_add_box(c, Vector3(0.43, 1.9, 0.5), _mats.locker, false)
		for v in 3:
			_add_box(c + Vector3(0, 0.75 - v * 0.04, -0.252), Vector3(0.25, 0.015, 0.005), _mats.dark_steel, false)
		_add_box(c + Vector3(0.14, 0.1, -0.26), Vector3(0.03, 0.12, 0.02), _mats.steel, false)
	_add_collider(Vector3(i.get_center().x, FLOOR_Y + 0.95, i.end.y - 0.25), Vector3(2.7, 1.9, 0.5))

func _furnish_utility() -> void:
	var r: Rect2 = ROOMS.utility
	var x0 := r.position.x + WALL_T
	var x1 := r.end.x - WALL_T
	var z1 := r.end.y - WALL_T
	# A diesel generator against the south wall, with its exhaust up into the ceiling.
	var g := Vector3(r.get_center().x - 0.4, FLOOR_Y, z1 - 0.6)
	_add_box(g + Vector3(0, 0.08, 0), Vector3(1.8, 0.16, 1.0), _mats.dark_steel, true)
	_add_box(g + Vector3(0, 0.66, 0), Vector3(1.6, 1.0, 0.9), _mats.yellow, false)
	_add_box(g + Vector3(0.55, 0.9, -0.46), Vector3(0.35, 0.25, 0.02), _mats.black, false)
	_add_box(g + Vector3(0.55, 0.9, -0.475), Vector3(0.08, 0.04, 0.01), _mats.green_led, false)
	_add_rod(g + Vector3(-0.5, 1.16, 0.2), g + Vector3(-0.5, ROOM_H, 0.2), 0.06, _mats.steel)
	# Two water tanks on the east wall.
	for z in [r.position.y + 1.2, r.position.y + 2.3]:
		_add_cyl(Vector3(x1 - 0.5, FLOOR_Y + 0.9, z), 0.45, 1.8, _mats.tank, true)
	# An air filtration unit with its duct to the ceiling.
	var f := Vector3(x1 - 0.4, FLOOR_Y, r.position.y + 3.6)
	_add_box(f + Vector3(0, 0.8, 0), Vector3(0.7, 1.6, 0.8), _mats.steel, true)
	_add_box(f + Vector3(-0.36, 1.1, 0), Vector3(0.02, 0.6, 0.6), _mats.dark_steel, false)
	_add_cyl(f + Vector3(0, 1.6 + (ROOM_H - 1.6) / 2.0, 0), 0.18, ROOM_H - 1.6, _mats.steel)
	# An electrical panel and supply shelves on the west wall.
	var p := Vector3(x0 + 0.06, FLOOR_Y + 1.5, r.position.y + 1.1)
	_add_box(p, Vector3(0.12, 0.9, 0.7), _mats.wall, false)
	for k in 3:
		_add_box(p + Vector3(0.065, 0.3 - k * 0.12, -0.2), Vector3(0.01, 0.04, 0.04), _mats.green_led if k < 2 else _mats.red_led, false)
	_shelf_unit(Vector3(x0 + 0.3, FLOOR_Y, r.position.y + 3.4), Vector2(0.5, 2.0), 2.0, 5, "supplies", true)

## A steel shelving unit centred on `base` (floor level), `size` (x, z) in plan.
## `fill` picks what sits on the shelves: "ammo" (olive cans), "supplies"
## (cardboard boxes), "cans" (tins) or "water" (blue jugs). With `along_z` the
## long side runs along z.
func _shelf_unit(base: Vector3, size: Vector2, height: float, shelves: int, fill: String, along_z := false) -> void:
	var sx := size.x
	var sz := size.y
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			_add_box(base + Vector3(cx * (sx / 2.0 - 0.02), height / 2.0, cz * (sz / 2.0 - 0.02)), Vector3(0.04, height, 0.04), _mats.steel, false)
	var long := sz if along_z else sx
	var items := {
		"ammo": [Vector3(0.3, 0.19, 0.16), _mats.olive, 0.36],
		"supplies": [Vector3(0.3, 0.26, 0.4), _mats.cardboard, 0.36],
		"cans": [Vector3(0.24, 0.12, 0.24), _mats.tin, 0.28],
		"water": [Vector3(0.24, 0.34, 0.24), _mats.water, 0.3],
	}
	var item: Array = items[fill]
	var box: Vector3 = item[0]
	if along_z:
		box = Vector3(box.z, box.y, box.x)
	for k_shelf in shelves:
		var y := 0.1 + k_shelf * (height - 0.2) / (shelves - 1)
		_add_box(base + Vector3(0, y, 0), Vector3(sx, 0.03, sz), _mats.steel, false)
		if k_shelf == shelves - 1:
			continue
		var count := floori(long / float(item[2]))
		for k in count:
			if fill == "supplies" and (k + k_shelf) % 3 == 2:
				continue
			var a := -long / 2.0 + (k + 0.5) * long / count
			var off := Vector3(0, 0, a) if along_z else Vector3(a, 0, 0)
			_add_box(base + off + Vector3(0, y + 0.015 + box.y / 2.0, 0), box, item[1], false)
			if fill == "ammo":
				_add_box(base + off + Vector3(0, y + 0.015 + box.y + 0.01, 0), Vector3(0.1, 0.02, 0.03), _mats.dark_steel, false)
			elif fill == "cans":
				_add_box(base + off + Vector3(0, y + 0.015 + box.y / 2.0, 0), box * Vector3(1.02, 0.4, 1.02), _mats.red, false)
	# One solid block for the whole unit, so it is not walked through.
	_add_collider(base + Vector3(0, height / 2.0, 0), Vector3(sx, height, sz))

func _crate(c: Vector3, size: Vector3, marked: bool) -> void:
	_add_box(c, size, _mats.wood, true)
	for sx in [-1.0, 1.0]:
		_add_box(c + Vector3(sx * (size.x / 2.0 - 0.03), 0, 0), Vector3(0.07, size.y + 0.01, size.z + 0.01), _mats.dark_wood, false)
	if marked:
		_add_box(c + Vector3(0, size.y / 2.0 + 0.003, 0), Vector3(size.x * 0.5, 0.006, 0.1), _mats.yellow, false)

func _table(base: Vector3, size: Vector2, height: float, top: Material) -> void:
	_add_box(base + Vector3(0, height - 0.025, 0), Vector3(size.x, 0.05, size.y), top, false)
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			_add_box(base + Vector3(cx * (size.x / 2.0 - 0.06), (height - 0.05) / 2.0, cz * (size.y / 2.0 - 0.06)), Vector3(0.05, height - 0.05, 0.05), _mats.dark_steel, false)
	_add_collider(base + Vector3(0, height / 2.0, 0), Vector3(size.x, height, size.y))

## An office chair facing north (-z), its seat centred over `base`.
func _chair(base: Vector3) -> void:
	_add_cyl(base + Vector3(0, 0.03, 0), 0.25, 0.04, _mats.black)
	_add_rod(base + Vector3(0, 0.05, 0), base + Vector3(0, 0.45, 0), 0.025, _mats.steel)
	_add_box(base + Vector3(0, 0.48, 0), Vector3(0.48, 0.07, 0.46), _mats.black, false)
	_add_box(base + Vector3(0, 0.8, 0.22), Vector3(0.44, 0.55, 0.05), _mats.black, false)
	_add_collider(base + Vector3(0, 0.45, 0), Vector3(0.5, 0.9, 0.5))

func _bunk(base: Vector3) -> void:
	var size := Vector3(0.95, 1.85, 2.05)
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			_add_box(base + Vector3(cx * (size.x / 2.0 - 0.025), size.y / 2.0, cz * (size.z / 2.0 - 0.025)), Vector3(0.05, size.y, 0.05), _mats.dark_steel, false)
	for y in [0.35, 1.4]:
		_add_box(base + Vector3(0, y, 0), Vector3(size.x, 0.05, size.z), _mats.dark_steel, false)
		_add_box(base + Vector3(0, y + 0.1, 0), Vector3(size.x - 0.06, 0.15, size.z - 0.06), _mats.mattress, false)
		_add_box(base + Vector3(0, y + 0.22, -size.z / 2.0 + 0.3), Vector3(0.6, 0.1, 0.35), _mats.pillow, false)
	_add_collider(base + Vector3(0, size.y / 2.0, 0), size)

# --- lights ----------------------------------------------------------------

## A ceiling LED strip down each room's long axis and an omni light every few
## metres along it; the stairwell has one light partway down.
func _build_lights() -> void:
	var sw: Rect2 = ROOMS.stairwell
	_add_light(Vector3(sw.get_center().x, -1.0, sw.get_center().y))
	for room: String in ROOMS:
		if room == "stairwell":
			continue
		var i := inner(room)
		var along_x := i.size.x >= i.size.y
		var long := i.size.x if along_x else i.size.y
		var strip := Vector3(long - 1.0, 0.03, 0.12) if along_x else Vector3(0.12, 0.03, long - 1.0)
		_add_box(Vector3(i.get_center().x, FLOOR_Y + ROOM_H - 0.02, i.get_center().y), strip, _mats.led, false)
		var n := maxi(1, roundi(long / 4.5))
		for k in n:
			var f := (k + 0.5) / n - 0.5
			var p := Vector3(i.get_center().x + (f * long if along_x else 0.0), FLOOR_Y + ROOM_H - 0.3, i.get_center().y + (0.0 if along_x else f * long))
			_add_light(p)

func _add_light(p: Vector3) -> void:
	var light := OmniLight3D.new()
	light.position = p
	light.omni_range = 4.5
	light.light_energy = 1.1
	light.light_color = Color(0.95, 0.97, 1.0)
	light.shadow_enabled = false
	light.visible = false
	add_child(light)
	_lights.append(light)

## An interior reflection probe over the shelter, so the sky's ambient light
## does not fill rooms that are underground; it brings its own soft fill.
func _build_probe() -> void:
	var probe := ReflectionProbe.new()
	probe.name = "Probe"
	var r := footprint()
	var top := -0.1
	probe.size = Vector3(r.size.x, top - (FLOOR_Y - 0.2), r.size.y)
	probe.position = Vector3(r.get_center().x, (top + FLOOR_Y - 0.2) / 2.0, r.get_center().y)
	probe.interior = true
	probe.ambient_mode = ReflectionProbe.AMBIENT_COLOR
	probe.ambient_color = Color(0.75, 0.78, 0.82)
	probe.ambient_color_energy = 0.35
	probe.blend_distance = 0.3
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	add_child(probe)

# --- helpers ---------------------------------------------------------------

func _add_box(pos: Vector3, size: Vector3, material: Material, collide: bool) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	add_child(mi)
	if collide:
		_add_collider(pos, size)

func _add_collider(pos: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = pos
	_walls_body.add_child(cs)

## A cylinder standing up at `pos`, or lying along x when `sideways` (a wall clock).
func _add_cyl(pos: Vector3, radius: float, height: float, material: Material, collide := false, sideways := false) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	if sideways:
		mi.rotation_degrees.z = 90.0
	add_child(mi)
	if collide:
		_add_collider(pos, Vector3(radius * 2.0, height, radius * 2.0))

## A thin round bar from `a` to `b`.
func _add_rod(a: Vector3, b: Vector3, radius: float, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 8
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	var dir := (b - a).normalized()
	var side := dir.cross(Vector3.RIGHT if absf(dir.x) < 0.9 else Vector3.FORWARD).normalized()
	mi.transform = Transform3D(Basis(side, dir, side.cross(dir)), (a + b) / 2.0)
	add_child(mi)
