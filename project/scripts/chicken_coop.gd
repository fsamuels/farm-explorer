extends Node3D
## The chicken coop (D-164): a walk-in red-stained run with a tan, windowed
## roosting house at one end, built from primitives after the photos in
## Downloads/Chicken coop.
##
## It is 8 ft wide (local X) by 6 ft deep (local Z). Local +Z is the front, the
## face with the door, toward the farmhouse. At the -X end sits the roosting house: tan boards with a
## three-pane white window on the front, a mesh run underneath, and a white
## nest box with a hinged lid on its outer end. The rest of the front is the
## door (open, its leaf swung back) and a mesh panel. Everything is wire mesh
## in a red frame, with a shed roof of galvanized corrugated steel that is high at the front,
## overhangs on red brackets and slopes down to the back. The floor is bare dirt with a
## plank sill.
##
## The roof slopes down toward the back, away from the door, and the whole coop
## is squared to the south wall of the farmhouse, with its door on the house side.
##
## The node's origin is the centre of the floor. The Buildings entry of the same
## name keeps the map footprint and is made invisible and non-solid in
## main.tscn, as the duck house's is; this node carries the real collision.

const TerrainMath := preload("res://scripts/terrain_math.gd")

const FT := 0.3048
const WIDTH := 8.0 * FT
const DEPTH := 6.0 * FT
const FRAME := 0.07
## The roof is high at the front (+Z, the door side) and low at the back.
const EAVE_HIGH := 2.3
const EAVE_LOW := 1.95
## The roosting house: its width, and the bottom of its tan boards.
const HOUSE_WIDTH := 0.95
const HOUSE_FLOOR := 0.95
## The doorway in the front wall, from the house's edge.
const DOOR_WIDTH := 0.85
const DOOR_HEIGHT := 1.75
const DOOR_GAP := 0.08
## Where the coop stands in the world (x, z).
const AT := Vector2(48.7, -14.6)
## Along the farmhouse's south wall (its local X axis in main.tscn, in world x, z).
const HOUSE_SOUTH_WALL := Vector2(10.644, 3.9134)

const RED := Color(0.55, 0.13, 0.08)
const TAN := Color(0.78, 0.68, 0.5)
const WHITE := Color(0.92, 0.92, 0.9)
const TIN := Color(0.74, 0.77, 0.79)
const SILL := Color(0.45, 0.28, 0.14)
const DIRT := Color(0.38, 0.3, 0.22)
const MESH := Color(0.7, 0.72, 0.74, 0.3)
const GLASS := Color(0.3, 0.34, 0.36, 0.75)

## Yaw (radians) that turns local +Z to face the point `target` from `from`.
static func facing_yaw(from: Vector2, target: Vector2) -> float:
	var d := target - from
	return atan2(d.x, d.y)

## The front's direction in world (x, z): square to the house's south wall,
## toward the house (north of the wall).
static func front_dir() -> Vector2:
	return Vector2(HOUSE_SOUTH_WALL.y, -HOUSE_SOUTH_WALL.x).normalized()

## The roof's underside height at local z (high at the front, +Z).
static func roof_height(z: float) -> float:
	var t := (z + DEPTH * 0.5) / DEPTH
	return lerpf(EAVE_LOW, EAVE_HIGH, t)

## The doorway along the front wall, as local x from..to.
static func door_span() -> Vector2:
	var x0 := -WIDTH * 0.5 + HOUSE_WIDTH + DOOR_GAP
	return Vector2(x0, x0 + DOOR_WIDTH)

## World (x, z) of a local (x, z) point on this coop.
func world_xz(local: Vector2) -> Vector2:
	var p := to_global(Vector3(local.x, 0.0, local.y))
	return Vector2(p.x, p.z)

## The point just outside the middle of the doorway, in world (x, z).
func door_outside() -> Vector2:
	var span := door_span()
	return world_xz(Vector2((span.x + span.y) * 0.5, DEPTH * 0.5 + 0.8))

