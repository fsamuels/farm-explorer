extends SceneTree
## Tests for the back-yard shed (D-193): where it stands, its size, the red
## door at the east end, and that the walls are solid and the deck walkable.
## Run headless from project/:
##   godot --headless -s res://tests/test_back_yard_shed.gd

const Shed := preload("res://scripts/back_yard_shed.gd")
const Birches := preload("res://scripts/back_yard_birches.gd")

var _failures := 0

func _init() -> void:
	_run.call_deferred()

func _check(cond: bool, what: String) -> void:
	if not cond:
		_failures += 1
		push_error("FAIL: " + what)

func _run() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10:
		await physics_frame
	var shed := main.get_node("BackYardShed") as Node3D
	_check(Vector2(shed.global_position.x, shed.global_position.z).is_equal_approx(Shed.SPOT), "the shed is at its spot")
	var roof := (shed.get_node("Roof") as MeshInstance3D).mesh.get_aabb()
	_check(absf(roof.end.y - Shed.RIDGE_HEIGHT) < 0.05, "the ridge is %.1f m up (%.2f)" % [Shed.RIDGE_HEIGHT, roof.end.y])
	_check(roof.size.x > Shed.LENGTH and roof.size.z > Shed.WIDTH, "the roof overhangs the walls")
	var door := shed.get_node("Door") as MeshInstance3D
	var colour := (door.material_override as StandardMaterial3D).albedo_color
	_check(colour.r > 0.6 and colour.g < 0.2, "a red door")
	_check(door.global_position.x > shed.global_position.x + Shed.LENGTH / 2.0, "the door is on the east end")
	# Clear of the back-yard fences and of the birches.
	for fence_name in ["BackYard_West", "BackYard_North"]:
		var fence := main.get_node("BackFences/" + fence_name) as Path3D
		for k in fence.curve.point_count:
			var f := fence.global_transform * fence.curve.get_point_position(k)
			_check(Vector2(f.x, f.z).distance_to(Shed.SPOT) > 1.5, "the shed is clear of %s point %d" % [fence_name, k])
	for p in Birches.spots():
		_check(p.distance_to(Shed.SPOT) > 4.5, "the shed is clear of the birch at %s" % p)
	# Solid walls, and a deck you can walk onto.
	var space := (main as Node3D).get_world_3d().direct_space_state
	var at := Shed.SPOT
	var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x, 1.0, at.y + 3.0), Vector3(at.x, 1.0, at.y)))
	_check(not wall.is_empty() and absf(wall.position.z - (at.y + Shed.WIDTH / 2.0)) < 0.05, "the north-south wall is solid")
	var deck_x := at.x + Shed.LENGTH / 2.0 + Shed.DECK_REACH * 0.5
	var deck := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(deck_x, 3.0, at.y), Vector3(deck_x, -1.0, at.y)))
	_check(not deck.is_empty() and absf(deck.position.y - Shed.DECK_HEIGHT) < 0.02, "the deck top is %.2f m up" % Shed.DECK_HEIGHT)
	var toe_x := at.x + Shed.LENGTH / 2.0 + Shed.DECK_REACH + Shed.DECK_SLOPE * 0.5
	var toe := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(toe_x, 3.0, at.y), Vector3(toe_x, -1.0, at.y)))
	_check(not toe.is_empty() and toe.position.y > 0.02 and toe.position.y < Shed.DECK_HEIGHT, "a slope down from the deck's edge")
	print("back yard shed: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures else 0)
