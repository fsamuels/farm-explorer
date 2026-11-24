extends Control
const WorldMath := preload("res://scripts/world_math.gd")
## The minimap (bottom left, always on) and the full-screen map that M
## (`toggle_map`) opens (D-93). This node owns what the two share: the scene's
## map data, the breadcrumb trail of where you've walked, and the waypoint.
##
## Opening the map pauses the game and frees the mouse, as most first-person
## games do; minimap.tscn sets process_mode ALWAYS so this node keeps running.

const MapMath := preload("res://scripts/map_math.gd")
const MapCanvas := preload("res://scripts/map_canvas.gd")
const HudStyle := preload("res://scripts/hud_style.gd")

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
## How close (screen px) a double-click must be to a transport point's marker.
const PLACE_PICK_RADIUS := 24.0
## "Near <building>" shows within this many metres of a footprint.
const NEARBY_DISTANCE := 20.0
const FONT_SIZE := 22
## The X / Z readout is bigger than the other minimap text (it is read all the time while placing things).
const COORDS_FONT_SIZE := 34
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
	["Double-click building", "Teleport to its front door"],
	["C", "Center on you"],
	["Backspace", "Clear waypoint"],
	["M / Esc", "Close map"],
]

@export var player_path: NodePath

@onready var player: Node3D = get_node(player_path)

## The "G — Sky" icon button under the minimap (D-110).
var sky_button: Button
## The "C — News" icon button beside it (D-130).
var news_button: Button
var trail := PackedVector2Array()
## Vector2 world position, or null when no waypoint is set.
var waypoint = null

var _data := {}
var _minimap_box: VBoxContainer
var _minimap: MapCanvas
var _minimap_info: Label
## Big X / Z readout above the info lines; click it (with a free mouse) to copy
## "x, z facing N°" to the clipboard.
var _coords: Label
var _copied_until := 0.0
## The bottom key-hint bar, right of the minimap (M Map, G Sky, C News, F1 Help, Tab size).
var _hint_bar: PanelContainer
var _size_index := 0
## Chips dropped first when the window is too narrow, least important first.
var _optional_chips: Array[Label] = []
var _idle := 0.0
var _full_layer: CanvasLayer
var _full: MapCanvas
var _location_label: Label
var _cursor_label: Label
var _layer_labels: Array[Label] = []
var _dragging := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_hud_scale()
	get_window().size_changed.connect(_apply_hud_scale)
	get_viewport().size_changed.connect(_on_view_resized)
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

func _process(delta: float) -> void:
	_idle += delta
	# A free mouse (menus, Esc) means someone is reaching for the buttons.
	_hint_bar.modulate.a = 1.0 if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED else HudStyle.fade_alpha(_idle)
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
		_minimap_info.visible = _minimap_info.text != ""
		_coords.text = _coords_text(here)
		_minimap.queue_redraw()

## Keeps the HUD readable on big or high-DPI windows (never shrinks it).
func _apply_hud_scale() -> void:
	get_window().content_scale_factor = HudStyle.scale_for(float(get_window().size.y))

func _on_view_resized() -> void:
	if _hint_bar != null and _minimap != null:
		_apply_minimap_size()

func _apply_minimap_size() -> void:
	var edge: float = minf(HudStyle.MINIMAP_SIZES[_size_index], get_viewport().get_visible_rect().size.y * 0.45)
	_minimap.custom_minimum_size = Vector2(edge, edge)
	_minimap.size = Vector2(edge, edge)
	if _hint_bar != null:
		_hint_bar.offset_left = MINIMAP_MARGIN * 2.0 + edge + 8.0
		_fit_hint_bar.call_deferred()

## On a narrow window, drop the least important chips (Tab, then F1) so the
## bar never runs off the right edge.
func _fit_hint_bar() -> void:
	for chip in _optional_chips:
		chip.visible = true
	_hint_bar.reset_size()
	var room := get_viewport().get_visible_rect().size.x - _hint_bar.offset_left - MINIMAP_MARGIN
	for chip in _optional_chips:
		if _hint_bar.get_combined_minimum_size().x <= room:
			break
		chip.visible = false
		_hint_bar.reset_size()

