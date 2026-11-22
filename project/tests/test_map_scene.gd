extends SceneTree

const MapMath := preload("res://scripts/map_math.gd")
## Loads main.tscn headless and checks the map (D-93) picks up the farm from
## scene groups and that M opens/closes it with the game paused. Run from
## project/ (after the editor has imported assets once):
##   godot --headless -s res://tests/test_map_scene.gd

var _failures := 0

func _init() -> void:
	_run.call_deferred()

func _check(cond: bool, what: String) -> void:
	if not cond:
		_failures += 1
		push_error("FAIL: " + what)

func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 5:
		await process_frame

	var map = main.get_node("Minimap/Root")
	var data: Dictionary = map._data
	var names: Array = data.buildings.map(func(b): return b.name)
	_check(names.size() == main.get_node("Buildings").get_children().filter(func(n): return n.is_in_group("map_building")).size(), "every building collected")
	_check("Front Barn" in names and "Sally's House" in names, "building names come from node names: %s" % [names])
	_check(data.imagery.size() == 3, "ground + two orthomosaic sections: %d" % data.imagery.size())
	_check(data.bounds.size.x >= 520.0, "bounds cover the ground plane: %s" % data.bounds)
	_check(data.fences.size() > 20, "fence paths collected: %d" % data.fences.size())
	_check(data.boundary.size() > 5, "boundary segments collected: %d" % data.boundary.size())
	_check(data.horses.size() >= 10, "horses collected: %d" % data.horses.size())

	_check(not map.is_open() and not paused, "starts closed and unpaused")
	_press_m()
	await process_frame
	_check(map.is_open() and paused, "M opens the map and pauses")
	for i in 2:
		_press(KEY_1)
		_press(KEY_2)
	await process_frame
	_check(map._full.show_labels and map._full.show_fences, "1/2 twice turns layers back on")
	_check(not map._minimap.show_labels, "names never turn on in the minimap")
	_check(map._full.show_grid and not map._minimap.show_grid, "grid on in the full map only")
	_press(KEY_5)
	await process_frame
	_check(not map._full.show_grid and not map._minimap.show_grid, "5 hides the grid")
	_press(KEY_5)
	await process_frame
	_check(map._full.show_grid and not map._minimap.show_grid, "5 again shows it, still not on the minimap")
	_check(map._minimap.show_fences, "fences follow the full map's toggle")
	_press_m()
	await process_frame
	_check(not map.is_open() and not paused, "M again closes it and unpauses")

	await _test_teleport(main, map)

	print("map_scene: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures else 0)

## Double-clicking a building on the open map (D-118) puts the player just
## outside its front door, facing it, and closes the map.
func _test_teleport(main: Node, map) -> void:
	var player: Node3D = main.get_node("Player")
	var data: Dictionary = map._data
	for index in data.buildings.size():
		var building: Dictionary = data.buildings[index]
		map.set_open(true)
		player.global_position = Vector3(0, 1, 0)
		map._full.center = building.center
		map._full.scale_px = 8.0
		# Overlapping footprints resolve to the first one under the cursor.
		var target: Dictionary = data.buildings[MapMath.footprint_at(building.center, data.footprints)]
		_double_click(map, map._full.to_screen(building.center))
		await process_frame
		var here := MapMath.flatten(player.global_position)
		_check(not map.is_open() and not paused, "%s: teleport closes the map and unpauses" % target.name)
		_check(here.distance_to(target.front) < 0.01, "%s: lands on its front spot" % target.name)
		_check(not Geometry2D.is_point_in_polygon(here, target.poly), "%s: lands outside the footprint" % target.name)
		var facing := Vector2(-sin(player.global_rotation.y), -cos(player.global_rotation.y))
		_check(facing.dot((target.center - here).normalized()) > 0.99, "%s: faces the building" % target.name)

	# Walk-in buildings use their real front door: the Shop's east door, Sally's
	# House's east/porch door, the Front Barn's north end (D-125).
	var shop := _building(data, "Shop")
	_check(absf(shop.front.x - (210.2 + 2.5)) < 0.5 and absf(shop.front.y - -50.6) < 0.5, "Shop front is outside its east door: %s" % shop.front)
	var house := _building(data, "Sally's House")
	_check(house.front.x > house.center.x + 4.0, "Sally's House front is on its east side: %s" % house.front)
	var barn := _building(data, "Front Barn")
	_check(barn.front.y < barn.center.y - 10.0, "Front Barn front is at its north end: %s" % barn.front)

	# A click that misses every building does nothing, and neither does one
	# while driving (the car would be left behind).
	map.set_open(true)
	player.global_position = Vector3(0, 1, 0)
	map._full.center = Vector2.ZERO
	_double_click(map, map._full.to_screen(Vector2(-250, 250)))
	_check(map.is_open() and player.global_position.x == 0.0, "double-click on empty ground does nothing")
	player.set("vehicle", main.get_node("TR6"))
	map._full.center = shop.center
	_double_click(map, map._full.to_screen(shop.center))
	_check(map.is_open() and player.global_position.x == 0.0, "no teleport while driving")
	player.set("vehicle", null)
	map.set_open(false)

func _building(data: Dictionary, building_name: String) -> Dictionary:
	return data.buildings[data.buildings.map(func(b): return b.name).find(building_name)]

func _double_click(map, at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.double_click = true
	event.position = at
	map._on_full_map_input(event)

func _press_m() -> void:
	_press(KEY_M)

func _press(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	var release := event.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
