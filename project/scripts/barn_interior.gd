extends Node3D
## The Front Barn's inside (D-116), kept simple: three stalls along the east
## side (low board walls with a gate each), a tack room in the middle third of
## the west side (walls, a door, a low ceiling) and a stack of hay bales in the
## middle of the tall central part. It sits in the barn shell's frame (`shell`
## is the FrontBarnShell node; +X east, +Z south, origin at the footprint
## centre on the ground) and reads the shell's width, depth and wall
## thickness, so it follows the footprint.

const WallLayout := preload("res://scripts/wall_layout.gd")
const DoorScript := preload("res://scripts/shop_door.gd")

@export var shell_path: NodePath = ^"../FrontBarnShell"
## How far the stalls and the tack room reach in from the east and west walls.
@export var side_depth := 4.0
@export var stall_count := 3
@export var stall_wall_height := 1.8
@export var stall_gate_width := 1.3
@export var tack_height := 2.6
@export var tack_door_width := 0.9
@export var tack_door_height := 2.1
## The hay stack: bales across x and z, tiers high (a bale is 0.9 x 0.45 x 0.45).
@export var hay_bales_x := 4
@export var hay_bales_z := 6
@export var hay_tiers := 8

const WALL_T := 0.1
const BALE := Vector3(0.9, 0.45, 0.45)

var width := 1.0
var depth := 1.0
var wall_t := 0.15

var _body: StaticBody3D
var _wood: StandardMaterial3D
var _tack: StandardMaterial3D
## The gates and the tack-room door, for the tests.
var gates: Array[Node3D] = []
var tack_door: Node3D
var hay_center := Vector3.ZERO
var hay_size := Vector3.ZERO

## Z of each stall's centre, from the footprint centre: `count` equal bays
## filling `length`.
static func bay_centres(length: float, count: int) -> Array[float]:
	var out: Array[float] = []
	for i in count:
		out.append((float(i) + 0.5) * length / float(count) - length / 2.0)
	return out

func _ready() -> void:
	var shell := get_node_or_null(shell_path) as Node3D
	if shell == null:
		push_warning("barn_interior: no shell at %s" % shell_path)
		return
	width = shell.width
	depth = shell.depth
	wall_t = shell.WALL_T
	# Sit on the shell's visual floor (FLOOR_TOP), not in it.
	global_transform = shell.global_transform.translated_local(Vector3(0, shell.FLOOR_TOP, 0))
	_wood = _material(Color(0.42, 0.3, 0.19))
	_tack = _material(Color(0.62, 0.52, 0.4))
	_body = StaticBody3D.new()
	_body.name = "Fittings"
	add_child(_body)
	_build_stalls()
	_build_tack_room()
	_build_hay()

func _material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _build_stalls() -> void:
	var inner := depth - 2.0 * wall_t
	var front_x := width / 2.0 - wall_t - side_depth
	var centres := bay_centres(inner, stall_count)
	# The stall fronts: one wall along z with a gate opening per stall.
	var openings: Array = []
	for c in centres:
		openings.append({c = c, w = stall_gate_width + 0.04, y0 = 0.0, y1 = stall_wall_height})
	for r in WallLayout.pieces(inner, stall_wall_height, openings):
		_add_box(Vector3(front_x, r.position.y + r.size.y / 2.0, r.position.x + r.size.x / 2.0),
				Vector3(WALL_T, r.size.y, r.size.x), _wood, true)
	# Dividers between the stalls, from the front to the east wall.
	var east_x := width / 2.0 - wall_t
	for i in range(1, stall_count):
		var z: float = (centres[i - 1] + centres[i]) / 2.0
		_add_box(Vector3((front_x + east_x) / 2.0, stall_wall_height / 2.0, z),
				Vector3(east_x - front_x, stall_wall_height, WALL_T), _wood, true)
	# A gate in each opening, hinged at its south edge, swinging into the stall.
	for c in centres:
		var door := DoorScript.new()
		door.kind = DoorScript.Kind.SWING
		door.width = stall_gate_width + 0.04
		door.height = stall_wall_height - 0.2
		door.color = Color(0.5, 0.36, 0.22)
		door.label = "stall gate"
		door.window_pane = false
		# Faces the aisle (outward is -x): door yaw 90, its +X runs north.
		door.position = Vector3(front_x, 0.0, c + (stall_gate_width + 0.04) / 2.0)
		door.rotation_degrees.y = 90.0
		door.name = "StallGate%d" % gates.size()
		add_child(door)
		gates.append(door)

func _build_tack_room() -> void:
	var west_x := -width / 2.0 + wall_t
	var front_x := west_x + side_depth
	var third := (depth - 2.0 * wall_t) / 3.0
	var z0 := -third / 2.0
	var z1 := third / 2.0
	# North and south walls from the west wall to the aisle side.
	for z in [z0, z1]:
		_add_box(Vector3((west_x + front_x) / 2.0, tack_height / 2.0, z), Vector3(side_depth, tack_height, WALL_T), _tack, true)
	# The aisle-side wall, with the door opening in the middle.
	for r in WallLayout.pieces(third, tack_height, [{c = 0.0, w = tack_door_width + 0.04, y0 = 0.0, y1 = tack_door_height}]):
		_add_box(Vector3(front_x, r.position.y + r.size.y / 2.0, r.position.x + r.size.x / 2.0),
				Vector3(WALL_T, r.size.y, r.size.x), _tack, true)
	# A low ceiling over the room.
	_add_box(Vector3((west_x + front_x) / 2.0, tack_height + 0.02, 0.0), Vector3(side_depth + WALL_T, 0.04, third + WALL_T), _tack, false)
	# The door faces the aisle (outward is +x): yaw -90, its +X runs south.
	var door := DoorScript.new()
	door.kind = DoorScript.Kind.SWING
	door.width = tack_door_width + 0.04
	door.height = tack_door_height - 0.02
	door.label = "tack room door"
	door.window_pane = false
	door.color = Color(0.85, 0.85, 0.82)
	door.position = Vector3(front_x, 0.0, -(tack_door_width + 0.04) / 2.0)
	door.rotation_degrees.y = -90.0
	door.name = "TackDoor"
	add_child(door)
	tack_door = door

func _build_hay() -> void:
	var mesh := BoxMesh.new()
	mesh.size = BALE * 0.97
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1, 1, 1)
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	mesh.material = material
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = mesh
	multi.instance_count = hay_bales_x * hay_bales_z * hay_tiers
	hay_size = Vector3(BALE.x * hay_bales_x, BALE.y * hay_tiers, BALE.z * hay_bales_z)
	hay_center = Vector3(0.0, hay_size.y / 2.0, 0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 116
	var i := 0
	for t in hay_tiers:
		for ix in hay_bales_x:
			for iz in hay_bales_z:
				var p := Vector3(
						(float(ix) + 0.5) * BALE.x - hay_size.x / 2.0,
						(float(t) + 0.5) * BALE.y,
						(float(iz) + 0.5) * BALE.z - hay_size.z / 2.0)
				multi.set_instance_transform(i, Transform3D(Basis.IDENTITY, p))
				var shade := rng.randf_range(0.85, 1.05)
				multi.set_instance_color(i, Color(0.86 * shade, 0.7 * shade, 0.3 * shade))
				i += 1
	var instance := MultiMeshInstance3D.new()
	instance.name = "HayStack"
	instance.multimesh = multi
	add_child(instance)
	var shape := BoxShape3D.new()
	shape.size = hay_size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = hay_center
	_body.add_child(cs)

func _add_box(pos: Vector3, size: Vector3, material: Material, collide: bool) -> void:
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
