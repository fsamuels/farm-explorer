extends SceneTree
## Tests for the drivable cars (D-106): the pure math in scripts/vehicle_math.gd,
## then both cars in main.tscn driven with simulated key presses. Run headless
## from project/ (after the editor has imported assets once):
##   godot --headless -s res://tests/test_vehicle.gd

const VehicleMath := preload("res://scripts/vehicle_math.gd")
const EngineSound := preload("res://scripts/engine_sound.gd")
const WheelBuilder := preload("res://scripts/wheel_builder.gd")

var _failures := 0

func _init() -> void:
	_test_math()
	_test_engine_sound()
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
	_check(is_equal_approx(VehicleMath.to_mph(-10.0), 22.369362920544), "mph of reverse speed: %s" % VehicleMath.to_mph(-10.0))
	_check(absf(VehicleMath.to_mph(26.8224) - 60.0) < 0.001, "26.82 m/s is 60 mph")

	# Headlights: off in daylight (sun 1.0, dawn 0.8), full at dusk / night
	# (0.25-0.3), fading in between, never outside 0..1.
	_check(VehicleMath.headlight_demand(1.0) == 0.0, "headlights off at noon")
	_check(VehicleMath.headlight_demand(0.8) == 0.0, "headlights off at dawn")
	_check(VehicleMath.headlight_demand(0.3) == 1.0, "headlights full at night")
	_check(VehicleMath.headlight_demand(0.25) == 1.0, "headlights full at dusk")
	_check(is_equal_approx(VehicleMath.headlight_demand(0.55), 0.5), "headlights half on at 0.55")
	_check(VehicleMath.headlight_demand(0.0) == 1.0 and VehicleMath.headlight_demand(5.0) == 0.0, "headlight level is clamped")

	var offsets := VehicleMath.exit_offsets(-0.4, 0.1, 0.95, 2.3, 0.7)
	_check(offsets.size() == 8, "four sides and four corners")
	_check(offsets[0].x < -1.5 and offsets[1].x > 1.5, "driver's side (left) first, then right")
	_check(offsets[2].z > 2.9 and offsets[3].z < -2.9, "then behind, then in front")
	_check(absf(offsets[4].x) > 1.5 and absf(offsets[4].z) > 2.9, "then the corners")

func _test_engine_sound() -> void:
	var tops := PackedFloat32Array([6.0, 11.0, 17.0, 24.0])
	_check(EngineSound.gear_for_speed(0.0, tops) == 0, "gear 1 at rest")
	_check(EngineSound.gear_for_speed(-8.0, tops) == 1, "reverse speed picks a gear by magnitude")
	_check(EngineSound.gear_for_speed(99.0, tops) == 3, "top gear is the last")
	_check(is_equal_approx(EngineSound.rpm_for_speed(0.0, tops, 900.0, 6000.0), 900.0), "idle at rest")
	_check(is_equal_approx(EngineSound.rpm_for_speed(24.0, tops, 900.0, 6000.0), 6000.0), "redline at top speed")
	var before := EngineSound.rpm_for_speed(5.99, tops, 900.0, 6000.0)
	var after := EngineSound.rpm_for_speed(6.01, tops, 900.0, 6000.0)
	_check(after < before - 1500.0, "revs drop at the 1-2 shift: %s -> %s" % [before, after])
	_check(EngineSound.rpm_for_speed(9.0, tops, 900.0, 6000.0) > EngineSound.rpm_for_speed(7.0, tops, 900.0, 6000.0), "revs climb within a gear")
	_check(is_equal_approx(EngineSound.firing_hz(6000.0, 4), 200.0), "4 cylinders at 6000 rpm fire 200 times a second")
	_check(is_equal_approx(EngineSound.firing_hz(6000.0, 6), 300.0), "6 cylinders fire 300 times a second")

	var synth := EngineSound.new(4)
	var buf := synth.render(4000, 3000.0, 1.0)
	var peak := 0.0
	var energy := 0.0
	for v in buf:
		peak = maxf(peak, absf(v.x))
		energy += v.x * v.x
	_check(buf.size() == 4000, "render returns the frames asked for")
	_check(peak <= 1.0 and peak > 0.1, "audio is audible and never clips: peak %s" % peak)
	_check(energy / 4000.0 > 0.005, "audio is not silent")
	# The note repeats every two firing periods (half-order burble): the signal
	# should match itself at that lag and not at an unrelated one.
	var period := EngineSound.MIX_RATE / EngineSound.firing_hz(3000.0, 4)
	_check(_autocorr(buf, int(round(period * 2.0))) > 0.8, "pitch matches the firing frequency (%s)" % _autocorr(buf, int(round(period * 2.0))))
	_check(_autocorr(buf, int(round(period * 1.37))) < 0.6, "and not an unrelated lag (%s)" % _autocorr(buf, int(round(period * 1.37))))
	var quiet_buf := EngineSound.new(4).render(4000, 3000.0, 0.0)
	var quiet := 0.0
	for v in quiet_buf:
		quiet += v.x * v.x
	_check(quiet < energy, "less throttle is quieter")

