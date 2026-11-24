extends SceneTree
## Tests for the ducks' and geese's evening routine (D-161): into the pen a little
## after sunset, into the house a little after dusk. Run headless from project/:
##   godot --headless -s res://tests/test_bird_routine.gd

const Wander := preload("res://scripts/wander.gd")
const TimeOfDay := preload("res://scripts/time_of_day.gd")

var _failures := 0

func _init() -> void:
	_run.call_deferred()

func _check(cond: bool, what: String) -> void:
	if not cond:
		_failures += 1
		push_error("FAIL: " + what)

func _done() -> void:
	print("bird_routine: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures else 0)

func _run() -> void:
	# The phases, after the sky's own sunset (18:30) and dusk (19:30).
	_check(Wander.phase_at(13.0) == Wander.Phase.FREE, "free by day")
	_check(Wander.phase_at(18.5) == Wander.Phase.FREE, "still free at sunset")
	_check(Wander.PEN_HOUR > TimeOfDay.hour_of("sunset") and Wander.PEN_HOUR < TimeOfDay.hour_of("dusk"), "penned a little after sunset")
	_check(Wander.ROOST_HOUR > TimeOfDay.hour_of("dusk") and Wander.ROOST_HOUR < TimeOfDay.hour_of("night"), "housed a little after dusk")
	_check(Wander.phase_at(19.0) == Wander.Phase.PEN, "in the pen between")
	_check(Wander.phase_at(21.0) == Wander.Phase.ROOST, "in the house at night")
	_check(Wander.phase_at(2.0) == Wander.Phase.ROOST, "in the house after midnight")
	_check(Wander.phase_at(7.0) == Wander.Phase.FREE, "out again after sunrise")

	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await physics_frame
	var tod := main.get_node("TimeOfDay")
	tod.clock_running = false
	var house := main.get_node("Buildings/DuckHouse")
	var goose: Node3D = main.get_node("Goose4")
	_check(goose.evening_routine and main.get_node("MallardDuck").evening_routine, "birds keep the routine")

	var pen: Vector2 = house.pen_point()
	# Evening: they walk to the pen.
	tod.hour = 19.0
	goose.move_speed = 4.0
	for i in 1500:
		goose._process(0.1)
	var p := Vector2(goose.global_position.x, goose.global_position.z)
	_check(p.distance_to(pen) <= 3.0, "the goose is in the pen at 19:00 (%s vs %s)" % [p, pen])
	# Night: through the doorway, into the house.
	tod.hour = 21.0
	for i in 1500:
		goose._process(0.1)
	p = Vector2(goose.global_position.x, goose.global_position.z)
	_check(p.distance_to(house.roost_point()) <= 1.6, "the goose is in the house at 21:00 (%s)" % p)
	# Morning: back out.
	tod.hour = 8.0
	for i in 20:
		goose._process(0.1)
	_check(goose._phase == Wander.Phase.FREE, "the goose is let out in the morning")
	_done()
