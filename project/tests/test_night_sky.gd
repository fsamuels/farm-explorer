extends SceneTree
## Tests for the night sky (D-101): the sky maths (scripts/sky_math.gd), the
## catalogue data and its baked star / line maps (scripts/star_data.gd,
## star_map.gd), and that main.tscn's TimeOfDay node puts the sky shader in the
## environment, fades the stars with the lighting and weather, turns the sky
## with the clock and toggles the constellation lines on N. Run headless from
## project/ (after the editor has imported assets once):
##   godot --headless -s res://tests/test_night_sky.gd

const SkyMath := preload("res://scripts/sky_math.gd")
const StarMap := preload("res://scripts/star_map.gd")
const StarData := preload("res://scripts/star_data.gd")
const TimeOfDay := preload("res://scripts/time_of_day.gd")

var _failures := 0

func _init() -> void:
	_run.call_deferred()

func _check(cond: bool, what: String) -> void:
	if not cond:
		_failures += 1
		push_error("FAIL: " + what)

func _run() -> void:
	_test_sky_math()
	_test_star_look()
	_test_data()
	_test_bake()
	_test_presets()
	await _test_scene()
	print("night_sky: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures else 0)

func _test_sky_math() -> void:
	_check((load("res://scripts/sky_math.gd") as GDScript).can_instantiate(), "sky_math.gd compiles")
	_check(is_zero_approx(SkyMath.days_since_j2000(2000, 1, 1)), "J2000 noon is day 0")
	_check(is_equal_approx(SkyMath.days_since_j2000(2000, 1, 2), 1.0), "a day later is day 1")
	var d := SkyMath.days_since_j2000(2026, 11, 21)
	_check(is_equal_approx(SkyMath.sidereal_degrees(d, 13.0) - SkyMath.sidereal_degrees(d, 12.0), 15.0) or is_equal_approx(SkyMath.sidereal_degrees(d, 12.0) - SkyMath.sidereal_degrees(d, 13.0), 345.0), "the sky turns 15 degrees an hour")
	_check(SkyMath.sidereal_degrees(d, 5.0) >= 0.0 and SkyMath.sidereal_degrees(d, 5.0) < 360.0, "sidereal time wraps into 0..360")
	# On 21 Nov the mean sun is near RA 15h40m (~235 deg), so at noon that's on the meridian.
	_check(absf(SkyMath.sidereal_degrees(d, 12.0) - 238.0) < 6.0, "noon sidereal time matches the sun's RA: %s" % SkyMath.sidereal_degrees(d, 12.0))
	var b := SkyMath.celestial_to_world(SkyMath.LATITUDE, 123.0)
	_check(b.is_equal_approx(b.orthonormalized()) and is_equal_approx(b.determinant(), 1.0), "the celestial rotation is a proper rotation")
	# The celestial pole is as high as the latitude, due north (-z).
	var pole := b * Vector3(0, 0, 1)
	_check(is_equal_approx(rad_to_deg(asin(pole.y)), SkyMath.LATITUDE) and pole.z < 0.0 and is_zero_approx(pole.x), "the pole sits at the latitude, due north: %s" % pole)
	_check(is_equal_approx(SkyMath.altitude_degrees(10.0, 90.0, SkyMath.LATITUDE, 77.0), SkyMath.LATITUDE), "Polaris-like star stays at latitude altitude")
	# A star on the meridian (RA = sidereal time) peaks at 90 - |lat - dec|.
	_check(is_equal_approx(SkyMath.altitude_degrees(100.0, 20.0, SkyMath.LATITUDE, 100.0), 90.0 - (SkyMath.LATITUDE - 20.0)), "meridian altitude")
	var on_meridian := b.inverse() * Vector3.UP  # the zenith in celestial axes
	var zenith_star := SkyMath.celestial_to_world(SkyMath.LATITUDE, 123.0) * on_meridian
	_check(zenith_star.is_equal_approx(Vector3.UP), "zenith round-trips")
	# Six hours past the meridian a star is in the west (-x) and has set lower;
	# six hours before it, it is in the east (+x).
	var west := SkyMath.celestial_to_world(SkyMath.LATITUDE, 100.0 + 90.0) * SkyMath.radec_to_vector(100.0, 0.0)
	var east := SkyMath.celestial_to_world(SkyMath.LATITUDE, 100.0 - 90.0) * SkyMath.radec_to_vector(100.0, 0.0)
	_check(west.x < -0.9 and east.x > 0.9, "stars rise in the east and set in the west: %s %s" % [east, west])
	var p := SkyMath.map_pixel(Vector3(1, 0, 0), 4096, 2048)
	_check(p.is_equal_approx(Vector2(2048, 1024)), "RA 0, Dec 0 is the map centre")
	_check(is_zero_approx(SkyMath.map_pixel(Vector3(0, 0, 1), 4096, 2048).y), "the north pole is the top row")

func _test_star_look() -> void:
	var hot := SkyMath.star_color(20000.0)
	var cool := SkyMath.star_color(3500.0)
	_check(hot.b > hot.r and cool.r > cool.b, "hot stars look blue, cool ones orange")
	_check(SkyMath.star_color(5800.0).get_luminance() > 0.6, "colours stay bright")
	_check(SkyMath.star_level(-1.46) > 0.99 and SkyMath.star_level(9.0) == 0.0, "level clamps")
	_check(SkyMath.star_peak(-1.0) > SkyMath.star_peak(2.0) and SkyMath.star_peak(2.0) > SkyMath.star_peak(5.0), "brighter stars have higher peaks")
	_check(SkyMath.star_peak(-5.0) <= 1.0 and SkyMath.star_peak(8.0) > 0.0, "peak stays in range")
	_check(SkyMath.star_sigma(0.0) > SkyMath.star_sigma(5.0), "brighter stars are bigger")

func _test_data() -> void:
	_check((load("res://scripts/star_data.gd") as GDScript).can_instantiate(), "star_data.gd compiles")
	_check(StarData.STARS.size() % 4 == 0 and StarData.STARS.size() >= 4 * 1000, "a thousand-plus stars: %d" % (StarData.STARS.size() / 4))
	_check(StarData.LINES.size() % 4 == 0 and StarData.LINES.size() >= 4 * 30, "constellation line segments: %d" % (StarData.LINES.size() / 4))
	var brightest := 99.0
	var faintest := -99.0
	var polaris := false
	for i in range(0, StarData.STARS.size(), 4):
		var ra := StarData.STARS[i]
		var dec := StarData.STARS[i + 1]
		_check(ra >= 0.0 and ra < 360.0 and dec >= -90.0 and dec <= 90.0, "star %d has valid coordinates" % (i / 4))
		brightest = minf(brightest, StarData.STARS[i + 2])
		faintest = maxf(faintest, StarData.STARS[i + 2])
		if dec > 89.0 and StarData.STARS[i + 2] < 2.5:
			polaris = true
	_check(is_equal_approx(brightest, -1.46), "Sirius is the brightest: %s" % brightest)
	_check(faintest <= 5.0, "nothing fainter than the cutoff: %s" % faintest)
	_check(polaris, "Polaris is in the catalogue")

func _test_bake() -> void:
	var w := 1024
	var h := 512
	var img := StarMap.bake_stars(w, h)
	_check(img.get_width() == w and img.get_height() == h, "star map size")
	# Sirius sits at its map pixel, at full brightness.
	var sirius := Vector2.ZERO
	for i in range(0, StarData.STARS.size(), 4):
		if is_equal_approx(StarData.STARS[i + 2], -1.46):
			sirius = SkyMath.map_pixel(SkyMath.radec_to_vector(StarData.STARS[i], StarData.STARS[i + 1]), w, h)
	var px := img.get_pixel(int(sirius.x), int(sirius.y))
	_check(px.get_luminance() > 0.6, "Sirius is drawn bright: %s" % px)
	# Most of the sky is dark.
	var lit := 0
	for y in range(0, h, 2):
		for x in range(0, w, 2):
			if img.get_pixel(x, y).get_luminance() > 0.05:
				lit += 1
	var frac := float(lit) / (w * h / 4.0)
	_check(frac > 0.002 and frac < 0.15, "stars cover a small part of the sky: %s" % frac)
	# Near a pole a star is stretched along its row, so it stays round on the sky.
	var polaris_row := -1
	for i in range(0, StarData.STARS.size(), 4):
		if StarData.STARS[i + 1] > 89.0 and StarData.STARS[i + 2] < 2.5:
			polaris_row = int(SkyMath.map_pixel(SkyMath.radec_to_vector(StarData.STARS[i], StarData.STARS[i + 1]), w, h).y)
	var row_lit := 0
	for x in w:
		if img.get_pixel(x, polaris_row).get_luminance() > 0.05:
			row_lit += 1
	_check(row_lit > 40, "Polaris is stretched across its row on the map: %d px" % row_lit)
	var lines := StarMap.bake_lines(w, h)
	_check(lines.get_format() == Image.FORMAT_L8, "line map is one channel")
	var a := SkyMath.radec_to_vector(StarData.LINES[0], StarData.LINES[1])
	var b := SkyMath.radec_to_vector(StarData.LINES[2], StarData.LINES[3])
	var mid := SkyMath.map_pixel(a.slerp(b, 0.5), w, h)
	var best := 0.0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			best = maxf(best, lines.get_pixel(posmod(int(mid.x) + dx, w), clampi(int(mid.y) + dy, 0, h - 1)).r)
	_check(best > 0.4, "the middle of a constellation line is drawn: %s" % best)
	_check(lines.get_pixel(0, 0).r == 0.0, "no line in an empty corner")

func _test_presets() -> void:
	_check(TimeOfDay.PRESETS.day.stars == 0.0 and TimeOfDay.PRESETS.sunset.stars == 0.0 and TimeOfDay.PRESETS.sunrise.stars == 0.0, "no stars in daylight")
	_check(TimeOfDay.PRESETS.night.stars == 1.0, "full stars at night")
	_check(TimeOfDay.PRESETS.dusk.stars > 0.0 and TimeOfDay.PRESETS.dusk.stars < 1.0 and TimeOfDay.PRESETS.dawn.stars > 0.0 and TimeOfDay.PRESETS.dawn.stars < 1.0, "some stars at dusk and dawn")
	var night := TimeOfDay.PRESETS.night
	_check(TimeOfDay.overcast_preset(night, 0.0).stars == 1.0, "clear sky keeps its stars")
	_check(TimeOfDay.overcast_preset(night, 1.0).stars == 0.0, "full cloud hides the stars")
	_check(TimeOfDay.overcast_preset(night, 0.5).stars < 0.5, "half cloud hides more than half of them: %s" % TimeOfDay.overcast_preset(night, 0.5).stars)
	_check(TimeOfDay.overcast_preset(night, 0.0, 0.045).stars == 0.0, "heavy fog hides the stars")
	var light: float = TimeOfDay.overcast_preset(night, 0.0, 0.012).stars
	_check(light > 0.0 and light < 1.0, "light fog dims them: %s" % light)
	_check(TimeOfDay.blend(TimeOfDay.PRESETS.dusk, night, 0.5).stars > TimeOfDay.PRESETS.dusk.stars, "stars fade in through the blend")

func _test_scene() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	var tod = main.get_node("TimeOfDay")
	var env: Environment = main.get_node("WorldEnvironment").environment
	_check(env.background_mode == Environment.BG_SKY and env.sky != null, "the environment uses the sky shader")
	_check(env.sky.sky_material is ShaderMaterial, "the sky has a shader material")
	var mat: ShaderMaterial = env.sky.sky_material
	_check(mat.get_shader_parameter("star_map") is Texture2D and mat.get_shader_parameter("line_map") is Texture2D, "star and line maps are baked")
	_check(env.fog_sky_affect == 0.0, "fog leaves the sky alone")
	_check(is_zero_approx(mat.get_shader_parameter("star_strength")), "no stars by day")
	_check(mat.get_shader_parameter("sky_color").is_equal_approx(Color(0.55, 0.75, 0.95)), "the day sky colour is passed to the shader")
	tod.set_preset("night", true)
	_check(is_equal_approx(mat.get_shader_parameter("star_strength"), 1.0), "full stars at night")
	_check(env.background_color.v < 0.2, "the flat background colour still follows the lighting")
	# Clouds hide the stars.
	tod.set_overcast(1.0)
	_check(is_zero_approx(mat.get_shader_parameter("star_strength")), "overcast hides the stars")
	tod.set_overcast(0.0)
	_check(is_equal_approx(mat.get_shader_parameter("star_strength"), 1.0), "clear sky brings them back")
	# The sky turns with the clock.
	tod.hour = 23.0
	tod.sky_hour = 23.0
	tod._apply(TimeOfDay.preset_at_hour(23.0))
	var h23: Basis = mat.get_shader_parameter("sky_to_celestial")
	tod.sky_hour = 24.0
	tod._apply(TimeOfDay.preset_at_hour(24.0))
	var h24: Basis = mat.get_shader_parameter("sky_to_celestial")
	var turn := (h23 * h24.inverse()).get_euler().length()
	_check(not h23.is_equal_approx(h24) and rad_to_deg(turn) > 14.0 and rad_to_deg(turn) < 16.0, "an hour turns the sky about 15 degrees: %s" % rad_to_deg(turn))
	# T turns the sky forward through the blend, not backwards.
	tod.transition_seconds = 0.05
	tod.set_preset("day", true)
	tod.set_preset("night", false)
	await create_timer(0.3).timeout
	_check(is_equal_approx(tod.sky_hour, 23.0), "a preset change ends with the sky at the preset's hour: %s" % tod.sky_hour)
	# N toggles the constellation lines.
	_check(mat.get_shader_parameter("line_strength") > 0.0 and tod.show_constellations, "lines start on")
	_press(KEY_N)
	await process_frame
	_check(not tod.show_constellations and is_zero_approx(mat.get_shader_parameter("line_strength")), "N hides the lines")
	paused = true
	_press(KEY_N)
	await process_frame
	_check(not tod.show_constellations, "N is ignored while the map has the game paused")
	paused = false
	_press(KEY_N)
	await process_frame
	_check(tod.show_constellations and mat.get_shader_parameter("line_strength") > 0.0, "N shows them again")
	main.queue_free()

func _press(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
