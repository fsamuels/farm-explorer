extends Node3D
## An interactive door for the Shop (D-98), opened with E like gate.gd.
##
## The node's origin is the bottom of the opening on the wall's centre line:
## local +X runs along the wall (to the leaf's far edge) and local -Z points to
## the outside. Three kinds:
##  - SWING: hinged at the origin, the leaf extends along +X and swings about Y
##    by `open_angle_deg` (positive turns the free edge toward +Z, the inside).
##  - SLIDE: the leaf hangs outside the wall and slides along +X by `slide`
##    metres (negative slides back toward -X).
##  - ROLLUP: the leaf rolls up into the header, shrinking to nothing at the top.

const Corrugated := preload("res://scripts/corrugated.gd")

## Physics layer (bit 8) for interact-only bodies; the interact rays look at it.
const PICK_LAYER := 1 << 7

enum Kind { SWING, SLIDE, ROLLUP }

@export var kind: Kind = Kind.SWING
@export var width := 0.91
@export var height := 2.1
@export var thickness := 0.05
@export var color := Color(0.85, 0.85, 0.82)
@export var open_angle_deg := 90.0
@export var slide := 0.0
@export var swing_time := 0.8
@export var label := "door"
## Where the panel sits across the wall (local Z); SLIDE doors hang outside.
@export var offset_z := 0.0
## Optional ribbed look for panels (garage / barn doors).
@export var ribbed := false
@export var window_pane := false
## A patio slider (D-170, the House's back doors): `width` is the whole
## opening, glazed in two white-framed glass panels. The panel at -X is fixed;
## the one at +X slides over it (set `slide` to minus its travel).
@export var glass := false

## Built already open (the Back Barn's doors); E still closes it.
@export var start_open := false

const GLASS_FRAME := 0.06
const GLASS_GAP := 0.07

var is_open := false
var _body: AnimatableBody3D
var _visual: Node3D
var _shape: CollisionShape3D
var _tween: Tween

func _ready() -> void:
	_build()
	if start_open:
		# Already slid aside, no animation and no collider.
		is_open = true
		_body.position.x = slide
		_shape.disabled = true

func get_interact_prompt() -> String:
	return ("Close " if is_open else "Open ") + label

func interact(_actor: Node3D) -> void:
	set_open(not is_open)

func set_open(open: bool) -> void:
	if open == is_open:
		return
	is_open = open
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT) \
			.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	var time := swing_time * (2.2 if kind != Kind.SWING else 1.0)
	match kind:
		Kind.SWING:
			_tween.tween_property(_body, "rotation:y",
					-deg_to_rad(open_angle_deg) if open else 0.0, time)
		Kind.SLIDE:
			_tween.tween_property(_body, "position:x", slide if open else 0.0, time)
		Kind.ROLLUP:
			_tween.tween_property(_visual, "scale:y", 0.02 if open else 1.0, time)
	# Sliding and rolling leaves stop blocking once open; the collider comes
	# back only when they have finished closing, so it never appears inside
	# the player. Swing leaves keep theirs mid-swing so they shove the player,
	# like gates. The pick body (see _build) stays put so E can still close.
	if kind == Kind.SWING:
		return
	if open:
		_shape.set_deferred("disabled", true)
	else:
		_tween.tween_callback(func(): _shape.set_deferred("disabled", false))

func _build() -> void:
	for child in get_children():
		child.queue_free()
	_body = AnimatableBody3D.new()
	_body.name = "Leaf"
	_body.sync_to_physics = true
	add_child(_body)
	if glass:
		_build_glass()
		return

	var material: StandardMaterial3D
	if ribbed:
		material = Corrugated.material(color)
	else:
		material = StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.55
		material.metallic = 0.3

	# SWING leaves are centred on their hinge at the origin; the others are
	# centred over the opening so scaling / sliding reads naturally.
	var centre := Vector3(width / 2.0, height / 2.0, offset_z)
	var parent: Node3D = _body
	if kind == Kind.ROLLUP:
		# Pivot at the top so the leaf rolls up toward the header; only this
		# visual is scaled, never the physics body.
		_visual = Node3D.new()
		_visual.position.y = height
		_body.add_child(_visual)
		parent = _visual
		centre.y = -height / 2.0
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, height, thickness)
	var leaf := MeshInstance3D.new()
	leaf.mesh = mesh
	leaf.material_override = material
	leaf.position = centre
	parent.add_child(leaf)

	if window_pane:
		var glass := StandardMaterial3D.new()
		glass.albedo_color = Color(0.7, 0.85, 0.95, 0.35)
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var pane := MeshInstance3D.new()
		var pane_mesh := BoxMesh.new()
		pane_mesh.size = Vector3(width * 0.5, height * 0.3, thickness + 0.02)
		pane.mesh = pane_mesh
		pane.material_override = glass
		pane.position = centre + Vector3(0, height * 0.22, 0)
		parent.add_child(pane)

	if kind != Kind.ROLLUP:
		# A knob / pull on the inside face is skipped; a handle on both faces
		# shows where to grab.
		var handle_mesh := BoxMesh.new()
		handle_mesh.size = Vector3(0.12, 0.04, 0.12 + thickness)
		var handle := MeshInstance3D.new()
		handle.mesh = handle_mesh
		var handle_material := StandardMaterial3D.new()
		handle_material.albedo_color = Color(0.25, 0.25, 0.27)
		handle_material.metallic = 0.8
		handle_material.roughness = 0.35
		handle.material_override = handle_material
		handle.position = Vector3(width - 0.12 if kind == Kind.SWING else 0.2, 0.95, offset_z)
		parent.add_child(handle)

	var box := BoxShape3D.new()
	box.size = Vector3(width, height, thickness)
	_shape = CollisionShape3D.new()
	_shape.shape = box
	_shape.position = Vector3(width / 2.0, height / 2.0, offset_z)
	_body.add_child(_shape)

	if kind != Kind.SWING:
		_add_pick()

