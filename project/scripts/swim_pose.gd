extends RefCounted
## Poses the player's skeleton for the breaststroke (D-151). The imported walk
## and run animations know nothing about swimming, so while swimming the
## animation player is paused and this sets the arm and leg bones directly from
## swim_math.gd's directions, aiming each bone from its rest direction.
##
## Directions are given in the Model's own axes (upright rest pose); they are
## turned into the skeleton's axes here, so it doesn't matter how the glb's
## armature happens to be oriented.

const SwimMath := preload("res://scripts/swim_math.gd")

const ARM_CHAINS := {
	1.0: ["clavicle_l", "upperarm_l", "lowerarm_l", "hand_l"],
	-1.0: ["clavicle_r", "upperarm_r", "lowerarm_r", "hand_r"],
}
const LEG_CHAINS := {
	1.0: ["thigh_l", "calf_l", "foot_l"],
	-1.0: ["thigh_r", "calf_r", "foot_r"],
}

## Pose `skeleton` (a child of `model`) at stroke `phase`.
static func apply(skeleton: Skeleton3D, model: Node3D, phase: float) -> void:
	skeleton.reset_bone_poses()
	# model axes -> skeleton axes (the skeleton may sit under a rotated armature).
	var to_skeleton := (model.global_transform.affine_inverse() * skeleton.global_transform).basis.inverse()
	for side: float in ARM_CHAINS:
		var dirs := SwimMath.arm_dirs(phase, side)
		var chain: Array = ARM_CHAINS[side]
		_aim_chain(skeleton, chain[0], [chain[1], chain[2]], [chain[2], chain[3]],
				[to_skeleton * dirs.upper, to_skeleton * dirs.lower])
	for side: float in LEG_CHAINS:
		var dirs := SwimMath.leg_dirs(phase, side)
		var chain: Array = LEG_CHAINS[side]
		_aim_chain(skeleton, skeleton.get_bone_name(skeleton.get_bone_parent(skeleton.find_bone(chain[0]))),
				[chain[0], chain[1]], [chain[1], chain[2]], [to_skeleton * dirs.thigh, to_skeleton * dirs.calf])

## Point each bone in `bones` at the matching direction in `dirs`, one after the
## other down the chain. `children[i]` is the bone whose position along
## `bones[i]` gives that bone's own axis. `anchor` is the bone above the first,
## left at its rest pose.
static func _aim_chain(skeleton: Skeleton3D, anchor: String, bones: Array, children: Array, dirs: Array) -> void:
	var parent_global := _global_basis(skeleton, skeleton.find_bone(anchor))
	for i in bones.size():
		var bone := skeleton.find_bone(bones[i])
		var child := skeleton.find_bone(children[i])
		if bone < 0 or child < 0:
			return
		var rest_global := _global_rest_basis(skeleton, bone)
		var axis := rest_global * skeleton.get_bone_rest(child).origin.normalized()
		var want: Vector3 = (dirs[i] as Vector3).normalized()
		var turn := Quaternion(axis, want)
		var new_global := Basis(turn) * rest_global
		var local := parent_global.inverse() * new_global
		skeleton.set_bone_pose_rotation(bone, local.get_rotation_quaternion())
		parent_global = new_global

## A bone's global basis in the current pose (parents' poses included).
static func _global_basis(skeleton: Skeleton3D, bone: int) -> Basis:
	return skeleton.get_bone_global_pose(bone).basis

static func _global_rest_basis(skeleton: Skeleton3D, bone: int) -> Basis:
	return skeleton.get_bone_global_rest(bone).basis
