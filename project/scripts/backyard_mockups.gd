extends Node3D
## Mockups for a new outdoor space at the back of the House (D-184 to D-190).
## Press O to step to the next idea (Shift+O for the one before); a card names
## it and lists what is in it. Idea 0 is the back yard as built; every other
## idea tears out the deck and the concrete pad (house_backyard.gd's
## set_as_built) and builds its own ground, the realistic ones putting the pad
## back.
##
## The owner's brief, as it stands (D-190): practical and functional, for a
## horse farm, nothing ornamental. The hot tub stays by the 50 A plug on the
## South Wing's west wall, sunk into a deck; some ideas run a deck from the
## master-bedroom slider (the Wing's) to it. A covered place with a propane
## fire table; a table-top counter, a sink optional, and the owner's Traeger
## pellet grill. Realistic ideas come first, best fit first; a handful at the
## end are just for fun. Every tub can be got into (hot_tub_soak.gd).
##
## Everything is built in the House's frame (building_shell.gd's frame_for):
## the west wall at x = WALL (-5.67), +z south. Each idea is built the first
## time it is shown, under its own Node3D, with its own StaticBody3D; a hidden
## idea is disabled, which takes its collision out of the world.

const Shell := preload("res://scripts/building_shell.gd")
const K := preload("res://scripts/mockup_kit.gd")
const Backyard := preload("res://scripts/house_backyard.gd")

## Where the hot tub goes in most ideas: just north of the South Wing's
## north-west corner, about 4 m from the 50 A plug on the Wing's west wall.
## Right beside that wall would be under the nearest willow's crown, which
## reaches north to z 5.5 there.
const TUB := Vector2(-11.7, 3.9)
## The door from the garage to the back yard, on the garage's south wall,
## and the patch of ground outside it every idea keeps clear.
const GARAGE_DOOR := Vector2(-6.62, -7.17)
const DOOR_CLEAR := Rect2(-7.2, -7.1, 1.2, 1.3)
## The glass sliders' sills (D-170): every idea gives each a landing this high.
const SILL := 0.36

const IDEAS := [
	{"name": "As built", "tier": "today",
		"notes": ["The deck and concrete pad as they are now"]},
	{"name": "Master Deck to the Tub", "tier": "realistic", "build": "_master_deck_pavilion",
		"notes": ["A deck from the master-bedroom slider straight to the tub, all one level",
			"The tub by the 50 A plug, sunk into the deck",
			"Keep the concrete pad; more concrete out west under a pavilion with a galvanised roof",
			"Under it: a counter with a sink, the Traeger, and a propane fire table with chairs"]},
	{"name": "Master Deck, Covered Tub", "tier": "realistic", "build": "_master_deck_covered_tub",
		"notes": ["A deck from the master-bedroom slider to the tub, and a roof over the tub for snow and sun",
			"A lean-to off the house over the pad by the kitchen slider",
			"Under it: the fire table, a counter with a sink against the wall, the Traeger"]},
	{"name": "One Deck for Both Doors", "tier": "realistic", "build": "_one_deck_both_doors",
		"notes": ["One deck from the kitchen slider along the house to the master-bedroom slider and the tub",
			"A metal roof over its north end: the fire table, a counter with a sink, the Traeger",
			"The concrete pad kept by the garage"]},
	{"name": "Master Deck and a Sauna Pad", "tier": "realistic", "build": "_master_deck_sauna_pad",
		"notes": ["The master-bedroom deck to the tub, and the galvanised-roof pavilion with the counter, sink, Traeger and fire table",
			"Room for a sauna: a gravel pad west of the tub, with a power stub"]},
	{"name": "Master Deck and Barrel Sauna", "tier": "realistic", "build": "_master_deck_barrel_sauna",
		"notes": ["The master-bedroom deck runs past the tub to a cedar barrel sauna",
			"A stock-tank cold plunge and a shower beside it",
			"The pavilion with the counter, sink, Traeger and fire table"]},
	{"name": "Master Deck and Sauna Cabin", "tier": "realistic", "build": "_master_deck_sauna_cabin",
		"notes": ["The master-bedroom deck to the tub; a small cedar sauna cabin on a slab beside it, with a shower",
			"The pavilion with the counter, sink, Traeger and fire table"]},
	{"name": "Screened Porch for Fly Season", "tier": "realistic", "build": "_screened_porch_fly_season",
		"notes": ["A screened room off the kitchen slider with the fire table: no flies or mosquitoes",
			"The counter with a sink and the Traeger just outside it",
			"The master-bedroom deck to the tub"]},
	{"name": "Master Deck with Privacy Screens", "tier": "realistic", "build": "_master_deck_privacy",
		"notes": ["The master-bedroom deck to the tub, with plain cedar screens on the tub's west and south",
			"The pavilion with the counter, sink, Traeger and fire table"]},
	{"name": "Pad and Pole-Barn Pavilion", "tier": "realistic", "build": "_pad_pole_barn",
		"notes": ["Keep the pad; a pole-barn pavilion like the farm's own, red posts and a galvanised roof",
			"Inside: the counter with a sink, the Traeger, a table and the fire table",
			"The tub on its own deck by the plug, steps up"]},
	{"name": "Gravel and Steel Canopy", "tier": "realistic", "build": "_gravel_steel_canopy",
		"notes": ["The cheapest: gravel out from the pad and a steel carport canopy",
			"Under it: a counter, the Traeger and the fire table",
			"The tub on its own deck by the plug, steps up"]},
	{"name": "Ranch Corral", "tier": "fun", "build": "_ranch_corral",
		"notes": ["A split-rail corral with a red loafing shed and hay bales round the fire",
			"A canvas-topped chuckwagon",
			"Tub deck by the plug"]},
	{"name": "Treehouse Lounge", "tier": "fun", "build": "_treehouse",
		"notes": ["A lounge platform 2.6 m up among the willows, with a fire table",
			"A barrel sauna on the lawn; tub deck by the plug"]},
	{"name": "Outdoor Cinema", "tier": "fun", "build": "_outdoor_cinema",
		"notes": ["A big screen on the lawn, bean bags and a long fire table",
			"A snack bar with a popcorn cart; watch from the tub"]},
	{"name": "Viking Longhouse", "tier": "fun", "build": "_viking_longhouse",
		"notes": ["A turf-roofed longhouse with dragon heads and a long stone hearth",
			"A turf-roofed sauna"]},
	{"name": "Thermae Salicis (Willow Baths)", "tier": "fun", "build": "_thermae",
		"notes": ["A Roman bathhouse: the hot tub is the caldarium, on a marble deck",
			"A 16 m pool in a colonnade, with the giant rubber duck",
			"A domed sauna, a volcano that is a fire table, amphorae and a hot-air balloon"]},
]

