extends Node
## Time-of-day presets (D-94; Dawn D-95, Sunrise D-96): Day, Sunset, Dusk,
## Night, Dawn and Sunrise. T (`cycle_time_of_day`)
## steps to the next one, blending the sun, sky colour, ambient light and fog
## over `transition_seconds` and briefly naming the new time at the top of the
## screen. A lighting change only: nothing else in the scene reacts to the time.
##
## A running clock (Y, `toggle_clock`, on by default) can instead advance the time on its own:
## `hour` moves through the day and the lighting is blended between the presets
## placed on it by KEYFRAMES. T stops the clock and jumps to the next preset;
## Y starts it again from there. The clock starts running, at Day (13:00).
##
## The world is laid out with +x east and -z north (see map_math.gd), so the
## sunset sun sits low in the west, the moon rises in the southeast and the
## dawn sun comes up in the east.
##
## The sky itself is a shader (shaders/night_sky.gdshader, D-104): the flat sky
## colour of the preset, with the stars, a Milky Way and constellation lines
## fading in as the preset's `stars` level rises (dusk, dawn and night). The
## stars sit where they really are over Lowden for today's date and the clock
## hour, so they turn with the running clock; N toggles the constellation lines.
##
## The moon (D-123) is a full moon that rises in the east and sets in the west
## on the clock (`moon_direction()`), lights the night from where it hangs, and
## washes out the fainter stars while it is high. It can be turned off for good
## (`set_moon_enabled()`), leaving dark nights. Shooting stars have a rate
## (`set_meteor_level()`: off, some, shower), and typing "starlink" in the sky
## menu sends a train of satellites across a dark sky (`start_starlink()`).
##
## The northern lights (D-105) are drawn by the same sky shader, in the north
## (-z) sky: weather.gd turns them on with set_aurora(), and they show only as
## far as the stars do, so they need a dark, clear sky.
##
## Weather (weather.gd, D-95) dims the scene through `set_overcast()`: the
## preset stays as chosen and `overcast_preset()` greys it on the way to the
## screen, so time of day and weather can change independently.

const SkyMath := preload("res://scripts/sky_math.gd")
const StarMap := preload("res://scripts/star_map.gd")
const ConstellationNames := preload("res://scripts/constellation_names.gd")
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
		"aurora": 0.0,
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
		"aurora": 0.0,
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
		"aurora": 0.0,
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
		"aurora": 0.0,
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
		"aurora": 0.0,
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
		"aurora": 0.0,
	},
}
const ORDER := ["day", "sunset", "dusk", "night", "dawn", "sunrise"]

## The full moon crosses due south at this clock hour, so it rises about six
## hours earlier (18:30, as the sun sets) and sets six hours later (06:30).
const MOON_TRANSIT_HOUR := 0.5
## How much of the star light a high moon washes out (0..1).
const MOON_GLARE := 0.5
## Shooting stars: seconds between possible streaks for each level; 0 is off.
const METEOR_LEVELS := [["off", 0.0], ["some", 11.0], ["shower", 2.5]]
## A Starlink train takes this long to cross the sky, and needs the sky at least
## this dark (the `stars` level, after cloud and fog) to be seen.
const STARLINK_SECONDS := 70.0
const STARLINK_MIN_STARS := 0.3
## Where each preset sits on the 24 h clock, in clock order. Night is a long
## stretch (23:00 to 05:30) so the clock spends real time in the dark.
const KEYFRAMES := [[5.5, "dawn"], [6.5, "sunrise"], [13.0, "day"], [18.5, "sunset"], [19.5, "dusk"], [23.0, "night"]]

## How coarsely the on-screen clock reads: it rounds to this many clock hours.
## Half an hour of a 20-minute day is 25 real seconds, so the text changes
## about twice a minute rather than every frame. The cadence scales with
## `day_seconds` (half a clock hour = day_seconds / 48 real seconds), so
## retune this if the day length changes.
const CLOCK_STEP_HOURS := 0.5

@export var environment_path: NodePath = ^"../WorldEnvironment"
@export var sun_path: NodePath = ^"../DirectionalLight3D"
@export var transition_seconds := 1.5
@export var start_preset := "day"
## Whether the clock is running from the first frame (Y toggles it).
@export var start_clock_running := true
## Real seconds one 24 h clock day takes while the clock runs.
@export var day_seconds := 1200.0
## Width of the baked star map in pixels (the height is half). Lower it for a
## cheaper start-up, e.g. on Web.
@export var star_map_width := 4096
## Draw faint constellation lines in the sky (N toggles).
@export var show_constellations := true
## The moon: on (rises and sets) or off for good.
@export var moon_enabled := true
## Index into METEOR_LEVELS: off, some (the default) or a shower.
@export var meteor_level := 1