## One dark bar of key chips along the bottom, in place of the loose hints. It
## fades after a few idle seconds (see _process) and returns on any input.
func _build_hint_bar() -> void:
	_hint_bar = PanelContainer.new()
	_hint_bar.add_theme_stylebox_override("panel", HudStyle.panel(8.0, 0.68))
	# Bottom row, just right of the minimap so the two never overlap.
	_hint_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_hint_bar.grow_horizontal = Control.GROW_DIRECTION_END
	_hint_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint_bar.offset_bottom = -MINIMAP_MARGIN
	add_child(_hint_bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	_hint_bar.add_child(row)
	row.add_child(_chip("M", "Map"))
	row.add_child(_chip("1", "Torch"))
	sky_button = _build_sky_button()
	row.add_child(sky_button)
	news_button = _build_news_button()
	row.add_child(news_button)
	var help_chip := _chip("F1", "Help")
	row.add_child(help_chip)
	var size_chip := _chip("Tab", "Map size")
	row.add_child(size_chip)
	_optional_chips = [size_chip, help_chip]

func _chip(key: String, text: String) -> Label:
	var label := _outlined_label("%s — %s" % [key, text], FONT_SIZE - 2)
	label.add_theme_color_override("font_color", KEY_COLOR)
	return label

## Any key or click counts as activity: it wakes the hint bar, and Tab cycles
## the minimap's size.
func _input(event: InputEvent) -> void:
	if (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed):
		_idle = 0.0
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB and not is_open() and not get_tree().paused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_size_index = HudStyle.next_minimap_index(_size_index)
		_apply_minimap_size()
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	var window := get_window()
	if window != null:
		if window.size_changed.is_connected(_apply_hud_scale):
			window.size_changed.disconnect(_apply_hud_scale)
		window.content_scale_factor = 1.0
	if get_viewport().size_changed.is_connected(_on_view_resized):
		get_viewport().size_changed.disconnect(_on_view_resized)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_map"):
		if get_tree().paused and not is_open():
			return  # the sky menu has the game paused
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
	_hint_bar.visible = not open
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
				if button.pressed and button.double_click:
					var vehicle := _vehicle_at(button.position)
					var place := _place_at(button.position)
					if vehicle != -1:
						_teleport_to_vehicle(vehicle)
					elif place != -1:
						_teleport_to_place(place)
					else:
						_teleport_to(MapMath.footprint_at(_full.to_world(button.position), _data.footprints))
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
	# Zoomed out as far as the whole driveable world (D-148), if it's in the data.
	var world: Rect2 = _data.get("world_bounds", Rect2())
	if world.has_area():
		var view := get_viewport().get_visible_rect().size
		return minf(view.x / world.size.x, view.y / world.size.y) * FULL_MIN_ZOOM
	return _fit_scale() * FULL_MIN_ZOOM

## Keeps the view centered somewhere over the imagery so you can't pan away.
func _clamp_center() -> void:
	var bounds: Rect2 = _data.get("world_bounds", _data.get("bounds", Rect2()))
	if bounds.has_area():
		_full.center = _full.center.clamp(bounds.position, bounds.end)

## Where to stand at (x, z): just above the ground there. Teleporting used to
## keep the current height, which buried you wherever the land is higher.
func _ground_y(x: float, z: float) -> float:
	return WorldMath.height_at(x, z) + 0.2

## Moves the player to just outside a building's front door, facing it, and
## closes the map (D-118). Not while driving: the car would be left behind.
func _teleport_to(index: int) -> void:
	if index == -1 or player.get("vehicle") != null:
		return
	var building: Dictionary = _data.buildings[index]
	var spot: Vector2 = building.front
	var yaw := MapMath.yaw_facing(spot, building.center)
	player.global_transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(spot.x, _ground_y(spot.x, spot.y), spot.y))
	player.velocity = Vector3.ZERO
	player.model_yaw = 0.0
	# The trail is where you've walked; a jump would draw a line across the farm.
	trail.clear()
	set_open(false)

## Index into data.places of the transport-point marker under `screen`, or -1.
func _place_at(screen: Vector2) -> int:
	var best := -1
	var best_dist := PLACE_PICK_RADIUS
	for i in _data.places.size():
		var d: float = _full.to_screen(_data.places[i].at).distance_to(screen)
		if d <= best_dist:
			best = i
			best_dist = d
	return best

## Index into data.vehicles of the vehicle marker under `screen`, or -1.
func _vehicle_at(screen: Vector2) -> int:
	var best := -1
	var best_dist := PLACE_PICK_RADIUS
	for i in _data.vehicles.size():
		var car: Node3D = _data.vehicles[i]
		if not is_instance_valid(car):
			continue
		var d: float = _full.to_screen(MapMath.flatten(car.global_position)).distance_to(screen)
		if d <= best_dist:
			best = i
			best_dist = d
	return best

