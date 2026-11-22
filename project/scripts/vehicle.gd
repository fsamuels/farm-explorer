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
## Most engine audio frames synthesized in one _process call.
const MAX_AUDIO_FRAMES_PER_UPDATE := 1024
## Headlight fade speed, in full brightness per second.
const HEADLIGHT_FADE_RATE := 2.0
## Brake lights come on and go off almost at once.
const BRAKE_LIGHT_FADE_RATE := 12.0
## Tail lamps glow at this fraction of full brightness with just the headlights.
const TAIL_DIM := 0.2

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
## Headlamp positions in the car's local frame (x right, y up, z back; the car
## faces -Z). Each gets a spot light and a glowing lens that fade in as the
## scene gets dark (time_of_day.gd's sun_energy) while somebody is driving.
@export var headlight_positions := PackedVector3Array()
@export var headlight_range := 40.0
@export var headlight_energy := 5.0
## Also light the lamps on a parked, empty car when it's dark.
@export var headlights_when_parked := false
## Tail lamp positions (same frame as the headlamps, at the back of the car).
## They glow dim red whenever the headlights are on and bright red while the
## driver brakes, by day or night.
@export var taillight_positions := PackedVector3Array()

var driver: Node3D
var speed := 0.0
var steer := 0.0
var engine_rpm := 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

## One entry per wheel: {steer: Node3D, spin: Node3D, radius: float, front: bool}.
var wheels: Array[Dictionary] = []
var _throttle := 0.0
## How dark the scene is as a 0..1 headlight demand, and the fade actually shown.
var _headlight_demand := 0.0
var headlight_level := 0.0
var _headlight_applied := -1.0
## 0..1 glow of the rear lamps (the larger of the dim running glow and the brake
## light) and how hard the brake light is on.
var tail_level := 0.0
var brake_level := 0.0
var _braking := false
var _tail_applied := -1.0
var _tail_lamps: Array[SpotLight3D] = []
var _tail_lenses: Array[MeshInstance3D] = []
var _tail_material: StandardMaterial3D
var _lamps: Array[SpotLight3D] = []
var _lenses: Array[MeshInstance3D] = []
var _lens_material: StandardMaterial3D
var _synth: RefCounted
var _audio: AudioStreamPlayer3D
var _playback: AudioStreamGeneratorPlayback
## Total audio frames handed to the generator (the sound tests read this).
var frames_pushed := 0

func _ready() -> void:
	_build_wheels()
	_build_engine_sound()
	_build_headlights()
	_build_taillights()
	# Deferred so every node in the scene is in the tree whatever the order.
	_watch_time_of_day.call_deferred()

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

func _build_headlights() -> void:
	_lens_material = StandardMaterial3D.new()
	_lens_material.albedo_color = Color(1.0, 0.97, 0.85)
	_lens_material.emission_enabled = true
	_lens_material.emission = Color(1.0, 0.93, 0.7)
	_lens_material.emission_energy_multiplier = 0.0
	var lens_mesh := SphereMesh.new()
	lens_mesh.radius = 0.07
	lens_mesh.height = 0.14
	lens_mesh.material = _lens_material
	for pos in headlight_positions:
		var lamp := SpotLight3D.new()
		lamp.position = pos
		lamp.rotation_degrees.x = -2.0
		lamp.spot_range = headlight_range
		lamp.spot_angle = 32.0
		lamp.spot_attenuation = 0.8
		lamp.light_color = Color(1.0, 0.94, 0.8)
		lamp.light_energy = 0.0
		lamp.visible = false
		add_child(lamp)
		_lamps.append(lamp)
		var lens := MeshInstance3D.new()
		lens.mesh = lens_mesh
		lens.position = pos
		lens.visible = false
		add_child(lens)
		_lenses.append(lens)

