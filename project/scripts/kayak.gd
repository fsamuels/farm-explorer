extends "res://scripts/vehicle.gd"
## A one-person kayak (D-150): vehicle.gd's arcade steering on the water. It
## floats on whatever water is under it (the pond, or a brimming ditch), bobbing
## a little, and the paddle swings while you move. Shallows stop it, because
## its hull is a box that meets the sloping bank; on dry ground it can only be
## dragged along at a crawl. It has no engine, so no engine note and no revs.

const BoatBuilder := preload("res://scripts/boat_builder.gd")

## Water must be at least this deep under the boat for it to float.
const FLOAT_DEPTH := 0.15
## The most you can drag it along on dry ground (m/s).
const DRAG_SPEED := 1.2
## How quickly it settles onto the surface (per second), and how far the bob goes.
const SETTLE_RATE := 8.0
const BOB := 0.025

var paddle: Node3D
var afloat := false
var _water: Node
var _stroke := 0.0
var _bob_time := 0.0

func _ready() -> void:
	has_engine = false
	paddle = BoatBuilder.build(self)
	super._ready()

## Skip the engine and lamps entirely: just swing the paddle.
func _process(delta: float) -> void:
	if paddle == null:
		return
	if driver == null:
		paddle.rotation = paddle.rotation.lerp(Vector3.ZERO, clampf(4.0 * delta, 0.0, 1.0))
		return
	# One stroke per ~1.3 s at a crawl, quicker as it speeds up; each side
	# dips in turn.
	_stroke += (0.8 + absf(speed)) * delta * 2.4
	var amount := clampf(absf(speed) / 1.5, 0.15, 1.0)
	paddle.rotation = Vector3(0.0, sin(_stroke) * 0.35 * amount, sin(_stroke) * 0.55 * amount)

func _top_speed() -> float:
	return super._top_speed() if afloat else DRAG_SPEED

func _top_reverse() -> float:
	return super._top_reverse() if afloat else DRAG_SPEED

func _settled() -> bool:
	return is_on_floor() and is_nan(_surface_here())

## The water surface under the boat, or NAN where there is too little water to float on.
func _surface_here() -> float:
	if not is_instance_valid(_water):
		_water = get_tree().get_first_node_in_group("water")
	if _water == null or _water.water_depth_at(global_position.x, global_position.z) < FLOAT_DEPTH:
		return NAN
	return _water.water_surface_at(global_position.x, global_position.z)

func _apply_vertical(delta: float) -> void:
	var surface := _surface_here()
	afloat = not is_nan(surface)
	if not afloat:
		super._apply_vertical(delta)
		return
	_bob_time += delta
	var target := surface + BOB * sin(_bob_time * 1.7)
	velocity.y = clampf((target - global_position.y) * SETTLE_RATE, -3.0, 3.0)
