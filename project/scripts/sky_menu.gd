extends CanvasLayer
## The sky menu (D-110): pick the time of day and the weather from a list
## instead of cycling through them with T and R. G (`open_sky_menu`) or the sun
## icon under the minimap opens it. Like the full map it pauses the game and
## frees the mouse while open, so changes are applied instantly (a fade would
## freeze mid-way) and you see them behind the panel; Esc, G or Close resumes.

const TimeOfDay := preload("res://scripts/time_of_day.gd")
const Weather := preload("res://scripts/weather.gd")

const FONT_SIZE := 22
const KEY_COLOR := Color(1.0, 0.86, 0.55)
const UNAVAILABLE_TINT := Color(1, 1, 1, 0.4)

## Times of day left to right, dawn to night (TimeOfDay.ORDER is the T-key order).
const TIME_ORDER := ["dawn", "sunrise", "day", "sunset", "dusk", "night"]

## The weather columns: a heading and the weathers under it, top to bottom.
## Clear sits by itself at the top centre, above the columns.
const WEATHER_GROUPS := [
	["Fog & smoke", ["light_fog", "heavy_fog", "haze", "heavy_smoke"]],
	["Rain", ["drizzle", "rain", "downpour", "thunderstorm"]],
	["Snow", ["snow", "heavy_snow"]],
	["Special", ["rainbow", "aurora"]],
]

## Each weather button's gradient, top and bottom, echoing how that weather
## looks in the sky.
const WEATHER_COLORS := {
	"clear": [Color(0.35, 0.6, 0.9), Color(0.7, 0.85, 0.97)],
	"light_fog": [Color(0.62, 0.65, 0.68), Color(0.78, 0.8, 0.82)],
	"heavy_fog": [Color(0.45, 0.47, 0.5), Color(0.65, 0.67, 0.7)],
	"haze": [Color(0.6, 0.45, 0.3), Color(0.82, 0.62, 0.42)],
	"heavy_smoke": [Color(0.4, 0.26, 0.17), Color(0.66, 0.42, 0.26)],
	"drizzle": [Color(0.5, 0.6, 0.7), Color(0.62, 0.7, 0.78)],
	"rain": [Color(0.33, 0.42, 0.55), Color(0.5, 0.58, 0.68)],
	"downpour": [Color(0.22, 0.3, 0.45), Color(0.36, 0.45, 0.58)],
	"thunderstorm": [Color(0.16, 0.14, 0.28), Color(0.36, 0.3, 0.5)],
	"snow": [Color(0.72, 0.8, 0.9), Color(0.93, 0.96, 1.0)],
	"heavy_snow": [Color(0.6, 0.68, 0.8), Color(0.85, 0.9, 0.96)],
	"rainbow": [Color(0.5, 0.7, 0.95), Color(0.97, 0.82, 0.62)],
	"aurora": [Color(0.04, 0.1, 0.18), Color(0.1, 0.55, 0.4)],
}

## Typing this while the menu is open (where the letters are not also commands)
## sends a Starlink train across the sky.
const STARLINK_CODE := "starlink"

## The Water row (D-142): jump the pond to a level, and how fast the water runs
## compared with the clock.
const POND_PRESETS := [["Empty pond", 0.0], ["Half full", 0.5], ["Full pond", 1.0]]
const WATER_SPEEDS := [["Normal", 1.0], ["Fast  x5", 5.0], ["Very fast  x20", 20.0]]
## The ditch burn's wind (D-156): a multiple of the usual south-west wind.
const FIRE_WINDS := [["Light", 0.5], ["Usual", 1.0], ["Gale", 1.8]]

@export var time_of_day_path: NodePath = ^"../TimeOfDay"
@export var weather_path: NodePath = ^"../Weather"
@export var terrain_path: NodePath = ^"../DistantTerrain"
@export var water_path: NodePath = ^"../Water"
@export var fire_path: NodePath = ^"../Fire"

var _tod: Node
var _weather: Node
var _terrain: Node
var _water: Node
var _fire: Node
var _fire_status: Label
var _fire_wind_buttons := []
var _weir_button: Button
var _water_status: Label
var _speed_buttons := []
var _season_button: Button
var _time_buttons := {}
var _weather_buttons := {}
var _clock_button: Button
var _names_button: Button
var _moon_button: Button
var _meteor_button: Button
var _typed := ""
var _hint: Label
var _panel: PanelContainer
var _mouse_before := Input.MOUSE_MODE_CAPTURED
var _close_button: Button

