extends SceneTree
## Tests for the House's ground floor (D-194): the kitchen, pantry, dining and
## living rooms are built, the pantry's door lines up with the garage's
## opening, and the real player can cross from the sliding door to the front
## door, walk through the pantry into the garage once its door is open, and is
## stopped by the counters and the closed south-east block. Run headless from
## project/:
##   godot --headless -s res://tests/test_house_interior.gd

const Interior := preload("res://scripts/house_interior.gd")
const Shell := preload("res://scripts/building_shell.gd")

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
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _step(10)
	var player: CharacterBody3D = main.get_node("Player")
	var shell: Node3D = main.get_node("Buildings/HouseShell")
	var garage: Node3D = main.get_node("Buildings/GarageShell")
	var inside: Node3D = main.get_node("Buildings/HouseInterior")
	_test_built(shell, garage, inside)
	await _test_walks(player, shell, garage)
	print("house interior: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures else 0)

func _test_built(shell: Node3D, garage: Node3D, inside: Node3D) -> void:
	_check(inside.global_transform.is_equal_approx(shell.global_transform), "interior and shell share a frame")
	for n in ["WoodFloor", "TileFloor", "Stove", "Fridge", "Sink", "DiningTable", "Sofa", "TV", "SouthEastBlock"]:
		_check(inside.find_child(n, false, false) != null, "the interior has %s" % n)
	_check(shell.rise == 0.0, "the House has a flat ceiling")
	# The kitchen is north-west, the block south-east, the dining table south-west.
	_check(Interior.KITCHEN.get_center().x < 0.0 and Interior.KITCHEN.get_center().y < 0.0, "kitchen in the north-west")
	_check(Interior.BLOCK.get_center().x > 0.0 and Interior.BLOCK.get_center().y > 0.0, "closed block in the south-east")
	_check(Interior.DINING_TABLE.x < 0.0 and Interior.DINING_TABLE.z > 0.0, "dining table in the south-west")
	# The pantry's door and the garage's opening meet.
	var door := _door(shell, "north")
	_check(door != null, "a door in the House's north wall")
	var opening := Vector3.INF
	for d: Dictionary in garage.doors:
		if not d.get("leaf", true):
			opening = garage.to_global(Vector3(float(d.along), 0, garage.depth / 2.0))
	_check(opening != Vector3.INF, "the garage has an opening on its south wall")
	if door != null and opening != Vector3.INF:
		var door_mid := door.global_position + door.global_basis.x * (float(door.width) / 2.0)
		var gap := Vector2(door_mid.x - opening.x, door_mid.z - opening.z).length()
		_check(gap < 0.35, "pantry door lines up with the garage's opening (%.2f m apart)" % gap)
		var local := shell.to_local(door_mid)
		_check(Interior.PANTRY.grow(0.01).has_point(Vector2(local.x, -7.145)), "the garage door is in the pantry")

func _door(shell: Node3D, wall: String) -> Node3D:
	for c in shell.get_children():
		if c.has_meta("wall") and c.get_meta("wall") == wall:
			return c
	return null

func _walk(player: CharacterBody3D, frame: Node3D, from: Vector3, toward: Vector3, frames: int) -> Vector3:
	var start := frame.to_global(from)
	player.global_position = start + Vector3(0, 0.1, 0)
	player.velocity = Vector3.ZERO
	var dir := frame.to_global(toward) - start
	dir.y = 0.0
	player.global_basis = Basis.looking_at(dir.normalized(), Vector3.UP)
	Input.action_press("move_forward")
	await _step(frames)
	Input.action_release("move_forward")
	await _step(5)
	return frame.to_local(player.global_position)

func _test_walks(player: CharacterBody3D, shell: Node3D, garage: Node3D) -> void:
	# Across the open middle, from inside the slider to the front door.
	var p := await _walk(player, shell, Vector3(-4.3, 0.05, 0.6), Vector3(5.0, 0.05, 1.8), 120)
	_check(p.x > 3.8, "from the slider across to the front door (at %s)" % p)
	# The kitchen's west counter stops you.
	p = await _walk(player, shell, Vector3(-3.0, 0.05, -3.2), Vector3(-8.0, 0.05, -3.2), 60)
	_check(p.x > -4.92 + 0.2, "the west counter stops you (x %.2f)" % p.x)
	# The south-east block is solid.
	p = await _walk(player, shell, Vector3(2.5, 0.05, 1.2), Vector3(2.5, 0.05, 7.0), 60)
	_check(p.z < Interior.BLOCK.position.y, "the closed block stops you (z %.2f)" % p.z)
	# Into the pantry: the shut garage door keeps you in it; open, on into the garage.
	var from := Vector3(Interior.PANTRY_DOOR_X, 0.05, -3.0)
	var toward := Vector3(Interior.PANTRY_DOOR_X, 0.05, -12.0)
	p = await _walk(player, shell, from, toward, 90)
	_check(p.z < Interior.PANTRY.end.y and p.z > -7.3, "into the pantry, stopped by the shut garage door (z %.2f)" % p.z)
	var door := _door(shell, "north")
	door.set_open(true)
	await _step(60)
	p = await _walk(player, shell, from, toward, 120)
	var g := garage.to_local(shell.to_global(p))
	_check(absf(g.x) < garage.width / 2.0 and absf(g.z) < garage.depth / 2.0 - 0.2 and g.y > -0.2, "through the pantry into the garage (at %s)" % g)
