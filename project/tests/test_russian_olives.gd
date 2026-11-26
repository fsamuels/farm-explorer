extends SceneTree
## Tests for the Russian olives (D-194, D-199): the line they follow, their 15
## to 25 ft heights, thin at the west, an old-growth forest with young trees
## under it along the House, thick at the east, clear of fences and buildings,
## and the tree itself (leaves, solid trunk). Run headless from
## project/:
##   godot --headless -s res://tests/test_russian_olives.gd

const Olives := preload("res://scripts/russian_olives.gd")
const Olive := preload("res://scripts/russian_olive.gd")

var _failures := 0

func _init() -> void:
	_run.call_deferred()

func _check(cond: bool, what: String) -> void:
	if not cond:
		_failures += 1
		push_error("FAIL: " + what)

func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)

func _run() -> void:
	var spots := Olives.spots()
	_check(spots.size() >= 60 and spots.size() <= 130, "a stand of trees (%d)" % spots.size())
	_check(spots == Olives.spots(), "the same spots every run")
	var line := Olives.END - Olives.START
	var across := Vector2(-line.normalized().y, line.normalized().x)
	var west := 0
	var forest := 0
	var east := 0
	var deep := 0
	for p in spots:
		var off := (p - Olives.START).dot(across)
		var stretch: Dictionary = Olives.stretch_at(p.x)
		_check(off >= -stretch.north - 0.01 and off <= stretch.south + 0.01, "%s stands in its band (%.1f m off the line)" % [p, off])
		_check(p.x >= Olives.START.x - 0.5 and p.x <= Olives.END.x + 5.0, "%s is within the line's length" % p)
		if p.x <= -5.0:
			west += 1
		elif p.x <= 95.0:
			forest += 1
			if off < -6.0:
				deep += 1
		else:
			east += 1
	# Per metre of line: thin in the west, a forest along the House, thick in the east.
	var w_rate := west / 49.0
	var f_rate := forest / 100.0
	var e_rate := east / 47.0
	_check(f_rate > e_rate * 2.0 and f_rate > w_rate * 4.0, "a forest along the House (%.2f per m, east %.2f, west %.2f)" % [f_rate, e_rate, w_rate])
	_check(e_rate > w_rate, "thicker at the east end than the west (%.2f vs %.2f)" % [e_rate, w_rate])
	_check(deep > 10, "the forest runs deep over the grove (%d trees more than 6 m north of the line)" % deep)

	var tree := Olive.build(7, 6.0)
	var bark := (tree.get_node("Bark") as MeshInstance3D).mesh.get_aabb()
	var leaves := (tree.get_node("Leaves") as MeshInstance3D).mesh.get_aabb()
	_check(leaves.size.x > 3.0 and leaves.size.x < 11.0, "a broad crown (%.1f m)" % leaves.size.x)
	_check(leaves.end.y > 3.5 and leaves.end.y < 9.5, "a 6 m tree reaches %.1f m" % leaves.end.y)
	_check(bark.size.y > 2.0, "stems rise (%.1f m)" % bark.size.y)
	_check(Olive.build(7, 6.0).get_node("Bark").mesh.get_aabb().is_equal_approx(bark), "the same seed grows the same tree")
	_check(not Olive.build(8, 6.0).get_node("Bark").mesh.get_aabb().is_equal_approx(bark), "another seed grows another tree")

	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10:
		await physics_frame
	var stand := main.get_node("RussianOlives") as Node3D
	_check(stand.get_child_count() == spots.size(), "a tree at every spot")
	var tallest := 0.0
	var shortest := INF
	var young := 0
	for i in stand.get_child_count():
		var t := stand.get_child(i) as Node3D
		var leaves_mi := t.get_node("Leaves") as MeshInstance3D
		var top := leaves_mi.mesh.get_aabb().end.y * leaves_mi.scale.y
		tallest = maxf(tallest, top)
		shortest = minf(shortest, top)
		if top < 4.6 and Olives.stretch_at(spots[i].x).get("forest", false):
			young += 1
	_check(tallest < 8.3 * 1.25 and tallest > 6.0, "the tallest is about 25 ft (%.1f m to the leaf tops)" % tallest)
	_check(shortest > 2.6, "the shortest, a young tree, is about 10 ft (%.1f m to the leaf tops)" % shortest)
	_check(young >= 8, "young trees coming up in the forest (%d)" % young)
	# Clear of every fence and building.
	var segs: Array = []
	for group_name in ["BackFences", "PastureFences", "TrackTeamFences"]:
		var group := main.get_node_or_null(group_name)
		if group == null:
			continue
		for path in group.get_children():
			if path is Path3D:
				var pts: Array[Vector2] = []
				for k in path.curve.point_count:
					var w: Vector3 = path.global_transform * path.curve.get_point_position(k)
					pts.append(Vector2(w.x, w.z))
				for k in pts.size() - 1:
					segs.append([pts[k], pts[k + 1], path.name])
	for i in stand.get_child_count():
		var p := spots[i]
		for s in segs:
			_check(_seg_dist(p, s[0], s[1]) > 1.2, "olive %d is clear of fence %s" % [i + 1, s[2]])
		for b in main.get_node("Buildings").get_children():
			if b is Node3D and b.get_child_count() > 0 and b.get_node_or_null("CollisionShape3D") != null:
				var local := (b as Node3D).to_local(Vector3(p.x, b.global_position.y, p.y))
				_check(absf(local.x) > 0.5 + 0.2 or absf(local.z) > 0.5 + 0.2, "olive %d is outside building %s" % [i + 1, b.name])
	# A trunk stops a person; the ground under it is where it stands.
	var space := (main as Node3D).get_world_3d().direct_space_state
	var first := stand.get_child(0) as Node3D
	var side := PhysicsRayQueryParameters3D.create(first.global_position + Vector3(-3, 1.0, 0), first.global_position + Vector3(3, 1.0, 0))
	var hit := space.intersect_ray(side)
	_check(not hit.is_empty() and (hit.collider as Node).name == "Trunk", "a trunk blocks the way")
	print("russian olives: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures else 0)