func _ready() -> void:
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("sky_menu")
	_tod = get_node_or_null(time_of_day_path)
	_weather = get_node_or_null(weather_path)
	_terrain = get_node_or_null(terrain_path)
	_water = get_node_or_null(water_path)
	_fire = get_node_or_null(fire_path)
	_build()
	_panel.visible = false

func is_open() -> bool:
	return _panel.visible

## Add a typed letter to `typed`, keeping only as many as the code is long.
static func push_typed(typed: String, letter: String) -> String:
	return (typed + letter.to_lower()).right(STARLINK_CODE.length())

func _input(event: InputEvent) -> void:
	if is_open() and event is InputEventKey and event.pressed and not event.echo and not (event.ctrl_pressed or event.alt_pressed or event.meta_pressed):
		var letter := OS.get_keycode_string(event.keycode)
		if letter.length() == 1:
			_typed = push_typed(_typed, letter)
			if _typed == STARLINK_CODE:
				_typed = ""
				starlink()
	if event.is_action_pressed("open_sky_menu"):
		if get_tree().paused and not is_open():
			return  # the full map has the game paused; leave G alone
		set_open(not is_open())
		get_viewport().set_input_as_handled()
	elif is_open() and event.is_action_pressed("ui_cancel"):
		set_open(false)
		get_viewport().set_input_as_handled()

## Open or close the menu. Opening is ignored while something else (the full
## map) has the game paused.
func set_open(open: bool) -> void:
	if open == is_open():
		return
	if open and get_tree().paused:
		return
	_panel.visible = open
	_typed = ""  # a half-typed code doesn't carry over to the next visit
	get_tree().paused = open
	if open:
		_mouse_before = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		# Give the mouse back the way it was (Esc may have freed it before).
		Input.mouse_mode = _mouse_before
	if open:
		refresh()
		_close_button.grab_focus.call_deferred()

## Pick a time of day. A rainbow or aurora that can't be seen at the new time
## is dropped (weather goes back to clear).
func choose_time(preset_name: String) -> void:
	if _tod:
		_tod.set_preset(preset_name, true)
		if _weather and not Weather.allowed_at(_weather.current, preset_name):
			_weather.set_weather("clear", true)
	_hint.text = ""
	refresh()

## Pick a weather. A special (rainbow, aurora) that doesn't suit the current
## time of day is ignored; picking the special that is already on turns it off.
func choose_weather(weather_name: String) -> void:
	if _weather:
		if Weather.SPECIAL_TIMES.has(weather_name) and _weather.current == weather_name:
			weather_name = "clear"
		elif not is_available(weather_name):
			# Dimmed, not disabled, so a click can say why it isn't offered now.
			_hint.text = Weather.restriction_text(weather_name)
			return
		_weather.set_weather(weather_name, true)
	_hint.text = ""
	refresh()

## True if `weather_name` can be chosen at the current time of day. The active
## weather always counts, so a special left on at the wrong time (R, the clock)
## can still be switched off.
func is_available(weather_name: String) -> bool:
	if _weather and weather_name == _weather.current:
		return true
	return _tod == null or Weather.allowed_at(weather_name, _tod.current)

func toggle_clock() -> void:
	if _tod:
		_tod.set_clock_running(not _tod.clock_running)
	refresh()

## Constellation lines and names together: the names themselves only appear
## at night, but the one button owns both.
func toggle_names() -> void:
	if _tod:
		_tod.set_show_constellations(not _tod.show_constellations)
	refresh()

func toggle_moon() -> void:
	if _tod:
		_tod.set_moon_enabled(not _tod.moon_enabled)
	refresh()

## Step the shooting stars through off, some and shower.
func cycle_meteors() -> void:
	if _tod:
		_tod.set_meteor_level((_tod.meteor_level + 1) % TimeOfDay.METEOR_LEVELS.size())
	refresh()

## Summer or winter on the distant hills and mountains (D-133).
func choose_season(season_name: String) -> void:
	if _terrain:
		_terrain.set_season(season_name)
	refresh()

## Switch the distant hills between summer and winter.
func toggle_season() -> void:
	if _terrain:
		choose_season("summer" if _terrain.season == "winter" else "winter")

## Open or shut the weir that feeds the ditch.
func toggle_weir() -> void:
	if _water:
		_water.weir_open = not _water.weir_open
	refresh()

