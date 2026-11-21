extends Node
## Time-of-day presets (D-94; Dawn D-95, Sunrise D-96): Day, Sunset, Dusk,
## Night, Dawn and Sunrise. T (`cycle_time_of_day`)
## steps to the next one, blending the sun, sky colour, ambient light and fog
## over `transition_seconds` and briefly naming the new time at the top of the
## screen. A lighting change only: nothing else in the scene reacts to the time.
##
## A running clock (Y, `toggle_clock`) can instead advance the time on its own:
## `hour` moves through the day and the lighting is blended between the presets
## placed on it by KEYFRAMES. T stops the clock and jumps to the next preset;
## Y starts it again from there. The clock starts stopped.
##
## The world is laid out with +x east and -z north (see map_math.gd), so the
## sunset sun sits low in the west, the moon rises in the southeast and the
## dawn sun comes up in the east.
##
## The sky itself is a shader (shaders/night_sky.gdshader, D-103): the flat sky
## colour of the preset, with the stars, a Milky Way and constellation lines
## fading in as the preset's `stars` level rises (dusk, dawn and night). The
## stars sit where they really are over Lowden for today's date and the clock
## hour, so they turn with the running clock; N toggles the constellation lines.
##
## Weather (weather.gd, D-95) dims the scene through `set_overcast()`: the
## preset stays as chosen and `overcast_preset()` greys it on the way to the
## screen, so time of day and weather can change independently.

const SkyMath := preload("res://scripts/sky_math.gd")
const StarMap := preload("res://scripts/star_map.gd")
const SKY_SHADER := preload("res://shaders/night_sky.gdshader")

signal lighting_changed(p: Dictionary)

## Each preset holds the same keys; `blend()` lerps between any two of them.
## "day" reproduces the lighting main.tscn had before this script existed.
const PRESETS := {
	"day": {
		"label": "Day",
		"sun_rotation": Vector3(-45, -30, 0),
		"sun_color": Color(1, 1, 1),
		"sun_energy": 1.0,
		"sky_color": Color(0.55, 0.75, 0.95),
		"ambient_color": Color(0.6, 0.65, 0.7),
		"ambient_energy": 1.0,
		"fog_color": Color(0.55, 0.75, 0.95),
		"fog_density": 0.0,
		"stars": 0.0,
	},
	"sunset": {
		"label": "Sunset",
		"sun_rotation": Vector3(-8, -90, 0),
		"sun_color": Color(1.0, 0.62, 0.35),
		"sun_energy": 1.1,
		"sky_color": Color(0.95, 0.6, 0.4),
		"ambient_color": Color(0.7, 0.55, 0.5),
		"ambient_energy": 0.8,
		"fog_color": Color(0.95, 0.65, 0.45),
		"fog_density": 0.003,
		"stars": 0.0,
	},
	"dusk": {
		"label": "Dusk",
		"sun_rotation": Vector3(-4, -100, 0),
		"sun_color": Color(0.55, 0.45, 0.75),
		"sun_energy": 0.25,
		"sky_color": Color(0.32, 0.3, 0.5),
		"ambient_color": Color(0.4, 0.4, 0.6),
		"ambient_energy": 0.55,
		"fog_color": Color(0.35, 0.32, 0.5),
		"fog_density": 0.004,
		"stars": 0.45,
	},
	"night": {
		"label": "Night",
		"sun_rotation": Vector3(-40, 45, 0),
		"sun_color": Color(0.6, 0.7, 1.0),
		"sun_energy": 0.3,
		"sky_color": Color(0.03, 0.04, 0.09),
		"ambient_color": Color(0.25, 0.3, 0.5),
		"ambient_energy": 0.45,
		"fog_color": Color(0.04, 0.05, 0.1),
		"fog_density": 0.006,
		"stars": 1.0,
	},
	"dawn": {
		"label": "Dawn",
		"sun_rotation": Vector3(-6, 90, 0),
		"sun_color": Color(1.0, 0.75, 0.6),
		"sun_energy": 0.8,
		"sky_color": Color(0.85, 0.72, 0.75),
		"ambient_color": Color(0.6, 0.6, 0.72),
		"ambient_energy": 0.7,
		"fog_color": Color(0.88, 0.78, 0.8),
		"fog_density": 0.004,
		"stars": 0.35,
	},
	"sunrise": {
		"label": "Sunrise",
		"sun_rotation": Vector3(-12, 85, 0),
		"sun_color": Color(1.0, 0.72, 0.48),
		"sun_energy": 1.0,
		"sky_color": Color(0.95, 0.76, 0.58),
		"ambient_color": Color(0.7, 0.63, 0.56),
		"ambient_energy": 0.85,
		"fog_color": Color(0.95, 0.8, 0.66),
		"fog_density": 0.002,
		"stars": 0.0,
	},
}
const ORDER := ["day", "sunset", "dusk", "night", "dawn", "sunrise"]
## Where each preset sits on the 24 h clock, in clock order. Night is a long
## stretch (23:00 to 05:30) so the clock spends real time in the dark.
const KEYFRAMES := [[5.5, "dawn"], [6.5, "sunrise"], [13.0, "day"], [18.5, "sunset"], [19.5, "dusk"], [23.0, "night"]]

