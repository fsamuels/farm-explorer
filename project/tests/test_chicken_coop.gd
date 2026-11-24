extends SceneTree
## Tests for the chicken coop (D-164). Run headless from project/:
##   godot --headless -s res://tests/test_chicken_coop.gd

const Coop := preload("res://scripts/chicken_coop.gd")

var _failures := 0

func _init() -> void:
	_run.call_deferred()

func _check(cond: bool, what: String) -> void:
	if not cond:
		_failures += 1
		push_error("FAIL: " + what)

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
	_check(front.dot(to_house) > 0.99, "the front (door side) faces the house")
	var yaw := Coop.facing_yaw(Vector2(48.7, -14.6), Vector2(61.77, -31.3))
	_check(absf(angle_difference(yaw, coop.rotation.y)) < 0.02, "its yaw matches facing_yaw toward the house")
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

	print("chicken_coop: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures else 0)
