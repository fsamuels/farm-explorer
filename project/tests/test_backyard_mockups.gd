extends SceneTree
## Tests for the back-yard mockups. Run headless from project/:
##   godot --headless -s res://tests/test_backyard_mockups.gd

const Mockups := preload("res://scripts/backyard_mockups.gd")
const Backyard := preload("res://scripts/house_backyard.gd")

## The 50 A plug: on the South Wing's west wall, near its north end (House frame).
const PLUG := Vector2(-9.69, 8.0)
## The yard the mockups may use, in the House's frame: the back-yard fences on
## the north, west and south, then the chicken run's west fence and the
## Wing's line, the Wing, the House's west wall and the garage.
const YARD := [Vector2(-8.7, -14.9), Vector2(-10.7, -16.1), Vector2(-25.1, -10.8), Vector2(-36.7, -6.4),
	Vector2(-48.3, -2.2), Vector2(-46.6, 9.7), Vector2(-45.3, 18.5), Vector2(-34.0, 21.7), Vector2(-20.8, 19.9),
	Vector2(-18.3, 20.5), Vector2(-18.0, 12.7), Vector2(-9.69, 12.7), Vector2(-9.69, 7.24), Vector2(-5.67, 7.24),
	Vector2(-5.67, -7.42), Vector2(-8.35, -7.42)]

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

