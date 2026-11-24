extends Node3D
## The Front Barn's inside (D-116, D-121). It is a pole barn: the shell leaves
## the north, south and east sides open, so this node adds a post at each
## corner (the facade, barn_facade.gd, adds the rest of the posts, the siding and
## the roofs, D-125) and fills in the rest: three stalls along the east side (walls of four spaced
## boards, a gate each), a tack room in the middle third of the west side
## (walls, the barn's only door, a low ceiling), an open cubby on each side of
## it (a wall at each end) and a staircase of hay bales in the southern third of the tall
## central part. It sits in the barn shell's frame (`shell`
## is the FrontBarnShell node; +X east, +Z south, origin at the footprint
## centre on the ground) and reads the shell's width, depth and wall
## thickness, so it follows the footprint.

const WallLayout := preload("res://scripts/wall_layout.gd")
const DoorScript := preload("res://scripts/shop_door.gd")
const Profile := preload("res://scripts/barn_profile.gd")

@export var shell_path: NodePath = ^"../FrontBarnShell"
## How far the stalls and the tack room reach in from the east and west walls.
@export var side_depth := 4.0
@export var stall_count := 3
@export var stall_wall_height := 1.8
## Boards in each stall wall, spaced up to `stall_wall_height` with gaps between.
@export var board_count := 4
@export var stall_gate_width := 1.3
@export var tack_height := 2.4  # under the wing roof's low edge (D-125)
@export var tack_door_width := 0.9
@export var tack_door_height := 2.1
@export var post_size := 0.25
## The hay pile: `hay_bales_x` bales across, and steps climbing south, each
## `hay_step_bales` bales deep with the listed number of tiers (a bale is 0.9 x
## 0.45 x 0.45).
@export var hay_bales_x := 4
@export var hay_step_bales := 3
@export var hay_step_tiers := PackedInt32Array([1, 2, 3, 4])

const WALL_T := 0.1
## The stall boards (D-128): a board's height, thickness and how far off the
## floor the lowest one sits, and the posts between runs.
const BOARD_H := 0.25
const BOARD_T := 0.05
const BOARD_BOTTOM := 0.2
const STALL_POST := 0.12
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
	_build_cubbies()
	_build_posts(Profile.CLEARANCE)
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
	# The stall fronts: a run of boards along z with a gate opening per stall.
	var openings: Array = []
	for c in centres:
		openings.append({c = c, w = stall_gate_width + 0.04, y0 = 0.0, y1 = stall_wall_height})
	for r in WallLayout.pieces(inner, stall_wall_height, openings):
		_add_boards(front_x, r.position.x + r.size.x / 2.0, r.size.x, true)
	# The south stall is closed at its south end (D-129): a board wall from its front to the east wall.
	var east_end := width / 2.0 - wall_t
	_add_boards((front_x + east_end) / 2.0, inner / 2.0 - STALL_POST / 2.0, east_end - front_x, false)
	# Dividers between the stalls, from the front to the east wall.
	var east_x := width / 2.0 - wall_t
	for i in range(1, stall_count):
		var z: float = (centres[i - 1] + centres[i]) / 2.0
		_add_boards((front_x + east_x) / 2.0, z, east_x - front_x, false)
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

## One stall wall run (D-128): `board_count` horizontal boards stacked up to
## `stall_wall_height` with open gaps between them, and a post at each end. It
## is centred on (`x`, `z`) and `length` long, along z when `along_z`, else x.
func _add_boards(x: float, z: float, length: float, along_z: bool) -> void:
	var pitch := (stall_wall_height - BOARD_BOTTOM - BOARD_H) / float(board_count - 1)
	for i in board_count:
		var y := BOARD_BOTTOM + BOARD_H / 2.0 + pitch * float(i)
		var size := Vector3(BOARD_T, BOARD_H, length) if along_z else Vector3(length, BOARD_H, BOARD_T)
		_add_box(Vector3(x, y, z), size, _wood, true)
	for end in [-1.0, 1.0]:
		var at := Vector3(x, stall_wall_height / 2.0, z + end * length / 2.0) if along_z \
				else Vector3(x + end * length / 2.0, stall_wall_height / 2.0, z)
		_add_box(at, Vector3(STALL_POST, stall_wall_height, STALL_POST), _wood, true)

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

## The two open cubbies beside the tack room: each has the tack room's wall on
## one end and a wall at the barn's end on the other, and is open to the aisle.
func _build_cubbies() -> void:
	var west_x := -width / 2.0 + wall_t
	var front_x := west_x + side_depth
	var end_z := depth / 2.0 - WALL_T / 2.0
	for z in [-end_z, end_z]:
		_add_box(Vector3((west_x + front_x) / 2.0, tack_height / 2.0, z), Vector3(side_depth, tack_height, WALL_T), _wood, true)

## A post at each corner of the footprint, up to the siding line (D-125); the
## facade adds the posts along the two ends.
func _build_posts(eave: float) -> void:
	var half := post_size / 2.0
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_add_box(Vector3(sx * (width / 2.0 - half), eave / 2.0, sz * (depth / 2.0 - half)), Vector3(post_size, eave, post_size), _wood, true)

## The hay pile (D-136): in the barn's southernmost third, against the south
## end, built as a staircase of `hay_step_tiers.size()` steps that climb toward
## the south, each step `hay_step_bales` bales deep and a bale higher than the
## last (so up to 4 bales). Each step is its own collision box, so a player can
## hop up it. `hay_center` / `hay_size` are the pile's whole bounding box.
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
	var steps := hay_step_tiers.size()
	var step_depth := BALE.z * float(hay_step_bales)
	var max_tiers := 0
	var total := 0
	for tiers in hay_step_tiers:
		max_tiers = maxi(max_tiers, tiers)
		total += tiers * hay_bales_x * hay_step_bales
	multi.instance_count = total
	hay_size = Vector3(BALE.x * hay_bales_x, BALE.y * max_tiers, step_depth * steps)
	# Against the south end, inside its wall.
	var south_z := depth / 2.0 - wall_t - 0.1
	hay_center = Vector3(0.0, hay_size.y / 2.0, south_z - hay_size.z / 2.0)
	var north_z := south_z - hay_size.z
	var rng := RandomNumberGenerator.new()
	rng.seed = 116
	var i := 0
	for step in steps:
		var tiers: int = hay_step_tiers[step]
		var z0 := north_z + step_depth * float(step)
		for t in tiers:
			for ix in hay_bales_x:
				for iz in hay_step_bales:
					var p := Vector3(
							(float(ix) + 0.5) * BALE.x - hay_size.x / 2.0,
							(float(t) + 0.5) * BALE.y,
							z0 + (float(iz) + 0.5) * BALE.z)
					multi.set_instance_transform(i, Transform3D(Basis.IDENTITY, p))
					var shade := rng.randf_range(0.85, 1.05)
					multi.set_instance_color(i, Color(0.86 * shade, 0.7 * shade, 0.3 * shade))
					i += 1
		var shape := BoxShape3D.new()
		shape.size = Vector3(hay_size.x, BALE.y * float(tiers), step_depth)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position = Vector3(0.0, shape.size.y / 2.0, z0 + step_depth / 2.0)
		_body.add_child(cs)
	var instance := MultiMeshInstance3D.new()
	instance.name = "HayStack"
	instance.multimesh = multi
	add_child(instance)

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
