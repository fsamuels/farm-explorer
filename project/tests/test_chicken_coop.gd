extends SceneTree
## Tests for the chicken coop (D-164). Run headless from project/:
##   godot --headless -s res://tests/test_chicken_coop.gd

const Coop := preload("res://scripts/chicken_coop.gd")
const TimeOfDayScript := preload("res://scripts/time_of_day.gd")

var _failures := 0

func _init() -> void:
	_run.call_deferred()

func _check(cond: bool, what: String) -> void:
	if not cond:
		_failures += 1
		push_error("FAIL: " + what)

## Height of the roof's top surface at local z, by a ray from above.
func _roof_y(coop: Node3D, space: PhysicsDirectSpaceState3D, z: float) -> float:
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(coop.to_global(Vector3(0.0, 5.0, z)), coop.to_global(Vector3(0.0, 0.0, z))))
	if hit.is_empty():
		return -1.0
	return coop.to_local(hit.position).y

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
	var coop := main.get_node("Buildings/ChickenCoop") as Node3D
	_check(coop != null, "the chicken coop is in the scene")
	_check(coop.is_in_group("chicken_coop"), "the coop is in its group")
	_check(Vector2(coop.global_position.x, coop.global_position.z).distance_to(Vector2(48.7, -14.6)) < 0.01, "it stands at 48.7, -14.6")
	_check(absf(Coop.WIDTH - 2.438) < 0.01 and absf(Coop.DEPTH - 1.829) < 0.01, "8 ft wide by 6 ft deep")

	# The door faces the farmhouse.
	var house := main.get_node("Buildings/House") as Node3D
	var front := Vector2(coop.global_transform.basis.z.x, coop.global_transform.basis.z.z).normalized()
	var to_house := (Vector2(house.global_position.x, house.global_position.z) - Vector2(coop.global_position.x, coop.global_position.z)).normalized()
	_check(front.dot(to_house) > 0.9, "the front (door side) is on the house side")
	var south_wall := Vector2(house.global_transform.basis.x.x, house.global_transform.basis.x.z).normalized()
	var coop_x := Vector2(coop.global_transform.basis.x.x, coop.global_transform.basis.x.z).normalized()
	_check(absf(coop_x.dot(south_wall)) > 0.999, "the coop is parallel to the house's south wall")
	_check(front.dot(-Vector2(house.global_transform.basis.z.x, house.global_transform.basis.z.z).normalized()) > 0.999, "the door side is square to the south wall, on the house side")
	_check(Coop.door_span().y - Coop.door_span().x >= 0.8, "the doorway is wide enough to walk through")
	_check(coop.door_outside().distance_to(Vector2(house.global_position.x, house.global_position.z)) < Vector2(coop.global_position.x, coop.global_position.z).distance_to(Vector2(house.global_position.x, house.global_position.z)), "outside the door is nearer the house than the coop's middle")

	# Its map footprint is named, hidden, non-solid, and matches the coop.
	var footprint := main.get_node("Buildings/Chicken Coop") as Node3D
	_check(footprint != null and footprint.is_in_group("map_building"), "the coop has a named map footprint")
	_check(Vector2(footprint.global_position.x, footprint.global_position.z).distance_to(Vector2(coop.global_position.x, coop.global_position.z)) < 0.01, "footprint and coop share a centre")
	_check(absf(footprint.global_transform.basis.x.length() - Coop.WIDTH) < 0.02 and absf(footprint.global_transform.basis.z.length() - Coop.DEPTH) < 0.02, "footprint is the coop's size")
	_check(footprint.global_transform.basis.z.normalized().dot(coop.global_transform.basis.z.normalized()) > 0.999, "footprint and coop face the same way")

	# It is built and has solid walls and a roof, and the doorway is clear.
	var walls := coop.get_node_or_null("Walls") as StaticBody3D
	_check(walls != null and walls.get_child_count() > 10, "the coop has solid walls")
	_check(coop.get_node_or_null("DoorLeaf") != null, "the coop has a door")
	var space := coop.get_world_3d().direct_space_state
	var span := Coop.door_span()
	var mid := (span.x + span.y) * 0.5
	var a := coop.to_global(Vector3(mid, 0.9, Coop.DEPTH * 0.5 + 0.6))
	var b := coop.to_global(Vector3(mid, 0.9, 0.0))
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(a, b))
	_check(hit.is_empty(), "nothing blocks the doorway")
	var c := coop.to_global(Vector3(Coop.WIDTH * 0.5 - 0.3, 0.9, Coop.DEPTH * 0.5 + 0.6))
	var d := coop.to_global(Vector3(Coop.WIDTH * 0.5 - 0.3, 0.9, 0.0))
	_check(not space.intersect_ray(PhysicsRayQueryParameters3D.create(c, d)).is_empty(), "the front wall beside the door is solid")

	# The roof is high at the front (the door side) and slopes down to the back.
	var hx := Coop.WIDTH * 0.5
	var hz := Coop.DEPTH * 0.5
	var top_hi := _roof_y(coop, space, hz - 0.3)
	var top_lo := _roof_y(coop, space, -hz + 0.3)
	_check(top_hi > top_lo + 0.1, "the roof is higher at the door side than at the back")
	_check(absf(top_hi - Coop.roof_height(hz - 0.3)) < 0.12 and absf(top_lo - Coop.roof_height(-hz + 0.3)) < 0.12, "the roof sits on the walls")
	var roof_mat := (walls.get_child(walls.get_child_count() - 2) as MeshInstance3D).material_override as StandardMaterial3D
	_check(roof_mat.albedo_color.v > 0.6 and absf(roof_mat.albedo_color.r - roof_mat.albedo_color.b) < 0.12, "the roof is a light, silvery galvanized grey")
	# The door leaf swings out the front, not into the run.
	var leaf := coop.get_node("DoorLeaf") as Node3D
	var free_end := leaf.to_global(Vector3(-Coop.DOOR_WIDTH + 0.04, 0.0, 0.0))
	_check(coop.to_local(free_end).z > Coop.DEPTH * 0.5 + 0.2, "the open door leaf is outside the front wall")
	# Under the roosting house the back and outer end are closed.
	var xh := -hx + Coop.HOUSE_WIDTH * 0.5
	var back := space.intersect_ray(PhysicsRayQueryParameters3D.create(coop.to_global(Vector3(xh, 0.5, -Coop.DEPTH * 0.5 - 0.5)), coop.to_global(Vector3(xh, 0.5, 0.0))))
	_check(not back.is_empty(), "the back under the roosting house is closed")
	var end := space.intersect_ray(PhysicsRayQueryParameters3D.create(coop.to_global(Vector3(-hx - 0.5, 0.5, 0.0)), coop.to_global(Vector3(0.0, 0.5, 0.0))))
	_check(not end.is_empty(), "the outer end under the roosting house is closed")
	# The footprint sits at the coop's ground.
	_check(absf(footprint.global_position.y - (coop.global_position.y + 1.15)) < 0.3, "the footprint is at the coop's ground level")

	# The run's fence leaves the house, runs round the coop and joins the back-yard
	# fence; the old back-yard fence no longer passes the coop.
	var run := _fence_points(main, "ChickenRun_Fence")
	_check(run[0].distance_to(Vector2(61.2, -18.2)) < 1.0, "the run fence starts at the house")
	for corner in [Vector2(56.6, -2.9), Vector2(35.2, -10.4)]:
		var near := false
		for p in run:
			near = near or p.distance_to(corner) < 0.05
		_check(near, "the run fence has a post at the corner %s" % corner)
	_check(run.back().distance_to(Vector2(37.5, -18.4)) < 0.3, "the run fence ends near 37.5, -18.4")
	for i in run.size() - 1:
		_check(run[i].distance_to(run[i + 1]) < 3.6, "the run fence has a post at least every 3.6 m (span %d)" % i)
	var yard := _fence_points(main, "BackYard_South")
	var gate := main.get_node("BackFences/ChickenRun_Gate") as Node3D
	var hinge := Vector2(gate.global_position.x, gate.global_position.z)
	var latch_world := gate.to_global(Vector3(gate.get("width"), 0.0, 0.0))
	_check(hinge.distance_to(Vector2(35.4, -19.8)) < 0.05, "the gate is hinged on the post at 35.4, -19.8")
	_check(yard.back().distance_to(hinge) < 0.05, "the back-yard fence ends at the gate's hinge post")
	_check(Vector2(latch_world.x, latch_world.z).distance_to(run.back()) < 0.1, "the gate's open end is on the post where the run fence ends")
	for p in yard:
		_check(p.x < 38.0, "no back-yard fence point stays east of the join")
	var here := Vector2(coop.global_position.x, coop.global_position.z)
	_check(Geometry2D.is_point_in_polygon(here, PackedVector2Array(run)), "the coop stands inside the run fence")

	# The chickens roam the yard and keep an earlier, longer night than the ducks (D-166).
	var Wander := preload("res://scripts/wander.gd")
	var tod := main.get_node("TimeOfDay")
	tod.clock_running = false
	var hen := main.get_node("Flock/Hen1") as Node3D
	var flock := main.get_node("Flock") as Node3D
	_check(Vector2(flock.global_position.x, flock.global_position.z).distance_to(Vector2(45.0, -14.0)) < 0.01, "the flock lives in the yard by the coop")
	_check(hen.evening_routine and hen.routine_group == &"chicken_coop", "hens follow the sleep routine, in the coop")
	_check(main.get_node("Flock/Rooster").evening_routine, "so does the rooster")
	_check(hen.roost_hour < Wander.PEN_HOUR and hen.roost_hour < TimeOfDayScript.hour_of("sunset"), "hens go to bed before the ducks' pen time, before sunset")
	_check(hen.release_hour > Wander.RELEASE_HOUR, "hens get up later than the ducks")
	_check(Wander.phase_for(7.0, hen.pen_hour, hen.roost_hour, hen.release_hour) == Wander.Phase.ROOST, "still shut in at 7:00 when the ducks are out")
	_check(Wander.phase_for(18.0, hen.pen_hour, hen.roost_hour, hen.release_hour) == Wander.Phase.ROOST, "already in at 18:00")
	_check(Wander.phase_at(18.0) == Wander.Phase.FREE, "when the ducks are still out")
	# By day they wander the yard, inside the fence and never through the coop.
	tod.hour = 12.0
	hen.move_speed = 4.0
	var walk: Array[Vector2] = []
	var stray := 0
	var in_coop := 0
	var last := Vector2(hen.global_position.x, hen.global_position.z)
	for i in 3000:
		hen._process(0.1)
		var hp := Vector2(hen.global_position.x, hen.global_position.z)
		walk.append(hp)
		for k in run.size() - 1:
			if Geometry2D.segment_intersects_segment(last, hp, run[k], run[k + 1]) != null:
				stray += 1
		last = hp
		if coop.is_inside(hp):
			in_coop += 1
	_check(stray == 0, "a hen never crosses the yard's fence by day (%d crossings)" % stray)
	_check(in_coop == 0, "a hen never walks through the coop by day (%d steps)" % in_coop)
	# Evening: round to the door and in, through the doorway only.
	tod.hour = 18.5
	walk.clear()
	for i in 1500:
		hen._process(0.1)
		walk.append(Vector2(hen.global_position.x, hen.global_position.z))
	var hp2: Vector2 = walk[-1]
	_check(hp2.distance_to(coop.roost_point()) <= 1.0, "the hen is in the coop at 18:30 (%s)" % hp2)
	_check(_wall_crossings(coop, walk) == 0, "it went in by the door, not through a wall")
	# Morning, later than the ducks: still shut in at 7:00, out at 8:00 by the door.
	tod.hour = 7.0
	for i in 100:
		hen._process(0.1)
	_check(coop.is_inside(Vector2(hen.global_position.x, hen.global_position.z)), "the hen is still in at 7:00")
	tod.hour = 8.0
	walk.clear()
	walk.append(Vector2(hen.global_position.x, hen.global_position.z))
	for i in 600:
		hen._process(0.1)
		walk.append(Vector2(hen.global_position.x, hen.global_position.z))
	_check(not coop.is_inside(walk[-1]), "the hen is out at 8:00")
	_check(_wall_crossings(coop, walk) == 0, "it came out by the door (%d wall crossings, ends %s)" % [_wall_crossings(coop, walk), walk[-1]])
	# Routes from the back of the coop go round it.
	var behind: Vector2 = coop.world_xz(Vector2(0.0, -2.5))
	var detour: Array[Vector2] = coop.route_to_pen_front(behind)
	_check(detour.size() == 2, "from behind the coop, round a corner and the front corner")

	print("chicken_coop: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures else 0)

## How many times a path of world points passes in or out of the coop through a
## wall rather than the doorway.
func _wall_crossings(coop: Node, path: Array) -> int:
	var walls := 0
	var door: Vector2 = Coop.door_span()
	for i in range(1, path.size()):
		var a: Vector2 = path[i - 1]
		var b: Vector2 = path[i]
		for k in 20:
			var p: Vector2 = a.lerp(b, k / 20.0)
			var q: Vector2 = a.lerp(b, (k + 1) / 20.0)
			if coop.is_inside(p) != coop.is_inside(q):
				var m: Vector2 = coop.local_xz((p + q) * 0.5)
				if not (m.y > 0.0 and m.x > door.x and m.x < door.y):
					walls += 1
	return walls