func _build_taillights() -> void:
	_tail_material = StandardMaterial3D.new()
	_tail_material.albedo_color = Color(0.6, 0.02, 0.02)
	_tail_material.emission_enabled = true
	_tail_material.emission = Color(0.8, 0.03, 0.02)
	_tail_material.emission_energy_multiplier = 0.0
	# A flat lens like a tail lamp, rather than a ball.
	var lens_mesh := BoxMesh.new()
	lens_mesh.size = Vector3(0.12, 0.08, 0.02)
	lens_mesh.material = _tail_material
	for pos in taillight_positions:
		var lamp := SpotLight3D.new()
		lamp.position = pos
		lamp.rotation_degrees.y = 180.0  # shine backward (+Z)
		lamp.spot_range = 8.0
		lamp.spot_angle = 55.0
		lamp.light_color = Color(1.0, 0.1, 0.05)
		lamp.light_energy = 0.0
		lamp.visible = false
		add_child(lamp)
		_tail_lamps.append(lamp)
		var lens := MeshInstance3D.new()
		lens.mesh = lens_mesh
		lens.position = pos
		lens.visible = false
		add_child(lens)
		_tail_lenses.append(lens)

## Follow the scene's darkness: time_of_day.gd announces every lighting change
## (including the weather dimming the sun), and the lamps fade toward it.
func _watch_time_of_day() -> void:
	var tod := get_tree().root.find_child("TimeOfDay", true, false)
	if tod == null or not tod.has_signal("lighting_changed"):
		if not headlight_positions.is_empty():
			push_warning("%s: no TimeOfDay node found, so its headlights will never come on" % name)
		return
	tod.lighting_changed.connect(_on_lighting_changed)
	var now: Dictionary = tod.shown()
	if not now.is_empty():
		_on_lighting_changed(now)

func _on_lighting_changed(p: Dictionary) -> void:
	_headlight_demand = VehicleMath.headlight_demand(p.sun_energy)

func _update_headlights(delta: float) -> void:
	var lit := driver != null or headlights_when_parked
	var target := _headlight_demand if lit else 0.0
	headlight_level = move_toward(headlight_level, target, HEADLIGHT_FADE_RATE * delta)
	if headlight_level == _headlight_applied:
		return  # nothing changed since the lamps were last set
	_headlight_applied = headlight_level
	var on := headlight_level > 0.001
	for lamp in _lamps:
		lamp.visible = on
		lamp.light_energy = headlight_energy * headlight_level
	for lens in _lenses:
		lens.visible = on
	_lens_material.emission_energy_multiplier = 3.0 * headlight_level

## The engine runs while somebody is driving. Revs follow road speed through
## the gears (with a lag, and a blip on the throttle) and the generator is
## topped up with audio each frame.
func _process(delta: float) -> void:
	_update_headlights(delta)
	_update_taillights(delta)
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
		# Top the buffer up in small chunks so boarding doesn't synthesize all of
		# it in one frame.
		var frames := mini(_playback.get_frames_available(), MAX_AUDIO_FRAMES_PER_UPDATE)
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

## Tail lights: dim red with the headlights, bright red while braking (the
## brake light works by day too, but only while someone is driving).
func _update_taillights(delta: float) -> void:
	brake_level = move_toward(brake_level, 1.0 if _braking else 0.0, BRAKE_LIGHT_FADE_RATE * delta)
	tail_level = maxf(headlight_level * TAIL_DIM, brake_level)
	if tail_level == _tail_applied:
		return
	_tail_applied = tail_level
	var on := tail_level > 0.001
	for lamp in _tail_lamps:
		lamp.visible = on
		lamp.light_energy = 2.0 * tail_level
	for lens in _tail_lenses:
		lens.visible = on
	_tail_material.emission_energy_multiplier = 3.0 * tail_level

func speed_mph() -> float:
	return VehicleMath.to_mph(speed)

func _physics_process(delta: float) -> void:
	var throttle := 0.0
	var steer_input := 0.0
	var handbrake := driver == null
	if handbrake and speed == 0.0 and steer == 0.0 and is_on_floor():
		_braking = false
		return  # parked and settled: nothing to simulate
	if driver != null:
		throttle = Input.get_axis("move_back", "move_forward")
		steer_input = Input.get_axis("move_right", "move_left")
		handbrake = Input.is_action_pressed("jump")
	_throttle = 0.0 if handbrake else throttle
	_braking = driver != null and VehicleMath.is_braking(speed, throttle, handbrake)
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