var current := 0
var _built := {}
var _card: CanvasLayer
var _title: Label
var _notes: Label
var _hide_at := 0.0
var _hint: CanvasLayer
var _hint_label: Label
## Where the "press O" hint shows, in the House's frame (x, z): the deck,
## the pad and the lawn behind the House out to about 14 m.
const HINT_AREA := Rect2(-20.0, -9.0, 15.0, 18.0)
var _wall := -5.67

func _ready() -> void:
	add_to_group("backyard_mockups")
	var house := get_node_or_null("../House") as Node3D
	if house == null:
		push_warning("backyard_mockups: no House under Buildings")
		return
	global_transform = Shell.frame_for(house)
	_wall = -house.global_transform.basis.x.length() / 2.0
	_build_card()
	_build_hint()

func idea_count() -> int:
	return IDEAS.size()

func idea_name(i: int) -> String:
	return IDEAS[i].name

## Show idea `i` (0 = as built): hide the others, build it the first time.
func show_idea(i: int) -> void:
	current = posmod(i, IDEAS.size())
	var yard := get_node_or_null("../HouseBackyard")
	if yard and yard.has_method("set_as_built"):
		yard.set_as_built(current == 0)
	for key in _built:
		var holder: Node3D = _built[key]
		var on: bool = key == current
		holder.visible = on
		holder.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	if current != 0 and not _built.has(current):
		_built[current] = _build(current)
	_show_card()

## The holder of idea `i`, built if need be (for tests).
func built_idea(i: int) -> Node3D:
	if not _built.has(i):
		show_idea(i)
	return _built.get(i)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cycle_backyard") and not event.is_echo() and not someone_in_a_tub():
		var shift := event is InputEventKey and (event as InputEventKey).shift_pressed
		show_idea(current + (-1 if shift else 1))
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if _card and _card.visible and Time.get_ticks_msec() / 1000.0 > _hide_at:
		_card.visible = false
	if _hint:
		var cam := get_viewport().get_camera_3d()
		var near := cam != null and in_hint_area(to_local(cam.global_position))
		_hint.visible = near and not _card.visible and not someone_in_a_tub()
		if _hint.visible:
			_hint_label.text = hint_text()

## Whether anyone is sitting in a hot tub (hot_tub_soak.gd), when the card
## and the hint keep out of the way.
func someone_in_a_tub() -> bool:
	for soak in get_tree().get_nodes_in_group("hot_tub_soak"):
		if soak.driver != null:
			return true
	return false

## Whether a point in this frame is in the back yard, low enough to be
## standing (or driving) there rather than flying over, and not below the
## ground in the bomb shelter that runs under it (bunker.gd, D-186).
static func in_hint_area(p: Vector3) -> bool:
	return HINT_AREA.has_point(Vector2(p.x, p.z)) and p.y < 6.0 and p.y > -1.0

## The hint's words: an invitation as built, else the idea showing.
func hint_text() -> String:
	if current == 0:
		return "O  —  See %d ideas for this back yard" % (IDEAS.size() - 1)
	return "Back yard idea %d of %d: %s   ·   O next   ·   Shift+O back" % [current, IDEAS.size() - 1, IDEAS[current].name]

func _build_hint() -> void:
	_hint = CanvasLayer.new()
	_hint.name = "MockupHint"
	_hint.layer = 5
	_hint.visible = false
	add_child(_hint)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", preload("res://scripts/hud_style.gd").backing(14.0, 6.0))
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_bottom = -90
	_hint.add_child(panel)
	_hint_label = Label.new()
	_hint_label.add_theme_font_size_override("font_size", 24)
	_hint_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.55))
	panel.add_child(_hint_label)

func hint_visible() -> bool:
	return _hint != null and _hint.visible

# --- the card ----------------------------------------------------------------

func _build_card() -> void:
	_card = CanvasLayer.new()
	_card.name = "MockupCard"
	_card.layer = 5
	_card.visible = false
	add_child(_card)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", preload("res://scripts/hud_style.gd").panel(16.0, 0.72))
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_bottom = -24
	_card.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 30)
	_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.55))
	box.add_child(_title)
	_notes = Label.new()
	_notes.add_theme_font_size_override("font_size", 20)
	box.add_child(_notes)

func _show_card() -> void:
	if _card == null:
		return
	var idea: Dictionary = IDEAS[current]
	_title.text = ("Back yard idea %d of %d: %s%s" % [current, IDEAS.size() - 1, idea.name, " (just for fun)" if idea.tier == "fun" else ""]) if current > 0 \
			else "Back yard as built (ideas: %d)" % (IDEAS.size() - 1)
	var lines := []
	for n in idea.notes:
		lines.append("•  " + n)
	lines.append("O next idea   ·   Shift+O previous   ·   Map: Back Yard to look")
	_notes.text = "\n".join(lines)
	_card.visible = true
	_hide_at = Time.get_ticks_msec() / 1000.0 + 12.0

func card_text() -> String:
	return _title.text + "\n" + _notes.text if _title else ""

# --- building ----------------------------------------------------------------

func _build(i: int) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Idea%d" % i
	add_child(holder)
	var body := StaticBody3D.new()
	body.name = "Body"
	holder.add_child(body)
	if IDEAS[i].has("build"):
		call(IDEAS[i].build, holder, body)
	return holder

## A Node3D under `parent` raised to `y` (for things standing on a deck).
func _raised(parent: Node3D, y: float) -> Node3D:
	var n := Node3D.new()
	n.position.y = y
	parent.add_child(n)
	return n