func _autocorr(buf: PackedVector2Array, lag: int) -> float:
	var num := 0.0
	var den := 0.0
	for i in range(1000, buf.size() - lag):
		num += buf[i].x * buf[i + lag].x
		den += buf[i].x * buf[i].x
	return num / maxf(den, 0.0001)

func _test_wheel_builder() -> void:
	# A car with a "wheel" triangle at each corner, all in one mesh.
	var car := Node3D.new()
	root.add_child(car)
	var mesh := ArrayMesh.new()
	var verts := PackedVector3Array()
	var centers := [Vector3(-0.7, 0.3, -1.2), Vector3(0.7, 0.3, -1.2), Vector3(-0.7, 0.3, 1.0), Vector3(0.7, 0.3, 1.0)]
	for c: Vector3 in centers:
		verts.append_array([c + Vector3(0, 0.3, 0), c + Vector3(0, -0.3, 0.3), c + Vector3(0, -0.3, -0.3)])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	car.add_child(mi)
	var wheels := WheelBuilder.build([mi], car)
	_check(wheels.size() == 4, "four wheels from one mesh: %d" % wheels.size())
	for w in wheels:
		var want: Vector3 = centers[w.quadrant]
		_check((w.center as Vector3).distance_to(want + Vector3(0, 0, 0)) < 0.01, "wheel %d centre %s vs %s" % [w.quadrant, w.center, want])
		_check(w.front == (want.z < 0.0), "wheel %d front flag" % w.quadrant)
		_check(absf(w.radius - 0.3) < 0.01, "wheel %d radius %s" % [w.quadrant, w.radius])
		var arr: Array = (w.meshes[0] as ArrayMesh).surface_get_arrays(0)
		_check((arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() == 3, "wheel %d keeps just its own triangle" % w.quadrant)
	car.queue_free()
	_test_wheel_builder_mirrored()

## A mesh under a mirroring transform keeps its faces pointing the same way.
func _test_wheel_builder_mirrored() -> void:
	var car := Node3D.new()
	root.add_child(car)
	var a := Vector3(0.7, 0.0, -1.2)
	var b := Vector3(0.7, 0.4, -1.2)
	var c := Vector3(0.7, 0.0, -0.8)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([a, b, c])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.scale = Vector3(-1, 1, 1)
	car.add_child(mi)
	var wheels := WheelBuilder.build([mi], car)
	_check(wheels.size() == 1, "mirrored mesh gives one wheel")
	if wheels.size() == 1:
		var arr: Array = (wheels[0].meshes[0] as ArrayMesh).surface_get_arrays(0)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var baked := (v[idx[1]] - v[idx[0]]).cross(v[idx[2]] - v[idx[0]])
		var mirror := Basis.from_scale(Vector3(-1, 1, 1))
		var want := mirror * (b - a).cross(c - a)
		_check(baked.dot(want) > 0.0, "mirrored wheel faces keep their orientation")
	car.queue_free()

func _step(frames: int) -> void:
	for i in frames:
		await physics_frame

func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _run() -> void:
	_test_drive_hud()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _step(10)
	var player := main.get_node("Player")
	var space := main.get_viewport().world_3d.direct_space_state

	_test_wheel_builder()
	await _test_utv_placement(main, player)
	var names := ["BMW2002tii", "TR6", "CubCadetUTV"]
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
		if car_name == "CubCadetUTV":
			# Its barn is full of hay and posts: drive it on open ground.
			car.global_transform = Transform3D(Basis.IDENTITY, Vector3(90, 0.0, 150))
		car.speed = 0.0
		await _step(5)
		await _drive(main, player, car, car_name, space)

	await _test_utv(main, player)
	_done()

## The UTV is parked inside the Front Barn, facing out its open north side.
func _test_utv_placement(main: Node, player: CharacterBody3D) -> void:
	var utv: CharacterBody3D = main.get_node("CubCadetUTV")
	var shell: Node3D = main.get_node("Buildings/FrontBarnShell")
	var inside := shell.to_local(utv.global_position)
	_check(absf(inside.x) < shell.width / 2.0 - 1.0 and absf(inside.z) < shell.depth / 2.0 - 1.0,
			"the UTV starts inside the Front Barn: %s" % inside)
	_check((-utv.global_basis.z).dot(-shell.global_basis.z) > 0.99, "the UTV faces out the barn's north side")
	# Straight ahead is clear all the way out of the barn.
	utv.board(player)
	Input.action_press("move_forward")
	await _step(420)
	Input.action_release("move_forward")
	utv.release()
	var out := shell.to_local(utv.global_position)
	_check(out.z < -shell.depth / 2.0 - 0.5, "the UTV drives out of the barn's north side: %s" % out)
	utv.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, -50, 0))
	utv.speed = 0.0

