extends Node3D
## Weather (D-95, D-99, D-101, D-105): Clear, Drizzle, Rain, Downpour,
## Thunderstorm, Light fog, Heavy fog, Snow, Heavy snow, Rainbow and Aurora. R (`cycle_weather`) steps to the
## next one. Rain and snow are GPU particles emitted from a box that follows the
## active camera, so they're everywhere you go without filling the whole farm.
## The rain weathers share one emitter and differ in drop count, streak length, speed
## and wind slant; the fog weathers have no particles, only thicker fog.
## Thunderstorms add random lightning flashes (a brief brightening of the sky
## and ambient light through TimeOfDay.set_flash()).
## A heightfield collider that also follows the camera hides drops and flakes
## when they hit a roof, a tree or the ground, so it doesn't rain indoors. The
## sky clouds over through TimeOfDay.set_overcast(), and the particles are
## tinted by the scene's brightness so they don't glow at night.
## The rainbow is a faint seven-band arch that always stands in the eastern sky
## and moves with the active camera, like a real rainbow (you can't walk up to
## it), so it's seen facing east from anywhere. It fades in and out with the
## weather changes.
## The aurora is a sky effect: curtains of green and pink light in the northern
## sky, visible only once it's dark (the clear sky is otherwise unchanged).
##
## The ground and the roofs carry a `wet` and a `snow` level that rise and fall
## with the weather and persist after it changes (see `surface_step()`): rain
## wets them and opens puddles, snow settles in patches on anything facing up,
## and clear weather slowly dries and melts them. A shader overlay
## (shaders/weather_surface.gdshader) draws both.
##
## Not done yet: sound.

const ORDER := ["clear", "drizzle", "rain", "downpour", "thunderstorm", "light_fog", "heavy_fog", "haze", "heavy_smoke", "snow", "heavy_snow", "rainbow", "aurora"]
## Per weather: the label shown on screen, the cloud cover it puts on the sky
## (see TimeOfDay.overcast_preset), `fog` (extra fog density on top of that),
## `precip` ("rain", "snow" or "" for none) and, for rain, the drop count,
## streak size, wind slant (x per unit fall) and fall speed range; for snow,
## the flake count and wind slant. `wet` and `snow` are how fast (per second,
## 1 = fully) the ground and roofs get wetter or snowier, negative while they
## dry out or melt.
const WEATHER := {
	"clear": {"label": "Clear", "overcast": 0.0, "fog": 0.0, "precip": "", "wet": -0.006, "snow": -0.0017},
	"drizzle": {"label": "Drizzle", "overcast": 0.55, "fog": 0.0, "precip": "rain",
		"drops": 2500, "width": 0.012, "length": 0.3, "slant": 0.03, "speed": Vector2(9.0, 12.0), "wet": 0.02, "snow": -0.01},
	"rain": {"label": "Rain", "overcast": 1.0, "fog": 0.0, "precip": "rain",
		"drops": 9000, "width": 0.018, "length": 0.55, "slant": 0.08, "speed": Vector2(17.0, 21.0), "wet": 0.05, "snow": -0.02},
	"downpour": {"label": "Downpour", "overcast": 1.0, "fog": 0.004, "precip": "rain",
		"drops": 14000, "width": 0.022, "length": 0.75, "slant": 0.18, "speed": Vector2(20.0, 25.0), "wet": 0.12, "snow": -0.03},
	"thunderstorm": {"label": "Thunderstorm", "overcast": 1.0, "fog": 0.006, "precip": "rain", "lightning": true,
		"drops": 14000, "width": 0.022, "length": 0.75, "slant": 0.25, "speed": Vector2(20.0, 25.0), "wet": 0.12, "snow": -0.03},
	"light_fog": {"label": "Light fog", "overcast": 0.3, "fog": 0.012, "precip": "", "wet": -0.002, "snow": -0.001},
	"heavy_fog": {"label": "Heavy fog", "overcast": 0.5, "fog": 0.045, "precip": "", "wet": 0.0, "snow": -0.0005},
	"haze": {"label": "Smoke haze", "overcast": 0.1, "fog": 0.0, "precip": "ash", "flecks": 400, "slant": 0.05, "smoke": 0.5, "wet": -0.006, "snow": -0.0017},
	"heavy_smoke": {"label": "Heavy smoke", "overcast": 0.2, "fog": 0.0, "precip": "ash", "flecks": 1500, "slant": 0.1, "smoke": 1.0, "wet": -0.006, "snow": -0.0017},
	"snow": {"label": "Snow", "overcast": 0.7, "fog": 0.0, "precip": "snow", "wet": -0.02, "snow": 0.012,
		"flakes": 4000, "slant": 0.0},
	"heavy_snow": {"label": "Heavy snow", "overcast": 0.9, "fog": 0.02, "precip": "snow", "wet": -0.02, "snow": 0.04,
		"flakes": 10000, "slant": 0.22},
	"rainbow": {"label": "Rainbow", "overcast": 0.2, "fog": 0.0, "precip": "", "rainbow": true, "wet": -0.003, "snow": -0.0017},
	"aurora": {"label": "Aurora", "overcast": 0.0, "fog": 0.0, "precip": "", "aurora": true, "wet": -0.006, "snow": -0.0017},
}