## Moves the player beside a vehicle, facing the way it points, and closes the
## map (D-144). Not while driving, and not into a car someone is driving.
func _teleport_to_vehicle(index: int) -> void:
	if index == -1 or player.get("vehicle") != null:
		return
	var car: Node3D = _data.vehicles[index]
	if car.driver != null:
		return
	var spot: Vector3 = car.map_arrival_spot()
	player.global_transform = Transform3D(Basis(Vector3.UP, car.global_rotation.y), Vector3(spot.x, _ground_y(spot.x, spot.z), spot.z))
	player.velocity = Vector3.ZERO
	player.model_yaw = 0.0
	trail.clear()
	set_open(false)

## Moves the player to a transport point in the back pastures and closes the
## map (D-139). Not while driving, like building teleports.
func _teleport_to_place(index: int) -> void:
	if index == -1 or player.get("vehicle") != null:
		return
	_data.places[index].node.receive(player)
	trail.clear()
	set_open(false)

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
	var hovered_place := _place_at(_full.get_local_mouse_position())
	_full.highlighted_place = hovered_place
	var hovered_vehicle := _vehicle_at(_full.get_local_mouse_position())
	_full.highlighted_vehicle = hovered_vehicle
	# Vehicles, then markers, win over a building under them, as on double-click.
	if hovered_vehicle != -1:
		hovered_place = -1
		_full.highlighted_place = -1
	if hovered_vehicle != -1 or hovered_place != -1:
		hovered = -1
		_full.highlighted_building = -1

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
		var hint := "get out of the car to teleport" if player.get("vehicle") != null else "double-click to teleport"
		cursor_text = "%s  (%s)   ·   %s" % [_data.buildings[hovered].name, hint, cursor_text]
	if hovered_place != -1:
		var hint := "get out of the car to teleport" if player.get("vehicle") != null else "double-click to teleport"
		cursor_text = "%s  (%s)   ·   %s" % [_data.places[hovered_place].name, hint, cursor_text]
	if hovered_vehicle != -1:
		var hint := "get out of the car to teleport" if player.get("vehicle") != null else "double-click to teleport"
		cursor_text = "%s  (%s)   ·   %s" % [_data.vehicles[hovered_vehicle].label, hint, cursor_text]
	_cursor_label.text = cursor_text

func _minimap_text(here: Vector2) -> String:
	var heading := MapMath.yaw_to_bearing(player.global_rotation.y)
	var lines := ["Facing %s %d°" % [MapMath.cardinal(heading), roundi(heading)]]
	lines.append(_location_text(here))
	if waypoint != null:
		lines.append(_waypoint_text(here))
	return "\n".join(lines)

## The big readout: "X 12.9   Z 17.6", with a hint when a click would copy it.
func _coords_text(here: Vector2) -> String:
	var text := "X %.1f   Z %.1f" % [here.x, here.y]
	if Time.get_ticks_msec() / 1000.0 < _copied_until:
		return text + "   (copied)"
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return text + "   (click to copy)"
	return text

## What a click copies: the spot and the way you face, e.g. "12.9, 17.6 facing 333°".
func coords_clipboard_text() -> String:
	var here := MapMath.flatten(player.global_position)
	var heading := MapMath.yaw_to_bearing(player.global_rotation.y)
	return "%.1f, %.1f facing %d°" % [here.x, here.y, roundi(heading)]

