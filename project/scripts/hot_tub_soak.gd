extends StaticBody3D
## Getting into a back-yard hot tub (D-190). Every tub the mockup kit builds
## (mockup_kit.gd `hot_tub`) gets one of these, sitting on the water. Look at
## the water and press E: you strip to your underwear (your clothes land folded
## on the deck), sit down in the tub facing west, and the view goes to first
## person, so on a clear night you look straight out at the western sky and
## its stars. L cycles the underwater lights, J turns the jets on and off
## (bubbles, and much more steam), K steps through sky scenes for a soak
## (night, night with light snow, night with the aurora, sunset), E gets you
## out onto the deck.
##
## It works like a car seat (vehicle.gd): the player's `enter_vehicle` calls
## `board`, carries the body to `seat_transform` every frame and asks
## `can_leave` / `find_exit_spot` / `release` on the way out. `show_body` tells
## the player to show the body in third person, sunk to the shoulders, which
## reads as sitting in the water.

## Physics layer the interact rays look at (as shop_door.gd's PICK_LAYER).
const PICK_LAYER := 1 << 7
## The light settings L steps through.
const LIGHTS := [
	{"name": "off", "color": Color(0, 0, 0), "energy": 0.0},
	{"name": "blue", "color": Color(0.25, 0.55, 1.0), "energy": 1.6},
	{"name": "teal", "color": Color(0.2, 0.9, 0.8), "energy": 1.5},
	{"name": "purple", "color": Color(0.65, 0.3, 1.0), "energy": 1.5},
	{"name": "warm white", "color": Color(1.0, 0.85, 0.6), "energy": 1.3},
]
## The sky scenes K steps through: a time-of-day preset (time_of_day.gd) and
## a weather (weather.gd). The time goes first: the aurora needs a dark sky.
const SCENES := [
	{"name": "Night", "time": "night", "weather": "clear"},
	{"name": "Night, light snow", "time": "night", "weather": "snow"},
	{"name": "Night, aurora", "time": "night", "weather": "aurora"},
	{"name": "Sunset", "time": "sunset", "weather": "clear"},
]
const STEAM_CALM := 14
const STEAM_JETS := 50

## The tub's inside width, metres, and the water's height above this node.
@export var size := 2.3
@export var water_y := 0.95
var show_body := true
var eye_offset := Vector3(0, 1.65, 0)
var driver: Node3D
var light_index := 1
var jets := false
## Which of SCENES is showing, or -1 before K is first pressed.
var scene_index := -1

var _light: OmniLight3D
var _water_mat: StandardMaterial3D
var _steam: CPUParticles3D
var _steam_jets: CPUParticles3D
var _bubbles: CPUParticles3D
var _flakes: CPUParticles3D
var _foam: MeshInstance3D
var _clothes: Node3D
var _hud: CanvasLayer
var _hud_label: Label

func _ready() -> void:
	add_to_group("hot_tub_soak")
	collision_layer = PICK_LAYER
	collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = Vector3(size - 0.3, 0.3, size - 0.3)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(0, water_y, 0)
	add_child(cs)
	_light = OmniLight3D.new()
	_light.position = Vector3(0, water_y - 0.35, 0)
	_light.omni_range = size * 1.4
	_light.shadow_enabled = false
	add_child(_light)
	_steam = _make_steam(STEAM_CALM, 0.35)
	_steam.emitting = true
	_steam_jets = _make_steam(STEAM_JETS, 0.55)
	_steam_jets.emitting = false
	_bubbles = _make_bubbles()
	_flakes = _make_flakes()
	_foam = MeshInstance3D.new()
	var foam_mesh := PlaneMesh.new()
	foam_mesh.size = Vector2(size - 0.3, size - 0.3)
	_foam.mesh = foam_mesh
	var foam_mat := StandardMaterial3D.new()
	foam_mat.albedo_color = Color(0.95, 0.97, 1.0, 0.35)
	foam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	foam_mat.roughness = 0.9
	_foam.material_override = foam_mat
	_foam.position = Vector3(0, water_y + 0.015, 0)
	_foam.visible = false
	add_child(_foam)
	_clothes = _make_clothes()
	_clothes.visible = false
	_build_hud()
	_apply_lights()

## The tub's water surface material, so the lights can tint it (the kit
## passes it in after building the water).
func set_water_material(m: StandardMaterial3D) -> void:
	_water_mat = m.duplicate() as StandardMaterial3D
	_water_mat.emission_enabled = true
	_apply_lights()

