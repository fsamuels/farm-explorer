extends SceneTree
## Tests for the super sprint and the transport points (D-131, D-139). Run headless from
## project/ (after the editor has imported assets once):
##   godot --headless -s res://tests/test_transport.gd

const PlayerScript := preload("res://scripts/player.gd")

## The points must sit this far inside the property line, metres.
const BOUNDARY_MARGIN := 15.0

var _failures := 0

func _init() -> void:
	_test_speed()
	_run.call_deferred()

func _check(cond: bool, what: String) -> void:
	if not cond:
		_failures += 1
		push_error("FAIL: " + what)

func _done() -> void:
	print("transport: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures else 0)

func _test_speed() -> void:
	_check(PlayerScript.move_speed(false, false) == PlayerScript.SPEED, "plain move speed")
	_check(PlayerScript.move_speed(false, true) == PlayerScript.SUPER_SPRINT_SPEED, "Ctrl super sprints")
	_check(PlayerScript.move_speed(true, false) == PlayerScript.WALK_SPEED, "Shift walks")
	_check(PlayerScript.move_speed(true, true) == PlayerScript.WALK_SPEED, "walking beats super sprint")
	_check(PlayerScript.SUPER_SPRINT_SPEED >= 3.0 * PlayerScript.SPEED, "super sprint is much faster than a sprint")
	_check(InputMap.has_action("super_sprint") and not InputMap.action_get_events("super_sprint").is_empty(), "super_sprint is bound to a key")

func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await physics_frame
	var player = main.get_node("Player")
	var pads: Array = main.get_node("TransportPads").get_children()
	_check(pads.size() >= 4, "several points: %d" % pads.size())

	# Boundary segments, for the "well inside the property" check.
	var segments: Array = []
	for fence in main.get_node("Boundary").get_children():
		var half: Vector3 = fence.global_transform.basis.x.normalized() * float(fence.get("length")) * 0.5
		segments.append([Vector2(fence.global_position.x - half.x, fence.global_position.z - half.z),
				Vector2(fence.global_position.x + half.x, fence.global_position.z + half.z)])

	var names := {}
	for pad in pads:
		_check(not names.has(pad.pad_name), "%s: name is unique" % pad.pad_name)
		names[pad.pad_name] = true
		for child in pad.find_children("*", "", true, false):
			_check(not (child is VisualInstance3D or child is CollisionObject3D), "%s is invisible: no meshes, lights or colliders" % pad.pad_name)
		for point in [pad.global_position, pad.arrival_spot()]:
			var here := Vector2(point.x, point.z)
			var nearest := INF
			var crossings := 0
			for seg in segments:
				nearest = minf(nearest, (Geometry2D.get_closest_point_to_segment(here, seg[0], seg[1]) - here).length())
				# Ray toward -X: an odd number of crossings means inside the parcel.
				if Geometry2D.segment_intersects_segment(here, here + Vector2(-1000.0, 0.0), seg[0], seg[1]) != null:
					crossings += 1
			_check(nearest >= BOUNDARY_MARGIN, "%s is %.1f m from the property line" % [pad.pad_name, nearest])
			_check(crossings % 2 == 1, "%s is inside the property (%d crossings)" % [pad.pad_name, crossings])

	# receive() lands you at the arrival spot, stopped, level, facing away (for a
	# point with no facing of its own; some, like Back Barn, set facing_bearing).
	var point = pads.filter(func(p): return p.facing_bearing < 0.0)[0]
	player.velocity = Vector3(5, 0, 5)
	player.get_node("Head").rotation.x = -1.0
	point.receive(player)
	var landed := Vector2(player.global_position.x, player.global_position.z)
	var want := Vector2(point.arrival_spot().x, point.arrival_spot().z)
	_check(landed.distance_to(want) < 0.01, "receive lands at the arrival spot")
	_check(player.velocity == Vector3.ZERO, "arrival stops you dead")
	_check(player.get_node("Head").rotation.x == 0.0, "arrival looks level")
	var facing := Vector2(-sin(player.global_rotation.y), -cos(player.global_rotation.y))
	var away := (landed - Vector2(point.global_position.x, point.global_position.z)).normalized()
	_check(facing.dot(away) > 0.99, "you arrive facing away from the point")
	_done()
