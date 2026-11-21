extends SceneTree
## Tests for scripts/weather.gd (D-95, D-99) and its overcast, fog and flash
## hooks in time_of_day.gd: the pure helpers, and that main.tscn's Weather node
## steps through the weathers on R, clouds the sky over through TimeOfDay,
## thickens fog, flashes lightning in a thunderstorm, and leaves time of day
## working underneath. Run headless from project/ (after the editor has imported assets
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
	_test_rainbow()
	_test_lightning()
	_test_fog_and_flash_presets()
	await _test_scene()
	print("weather: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures else 0)

func _test_next_weather() -> void:
	_check((load("res://scripts/weather.gd") as GDScript).can_instantiate(), "weather.gd compiles")
	var seen := ["clear"]
	var w := "clear"
	for i in Weather.ORDER.size() - 1:
		w = Weather.next_weather(w)
		_check(not seen.has(w), "%s appears once in the cycle" % w)
		seen.append(w)
	_check(Weather.next_weather(Weather.ORDER[-1]) == "clear", "the last weather wraps to clear")
	_check(Weather.next_weather("clear") == "drizzle" and Weather.next_weather("drizzle") == "rain", "clear -> drizzle -> rain")
	_check(Weather.next_weather("hail") == "clear", "unknown restarts at clear")
	_check(Weather.WEATHER.size() == Weather.ORDER.size(), "every weather in ORDER has an entry")
	for name in Weather.ORDER:
		var look: Dictionary = Weather.WEATHER[name]
		_check(look.has("label") and look.has("overcast") and look.has("fog") and look.has("precip"), "%s has the basic fields" % name)
		if look.precip == "rain":
			_check(look.drops > 0 and look.drops <= Weather.RAIN_MAX_DROPS, "%s drop count fits the emitter" % name)
			_check(look.has("width") and look.has("length") and look.has("slant") and look.speed.x <= look.speed.y, "%s has rain settings" % name)
	var order_drops := []
	for name in ["drizzle", "rain", "downpour"]:
		order_drops.append(Weather.WEATHER[name].drops)
	_check(order_drops[0] < order_drops[1] and order_drops[1] < order_drops[2], "drizzle < rain < downpour")
	_check(Weather.WEATHER.heavy_fog.fog > Weather.WEATHER.light_fog.fog and Weather.WEATHER.light_fog.fog > 0.0, "heavy fog is thicker than light fog")
	_check(Weather.WEATHER.thunderstorm.get("lightning", false) and not Weather.WEATHER.downpour.get("lightning", false), "only thunderstorms have lightning")

func _test_rainbow() -> void:
	_check(Weather.WEATHER.rainbow.get("rainbow", false) and Weather.WEATHER.rainbow.precip == "", "rainbow is dry and flagged")
	_check(Weather.next_weather("snow") == "rainbow" and Weather.next_weather("rainbow") == "clear", "snow -> rainbow -> clear")
	var south := Weather.arch_point(90.0, 0.0)
	var top := Weather.arch_point(90.0, 0.5)
	var north := Weather.arch_point(90.0, 1.0)
	_check(south.y < 0.001 and north.y < 0.001, "both feet are on the ground")
	_check(is_equal_approx(top.y, 90.0) and absf(top.z) < 0.001, "the top is one radius high, midway")
	_check(south.z > 89.9 and north.z < -89.9 and south.x == 0.0, "feet are south and north in a single plane")
	var mesh := Weather.build_rainbow_mesh(90.0, 3.0, 8)
	var arrays := mesh.surface_get_arrays(0)
	var bands := Weather.RAINBOW_COLORS.size()
	_check(arrays[Mesh.ARRAY_VERTEX].size() == bands * 9 * 2, "two vertices per step per band: %s" % arrays[Mesh.ARRAY_VERTEX].size())
	_check(arrays[Mesh.ARRAY_INDEX].size() == bands * 8 * 6, "two triangles per step per band")
	var inner_edge: float = Weather.RAINBOW_RADIUS - bands * Weather.RAINBOW_BAND_WIDTH
	_check(inner_edge > 0.0, "the innermost band stays outside the centre")
	var top_i := 4 * 2  # outer vertex of band 0 at the top
	_check(is_equal_approx(arrays[Mesh.ARRAY_VERTEX][top_i].y, 90.0), "the outer band's top is at the radius")
	_check(arrays[Mesh.ARRAY_COLOR][0].a < 0.001 and absf(arrays[Mesh.ARRAY_COLOR][top_i].a - Weather.RAINBOW_BAND_ALPHA[0]) < 0.01, "feet fade out, the top is at the band opacity")
	var at := Weather.rainbow_position(Vector3(10, 2, -30))
	_check(is_equal_approx(at.x, 10.0 + Weather.RAINBOW_DISTANCE) and at.y == 0.0 and is_equal_approx(at.z, -30.0), "the rainbow stands due east of the camera")
	_check(Weather.RAINBOW_ALPHA <= 0.3, "the rainbow is faint")
	_check(Weather.RAINBOW_BAND_ALPHA.size() == bands, "one opacity per band")
	var mid_top_i := 2 * 18 + 8  # band 2 (yellow), at the top
	_check(arrays[Mesh.ARRAY_COLOR][top_i].a < arrays[Mesh.ARRAY_COLOR][mid_top_i].a, "outer bands are fainter than the middle")

func _test_lightning() -> void:
	_check(is_equal_approx(Weather.lightning_delay(0.0), Weather.LIGHTNING_MIN), "shortest wait")
	_check(is_equal_approx(Weather.lightning_delay(1.0), Weather.LIGHTNING_MAX), "longest wait")
	_check(Weather.lightning_delay(-5.0) == Weather.LIGHTNING_MIN and Weather.lightning_delay(9.0) == Weather.LIGHTNING_MAX, "wait is clamped")
	_check(Weather.flash_level(-0.1) == 0.0 and Weather.flash_level(0.0) == 0.0, "no flash before the strike")
	_check(is_equal_approx(Weather.flash_level(0.05), 1.0), "flash peaks at full")
	_check(Weather.flash_level(0.12) < 0.3 and Weather.flash_level(0.17) > 0.7, "dip then second flicker")
	_check(Weather.flash_level(Weather.FLASH_SECONDS) == 0.0 and Weather.flash_level(5.0) == 0.0, "flash ends")
	for i in 61:
		var level := Weather.flash_level(i * 0.01)
		_check(level >= 0.0 and level <= 1.0, "flash stays within 0..1 at %s: %s" % [i * 0.01, level])

func _test_fog_and_flash_presets() -> void:
	for name in TimeOfDay.ORDER:
		var p: Dictionary = TimeOfDay.PRESETS[name]
		_check(TimeOfDay.overcast_preset(p, 0.0, 0.0, 0.0) == p, "%s: no weather leaves it alone" % name)
		var fog := TimeOfDay.overcast_preset(p, 0.0, 0.045)
		_check(is_equal_approx(fog.fog_density, p.fog_density + 0.045), "%s: extra fog adds density" % name)
		_check(fog.sky_color.is_equal_approx(fog.fog_color), "%s: heavy fog turns the sky to the fog colour" % name)
		_check(fog.sun_energy == p.sun_energy, "%s: fog alone doesn't dim the sun" % name)
		var heavy := TimeOfDay.overcast_preset(p, 0.5, 0.045)
		_check(heavy.fog_density > TimeOfDay.overcast_preset(p, 0.5).fog_density, "%s: fog stacks on cloud cover" % name)
		var flash := TimeOfDay.overcast_preset(p, 1.0, 0.0, 1.0)
		_check(flash.ambient_energy > p.ambient_energy, "%s: a flash brightens the ambient light" % name)
		_check(flash.sky_color.v > TimeOfDay.overcast_preset(p, 1.0).sky_color.v - 0.001, "%s: a flash lightens the sky" % name)
		_check(flash.keys() == p.keys(), "%s: same keys with fog and flash" % name)

func _test_overcast_preset() -> void:
	for name in TimeOfDay.ORDER:
		var p: Dictionary = TimeOfDay.PRESETS[name]
		_check(TimeOfDay.overcast_preset(p, 0.0) == p, "%s: no overcast leaves it alone" % name)
		var o := TimeOfDay.overcast_preset(p, 1.0)
		_check(o.sun_energy < p.sun_energy, "%s: overcast dims the sun" % name)
		_check(o.fog_density > p.fog_density, "%s: overcast thickens fog" % name)
		_check(o.sky_color.s < p.sky_color.s + 0.001, "%s: overcast greys the sky" % name)
		_check(o.keys() == p.keys(), "%s: same keys" % name)
		_check(not TimeOfDay.overcast_preset(p, 0.0).is_read_only(), "%s: result is always a writable copy" % name)

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
	# A script that fails to compile still loads as a bare node, and every
	# check below would then be skipped or fail confusingly; stop early.
	if not weather.has_method("set_weather"):
		_check(false, "weather.gd compiled and is attached")
		return
	var tod = main.get_node("TimeOfDay")
	var sun: DirectionalLight3D = main.get_node("DirectionalLight3D")
	var env: Environment = main.get_node("WorldEnvironment").environment
	var rain: GPUParticles3D = weather.get_node("Rain")
	var snow: GPUParticles3D = weather.get_node("Snow")

	_check(weather.current == "clear" and not rain.emitting and not snow.emitting, "starts clear")
	_check(is_equal_approx(tod.overcast, 0.0) and is_equal_approx(sun.light_energy, 1.0), "clear leaves the sun alone")

	weather.transition_seconds = 0.05
	_press(KEY_R)
	await process_frame
	_check(weather.current == "drizzle" and rain.emitting and not snow.emitting, "R starts drizzle")
	await create_timer(0.2).timeout
	_check(is_equal_approx(tod.overcast, 0.55), "drizzle half-clouds the sky: %s" % tod.overcast)
	_check(rain.amount_ratio < 0.25, "drizzle is light: %s" % rain.amount_ratio)
	_press(KEY_R)
	await process_frame
	await create_timer(0.2).timeout
	_check(weather.current == "rain" and rain.emitting, "R again is rain")
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

	_check(is_equal_approx(rain.amount_ratio, 9000.0 / Weather.RAIN_MAX_DROPS), "rain shows 9000 drops")
	weather.set_weather("downpour", true)
	_check(rain.emitting and rain.amount_ratio > 0.99 and (rain.draw_pass_1 as QuadMesh).size.y > 0.7, "downpour is the heaviest, longest-streaked rain")
	weather.set_weather("thunderstorm", true)
	_check(rain.emitting and tod.flash == 0.0, "thunderstorm starts with no flash")
	# Step the lightning by hand: real frame times vary, and a long first
	# frame could run the whole flash between two awaits.
	weather._strike_in = 0.0
	weather._update_lightning(0.01)
	_check(weather._flash_t >= 0.0, "a strike starts when the timer runs out")
	weather._update_lightning(0.05)  # 0.05 s in: the peak
	_check(is_equal_approx(tod.flash, 1.0), "a thunderstorm strike flashes the sky: %s" % tod.flash)
	_check(env.ambient_light_energy > 2.0 and env.background_color.v > 0.8, "the flash brightens the ambient light and sky: %s" % env.ambient_light_energy)
	weather._update_lightning(Weather.FLASH_SECONDS)
	_check(tod.flash == 0.0 and weather._flash_t < 0.0, "the flash fades out: %s" % tod.flash)
	_check(weather._strike_in >= Weather.LIGHTNING_MIN, "the next strike is scheduled: %s" % weather._strike_in)
	weather._update_lightning(0.5)
	_check(weather._flash_t < 0.0 and tod.flash == 0.0, "no new strike until the timer runs out")
	weather.set_weather("downpour", true)
	weather._strike_in = 0.0
	weather._update_lightning(0.01)
	_check(weather._flash_t < 0.0 and tod.flash == 0.0, "downpour has no lightning")
	weather.set_weather("thunderstorm", true)
	weather.set_weather("heavy_fog", true)
	_check(not rain.emitting and tod.flash == 0.0, "fog has no rain and no lightning")
	_check(env.fog_enabled and env.fog_density > 0.04, "heavy fog thickens the fog: %s" % env.fog_density)
	var heavy_density: float = env.fog_density
	weather.set_weather("light_fog", true)
	_check(env.fog_density > 0.01 and env.fog_density < heavy_density, "light fog is thinner than heavy fog: %s" % env.fog_density)
	weather.set_weather("clear", true)
	_check(not env.fog_enabled and is_equal_approx(sun.light_energy, 1.0), "clear removes the fog and restores the sun")
	weather.set_weather("snow", true)
	weather.set_weather("rain", true)
	_check(rain.emitting and not snow.emitting, "snow -> rain switches the emitter")
	weather.set_weather("snow", true)
	_check(weather.current == "snow" and snow.emitting and not rain.emitting, "snow")
	var rainbow: MeshInstance3D = weather.get_node("Rainbow")
	_check(not rainbow.visible, "no rainbow in snow")
	paused = true
	_press(KEY_R)
	await process_frame
	_check(weather.current == "snow", "R is ignored while the map has the game paused")
	paused = false
	_press(KEY_R)
	await process_frame
	await create_timer(0.2).timeout
	_check(weather.current == "rainbow" and rainbow.visible and not snow.emitting and not rain.emitting, "R after snow shows the rainbow")
	var rainbow_mat := rainbow.material_override as StandardMaterial3D
	_check(rainbow_mat.albedo_color.a > 0.15, "the rainbow fades in: %s" % rainbow_mat.albedo_color.a)
	if cam:
		await process_frame
		_check(rainbow.global_position.distance_to(Weather.rainbow_position(cam.global_position)) < 0.01, "the rainbow follows the camera")
	_check(tod.overcast > 0.0 and tod.overcast < 0.5, "a rainbow sky is only lightly clouded: %s" % tod.overcast)
	tod.set_preset("night", true)
	_check(rainbow_mat.albedo_color.v < 0.5, "the rainbow is dimmed at night: %s" % rainbow_mat.albedo_color)
	tod.set_preset("day", true)
	_press(KEY_R)
	await process_frame
	await create_timer(0.2).timeout
	_check(weather.current == "clear" and not rainbow.visible, "R again clears and hides the rainbow")
	_check(not snow.emitting, "no snow after the rainbow")
	var snow_mat: StandardMaterial3D = snow.draw_pass_1.surface_get_material(0)
	_check(snow_mat.albedo_color.a < 0.01, "leftover snow fades out with the sky: %s" % snow_mat.albedo_color.a)
	_check(is_equal_approx(sun.light_energy, 1.0), "clearing restores the sun: %s" % sun.light_energy)
	weather.set_weather("Rain", true)
	_check(weather.current == "clear" and not rain.emitting, "unknown weather falls back to clear")
	weather.set_weather("snow", true)
	_check(snow.emitting and snow_mat.albedo_color.a > 0.5, "snow comes back visible after fading out")
	main.queue_free()

func _press(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