## Special sky effects and the times of day (TimeOfDay preset names) they can
## be chosen at: a rainbow needs daylight (dawn through sunset) and the aurora
## needs a dark sky (dusk, and night when it is at its best). Any other weather
## is allowed at any time. The sky menu greys out a special at the wrong time
## and drops it when the time moves somewhere it can't be seen.
const SPECIAL_TIMES := {
	"rainbow": ["dawn", "sunrise", "day", "sunset"],
	"aurora": ["dusk", "night"],
}

## True if `weather` can be shown at time-of-day preset `preset_name`.
static func allowed_at(weather: String, preset_name: String) -> bool:
	return not SPECIAL_TIMES.has(weather) or preset_name in SPECIAL_TIMES[weather]

## Why a special can't be chosen at the wrong time, for the sky menu to show.
static func restriction_text(weather: String) -> String:
	match weather:
		"rainbow":
			return "A rainbow only appears from dawn to sunset."
		"aurora":
			return "The aurora only appears at dusk and at night."
	return ""

## The rainbow's arch lies in a north-south plane (+x east, -z north),
## RAINBOW_DISTANCE east of the camera and RAINBOW_RADIUS high, so it stands
## ~31 degrees high and ~60 degrees wide.
const RAINBOW_DISTANCE := 150.0
const RAINBOW_RADIUS := 90.0
const RAINBOW_BAND_WIDTH := 3.0
const RAINBOW_STEPS := 48
const RAINBOW_ALPHA := 0.22
## How opaque each band is (outermost first), so the arch's edges are soft.
const RAINBOW_BAND_ALPHA := [0.45, 0.75, 1.0, 1.0, 1.0, 0.75, 0.45]
## Outermost band first, as a real rainbow has red on the outside.
const RAINBOW_COLORS := [
	Color(0.95, 0.15, 0.15), Color(1.0, 0.55, 0.1), Color(1.0, 0.92, 0.2),
	Color(0.25, 0.8, 0.3), Color(0.2, 0.55, 1.0), Color(0.3, 0.25, 0.8), Color(0.6, 0.3, 0.8),
]

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
## Likewise for snow: the emitter is built for heavy snow.
const SNOW_MAX_FLAKES := 10000
## Falling ash in smoke: the emitter is built for this many flecks.
const ASH_MAX_FLECKS := 3000

## Meshes that carry the wet / snow overlay: the ground imagery (group) and any
## mesh under the buildings node with this in its name.
const SURFACE_GROUP := "map_imagery"
const ROOF_NAME := "Roof"
## While snow melts, this fraction of what melts turns into wetness.
const MELT_TO_WET := 1.0
const SURFACE_SHADER := preload("res://shaders/weather_surface.gdshader")

