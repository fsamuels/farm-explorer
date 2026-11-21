extends Control
## The minimap (bottom left, always on) and the full-screen map that M
## (`toggle_map`) opens (D-93). This node owns what the two share: the scene's
## map data, the breadcrumb trail of where you've walked, and the waypoint.
##
## Opening the map pauses the game and frees the mouse, as most first-person
## games do; minimap.tscn sets process_mode ALWAYS so this node keeps running.

const MapMath := preload("res://scripts/map_math.gd")
const MapCanvas := preload("res://scripts/map_canvas.gd")

const MINIMAP_SIZE := Vector2(360, 360)
const MINIMAP_MARGIN := 24.0
## Pixels per metre on the minimap, which follows the player.
const MINIMAP_SCALE := 1.8
## Above the player HUD (crosshair, controls help).
const FULL_MAP_LAYER := 10
const FULL_MAX_SCALE := 24.0
## Furthest zoom-out, as a fraction of the zoom that fits the whole farm.
const FULL_MIN_ZOOM := 0.8
## Zoom the map opens at, as a multiple of the fit-the-farm zoom.
const FULL_OPEN_ZOOM := 1.6
const ZOOM_STEP := 1.2
const TRAIL_SPACING := 3.0
const TRAIL_MAX_POINTS := 4000
## How close (px) a right-click must be to the waypoint to remove it.
const WAYPOINT_PICK_RADIUS := 28.0
## "Near <building>" shows within this many metres of a footprint.
const NEARBY_DISTANCE := 20.0
const FONT_SIZE := 22
const KEY_COLOR := Color(1.0, 0.86, 0.55)
## Number keys that toggle map layers while the map is open:
## [key, MapCanvas property, legend text].
const LAYERS := [
	[KEY_1, "show_labels", "Names"],
	[KEY_2, "show_fences", "Fences"],
	[KEY_3, "show_horses", "Horses"],
	[KEY_4, "show_trail", "Your trail"],
	[KEY_5, "show_grid", "Grid (X / Z metres)"],
]
const CONTROLS := [
	["Mouse wheel", "Zoom"],
	["Drag", "Pan"],
	["Right-click", "Set / remove waypoint"],
	["C", "Center on you"],
	["Backspace", "Clear waypoint"],
	["M / Esc", "Close map"],
]

@export var player_path: NodePath

@onready var player: Node3D = get_node(player_path)

var trail := PackedVector2Array()
## Vector2 world position, or null when no waypoint is set.
var waypoint = null

var _data := {}
var _minimap_box: VBoxContainer
var _minimap: MapCanvas
var _minimap_info: Label
var _full_layer: CanvasLayer
var _full: MapCanvas
var _location_label: Label
var _cursor_label: Label
var _layer_labels: Array[Label] = []
var _dragging := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_minimap()
	_build_full_map()
	# Wait until every building and fence has its final transform.
	_collect.call_deferred()

func _collect() -> void:
	_data = MapCanvas.collect(get_tree())
	for canvas in [_minimap, _full]:
		canvas.data = _data
		canvas.player = player

func is_open() -> bool:
	return _full_layer.visible

func _process(_delta: float) -> void:
	if player == null or _data.is_empty():
		return
	var here := MapMath.flatten(player.global_position)
	if not get_tree().paused:
		MapMath.trail_append(trail, here, TRAIL_SPACING, TRAIL_MAX_POINTS)
	for canvas in [_minimap, _full]:
		canvas.trail = trail
		canvas.waypoint = waypoint

	if is_open():
		_update_full_map(here)
		_full.queue_redraw()
	else:
		_minimap.center = here
		_minimap_info.text = _minimap_text(here)
		_minimap.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_map"):
		set_open(not is_open())
		get_viewport().set_input_as_handled()
		return
	if not is_open():
		return
	if event.is_action_pressed("ui_cancel"):
		set_open(false)
		get_viewport().set_input_as_handled()
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_C:
			_full.center = MapMath.flatten(player.global_position)
		KEY_BACKSPACE, KEY_DELETE:
			waypoint = null
		_:
			for i in LAYERS.size():
				if key.physical_keycode == LAYERS[i][0]:
					_toggle_layer(i)
	get_viewport().set_input_as_handled()

func set_open(open: bool) -> void:
	if open == is_open():
		return
	_full_layer.visible = open
	_minimap_box.visible = not open
	get_tree().paused = open
	_dragging = false
	if open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_full.scale_px = clampf(_fit_scale() * FULL_OPEN_ZOOM, _min_scale(), FULL_MAX_SCALE)
		_full.center = MapMath.flatten(player.global_position)
		_clamp_center()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_full_map_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		match button.button_index:
			MOUSE_BUTTON_WHEEL_UP when button.pressed:
				_zoom_to(_full.scale_px * ZOOM_STEP, button.position)
			MOUSE_BUTTON_WHEEL_DOWN when button.pressed:
				_zoom_to(_full.scale_px / ZOOM_STEP, button.position)
			MOUSE_BUTTON_LEFT:
				_dragging = button.pressed
			MOUSE_BUTTON_RIGHT when button.pressed:
				_toggle_waypoint(button.position)
	elif event is InputEventMouseMotion and _dragging:
		_full.center -= (event as InputEventMouseMotion).relative / _full.scale_px
		_clamp_center()
	elif event is InputEventMagnifyGesture:
		var pinch := event as InputEventMagnifyGesture
		_zoom_to(_full.scale_px * pinch.factor, pinch.position)

