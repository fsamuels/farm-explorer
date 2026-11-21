extends SceneTree
## Loads main.tscn headless and checks the walk-in Shop (D-98): solid walls,
## closed doors that block, and doors that open a passable gap. Run from
## project/ (after the editor has imported assets once):
##   godot --headless -s res://tests/test_shop.gd

var _failures := 0
var _space: PhysicsDirectSpaceState3D

func _init() -> void:
	_run.call_deferred()

func _check(cond: bool, what: String) -> void:
	if not cond:
		_failures += 1
		push_error("FAIL: " + what)

## True if a ray between two points in the Shop's frame hits something.
func _hits(shell: Node3D, from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(shell.to_global(from), shell.to_global(to))
	return not _space.intersect_ray(query).is_empty()

func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 5:
		await physics_frame
	_space = main.get_viewport().world_3d.direct_space_state

	var shell := main.get_node("Buildings/ShopShell") as Node3D
	var shop := main.get_node("Buildings/Shop")
	_check(shop.is_in_group("map_building"), "Shop is still on the map")
	_check(not shop.get_node("MeshInstance3D").visible, "placeholder box hidden")
	var hw: float = shell.width / 2.0
	var hd: float = shell.depth / 2.0
	_check(shell.width > 14.0 and shell.depth > 10.0, "footprint read from the box: %s x %s" % [shell.width, shell.depth])

	var main_door := shell.get_node("MainDoor")
	var garage := shell.get_node("GarageDoor")
	var barn := shell.get_node("BarnDoor")
	_check(main_door.get_interact_prompt() == "Open door", "prompt: %s" % main_door.get_interact_prompt())

	# Door centres in the Shop's frame (the numbers the user gave, in world X/Z).
	var main_c := shell.to_local(Vector3(210.2, 0, -50.6)).z
	var garage_c := shell.to_local(Vector3(207.3, 0, -47.0)).x
	var barn_c := shell.to_local(Vector3(194.5, 0, -50.6)).z - 0.1 - 1.5

	var main_ray := [Vector3(hw + 2, 1.0, main_c), Vector3(hw - 2, 1.0, main_c)]
	var garage_ray := [Vector3(garage_c, 1.0, hd + 2), Vector3(garage_c, 1.0, hd - 2)]
	var barn_ray := [Vector3(-hw - 2, 1.0, barn_c), Vector3(-hw + 2, 1.0, barn_c)]
	_check(_hits(shell, main_ray[0], main_ray[1]), "closed main door blocks")
	_check(_hits(shell, garage_ray[0], garage_ray[1]), "closed garage door blocks")
	_check(_hits(shell, barn_ray[0], barn_ray[1]), "closed barn door blocks")
	# Plain wall, north side, and a window (glass blocks too).
	_check(_hits(shell, Vector3(0, 1.0, -hd - 2), Vector3(0, 1.0, -hd + 2)), "north wall is solid")

	for door in [main_door, garage, barn]:
		door.interact(null)
		_check(door.is_open and door.get_interact_prompt().begins_with("Close"), "%s opened" % door.name)
	await create_timer(3.2).timeout
	await physics_frame
	_check(not _hits(shell, main_ray[0], main_ray[1]), "open main door lets you through")
	_check(not _hits(shell, garage_ray[0], garage_ray[1]), "open garage door lets you through")
	_check(not _hits(shell, barn_ray[0], barn_ray[1]), "open barn door lets you through")
	_check(_hits(shell, Vector3(0, 1.0, -hd - 2), Vector3(0, 1.0, -hd + 2)), "north wall still solid")

	# The barn door ends up clear of the opening, flush with the north wall.
	var leaf := barn.get_node("Leaf") as Node3D
	var leaf_north := shell.to_local(leaf.global_position + leaf.global_basis.x * barn.width).z
	_check(absf(leaf_north - (-hd)) < 0.05, "barn leaf's far edge is even with the north wall: %s vs %s" % [leaf_north, -hd])

	barn.interact(null)
	await create_timer(3.2).timeout
	await physics_frame
	_check(_hits(shell, barn_ray[0], barn_ray[1]), "closing the barn door blocks it again")

	print("shop: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures else 0)
