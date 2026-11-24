extends CanvasLayer
## Toasts (D-142): short notices that fade in at the top centre of the screen,
## stay a few seconds, and fade out, like the pop-ups on a web page. Anything
## can post one without knowing about this node:
##
##   get_tree().call_group("toast", "show_toast", "The pond is full", Color(0.4, 0.7, 1.0))
##
## Notices queue up and show one at a time. They keep running while the game is
## paused (the sky menu, the map), so a notice raised from a menu button shows
## straight away.

const HudStyle := preload("res://scripts/hud_style.gd")

const FONT_SIZE := 30
const FADE_IN := 0.25
const HOLD := 3.2
const FADE_OUT := 0.7
## How far the notice slides down as it appears, in pixels.
const SLIDE := 18.0
## Gap between the top of the window and a settled notice.
const TOP_MARGIN := 56.0
## Notices waiting behind the one on screen; more than this drops the oldest.
const MAX_QUEUED := 6
const DEFAULT_ACCENT := Color(1.0, 0.86, 0.55)

var _queue: Array = []   # [text, accent]
var _showing := false
## What is on screen now, and how far through its slide it is (0..1).
var current_text := ""
var _slide := 0.0
var _panel: PanelContainer
var _label: Label
var _style: StyleBoxFlat
var _tween: Tween

func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("toast")
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style = HudStyle.dialog(DEFAULT_ACCENT)
	_style.bg_color = Color(0.04, 0.06, 0.1, 0.9)
	_style.set_content_margin_all(14)
	_style.content_margin_left = 22
	_style.content_margin_right = 26
	_style.set_border_width_all(0)
	_style.border_width_left = 8
	_style.set_corner_radius_all(10)
	_panel.add_theme_stylebox_override("panel", _style)
	_panel.modulate.a = 0.0
	_panel.visible = false
	root.add_child(_panel)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", Color(0.96, 0.97, 1.0))
	_panel.add_child(_label)

func _process(_delta: float) -> void:
	if _panel.visible:
		var size := get_viewport().get_visible_rect().size / get_window().content_scale_factor
		_panel.position = Vector2((size.x - _panel.size.x) * 0.5, TOP_MARGIN - SLIDE * (1.0 - _slide))

## Show `text`, with a coloured edge in `accent`. A notice already waiting or
## on screen with the same text is not repeated.
func show_toast(text: String, accent := DEFAULT_ACCENT) -> void:
	if text == current_text and _showing:
		return
	for waiting in _queue:
		if waiting[0] == text:
			return
	_queue.append([text, accent])
	while _queue.size() > MAX_QUEUED:
		_queue.pop_front()
	if not _showing:
		_next()

## How many notices are waiting behind the one on screen.
func queued() -> int:
	return _queue.size()

func is_showing() -> bool:
	return _showing

## Drop everything, on screen and waiting.
func clear() -> void:
	_queue.clear()
	if _tween:
		_tween.kill()
	_showing = false
	current_text = ""
	_panel.visible = false

func _next() -> void:
	if _queue.is_empty():
		_showing = false
		current_text = ""
		_panel.visible = false
		return
	var item: Array = _queue.pop_front()
	_showing = true
	current_text = item[0]
	_label.text = item[0]
	_style.border_color = item[1]
	_panel.reset_size()
	_panel.visible = true
	_panel.modulate.a = 0.0
	_slide = 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.set_parallel(true)
	_tween.tween_property(_panel, "modulate:a", 1.0, FADE_IN)
	_tween.tween_property(self, "_slide", 1.0, FADE_IN)
	_tween.set_parallel(false)
	_tween.tween_interval(HOLD)
	_tween.tween_property(_panel, "modulate:a", 0.0, FADE_OUT).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_next)
