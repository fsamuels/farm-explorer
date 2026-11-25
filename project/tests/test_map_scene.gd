extends SceneTree
const WorldMath := preload("res://scripts/world_math.gd")

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

	# The X / Z readout is big, shows the spot, and clicking it copies "x, z facing N".
	var player_node := main.get_node("Player") as Node3D
	player_node.global_position = Vector3(12.9, 0.0, 17.6)
	player_node.global_rotation.y = deg_to_rad(-333.0)
	await process_frame
	_check(map._coords.get_theme_font_size("font_size") > map._minimap_info.get_theme_font_size("font_size"), "the coordinates are bigger than the other minimap text")
	_check(map._coords.text.begins_with("X 12.9   Z 17.6"), "the readout shows X and Z: %s" % map._coords.text)
	_check(map.coords_clipboard_text() == "12.9, 17.6 facing 333°", "the copied text is the spot and facing: %s" % map.coords_clipboard_text())
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	DisplayServer.clipboard_set("")
	map._coords.gui_input.emit(click)
	_check(DisplayServer.clipboard_get() in ["", "12.9, 17.6 facing 333°"], "clicking copies it (headless may have no clipboard)")
	_check(map._coords.text.contains("copied") or DisplayServer.clipboard_get() == "", "the readout says when it has copied")
	var names: Array = data.buildings.map(func(b): return b.name)
	_check(names.size() == main.get_node("Buildings").get_children().filter(func(n): return n.is_in_group("map_building")).size(), "every building collected")
	_check("Front Barn" in names and "Sally's House" in names, "building names come from node names: %s" % [names])
	var back_barn: Dictionary = data.buildings.filter(func(b): return b.name == "Back Barn")[0]
	_check(back_barn.front.distance_to(Vector2(30.6, -14.5)) < 0.01 and is_equal_approx(MapMath.yaw_to_bearing(back_barn.yaw), 285.0), "the Back Barn teleport lands at 30.6, -14.5 facing 285")
	var house_parts: Array = data.buildings.filter(func(b): return b.name == "House")
	_check(house_parts.size() == 2 and house_parts.all(func(b): return b.front == house_parts[0].front), "the south wing is part of the House: %d" % house_parts.size())
	_check(not names.has("House South Wing"), "the south wing has no name of its own")
	_check(data.imagery.size() == 4, "world photo + ground + two orthomosaic sections: %d" % data.imagery.size())
	_check(data.world_bounds.size.x >= 11000.0 and data.bounds.size.x < 1000.0, "the map pans over the whole world but opens fitted to the farm: %s vs %s" % [data.world_bounds, data.bounds])
	_check(data.bounds.size.x >= 520.0, "bounds cover the ground plane: %s" % data.bounds)
	_check(data.fences.size() > 20, "fence paths collected: %d" % data.fences.size())
	_check(data.boundary.size() > 5, "boundary segments collected: %d" % data.boundary.size())
	_check(data.horses.size() >= 10, "horses collected: %d" % data.horses.size())
	# The property line is one loop with its east side open to the road (D-148):
	# every segment end meets another segment's end, so a segment rotated the wrong
	# way (a mirrored diagonal) shows up as a gap, except the two ends at the
	# road-side line (x = 264) where the open side begins.
	var ends: Array = []
	for seg in data.boundary:
		ends.append(seg[0])
		ends.append(seg[1])
	var open_ends := 0
	for i in ends.size():
		var near := 0
		for j in ends.size():
			if i != j and ends[i].distance_to(ends[j]) < 1.5:
				near += 1
		if near == 0 and absf(ends[i].x - 264.0) < 0.1:
			open_ends += 1
			continue
		_check(near >= 1, "boundary end %s meets another end (%d)" % [ends[i], near])
	_check(open_ends == 2, "the east side is open: two ends at x = 264 (%d)" % open_ends)

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
	await _test_places(main, map)
	await _test_vehicles(main, map)

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
		player.global_position = Vector3(0, 50, 0)
		map._full.center = building.center
		map._full.scale_px = 8.0
		# Overlapping footprints resolve to the first one under the cursor.
		var target: Dictionary = data.buildings[MapMath.footprint_at(building.center, data.footprints)]
		_double_click(map, map._full.to_screen(building.center))
		await process_frame
		var here := MapMath.flatten(player.global_position)
		_check(not map.is_open() and not paused, "%s: teleport closes the map and unpauses" % target.name)
		_check(here.distance_to(target.front) < 0.01, "%s: lands on its front spot" % target.name)
		_check(absf(player.global_position.y - (WorldMath.height_at(here.x, here.y) + 0.2)) < 0.01, "%s: lands on the ground, whatever height you left from" % target.name)
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

