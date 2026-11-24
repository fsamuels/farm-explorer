extends Node3D
## The duck and geese house (D-155, reoriented in D-157): a small wood-and-tin
## shed built from primitives, after the photos in Downloads/Duck and Geese House.
## It is 16 ft long (local Z, +Z = south) by 10 ft deep (local X, +X = toward the
## pen). The long east side is the front, facing the pen: boards low and chain
## link above, with an open bay at its north end where the geese walk in. The
## west side (the back, on the line of the west pen fence) and both ends are
## corrugated tin with wood rails inside. A shed roof slopes down to the back,
## the floor is sawdust, and two stock tanks (one bigger) lie side by side along
## the south pen fence, centred on TANKS_AT, where they show in the aerial photo.
##
## The node's origin is the centre of the floor and +X runs along the south pen
## fence. The Buildings entry of the same name keeps the map footprint and is
## made invisible and non-solid in main.tscn, the way the Shop's box is; this
## node carries the real collision.

const TerrainMath := preload("res://scripts/terrain_math.gd")

const FT := 0.3048
const LENGTH := 16.0 * FT
const DEPTH := 10.0 * FT
const WALL_T := 0.08
const BOARD_HEIGHT := 1.1
## The roof is low at the back (west) and high at the front (east).
const EAVE_FRONT := 2.35
const EAVE_BACK := 2.0
## The open bay in the front wall, from its north end.
const DOOR_WIDTH := 2.0
const DOOR_HEIGHT := 1.9
## Where the two tanks' shared centre is in the world (x, z), read off the aerial photo.
const TANKS_AT := Vector2(12.9, 17.6)

const BOARD_COLOR := Color(0.36, 0.2, 0.1)
const TIN_COLOR := Color(0.72, 0.75, 0.78)
const POST_COLOR := Color(0.26, 0.17, 0.1)
const RAIL_COLOR := Color(0.3, 0.17, 0.1)
const ROOF_COLOR := Color(0.3, 0.2, 0.12)
const SAWDUST_COLOR := Color(0.72, 0.6, 0.42)
const TANK_COLOR := Color(0.62, 0.62, 0.6)
const WATER_COLOR := Color(0.25, 0.32, 0.22)

## Where the doorway sits along the front (east) wall, as local z from..to.
static func door_span() -> Vector2:
	var north := -LENGTH * 0.5
	return Vector2(north, north + DOOR_WIDTH)

## The height of the roof's underside at local x.
static func roof_height(x: float) -> float:
	return EAVE_BACK - (x + DEPTH * 0.5) / DEPTH * (EAVE_BACK - EAVE_FRONT)

## Where the birds spend the early evening, in the pen, as a point in front of the
## doorway (local x toward the pen, z from the middle), and how far they spread.
const PEN_SPOT := Vector2(4.5, -2.0)
const PEN_RADIUS := 2.5
## How far inside the front wall the roost spreads, and how far outside the doorway
## the birds line up before they go in.
const ROOST_RADIUS := 0.9
const DOOR_OUTSIDE := 0.9

## Local point just outside, and just inside, the middle of the doorway.
static func door_outside_local() -> Vector2:
	var span := door_span()
	return Vector2(DEPTH * 0.5 + DOOR_OUTSIDE, (span.x + span.y) * 0.5)

static func door_inside_local() -> Vector2:
	var span := door_span()
	return Vector2(DEPTH * 0.5 - 0.7, (span.x + span.y) * 0.5)

## World (x, z) of a local (x, z) point on this house.
func world_xz(local: Vector2) -> Vector2:
	var p := to_global(Vector3(local.x, 0.0, local.y))
	return Vector2(p.x, p.z)

func pen_point() -> Vector2:
	return world_xz(PEN_SPOT)

func door_outside() -> Vector2:
	return world_xz(door_outside_local())

func door_inside() -> Vector2:
	return world_xz(door_inside_local())

func roost_point() -> Vector2:
	return world_xz(Vector2(-0.3, 0.3))

func _ready() -> void:
	add_to_group("duck_house")
	# Sit on the ground; the foot of the walls follows the carved terrain.
	position.y = TerrainMath.height_at(global_position.x, global_position.z)
	_build()