func get_water_material() -> StandardMaterial3D:
	return _water_mat

func get_interact_prompt() -> String:
	return "Get in the hot tub"

func interact(actor: Node3D) -> void:
	if driver == null and actor.has_method("enter_vehicle"):
		actor.enter_vehicle(self)

# --- the seat (the same calls a car answers) ---------------------------------

func board(actor: Node3D) -> void:
	driver = actor
	if actor.has_method("set_underwear"):
		actor.set_underwear(true)
	_clothes.visible = true
	_hud.visible = true
	# Sit back looking out at the western sky, just above the horizon.
	var head := actor.get_node_or_null("Head") as Node3D
	if head:
		head.rotation.x = deg_to_rad(6.0)
	_update_hud()

func can_leave() -> bool:
	return true

## A spot on the deck beside the tub, on its north side (the steps side in
## most ideas), else east, west or south; null if all are blocked.
func find_exit_spot() -> Variant:
	var space := get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	var reach := size / 2.0 + 0.75
	for d in [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1)]:
		var spot := to_global(d * reach + Vector3(0, water_y - 0.4, 0))
		# Drop onto whatever is there (the deck), from above.
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(spot + Vector3(0, 2.0, 0), spot - Vector3(0, 2.0, 0)))
		if not hit.is_empty():
			spot.y = hit.position.y + 0.05
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.transform = Transform3D(Basis.IDENTITY, spot + Vector3(0, 0.95, 0))
		query.collision_mask = 1
		if space.intersect_shape(query, 1).is_empty():
			return spot
	return null

func release() -> void:
	if driver and driver.has_method("set_underwear"):
		driver.set_underwear(false)
	driver = null
	_clothes.visible = false
	_hud.visible = false

## Sitting on the east bench facing west, sunk so the water is at the
## shoulders: the feet are 1.35 m under the surface.
func seat_transform(look_yaw: float) -> Transform3D:
	var seat := to_global(Vector3(size / 2.0 - 0.45, water_y - 1.35, 0))
	var west := global_rotation.y + PI / 2.0
	return Transform3D(Basis(Vector3.UP, west + look_yaw), seat)

# --- lights, jets, steam -----------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if driver == null:
		return
	if event.is_action_pressed("tub_lights") and not event.is_echo():
		cycle_lights()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("tub_jets") and not event.is_echo():
		set_jets(not jets)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("tub_scene") and not event.is_echo():
		cycle_scene()
		get_viewport().set_input_as_handled()

func cycle_lights() -> void:
	light_index = (light_index + 1) % LIGHTS.size()
	_apply_lights()
	_update_hud()

func set_jets(on: bool) -> void:
	jets = on
	_steam_jets.emitting = on
	_bubbles.emitting = on
	_foam.visible = on
	_update_hud()

## Step to the next sky scene: set the time of day, then the weather.
func cycle_scene() -> void:
	scene_index = (scene_index + 1) % SCENES.size()
	var sc: Dictionary = SCENES[scene_index]
	var tod := _world_node("TimeOfDay")
	if tod:
		tod.set_preset(sc.time)
	var weather := _world_node("Weather")
	if weather:
		weather.set_weather(sc.weather)
	# The game's snow is unlit, faint at night; flakes round the tub, caught
	# in the light off the water, make the snow scene read.
	_flakes.emitting = sc.weather == "snow"
	_update_hud()

func flakes_falling() -> bool:
	return _flakes.emitting

func scene_name() -> String:
	return SCENES[scene_index].name if scene_index >= 0 else "pick one"

## A node of the main scene (TimeOfDay, Weather): the nearest ancestor that
## has a child of that name has it.
func _world_node(node_name: String) -> Node:
	var n := get_parent()
	while n:
		if n.has_node(node_name):
			return n.get_node(node_name)
		n = n.get_parent()
	return null

func light_name() -> String:
	return LIGHTS[light_index].name

## How many steam puffs are in the air at once: always some, many more with
## the jets on.
func steam_amount() -> int:
	return STEAM_CALM + (STEAM_JETS if jets else 0)

func _apply_lights() -> void:
	var l: Dictionary = LIGHTS[light_index]
	_light.visible = l.energy > 0.0
	_light.light_color = l.color
	_light.light_energy = l.energy
	if _water_mat:
		_water_mat.emission = l.color
		_water_mat.emission_energy_multiplier = 0.3 * l.energy

