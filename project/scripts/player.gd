extends CharacterBody3D

const SPEED := 9.0
const JUMP_VELOCITY := 4.5
const MOUSE_SENSITIVITY := 0.003

## Visual layer the player's own body renders on. The first-person camera
## leaves it out of its cull mask (player.tscn) so you don't see the inside of
## your own head, but the body still casts its shadow.
const BODY_LAYER := 2

## Native ground speeds of the walk/sprint cycles at the Model's 0.969 scale,
## measured from foot travel in player.glb (D-89). Playback speed is scaled
## against these so feet don't skate.
const WALK_ANIM_SPEED := 1.0
const SPRINT_ANIM_SPEED := 8.9
const LOOPING_ANIMS := ["Idle", "Walk", "Jog", "Sprint", "Jump_Loop"]
const MODEL_TURN_RATE := 10.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interact_ray: RayCast3D = $Head/Camera3D/InteractRay
@onready var spring_arm: SpringArm3D = $Head/SpringArm3D
@onready var tp_camera: Camera3D = $Head/SpringArm3D/ThirdPersonCamera
@onready var tp_interact_ray: RayCast3D = $Head/SpringArm3D/ThirdPersonCamera/InteractRay
@onready var interact_prompt: Label = $HUD/InteractPrompt
@onready var model: Node3D = $Model
@onready var anim_player: AnimationPlayer = $Model/AnimationPlayer

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var third_person := false
var model_yaw := 0.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_set_body_layer(model)
	# Neither the spring arm nor the third-person ray (which starts behind the
	# player) should hit the player's own capsule.
	spring_arm.add_excluded_object(get_rid())
	tp_interact_ray.add_exception(self)
	interact_ray.add_exception(self)
	for anim_name in LOOPING_ANIMS:
		if anim_player.has_animation(anim_name):
			anim_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	anim_player.play("Idle")
	_apply_view()

func _set_body_layer(node: Node) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = 1 << (BODY_LAYER - 1)
	for child in node.get_children():
		_set_body_layer(child)

func _apply_view() -> void:
	camera.current = not third_person
	tp_camera.current = third_person
	interact_ray.enabled = not third_person
	tp_interact_ray.enabled = third_person

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event.is_action_pressed("toggle_view"):
		third_person = not third_person
		_apply_view()

	if event.is_action_pressed("interact"):
		var target := _interact_target()
		if target:
			target.interact(self)

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))

func _process(_delta: float) -> void:
	var target := _interact_target()
	interact_prompt.visible = target != null
	if target:
		interact_prompt.text = "E — " + target.get_interact_prompt()

## The nearest node under the crosshair that can be interacted with: the active
## view's ray collider or its closest ancestor with an `interact(actor)` method
## (e.g. gate.gd). In third person the ray starts at the camera behind the
## player, so a hit only counts if it is in front of the player's eyes and
## within reach (2.5m) of them.
func _interact_target() -> Node:
	var ray := tp_interact_ray if third_person else interact_ray
	if not ray.is_colliding():
		return null
	if third_person:
		var to_hit := ray.get_collision_point() - head.global_position
		if to_hit.length() > 2.5 or to_hit.dot(-head.global_basis.z) <= 0.0:
			return null
	var node: Node = ray.get_collider()
	while node and not node.has_method("interact"):
		node = node.get_parent()
	return node

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
	_animate(input_dir, delta)

## Face the body toward the movement direction (relative to the camera yaw) and
## pick the animation from ground speed / airborne state.
func _animate(input_dir: Vector2, delta: float) -> void:
	var target_yaw := 0.0
	if input_dir != Vector2.ZERO:
		target_yaw = atan2(-input_dir.x, -input_dir.y)
	model_yaw = lerp_angle(model_yaw, target_yaw, clamp(MODEL_TURN_RATE * delta, 0.0, 1.0))
	model.rotation.y = PI + model_yaw

	var ground_speed := Vector2(velocity.x, velocity.z).length()
	if not is_on_floor():
		_play("Jump_Loop", 1.0)
	elif ground_speed > 3.0:
		_play("Sprint", ground_speed / SPRINT_ANIM_SPEED)
	elif ground_speed > 0.2:
		_play("Walk", max(ground_speed / WALK_ANIM_SPEED, 0.5))
	else:
		_play("Idle", 1.0)

func _play(anim_name: String, speed_scale: float) -> void:
	if anim_player.current_animation != anim_name:
		anim_player.play(anim_name, 0.2)
	anim_player.speed_scale = speed_scale
