extends Control
## Read-only controls help panel (D-90). Shown when the game starts; F1
## (`toggle_help`) hides/shows it. While hidden, a small "F1 — Controls" hint
## stays in the corner. Purely informational: it never takes the mouse.

const CONTROLS := [
	["W A S D", "Move (sprint by default)"],
	["Hold Shift", "Walk"],
	["Mouse", "Look around"],
	["Space", "Jump"],
	["E", "Open / close a gate you're looking at"],
	["F", "Switch first- / third-person view"],
	["Mouse wheel", "Zoom the camera out into third person, or in to first person"],
	["M", "Open / close the map (pauses the game)"],
	["T", "Change the time of day: day, sunset, dusk, night"],
	["Esc", "Release the mouse (click to recapture)"],
	["F1", "Show / hide this help"],
]

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

	var footer := _outlined_label("Explore the farm: walk up to gates and press E to open them.\nThe minimap (bottom left) shows where you are; press M for the full map.")
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