var current := ""
## 0 = clear sky, 1 = fully overcast (set by weather.gd).
var overcast := 0.0
## Fog added on top of the preset's (set by weather.gd for the fog weathers).
var fog_extra := 0.0
## Lightning flash brightness, 0..1 (set by weather.gd during thunderstorms).
var flash := 0.0
## Northern lights, 0..1 (set by weather.gd); shown only when the sky is dark.
var aurora_level := 0.0
## Wildfire smoke, 0..1 (set by weather.gd).
var smoke_level := 0.0
## Seconds into a Starlink train's crossing, or -1 when none is on.
var _train_time := -1.0
var _meteor_time := 0.0
var _meteor_shown := 0.0
var _aurora_time := 0.0
var _aurora_shown := 0.0
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
var _clock_label: Label
var _name_labels: Array[Label] = []

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
static func overcast_preset(p: Dictionary, amount: float, extra_fog := 0.0, flash_amount := 0.0, aurora_amount := 0.0, smoke_amount := 0.0) -> Dictionary:
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
	if smoke_amount > 0.0:
		# Wildfire smoke (0..1): unlike fog it is warm. The light, the sky, the
		# haze and the ambient all lean orange-brown at their own brightness
		# (so a smoky night is still dark), the sun dims to a dull disc, and the
		# haze is a thin distance veil rather than a wall. Smoke hides stars.
		var s := clampf(smoke_amount, 0.0, 1.0)
		out.fog_density += 0.014 * s
		# Colour comes on faster than density (blue mixed half way with orange
		# is grey, which is not what thin smoke looks like).
		var tint := sqrt(s)
		out.fog_color = out.fog_color.lerp(_smoke(out.fog_color), 0.85 * tint)
		out.sky_color = out.sky_color.lerp(_smoke(out.sky_color).lerp(out.fog_color, 0.5), 0.9 * tint)
		out.ambient_color = out.ambient_color.lerp(_smoke(out.ambient_color), 0.7 * tint)
		out.sun_color = out.sun_color.lerp(Color(1.0, 0.5, 0.25), 0.75 * tint)
		out.sun_energy *= 1.0 - 0.55 * s
		out.stars *= pow(1.0 - s, 2.0)
	if aurora_amount > 0.0:
		# The northern lights show only against a dark sky, so they follow the
		# stars: gone by day, and hidden by the same cloud and fog.
		out.aurora = clampf(aurora_amount, 0.0, 1.0) * out.stars
	if flash_amount > 0.0:
		var f := clampf(flash_amount, 0.0, 1.0)
		out.sky_color = out.sky_color.lerp(Color(0.85, 0.9, 1.0), 0.7 * f)
		out.ambient_color = out.ambient_color.lerp(Color(0.8, 0.85, 1.0), f)
		out.ambient_energy = p.ambient_energy + 1.5 * f
	return out

## `c` seen through wildfire smoke: the same brightness, tinted orange-brown.
static func _smoke(c: Color) -> Color:
	var l := c.get_luminance()
	return Color(l * 1.25, l * 0.78, l * 0.45)

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

## The on-screen clock's estimate of hour `h`: rounded to the nearest half hour,
## 12-hour style, so 18.4 reads "~6:30 PM". It only changes once per
## CLOCK_STEP_HOURS, which at the default day length is every 25 real seconds.
static func clock_estimate(h: float) -> String:
	var steps := int(roundf(fposmod(h, 24.0) / CLOCK_STEP_HOURS)) % int(24.0 / CLOCK_STEP_HOURS)
	var minutes := int(steps * CLOCK_STEP_HOURS * 60.0)
	var h24 := minutes / 60
	var h12 := h24 % 12
	return "~%d:%02d %s" % [12 if h12 == 0 else h12, minutes % 60, "AM" if h24 < 12 else "PM"]