@export var environment_path: NodePath = ^"../WorldEnvironment"
@export var sun_path: NodePath = ^"../DirectionalLight3D"
@export var transition_seconds := 1.5
@export var start_preset := "day"
## Real seconds one 24 h clock day takes while the clock runs.
@export var day_seconds := 1200.0
## Width of the baked star map in pixels (the height is half). Lower it for a
## cheaper start-up, e.g. on Web.
@export var star_map_width := 4096
## Draw faint constellation lines in the sky (N toggles).
@export var show_constellations := true

var current := ""
## 0 = clear sky, 1 = fully overcast (set by weather.gd).
var overcast := 0.0
## Fog added on top of the preset's (set by weather.gd for the fog weathers).
var fog_extra := 0.0
## Lightning flash brightness, 0..1 (set by weather.gd during thunderstorms).
var flash := 0.0
## The clock hour (0..24) the lighting is at, and whether it's advancing.
var hour := 13.0
var clock_running := false
## The hour the stars are drawn for. It equals `hour` except while a preset
## blend runs, when it turns forward from the old hour to the new one so the
## stars don't jump.
var sky_hour := 13.0
var _sky_material: ShaderMaterial
## Days from J2000 noon to noon today: which stars are up depends on the date.
var _sky_days := 0.0
var _shown: Dictionary = {}
var _tween: Tween
var _toast: Label
var _toast_tween: Tween

## The preset after `preset_name` in ORDER, wrapping Sunrise back to Day. Unknown names
## restart the cycle at Day.
static func next_preset(preset_name: String) -> String:
	var i := ORDER.find(preset_name)
	return ORDER[0] if i == -1 else ORDER[(i + 1) % ORDER.size()]

