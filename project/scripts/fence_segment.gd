@tool
extends StaticBody3D

const POST_SPACING := 3.0
const POST_HEIGHT := 1.1
const POST_RADIUS := 0.05
const WIRE_HEIGHTS := [0.35, 0.65, 0.95]
const WIRE_RADIUS := 0.012
const POST_COLOR := Color(0.32, 0.24, 0.16)
const WIRE_COLOR := Color(0.55, 0.55, 0.52)

@export var length := 5.0:
	set(value):
		length = value
		_rebuild()

func _ready() -> void:
	_rebuild()

func _rebuild() -> void:
	if not is_inside_tree() or length <= 0.0:
		return

	for child in get_children():
		child.queue_free()

	var post_material := StandardMaterial3D.new()
	post_material.albedo_color = POST_COLOR
	var wire_material := StandardMaterial3D.new()
	wire_material.albedo_color = WIRE_COLOR

	var post_count := maxi(2, int(ceil(length / POST_SPACING)) + 1)
	var spacing := length / float(post_count - 1)

	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = POST_RADIUS
	post_mesh.bottom_radius = POST_RADIUS
	post_mesh.height = POST_HEIGHT

	for i in range(post_count):
		var post := MeshInstance3D.new()
		post.mesh = post_mesh
		post.material_override = post_material
		post.position = Vector3(-length / 2.0 + i * spacing, POST_HEIGHT / 2.0, 0.0)
		add_child(post)

	var wire_mesh := CylinderMesh.new()
	wire_mesh.top_radius = WIRE_RADIUS
	wire_mesh.bottom_radius = WIRE_RADIUS
	wire_mesh.height = length

	for wire_height in WIRE_HEIGHTS:
		var wire := MeshInstance3D.new()
		wire.mesh = wire_mesh
		wire.material_override = wire_material
		wire.rotation_degrees = Vector3(0.0, 0.0, 90.0)
		wire.position = Vector3(0.0, wire_height, 0.0)
		add_child(wire)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(length, POST_HEIGHT, 0.2)
	collision.shape = shape
	collision.position = Vector3(0.0, POST_HEIGHT / 2.0, 0.0)
	add_child(collision)
