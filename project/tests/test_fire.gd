extends SceneTree
## Tests for the ditch burn (D-156): scripts/fire_grid.gd (pure) and the Fire
## node in main.tscn (scripts/fire_system.gd). Run headless from project/:
##   godot --headless -s res://tests/test_fire.gd

const FireGrid := preload("res://scripts/fire_grid.gd")
const FireHud := preload("res://scripts/fire_hud.gd")
const FireSound := preload("res://scripts/fire_sound.gd")
const FireSystem := preload("res://scripts/fire_system.gd")
const TerrainMath := preload("res://scripts/terrain_math.gd")
const WaterMath := preload("res://scripts/water_math.gd")

var _failures := 0

func _init() -> void:
	_test_wind()
	_test_factors()
	_test_ignite()
	_test_spread_follows_wind()
	_test_blocks()
	_test_embers()
	_test_rain()
	_test_bookkeeping()
	_test_helpers()
	await _test_scene()
	print("fire: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures else 0)

func _check(cond: bool, what: String) -> void:
	if not cond:
		_failures += 1
		push_error("FAIL: " + what)

## A flat grid of `w` by `h` cells, every cell holding `fuel` in the target zone.
func _grid(w: int, h: int, fuel := 0.8, seed_value := 1) -> FireGrid:
	var g := FireGrid.new(w, h, Vector2.ZERO, 1.0, seed_value)
	for i in w * h:
		g.set_cell(i, fuel, FireGrid.TARGET)
	g.count_fuel()
	return g

func _run(g: FireGrid, seconds: float, wind: Vector2, wetness := 0.0) -> void:
	var t := 0.0
	while t < seconds:
		g.step(0.1, wind, wetness)
		t += 0.1

## How far east the fire has got: the largest column with a lit cell.
func _reach(g: FireGrid) -> int:
	var far := -1
	for i in g.fuel.size():
		if g.state[i] != FireGrid.UNBURNT:
			far = maxi(far, i % g.width)
	return far

func _test_wind() -> void:
	var base := Vector2(1.0, -1.0).normalized()
	var lo := INF
	var hi := 0.0
	var worst := 0.0
	for k in 2000:
		var w := FireGrid.wind_at(k * 1.7, base, 5.0)
		lo = minf(lo, w.length())
		hi = maxf(hi, w.length())
		worst = maxf(worst, absf(angle_difference(base.angle(), w.angle())))
	_check(lo >= 0.5 and lo < 4.0, "the wind never drops to nothing but does ease: %s" % lo)
	_check(hi > 6.0 and hi < 11.0, "gusts lift the wind well above its base but not wildly: %s" % hi)
	_check(worst < 0.55, "the wind stays within about 30 degrees of south-west to north-east: %s" % rad_to_deg(worst))
	_check(FireGrid.wind_at(123.4, base, 5.0) == FireGrid.wind_at(123.4, base, 5.0), "the wind is a pure function of time")
	var mid := FireGrid.wind_at(0.0, base, 5.0)
	_check(mid.x > 0.0 and mid.y < 0.0, "it blows toward the north-east: east (+x) and north (-z): %s" % mid)

func _test_factors() -> void:
	var wind := Vector2(6.0, 0.0)
	_check(FireGrid.wind_factor(wind, Vector2(1, 0)) > 4.0, "downwind spread is several times faster")
	_check(FireGrid.wind_factor(wind, Vector2(-1, 0)) < 0.25, "upwind spread is several times slower")
	_check(absf(FireGrid.wind_factor(wind, Vector2(0, 1)) - 1.0) < 0.001, "across the wind is unchanged")
	_check(FireGrid.wind_factor(Vector2(60, 0), Vector2(1, 0)) <= FireGrid.WIND_FACTOR_MAX, "the wind factor is capped")
	_check(FireGrid.slope_factor(0.5) > 1.0 and FireGrid.slope_factor(-0.5) < 1.0 and FireGrid.slope_factor(0.0) == 1.0, "fire runs uphill")

func _test_ignite() -> void:
	var g := _grid(20, 10)
	_check(g.ignite_cell(g.index(3, 3)), "a fuel cell lights")
	_check(not g.ignite_cell(g.index(3, 3)), "an alight cell does not light twice")
	_check(g.burning.size() == 1 and g.target_lit == 1, "one cell burning and counted")
	_check(not g.ignite_cell(-1), "no cell, no fire")
	var lit := g.ignite_at(10.5, 5.5, 1.0)
	_check(lit >= 4 and lit <= 9, "a torch spot lights a handful of cells: %d" % lit)
	var bare := _grid(5, 5, 0.0)
	_check(not bare.ignite_cell(bare.index(2, 2)) and bare.ignite_at(2.5, 2.5, 2.0) == 0, "bare ground does not light")
	_check(g.cell_at(-1.0, 0.0) == -1 and g.cell_at(3.2, 3.9) == g.index(3, 3), "world points map to cells")
	_check(g.center_of(g.index(3, 3)).is_equal_approx(Vector2(3.5, 3.5)), "cell centres")

func _test_spread_follows_wind() -> void:
	var down := _grid(60, 7, 0.8, 7)
	down.ignite_at(30.5, 3.5, 1.0)
	_run(down, 40.0, Vector2(6.0, 0.0))
	var up := _grid(60, 7, 0.8, 7)
	up.ignite_at(30.5, 3.5, 1.0)
	_run(up, 40.0, Vector2(-6.0, 0.0))
	var east_head := _reach(down) - 30
	_check(east_head > 12, "with the wind behind it the head fire runs: %d cells in 40 s" % east_head)
	# The same fire blown west is the mirror image, so its east edge barely moves.
	var east_back := _reach(up) - 30
	_check(east_back < east_head / 2, "against the wind it backs slowly: %d vs %d" % [east_back, east_head])
	var calm := _grid(60, 7, 0.8, 7)
	calm.ignite_at(30.5, 3.5, 1.0)
	_run(calm, 40.0, Vector2.ZERO)
	var calm_reach := _reach(calm) - 30
	_check(calm_reach > 1 and calm_reach < east_head, "in still air it creeps, slower than the wind-driven head: %d" % calm_reach)
	# Cells burn out behind the front.
	_run(down, 60.0, Vector2(6.0, 0.0))
	var burnt := 0
	for s in down.state:
		burnt += 1 if s == FireGrid.BURNT else 0
	_check(burnt > 100, "burnt-out ground builds up behind the front: %d" % burnt)
	_check(down.burning.size() <= down.fuel.size(), "the burning list stays sane")

func _test_blocks() -> void:
	# A bare band stops creeping fire when the air is still.
	var g := _grid(40, 5, 0.8, 3)
	for cz in 5:
		for cx in range(10, 16):
			g.set_cell(g.index(cx, cz), 0.0, FireGrid.NONE)
	g.count_fuel()
	g.ignite_at(5.5, 2.5, 1.0)
	_run(g, 120.0, Vector2.ZERO)
	_check(_reach(g) < 10, "a bare strip stops a creeping fire: reached %d" % _reach(g))
	# Standing water stops ignition.
	var wet := _grid(10, 3)
	for i in wet.fuel.size():
		wet.moisture[i] = 1.0
	_check(wet.ignite_at(5.0, 1.5, 2.0) == 0, "a soaked cell will not light")
	# A damp cell lights but slower than a dry one.
	var dry := _grid(20, 3, 0.8, 5)
	var damp := _grid(20, 3, 0.8, 5)
	for i in damp.fuel.size():
		damp.moisture[i] = 0.6
	dry.ignite_at(2.5, 1.5, 1.0)
	damp.ignite_at(2.5, 1.5, 1.0)
	# Damp cells won't light at all above WET_NO_LIGHT; below it they do, so hand-light one.
	damp.moisture[damp.index(2, 1)] = 0.0
	damp.ignite_cell(damp.index(2, 1))
	_run(dry, 30.0, Vector2(4.0, 0.0))
	_run(damp, 30.0, Vector2(4.0, 0.0))
	_check(_reach(damp) < _reach(dry), "damp fuel spreads slower: %d vs %d" % [_reach(damp), _reach(dry)])

func _test_embers() -> void:
	# Fire can't creep over a 7-cell bare band, but embers in a gale can carry it.
	var jumped_gale := 0
	var jumped_calm := 0
	for seed_value in 12:
		for gale in [true, false]:
			var g := _grid(60, 9, 0.9, seed_value + 1)
			for cz in 9:
				for cx in range(20, 27):
					g.set_cell(g.index(cx, cz), 0.0, FireGrid.NONE)
			g.count_fuel()
			g.ignite_at(10.5, 4.5, 2.0)
			_run(g, 60.0, Vector2(10.0, 0.0) if gale else Vector2(0.4, 0.0))
			var crossed := false
			for cz in 9:
				for cx in range(27, 60):
					if g.state[g.index(cx, cz)] != FireGrid.UNBURNT:
						crossed = true
			if crossed:
				if gale:
					jumped_gale += 1
				else:
					jumped_calm += 1
	_check(jumped_gale >= 1, "in a gale an ember carries the fire over a bare band: %d of 12" % jumped_gale)
	_check(jumped_calm == 0, "in a calm it does not: %d of 12" % jumped_calm)

func _test_rain() -> void:
	var g := _grid(40, 5, 0.8, 9)
	g.ignite_at(5.5, 2.5, 1.5)
	_run(g, 20.0, Vector2(4.0, 0.0), 1.0)
	_check(g.burning.size() == 0, "heavy rain puts the fire out")
	var small := g.target_lit
	_run(g, 20.0, Vector2(4.0, 0.0), 1.0)
	_check(g.target_lit == small, "and nothing new lights in the rain")
	var dry := _grid(40, 5, 0.8, 9)
	dry.ignite_at(5.5, 2.5, 1.5)
	_run(dry, 20.0, Vector2(4.0, 0.0), 0.0)
	_check(dry.target_lit > small * 2, "the same fire in dry air spreads: %d vs %d" % [dry.target_lit, small])

func _test_bookkeeping() -> void:
	var g := _grid(30, 5, 0.8, 11)
	_check(g.target_total == 150 and g.protected_total == 0, "fuel cells are counted by zone")
	_check(g.target_coverage() == 0.0, "nothing is lit at the start")
	for cx in range(20, 30):
		for cz in 5:
			g.set_cell(g.index(cx, cz), 0.8, FireGrid.PROTECTED)
	g.count_fuel()
	_check(g.target_total == 100 and g.protected_total == 50, "the protected zone is counted apart")
	g.ignite_at(2.5, 2.5, 1.0)
	_run(g, 100.0, Vector2(6.0, 0.0))
	_check(g.protected_lit > 0, "a fire that runs on into the protected zone counts it: %d" % g.protected_lit)
	_check(g.target_coverage() > 0.9, "and covers most of the target: %s" % g.target_coverage())
	# The fire department.
	var h := _grid(30, 3, 0.8, 2)
	for cx in range(10, 30):
		for cz in 3:
			h.set_cell(h.index(cx, cz), 0.8, FireGrid.PROTECTED)
	h.count_fuel()
	h.ignite_at(25.5, 1.5, 1.5)
	var burning := h.burning.size()
	_check(h.extinguish_zone(FireGrid.TARGET) == 0 and h.burning.size() == burning, "the other zone is left alone")
	_check(h.extinguish_zone(FireGrid.PROTECTED) == burning and h.burning.is_empty(), "the fire department puts out the protected zone")
	var i := h.index(25, 1)
	_check(h.state[i] == FireGrid.BURNT and h.burn_progress(i) == 1.0, "and what they put out counts as burnt")
	# Flames build, burn and fade; regrowth resets the lot.
	var f := _grid(5, 5, 1.0)
	var c := f.index(2, 2)
	f.ignite_cell(c)
	_check(f.flame_strength(c) == 0.0 and f.burn_progress(c) == 0.0, "a cell just lit has no flame yet")
	f.left[c] = f.total[c] * 0.6
	_check(f.flame_strength(c) > 0.9, "it burns hot in the middle")
	f.left[c] = f.total[c] * 0.05
	_check(f.flame_strength(c) < 0.2, "and dies down at the end")
	f.regrow()
	_check(f.state[c] == FireGrid.UNBURNT and f.burning.is_empty() and f.target_lit == 0, "grass grows back")

func _test_helpers() -> void:
	_check(FireHud.wind_from_name(Vector2(1.0, -1.0)) == "SW", "wind blowing to the north-east is a south-west wind: %s" % FireHud.wind_from_name(Vector2(1.0, -1.0)))
	_check(FireHud.wind_from_name(Vector2(-1.0, 0.0)) == "E", "blowing west is an east wind")
	_check(FireHud.wind_from_name(Vector2(0.0, 1.0)) == "N", "blowing south is a north wind")
	_check(FireHud.wind_from_name(Vector2.ZERO) == "calm", "no wind is calm")
	_check(FireHud.mph(5.0) == 11, "5 m/s is 11 mph")
	var mesh := FireSystem.clump_mesh()
	var arrays := mesh.surface_get_arrays(0)
	_check((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() > 40 and (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() % 3 == 0, "a grass clump is a fan of blades")
	var top := 0.0
	for v in arrays[Mesh.ARRAY_VERTEX]:
		top = maxf(top, v.y)
	_check(top > 0.9 and top < 1.3, "tall bunch grass is about a metre: %s" % top)
	var quiet := FireSound.new().render(512, 0.0, 0.0, 0.0)
	var peak := 0.0
	for f in quiet:
		peak = maxf(peak, absf(f.x))
	_check(peak == 0.0, "no fire, no sound")
	var loud := FireSound.new().render(4096, 1.0, 1.0, 1.0)
	peak = 0.0
	for f in loud:
		peak = maxf(peak, absf(f.x))
	_check(peak > 0.05 and peak <= 0.81, "a big fire is audible and does not clip: %s" % peak)
	var hiss_only := FireSound.new().render(4096, 0.0, 0.0, 1.0)
	peak = 0.0
	for f in hiss_only:
		peak = maxf(peak, absf(f.x))
	_check(peak > 0.02, "the torch hisses")

func _test_scene() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	var fire := main.get_node_or_null("Fire")
	if fire == null or not fire.has_method("light_at"):
		_check(false, "fire_system.gd compiled and is attached to Fire")
		return
	var water := main.get_node("Water")
	var weather := main.get_node("Weather")
	var grid: FireGrid = fire.grid
	_check(grid.width == FireSystem.GRID_W and grid.height == FireSystem.GRID_H, "the grid covers the strip")
	_check(grid.target_total > 1500, "a long strip of fuel to burn: %d cells" % grid.target_total)
	_check(grid.protected_total > 1000, "and land beside it that must not burn: %d cells" % grid.protected_total)
	_check(fire._ditch_cells.size() > 80, "the ditch bed is fuel: %d cells" % fire._ditch_cells.size())
	# What stands where.
	var road := FireSystem.classify(276.0, 0.0, 0.5)
	_check(road["fuel"] == 0.0 and road["zone"] == FireGrid.NONE, "the road is bare")
	var bed := FireSystem.classify(255.0, 10.0, 0.0)
	_check(bed["zone"] == FireGrid.TARGET and bed["fuel"] > 0.5 and bed["ditch_s"] >= 0.0, "the ditch bed is target fuel")
	var strip := FireSystem.classify(264.0, 10.0, 0.3)
	_check(strip["zone"] == FireGrid.TARGET and strip["fuel"] > 0.4 and strip["ditch_s"] < 0.0, "the strip between ditch and road is target fuel")
	var pasture := FireSystem.classify(247.0, 10.0, 0.3)
	_check(pasture["zone"] == FireGrid.PROTECTED and pasture["fuel"] > 0.0, "the pasture west of the ditch must not burn")
	var field := FireSystem.classify(285.0, 10.0, 0.3)
	_check(field["zone"] == FireGrid.PROTECTED and field["fuel"] > 0.0, "nor the field beyond the road")
	var driveway := FireSystem.classify(264.0, -47.0, 0.9)
	_check(driveway["fuel"] <= FireSystem.DRIVEWAY_FUEL + 0.001, "the driveway has hardly any fuel: %s" % driveway["fuel"])
	var corner := FireSystem.classify(246.0, 69.4, 0.9)
	_check(corner["fuel"] == 0.0, "the east-west ditch along the south edge does not burn yet")
	_check(absf(FireSystem.ground_height(246.0, 69.4) - TerrainMath.height_at(246.0, 69.4)) < 0.001 and FireSystem.ground_height(246.0, 69.4) < -0.5, "the ground there is the carved ditch")
	var bare := FireSystem.classify(264.0, 10.0, -1.0)
	_check(bare["fuel"] == 0.0, "the sparsest patches are bare dirt")
	var margin := FireSystem.classify(253.0, 10.0, 0.9)
	_check(margin["fuel"] == 0.0, "a bare margin separates the ditch from the pasture: %s" % margin)
	# Looks.
	var grass: MultiMeshInstance3D = fire.get_node("Grass")
	_check(grass.multimesh.instance_count > 3000, "tall grass stands on the fuel: %d clumps" % grass.multimesh.instance_count)
	_check(fire.get_node_or_null("Scorch") != null and fire.get_node_or_null("Flames") != null and fire.get_node_or_null("Smoke") != null and fire.get_node_or_null("Embers") != null, "scorch, flames, smoke and embers are built")
	_check(not fire.get_node("Flames").emitting, "nothing burns at the start")
	_check(fire.get_node_or_null("PropaneTank") != null, "there is a propane tank")
	_check(fire.wind.x > 0.0 and fire.wind.y < 0.0, "the wind blows toward the north-east: %s" % fire.wind)
	# Light the south end and watch it.
	var start: int = fire.light_at(Vector2(262.0, 58.0), 1.5)
	_check(start > 0, "the torch lights the grass")
	fire.step(5.0)
	_check(fire.get_node("Flames").emitting and fire.get_node("Smoke").emitting, "flames and smoke rise from the fire")
	_check(fire.quest == FireSystem.Quest.STARTED, "lighting the strip starts the quest")
	var before: int = grid.target_lit
	fire.step(60.0)
	_check(grid.target_lit > before + 20, "the fire spreads: %d -> %d" % [before, grid.target_lit])
	var north := INF
	for i in grid.fuel.size():
		if grid.state[i] != FireGrid.UNBURNT:
			north = minf(north, grid.center_of(i).y)
	_check(north < 55.0, "it has run north, with the wind: %s" % north)
	# Standing water keeps the ditch from burning.
	water.flow = WaterMath.new_flow(1.0)
	fire._update_moisture()
	var bed_cell := grid.cell_at(255.0, -20.0)
	_check(bed_cell >= 0 and grid.moisture[bed_cell] > 0.9, "a running ditch is wet: %s" % grid.moisture[bed_cell])
	_check(not grid.ignite_cell(bed_cell), "and will not light")
	water.flow = WaterMath.new_flow(0.0)
	fire._update_moisture()
	_check(grid.moisture[bed_cell] < 0.05, "a dry ditch is dry again")
	# Rain.
	weather.set_weather("clear", true)
	_check(fire.wetness() < 0.01, "clear air is dry")
	weather.set_weather("rain", true)
	_check(fire.wetness() >= 0.85, "rain wets it: %s" % fire.wetness())
	fire.step(40.0)
	_check(grid.burning.is_empty(), "rain puts the fire out")
	weather.set_weather("clear", true)
	# Start over and test the quest from the top.
	fire.regrow()
	_check(grid.target_lit == 0 and grid.burning.is_empty() and fire.quest == FireSystem.Quest.IDLE, "regrowing starts over")
	_check(fire.get_interact_prompt().begins_with("Start"), "the tank offers to start the quest")
	fire.tank_level = 0.2
	fire.interact(null)
	_check(fire.quest == FireSystem.Quest.STARTED and fire.tank_level == 1.0, "using the tank starts the quest and refills the torch")
	# Light the whole strip at once and let it burn out.
	var z := -88.0
	while z <= 64.0:
		fire.light_at(Vector2(264.0, z), 3.0)
		z += 6.0
	for k in range(0, fire._ditch_cells.size(), 4):
		grid.ignite_cell(fire._ditch_cells[k])
	fire.step(100.0)
	_check(grid.burning.is_empty(), "the fire burns itself out")
	_check(fire.quest == FireSystem.Quest.BURNED, "the quest moves on to opening the weir")
	_check(grid.target_coverage() > 0.8, "most of the ditch and strip is burnt: %s" % grid.target_coverage())
	_check(fire.score > 50, "and the score reflects it: %d (coverage %s, escaped %d, dept %s)" % [fire.score, grid.target_coverage(), grid.protected_lit, fire.dept_called])
	water.weir_open = true
	_check(fire.quest == FireSystem.Quest.DONE, "opening the weir finishes the quest")
	water.weir_open = false
	# With the weir already open, finishing the burn finishes the quest.
	fire.regrow()
	water.weir_open = true
	fire.step(0.1)
	for k in range(0, fire._ditch_cells.size(), 5):
		grid.moisture[fire._ditch_cells[k]] = 0.0
	var zz := -88.0
	while zz <= 64.0:
		fire.light_at(Vector2(264.0, zz), 3.0)
		zz += 6.0
	fire.step(100.0)
	_check(fire.quest == FireSystem.Quest.DONE, "a burn that ends with the weir already open completes the quest: %d" % fire.quest)
	water.weir_open = false
	# Fire across the line brings the fire department.
	fire.regrow()
	fire.light_at(Vector2(246.0, 0.0), 1.5)
	_check(grid.protected_lit > 0, "the pasture can catch")
	fire.step(FireSystem.DEPT_DELAY - 5.0)
	_check(not fire.dept_called, "the fire department takes a while")
	fire.step(10.0)
	_check(fire.dept_called, "then the fire department comes")
	var after: int = grid.protected_lit
	fire.step(20.0)
	_check(grid.protected_lit == after, "and nothing more lights beyond the line")
	_check(fire.burn_score() == 0, "an escape with no burn scores nothing")
	# The torch.
	var player := main.get_node("Player")
	_check(fire._torch != null and fire._torch.get_parent() == player.get_node("Head"), "the torch is on the player's head")
	_check(not fire._torch.visible and not fire.torch_equipped, "it starts stowed")
	fire.regrow()
	fire.torch_equipped = true
	fire._update_torch(0.016)
	_check(fire._torch.visible, "taking it out shows it")
	player.global_position = Vector3(264.0, 0.5, 30.0)
	player.get_node("Head").rotation.x = deg_to_rad(-45.0)
	var lit_by_torch := 0
	for yaw in [0.0, 90.0, 180.0, 270.0]:
		player.rotation_degrees.y = yaw
		await process_frame
		lit_by_torch += fire._torch_ignite()
	_check(lit_by_torch > 0, "the torch lights grass it is pointed at: %d" % lit_by_torch)
	weather.set_weather("rain", true)
	fire.regrow()
	player.get_node("Head").rotation.x = deg_to_rad(-45.0)
	var wet_lit := 0
	for yaw in [0.0, 90.0, 180.0, 270.0]:
		player.rotation_degrees.y = yaw
		await process_frame
		wet_lit += fire._torch_ignite()
	_check(wet_lit == 0, "the torch will not light grass in the rain")
	weather.set_weather("clear", true)
	player.get_node("Head").rotation.x = deg_to_rad(80.0)
	var up: int = fire._torch_ignite()
	_check(up == 0, "but not the sky")
	fire.firing = true
	var tank: float = fire.tank_level
	fire.tank_level = 0.0
	fire._update_torch(0.016)
	_check(not fire.firing, "an empty tank means no flame")
	fire.tank_level = tank
	player.vehicle = main
	fire._update_torch(0.016)
	_check(not fire.torch_equipped, "driving puts the torch away")
	player.vehicle = null
	# The HUD.
	var hud: Control = fire._hud
	_check(hud != null and hud.get_script() == FireHud, "there is a burn readout")
	# The sky menu's Fire row.
	var menu := get_first_node_in_group("sky_menu")
	_check(menu != null and menu.has_method("regrow_fire"), "the sky menu has a Fire row")
	if menu:
		menu.choose_fire_wind(2)
		_check(is_equal_approx(fire.wind_scale, 1.8), "the Gale button blows harder")
		menu.choose_fire_wind(1)
		fire.light_at(Vector2(264.0, 30.0), 2.0)
		menu.regrow_fire()
		_check(grid.target_lit == 0 and fire.quest == FireSystem.Quest.IDLE, "Regrow the grass starts over")
		fire.tank_level = 0.1
		menu.refill_torch()
		_check(fire.tank_level == 1.0, "Refill the torch tops up the tank")
	main.queue_free()
	await process_frame
