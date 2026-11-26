extends SceneTree
## Tests for the back-yard birches (D-192): the owner's four spots, three more
## in a line just west with the way south-west left open, the tree itself
## (tall, white, leaves overhead), and the trunks being solid. Run headless
## from project/:
##   godot --headless -s res://tests/test_back_yard_birches.gd

const Birches := preload("res://scripts/back_yard_birches.gd")
const Birch := preload("res://scripts/birch.gd")

var _failures := 0

func _init() -> void:
	_run.call_deferred()

func _check(cond: bool, what: String) -> void:
	if not cond:
		_failures += 1
		push_error("FAIL: " + what)

func _run() -> void:
	var spots := Birches.spots()
	_check(spots.size() == 7, "seven birches")
	_check(spots[0] == Vector2(24.5, -30.7) and spots[1] == Vector2(23.7, -33.6) and spots[2] == Vector2(23.8, -37.9) and spots[3] == Vector2(27.4, -40.6), "the owner's four spots")
	var first_west := INF
	for i in 4:
		first_west = minf(first_west, spots[i].x)
	for i in range(4, 7):
		_check(spots[i].x < first_west - 2.0 and spots[i].x > first_west - 8.0, "birch %d stands just west of the first line (x %.1f)" % [i + 1, spots[i].x])
		_check(spots[i].y < -30.0 and spots[i].y > -41.0, "birch %d is level with the first line (z %.1f)" % [i + 1, spots[i].y])
	# Nothing stands south of the first tree: the view south-west stays open.
	for p in spots:
		_check(p.y < -30.0, "no birch south of z -30 at %s" % p)
	for i in spots.size():
		for j in range(i + 1, spots.size()):
			_check(spots[i].distance_to(spots[j]) > 2.5, "birches %d and %d not on top of each other" % [i + 1, j + 1])

	var tree := Birch.build(1, 12.0)
	var bark := (tree.get_node("Bark") as MeshInstance3D).mesh.get_aabb()
	var leaves := (tree.get_node("Leaves") as MeshInstance3D).mesh.get_aabb()
	_check(bark.end.y > 10.5 and bark.end.y < 13.0, "a 12 m tree (%.1f)" % bark.end.y)
	_check(leaves.position.y > 1.8, "leaves no lower than 1.8 m (%.2f)" % leaves.position.y)
	_check(leaves.end.y > 9.5, "leaves reach the top (%.1f)" % leaves.end.y)
	_check(leaves.size.x < 9.0 and bark.size.x < 6.0, "a tall narrow tree (crown %.1f m across)" % leaves.size.x)
	var img := Birch.bark_image()
	var lum := 0.0
	for k in 64:
		lum += img.get_pixel(k, k).get_luminance() / 64.0
	_check(lum > 0.25 and lum < 0.6, "grey-brown bark, not white (%.2f)" % lum)
	_check(Birch.build(1, 12.0).get_node("Bark").mesh.get_aabb().is_equal_approx(bark), "the same seed grows the same tree")
	_check(not Birch.build(2, 12.0).get_node("Bark").mesh.get_aabb().is_equal_approx(bark), "another seed grows another tree")

	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10:
		await physics_frame
	var stand := main.get_node("BackYardBirches") as Node3D
	_check(stand.get_child_count() == 7, "seven birches in the scene")
	var west_fence := main.get_node("BackFences/BackYard_West") as Path3D
	for i in stand.get_child_count():
		var b := stand.get_child(i) as Node3D
		_check(is_equal_approx(b.global_position.x, spots[i].x) and is_equal_approx(b.global_position.z, spots[i].y), "%s at its spot" % b.name)
		for k in west_fence.curve.point_count:
			var f := west_fence.global_transform * west_fence.curve.get_point_position(k)
			_check(Vector2(f.x, f.z).distance_to(spots[i]) > 3.0, "%s clear of the west fence" % b.name)
	# Trunk stands on the ground and stops a person.
	var space := (main as Node3D).get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(spots[0].x + 1.0, 20, spots[0].y), Vector3(spots[0].x + 1.0, -5, spots[0].y))
	var hit := space.intersect_ray(q)
	_check(not hit.is_empty() and absf(hit.position.y) < 0.5, "the ground under the first birch is level")
	var side := PhysicsRayQueryParameters3D.create(Vector3(spots[0].x - 3, 1.0, spots[0].y), Vector3(spots[0].x + 3, 1.0, spots[0].y))
	var trunk_hit := space.intersect_ray(side)
	_check(not trunk_hit.is_empty() and (trunk_hit.collider as Node).name == "Trunk", "a trunk blocks the way")
	print("back yard birches: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures else 0)