## How far outside the walls the chickens keep when they walk round the coop, and
## how far they spread inside (D-166). Chickens use the coop the way the ducks
## use their house (see wander.gd): in at the door at night, out again at dawn.
const CORNER_CLEARANCE := 0.7
const CROSS_MARGIN := 0.15
const ROOST_RADIUS := 0.45
const PEN_RADIUS := 2.0

func pen_radius() -> float:
	return PEN_RADIUS

func roost_radius() -> float:
	return ROOST_RADIUS

## World (x, z) point `p` in this coop's local x, z.
func local_xz(p: Vector2) -> Vector2:
	var q := to_local(Vector3(p.x, global_position.y, p.y))
	return Vector2(q.x, q.z)

## True if world point `p` is within the coop's walls.
func is_inside(p: Vector2) -> bool:
	var q := local_xz(p)
	return absf(q.x) < WIDTH * 0.5 and absf(q.y) < DEPTH * 0.5

## True if `p` is inside the coop or too close to its walls to stand there.
func is_blocked(p: Vector2) -> bool:
	var q := local_xz(p)
	return absf(q.x) < WIDTH * 0.5 + CORNER_CLEARANCE and absf(q.y) < DEPTH * 0.5 + CORNER_CLEARANCE

func door_inside() -> Vector2:
	var span := door_span()
	return world_xz(Vector2((span.x + span.y) * 0.5, DEPTH * 0.5 - 0.45))

func roost_point() -> Vector2:
	return world_xz(Vector2(0.2, -0.2))

func pen_point() -> Vector2:
	return door_outside()

## The coop's four corners, pushed out by CORNER_CLEARANCE, in world (x, z).
func _corners() -> Array[Vector2]:
	var hx := WIDTH * 0.5 + CORNER_CLEARANCE
	var hz := DEPTH * 0.5 + CORNER_CLEARANCE
	return [world_xz(Vector2(-hx, -hz)), world_xz(Vector2(hx, -hz)), world_xz(Vector2(hx, hz)), world_xz(Vector2(-hx, hz))]

## True if the straight walk from `a` to `b` goes through the coop's walls or
## within CROSS_MARGIN of them (less than the corner clearance, so a bird that
## has strayed close to a wall is still sent round it).
func crosses_coop(a: Vector2, b: Vector2) -> bool:
	var qa := local_xz(a)
	var qb := local_xz(b)
	var hx := WIDTH * 0.5 + CROSS_MARGIN
	var hz := DEPTH * 0.5 + CROSS_MARGIN
	for i in 21:
		var q := qa.lerp(qb, i / 20.0)
		if absf(q.x) < hx and absf(q.y) < hz:
			return true
	return false