## Lerp every numeric field of two presets; t = 0 gives `a`, 1 gives `b`.
## Non-numeric fields (the label) come from `b`. The sun's rotation is
## slerped, so it moves along the shortest arc at a steady rate rather than
## sweeping each Euler angle independently.
static func blend(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out := {}
	for key in b:
		var va = a.get(key, b[key])
		var vb = b[key]
		if key == "sun_rotation":
			out[key] = slerp_rotation(va, vb, t)
		elif vb is float or vb is Color or vb is Vector3:
			out[key] = lerp(va, vb, t)
		else:
			out[key] = vb
	return out

## `p` under cloud cover `amount` (0..1): the sun dims, the sky, ambient
## light and fog go grey at their own brightness, and fog thickens. `extra_fog`
## adds fog density on top (the fog weathers) and greys the fog colour, and
## `flash` (0..1) is a lightning flash that brightens the sky and ambient
## light. Always returns a fresh, writable copy (never one of the read-only
## PRESETS).
static func overcast_preset(p: Dictionary, amount: float, extra_fog := 0.0, flash_amount := 0.0) -> Dictionary:
	var out := p.duplicate()
	if amount > 0.0:
		# Cloud hides the stars much faster than it dims the sun.
		out.stars = p.stars * pow(1.0 - clampf(amount, 0.0, 1.0), 2.0)
		var grey := _grey(p.sky_color)
		out.sky_color = p.sky_color.lerp(grey, 0.8 * amount)
		out.fog_color = p.fog_color.lerp(grey, amount)
		out.ambient_color = p.ambient_color.lerp(_grey(p.ambient_color), 0.6 * amount)
		out.sun_energy = p.sun_energy * (1.0 - 0.75 * amount)
		out.fog_density = p.fog_density + 0.008 * amount
	if extra_fog > 0.0:
		out.fog_density += extra_fog
		# Thick fog is the same grey whatever the hour, but keeps its own brightness.
		var thick := minf(1.0, extra_fog / 0.012)
		out.fog_color = out.fog_color.lerp(_grey(out.fog_color), thick)
		# The background is a flat colour that fog doesn't touch, so match it to
		# the fog or the sky shows as a seam above the greyed-out distance.
		out.sky_color = out.sky_color.lerp(out.fog_color, thick)
		out.stars *= 1.0 - minf(1.0, extra_fog / 0.03)  # light fog dims them, heavy fog hides them
	if flash_amount > 0.0:
		var f := clampf(flash_amount, 0.0, 1.0)
		out.sky_color = out.sky_color.lerp(Color(0.85, 0.9, 1.0), 0.7 * f)
		out.ambient_color = out.ambient_color.lerp(Color(0.8, 0.85, 1.0), f)
		out.ambient_energy = p.ambient_energy + 1.5 * f
	return out

static func _grey(c: Color) -> Color:
	var l := c.get_luminance() * 0.85
	return Color(l, l, l * 1.05)

## The lighting at clock `h` (hours, wrapping at 24): the blend between the two
## KEYFRAMES presets it falls between.
static func preset_at_hour(h: float) -> Dictionary:
	var n := KEYFRAMES.size()
	h = fposmod(h, 24.0)
	for i in n:
		var a: Array = KEYFRAMES[i]
		var b: Array = KEYFRAMES[(i + 1) % n]
		var span := fposmod(b[0] - a[0], 24.0)
		var into := fposmod(h - a[0], 24.0)
		if into < span:
			return blend(PRESETS[a[1]], PRESETS[b[1]], into / span)
	return PRESETS.day.duplicate()  # unreachable: the spans cover the whole day

## The name of the last preset the clock has passed at hour `h`.
static func keyframe_before(h: float) -> String:
	var n := KEYFRAMES.size()
	h = fposmod(h, 24.0)
	for i in n:
		var a: Array = KEYFRAMES[i]
		var b: Array = KEYFRAMES[(i + 1) % n]
		if fposmod(h - a[0], 24.0) < fposmod(b[0] - a[0], 24.0):
			return a[1]
	return "day"

## The clock hour a preset sits at.
static func hour_of(preset_name: String) -> float:
	for k in KEYFRAMES:
		if k[1] == preset_name:
			return k[0]
	return 13.0

## Hour 13.5 as "13:30".
static func format_hour(h: float) -> String:
	var minutes := int(floorf(fposmod(h, 24.0) * 60.0))
	return "%02d:%02d" % [minutes / 60, minutes % 60]

## Spherical blend between two rotations given as Euler degrees.
static func slerp_rotation(a: Vector3, b: Vector3, t: float) -> Vector3:
	var qa := Quaternion.from_euler(a * (PI / 180.0))
	var qb := Quaternion.from_euler(b * (PI / 180.0))
	return qa.slerp(qb, t).get_euler() * (180.0 / PI)

func _ready() -> void:
	_build_toast()
	_build_sky()
	set_preset(start_preset, true)

func _process(delta: float) -> void:
	if clock_running:
		hour = fposmod(hour + delta * 24.0 / maxf(day_seconds, 1.0), 24.0)
		current = keyframe_before(hour)
		sky_hour = hour
		_apply(preset_at_hour(hour))

func _unhandled_input(event: InputEvent) -> void:
	# The full map pauses the tree (D-93), which would freeze a blend and its
	# label mid-way, so T and Y only work while the game is running.
	if get_tree().paused:
		return
	if event.is_action_pressed("cycle_time_of_day"):
		set_preset(next_preset(current))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_clock"):
		set_clock_running(not clock_running)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_constellations"):
		show_constellations = not show_constellations
		if not _shown.is_empty():
			_apply(_shown)
		show_toast("Constellation lines " + ("on" if show_constellations else "off"))
		get_viewport().set_input_as_handled()

## Start or stop the running clock. Starting continues from the hour set by the
## last preset picked; stopping holds whatever the clock reached.
func set_clock_running(on: bool) -> void:
	if on == clock_running:
		return
	clock_running = on
	if on:
		if _tween:
			_tween.kill()
			_tween = null
		sky_hour = hour  # don't leave the stars part-way through a blend
	show_toast("Clock running" if on else "Clock paused at " + format_hour(hour))

## Switch to preset `preset_name`, blending from whatever is on screen now (so a
## second press mid-transition starts from the half-blended state).
func set_preset(preset_name: String, instant := false) -> void:
	if not PRESETS.has(preset_name):
		push_warning("Unknown time-of-day preset '%s'" % preset_name)
		return
	current = preset_name
	hour = hour_of(preset_name)
	clock_running = false  # picking a preset stops the clock
	var target: Dictionary = PRESETS[preset_name]
	if _tween:
		_tween.kill()
		_tween = null
	var from_hour := sky_hour
	if instant or _shown.is_empty() or transition_seconds <= 0.0:
		sky_hour = hour
		_apply(target)
		return
	var from := _shown.duplicate()
	var turn := fposmod(hour - from_hour, 24.0)  # the sky only turns forward
	_tween = create_tween()
	_tween.tween_method(func(t: float):
		sky_hour = from_hour + turn * t
		_apply(blend(from, target, t)), 0.0, 1.0, transition_seconds)
	show_toast(target.label)

## Change the cloud cover (0..1) and redraw the current lighting under it.
func set_overcast(amount: float) -> void:
	overcast = clampf(amount, 0.0, 1.0)
	if not _shown.is_empty():
		_apply(_shown)

## Change the extra fog density (0 = the preset's own) and redraw.
func set_fog_extra(amount: float) -> void:
	fog_extra = maxf(amount, 0.0)
	if not _shown.is_empty():
		_apply(_shown)

## Set the lightning flash (0..1) and redraw.
func set_flash(amount: float) -> void:
	flash = clampf(amount, 0.0, 1.0)
	if not _shown.is_empty():
		_apply(_shown)

## What's on screen now: the (possibly mid-blend) preset under the current
## weather.
func shown() -> Dictionary:
	return overcast_preset(_shown, overcast, fog_extra, flash)

func _apply(preset: Dictionary) -> void:
	_shown = preset
	var p := overcast_preset(preset, overcast, fog_extra, flash)
	var sun := get_node_or_null(sun_path) as DirectionalLight3D
	if sun:
		sun.rotation_degrees = p.sun_rotation
		sun.light_color = p.sun_color
		sun.light_energy = p.sun_energy
	var world := get_node_or_null(environment_path) as WorldEnvironment
	if world and world.environment:
		var env := world.environment
		env.background_color = p.sky_color
		env.ambient_light_color = p.ambient_color
		env.ambient_light_energy = p.ambient_energy
		env.fog_enabled = p.fog_density > 0.0
		env.fog_light_color = p.fog_color
		env.fog_density = p.fog_density
	_apply_sky(p)
	lighting_changed.emit(p)

## Create the sky shader, bake the star maps and put the sky in the
## environment in place of its flat background colour. Skipped without an
## environment (a test scene, say).
func _build_sky() -> void:
	var world := get_node_or_null(environment_path) as WorldEnvironment
	if not world or not world.environment:
		return
	var date := Time.get_date_dict_from_system()
	_sky_days = SkyMath.days_since_j2000(date.year, date.month, date.day)
	var w := maxi(star_map_width, 64)
	_sky_material = ShaderMaterial.new()
	_sky_material.shader = SKY_SHADER
	_sky_material.set_shader_parameter("star_map", ImageTexture.create_from_image(StarMap.bake_stars(w, w / 2)))
	_sky_material.set_shader_parameter("line_map", ImageTexture.create_from_image(StarMap.bake_lines(w, w / 2)))
	var sky := Sky.new()
	sky.sky_material = _sky_material
	# Reflections only need a rough sky, and the shader changes every frame
	# while the clock runs: keep the cubemap small and update it gradually.
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	var env := world.environment
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.fog_sky_affect = 0.0  # fog would otherwise swallow the stars

## Point the sky shader at lighting `p`: its colour, how many stars to show and
## which way the celestial sphere is turned.
func _apply_sky(p: Dictionary) -> void:
	if not _sky_material:
		return
	_sky_material.set_shader_parameter("sky_color", p.sky_color)
	_sky_material.set_shader_parameter("star_strength", p.stars)
	_sky_material.set_shader_parameter("line_strength", 0.14 if show_constellations else 0.0)
	var lst := SkyMath.sidereal_degrees(_sky_days, sky_hour)
	_sky_material.set_shader_parameter("sky_to_celestial", SkyMath.celestial_to_world(SkyMath.LATITUDE, lst).transposed())

func _build_toast() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_toast = Label.new()
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_top = 40
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 40)
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.modulate.a = 0.0
	layer.add_child(_toast)

## Briefly name something at the top of the screen (also used by weather.gd).
func show_toast(text: String) -> void:
	_toast.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.2)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)