## Spherical blend between two rotations given as Euler degrees.
static func slerp_rotation(a: Vector3, b: Vector3, t: float) -> Vector3:
	var qa := Quaternion.from_euler(a * (PI / 180.0))
	var qb := Quaternion.from_euler(b * (PI / 180.0))
	return qa.slerp(qb, t).get_euler() * (180.0 / PI)

func _ready() -> void:
	_build_toast()
	_build_sky()
	_build_clock_label()
	_build_name_labels()
	set_preset(start_preset, true)
	# Picking a preset stops the clock; start it quietly (no toast) from there.
	if start_clock_running:
		clock_running = true
		sky_hour = hour
		_refresh_clock_label()

func _process(delta: float) -> void:
	_update_name_labels()
	if _train_time >= 0.0 and _sky_material:
		_train_time += delta
		if _train_time > STARLINK_SECONDS:
			_train_time = -1.0
		_sky_material.set_shader_parameter("train_time", _train_time)
	if _aurora_shown > 0.001 and _sky_material:
		_aurora_time += delta
		_sky_material.set_shader_parameter("aurora_time", _aurora_time)
	if _meteor_shown > 0.01 and _sky_material:
		_meteor_time += delta
		_sky_material.set_shader_parameter("meteor_time", _meteor_time)
	if clock_running:
		hour = fposmod(hour + delta * 24.0 / maxf(day_seconds, 1.0), 24.0)
		current = keyframe_before(hour)
		sky_hour = hour
		_apply(preset_at_hour(hour))
		_refresh_clock_label()

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
		set_show_constellations(not show_constellations)
		show_toast("Constellation lines " + ("on" if show_constellations else "off"))
		get_viewport().set_input_as_handled()

## Show or hide the constellation lines and names.
func set_show_constellations(on: bool) -> void:
	show_constellations = on
	if not _shown.is_empty():
		_apply(_shown)
	# The names are moved in _process, which doesn't run while the sky menu has
	# the game paused: update them now so the one button changes lines and names.
	_update_name_labels()

## Turn the moon on (it rises and sets) or off for good.
func set_moon_enabled(on: bool) -> void:
	moon_enabled = on
	if not _shown.is_empty():
		_apply(_shown)

## Pick how many shooting stars: an index into METEOR_LEVELS.
func set_meteor_level(level: int) -> void:
	meteor_level = clampi(level, 0, METEOR_LEVELS.size() - 1)
	if not _shown.is_empty():
		_apply(_shown)

## True if a Starlink train could be seen now: the sky is dark enough, with
## the weather taken into account.
func starlink_visible() -> bool:
	if _shown.is_empty():
		return false
	# The same star level the sky shader gets, with a high moon's glare taken off.
	var visible_stars: float = shown().stars * (1.0 - moon_glare(_shown.get("stars", 0.0), sky_hour, moon_enabled))
	return visible_stars >= STARLINK_MIN_STARS

## Send a Starlink train across the sky. Returns false (and does nothing) when
## the sky is too bright or too cloudy to see one.
func start_starlink() -> bool:
	if not starlink_visible():
		return false
	_train_time = 0.0
	if _sky_material:
		_sky_material.set_shader_parameter("train_time", 0.0)
	return true

func is_starlink_running() -> bool:
	return _train_time >= 0.0

## The direction (unit, +x east, +y up, -z north) of the full moon at clock hour
## `h`, as the sun's opposite number at an equinox: due east on the horizon at
## 18:30, due south and highest at 00:30, due west on the horizon at 06:30.
static func moon_direction(h: float) -> Vector3:
	var hour_angle := deg_to_rad((fposmod(h, 24.0) - MOON_TRANSIT_HOUR) * 15.0)
	var lat := deg_to_rad(SkyMath.LATITUDE)
	return Vector3(-sin(hour_angle), cos(lat) * cos(hour_angle), sin(lat) * cos(hour_angle))

## `p` with the night light turned into the moon's: the scene's one directional
## light blends from the preset's sun to the moon (where it hangs at clock hour
## `h`, as the preset gets dark: `base_stars` is its star level), and goes out
## while the moon is below the horizon or turned off. By day it changes nothing.
static func moon_adjust(p: Dictionary, base_stars: float, h: float, enabled: bool) -> Dictionary:
	var out := p.duplicate()
	var m := smoothstep(0.3, 0.8, base_stars)
	if m <= 0.0:
		return out
	var dir := moon_direction(h)
	var up := smoothstep(-0.05, 0.12, dir.y) if enabled else 0.0
	var moon_rotation := Basis.looking_at(-dir, Vector3.UP).get_euler() * (180.0 / PI)
	out.sun_rotation = slerp_rotation(p.sun_rotation, moon_rotation, m)
	out.sun_energy = lerpf(p.sun_energy, p.sun_energy * up, m)
	return out