@export var time_of_day_path: NodePath = ^"../TimeOfDay"
@export var transition_seconds := 2.0
@export var start_weather := "clear"
@export var buildings_path: NodePath = ^"../Buildings"
## Start the ground off wet or snowy (0..1), e.g. for screenshots.
@export_range(0.0, 1.0) var start_wet := 0.0
@export_range(0.0, 1.0) var start_snow := 0.0

var current := ""
var _rain: GPUParticles3D
var _snow: GPUParticles3D
var _collider: GPUParticlesCollisionHeightField3D
var _tween: Tween
var _brightness := 1.0
var _rain_mesh: QuadMesh
var _rain_process: ParticleProcessMaterial
var _snow_process: ParticleProcessMaterial
var _ash: GPUParticles3D
var _ash_process: ParticleProcessMaterial
var _rainbow: MeshInstance3D
var _rainbow_fade := 0.0
## Seconds until the next lightning strike, and how long the current flash
## has lasted (-1 = none).
var _strike_in := 0.0
var _flash_t := -1.0
## How wet (puddles, gloss) and how snowy (settled snow) the ground and roofs
## are, 0..1. They change slowly with the weather and outlast it.
var surface_wet := 0.0
var surface_snow := 0.0
var _surface_material: ShaderMaterial
var _surface_meshes: Array[MeshInstance3D] = []
var _overlay_on := false

## The weather after `weather` in ORDER, wrapping Snow back to Clear. Unknown
## names restart at Clear.
static func next_weather(weather: String) -> String:
	var i := ORDER.find(weather)
	return ORDER[0] if i == -1 else ORDER[(i + 1) % ORDER.size()]

## The wet and snow levels after `delta` seconds of `weather`: each moves at
## the weather's `wet` / `snow` rate, snow that melts leaves the ground wetter,
## and both stay within 0..1.
static func surface_step(wet: float, snow: float, weather: String, delta: float) -> Vector2:
	var look: Dictionary = WEATHER.get(weather, WEATHER.clear)
	var snow_change: float = look.snow * delta
	var new_snow := clampf(snow + snow_change, 0.0, 1.0)
	var melted := snow - new_snow  # > 0 only while snow is going
	var new_wet := clampf(wet + look.wet * delta + maxf(melted, 0.0) * MELT_TO_WET, 0.0, 1.0)
	return Vector2(new_wet, new_snow)

## Whether a mesh named `node_name` under the buildings node gets the overlay.
static func is_roof(node_name: String) -> bool:
	return node_name.contains(ROOF_NAME)

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

## Where the rainbow stands for a camera at `camera`: due east of it, on the
## ground, so the arch looks the same from wherever you are.
static func rainbow_position(camera: Vector3) -> Vector3:
	return Vector3(camera.x + RAINBOW_DISTANCE, 0.0, camera.z)

## A point on a rainbow arch of `radius` in its own plane: `t` 0..1 runs from
## the south foot (on the ground) over the top to the north foot. Local x is 0
## (the arch's plane), y up and z south, so -z is north.
static func arch_point(radius: float, t: float) -> Vector3:
	var a := PI * clampf(t, 0.0, 1.0)
	return Vector3(0.0, radius * sin(a), radius * cos(a))

