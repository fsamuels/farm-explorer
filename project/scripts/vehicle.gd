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
const WheelBuilder := preload("res://scripts/wheel_builder.gd")
const EngineSound := preload("res://scripts/engine_sound.gd")

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
## Names (or name prefixes) of the Model's meshes that are wheel geometry:
## tyres, rims, hubs. They're split into four wheels that spin and steer.
@export var wheel_meshes := PackedStringArray()
## Engine note: cylinder count, idle / redline revs, and the road speed (m/s)
## at which each gear tops out (the pitch climbs and drops at each shift).
@export var cylinders := 4
@export var idle_rpm := 900.0
@export var redline_rpm := 6000.0
@export var gear_tops := PackedFloat32Array([6.0, 11.0, 17.0, 24.0])
@export var engine_volume_db := -4.0

var driver: Node3D
var speed := 0.0
var steer := 0.0
var engine_rpm := 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

## One entry per wheel: {steer: Node3D, spin: Node3D, radius: float, front: bool}.
var wheels: Array[Dictionary] = []
var _throttle := 0.0
var _synth: RefCounted
var _audio: AudioStreamPlayer3D
var _playback: AudioStreamGeneratorPlayback
## Total audio frames handed to the generator (the sound tests read this).
var frames_pushed := 0

func _ready() -> void:
	_build_wheels()
	_build_engine_sound()

func _build_wheels() -> void:
	var sources: Array = []
	var stack: Array = [self]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node is MeshInstance3D and _is_wheel_mesh(String(node.name)):
			sources.append(node)
	if sources.is_empty():
		return
	for entry in WheelBuilder.build(sources, self):
		var steer := Node3D.new()
		steer.name = "Wheel%d" % entry.quadrant
		steer.position = entry.center
		var spin := Node3D.new()
		spin.name = "Spin"
		steer.add_child(spin)
		for mesh: Mesh in entry.meshes:
			var instance := MeshInstance3D.new()
			instance.mesh = mesh
			spin.add_child(instance)
		add_child(steer)
		wheels.append({"steer": steer, "spin": spin, "radius": entry.radius, "front": entry.front})
	for source: Node in sources:
		source.queue_free()

func _is_wheel_mesh(node_name: String) -> bool:
	for prefix in wheel_meshes:
		if node_name.begins_with(prefix):
			return true
	return false

func _build_engine_sound() -> void:
	_synth = EngineSound.new(cylinders)
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = EngineSound.MIX_RATE
	stream.buffer_length = 0.2
	_audio = AudioStreamPlayer3D.new()
	_audio.name = "EngineSound"
	_audio.stream = stream
	_audio.position = Vector3(0.0, 0.6, -1.4)
	_audio.unit_size = 6.0
	_audio.max_distance = 80.0
	_audio.volume_db = engine_volume_db
	add_child(_audio)

## The engine runs while somebody is driving. Revs follow road speed through
## the gears (with a lag, and a blip on the throttle) and the generator is
## topped up with audio each frame.
func _process(delta: float) -> void:
	if driver == null:
		if _audio.playing:
			_audio.stop()
			_playback = null
		engine_rpm = 0.0
		return
	var target := EngineSound.rpm_for_speed(speed, gear_tops, idle_rpm, redline_rpm)
	target += maxf(_throttle, 0.0) * 0.08 * (redline_rpm - idle_rpm)
	if not _audio.playing:
		engine_rpm = idle_rpm
		_audio.play()
		_playback = _audio.get_stream_playback() as AudioStreamGeneratorPlayback
	engine_rpm = move_toward(engine_rpm, minf(target, redline_rpm), 8.0 * redline_rpm * delta)
	if _playback:
		var frames := _playback.get_frames_available()
		if frames > 0:
			_playback.push_buffer(_synth.render(frames, engine_rpm, clampf(_throttle, 0.0, 1.0)))
			frames_pushed += frames

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

func speed_mph() -> float:
	return VehicleMath.to_mph(speed)

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
	_throttle = throttle
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
	_turn_wheels(delta)

## Roll every wheel by the distance travelled and turn the front pair with the
## steering. Forward is -Z, so a wheel rolling forward turns negatively about X.
func _turn_wheels(delta: float) -> void:
	var lock := deg_to_rad(max_steer_deg)
	for wheel in wheels:
		var spin: Node3D = wheel.spin
		spin.rotation.x = wrapf(spin.rotation.x - speed / wheel.radius * delta, -PI, PI)
		if wheel.front:
			(wheel.steer as Node3D).rotation.y = steer * lock