## Fill the whole ditch with water at once, or drain it.
func set_ditch(full: bool) -> void:
	if _water:
		_water.set_ditch_full(full)
	refresh()

## Put the pond at `fraction` full (0 empty .. 1 full). The pond's own toast
## ("The pond is full") announces it.
func set_pond(fraction: float) -> void:
	if _water:
		_water.set_pond_fill(fraction)
	refresh()

## Pick how fast the water runs: index into WATER_SPEEDS.
func choose_water_speed(index: int) -> void:
	if _water:
		_water.time_scale = WATER_SPEEDS[index][1]
	refresh()

## The Starlink easter egg: close the menu and send a train across the sky, or
## say why not if the sky is too bright or cloudy to see one.
func starlink() -> void:
	if _tod == null:
		return
	if _tod.start_starlink():
		_hint.text = ""
		set_open(false)
	else:
		_hint.text = "A Starlink train needs a dark, clear sky: try dusk or night."

## Mark the current time, weather and toggles on the buttons.
func refresh() -> void:
	if _tod:
		for key in _time_buttons:
			(_time_buttons[key] as Button).set_pressed_no_signal(key == _tod.current)
		_clock_button.set_pressed_no_signal(_tod.clock_running)
		_clock_button.text = "Clock: " + ("running  (%s)" % TimeOfDay.clock_estimate(_tod.hour) if _tod.clock_running else "paused")
		_names_button.set_pressed_no_signal(_tod.show_constellations)
		_names_button.text = "Constellations\n" + ("lines + names" if _tod.show_constellations else "off")
		_moon_button.set_pressed_no_signal(_tod.moon_enabled)
		_moon_button.text = "Moon\n" + ("rises and sets" if _tod.moon_enabled else "never")
		var level: String = TimeOfDay.METEOR_LEVELS[_tod.meteor_level][0]
		_meteor_button.set_pressed_no_signal(_tod.meteor_level > 0)
		_meteor_button.text = "Shooting stars\n" + level
	if _terrain:
		_season_button.set_pressed_no_signal(_terrain.season == "winter")
		_season_button.text = "Season\n" + ("winter (snowy hills)" if _terrain.season == "winter" else "summer")
	if _weather:
		for key in _weather_buttons:
			var b := _weather_buttons[key] as Button
			b.set_pressed_no_signal(key == _weather.current)
			b.modulate = Color.WHITE if is_available(key) else UNAVAILABLE_TINT
	if _fire:
		_fire_status.text = "%d%% of the strip burned" % roundi(_fire.grid.target_coverage() * 100.0)
		for i in _fire_wind_buttons.size():
			(_fire_wind_buttons[i] as Button).set_pressed_no_signal(is_equal_approx(_fire.wind_scale, FIRE_WINDS[i][1]))
	if _water:
		_weir_button.set_pressed_no_signal(_water.weir_open)
		_weir_button.text = "Weir\n" + ("open" if _water.weir_open else "shut")
		_water_status.text = "Pond %d%% full" % roundi(_water.pond_fill_fraction() * 100.0)
		for i in _speed_buttons.size():
			(_speed_buttons[i] as Button).set_pressed_no_signal(is_equal_approx(_water.time_scale, WATER_SPEEDS[i][1]))

