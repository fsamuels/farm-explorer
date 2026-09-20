@tool
extends Path3D

const POST_HEIGHT := 1.1
const POST_RADIUS := 0.05
const WIRE_HEIGHTS := [0.35, 0.65, 0.95]
const WIRE_RADIUS := 0.012
const POST_COLOR := Color(0.32, 0.24, 0.16)
const WIRE_COLOR := Color(0.55, 0.55, 0.52)

@export var closed := true:
	set(value):
		closed = value
		_rebuild()

func _ready() -> void:
	if curve and not curve.changed.is_connected(_rebuild):
		curve.changed.connect(_rebuild)
	_rebuild()

func _rebuild() -> void:
	if not is_inside_tree() or curve == null:
		return

	for child in get_children():
		child.queue_free()

	var point_count := curve.point_count
	if point_count < 2:
		return

	var post_material := StandardMaterial3D.new()
	post_material.albedo_color = POST_COLOR
	var wire_material := StandardMaterial3D.new()
	wire_material.albedo_color = WIRE_COLOR

	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = POST_RADIUS
	post_mesh.bottom_radius = POST_RADIUS
	post_mesh.height = POST_HEIGHT

	var positions: Array[Vector3] = []
	for i in range(point_count):
		var p := curve.get_point_position(i)
		positions.append(Vector3(p.x, 0.0, p.z))

	for pos in positions:
		var post := MeshInstance3D.new()
		post.mesh = post_mesh
		post.material_override = post_material
		post.position = Vector3(pos.x, POST_HEIGHT / 2.0, pos.z)
		add_child(post)

	var segment_count := point_count if closed else point_count - 1
	for i in range(segment_count):
		var a := positions[i]
		var b := positions[(i + 1) % point_count]
		var mid := (a + b) / 2.0
		var chord := b - a
		var seg_length := chord.length()
		if seg_length < 0.001:
			continue
		var direction := chord.normalized()

		var wire_mesh := CylinderMesh.new()
		wire_mesh.top_radius = WIRE_RADIUS
		wire_mesh.bottom_radius = WIRE_RADIUS
		wire_mesh.height = seg_length

		var up := Vector3.UP
		var axis := up.cross(direction)
		var rot_basis: Basis
		if axis.length() < 0.0001:
			rot_basis = Basis.IDENTITY
		else:
			rot_basis = Basis(axis.normalized(), up.angle_to(direction))

		for wire_height in WIRE_HEIGHTS:
			var wire := MeshInstance3D.new()
			wire.mesh = wire_mesh
			wire.material_override = wire_material
			wire.transform = Transform3D(rot_basis, Vector3(mid.x, wire_height, mid.z))
			add_child(wire)