func _zoom_to(new_scale: float, pivot: Vector2) -> void:
	new_scale = clampf(new_scale, _min_scale(), FULL_MAX_SCALE)
	_full.center = MapMath.zoom_center(_full.center, _full.scale_px, new_scale, pivot, _full.size)
	_full.scale_px = new_scale
	_clamp_center()

## The zoom (px per metre) at which the whole imaged farm fits the screen.
func _fit_scale() -> float:
	var bounds: Rect2 = _data.get("bounds", Rect2())
	if not bounds.has_area():
		return 1.0
	var view := get_viewport().get_visible_rect().size
	return minf(view.x / bounds.size.x, view.y / bounds.size.y)

func _min_scale() -> float:
	return _fit_scale() * FULL_MIN_ZOOM

## Keeps the view centered somewhere over the imagery so you can't pan away.
func _clamp_center() -> void:
	var bounds: Rect2 = _data.get("bounds", Rect2())
	if bounds.has_area():
		_full.center = _full.center.clamp(bounds.position, bounds.end)

func _toggle_waypoint(screen: Vector2) -> void:
	if waypoint != null and _full.to_screen(waypoint).distance_to(screen) <= WAYPOINT_PICK_RADIUS:
		waypoint = null
	else:
		waypoint = _full.to_world(screen)

func _toggle_layer(index: int) -> void:
	var property: String = LAYERS[index][1]
	var on: bool = not _full.get(property)
	_full.set(property, on)
	# Names and the grid stay off the minimap; it's too small for them.
	if property not in ["show_labels", "show_grid"]:
		_minimap.set(property, on)
	_refresh_layer_labels()

func _update_full_map(here: Vector2) -> void:
	var cursor := _full.to_world(_full.get_local_mouse_position())
	var hovered := MapMath.footprint_at(cursor, _data.footprints)
	_full.highlighted_building = hovered

	var heading := MapMath.yaw_to_bearing(player.global_rotation.y)
	var location := "%s  ·  facing %s (%d°)" % [_location_text(here), MapMath.cardinal(heading), roundi(heading)]
	if waypoint != null:
		location += "\n" + _waypoint_text(here)
	_location_label.text = location

	var cursor_text := "X %.1f   Z %.1f   ·   %s %s of you" % [
		cursor.x, cursor.y,
		MapMath.format_distance(here.distance_to(cursor)),
		MapMath.cardinal(MapMath.bearing_between(here, cursor)),
	]
	if hovered != -1:
		cursor_text = _data.buildings[hovered].name + "   ·   " + cursor_text
	_cursor_label.text = cursor_text

func _minimap_text(here: Vector2) -> String:
	var heading := MapMath.yaw_to_bearing(player.global_rotation.y)
	var lines := ["X %.1f   Z %.1f   ·   %s %d°" % [here.x, here.y, MapMath.cardinal(heading), roundi(heading)]]
	lines.append(_location_text(here))
	if waypoint != null:
		lines.append(_waypoint_text(here))
	return "\n".join(lines)

func _location_text(here: Vector2) -> String:
	var inside := MapMath.footprint_at(here, _data.footprints)
	if inside != -1:
		return "At " + _data.buildings[inside].name
	var near := MapMath.nearest_footprint(here, _data.footprints, NEARBY_DISTANCE)
	if near != -1:
		return "Near " + _data.buildings[near].name
	return "Out on the farm"

func _waypoint_text(here: Vector2) -> String:
	return "Waypoint: %s %s" % [
		MapMath.format_distance(here.distance_to(waypoint)),
		MapMath.cardinal(MapMath.bearing_between(here, waypoint)),
	]

func _build_minimap() -> void:
	_minimap_box = VBoxContainer.new()
	_minimap_box.anchor_top = 1.0
	_minimap_box.anchor_bottom = 1.0
	_minimap_box.offset_left = MINIMAP_MARGIN
	_minimap_box.offset_top = -MINIMAP_MARGIN
	_minimap_box.offset_bottom = -MINIMAP_MARGIN
	# Grow upward, so extra info lines push the text up, not the map down.
	_minimap_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_minimap_box.add_theme_constant_override("separation", 6)
	add_child(_minimap_box)

	var hint := _outlined_label("M — Map", FONT_SIZE - 2)
	hint.add_theme_color_override("font_color", KEY_COLOR)
	_minimap_box.add_child(hint)
	_minimap_info = _outlined_label("", FONT_SIZE - 4)
	_minimap_box.add_child(_minimap_info)

	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _panel_style(Color(0, 0, 0, 0.6), 4))
	_minimap_box.add_child(frame)
	_minimap = MapCanvas.new()
	_minimap.custom_minimum_size = MINIMAP_SIZE
	_minimap.clip_contents = true
	_minimap.scale_px = MINIMAP_SCALE
	_minimap.show_labels = false
	_minimap.show_grid = false
	_minimap.pin_waypoint_to_edge = true
	_minimap.marker_scale = 0.8
	_minimap.font_size = FONT_SIZE - 6
	frame.add_child(_minimap)

	# North is always up on the minimap; say so.
	var north := _outlined_label("N", FONT_SIZE - 2)
	north.add_theme_color_override("font_color", KEY_COLOR)
	north.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	north.grow_horizontal = Control.GROW_DIRECTION_BOTH
	north.offset_top = 2
	_minimap.add_child(north)
	_ignore_mouse(_minimap_box)