## The rainbow as a mesh of RAINBOW_COLORS.size() ribbons, each `band_width`
## thick, outermost at `radius`. Vertex alpha fades to 0 at the feet.
static func build_rainbow_mesh(radius: float, band_width: float, steps: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for band in RAINBOW_COLORS.size():
		var outer := radius - band * band_width
		var inner := outer - band_width
		var base := verts.size()
		for i in steps + 1:
			var t := float(i) / steps
			var c: Color = RAINBOW_COLORS[band]
			c.a = pow(sin(PI * t), 1.5) * RAINBOW_BAND_ALPHA[band]  # 0 at the feet, strongest at the top
			verts.append(arch_point(outer, t))
			verts.append(arch_point(inner, t))
			colors.append(c)
			colors.append(c)
		for i in steps:
			var v := base + i * 2
			indices.append_array([v, v + 1, v + 2, v + 1, v + 3, v + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

## How bright (0.15..1) to draw rain and snow under lighting preset `p`, so
## they read as lit by the scene rather than glowing white at night.
static func particle_brightness(p: Dictionary) -> float:
	var lit: float = p.ambient_energy * p.ambient_color.get_luminance() + 0.5 * p.sun_energy
	return clampf(lit, 0.15, 1.0)

func _ready() -> void:
	_rain = _build_rain()
	_snow = _build_snow()
	_ash = _build_ash()
	_rainbow = _build_rainbow()
	_build_surfaces()
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
	var level := surface_step(surface_wet, surface_snow, current, delta)
	# Not is_equal_approx: a slow rate moves a level by less than its 1e-5
	# tolerance in one frame, and the change would be dropped every frame.
	if level.x != surface_wet or level.y != surface_snow:
		set_surfaces(level.x, level.y)
	var cam := get_viewport().get_camera_3d()
	if cam:
		var at := cam.global_position
		_rain.global_position = at + Vector3(0, RAIN_HEIGHT, 0)
		_snow.global_position = at + Vector3(0, SNOW_HEIGHT, 0)
		_ash.global_position = at + Vector3(0, SNOW_HEIGHT, 0)
		_rainbow.global_position = rainbow_position(at)

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
	elif precip == "snow":
		_configure_snow(look)
	elif precip == "ash":
		_configure_ash(look)
	if _tween:
		_tween.kill()
		_tween = null
	var fade := not instant and transition_seconds > 0.0
	if fade:
		_tween = create_tween().set_parallel()
	for particles: GPUParticles3D in [_rain, _snow, _ash]:
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
	var rainbow_target := 1.0 if look.get("rainbow", false) else 0.0
	if fade:
		_tween.tween_method(_set_rainbow_fade, _rainbow_fade, rainbow_target, transition_seconds)
	else:
		_set_rainbow_fade(rainbow_target)
	var tod := _time_of_day()
	if not tod:
		return
	var aurora_target := 1.0 if look.get("aurora", false) else 0.0
	var smoke_target: float = look.get("smoke", 0.0)
	if not fade:
		tod.set_flash(0.0)
		tod.set_fog_extra(look.fog)
		tod.set_overcast(look.overcast)
		tod.set_aurora(aurora_target)
		tod.set_smoke(smoke_target)
		return
	tod.set_flash(0.0)
	_tween.tween_method(tod.set_aurora, tod.aurora_level, aurora_target, transition_seconds)
	_tween.tween_method(tod.set_smoke, tod.smoke_level, smoke_target, transition_seconds)
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

## Point the snow emitter at a weather's flake count and wind slant.
func _configure_snow(look: Dictionary) -> void:
	_snow.amount_ratio = float(look.flakes) / SNOW_MAX_FLAKES
	_snow_process.direction = Vector3(look.slant, -1, 0)

## Point the ash emitter at a weather's fleck count and wind slant.
func _configure_ash(look: Dictionary) -> void:
	_ash.amount_ratio = float(look.flecks) / ASH_MAX_FLECKS
	_ash_process.direction = Vector3(look.slant, -1, 0)

## Find the ground and roof meshes and give them the shared overlay material.
func _build_surfaces() -> void:
	_surface_material = ShaderMaterial.new()
	_surface_material.shader = SURFACE_SHADER
	# Draw after the farm's alpha-blended orthomosaic patches, which sort at the
	# same depth; otherwise snow vanishes from them depending on camera position.
	_surface_material.render_priority = 1
	for node in get_tree().get_nodes_in_group(SURFACE_GROUP):
		if node is MeshInstance3D:
			_surface_meshes.append(node)
	var buildings := get_node_or_null(buildings_path)
	if buildings:
		for node in buildings.find_children("*", "MeshInstance3D", true, false):
			if is_roof(node.name):
				_surface_meshes.append(node)
	set_surfaces(start_wet, start_snow)

## Give a mesh made after start-up (a chunk of the driveable world, D-146) the
## wet / snow overlay too, and take it off the list again when it's freed.
func add_surface(mesh: MeshInstance3D) -> void:
	if mesh in _surface_meshes:
		return
	_surface_meshes.append(mesh)
	if _overlay_on and _surface_material:
		mesh.material_overlay = _surface_material

func remove_surface(mesh: MeshInstance3D) -> void:
	_surface_meshes.erase(mesh)

## Set how wet and snowy the ground and roofs are (0..1). The overlay is only
## attached to the meshes while there is something to show.
func set_surfaces(wet: float, snow: float) -> void:
	surface_wet = clampf(wet, 0.0, 1.0)
	surface_snow = clampf(snow, 0.0, 1.0)
	if not _surface_material:
		return
	_surface_material.set_shader_parameter("wet", surface_wet)
	_surface_material.set_shader_parameter("snow", surface_snow)
	var on := surface_wet > 0.003 or surface_snow > 0.003
	if on == _overlay_on:
		return
	_overlay_on = on
	for mesh in _surface_meshes:
		mesh.material_overlay = _surface_material if on else null

func _time_of_day() -> Node:
	return get_node_or_null(time_of_day_path)

func _on_lighting_changed(p: Dictionary) -> void:
	_brightness = particle_brightness(p)
	for particles in [_rain, _snow, _ash]:
		_tint(particles)
	_tint_rainbow()

func _set_rainbow_fade(amount: float) -> void:
	_rainbow_fade = amount
	_tint_rainbow()

## Vertex colours give the bands and their faded feet; the material colour
## dims the lot by the scene's brightness and by the fade (0 = hidden).
func _tint_rainbow() -> void:
	var mat := _rainbow.material_override as StandardMaterial3D
	mat.albedo_color = Color(_brightness, _brightness, _brightness, RAINBOW_ALPHA * _rainbow_fade)
	_rainbow.visible = _rainbow_fade > 0.001

func _build_rainbow() -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var node := MeshInstance3D.new()
	node.name = "Rainbow"
	node.mesh = build_rainbow_mesh(RAINBOW_RADIUS, RAINBOW_BAND_WIDTH, RAINBOW_STEPS)
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = rainbow_position(Vector3.ZERO)
	node.visible = false
	add_child(node)
	return node

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
	_snow_process = process
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
	return _particles("Snow", SNOW_MAX_FLAKES, 9.0, process, mesh, Color(1, 1, 1, 0.9))

## Ash from distant fires: small dark flecks, like snow but fewer, smaller,
## slower and tumbling about more in the air.
func _build_ash() -> GPUParticles3D:
	var process := _process_material(Vector3(0.05, -1, 0), 30.0, 0.5, 0.9)
	process.gravity = Vector3(0, -0.15, 0)
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.9
	process.turbulence_influence_min = 0.05
	process.turbulence_influence_max = 0.12
	_ash_process = process
	var mat := _particle_material(Color(0.3, 0.27, 0.25, 0.85), BaseMaterial3D.BILLBOARD_ENABLED)
	var dot := GradientTexture2D.new()
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(0.5, 0.0)
	dot.gradient = Gradient.new()
	dot.gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	dot.width = 16
	dot.height = 16
	mat.albedo_texture = dot
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.07, 0.07)
	mesh.material = mat
	return _particles("Ash", ASH_MAX_FLECKS, 12.0, process, mesh, Color(0.3, 0.27, 0.25, 0.85))

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
