extends Node3D
## The bomb shelter under the House (D-145): a wooden trap door in the House's
## floor opens on concrete stairs down to a modern multi-room shelter. A steel
## blast door at the foot of the stairs gives onto a corridor, with a munitions
## store, a bunk room and a utility room off it, each behind a steel door.
##
## Everything is built in code from boxes and cylinders, in the same frame as
## the House's shell (building_shell.gd `frame_for`): x across the House, z along
## it, y up from the ground. Layout numbers are in the constants below. Rooms are
## Rect2s in (x, z), each with its own four walls set just inside its edges, so
## two rooms that share an edge stand back to back. A door on a shared edge cuts
## both walls and hangs on the edge line.
##
## It also cuts the ground (terrain.gd, `terrain_holes`) where the stairs go down
## and asks the House's shell to cut its floor there (`hatch_rect`). The ground
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
## Top of the House's floor (building_shell.gd FLOOR_TOP).
const HOUSE_FLOOR := 0.05
## The stairs: inner width, where the top step starts (z), the run and how many
## risers. The hatch over them is `HATCH_LEN` long.
const STAIR_X0 := 3.0
const STAIR_W := 1.2
const STAIR_Z0 := -6.2
const STAIR_RUN := 4.2
const RISERS := 16
const HATCH_LEN := 3.0
## How far the cut in the ground reaches past the hatch, hidden under the floor.
const HOLE_MARGIN := 0.25
const DOOR_H := 2.1

## Rooms: name -> Rect2(x, z, width, depth) of the outside of the walls.
const ROOMS := {
	"stairwell": Rect2(2.85, -6.35, 1.5, 4.5),
	"corridor": Rect2(-5.0, -1.85, 10.0, 2.2),
	"munitions": Rect2(-5.0, -6.35, 7.85, 4.5),
	"bunks": Rect2(-5.0, 0.35, 5.5, 6.0),
	"utility": Rect2(0.5, 0.35, 4.5, 6.0),
}
## Doors on shared edges: x along the edge, z the edge line (all on z lines),
## which room the leaf swings into and that room's wall.
const DOORS := [
	{x = 3.6, z = -1.85, w = 1.2, room = "corridor", wall = "north", label = "blast door", blast = true},
	{x = -1.0, z = -1.85, w = 1.0, room = "munitions", wall = "south", label = "munitions store door"},
	{x = -2.0, z = 0.35, w = 1.0, room = "bunks", wall = "north", label = "bunk room door"},
	{x = 2.75, z = 0.35, w = 1.0, room = "utility", wall = "north", label = "utility room door"},
]

## The building whose floor the hatch is in (building_shell.gd reads this).
@export var hatch_building := "House"

var trap_door: Node3D
var _box: Node3D
var _walls_body: StaticBody3D
var _lights: Array[OmniLight3D] = []
var _mats := {}

func _enter_tree() -> void:
	add_to_group("terrain_hole")
	add_to_group("floor_hatch")

## The hatch in the House's floor, in the shell's (x, z).
func hatch_rect() -> Rect2:
	return Rect2(STAIR_X0, STAIR_Z0, STAIR_W, HATCH_LEN)

## How long each step's tread is and how high each riser.
static func tread() -> float:
	return STAIR_RUN / RISERS

static func rise() -> float:
	return (HOUSE_FLOOR - FLOOR_Y) / RISERS

## The walking ramp's slope (rise over run). It leaves the House's floor level
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
	_furnish_bunks()
	_furnish_utility()
	_build_lights()
	_build_probe()

## Lights only while the camera is down here or near the hatch: unshadowed,
## they would otherwise light the House's walls from below.
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
	# The stairwell's ceiling where the House's floor is over it (past the hatch).
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
	# where it is under the House's floor, so a closed trap door clears it.
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

func _furnish_corridor() -> void:
	var r: Rect2 = ROOMS.corridor
	# LED strips down the middle of the ceiling.
	_add_box(Vector3(r.get_center().x, FLOOR_Y + ROOM_H - 0.02, r.get_center().y), Vector3(r.size.x - 1.0, 0.03, 0.12), _mats.led, false)
	# A painted guide stripe low on the south wall, and a fire extinguisher.
	_add_box(Vector3(r.get_center().x, FLOOR_Y + 1.0, r.end.y - WALL_T - 0.005), Vector3(r.size.x - 0.4, 0.12, 0.01), _mats.yellow, false)
	_add_cyl(Vector3(r.position.x + 0.4, FLOOR_Y + 0.35, r.position.y + 0.35), 0.09, 0.6, _mats.red)
	# The stairwell gets a strip over the foot of the stairs.
	var s: Rect2 = ROOMS.stairwell
	_add_box(Vector3(s.get_center().x, -0.12, s.end.y - 0.6), Vector3(0.12, 0.03, 0.8), _mats.led, false)

