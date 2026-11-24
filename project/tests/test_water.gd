extends SceneTree
## Tests for the ditch and pond water (D-141): scripts/water_math.gd (pure), and
## the Water node in main.tscn (scripts/water_system.gd). Run headless from project/:
##   godot --headless -s res://tests/test_water.gd

const TerrainMath := preload("res://scripts/terrain_math.gd")
const WaterData := preload("res://scripts/water_data.gd")
const WaterMath := preload("res://scripts/water_math.gd")

var _failures := 0

func _init() -> void:
	_test_route()
	_test_basin()
	_test_flow()
	_test_pond_step()
	await _test_scene()
	print("water: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures else 0)

func _check(cond: bool, what: String) -> void:
	if not cond:
		_failures += 1
		push_error("FAIL: " + what)

func _near(a: float, b: float, what: String, eps := 0.02) -> void:
	_check(absf(a - b) <= eps, "%s: got %s, want %s" % [what, a, b])

func _test_route() -> void:
	var length := WaterMath.route_length()
	_check(length > 300.0 and length < 800.0, "the route from the weir to the pond is a few hundred metres: %s" % length)
	_check(WaterMath.point_at(0.0).distance_to(WaterData.WEIR) < 0.01, "the route starts at the weir")
	_check(WaterMath.point_at(length).distance_to(Vector2(59.4, 38.0)) < 0.01, "the route ends at the pond inlet")
	_check(not WaterMath.is_buried_at(5.0), "the ditch is open at the weir")
	_check(WaterMath.is_buried_at(WaterMath.nearest_on_route(258.2, -46.0).x), "the driveway culvert is buried")
	_check(WaterMath.is_buried_at(length - 3.0), "the last stretch into the pond is buried")
	var near := WaterMath.nearest_on_route(255.0, 10.0)
	_check(near.y < 0.01 and not WaterMath.is_buried_at(near.x), "a point on the road-side ditch is on the open route")
	# Distances along the route increase through every segment.
	var last := -1.0
	for i in WaterMath.segment_count():
		_check(WaterMath.segment_start(i) > last, "segment starts rise at %d" % i)
		last = WaterMath.segment_start(i)

func _test_basin() -> void:
	var capacity := WaterMath.pond_capacity()
	print("water: pond holds %.0f m3 at its spill level" % capacity)
	_check(capacity > 3000.0 and capacity < 30000.0, "a pond this size holds thousands of cubic metres: %s" % capacity)
	_near(WaterMath.pond_volume_at(-WaterData.POND_DEPTH), 0.0, "nothing at the floor of the deepest lobe", 0.5)
	var previous := -1.0
	for k in range(0, 11):
		var level := -WaterData.POND_DEPTH + WaterData.POND_DEPTH * k / 10.0
		var v := WaterMath.pond_volume_at(level)
		_check(v >= previous, "volume rises with level at %s" % level)
		previous = v
	# Level and volume convert back and forth.
	for level in [-3.0, -2.0, -1.0, -0.5]:
		_near(WaterMath.pond_level_at(WaterMath.pond_volume_at(level)), level, "level round-trips at %s" % level, 0.05)
	# The surface grows as the pond fills, and the deep lobes fill first.
	_check(WaterMath.pond_area_at(-0.3) > WaterMath.pond_area_at(-3.0) * 1.8, "the pond spreads as it fills")
	_check(WaterMath.pond_area_at(-3.7) > 0.0 and WaterMath.pond_area_at(-3.7) < 0.4 * WaterMath.pond_area_at(WaterMath.POND_SPILL_LEVEL), "only the deepest hollows hold water at first: %s m2" % WaterMath.pond_area_at(-3.7))
	_near(WaterMath.pond_level_at(0.0), -WaterData.POND_DEPTH, "an empty pond sits at its floor", 0.001)
	_near(WaterMath.pond_level_at(capacity), WaterMath.POND_SPILL_LEVEL, "a full pond sits at its spill level", 0.01)

func _test_flow() -> void:
	var length_seconds := 40.0
	# A dry ditch with the weir open fills from the top, front first.
	var flow := WaterMath.new_flow()
	for i in 20:   # 10 s
		flow = WaterMath.flow_step(flow, true, length_seconds, 0.5)
	_check(flow[0] > 0.99, "water at the weir: %s" % flow[0])
	_check(flow[flow.size() / 2] < 0.05, "the front has not reached the middle yet after a quarter of the trip: %s" % flow[flow.size() / 2])
	_check(WaterMath.outflow(flow) == 0.0, "nothing reaches the pond yet")
	for i in 80:   # 40 s more
		flow = WaterMath.flow_step(flow, true, length_seconds, 0.5)
	_check(WaterMath.outflow(flow) > 0.95, "water reaches the pond: %s" % WaterMath.outflow(flow))
	_check(flow[flow.size() / 2] > 0.95, "and the whole ditch is full")
	# Shutting the weir lets the water already in the ditch run out, not vanish.
	for i in 20:   # 10 s
		flow = WaterMath.flow_step(flow, false, length_seconds, 0.5)
	_check(flow[0] < 0.05, "the top of the ditch empties first: %s" % flow[0])
	_check(WaterMath.outflow(flow) > 0.95, "the water already in the ditch is still arriving: %s" % WaterMath.outflow(flow))
	for i in 100:   # 50 s more
		flow = WaterMath.flow_step(flow, false, length_seconds, 0.5)
	_check(WaterMath.outflow(flow) < 0.05, "then it is all gone: %s" % WaterMath.outflow(flow))
	# Never leaves 0..1.
	for v in flow:
		_check(v >= -0.0001 and v <= 1.0001, "flow stays in range: %s" % v)
	_near(WaterMath.ditch_water_depth(1.0), WaterData.DITCH_DEPTH * WaterMath.DITCH_MAX_FILL, "a running ditch fills most of its depth")
	_check(WaterMath.ditch_water_depth(1.0) < WaterData.DITCH_DEPTH, "and leaves freeboard")
	_near(WaterMath.ditch_water_depth(0.0, 0.5), 0.5 * WaterMath.ditch_water_depth(1.0), "rain pools a floor of water")

func _test_pond_step() -> void:
	var capacity := WaterMath.pond_capacity()
	var v := WaterMath.pond_step(0.0, 1.0, 1.0 / 240.0, 0.0, 0.0, 60.0)
	_near(v, capacity / 4.0, "a minute of full flow fills a quarter of a four-minute pond", capacity * 0.002)
	_near(WaterMath.pond_step(capacity * 0.99, 1.0, 1.0 / 240.0, 0.0, 0.0, 60.0), capacity, "it cannot overfill", 0.01)
	_check(WaterMath.pond_step(capacity * 0.5, 0.0, 1.0 / 240.0, 0.0, 1.0 / 2700.0, 60.0) < capacity * 0.5, "with no inflow it slowly loses water")
	_check(WaterMath.pond_step(5.0, 0.0, 1.0 / 240.0, 0.0, 1.0, 600.0) >= 0.0, "and never goes below empty")
	_check(WaterMath.pond_step(0.0, 0.0, 1.0 / 240.0, 1.0 / 1200.0, 0.0, 60.0) > 0.0, "rain alone adds water")

func _test_scene() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	var water := main.get_node_or_null("Water")
	if water == null or not water.has_method("pond_fill_fraction"):
		_check(false, "water_system.gd compiled and is attached to Water")
		return
	var weather := main.get_node("Weather")
	_check(not water.weir_open, "the weir starts shut")
	_check(water.pond_fill_fraction() == 0.0, "the pond starts empty")
	var pond_surface: MeshInstance3D = water.get_node("PondSurface")
	var ditch_surface: MeshInstance3D = water.get_node("DitchSurface")
	_check(not pond_surface.visible, "no water sheet over a dry pond")
	_check((pond_surface.material_override as ShaderMaterial).get_shader_parameter("ribbon") == false, "the pond is a flat sheet")
	var ditch_material := ditch_surface.material_override as ShaderMaterial
	_check(ditch_material.get_shader_parameter("ribbon") == true and ditch_material.get_shader_parameter("flow_tex") != null, "the ditch is a ribbon with a flow texture")
	_check(ditch_surface.mesh.get_surface_count() == 1 and (ditch_surface.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() > 200, "the ditch ribbon is built")
	_check(water.get_node_or_null("Weir") != null, "there is a weir")
	var mouths := 0
	for child in water.get_children():
		if child is Node3D and child.get_child_count() == 2 and child.get_child(0) is MeshInstance3D and (child.get_child(0) as MeshInstance3D).mesh is CylinderMesh:
			mouths += 1
	_check(mouths == 4, "four pipe mouths: both ends of the culvert, the pipe's start and the pond inlet: %s" % mouths)

	# The weir answers E: the ray finds the node, which reads "Open the weir" and toggles.
	var space: PhysicsDirectSpaceState3D = water.get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(WaterData.WEIR.x, 3.0, WaterData.WEIR.y), Vector3(WaterData.WEIR.x, -3.0, WaterData.WEIR.y)))
	var target: Node = hit.get("collider")
	while target and not target.has_method("interact"):
		target = target.get_parent()
	_check(target == water, "looking at the weir gate offers the weir's interaction")
	_check(water.get_interact_prompt() == "Open the weir", "prompt: %s" % water.get_interact_prompt())
	water.interact(null)
	_check(water.weir_open and water.get_interact_prompt() == "Shut the weir", "interacting opens the weir")

	# Run the clock: water travels the ditch, then the pond fills and spills.
	water.travel_seconds = 45.0
	for i in 60:
		water._step(1.0)
	_check(WaterMath.outflow(water.flow) > 0.9, "the ditch is running to the pond after a minute: %s" % WaterMath.outflow(water.flow))
	_check(water.pond_fill_fraction() > 0.0, "the pond has started to fill")
	var depth_in_ditch: float = water.water_depth_at(255.0, 10.0)
	_near(depth_in_ditch, WaterMath.ditch_water_depth(1.0), "water in the ditch at the road", 0.05)
	_check(is_nan(water.water_surface_at(0.0, -60.0)), "no water on dry ground")
	_check(is_nan(water.water_surface_at(258.2, -46.0)), "no surface over the buried culvert")
	var toast: Node = main.get_node("Toast")
	toast.clear()
	for i in 330:
		water._step(1.0)
	_check(toast.current_text == "The pond is full", "a toast says the pond is full when it fills: '%s'" % toast.current_text)
	_check(water.pond_fill_fraction() > 0.95, "the pond is full after a few minutes: %s" % water.pond_fill_fraction())
	_check(pond_surface.visible and water.pond_level > -0.5, "the pond sheet is up near the rim: %s" % water.pond_level)
	_near(pond_surface.position.y, water.pond_level, "the sheet sits at the pond's level", 0.001)
	_near(water.water_depth_at(66.0, 26.0), water.pond_level + WaterData.POND_DEPTH, "depth in the middle lobe", 0.05)
	_check(water.water_depth_at(66.0, 60.0) == 0.0, "dry bank just south of the pond")

	# Shut the weir: the ditch runs out, the pond keeps what it has and slowly drops.
	water.weir_open = false
	for i in 120:
		water._step(1.0)
	_check(WaterMath.outflow(water.flow) < 0.05 and water.flow[0] < 0.05, "the ditch has drained")
	var held: float = water.pond_volume
	for i in 600:
		water._step(1.0)
	_check(water.pond_volume < held and water.pond_volume > 0.0, "the pond loses water slowly with the weir shut")

	# Rain: puddles in the ditch and a rising pond, then they fade.
	water.set_pond_fill(0.2)
	var before: float = water.pond_volume
	weather.set_weather("rain", true)
	for i in 120:
		water._step(1.0)
	_check(water.pond_volume > before, "rain tops up the pond")
	_check(water.rain_pool > 0.15, "and leaves standing water in the ditch: %s" % water.rain_pool)
	_check(water.water_depth_at(255.0, 10.0) > 0.1, "which you can wade in")
	weather.set_weather("clear", true)
	for i in 900:
		water._step(1.0)
	_check(water.rain_pool < 0.01, "the standing water dries up: %s" % water.rain_pool)

	water.set_ditch_full(true)
	_check(water.flow[100] == 1.0, "the ditch can be set running full at once")
	await _test_toasts_and_controls(main, water)
	await _test_swimming(main, water)
	main.queue_free()

