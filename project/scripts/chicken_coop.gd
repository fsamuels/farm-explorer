extends Node3D
## The chicken coop (D-164): a walk-in red-stained run with a tan, windowed
## roosting house at one end, built from primitives after the photos in
## Downloads/Chicken coop.
##
## It is 8 ft wide (local X) by 6 ft deep (local Z). Local +Z is the front, the
## face with the door. At the -X end sits the roosting house: tan boards with a
## three-pane white window on the front, a mesh run underneath, and a white
## nest box with a hinged lid on its outer end. The rest of the front is the
## door (open, its leaf swung back) and a mesh panel. Everything is wire mesh
## in a red frame, with a shed roof of dark corrugated tin that overhangs on red
## brackets and is high over the roosting house. The floor is bare dirt with a
## plank sill.
##
## The node's origin is the centre of the floor. The Buildings entry of the same
## name keeps the map footprint and is made invisible and non-solid in
## main.tscn, as the duck house's is; this node carries the real collision.

const TerrainMath := preload("res://scripts/terrain_math.gd")

const FT := 0.3048
const WIDTH := 8.0 * FT
const DEPTH := 6.0 * FT
const FRAME := 0.07
## The roof is high over the roosting house (-X) and lower over the run (+X).
const EAVE_HIGH := 2.3
const EAVE_LOW := 2.15
## The roosting house: its width, and the bottom of its tan boards.
const HOUSE_WIDTH := 0.95
const HOUSE_FLOOR := 0.95
## The doorway in the front wall, from the house's edge.
const DOOR_WIDTH := 0.85
const DOOR_HEIGHT := 1.75
const DOOR_GAP := 0.08
## Where the coop stands in the world (x, z) and the farmhouse it faces.
const AT := Vector2(48.7, -14.6)
const FACES := Vector2(61.77, -31.3)

const RED := Color(0.55, 0.13, 0.08)
const TAN := Color(0.78, 0.68, 0.5)
const WHITE := Color(0.92, 0.92, 0.9)
const TIN := Color(0.3, 0.17, 0.12)
const SILL := Color(0.45, 0.28, 0.14)
const DIRT := Color(0.38, 0.3, 0.22)
const MESH := Color(0.7, 0.72, 0.74, 0.3)
const GLASS := Color(0.3, 0.34, 0.36, 0.75)

## Yaw (radians) that turns local +Z to face the point `target` from `from`.
static func facing_yaw(from: Vector2, target: Vector2) -> float:
	var d := target - from
	return atan2(d.x, d.y)

## The roof's underside height at local x.
static func roof_height(x: float) -> float:
	var t := (x + WIDTH * 0.5) / WIDTH
	return lerpf(EAVE_HIGH, EAVE_LOW, t)

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

func _ready() -> void:
	add_to_group("chicken_coop")
	# Stand at AT facing the farmhouse, on the ground.
	rotation.y = facing_yaw(AT, FACES)
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

	# Corner posts, tall over the roosting house, lower over the run.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var h := roof_height(sx * hx) - 0.05
			_box(body, Vector3(FRAME, h, FRAME), Vector3(sx * (hx - FRAME * 0.5), h * 0.5, sz * (hz - FRAME * 0.5)), RED, true)

	_roosting_house(body, hx, hz)
	_run_walls(body, hx, hz)
	_door(hx, hz)
	_roof(body)

## The tan roosting house at the -X end: boards above HOUSE_FLOOR on all three
## outside faces, a window in the front, a nest box on the outer end.
func _roosting_house(body: StaticBody3D, hx: float, hz: float) -> void:
	var top := roof_height(-hx + HOUSE_WIDTH * 0.5) - 0.06
	var h := top - HOUSE_FLOOR
	var mid_y := HOUSE_FLOOR + h * 0.5
	var cx := -hx + HOUSE_WIDTH * 0.5
	# Back, outer end and front boards.
	_box(body, Vector3(HOUSE_WIDTH, h, 0.05), Vector3(cx, mid_y, -hz + 0.03), TAN, true)
	_box(body, Vector3(0.05, h, DEPTH - 0.1), Vector3(-hx + 0.03, mid_y, 0.0), TAN, true)
	_box(body, Vector3(HOUSE_WIDTH, h, 0.05), Vector3(cx, mid_y, hz - 0.03), TAN, true)
	# Floor of the house, over the mesh run below it.
	_box(body, Vector3(HOUSE_WIDTH, 0.05, DEPTH - 0.1), Vector3(cx, HOUSE_FLOOR, 0.0), SILL, true)
	# Red trim round the window, and the white window of three panes.
	var win_y := HOUSE_FLOOR + h * 0.5
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
	var h_right := roof_height((door.y + hx) * 0.5) - 0.06
	_mesh_panel(body, Vector3(right_w, h_right - 0.12, 0.03), Vector3((door.y + hx) * 0.5, 0.12 + (h_right - 0.12) * 0.5, hz - 0.03))
	var head := roof_height((door.x + door.y) * 0.5) - 0.06 - DOOR_HEIGHT
	_box(body, Vector3(DOOR_WIDTH, head, FRAME), Vector3((door.x + door.y) * 0.5, DOOR_HEIGHT + head * 0.5, hz - FRAME * 0.5), RED, true)
	# Back wall of the run, over its whole width, and the east end.
	var run_w := WIDTH - HOUSE_WIDTH
	var run_mid := (xl + hx) * 0.5
	var h_back := roof_height(run_mid) - 0.06
	_mesh_panel(body, Vector3(run_w, h_back - 0.12, 0.03), Vector3(run_mid, 0.12 + (h_back - 0.12) * 0.5, -hz + 0.03))
	_mesh_panel(body, Vector3(0.03, roof_height(hx) - 0.18, DEPTH - 0.2), Vector3(hx - 0.03, 0.12 + (roof_height(hx) - 0.18) * 0.5, 0.0))
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

## The shed roof of dark corrugated tin: a slab sloping from the roosting house
## down over the run, with an overhang, and red brackets under it at the front.
func _roof(body: StaticBody3D) -> void:
	var rise := EAVE_LOW - EAVE_HIGH
	# rise is negative (high at -X, low at +X); a negative z rotation lowers +X.
	var slope := atan2(rise, WIDTH)
	var length := sqrt(WIDTH * WIDTH + rise * rise) + 0.5
	var roof := _box(body, Vector3(length, 0.06, DEPTH + 0.5), Vector3(0.0, (EAVE_HIGH + EAVE_LOW) * 0.5 + 0.03, 0.0), TIN, true)
	roof.rotation.z = slope
	(body.get_child(body.get_child_count() - 1) as CollisionShape3D).rotation.z = slope
	# Corrugation ribs, running down the slope.
	var ribs := 14
	for k in ribs:
		var z := -DEPTH * 0.5 - 0.2 + (DEPTH + 0.4) * (k + 0.5) / ribs
		var rib := _box(self, Vector3(length, 0.025, 0.05), Vector3(0.0, (EAVE_HIGH + EAVE_LOW) * 0.5 + 0.075, z), TIN.lightened(0.12))
		rib.rotation.z = slope
	# Red brackets under the overhang at the front.
	for x in [-WIDTH * 0.5 + 0.1, 0.0, WIDTH * 0.5 - 0.1]:
		var h := roof_height(x)
		var bracket := _box(self, Vector3(0.07, 0.4, 0.07), Vector3(x, h - 0.05, DEPTH * 0.5 + 0.18), RED)
		bracket.rotation.x = 0.7

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