## Interact-only body that stays at the closed position so the player's ray can
## still find the door while it is open. It sits on its own layer, which the
## player's body ignores (player.gd adds it to the rays).
func _add_pick() -> void:
	var pick := StaticBody3D.new()
	pick.name = "Pick"
	pick.collision_layer = PICK_LAYER
	pick.collision_mask = 0
	var pick_shape := CollisionShape3D.new()
	var pick_box := BoxShape3D.new()
	pick_box.size = Vector3(width, height, 0.05)
	pick_shape.shape = pick_box
	pick_shape.position = Vector3(width / 2.0, height / 2.0, 0.0)
	pick.add_child(pick_shape)
	add_child(pick)

## Width of one glass panel: half the opening plus the overlap where they meet.
func glass_panel_width() -> float:
	return width / 2.0 + GLASS_FRAME / 2.0

## The patio slider: a fixed panel at -X (just inside), a sliding one at +X
## (just outside) that rides over it, each a white frame round tinted glass.
func _build_glass() -> void:
	var pw := glass_panel_width()
	var fixed := StaticBody3D.new()
	fixed.name = "FixedPanel"
	add_child(fixed)
	_glass_panel(fixed, Vector3(pw / 2.0, height / 2.0, GLASS_GAP / 2.0), pw)
	var fixed_shape := CollisionShape3D.new()
	var fixed_box := BoxShape3D.new()
	fixed_box.size = Vector3(pw, height, thickness)
	fixed_shape.shape = fixed_box
	fixed_shape.position = Vector3(pw / 2.0, height / 2.0, GLASS_GAP / 2.0)
	fixed.add_child(fixed_shape)

	var centre := Vector3(width - pw / 2.0, height / 2.0, -GLASS_GAP / 2.0)
	_glass_panel(_body, centre, pw)
	var handle := MeshInstance3D.new()
	var handle_mesh := BoxMesh.new()
	handle_mesh.size = Vector3(0.03, 0.3, thickness + 0.06)
	handle.mesh = handle_mesh
	var handle_material := StandardMaterial3D.new()
	handle_material.albedo_color = Color(0.2, 0.2, 0.22)
	handle_material.metallic = 0.6
	handle.material_override = handle_material
	handle.position = Vector3(width - pw + GLASS_FRAME + 0.05, 1.0, -GLASS_GAP / 2.0)
	_body.add_child(handle)
	var box := BoxShape3D.new()
	box.size = Vector3(pw, height, thickness)
	_shape = CollisionShape3D.new()
	_shape.shape = box
	_shape.position = centre
	_body.add_child(_shape)
	_add_pick()

func _glass_panel(parent: Node3D, centre: Vector3, w: float) -> void:
	var frame_material := StandardMaterial3D.new()
	frame_material.albedo_color = color
	frame_material.roughness = 0.5
	var f := GLASS_FRAME
	for piece in [
		[Vector3(0, height / 2.0 - f / 2.0, 0), Vector3(w, f, thickness)],
		[Vector3(0, -height / 2.0 + f / 2.0, 0), Vector3(w, f * 1.6, thickness)],
		[Vector3(-w / 2.0 + f / 2.0, 0, 0), Vector3(f, height, thickness)],
		[Vector3(w / 2.0 - f / 2.0, 0, 0), Vector3(f, height, thickness)],
	]:
		var mesh := BoxMesh.new()
		mesh.size = piece[1]
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = frame_material
		mi.position = centre + piece[0]
		parent.add_child(mi)
	var glass_material := StandardMaterial3D.new()
	glass_material.albedo_color = Color(0.12, 0.16, 0.18, 0.62)
	glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_material.metallic = 0.5
	glass_material.roughness = 0.05
	glass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var pane := MeshInstance3D.new()
	var pane_mesh := QuadMesh.new()
	pane_mesh.size = Vector2(w - 2.0 * f, height - 2.0 * f)
	pane.mesh = pane_mesh
	pane.material_override = glass_material
	pane.position = centre
	parent.add_child(pane)