func _on_coords_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and player != null:
		DisplayServer.clipboard_set(coords_clipboard_text())
		_copied_until = Time.get_ticks_msec() / 1000.0 + 1.5

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

	_coords = _outlined_label("", COORDS_FONT_SIZE)
	_coords.add_theme_stylebox_override("normal", HudStyle.backing(8.0, 2.0))
	_coords.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_coords.gui_input.connect(_on_coords_input)
	_minimap_box.add_child(_coords)

	_minimap_info = _outlined_label("", FONT_SIZE - 4)
	_minimap_info.add_theme_stylebox_override("normal", HudStyle.backing(8.0, 2.0))
	_minimap_info.visible = false
	_minimap_info.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_minimap_box.add_child(_minimap_info)
	_build_hint_bar()

	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", HudStyle.panel(4.0))
	_minimap_box.add_child(frame)
	_minimap = MapCanvas.new()
	_minimap.clip_contents = true
	_minimap.scale_px = MINIMAP_SCALE
	_minimap.show_labels = false
	_minimap.show_grid = false
	_minimap.pin_waypoint_to_edge = true
	_minimap.marker_scale = 0.8
	_minimap.font_size = FONT_SIZE - 6
	frame.add_child(_minimap)
	_apply_minimap_size()

	# North is always up on the minimap; say so.
	var north := _outlined_label("N", FONT_SIZE - 2)
	north.add_theme_color_override("font_color", KEY_COLOR)
	north.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	north.grow_horizontal = Control.GROW_DIRECTION_BOTH
	north.offset_top = 2
	_minimap.add_child(north)
	_ignore_mouse(_minimap_box)
	_ignore_mouse(_hint_bar)
	# The coordinates click to copy (with a free mouse), like the icons below.
	_coords.mouse_filter = Control.MOUSE_FILTER_STOP
	_coords.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# The icons are the only clickable things here (with a free mouse).
	sky_button.mouse_filter = Control.MOUSE_FILTER_STOP
	news_button.mouse_filter = Control.MOUSE_FILTER_STOP

## The sun-and-cloud icon (and "G") that opens the sky menu (D-110). It needs a
## free mouse to click (Esc), so the key is the main way in.
func _build_sky_button() -> Button:
	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.text = "G — Sky"
	button.add_theme_font_size_override("font_size", FONT_SIZE - 2)
	button.add_theme_color_override("font_color", KEY_COLOR)
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	button.icon = _sky_icon()
	button.tooltip_text = "Pick the time of day and the weather"
	button.pressed.connect(func() -> void: get_tree().call_group("sky_menu", "set_open", true))
	return button

## The star icon (and "C") that opens the What's New dialog (D-130).
func _build_news_button() -> Button:
	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.text = "C — News"
	button.add_theme_font_size_override("font_size", FONT_SIZE - 2)
	button.add_theme_color_override("font_color", KEY_COLOR)
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	button.icon = _news_icon()
	button.tooltip_text = "What's new in the game"
	button.pressed.connect(func() -> void: get_tree().call_group("whats_new", "set_open", true))
	return button

## A four-pointed sparkle, drawn into a texture so there is no icon file to ship.
static func _news_icon() -> ImageTexture:
	var size := 40
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(20, 20)
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5) - c
			# |x|^0.5 + |y|^0.5 < r is a pointed four-armed star (an astroid).
			var inside := sqrt(absf(d.x)) + sqrt(absf(d.y)) < 4.2
			img.set_pixel(x, y, Color(1.0, 0.86, 0.35) if inside else Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)

## A small sun peeking out from behind a cloud, drawn into a texture so there
## is no icon file to ship.
static func _sky_icon() -> ImageTexture:
	var size := 40
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var sun := Vector2(14, 14)
	var puffs := [Vector2(14, 28), Vector2(22, 24), Vector2(30, 28)]
	var radii := [7.0, 9.0, 6.5]
	for y in size:
		for x in size:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := p.distance_to(sun)
			var color := Color(0, 0, 0, 0)
			if d < 7.5:
				color = Color(1.0, 0.82, 0.25)
			elif d < 11.5 and fposmod(rad_to_deg((p - sun).angle()) + 11.25, 45.0) < 22.5:
				color = Color(1.0, 0.82, 0.25)
			var in_cloud := p.y > 24.0 and p.y < 34.0 and p.x > 8.0 and p.x < 36.0
			for i in puffs.size():
				if p.distance_to(puffs[i]) < radii[i]:
					in_cloud = true
			if in_cloud:
				color = Color(0.92, 0.95, 1.0)
			img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)

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
	_full.show_places = true
	_full.font_size = FONT_SIZE
	_full.marker_scale = 1.4
	_full.gui_input.connect(_on_full_map_input)
	_full_layer.add_child(_full)

	var title_panel := PanelContainer.new()
	title_panel.add_theme_stylebox_override("panel", HudStyle.panel(16.0))
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
	cursor_panel.add_theme_stylebox_override("panel", HudStyle.panel(10.0))
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
	panel.add_theme_stylebox_override("panel", HudStyle.panel(18.0))
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

## Overlays never take the mouse, so drags and clicks reach the map (or, for
## the minimap, the game's click-to-recapture).
func _ignore_mouse(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in control.get_children():
		if child is Control:
			_ignore_mouse(child)