## Stoops at the two glass sliders: the House's (west wall, centred z -0.3)
## and the Wing's (its north wall, x about -7.95 to -5.95).
func _stoops(root: Node3D, body: StaticBody3D, material: Material, house := true, wing := true) -> void:
	if house:
		K.landing(root, body, Rect2(_wall - 1.5, -2.1, 1.5, 3.6), SILL, material, ["west", "north", "south"])
	if wing:
		K.landing(root, body, Rect2(-8.5, 5.9, 2.83, 1.34), SILL, material, ["north"])

## The garage strip of concrete in front of the garage, with the AC on it.
func _garage_strip(root: Node3D, material: Material) -> void:
	K.slab(root, Rect2(-9.69, -14.9, 0.94, 7.48), 0.05, material)

## A patio from `x0` to the House's west wall, from the garage's south wall
## to the Wing, and, when `z0` is further north than the garage's south wall,
## on north beside the garage (never under it).
func _patio(root: Node3D, x0: float, z0: float, material: Material) -> void:
	K.slab(root, Rect2(x0, -7.42, _wall - x0, 14.66), 0.05, material)
	if z0 < -7.42:
		K.slab(root, Rect2(x0, z0, -8.75 - x0, -7.42 - z0), 0.05, material)

func _split_rail(root: Node3D, pts: Array) -> void:
	var wood := K.mat(Color(0.55, 0.45, 0.33), 0.95)
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var d := b - a
		var mid := (a + b) / 2.0
		for h in [0.45, 0.9]:
			K.box(root, Vector3(mid.x, h, mid.y), Vector3(d.length(), 0.09, 0.09), wood, null, atan2(-d.y, d.x))
	for p in pts:
		K.box(root, Vector3(p.x, 0.55, p.y), Vector3(0.14, 1.1, 0.14), wood)

func _ranch_corral(root: Node3D, body: StaticBody3D) -> void:
	var dirt := K.paving(Color(0.62, 0.55, 0.45), 0.2, "corral")
	_patio(root, -19.5, -7.42, dirt)
	_garage_strip(root, dirt)
	_stoops(root, body, K.boards(Color(0.5, 0.42, 0.34)))
	# A split-rail corral with a gap on the house side.
	_split_rail(root, [Vector2(-10.6, -4.0), Vector2(-10.6, -7.1), Vector2(-18.8, -7.1), Vector2(-18.8, -1.0), Vector2(-10.6, -1.0), Vector2(-10.6, -2.6)])
	# A loafing shed like the farm's turn-out sheds, hay bales round the fire.
	K.pavilion(root, body, Rect2(-18.4, -6.9, 6.0, 3.2), 2.6, "shed", Color(0.55, 0.16, 0.12), Color(0.72, 0.74, 0.76), 3)
	K.fire_table(root, body, Vector2(-15.4, -5.2), Vector2(1.0, 1.0), true, 0.5, K.STONE)
	var hay := K.mat(Color(0.85, 0.72, 0.38), 1.0)
	for k in 5:
		var a := PI * 0.1 + PI * 0.8 * k / 4.0
		K.box(root, Vector3(-15.4 + cos(a) * 1.6, 0.23, -5.2 + sin(a) * 1.4), Vector3(0.9, 0.45, 0.45), hay, null, -a)
	# The chuckwagon: a canvas-topped wagon with the grill beside it.
	var wag := Vector3(-13.2, 0, -2.6)
	K.box(root, wag + Vector3(0, 0.85, 0), Vector3(2.6, 0.5, 1.2), K.mat(Color(0.45, 0.30, 0.18), 0.9), body)
	for sx in [-0.9, 0.9]:
		for sz in [-0.65, 0.65]:
			var w := K.cyl(root, wag + Vector3(sx, 0.5, sz), 0.5, 0.08, K.mat(Color(0.3, 0.2, 0.12), 0.9), null, -1.0, 12)
			w.rotation.x = PI / 2.0
	var top := K.cyl(root, wag + Vector3(0, 1.1, 0), 0.75, 2.4, K.mat(Color(0.93, 0.9, 0.82), 0.95), null, -1.0, 16)
	top.rotation.z = PI / 2.0
	K.kitchen(root, body, Vector2(-17.6, -2.4), Vector2(1, 0), Vector2(0, -1), 2.4, ["grill", "counter", "sink"])
	K.tub_on_deck(root, body, TUB, 2.3, K.boards(Color(0.5, 0.42, 0.34)), ["north"], K.STEEL)

