extends SceneTree
## Tests for the Things to Do card (D-167). Run headless from project/:
##   godot --headless -s res://tests/test_things_to_do.gd

const ThingsToDo := preload("res://scripts/things_to_do.gd")
const FireSystem := preload("res://scripts/fire_system.gd")
const WaterData := preload("res://scripts/water_data.gd")
const ControlsOverlay := preload("res://scripts/controls_overlay.gd")

var _failures := 0

func _init() -> void:
	_run.call_deferred()

func _check(cond: bool, what: String) -> void:
	if not cond:
		_failures += 1
		push_error("FAIL: " + what)

func _run() -> void:
	_test_list()
	_test_saving()
	await _test_scene()
	print("things to do: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures else 0)

func _test_list() -> void:
	var ids := {}
	for activity: Dictionary in ThingsToDo.ACTIVITIES:
		_check(not ids.has(activity.id), "activity %s is listed once" % activity.id)
		ids[activity.id] = true
		_check(activity.title != "" and activity.text != "" and activity.go != "", "%s has a title, text and button" % activity.id)
		var words: String = (activity.title + " " + activity.text).to_lower()
		_check(not words.contains("shelter") and not words.contains("bunker") and not words.contains("trap door"), "%s leaves the bomb shelter to be found" % activity.id)
	for id in ["burn", "weir", "paddle", "utv", "car"]:
		_check(ids.has(id), "%s is on the list" % id)
	_check(ThingsToDo.done_count({"burn": true, "car": true, "nonsense": true}) == 2, "done_count counts only listed activities")
	var small: float = ThingsToDo.ui_scale(Vector2(1280, 720), Vector2(1500, 1200))
	var huge: float = ThingsToDo.ui_scale(Vector2(10000, 10000), Vector2(1500, 1200))
	_check(small < 1.0 and huge == ThingsToDo.MAX_SCALE, "the card shrinks in a small window and stops growing: %s %s" % [small, huge])
	_check(InputMap.has_action("toggle_things_to_do"), "H has an action")
	var found := false
	for event in InputMap.action_get_events("toggle_things_to_do"):
		if event is InputEventKey and event.physical_keycode == KEY_H:
			found = true
	_check(found, "the action is bound to H")
	var help := false
	for row in ControlsOverlay.CONTROLS:
		if row[0] == "H":
			help = true
	_check(help, "the controls help lists H")

func _test_saving() -> void:
	var path := "user://test_things_to_do.cfg"
	_check(ThingsToDo.load_done(path).is_empty(), "no file means nothing is done")
	_check(ThingsToDo.load_done("").is_empty(), "no path means nothing is done")
	ThingsToDo.save_done(path, {"weir": true, "utv": true, "paddle": false})
	var back := ThingsToDo.load_done(path)
	_check(back == {"weir": true, "utv": true}, "the ticks come back: %s" % back)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	ThingsToDo.save_done("", {"weir": true})  # does nothing, and doesn't fail

func _press(card: Node, action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	card._input(event)

func _test_scene() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var card: Node = main.get_node("ThingsToDo")
	card.save_path = ""  # never touch the real save
	card.done.clear()
	card.refresh()
	var player: Node3D = main.get_node("Player")
	var water: Node = main.get_node("Water")
	var fire: Node = main.get_node("Fire")

	_check(not card.is_open() and not paused, "the card starts closed")

	# The start-up list stands in for the F1 panel.
	var controls: Node = player.get_node("HUD/ControlsOverlay")
	_check(card._hud.visible, "the start-up list is showing at the start")
	_check(not controls.is_open(), "and the F1 panel is not")
	_check(card._hud.position.y > controls._hint.position.y, "the list sits under the F1 hint, not over it")
	_check(card._hud.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the list never takes the mouse")
	card._process(1.0)
	_check(card._hud.visible, "it stays while you stand still")
	Input.action_press("move_forward")
	card._process(1.0)
	_check(card._hud.visible, "one second of moving keeps it")
	card._process(1.1)
	Input.action_release("move_forward")
	_check(not card._hud.visible, "two seconds of moving tucks it away")
	card.set_hud_open(true)
	var key := InputEventKey.new()
	key.keycode = KEY_Q
	key.pressed = true
	card._input(key)
	_check(not card._hud.visible, "so does another key")
	card.set_hud_open(true)
	_press(card, "toggle_things_to_do")
	_check(card.is_open() and not card._hud.visible, "H swaps the list for the full card")
	_press(card, "toggle_things_to_do")
	card.set_hud_open(true)
	controls._set_open(true)
	card._process(0.1)
	_check(not card._hud.visible, "the list gives way when F1 opens the controls")
	controls._set_open(false)
	_press(card, "toggle_things_to_do")
	_check(card.is_open() and paused, "H opens it and pauses the game")
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "the mouse is freed while it is open")
	_press(card, "toggle_things_to_do")
	_check(not card.is_open() and not paused, "H closes it and resumes")
	card.set_open(true)
	_press(card, "ui_cancel")
	_check(not card.is_open() and not paused, "Esc closes it")
	paused = true
	_press(card, "toggle_things_to_do")
	_check(not card.is_open(), "H does nothing while something else has the game paused")
	paused = false
	var sky: Node = main.get_node("SkyMenu")
	sky.set_open(true)
	card.set_open(true)
	_check(not card.is_open(), "it won't open over the sky menu")
	sky.set_open(false)

	for activity: Dictionary in ThingsToDo.ACTIVITIES:
		_check(card.status_labels[activity.id].text == "To do", "%s starts as to do" % activity.id)
		_check(not card.destination(activity.id).is_empty(), "%s has somewhere to go" % activity.id)
	_check(card._progress.text == "0 of 5 done", "nothing done at the start: %s" % card._progress.text)

	# Where each button takes you.
	var burn: Dictionary = card.destination("burn")
	var at := Vector2(burn.at.x, burn.at.z)
	_check(at.distance_to(FireSystem.TANK_POS) < 3.0, "the burn button puts you by the propane tank: %s" % at)
	_check(_facing(burn.yaw, at, FireSystem.TANK_POS), "and facing it")
	var weir: Dictionary = card.destination("weir")
	at = Vector2(weir.at.x, weir.at.z)
	_check(at.distance_to(WaterData.WEIR) < 4.0 and at.x < WaterData.WEIR.x, "the weir button puts you on its west bank, by the hand wheel: %s" % at)
	_check(_facing(weir.yaw, at, WaterData.WEIR), "and facing the weir")
	for id in ["paddle", "utv", "car"]:
		var place: Dictionary = card.destination(id)
		var near := false
		for node in get_nodes_in_group("map_vehicle"):
			if (node as Node3D).global_position.distance_to(place.at) < 6.0:
				near = true
		_check(near, "the %s button puts you by a vehicle" % id)

	# Taking you there.
	card.set_open(true)
	_check(card.go("weir") and not card.is_open() and not paused, "Take me there goes and closes the card")
	_check(player.global_position.distance_to(weir.at) < 0.01 and player.velocity == Vector3.ZERO, "the player is at the weir: %s" % player.global_position)
	var car: Node3D = main.get_node("TR6")
	player.vehicle = car  # sitting in a car
	card.set_open(true)
	_check(card.go_buttons["burn"].disabled, "the buttons are off while driving")
	var before := player.global_position
	_check(not card.go("burn") and player.global_position == before, "no teleporting out of a vehicle")
	player.vehicle = null
	card.set_open(false)
	card.refresh()
	_check(not card.go_buttons["burn"].disabled, "and back on when you get out")
	car.driver = player
	_check(not card.destination("car").is_empty(), "the other car is still on offer when one is taken")
	main.get_node("BMW2002tii").driver = player
	_check(card.destination("car").is_empty(), "no spot when every car has a driver")
	car.driver = null
	main.get_node("BMW2002tii").driver = null

	# Noticing what you do.
	_check(not card.is_happening("weir") and not card.is_happening("burn"), "nothing is happening yet")
	water.weir_open = true
	card.watch()
	_check(card.done.get("weir", false) and card.status_labels["weir"].text == "Done!", "opening the weir ticks it")
	_check(card._progress.text == "1 of 5 done", "the count follows: %s" % card._progress.text)
	card.done.clear()
	water.weir_open = false
	fire.quest = FireSystem.Quest.STARTED
	_check(not card.is_happening("burn"), "a burn that has only started isn't done")
	fire.quest = FireSystem.Quest.BURNED
	_check(card.is_happening("burn"), "a finished burn is done")
	fire.quest = FireSystem.Quest.IDLE
	var utv: Node3D = main.get_node("CubCadetUTV")
	_check(not card.is_happening("utv"), "the Cub Cadet isn't being driven")
	utv.driver = player
	_check(card.is_happening("utv") and not card.is_happening("car"), "driving the Cub Cadet counts, and isn't the car")
	utv.driver = null
	var kayak: Node3D = main.get_node("Kayak")
	kayak.driver = player
	_check(not card.is_happening("paddle"), "a kayak being dragged over land isn't a paddle")
	kayak.afloat = true
	_check(card.is_happening("paddle"), "a kayak afloat with someone in it is")
	kayak.driver = null
	kayak.afloat = false
	main.get_node("TR6").driver = player
	_check(card.is_happening("car"), "driving a car counts")
	main.get_node("TR6").driver = null

	# Starting over asks first, then clears the ticks and the world.
	card.done = {"weir": true, "burn": true}
	water.weir_open = true
	fire.quest = FireSystem.Quest.BURNED
	card.refresh()
	card.start_over()
	_check(card.reset_button.text == ThingsToDo.RESET_SURE_TEXT and card.done.size() == 2, "the first press only asks")
	card.set_open(true)
	_check(card.reset_button.text == ThingsToDo.RESET_TEXT, "opening the card forgets the question")
	card.start_over()
	card.start_over()
	_check(card.done.is_empty() and card._progress.text == "0 of 5 done", "the second press clears every tick")
	_check(not water.weir_open and fire.quest == FireSystem.Quest.IDLE, "and shuts the weir and starts the burn afresh")
	card.watch()
	_check(card.done.is_empty(), "so nothing ticks itself straight back")
	_check(card.reset_button.text == ThingsToDo.RESET_TEXT, "the button asks again next time")
	card.set_open(false)

	# The pond shortcut.
	water.set_pond_fill(0.0)
	card.fill_pond()
	_check(water.pond_fill_fraction() > 0.99 and card.fill_button != null, "Fill the pond brims the pond")
	main.queue_free()
	await process_frame

func _facing(yaw: float, from: Vector2, target: Vector2) -> bool:
	var forward := Vector2(-sin(yaw), -cos(yaw))
	return forward.dot((target - from).normalized()) > 0.99
