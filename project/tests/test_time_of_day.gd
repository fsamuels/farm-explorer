extends SceneTree
## Tests for scripts/time_of_day.gd (D-94): the pure preset helpers, and that
## main.tscn's TimeOfDay node drives the real sun and environment, starts at the
## scene's original daytime lighting, steps through the cycle on T, and runs the
## clock on Y (D-99). Run
## headless from project/ (after the editor has imported assets once):
##   godot --headless -s res://tests/test_time_of_day.gd

const TimeOfDay := preload("res://scripts/time_of_day.gd")

var _failures := 0

func _init() -> void:
	_run.call_deferred()

func _check(cond: bool, what: String) -> void:
	if not cond:
		_failures += 1
		push_error("FAIL: " + what)

func _run() -> void:
	_test_next_preset()
	_test_presets_share_keys()
	_test_blend()
	_test_clock_math()
	await _test_scene()
	print("time_of_day: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures else 0)

func _test_next_preset() -> void:
	_check((load("res://scripts/time_of_day.gd") as GDScript).can_instantiate(), "time_of_day.gd compiles")
	_check(TimeOfDay.next_preset("day") == "sunset", "day -> sunset")
	_check(TimeOfDay.next_preset("sunset") == "dusk", "sunset -> dusk")
	_check(TimeOfDay.next_preset("dusk") == "night", "dusk -> night")
	_check(TimeOfDay.next_preset("night") == "dawn", "night -> dawn")
	_check(TimeOfDay.next_preset("dawn") == "sunrise", "dawn -> sunrise")
	_check(TimeOfDay.next_preset("sunrise") == "day", "sunrise wraps to day")
	_check(TimeOfDay.next_preset("bogus") == "day", "unknown restarts at day")

func _test_presets_share_keys() -> void:
	var keys: Array = TimeOfDay.PRESETS.day.keys()
	keys.sort()
	for name in TimeOfDay.ORDER:
		var k: Array = TimeOfDay.PRESETS[name].keys()
		k.sort()
		_check(k == keys, "%s has the same keys as day" % name)

func _test_blend() -> void:
	var a: Dictionary = TimeOfDay.PRESETS.day
	var b: Dictionary = TimeOfDay.PRESETS.night
	_check(TimeOfDay.blend(a, b, 0.0).sun_energy == a.sun_energy, "t=0 is a")
	_check(TimeOfDay.blend(a, b, 1.0).sky_color.is_equal_approx(b.sky_color), "t=1 is b")
	var mid := TimeOfDay.blend(a, b, 0.5)
	_check(is_equal_approx(mid.sun_energy, (a.sun_energy + b.sun_energy) / 2.0), "energy midpoint")
	# The sun rotation is slerped (constant angular speed), not lerped per Euler angle.
	var dusk: Dictionary = TimeOfDay.PRESETS.dusk
	var fa := _forward(dusk.sun_rotation)
	var fb := _forward(b.sun_rotation)
	var fm := _forward(TimeOfDay.blend(dusk, b, 0.5).sun_rotation)
	_check(absf(fa.angle_to(fm) - fm.angle_to(fb)) < 0.01, "sun rotation slerps: midpoint is equally far from both ends")
	_check(_forward(TimeOfDay.blend(a, b, 1.0).sun_rotation).is_equal_approx(fb), "rotation t=1 is b")
	_check(mid.label == b.label, "label comes from the target")

func _test_clock_math() -> void:
	_check(TimeOfDay.KEYFRAMES.size() == TimeOfDay.ORDER.size(), "every preset has a clock hour")
	var last := -1.0
	for k in TimeOfDay.KEYFRAMES:
		_check(TimeOfDay.PRESETS.has(k[1]) and TimeOfDay.ORDER.has(k[1]), "%s is a preset" % k[1])
		_check(k[0] > last and k[0] < 24.0, "keyframes are in clock order: %s" % k[0])
		last = k[0]
		var at := TimeOfDay.preset_at_hour(k[0])
		var p: Dictionary = TimeOfDay.PRESETS[k[1]]
		_check(is_equal_approx(at.sun_energy, p.sun_energy) and at.sky_color.is_equal_approx(p.sky_color), "%s: exact at its own hour" % k[1])
		_check(TimeOfDay.keyframe_before(k[0]) == k[1], "%s: is the keyframe at its own hour" % k[1])
		_check(TimeOfDay.hour_of(k[1]) == k[0], "%s: hour_of matches" % k[1])
	var noon := TimeOfDay.preset_at_hour(13.0)
	var sunset := TimeOfDay.preset_at_hour(18.5)
	var mid := TimeOfDay.preset_at_hour(15.75)
	_check(is_equal_approx(mid.sun_energy, (noon.sun_energy + sunset.sun_energy) / 2.0), "halfway between day and sunset is the midpoint")
	# The night -> dawn span crosses midnight.
	var night := TimeOfDay.PRESETS.night
	var dawn := TimeOfDay.PRESETS.dawn
	var past_midnight := TimeOfDay.preset_at_hour(26.25)  # 02:15, halfway through 23:00 -> 05:30
	_check(is_equal_approx(past_midnight.sun_energy, (night.sun_energy + dawn.sun_energy) / 2.0), "midnight wrap blends night into dawn")
	_check(TimeOfDay.keyframe_before(2.0) == "night" and TimeOfDay.keyframe_before(-1.0) == "night", "after midnight is still night")
	_check(TimeOfDay.keyframe_before(5.0) == "night" and TimeOfDay.keyframe_before(6.0) == "dawn", "dawn begins at 05:30")
	_check(TimeOfDay.format_hour(13.5) == "13:30" and TimeOfDay.format_hour(0.0) == "00:00" and TimeOfDay.format_hour(25.0) == "01:00", "format_hour")
	_check(not TimeOfDay.preset_at_hour(10.0).is_read_only(), "clock presets are writable copies")

func _test_scene() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	var tod = main.get_node("TimeOfDay")
	var sun: DirectionalLight3D = main.get_node("DirectionalLight3D")
	var env: Environment = main.get_node("WorldEnvironment").environment

	_check(tod.current == "day", "starts at day")
	# The day preset must keep the look main.tscn had before D-94.
	var expected := Basis(Vector3(0.8660254, 0, 0.5), Vector3(0.35355338, 0.70710677, -0.6123724), Vector3(-0.35355338, 0.70710677, 0.6123724))
	_check(sun.basis.is_equal_approx(expected), "day sun matches the original light: %s" % sun.basis)
	_check(env.background_color.is_equal_approx(Color(0.55, 0.75, 0.95)), "day sky unchanged")
	_check(not env.fog_enabled, "no fog by day")

	tod.set_preset("night", true)
	_check(is_equal_approx(sun.light_energy, 0.3), "night dims the sun: %s" % sun.light_energy)
	_check(env.fog_enabled and env.fog_density > 0.0, "night has fog")
	_check(env.background_color.v < 0.2, "night sky is dark")

	tod.transition_seconds = 0.05
	_press(KEY_T)
	await process_frame
	_check(tod.current == "dawn", "T after night goes to dawn")
	await create_timer(0.2).timeout
	_check(is_equal_approx(sun.light_energy, 0.8), "transition finishes at dawn energy: %s" % sun.light_energy)
	_press(KEY_T)
	await process_frame
	_check(tod.current == "sunrise", "T after dawn goes to sunrise")
	_press(KEY_T)
	await process_frame
	_check(tod.current == "day", "T after sunrise goes back to day")
	_press(KEY_T)
	await process_frame
	_check(tod.current == "sunset", "T again goes to sunset")
	paused = true
	_press(KEY_T)
	await process_frame
	_check(tod.current == "sunset", "T is ignored while the map has the game paused")
	paused = false

	# The clock: starts stopped, Y runs it, time advances, T stops it.
	tod.set_preset("day", true)
	_check(not tod.clock_running and is_equal_approx(tod.hour, 13.0), "clock starts stopped at 13:00")
	tod.day_seconds = 24.0  # one clock hour per second
	_press(KEY_Y)
	await process_frame
	_check(tod.clock_running, "Y starts the clock")
	await create_timer(0.5).timeout
	_check(tod.hour > 13.2 and tod.hour < 14.5, "the hour advances: %s" % tod.hour)
	_press(KEY_Y)
	await process_frame
	var held: float = tod.hour
	_check(not tod.clock_running, "Y again stops the clock")
	await create_timer(0.2).timeout
	_check(is_equal_approx(tod.hour, held), "a stopped clock holds its hour")
	paused = true
	_press(KEY_Y)
	await process_frame
	_check(not tod.clock_running, "Y is ignored while the map has the game paused")
	paused = false
	tod.hour = 20.0
	_press(KEY_Y)
	await process_frame
	tod.hour = 23.0
	await process_frame
	_check(tod.current == "night" and sun.light_energy < 0.35, "the clock drives the lighting: %s %s" % [tod.current, sun.light_energy])
	tod.transition_seconds = 0.05
	_press(KEY_T)
	await process_frame
	_check(not tod.clock_running and tod.current == "dawn" and is_equal_approx(tod.hour, 5.5), "T stops the clock and jumps to the next preset")
	main.queue_free()

func _forward(euler_deg: Vector3) -> Vector3:
	return -Basis.from_euler(euler_deg * (PI / 180.0)).z

func _press(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