func _treehouse(root: Node3D, body: StaticBody3D) -> void:
	var pavers := K.paving(Color(0.62, 0.58, 0.52), 0.6, "tree")
	_patio(root, -18.0, -7.42, pavers)
	_garage_strip(root, pavers)
	_stoops(root, body, K.mat(K.STONE))
	K.tub_on_deck(root, body, TUB, 2.3, K.boards(K.CEDAR), ["north", "west"], K.CEDAR_DARK)
	# A lounge platform 2.6 m up among the willows, reached by a stair.
	var top := 2.6
	var deck := Rect2(-22.5, 6.5, 5.0, 5.0)
	var c := deck.get_center()
	for x in [deck.position.x + 0.2, deck.end.x - 0.2]:
		for z in [deck.position.y + 0.2, deck.end.y - 0.2]:
			K.box(root, Vector3(x, top / 2.0, z), Vector3(0.3, top, 0.3), K.mat(K.CEDAR_DARK), body)
	K.box(root, Vector3(c.x, top - 0.1, c.y), Vector3(deck.size.x, 0.2, deck.size.y), K.boards(K.CEDAR), body)
	var gap := Rect2(-21.0, deck.position.y, 1.2, 0.1)
	for side in [[Vector3(c.x, top + 0.5, deck.end.y), Vector3(deck.size.x, 1.0, 0.08)],
			[Vector3(deck.position.x, top + 0.5, c.y), Vector3(0.08, 1.0, deck.size.y)],
			[Vector3(deck.end.x, top + 0.5, c.y), Vector3(0.08, 1.0, deck.size.y)],
			[Vector3((deck.position.x + gap.position.x) / 2.0, top + 0.5, deck.position.y), Vector3(gap.position.x - deck.position.x, 1.0, 0.08)],
			[Vector3((gap.end.x + deck.end.x) / 2.0, top + 0.5, deck.position.y), Vector3(deck.end.x - gap.end.x, 1.0, 0.08)]]:
		K.box(root, side[0], side[1], K.mat(K.CEDAR, 0.8), body)
	# The stair: treads to look at, a ramp hull to walk on.
	var run := 5.4
	for k in 15:
		var t := float(k + 1) / 16.0
		K.box(root, Vector3(gap.get_center().x, top * t - 0.04, deck.position.y - run * (1.0 - t)), Vector3(1.2, 0.08, 0.34), K.mat(K.CEDAR, 0.8))
	var ramp := ConvexPolygonShape3D.new()
	ramp.points = PackedVector3Array([
		Vector3(gap.position.x, 0, deck.position.y - run), Vector3(gap.end.x, 0, deck.position.y - run),
		Vector3(gap.position.x, top, deck.position.y), Vector3(gap.end.x, top, deck.position.y),
		Vector3(gap.position.x, 0, deck.position.y), Vector3(gap.end.x, 0, deck.position.y)])
	var cs := CollisionShape3D.new()
	cs.shape = ramp
	body.add_child(cs)
	var up := _raised(root, top)
	K.pavilion(up, body, Rect2(deck.position.x + 0.3, deck.position.y + 0.9, deck.size.x - 0.6, deck.size.y - 1.2), 2.3, "gable", K.CEDAR_DARK, Color(0.3, 0.4, 0.3), 2)
	K.fire_table(up, body, c + Vector2(0, 0.4), Vector2(0.9, 0.9), true, 0.45)
	K.sofa(up, c + Vector2(0, 1.7), Vector2(0, -1), 2.2)
	K.chair(up, c + Vector2(-1.4, 0.2), Vector2(1, 0))
	K.chair(up, c + Vector2(1.4, 0.2), Vector2(-1, 0))
	K.string_lights(up, body, [Vector2(deck.position.x, deck.position.y), Vector2(deck.end.x, deck.position.y)], 2.4, false)
	# Below: the kitchen on the patio and a barrel sauna on the lawn.
	K.kitchen(root, body, Vector2(-17.6, -6.8), Vector2(1, 0), Vector2(0, 1), 3.6, ["grill", "smoker", "sink", "fridge"])
	K.barrel_sauna(root, body, Vector2(-26.5, 3.0), 0.0, 2.6)

func _outdoor_cinema(root: Node3D, body: StaticBody3D) -> void:
	_garage_strip(root, K.mat(K.CONCRETE))
	_stoops(root, body, K.mat(K.STONE))
	K.slab(root, Rect2(-27.0, -5.0, 13.0, 8.0), 0.04, K.paving(Color(0.40, 0.42, 0.40), 0.9, "cinema"))
	# A big screen at the west end, facing the house.
	for z in [-4.4, 2.4]:
		K.box(root, Vector3(-30.0, 2.4, z), Vector3(0.2, 4.8, 0.2), K.mat(K.CHARCOAL), body)
	K.box(root, Vector3(-30.0, 2.8, -1.0), Vector3(0.05, 3.4, 6.4), K.mat(Color(0.97, 0.97, 0.96), 0.9))
	K.box(root, Vector3(-30.0, 4.6, -1.0), Vector3(0.15, 0.2, 7.0), K.mat(K.CHARCOAL))
	# Two rows of loungers, the back row on a riser, a long fire table in front.
	K.landing(root, body, Rect2(-20.6, -4.6, 2.6, 7.2), 0.4, K.boards(K.CHARCOAL), ["west", "east"])
	var bags := [Color(0.8, 0.2, 0.2), Color(0.2, 0.4, 0.75), Color(0.95, 0.75, 0.2), Color(0.45, 0.32, 0.2)]
	for k in 4:
		K.ball(root, Vector3(-24.0, 0.35, -3.6 + k * 1.8), 0.6, K.mat(bags[k], 0.9), 0.6)
		K.ball(_raised(root, 0.4), Vector3(-19.4, 0.35, -3.6 + k * 1.8), 0.6, K.mat(bags[3 - k], 0.9), 0.6)
	K.fire_table(root, body, Vector2(-25.6, -1.0), Vector2(0.6, 4.0), false, 0.35, K.CHARCOAL)
	# The snack bar: a flat-roofed pavilion with the kitchen and a popcorn cart.
	K.pavilion(root, body, Rect2(-16.0, -7.2, 5.4, 3.6), 2.7, "flat", K.CHARCOAL, Color(0.65, 0.12, 0.12), 3)
	K.kitchen(root, body, Vector2(-15.7, -6.5), Vector2(1, 0), Vector2(0, 1), 4.0, ["fridge", "pizza", "grill", "sink"])
	K.box(root, Vector3(-12.0, 0.5, -4.4), Vector3(0.8, 1.0, 0.6), K.mat(Color(0.8, 0.12, 0.12), 0.5), body)
	K.box(root, Vector3(-12.0, 1.3, -4.4), Vector3(0.7, 0.6, 0.5), K.mat(Color(1.0, 0.95, 0.7, 0.6), 0.2, 0.0, 0.5))
	K.label(root, Vector3(-13.3, 3.2, -3.5), "NOW SHOWING", 64, Color(1.0, 0.85, 0.4))
	K.string_lights(root, body, [Vector2(-29.6, 3.0), Vector2(-17.0, 3.0)], 3.2)
	K.tub_on_deck(root, body, TUB, 2.3, K.boards(K.CEDAR), ["north"], K.CEDAR_DARK)

