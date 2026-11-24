extends SceneTree
## Tests for the carved ground (D-140): scripts/terrain_math.gd, the generated
## scripts/water_data.gd and the Terrain node in main.tscn. Run headless from project/:
##   godot --headless -s res://tests/test_terrain.gd

const TerrainMath := preload("res://scripts/terrain_math.gd")
const WaterData := preload("res://scripts/water_data.gd")
const TRACE := "res://../docs/gis/water-features-340732310005.json"

var _failures := 0

func _init() -> void:
	_test_level_ground()
	_test_ditch()
	_test_pond()
	_test_walkable_slopes()
	_test_buried_runs_are_not_carved()
	_test_data_matches_trace()
	await _test_scene()
	print("terrain: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures else 0)

func _check(cond: bool, what: String) -> void:
	if not cond:
		_failures += 1
		push_error("FAIL: " + what)

func _near(a: float, b: float, what: String, eps := 0.02) -> void:
	_check(absf(a - b) <= eps, "%s: got %s, want %s" % [what, a, b])

func _test_level_ground() -> void:
	for p in [Vector2(0, -60), Vector2(200, 0), Vector2(150, 40), Vector2(-120, 100), Vector2(300, 150)]:
		_near(TerrainMath.height_at(p.x, p.y), 0.0, "level ground at %s" % p, 0.0001)

func _test_ditch() -> void:
	var depth := WaterData.DITCH_DEPTH
	# On the road-side run's centerline (255, 10) and the south run's (160, 69.7): full depth.
	_near(TerrainMath.height_at(255.0, 10.0), -depth, "road-side ditch bottom")
	_near(TerrainMath.height_at(160.0, 69.7), -depth, "south ditch bottom")
	# Across the channel the ground rises: bottom, midway up the bank, lip, level beyond.
	var mid := TerrainMath.height_at(255.0 + (TerrainMath.DITCH_BOTTOM_HALF + TerrainMath.DITCH_TOP_HALF) * 0.5, 10.0)
	_check(mid < -0.2 and mid > -depth + 0.2, "half way up the bank is part way out: %s" % mid)
	_near(TerrainMath.height_at(255.0 + TerrainMath.DITCH_TOP_HALF + 0.05, 10.0), 0.0, "ground just past the lip", 0.001)
	_near(TerrainMath.height_at(255.0 + 5.0, 10.0), 0.0, "ground 5 m off the ditch", 0.0001)
	# The ditch is 2-3 feet deep (0.61-0.91 m).
	_check(depth >= 0.6 and depth <= 0.92, "ditch depth is 2-3 ft: %s" % depth)
	# The weir end is cut too, and the profile never cuts the other way.
	_check(TerrainMath.height_at(WaterData.WEIR.x, WaterData.WEIR.y + 3.0) < -0.5, "ditch reaches the weir")
	for r in [0.0, 0.1, 0.3, 0.6, 1.0, 1.3, 1.5, 3.0]:
		var d := TerrainMath.ditch_profile(r)
		_check(d >= 0.0 and d <= depth + 0.0001, "ditch profile in range at r=%s: %s" % [r, d])

func _test_pond() -> void:
	var depth := WaterData.POND_DEPTH
	# Deepest in the middle lobe and the west lobe, 10-15 ft (3.05-4.57 m) as the owner said.
	_near(TerrainMath.height_at(66.0, 26.0), -depth, "middle lobe floor")
	_near(TerrainMath.height_at(-28.0, 19.0), -depth, "west lobe floor")
	_check(depth >= 3.0 and depth <= 4.6, "pond depth is 10-15 ft: %s" % depth)
	# The narrow neck between the lobes is shallower than the lobes but still cut.
	var neck := TerrainMath.height_at(22.0, 37.0)
	_check(neck < -1.0 and neck > -depth + 0.2, "the neck is shallower than the lobes: %s" % neck)
	# Outside the outline is level; the outline reaches about x=131 in the east and x=-55 in the west.
	_near(TerrainMath.height_at(66.0, 60.0), 0.0, "level south of the middle lobe", 0.0001)
	_check(TerrainMath.pond_sdf(128.0, -9.0) < 0.0, "pond reaches x=128 in the east")
	_check(TerrainMath.pond_sdf(-53.0, 12.0) < 0.0, "pond reaches x=-53 in the west")
	_check(TerrainMath.pond_sdf(140.0, -15.0) > 0.0, "pond ends before x=140")
	_check(TerrainMath.pond_sdf(-65.0, 12.0) > 0.0, "pond ends before x=-65")
	# Never cuts upward, and the rim is level.
	for p in [Vector2(100, 5), Vector2(50, 30), Vector2(0, 33), Vector2(-40, 15), Vector2(10, 20)]:
		_check(TerrainMath.height_at(p.x, p.y) <= 0.0, "pond never rises above level at %s" % p)

## Steepest slope anywhere the player can walk: stay under 45 degrees so they can climb out.
func _test_walkable_slopes() -> void:
	var worst_ditch := 0.0
	var x := 250.0
	while x < 260.0:
		worst_ditch = maxf(worst_ditch, absf(TerrainMath.height_at(x + 0.05, 10.0) - TerrainMath.height_at(x, 10.0)) / 0.05)
		x += 0.05
	_check(worst_ditch < 0.95, "ditch banks are under 45 degrees: slope %s" % worst_ditch)
	_check(worst_ditch > 0.4, "the ditch banks are real banks: slope %s" % worst_ditch)
	var worst_pond := 0.0
	var step := 0.5
	var px := -60.0
	while px < 135.0:
		var pz := -15.0
		while pz < 50.0:
			var h := TerrainMath.height_at(px, pz)
			worst_pond = maxf(worst_pond, absf(TerrainMath.height_at(px + step, pz) - h) / step)
			worst_pond = maxf(worst_pond, absf(TerrainMath.height_at(px, pz + step) - h) / step)
			pz += 0.5
		px += 0.5
	_check(worst_pond < 1.0, "pond banks are under 45 degrees: slope %s" % worst_pond)

func _test_buried_runs_are_not_carved() -> void:
	# The driveway culvert and the pipe to the pond run under level ground.
	_near(TerrainMath.height_at(258.2, -46.0), 0.0, "ground over the driveway culvert", 0.0001)
	_near(TerrainMath.height_at(59.4, 55.0), 0.0, "ground over the buried pipe", 0.0001)
	_near(TerrainMath.height_at(63.0, 65.5), 0.0, "ground over the pipe where it turns north", 0.0001)
	# The pipe reaches the pond's south bank.
	_check(TerrainMath.pond_sdf(59.4, 38.0) < 3.0, "the pipe meets the pond bank")
	_check(WaterData.PIPE_SEGMENTS.size() == 12, "culvert + two pipe legs: %s numbers" % WaterData.PIPE_SEGMENTS.size())

## water_data.gd is generated from docs/gis/water-features-*.json; fail if it drifts.
func _test_data_matches_trace() -> void:
	var path := ProjectSettings.globalize_path(TRACE)
	if not FileAccess.file_exists(path):
		print("terrain: trace JSON not reachable from here, skipping the sync check")
		return
	var trace: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	_near(WaterData.DITCH_DEPTH, trace["ditch"]["depth_m"], "ditch depth matches the trace", 0.0001)
	_near(WaterData.DITCH_TOP_WIDTH, trace["ditch"]["width_m"], "ditch width matches the trace", 0.0001)
	_near(WaterData.DITCH_BOTTOM_WIDTH, trace["ditch"]["bottom_width_m"], "ditch bottom matches the trace", 0.0001)
	_near(WaterData.POND_DEPTH, trace["pond"]["depth_m"], "pond depth matches the trace", 0.0001)
	_near(WaterData.POND_BANK_RUN, trace["pond"]["bank_run_m"], "pond bank run matches the trace", 0.0001)
	_near(WaterData.WEIR.x, trace["weir"]["pos"][0], "weir x matches the trace", 0.001)
	var open_count := 0
	var buried_count := 0
	for seg in trace["ditch"]["segments"]:
		var n: int = seg["points"].size() - 1
		if seg.get("buried", false):
			buried_count += n
		else:
			open_count += n
	_check(WaterData.DITCH_SEGMENTS.size() == open_count * 4, "open ditch segments match the trace: %s vs %s" % [WaterData.DITCH_SEGMENTS.size() / 4, open_count])
	_check(WaterData.PIPE_SEGMENTS.size() == buried_count * 4, "buried segments match the trace")
	_check(WaterData.POND_SPINE.size() == trace["pond"]["spine_x_z_halfwidth_m"].size() * 3, "pond spine matches the trace")
	var first: Array = trace["pond"]["spine_x_z_halfwidth_m"][0]
	_near(WaterData.POND_SPINE[0], first[0], "pond spine starts where the trace does", 0.001)

## Fence posts are the thin cylinders (wires are cylinders too, but laid on their side).
func _is_post(node: MeshInstance3D) -> bool:
	return node.mesh is CylinderMesh and is_equal_approx((node.mesh as CylinderMesh).top_radius, 0.05)

func _test_scene() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	var terrain := main.get_node_or_null("Terrain") as StaticBody3D
	if terrain == null or not terrain.has_method("build"):
		_check(false, "terrain.gd compiled and is attached to Terrain")
		return
	var surface: MeshInstance3D = terrain.get_node("Surface")
	_check(surface.mesh is ArrayMesh and surface.mesh.get_surface_count() == 1, "the terrain has a mesh")
	_check(surface.material_override is ShaderMaterial, "the terrain is drawn with the imagery shader")
	_check(surface.is_in_group("map_imagery"), "the weather overlay finds the terrain")
	# Level quads dominate: the mesh stays small enough to build at start-up.
	var stats: Dictionary = terrain.get("stats")
	print("terrain: %d of %d tiles carved, %d vertices, %d triangles, built in %d ms" % [stats["carved_tiles"], stats["tiles"], stats["vertices"], stats["triangles"], stats["build_ms"]])
	_check(stats["carved_tiles"] > 100 and stats["carved_tiles"] < 1500, "a sensible number of tiles are carved: %s" % stats["carved_tiles"])
	_check(stats["triangles"] < 400000, "the mesh is small: %s triangles" % stats["triangles"])
	# Triangles wind the same way as the PlaneMesh they replace (else the ground is invisible from above).
	var plane_arrays := PlaneMesh.new().get_mesh_arrays()
	var pv: PackedVector3Array = plane_arrays[Mesh.ARRAY_VERTEX]
	var pi: PackedInt32Array = plane_arrays[Mesh.ARRAY_INDEX]
	var plane_up := (pv[pi[1]] - pv[pi[0]]).cross(pv[pi[2]] - pv[pi[0]]).y
	var arrays: Array = surface.mesh.surface_get_arrays(0)
	var mv: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var mi: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var ours_up := (mv[mi[1]] - mv[mi[0]]).cross(mv[mi[2]] - mv[mi[0]]).y
	_check(signf(plane_up) == signf(ours_up), "ground triangles face up like PlaneMesh's (%s vs %s)" % [plane_up, ours_up])
	var wrong := 0
	for t in range(0, mi.size(), 3):
		var up := (mv[mi[t + 1]] - mv[mi[t]]).cross(mv[mi[t + 2]] - mv[mi[t]]).y
		if signf(up) != signf(plane_up) and absf(up) > 1e-6:
			wrong += 1
	_check(wrong == 0, "every ground triangle faces up: %s do not" % wrong)

	# Standing on it: rays from above land on the carved surface.
	var space: PhysicsDirectSpaceState3D = terrain.get_world_3d().direct_space_state
	var cases := {
		"level ground": Vector2(0, -60),
		"ditch bottom, road side": Vector2(255, 10),
		"ditch bottom, south run": Vector2(160, 69.7),
		"middle lobe floor": Vector2(66, 26),
		"west lobe floor": Vector2(-28, 19),
		"over the driveway culvert": Vector2(258.2, -46),
	}
	for name in cases:
		var at: Vector2 = cases[name]
		var query := PhysicsRayQueryParameters3D.create(Vector3(at.x, 20, at.y), Vector3(at.x, -30, at.y))
		var hit: Dictionary = space.intersect_ray(query)
		_check(not hit.is_empty(), "ground under %s" % name)
		if not hit.is_empty():
			_near(hit.position.y, TerrainMath.height_at(at.x, at.y), "collision matches the mesh at %s" % name, 0.03)
	# A ray from far below the pond floor still stops at the safety floor, not the void.
	var low: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(66, -20, 26), Vector3(66, 5, 26)))
	_check(not low.is_empty(), "a safety floor sits under the pond")
	# The seam between flat and carved tiles has no gap: rays along a line that crosses it all hit.
	var misses := 0
	for i in 400:
		var x := 40.0 + i * 0.35
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 20, 17.3), Vector3(x, -30, 17.3)))
		if hit.is_empty():
			misses += 1
	_check(misses == 0, "no gaps along a line across the pond's north rim: %s misses" % misses)

	# The flat imagery planes are hidden but still there for the map.
	var ground: MeshInstance3D = main.get_node("Ground/MeshInstance3D")
	_check(not ground.visible and not main.get_node("FrontSectionOrthomosaic").visible, "the flat imagery planes are hidden")
	_check(ground.is_in_group("map_imagery") and ground.mesh is PlaneMesh, "the map can still read the flat planes")

	# Fence posts stand on the carved ground: each reaches down to the surface under it
	# and keeps its top at the usual height, so a post that lands in the ditch isn't left hanging.
	var posts := 0
	var floating := []
	for node in get_nodes_in_group("map_fence"):
		var path := node as Path3D
		if path == null:
			continue
		for child in path.get_children():
			var post := child as MeshInstance3D
			if post == null or not _is_post(post):
				continue
			posts += 1
			var world := path.to_global(post.position)
			var half: float = (post.mesh as CylinderMesh).height * 0.5
			var bottom: float = post.position.y - half
			var top: float = post.position.y + half
			if absf(bottom - minf(TerrainMath.height_at(world.x, world.z), 0.0)) > 0.01 or absf(top - 1.1) > 0.01:
				floating.append("%s at (%.1f, %.1f)" % [path.name, world.x, world.z])
	_check(posts > 100, "found the fence posts: %s" % posts)
	_check(floating.is_empty(), "fence posts reach the ground and keep their top: %s" % [floating])
	await _test_fence_in_ditch(main)
	await _test_wander_follows_ground(main)
	main.queue_free()

