extends PanelContainer
## The burn's readout (D-156): a wind arrow and speed, the propane left in the
## torch, and the quest line. fire_system.gd builds it and calls `show_state`.
## The wind arrow points where the wind is blowing, as seen from the camera, so
## "up" on the arrow means "the fire will run straight ahead of you".

const HudStyle := preload("res://scripts/hud_style.gd")

const FONT_SIZE := 22
const MPH_PER_MPS := 2.23694
const GAUGE_COLOR := Color(1.0, 0.62, 0.2)
const ARROW_SIZE := 64.0

class WindArrow extends Control:
	## Screen-space direction the arrow points (+x right, +y down).
	var direction := Vector2(0.0, -1.0)
	var strength := 0.5

	func _init() -> void:
		custom_minimum_size = Vector2(ARROW_SIZE, ARROW_SIZE)

	func _draw() -> void:
		var c := size * 0.5
		var d := direction.normalized() if direction.length() > 0.001 else Vector2(0, -1)
		var side := Vector2(-d.y, d.x)
		var len := size.x * (0.3 + 0.2 * clampf(strength, 0.0, 1.0))
		var tip := c + d * len
		var tail := c - d * len
		draw_circle(c, size.x * 0.48, Color(1, 1, 1, 0.08))
		draw_line(tail, tip - d * 10.0, GAUGE_COLOR, 5.0, true)
		draw_colored_polygon(PackedVector2Array([tip, tip - d * 16.0 + side * 9.0, tip - d * 16.0 - side * 9.0]), GAUGE_COLOR)

var _arrow: WindArrow
var _wind_label: Label
var _tank_bar: ProgressBar
var _tank_label: Label
var _quest_title: Label
var _quest_line: Label

func _init() -> void:
	name = "FireHud"
	add_theme_stylebox_override("panel", HudStyle.backing(14.0, 10.0))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	position = Vector2(24.0, -150.0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	_quest_title = _label(FONT_SIZE + 2, Color(1.0, 0.86, 0.55))
	box.add_child(_quest_title)
	_quest_line = _label(FONT_SIZE - 2, Color(0.92, 0.92, 0.92))
	_quest_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quest_line.custom_minimum_size = Vector2(330.0, 0.0)
	box.add_child(_quest_line)

	var wind := HBoxContainer.new()
	wind.add_theme_constant_override("separation", 12)
	wind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(wind)
	_arrow = WindArrow.new()
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wind.add_child(_arrow)
	_wind_label = _label(FONT_SIZE, Color(1, 1, 1))
	_wind_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wind.add_child(_wind_label)

	var tank := HBoxContainer.new()
	tank.add_theme_constant_override("separation", 10)
	tank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(tank)
	_tank_label = _label(FONT_SIZE - 2, Color(0.8, 0.85, 0.9))
	_tank_label.text = "Propane"
	tank.add_child(_tank_label)
	_tank_bar = ProgressBar.new()
	_tank_bar.min_value = 0.0
	_tank_bar.max_value = 1.0
	_tank_bar.show_percentage = false
	_tank_bar.custom_minimum_size = Vector2(170.0, 18.0)
	_tank_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tank_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tank.add_child(_tank_bar)

func _label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## Compass name for a wind blowing along `wind` (x east, z south): the
## direction it blows FROM, as weather people say ("SW wind").
static func wind_from_name(wind: Vector2) -> String:
	if wind.length() < 0.05:
		return "calm"
	# Angle of the direction the wind comes from, 0 = north, clockwise.
	var from := (-wind).normalized()
	var deg := fposmod(rad_to_deg(atan2(from.x, -from.y)), 360.0)
	var names := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	return names[int(round(deg / 45.0)) % 8]

static func mph(speed: float) -> int:
	return int(round(speed * MPH_PER_MPS))

## Update the readout. `info` keys: wind (Vector2, m/s), view_right and
## view_forward (Vector2 in x/z, the camera's axes), tank (0..1), show_tank,
## title, line.
func show_state(info: Dictionary) -> void:
	var wind: Vector2 = info.get("wind", Vector2.ZERO)
	var right: Vector2 = info.get("view_right", Vector2(1, 0))
	var forward: Vector2 = info.get("view_forward", Vector2(0, -1))
	_arrow.direction = Vector2(wind.dot(right), -wind.dot(forward))
	_arrow.strength = clampf(wind.length() / 10.0, 0.0, 1.0)
	_arrow.queue_redraw()
	_wind_label.text = "%s wind\n%d mph" % [wind_from_name(wind), mph(wind.length())]
	var show_tank: bool = info.get("show_tank", false)
	_tank_label.visible = show_tank
	_tank_bar.visible = show_tank
	_tank_bar.value = info.get("tank", 0.0)
	_quest_title.text = info.get("title", "")
	_quest_title.visible = _quest_title.text != ""
	_quest_line.text = info.get("line", "")
	_quest_line.visible = _quest_line.text != ""
