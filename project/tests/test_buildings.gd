extends SceneTree
## Tests for the walk-in Sally's House and Front Barn (D-115): the shells are
## built over the placeholder boxes, doors sit where the photographed doors
## are, and the real player can walk in through an open doorway but not
## through a wall. Run headless from project/:
##   godot --headless -s res://tests/test_buildings.gd

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
	_test_math()
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _step(10)
	var player: CharacterBody3D = main.get_node("Player")
	var house: Node3D = main.get_node("Buildings/SallysHouseShell")
	var barn: Node3D = main.get_node("Buildings/FrontBarnShell")
	_test_built(main, house, "Sally's House")
	_test_built(main, barn, "Front Barn")
	await _walk_tests(player, house, "south", "Sally's House south door")
	await _walk_tests(player, house, "east", "Sally's House front door")
	await _walk_tests(player, barn, "south", "barn south door")
	await _walk_tests(player, barn, "east", "barn side door")
	print("buildings: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures else 0)

func _test_math() -> void:
	# Left to right seen from outside: south runs +x, north -x, east +z, west -z.
	_check(is_equal_approx(Shell.along_for("south", 0.75, 10.0), 2.5), "south wall: right of centre is +x")
	_check(is_equal_approx(Shell.along_for("north", 0.75, 10.0), -2.5), "north wall: right of centre is -x")
	_check(is_equal_approx(Shell.along_for("east", 0.75, 10.0), 2.5), "east wall: right of centre is +z")
	_check(is_equal_approx(Shell.along_for("west", 0.75, 10.0), -2.5), "west wall: right of centre is -z")
	_check(is_zero_approx(Shell.along_for("south", 0.5, 10.0)), "the middle of a wall is its centre")

func _test_built(main: Node, shell: Node3D, nm: String) -> void:
	var box: Node3D = main.get_node("Buildings/" + shell.building_name)
	_check(not (box.get_node("MeshInstance3D") as Node3D).visible, "%s: placeholder box hidden" % nm)
	_check((box.get_node("CollisionShape3D") as CollisionShape3D).disabled, "%s: placeholder collision off" % nm)
	_check(shell.get_node("Walls").get_child_count() >= 8, "%s: walls have collision (%d)" % [nm, shell.get_node("Walls").get_child_count()])
	var door_count := 0
	for c in shell.get_children():
		if c.has_meta("wall"):
			door_count += 1
	_check(door_count == shell.doors.size() and door_count > 0, "%s: a working door for each entry (%d)" % [nm, door_count])
	_check(shell.get_node("Ceiling") != null, "%s: has a ceiling" % nm)

func _door(shell: Node3D, wall: String) -> Node3D:
	for c in shell.get_children():
		if c.has_meta("wall") and c.get_meta("wall") == wall:
			return c
	return null

## Stand 3 m outside the door, face in and walk: in through the doorway (after
## opening it when it is a slider), and, from 4 m to the side, not through the wall.
func _walk_tests(player: CharacterBody3D, shell: Node3D, wall: String, nm: String) -> void:
	var door := _door(shell, wall)
	_check(door != null, "%s exists" % nm)
	if door == null:
		return
	var spec: Dictionary = Shell.WALLS[wall]
	var out: Vector3 = shell.global_basis * (spec.out as Vector3)
	out.y = 0.0
	out = out.normalized()
	# The doorway's centre on the wall line, from the door's own origin.
	var centre: Vector3 = door.global_position + door.global_basis.x * (float(door.width) / 2.0)
	centre.y = 0.0
	# A closed door is solid: walking at it gets nowhere.
	player.global_position = centre + out * 3.0 + Vector3(0, 0.1, 0)
	player.velocity = Vector3.ZERO
	player.global_basis = Basis.looking_at(-out, Vector3.UP)
	Input.action_press("move_forward")
	await _step(80)
	Input.action_release("move_forward")
	_check(not _inside(shell, player.global_position), "%s: closed, it blocks the player" % nm)
	# Open it and the doorway must be clear.
	door.set_open(true)
	await _step(120)
	# Through the wall first: offset sideways from the door.
	var side := out.cross(Vector3.UP).normalized()
	var wall_start: Vector3 = centre + out * 3.0 + side * (float(door.width) / 2.0 + 2.5)
	var inside_before := _inside(shell, wall_start)
	player.global_position = wall_start + Vector3(0, 0.1, 0)
	player.velocity = Vector3.ZERO
	player.global_basis = Basis.looking_at(-out, Vector3.UP)
	Input.action_press("move_forward")
	await _step(80)
	Input.action_release("move_forward")
	_check(not inside_before and not _inside(shell, player.global_position), "%s: a plain wall stops the player" % nm)
	# Now through the doorway.
	player.global_position = centre + out * 3.0 + Vector3(0, 0.1, 0)
	player.velocity = Vector3.ZERO
	player.global_basis = Basis.looking_at(-out, Vector3.UP)
	Input.action_press("move_forward")
	await _step(80)
	Input.action_release("move_forward")
	_check(_inside(shell, player.global_position), "%s: the player walks in (at %s)" % [nm, player.global_position])
	door.set_open(false)
	await _step(120)

func _inside(shell: Node3D, world: Vector3) -> bool:
	var p := shell.to_local(world)
	return absf(p.x) < shell.width / 2.0 - 0.1 and absf(p.z) < shell.depth / 2.0 - 0.1
