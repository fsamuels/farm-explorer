extends Node3D
## A transport pad (D-128): a glowing disc with a pillar of light. Look at the
## pillar and press E to be sent to the pad named by `destination`, which lands
## you beside it facing away. Pads are chained in a ring in main.tscn, so
## pressing E at each one in turn walks the whole loop and ends back where it
## started. The pillar is a collider so the player's interact ray (player.gd)
## can find it; the disc itself is only a mesh, so you can walk across it.

const DISC_RADIUS := 1.6
const PILLAR_RADIUS := 0.3
const PILLAR_HEIGHT := 2.6
## How far in front of the pad's pillar (local +Z) you are put down.
const ARRIVAL_DISTANCE := 2.2
const GLOW := Color(0.25, 0.85, 1.0)

@export var pad_name := "Transport pad"
## The pad this one sends you to.
@export var destination: NodePath

func _ready() -> void:
	add_to_group("transport_pad")
	_build()

func get_interact_prompt() -> String:
	var target := get_destination()
	return "Transport to " + (target.pad_name if target else "nowhere")

func interact(actor: Node3D) -> void:
	var target := get_destination()
	if target == null:
		return
	target.receive(actor)

func get_destination() -> Node:
	if destination.is_empty():
		return null
	var node := get_node_or_null(destination)
	return node if node != null and node.has_method("receive") else null

## Where you stand after arriving: in front of the pillar, on the ground.
func arrival_spot() -> Vector3:
	return global_transform * Vector3(0.0, 0.0, ARRIVAL_DISTANCE)

## Puts `actor` beside this pad looking away from it, and stops it dead.
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

func _build() -> void:
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(GLOW, 0.55)
	glow.emission_enabled = true
	glow.emission = GLOW
	glow.emission_energy_multiplier = 2.0
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.cull_mode = BaseMaterial3D.CULL_DISABLED

	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = DISC_RADIUS
	disc_mesh.bottom_radius = DISC_RADIUS
	disc_mesh.height = 0.06
	var disc := MeshInstance3D.new()
	disc.name = "Disc"
	disc.mesh = disc_mesh
	disc.material_override = glow
	disc.position.y = 0.03
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)

	var pillar_mesh := CylinderMesh.new()
	pillar_mesh.top_radius = PILLAR_RADIUS
	pillar_mesh.bottom_radius = PILLAR_RADIUS
	pillar_mesh.height = PILLAR_HEIGHT
	var body := StaticBody3D.new()
	body.name = "Pillar"
	var pillar := MeshInstance3D.new()
	pillar.mesh = pillar_mesh
	pillar.material_override = glow
	pillar.position.y = PILLAR_HEIGHT * 0.5
	pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(pillar)
	var shape := CylinderShape3D.new()
	shape.radius = PILLAR_RADIUS
	shape.height = PILLAR_HEIGHT
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = PILLAR_HEIGHT * 0.5
	body.add_child(collision)
	add_child(body)

	var light := OmniLight3D.new()
	light.light_color = GLOW
	light.light_energy = 1.2
	light.omni_range = 8.0
	light.position.y = 1.5
	add_child(light)