func _furnish_munitions() -> void:
	var r: Rect2 = ROOMS.munitions
	var x0 := r.position.x + WALL_T
	var x1 := r.end.x - WALL_T
	var z0 := r.position.y + WALL_T
	var z1 := r.end.y - WALL_T
	_add_box(Vector3(r.get_center().x, FLOOR_Y + ROOM_H - 0.02, r.get_center().y), Vector3(r.size.x - 1.2, 0.03, 0.12), _mats.led, false)
	# Steel shelving along the north wall, loaded with olive ammo cans.
	for cx in [x0 + 1.05, x0 + 3.05, x0 + 5.05]:
		_shelf_unit(Vector3(cx, FLOOR_Y, z0 + 0.32), Vector2(1.8, 0.55), 2.0, 4, "ammo")
	# A long-gun rack on the west wall.
	_add_box(Vector3(x0 + 0.12, FLOOR_Y + 0.15, (z0 + z1) / 2.0), Vector3(0.24, 0.3, 2.2), _mats.dark_steel, true)
	_add_box(Vector3(x0 + 0.05, FLOOR_Y + 1.3, (z0 + z1) / 2.0), Vector3(0.1, 0.06, 2.2), _mats.dark_steel, false)
	for i in 8:
		var z := (z0 + z1) / 2.0 - 0.95 + i * 0.27
		_add_box(Vector3(x0 + 0.13, FLOOR_Y + 0.45, z), Vector3(0.07, 0.3, 0.05), _mats.black, false)  # stock
		_add_box(Vector3(x0 + 0.1, FLOOR_Y + 0.85, z), Vector3(0.05, 0.55, 0.04), _mats.black, false)  # receiver
		_add_rod(Vector3(x0 + 0.08, FLOOR_Y + 1.1, z), Vector3(x0 + 0.08, FLOOR_Y + 1.55, z), 0.012, _mats.dark_steel)
	# Wooden crates on pallets along the east wall, some marked yellow.
	for row in 2:
		var pz := z1 - 0.9 - row * 1.45
		_add_box(Vector3(x1 - 0.65, FLOOR_Y + 0.07, pz), Vector3(1.2, 0.14, 1.2), _mats.wood, true)
		for layer in 2 - row:
			for col in 2:
				var c := Vector3(x1 - 0.95 + col * 0.6, FLOOR_Y + 0.14 + 0.25 + layer * 0.5, pz)
				_crate(c, Vector3(0.56, 0.48, 1.1), (col + layer + row) % 2 == 0)
	# A steel table in the middle with an open ammo can and a few shells.
	var t := Vector3(-1.6, FLOOR_Y, z0 + 2.3)
	_table(t, Vector2(1.6, 0.8), 0.9, _mats.steel)
	_add_box(t + Vector3(-0.3, 0.9 + 0.1, 0.0), Vector3(0.32, 0.2, 0.16), _mats.olive, false)
	for i in 5:
		_add_cyl(t + Vector3(0.2 + i * 0.09, 0.9 + 0.08, 0.1), 0.025, 0.16, _mats.yellow)

func _furnish_bunks() -> void:
	var r: Rect2 = ROOMS.bunks
	var x0 := r.position.x + WALL_T
	var x1 := r.end.x - WALL_T
	var z1 := r.end.y - WALL_T
	for z in [r.position.y + 0.75, r.position.y + 3.2]:
		_add_box(Vector3(r.get_center().x, FLOOR_Y + ROOM_H - 0.02, z + 1.0), Vector3(r.size.x - 1.5, 0.03, 0.12), _mats.led, false)
	# Two steel bunk beds along the west wall.
	for z in [r.position.y + 1.4, r.position.y + 3.9]:
		_bunk(Vector3(x0 + 0.5, FLOOR_Y, z))
	# A table with four stools.
	var t := Vector3(-1.8, FLOOR_Y, r.position.y + 3.2)
	_table(t, Vector2(0.9, 1.5), 0.75, _mats.wood)
	for s in [Vector3(-0.75, 0, -0.4), Vector3(-0.75, 0, 0.4), Vector3(0.75, 0, -0.4), Vector3(0.75, 0, 0.4)]:
		_add_cyl(t + s + Vector3(0, 0.23, 0), 0.03, 0.46, _mats.steel)
		_add_cyl(t + s + Vector3(0, 0.47, 0), 0.18, 0.04, _mats.dark_steel)
	# A kitchenette on the east wall: counter, sink, cupboards.
	var kz := r.position.y + 3.6
	_add_box(Vector3(x1 - 0.3, FLOOR_Y + 0.45, kz), Vector3(0.6, 0.9, 2.4), _mats.wall, true)
	_add_box(Vector3(x1 - 0.3, FLOOR_Y + 0.92, kz), Vector3(0.62, 0.04, 2.42), _mats.dark_steel, false)
	_add_box(Vector3(x1 - 0.3, FLOOR_Y + 0.93, kz - 0.5), Vector3(0.4, 0.02, 0.5), _mats.steel, false)
	_add_box(Vector3(x1 - 0.18, FLOOR_Y + 1.85, kz), Vector3(0.36, 0.7, 2.4), _mats.wall, false)
	# A status screen on the south wall.
	_add_box(Vector3(-1.8, FLOOR_Y + 1.5, z1 - 0.03), Vector3(1.2, 0.7, 0.04), _mats.black, false)
	_add_box(Vector3(-1.8, FLOOR_Y + 1.5, z1 - 0.055), Vector3(1.1, 0.6, 0.01), _mats.screen, false)

