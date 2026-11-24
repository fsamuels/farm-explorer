extends SceneTree
## Tests for the driveable world (D-148): real ground and named roads out to
## 5.6 km. scripts/world_math.gd, road_math.gd, the generated world_data.gd /
## road_data.gd, the World node's chunks, and the opened-up boundary. Run
## headless from project/:
##   godot --headless -s res://tests/test_world.gd

const WorldData := preload("res://scripts/world_data.gd")
const WorldMath := preload("res://scripts/world_math.gd")
const RoadData := preload("res://scripts/road_data.gd")
const RoadMath := preload("res://scripts/road_math.gd")
const WorldTerrain := preload("res://scripts/world_terrain.gd")

var _failures := 0

func _init() -> void:
	_test_data()
	_test_farm_stays_level()
	_test_mesh_matches_height()
	_test_chunks()
	_test_roads()
	_test_road_mesh()
	_test_driveable()
	await _test_scene()
	print("world: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures else 0)

func _check(cond: bool, what: String) -> void:
	if not cond:
		_failures += 1
		push_error("FAIL: " + what)

func _near(a: float, b: float, what: String, eps := 0.02) -> void:
	_check(absf(a - b) <= eps, "%s: got %s, want %s" % [what, a, b])

func _test_data() -> void:
	var h := WorldMath.heights()
	_check(h.size() == WorldData.NODES * WorldData.NODES, "one height per grid node: %s" % h.size())
	_check(WorldData.NODES == int(2.0 * WorldData.HALF / WorldData.CELL) + 1, "grid covers the square")
	_check(WorldData.HALF >= 4830.0, "the square reaches 3 miles (4.83 km): %s" % WorldData.HALF)
	_near(WorldMath.raw_height(0.0, 0.0), 0.0, "the origin is the datum", 1.0)
	# Real relief out here: the area runs a few hundred metres top to bottom.
	var lo := INF
	var hi := -INF
	for y in h:
		lo = minf(lo, y)
		hi = maxf(hi, y)
	_check(lo > -100.0 and hi < 300.0, "relief is plausible: %s .. %s" % [lo, hi])
	_check(hi - lo > 30.0, "there is real relief to drive over: %s" % (hi - lo))
	_check(WorldData.ORIGIN_ELEVATION > 100.0 and WorldData.ORIGIN_ELEVATION < 200.0, "origin elevation is the farm's: %s" % WorldData.ORIGIN_ELEVATION)

func _test_farm_stays_level() -> void:
	for p in [Vector2(0, 0), Vector2(100, -100), Vector2(250, 0), Vector2(-200, 200), Vector2(300, 220)]:
		var y := WorldMath.height_at(p.x, p.y)
		_check(y <= 0.0 and y >= -WorldMath.FARM_SINK - 0.0001, "farm ground at %s is level (just under 0): %s" % [p, y])
	# Far outside the farm square the real relief is back in full.
	var far := Vector2(3000.0, 2000.0)
	_near(WorldMath.height_at(far.x, far.y), WorldMath.raw_height(far.x, far.y), "relief returns beyond the blend", 0.0001)
	# No step anywhere along lines that leave the farm square in each direction.
	for dir in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1), Vector2(1, 1).normalized()]:
		var prev := WorldMath.height_at(0.0, 0.0)
		var worst := 0.0
		for k in range(1, 1200):
			var p: Vector2 = Vector2(49.4, -33.7) + dir * k
			var y := WorldMath.height_at(p.x, p.y)
			worst = maxf(worst, absf(y - prev))
			prev = y
		_check(worst < 0.5, "ground is continuous leaving the farm along %s: biggest metre-step %s" % [dir, worst])