func _run() -> void:
	_test_brief()
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _step(5)
	var mock: Node3D = main.get_node("Buildings/BackyardMockups")
	var yard: Node3D = main.get_node("Buildings/HouseBackyard")
	_check(mock.global_transform.is_equal_approx(yard.global_transform), "mockups build in the House's frame")
	_check(InputMap.has_action("cycle_backyard"), "an O action to step through them")
	var leaves := _leaf_points(yard)
	await _test_garage_door(main.get_node("Player"), main, "As built")
	for i in range(1, mock.idea_count()):
		var holder: Node3D = mock.built_idea(i)
		await _step(2)
		_test_idea(mock, yard, holder, i, leaves)
		await _test_sliders(main.get_node("Player"), main, mock.idea_name(i))
		_test_door_clear(holder, mock.idea_name(i))
		await _test_garage_door(main.get_node("Player"), main, mock.idea_name(i))
	await _test_hint(mock, main.get_node("Player"))
	await _test_cycling(mock, yard)
	print("backyard mockups: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures else 0)

## The tiers asked for: mostly reasonable, a few extravagant, one absurd.
func _test_brief() -> void:
	var tiers := {}
	for idea in Mockups.IDEAS.slice(1):
		tiers[idea.tier] = tiers.get(idea.tier, 0) + 1
	var n := Mockups.IDEAS.size() - 1
	_check(n >= 3 and n <= 60, "between 3 and 60 ideas (%d)" % n)
	_check(tiers.get("reasonable", 0) >= tiers.get("extravagant", 0) and tiers.get("reasonable", 0) >= 3, "most are reasonable %s" % str(tiers))
	_check(tiers.get("extravagant", 0) >= 1, "some are extravagant")
	_check(tiers.get("absurdly over the top", 0) == 1, "exactly one is absurd")

func _marks(holder: Node3D, kind: String) -> Array:
	return holder.find_children("Mark_*", "Marker3D", true, false).filter(func(m: Node) -> bool: return m.get_meta("kind") == kind)

func _test_idea(mock: Node3D, yard: Node3D, holder: Node3D, i: int, leaves: PackedVector2Array) -> void:
	var name: String = mock.idea_name(i)
	_check(holder != null and holder.visible, "%s is built and shown" % name)
	_check(not yard.is_as_built(), "%s: the deck and pad are torn out" % name)
	var tubs := _marks(holder, "hot_tub")
	_check(tubs.size() >= 1, "%s has a hot tub" % name)
	_check(_marks(holder, "cover").size() >= 1, "%s has a covered place to hang out" % name)
	_check(_marks(holder, "fire_table").size() >= 1, "%s has a fire table" % name)
	var grill := false
	for k in _marks(holder, "kitchen"):
		grill = grill or (k.get_meta("items") as Array).has("grill")
	_check(grill, "%s has an outdoor kitchen with a grill" % name)
	# A sauna wherever the card promises one, or room left for one: a spot
	# at least 2.4 m square with nothing solid standing in it.
	var card := " ".join(Mockups.IDEAS[i].notes).to_lower()
	if card.contains("room for a sauna"):
		var spots := _marks(holder, "sauna_spot")
		_check(spots.size() >= 1, "%s leaves room for a sauna" % name)
		for sp in spots:
			var r: Rect2 = sp.get_meta("rect")
			_check(r.size.x >= 2.4 and r.size.y >= 2.4, "%s: the sauna spot is at least 2.4 m square (%s)" % [name, r.size])
			_check(_clear(holder, r.grow(-0.1), float(sp.get_meta("top"))), "%s: nothing stands in the sauna spot" % name)
	elif card.contains("sauna") or name.to_lower().contains("sauna"):
		_check(_marks(holder, "sauna").size() >= 1, "%s has the sauna its card lists" % name)
	var near_plug := false
	for t in tubs:
		var p := Vector2((t as Node3D).position.x, (t as Node3D).position.z)
		var half: float = float(t.get_meta("size")) / 2.0 + 0.3
		var over := 0
		for leaf in leaves:
			if absf(leaf.x - p.x) < half and absf(leaf.y - p.y) < half:
				over += 1
		_check(over == 0, "%s: no willow leaves over the tub at %s (%d)" % [name, p, over])
		near_plug = near_plug or p.distance_to(PLUG) < 6.0
	_check(near_plug, "%s: a tub within 6 m of the 50 A plug" % name)
	# Every tub stands in a deck: a tub-deck marker at its centre, its rim at
	# sitting height above the deck.
	var decks := _marks(holder, "tub_deck")
	for t in tubs:
		var decked := false
		for d in decks:
			decked = decked or (d as Node3D).position.distance_to((t as Node3D).position) < 0.05
		_check(decked, "%s: the tub at %s is surrounded by a deck" % [name, (t as Node3D).position])
	# Everything stays in the yard: each mesh's footprint corners, a little
	# shrunk, inside the yard polygon.
	var out := 0
	var first := ""
	for mi in holder.find_children("*", "MeshInstance3D", true, false):
		var aabb: AABB = (mi as MeshInstance3D).get_aabb()
		var xf: Transform3D = mock.global_transform.affine_inverse() * (mi as Node3D).global_transform
		for c in 8:
			var corner := xf * aabb.get_endpoint(c)
			var centre := xf * aabb.get_center()
			var p := Vector2(corner.x, corner.z).move_toward(Vector2(centre.x, centre.z), 0.2)
			if not Geometry2D.is_point_in_polygon(p, PackedVector2Array(YARD)):
				out += 1
				if first == "":
					first = "%s at %s" % [mi.get_path(), p]
	_check(out == 0, "%s: everything inside the yard (%d corners out, first %s)" % [name, out, first])

## Leaf vertices of every willow, in the House's frame (x, z).
func _leaf_points(yard: Node3D) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for c in yard.get_children():
		if not c.name.begins_with("Willow"):
			continue
		var leaves := c.get_node("Leaves") as MeshInstance3D
		var xf := yard.global_transform.affine_inverse() * leaves.global_transform
		for v in leaves.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var p: Vector3 = xf * v
			pts.append(Vector2(p.x, p.z))
	return pts

## With the deck gone, both sliders still step down onto a landing: walk out
## of each door into the yard.
func _test_sliders(player: CharacterBody3D, main: Node, name: String) -> void:
	for spec in [["Buildings/HouseShell", "west", Vector3.LEFT], ["Buildings/WingShell", "north", Vector3.FORWARD]]:
		var shell: Node3D = main.get_node(spec[0])
		var door: Node3D = null
		for c in shell.get_children():
			if c.has_meta("wall") and c.get_meta("wall") == spec[1] and c.get("glass"):
				door = c
		if door == null:
			_check(false, "%s: slider on %s" % [name, spec[0]])
			continue
		door.set_open(true)
		await _step(90)
		var gap: Vector3 = door.global_position + door.global_basis.x * (float(door.width) - door.glass_panel_width() / 2.0)
		var at := shell.to_local(gap)
		var out_dir: Vector3 = spec[2]
		var face: float = (shell.width if spec[1] == "west" else shell.depth) / 2.0
		var axis := Vector3(0, 0, at.z) if spec[1] == "west" else Vector3(at.x, 0, 0)
		player.global_position = shell.to_global(axis + out_dir * (face - 1.5)) + Vector3(0, 0.1, 0)
		player.velocity = Vector3.ZERO
		var dir := shell.to_global(axis + out_dir * (face + 6.0)) - player.global_position
		dir.y = 0.0
		player.global_basis = Basis.looking_at(dir.normalized(), Vector3.UP)
		Input.action_press("move_forward")
		await _step(80)
		Input.action_release("move_forward")
		await _step(5)
		var p := shell.to_local(player.global_position)
		_check(p.dot(out_dir) > face + 1.5, "%s: out through the %s slider into the yard (%.2f m out)" % [name, spec[0].get_file(), p.dot(out_dir) - face])
		door.set_open(false)
		await _step(90)

## Walking up to the deck shows a hint to press O; walking away hides it.
func _test_hint(mock: Node3D, player: CharacterBody3D) -> void:
	mock.show_idea(0)
	mock._card.visible = false
	_check(Mockups.in_hint_area(Vector3(-7.0, 1.6, 0.0)), "the deck is in the hint area")
	_check(not Mockups.in_hint_area(Vector3(-7.0, 30.0, 0.0)), "not when flying high over it")
	_check(not Mockups.in_hint_area(Vector3(10.0, 1.6, 0.0)), "not inside or east of the House")
	_check(not Mockups.in_hint_area(Vector3(-7.0, -1.6, 0.0)), "not from the bomb shelter under the yard")
	player.global_position = mock.to_global(Vector3(-9.0, 0.5, 0.0))
	player.velocity = Vector3.ZERO
	await process_frame
	await process_frame
	_check(mock.hint_visible() and mock.hint_text().contains("See %d ideas" % (mock.idea_count() - 1)), "standing by the deck shows the O hint (%s)" % mock.hint_text())
	player.global_position = Vector3(232.6, 1.0, -48.4)
	await process_frame
	await process_frame
	_check(not mock.hint_visible(), "far away, no hint")

## Whether the idea's own collision leaves plan rectangle `r` empty from
## 0.3 m above `top` to head height.
func _clear(holder: Node3D, r: Rect2, top: float) -> bool:
	var shape := BoxShape3D.new()
	shape.size = Vector3(r.size.x, 2.0, r.size.y)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = holder.global_transform * Transform3D(Basis(), Vector3(r.get_center().x, top + 1.3, r.get_center().y))
	var body := holder.get_node("Body")
	var hits := holder.get_world_3d().direct_space_state.intersect_shape(q, 16)
	return hits.filter(func(h: Dictionary) -> bool: return h.collider == body).is_empty()

## Nothing solid stands outside the garage door (bar the low foot of a step
## hull): a box query over the patch every idea keeps clear.
func _test_door_clear(holder: Node3D, name: String) -> void:
	var r: Rect2 = Mockups.DOOR_CLEAR
	var shape := BoxShape3D.new()
	shape.size = Vector3(r.size.x, 1.6, r.size.y)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = holder.global_transform * Transform3D(Basis(), Vector3(r.get_center().x, 1.0, r.get_center().y))
	var body := holder.get_node("Body")
	q.exclude = []
	var hits := holder.get_world_3d().direct_space_state.intersect_shape(q, 16)
	var ours := hits.filter(func(h: Dictionary) -> bool: return h.collider == body)
	_check(ours.is_empty(), "%s: nothing in the way outside the garage door" % name)

## Out of the garage through its back door into the yard.
func _test_garage_door(player: CharacterBody3D, main: Node, name: String) -> void:
	var garage: Node3D = main.get_node("Buildings/GarageShell")
	var door: Node3D = null
	for c in garage.get_children():
		if c.has_meta("wall") and c.get_meta("wall") == "south":
			door = c
	if door == null:
		_check(false, "the garage has a door on its south wall")
		return
	door.set_open(true)
	await _step(60)
	var mid: Vector3 = door.global_position + door.global_basis.x * (float(door.width) / 2.0)
	var at := garage.to_local(mid)
	var face: float = garage.depth / 2.0
	player.global_position = garage.to_global(Vector3(at.x, 0.1, face - 1.6))
	player.velocity = Vector3.ZERO
	var dir := garage.to_global(Vector3(at.x, 0, face + 6.0)) - player.global_position
	dir.y = 0.0
	player.global_basis = Basis.looking_at(dir.normalized(), Vector3.UP)
	Input.action_press("move_forward")
	await _step(70)
	Input.action_release("move_forward")
	await _step(5)
	var p := garage.to_local(player.global_position)
	_check(p.z > face + 1.2, "%s: out of the garage's back door into the yard (%.2f m out)" % [name, p.z - face])
	door.set_open(false)
	await _step(60)

## O steps through the ideas and back to as built; the card follows.
func _test_cycling(mock: Node3D, yard: Node3D) -> void:
	mock.show_idea(0)
	_check(yard.is_as_built(), "idea 0 puts the deck back")
	var ev := InputEventAction.new()
	ev.action = "cycle_backyard"
	ev.pressed = true
	mock._unhandled_input(ev)
	_check(mock.current == 1 and mock.card_text().contains(mock.idea_name(1)), "O shows idea 1 and its card")
	var shown := 0
	for c in mock.get_children():
		if c is Node3D and c.name.begins_with("Idea") and (c as Node3D).visible:
			shown += 1
	_check(shown == 1, "only one idea shows at a time (%d)" % shown)
	var back := InputEventKey.new()
	back.physical_keycode = KEY_O
	back.shift_pressed = true
	back.pressed = true
	mock.show_idea(1)
	mock._unhandled_input(back)
	_check(mock.current == 0 and yard.is_as_built(), "Shift+O goes back to as built")
	mock.show_idea(-1)
	_check(mock.current == mock.idea_count() - 1, "stepping back from as built wraps to the last idea")