func _make_steam(amount: int, speed: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 3.5
	# Not off the east end, where you sit: a puff in your face hides the sky.
	p.position = Vector3(-0.35, water_y + 0.05, 0)
	p.emission_box_extents = Vector3(size / 2.0 - 0.55, 0.02, size / 2.0 - 0.2)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.direction = Vector3.UP
	p.spread = 15.0
	p.gravity = Vector3(0.05, 0.08, 0)
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.4))
	curve.add_point(Vector2(1.0, 1.6))
	p.scale_amount_curve = curve
	# Faint white puffs that grow as they rise (the scale curve). Particle
	# colours do not reach this material, so the faintness is in its albedo.
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.5)
	var m := StandardMaterial3D.new()
	m.albedo_texture = _puff_texture()
	m.albedo_color = Color(1, 1, 1, 0.12)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = m
	p.mesh = quad
	add_child(p)
	return p

func _make_bubbles() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 60
	p.lifetime = 0.8
	p.position = Vector3(0, water_y - 0.3, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(size / 2.0 - 0.25, 0.05, size / 2.0 - 0.25)
	p.direction = Vector3.UP
	p.spread = 10.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.35
	p.initial_velocity_max = 0.5
	var ball := SphereMesh.new()
	ball.radius = 0.025
	ball.height = 0.05
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.95, 0.97, 1.0, 0.7)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ball.material = m
	p.mesh = ball
	p.emitting = false
	add_child(p)
	return p

## Snowflakes drifting down round the tub, in the snow scene.
func _make_flakes() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 260
	p.lifetime = 6.0
	p.preprocess = 6.0
	p.position = Vector3(0, water_y + 4.0, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(5.0, 0.2, 5.0)
	p.direction = Vector3.DOWN
	p.spread = 20.0
	p.gravity = Vector3(0.1, -0.25, 0.05)
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 0.7
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	var m := StandardMaterial3D.new()
	m.albedo_texture = _puff_texture()
	m.albedo_color = Color(1, 1, 1, 0.9)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = m
	p.mesh = quad
	p.emitting = false
	add_child(p)
	return p

static var _puff: ImageTexture

## A soft round puff, white fading to clear at the edge.
static func _puff_texture() -> ImageTexture:
	if _puff == null:
		var n := 64
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var d := Vector2(x - n / 2.0 + 0.5, y - n / 2.0 + 0.5).length() / (n / 2.0)
				var a := clampf(1.0 - d, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a * a))
		_puff = ImageTexture.create_from_image(img)
	return _puff

## Clothes folded on the deck by the tub, with the boots beside them.
func _make_clothes() -> Node3D:
	var n := Node3D.new()
	n.name = "Clothes"
	n.position = Vector3(size / 2.0 + 0.35, water_y - 0.4, -size / 2.0 + 0.2)
	add_child(n)
	var parts := [
		[Vector3(0, 0.03, 0), Vector3(0.4, 0.06, 0.3), Color(0.25, 0.32, 0.5)],
		[Vector3(0, 0.09, 0.01), Vector3(0.36, 0.06, 0.28), Color(0.55, 0.2, 0.18)],
		[Vector3(0.02, 0.14, 0), Vector3(0.24, 0.05, 0.22), Color(0.36, 0.24, 0.14)],
		[Vector3(-0.1, 0.12, 0.35), Vector3(0.12, 0.24, 0.28), Color(0.18, 0.14, 0.11)],
		[Vector3(0.1, 0.12, 0.35), Vector3(0.12, 0.24, 0.28), Color(0.18, 0.14, 0.11)],
	]
	for p in parts:
		var mesh := BoxMesh.new()
		mesh.size = p[1]
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		var m := StandardMaterial3D.new()
		m.albedo_color = p[2]
		m.roughness = 0.9
		mi.material_override = m
		mi.position = p[0]
		n.add_child(mi)
	return n

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "TubHud"
	_hud.layer = 6
	_hud.visible = false
	add_child(_hud)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", preload("res://scripts/hud_style.gd").backing(14.0, 6.0))
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_bottom = -30
	_hud.add_child(panel)
	_hud_label = Label.new()
	_hud_label.add_theme_font_size_override("font_size", 22)
	_hud_label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	panel.add_child(_hud_label)

func _update_hud() -> void:
	if _hud_label:
		_hud_label.text = "In the hot tub   ·   L lights (%s)   ·   J jets (%s)   ·   K sky (%s)   ·   E get out" % [light_name(), "on" if jets else "off", scene_name()]

func hud_text() -> String:
	return _hud_label.text if _hud_label else ""