func _build() -> void:
	for child in get_children():
		child.queue_free()
	var hx := DEPTH * 0.5
	var hz := LENGTH * 0.5
	var body := StaticBody3D.new()
	body.name = "Walls"
	add_child(body)

	# Floor of sawdust, just above the ground.
	_box(self, Vector3(DEPTH - 0.1, 0.06, LENGTH - 0.1), Vector3(0.0, 0.03, 0.0), SAWDUST_COLOR)

	# Corner posts.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var h := EAVE_BACK if sx < 0.0 else EAVE_FRONT
			_box(self, Vector3(0.14, h, 0.14), Vector3(sx * hx, h * 0.5, sz * hz), POST_COLOR)

	# Back (west) wall: tin the full height. Both ends: tin, stepping down with the roof.
	_box(body, Vector3(WALL_T, EAVE_BACK, LENGTH), Vector3(-hx, EAVE_BACK * 0.5, 0.0), TIN_COLOR, true)
	for sz in [-1.0, 1.0]:
		_end_wall(body, sz * hz)
	_rails(hx, hz)

	# Front (east) wall: boards low and chain link above, from the doorway to the
	# south corner, and a header over the doorway.
	var door := door_span()
	var solid_len := hz - door.y
	var solid_mid := (door.y + hz) * 0.5
	_box(body, Vector3(WALL_T, BOARD_HEIGHT, solid_len), Vector3(hx, BOARD_HEIGHT * 0.5, solid_mid), BOARD_COLOR, true)
	var link_h := EAVE_FRONT - BOARD_HEIGHT
	var link := _box(body, Vector3(WALL_T * 0.5, link_h, solid_len), Vector3(hx, BOARD_HEIGHT + link_h * 0.5, solid_mid), Color(0.7, 0.72, 0.74, 0.35), true)
	(link.material_override as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var header_h := EAVE_FRONT - DOOR_HEIGHT
	_box(body, Vector3(WALL_T, header_h, DOOR_WIDTH), Vector3(hx, DOOR_HEIGHT + header_h * 0.5, (door.x + door.y) * 0.5), BOARD_COLOR, true)

	_roof(body)
	_tanks()

## An end wall (north or south) at local z: tin from the floor up to the roof, in
## short slices that each stop just under the roof.
func _end_wall(body: StaticBody3D, z: float) -> void:
	var slices := maxi(1, ceili(DEPTH / 0.5))
	var slice_len := DEPTH / slices
	for k in slices:
		var x0 := -DEPTH * 0.5 + slice_len * k
		var top := roof_height(x0 + slice_len) - 0.02
		_box(body, Vector3(slice_len, top, WALL_T * 0.6), Vector3(x0 + slice_len * 0.5, top * 0.5, z), TIN_COLOR, true)

## The wood rails along the inside of the back wall and the ends.
func _rails(hx: float, hz: float) -> void:
	for y in [0.55, 1.2]:
		_box(self, Vector3(0.05, 0.14, LENGTH - 0.2), Vector3(-hx + 0.07, y, 0.0), RAIL_COLOR)
		for sz in [-1.0, 1.0]:
			_box(self, Vector3(DEPTH - 0.3, 0.14, 0.05), Vector3(0.0, y, sz * (hz - 0.07)), RAIL_COLOR)

## The shed roof: a slab sloping down to the back, with a little overhang.
func _roof(body: StaticBody3D) -> void:
	var rise := EAVE_BACK - EAVE_FRONT
	var slope := -atan2(rise, DEPTH)
	var length := sqrt(DEPTH * DEPTH + rise * rise) + 0.5
	var roof := _box(body, Vector3(length, 0.07, LENGTH + 0.5), Vector3(0.0, (EAVE_BACK + EAVE_FRONT) * 0.5 + 0.04, 0.0), ROOF_COLOR, true)
	roof.rotation.z = slope
	# The collision shape is a sibling of the mesh, so tilt it the same way.
	(body.get_child(body.get_child_count() - 1) as CollisionShape3D).rotation.z = slope

## Two grey stock tanks (one bigger) side by side along the fence line, centred
## on TANKS_AT, each with a little water in it.
func _tanks() -> void:
	var centre := to_local(Vector3(TANKS_AT.x, global_position.y, TANKS_AT.y))
	var sizes := [Vector2(1.5, 0.85), Vector2(1.25, 0.75)]
	var xs := [-0.7, 0.65]
	for i in 2:
		var tank := Node3D.new()
		tank.name = "Tank%d" % (i + 1)
		tank.position = Vector3(centre.x + xs[i], 0.0, centre.z)
		add_child(tank)
		var size: Vector2 = sizes[i]
		_box(tank, Vector3(size.x, 0.36, size.y), Vector3(0.0, 0.18, 0.0), TANK_COLOR)
		_box(tank, Vector3(size.x - 0.14, 0.02, size.y - 0.14), Vector3(0.0, 0.37, 0.0), WATER_COLOR)

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