func _viking_longhouse(root: Node3D, body: StaticBody3D) -> void:
	var stone := K.paving(Color(0.48, 0.47, 0.44), 0.7, "viking")
	_patio(root, -25.0, -7.42, stone)
	_garage_strip(root, stone)
	_stoops(root, body, K.mat(K.STONE))
	var timber := K.mat(Color(0.35, 0.24, 0.15), 0.95)
	var turf := K.mat(Color(0.32, 0.38, 0.2), 1.0)
	# An open-sided longhouse: carved posts, a steep turf roof, dragon heads.
	var h := Rect2(-24.0, -7.0, 10.0, 5.0)
	var c := h.get_center()
	K.mark(root, Vector3(c.x, 0, c.y), "cover")
	for i in 5:
		var x := h.position.x + 0.2 + i * (h.size.x - 0.4) / 4.0
		for z in [h.position.y + 0.2, h.end.y - 0.2]:
			K.cyl(root, Vector3(x, 1.2, z), 0.16, 2.4, timber, body, -1.0, 8)
			K.cyl(root, Vector3(x, 1.0, z), 0.4, 0.06, K.mat([Color(0.7, 0.15, 0.12), Color(0.15, 0.3, 0.6), Color(0.85, 0.7, 0.2)][i % 3], 0.6), null, -1.0, 16).rotation.x = PI / 2.0
	var rise := 3.2
	for sz in [-1.0, 1.0]:
		var half := h.size.y / 2.0 + 0.6
		var roof := K.box(root, Vector3(c.x, 2.4 + rise / 2.0, c.y + sz * half / 2.0), Vector3(h.size.x + 0.8, 0.3, sqrt(half * half + rise * rise)), turf)
		roof.rotation.x = sz * atan2(rise, half)
	for ex in [-1.0, 1.0]:
		var e := Vector3(c.x + ex * (h.size.x / 2.0 + 0.5), 2.4 + rise, c.y)
		for k in 4:
			K.box(root, e + Vector3(ex * k * 0.25, k * 0.25, 0), Vector3(0.3, 0.3, 0.25), timber)
		K.ball(root, e + Vector3(ex * 1.1, 1.05, 0), 0.25, timber, 1.0)
	# The long hearth down the middle, benches either side.
	K.box(root, Vector3(c.x, 0.2, c.y), Vector3(4.4, 0.4, 0.9), K.mat(K.STONE, 0.95), body)
	K.flames(root, Vector3(c.x, 0.4, c.y), 1.8, 9, 0.5)
	K.mark(root, Vector3(c.x, 0, c.y), "fire_table")
	for z in [c.y - 1.5, c.y + 1.5]:
		K.box(root, Vector3(c.x, 0.23, z), Vector3(6.0, 0.08, 0.45), timber)
		K.box(root, Vector3(c.x, 0.1, z), Vector3(5.6, 0.2, 0.2), timber)
	K.kitchen(root, body, Vector2(-13.4, -6.6), Vector2(1, 0), Vector2(0, 1), 3.0, ["grill", "smoker", "counter"], K.STONE)
	# A turf-roofed sauna, the Norse way.
	K.cabin_sauna(root, body, Rect2(-23.6, 0.6, 3.2, 3.0), 2.2)
	K.box(root, Vector3(-22.0, 2.55, 2.1), Vector3(3.8, 0.25, 3.8), turf)
	K.tub_on_deck(root, body, TUB, 2.3, K.boards(Color(0.4, 0.28, 0.18)), ["north", "west"], Color(0.4, 0.28, 0.18))

