extends Node3D

const TerrainMath := preload("res://scripts/terrain_math.gd")

@export var wander_radius := 12.0
@export var move_speed := 1.5
@export var idle_time_min := 2.0
@export var idle_time_max := 6.0
@export var arrival_distance := 0.3
@export var faces_movement := true
## Ducks and geese (D-142): once the pond holds water they head for it, swim
## about on it, and float on the surface as it rises and falls.
@export var swims := false
## Speed on the water, slower than walking.
@export var swim_speed := 0.5

## How far a swimmer looks for water, how likely it is to head for the pond when
## it isn't on it, and how likely to stay on it when it is.
const SWIM_REACH := 90.0
const GO_TO_WATER := 0.6
const STAY_ON_WATER := 0.85
## Water this deep lifts a bird off the bottom; it floats a little low in it and bobs.
const FLOAT_DEPTH := 0.12
const FLOAT_SINK := 0.04
const BOB := 0.015

var home_position: Vector3
## Height of the level ground this animal stands on; it follows the carved
## ground (the ditch and pond, D-140) down from there.
var _level_y := 0.0
var target_position: Vector3
var idle_timer := 0.0
var is_walking := false
## True while floating on the pond.
var swimming := false
var _water: Node
var _bob_phase := 0.0

func _ready() -> void:
	home_position = position
	_level_y = position.y - TerrainMath.height_at(global_position.x, global_position.z)
	_bob_phase = randf() * TAU
	_start_idle()

func _start_idle() -> void:
	is_walking = false
	idle_timer = randf_range(idle_time_min, idle_time_max)

## The water system, once it exists (found by its group).
func _find_water() -> Node:
	if _water == null or not is_instance_valid(_water):
		_water = get_tree().get_first_node_in_group("water")
	return _water

## Head for open water if there is any about; true if a swim spot was chosen.
func _pick_swim_target() -> bool:
	var water := _find_water()
	if water == null or not water.pond_has_water():
		return false
	if randf() >= (STAY_ON_WATER if swimming else GO_TO_WATER):
		return false
	var spot: Vector2 = water.random_swim_spot(Vector2(global_position.x, global_position.z), SWIM_REACH)
	if spot == Vector2.INF:
		return false
	var world := Vector3(spot.x, global_position.y, spot.y)
	target_position = get_parent().to_local(world) if get_parent() is Node3D else world
	is_walking = true
	return true

## Stand on the carved ground, or float on the pond where it is deep enough.
func _follow_ground() -> void:
	var x := global_position.x
	var z := global_position.z
	var y := TerrainMath.height_at(x, z)
	swimming = false
	if swims:
		var water := _find_water()
		if water:
			var depth: float = water.pond_depth_at(x, z)
			if depth > FLOAT_DEPTH:
				y += depth - FLOAT_SINK + sin(Time.get_ticks_msec() * 0.002 + _bob_phase) * BOB
				swimming = true
	position.y = _level_y + y

func _pick_new_target() -> void:
	if swims and _pick_swim_target():
		return
	var angle := randf_range(0.0, TAU)
	var radius := randf_range(0.0, wander_radius)
	target_position = home_position + Vector3(cos(angle), 0.0, sin(angle)) * radius
	is_walking = true

func _process(delta: float) -> void:
	if swims:
		_follow_ground()   # the water may have risen under a bird standing still
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
	position += direction * (swim_speed if swimming else move_speed) * delta
	_follow_ground()