func _test_mesh_matches_height() -> void:
	# Every triangle of a chunk lies on `height_at`'s surface, so a road or wheel
	# placed with it sits on the collider. Use a chunk with real relief.
	var c := WorldMath.chunk_at(2000.0, 1500.0)
	var data := WorldMath.chunk_arrays(c.x, c.y)
	var faces: PackedVector3Array = data.faces
	_check(faces.size() == WorldMath.CHUNK_CELLS * WorldMath.CHUNK_CELLS * 6, "a full chunk has two triangles a cell: %s" % faces.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var corner := WorldMath.chunk_corner(c.x, c.y)
	for n in 200:
		var x := corner.x + rng.randf_range(0.0, WorldMath.chunk_size())
		var z := corner.y + rng.randf_range(0.0, WorldMath.chunk_size())
		var found := false
		for t in range(0, faces.size(), 3):
			var a := faces[t]
			var b := faces[t + 1]
			var d := faces[t + 2]
			var bary := _barycentric(Vector2(x, z), Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(d.x, d.z))
			if bary.x >= -1e-6 and bary.y >= -1e-6 and bary.z >= -1e-6:
				var y: float = a.y * bary.x + b.y * bary.y + d.y * bary.z
				_near(y, WorldMath.height_at(x, z), "mesh height at (%.1f, %.1f)" % [x, z], 0.0015)
				found = true
				break
		_check(found, "a triangle covers (%.1f, %.1f)" % [x, z])
	# Triangles wind the same way as a PlaneMesh's, so the ground shows from above.
	var plane_arrays := PlaneMesh.new().get_mesh_arrays()
	var pv: PackedVector3Array = plane_arrays[Mesh.ARRAY_VERTEX]
	var pi: PackedInt32Array = plane_arrays[Mesh.ARRAY_INDEX]
	var plane_up := (pv[pi[1]] - pv[pi[0]]).cross(pv[pi[2]] - pv[pi[0]]).y
	var wrong := 0
	for t in range(0, faces.size(), 3):
		var up := (faces[t + 1] - faces[t]).cross(faces[t + 2] - faces[t]).y
		if signf(up) != signf(plane_up):
			wrong += 1
	_check(wrong == 0, "every ground triangle faces up: %s do not" % wrong)

func _barycentric(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> Vector3:
	var v0 := b - a
	var v1 := c - a
	var v2 := p - a
	var den := v0.x * v1.y - v1.x * v0.y
	if absf(den) < 1e-12:
		return Vector3(-1, -1, -1)
	var v := (v2.x * v1.y - v1.x * v2.y) / den
	var w := (v0.x * v2.y - v2.x * v0.y) / den
	return Vector3(1.0 - v - w, v, w)

func _test_chunks() -> void:
	_check(WorldMath.chunk_count() == 35, "35 chunks a side: %s" % WorldMath.chunk_count())
	_check(WorldMath.chunk_at(0.0, 0.0) == Vector2i(17, 17), "origin chunk: %s" % WorldMath.chunk_at(0.0, 0.0))
	_check(WorldMath.chunk_at(6000.0, 0.0) == Vector2i(-1, -1), "outside the world has no chunk")
	var corner := WorldMath.chunk_corner(17, 17)
	_check(WorldMath.chunk_at(corner.x + 1.0, corner.y + 1.0) == Vector2i(17, 17), "a chunk's corner is inside it")
	var wanted := WorldTerrain.wanted_chunks(Vector2(0, 0), 2300.0)
	_check(wanted[0] == Vector2i(17, 17), "nearest chunk first: %s" % wanted[0])
	_check(wanted.size() > 100 and wanted.size() < 250, "a sensible number of chunks around the farm: %s" % wanted.size())
	for c in wanted:
		_check(WorldTerrain.chunk_distance(c, Vector2.ZERO) <= 2300.0, "wanted chunk %s is in range" % c)
	# At the world's edge only the chunks that exist are asked for.
	for c in WorldTerrain.wanted_chunks(Vector2(5590.0, 5590.0), 2300.0):
		_check(c.x < 35 and c.y < 35 and c.x >= 0 and c.y >= 0, "edge chunk %s exists" % c)
	# The farm square is covered by the farm's own ground: its interior cells have no world mesh.
	var farm_chunk := WorldMath.chunk_arrays(17, 17)
	_check(farm_chunk.faces.size() < WorldMath.CHUNK_CELLS * WorldMath.CHUNK_CELLS * 6, "cells inside the farm square are left to the farm's ground")

func _test_roads() -> void:
	var names: Array = RoadData.NAMES
	_check(names.has("Lowden-Gardena Rd"), "the road past the farm is there")
	_check(names.has("US Hwy 12"), "US 12 is there")
	_check(RoadData.ROADS.size() > 50, "main roads: %s" % RoadData.ROADS.size())
	for row in RoadData.ROADS:
		_check(row[4] >= 2 and row[3] + row[4] <= Marshalls.base64_to_raw(RoadData.POINTS_B64).size() / 8, "road %s has its points" % names[row[0]])
	# Every road is named, and none of the unnamed ones got in.
	for n in names:
		_check(String(n) != "", "road names are not empty")
	# Lowden-Gardena Rd runs down the farm's east side, in the asphalt of the aerial photo (x 270-280).
	var near := RoadMath.nearest(275.0, 0.0, 30.0)
	_check(not near.is_empty() and near.name == "Lowden-Gardena Rd", "the nearest road at the farm's east side is Lowden-Gardena Rd: %s" % [near])
	_check(near.get("distance", 99.0) < 6.0, "it passes within 6 m of the aerial photo's asphalt: %s" % near.get("distance", 99.0))
	# Every point has a surface read off the aerial photo: US highways and the road at the farm are
	# asphalt, and there is plenty of gravel too.
	var points := Marshalls.base64_to_raw(RoadData.POINTS_B64).size() / 8
	_check(Marshalls.base64_to_raw(RoadData.SURFACE_B64).size() == points, "one surface per point: %s for %s points" % [Marshalls.base64_to_raw(RoadData.SURFACE_B64).size(), points])
	var gravel := 0
	var total := 0
	for road in RoadMath.roads():
		for sf in road.surface:
			total += 1
			if sf == RoadMath.GRAVEL:
				gravel += 1
		if road.kind <= 1:
			_check(road.surface.count(RoadMath.GRAVEL) == 0, "%s is asphalt all along" % road.name)
	print("world: %.0f%% of road points read as gravel" % (100.0 * gravel / total))
	_check(gravel > total / 10 and gravel < total * 9 / 10, "a real mix of asphalt and gravel: %s of %s" % [gravel, total])
	var piece_here: Vector2i = RoadMath.pieces_in(WorldMath.chunk_at(275.0, 300.0))[0]
	_check(RoadMath.roads()[piece_here.x].surface[piece_here.y] == RoadMath.PAVED, "the road past the farm is asphalt")
	# A gravel road is narrower than an asphalt one.
	for road in RoadMath.roads():
		var g: int = road.surface.find(RoadMath.GRAVEL)
		var a: int = road.surface.find(RoadMath.PAVED)
		if g != -1 and a != -1 and road.kind == 2:
			_check(RoadMath.width_at(road, g) < RoadMath.width_at(road, a), "gravel is narrower than asphalt on %s" % road.name)
			break
	# Resampling keeps the ends and spaces the points.
	var line := PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 50)])
	var r := RoadMath.resample(line, 8.0)
	_check(r[0] == line[0] and r[r.size() - 1] == line[2], "resampling keeps the ends")
	for k in range(1, r.size() - 1):
		# Spacing is along the line, so the one point after the corner is closer in a straight line.
		_check(r[k].distance_to(r[k - 1]) <= 8.001, "resampled spacing at %s: %s" % [k, r[k].distance_to(r[k - 1])])
	_check(r.size() == 20, "100 m + 50 m at 8 m is 19 steps and a stub: %s points" % r.size())

