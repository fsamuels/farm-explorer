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
	_check(pen.front().distance_to(Vector2(11.3, 17.313)) < 0.05, "pen fence starts at 11.3, 17.31, just west of the tanks (D-163)")
	_check(pen.back().distance_to(Vector2(22.7, 9.6)) < 0.05, "pen fence ends at 22.7, 9.6")
	var corner_ok := false
	for p in pen:
		if p.distance_to(Vector2(19.8, 19.9)) < 0.05:
			corner_ok = true
	_check(corner_ok, "pen fence turns at 19.8, 19.9")
	for i in range(pen.size() - 1):
		_check(pen[i].distance_to(pen[i + 1]) < 3.6, "pen fence posts are at most 3.6 m apart (%d)" % i)

	# The house's south wall is on the fence line, with an opening of about 2 m to
	# the fence's end, which stands just west of the bigger tank.
	var line_dir := (Vector2(19.8, 19.9) - Vector2(10.6, 17.1)).normalized()
	var line_n := Vector2(-line_dir.y, line_dir.x)
	var south_mid := centre + south * DuckHouse.LENGTH * 0.5
	_check(absf((south_mid - Vector2(11.3, 17.313)).dot(line_n)) < 0.2, "the south wall lies on the pen fence line")
	var south_east := south_mid + along * DuckHouse.DEPTH * 0.5
	var opening := south_east.distance_to(Vector2(11.3, 17.313))
	_check(opening > 1.7 and opening < 2.3, "about a 2 m opening between the house and the fence: %.2f m" % opening)
	var tank := main.get_node("Buildings/DuckHouse/Tank1") as Node3D
	var tank_west := Vector2(tank.global_position.x, tank.global_position.z) - along * 0.75
	var post_to_tank := (tank_west - Vector2(11.3, 17.313)).dot(along)
	_check(post_to_tank > 0.0 and post_to_tank < 0.4, "the post is just west of the bigger tank: %.2f m" % post_to_tank)

	# The west fence runs from the house's west side nearly north to the middle of the Back Barn.
	var back := _fence_points(main, "DuckPen_West")
	var house_nw := centre - south * DuckHouse.LENGTH * 0.5 - along * DuckHouse.DEPTH * 0.5
	_check(back.front().distance_to(house_nw) < 0.5, "the west fence starts at the house's north-west corner: %s vs %s" % [back.front(), house_nw])
	var barn := main.get_node("Buildings/Back Barn") as Node3D
	var barn_front := barn.global_transform * Vector3(0.0, 0.0, 0.5)
	_check(back.back().distance_to(Vector2(barn_front.x, barn_front.z)) < 0.5, "the west fence ends in the middle of the Back Barn's south wall")
	var bearing := rad_to_deg((back.back() - back.front()).angle_to(Vector2(0.0, -1.0)))
	_check(absf(bearing) < 16.0, "the west fence runs almost due north: %.1f degrees off" % bearing)

	# Two closed areas (D-157): the duck pen with the willows north of it, and the
	# Back Barn pen, with a little alley between them that has a gate at each end
	# and is open to the east.
	# Each joint below is a shared post.
	_check(main.get_node_or_null("BackFences/DuckPen_Cross") == null, "no fence from the 20.1, 9.0 post west to the barn fence")
	var pen_east_end: Vector2 = pen.back()
	var duck_gate := main.get_node("BackFences/DuckPen_Gate") as Node3D
	var barn_gate := main.get_node("BackFences/BackBarnPen_Gate") as Node3D
	var alley_w := _fence_points(main, "DuckPen_Alley_West")
	var barn_n := _fence_points(main, "BackBarnPen_North")
	var barn_e := _fence_points(main, "BackBarnPen_East")
	var barn_s := _fence_points(main, "BackBarnPen_South")
	var duck_hinge := _flat(duck_gate.global_position)
	var duck_latch := _flat(duck_gate.to_global(Vector3(duck_gate.get("width"), 0.0, 0.0)))
	var barn_hinge := _flat(barn_gate.global_position)
	var barn_latch := _flat(barn_gate.to_global(Vector3(barn_gate.get("width"), 0.0, 0.0)))

	# The two gates: parallel, hinged on the eastern posts, open ends to the west.
	_check(duck_hinge.distance_to(Vector2(22.7, 9.6)) < 0.05, "the duck pen gate hangs on the post at 22.7, 9.6")
	_check(duck_latch.distance_to(Vector2(20.1, 9.0)) < 0.1, "the duck pen gate's open end is on the post at 20.1, 9.0")
	_check(barn_hinge.distance_to(Vector2(23.6, 5.8)) < 0.15, "the Back Barn pen gate hangs on the post at 23.6, 5.9")
	_check(absf(barn_latch.x - 20.1) < 0.2 and barn_latch.y < 9.0 - 3.0, "the Back Barn pen gate's open end is directly north of the 20.1, 9.0 post")
	_check((duck_latch - duck_hinge).normalized().dot((barn_latch - barn_hinge).normalized()) > 0.99, "the two gates are parallel")
	_check(duck_hinge.x > duck_latch.x and barn_hinge.x > barn_latch.x, "both hinges are on the eastern posts")
	_check(pen_east_end.distance_to(duck_hinge) < 0.05, "duck pen: the east fence meets the gate")

	# Alley: a gate at each end, a fence on its west side, open to the east.
	_check(main.get_node_or_null("BackFences/DuckPen_Alley_East") == null, "alley: no fence between the two hinge posts")
	_check(alley_w.front().distance_to(barn_latch) < 0.1 and alley_w.back().distance_to(duck_latch) < 0.1, "alley: the west side joins the two open-end posts")

	# Back Barn pen: barn -> north -> east -> gate -> south -> west fence -> barn.
	var barn_se := barn.global_transform * Vector3(0.5, 0.0, 0.5)
	for q in barn_n:
		_check(q.distance_to(Vector2(26.3, -10.3)) > 0.5, "no stray post at 26.3, -10.3 (an artifact in the image)")
	_check(barn_n.front().distance_to(_flat(barn_se)) < 0.6, "Back Barn pen: the north fence starts at the barn's SE corner")
	_check(_dist_to_line(barn_e.front(), barn_n) < 0.05, "Back Barn pen: the north and east fences meet (no gap)")
	_check(barn_e.back().distance_to(barn_hinge) < 0.05, "Back Barn pen: the east fence meets the gate")
	_check(barn_s.front().distance_to(barn_latch) < 0.1, "Back Barn pen: the gate closes on the south fence")
	_check(_dist_to_line(barn_s.back(), back) < 0.1, "Back Barn pen: the south fence meets the west fence")

	# The Front Pond teleport point lands you at 109.4, -18.6 facing 150 degrees.
	var pond_pad := main.get_node("TransportPads/Pad_FrontPond")
	var player_ := main.get_node("Player") as Node3D
	pond_pad.receive(player_)
	_check(_flat(player_.global_position).distance_to(Vector2(109.4, -18.6)) < 0.05, "Front Pond: you land at 109.4, -18.6")
	_check(absf(fposmod(rad_to_deg(-player_.global_rotation.y), 360.0) - 150.0) < 0.5, "Front Pond: you face 150 degrees")

	# The Back Barn teleport point faces 333 degrees.
	var pad := main.get_node("TransportPads/Pad_BackBarn")
	_check(is_equal_approx(pad.facing_bearing, 333.0), "the Back Barn point faces 333 degrees")
	var player := main.get_node("Player") as Node3D
	pad.receive(player)
	var bearing_now := fposmod(rad_to_deg(-player.global_rotation.y), 360.0)
	_check(absf(bearing_now - 333.0) < 0.5, "arriving there you face 333 degrees: %.1f" % bearing_now)
	_check(Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(12.0, 22.2)) < 0.5, "and you land in the same spot as before")

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

func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)

## Distance from `p` to the nearest point of polyline `line`.
func _dist_to_line(p: Vector2, line: Array[Vector2]) -> float:
	var best := INF
	for i in range(line.size() - 1):
		var ab := line[i + 1] - line[i]
		var u := clampf((p - line[i]).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(line[i] + ab * u))
	return best

func _ray(space: PhysicsDirectSpaceState3D, house: Node3D, from_local: Vector3, to_local: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(house.to_global(from_local), house.to_global(to_local))
	return space.intersect_ray(q)