## The pond announces itself when it becomes full or empty, and the sky menu's Water row drives it.
func _test_toasts_and_controls(main: Node, water: Node) -> void:
	var toast: Node = main.get_node("Toast")
	var menu: Node = main.get_node("SkyMenu")
	water.weir_open = false
	water.time_scale = 1.0
	water.set_pond_fill(0.5)
	toast.clear()
	water.set_pond_fill(1.0)
	_check(toast.current_text == "The pond is full", "filling the pond says so: '%s'" % toast.current_text)
	toast.clear()
	water.set_pond_fill(1.0)
	water.set_pond_fill(0.95)
	water.set_pond_fill(1.0)
	_check(not toast.is_showing(), "a pond hovering near full does not announce itself again")
	water.set_pond_fill(0.5)
	water.set_pond_fill(1.0)
	_check(toast.current_text == "The pond is full", "but it does after dropping well away and refilling")
	toast.clear()
	water.set_pond_fill(0.0)
	_check(toast.current_text == "The pond is empty", "emptying the pond says so: '%s'" % toast.current_text)
	toast.clear()
	water.set_pond_fill(0.0)
	water.set_pond_fill(0.01)
	water.set_pond_fill(0.0)
	_check(not toast.is_showing(), "a pond hovering near empty does not announce itself again")
	water.set_pond_fill(0.3)
	water.set_pond_fill(0.0)
	_check(toast.current_text == "The pond is empty", "but it does after being refilled and emptied again")
	_check(toast.queued() <= toast.MAX_QUEUED, "the toast queue stays bounded")

	# Water speed: the same half second of play moves the water twenty times as far.
	toast.clear()
	water.set_ditch_full(false)
	water.weir_open = true
	water.time_scale = 1.0
	water._process(0.5)
	var slow: float = water.flow[40]
	water.set_ditch_full(false)
	water.time_scale = 20.0
	water._process(0.5)
	_check(slow < 0.05 and water.flow[40] > 0.5, "time_scale speeds the water up: %s vs %s" % [slow, water.flow[40]])
	water.time_scale = 1.0
	water.weir_open = false

	# The sky menu's Water row.
	_check(menu._weir_button != null and menu._water_status != null and menu._speed_buttons.size() == 3, "the sky menu has a Water row")
	menu.toggle_weir()
	_check(water.weir_open and menu._weir_button.button_pressed and menu._weir_button.text == "Weir\nopen", "the menu opens the weir: %s" % menu._weir_button.text)
	menu.toggle_weir()
	_check(not water.weir_open and menu._weir_button.text == "Weir\nshut", "and shuts it")
	menu.set_pond(1.0)
	_check(is_equal_approx(water.pond_fill_fraction(), 1.0) and menu._water_status.text == "Pond 100% full", "the menu fills the pond: %s" % menu._water_status.text)
	menu.set_pond(0.5)
	_check(absf(water.pond_fill_fraction() - 0.5) < 0.01 and menu._water_status.text == "Pond 50% full", "or half fills it: %s" % menu._water_status.text)
	menu.set_pond(0.0)
	_check(water.pond_fill_fraction() == 0.0, "or empties it")
	menu.set_ditch(true)
	_check(water.flow[10] == 1.0 and water.flow[200] == 1.0, "the menu fills the ditch")
	menu.set_ditch(false)
	_check(water.flow[10] == 0.0, "and drains it")
	menu.choose_water_speed(2)
	_check(is_equal_approx(water.time_scale, 20.0) and menu._speed_buttons[2].button_pressed and not menu._speed_buttons[0].button_pressed, "the menu sets the water speed")
	menu.choose_water_speed(0)
	_check(is_equal_approx(water.time_scale, 1.0) and menu._speed_buttons[0].button_pressed, "and puts it back")
	toast.clear()

