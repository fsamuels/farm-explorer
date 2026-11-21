extends Node
## Time-of-day presets (D-94, Dawn added in D-95): Day, Sunset, Dusk, Night and
## Dawn. T (`cycle_time_of_day`)
## steps to the next one, blending the sun, sky colour, ambient light and fog
## over `transition_seconds` and briefly naming the new time at the top of the
## screen. A lighting change only: no clock runs, and nothing else in the scene
## reacts to the time.
##
## The world is laid out with +x east and -z north (see map_math.gd), so the
## sunset sun sits low in the west, the moon rises in the southeast and the
## dawn sun comes up in the east.
##
## Weather (weather.gd, D-95) dims the scene through `set_overcast()`: the
## preset stays as chosen and `overcast_preset()` greys it on the way to the
## screen, so time of day and weather can change independently.

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
	},
}
const ORDER := ["day", "sunset", "dusk", "night", "dawn"]

@export var environment_path: NodePath = ^"../WorldEnvironment"
@export var sun_path: NodePath = ^"../DirectionalLight3D"
@export var transition_seconds := 1.5
@export var start_preset := "day"

var current := ""
## 0 = clear sky, 1 = fully overcast (set by weather.gd).
var overcast := 0.0
var _shown: Dictionary = {}
var _tween: Tween
var _toast: Label
var _toast_tween: Tween

## The preset after `preset_name` in ORDER, wrapping Dawn back to Day. Unknown names
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
## light and fog go grey at their own brightness, and fog thickens.
static func overcast_preset(p: Dictionary, amount: float) -> Dictionary:
	if amount <= 0.0:
		return p
	var out := p.duplicate()
	var grey := _grey(p.sky_color)
	out.sky_color = p.sky_color.lerp(grey, 0.8 * amount)
	out.fog_color = p.fog_color.lerp(grey, amount)
	out.ambient_color = p.ambient_color.lerp(_grey(p.ambient_color), 0.6 * amount)
	out.sun_energy = p.sun_energy * (1.0 - 0.75 * amount)
	out.fog_density = p.fog_density + 0.008 * amount
	return out

static func _grey(c: Color) -> Color:
	var l := c.get_luminance() * 0.85
	return Color(l, l, l * 1.05)

## Spherical blend between two rotations given as Euler degrees.
static func slerp_rotation(a: Vector3, b: Vector3, t: float) -> Vector3:
	var qa := Quaternion.from_euler(a * (PI / 180.0))
	var qb := Quaternion.from_euler(b * (PI / 180.0))
	return qa.slerp(qb, t).get_euler() * (180.0 / PI)

func _ready() -> void:
	_build_toast()
	set_preset(start_preset, true)

func _unhandled_input(event: InputEvent) -> void:
	# The full map pauses the tree (D-93), which would freeze a blend and its
	# label mid-way, so T only works while the game is running.
	if event.is_action_pressed("cycle_time_of_day") and not get_tree().paused:
		set_preset(next_preset(current))
		get_viewport().set_input_as_handled()

## Switch to preset `preset_name`, blending from whatever is on screen now (so a
## second press mid-transition starts from the half-blended state).
func set_preset(preset_name: String, instant := false) -> void:
	if not PRESETS.has(preset_name):
		push_warning("Unknown time-of-day preset '%s'" % preset_name)
		return
	current = preset_name
	var target: Dictionary = PRESETS[preset_name]
	if _tween:
		_tween.kill()
		_tween = null
	if instant or _shown.is_empty() or transition_seconds <= 0.0:
		_apply(target)
		return
	var from := _shown.duplicate()
	_tween = create_tween()
	_tween.tween_method(func(t: float): _apply(blend(from, target, t)), 0.0, 1.0, transition_seconds)
	show_toast(target.label)

## Change the cloud cover (0..1) and redraw the current lighting under it.
func set_overcast(amount: float) -> void:
	overcast = clampf(amount, 0.0, 1.0)
	if not _shown.is_empty():
		_apply(_shown)

## What's on screen now: the (possibly mid-blend) preset under the current
## overcast.
func shown() -> Dictionary:
	return overcast_preset(_shown, overcast)

func _apply(preset: Dictionary) -> void:
	_shown = preset
	var p := overcast_preset(preset, overcast)
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
	lighting_changed.emit(p)

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