func _build_full_map() -> void:
	_full_layer = CanvasLayer.new()
	_full_layer.layer = FULL_MAP_LAYER
	_full_layer.visible = false
	add_child(_full_layer)

	_full = MapCanvas.new()
	_full.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_full.clip_contents = true
	_full.mouse_filter = Control.MOUSE_FILTER_STOP
	_full.show_compass = true
	_full.show_scale_bar = true
	_full.font_size = FONT_SIZE
	_full.marker_scale = 1.4
	_full.gui_input.connect(_on_full_map_input)
	_full_layer.add_child(_full)

	var title_panel := PanelContainer.new()
	title_panel.add_theme_stylebox_override("panel", _panel_style(Color(0, 0, 0, 0.6), 16))
	title_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title_panel.offset_top = 24
	var title_box := VBoxContainer.new()
	title_panel.add_child(title_box)
	var title := _outlined_label("Reign Cloud Ranch", FONT_SIZE + 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_box.add_child(title)
	_location_label = _outlined_label("", FONT_SIZE)
	_location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_box.add_child(_location_label)
	_full_layer.add_child(title_panel)

	var legend := _build_legend()
	legend.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	legend.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	legend.offset_right = -24
	legend.offset_top = 210
	_full_layer.add_child(legend)

	var cursor_panel := PanelContainer.new()
	cursor_panel.add_theme_stylebox_override("panel", _panel_style(Color(0, 0, 0, 0.6), 10))
	cursor_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	cursor_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	cursor_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	cursor_panel.offset_bottom = -24
	_cursor_label = _outlined_label("", FONT_SIZE - 2)
	cursor_panel.add_child(_cursor_label)
	_full_layer.add_child(cursor_panel)

	for overlay in [title_panel, legend, cursor_panel]:
		_ignore_mouse(overlay)

func _build_legend() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0, 0, 0, 0.6), 18))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	box.add_child(_heading("Key"))
	for row in [
		[MapCanvas.PLAYER_COLOR, "You"],
		[MapCanvas.WAYPOINT_COLOR, "Waypoint"],
		[MapCanvas.BUILDING_FILL, "Building"],
		[MapCanvas.HORSE_COLOR, "Horse"],
		[MapCanvas.FENCE_COLOR, "Fence"],
		[MapCanvas.BOUNDARY_COLOR, "Property line"],
		[MapCanvas.TRAIL_COLOR, "Where you've been"],
	]:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		var swatch := ColorRect.new()
		swatch.color = Color(row[0], 1.0)
		swatch.custom_minimum_size = Vector2(22, 22)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(swatch)
		line.add_child(_outlined_label(row[1], FONT_SIZE - 2))
		box.add_child(line)

	box.add_child(_heading("Layers"))
	for i in LAYERS.size():
		var label := _outlined_label("", FONT_SIZE - 2)
		_layer_labels.append(label)
		box.add_child(label)
	_refresh_layer_labels()

	box.add_child(_heading("Controls"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	for row in CONTROLS:
		var key := _outlined_label(row[0], FONT_SIZE - 2)
		key.add_theme_color_override("font_color", KEY_COLOR)
		grid.add_child(key)
		grid.add_child(_outlined_label(row[1], FONT_SIZE - 2))
	box.add_child(grid)
	return panel

func _refresh_layer_labels() -> void:
	for i in LAYERS.size():
		var on: bool = _full.get(LAYERS[i][1])
		_layer_labels[i].text = "%s  %s  %s" % [OS.get_keycode_string(LAYERS[i][0]), LAYERS[i][2], "on" if on else "off"]
		_layer_labels[i].modulate = Color(1, 1, 1) if on else Color(1, 1, 1, 0.5)

func _heading(text: String) -> Label:
	var label := _outlined_label(text, FONT_SIZE + 2)
	label.add_theme_color_override("font_color", KEY_COLOR)
	return label

func _outlined_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 4)
	return label

func _panel_style(color: Color, margin: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
	style.set_content_margin_all(margin)
	return style

## Overlays never take the mouse, so drags and clicks reach the map (or, for
## the minimap, the game's click-to-recapture).
func _ignore_mouse(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in control.get_children():
		if child is Control:
			_ignore_mouse(child)
