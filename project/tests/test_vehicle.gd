extends SceneTree
## Tests for the drivable cars (D-106): the pure math in scripts/vehicle_math.gd,
## then both cars in main.tscn driven with simulated key presses. Run headless
## from project/ (after the editor has imported assets once):
##   godot --headless -s res://tests/test_vehicle.gd

const VehicleMath := preload("res://scripts/vehicle_math.gd")

var _failures := 0

func _init() -> void:
	_test_math()
	_run.call_deferred()

func _check(cond: bool, what: String) -> void:
	if not cond:
		_failures += 1
		push_error("FAIL: " + what)

func _done() -> void:
	print("vehicle: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures else 0)

func _speed(s: float, throttle: float, handbrake := false) -> float:
	return VehicleMath.next_speed(s, throttle, handbrake, 0.1, 6.0, 14.0, 10.0, 2.0, 20.0, 5.0)

func _test_math() -> void:
	_check(is_equal_approx(_speed(0.0, 1.0), 0.6), "accelerates from rest")
	_check(is_equal_approx(_speed(19.9, 1.0), 20.0), "capped at max speed")
	_check(is_equal_approx(_speed(0.0, -1.0), -0.6), "reverses from rest")
	_check(is_equal_approx(_speed(-4.9, -1.0), -5.0), "reverse capped")
	_check(is_equal_approx(_speed(10.0, -1.0), 8.6), "opposing throttle brakes")
	_check(_speed(1.0, -1.0) == 0.0, "braking stops at zero, not through it")
	_check(is_equal_approx(_speed(10.0, 0.0), 9.8), "coasts down with drag")
	_check(_speed(0.1, 0.0) == 0.0, "drag stops at zero")
	_check(is_equal_approx(_speed(10.0, 1.0, true), 9.0), "handbrake ignores throttle")

	var max_steer := deg_to_rad(30.0)
	_check(VehicleMath.yaw_rate(0.0, 1.0, 2.5, max_steer, 8.0) == 0.0, "no turning at rest")
	_check(VehicleMath.yaw_rate(5.0, 1.0, 2.5, max_steer, 8.0) > 0.0, "steer left turns left")
	_check(VehicleMath.yaw_rate(5.0, -1.0, 2.5, max_steer, 8.0) < 0.0, "steer right turns right")
	_check(VehicleMath.yaw_rate(-5.0, 1.0, 2.5, max_steer, 8.0) < 0.0, "reversing flips the turn")
	_check(is_equal_approx(VehicleMath.yaw_rate(5.0, 0.0, 2.5, max_steer, 8.0), 0.0), "straight with no steer")
	var fast := VehicleMath.yaw_rate(30.0, 1.0, 2.5, max_steer, 8.0)
	_check(is_equal_approx(fast * 30.0, 8.0), "sideways acceleration capped at speed: %s" % (fast * 30.0))
	_check(is_equal_approx(VehicleMath.to_kmh(-10.0), 36.0), "km/h of reverse speed")

	var offsets := VehicleMath.exit_offsets(-0.4, 0.1, 0.95, 2.3, 0.7)
	_check(offsets.size() == 8, "four sides and four corners")
	_check(offsets[0].x < -1.5 and offsets[1].x > 1.5, "driver's side (left) first, then right")
	_check(offsets[2].z > 2.9 and offsets[3].z < -2.9, "then behind, then in front")
	_check(absf(offsets[4].x) > 1.5 and absf(offsets[4].z) > 2.9, "then the corners")

func _step(frames: int) -> void:
	for i in frames:
		await physics_frame

func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _step(10)
	var player := main.get_node("Player")
	var space := main.get_viewport().world_3d.direct_space_state

	var names := ["BMW2002tii", "TR6"]
	var homes := {}
	for car_name in names:
		homes[car_name] = main.get_node(car_name).global_transform
	for car_name in names:
		# Each car is tested alone, from where the scene parks it; the others
		# wait well away from its path.
		var slot := 0
		for other in names:
			if other != car_name:
				main.get_node(other).global_position = Vector3(120 + 30 * slot, 0.5, 150)
				slot += 1
		var car := main.get_node(car_name)
		car.global_transform = homes[car_name]
		car.speed = 0.0
		await _step(5)
		await _drive(main, player, car, car_name, space)

	_done()

func _drive(main: Node, player: CharacterBody3D, car: CharacterBody3D, nm: String, space: PhysicsDirectSpaceState3D) -> void:
	# Park the player beside the car and look at it: the prompt target is the car.
	player.global_position = car.to_global(Vector3(-2.0, 0.2, 0.0))
	await _step(5)
	_check(car.get_interact_prompt().begins_with("Get in the "), "%s prompt: %s" % [nm, car.get_interact_prompt()])
	var start := car.global_transform
	_check(car.driver == null and player.vehicle == null, "%s starts empty" % nm)

	car.interact(player)
	await _step(3)
	_check(player.vehicle == car and car.driver == player, "%s boarded" % nm)
	_check(not player.model.visible, "%s player body hidden while seated" % nm)
	var seat: Vector3 = car.seat_transform(0.0).origin
	_check(_flat_dist(player.global_position, seat) < 0.05, "%s player rides at the seat" % nm)
	_check(absf(player.head.global_position.y - (car.global_position.y + car.eye_offset.y)) < 0.05,
			"%s camera at the driver's eye height" % nm)
	_check(absf(car.global_position.y - start.origin.y) < 0.03, "%s rests on the ground (y %s)" % [nm, car.global_position.y])

	# Throttle: moves along its own -Z, not sideways, and the player comes with it.
	Input.action_press("move_forward")
	await _step(60)
	var heading := -start.basis.z
	var moved := car.global_position - start.origin
	_check(car.speed > 3.0, "%s accelerates (%s m/s)" % [nm, car.speed])
	_check(moved.dot(heading) > 2.0 and absf(moved.cross(heading).y) < 0.3,
			"%s drives forward along its nose: %s" % [nm, moved])
	_check(_flat_dist(player.global_position, car.seat_transform(0.0).origin) < 0.05, "%s player carried along" % nm)

	# Can't get out while moving.
	_check(not car.can_leave(), "%s is too fast to leave (%s)" % [nm, car.speed])
	player.leave_vehicle()
	_check(player.vehicle == car and car.driver == player, "%s stays seated while moving" % nm)

	# Steering left turns the car left (positive yaw).
	var yaw0 := car.rotation.y
	Input.action_press("move_left")
	await _step(40)
	Input.action_release("move_left")
	var left_turn := angle_difference(yaw0, car.rotation.y)
	_check(left_turn > 0.15, "%s turns left: %s" % [nm, left_turn])
	Input.action_press("move_right")
	await _step(80)
	Input.action_release("move_right")
	var right_turn := angle_difference(yaw0, car.rotation.y) - left_turn
	_check(right_turn < -0.15, "%s turns right: %s" % [nm, right_turn])
	Input.action_release("move_forward")

	# Handbrake stops it; then reverse moves it backwards.
	Input.action_press("jump")
	await _step(120)
	Input.action_release("jump")
	_check(absf(car.speed) < 0.1, "%s handbrake stops (%s)" % [nm, car.speed])
	Input.action_press("move_back")
	await _step(40)
	Input.action_release("move_back")
	_check(car.speed < -1.0, "%s reverses (%s)" % [nm, car.speed])
	Input.action_press("jump")
	await _step(60)
	Input.action_release("jump")

	# A wall ahead stops the car instead of letting it through.
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 4, 0.5)
	shape.shape = box
	wall.add_child(shape)
	main.add_child(wall)
	var ahead := -car.global_basis.z
	wall.global_transform = Transform3D(car.global_basis, car.global_position + ahead * 9.0 + Vector3(0, 2, 0))
	await _step(2)
	Input.action_press("move_forward")
	await _step(150)
	Input.action_release("move_forward")
	var gap := (wall.global_position - car.global_position).dot(ahead)
	_check(gap > 0.25 + 1.8, "%s stops at the wall (gap %s)" % [nm, gap])
	_check(absf(car.speed) < 3.0, "%s lost its speed on impact (%s)" % [nm, car.speed])
	wall.queue_free()
	Input.action_press("jump")
	await _step(60)
	Input.action_release("jump")

	# Can't get out when boxed in.
	var fence := StaticBody3D.new()
	for off in VehicleMath.exit_offsets(car.eye_offset.x, car.eye_offset.z, car.half_width, car.half_length, 0.7):
		var blocker := CollisionShape3D.new()
		var blocker_shape := BoxShape3D.new()
		blocker_shape.size = Vector3(1.4, 2.0, 1.4)
		blocker.shape = blocker_shape
		blocker.position = fence.to_local(car.to_global(off + Vector3(0, 1.0, 0)))
		fence.add_child(blocker)
	main.add_child(fence)
	fence.global_transform = Transform3D.IDENTITY
	for c in fence.get_children():
		c.global_position = c.position  # positions were computed in world space
	await _step(3)
	_check(car.find_exit_spot() == null, "%s boxed in has no exit spot" % nm)
	player.leave_vehicle()
	_check(player.vehicle == car, "%s stays seated when boxed in" % nm)
	fence.queue_free()
	await _step(3)

	# Getting out: beside the car, clear of it, walking again.
	player.leave_vehicle()
	await _step(5)
	_check(player.vehicle == null and car.driver == null, "%s left" % nm)
	_check(player.model.visible, "%s player body back" % nm)
	_check(not player.collision_shape.disabled, "%s player collision back" % nm)
	var local := car.to_local(player.global_position)
	_check(absf(local.x) > car.half_width or absf(local.z) > car.half_length,
			"%s player stands outside the body: %s" % [nm, local])
	_check(absf(player.head.position.y - 1.6) < 0.001, "%s head height restored" % nm)
	# Unoccupied cars sit still.
	var parked := car.global_position
	await _step(30)
	_check(_flat_dist(parked, car.global_position) < 0.01, "%s stays parked" % nm)
	# Parked, the car is solid: a ray down onto the roof hits it.
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			car.to_global(Vector3(0, 3, 0)), car.to_global(Vector3(0, 0.3, 0)), 1))
	_check(not hit.is_empty() and hit.collider == car, "%s is solid when parked: %s" % [nm, hit])
