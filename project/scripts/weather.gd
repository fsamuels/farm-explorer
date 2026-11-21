extends Node3D
## Weather (D-95, D-98): Clear, Drizzle, Rain, Downpour, Thunderstorm, Light
## fog, Heavy fog and Snow. R (`cycle_weather`) steps to the next one. Rain and
## snow are GPU particles emitted from a box that follows the active camera,
## so they're everywhere you go without filling the whole farm. The rain
## weathers share one emitter and differ in drop count, streak length, speed
## and wind slant; the fog weathers have no particles, only thicker fog.
## Thunderstorms add random lightning flashes (a brief brightening of the sky
## and ambient light through TimeOfDay.set_flash()).
## A heightfield collider that also follows the camera hides drops and flakes
## when they hit a roof, a tree or the ground, so it doesn't rain indoors. The
## sky clouds over through TimeOfDay.set_overcast(), and the particles are
## tinted by the scene's brightness so they don't glow at night.
##
## Not done yet: puddles / a wet look, snow settling on the ground, sound.

const ORDER := ["clear", "drizzle", "rain", "downpour", "thunderstorm", "light_fog", "heavy_fog", "snow"]
## Per weather: the label shown on screen, the cloud cover it puts on the sky
## (see TimeOfDay.overcast_preset), `fog` (extra fog density on top of that),
## `precip` ("rain", "snow" or "" for none) and, for rain, the drop count,
## streak size, wind slant (x per unit fall) and fall speed range.
const WEATHER := {
	"clear": {"label": "Clear", "overcast": 0.0, "fog": 0.0, "precip": ""},
	"drizzle": {"label": "Drizzle", "overcast": 0.55, "fog": 0.0, "precip": "rain",
		"drops": 2500, "width": 0.012, "length": 0.3, "slant": 0.03, "speed": Vector2(9.0, 12.0)},
	"rain": {"label": "Rain", "overcast": 1.0, "fog": 0.0, "precip": "rain",
		"drops": 9000, "width": 0.018, "length": 0.55, "slant": 0.08, "speed": Vector2(17.0, 21.0)},
	"downpour": {"label": "Downpour", "overcast": 1.0, "fog": 0.004, "precip": "rain",
		"drops": 14000, "width": 0.022, "length": 0.75, "slant": 0.18, "speed": Vector2(20.0, 25.0)},
	"thunderstorm": {"label": "Thunderstorm", "overcast": 1.0, "fog": 0.006, "precip": "rain", "lightning": true,
		"drops": 14000, "width": 0.022, "length": 0.75, "slant": 0.25, "speed": Vector2(20.0, 25.0)},
	"light_fog": {"label": "Light fog", "overcast": 0.3, "fog": 0.012, "precip": ""},
	"heavy_fog": {"label": "Heavy fog", "overcast": 0.5, "fog": 0.045, "precip": ""},
	"snow": {"label": "Snow", "overcast": 0.7, "fog": 0.0, "precip": "snow"},
}

## Seconds between lightning strikes, and how long one flash lasts.
const LIGHTNING_MIN := 4.0
const LIGHTNING_MAX := 14.0
const FLASH_SECONDS := 0.6

## Emitter box half-size around the camera, and how far above it drops start.
const AREA := 22.0
const RAIN_HEIGHT := 14.0
const SNOW_HEIGHT := 10.0
const COLLIDER_SIZE := 100.0
## The rain emitter is built for the heaviest rain; lighter weathers show a
## fraction of its drops (`amount_ratio`).
const RAIN_MAX_DROPS := 14000

@export var time_of_day_path: NodePath = ^"../TimeOfDay"
@export var transition_seconds := 2.0
@export var start_weather := "clear"

var current := ""
var _rain: GPUParticles3D
var _snow: GPUParticles3D
var _collider: GPUParticlesCollisionHeightField3D
var _tween: Tween
var _brightness := 1.0
var _rain_mesh: QuadMesh
var _rain_process: ParticleProcessMaterial
## Seconds until the next lightning strike, and how long the current flash
## has lasted (-1 = none).
var _strike_in := 0.0
var _flash_t := -1.0