func _furnish_utility() -> void:
	var r: Rect2 = ROOMS.utility
	var x0 := r.position.x + WALL_T
	var x1 := r.end.x - WALL_T
	var z1 := r.end.y - WALL_T
	_add_box(Vector3(r.get_center().x, FLOOR_Y + ROOM_H - 0.02, r.get_center().y), Vector3(0.12, 0.03, r.size.y - 1.4), _mats.led, false)
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
	for i in 3:
		_add_box(p + Vector3(0.065, 0.3 - i * 0.12, -0.2), Vector3(0.01, 0.04, 0.04), _mats.green_led if i < 2 else _mats.red_led, false)
	_shelf_unit(Vector3(x0 + 0.3, FLOOR_Y, r.position.y + 3.4), Vector2(0.5, 2.0), 2.0, 5, "supplies", true)

## A steel shelving unit centred on `base` (floor level), `size` (x, z) in plan.
## `fill` "ammo" or "supplies" picks what sits on the shelves. With `along_z`
## the long side runs along z.
func _shelf_unit(base: Vector3, size: Vector2, height: float, shelves: int, fill: String, along_z := false) -> void:
	var sx := size.x
	var sz := size.y
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			_add_box(base + Vector3(cx * (sx / 2.0 - 0.02), height / 2.0, cz * (sz / 2.0 - 0.02)), Vector3(0.04, height, 0.04), _mats.steel, false)
	var long := sz if along_z else sx
	for i in shelves:
		var y := 0.1 + i * (height - 0.2) / (shelves - 1)
		_add_box(base + Vector3(0, y, 0), Vector3(sx, 0.03, sz), _mats.steel, false)
		if i == shelves - 1:
			continue
		var count := floori(long / 0.36)
		for k in count:
			var a := -long / 2.0 + (k + 0.5) * long / count
			var off := Vector3(0, 0, a) if along_z else Vector3(a, 0, 0)
			if fill == "ammo":
				var can := Vector3(0.3, 0.19, 0.16)
				_add_box(base + off + Vector3(0, y + 0.015 + can.y / 2.0, 0), can if not along_z else Vector3(can.z, can.y, can.x), _mats.olive, false)
				_add_box(base + off + Vector3(0, y + 0.015 + can.y + 0.01, 0), Vector3(0.1, 0.02, 0.03), _mats.dark_steel, false)
			elif (k + i) % 3 != 2:
				var crate := Vector3(0.3, 0.26, 0.4)
				_add_box(base + off + Vector3(0, y + 0.015 + crate.y / 2.0, 0), crate if not along_z else Vector3(crate.z, crate.y, crate.x), _mats.cardboard, false)
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

func _build_lights() -> void:
	var spots := [
		Vector3(3.6, -1.0, -3.0),
		Vector3(-2.5, FLOOR_Y + ROOM_H - 0.3, -0.75), Vector3(2.0, FLOOR_Y + ROOM_H - 0.3, -0.75),
		Vector3(-2.0, FLOOR_Y + ROOM_H - 0.3, -4.1),
		Vector3(-2.3, FLOOR_Y + ROOM_H - 0.3, 2.3), Vector3(-2.3, FLOOR_Y + ROOM_H - 0.3, 4.7),
		Vector3(2.75, FLOOR_Y + ROOM_H - 0.3, 3.3),
	]
	for p in spots:
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

func _add_cyl(pos: Vector3, radius: float, height: float, material: Material, collide := false) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
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
