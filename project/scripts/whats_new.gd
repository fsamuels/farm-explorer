extends CanvasLayer
## The What's New dialog (D-130): the changelog, newest release first, with a
## one-line headline per release and a "by the numbers" panel on the size of the
## game. C (`show_changelog`) or the star icon under the minimap opens it. Like
## the sky menu and the full map it pauses the game and frees the mouse while
## open; Esc, C or Close resumes. The text comes from release_data.gd, which
## tools/build_release_notes.gd generates from CHANGELOG.md.

const ReleaseNotes := preload("res://scripts/release_notes.gd")
const ReleaseData := preload("res://scripts/release_data.gd")

## The dialog is laid out at this large size (it was 22 px and far too small to
## read) and then scaled as a whole to fit the window, so a small window shrinks
## it rather than cutting it off.
const FONT_SIZE := 46
const PANEL_WIDTH := 1900.0
## Text room inside the panel (margins and the scroll bar), px.
const TEXT_INSET := 120.0
const LIST_HEIGHT := 700.0
## The most of the window the dialog fills, and how far it may scale.
const WINDOW_FILL := 0.96
const MIN_SCALE := 0.3
const MAX_SCALE := 2.5
const KEY_COLOR := Color(1.0, 0.86, 0.55)
const MUTED := Color(0.7, 0.72, 0.78)

var _panel: PanelContainer
var _mouse_before := Input.MOUSE_MODE_CAPTURED
## Each release's heading, for the tests.
var heading_labels: Array[Label] = []
var summary_labels: Array[Label] = []
var stat_values: Dictionary = {}
var latest_label: Label
var _scroll: ScrollContainer

func _ready() -> void:
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("whats_new")
	_build(ReleaseData.DATA)
	_panel.visible = false

func is_open() -> bool:
	return _panel.visible

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("show_changelog"):
		if get_tree().paused and not is_open():
			return  # the map or the sky menu has the game paused
		set_open(not is_open())
		get_viewport().set_input_as_handled()
	elif is_open() and event.is_action_pressed("ui_cancel"):
		set_open(false)
		get_viewport().set_input_as_handled()

## Open or close the dialog. Opening is ignored while something else has the
## game paused.
func set_open(open: bool) -> void:
	if open == is_open():
		return
	if open and get_tree().paused:
		return
	_panel.visible = open
	get_tree().paused = open
	if open:
		_fit_to_window()
		_mouse_before = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = _mouse_before

## Scale the whole panel to fit the window (the web build can be short, a 5K
## screen is huge) about its own centre.
func _fit_to_window() -> void:
	var view := get_viewport().get_visible_rect().size
	var size := _panel.get_combined_minimum_size()
	_panel.pivot_offset = size * 0.5
	_panel.scale = Vector2.ONE * ui_scale(view, size)

## The scale that makes a panel of `size` fill WINDOW_FILL of a `view`-sized window.
static func ui_scale(view: Vector2, size: Vector2) -> float:
	return clampf(minf(view.x / size.x, view.y / size.y) * WINDOW_FILL, MIN_SCALE, MAX_SCALE)

func _build(data: Dictionary) -> void:
	_panel = PanelContainer.new()
	var style := preload("res://scripts/hud_style.gd").dialog(KEY_COLOR)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	_panel.add_child(box)

	var title := Label.new()
	title.text = "What's New"
	title.add_theme_font_size_override("font_size", FONT_SIZE + 10)
	box.add_child(title)

	var entries: Array = data.entries
	latest_label = _wrapped(FONT_SIZE, KEY_COLOR)
	latest_label.text = entries[0].summary if not entries.is_empty() else ""
	box.add_child(latest_label)

	var scroll := ScrollContainer.new()
	_scroll = scroll
	scroll.custom_minimum_size = Vector2(0, LIST_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)
	for entry: Dictionary in entries:
		var heading := Label.new()
		heading.text = entry.title
		heading.add_theme_font_size_override("font_size", FONT_SIZE)
		heading.add_theme_color_override("font_color", Color(1, 1, 1))
		list.add_child(heading)
		heading_labels.append(heading)
		var summary := _wrapped(FONT_SIZE - 4, KEY_COLOR)
		summary.text = entry.summary
		list.add_child(summary)
		summary_labels.append(summary)
		for bullet: String in entry.bullets:
			var text := RichTextLabel.new()
			text.bbcode_enabled = true
			text.fit_content = true
			text.scroll_active = false
			text.add_theme_font_size_override("normal_font_size", FONT_SIZE - 6)
			text.add_theme_font_size_override("bold_font_size", FONT_SIZE - 6)
			text.add_theme_color_override("default_color", MUTED)
			text.text = "•  " + ReleaseNotes.bullet_bbcode(bullet)
			list.add_child(text)
		list.add_child(HSeparator.new())

	var stats_heading := Label.new()
	stats_heading.text = "By the numbers"
	stats_heading.add_theme_font_size_override("font_size", FONT_SIZE - 2)
	stats_heading.add_theme_color_override("font_color", KEY_COLOR)
	box.add_child(stats_heading)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 36)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	for row in ReleaseNotes.stats_rows(data.stats):
		var label := Label.new()
		label.text = row[0]
		label.add_theme_font_size_override("font_size", FONT_SIZE - 6)
		label.add_theme_color_override("font_color", MUTED)
		grid.add_child(label)
		var value := Label.new()
		value.text = row[1]
		value.add_theme_font_size_override("font_size", FONT_SIZE - 6)
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(value)
		stat_values[row[0]] = value

	var close := Button.new()
	close.text = "Close  (C or Esc)"
	close.add_theme_font_size_override("font_size", FONT_SIZE - 4)
	close.pressed.connect(set_open.bind(false))
	box.add_child(close)

func _wrapped(size: int, color: Color) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(PANEL_WIDTH - TEXT_INSET, 0)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label
