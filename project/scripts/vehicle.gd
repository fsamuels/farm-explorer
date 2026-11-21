extends CharacterBody3D
## A car the player can get into and drive (D-106). Put the car's model under a
## Model child and a box CollisionShape3D on this node; the car faces local -Z.
##
## E on the car (gate.gd-style `interact`) seats the player; E again gets them
## out. While seated, the player node (player.gd) rides at the seat each
## physics frame and this script reads W/S (throttle / brake / reverse), A/D
## (steer) and Space (handbrake). Handling is arcade: a bicycle-model turn rate
## with a cap on sideways acceleration (vehicle_math.gd), and the body slides
## along whatever it hits, losing speed as it goes.

const VehicleMath := preload("res://scripts/vehicle_math.gd")

## How fast the wheel turns toward the key (full lock per 1/STEER_RATE seconds).
const STEER_RATE := 4.0

@export var label := "car"
@export var wheelbase := 2.6
@export var max_speed := 22.0
@export var max_reverse := 6.0
@export var accel := 6.0
@export var brake_decel := 14.0
@export var hand_decel := 10.0
@export var drag := 2.0
@export var max_steer_deg := 32.0
@export var max_lat_accel := 8.0
## The driver's eye in the car's local frame (x right, y up from the ground,
## z back). Only x and z place the player; y becomes the camera height.
@export var eye_offset := Vector3(-0.38, 1.1, 0.0)
## Half extents of the body on the ground, used to find a spot to get out.
@export var half_width := 0.95
@export var half_length := 2.3

var driver: Node3D
var speed := 0.0
var steer := 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func get_interact_prompt() -> String:
	return "Get in the " + label

func interact(actor: Node3D) -> void:
	if driver == null and actor.has_method("enter_vehicle"):
		actor.enter_vehicle(self)

func board(actor: Node3D) -> void:
	driver = actor

## True when the car is slow enough to step out of.
func can_leave() -> bool:
	return absf(speed) <= VehicleMath.MAX_EXIT_SPEED

## A global spot on the ground with room for the player to stand, trying the
## sides, ends and corners in turn, or null if the car is boxed in.
func find_exit_spot() -> Variant:
	var offsets := VehicleMath.exit_offsets(eye_offset.x, eye_offset.z, half_width, half_length, 0.7)
	var space := get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	for offset in offsets:
		var spot := to_global(offset)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.transform = Transform3D(Basis.IDENTITY, spot + Vector3(0, 0.95, 0))
		query.collision_mask = 1
		query.exclude = [get_rid()]
		if space.intersect_shape(query, 1).is_empty():
			return spot
	return null

## Frees the seat once the player has been put at a spot from find_exit_spot().
func release() -> void:
	driver = null

## The player's transform while seated, `look_yaw` being how far they've turned
## their head left of straight ahead.
func seat_transform(look_yaw: float) -> Transform3D:
	var seat := Vector3(eye_offset.x, 0.0, eye_offset.z)
	return global_transform * Transform3D(Basis(Vector3.UP, look_yaw), seat)

func speed_kmh() -> float:
	return VehicleMath.to_kmh(speed)

func _physics_process(delta: float) -> void:
	var throttle := 0.0
	var steer_input := 0.0
	var handbrake := driver == null
	if handbrake and speed == 0.0 and steer == 0.0 and is_on_floor():
		return  # parked and settled: nothing to simulate
	if driver != null:
		throttle = Input.get_axis("move_back", "move_forward")
		steer_input = Input.get_axis("move_right", "move_left")
		handbrake = Input.is_action_pressed("jump")
	steer = move_toward(steer, steer_input, STEER_RATE * delta)
	speed = VehicleMath.next_speed(speed, throttle, handbrake, delta, accel, brake_decel,
			hand_decel, drag, max_speed, max_reverse)
	rotate_y(VehicleMath.yaw_rate(speed, steer, wheelbase, deg_to_rad(max_steer_deg), max_lat_accel) * delta)

	var forward := -global_basis.z
	velocity.x = forward.x * speed
	velocity.z = forward.z * speed
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= gravity * delta
	move_and_slide()
	# Whatever the slide took off the car's motion (hitting a wall) is lost.
	speed = Vector3(velocity.x, 0.0, velocity.z).dot(-global_basis.z)