func _build() -> void:
	_panel = PanelContainer.new()
	var style := preload("res://scripts/hud_style.gd").dialog(KEY_COLOR)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.offset_right = -32
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)

	var title := Label.new()
	title.text = "Sky & Weather"
	title.add_theme_font_size_override("font_size", FONT_SIZE + 10)
	box.add_child(title)

	box.add_child(_heading("Time of day"))
	# One row of six buttons, each painted in that time's sky colour with the
	# name and clock time on two short lines.
	var times := HBoxContainer.new()
	times.add_theme_constant_override("separation", 6)
	box.add_child(times)
	for key in TIME_ORDER:
		var hour := TimeOfDay.hour_of(key)
		var b := _button("%s\n%s" % [TimeOfDay.PRESETS[key].label, TimeOfDay.clock_estimate(hour).trim_prefix("~")])
		var sky: Color = TimeOfDay.PRESETS[key].sky_color.lerp(Color.WHITE, 0.1)
		_paint_gradient(b, sky.darkened(0.12), sky.lightened(0.18), 8)
		b.custom_minimum_size = Vector2(92, 64)
		b.pressed.connect(choose_time.bind(key))
		times.add_child(b)
		_time_buttons[key] = b
	_clock_button = _button("")
	_clock_button.pressed.connect(toggle_clock)
	box.add_child(_clock_button)

	box.add_child(_heading("Weather"))
	# Clear is the way back to plain weather, so it sits top centre on its own,
	# which keeps the first column short.
	var clear_row := HBoxContainer.new()
	clear_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(clear_row)
	_add_weather_button(clear_row, "clear")
	(_weather_buttons["clear"] as Button).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	(_weather_buttons["clear"] as Button).custom_minimum_size = Vector2(220, 44)
	# Related weathers stack in vertical lists.
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 8)
	box.add_child(columns)
	for group in WEATHER_GROUPS:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 8)
		columns.add_child(column)
		var label := Label.new()
		label.text = group[0]
		label.add_theme_font_size_override("font_size", FONT_SIZE - 6)
		label.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78))
		column.add_child(label)
		for key in group[1]:
			_add_weather_button(column, key)

	# Says why a dimmed weather isn't available when you click it; sits right
	# under the columns and keeps its height when empty so nothing jumps.
	_hint = Label.new()
	_hint.custom_minimum_size = Vector2(0, 30)
	_hint.add_theme_font_size_override("font_size", FONT_SIZE - 4)
	_hint.add_theme_color_override("font_color", KEY_COLOR)
	box.add_child(_hint)

	# The season shares the bottom row so the menu doesn't grow taller: snow on
	# the Blue Mountains or summer-gold hills (D-133). Falling snow shows winter
	# whichever is picked.
	box.add_child(_heading("Night sky & season"))
	var night := HBoxContainer.new()
	night.add_theme_constant_override("separation", 8)
	box.add_child(night)
	_names_button = _button("")
	_names_button.pressed.connect(toggle_names)
	_moon_button = _button("")
	_moon_button.pressed.connect(toggle_moon)
	_meteor_button = _button("")
	_meteor_button.pressed.connect(cycle_meteors)
	_season_button = _button("")
	_season_button.pressed.connect(toggle_season)
	_season_button.visible = _terrain != null
	for b in [_names_button, _moon_button, _meteor_button, _season_button]:
		b.custom_minimum_size = Vector2(0, 62)
		night.add_child(b)

	if _water:
		_build_water(box)
	if _fire:
		_build_fire(box)

	var close := _button("Close  (G or Esc)")
	_close_button = close
	close.toggle_mode = false
	close.pressed.connect(set_open.bind(false))
	box.add_child(close)

## The Water row: weir and ditch, the pond's level, and the water's speed.
func _build_water(box: VBoxContainer) -> void:
	var title := HBoxContainer.new()
	box.add_child(title)
	var heading := _heading("Water")
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(heading)
	_water_status = Label.new()
	_water_status.add_theme_font_size_override("font_size", FONT_SIZE - 2)
	_water_status.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	title.add_child(_water_status)

	var ditch := HBoxContainer.new()
	ditch.add_theme_constant_override("separation", 8)
	box.add_child(ditch)
	_weir_button = _button("")
	_weir_button.pressed.connect(toggle_weir)
	ditch.add_child(_weir_button)
	var fill := _action_button("Fill ditch")
	fill.pressed.connect(set_ditch.bind(true))
	ditch.add_child(fill)
	var drain := _action_button("Drain ditch")
	drain.pressed.connect(set_ditch.bind(false))
	ditch.add_child(drain)
	for b in [_weir_button, fill, drain]:
		b.custom_minimum_size = Vector2(0, 62)

	var pond := HBoxContainer.new()
	pond.add_theme_constant_override("separation", 8)
	box.add_child(pond)
	for preset in POND_PRESETS:
		var b := _action_button(preset[0])
		_paint_gradient(b, Color(0.18, 0.42, 0.55).lerp(Color(0.06, 0.14, 0.2), 1.0 - preset[1]), Color(0.3, 0.6, 0.75).lerp(Color(0.1, 0.2, 0.28), 1.0 - preset[1]), 6)
		b.pressed.connect(set_pond.bind(preset[1]))
		pond.add_child(b)

	var speed := HBoxContainer.new()
	speed.add_theme_constant_override("separation", 8)
	box.add_child(speed)
	var speed_label := Label.new()
	speed_label.text = "Water speed"
	speed_label.add_theme_font_size_override("font_size", FONT_SIZE - 2)
	speed_label.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78))
	speed.add_child(speed_label)
	for i in WATER_SPEEDS.size():
		var b := _button(WATER_SPEEDS[i][0])
		b.pressed.connect(choose_water_speed.bind(i))
		speed.add_child(b)
		_speed_buttons.append(b)

