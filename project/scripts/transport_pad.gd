extends Node3D
## A transport point (D-131, reworked in D-139): an invisible spot in the back
## pastures that the full map offers as a teleport destination, the way it does
## for buildings (D-118). There is nothing to see in the world; the map draws a
## marker and name for each one, and double-clicking it calls receive().

## How far in front of the point's local +Z you are put down.
const ARRIVAL_DISTANCE := 2.2

@export var pad_name := "Transport point"

func _ready() -> void:
	add_to_group("transport_pad")

## Where you stand after arriving, on the ground.
func arrival_spot() -> Vector3:
	return global_transform * Vector3(0.0, 0.0, ARRIVAL_DISTANCE)

## Puts `actor` at the arrival spot facing away from the point, and stops it dead.
func receive(actor: Node3D) -> void:
	var spot := arrival_spot()
	var yaw := global_rotation.y + PI
	actor.global_transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(spot.x, actor.global_position.y, spot.z))
	if actor is CharacterBody3D:
		(actor as CharacterBody3D).velocity = Vector3.ZERO
	if "model_yaw" in actor:
		actor.model_yaw = 0.0
	# Arrive looking level, not at the ground or sky you were looking at.
	var head := actor.get_node_or_null("Head") as Node3D
	if head:
		head.rotation.x = 0.0
