extends Node3D
## The duck and geese house (D-155): a small wood-and-tin shed built from
## primitives, after the photos in Downloads/Duck and Geese House. It is 16 ft
## wide (local X, along the pen fence) by 10 ft deep (local Z, +Z = south) with
## its south wall on the line of the pen fence. The back and west walls are wood
## boards over corrugated tin; the south wall is boards under chain link; the
## east wall (the pen side) is boards under chain link with an open doorway at
## its south end, where the geese walk in. A pitched shed roof slopes to the
## south, there is sawdust on the floor, and two stock tanks stand outside the
## doorway for the ducks.
##
## The node's origin is the centre of the floor, +X runs along the fence. The
## Buildings entry of the same name keeps the map footprint and is made
## invisible and non-solid in main.tscn, the way the Shop's box is; this node
## carries the real collision.

const TerrainMath := preload("res://scripts/terrain_math.gd")

const FT := 0.3048
const WIDTH := 16.0 * FT
const DEPTH := 10.0 * FT
const WALL_T := 0.08
const BOARD_HEIGHT := 1.1
const EAVE_SOUTH := 2.0
const EAVE_NORTH := 2.35
## The doorway in the east wall: this wide, from the south corner post.
const DOOR_WIDTH := 1.5

const BOARD_COLOR := Color(0.36, 0.2, 0.1)
const TIN_COLOR := Color(0.72, 0.75, 0.78)
const POST_COLOR := Color(0.26, 0.17, 0.1)
const ROOF_COLOR := Color(0.3, 0.2, 0.12)
const SAWDUST_COLOR := Color(0.72, 0.6, 0.42)
const TANK_COLOR := Color(0.62, 0.62, 0.6)
const WATER_COLOR := Color(0.25, 0.32, 0.22)

## Where the doorway sits along the east wall, as local z from..to.
static func door_span() -> Vector2:
	var south := DEPTH * 0.5
	return Vector2(south - DOOR_WIDTH, south)

func _ready() -> void:
	# Sit on the ground; the foot of the walls follows the carved terrain.
	var ground := TerrainMath.height_at(global_position.x, global_position.z)
	position.y = ground
	_build()

func _build() -> void:
	for child in get_children():
		child.queue_free()
	var hx := WIDTH * 0.5
	var hz := DEPTH * 0.5
	var body := StaticBody3D.new()
	body.name = "Walls"
	add_child(body)

	# Floor of sawdust, just above the ground.
	_box(self, Vector3(WIDTH - 0.1, 0.06, DEPTH - 0.1), Vector3(0.0, 0.03, 0.0), SAWDUST_COLOR)

	# Corner posts.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var h := EAVE_NORTH if sz < 0.0 else EAVE_SOUTH
			_box(self, Vector3(0.14, h, 0.14), Vector3(sx * hx, h * 0.5, sz * hz), POST_COLOR)

	# North (back) and west walls: boards low, tin above.
	_wall(body, Vector3(0.0, 0.0, -hz), WIDTH, EAVE_NORTH, true, true)
	_wall(body, Vector3(-hx, 0.0, 0.0), DEPTH, EAVE_NORTH, true, true, true)
	# South wall: boards low, chain link above.
	_wall(body, Vector3(0.0, 0.0, hz), WIDTH, EAVE_SOUTH, true, false)
	# East wall (the pen side): the same, from the north corner up to the doorway.
	var door := door_span()
	var solid_len := door.x + hz
	_wall(body, Vector3(hx, 0.0, -hz + solid_len * 0.5), solid_len, EAVE_NORTH, true, false, true)
	# A header over the doorway.
	var header_h := EAVE_SOUTH - 1.9
	_box(body, Vector3(WALL_T, header_h, DOOR_WIDTH), Vector3(hx, 1.9 + header_h * 0.5, (door.x + door.y) * 0.5), BOARD_COLOR, true)

	_roof(body)
	_tanks()

## One wall panel standing on the floor, centred at `at` (y ignored), `length`
## long, `height` tall. `solid_upper` picks tin over chain link above the
## boards; `along_z` is for the west and east walls, which run along local Z.
func _wall(body: StaticBody3D, at: Vector3, length: float, height: float, boards: bool, solid_upper: bool, along_z := false) -> void:
	var size_low := Vector3(WALL_T, BOARD_HEIGHT, length) if along_z else Vector3(length, BOARD_HEIGHT, WALL_T)
	var upper_h := height - BOARD_HEIGHT
	var size_up := Vector3(WALL_T * 0.5, upper_h, length) if along_z else Vector3(length, upper_h, WALL_T * 0.5)
	if boards:
		_box(body, size_low, Vector3(at.x, BOARD_HEIGHT * 0.5, at.z), BOARD_COLOR, true)
	var upper_at := Vector3(at.x, BOARD_HEIGHT + upper_h * 0.5, at.z)
	if solid_upper:
		_box(body, size_up, upper_at, TIN_COLOR, true)
	else:
		# Chain link: a thin pale panel you can't see through well but that is
		# still solid, so nothing walks or flies through the screen.
		var link := _box(body, size_up, upper_at, Color(0.7, 0.72, 0.74, 0.35), true)
		var mat := link.material_override as StandardMaterial3D
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

## The shed roof: a slab sloping down to the south, with a little overhang.
func _roof(body: StaticBody3D) -> void:
	var rise := EAVE_NORTH - EAVE_SOUTH
	var slope := atan2(rise, DEPTH)
	var length := sqrt(DEPTH * DEPTH + rise * rise) + 0.5
	var roof := _box(body, Vector3(WIDTH + 0.5, 0.07, length), Vector3(0.0, (EAVE_NORTH + EAVE_SOUTH) * 0.5 + 0.04, 0.0), ROOF_COLOR, true)
	roof.rotation.x = slope
	# The collision shape is a sibling of the mesh, so tilt it the same way.
	var shape_node := body.get_child(body.get_child_count() - 1) as CollisionShape3D
	shape_node.rotation.x = slope

## Two grey stock tanks outside the doorway, with a little water in each.
func _tanks() -> void:
	for i in 2:
		var z := -0.55 + 0.75 * i - 0.6
		var tank := Node3D.new()
		tank.name = "Tank%d" % (i + 1)
		tank.position = Vector3(WIDTH * 0.5 + 1.0, 0.0, z)
		add_child(tank)
		_box(tank, Vector3(0.7, 0.36, 1.3), Vector3(0.0, 0.18, 0.0), TANK_COLOR)
		_box(tank, Vector3(0.56, 0.02, 1.16), Vector3(0.0, 0.37, 0.0), WATER_COLOR)

## Adds a box mesh under `parent` (and a matching collision shape when `solid`
## and `parent` is a StaticBody3D). Returns the mesh.
func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color, solid := false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = at
	parent.add_child(node)
	if solid and parent is StaticBody3D:
		var shape := BoxShape3D.new()
		shape.size = size
		var col := CollisionShape3D.new()
		col.shape = shape
		col.position = at
		parent.add_child(col)
	return node