## How much of the stars' light the moon washes out at clock hour `h` (0..MOON_GLARE):
## nothing when it is off, below the horizon or the sky is not dark, most when high.
static func moon_glare(base_stars: float, h: float, enabled: bool) -> float:
	if not enabled:
		return 0.0
	var alt := moon_direction(h).y
	return MOON_GLARE * smoothstep(0.3, 0.8, base_stars) * smoothstep(0.0, 0.5, alt)

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
	_refresh_clock_label()
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
	_refresh_clock_label()
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

## Set the northern lights (0..1) and redraw.
func set_aurora(amount: float) -> void:
	aurora_level = clampf(amount, 0.0, 1.0)
	if not _shown.is_empty():
		_apply(_shown)

## Set the wildfire smoke (0..1) and redraw.
func set_smoke(amount: float) -> void:
	smoke_level = clampf(amount, 0.0, 1.0)
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
	return overcast_preset(_shown, overcast, fog_extra, flash, aurora_level, smoke_level)

func _apply(preset: Dictionary) -> void:
	_shown = preset
	var p := overcast_preset(preset, overcast, fog_extra, flash, aurora_level, smoke_level)
	p = moon_adjust(p, preset.get("stars", 0.0), sky_hour, moon_enabled)
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
	if get_tree() and get_tree().paused:
		_update_name_labels()  # _process is not running to do it

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
	_sky_material.set_shader_parameter("planet_dir", planet_directions(_sky_days + 0.5))
	_sky_material.set_shader_parameter("planet_col", planet_colors())
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
	var glare := moon_glare(_shown.get("stars", 0.0), sky_hour, moon_enabled)
	_sky_material.set_shader_parameter("star_strength", p.stars * (1.0 - glare))
	_sky_material.set_shader_parameter("aurora_strength", p.aurora)
	_aurora_shown = p.aurora
	_sky_material.set_shader_parameter("line_strength", 0.14 if show_constellations else 0.0)
	var lst := SkyMath.sidereal_degrees(_sky_days, sky_hour)
	_sky_material.set_shader_parameter("sky_to_celestial", SkyMath.celestial_to_world(SkyMath.LATITUDE, lst).transposed())
	# The sun by day, the moon at night: the scene's one directional light.
	var body := body_look(p, _shown.get("stars", 0.0), overcast, fog_extra, smoke_level)
	_sky_material.set_shader_parameter("body_dir", body.dir)
	_sky_material.set_shader_parameter("body_color", body.color)
	# With the moon off its disc goes too (the sun's is untouched: moon is 0 by day).
	_sky_material.set_shader_parameter("body_strength", body.strength * (1.0 if moon_enabled else 1.0 - body.moon))
	_sky_material.set_shader_parameter("body_glow", body.glow)
	_sky_material.set_shader_parameter("body_moon", body.moon)
	# Shooting stars only streak across a dark, clear sky.
	var period: float = METEOR_LEVELS[meteor_level][1]
	_meteor_shown = smoothstep(0.7, 1.0, p.stars) if period > 0.0 else 0.0
	_sky_material.set_shader_parameter("meteor_period", maxf(period, 0.1))
	_sky_material.set_shader_parameter("meteor_strength", _meteor_shown)

## How the sun or moon disc is drawn under lighting `p`: where (the direction
## the light comes from), its colour, how visible it is (hidden below the
## horizon, by cloud and fog, and dulled by smoke), the size of its glow
## (bigger in smoke and near the horizon) and `moon` 0..1 (the preset's own
## `stars`: by night the light is the moon's, so the disc turns pale and
## mottled). `base_stars` is the preset's star level before weather.
static func body_look(p: Dictionary, base_stars: float, cloud: float, fog: float, smoke: float) -> Dictionary:
	var dir: Vector3 = Basis.from_euler(p.sun_rotation * (PI / 180.0)).z
	var moon := smoothstep(0.3, 0.8, base_stars)
	var sun_c: Color = p.sun_color
	# The sun's disc is nearly white, but only a dull orange through smoke.
	var white := sun_c.lerp(Color.WHITE, 0.55 * (1.0 - smoke))
	var color := Vector3(white.r, white.g, white.b).lerp(Vector3(0.86, 0.9, 1.0), moon)
	var strength := smoothstep(-0.03, 0.06, dir.y) * pow(1.0 - clampf(cloud, 0.0, 1.0), 2.0)
	strength *= 1.0 - clampf(fog / 0.02, 0.0, 1.0)
	strength *= 1.0 - 0.35 * smoke
	var glow := 0.25 + 0.6 * smoke + 0.3 * (1.0 - clampf(dir.y * 3.0, 0.0, 1.0))
	return {"dir": dir, "color": color, "strength": strength, "glow": clampf(glow, 0.0, 1.0), "moon": moon}

