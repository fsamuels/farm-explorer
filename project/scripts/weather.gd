extends Node3D
## Weather (D-95): Clear, Rain and Snow. R (`cycle_weather`) steps to the next
## one. Rain and snow are GPU particles emitted from a box that follows the
## active camera, so they're everywhere you go without filling the whole farm.
## A heightfield collider that also follows the camera hides drops and flakes
## when they hit a roof, a tree or the ground, so it doesn't rain indoors. The
## sky clouds over through TimeOfDay.set_overcast(), and the particles are
## tinted by the scene's brightness so they don't glow at night.
##
## Not done yet: puddles / a wet look, snow settling on the ground, sound.

const ORDER := ["clear", "rain", "snow"]
const LABELS := {"clear": "Clear", "rain": "Rain", "snow": "Snow"}
## Cloud cover each weather puts on the sky (see TimeOfDay.overcast_preset).
const OVERCAST := {"clear": 0.0, "rain": 1.0, "snow": 0.7}

## Emitter box half-size around the camera, and how far above it drops start.
const AREA := 22.0
const RAIN_HEIGHT := 14.0
const SNOW_HEIGHT := 10.0
const COLLIDER_SIZE := 100.0

@export var time_of_day_path: NodePath = ^"../TimeOfDay"
@export var transition_seconds := 2.0
@export var start_weather := "clear"

var current := ""
var _rain: GPUParticles3D
var _snow: GPUParticles3D
var _collider: GPUParticlesCollisionHeightField3D
var _tween: Tween
var _brightness := 1.0

## The weather after `weather` in ORDER, wrapping Snow back to Clear. Unknown
## names restart at Clear.
static func next_weather(weather: String) -> String:
	var i := ORDER.find(weather)
	return ORDER[0] if i == -1 else ORDER[(i + 1) % ORDER.size()]

## How bright (0.15..1) to draw rain and snow under lighting preset `p`, so
## they read as lit by the scene rather than glowing white at night.
static func particle_brightness(p: Dictionary) -> float:
	var lit: float = p.ambient_energy * p.ambient_color.get_luminance() + 0.5 * p.sun_energy
	return clampf(lit, 0.15, 1.0)

func _ready() -> void:
	_rain = _build_rain()
	_snow = _build_snow()
	_collider = GPUParticlesCollisionHeightField3D.new()
	# Wider than the emitter box plus drift: snow lives ~9 s in world space,
	# so flakes left behind as you walk still need something to land on.
	_collider.size = Vector3(COLLIDER_SIZE, 60, COLLIDER_SIZE)
	_collider.resolution = GPUParticlesCollisionHeightField3D.RESOLUTION_512
	_collider.follow_camera_enabled = true
	_collider.update_mode = GPUParticlesCollisionHeightField3D.UPDATE_MODE_WHEN_MOVED
	_collider.position.y = 15
	add_child(_collider)
	var tod := _time_of_day()
	if tod:
		tod.lighting_changed.connect(_on_lighting_changed)
		if not tod.shown().is_empty():
			_on_lighting_changed(tod.shown())
	set_weather(start_weather, true)

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		var at := cam.global_position
		_rain.global_position = at + Vector3(0, RAIN_HEIGHT, 0)
		_snow.global_position = at + Vector3(0, SNOW_HEIGHT, 0)

func _unhandled_input(event: InputEvent) -> void:
	# Like T, ignored while the full map has the game paused (D-93).
	if event.is_action_pressed("cycle_weather") and not get_tree().paused:
		set_weather(next_weather(current))
		get_viewport().set_input_as_handled()

