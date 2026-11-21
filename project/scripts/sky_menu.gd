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
const WEATHER_COLUMNS := 2

@export var time_of_day_path: NodePath = ^"../TimeOfDay"
@export var weather_path: NodePath = ^"../Weather"

var _tod: Node
var _weather: Node
var _time_buttons := {}
var _weather_buttons := {}
var _clock_button: Button
var _names_button: Button
var _panel: PanelContainer
var _mouse_before := Input.MOUSE_MODE_CAPTURED

func _ready() -> void:
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("sky_menu")
	_tod = get_node_or_null(time_of_day_path)
	_weather = get_node_or_null(weather_path)
	_build()
	_panel.visible = false

func is_open() -> bool:
	return _panel.visible

func _input(event: InputEvent) -> void:
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
	get_tree().paused = open
	if open:
		_mouse_before = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		# Give the mouse back the way it was (Esc may have freed it before).
		Input.mouse_mode = _mouse_before
	if open:
		refresh()

## Pick a time of day. A rainbow or aurora that can't be seen at the new time
## is dropped (weather goes back to clear).
func choose_time(preset_name: String) -> void:
	if _tod:
		_tod.set_preset(preset_name, true)
		if _weather and not Weather.allowed_at(_weather.current, preset_name):
			_weather.set_weather("clear", true)
	refresh()

## Pick a weather. A special (rainbow, aurora) that doesn't suit the current
## time of day is ignored; picking the special that is already on turns it off.
func choose_weather(weather_name: String) -> void:
	if _weather:
		if _tod and not Weather.allowed_at(weather_name, _tod.current):
			return
		if Weather.SPECIAL_TIMES.has(weather_name) and _weather.current == weather_name:
			weather_name = "clear"
		_weather.set_weather(weather_name, true)
	refresh()

func toggle_clock() -> void:
	if _tod:
		_tod.set_clock_running(not _tod.clock_running)
	refresh()

func toggle_names() -> void:
	if _tod:
		_tod.set_show_constellations(not _tod.show_constellations)
	refresh()

## Mark the current time, weather and toggles on the buttons.
func refresh() -> void:
	if _tod:
		for key in _time_buttons:
			(_time_buttons[key] as Button).set_pressed_no_signal(key == _tod.current)
		_clock_button.set_pressed_no_signal(_tod.clock_running)
		_clock_button.text = "Clock: " + ("running  (%s)" % TimeOfDay.clock_estimate(_tod.hour) if _tod.clock_running else "paused")
		_names_button.set_pressed_no_signal(_tod.show_constellations)
		_names_button.text = "Constellation lines and names: " + ("on" if _tod.show_constellations else "off")
	if _weather:
		for key in _weather_buttons:
			var b := _weather_buttons[key] as Button
			b.set_pressed_no_signal(key == _weather.current)
			b.disabled = _tod != null and not Weather.allowed_at(key, _tod.current)

func _build() -> void:
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.1, 0.88)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(22)
	style.border_color = KEY_COLOR
	style.set_border_width_all(2)
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
	title.text = "Sky & weather"
	title.add_theme_font_size_override("font_size", FONT_SIZE + 10)
	box.add_child(title)

	box.add_child(_heading("Time of day"))
	# One row of six buttons, each painted in that time's sky colour with the
	# name and clock time on two short lines.
	var times := HBoxContainer.new()
	times.add_theme_constant_override("separation", 6)
	box.add_child(times)
	for key in TimeOfDay.ORDER:
		var hour := TimeOfDay.hour_of(key)
		var b := _button("%s\n%s" % [TimeOfDay.PRESETS[key].label, TimeOfDay.clock_estimate(hour).trim_prefix("~")])
		_paint_time_button(b, TimeOfDay.PRESETS[key].sky_color)
		b.custom_minimum_size = Vector2(92, 64)
		b.pressed.connect(choose_time.bind(key))
		times.add_child(b)
		_time_buttons[key] = b
	_clock_button = _button("")
	_clock_button.pressed.connect(toggle_clock)
	box.add_child(_clock_button)

	box.add_child(_heading("Weather"))
	var grid := GridContainer.new()
	grid.columns = WEATHER_COLUMNS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	for key in Weather.ORDER:
		if not Weather.SPECIAL_TIMES.has(key):
			_add_weather_button(grid, key)

	box.add_child(_heading("Special sky   (rainbow by day, aurora at night)"))
	var specials := HBoxContainer.new()
	specials.add_theme_constant_override("separation", 8)
	box.add_child(specials)
	for key in Weather.SPECIAL_TIMES:
		_add_weather_button(specials, key)

	_names_button = _button("")
	_names_button.pressed.connect(toggle_names)
	box.add_child(_names_button)

	var close := _button("Close  (G or Esc)")
	close.toggle_mode = false
	close.pressed.connect(set_open.bind(false))
	box.add_child(close)

func _add_weather_button(parent: Container, key: String) -> void:
	var b := _button(Weather.WEATHER[key].label)
	b.pressed.connect(choose_weather.bind(key))
	parent.add_child(b)
	_weather_buttons[key] = b

## Fill a time-of-day button with the sky colour (lightened a little so Night
## isn't a black hole), light text on the dark ones and dark text on the rest,
## and a bright border when it is the chosen one.
func _paint_time_button(b: Button, sky: Color) -> void:
	var fill := sky.lerp(Color.WHITE, 0.12)
	var dark := fill.get_luminance() < 0.45
	var text := Color(1, 1, 1) if dark else Color(0.1, 0.1, 0.12)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var s := StyleBoxFlat.new()
		s.bg_color = fill.lightened(0.12) if state.begins_with("hover") else fill
		s.set_corner_radius_all(8)
		s.set_border_width_all(4 if state.ends_with("pressed") else 1)
		s.border_color = KEY_COLOR if state.ends_with("pressed") else Color(1, 1, 1, 0.25)
		b.add_theme_stylebox_override(state, s)
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
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 44)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", FONT_SIZE - 2)
	return b