func _thermae(root: Node3D, body: StaticBody3D) -> void:
	var marble := K.paving(Color(0.90, 0.88, 0.84), 1.2, "marble")
	K.slab(root, Rect2(-40.0, -5.0, _wall + 40.0, 12.24), 0.05, marble)
	K.slab(root, Rect2(-25.0, -10.6, 16.25, 5.6), 0.05, marble)
	K.slab(root, Rect2(-44.0, 7.24, 25.6, 11.0), 0.05, marble)
	_garage_strip(root, marble)
	_stoops(root, body, K.mat(K.WHITE))
	var white := K.mat(Color(0.95, 0.94, 0.90), 0.6)
	# The caldarium: the hot tub on a marble deck under a ring of columns.
	K.tub_on_deck(root, body, TUB, 2.6, K.mat(Color(0.92, 0.9, 0.86), 0.5), ["north", "west"], Color(0.92, 0.9, 0.86), 1.0)
	# The frigidarium: a big raised pool in a colonnade.
	var pool := Rect2(-40.0, 2.0, 16.0, 13.0)
	for side in [[Vector3(pool.get_center().x, 0.45, pool.position.y), Vector3(pool.size.x, 0.9, 0.5)],
			[Vector3(pool.get_center().x, 0.45, pool.end.y), Vector3(pool.size.x, 0.9, 0.5)],
			[Vector3(pool.position.x, 0.45, pool.get_center().y), Vector3(0.5, 0.9, pool.size.y)],
			[Vector3(pool.end.x, 0.45, pool.get_center().y), Vector3(0.5, 0.9, pool.size.y)]]:
		K.box(root, side[0], side[1], white, body)
	K.box(root, Vector3(pool.get_center().x, 0.8, pool.get_center().y), Vector3(pool.size.x - 0.5, 0.02, pool.size.y - 0.5), K.mat(Color(0.25, 0.65, 0.85, 0.75), 0.05, 0.1, 0.3))
	for i in 9:
		for z in [pool.position.y - 1.2, pool.end.y + 1.2]:
			K.cyl(root, Vector3(pool.position.x + i * 2.0, 2.2, z), 0.3, 4.4, white, body, -1.0, 12)
	for z in [pool.position.y - 1.2, pool.end.y + 1.2]:
		K.box(root, Vector3(pool.get_center().x, 4.6, z), Vector3(pool.size.x + 1.0, 0.5, 1.0), white)
	K.mark(root, Vector3(pool.get_center().x, 0, pool.position.y - 1.2), "cover")
	K.label(root, Vector3(pool.get_center().x, 5.6, pool.position.y - 1.75), "THERMAE SALICIS", 120, Color(0.85, 0.7, 0.3))
	# A giant rubber duck in the frigidarium, for continuity.
	var duck := K.mat(Color(1.0, 0.85, 0.1), 0.4)
	K.ball(root, Vector3(-30.0, 1.4, 8.5), 1.3, duck, 0.8)
	K.ball(root, Vector3(-29.0, 2.7, 8.5), 0.75, duck)
	K.box(root, Vector3(-28.2, 2.6, 8.5), Vector3(0.5, 0.2, 0.4), K.mat(Color(1.0, 0.5, 0.1), 0.4))
	# The laconicum: a domed sauna.
	K.cyl(root, Vector3(-20.8, 1.2, 11.5), 2.2, 2.4, white, body, -1.0, 16)
	K.ball(root, Vector3(-20.8, 2.4, 11.5), 2.2, white, 0.9)
	K.mark(root, Vector3(-20.8, 0, 11.5), "sauna")
	K.cyl(root, Vector3(-20.8, 4.6, 11.5), 0.15, 1.0, K.mat(K.STEEL, 0.4, 0.7))
	# A volcano that is a fire table.
	K.cyl(root, Vector3(-33.0, 1.4, -2.2), 2.8, 2.8, K.mat(Color(0.30, 0.22, 0.20), 0.95), body, 0.9, 16)
	K.flames(root, Vector3(-33.0, 2.8, -2.2), 0.6, 7, 1.0)
	K.mark(root, Vector3(-33.0, 0, -2.2), "fire_table")
	for k in 8:
		var a := PI * 1.05 + PI * 0.9 * k / 7.0
		K.chair(root, Vector2(-33.0 + cos(a) * 4.2, -2.2 + sin(a) * 4.2), Vector2(-cos(a), -sin(a)), Color(0.55, 0.15, 0.15))
	# The culina: a twelve-metre kitchen under a pergola.
	K.kitchen(root, body, Vector2(-24.5, -9.0), Vector2(1, 0), Vector2(0, 1), 12.0,
			["grill", "grill", "grill", "pizza", "pizza", "smoker", "flat_top", "sink", "sink", "fridge", "fridge", "burner"])
	K.pavilion(root, body, Rect2(-24.6, -10.2, 12.6, 3.4), 3.0, "flat", Color(0.95, 0.94, 0.90), Color(0.65, 0.3, 0.2), 6)
	# Amphorae and statues on plinths.
	for p in [Vector2(-42.0, 0.5), Vector2(-42.0, 16.5), Vector2(-22.0, 16.5)]:
		K.box(root, Vector3(p.x, 0.5, p.y), Vector3(0.9, 1.0, 0.9), white, body)
		K.cyl(root, Vector3(p.x, 1.6, p.y), 0.35, 1.2, white)
		K.ball(root, Vector3(p.x, 2.45, p.y), 0.25, white)
	for p in [Vector2(-25.0, 0.0), Vector2(-14.0, -1.5)]:
		K.ball(root, Vector3(p.x, 0.6, p.y), 0.45, K.mat(Color(0.75, 0.45, 0.3), 0.9), 1.4)
	# A tethered hot-air balloon, because the guests expect it.
	K.ball(root, Vector3(-36.0, 14.0, 16.0), 3.5, K.mat(Color(0.85, 0.2, 0.25), 0.7), 1.2)
	K.box(root, Vector3(-36.0, 9.0, 16.0), Vector3(1.2, 1.0, 1.2), K.mat(Color(0.55, 0.4, 0.25), 0.9))
	K.cyl(root, Vector3(-36.0, 4.2, 16.0), 0.02, 8.6, K.mat(K.CHARCOAL))

# --- the realistic ideas -----------------------------------------------------
#
# Every one keeps the tub where the 50 A plug can reach it (TUB), sunk in a
# deck; a covered place with a propane fire table; a table-top counter (some
# with a sink) and the owner's Traeger standing beside it. Plain, practical
# materials; nothing ornamental.

## The concrete pad that is there now (house_backyard.gd's pad_rects), kept:
## along the back of the House, and the strip in front of the garage (drawn
## to the garage's leaning wall rather than under it).
func _existing_pad(root: Node3D) -> void:
	var concrete := K.paving(K.CONCRETE, 1.2, "existing_pad")
	K.slab(root, Backyard.pad_rects(_wall)[0], 0.05, concrete)
	_garage_strip(root, concrete)

## More concrete west of the pad, from the garage's line to `z1`, out to `x0`.
func _pad_extension(root: Node3D, x0: float, z1: float, material: Material = null) -> void:
	K.slab(root, Rect2(x0, -7.42, -9.69 - x0, z1 + 7.42), 0.05, material if material else K.paving(K.CONCRETE, 1.2, "extension"))

## A landing at the kitchen slider (the House's west wall), with steps west
## and north; no steps south, where a master deck may start.
func _kitchen_stoop(root: Node3D, body: StaticBody3D, material: Material) -> void:
	K.landing(root, body, Rect2(_wall - 1.5, -2.1, 1.5, 3.6), SILL, material, ["west", "north"])

## The master-bedroom deck: from the South Wing's slider (the master bedroom)
## west to the tub, at the sill's height, with the tub sunk into its west end
## so it is one level walk from the bedroom door into the water.
func _master_deck(root: Node3D, body: StaticBody3D, deck: Material, tub_sides := ["north", "west"], cabinet := K.CEDAR_DARK) -> void:
	var r := Rect2(-9.6, 3.0, _wall + 9.6, 4.24)
	K.landing(root, body, r, SILL, deck, ["north"])
	K.tub_on_deck(root, body, TUB, 2.3, deck, tub_sides, cabinet, 1.0, SILL)
	K.mark(root, Vector3(r.get_center().x, SILL, r.get_center().y), "master_deck", {"rect": r.merge(Rect2(TUB.x - 2.15, TUB.y - 2.15, 4.3, 4.3))})

