extends CanvasLayer
## The Things to Do card (D-167): a short list of what a new player can try, each
## with a "Take me there" button that teleports them to the spot, a Done tick
## once they have done it, and (for the paddle) a "Fill the pond" shortcut so
## the kayak has water without waiting for the weir. H (`toggle_things_to_do`)
## or the hint in the top left opens it. Like the map, the sky menu and What's
## New it pauses the game and frees the mouse while open; Esc, H or Close
## resumes. It never opens by itself.
##
## When the game starts a small read-only version of the list (no buttons, never
## takes the mouse) shows in the top left in place of the F1 controls panel
## (D-168). It tucks itself away after HIDE_AFTER_MOVING seconds of walking or
## driving, or when you press any other key, like the controls panel does.
##
## What counts as done is watched while you play (the fire quest, the weir, who
## is sitting in which vehicle) and kept in user://things_to_do.cfg so the ticks
## survive a restart. The bomb shelter is deliberately not listed: it is meant to
## be found (docs/easter-eggs.md).

const MapMath := preload("res://scripts/map_math.gd")
const WorldMath := preload("res://scripts/world_math.gd")
const WaterData := preload("res://scripts/water_data.gd")
const FireSystem := preload("res://scripts/fire_system.gd")
const HudStyle := preload("res://scripts/hud_style.gd")
const ActivityIcon := preload("res://scripts/activity_icon.gd")
const ControlsOverlay := preload("res://scripts/controls_overlay.gd")

## One entry per activity, in the order shown: id, title, what to do, the
## teleport button's label.
const ACTIVITIES := [
	{"id": "burn", "title": "Burn the ditch", "blurb": "Light up the dry grass",
		"text": "Grab the propane torch and torch the dry ditch grass! Press E at the tank by the road to start, 1 for the torch, then hold the left mouse button and burn south to north with the wind.",
		"go": "Take me to the propane tank"},
	{"id": "weir", "title": "Open the weir", "blurb": "Spin the wheel, let the water run",
		"text": "Spin the red wheel (E) to lift the gate and send water down the ditch to the pond. Burn first: a wet ditch won't burn!",
		"go": "Take me to the weir"},
	{"id": "paddle", "title": "Go for a paddle", "blurb": "Kayaks by the pond",
		"text": "Hop in a kayak with E and drag it into the pond with W. It floats once there's water: open the weir, or tap Fill the pond to skip the wait.",
		"go": "Take me to the kayaks"},
	{"id": "utv", "title": "Drive the Cub Cadet", "blurb": "Dump bed and all",
		"text": "Get in with E and drive with W A S D. Slow down and press B to tip the dump bed up and down.",
		"go": "Take me to the Cub Cadet"},
	{"id": "car", "title": "Take a car for a drive", "blurb": "The TR6 or the BMW",
		"text": "The Triumph TR6 and the BMW 2002tii are parked by the house. E to get in, W to go, Space for the handbrake.",
		"go": "Take me to the cars"},
]

const UTV_LABEL := "Cub Cadet 550"
const CAR_LABELS := ["Triumph TR6", "BMW 2002tii"]
const KAYAK_LABELS := ["green kayak", "yellow kayak"]

## How far from the propane tank and the weir's hand wheel you are put down, m.
const TANK_STAND := 2.2
const WEIR_STAND := 3.2
## Seconds between looks at whether something has been done.
const WATCH_INTERVAL := 0.25
## The start-up list tucks away after this many seconds of moving.
const HIDE_AFTER_MOVING := 2.0
const RESET_TEXT := "Start over"
const RESET_SURE_TEXT := "Really? Press again"
const HUD_FONT := 22
const ICON_SIZE := 100.0
const HUD_ICON_SIZE := 44.0

const FONT_SIZE := 34
const PANEL_WIDTH := 1500.0
const WINDOW_FILL := 0.8
const MIN_SCALE := 0.3
const MAX_SCALE := 1.8
const KEY_COLOR := Color(1.0, 0.86, 0.55)
const MUTED := Color(0.7, 0.72, 0.78)
const DONE_COLOR := Color(0.6, 0.9, 0.5)
const TODO_COLOR := Color(0.62, 0.65, 0.72)

@export var player_path: NodePath = ^"../Player"
## Where the ticks are kept; empty keeps them for this session only.
var save_path := "user://things_to_do.cfg"

var done := {}
var _player: Node
var _panel: PanelContainer
var _progress: Label
var _stars: Control
var _heading: Label
var _hud: PanelContainer
var _hud_rows := {}
var _moved := 0.0
var _notice: Label
var _mouse_before := Input.MOUSE_MODE_CAPTURED
var _close_button: Button
var _since_watch := 0.0
## Each activity's widgets, by id, for the tests.
var status_labels := {}
var go_buttons := {}
var icons := {}
var fill_button: Button
var reset_button: Button
var _confirming_reset := false