func _test_road_mesh() -> void:
	var chunk := WorldMath.chunk_at(275.0, 300.0)
	var pieces := RoadMath.pieces_in(chunk)
	_check(not pieces.is_empty(), "the chunk south-east of the farm has road in it")
	var arrays := RoadMath.build_arrays(pieces)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	_check(v.size() == pieces.size() * 2 * RoadMath.ACROSS, "two cross-sections a piece")
	var plane_arrays := PlaneMesh.new().get_mesh_arrays()
	var pv: PackedVector3Array = plane_arrays[Mesh.ARRAY_VERTEX]
	var pi: PackedInt32Array = plane_arrays[Mesh.ARRAY_INDEX]
	var plane_up := (pv[pi[1]] - pv[pi[0]]).cross(pv[pi[2]] - pv[pi[0]]).y
	var wrong := 0
	for t in range(0, idx.size(), 3):
		var up := (v[idx[t + 1]] - v[idx[t]]).cross(v[idx[t + 2]] - v[idx[t]]).y
		if signf(up) != signf(plane_up):
			wrong += 1
	_check(wrong == 0, "every road triangle faces up: %s do not" % wrong)
	# The ribbon rides just above the ground everywhere.
	var lo := INF
	var hi := -INF
	for p in v:
		var above := p.y - WorldMath.height_at(p.x, p.z)
		lo = minf(lo, above)
		hi = maxf(hi, above)
	_check(lo >= RoadMath.LIFT - 0.0001 and hi <= RoadMath.LIFT + RoadMath.STACK * 11 + 0.0001, "road rides %s..%s m above the ground" % [lo, hi])