## The weather after `weather` in ORDER, wrapping Snow back to Clear. Unknown
## names restart at Clear.
static func next_weather(weather: String) -> String:
	var i := ORDER.find(weather)
	return ORDER[0] if i == -1 else ORDER[(i + 1) % ORDER.size()]

## Seconds to wait before the next lightning strike: `r` (0..1, from a random
## number) picks a point between LIGHTNING_MIN and LIGHTNING_MAX.
static func lightning_delay(r: float) -> float:
	return lerpf(LIGHTNING_MIN, LIGHTNING_MAX, clampf(r, 0.0, 1.0))

## Flash brightness (0..1) `t` seconds after a strike: a sharp peak, a dip, a
## second flicker, then a fade out over FLASH_SECONDS. 0 outside the flash.
static func flash_level(t: float) -> float:
	if t < 0.0 or t >= FLASH_SECONDS:
		return 0.0
	if t < 0.05:
		return t / 0.05
	if t < 0.12:
		return lerpf(1.0, 0.25, (t - 0.05) / 0.07)
	if t < 0.17:
		return lerpf(0.25, 0.8, (t - 0.12) / 0.05)
	return 0.8 * (1.0 - (t - 0.17) / (FLASH_SECONDS - 0.17))

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

func _process(delta: float) -> void:
	_update_lightning(delta)
	var cam := get_viewport().get_camera_3d()
	if cam:
		var at := cam.global_position
		_rain.global_position = at + Vector3(0, RAIN_HEIGHT, 0)
		_snow.global_position = at + Vector3(0, SNOW_HEIGHT, 0)

func _update_lightning(delta: float) -> void:
	var tod := _time_of_day()
	if not tod or not WEATHER[current].get("lightning", false):
		return
	if _flash_t >= 0.0:
		_flash_t += delta
		if _flash_t >= FLASH_SECONDS:
			_flash_t = -1.0
		tod.set_flash(flash_level(_flash_t))
		return
	_strike_in -= delta
	if _strike_in <= 0.0:
		_flash_t = 0.0
		_strike_in = lightning_delay(randf())

func _unhandled_input(event: InputEvent) -> void:
	# Like T, ignored while the full map has the game paused (D-93).
	if event.is_action_pressed("cycle_weather") and not get_tree().paused:
		set_weather(next_weather(current))
		get_viewport().set_input_as_handled()

func set_weather(weather: String, instant := false) -> void:
	if not WEATHER.has(weather):
		push_warning("Unknown weather '%s', using clear" % weather)
		weather = "clear"
	var previous := current
	var look: Dictionary = WEATHER[weather]
	var precip: String = look.precip
	var previous_precip: String = WEATHER[previous].precip if WEATHER.has(previous) else ""
	current = weather
	_flash_t = -1.0
	_strike_in = lightning_delay(randf()) * 0.4  # first strike comes sooner
	if precip == "rain":
		_configure_rain(look)
	if _tween:
		_tween.kill()
		_tween = null
	var fade := not instant and transition_seconds > 0.0
	if fade:
		_tween = create_tween().set_parallel()
	for particles: GPUParticles3D in [_rain, _snow]:
		var on := particles.name.to_lower() == precip
		if on and not (previous_precip == precip and particles.emitting):
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
	if not fade:
		tod.set_flash(0.0)
		tod.set_fog_extra(look.fog)
		tod.set_overcast(look.overcast)
		return
	tod.set_flash(0.0)
	_tween.tween_method(tod.set_overcast, tod.overcast, look.overcast, transition_seconds)
	_tween.tween_method(tod.set_fog_extra, tod.fog_extra, look.fog, transition_seconds)
	tod.show_toast(look.label)

## Point the shared rain emitter at a weather's drop count, streak size, wind
## slant and fall speed.
func _configure_rain(look: Dictionary) -> void:
	_rain.amount_ratio = float(look.drops) / RAIN_MAX_DROPS
	_rain_mesh.size = Vector2(look.width, look.length)
	_rain_process.direction = Vector3(look.slant, -1, 0)
	_rain_process.initial_velocity_min = look.speed.x
	_rain_process.initial_velocity_max = look.speed.y

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
	_rain_process = process
	_rain_mesh = mesh
	return _particles("Rain", RAIN_MAX_DROPS, 1.4, process, mesh, Color(0.8, 0.84, 0.92, 0.6))

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
