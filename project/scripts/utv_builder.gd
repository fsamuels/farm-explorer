extends RefCounted
## Builds the Cub Cadet 550 UTV's body out of primitives (D-127), so the repo
## needs no downloaded model or Blender step. build() fills a `Model` node with:
##   * yellow bodywork (hood, fenders, dash, floor), a black bench seat, steering
##     wheel, roll cage, bumper and headlamp housings;
##   * one mesh "Wheel_Tyres" holding all four tyres and one "Wheel_Rims" holding
##     all four rims, which vehicle.gd splits into spinning, steering wheels
##     (wheel_builder.gd), the way it does for the downloaded cars;
##   * a "Bed" node: a black-floored, yellow-sided dump box hinged at its rear
##     edge, which vehicle.gd tips by rotating it about X.
## The vehicle faces local -Z, x right, y up from the ground.

const YELLOW := Color(0.98, 0.78, 0.04)
const BLACK := Color(0.07, 0.07, 0.08)
const TYRE := Color(0.05, 0.05, 0.05)
const RIM := Color(0.62, 0.64, 0.68)

const WHEEL_RADIUS := 0.33
const WHEEL_WIDTH := 0.24
const TRACK_HALF := 0.74
const FRONT_AXLE_Z := -0.95
const REAR_AXLE_Z := 0.95
## Where the bed hinges (its rear edge), and how long it is toward the front.
const BED_HINGE := Vector3(0.0, 0.62, 1.55)
const BED_LENGTH := 1.15
const BED_WIDTH := 1.2

static func material(color: Color, rough := 0.6, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m

## Adds the body to `model` (a Node3D) and returns the Bed node.
static func build(model: Node3D) -> Node3D:
	var yellow := material(YELLOW, 0.35, 0.1)
	var black := material(BLACK, 0.8)
	# Chassis floor and the lower tub.
	_box(model, "Floor", Vector3(0, 0.42, -0.35), Vector3(1.2, 0.1, 2.0), black)
	_box(model, "Rocker_L", Vector3(-0.62, 0.45, -0.35), Vector3(0.1, 0.2, 1.8), yellow)
	_box(model, "Rocker_R", Vector3(0.62, 0.45, -0.35), Vector3(0.1, 0.2, 1.8), yellow)
	# Hood and nose, a low front bumper, and the headlamp housings.
	_box(model, "Hood", Vector3(0, 0.66, -1.0), Vector3(1.1, 0.34, 0.9), yellow)
	_box(model, "Nose", Vector3(0, 0.55, -1.52), Vector3(1.0, 0.3, 0.15), yellow)
	_box(model, "Bumper", Vector3(0, 0.4, -1.62), Vector3(1.3, 0.14, 0.12), black)
	_box(model, "Lamp_L", Vector3(-0.42, 0.62, -1.56), Vector3(0.22, 0.14, 0.1), black)
	_box(model, "Lamp_R", Vector3(0.42, 0.62, -1.56), Vector3(0.22, 0.14, 0.1), black)
	# Fender flares over the front wheels and the rear ones beside the bed.
	for sx in [-1.0, 1.0]:
		_box(model, "FenderF", Vector3(sx * 0.7, 0.72, FRONT_AXLE_Z), Vector3(0.34, 0.07, 0.8), yellow)
		_box(model, "FenderR", Vector3(sx * 0.72, 0.74, REAR_AXLE_Z - 0.1), Vector3(0.3, 0.07, 0.8), yellow)
	# Dash, the bench and its back, and the steering wheel.
	_box(model, "Dash", Vector3(0, 0.82, -0.52), Vector3(1.1, 0.34, 0.18), yellow)
	_box(model, "Seat", Vector3(0, 0.56, 0.0), Vector3(1.1, 0.16, 0.56), black)
	_box(model, "SeatBack", Vector3(0, 0.92, 0.3), Vector3(1.1, 0.56, 0.12), black)
	var wheel := MeshInstance3D.new()
	wheel.name = "SteeringWheel"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.1
	ring.outer_radius = 0.14
	wheel.mesh = ring
	wheel.material_override = black
	wheel.position = Vector3(-0.34, 1.02, -0.38)
	wheel.rotation_degrees = Vector3(-60.0, 0.0, 0.0)
	model.add_child(wheel)
	# Roll cage: four posts, two roof rails, two cross bars.
	for sx in [-1.0, 1.0]:
		_tube(model, "CageFront", Vector3(sx * 0.62, 1.1, -0.55), Vector3(sx * 0.62, 1.68, -0.4), 0.025, black)
		_tube(model, "CageRear", Vector3(sx * 0.62, 0.9, 0.42), Vector3(sx * 0.62, 1.68, 0.42), 0.025, black)
		_tube(model, "CageRail", Vector3(sx * 0.62, 1.68, -0.4), Vector3(sx * 0.62, 1.68, 0.42), 0.025, black)
	_tube(model, "CageTop_F", Vector3(-0.62, 1.68, -0.4), Vector3(0.62, 1.68, -0.4), 0.025, black)
	_tube(model, "CageTop_R", Vector3(-0.62, 1.68, 0.42), Vector3(0.62, 1.68, 0.42), 0.025, black)
	_wheels(model)
	return _bed(model, yellow, black)

static func _wheels(model: Node3D) -> void:
	var tyres := SurfaceTool.new()
	var rims := SurfaceTool.new()
	var tyre_mesh := CylinderMesh.new()
	tyre_mesh.top_radius = WHEEL_RADIUS
	tyre_mesh.bottom_radius = WHEEL_RADIUS
	tyre_mesh.height = WHEEL_WIDTH
	tyre_mesh.radial_segments = 20
	tyre_mesh.rings = 1
	var rim_mesh := CylinderMesh.new()
	rim_mesh.top_radius = WHEEL_RADIUS * 0.62
	rim_mesh.bottom_radius = WHEEL_RADIUS * 0.62
	rim_mesh.height = WHEEL_WIDTH + 0.02
	rim_mesh.radial_segments = 12
	rim_mesh.rings = 1
	# A cylinder's axis is Y; the wheel's axle runs along X.
	var axle := Basis(Vector3.BACK, deg_to_rad(90.0))
	for sx in [-1.0, 1.0]:
		for z in [FRONT_AXLE_Z, REAR_AXLE_Z]:
			var xf := Transform3D(axle, Vector3(sx * TRACK_HALF, WHEEL_RADIUS, z))
			tyres.append_from(tyre_mesh, 0, xf)
			rims.append_from(rim_mesh, 0, xf)
	var tyre_node := MeshInstance3D.new()
	tyre_node.name = "Wheel_Tyres"
	tyre_node.mesh = tyres.commit()
	tyre_node.material_override = material(TYRE, 0.95)
	model.add_child(tyre_node)
	var rim_node := MeshInstance3D.new()
	rim_node.name = "Wheel_Rims"
	rim_node.mesh = rims.commit()
	rim_node.material_override = material(RIM, 0.4, 0.6)
	model.add_child(rim_node)

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

## A thin cylinder from `a` to `b`.
static func _tube(parent: Node3D, node_name: String, a: Vector3, b: Vector3, radius: float, mat: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 8
	mesh.rings = 1
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = (a + b) / 2.0
	var up := (b - a).normalized()
	var axis := Vector3.UP.cross(up)
	if axis.length() > 0.0001:
		mi.basis = Basis(axis.normalized(), Vector3.UP.angle_to(up))
	parent.add_child(mi)