## Waypoints that take a bird from `a` to `b` round the coop instead of through
## it: one corner if that clears it, else two. Empty if the straight walk is clear.
func detour_round_pen(a: Vector2, b: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if is_inside(a) or is_inside(b) or not crosses_coop(a, b):
		return out
	var corners := _corners()
	var best := INF
	for i in 4:
		var c := corners[i]
		if not crosses_coop(a, c) and not crosses_coop(c, b):
			var len := a.distance_to(c) + c.distance_to(b)
			if len < best:
				best = len
				out = [c]
	if not out.is_empty():
		return out
	for i in 4:
		var c1 := corners[i]
		var c2 := corners[(i + 1) % 4]
		if not crosses_coop(a, c1) and not crosses_coop(c2, b):
			var len := a.distance_to(c1) + c1.distance_to(c2) + c2.distance_to(b)
			if len < best:
				best = len
				out = [c1, c2]
		c1 = corners[(i + 1) % 4]
		c2 = corners[i]
		if not crosses_coop(a, c1) and not crosses_coop(c2, b):
			var len2 := a.distance_to(c1) + c1.distance_to(c2) + c2.distance_to(b)
			if len2 < best:
				best = len2
				out = [c1, c2]
	return out

## Waypoints from anywhere to just outside the door: out of the coop through the
## door if inside, else round the walls.
func route_to_pen_front(p: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if is_inside(p):
		out.append(door_inside())
		out.append(door_outside())
		return out
	return detour_round_pen(p, door_outside())

## Waypoints out of the door if inside; empty otherwise.
func route_out_of_pen(p: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if is_inside(p):
		out.append(door_inside())
		out.append(door_outside())
	return out

func _ready() -> void:
	add_to_group("chicken_coop")
	# Stand at AT, square to the house's south wall with the door toward the house.
	rotation.y = facing_yaw(Vector2.ZERO, front_dir())
	position = Vector3(AT.x, TerrainMath.height_at(AT.x, AT.y), AT.y)
	_build()

func _build() -> void:
	for child in get_children():
		child.queue_free()
	var hx := WIDTH * 0.5
	var hz := DEPTH * 0.5
	var body := StaticBody3D.new()
	body.name = "Walls"
	add_child(body)

	# Dirt floor and the plank sill round it.
	_box(self, Vector3(WIDTH - 0.1, 0.04, DEPTH - 0.1), Vector3(0.0, 0.02, 0.0), DIRT)
	_box(body, Vector3(WIDTH, 0.12, 0.1), Vector3(0.0, 0.06, -hz + 0.05), SILL, true)
	_box(body, Vector3(0.1, 0.12, DEPTH - 0.2), Vector3(-hx + 0.05, 0.06, 0.0), SILL, true)
	_box(body, Vector3(0.1, 0.12, DEPTH - 0.2), Vector3(hx - 0.05, 0.06, 0.0), SILL, true)
	var door := door_span()
	_box(body, Vector3(door.x + hx, 0.12, 0.1), Vector3((door.x - hx) * 0.5, 0.06, hz - 0.05), SILL, true)
	_box(body, Vector3(hx - door.y, 0.12, 0.1), Vector3((door.y + hx) * 0.5, 0.06, hz - 0.05), SILL, true)

	# Corner posts, tall at the front, lower at the back.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var h := roof_height(sz * hz) - 0.05
			_box(body, Vector3(FRAME, h, FRAME), Vector3(sx * (hx - FRAME * 0.5), h * 0.5, sz * (hz - FRAME * 0.5)), RED, true)

	_roosting_house(body, hx, hz)
	_run_walls(body, hx, hz)
	_door(hx, hz)
	_roof(body)

## The tan roosting house at the -X end: boards above HOUSE_FLOOR on all three
## outside faces, a window in the front, a nest box on the outer end.
func _roosting_house(body: StaticBody3D, hx: float, hz: float) -> void:
	var h_front := roof_height(hz) - 0.06 - HOUSE_FLOOR
	var h_back := roof_height(-hz) - 0.06 - HOUSE_FLOOR
	var h := (h_front + h_back) * 0.5
	var cx := -hx + HOUSE_WIDTH * 0.5
	# Back, outer end and front boards.
	_box(body, Vector3(HOUSE_WIDTH, h_back, 0.05), Vector3(cx, HOUSE_FLOOR + h_back * 0.5, -hz + 0.03), TAN, true)
	_box(body, Vector3(0.05, h, DEPTH - 0.1), Vector3(-hx + 0.03, HOUSE_FLOOR + h * 0.5, 0.0), TAN, true)
	_box(body, Vector3(HOUSE_WIDTH, h_front, 0.05), Vector3(cx, HOUSE_FLOOR + h_front * 0.5, hz - 0.03), TAN, true)
	# Floor of the house, over the mesh run below it.
	_box(body, Vector3(HOUSE_WIDTH, 0.05, DEPTH - 0.1), Vector3(cx, HOUSE_FLOOR, 0.0), SILL, true)
	# Red trim round the window, and the white window of three panes.
	var win_y := HOUSE_FLOOR + h_front * 0.5
	_box(self, Vector3(HOUSE_WIDTH - 0.1, 0.4, 0.04), Vector3(cx, win_y, hz + 0.0), RED)
	_box(self, Vector3(HOUSE_WIDTH - 0.2, 0.3, 0.05), Vector3(cx, win_y, hz + 0.01), WHITE)
	for k in 3:
		var px := cx + (k - 1) * 0.25
		var pane := _box(self, Vector3(0.21, 0.24, 0.06), Vector3(px, win_y, hz + 0.015), GLASS)
		_transparent(pane)
	# The nest box: a white box on the outer end with a sloped, hinged lid.
	var nest_x := -hx - 0.18
	_box(self, Vector3(0.36, 0.34, 0.5), Vector3(nest_x, HOUSE_FLOOR + 0.2, 0.1), WHITE)
	var lid := _box(self, Vector3(0.42, 0.04, 0.56), Vector3(nest_x - 0.04, HOUSE_FLOOR + 0.42, 0.1), WHITE)
	lid.rotation.z = 0.35

## The mesh walls: under the roosting house, and over the run to the door and
## beside it, plus the back and the east end, each in a red frame.
func _run_walls(body: StaticBody3D, hx: float, hz: float) -> void:
	var door := door_span()
	var xl := -hx + HOUSE_WIDTH
	# Under the roosting house: front, back and outer end (house boards stand above).
	_mesh_panel(body, Vector3(xl - -hx, HOUSE_FLOOR - 0.12, 0.03), Vector3((xl - hx) * 0.5, 0.12 + (HOUSE_FLOOR - 0.12) * 0.5, hz - 0.03))
	_mesh_panel(body, Vector3(HOUSE_WIDTH, HOUSE_FLOOR - 0.12, 0.03), Vector3((xl - hx) * 0.5, 0.12 + (HOUSE_FLOOR - 0.12) * 0.5, -hz + 0.03))
	_mesh_panel(body, Vector3(0.03, HOUSE_FLOOR - 0.12, DEPTH - 0.2), Vector3(-hx + 0.03, 0.12 + (HOUSE_FLOOR - 0.12) * 0.5, 0.0))
	# Run front: beside the door, and over it.
	var right_w := hx - door.y
	var h_right := roof_height(hz) - 0.06
	_mesh_panel(body, Vector3(right_w, h_right - 0.12, 0.03), Vector3((door.y + hx) * 0.5, 0.12 + (h_right - 0.12) * 0.5, hz - 0.03))
	var head := roof_height(hz) - 0.06 - DOOR_HEIGHT
	_box(body, Vector3(DOOR_WIDTH, head, FRAME), Vector3((door.x + door.y) * 0.5, DOOR_HEIGHT + head * 0.5, hz - FRAME * 0.5), RED, true)
	# Back wall of the run, over its whole width, and the east end.
	var run_w := WIDTH - HOUSE_WIDTH
	var run_mid := (xl + hx) * 0.5
	var h_back := roof_height(-hz) - 0.06
	_mesh_panel(body, Vector3(run_w, h_back - 0.12, 0.03), Vector3(run_mid, 0.12 + (h_back - 0.12) * 0.5, -hz + 0.03))
	var h_end := roof_height(0.0) - 0.18
	_mesh_panel(body, Vector3(0.03, h_end, DEPTH - 0.2), Vector3(hx - 0.03, 0.12 + h_end * 0.5, 0.0))
	# Mid-rails of red on the run's walls, as in the photos.
	for sz in [-1.0, 1.0]:
		_box(self, Vector3(run_w, 0.08, FRAME), Vector3(run_mid, 1.0, sz * (hz - FRAME * 0.5)), RED)
	_box(self, Vector3(FRAME, 0.08, DEPTH - 0.2), Vector3(hx - FRAME * 0.5, 1.0, 0.0), RED)

## A transparent wire-mesh slab (solid for walking into).
func _mesh_panel(body: StaticBody3D, size: Vector3, at: Vector3) -> void:
	var node := _box(body, size, at, MESH, true)
	_transparent(node)

## The door: a red-framed mesh leaf, hinged on its east edge and swung open
## outward (toward the farmhouse), so the doorway is clear.
func _door(_hx: float, hz: float) -> void:
	var span := door_span()
	var hinge := Node3D.new()
	hinge.name = "DoorLeaf"
	hinge.position = Vector3(span.y, 0.0, hz)
	hinge.rotation.y = deg_to_rad(100.0)
	add_child(hinge)
	var w := DOOR_WIDTH - 0.04
	_box(hinge, Vector3(w, DOOR_HEIGHT - 0.1, 0.03), Vector3(-w * 0.5, 0.05 + (DOOR_HEIGHT - 0.1) * 0.5, 0.0), MESH)
	(hinge.get_child(0) as MeshInstance3D).material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_box(hinge, Vector3(0.08, DOOR_HEIGHT - 0.1, 0.06), Vector3(-0.04, 0.05 + (DOOR_HEIGHT - 0.1) * 0.5, 0.0), RED)
	_box(hinge, Vector3(0.08, DOOR_HEIGHT - 0.1, 0.06), Vector3(-w + 0.04, 0.05 + (DOOR_HEIGHT - 0.1) * 0.5, 0.0), RED)
	_box(hinge, Vector3(w, 0.08, 0.06), Vector3(-w * 0.5, DOOR_HEIGHT - 0.1, 0.0), RED)
	_box(hinge, Vector3(w, 0.08, 0.06), Vector3(-w * 0.5, 0.1, 0.0), RED)
	_box(hinge, Vector3(w, 0.08, 0.06), Vector3(-w * 0.5, 0.95, 0.0), RED)

## The shed roof of galvanized corrugated steel: a slab sloping down to the back
## (away from the door), with an overhang, and red brackets under it at the front.
func _roof(body: StaticBody3D) -> void:
	var rise := EAVE_HIGH - EAVE_LOW
	# A negative x rotation raises +Z (the front) and lowers the back.
	var slope := -atan2(rise, DEPTH)
	var length := sqrt(DEPTH * DEPTH + rise * rise) + 0.5
	var mid_y := (EAVE_HIGH + EAVE_LOW) * 0.5
	var roof := _box(body, Vector3(WIDTH + 0.5, 0.06, length), Vector3(0.0, mid_y + 0.03, 0.0), TIN, true)
	roof.rotation.x = slope
	(body.get_child(body.get_child_count() - 1) as CollisionShape3D).rotation.x = slope
	_galvanize(roof)
	# Corrugation ribs, running down the slope.
	var ribs := 16
	for k in ribs:
		var x := -WIDTH * 0.5 - 0.2 + (WIDTH + 0.4) * (k + 0.5) / ribs
		var rib := _box(self, Vector3(0.05, 0.025, length), Vector3(x, mid_y + 0.075, 0.0), TIN.lightened(0.1))
		rib.rotation.x = slope
		_galvanize(rib)
	# Red brackets under the overhang at the front.
	for x in [-WIDTH * 0.5 + 0.1, 0.0, WIDTH * 0.5 - 0.1]:
		var h := roof_height(DEPTH * 0.5)
		var bracket := _box(self, Vector3(0.07, 0.4, 0.07), Vector3(x, h - 0.05, DEPTH * 0.5 + 0.18), RED)
		bracket.rotation.x = 0.7

## Silvery, a little shiny, like new galvanized sheet.
func _galvanize(node: MeshInstance3D) -> void:
	var mat := node.material_override as StandardMaterial3D
	mat.metallic = 0.5
	mat.roughness = 0.4

func _transparent(node: MeshInstance3D) -> void:
	(node.material_override as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

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