## The Cub Cadet: parked in the Front Barn facing out its north side, and its
## dump bed tips with B only when nearly stopped, limiting speed while up.
func _test_utv(main: Node, player: CharacterBody3D) -> void:
	var utv: CharacterBody3D = main.get_node("CubCadetUTV")
	_check(utv.bed != null and utv.bed.name == "Bed" and utv.wheels.size() == 4, "the UTV has a bed and four wheels")
	_check(utv.max_speed < 14.0 and utv.label == "Cub Cadet 550", "the UTV is tuned slower than the cars")
	# Cub Cadet yellow and black: the Ranger body has yellow and none of its red, and
	# the bed is yellow too.
	var has_yellow := false
	var has_red := false
	var meshes := utv.get_node("Model").find_children("*", "MeshInstance3D", true, false)
	_check(utv.get_node_or_null("Model/Body") != null, "the Ranger body mesh loaded")
	for mi: MeshInstance3D in meshes:
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s) as StandardMaterial3D
			if m == null:
				continue
			var c := m.albedo_color
			var yellow_here := c.r > 0.9 and c.g > 0.7 and c.b < 0.2
			if yellow_here and mi.name == "Body":
				has_yellow = true
			has_red = has_red or (c.r > 0.5 and c.g < 0.3 and c.b < 0.3)
	_check(has_yellow and not has_red, "the UTV body is yellow, with no red (yellow %s, red %s)" % [has_yellow, has_red])
	var side := utv.get_node("Model/Bed/BedSide") as MeshInstance3D
	_check((side.material_override as StandardMaterial3D).albedo_color.r > 0.9, "the dump bed is yellow")

	utv.speed = 0.0
	player.global_position = utv.to_global(Vector3(-2.0, 0.2, 0.0))
	await _step(5)
	utv.interact(player)
	await _step(3)
	_check(utv.driver == player, "the UTV can be boarded")
	_check(utv.bed.rotation.x == 0.0, "the bed starts down")
	Input.action_press("dump_bed")
	await _step(2)
	Input.action_release("dump_bed")
	await _step(60)
	_check(utv.bed_target == 1.0 and utv.bed.rotation.x > deg_to_rad(10.0), "B tips the bed up (%s rad)" % utv.bed.rotation.x)
	await _step(120)
	_check(is_equal_approx(utv.bed.rotation.x, deg_to_rad(utv.bed_max_deg)), "the bed stops at its maximum (%s rad)" % utv.bed.rotation.x)
	# The bed's front rises: a point at the bed's front edge is higher than the hinge.
	var front_y: float = (utv.bed as Node3D).to_global(Vector3(0, 0, -1.0)).y
	_check(front_y > utv.bed.global_position.y + 0.4, "the raised bed's front is up")
	# With the bed up the top speed is limited.
	Input.action_press("move_forward")
	await _step(150)
	Input.action_release("move_forward")
	_check(utv.speed <= utv.BED_UP_MAX_SPEED + 0.01 and utv.speed > 1.0, "bed up limits speed (%s m/s)" % utv.speed)
	Input.action_press("move_back")
	await _step(150)
	Input.action_release("move_back")
	_check(utv.speed >= -utv.BED_UP_MAX_SPEED - 0.01 and utv.speed < -1.0, "bed up limits reverse too (%s m/s)" % utv.speed)
	Input.action_press("jump")
	await _step(90)
	Input.action_release("jump")
	Input.action_press("dump_bed")
	await _step(2)
	Input.action_release("dump_bed")
	await _step(200)
	_check(utv.bed.rotation.x == 0.0 and utv.bed_target == 0.0, "B lowers the bed again")
	# It won't tip while moving fast.
	Input.action_press("move_forward")
	await _step(90)
	_check(utv.speed > utv.BED_RAISE_MAX_SPEED + 1.0, "the UTV reaches %s m/s" % utv.speed)
	Input.action_press("dump_bed")
	await _step(2)
	Input.action_release("dump_bed")
	Input.action_release("move_forward")
	await _step(30)
	_check(utv.bed_target == 0.0 and utv.bed.rotation.x == 0.0, "the bed refuses to tip at speed")
	Input.action_press("jump")
	await _step(120)
	Input.action_release("jump")
	# Getting out with the bed up lowers it.
	Input.action_press("dump_bed")
	await _step(2)
	Input.action_release("dump_bed")
	await _step(5)
	utv.release()
	_check(utv.bed_target == 0.0, "releasing the UTV sends the bed down")
	player.leave_vehicle()
	await _step(5)