func _ready() -> void:
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("things_to_do")
	_player = get_node_or_null(player_path)
	done = load_done(save_path)
	_build()
	_build_hud()
	_panel.visible = false
	refresh()

func is_open() -> bool:
	return _panel.visible

func _input(event: InputEvent) -> void:
	if _hud.visible and ControlsOverlay.is_action_key(event) and not event.is_action("toggle_things_to_do"):
		set_hud_open(false)
	if event.is_action_pressed("toggle_things_to_do"):
		if get_tree().paused and not is_open():
			return  # the map or a menu has the game paused
		set_open(not is_open())
		get_viewport().set_input_as_handled()
	elif is_open() and event.is_action_pressed("ui_cancel"):
		set_open(false)
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if _hud.visible:
		var moving := false
		for action in ControlsOverlay.DIRECTION_ACTIONS:
			if Input.is_action_pressed(action):
				moving = true
		_moved = ControlsOverlay.advance_move_time(_moved, moving, delta)
		if _moved >= HIDE_AFTER_MOVING or _controls_open():
			set_hud_open(false)
	_since_watch += delta
	if _since_watch >= WATCH_INTERVAL:
		_since_watch = 0.0
		watch()

## Show or tuck away the start-up list.
func set_hud_open(open: bool) -> void:
	_hud.visible = open
	_moved = 0.0

func _controls_open() -> bool:
	var controls := get_tree().get_first_node_in_group("controls_overlay")
	return controls != null and controls.is_open()

## Open or close the card. Opening is ignored while something else has the
## game paused.
func set_open(open: bool) -> void:
	if open == is_open():
		return
	if open and get_tree().paused:
		return
	_panel.visible = open
	get_tree().paused = open
	_confirming_reset = false
	reset_button.text = RESET_TEXT
	if open:
		set_hud_open(false)
		_notice.text = ""
		refresh()
		_fit_to_window()
		_close_button.grab_focus.call_deferred()  # a controller steers by focus (D-182)
		_mouse_before = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = _mouse_before

func _fit_to_window() -> void:
	var view := get_viewport().get_visible_rect().size
	var size := _panel.get_combined_minimum_size()
	_panel.pivot_offset = size * 0.5
	_panel.scale = Vector2.ONE * ui_scale(view, size)

## The scale that makes a panel of `size` fill WINDOW_FILL of a `view`-sized window.
static func ui_scale(view: Vector2, size: Vector2) -> float:
	return clampf(minf(view.x / size.x, view.y / size.y) * WINDOW_FILL, MIN_SCALE, MAX_SCALE)

# --- what is done ------------------------------------------------------------

## True once the world shows `id` has been done right now.
func is_happening(id: String) -> bool:
	match id:
		"burn":
			var fire := get_tree().get_first_node_in_group("fire")
			return fire != null and int(fire.quest) >= FireSystem.Quest.BURNED
		"weir":
			var water := get_tree().get_first_node_in_group("water")
			return water != null and bool(water.weir_open)
		"paddle":
			for car in _vehicles_labelled(KAYAK_LABELS):
				if car.driver != null and car.get("afloat"):
					return true
		"utv":
			for car in _vehicles_labelled([UTV_LABEL]):
				if car.driver != null:
					return true
		"car":
			for car in _vehicles_labelled(CAR_LABELS):
				if car.driver != null:
					return true
	return false

## Tick off whatever has newly been done, with a toast and a save.
func watch() -> void:
	var newly: Array[String] = []
	for activity: Dictionary in ACTIVITIES:
		var id: String = activity.id
		if not done.get(id, false) and is_happening(id):
			done[id] = true
			newly.append(activity.title)
	if newly.is_empty():
		return
	save_done(save_path, done)
	refresh()
	var toast := get_tree().get_first_node_in_group("toast")
	if toast != null:
		for title in newly:
			toast.show_toast("Done: %s  (%d of %d)" % [title, done_count(done), ACTIVITIES.size()], DONE_COLOR)

static func done_count(state: Dictionary) -> int:
	var n := 0
	for activity: Dictionary in ACTIVITIES:
		if state.get(activity.id, false):
			n += 1
	return n

## The ticks saved in `path`; none when there is no file (or no path).
static func load_done(path: String) -> Dictionary:
	var state := {}
	if path == "":
		return state
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return state
	for activity: Dictionary in ACTIVITIES:
		if config.get_value("done", activity.id, false):
			state[activity.id] = true
	return state

static func save_done(path: String, state: Dictionary) -> void:
	if path == "":
		return
	var config := ConfigFile.new()
	for activity: Dictionary in ACTIVITIES:
		if state.get(activity.id, false):
			config.set_value("done", activity.id, true)
	config.save(path)

# --- taking you there ----------------------------------------------------------

