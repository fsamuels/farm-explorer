extends Control
## Read-only controls help panel (D-90). Shown when the game starts; F1
## (`toggle_help`) hides/shows it. While hidden, a small "F1 — Controls" hint
## stays in the corner. Purely informational: it never takes the mouse.
##
## Pressing any other key (anything but the movement keys, Space, Shift and F1
## itself) tucks the panel away, so a key you use for something is also the
## moment the screen clears. It watches input without consuming it.

const CONTROLS := [
	["W A S D", "Move (sprint by default)"],
	["Hold Shift", "Walk"],
	["Hold Ctrl", "Super sprint: run three times as fast"],
	["Mouse", "Look around"],
	["Space", "Jump"],
	["E", "Open / close a gate or door you're looking at; get in or out of a car; use a glowing transport pad (back pastures)"],
	["Driving", "W gas / brake / reverse, A D steer, Space handbrake, mouse looks around"],
	["B", "Tip the Cub Cadet's dump bed up or down (slow down first)"],
	["F", "Switch first- / third-person view"],
	["Mouse wheel", "Zoom the camera out into third person, or in to first person"],
	["M", "Open / close the map (pauses the game)"],
	["C", "What's New: the changelog and the game's size (pauses the game)"],
	["G", "Sky menu: pick the time of day, weather, moon and shooting stars (pauses the game)"],
	["T", "Change the time of day: day, sunset, dusk, night, dawn, sunrise"],
	["Y", "Start / stop the clock (time shown top right)"],
	["N", "Show / hide constellation lines (and, at night, their names)"],
	["R", "Change the weather: rain, storm, fog, snow, rainbow, aurora, clear"],
	["Esc", "Release the mouse (click to recapture)"],
	["F1", "Show / hide this help (any other key but moving also hides it)"],
]

## Keys that only move you around: they never minimize the panel.
const MOVE_ACTIONS := ["move_forward", "move_back", "move_left", "move_right", "jump", "walk", "super_sprint"]

const FONT_SIZE := 22
const KEY_COLOR := Color(1.0, 0.86, 0.55)

var _panel: PanelContainer
var _hint: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel = _build_panel()
	add_child(_panel)
	_hint = _outlined_label("F1 — Controls")
	_hint.position = Vector2(16, 16)
	add_child(_hint)
	_set_open(true)

## True for a fresh key press that is something other than moving (or F1,
## which toggles the panel itself). Echoes from a held key don't count.
static func is_action_key(event: InputEvent) -> bool:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return false
	if event.is_action("toggle_help"):
		return false
	# Bare modifiers and OS shortcuts (Cmd+Tab, Ctrl+C) aren't game controls.
	if event.keycode in [KEY_CTRL, KEY_ALT, KEY_META, KEY_CAPSLOCK, KEY_SHIFT] or event.physical_keycode in [KEY_CTRL, KEY_ALT, KEY_META, KEY_CAPSLOCK] or event.ctrl_pressed or event.meta_pressed or event.alt_pressed:
		return false
	for action in MOVE_ACTIONS:
		if event.is_action(action):
			return false
	return true

func _input(event: InputEvent) -> void:
	if _panel.visible and is_action_key(event):
		_set_open(false)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_help"):
		_set_open(not _panel.visible)
		get_viewport().set_input_as_handled()

func _set_open(open: bool) -> void:
	_panel.visible = open
	_hint.visible = not open

func _build_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.6)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := _outlined_label("Controls")
	title.add_theme_font_size_override("font_size", FONT_SIZE + 6)
	box.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	for row in CONTROLS:
		var key := _outlined_label(row[0])
		key.add_theme_color_override("font_color", KEY_COLOR)
		grid.add_child(key)
		grid.add_child(_outlined_label(row[1]))

	var footer := _outlined_label("Explore the farm: walk up to gates and doors and press E to open them. You can go inside the Shop, Sally's House and the Front Barn.\nThe minimap (bottom left) shows where you are; press M for the full map.")
	footer.add_theme_font_size_override("font_size", FONT_SIZE - 4)
	footer.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	box.add_child(footer)
	return panel

func _outlined_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 4)
	return label