## A pavilion over `pav` holding the cooking and the fire: a table-top counter
## along its back (with a sink when `sink`), the Traeger at the counter's end,
## and a propane fire table with chairs in front.
func _cook_and_fire(root: Node3D, body: StaticBody3D, pav: Rect2, roof := "shed", roof_color := Color(0.72, 0.74, 0.76), post := K.CEDAR, sink := true, posts := 2) -> void:
	K.pavilion(root, body, pav, 2.7, roof, post, roof_color, posts)
	var items := ["counter", "sink", "counter"] if sink else ["counter", "counter"]
	K.kitchen(root, body, Vector2(pav.position.x + 0.3, pav.position.y + 0.7), Vector2(1, 0), Vector2(0, 1), 2.4, items, K.CEDAR_DARK, Color(0.55, 0.54, 0.52))
	K.traeger(root, body, Vector2(pav.position.x + 3.65, pav.position.y + 0.6), Vector2(0, 1))
	var c := Vector2(pav.get_center().x, pav.position.y + 2.7)
	K.fire_table(root, body, c, Vector2(1.3, 0.8), false, 0.6, K.CONCRETE)
	for p in [[c + Vector2(-1.4, 0), Vector2(1, 0)], [c + Vector2(1.4, 0), Vector2(-1, 0)], [c + Vector2(0, 1.25), Vector2(0, -1)]]:
		K.chair(root, p[0], p[1])

const GALVANISED := Color(0.72, 0.74, 0.76)

func _master_deck_pavilion(root: Node3D, body: StaticBody3D) -> void:
	_existing_pad(root)
	_pad_extension(root, -15.4, -1.4)
	_kitchen_stoop(root, body, K.mat(K.CONCRETE))
	_master_deck(root, body, K.boards(K.CEDAR))
	_cook_and_fire(root, body, Rect2(-15.0, -7.0, 5.0, 4.4))

func _master_deck_covered_tub(root: Node3D, body: StaticBody3D) -> void:
	_existing_pad(root)
	_kitchen_stoop(root, body, K.mat(K.CONCRETE))
	_master_deck(root, body, K.boards(K.CEDAR))
	# A gable roof over the tub, for snow and summer sun.
	# Its south posts stand past the deck so the walk from the bedroom door
	# to the water is clear.
	K.pavilion(root, body, Rect2(TUB.x - 2.1, TUB.y - 2.1, 4.2, 4.8), 2.9, "gable", K.CEDAR, GALVANISED, 2)
	# A lean-to off the house over the pad by the kitchen slider: the fire
	# table, the counter against the wall and the Traeger.
	for z in [-6.8, -4.7, -2.6]:
		K.box(root, Vector3(-9.3, 1.25, z), Vector3(0.16, 2.5, 0.16), K.mat(K.CEDAR, 0.8), body)
	K.box(root, Vector3(-9.3, 2.5, -4.7), Vector3(0.18, 0.2, 4.6), K.mat(K.CEDAR, 0.8))
	var roof := K.box(root, Vector3(-7.55, 2.68, -4.7), Vector3(3.7, 0.08, 5.0), K.mat(GALVANISED, 0.5, 0.5))
	roof.rotation.z = -0.07
	K.mark(root, Vector3(-7.5, 0, -4.7), "cover")
	K.fire_table(root, body, Vector2(-8.3, -4.1), Vector2(1.2, 0.75), false, 0.6, K.CONCRETE)
	K.chair(root, Vector2(-8.3, -2.9), Vector2(0, -1))
	K.chair(root, Vector2(-8.3, -5.3), Vector2(0, 1))
	K.kitchen(root, body, Vector2(_wall - 0.7, -5.4), Vector2(0, 1), Vector2(-1, 0), 2.0, ["counter", "sink"], K.CEDAR_DARK, Color(0.55, 0.54, 0.52))
	K.traeger(root, body, Vector2(-8.9, -6.5), Vector2(0, 1))

func _one_deck_both_doors(root: Node3D, body: StaticBody3D) -> void:
	_existing_pad(root)
	var deck := K.boards(Color(0.56, 0.45, 0.35))
	# One deck at the sill from the kitchen slider along the wall to the
	# master-bedroom slider and the tub.
	var r := Rect2(-9.6, -5.2, _wall + 9.6, 12.44)
	K.landing(root, body, r, SILL, deck, ["north", "west"])
	K.tub_on_deck(root, body, TUB, 2.3, deck, ["north", "west"], K.CEDAR_DARK, 1.0, SILL)
	K.mark(root, Vector3(r.get_center().x, SILL, r.get_center().y), "master_deck", {"rect": r.merge(Rect2(TUB.x - 2.15, TUB.y - 2.15, 4.3, 4.3))})
	var on := _raised(root, SILL)
	# A metal roof off the house over the north end of the deck.
	for z in [-5.0, -2.6]:
		K.box(on, Vector3(-9.4, 1.2, z), Vector3(0.16, 2.4, 0.16), K.mat(K.CEDAR, 0.8), body)
	var roof := K.box(on, Vector3(-7.6, 2.55, -3.8), Vector3(4.0, 0.08, 3.4), K.mat(GALVANISED, 0.5, 0.5))
	roof.rotation.z = -0.07
	K.mark(on, Vector3(-7.6, 0, -3.8), "cover")
	K.fire_table(on, body, Vector2(-8.0, -2.1), Vector2(1.2, 0.7), false, 0.6, K.CONCRETE)
	K.chair(on, Vector2(-9.1, -2.1), Vector2(1, 0))
	K.chair(on, Vector2(-6.9, -2.1), Vector2(-1, 0))
	K.kitchen(on, body, Vector2(-9.4, -5.0), Vector2(0, 1), Vector2(1, 0), 2.0, ["counter", "sink"], K.CEDAR_DARK, Color(0.55, 0.54, 0.52))
	K.traeger(on, body, Vector2(-7.4, -4.6), Vector2(-1, 0))

func _master_deck_sauna_pad(root: Node3D, body: StaticBody3D) -> void:
	_existing_pad(root)
	_pad_extension(root, -15.4, -1.4)
	_kitchen_stoop(root, body, K.mat(K.CONCRETE))
	_master_deck(root, body, K.boards(K.CEDAR))
	_cook_and_fire(root, body, Rect2(-15.0, -7.0, 5.0, 4.4))
	K.sauna_spot(root, Rect2(-18.6, 1.6, 2.8, 3.2))

