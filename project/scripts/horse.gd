extends Node3D

const WANDER_RADIUS := 12.0
const WALK_SPEED := 1.5
const ARRIVAL_DISTANCE := 0.3
const IDLE_TIME_MIN := 2.0
const IDLE_TIME_MAX := 6.0

@onready var anim_player: AnimationPlayer = $Model/AnimationPlayer

var home_position: Vector3
var target_position: Vector3
var idle_timer := 0.0
var is_walking := false

func _ready() -> void:
	home_position = global_position
	_start_idle()

func _start_idle() -> void:
	is_walking = false
	idle_timer = randf_range(IDLE_TIME_MIN, IDLE_TIME_MAX)
	anim_player.play("Armature|Idle")

func _pick_new_target() -> void:
	var angle := randf_range(0.0, TAU)
	var radius := randf_range(0.0, WANDER_RADIUS)
	target_position = home_position + Vector3(cos(angle), 0.0, sin(angle)) * radius
	is_walking = true
	anim_player.play("Armature|Walk")

func _process(delta: float) -> void:
	if not is_walking:
		idle_timer -= delta
		if idle_timer <= 0.0:
			_pick_new_target()
		return

	var to_target := target_position - global_position
	to_target.y = 0.0
	var distance := to_target.length()
	if distance <= ARRIVAL_DISTANCE:
		_start_idle()
		return

	var direction := to_target / distance
	look_at(global_position + direction, Vector3.UP)
	global_position += direction * WALK_SPEED * delta
