@tool
extends StaticBody3D

const TREE_SPACING := 9.0
const SPACING_JITTER := 1.5
const DEPTH_JITTER := 2.0
const SCALE_MIN := 0.8
const SCALE_MAX := 1.3
const WALL_HEIGHT := 3.0
const WALL_THICKNESS := 1.0

@export var length := 20.0:
	set(value):
		length = value
		_rebuild()

var _tree_scene := preload("res://scenes/tree.tscn")

func _ready() -> void:
	_rebuild()

func _rebuild() -> void:
	if not is_inside_tree() or length <= 0.0:
		return

	for child in get_children():
		child.queue_free()

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)

	var tree_count := maxi(1, int(round(length / TREE_SPACING)))
	var spacing := length / float(tree_count)

	for i in range(tree_count):
		var tree := _tree_scene.instantiate()
		var x := -length / 2.0 + (i + 0.5) * spacing + rng.randf_range(-SPACING_JITTER, SPACING_JITTER)
		var z := rng.randf_range(-DEPTH_JITTER, DEPTH_JITTER)
		var s := rng.randf_range(SCALE_MIN, SCALE_MAX)
		tree.position = Vector3(x, 0.0, z)
		tree.rotation.y = rng.randf_range(0.0, TAU)
		tree.scale = Vector3.ONE * s
		add_child(tree)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(length, WALL_HEIGHT, WALL_THICKNESS)
	collision.shape = shape
	collision.position = Vector3(0.0, WALL_HEIGHT / 2.0, 0.0)
	add_child(collision)
