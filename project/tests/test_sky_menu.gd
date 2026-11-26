extends SceneTree
## Tests for the sky menu (D-110), the constellation name labels and the new
## start position and default view. Run headless from project/:
##   godot --headless -s res://tests/test_sky_menu.gd

const CN := preload("res://scripts/constellation_names.gd")
const SkyMath := preload("res://scripts/sky_math.gd")
const Weather := preload("res://scripts/weather.gd")
const TimeOfDay := preload("res://scripts/time_of_day.gd")
const ControlsOverlay := preload("res://scripts/controls_overlay.gd")

var _failures := 0

func _init() -> void:
	_run.call_deferred()

func _check(cond: bool, what: String) -> void:
	if not cond:
		_failures += 1
		push_error("FAIL: " + what)

func _run() -> void:
	_test_names()
	_test_moon()
	_test_overlay_keys()
	await _test_scene()
	print("sky menu: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures else 0)

func _test_names() -> void:
	_check(is_zero_approx(CN.label_alpha(0.0, 0.0)), "no name labels by day")
	_check(is_equal_approx(CN.label_alpha(1.0, 0.0), 1.0), "full name labels on a clear night")
	_check(is_zero_approx(CN.label_alpha(1.0, 1.0)), "overcast hides the names")
	# Cassiopeia is circumpolar at this latitude: above the horizon at any hour.
	for lst in [0.0, 90.0, 180.0, 270.0]:
		_check(CN.above_horizon(CN.direction(2, lst)), "Cassiopeia stays up at sidereal time %s" % lst)
	# Every direction is a unit vector, and the pole star's constellation sits near the pole altitude.
	_check(is_equal_approx(CN.direction(0, 33.0).length(), 1.0), "directions are unit vectors")
	var minor := CN.direction(1, 10.0)
	_check(absf(rad_to_deg(asin(minor.y)) - SkyMath.LATITUDE) < 15.0, "Ursa Minor is near the pole altitude")

func _test_moon() -> void:
	# Names are for the dark of night only, not dusk or dawn.
	_check(is_zero_approx(CN.label_alpha(0.45, 0.0)) and is_zero_approx(CN.label_alpha(0.35, 0.0)), "no names at dusk or dawn")
	# The full moon rises in the east at 18:30, is due south and highest at 00:30, sets in the west at 06:30.
	var rise := TimeOfDay.moon_direction(18.5)
	var high := TimeOfDay.moon_direction(0.5)
	var set_ := TimeOfDay.moon_direction(6.5)
	_check(absf(rise.y) < 0.01 and rise.x > 0.9, "the moon rises in the east: %s" % rise)
	_check(set_.y < 0.01 and absf(set_.y) < 0.01 and set_.x < -0.9, "the moon sets in the west: %s" % set_)
	_check(high.y > 0.6 and high.z > 0.5 and absf(high.x) < 0.01, "the moon is high in the south at 00:30: %s" % high)
	_check(TimeOfDay.moon_direction(13.0).y < -0.5, "the moon is down at midday")
	var night: Dictionary = TimeOfDay.PRESETS.night
	var lit := TimeOfDay.moon_adjust(night, 1.0, 0.5, true)
	_check(lit.sun_energy > 0.25, "a high moon lights the night: %s" % lit.sun_energy)
	_check(is_zero_approx(TimeOfDay.moon_adjust(night, 1.0, 0.5, false).sun_energy), "no moon, no moonlight")
	_check(is_zero_approx(TimeOfDay.moon_adjust(night, 1.0, 13.0, true).sun_energy), "no moonlight while the moon is down")
	_check(is_equal_approx(TimeOfDay.moon_adjust(TimeOfDay.PRESETS.day, 0.0, 13.0, true).sun_energy, 1.0), "the moon changes nothing by day")
	var dir: Vector3 = Basis.from_euler(lit.sun_rotation * (PI / 180.0)).z
	_check(dir.distance_to(high) < 0.01, "the night light comes from where the moon is: %s vs %s" % [dir, high])
	_check(TimeOfDay.moon_glare(1.0, 0.5, true) > 0.4 and is_zero_approx(TimeOfDay.moon_glare(1.0, 0.5, false)), "a high moon washes out stars, off it does not")
	_check(is_zero_approx(TimeOfDay.moon_glare(1.0, 13.0, true)) and is_zero_approx(TimeOfDay.moon_glare(0.0, 0.5, true)), "no glare while down or by day")

func _test_overlay_keys() -> void:
	var move := InputEventKey.new()
	move.physical_keycode = KEY_W
	move.pressed = true
	_check(not ControlsOverlay.is_action_key(move), "W is a moving key")
	for k in [KEY_A, KEY_S, KEY_D, KEY_SPACE, KEY_SHIFT, KEY_F1]:
		var e := InputEventKey.new()
		e.physical_keycode = k
		e.pressed = true
		_check(not ControlsOverlay.is_action_key(e), "key %s does not minimize the help" % k)
	for k in [KEY_CTRL, KEY_ALT, KEY_META, KEY_CAPSLOCK]:
		var e := InputEventKey.new()
		e.physical_keycode = k
		e.keycode = k
		e.pressed = true
		_check(not ControlsOverlay.is_action_key(e), "modifier key %s does not minimize the help" % k)
	var cmd_c := InputEventKey.new()
	cmd_c.physical_keycode = KEY_C
	cmd_c.meta_pressed = true
	cmd_c.pressed = true
	_check(not ControlsOverlay.is_action_key(cmd_c), "an OS shortcut does not minimize the help")
	for k in [KEY_T, KEY_G, KEY_M, KEY_N, KEY_E, KEY_ESCAPE]:
		var e := InputEventKey.new()
		e.physical_keycode = k
		e.pressed = true
		_check(ControlsOverlay.is_action_key(e), "key %s minimizes the help" % k)
		e.echo = true
		_check(not ControlsOverlay.is_action_key(e), "a held key's echo does not")

func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	return e

func _test_scene() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var player: Node3D = main.get_node("Player")
	var tod: Node = main.get_node("TimeOfDay")
	var weather: Node = main.get_node("Weather")
	var menu: Node = main.get_node("SkyMenu")
	_check(player.global_position.distance_to(Vector3(232.6, player.global_position.y, -48.4)) < 0.2, "the player starts at 232.6, -48.4: %s" % player.global_position)
	var bearing := fposmod(rad_to_deg(-player.global_rotation.y), 360.0)
	_check(absf(bearing - 249.0) < 0.5, "the player starts facing 249 degrees: %s" % bearing)
	_check(player.third_person and player.tp_camera.current and not player.camera.current, "the game starts in third person")

	_check(not menu.is_open() and not paused, "the menu starts closed")
	menu.set_open(true)
	_check(menu.is_open() and paused, "opening the menu pauses the game")
	await process_frame
	_check(menu._close_button.has_focus(), "opening the menu focuses Close, so a controller can steer it")
	# B (ui_cancel on a pad) must close the menu without freeing the mouse.
	var back := InputEventJoypadButton.new()
	back.button_index = JOY_BUTTON_B
	back.pressed = true
	_check(back.is_action("ui_cancel"), "B is ui_cancel, so it closes menus")
	var a_button := InputEventJoypadButton.new()
	a_button.button_index = JOY_BUTTON_A
	a_button.pressed = true
	_check(a_button.is_action("ui_accept"), "A is ui_accept, so it presses the focused button")
	_check(InputMap.action_has_event("ui_accept", _key(KEY_ENTER)) and InputMap.action_has_event("ui_cancel", _key(KEY_ESCAPE)), "Enter and Esc still work")
	menu.choose_time("night")
	menu.choose_weather("snow")
	_check(tod.current == "night" and weather.current == "snow", "the menu picks the time and weather directly: %s %s" % [tod.current, weather.current])
	_check((menu._time_buttons["night"] as Button).button_pressed and not (menu._time_buttons["day"] as Button).button_pressed, "the current time is marked")
	_check((menu._weather_buttons["snow"] as Button).button_pressed, "the current weather is marked")
	# Rainbow by day only, aurora at dusk / night only.
	_check(not Weather.allowed_at("rainbow", "night") and not Weather.allowed_at("rainbow", "dusk"), "no rainbow at dusk or night")
	for t in ["dawn", "sunrise", "day", "sunset"]:
		_check(Weather.allowed_at("rainbow", t) and not Weather.allowed_at("aurora", t), "rainbow but no aurora at %s" % t)
	_check(Weather.allowed_at("aurora", "dusk") and Weather.allowed_at("aurora", "night"), "aurora at dusk and night")
	_check(Weather.allowed_at("snow", "day") and Weather.allowed_at("snow", "night"), "ordinary weather at any time")
	_check(_dim(menu, "rainbow") and not _dim(menu, "aurora"), "at night the rainbow is dimmed, the aurora is not")
	menu.choose_weather("rainbow")
	_check(weather.current == "snow", "a rainbow can't be picked at night: %s" % weather.current)
	_check(menu._hint.text == Weather.restriction_text("rainbow") and menu._hint.text.contains("dawn"), "clicking the dimmed rainbow says when it appears: '%s'" % menu._hint.text)
	menu.choose_weather("aurora")
	_check(menu._hint.text == "", "the hint clears after a real pick")
	_check(menu.TIME_ORDER == ["dawn", "sunrise", "day", "sunset", "dusk", "night"], "times run dawn to night")
	var grouped := ["clear"]  # Clear sits on its own, top centre, above the columns
	for group in menu.WEATHER_GROUPS:
		grouped.append_array(group[1])
	grouped.sort()
	var all_weather: Array = weather.ORDER.duplicate()
	all_weather.sort()
	_check(grouped == all_weather, "every weather is in exactly one column")
	for key in weather.ORDER:
		_check(menu.WEATHER_COLORS.has(key), "a gradient for weather '%s'" % key)
	var times_sorted: Array = menu.TIME_ORDER.duplicate()
	times_sorted.sort()
	var tod_sorted: Array = tod.ORDER.duplicate()
	tod_sorted.sort()
	_check(times_sorted == tod_sorted, "the menu lists every time of day once")
	_check(weather.current == "aurora", "the aurora can be picked at night")
	menu.choose_weather("aurora")
	_check(weather.current == "clear", "picking the aurora again turns it off: %s" % weather.current)
	menu.choose_weather("aurora")
	menu.choose_time("day")
	_check(weather.current == "clear", "moving to day drops the aurora: %s" % weather.current)
	_check(_dim(menu, "aurora") and not _dim(menu, "rainbow"), "by day the aurora is dimmed, the rainbow is not")
	menu.choose_weather("rainbow")
	_check(weather.current == "rainbow", "the rainbow can be picked by day")
	menu.choose_time("sunset")
	_check(weather.current == "rainbow", "the rainbow stays through sunset")
	menu.choose_time("dusk")
	_check(weather.current == "clear", "dusk drops the rainbow: %s" % weather.current)
	# A special left on at the wrong time (R, the clock) can still be switched off.
	weather.set_weather("rainbow", true)
	menu.refresh()
	_check(not _dim(menu, "rainbow"), "an active special is never dimmed")
	menu.choose_weather("rainbow")
	_check(weather.current == "clear", "it can be switched off: %s" % weather.current)
	menu.choose_time("night")
	menu.choose_weather("snow")
	menu.toggle_clock()
	_check(tod.clock_running, "the menu starts the clock")
	menu.toggle_clock()
	menu.toggle_names()
	_check(not tod.show_constellations, "the menu turns constellation lines and names off")
	menu.toggle_names()
	menu.set_open(false)
	_check(not menu.is_open() and not paused, "closing the menu resumes the game")
	for key in tod.ORDER:
		_check(menu._time_buttons.has(key), "a button for time '%s'" % key)
	for key in weather.ORDER:
		_check(menu._weather_buttons.has(key), "a button for weather '%s'" % key)

	var minimap: Node = main.get_node("Minimap/Root")
	var icon: Button = minimap.sky_button
	_check(icon != null and icon.mouse_filter == Control.MOUSE_FILTER_STOP, "the minimap's sky icon takes clicks")
	icon.pressed.emit()
	_check(menu.is_open(), "the sky icon opens the menu")
	menu.set_open(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu.set_open(true)
	menu.set_open(false)
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "closing the menu leaves a freed mouse free")
	paused = true
	menu.set_open(true)
	_check(not menu.is_open(), "the menu won't open over something else that paused the game")
	paused = false
	_check(minimap != null, "minimap present")

	# Name labels: hidden by day, shown on a clear night with a constellation in view.
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.make_current()
	cam.global_position = Vector3(232, 1.7, -48)
	tod.set_preset("day", true)
	await process_frame
	await process_frame
	_check(_visible_names(tod) == 0, "no constellation names by day")
	tod.set_preset("night", true)
	weather.set_weather("clear", true)
	var lst := SkyMath.sidereal_degrees(tod._sky_days, tod.sky_hour)
	cam.look_at(cam.global_position + CN.direction(1, lst) * 100.0, Vector3.UP)
	await process_frame
	await process_frame
	_check(_visible_names(tod) >= 1, "names show at night with a constellation in view: %s" % _visible_names(tod))
	tod.set_show_constellations(false)
	await process_frame
	_check(_visible_names(tod) == 0, "N hides the names with the lines")
	# The menu's button owns both, even though the paused game isn't running _process.
	menu.set_open(true)
	menu.toggle_names()
	_check(tod.show_constellations and _visible_names(tod) >= 1, "the menu button brings the names back while paused")
	menu.toggle_names()
	_check(not tod.show_constellations and _visible_names(tod) == 0, "the menu button hides the names while paused")
	menu.toggle_names()
	# Dusk: lines yes, names no.
	menu.choose_time("dusk")
	_check(_visible_names(tod) == 0, "no names at dusk")
	menu.choose_time("night")
	# Moon and shooting stars.
	var mat: ShaderMaterial = tod._sky_material
	var star_before: float = mat.get_shader_parameter("star_strength")
	_check(menu._names_button.text.begins_with("Constellations") and menu._moon_button.text.begins_with("Moon") and menu._meteor_button.text.begins_with("Shooting stars"), "the night sky buttons all have labels")
	menu.toggle_moon()
	_check(menu._moon_button.text.ends_with("never"), "the Moon button says when it is off")
	_check(not tod.moon_enabled and mat.get_shader_parameter("star_strength") > star_before - 0.0001, "the menu turns the moon off")
	_check(is_zero_approx(mat.get_shader_parameter("body_strength")), "no moon disc with the moon off")
	menu.toggle_moon()
	menu.cycle_meteors()
	_check(tod.meteor_level == 2 and mat.get_shader_parameter("meteor_period") < 5.0, "a shooting star shower is more frequent")
	menu.cycle_meteors()
	_check(tod.meteor_level == 0 and is_zero_approx(mat.get_shader_parameter("meteor_strength")), "shooting stars can be turned off")
	menu.cycle_meteors()
	_check(tod.meteor_level == 1, "and back to some")
	# Typing "starlink" with the menu open sends a train, but only on a dark sky.
	menu.choose_time("day")
	_type(menu, "starlink")
	_check(not tod.is_starlink_running() and menu.is_open() and menu._hint.text != "", "no Starlink train by day, and the menu says why")
	menu.choose_time("night")
	_type(menu, "starli")
	menu.set_open(false)
	menu.set_open(true)
	_type(menu, "nk")
	_check(not tod.is_starlink_running(), "a half-typed code does not carry over to the next visit")
	_type(menu, "starlnk")
	_check(not tod.is_starlink_running(), "a typo does not start it")
	_type(menu, "starlink")
	_check(tod.is_starlink_running() and not menu.is_open(), "typing starlink at night closes the menu and starts a train")
	_check(mat.get_shader_parameter("train_time") >= 0.0, "the sky shader is told")
	tod._train_time = TimeOfDay.STARLINK_SECONDS - 0.01
	tod._process(0.1)
	_check(not tod.is_starlink_running(), "the train ends")
	weather.set_weather("thunderstorm", true)
	_check(not tod.start_starlink(), "no Starlink train under storm cloud")
	main.queue_free()
	await process_frame

func _type(menu: Node, text: String) -> void:
	for letter in text:
		var e := InputEventKey.new()
		e.keycode = OS.find_keycode_from_string(letter)
		e.pressed = true
		menu._input(e)

func _dim(menu: Node, key: String) -> bool:
	return (menu._weather_buttons[key] as Button).modulate.a < 1.0

func _visible_names(tod: Node) -> int:
	var n := 0
	for l in tod._name_labels:
		if l.visible:
			n += 1
	return n
