extends SceneTree
## Tests for getting into a back-yard hot tub (D-190). Run headless from
## project/:
##   godot --headless -s res://tests/test_hot_tub.gd

var _failures := 0

func _init() -> void:
	_run.call_deferred()

func _check(cond: bool, what: String) -> void:
	if not cond:
		_failures += 1
		push_error("FAIL: " + what)

func _step(n: int) -> void:
	for i in n:
		await physics_frame

func _press(target: Object, action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	target._unhandled_input(ev)

func _run() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _step(5)
	var player: CharacterBody3D = main.get_node("Player")
	var mock: Node3D = main.get_node("Buildings/BackyardMockups")
	_check(InputMap.has_action("tub_lights") and InputMap.has_action("tub_jets"), "L and J actions for the tub")
	# Every idea's tub can be got into.
	for i in range(1, mock.idea_count()):
		var holder: Node3D = mock.built_idea(i)
		_check(not holder.find_children("Soak", "", true, false).is_empty(), "%s: its tub can be got into" % mock.idea_name(i))
	mock.show_idea(1)
	await _step(3)
	var soak: Node3D = mock.built_idea(1).find_children("Soak", "", true, false)[0]
	_check(soak.get_interact_prompt() == "Get in the hot tub", "the prompt on the water")

	# In: underwear, first person, seated facing west, water at the shoulders.
	player.third_person = true
	soak.interact(player)
	await _step(5)
	_check(player.vehicle == soak, "E on the water puts you in the tub")
	_check(player.underwear, "stripped to underwear")
	_check(not player.third_person, "the view goes to first person")
	_check(not player.model.visible, "in first person the body is hidden (the camera is in the head)")
	var local := soak.to_local(player.global_position)
	_check(absf(local.y - (soak.water_y - 1.35)) < 0.05, "sunk so the water is at the shoulders (%.2f)" % local.y)
	var forward := -player.global_basis.z
	var west := -mock.global_basis.x
	_check(forward.dot(west) > 0.99, "facing west, toward the evening sky")
	var eye: float = player.get_node("Head").global_position.y - soak.global_position.y
	_check(eye > soak.water_y + 0.1 and eye < soak.water_y + 0.6, "eyes just above the water (%.2f)" % eye)
	_check(soak.get_node("Clothes").visible, "your clothes are folded on the deck")
	_check(soak.hud_text().contains("L lights") and soak.hud_text().contains("J jets"), "the tub's controls show (%s)" % soak.hud_text())

	# Lights: L steps through off and colours, tinting the water.
	var before: String = soak.light_name()
	_press(soak, "tub_lights")
	_check(soak.light_name() != before, "L changes the lights (%s to %s)" % [before, soak.light_name()])
	for k in 5:
		_press(soak, "tub_lights")
		if soak.light_name() == "off":
			break
	_check(soak.light_name() == "off" and not soak._light.visible, "the lights can be turned off")
	_press(soak, "tub_lights")
	_check(soak._light.visible and soak.get_water_material().emission_energy_multiplier > 0.0, "and on again, lighting the water")

	# Jets: bubbles, foam and much more steam.
	var calm: int = soak.steam_amount()
	_press(soak, "tub_jets")
	_check(soak.jets and soak._bubbles.emitting and soak._foam.visible, "J turns the jets on: bubbles and foam")
	_check(soak.steam_amount() > calm * 2, "more steam with the jets on (%d to %d)" % [calm, soak.steam_amount()])
	_check(soak._steam.emitting, "there is always some steam")
	_press(soak, "tub_jets")
	_check(not soak.jets and not soak._bubbles.emitting, "J again turns them off")

	# Third person shows you in the water.
	var toggle := InputEventAction.new()
	toggle.action = "toggle_view"
	toggle.pressed = true
	player._unhandled_input(toggle)
	_check(player.third_person and player.model.visible, "in third person you see yourself in the tub")
	player._unhandled_input(toggle)

	# Out: dressed, standing on the deck beside the tub.
	player.leave_vehicle()
	await _step(30)
	_check(player.vehicle == null, "E gets you out")
	_check(not player.underwear, "dressed again")
	_check(not soak.get_node("Clothes").visible, "the clothes are picked up")
	var out := soak.to_local(player.global_position)
	_check(Vector2(out.x, out.z).length() > soak.size / 2.0 and Vector2(out.x, out.z).length() < soak.size / 2.0 + 1.5, "standing beside the tub (%s)" % out)
	_check(player.global_position.y > soak.global_position.y + 0.2, "on the deck, not on the ground below it (%.2f)" % (player.global_position.y - soak.global_position.y))
	print("hot tub: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures else 0)
