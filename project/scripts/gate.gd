@tool
extends Node3D

## A swinging pipe-panel gate. The node's origin is the hinge post and the panel
## runs along local +X for `width` metres to the latch end. The player opens and
## closes it through `interact()` (see player.gd); it always swings away from
## whoever opens it.

const POST_HEIGHT := 1.1
const POST_RADIUS := 0.05
const POST_COLOR := Color(0.32, 0.24, 0.16)
const PIPE_RADIUS := 0.025
const PIPE_COLOR := Color(0.78, 0.8, 0.8)
const RAIL_HEIGHTS := [0.2, 0.48, 0.76, 1.04]
const LATCH_CLEARANCE := 0.06

@export var width := 3.66:
	set(value):
		width = value
		_rebuild()

@export_range(10.0, 180.0) var open_angle_deg := 90.0
@export var swing_time := 0.6

var is_open := false
var _hinge: AnimatableBody3D
var _tween: Tween

func _ready() -> void:
	_rebuild()

func get_interact_prompt() -> String:
	return "Close gate" if is_open else "Open gate"

func interact(actor: Node3D) -> void:
	var target := 0.0
	if not is_open:
		# Rotating by +angle about Y swings the latch end toward local -Z, so
		# pick the sign that moves it to the side opposite the actor.
		var side := to_local(actor.global_position).z
		target = deg_to_rad(open_angle_deg) * (1.0 if side >= 0.0 else -1.0)
	is_open = not is_open
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT) \
			.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.tween_property(_hinge, "rotation:y", target, swing_time)

func _rebuild() -> void:
	if not is_inside_tree() or width <= 0.0:
		return

	for child in get_children():
		child.queue_free()

	var post_material := StandardMaterial3D.new()
	post_material.albedo_color = POST_COLOR
	var pipe_material := StandardMaterial3D.new()
	pipe_material.albedo_color = PIPE_COLOR
	pipe_material.metallic = 0.6
	pipe_material.roughness = 0.4

	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = POST_RADIUS
	post_mesh.bottom_radius = POST_RADIUS
	post_mesh.height = POST_HEIGHT
	var hinge_post := MeshInstance3D.new()
	hinge_post.mesh = post_mesh
	hinge_post.material_override = post_material
	hinge_post.position = Vector3(0.0, POST_HEIGHT / 2.0, 0.0)
	add_child(hinge_post)

	# The hinge is itself an AnimatableBody3D, rotated about the post, so the
	# panel's collision swings with it and blocks (and pushes) the player
	# mid-swing. Rotating a plain parent node would leave the collision behind.
	_hinge = AnimatableBody3D.new()
	_hinge.name = "Hinge"
	add_child(_hinge)
	is_open = false

	var start := POST_RADIUS + PIPE_RADIUS
	var length := width - LATCH_CLEARANCE - start

	var rail_mesh := CylinderMesh.new()
	rail_mesh.top_radius = PIPE_RADIUS
	rail_mesh.bottom_radius = PIPE_RADIUS
	rail_mesh.height = length
	for rail_height in RAIL_HEIGHTS:
		var rail := MeshInstance3D.new()
		rail.mesh = rail_mesh
		rail.material_override = pipe_material
		rail.rotation_degrees = Vector3(0.0, 0.0, 90.0)
		rail.position = Vector3(start + length / 2.0, rail_height, 0.0)
		_hinge.add_child(rail)

	var bottom: float = RAIL_HEIGHTS[0]
	var top: float = RAIL_HEIGHTS[-1]
	var stile_mesh := CylinderMesh.new()
	stile_mesh.top_radius = PIPE_RADIUS
	stile_mesh.bottom_radius = PIPE_RADIUS
	stile_mesh.height = top - bottom
	for x in [start, start + length]:
		var stile := MeshInstance3D.new()
		stile.mesh = stile_mesh
		stile.material_override = pipe_material
		stile.position = Vector3(x, (top + bottom) / 2.0, 0.0)
		_hinge.add_child(stile)

	var shape := BoxShape3D.new()
	shape.size = Vector3(length, POST_HEIGHT, 0.12)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(start + length / 2.0, POST_HEIGHT / 2.0, 0.0)
	_hinge.add_child(collision)