## Transport points in the back pastures (D-139) are drawn on the open map and
## double-clicking one lands you there, the same as a building.
func _test_places(main: Node, map) -> void:
	var player: Node3D = main.get_node("Player")
	var places: Array = map._data.places
	_check(places.size() >= 4, "map offers the transport points: %d" % places.size())
	for index in places.size():
		var place: Dictionary = places[index]
		map.set_open(true)
		player.global_position = Vector3(0, 1, 0)
		map._full.center = place.at
		map._full.scale_px = 4.0
		_check(map._place_at(map._full.to_screen(place.at)) == index, "%s: found under the cursor" % place.name)
		_double_click(map, map._full.to_screen(place.at))
		await process_frame
		var here := MapMath.flatten(player.global_position)
		var want := MapMath.flatten(place.node.arrival_spot())
		_check(not map.is_open() and not paused, "%s: teleport closes the map" % place.name)
		_check(here.distance_to(want) < 0.01, "%s: lands at its arrival spot" % place.name)
	map.set_open(true)
	player.global_position = Vector3(0, 1, 0)
	player.set("vehicle", main.get_node("TR6"))
	map._full.center = places[0].at
	_double_click(map, map._full.to_screen(places[0].at))
	_check(map.is_open() and player.global_position.x == 0.0, "no point teleport while driving")
	player.set("vehicle", null)
	map.set_open(false)

## The driveable vehicles are on the open map (D-144) and double-clicking one
## puts you beside it, facing the way it points, with the map closed.
func _test_vehicles(main: Node, map) -> void:
	var player: Node3D = main.get_node("Player")
	var cars: Array = map._data.vehicles
	_check(cars.size() == 5, "map lists the three cars and the two kayaks: %d" % cars.size())
	for index in cars.size():
		var car: Node3D = cars[index]
		var car_at := MapMath.flatten(car.global_position)
		map.set_open(true)
		player.global_position = Vector3(0, 1, 0)
		map._full.center = car_at
		map._full.scale_px = 4.0
		_check(map._vehicle_at(map._full.to_screen(car_at)) == index, "%s: found under the cursor" % car.label)
		_double_click(map, map._full.to_screen(car_at))
		await process_frame
		var here := MapMath.flatten(player.global_position)
		_check(not map.is_open() and not paused, "%s: teleport closes the map" % car.label)
		var dist := here.distance_to(car_at)
		_check(dist > 0.5 and dist < 8.0, "%s: lands beside it (%.1f m)" % [car.label, dist])
		_check(absf(angle_difference(player.global_rotation.y, car.global_rotation.y)) < 0.01, "%s: faces the way it points" % car.label)
	# Not while driving, and not into a car someone else is driving.
	map.set_open(true)
	player.global_position = Vector3(0, 1, 0)
	var first: Node3D = cars[0]
	map._full.center = MapMath.flatten(first.global_position)
	first.driver = player
	_double_click(map, map._full.to_screen(MapMath.flatten(first.global_position)))
	_check(map.is_open() and player.global_position.x == 0.0, "no teleport to a car that is being driven")
	first.driver = null
	player.set("vehicle", main.get_node("TR6"))
	_double_click(map, map._full.to_screen(MapMath.flatten(first.global_position)))
	_check(map.is_open() and player.global_position.x == 0.0, "no vehicle teleport while driving")
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
