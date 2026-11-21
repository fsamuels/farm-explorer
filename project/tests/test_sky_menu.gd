extends SceneTree
## Tests for the sky menu (D-110), the constellation name labels and the new
## start position and default view. Run headless from project/:
##   godot --headless -s res://tests/test_sky_menu.gd

const CN := preload("res://scripts/constellation_names.gd")
const SkyMath := preload("res://scripts/sky_math.gd")
const Weather := preload("res://scripts/weather.gd")

var _failures := 0

func _init() -> void:
	_run.call_deferred()

func _check(cond: bool, what: String) -> void:
	if not cond:
		_failures += 1
		push_error("FAIL: " + what)

func _run() -> void:
	_test_names()
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
	var grouped := []
	for group in menu.WEATHER_GROUPS:
		grouped.append_array(group[1])
	grouped.sort()
	var all_weather: Array = weather.ORDER.duplicate()
	all_weather.sort()
	_check(grouped == all_weather, "every weather is in exactly one column")
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
	main.queue_free()
	await process_frame

func _dim(menu: Node, key: String) -> bool:
	return (menu._weather_buttons[key] as Button).modulate.a < 1.0

func _visible_names(tod: Node) -> int:
	var n := 0
	for l in tod._name_labels:
		if l.visible:
			n += 1
	return n
