extends SceneTree
## Tests for the front of the main House (D-200): the covered porch, the
## front windows and the garage's two roll-up doors. Run headless from project/:
##   godot --headless -s res://tests/test_house_front.gd

const Porch := preload("res://scripts/house_porch.gd")
const DoorScript := preload("res://scripts/shop_door.gd")
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
	_test_pure()
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _step(10)
	var shell: Node3D = main.get_node("Buildings/HouseShell")
	var porch: Node3D = main.get_node("Buildings/HousePorch")
	_test_porch(porch, shell)
	_test_windows(shell)
	_test_garage(main)
	await _test_front_door(main, shell)
	print("house front: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures else 0)

func _test_pure() -> void:
	var wall_len := 14.24
	var zs := Porch.post_zs()
	_check(zs.size() == 6, "six porch posts")
	for i in zs.size() - 1:
		_check(zs[i] > zs[i + 1], "post %d is south of post %d" % [i, i + 1])
	var slab := Porch.slab_rect(5.9, wall_len)
	_check(is_equal_approx(slab.position.x, 5.9) and slab.size.y > wall_len * 0.75, "the porch runs most of the front wall, against it")
	for z in zs:
		_check(z > slab.position.y and z < slab.end.y, "post at %.2f is on the slab" % z)
	var door_z := Porch.DOOR_Z
	for r in Porch.step_rects(5.9, wall_len):
		_check(r.position.y < door_z and r.end.y > door_z, "the steps are in front of the door")
		_check(r.position.x >= slab.end.x - 0.001, "the steps start at the porch's edge")

func _test_porch(porch: Node3D, shell: Node3D) -> void:
	_check(porch.global_transform.is_equal_approx(shell.global_transform), "the porch builds in the House's frame")
	_check(is_equal_approx(porch.wall_x, shell.width / 2.0), "the porch knows where the front wall is")
	for n in ["PorchSlab", "PorchStep1", "PorchStep2", "PorchRoof", "PorchFascia", "Post1", "Post6", "GarageApron"]:
		_check(porch.get_node_or_null(n) != null, "porch has %s" % n)
	var roof := porch.get_node("PorchRoof") as MeshInstance3D
	# The roof meets the wall at the eave and falls to the posts' top.
	var half := (roof.mesh as BoxMesh).size.x / 2.0
	var t := (roof.mesh as BoxMesh).size.y / 2.0
	var at_wall := (roof.transform * Vector3(-half, -t, 0.0)).y
	var at_posts := (roof.transform * Vector3(half, -t, 0.0)).y
	_check(absf(at_wall - shell.height) < 0.05, "the porch roof meets the wall at the eave (%.2f vs %.2f)" % [at_wall, shell.height])
	_check(at_posts < at_wall - 0.2 and absf(at_posts - 2.4) < 0.05, "the porch roof falls to the posts' top (%.2f)" % at_posts)
	_check(roof.position.y > 2.3 and roof.position.y < shell.height + 0.5, "the porch roof sits under the eave (%.2f)" % roof.position.y)

func _test_windows(shell: Node3D) -> void:
	var east: Array = shell.windows.filter(func(w): return w.wall == "east")
	_check(east.size() >= 7, "the front wall has its windows and sidelights (%d)" % east.size())
	var half: float = shell.depth / 2.0
	var spans := []
	for w: Dictionary in east:
		var a := float(w.along)
		var hw := float(w.width) / 2.0
		_check(absf(a) + hw < half, "front window at %.2f is on the wall" % a)
		_check(absf(a - _front_door_z(shell)) > hw + 0.475, "front window at %.2f clears the door" % a)
		for other: Vector2 in spans:
			_check(a - hw >= other.y or a + hw <= other.x, "front window at %.2f does not overlap another" % a)
		spans.append(Vector2(a - hw, a + hw))
	_check(absf(_front_door_z(shell) - Porch.DOOR_Z) < 0.05, "the porch's steps are at the front door (%.2f)" % _front_door_z(shell))

## The front door's centre along the east wall (the door entry gives `along` or `u`).
func _front_door_z(shell: Node3D) -> float:
	for d: Dictionary in shell.doors:
		if d.get("label", "") == "front door":
			return float(d.along) if d.has("along") else Shell.along_for("east", float(d.u), shell.depth)
	return 0.0

func _test_garage(main: Node) -> void:
	var garage: Node3D = main.get_node("Buildings/GarageShell")
	var doors := []
	for c in garage.get_children():
		if c.has_meta("wall") and c.get_meta("wall") == "north":
			doors.append(c)
	_check(doors.size() == 2, "two doors in the garage's north end (%d)" % doors.size())
	for d in doors:
		_check(d.kind == DoorScript.Kind.ROLLUP, "a garage door rolls up")
		_check(d.ribbed, "a garage door is ribbed")
		_check(d.get_interact_prompt() == "Open garage door", "garage door prompt is '%s'" % d.get_interact_prompt())
	if doors.size() == 2:
		_check(absf(doors[0].position.x - doors[1].position.x) > 3.3, "the two garage doors do not overlap")

## The front door is on the porch and walks through.
func _test_front_door(main: Node, shell: Node3D) -> void:
	var player: CharacterBody3D = main.get_node("Player")
	var door: Node3D = null
	for c in shell.get_children():
		if c.has_meta("wall") and c.get_meta("wall") == "east" and c.get("label") == "front door":
			door = c
	_check(door != null, "a front door on the east wall")
	if door == null:
		return
	# The door's origin is its hinge; walk at the middle of the opening.
	var mid := _front_door_z(shell)
	var face: float = shell.width / 2.0
	var from := Vector3(face + 4.0, 0.0, mid)
	var start := shell.to_global(from)
	player.global_position = start + Vector3(0, 0.1, 0)
	player.velocity = Vector3.ZERO
	player.global_basis = Basis.looking_at(shell.to_global(Vector3(face - 2.0, 0, mid)) - start, Vector3.UP)
	door.interact(player)
	await _step(60)
	Input.action_press("move_forward")
	await _step(120)
	Input.action_release("move_forward")
	await _step(5)
	var p := shell.to_local(player.global_position)
	_check(p.x < face - 0.5, "walked in through the front door, over the porch (x %.2f, wall %.2f)" % [p.x, face])