func _master_deck_barrel_sauna(root: Node3D, body: StaticBody3D) -> void:
	_existing_pad(root)
	_pad_extension(root, -15.4, -1.4)
	_kitchen_stoop(root, body, K.mat(K.CONCRETE))
	var cedar := K.boards(K.CEDAR)
	_master_deck(root, body, cedar, ["north"])
	# The deck carries on west from the tub to a barrel sauna; a stock-tank
	# cold plunge and a shower on the ground beside it.
	K.landing(root, body, Rect2(-19.8, 2.0, 5.95, 4.0), SILL, cedar, ["north", "west"])
	K.barrel_sauna(_raised(root, SILL), body, Vector2(-17.6, 4.0), 0.0, 2.4)
	K.cold_plunge(root, body, Vector2(-17.2, -0.6))
	K.shower(root, body, Vector2(-15.0, -0.8))
	_cook_and_fire(root, body, Rect2(-15.0, -7.0, 5.0, 4.4))

func _master_deck_sauna_cabin(root: Node3D, body: StaticBody3D) -> void:
	_existing_pad(root)
	_pad_extension(root, -15.4, -1.4)
	_kitchen_stoop(root, body, K.mat(K.CONCRETE))
	_master_deck(root, body, K.boards(K.CEDAR), ["north"])
	K.slab(root, Rect2(-19.0, 1.2, 3.4, 4.2), 0.05, K.paving(K.CONCRETE, 1.2, "sauna_pad"))
	K.cabin_sauna(root, body, Rect2(-18.8, 1.4, 2.6, 2.8), 2.3)
	K.shower(root, body, Vector2(-15.2, 0.6))
	_cook_and_fire(root, body, Rect2(-15.0, -7.0, 5.0, 4.4))

func _screened_porch_fly_season(root: Node3D, body: StaticBody3D) -> void:
	_existing_pad(root)
	_master_deck(root, body, K.boards(K.CEDAR))
	# A screened room off the kitchen slider, for fly and mosquito season:
	# deck floor at the sill, screen walls with a door on the west, a metal
	# roof, the fire table inside.
	var room := Rect2(_wall - 4.8, -3.6, 4.8, 4.9)
	var floor_mat := K.boards(Color(0.52, 0.47, 0.42))
	K.landing(root, body, room, SILL, floor_mat, ["west"])
	var on := _raised(root, SILL)
	K.mark(on, Vector3(room.get_center().x, 0, room.get_center().y), "cover")
	var screen := K.mat(Color(0.08, 0.08, 0.09, 0.35), 0.9)
	for z in [room.position.y + 0.08, room.end.y - 0.08]:
		K.box(on, Vector3(room.get_center().x, 1.25, z), Vector3(room.size.x, 2.5, 0.04), screen, body)
	var door_c := room.get_center().y
	for seg in [[room.position.y, door_c - 0.55], [door_c + 0.55, room.end.y]]:
		K.box(on, Vector3(room.position.x + 0.08, 1.25, (seg[0] + seg[1]) / 2.0), Vector3(0.04, 2.5, seg[1] - seg[0]), screen, body)
	var roof := K.box(on, Vector3(room.get_center().x - 0.1, 2.75, room.get_center().y), Vector3(room.size.x + 0.4, 0.08, room.size.y + 0.6), K.mat(GALVANISED, 0.5, 0.5))
	roof.rotation.z = -0.07
	K.fire_table(on, body, Vector2(-8.6, -0.6), Vector2(1.2, 0.8), false, 0.6, K.CONCRETE)
	K.chair(on, Vector2(-8.6, -1.9), Vector2(0, 1))
	K.chair(on, Vector2(-8.6, 0.6), Vector2(0, -1))
	# The counter against the porch's north side, the Traeger beside it.
	K.kitchen(root, body, Vector2(-10.4, -4.3), Vector2(1, 0), Vector2(0, -1), 2.4, ["counter", "sink", "counter"], K.CEDAR_DARK, Color(0.55, 0.54, 0.52))
	K.traeger(root, body, Vector2(-7.4, -4.6), Vector2(0, -1))

func _master_deck_privacy(root: Node3D, body: StaticBody3D) -> void:
	_existing_pad(root)
	_pad_extension(root, -15.4, -1.4)
	_kitchen_stoop(root, body, K.mat(K.CONCRETE))
	_master_deck(root, body, K.boards(K.CEDAR), ["north"])
	# Plain cedar screens on the tub's west and south sides.
	K.screen(root, body, TUB + Vector2(-2.3, -2.1), TUB + Vector2(-2.3, 2.3), 2.3, K.CEDAR_DARK)
	K.screen(root, body, TUB + Vector2(-2.3, 2.3), TUB + Vector2(2.0, 2.3), 2.3, K.CEDAR_DARK)
	_cook_and_fire(root, body, Rect2(-15.0, -7.0, 5.0, 4.4))

func _pad_pole_barn(root: Node3D, body: StaticBody3D) -> void:
	_existing_pad(root)
	_pad_extension(root, -17.4, -1.6)
	_stoops(root, body, K.mat(K.CONCRETE))
	K.tub_on_deck(root, body, TUB, 2.3, K.boards(K.CEDAR), ["north", "west"], K.CEDAR_DARK)
	# A pole-barn pavilion like the farm's own: red posts, galvanised roof.
	var pav := Rect2(-17.0, -7.2, 6.4, 5.4)
	_cook_and_fire(root, body, pav, "gable", GALVANISED, Color(0.55, 0.16, 0.12), true, 3)
	K.dining(root, Vector2(pav.end.x - 1.2, pav.position.y + 1.4), 1.8)

func _gravel_steel_canopy(root: Node3D, body: StaticBody3D) -> void:
	_existing_pad(root)
	_pad_extension(root, -15.8, -1.6, K.paving(Color(0.62, 0.58, 0.52), 0.12, "gravel_ext"))
	_stoops(root, body, K.mat(K.CONCRETE))
	K.tub_on_deck(root, body, TUB, 2.3, K.boards(Color(0.55, 0.53, 0.50)), ["north", "west"])
	# A steel carport canopy over the fire and the Traeger: the cheapest roof.
	_cook_and_fire(root, body, Rect2(-15.4, -7.0, 5.4, 4.6), "flat", GALVANISED, K.CHARCOAL, false, 2)