func _test_driveable() -> void:
	# A car can follow every named road in the world: no grade steeper than 17% over any 24 m,
	# measured on the ground the road is laid on (the mesh's own 20 m cells).
	var worst := 0.0
	var worst_name := ""
	var km := 0.0
	for road in RoadMath.roads():
		var pts: PackedVector2Array = road.points
		for k in range(0, pts.size() - 3, 3):
			var a := pts[k]
			var b := pts[k + 3]
			var run := a.distance_to(b)
			if run < 1.0:
				continue
			km += run / 1000.0
			var grade := absf(WorldMath.height_at(b.x, b.y) - WorldMath.height_at(a.x, a.y)) / run
			if grade > worst:
				worst = grade
				worst_name = road.name
	print("world: %.0f km of road sampled, steepest %.1f%% (%s)" % [km, worst * 100.0, worst_name])
	_check(km > 100.0, "100+ km of named road: %s" % km)
	_check(worst < 0.17, "no road steeper than 17%% over 24 m: %.1f%% on %s" % [worst * 100.0, worst_name])

func _test_scene() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 4:
		await process_frame
	var world := main.get_node_or_null("World")
	_check(world != null and world.has_method("update_around"), "world_terrain.gd is attached to World")
	if world == null or not world.has_method("update_around"):
		return
	_check(world.chunk_loaded(Vector2i(17, 17)), "the chunk on the farm loads at start")
	print("world: %d chunks loaded at start" % world.loaded_count())
	# Walls are gone: no fence on the road side, no wall of trees around the farm.
	_check(main.get_node_or_null("TreeLine") == null, "the treeline wall is gone")
	_check(main.get_node_or_null("Boundary/Fence_07") == null, "the fence across the road is gone")
	for fence in main.get_node("Boundary").get_children():
		var to_east: Vector3 = fence.global_transform * Vector3(fence.length * 0.5, 0.0, 0.0)
		var to_west: Vector3 = fence.global_transform * Vector3(-fence.length * 0.5, 0.0, 0.0)
		_check(maxf(to_east.x, to_west.x) < 264.5, "%s ends at the property line, not out across the road" % fence.name)

	# The world has an edge wall: a ray along the ground at the east edge hits it.
	var edge_ray := PhysicsRayQueryParameters3D.create(Vector3(5000.0, 100.0, 0.0), Vector3(6000.0, 100.0, 0.0))
	var wall: Dictionary = main.get_world_3d().direct_space_state.intersect_ray(edge_ray)
	_check(not wall.is_empty() and absf(wall.position.x - WorldData.HALF) < 0.5, "an invisible wall stands at the world's edge: %s" % [wall.get("position", "none")])

	# Drive away: move the focus 3 miles up the road and the ground follows.
	var far := Vector2(300.0, 4500.0)
	world.set_process(false)  # the test moves the focus itself; the camera stays at the farm
	world.update_around(far, true)
	var here := WorldMath.chunk_at(far.x, far.y)
	_check(world.chunk_loaded(here), "the chunk at 4.5 km loads")
	_check(not world.chunk_loaded(Vector2i(17, 17)), "the farm's chunk is dropped once you're far from it")
	await physics_frame
	await physics_frame
	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	for p in [Vector2(300.0, 4500.0), Vector2(150.0, 4000.0), Vector2(600.0, 4700.0)]:
		var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 400.0, p.y), Vector3(p.x, -400.0, p.y))
		var hit := space.intersect_ray(q)
		_check(not hit.is_empty(), "rays hit the ground at %s" % p)
		if not hit.is_empty():
			_near(hit.position.y, WorldMath.height_at(p.x, p.y), "collider height at %s" % p, 0.01)
	# And back: the farm is rebuilt on return.
	world.update_around(Vector2.ZERO, true)
	_check(world.chunk_loaded(Vector2i(17, 17)), "the farm's chunk comes back")
	_check(not world.chunk_loaded(here), "the far chunk is dropped on the way back")
	world.set_process(true)
	await _test_drive_hill(main, world)
	main.queue_free()

