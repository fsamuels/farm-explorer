extends SceneTree
## Tests for scripts/weather.gd (D-95) and its overcast hook in time_of_day.gd:
## the pure helpers, and that main.tscn's Weather node switches rain and snow
## on R, clouds the sky over through TimeOfDay, and leaves time of day working
## underneath. Run headless from project/ (after the editor has imported assets
## once):
##   godot --headless -s res://tests/test_weather.gd

const Weather := preload("res://scripts/weather.gd")
const TimeOfDay := preload("res://scripts/time_of_day.gd")

var _failures := 0

func _init() -> void:
	_run.call_deferred()

func _check(cond: bool, what: String) -> void:
	if not cond:
		_failures += 1
		push_error("FAIL: " + what)

func _run() -> void:
	_test_next_weather()
	_test_overcast_preset()
	_test_particle_brightness()
	await _test_scene()
	print("weather: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures else 0)

func _test_next_weather() -> void:
	_check(Weather.next_weather("clear") == "rain", "clear -> rain")
	_check(Weather.next_weather("rain") == "snow", "rain -> snow")
	_check(Weather.next_weather("snow") == "clear", "snow wraps to clear")
	_check(Weather.next_weather("hail") == "clear", "unknown restarts at clear")
	for w in Weather.ORDER:
		_check(Weather.OVERCAST.has(w) and Weather.LABELS.has(w), "%s has overcast + label" % w)

func _test_overcast_preset() -> void:
	for name in TimeOfDay.ORDER:
		var p: Dictionary = TimeOfDay.PRESETS[name]
		_check(TimeOfDay.overcast_preset(p, 0.0) == p, "%s: no overcast leaves it alone" % name)
		var o := TimeOfDay.overcast_preset(p, 1.0)
		_check(o.sun_energy < p.sun_energy, "%s: overcast dims the sun" % name)
		_check(o.fog_density > p.fog_density, "%s: overcast thickens fog" % name)
		_check(o.sky_color.s < p.sky_color.s + 0.001, "%s: overcast greys the sky" % name)
		_check(o.keys() == p.keys(), "%s: same keys" % name)

func _test_particle_brightness() -> void:
	var day := Weather.particle_brightness(TimeOfDay.PRESETS.day)
	var night := Weather.particle_brightness(TimeOfDay.PRESETS.night)
	_check(is_equal_approx(day, 1.0), "full brightness by day: %s" % day)
	_check(night < 0.5 and night >= 0.15, "dim but visible at night: %s" % night)

func _test_scene() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	var weather = main.get_node("Weather")
	var tod = main.get_node("TimeOfDay")
	var sun: DirectionalLight3D = main.get_node("DirectionalLight3D")
	var rain: GPUParticles3D = weather.get_node("Rain")
	var snow: GPUParticles3D = weather.get_node("Snow")

	_check(weather.current == "clear" and not rain.emitting and not snow.emitting, "starts clear")
	_check(is_equal_approx(tod.overcast, 0.0) and is_equal_approx(sun.light_energy, 1.0), "clear leaves the sun alone")

	weather.transition_seconds = 0.05
	_press(KEY_R)
	await process_frame
	_check(weather.current == "rain" and rain.emitting and not snow.emitting, "R starts rain")
	await create_timer(0.2).timeout
	_check(is_equal_approx(tod.overcast, 1.0), "rain clouds over fully: %s" % tod.overcast)
	_check(sun.light_energy < 0.5, "rain dims the sun: %s" % sun.light_energy)
	var cam := root.get_viewport().get_camera_3d()
	if cam:
		_check(rain.global_position.distance_to(cam.global_position + Vector3(0, Weather.RAIN_HEIGHT, 0)) < 0.01, "rain follows the camera")

	tod.set_preset("night", true)
	_check(tod.current == "night" and is_equal_approx(sun.light_energy, 0.3 * 0.25), "time of day still applies under rain: %s" % sun.light_energy)
	var mat: StandardMaterial3D = rain.draw_pass_1.surface_get_material(0)
	_check(mat.albedo_color.v < 0.5, "rain is dimmed at night: %s" % mat.albedo_color)
	tod.set_preset("day", true)

	_press(KEY_R)
	await process_frame
	_check(weather.current == "snow" and snow.emitting and not rain.emitting, "R again switches to snow")
	paused = true
	_press(KEY_R)
	await process_frame
	_check(weather.current == "snow", "R is ignored while the map has the game paused")
	paused = false
	_press(KEY_R)
	await process_frame
	await create_timer(0.2).timeout
	_check(weather.current == "clear" and not snow.emitting, "R again clears")
	_check(is_equal_approx(sun.light_energy, 1.0), "clearing restores the sun: %s" % sun.light_energy)
	main.queue_free()

func _press(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
