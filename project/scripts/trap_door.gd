extends Node3D
## A wooden trap door lying flat in a floor (D-145), opened with E like the
## doors (shop_door.gd) and gates.
##
## The node's origin is the middle of the opening at floor-top height. The
## opening is `width` across local X and `length` along local Z; the leaf is
## hinged along its long -X edge and swings up about Z by `open_angle_deg`, so
## an open leaf stands beside the opening like a low wall. A closed leaf is solid
## to stand on. Opening it takes its collider away at once (whoever stood on it
## drops onto the stairs below, rather than being flung by a moving body), and
## closing gives the collider back only once the leaf is down. A flat pick body
## on the interact-only layer stays over the opening so E can still close it,
## from above or from the stairs.

const PICK_LAYER := 1 << 7

@export var width := 1.2
@export var length := 3.0
@export var thickness := 0.06
@export var open_angle_deg := 100.0
@export var swing_time := 1.0
@export var label := "trap door"
@export var wood_color := Color(0.52, 0.36, 0.21)

var is_open := false
var _hinge: AnimatableBody3D
var _shape: CollisionShape3D
var _tween: Tween

func _ready() -> void:
	_build()

func get_interact_prompt() -> String:
	return ("Close " if is_open else "Open ") + label

func interact(_actor: Node3D) -> void:
	set_open(not is_open)

func set_open(open: bool) -> void:
	if open == is_open:
		return
	is_open = open
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT) \
			.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.tween_property(_hinge, "rotation:z", deg_to_rad(open_angle_deg) if open else 0.0, swing_time)
	if open:
		_shape.set_deferred("disabled", true)
	else:
		_tween.tween_callback(func(): _shape.set_deferred("disabled", false))

func _build() -> void:
	for child in get_children():
		child.queue_free()
	_hinge = AnimatableBody3D.new()
	_hinge.name = "Leaf"
	_hinge.sync_to_physics = true
	_hinge.position = Vector3(-width / 2.0, 0.0, 0.0)
	add_child(_hinge)

	# Planks run the long way, with thin dark gaps between them, and two
	# battens across the underside.
	var planks := 5
	var gap := 0.008
	var plank_w := (width - gap * (planks - 1)) / planks
	for i in planks:
		var tint := 1.0 + (float((i * 7) % 5) - 2.0) * 0.04
		var m := _material(Color(wood_color.r * tint, wood_color.g * tint, wood_color.b * tint), 0.8, 0.0)
		_box(_hinge, Vector3(plank_w / 2.0 + i * (plank_w + gap), -thickness / 2.0, 0.0),
				Vector3(plank_w, thickness, length - 0.01), m)
	var dark := _material(wood_color.darkened(0.35), 0.85, 0.0)
	_box(_hinge, Vector3(width / 2.0, -thickness / 2.0 - 0.002, 0.0), Vector3(width - 0.01, thickness - 0.01, length - 0.02), dark)
	for z in [-length * 0.3, length * 0.3]:
		_box(_hinge, Vector3(width / 2.0, -thickness - 0.03, z), Vector3(width - 0.1, 0.06, 0.12), dark)
	# Black iron strap hinges on top at the hinge edge, and a ring pull near the free edge.
	var iron := _material(Color(0.12, 0.12, 0.13), 0.5, 0.8)
	for z in [-length * 0.35, length * 0.35]:
		_box(_hinge, Vector3(0.22, 0.004, z), Vector3(0.44, 0.008, 0.07), iron)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.045
	torus.outer_radius = 0.06
	ring.mesh = torus
	ring.material_override = iron
	ring.position = Vector3(width - 0.14, 0.006, 0.0)
	ring.scale = Vector3(1.0, 0.4, 1.0)
	_hinge.add_child(ring)

	var box := BoxShape3D.new()
	box.size = Vector3(width, thickness, length)
	_shape = CollisionShape3D.new()
	_shape.shape = box
	_shape.position = Vector3(width / 2.0, -thickness / 2.0, 0.0)
	_hinge.add_child(_shape)

	var pick := StaticBody3D.new()
	pick.name = "Pick"
	pick.collision_layer = PICK_LAYER
	pick.collision_mask = 0
	var pick_shape := CollisionShape3D.new()
	var pick_box := BoxShape3D.new()
	pick_box.size = Vector3(width, 0.05, length)
	pick_shape.shape = pick_box
	pick_shape.position = Vector3(0.0, -0.025, 0.0)
	pick.add_child(pick_shape)
	add_child(pick)

func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m

func _box(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