## A fence run across the ditch: the post in the channel goes down to the floor.
func _test_fence_in_ditch(main: Node) -> void:
	var fence := Path3D.new()
	fence.set_script(load("res://scripts/fence_path.gd"))
	fence.closed = false
	var curve := Curve3D.new()
	curve.add_point(Vector3(255.0, 0, 4.0))   # in the road-side ditch's bottom
	curve.add_point(Vector3(255.0, 0, 7.0))
	curve.add_point(Vector3(240.0, 0, 7.0))   # level pasture
	fence.curve = curve
	main.add_child(fence)
	await process_frame
	var posts: Array = []
	for child in fence.get_children():
		if child is MeshInstance3D and _is_post(child):
			posts.append(child)
	_check(posts.size() == 3, "three posts built: %s" % posts.size())
	if posts.size() == 3:
		_near(posts[0].position.y - posts[0].mesh.height * 0.5, -WaterData.DITCH_DEPTH, "a post in the ditch stands on the bottom")
		_near(posts[0].position.y + posts[0].mesh.height * 0.5, 1.1, "its top is at the usual height")
		_near(posts[2].position.y - posts[2].mesh.height * 0.5, 0.0, "a post on level ground stands at 0", 0.0001)
	fence.queue_free()

## Animals follow the carved ground instead of walking on air over it.
func _test_wander_follows_ground(main: Node) -> void:
	var animal := Node3D.new()
	animal.set_script(load("res://scripts/wander.gd"))
	animal.position = Vector3(249.0, 0, 20.0)
	animal.wander_radius = 0.0
	main.add_child(animal)
	await process_frame
	# Force a walk into the ditch bottom and check the height comes down with it.
	animal.target_position = Vector3(255.0, 0, 20.0)
	animal.is_walking = true
	animal.move_speed = 30.0
	for i in 2:   # two 3 m steps: 249 -> 252 -> 255, onto the ditch's centerline
		animal._process(0.1)
	_near(animal.position.y, TerrainMath.height_at(animal.global_position.x, animal.global_position.z), "an animal in the ditch stands on the floor")
	_check(animal.position.y < -0.3, "...which is below the level ground: %s" % animal.position.y)
	animal.queue_free()
