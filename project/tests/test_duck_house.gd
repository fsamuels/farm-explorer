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
	_check(DuckHouse.LENGTH > DuckHouse.DEPTH, "16 ft long by 10 ft deep")
	_check(absf(DuckHouse.LENGTH - 4.877) < 0.01 and absf(DuckHouse.DEPTH - 3.048) < 0.01, "the size is 16 x 10 ft in metres")
	var centre := Vector2(house.global_position.x, house.global_position.z)
	var along := Vector2(house.global_transform.basis.x.x, house.global_transform.basis.x.z)  # toward the pen
	var south := Vector2(house.global_transform.basis.z.x, house.global_transform.basis.z.z)

	# It is located around (6.9, 13.6).
	_check(centre.distance_to(Vector2(6.9, 13.6)) < 2.5, "the house stands near 6.9, 13.6")

	# Its map footprint is named and matches the house.
	var footprint := main.get_node("Buildings/Duck and Geese House") as Node3D
	_check(footprint != null and footprint.is_in_group("map_building"), "the house has a named map footprint")
	_check(Vector2(footprint.global_position.x, footprint.global_position.z).distance_to(centre) < 0.01, "footprint and house share a centre")
	_check(absf(footprint.global_transform.basis.x.length() - DuckHouse.DEPTH) < 0.02, "footprint is as deep as the house")
	_check(absf(footprint.global_transform.basis.z.length() - DuckHouse.LENGTH) < 0.02, "footprint is as long as the house")
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
	var south_mid := centre + south * DuckHouse.LENGTH * 0.5
	_check(absf((south_mid - Vector2(10.6, 17.1)).dot(line_n)) < 0.2, "the south wall lies on the pen fence line")
	var south_east := south_mid + along * DuckHouse.DEPTH * 0.5
	var opening := south_east.distance_to(Vector2(10.6, 17.1))
	_check(opening > 0.9 and opening < 1.6, "about a 4 ft opening between the house and the fence: %.2f m" % opening)

	# The west fence runs from the house's west side nearly north to the middle of the Back Barn.
	var back := _fence_points(main, "DuckPen_West")
	var house_nw := centre - south * DuckHouse.LENGTH * 0.5 - along * DuckHouse.DEPTH * 0.5
	_check(back.front().distance_to(house_nw) < 0.5, "the west fence starts at the house's north-west corner: %s vs %s" % [back.front(), house_nw])
	var barn := main.get_node("Buildings/Back Barn") as Node3D
	var barn_front := barn.global_transform * Vector3(0.0, 0.0, 0.5)
	_check(back.back().distance_to(Vector2(barn_front.x, barn_front.z)) < 0.5, "the west fence ends in the middle of the Back Barn's south wall")
	var bearing := rad_to_deg((back.back() - back.front()).angle_to(Vector2(0.0, -1.0)))
	_check(absf(bearing) < 16.0, "the west fence runs almost due north: %.1f degrees off" % bearing)

	# The cross fence runs from the post at 20.1, 9.0 west to the barn fence, and
	# two gates meet that post.
	var cross := _fence_points(main, "DuckPen_Cross")
	_check(cross.front().distance_to(Vector2(20.1, 9.0)) < 0.05, "the cross fence starts at the post at 20.1, 9.0")
	var best := INF
	for i in range(back.size() - 1):
		var ab := back[i + 1] - back[i]
		var u := clampf((cross.back() - back[i]).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, cross.back().distance_to(back[i] + ab * u))
	_check(best < 0.1, "the cross fence ends on the barn fence: %.2f m away" % best)
	for i in range(cross.size() - 1):
		_check(cross[i].distance_to(cross[i + 1]) < 3.6, "cross fence posts are at most 3.6 m apart (%d)" % i)
	var post := Vector3(20.1, 0.0, 9.0)
	var short_gate := main.get_node("BackFences/DuckPen_Gate_Short") as Node3D
	var latch := short_gate.to_global(Vector3(short_gate.get("width"), 0.0, 0.0))
	_check(Vector2(latch.x, latch.z).distance_to(Vector2(post.x, post.z)) < 0.2, "the short gate's open end is on the post")
	_check(Vector2(short_gate.global_position.x, short_gate.global_position.z).distance_to(Vector2(22.7, 9.6)) < 0.05, "the short gate hangs from the end of the pen fence")
	var north_gate := main.get_node("BackFences/DuckPen_Gate_North") as Node3D
	_check(absf(north_gate.global_position.x - post.x) < 0.1 and north_gate.global_position.z < post.z - 2.0, "the north gate's hinge is directly north of the post")
	var north_latch := north_gate.to_global(Vector3(north_gate.get("width"), 0.0, 0.0))
	_check(Vector2(north_latch.x, north_latch.z).distance_to(Vector2(post.x, post.z)) < 0.2, "the north gate latches on the post")

	# Solid walls and an open bay at the north end of the pen-side (east) front.
	var space := root.world_3d.direct_space_state
	var door := DuckHouse.door_span()
	var east_x := DuckHouse.DEPTH * 0.5
	var south_z := (door.y + DuckHouse.LENGTH * 0.5) * 0.5
	var hit_wall := _ray(space, house, Vector3(east_x + 1.0, 0.8, south_z), Vector3(east_x - 1.0, 0.8, south_z))
	_check(not hit_wall.is_empty(), "the front is solid south of the bay")
	var mid_door := (door.x + door.y) * 0.5
	var hit_door := _ray(space, house, Vector3(east_x + 1.0, 0.8, mid_door), Vector3(east_x - 1.0, 0.8, mid_door))
	_check(hit_door.is_empty(), "you can walk in through the bay")
	var hit_back := _ray(space, house, Vector3(-east_x - 1.0, 0.8, 0.0), Vector3(0.0, 0.8, 0.0))
	_check(not hit_back.is_empty(), "the back (west) wall is solid")
	for sz in [-1.0, 1.0]:
		var end_hit := _ray(space, house, Vector3(0.0, 0.8, sz * (DuckHouse.LENGTH * 0.5 + 1.0)), Vector3(0.0, 0.8, 0.0))
		_check(not end_hit.is_empty(), "the end wall at z %.0f is solid" % sz)
	_check(not _ray(space, house, Vector3(0.0, 3.5, 0.0), Vector3(0.0, 0.5, 0.0)).is_empty(), "there is a roof")

	# The two tanks sit where they show in the aerial photo, the first the bigger.
	var t1 := house.get_node("Tank1") as Node3D
	var t2 := house.get_node("Tank2") as Node3D
	var mid := (Vector2(t1.global_position.x, t1.global_position.z) + Vector2(t2.global_position.x, t2.global_position.z)) * 0.5
	_check(mid.distance_to(Vector2(12.9, 17.6)) < 0.3, "the tanks are centred on 12.9, 17.6: %s" % mid)
	var big := (t1.get_child(0) as MeshInstance3D).mesh.get_aabb().size
	var small := (t2.get_child(0) as MeshInstance3D).mesh.get_aabb().size
	_check(big.x * big.z > small.x * small.z, "one tank is larger than the other")
	_check(absf(t1.position.x - t2.position.x) > 1.2, "the tanks don't overlap")
	# The roof slopes down to the back (west): its underside is lower there.
	_check(DuckHouse.roof_height(-DuckHouse.DEPTH * 0.5) < DuckHouse.roof_height(DuckHouse.DEPTH * 0.5), "the roof is low at the back, high at the front")

	_done()

func _ray(space: PhysicsDirectSpaceState3D, house: Node3D, from_local: Vector3, to_local: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(house.to_global(from_local), house.to_global(to_local))
	return space.intersect_ray(q)
