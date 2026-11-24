extends Node3D

const TerrainMath := preload("res://scripts/terrain_math.gd")

## The evening routine (D-161): a little after sunset (18:30) the birds come in to
## the pen by their house, and a little after dusk (19:30) they go inside, until
## sunrise. Clock hours, as time_of_day.gd keeps them.
const PEN_HOUR := 18.75
const ROOST_HOUR := 19.75
const RELEASE_HOUR := 6.5
enum Phase { FREE, PEN, ROOST }

@export var wander_radius := 12.0
@export var move_speed := 1.5
@export var idle_time_min := 2.0
@export var idle_time_max := 6.0
@export var arrival_distance := 0.3
@export var faces_movement := true
## Ducks and geese (D-142): once the pond holds water they head for it, swim
## about on it, and float on the surface as it rises and falls.
@export var swims := false
## Whether this bird puts itself away in the evening (the duck house's pen, then the house).
@export var evening_routine := false
## The group of the building it goes to, and its own hours (clock hours): the
## pen and then the house for the ducks, only the coop for the chickens, who go
## in earlier and come out later (D-166).
@export var routine_group: StringName = &"duck_house"
@export var pen_hour := PEN_HOUR
@export var roost_hour := ROOST_HOUR
@export var release_hour := RELEASE_HOUR
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
var _tod: Node
var _house: Node
var _phase := Phase.FREE
## Waypoints (world x, z) still to walk before wandering inside the house.
var _route: Array[Vector2] = []
var _warned := false
var _warned_api := false
var _bob_phase := 0.0

func _ready() -> void:
	home_position = position
	_level_y = position.y - TerrainMath.height_at(global_position.x, global_position.z)
	_bob_phase = randf() * TAU
	_start_idle()

## Which part of the evening routine the clock is in at hour `h`.
static func phase_at(h: float) -> Phase:
	return phase_for(h, PEN_HOUR, ROOST_HOUR, RELEASE_HOUR)

## The same for a bird with its own hours.
static func phase_for(h: float, pen: float, roost: float, release: float) -> Phase:
	h = fposmod(h, 24.0)
	if h >= roost or h < release:
		return Phase.ROOST
	if h >= pen:
		return Phase.PEN
	return Phase.FREE

func _find_routine_nodes() -> bool:
	if _tod == null or not is_instance_valid(_tod):
		# The clock sits beside the bird, or beside one of its parents (the flock).
		var up := get_parent()
		while up != null and _tod == null:
			_tod = up.get_node_or_null("TimeOfDay")
			up = up.get_parent()
	if _house == null or not is_instance_valid(_house):
		_house = get_tree().get_first_node_in_group(routine_group)
	var found := _tod != null and _house != null
	if found and not _warned_api:
		_warned_api = true
		for m in ["is_inside", "door_inside", "door_outside", "roost_point", "pen_point", "pen_radius", "roost_radius", "route_to_pen_front", "route_out_of_pen", "detour_round_pen"]:
			if not _house.has_method(m):
				push_warning("%s: %s lacks %s() for the evening routine" % [name, routine_group, m])
				found = false
	if not found and not _warned:
		_warned = true
		push_warning("%s: evening_routine needs a TimeOfDay and a building in group %s; staying out" % [name, routine_group])
	return found

## Follow the clock into a new phase: head for the pen or the house, or go back to wandering.
func _update_phase() -> void:
	if not _find_routine_nodes():
		return
	var phase := phase_for(_tod.hour, pen_hour, roost_hour, release_hour)
	if phase == _phase:
		return
	_phase = phase
	_route.clear()
	# Walk round the house, not through it, then on to the pen or in at the door.
	var here := Vector2(global_position.x, global_position.z)
	match phase:
		Phase.PEN:
			_route = _house.route_to_pen_front(here)   # in through the gap by the tanks
			_route.append(_house.pen_point())
		Phase.ROOST:
			if not _house.is_inside(here):
				_route = _house.route_to_pen_front(here)
				_route.append(_house.door_outside())
				_route.append(_house.door_inside())
		Phase.FREE:
			_route = _house.route_out_of_pen(here)   # out of the door and the gap first
	_pick_new_target()

func _go_to(spot: Vector2) -> void:
	var world := Vector3(spot.x, global_position.y, spot.y)
	target_position = get_parent().to_local(world) if get_parent() is Node3D else world
	is_walking = true

## A spot to amble to while penned or roosting.
func _routine_target() -> void:
	var centre: Vector2 = _house.pen_point() if _phase == Phase.PEN else _house.roost_point()
	var radius: float = _house.pen_radius() if _phase == Phase.PEN else _house.roost_radius()
	_go_to(centre + Vector2.from_angle(randf() * TAU) * randf() * radius)

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
	if not _route.is_empty():
		_go_to(_route.pop_front())
		return
	if evening_routine and _phase != Phase.FREE:
		_routine_target()
		return
	if not (swims and _pick_swim_target()):
		var angle := randf_range(0.0, TAU)
		var radius := randf_range(0.0, wander_radius)
		target_position = home_position + Vector3(cos(angle), 0.0, sin(angle)) * radius
		is_walking = true
		_keep_out_of_building()
	if evening_routine:
		_detour_round_pen()

## Pick the wander target again, a few times, if it is inside a building (the coop).
func _keep_out_of_building() -> void:
	if not evening_routine or not _find_routine_nodes() or not _house.has_method("is_blocked"):
		return
	for i in 9:
		var to: Vector3 = get_parent().to_global(target_position) if get_parent() is Node3D else target_position
		if not _house.is_blocked(Vector2(to.x, to.z)):
			return
		if i == 8:
			break
		var angle := randf_range(0.0, TAU)
		target_position = home_position + Vector3(cos(angle), 0.0, sin(angle)) * randf_range(0.0, wander_radius)
	target_position = home_position   # eight bad draws: stay put rather than lean on a wall

## Out and about, walk round the duck pen rather than across its fences.
func _detour_round_pen() -> void:
	if not _find_routine_nodes():
		return
	var to: Vector3 = get_parent().to_global(target_position) if get_parent() is Node3D else target_position
	var target := Vector2(to.x, to.z)
	_route = _house.detour_round_pen(Vector2(global_position.x, global_position.z), target)
	if not _route.is_empty():
		_route.append(target)
		_go_to(_route.pop_front())

func _process(delta: float) -> void:
	if evening_routine:
		_update_phase()
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
		if not _route.is_empty():
			_go_to(_route.pop_front())   # keep going: round the house, to the door, in
		else:
			_start_idle()
		return

	var direction := to_target / distance
	if faces_movement:
		look_at(global_position + direction, Vector3.UP)
	position += direction * (swim_speed if swimming else move_speed) * delta
	_follow_ground()