## Ducks and geese go to the pond when it has water, float on it, and walk back out when it dries.
func _test_swimming(main: Node, water: Node) -> void:
	var goose: Node3D = main.get_node("Goose4")
	var duck: Node3D = main.get_node("MallardDuck")
	_check(goose.swims and duck.swims and main.get_node("Duck1").swims and main.get_node("Duck2").swims, "ducks and geese swim")
	_check(not main.get_node("Flock").swims, "hens do not")
	water.weir_open = false
	water.set_pond_fill(0.0)
	_check(not water.pond_has_water(), "no swimming in a dry pond")
	_check(water.random_swim_spot(Vector2(40, 20), 90.0) == Vector2.INF, "no swim spot in a dry pond")
	goose._process(0.1)
	_check(not goose.swimming, "a goose in a dry pond stays on the ground")

	water.set_pond_fill(0.9)
	_check(water.pond_has_water(), "a filled pond can be swum on")
	var spot: Vector2 = water.random_swim_spot(Vector2(40, 20), 90.0)
	_check(spot != Vector2.INF and water.pond_depth_at(spot.x, spot.y) >= water.SWIM_DEPTH, "swim spots are in deep enough water: %s" % spot)
	_check(water.pond_depth_at(0.0, -60.0) == 0.0 and is_nan(water.pond_surface_at(0.0, -60.0)), "no pond water on dry ground")

	# Send the goose to the water and let it walk there.
	var chosen := false
	for i in 40:
		if goose._pick_swim_target():
			chosen = true
			break
	_check(chosen, "the goose picks the water as its destination")
	for i in 400:
		goose._process(0.5)
		if goose.swimming:
			break
	_check(goose.swimming, "the goose reaches the water and floats: at %s" % goose.global_position)
	if goose.swimming:
		var x: float = goose.global_position.x
		var z: float = goose.global_position.z
		_check(water.pond_depth_at(x, z) > water.SWIM_DEPTH * 0.1, "it is over water")
		_check(absf(goose.global_position.y - (water.pond_level - 0.04)) < 0.05, "and sits on the surface: y %s, level %s" % [goose.global_position.y, water.pond_level])
		# The water rising lifts it; draining the pond sets it back on the ground.
		var before: float = goose.global_position.y
		water.set_pond_fill(1.0)
		goose._process(0.1)
		_check(goose.global_position.y > before - 0.001 and goose.swimming, "it rides the surface up as the pond fills")
		water.set_pond_fill(0.0)
		goose._process(0.1)
		_check(not goose.swimming and absf(goose.global_position.y - TerrainMath.height_at(goose.global_position.x, goose.global_position.z)) < 0.001, "and stands on the bottom when the pond is gone: y %s" % goose.global_position.y)
