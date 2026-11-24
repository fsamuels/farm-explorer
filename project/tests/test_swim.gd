extends SceneTree
## Tests for swimming and the kayak (D-152): scripts/swim_math.gd (pure), the
## freestyle pose (swim_pose.gd) on the real player skeleton, then the player
## and the kayak in main.tscn on a full pond. Run headless from project/:
##   godot --headless -s res://tests/test_swim.gd

const SwimMath := preload("res://scripts/swim_math.gd")
const SwimPose := preload("res://scripts/swim_pose.gd")
const BoatBuilder := preload("res://scripts/boat_builder.gd")

## Deep water in the pond's middle lobe, and dry ground east of its rim.
const POND_MIDDLE := Vector2(-27.0, 19.0)
const DRY_GROUND := Vector2(2.0, 19.0)

var _failures := 0

func _init() -> void:
	_test_math()
	await _test_scene()
	print("swim: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures else 0)

func _check(cond: bool, what: String) -> void:
	if not cond:
		_failures += 1
		push_error("FAIL: " + what)

func _step(frames: int) -> void:
	for i in frames:
		await physics_frame

func _test_math() -> void:
	_check(not SwimMath.is_swimming(1.0, false), "knee-deep water is not swimming")
	_check(SwimMath.is_swimming(1.6, false), "deep water starts a swim")
	_check(SwimMath.is_swimming(1.4, true), "a swimmer stays swimming in the gap")
	_check(not SwimMath.is_swimming(1.4, false), "a walker stays walking in the gap")
	_check(not SwimMath.is_swimming(1.2, true), "shallow water ends a swim")
	_check(SwimMath.swim_speed(true) < SwimMath.swim_speed(false), "Shift slows the stroke")
	_check(SwimMath.swim_speed(false) < 3.0, "swimming is slower than running")
	var y := SwimMath.float_y(0.0, 0.0)
	_check(absf(y + SwimMath.DRAFT) < 0.05, "floats a draft below the surface: %s" % y)
	_check(SwimMath.float_velocity(-3.0, 0.0) == 4.0 and SwimMath.float_velocity(3.0, 0.0) == -4.0, "float speed is capped")
	_check(SwimMath.float_velocity(1.0, 1.0) == 0.0, "no float speed once at the surface")
	var p := SwimMath.advance_phase(0.95, SwimMath.STROKE_SECONDS * 0.1, true)
	_check(absf(p - 0.05) < 0.001, "the stroke phase wraps: %s" % p)
	_check(SwimMath.advance_phase(0.0, 1.0, false) < SwimMath.advance_phase(0.0, 1.0, true), "treading water ticks slower")

	# Freestyle: at phase 0 the left arm reaches ahead while the right, half a
	# cycle behind, is finishing its pull back by the hip; a quarter on, the left
	# arm is pulling down under the body and the right is swinging up over the water.
	var reach := SwimMath.arm_dirs(0.0, 1.0)
	var finish := SwimMath.arm_dirs(0.0, -1.0)
	_check(reach.upper.y > 0.9, "the left arm reaches forward: %s" % reach.upper)
	_check(finish.upper.y < -0.9, "the right arm is back by the hip: %s" % finish.upper)
	var pull := SwimMath.arm_dirs(0.25, 1.0)
	var recover := SwimMath.arm_dirs(0.25, -1.0)
	_check(pull.upper.z > 0.9, "mid-pull the arm points down at the floor: %s" % pull.upper)
	_check(recover.upper.z < -0.8 and recover.upper.x < -0.2, "mid-recovery the elbow is high and out to the side: %s" % recover.upper)
	var half_cycle: Vector3 = SwimMath.arm_dirs(0.75, -1.0).upper
	_check(absf(half_cycle.y - pull.upper.y) < 0.001 and absf(half_cycle.z - pull.upper.z) < 0.001, "the arms are half a cycle apart")
	_check(SwimMath.arm_dirs(0.999, 1.0).upper.distance_to(SwimMath.arm_dirs(0.0, 1.0).upper) < 0.05, "the stroke repeats smoothly")
	_check(SwimMath.elbow_bend(0.75) > SwimMath.elbow_bend(0.5) + 0.5, "the elbow bends in the recovery")
	var kick_l := SwimMath.leg_dirs(1.0 / 12.0, 1.0)
	var kick_r := SwimMath.leg_dirs(1.0 / 12.0, -1.0)
	_check(kick_l.thigh.z > 0.2 and kick_r.thigh.z < -0.2, "the legs flutter in opposition: %s %s" % [kick_l.thigh, kick_r.thigh])
	_check(SwimMath.leg_dirs(0.0, 1.0).thigh.y < -0.95, "the legs trail behind between kicks")
	_check(SwimMath.body_roll(0.0) > 0.5 and SwimMath.body_roll(0.5) < -0.5, "the body rolls side to side with the arms")
	_check(SwimMath.body_roll(0.25) == 0.0 or absf(SwimMath.body_roll(0.25)) < 0.001, "and is level between rolls")
	for i in 41:
		var ph := float(i) / 40.0
		for side in [-1.0, 1.0]:
			for d: Vector3 in [SwimMath.arm_dirs(ph, side).upper, SwimMath.arm_dirs(ph, side).lower, SwimMath.leg_dirs(ph, side).thigh, SwimMath.leg_dirs(ph, side).calf]:
				_check(absf(d.length() - 1.0) < 0.001 and d.is_finite(), "unit direction at phase %s" % ph)

	# The kayak's hull is pointed at both ends and widest amidships.
	_check(BoatBuilder.half_beam(0.0) > BoatBuilder.half_beam(0.7) and BoatBuilder.half_beam(1.0) < 0.01, "the hull tapers to a point")
	_check(BoatBuilder.rim_height(1.0) > BoatBuilder.rim_height(0.0), "the bow rides up")

## Where `bone` is, in the player Model's own axes.
func _bone_pos(skeleton: Skeleton3D, model: Node3D, bone: String) -> Vector3:
	var to_model := model.global_transform.affine_inverse() * skeleton.global_transform
	return to_model * skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin

func _test_pose(player: Node) -> void:
	var model: Node3D = player.get_node("Model")
	var sk: Skeleton3D = model.find_children("*", "Skeleton3D", true, false).front()
	var head: Vector3
	var pelvis: Vector3
	# Phase 0: left arm reaching ahead, right arm back by the hip.
	SwimPose.apply(sk, model, 0.0)
	head = _bone_pos(sk, model, "Head")
	pelvis = _bone_pos(sk, model, "pelvis")
	var left := _bone_pos(sk, model, "hand_l")
	var right := _bone_pos(sk, model, "hand_r")
	_check(left.y > head.y + 0.2, "reach: the left hand is past the head (%s vs %s)" % [left, head])
	_check(right.y < pelvis.y + 0.2, "reach: the right hand is back by the hip (%s)" % right)
	# A quarter on: the left hand is pulling under the body (belly side, +Z),
	# the right is up over the water (back side, -Z).
	SwimPose.apply(sk, model, 0.25)
	left = _bone_pos(sk, model, "hand_l")
	right = _bone_pos(sk, model, "hand_r")
	var shoulder := _bone_pos(sk, model, "upperarm_l")
	_check(left.z > shoulder.z + 0.3, "pull: the left hand is down under the body: %s vs %s" % [left, shoulder])
	var elbow := _bone_pos(sk, model, "lowerarm_r")
	_check(elbow.z < shoulder.z - 0.2, "recovery: the right elbow is high over the water: %s vs %s" % [elbow, shoulder])
	# The kick: at 1/12 the left foot is swung toward the floor, the right up.
	SwimPose.apply(sk, model, 1.0 / 12.0)
	var foot_l := _bone_pos(sk, model, "foot_l")
	var foot_r := _bone_pos(sk, model, "foot_r")
	_check(foot_l.z > foot_r.z + 0.05, "kick: the feet are on opposite sides of each other: %s %s" % [foot_l, foot_r])
	sk.reset_bone_poses()

func _test_scene() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _step(10)
	var player: CharacterBody3D = main.get_node("Player")
	var water: Node = main.get_node("Water")
	_test_pose(player)

	# On dry ground: walking.
	player.global_position = Vector3(DRY_GROUND.x, 0.1, DRY_GROUND.y)
	await _step(15)
	_check(not player.swimming, "dry ground is not swimming")
	_check(player.anim_player.active, "walking animations run on land")

	# The pond is dry to begin with: walk the bottom, no swimming (D-141).
	player.global_position = Vector3(POND_MIDDLE.x, 0.1, POND_MIDDLE.y)
	await _step(60)
	_check(not player.swimming, "an empty pond is walked on, not swum in")

	# Fill it and drop in.
	water.set_pond_fill(1.0)
	var surface: float = water.water_surface_at(POND_MIDDLE.x, POND_MIDDLE.y)
	player.global_position = Vector3(POND_MIDDLE.x, surface + 1.0, POND_MIDDLE.y)
	player.velocity = Vector3.ZERO
	await _step(120)
	_check(player.swimming, "dropping into a full pond starts a swim")
	_check(not player.anim_player.active, "the walking animation steps aside for the stroke")
	_check(absf(player.global_position.y - (surface - SwimMath.DRAFT)) < 0.15,
			"floats at the surface: y %s, surface %s" % [player.global_position.y, surface])
	_check(absf(player.model.global_basis.y.normalized().y) < 0.2, "the body lies flat: %s" % player.model.global_basis.y)
	# Swim forward: moves at stroke speed, stays at the surface, the stroke runs.
	var start := player.global_position
	var phase: float = player.swim_phase
	Input.action_press("move_forward")
	await _step(60)
	Input.action_release("move_forward")
	var moved := Vector2(player.global_position.x - start.x, player.global_position.z - start.z).length()
	_check(moved > 1.2 and moved < SwimMath.SPEED * 1.2, "swims about a stroke's speed: %s m in a second" % moved)
	_check(player.swimming and absf(player.global_position.y - (surface - SwimMath.DRAFT)) < 0.15, "still floating after swimming")
	_check(player.swim_phase != phase, "the stroke advances while swimming")
	# Jumping doesn't lift a swimmer out.
	Input.action_press("jump")
	await _step(10)
	Input.action_release("jump")
	_check(player.global_position.y < surface, "a swimmer can't jump out of the water")

	# Back to the bank: walks again and stands up.
	player.global_position = Vector3(DRY_GROUND.x, 0.1, DRY_GROUND.y)
	player.velocity = Vector3.ZERO
	await _step(30)
	_check(not player.swimming and player.anim_player.active, "back on land the player walks again")
	_check(absf(player.model.global_basis.y.normalized().y) > 0.99 and player.model.position.length() < 0.01, "and stands up straight")

	await _test_kayak(main, player, water)

func _test_kayak(main: Node, player: CharacterBody3D, water: Node) -> void:
	var kayak: CharacterBody3D = main.get_node("Kayak")
	_check(kayak.is_in_group("map_vehicle") and kayak.label == "green kayak", "the kayak is on the map")
	var hull_mat := (kayak.get_node("Model/Hull") as MeshInstance3D).material_override as StandardMaterial3D
	_check(hull_mat.albedo_color.is_equal_approx(BoatBuilder.HULL_GREEN), "the first kayak is green")
	# A second kayak just like it, in yellow, parked beside it on the bank.
	var yellow: CharacterBody3D = main.get_node("KayakYellow")
	_check(yellow.is_in_group("map_vehicle") and yellow.label == "yellow kayak", "the yellow kayak is on the map")
	var yellow_mat := (yellow.get_node("Model/Hull") as MeshInstance3D).material_override as StandardMaterial3D
	_check(yellow_mat.albedo_color.is_equal_approx(BoatBuilder.HULL_YELLOW), "the second kayak is yellow")
	_check(not yellow.has_engine and yellow.paddle != null, "the yellow kayak has a paddle too")
	_check(not yellow.afloat and absf(yellow.global_position.y) < 0.3, "the yellow kayak rests on dry land: %s" % yellow.global_position)
	_check(yellow.global_position.distance_to(kayak.global_position) > 1.0 and yellow.global_position.distance_to(kayak.global_position) < 3.0, "the two kayaks lie side by side")
	_check(not kayak.has_engine and kayak.paddle != null, "the kayak has a paddle and no engine")
	_check(kayak.get_node("Model/Hull") != null and kayak.get_node("Model/Paddle/BladeL") != null, "hull and paddle are built")

	# Parked on the bank, it sits on the ground and goes nowhere on its own.
	await _step(30)
	var home := kayak.global_position
	_check(not kayak.afloat and absf(home.y) < 0.3, "parked on dry land it rests on the ground: %s" % home)

	# Put it on the full pond: it floats.
	var surface: float = water.water_surface_at(POND_MIDDLE.x, POND_MIDDLE.y)
	kayak.global_transform = Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(POND_MIDDLE.x, surface + 0.5, POND_MIDDLE.y))
	kayak.speed = 0.0
	await _step(90)
	_check(kayak.afloat, "the kayak floats on a full pond")
	_check(absf(kayak.global_position.y - surface) < 0.08, "riding the surface: y %s, surface %s" % [kayak.global_position.y, surface])

	# Get in from the water: the player swims up and presses E.
	player.global_position = kayak.to_global(Vector3(1.0, 0.0, 0.0))
	await _step(30)
	kayak.interact(player)
	await _step(5)
	_check(kayak.driver == player and player.vehicle == kayak and not player.swimming, "boarding from the water works")
	# Paddle forward; it moves along its heading and keeps floating.
	var before := kayak.global_position
	Input.action_press("move_forward")
	await _step(120)
	Input.action_release("move_forward")
	var travelled := Vector2(kayak.global_position.x - before.x, kayak.global_position.z - before.z)
	_check(travelled.length() > 2.0, "paddling moves the kayak: %s m" % travelled.length())
	_check(travelled.normalized().dot(Vector2(-1.0, 0.0)) > 0.9, "and it heads the way it points (west): %s" % travelled.normalized())
	_check(kayak.afloat and kayak.speed <= kayak.max_speed + 0.01, "still afloat, within its top speed: %s" % kayak.speed)
	_check(absf(kayak.global_position.y - surface) < 0.1, "still on the surface after paddling")
	# Steering turns it.
	var heading := kayak.global_rotation.y
	Input.action_press("move_forward")
	Input.action_press("move_left")
	await _step(60)
	Input.action_release("move_left")
	Input.action_release("move_forward")
	_check(absf(angle_difference(heading, kayak.global_rotation.y)) > 0.1, "steering turns the kayak")
	# The paddle swings while it moves.
	await _step(5)
	_check(kayak.paddle.rotation.length() > 0.01, "the paddle swings")
	# Slow down and get out: the player ends up in the water, swimming.
	Input.action_press("jump")
	await _step(150)
	Input.action_release("jump")
	player.leave_vehicle()
	await _step(60)
	_check(player.vehicle == null and kayak.driver == null, "gets out of the kayak")
	_check(player.swimming, "and is swimming beside it")

	# Drained pond: the kayak settles on the bottom and can only be dragged.
	water.set_pond_fill(0.0)
	kayak.global_transform = Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(POND_MIDDLE.x, 0.5, POND_MIDDLE.y))
	await _step(120)
	_check(not kayak.afloat and kayak.global_position.y < -1.0, "a drained pond leaves the kayak on the bottom: %s" % kayak.global_position)
	_check(kayak._top_speed() < 2.0, "a kayak out of the water only crawls")
