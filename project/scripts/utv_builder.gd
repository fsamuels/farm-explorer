extends RefCounted
## Adds the dump bed to the Cub Cadet UTV (D-127, D-138). The body is the
## downloaded Ranger model (models/ranger_xp.glb, built by
## tools/build_ranger_model.py), which has its original rear tank unit cut out;
## this builds a hinged, yellow-sided dump box in its place and returns the
## "Bed" node, which vehicle.gd tips by rotating it about X.
## The vehicle faces local -Z, x right, y up from the ground.

const YELLOW := Color(0.98, 0.78, 0.04)
const BLACK := Color(0.07, 0.07, 0.08)

## Where the bed hinges (its rear edge), and how long and wide it is. It sits
## above the rear wheels (0.45 m from centre outward). The model's rear edge
## is at z 1.55, so the hinge leaves a small overhang; the cab ends near z 0.4.
const BED_HINGE := Vector3(0.0, 0.72, 1.62)
const BED_LENGTH := 1.2
const BED_WIDTH := 1.5

static func material(color: Color, rough := 0.6, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m

## Adds the bed to `model` (a Node3D) and returns the Bed node.
static func build(model: Node3D) -> Node3D:
	var yellow := material(YELLOW, 0.35, 0.1)
	var black := material(BLACK, 0.8)
	return _bed(model, yellow, black)

## The dump bed: its node sits on the hinge; the box extends forward (-Z) from it.
static func _bed(model: Node3D, yellow: Material, black: Material) -> Node3D:
	var bed := Node3D.new()
	bed.name = "Bed"
	bed.position = BED_HINGE
	model.add_child(bed)
	var half_w := BED_WIDTH / 2.0
	_box(bed, "BedFloor", Vector3(0, 0.0, -BED_LENGTH / 2.0), Vector3(BED_WIDTH, 0.06, BED_LENGTH), black)
	for sx in [-1.0, 1.0]:
		_box(bed, "BedSide", Vector3(sx * (half_w - 0.03), 0.18, -BED_LENGTH / 2.0), Vector3(0.06, 0.3, BED_LENGTH), yellow)
	_box(bed, "BedHeadboard", Vector3(0, 0.18, -BED_LENGTH + 0.03), Vector3(BED_WIDTH, 0.3, 0.06), yellow)
	_box(bed, "BedTailgate", Vector3(0, 0.18, -0.03), Vector3(BED_WIDTH, 0.3, 0.06), yellow)
	return bed

static func _box(parent: Node3D, node_name: String, pos: Vector3, size: Vector3, mat: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
