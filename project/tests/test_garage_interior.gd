extends SceneTree
## Tests for the House Garage's inside (D-201): the cartoon workshop's props,
## their outlines, and the clear paths. Run headless from project/:
##   godot --headless -s res://tests/test_garage_interior.gd

const Garage := preload("res://scripts/garage_interior.gd")

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
	_test_textures()
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _step(10)
	var room: Node3D = main.get_node("Buildings/GarageInterior")
	var shell: Node3D = main.get_node("Buildings/GarageShell")
	_test_props(room, shell)
	_test_clear(main, room)
	await _test_walk(main, shell)
	await _test_table_blocks(main, shell)
	print("garage interior: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures else 0)

func _test_textures() -> void:
	var cork := Garage.corkboard_texture()
	_check(cork.get_width() == 512 and cork.get_image().has_mipmaps(), "the corkboard is a mipmapped 512 px picture")
	# Pale notes and red pins on tan cork: not one flat colour.
	var seen := {}
	for y in range(0, cork.get_height(), 6):
		for x in range(0, cork.get_width(), 6):
			seen[cork.get_image().get_pixel(x, y).to_html()] = true
	_check(seen.size() > 5, "the corkboard has notes, string and pins (%d colours)" % seen.size())
	var clock := Garage.clock_texture().get_image()
	_check(clock.get_pixel(0, 0).a == 0.0 and clock.get_pixel(64, 64).a == 1.0, "the clock is a round face on a clear background")
	_check(Garage.pegboard_texture().get_width() == 256, "a pegboard texture")
	_check(Garage.calendar_texture().get_height() == 140, "a calendar texture")
	_check(Garage.poster_texture(0).get_width() == 64 and Garage.poster_texture(1).get_width() == 64, "two posters")

func _test_props(room: Node3D, shell: Node3D) -> void:
	_check(room.global_transform.is_equal_approx(shell.global_transform), "the garage inside builds in the garage's frame")
	for key in ["parts_cabinet", "chest", "pickle", "tan_box", "radio", "corkboard", "extinguisher", "tank0", "tank1",
			"table", "sink", "rack", "mace", "mask", "crown", "time_box", "jar", "bucket", "washer", "dryer",
			"lamp", "open_door", "fixture"]:
		_check(room.props.has(key), "the garage has its %s" % key)
	for n in ["CounterBase", "CounterTop", "Pegboard", "ClockFace", "Calendar", "Eyeball", "Sock", "Puddle", "Beam", "Vise", "Clipboard"]:
		_check(room.find_child(n, false, false) != null, "the garage has a %s" % n)
	# Cartoon outlines: most solid-looking props wear a black back-face outline.
	var inked := 0
	var plain := 0
	for c in room.get_children():
		if c is MeshInstance3D:
			if c.get_node_or_null("Ink") != null:
				inked += 1
			else:
				plain += 1
	_check(inked > 100, "props are outlined (%d inked, %d plain)" % [inked, plain])
	var ink := (room.get_node("CounterBase/Ink") as MeshInstance3D)
	_check((ink.material_override as StandardMaterial3D).cull_mode == BaseMaterial3D.CULL_FRONT, "an outline draws only the back faces")
	# The room is the right size: the counter runs along the west wall.
	var counter := room.get_node("CounterBase") as MeshInstance3D
	_check(absf(counter.position.x + room.half_x - Garage.COUNTER_D / 2.0) < 0.01, "the counter stands against the west wall")
	_check(counter.position.x < 0.0 and room.props["table"].position.x < 0.0, "the counter and the table are on the west side")
	_check(room.props["rack"] and room.props["washer"].position.x > 3.0, "the shelving and the laundry are on the east wall")
	_check(room.props["fixture"] and room.find_child("FixtureTube", false, false) != null, "fluorescent fixtures overhead")
	_check(room.props["corkboard"].position.y > 1.3 and room.props["corkboard"].position.y < 2.3, "the corkboard is at eye height on the wall")

## The stairs hatch and the doorways stay clear of solid props.
func _test_clear(main: Node, room: Node3D) -> void:
	var hatch: Rect2 = main.get_node("Buildings/HouseBunker").hatch_rect()
	var zones := {
		"stairs hatch": hatch.grow(0.35),
		"north doors": Rect2(-3.6, -4.0, 7.2, 0.8),
		"pantry door": Rect2(-2.9, 2.4, 1.0, 1.6),
		"opening to the house": Rect2(0.45, 2.4, 1.0, 1.6),
	}
	for name in zones:
		for r in room.colliders:
			_check(not r.intersects(zones[name]), "a prop at %s blocks the %s" % [r, name])
	var table := Rect2(Garage.TABLE_AT - Garage.TABLE_SIZE / 2.0, Garage.TABLE_SIZE)
	_check(room.colliders.any(func(r: Rect2) -> bool: return r.encloses(table.grow(-0.01))), "the work table's top is solid")
	for r in room.colliders:
		_check(r.position.x > -room.half_x - 0.05 and r.end.x < room.half_x + 0.05 and r.position.y > -room.half_z - 0.05 and r.end.y < room.half_z + 0.05, "prop %s is inside the garage" % r)

## From the pantry door, up the clear lane beside the work table to the north end.
func _test_walk(main: Node, shell: Node3D) -> void:
	var player: CharacterBody3D = main.get_node("Player")
	var start := shell.to_global(Vector3(-2.43, 0.0, 2.6))
	player.global_position = start + Vector3(0, 0.1, 0)
	player.velocity = Vector3.ZERO
	player.global_basis = Basis.looking_at(shell.to_global(Vector3(-2.43, 0, -2.0)) - start, Vector3.UP)
	Input.action_press("move_forward")
	await _step(150)
	Input.action_release("move_forward")
	await _step(5)
	var p := shell.to_local(player.global_position)
	_check(p.z < -1.5, "walked the length of the garage past the table and the counter (z %.2f)" % p.z)
	_check(p.x > -3.3 and p.x < -1.9, "and stayed in the lane between them (x %.2f)" % p.x)

## Walking at the work table from the east stops at it, and does not go under it.
func _test_table_blocks(main: Node, shell: Node3D) -> void:
	var player: CharacterBody3D = main.get_node("Player")
	var at := Garage.TABLE_AT
	var start := shell.to_global(Vector3(at.x + 2.0, 0.0, at.y))
	player.global_position = start + Vector3(0, 0.1, 0)
	player.velocity = Vector3.ZERO
	player.global_basis = Basis.looking_at(shell.to_global(Vector3(at.x, 0, at.y)) - start, Vector3.UP)
	Input.action_press("move_forward")
	await _step(150)
	Input.action_release("move_forward")
	await _step(5)
	var p := shell.to_local(player.global_position)
	_check(p.x > at.x + Garage.TABLE_SIZE.x / 2.0, "the work table stops the player (x %.2f, table edge %.2f)" % [p.x, at.x + Garage.TABLE_SIZE.x / 2.0])