func set_weather(weather: String, instant := false) -> void:
	if not OVERCAST.has(weather):
		push_warning("Unknown weather '%s', using clear" % weather)
		weather = "clear"
	var previous := current
	current = weather
	if _tween:
		_tween.kill()
		_tween = null
	var fade := not instant and transition_seconds > 0.0
	if fade:
		_tween = create_tween().set_parallel()
	for particles: GPUParticles3D in [_rain, _snow]:
		var on := particles.name.to_lower() == weather
		if on and not (previous == weather and particles.emitting):
			particles.restart()  # drop any faded-out leftovers
			_set_fade(1.0, particles)
		elif not on:
			particles.emitting = false
			# Fade what's still falling along with the sky, rather than
			# letting snow drift down for its full lifetime under a clear sky.
			if fade:
				_tween.tween_method(_set_fade.bind(particles), particles.get_meta("fade"), 0.0, transition_seconds)
			else:
				_set_fade(0.0, particles)
		particles.emitting = on
	var tod := _time_of_day()
	if not tod:
		return
	var target: float = OVERCAST[weather]
	if not fade:
		tod.set_overcast(target)
		return
	_tween.tween_method(tod.set_overcast, tod.overcast, target, transition_seconds)
	tod.show_toast(LABELS[weather])

func _time_of_day() -> Node:
	return get_node_or_null(time_of_day_path)

func _on_lighting_changed(p: Dictionary) -> void:
	_brightness = particle_brightness(p)
	for particles in [_rain, _snow]:
		_tint(particles)

func _set_fade(amount: float, particles: GPUParticles3D) -> void:
	particles.set_meta("fade", amount)
	_tint(particles)

## Material colour = base colour dimmed by the scene's brightness, with the
## alpha scaled by the particles' fade (1 = shown, 0 = faded out).
func _tint(particles: GPUParticles3D) -> void:
	var mat: StandardMaterial3D = particles.draw_pass_1.surface_get_material(0)
	var c: Color = particles.get_meta("base_color")
	var b := _brightness
	mat.albedo_color = Color(c.r * b, c.g * b, c.b * b, c.a * float(particles.get_meta("fade")))

func _build_rain() -> GPUParticles3D:
	var process := _process_material(Vector3(0.08, -1, 0), 2.0, 17.0, 21.0)
	var mat := _particle_material(Color(0.8, 0.84, 0.92, 0.6), BaseMaterial3D.BILLBOARD_FIXED_Y)
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.018, 0.55)
	mesh.material = mat
	return _particles("Rain", 9000, 1.4, process, mesh, Color(0.8, 0.84, 0.92, 0.6))

func _build_snow() -> GPUParticles3D:
	var process := _process_material(Vector3(0, -1, 0), 25.0, 0.9, 1.5)
	process.gravity = Vector3(0, -0.3, 0)
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.6
	process.turbulence_influence_min = 0.03
	process.turbulence_influence_max = 0.08
	var mat := _particle_material(Color(1, 1, 1, 0.9), BaseMaterial3D.BILLBOARD_ENABLED)
	var dot := GradientTexture2D.new()
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(0.5, 0.0)
	dot.gradient = Gradient.new()
	dot.gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	dot.width = 32
	dot.height = 32
	mat.albedo_texture = dot
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.07, 0.07)
	mesh.material = mat
	return _particles("Snow", 4000, 9.0, process, mesh, Color(1, 1, 1, 0.9))

func _process_material(direction: Vector3, spread: float, v_min: float, v_max: float) -> ParticleProcessMaterial:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(AREA, 0.5, AREA)
	process.direction = direction
	process.spread = spread
	process.initial_velocity_min = v_min
	process.initial_velocity_max = v_max
	process.gravity = Vector3.ZERO
	process.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	return process

func _particle_material(color: Color, billboard: BaseMaterial3D.BillboardMode) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = billboard
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

func _particles(node_name: String, amount: int, lifetime: float, process: ParticleProcessMaterial, mesh: Mesh, base: Color) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = node_name
	p.amount = amount
	p.lifetime = lifetime
	p.preprocess = lifetime
	p.process_material = process
	p.draw_pass_1 = mesh
	p.emitting = false
	p.collision_base_size = 0.02
	# Particles live in world space, so drops already falling keep falling
	# where they are when the camera moves; the box only moves where new ones
	# start. The visibility box covers the fall from the emitter to the ground.
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-AREA - 5, -RAIN_HEIGHT - 10, -AREA - 5), Vector3(AREA * 2 + 10, RAIN_HEIGHT + 15, AREA * 2 + 10))
	p.set_meta("base_color", base)
	p.set_meta("fade", 0.0)
	add_child(p)
	return p