func _build_fire(box: VBoxContainer) -> void:
	var title := HBoxContainer.new()
	box.add_child(title)
	var heading := _heading("Fire")
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(heading)
	_fire_status = Label.new()
	_fire_status.add_theme_font_size_override("font_size", FONT_SIZE - 2)
	_fire_status.add_theme_color_override("font_color", Color(1.0, 0.7, 0.4))
	title.add_child(_fire_status)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var regrow := _action_button("Regrow the grass")
	regrow.pressed.connect(regrow_fire)
	row.add_child(regrow)
	var refill := _action_button("Refill the torch")
	refill.pressed.connect(refill_torch)
	row.add_child(refill)
	for b in [regrow, refill]:
		b.custom_minimum_size = Vector2(0, 62)

	var wind := HBoxContainer.new()
	wind.add_theme_constant_override("separation", 8)
	box.add_child(wind)
	var wind_label := Label.new()
	wind_label.text = "Wind"
	wind_label.add_theme_font_size_override("font_size", FONT_SIZE - 2)
	wind_label.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78))
	wind.add_child(wind_label)
	for i in FIRE_WINDS.size():
		var b := _button(FIRE_WINDS[i][0])
		b.pressed.connect(choose_fire_wind.bind(i))
		wind.add_child(b)
		_fire_wind_buttons.append(b)

## Let the burnt grass grow back and start the burn over.
func regrow_fire() -> void:
	if _fire:
		_fire.regrow()
	refresh()

func refill_torch() -> void:
	if _fire:
		_fire.refill()
	refresh()

## Pick the burn's wind: index into FIRE_WINDS.
func choose_fire_wind(index: int) -> void:
	if _fire:
		_fire.wind_scale = FIRE_WINDS[index][1]
	refresh()

## A button that does something when pressed rather than staying down.
func _action_button(text: String) -> Button:
	var b := _button(text)
	b.toggle_mode = false
	return b

func _add_weather_button(parent: Container, key: String) -> void:
	var b := _button(Weather.WEATHER[key].label)
	_paint_gradient(b, WEATHER_COLORS[key][0], WEATHER_COLORS[key][1], 6)
	if Weather.SPECIAL_TIMES.has(key):
		b.tooltip_text = Weather.restriction_text(key)
	b.pressed.connect(choose_weather.bind(key))
	parent.add_child(b)
	_weather_buttons[key] = b

## Paint a button with a top-to-bottom gradient (the weather's or time's sky),
## dark text on light colours and white on dark, and a gold border plus a flat
## mid-tone fill when it is the chosen one.
func _paint_gradient(b: Button, top: Color, bottom: Color, radius: int) -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, top)
	gradient.set_color(1, bottom)
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 4
	tex.height = 64
	var mid := top.lerp(bottom, 0.5)
	for state in ["normal", "hover"]:
		var s := StyleBoxTexture.new()
		s.texture = tex
		if state == "hover":
			s.modulate_color = Color(1.15, 1.15, 1.15)
		b.add_theme_stylebox_override(state, s)
	for state in ["pressed", "hover_pressed"]:
		var s := StyleBoxFlat.new()
		s.bg_color = mid
		s.set_corner_radius_all(radius)
		s.set_border_width_all(4)
		s.border_color = KEY_COLOR
		b.add_theme_stylebox_override(state, s)
	var text := Color(1, 1, 1) if mid.get_luminance() < 0.45 else Color(0.1, 0.1, 0.12)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(color_name, text)

func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", FONT_SIZE)
	l.add_theme_color_override("font_color", KEY_COLOR)
	return l

func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_ALL  # a controller steers by focus (D-185)
	b.custom_minimum_size = Vector2(0, 44)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", FONT_SIZE - 2)
	# The chosen one stands out: lighter fill and the menu's gold border.
	for state in ["pressed", "hover_pressed"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.2, 0.26, 0.38)
		s.set_corner_radius_all(6)
		s.set_border_width_all(3)
		s.border_color = KEY_COLOR
		b.add_theme_stylebox_override(state, s)
	return b
