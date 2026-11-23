extends SceneTree
## Tests for the distant terrain and wind turbines (D-133): the generated data
## matches the real geography around the farm, the maths that stretches and
## squeezes it behaves, the shader include agrees with it, and main.tscn's
## DistantTerrain node builds the land and turbines and follows the season,
## weather and time of day. Run headless from project/:
##   godot --headless -s res://tests/test_horizon.gd

const HorizonMath := preload("res://scripts/horizon_math.gd")
const HorizonData := preload("res://scripts/horizon_data.gd")
const DistantTerrain := preload("res://scripts/distant_terrain.gd")

var _failures := 0
var _heights: PackedFloat32Array

func _init() -> void:
	_run.call_deferred()

func _check(cond: bool, what: String) -> void:
	if not cond:
		_failures += 1
		push_error("FAIL: " + what)

func _run() -> void:
	_heights = HorizonMath.decode_heights(HorizonData.HEIGHTS_B64)
	_test_data()
	_test_geography()
	_test_turbine_data()
	_test_math()
	_test_shader_include()
	await _test_scene()
	print("horizon: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures else 0)

func _test_data() -> void:
	var rings: Array = HorizonData.RINGS
	_check(_heights.size() == rings.size() * HorizonData.COLUMNS, "the grid has RINGS x COLUMNS heights: %d" % _heights.size())
	_check(HorizonData.COLUMNS * HorizonData.BEARING_STEP == 360.0, "the columns go all the way round")
	for i in rings.size() - 1:
		_check(rings[i] < rings[i + 1], "rings get farther out (%d)" % i)
	_check(rings[-1] >= 75000.0, "the terrain reaches past the Blue Mountains: %s" % rings[-1])
	# The farm sits in the Walla Walla valley at about 150 m.
	_check(absf(HorizonData.OBSERVER_ELEVATION - 150.0) < 15.0, "the farm is at ~150 m: %s" % HorizonData.OBSERVER_ELEVATION)
	_check(_heights.size() > 0 and _heights[0] > 100.0 and _heights[0] < 250.0, "the nearest ring is valley floor: %s" % _heights[0])

## Highest real elevation (and its distance) along compass bearing `b` between r0 and r1.
func _highest(b: float, r0: float, r1: float) -> Vector2:
	var best := Vector2(-1.0, 0.0)
	var r := r0
	while r <= r1:
		var p := HorizonMath.polar_point(b, r)
		var e := HorizonMath.elevation_at(_heights, HorizonData.RINGS, HorizonData.COLUMNS, p.x, p.y)
		if e > best.x:
			best = Vector2(e, r)
		r += 500.0
	return best

## The angle (degrees) above level that the highest drawn point on bearing `b` makes from the farm.
func _drawn_angle(b: float) -> float:
	var best := -90.0
	var r := 1000.0
	while r <= 78000.0:
		var p := HorizonMath.polar_point(b, r)
		var e := HorizonMath.elevation_at(_heights, HorizonData.RINGS, HorizonData.COLUMNS, p.x, p.y)
		best = maxf(best, rad_to_deg(atan2(HorizonMath.scene_height(e, r) - 1.7, r)))
		r += 250.0
	return best

func _test_geography() -> void:
	# Blue Mountains: the crest east of the farm is 1,200-1,950 m, 33-70 km out.
	for b in [80.0, 95.0, 110.0, 125.0]:
		var top := _highest(b, 30000.0, 72000.0)
		_check(top.x > 1200.0 and top.x < 1950.0, "Blue Mountains crest on bearing %s is %d m" % [b, top.x])
		_check(top.y > 33000.0 and top.y < 70000.0, "and %d km away" % (top.y / 1000.0))
	# The wind-farm ridge west-south-west: 450-650 m, 9-23 km out.
	for b in [235.0, 250.0, 265.0]:
		var ridge := _highest(b, 8000.0, 24000.0)
		_check(ridge.x > 430.0 and ridge.x < 700.0, "the western ridge on bearing %s is %d m" % [b, ridge.x])
	# North is the flat Columbia Plateau: nothing over 450 m within 20 km.
	_check(_highest(0.0, 1000.0, 20000.0).x < 450.0, "it is flat to the north")
	# Drawn with the exaggeration, the Blues stand 3-6 degrees above level (about
	# 2.5x their real 1-1.7 degrees), higher than the nearer western ridge.
	var east := _drawn_angle(95.0)
	var west := _drawn_angle(250.0)
	_check(east > 3.0 and east < 6.0, "the Blues rise %.2f degrees above level" % east)
	_check(west > 0.8 and west < east, "the western ridge rises %.2f degrees, below the Blues" % west)

func _test_turbine_data() -> void:
	var list: Array = HorizonData.TURBINES
	_check(list.size() > 1000, "over a thousand turbines: %d" % list.size())
	var stateline: int = HorizonData.PROJECTS.find("Stateline Wind Project")
	_check(stateline != -1, "the Stateline Wind Project is there")
	var n := 0
	for t: Array in list:
		_check(t.size() == 5 and t[2] > 20.0 and t[3] > 20.0, "turbine rows hold x, z, hub, rotor, project")
		if t[4] == stateline:
			n += 1
			var b := HorizonMath.bearing(t[0], t[1])
			var r := Vector2(t[0], t[1]).length()
			if b < 225.0 or b > 275.0 or r < 9000.0 or r > 23500.0:
				_check(false, "Stateline turbine at bearing %.1f, %.1f km is off its ridge" % [b, r / 1000.0])
				break
	_check(n > 400, "Stateline has its ~450 turbines: %d" % n)

func _test_math() -> void:
	_check(is_equal_approx(HorizonMath.exaggeration(0.0), 1.0), "no exaggeration at the farm")
	_check(is_equal_approx(HorizonMath.exaggeration(1000000.0), HorizonMath.EXAGGERATION), "full exaggeration far out")
	var last := 0.0
	var d := 0.0
	while d < 200000.0:
		var c := HorizonMath.compressed_distance(d)
		_check(c >= last, "squeezed distance never goes backwards (at %s)" % d)
		last = c
		d += 731.0
	_check(is_equal_approx(HorizonMath.compressed_distance(1000.0), 1000.0), "nothing near is squeezed")
	_check(HorizonMath.compressed_distance(80000.0) < HorizonMath.SQUEEZE_MAX, "the far edge lands inside SQUEEZE_MAX")
	# Ridges 1 km apart at the Blues still get some depth between them.
	_check(HorizonMath.compressed_distance(51000.0) - HorizonMath.compressed_distance(50000.0) > 5.0, "far ridges keep their order in depth")
	# Squeezed geometry must sit inside the camera's far plane (Godot's default
	# 4 km; the player cameras don't change it), allowing for the player being
	# anywhere on the 520 m ground plane (at most ~385 m from the origin).
	var cam := Camera3D.new()
	_check(HorizonMath.SQUEEZE_MAX + 400.0 < cam.far, "squeezed terrain fits inside the far plane (%s)" % cam.far)
	cam.free()
	_check(is_equal_approx(HorizonMath.scene_height(HorizonData.OBSERVER_ELEVATION + 50.0, 200.0), HorizonMath.NEAR_Y), "near the farm the land lies flat under the ground plane")
	_check(HorizonMath.scene_height(1800.0, 50000.0) > 3500.0, "the Blues are stretched: %s" % HorizonMath.scene_height(1800.0, 50000.0))
	_check(absf(HorizonMath.bearing(1.0, 0.0) - 90.0) < 0.01 and absf(HorizonMath.bearing(0.0, 1.0) - 180.0) < 0.01, "bearings: +x east, +z south")
	var p := HorizonMath.polar_point(270.0, 100.0)
	_check(p.distance_to(Vector2(-100.0, 0.0)) < 0.01, "polar_point puts west at -x")
	# Grid read-back matches the grid exactly at a grid point.
	var i := 40
	var j := 180
	var gp := HorizonMath.polar_point(j * HorizonData.BEARING_STEP, HorizonData.RINGS[i])
	var e := HorizonMath.elevation_at(_heights, HorizonData.RINGS, HorizonData.COLUMNS, gp.x, gp.y)
	_check(absf(e - _heights[i * HorizonData.COLUMNS + j]) < 0.5, "elevation_at reads the grid back: %s" % e)
	# Rotor speed: Stateline's 47 m rotors near 28 rpm, big new ones slower.
	var rpm47 := HorizonMath.rotor_speed(47.0) * 60.0 / TAU
	_check(rpm47 > 25.0 and rpm47 < 31.0, "a 47 m rotor turns ~28 rpm: %s" % rpm47)
	_check(HorizonMath.rotor_speed(127.0) < HorizonMath.rotor_speed(47.0), "bigger rotors turn slower")
	# Spin speeds fit whole turns into TIME's rollover, so blades don't jump.
	for rd in [47.0, 80.0, 103.0, 127.0]:
		var raw := HorizonMath.rotor_speed(rd)
		var safe := HorizonMath.loop_safe_speed(raw, 3600.0)
		var turns := safe * 3600.0 / TAU
		_check(absf(turns - roundf(turns)) < 1e-3 and absf(safe - raw) / raw < 0.001, "%s m rotor: whole turns per rollover, speed barely changed" % rd)
	# Far nacelles stay within twice their true size (they used to outgrow their
	# towers at 55-78 km), and the warning light makes up the rest.
	for far in [15000.0, 55000.0, 78000.0]:
		var s := HorizonMath.exaggeration(far)
		var mw: float = far * DistantTerrain.MIN_WIDTH_PER_METRE
		var hs := HorizonMath.nacelle_scale(100.0, s, mw)
		_check(hs <= s * HorizonMath.NACELLE_MAX_STRETCH + 1e-4 and hs >= s - 1e-4, "nacelle at %d km is 1-2x true size: %s" % [far / 1000.0, hs])
		_check(is_equal_approx(hs * HorizonMath.beacon_boost(hs, mw), maxf(hs, mw / 4.0)), "the warning light still reaches the distance floor at %d km" % (far / 1000.0))
	# Haze: clear air leaves the Blues showing, light fog hides even the near ridge.
	var clear := HorizonMath.haze_per_metre(0.0, 0.0, 0.0, false)
	_check(HorizonMath.haze(50000.0, clear) < 0.65, "the Blues show through clear air")
	_check(HorizonMath.haze(13000.0, HorizonMath.haze_per_metre(0.3, 0.012, 0.0, false)) > 0.99, "light fog hides the western ridge")
	_check(HorizonMath.haze(50000.0, HorizonMath.haze_per_metre(0.0, 0.0, 1.0, false)) > 0.99, "heavy smoke hides the Blues")
	_check(HorizonMath.haze(15000.0, HorizonMath.haze_per_metre(0.0, 0.0, 0.5, false)) < 0.95, "smoke haze still lets the near ridge show faintly")
	_check(is_zero_approx(HorizonMath.darkness(Color(0.55, 0.75, 0.95))), "no warning lights by day")
	_check(is_equal_approx(HorizonMath.darkness(Color(0.03, 0.04, 0.09)), 1.0), "warning lights at night")

func _test_shader_include() -> void:
	var text := FileAccess.get_file_as_string("res://shaders/horizon.gdshaderinc")
	for pair in [["SQUEEZE_START", HorizonMath.SQUEEZE_START], ["SQUEEZE_RANGE", HorizonMath.SQUEEZE_RANGE], ["SQUEEZE_SCALE", HorizonMath.SQUEEZE_SCALE]]:
		var re := RegEx.create_from_string("const float %s = ([0-9.]+);" % pair[0])
		var m := re.search(text)
		_check(m != null and is_equal_approx(m.get_string(1).to_float(), pair[1]), "shader %s matches horizon_math.gd" % pair[0])

func _test_scene() -> void:
	var t0 := Time.get_ticks_msec()
	DistantTerrain.build_terrain_mesh(_heights)
	print("terrain mesh built in %d ms" % (Time.get_ticks_msec() - t0))
	var started := Time.get_ticks_msec()
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var ready_ms := Time.get_ticks_msec() - started
	await process_frame
	await process_frame
	var terrain: Node3D = main.get_node_or_null("DistantTerrain")
	_check(terrain != null, "main.tscn has a DistantTerrain node")
	if terrain == null:
		return
	print("main.tscn ready in %d ms (distant terrain included)" % ready_ms)
	var mesh: ArrayMesh = terrain.terrain.mesh
	var tris := mesh.surface_get_array_len(0) / 3
	_check(tris == (HorizonData.RINGS.size() - 1) * HorizonData.COLUMNS * 2, "terrain has one quad per grid cell: %d triangles" % tris)
	# Every facet is front-facing (clockwise) from above: normal up.
	var normals: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	var down := 0
	for k in range(0, normals.size(), 3):
		if normals[k].y <= 0.0:
			down += 1
	_check(down == 0, "no terrain facet faces down: %d" % down)
	for node: MultiMeshInstance3D in [terrain.towers, terrain.heads, terrain.rotors]:
		_check(node.multimesh.instance_count == HorizonData.TURBINES.size(), "%s has a turbine each" % node.name)
		_check(node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s casts no shadow" % node.name)
		_check(node.custom_aabb.size.length() > 1000.0, "%s is culled by where it is drawn" % node.name)
	# A Stateline turbine stands on the drawn ridge, at most a few metres in or above it.
	var t: Array = HorizonData.TURBINES[HorizonData.TURBINES.size() / 2]
	var base: Dictionary = DistantTerrain.turbine_base(terrain._heights, t)
	_check(base.scale >= 1.0 and base.scale <= HorizonMath.EXAGGERATION, "turbines scale with the land: %s" % base.scale)
	# (MultiMesh transforms read back as identity headless, so the placement
	# is checked through the pure function that produces them.)
	var tower: Transform3D = DistantTerrain.turbine_placement(terrain._heights, t, HorizonData.TURBINES.size() / 2, 3600.0).transforms[0]
	_check(tower.origin.y < base.position.y, "tower feet are sunk into the hill")
	# No turbine's nacelle (11 m long in its mesh) outgrows its tower.
	var too_big := 0
	for k in HorizonData.TURBINES.size():
		var placed := DistantTerrain.turbine_placement(terrain._heights, HorizonData.TURBINES[k], k, 3600.0)
		var tw: Transform3D = placed.transforms[0]
		var hd: Transform3D = placed.transforms[1]
		if 11.0 * hd.basis.get_scale().x > tw.basis.get_scale().y * 0.6:
			too_big += 1
	_check(too_big == 0, "nacelles stay small against their towers (%d too big)" % too_big)

	var tod: Node = main.get_node("TimeOfDay")
	var weather: Node = main.get_node("Weather")
	var mat: ShaderMaterial = terrain.terrain.material_override
	var tower_mat: ShaderMaterial = terrain.towers.material_override
	# Season: winter by default (snow on the Blues), summer on request,
	# and falling snow brings winter back.
	_check(terrain.season == "winter" and is_equal_approx(mat.get_shader_parameter("snow"), 1.0), "winter by default")
	terrain.set_season("summer")
	_check(is_zero_approx(mat.get_shader_parameter("snow")), "summer has no snow")
	weather.set_weather("snow", true)
	_check(is_equal_approx(terrain.snow_amount(), 1.0) and is_equal_approx(mat.get_shader_parameter("snow"), 1.0), "falling snow shows winter in summer")
	weather.set_weather("clear", true)
	_check(is_zero_approx(mat.get_shader_parameter("snow")), "summer again once the snow stops")
	# Haze follows the weather and the sky colour.
	tod.set_preset("day", true)
	var clear_haze: float = mat.get_shader_parameter("haze_per_metre")
	weather.set_weather("heavy_fog", true)
	_check(mat.get_shader_parameter("haze_per_metre") > clear_haze * 20.0, "fog thickens the distant haze")
	weather.set_weather("clear", true)
	var haze_color: Color = mat.get_shader_parameter("haze_color")
	_check(haze_color.is_equal_approx(tod.shown().sky_color), "the haze is the sky colour")
	_check(is_zero_approx(tower_mat.get_shader_parameter("darkness")), "warning lights off by day")
	tod.set_preset("night", true)
	_check(tower_mat.get_shader_parameter("darkness") > 0.9, "warning lights on at night")
	tod.set_preset("day", true)
	# The sky menu's Season button.
	var menu: Node = main.get_node("SkyMenu")
	menu.choose_season("winter")
	_check(terrain.season == "winter", "the sky menu picks winter")
	_check(menu._season_button.button_pressed and menu._season_button.text.contains("winter"), "the Season button shows winter")
	menu.toggle_season()
	_check(terrain.season == "summer" and not menu._season_button.button_pressed and menu._season_button.text.contains("summer"), "the Season button switches to summer")
	menu.toggle_season()
	_check(terrain.season == "winter", "and back to winter")
	main.queue_free()
	await process_frame
