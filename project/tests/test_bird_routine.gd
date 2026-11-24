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
	var walk: Array[Vector2] = []
	for i in 1500:
		goose._process(0.1)
		walk.append(Vector2(goose.global_position.x, goose.global_position.z))
	_check(_fence_crossings(house, walk) == 1, "the goose comes into the pen once, through the gap by the tanks")
	var p := Vector2(goose.global_position.x, goose.global_position.z)
	_check(p.distance_to(pen) <= 3.0, "the goose is in the pen at 19:00 (%s vs %s)" % [p, pen])
	# Night: through the doorway, into the house.
	tod.hour = 21.0
	for i in 1500:
		goose._process(0.1)
	p = Vector2(goose.global_position.x, goose.global_position.z)
	_check(p.distance_to(house.roost_point()) <= 1.6, "the goose is in the house at 21:00 (%s)" % p)
	# Morning: back out, through the door and the gap.
	tod.hour = 8.0
	walk.clear()
	walk.append(p)
	for i in 600:
		goose._process(0.1)
		walk.append(Vector2(goose.global_position.x, goose.global_position.z))
	_check(not house.in_pen(walk[-1]), "the goose leaves the pen in the morning")
	_check(_fence_crossings(house, walk) == 1, "it leaves through the gap")
	_check(_crossings(house, walk) == 1, "and through the doorway")
	_check(goose._phase == Wander.Phase.FREE, "the goose is let out in the morning")

	# Routes go round the house, never through it.
	var behind: Vector2 = house.world_xz(Vector2(-3.0, 0.5))
	var route: Array = house.route_to_front(behind)
	_check(route.size() == 2, "from behind the house, round both corners")
	route.push_front(behind)
	route.append(house.door_outside())
	route.append(house.door_inside())
	_check(_crossings(house, route) == 1, "the route from behind only goes through the doorway")
	_check(house.route_to_front(house.pen_point()).is_empty(), "no detour from the pen")
	var out: Array = house.route_to_front(house.roost_point())
	_check(out.size() == 2 and out[1] == house.door_outside(), "out through the door in the morning")
	# From the pond, the field east of the pen and behind the house, routes in
	# cross no fence and no wall but at the gap and the doorway.
	for start in [Vector2(-5.0, 22.0), Vector2(0.0, 8.0), Vector2(40.0, 18.0), Vector2(30.0, 5.0), Vector2(14.0, 25.0)]:
		var r: Array = house.route_to_pen_front(start)
		r.push_front(start)
		r.append(house.door_outside())
		r.append(house.door_inside())
		_check(_fence_crossings(house, r) == 1, "from %s, into the pen once, at the gap" % start)
		_check(_crossings(house, r) == 1, "from %s, into the house only at the doorway" % start)
	# Out and about, walks between the field and the pond go round the pen.
	for pair in [[Vector2(40.0, 18.0), Vector2(-5.0, 22.0)], [Vector2(-5.0, 22.0), Vector2(40.0, 18.0)], [house.gap_outside(), Vector2(41.5, 17.9)]]:
		var r: Array = house.detour_round_pen(pair[0], pair[1])
		_check(not r.is_empty(), "a detour from %s to %s" % pair)
		r.push_front(pair[0])
		r.append(pair[1])
		_check(_fence_crossings(house, r) == 0 and _crossings(house, r) == 0, "from %s to %s, round the pen and the house" % pair)
	_check(house.detour_round_pen(Vector2(40.0, 18.0), Vector2(42.0, 20.0)).is_empty(), "no detour for a walk that misses the pen")
	# A goose shut in the house walks out of the door when let out.
	goose.position = goose.get_parent().to_local(Vector3(house.roost_point().x, goose.global_position.y, house.roost_point().y))
	tod.hour = 21.0
	goose._process(0.1)
	tod.hour = 8.0
	var steps: Array[Vector2] = []
	for i in 300:
		goose._process(0.1)
		steps.append(Vector2(goose.global_position.x, goose.global_position.z))
	_check(not house.is_inside(steps[-1]), "the goose has left the house")
	_check(_crossings(house, steps) == 1, "the goose leaves by the doorway, not the wall")
	_done()

## How many times a path of world points passes from inside the house to outside
## or back, through any wall but the doorway.
func _crossings(house: Node, path: Array) -> int:
	var walls := 0
	var door: Vector2 = house.door_span()
	for i in range(1, path.size()):
		var a: Vector2 = path[i - 1]
		var b: Vector2 = path[i]
		for k in 20:
			var p: Vector2 = a.lerp(b, k / 20.0)
			var q: Vector2 = a.lerp(b, (k + 1) / 20.0)
			if house.is_inside(p) != house.is_inside(q):
				var m: Vector2 = house.local_xz((p + q) * 0.5)
				var through_door: bool = m.x > 0.0 and m.y > door.x and m.y < door.y
				walls += 1 if through_door else 100
	return walls

## How many times a path crosses the pen's edge; a crossing away from the gap
## between the house and the fence counts 100.
func _fence_crossings(house: Node, path: Array) -> int:
	var n := 0
	var gap: Vector2 = house.gap_middle()
	for i in range(1, path.size()):
		var a: Vector2 = path[i - 1]
		var b: Vector2 = path[i]
		for k in 20:
			var p: Vector2 = a.lerp(b, k / 20.0)
			var q: Vector2 = a.lerp(b, (k + 1) / 20.0)
			if house.in_pen(p) != house.in_pen(q):
				n += 1 if ((p + q) * 0.5).distance_to(gap) < 1.0 else 100
	return n