## Drive a car up the steepest stretch of named road within 3 km of the farm: it
## stays on the ground, follows the slope, and gets somewhere.
func _test_drive_hill(main: Node, world: Node) -> void:
	var best_from := Vector2.ZERO
	var best_dir := Vector2.ZERO
	var best_grade := 0.0
	for road in RoadMath.roads():
		var pts: PackedVector2Array = road.points
		for k in range(0, pts.size() - 14, 5):
			var a := pts[k]
			var b := pts[k + 12]
			if a.length() > 3000.0 or WorldMath.in_farm(a.x, a.y) or a.distance_to(b) < 90.0:
				continue
			var grade := (WorldMath.height_at(b.x, b.y) - WorldMath.height_at(a.x, a.y)) / a.distance_to(b)
			if absf(grade) > best_grade and absf(grade) < 0.1:
				best_grade = absf(grade)
				best_from = a
				best_dir = (b - a).normalized()
	_check(best_grade > 0.03, "there's a real hill road near the farm to test on: %.1f%%" % (best_grade * 100.0))
	print("world: hill test on a %.1f%% stretch at %s" % [best_grade * 100.0, best_from])
	var car: CharacterBody3D = main.get_node("BMW2002tii")
	var player: CharacterBody3D = main.get_node("Player")
	world.update_around(best_from, true)
	await physics_frame
	var start_y := WorldMath.height_at(best_from.x, best_from.y)
	# Facing along the road, uphill if it climbs.
	var yaw := atan2(-best_dir.x, -best_dir.y)
	car.global_transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(best_from.x, start_y + 0.6, best_from.y))
	car.speed = 0.0
	car.board(player)
	Input.action_press("move_forward")
	for i in 600:
		await physics_frame
	var here := Vector2(car.global_position.x, car.global_position.z)
	Input.action_release("move_forward")
	var moved := here.distance_to(best_from)
	var ground := WorldMath.height_at(here.x, here.y)
	print("world: car moved %.0f m at %.1f m/s, %.2f m over the ground, tilt %.1f deg" % [moved, car.speed, car.global_position.y - ground,
			rad_to_deg(car.global_basis.y.angle_to(WorldMath.normal_at(here.x, here.y)))])
	_check(moved > 120.0, "the car drove %.0f m along the hill road" % moved)
	_check(car.speed > 8.0, "and kept its speed on the hill: %.1f m/s" % car.speed)
	_check(car.global_position.y - ground < 1.5 and car.global_position.y - ground > -0.5, "the car is on the ground, %.2f m over it" % (car.global_position.y - ground))
	_check(car.global_basis.y.angle_to(WorldMath.normal_at(here.x, here.y)) < deg_to_rad(6.0), "the car sits on the slope, not level through it")
	car.release()