## The planets' unit vectors in celestial axes (for the shader's `planet_dir`).
static func planet_directions(days: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in SkyMath.PLANETS.size():
		out.append(SkyMath.planet_vector(i, days))
	return out

## Each planet's colour in rgb and brightness in alpha (from its magnitude).
static func planet_colors() -> PackedColorArray:
	var out := PackedColorArray()
	for planet in SkyMath.PLANETS:
		var c: Color = planet.color
		c.a = clampf(0.5 * pow(2.512, -0.5 * planet.mag), 0.35, 1.6)
		out.append(c)
	return out

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

## Small top-right readout of the running clock's estimated time. It lives in
## the toast's CanvasLayer and is only visible while the clock runs.
func _build_clock_label() -> void:
	_clock_label = Label.new()
	_clock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clock_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_clock_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_clock_label.offset_right = -20
	_clock_label.offset_top = 16
	_clock_label.add_theme_font_size_override("font_size", 22)
	_clock_label.add_theme_stylebox_override("normal", preload("res://scripts/hud_style.gd").backing())
	_clock_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_clock_label.add_theme_constant_override("outline_size", 4)
	_clock_label.visible = false
	_toast.get_parent().add_child(_clock_label)

## Show or hide the readout, and rewrite its text only when the rounded time
## changes (not every frame).
func _refresh_clock_label() -> void:
	if _clock_label == null:
		return  # called before _ready() built it
	_clock_label.visible = clock_running
	if not clock_running:
		return
	var text := clock_estimate(hour)
	if _clock_label.text != text:
		_clock_label.text = text

## One label per constellation (D-110), repositioned each frame by
## _update_name_labels(). They share the toast's CanvasLayer and never take the
## mouse.
func _build_name_labels() -> void:
	for entry in ConstellationNames.ENTRIES:
		var label := Label.new()
		label.text = entry[0]
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", Color(0.78, 0.88, 1.0))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		label.add_theme_constant_override("outline_size", 4)
		label.visible = false
		_toast.get_parent().add_child(label)
		_name_labels.append(label)

## Put each constellation's name where it sits in the sky as seen by the
## current camera, fading with the stars and the clouds. Hidden by day, under
## cloud, with the lines off (N), or when the spot is below the horizon,
## behind the camera or off screen.
func _update_name_labels() -> void:
	if _name_labels.is_empty():
		return
	var cam := get_viewport().get_camera_3d()
	var alpha := 0.0
	if show_constellations and not _shown.is_empty():
		alpha = ConstellationNames.label_alpha(_shown.stars, overcast)
	if cam == null or alpha < 0.02:
		for label in _name_labels:
			label.visible = false
		return
	var lst := SkyMath.sidereal_degrees(_sky_days, sky_hour)
	var view := get_viewport().get_visible_rect().size
	for i in _name_labels.size():
		var label := _name_labels[i]
		var dir := ConstellationNames.direction(i, lst)
		var at := cam.global_position + dir * 1000.0
		var on_screen := ConstellationNames.above_horizon(dir) and not cam.is_position_behind(at)
		var pos := cam.unproject_position(at) if on_screen else Vector2.ZERO
		if on_screen and not Rect2(Vector2.ZERO, view).grow(-minf(40.0, view.x * 0.05)).has_point(pos):
			on_screen = false
		label.visible = on_screen
		if on_screen:
			# size is stale on the first frame a label shows; the minimum is not.
			label.position = pos - label.get_combined_minimum_size() * 0.5
			label.modulate.a = alpha

## Briefly name something at the top of the screen (also used by weather.gd).
func show_toast(text: String) -> void:
	_toast.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.2)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)
