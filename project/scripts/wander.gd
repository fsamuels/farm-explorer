extends Node3D

const TerrainMath := preload("res://scripts/terrain_math.gd")

@export var wander_radius := 12.0
@export var move_speed := 1.5
@export var idle_time_min := 2.0
@export var idle_time_max := 6.0
@export var arrival_distance := 0.3
@export var faces_movement := true

var home_position: Vector3
## Height of the level ground this animal stands on; it follows the carved
## ground (the ditch and pond, D-138) down from there.
var _level_y := 0.0
var target_position: Vector3
var idle_timer := 0.0
var is_walking := false

func _ready() -> void:
	home_position = position
	_level_y = position.y - TerrainMath.height_at(global_position.x, global_position.z)
	_start_idle()

func _start_idle() -> void:
	is_walking = false
	idle_timer = randf_range(idle_time_min, idle_time_max)

func _pick_new_target() -> void:
	var angle := randf_range(0.0, TAU)
	var radius := randf_range(0.0, wander_radius)
	target_position = home_position + Vector3(cos(angle), 0.0, sin(angle)) * radius
	is_walking = true

func _process(delta: float) -> void:
	if not is_walking:
		idle_timer -= delta
		if idle_timer <= 0.0:
			_pick_new_target()
		return

	var to_target := target_position - position
	to_target.y = 0.0
	var distance := to_target.length()
	if distance <= arrival_distance:
		_start_idle()
		return

	var direction := to_target / distance
	if faces_movement:
		look_at(global_position + direction, Vector3.UP)
	position += direction * move_speed * delta
	position.y = _level_y + TerrainMath.height_at(global_position.x, global_position.z)
