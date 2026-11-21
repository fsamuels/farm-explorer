extends SceneTree
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
	_check(map._minimap.show_fences, "fences follow the full map's toggle")
	_press_m()
	await process_frame
	_check(not map.is_open() and not paused, "M again closes it and unpauses")

	print("map_scene: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures else 0)

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
