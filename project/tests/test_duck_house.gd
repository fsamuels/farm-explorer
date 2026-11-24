extends SceneTree
## Tests for the duck and geese house and its pen fences (D-155). Run headless
## from project/:
##   godot --headless -s res://tests/test_duck_house.gd

const DuckHouse := preload("res://scripts/duck_house.gd")

var _failures := 0

func _init() -> void:
	_run.call_deferred()

func _check(cond: bool, what: String) -> void:
	if not cond:
		_failures += 1
		push_error("FAIL: " + what)

func _done() -> void:
	print("duck_house: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures else 0)

func _fence_points(main: Node, name: String) -> Array[Vector2]:
	var path := main.get_node("BackFences/%s" % name) as Path3D
	var out: Array[Vector2] = []
	for i in path.curve.point_count:
		var p := path.global_transform * path.curve.get_point_position(i)
		out.append(Vector2(p.x, p.z))
	return out

func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await physics_frame
	var house := main.get_node("Buildings/DuckHouse") as Node3D
	_check(house != null, "the duck house is in the scene")
	_check(DuckHouse.WIDTH > DuckHouse.DEPTH, "16 ft wide by 10 ft deep")
	_check(absf(DuckHouse.WIDTH - 4.877) < 0.01 and absf(DuckHouse.DEPTH - 3.048) < 0.01, "the size is 16 x 10 ft in metres")

	# It is located around (6.9, 13.6).
	_check(Vector2(house.global_position.x, house.global_position.z).distance_to(Vector2(6.9, 13.6)) < 1.5, "the house stands near 6.9, 13.6")

	# Its map footprint is named and matches the house.
	var footprint := main.get_node("Buildings/Duck and Geese House") as Node3D
	_check(footprint != null and footprint.is_in_group("map_building"), "the house has a named map footprint")
	_check(footprint.global_position.distance_to(Vector3(house.global_position.x, footprint.global_position.y, house.global_position.z)) < 0.01, "footprint and house share a centre")
	_check(absf(footprint.global_transform.basis.x.length() - DuckHouse.WIDTH) < 0.02, "footprint is as wide as the house")
	_check(absf(footprint.global_transform.basis.z.length() - DuckHouse.DEPTH) < 0.02, "footprint is as deep as the house")
	_check(footprint.global_transform.basis.x.normalized().dot(house.global_transform.basis.x.normalized()) > 0.999, "footprint and house face the same way")

	# The pen fence: the three corners given, and it is on the white lines.
	var pen := _fence_points(main, "DuckPen_SouthEast")
	_check(pen.front().distance_to(Vector2(10.6, 17.1)) < 0.05, "pen fence starts at 10.6, 17.1")
	_check(pen.back().distance_to(Vector2(22.7, 9.6)) < 0.05, "pen fence ends at 22.7, 9.6")
	var corner_ok := false
	for p in pen:
		if p.distance_to(Vector2(19.8, 19.9)) < 0.05:
			corner_ok = true
	_check(corner_ok, "pen fence turns at 19.8, 19.9")
	for i in range(pen.size() - 1):
		_check(pen[i].distance_to(pen[i + 1]) < 3.6, "pen fence posts are at most 3.6 m apart (%d)" % i)

	# The house's south wall is on the fence line, with a ~4 ft opening to the fence's end.
	var line_dir := (Vector2(19.8, 19.9) - Vector2(10.6, 17.1)).normalized()
	var line_n := Vector2(-line_dir.y, line_dir.x)
	var south_mid := Vector2(house.global_position.x, house.global_position.z) + Vector2(house.global_transform.basis.z.x, house.global_transform.basis.z.z) * DuckHouse.DEPTH * 0.5
	_check(absf((south_mid - Vector2(10.6, 17.1)).dot(line_n)) < 0.2, "the south wall lies on the pen fence line")
	var along := house.global_transform.basis.x
	var south_east := Vector2(house.global_position.x, house.global_position.z) \
			+ Vector2(house.global_transform.basis.z.x, house.global_transform.basis.z.z) * DuckHouse.DEPTH * 0.5 \
			+ Vector2(along.x, along.z) * DuckHouse.WIDTH * 0.5
	var opening := south_east.distance_to(Vector2(10.6, 17.1))
	_check(opening > 0.9 and opening < 1.6, "about a 4 ft opening between the house and the fence: %.2f m" % opening)

	# The back fence runs from the back of the house to the Back Barn.
	var back := _fence_points(main, "DuckPen_West")
	var house_ne := Vector2(house.global_position.x, house.global_position.z) \
			- Vector2(house.global_transform.basis.z.x, house.global_transform.basis.z.z) * DuckHouse.DEPTH * 0.5 \
			+ Vector2(along.x, along.z) * DuckHouse.WIDTH * 0.5
	_check(back.front().distance_to(house_ne) < 0.5, "the back fence starts at the back corner of the house: %s vs %s" % [back.front(), house_ne])
	var barn := main.get_node("Buildings/Back Barn") as Node3D
	var barn_sw := barn.global_transform * Vector3(-0.5, 0.0, 0.5)
	_check(back.back().distance_to(Vector2(barn_sw.x, barn_sw.z)) < 0.5, "the back fence ends at the Back Barn's south-west corner")

	# Solid walls and an open doorway on the pen side.
	var space := root.world_3d.direct_space_state
	var door := DuckHouse.door_span()
	var east_x := DuckHouse.WIDTH * 0.5
	var hit_wall := _ray(space, house, Vector3(east_x + 1.0, 0.8, -0.6), Vector3(east_x - 1.0, 0.8, -0.6))
	_check(not hit_wall.is_empty(), "the east wall is solid beside the doorway")
	var mid_door := (door.x + door.y) * 0.5
	var hit_door := _ray(space, house, Vector3(east_x + 1.0, 0.8, mid_door), Vector3(east_x - 1.0, 0.8, mid_door))
	_check(hit_door.is_empty(), "you can walk through the east doorway")
	var hit_back := _ray(space, house, Vector3(0.0, 0.8, -DuckHouse.DEPTH * 0.5 - 1.0), Vector3(0.0, 0.8, 0.0))
	_check(not hit_back.is_empty(), "the back wall is solid")
	var hit_south := _ray(space, house, Vector3(0.0, 0.8, DuckHouse.DEPTH * 0.5 + 1.0), Vector3(0.0, 0.8, 0.0))
	_check(not hit_south.is_empty(), "the south wall is solid")
	var hit_roof := _ray(space, house, Vector3(0.0, 3.5, 0.0), Vector3(0.0, 0.5, 0.0))
	_check(not hit_roof.is_empty(), "there is a roof")

	_done()

func _ray(space: PhysicsDirectSpaceState3D, house: Node3D, from_local: Vector3, to_local: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(house.to_global(from_local), house.to_global(to_local))
	return space.intersect_ray(q)
