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
	await _open_side_tests(player, barn)
	await _interior_tests(main, player)
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
	var walls: int = 4 - shell.open_walls.size()
	_check(shell.get_node("Walls").get_child_count() >= walls, "%s: walls have collision (%d)" % [nm, shell.get_node("Walls").get_child_count()])
	var door_count := 0
	for c in shell.get_children():
		if c.has_meta("wall"):
			door_count += 1
	_check(door_count == shell.doors.size() and (door_count > 0 or not shell.open_walls.is_empty()), "%s: a working door for each entry (%d)" % [nm, door_count])
	_check(shell.front_door_spot(3.0) != null, "%s: the map has a way-in spot" % nm)
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

func _walk_local(player: CharacterBody3D, interior: Node3D, from: Vector3, toward: Vector3, frames: int) -> Vector3:
	var start := interior.to_global(from)
	player.global_position = start + Vector3(0, 0.1, 0)
	player.velocity = Vector3.ZERO
	var dir := (interior.to_global(toward) - start)
	dir.y = 0.0
	player.global_basis = Basis.looking_at(dir.normalized(), Vector3.UP)
	Input.action_press("move_forward")
	await _step(frames)
	Input.action_release("move_forward")
	return interior.to_local(player.global_position)

## The pole barn: its south, north and east sides are open (walk straight in
## from each, no door), and the west side is a wall.
func _open_side_tests(player: CharacterBody3D, shell: Node3D) -> void:
	_check(shell.open_walls.size() == 3 and not shell.open_walls.has("west"), "the barn is open on three sides")
	# From 4 m outside the middle of each side, walk in. The south and north runs
	# stop at the hay stack, the east run at a stall front; both are inside.
	for wall in ["south", "north", "east", "west"]:
		var spec: Dictionary = Shell.WALLS[wall]
		var out: Vector3 = spec.out
		var half: float = shell.depth / 2.0 if spec.along_x else shell.width / 2.0
		var start := out * (half + 4.0)
		var at: Vector3 = await _walk_local(player, shell, start, Vector3.ZERO, 120)
		var inside: bool = absf(at.x) < shell.width / 2.0 - 0.3 and absf(at.z) < shell.depth / 2.0 - 0.3
		if wall == "west":
			_check(not inside, "the west wall stops the player (at %s)" % at)
		else:
			_check(inside, "the player walks in through the open %s side (at %s)" % [wall, at])

func _interior_tests(main: Node, player: CharacterBody3D) -> void:
	var interior: Node3D = main.get_node("Buildings/FrontBarnInterior")
	var Interior := preload("res://scripts/barn_interior.gd")
	var centres := Interior.bay_centres(interior.depth - 2.0 * interior.wall_t, 3)
	_check(centres.size() == 3 and is_zero_approx(centres[1]) and is_equal_approx(centres[0], -centres[2]), "three equal bays: %s" % [centres])
	for i in 3:
		_check(absf(interior.to_local(interior.gates[i].global_position).z - (centres[i] + (interior.stall_gate_width + 0.04) / 2.0)) < 0.01, "gate %d sits in its bay" % i)
	_check(interior.gates.size() == 3, "three stall gates (%d)" % interior.gates.size())
	_check(interior.tack_door != null, "a tack room door")
	_check(interior.hay_size.y > 3.0, "the hay stack is tall: %s" % interior.hay_size)
	var front_x: float = interior.width / 2.0 - interior.wall_t - interior.side_depth
	var tack_front: float = -interior.width / 2.0 + interior.wall_t + interior.side_depth
	# The hay is solid: walking at it from the north stops short.
	var at: Vector3 = await _walk_local(player, interior, Vector3(0, 0, -4.5), Vector3(0, 0, 4.0), 120)
	_check(at.z < -interior.hay_size.z / 2.0 + 0.1, "the hay stack stops the player (z %s)" % at.z)
	# The tack room: a closed door blocks, an open one lets you in.
	var aisle := Vector3(tack_front + 2.0, 0, 0)
	at = await _walk_local(player, interior, aisle, Vector3(-8, 0, 0), 100)
	_check(at.x > tack_front - 0.1, "the closed tack room door blocks (x %s)" % at.x)
	interior.tack_door.set_open(true)
	await _step(80)
	at = await _walk_local(player, interior, aisle, Vector3(-8, 0, 0), 100)
	_check(at.x < tack_front - 0.8, "the player walks into the tack room (x %s)" % at.x)
	interior.tack_door.set_open(false)
	# A stall: the wall beside a gate stops you; through the open gate you get in.
	var c: float = Interior.bay_centres(interior.depth - 2.0 * interior.wall_t, 3)[2]
	at = await _walk_local(player, interior, Vector3(front_x - 2.0, 0, c + 1.0), Vector3(8, 0, c + 1.0), 100)
	_check(at.x < front_x + 0.3, "the stall front stops the player (x %s)" % at.x)
	var gate: Node3D = interior.gates[2]
	gate.set_open(true)
	await _step(80)
	# The open leaf swings into the stall, not out across the aisle.
	var leaf: Vector3 = interior.to_local(gate._shape.global_position)
	_check(leaf.x > front_x + 0.1, "the open gate leaf lies inside the stall (x %s, front %s)" % [leaf.x, front_x])
	at = await _walk_local(player, interior, Vector3(front_x - 2.0, 0, c), Vector3(8, 0, c), 100)
	_check(at.x > front_x + 0.8, "the player walks into the stall through its gate (x %s)" % at.x)
	gate.set_open(false)

func _inside(shell: Node3D, world: Vector3) -> bool:
	var p := shell.to_local(world)
	return absf(p.x) < shell.width / 2.0 - 0.1 and absf(p.z) < shell.depth / 2.0 - 0.1