func _test_drive_hud() -> void:
	var Hud := preload("res://scripts/drive_hud.gd")
	_check(Hud.speed_text(37.4) == "37" and Hud.speed_text(-12.6) == "13" and Hud.speed_text(0.0) == "0", "speed text: %s %s" % [Hud.speed_text(37.4), Hud.speed_text(-12.6)])
	_check(Hud.rpm_text(3240.0) == "3.2k rpm" and Hud.rpm_text(-5.0) == "0.0k rpm", "rpm text: %s" % Hud.rpm_text(3240.0))

func _drive(main: Node, player: CharacterBody3D, car: CharacterBody3D, nm: String, space: PhysicsDirectSpaceState3D) -> void:
	# Park the player beside the car and look at it: the prompt target is the car.
	player.global_position = car.to_global(Vector3(-2.0, 0.2, 0.0))
	await _step(5)
	_check(car.get_interact_prompt().begins_with("Get in the "), "%s prompt: %s" % [nm, car.get_interact_prompt()])
	var start := car.global_transform
	_check(car.driver == null and player.vehicle == null, "%s starts empty" % nm)

	# Third person: the player faces the car and can target it just the same.
	player.third_person = true
	player._apply_view()
	player.global_basis = Basis(Vector3.UP, atan2(-(car.global_position.x - player.global_position.x), -(car.global_position.z - player.global_position.z)))
	player.head.rotation = Vector3(-0.3, 0, 0)
	await _step(6)
	_check(player._interact_target() == car, "%s can be targeted from third person" % nm)
	player.head.rotation = Vector3.ZERO
	car.interact(player)
	await _step(3)
	_check(player.vehicle == car and car.driver == player, "%s boarded" % nm)
	_check(not player.third_person and player.camera.current, "%s boarding from third person puts you at the wheel" % nm)
	player.drive_hud.show_drive(30.0, 3000.0, "")
	_check(player.drive_hud.visible and not player.interact_prompt.visible, "%s shows the quiet readout, not the big prompt" % nm)
	_check(not player.model.visible, "%s player body hidden while seated" % nm)

	# Headlights: dark by day, on at night while driven, off again by day.
	var tod := main.get_node("TimeOfDay")
	tod.set_preset("day", true)
	await _step(40)
	_check(car.headlight_level == 0.0 and not car._lamps[0].visible, "%s headlights off by day" % nm)
	_check(car._lamps.size() == 2 and car._lenses.size() == 2, "%s has two headlamps" % nm)
	tod.set_preset("night", true)
	await _step(60)
	_check(is_equal_approx(car.headlight_level, 1.0), "%s headlights fully on at night (%s)" % [nm, car.headlight_level])
	_check(car._lamps[0].visible and car._lamps[0].light_energy > 1.0 and car._lenses[0].visible, "%s lamps and lenses lit" % nm)
	_check(car._lamps[0].position.z < -1.5 and car._lamps[0].position.x < 0.0 and car._lamps[1].position.x > 0.0,
			"%s lamps sit at the front, one each side" % nm)
	tod.set_preset("day", true)
	await _step(60)
	_check(car.headlight_level == 0.0, "%s headlights fade out at day (%s)" % [nm, car.headlight_level])
	tod.set_preset("night", true)
	await _step(60)
	var seat: Vector3 = car.seat_transform(0.0).origin
	_check(_flat_dist(player.global_position, seat) < 0.05, "%s player rides at the seat" % nm)
	_check(absf(player.head.global_position.y - (car.global_position.y + car.eye_offset.y)) < 0.05,
			"%s camera at the driver's eye height" % nm)
	_check(absf(car.global_position.y - start.origin.y) < 0.03, "%s rests on the ground (y %s)" % [nm, car.global_position.y])

	_check(car.wheels.size() == 4, "%s has four wheels (%d)" % [nm, car.wheels.size()])
	var front := 0
	for w in car.wheels:
		front += 1 if w.front else 0
		_check(w.radius > 0.25 and w.radius < 0.45, "%s wheel radius %s" % [nm, w.radius])
	_check(front == 2, "%s two front wheels" % nm)
	var leftovers := 0
	for w in car.wheels:
		leftovers += (w.spin as Node3D).get_child_count()
	_check(leftovers >= 8, "%s wheels carry their meshes (%d)" % [nm, leftovers])
	var wheel0: Dictionary = car.wheels[0]
	var spin_total := 0.0
	var last_angle: float = (wheel0.spin as Node3D).rotation.x
	var travelled := 0.0
	var last_pos := car.global_position

	_check(car._audio.playing, "%s engine sound starts when seated" % nm)
	# Throttle: moves along its own -Z, not sideways, and the player comes with it.
	Input.action_press("move_forward")
	for i in 60:
		await physics_frame
		var angle: float = (wheel0.spin as Node3D).rotation.x
		spin_total += angle_difference(last_angle, angle)
		last_angle = angle
		travelled += _flat_dist(car.global_position, last_pos)
		last_pos = car.global_position
	_check(spin_total < -1.0, "%s wheel rolls forward (%s rad)" % [nm, spin_total])
	_check(absf(absf(spin_total) * wheel0.radius - travelled) < travelled * 0.15,
			"%s wheel roll matches distance: %s m rolled vs %s m driven" % [nm, absf(spin_total) * wheel0.radius, travelled])
	_check(car.engine_rpm > car.idle_rpm + 500.0, "%s revs rise with speed (%s rpm)" % [nm, car.engine_rpm])
	# Audio frames only flow where the audio driver gives the generator a playback.
	if car._playback != null:
		_check(car.frames_pushed > 0, "%s engine audio was generated (%d frames)" % [nm, car.frames_pushed])
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
	for w in car.wheels:
		if w.front:
			_check((w.steer as Node3D).rotation.y > 0.2, "%s front wheel turned left (%s)" % [nm, (w.steer as Node3D).rotation.y])
		else:
			_check(absf((w.steer as Node3D).rotation.y) < 0.001, "%s rear wheel stays straight" % nm)
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
	var body_half: float = (car.get_node("CollisionShape3D").shape as BoxShape3D).size.z / 2.0
	# The cars keep their original bar; the shorter UTV is judged by its own body.
	var min_gap := 0.25 + (body_half - 0.1 if nm == "CubCadetUTV" else 1.8)
	_check(gap > min_gap, "%s stops at the wall (gap %s)" % [nm, gap])
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
	_check(player.third_person and player.tp_camera.current, "%s getting out restores the third-person view" % nm)
	await _step(3)
	_check(not car._audio.playing, "%s engine stops when you get out" % nm)
	await _step(60)
	_check(car.headlight_level == 0.0 and not car._lamps[0].visible, "%s parked car's lamps go off at night" % nm)
	# The parked-lights option lights an empty car at night too, lens glow included.
	car.headlights_when_parked = true
	main.get_node("TimeOfDay").set_preset("night", true)
	await _step(60)
	_check(is_equal_approx(car.headlight_level, 1.0) and car._lamps[0].visible, "%s parked lamps light with headlights_when_parked" % nm)
	_check(car._lens_material.emission_energy_multiplier > 1.0, "%s lens glows with the lamps" % nm)
	car.headlights_when_parked = false
	await _step(60)
	_check(car.headlight_level == 0.0 and car._lens_material.emission_energy_multiplier == 0.0, "%s lamps and lens go dark again" % nm)
	main.get_node("TimeOfDay").set_preset("day", true)
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