func _vehicles_labelled(labels: Array) -> Array[Node3D]:
	var found: Array[Node3D] = []
	for label: String in labels:
		for node in get_tree().get_nodes_in_group("map_vehicle"):
			if node.get("label") == label:
				found.append(node)
	return found

## Where to put the player for `id`: {"at": Vector3, "yaw": float}, or an empty
## dictionary when there is nowhere to go (the vehicle is not in this world, or
## every one of them has someone driving it).
func destination(id: String) -> Dictionary:
	match id:
		"burn":
			return _beside(FireSystem.TANK_POS, TANK_STAND)
		"weir":
			# The hand wheel is on the weir's west bank.
			return _beside(WaterData.WEIR, WEIR_STAND)
		"paddle":
			return _beside_vehicle(KAYAK_LABELS)
		"utv":
			return _beside_vehicle([UTV_LABEL])
		"car":
			return _beside_vehicle(CAR_LABELS)
	return {}

## A spot `distance` west of `target`, on the ground, facing it.
static func _beside(target: Vector2, distance: float) -> Dictionary:
	var spot := target + Vector2(-distance, 0.0)
	return {
		"at": Vector3(spot.x, WorldMath.height_at(spot.x, spot.y) + 0.2, spot.y),
		"yaw": MapMath.yaw_facing(spot, target),
	}

func _beside_vehicle(labels: Array) -> Dictionary:
	for car in _vehicles_labelled(labels):
		if car.driver != null:
			continue
		var spot: Vector3 = car.map_arrival_spot()
		return {
			"at": Vector3(spot.x, WorldMath.height_at(spot.x, spot.z) + 0.2, spot.z),
			"yaw": car.global_rotation.y,
		}
	return {}

func _driving() -> bool:
	return _player != null and _player.get("vehicle") != null

## Put the player at the destination for `id` and close the card. Not while
## driving (the vehicle would be left behind). Returns whether it went.
func go(id: String) -> bool:
	if _player == null or _driving():
		return false
	var place := destination(id)
	if place.is_empty():
		_notice.text = "Someone is already driving that."
		return false
	_player.global_transform = Transform3D(Basis(Vector3.UP, place.yaw), place.at)
	_player.velocity = Vector3.ZERO
	_player.model_yaw = 0.0
	# Arrive looking level, not at the ground or sky you were looking at.
	var head := _player.get_node_or_null("Head") as Node3D
	if head:
		head.rotation.x = 0.0
	# The trail is where you've walked; a jump would draw a line across the farm.
	get_tree().call_group("minimap", "clear_trail")
	set_open(false)
	return true

## Start over: the first press asks, the second clears every tick (and the
## saved file) and puts the world back so each thing can be done again: the
## ditch grass grows back, the burn quest starts afresh and the weir shuts.
## Opening or closing the card forgets a first press.
func start_over() -> void:
	if not _confirming_reset:
		_confirming_reset = true
		reset_button.text = RESET_SURE_TEXT
		return
	_confirming_reset = false
	reset_button.text = RESET_TEXT
	done.clear()
	save_done(save_path, done)
	var fire := get_tree().get_first_node_in_group("fire")
	if fire != null:
		fire.regrow()
	var water := get_tree().get_first_node_in_group("water")
	if water != null:
		water.weir_open = false
	_notice.text = "Fresh start! The ditch has grown back and the weir is shut."
	refresh()

## Brim the pond so a kayak floats. Works with the weir shut too.
func fill_pond() -> void:
	var water := get_tree().get_first_node_in_group("water")
	if water == null:
		return
	water.set_pond_fill(1.0)
	_notice.text = "The pond is full."
	refresh()

# --- the card --------------------------------------------------------------------

## Update the ticks, the count and which buttons can be used.
func refresh() -> void:
	if _panel == null:
		return
	var driving := _driving()
	for activity: Dictionary in ACTIVITIES:
		var id: String = activity.id
		var ticked: bool = done.get(id, false)
		var label: Label = status_labels[id]
		label.text = "Done!" if ticked else "To do"
		label.add_theme_color_override("font_color", DONE_COLOR if ticked else TODO_COLOR)
		icons[id].ticked = ticked
		_hud_rows[id].modulate = Color(1, 1, 1, 0.45) if ticked else Color.WHITE
		_hud_rows[id].get_child(0).ticked = ticked
		var button: Button = go_buttons[id]
		button.disabled = driving
		button.tooltip_text = "Get out of the vehicle first" if driving else ""
	var count := done_count(done)
	_progress.text = "%d of %d done" % [count, ACTIVITIES.size()]
	_stars.lit = count
	_heading.text = "You've done it all. Farm hero!" if count == ACTIVITIES.size() else "Welcome to the farm!"

