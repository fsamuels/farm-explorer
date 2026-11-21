extends Control
## The quiet driving readout (D-113): a large, soft-blue speed in the lower
## right, a small rev figure under it, and a dim "E  get out" hint. It
## deliberately avoids the action yellow and has no panel, so it doesn't fight
## with the view through the windscreen. player.gd owns one and updates it
## while a car is driven. Notices ("Slow down to get out") appear in the hint
## line for a moment.

const SPEED_COLOR := Color(0.62, 0.78, 0.92, 0.9)
const SMALL_COLOR := Color(0.75, 0.82, 0.9, 0.55)
const NOTICE_COLOR := Color(1.0, 0.86, 0.55, 0.85)
const SPEED_SIZE := 64
const SMALL_SIZE := 20

var _speed: Label
var _unit: Label
var _rpm: Label
var _hint: Label

## "37" for 37.4 mph; reverse and creep show as their size, never negative.
static func speed_text(mph: float) -> String:
	return str(roundi(absf(mph)))

## "3.2k rpm" (to the nearest hundred).
static func rpm_text(rpm: float) -> String:
	return "%.1fk rpm" % (roundf(maxf(rpm, 0.0) / 100.0) / 10.0)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.offset_right = -40
	box.offset_bottom = -34
	box.alignment = BoxContainer.ALIGNMENT_END
	box.add_theme_constant_override("separation", -6)
	add_child(box)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	_speed = _label(SPEED_SIZE, SPEED_COLOR)
	_speed.text = "0"
	row.add_child(_speed)
	_unit = _label(SMALL_SIZE + 2, SMALL_COLOR)
	_unit.text = "mph"
	_unit.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(_unit)
	_rpm = _label(SMALL_SIZE, SMALL_COLOR)
	_rpm.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_rpm)
	_hint = _label(SMALL_SIZE, SMALL_COLOR)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_hint)

func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("outline_size", 5)
	return l

## Show the readout for a car doing `mph` with the engine at `rpm`; `notice`
## replaces the get-out hint while it is non-empty.
func show_drive(mph: float, rpm: float, notice: String) -> void:
	visible = true
	_speed.text = speed_text(mph)
	_rpm.text = rpm_text(rpm)
	var text := notice if notice != "" else _get_out_hint()
	if _hint.text != text:
		_hint.text = text
		_hint.add_theme_color_override("font_color", NOTICE_COLOR if notice != "" else SMALL_COLOR)

## "E  get out", with whatever key `interact` is bound to.
static func _get_out_hint() -> String:
	var key := "E"
	for event in InputMap.action_get_events("interact"):
		if event is InputEventKey:
			key = (event as InputEventKey).as_text_physical_keycode()
			break
	return "%s  get out" % key

func hide_drive() -> void:
	visible = false