func _build() -> void:
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", HudStyle.dialog(KEY_COLOR))
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	_panel.add_child(box)

	var head := HBoxContainer.new()
	box.add_child(head)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	_heading = Label.new()
	_heading.add_theme_font_size_override("font_size", FONT_SIZE + 10)
	_heading.add_theme_color_override("font_color", KEY_COLOR)
	titles.add_child(_heading)
	var tagline := Label.new()
	tagline.text = "Things to do. Pick one and we'll take you there."
	tagline.add_theme_font_size_override("font_size", FONT_SIZE - 10)
	tagline.add_theme_color_override("font_color", MUTED)
	titles.add_child(tagline)
	var tally := VBoxContainer.new()
	head.add_child(tally)
	_stars = ActivityIcon.new(ICON_SIZE)
	_stars.kind = "stars"
	_stars.total = ACTIVITIES.size()
	_stars.custom_minimum_size = Vector2(ICON_SIZE * ACTIVITIES.size() * 0.7, ICON_SIZE * 0.6)
	tally.add_child(_stars)
	_progress = Label.new()
	_progress.add_theme_font_size_override("font_size", FONT_SIZE - 10)
	_progress.add_theme_color_override("font_color", KEY_COLOR)
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tally.add_child(_progress)

	for activity: Dictionary in ACTIVITIES:
		box.add_child(HSeparator.new())
		box.add_child(_row(activity))

	box.add_child(HSeparator.new())
	_notice = Label.new()
	_notice.add_theme_font_size_override("font_size", FONT_SIZE - 8)
	_notice.add_theme_color_override("font_color", KEY_COLOR)
	box.add_child(_notice)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 24)
	box.add_child(bottom)
	var close := Button.new()
	close.text = "Close  (H or Esc)"
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close.add_theme_font_size_override("font_size", FONT_SIZE - 4)
	close.pressed.connect(set_open.bind(false))
	_close_button = close
	bottom.add_child(close)
	reset_button = Button.new()
	reset_button.text = RESET_TEXT
	reset_button.add_theme_font_size_override("font_size", FONT_SIZE - 4)
	reset_button.pressed.connect(start_over)
	bottom.add_child(reset_button)

func _row(activity: Dictionary) -> Control:
	var id: String = activity.id
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	var icon := ActivityIcon.new(ICON_SIZE)
	icon.kind = id
	row.add_child(icon)
	icons[id] = icon
	var status := Label.new()
	status.custom_minimum_size = Vector2(120, 0)
	status.add_theme_font_size_override("font_size", FONT_SIZE - 8)
	row.add_child(status)
	status_labels[id] = status

	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	var name_label := Label.new()
	name_label.text = activity.title
	name_label.add_theme_font_size_override("font_size", FONT_SIZE)
	words.add_child(name_label)
	var text := Label.new()
	text.text = activity.text
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(PANEL_WIDTH * 0.55, 0)
	text.add_theme_font_size_override("font_size", FONT_SIZE - 12)
	text.add_theme_color_override("font_color", MUTED)
	words.add_child(text)

	var buttons := VBoxContainer.new()
	buttons.custom_minimum_size = Vector2(PANEL_WIDTH * 0.3, 0)
	row.add_child(buttons)
	var go_button := Button.new()
	go_button.text = activity.go
	go_button.add_theme_font_size_override("font_size", FONT_SIZE - 12)
	go_button.pressed.connect(go.bind(id))
	buttons.add_child(go_button)
	go_buttons[id] = go_button
	if id == "paddle":
		fill_button = Button.new()
		fill_button.text = "Fill the pond"
		fill_button.add_theme_font_size_override("font_size", FONT_SIZE - 12)
		fill_button.pressed.connect(fill_pond)
		buttons.add_child(fill_button)
	return row

## The small read-only list shown at the start, top left under the F1 hint.
func _build_hud() -> void:
	_hud = PanelContainer.new()
	_hud.position = Vector2(16, 64)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.6)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	_hud.add_theme_stylebox_override("panel", style)
	add_child(_hud)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(box)
	var title := _hud_label("Things to do on the farm", HUD_FONT + 4)
	title.add_theme_color_override("font_color", KEY_COLOR)
	box.add_child(title)
	for activity: Dictionary in ACTIVITIES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := ActivityIcon.new(HUD_ICON_SIZE)
		icon.kind = activity.id
		row.add_child(icon)
		var words := VBoxContainer.new()
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		words.add_child(_hud_label(activity.title, HUD_FONT))
		var blurb := _hud_label(activity.blurb, HUD_FONT - 6)
		blurb.add_theme_color_override("font_color", MUTED)
		words.add_child(blurb)
		row.add_child(words)
		box.add_child(row)
		_hud_rows[activity.id] = row
	var footer := _hud_label("Press H to pick one and be taken there", HUD_FONT - 4)
	footer.add_theme_color_override("font_color", KEY_COLOR)
	box.add_child(footer)

func _hud_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 4)
	return label
