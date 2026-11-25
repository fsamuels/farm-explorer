extends Node3D
## Mockups for a new outdoor space at the back of the House. Press O
## to step to the next idea (Shift+O for the one before); a card names it and
## lists what is in it. Idea 0 is the back yard as built; every other idea
## tears out the deck and the concrete pad (house_backyard.gd's
## set_as_built) and builds its own ground.
##
## The owner's brief: a hot tub in every one, ideally on the right-hand (south)
## end of the back, by the South Wing's west wall where the 50 A plug is, but
## not under the willows; a covered place to hang out, probably with a propane
## fire table; an outdoor kitchen with a grill, maybe a sink and water; a sauna
## would be amazing. Most ideas are reasonable, a few extravagant, one absurdly
## over the top.
##
## Everything is built in the House's frame (building_shell.gd's frame_for):
## the west wall at x = WALL (-5.67), +z south. Each idea is built the first
## time it is shown, under its own Node3D, with its own StaticBody3D; a hidden
## idea is disabled, which takes its collision out of the world.

const Shell := preload("res://scripts/building_shell.gd")
const K := preload("res://scripts/mockup_kit.gd")

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
	{"name": "Simple Soak", "tier": "reasonable", "build": "_simple_soak",
		"notes": ["Deck out; broom-finished concrete patio and two stoops",
			"Hot tub sunk into a small cedar deck by the 50 A plug, with a privacy screen",
			"Shed-roof cedar pavilion with a propane fire table and four chairs",
			"Grill counter against the garage wall"]},
	{"name": "Pavilion and Barrel Sauna", "tier": "reasonable", "build": "_pavilion_sauna",
		"notes": ["Paver patio and a low wide landing at the slider",
			"Gable-roof pavilion: sectional, round fire table, kitchen with grill, sink and fridge",
			"Hot tub sunk into a cedar deck by the plug",
			"Cedar barrel sauna and an outdoor shower beside it"]},
	{"name": "Covered Porch", "tier": "reasonable", "build": "_covered_porch",
		"notes": ["New low composite deck along the whole back wall",
			"Porch roof off the house over a fire table, sofa and chairs",
			"Grill island with a sink on the deck",
			"Hot tub deck a step up from the porch deck, by the plug"]},
	{"name": "Screened Porch", "tier": "reasonable", "build": "_screened_porch",
		"notes": ["A screened room off the slider: bug-free evenings round a fire table",
			"Grill, counter and sink along the garage wall",
			"Hot tub sunk into a deck by the plug; paver patio between"]},
	{"name": "Wraparound Deck", "tier": "reasonable", "build": "_wraparound_deck",
		"notes": ["One deck from the garage to the Wing, with the tub deck a step up at its corner",
			"Louvred pergola over a round fire table, sofa and chairs",
			"Grill, side burner and sink on the deck"]},
	{"name": "Sauna Cabin and Patio", "tier": "reasonable", "build": "_sauna_cabin",
		"notes": ["Small cedar cabin sauna beside the tub deck, with a cold shower between",
			"Shed-roof pavilion with a fire table, sofa and chairs",
			"Grill, counter and sink against the garage wall"]},
	{"name": "Gravel and Pergola", "tier": "reasonable", "build": "_gravel_pergola",
		"notes": ["Pea-gravel patio and stepping stones to the tub deck",
			"Cedar pergola with a clear roof over a fire table and four Adirondack chairs",
			"Grill cart with a prep counter"]},
	{"name": "Kitchen by the Garage Door", "tier": "reasonable", "build": "_garage_kitchen",
		"notes": ["A gable kitchen pavilion a few steps from the garage door: fridge, sink, grill, burner",
			"Dining table under the same roof",
			"Round fire table with a sofa out on the brick patio; tub deck by the plug"]},
	{"name": "Hot Tub Gazebo", "tier": "reasonable", "build": "_tub_gazebo",
		"notes": ["The tub in a wide deck under its own cedar gazebo",
			"Shed-roof pavilion with a fire table and two sofas",
			"Grill and sink against the house wall"]},
	{"name": "Lean-To Patio", "tier": "reasonable", "build": "_lean_to",
		"notes": ["A lean-to roof off the house over the patio by the slider",
			"Fire table, sofa and chair under it; grill, sink and counter at its south end",
			"Tub deck by the plug"]},
	{"name": "Spa Deck with Sauna", "tier": "reasonable", "build": "_spa_deck_sauna",
		"notes": ["One cedar spa deck holding the tub, a barrel sauna and a shower",
			"Gable pavilion with a round fire table",
			"Grill and sink against the house wall"]},
	{"name": "Private Spa Corner", "tier": "reasonable", "build": "_spa_corner",
		"notes": ["Tub deck screened on two sides, with a shower and a bench",
			"Charcoal shed-roof pavilion with a fire table and two sofas",
			"Grill, sink and counter island"]},
	{"name": "Pizza Oven Patio", "tier": "reasonable", "build": "_pizza_patio",
		"notes": ["Terracotta pavers; a gable pavilion over a pizza oven, grill, sink and a dining table",
			"Round fire table with four chairs under bistro lights",
			"Tub deck by the plug"]},
	{"name": "Patio with a Sauna Pad", "tier": "reasonable", "build": "_sauna_pad_patio",
		"notes": ["Concrete patio; shed-roof pavilion with a fire table and four chairs",
			"Grill and sink against the house wall; tub deck by the plug",
			"Room for a sauna: a gravel pad west of the tub, with a power stub"]},
	{"name": "Boardwalk to a Sauna Deck", "tier": "reasonable", "build": "_boardwalk_sauna",
		"notes": ["The tub deck carries on west as a boardwalk to an empty deck",
			"Gable pavilion with a round fire table and sofa; grill and sink on the house wall",
			"Room for a sauna: the empty deck at the end of the boardwalk"]},
	{"name": "Pergola Row", "tier": "reasonable", "build": "_pergola_row",
		"notes": ["A row along the patio: a clear-roofed pergola over the fire table, an open one over the kitchen",
			"Grill, counter and sink; tub deck by the plug",
			"Room for a sauna: the last spot in the row, past the kitchen"]},
	{"name": "Garden Corner", "tier": "reasonable", "build": "_garden_corner",
		"notes": ["Pavers and raised planting beds; a cedar pavilion with a fire table and two sofas",
			"Grill and sink against the house wall; tub deck by the plug",
			"Room for a sauna: the quiet north-west corner of the patio"]},
	{"name": "Gazebo Fire Circle", "tier": "reasonable", "build": "_gazebo_firepit",
		"notes": ["A gravel yard with an octagonal gazebo round a fire table and five chairs",
			"Grill counter near the garage (the door stays clear); tub deck by the plug",
			"Room for a sauna: a gravel pad west of the tub"]},
	{"name": "L-Shaped Patio", "tier": "reasonable", "build": "_l_patio",
		"notes": ["Pavers along the house and out west in an L",
			"A kitchen pavilion on the west arm; a fire table under a small clear roof by the house",
			"Room for a sauna: the end of the L's west arm"]},
	{"name": "Screened Spa Court", "tier": "reasonable", "build": "_screened_spa_court",
		"notes": ["A cedar-screened court west of the tub deck, with an outdoor shower",
			"Charcoal shed-roof pavilion with a fire table; grill and sink on the house wall",
			"Room for a sauna: inside the court, beside the shower"]},
	{"name": "Cold Plunge Ready", "tier": "reasonable", "build": "_plunge_ready",
		"notes": ["Tub deck, a stock-tank cold plunge and a shower already in",
			"Gable pavilion with the kitchen at its back and a fire table in front",
			"Room for a sauna: a pad beside the plunge"]},
	{"name": "One Big Pavilion", "tier": "reasonable", "build": "_big_pavilion",
		"notes": ["One roof over the whole kitchen (fridge, sink, grill, burner) and a fire table lounge",
			"Tub deck by the plug",
			"Room for a sauna: a pad between the pavilion and the willows"]},
	{"name": "Porch Swing", "tier": "reasonable", "build": "_porch_swing",
		"notes": ["A lean-to roof off the house over a fire table, chairs and a porch swing",
			"Grill, sink and counter at its south end; tub deck by the plug",
			"Room for a sauna: a gravel pad out west of the tub"]},
	{"name": "Stepping Stones", "tier": "reasonable", "build": "_stepping_stones",
		"notes": ["Mostly lawn: a small pad under a clear-roofed pergola with a fire table and a grill",
			"Stepping stones to the tub deck",
			"Room for a sauna: a gravel pad at the end of the stones"]},
	{"name": "Hearth Room", "tier": "reasonable", "build": "_hearth_room",
		"notes": ["A pavilion with a stone back wall, a long fire table and two sofas",
			"Grill, sink and counter beside it; tub deck by the plug",
			"Room for a sauna: a pad south of the pavilion, west of the tub"]},
	{"name": "Barn Pavilion", "tier": "extravagant", "build": "_barn_pavilion",
		"notes": ["A 10 m timber-frame pole barn to match the farm: red posts, galvanised roof",
			"Kitchen along its back: smoker, grill, flat-top, sink, fridge; a long farm table",
			"Fire-table lounge at one end; bistro lights across the patio",
			"Hot tub deck under a pergola; barrel sauna and a stock-tank cold plunge"]},
	{"name": "Japanese Spa Garden", "tier": "extravagant", "build": "_japanese_garden",
		"notes": ["Raked gravel, a dark-wood veranda along the house, stone lanterns, a koi pond",
			"Hot tub in a dark deck behind a bamboo screen",
			"Cedar sauna and a cold plunge",
			"Pavilion with a low fire table and floor cushions; kitchen with grill and flat-top"]},
	{"name": "Two-Level Deck", "tier": "extravagant", "build": "_two_level_deck",
		"notes": ["Upper deck at the sliders with a kitchen (pizza oven, grill, sink) and a bar",
			"Lower deck with a white octagonal gazebo round a fire table",
			"Hot tub deck off the upper level; barrel sauna on the lower one"]},
	{"name": "Modern Glass Spa", "tier": "extravagant", "build": "_glass_spa",
		"notes": ["Glass-walled sauna and a raised plunge pool",
			"Hot tub in an ipe deck",
			"11 m flat-roof pavilion: linear fire table between two long sofas",
			"Kitchen wall with pizza oven, grill and sink; porcelain paving"]},
	{"name": "Pool and Spa", "tier": "extravagant", "build": "_pool_and_spa",
		"notes": ["An 11 m raised lap pool with four loungers",
			"Pool-house cabana: kitchen, fire table and sofa",
			"Tub deck by the plug"]},
	{"name": "Mountain Lodge", "tier": "extravagant", "build": "_mountain_lodge",
		"notes": ["Log pavilion round a six-metre stone fireplace, with a fire table and three sofas",
			"Stone kitchen with smoker and grill; flagstone patio",
			"Cedar sauna cabin with a porch and a cold plunge; log-toned tub deck"]},
	{"name": "Round Pavilion", "tier": "extravagant", "build": "_round_pavilion",
		"notes": ["An 8 m round pavilion: four sofas in a ring round a wide fire table",
			"Kitchen with grill, sink and pizza oven",
			"Barrel sauna; tub deck by the plug"]},
	{"name": "Desert Modern", "tier": "extravagant", "build": "_desert_modern",
		"notes": ["White stucco walls, sand paving, cor-ten planters with agaves",
			"Steel ramada with a long fire table between two sofas; stucco kitchen",
			"Plunge pool and sauna; ipe tub deck"]},
	{"name": "Treehouse Lounge", "tier": "extravagant", "build": "_treehouse",
		"notes": ["A lounge platform 2.6 m up among the willows: roof, fire table, sofa, lights",
			"Kitchen with grill and smoker on the patio below",
			"Barrel sauna on the lawn; tub deck by the plug"]},
	{"name": "Thermae Salicis (Willow Baths)", "tier": "absurdly over the top", "build": "_thermae",
		"notes": ["A Roman bathhouse: the hot tub is the caldarium, on a marble deck",
			"The frigidarium: a 16 m pool in a colonnade, with the giant rubber duck",
			"A domed laconicum sauna and a volcano that is a fire table",
			"A 12 m culina: three grills, two pizza ovens, a smoker",
			"Amphorae, statues and a tethered hot-air balloon"]},
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
	if event.is_action_pressed("cycle_backyard") and not event.is_echo():
		var shift := event is InputEventKey and (event as InputEventKey).shift_pressed
		show_idea(current + (-1 if shift else 1))
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if _card and _card.visible and Time.get_ticks_msec() / 1000.0 > _hide_at:
		_card.visible = false
	if _hint:
		var cam := get_viewport().get_camera_3d()
		var near := cam != null and in_hint_area(to_local(cam.global_position))
		_hint.visible = near and not _card.visible
		if _hint.visible:
			_hint_label.text = hint_text()

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
	_title.text = "Back yard idea %d of %d: %s (%s)" % [current, IDEAS.size() - 1, idea.name, idea.tier] if current > 0 \
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

# 1 ----------------------------------------------------------------------------
func _simple_soak(root: Node3D, body: StaticBody3D) -> void:
	var concrete := K.paving(K.CONCRETE, 1.2, "broom")
	K.slab(root, Rect2(-13.0, -7.42, _wall + 13.0, 14.66), 0.05, concrete)
	_garage_strip(root, concrete)
	_stoops(root, body, K.mat(K.CONCRETE))
	K.tub_on_deck(root, body, TUB, 2.3, K.boards(K.CEDAR), ["north"])
	K.screen(root, body, TUB + Vector2(-2.35, -2.15), TUB + Vector2(-2.35, 2.15), 2.4)
	K.pavilion(root, body, Rect2(-12.8, -6.9, 4.2, 4.2), 2.7, "shed", K.CEDAR, K.CHARCOAL)
	K.fire_table(root, body, Vector2(-10.7, -4.8))
	for p in [[Vector2(-10.7, -6.0), Vector2(0, 1)], [Vector2(-10.7, -3.6), Vector2(0, -1)], [Vector2(-12.0, -4.8), Vector2(1, 0)], [Vector2(-9.4, -4.8), Vector2(-1, 0)]]:
		K.chair(root, p[0], p[1])
	K.kitchen(root, body, Vector2(_wall - 0.7, -5.6), Vector2(0, 1), Vector2(-1, 0), 2.2, ["grill", "counter"])
	for p in [Vector2(-13.4, -7.0), Vector2(-14.9, 1.0), Vector2(-14.9, 6.6)]:
		K.shrub(root, p, 0.5)

# 2 ----------------------------------------------------------------------------
func _pavilion_sauna(root: Node3D, body: StaticBody3D) -> void:
	var pavers := K.paving(Color(0.70, 0.64, 0.55), 0.6)
	_patio(root, -15.5, -8.6, pavers)
	_garage_strip(root, pavers)
	var deck := K.boards(K.CEDAR)
	K.landing(root, body, Rect2(_wall - 2.4, -3.0, 2.4, 6.5), SILL, deck, ["west", "north", "south"])
	_stoops(root, body, deck, false, true)
	K.pavilion(root, body, Rect2(-15.3, -8.4, 5.4, 5.8), 2.8, "gable", K.CEDAR, K.SLATE, 3)
	K.kitchen(root, body, Vector2(-14.9, -7.5), Vector2(1, 0), Vector2(0, 1), 3.8, ["fridge", "sink", "counter", "grill"])
	K.fire_table(root, body, Vector2(-12.6, -5.3), Vector2(1.0, 1.0), true)
	K.sofa(root, Vector2(-12.6, -3.9), Vector2(0, -1), 2.6)
	K.sofa(root, Vector2(-14.5, -5.3), Vector2(1, 0), 1.8)
	K.tub_on_deck(root, body, TUB, 2.3, deck, ["north", "west"], K.CEDAR_DARK)
	K.slab(root, Rect2(-19.3, 3.3, 3.4, 3.4), 0.05, K.paving(Color(0.6, 0.58, 0.55), 0.15, "gravel"))
	K.barrel_sauna(root, body, Vector2(-17.6, 5.0), 0.0, 2.4)
	K.shower(root, body, Vector2(-16.0, 0.4))
	for p in [Vector2(-9.3, -8.0), Vector2(-15.4, -1.0)]:
		K.shrub(root, p, 0.6)

# 3 ----------------------------------------------------------------------------
func _covered_porch(root: Node3D, body: StaticBody3D) -> void:
	var deck := K.boards(Color(0.55, 0.53, 0.50))
	var r := Rect2(_wall - 4.2, -5.0, 4.2, 12.24)
	K.landing(root, body, r, SILL, deck, ["west", "north"])
	K.slab(root, Rect2(-9.69, -14.9, 0.94, 9.9), 0.05, K.mat(K.CONCRETE))
	# The porch roof: posts along the deck's outer edge, a beam, and a shed
	# roof falling from the house wall to the beam.
	var on := _raised(root, SILL)
	for z in [-4.8, -2.2, 0.4, 3.0]:
		K.box(on, Vector3(_wall - 4.0, 1.2, z), Vector3(0.16, 2.4, 0.16), K.mat(K.WHITE), body)
	K.box(on, Vector3(_wall - 4.0, 2.45, -0.9), Vector3(0.18, 0.2, 8.2), K.mat(K.WHITE))
	K.mark(on, Vector3(_wall - 2.0, 0, -0.9), "cover")
	var roof := K.box(on, Vector3(_wall - 2.25, 2.62, -0.9), Vector3(4.3, 0.08, 8.6), K.mat(K.SLATE, 0.6, 0.2))
	roof.rotation.z = -0.08
	K.fire_table(on, body, Vector2(-8.3, -1.6), Vector2(1.3, 0.8))
	K.sofa(on, Vector2(-8.3, -3.0), Vector2(0, 1), 2.2)
	K.chair(on, Vector2(-8.9, -0.3), Vector2(0, -1), K.WHITE)
	K.chair(on, Vector2(-7.7, -0.3), Vector2(0, -1), K.WHITE)
	K.kitchen(on, body, Vector2(-9.6, -4.1), Vector2(1, 0), Vector2(0, 1), 2.8, ["grill", "counter", "sink"])
	K.tub_on_deck(root, body, TUB, 2.3, deck, ["north", "west"])
	for p in [Vector2(-10.6, -5.6)]:
		K.shrub(root, p, 0.5)

# 4 ----------------------------------------------------------------------------
func _screened_porch(root: Node3D, body: StaticBody3D) -> void:
	var pavers := K.paving(Color(0.62, 0.62, 0.60), 0.6, "porch")
	K.slab(root, Rect2(-14.5, -7.42, _wall + 14.5, 14.66), 0.05, pavers)
	_garage_strip(root, pavers)
	# A screened room off the slider: a deck floor at the sill, posts, screen
	# walls (a doorway on the west), a shed roof falling away from the house.
	var room := Rect2(_wall - 4.8, -3.4, 4.8, 5.4)
	K.landing(root, body, room, SILL, K.boards(Color(0.52, 0.47, 0.42)), ["west"])
	var on := _raised(root, SILL)
	K.mark(on, Vector3(room.get_center().x, 0, room.get_center().y), "cover")
	var screen := K.mat(Color(0.08, 0.08, 0.09, 0.35), 0.9)
	var white := K.mat(K.WHITE)
	var x0 := room.position.x
	for z in [room.position.y + 0.08, room.end.y - 0.08]:
		K.box(on, Vector3(room.get_center().x, 1.25, z), Vector3(room.size.x, 2.5, 0.04), screen, body)
		K.box(on, Vector3(x0 + 0.08, 1.25, z), Vector3(0.14, 2.5, 0.14), white)
	# West wall, with a 1.1 m screen door in the middle.
	var door_c := room.get_center().y
	for seg in [[room.position.y, door_c - 0.55], [door_c + 0.55, room.end.y]]:
		var mid: float = (seg[0] + seg[1]) / 2.0
		K.box(on, Vector3(x0 + 0.08, 1.25, mid), Vector3(0.04, 2.5, seg[1] - seg[0]), screen, body)
	K.box(on, Vector3(x0 + 0.08, 2.55, door_c), Vector3(0.14, 0.12, room.size.y), white)
	var roof := K.box(on, Vector3(room.get_center().x - 0.1, 2.75, room.get_center().y), Vector3(room.size.x + 0.4, 0.08, room.size.y + 0.6), K.mat(K.SLATE, 0.6, 0.2))
	roof.rotation.z = -0.07
	K.fire_table(on, body, Vector2(-8.6, -0.3), Vector2(1.2, 0.8))
	K.sofa(on, Vector2(-8.6, -2.3), Vector2(0, 1), 2.2, K.WHITE)
	K.chair(on, Vector2(-9.2, 1.2), Vector2(0, -1), K.WHITE)
	K.chair(on, Vector2(-8.0, 1.2), Vector2(0, -1), K.WHITE)
	K.kitchen(root, body, Vector2(-10.4, -4.1), Vector2(1, 0), Vector2(0, -1), 2.8, ["grill", "counter", "sink"])
	_stoops(root, body, K.mat(K.CONCRETE), false, true)
	K.tub_on_deck(root, body, TUB, 2.3, K.boards(Color(0.52, 0.47, 0.42)), ["north", "west"])
	for p in [Vector2(-14.0, -6.8), Vector2(-14.0, 6.4)]:
		K.shrub(root, p, 0.6)

# 5 ----------------------------------------------------------------------------
func _wraparound_deck(root: Node3D, body: StaticBody3D) -> void:
	var deck := K.boards(Color(0.60, 0.45, 0.33))
	# One deck from the garage to the Wing, the tub deck a step up at its
	# south-west corner, and a louvred (slatted, covered) pergola over the
	# seating.
	K.landing(root, body, Rect2(-9.6, -5.2, _wall + 9.6, 12.44), SILL, deck, ["west", "north"])
	K.tub_on_deck(root, body, TUB, 2.3, deck, ["north", "west"], K.CEDAR_DARK)
	var on := _raised(root, SILL)
	var cover := Rect2(-9.5, -2.6, 3.4, 4.6)
	K.pavilion(on, body, cover, 2.5, "flat", K.CHARCOAL, Color(0.82, 0.82, 0.80), 2)
	for i in 12:
		K.box(on, Vector3(cover.get_center().x, 2.72, cover.position.y + 0.2 + i * 0.37), Vector3(cover.size.x, 0.04, 0.2), K.mat(K.WHITE, 0.6), null).rotation.x = 0.5
	K.fire_table(on, body, Vector2(-7.9, -0.3), Vector2(0.9, 0.9), true)
	K.sofa(on, Vector2(-9.0, -0.3), Vector2(1, 0), 2.2)
	K.chair(on, Vector2(-7.9, -1.7), Vector2(0, 1))
	K.chair(on, Vector2(-7.9, 1.1), Vector2(0, -1))
	K.kitchen(on, body, Vector2(-9.4, -4.4), Vector2(1, 0), Vector2(0, 1), 3.4, ["grill", "burner", "counter", "sink"])
	K.slab(root, Rect2(-9.69, -14.9, 0.94, 8.2), 0.05, K.mat(K.CONCRETE))
	for p in [Vector2(-11.2, -7.6), Vector2(-11.2, -1.0)]:
		K.shrub(root, p, 0.6)

# 6 ----------------------------------------------------------------------------
func _sauna_cabin(root: Node3D, body: StaticBody3D) -> void:
	var concrete := K.paving(Color(0.68, 0.67, 0.64), 0.9, "cabin")
	_patio(root, -17.5, -8.0, concrete)
	_garage_strip(root, concrete)
	_stoops(root, body, K.mat(K.CONCRETE))
	K.tub_on_deck(root, body, TUB, 2.3, K.boards(K.CEDAR), ["north", "west"], K.CEDAR_DARK)
	# The sauna beside the tub deck, its glass door facing it, with a cold
	# shower between.
	K.cabin_sauna(root, body, Rect2(-18.2, 0.4, 2.4, 2.6), 2.3)
	K.shower(root, body, Vector2(-15.0, -0.4))
	K.pavilion(root, body, Rect2(-14.6, -7.6, 4.6, 4.4), 2.7, "shed", K.CEDAR, K.CHARCOAL)
	K.fire_table(root, body, Vector2(-12.3, -5.0), Vector2(1.4, 0.8))
	K.sofa(root, Vector2(-12.3, -3.7), Vector2(0, -1), 2.2)
	K.chair(root, Vector2(-13.8, -5.0), Vector2(1, 0))
	K.chair(root, Vector2(-10.8, -5.0), Vector2(-1, 0))
	K.kitchen(root, body, Vector2(_wall - 0.7, -5.6), Vector2(0, 1), Vector2(-1, 0), 2.2, ["grill", "sink"])
	for p in [Vector2(-17.0, -7.4), Vector2(-17.0, 4.2)]:
		K.shrub(root, p, 0.6)

# 7 ----------------------------------------------------------------------------
func _barn_pavilion(root: Node3D, body: StaticBody3D) -> void:
	var pavers := K.paving(Color(0.58, 0.52, 0.46), 0.75, "barn")
	_patio(root, -22.0, -10.0, pavers)
	_garage_strip(root, pavers)
	_stoops(root, body, K.mat(K.STONE))
	# A timber-frame pole barn like the farm's own: red-stained posts, a
	# galvanised roof, a kitchen along its back, a long table and a lounge.
	var barn := Rect2(-21.5, -9.6, 10.0, 6.4)
	K.pavilion(root, body, barn, 3.2, "gable", Color(0.55, 0.16, 0.12), Color(0.72, 0.74, 0.76), 4)
	K.kitchen(root, body, Vector2(-21.0, -8.7), Vector2(1, 0), Vector2(0, 1), 5.4, ["fridge", "sink", "counter", "smoker", "grill", "flat_top"])
	K.dining(root, Vector2(-17.8, -6.0), 3.2)
	K.fire_table(root, body, Vector2(-13.6, -6.4), Vector2(1.6, 0.9), false, 0.55, K.STONE)
	K.sofa(root, Vector2(-13.6, -4.6), Vector2(0, -1), 2.4)
	K.chair(root, Vector2(-12.0, -7.6), Vector2(-0.6, 0.8))
	K.tub_on_deck(root, body, TUB, 2.3, K.boards(K.CEDAR), ["north", "west"], K.CEDAR_DARK, 1.2)
	K.pergola(root, body, Rect2(TUB.x - 2.3, TUB.y - 2.3, 4.6, 4.6), 3.2)
	K.barrel_sauna(root, body, Vector2(-18.4, 3.4), 0.0, 2.6)
	K.cold_plunge(root, body, Vector2(-16.6, -0.2))
	K.string_lights(root, body, [Vector2(-21.4, -2.8), Vector2(-14.0, 0.6), Vector2(-9.0, -2.8)], 3.2)

# 8 ----------------------------------------------------------------------------
func _japanese_garden(root: Node3D, body: StaticBody3D) -> void:
	var gravel := K.paving(Color(0.78, 0.77, 0.73), 0.12, "raked")
	_patio(root, -24.0, -10.0, gravel)
	_garage_strip(root, gravel)
	# An engawa: a long, low veranda of dark boards along the House.
	var dark := K.boards(Color(0.30, 0.22, 0.17))
	K.landing(root, body, Rect2(_wall - 2.0, -5.2, 2.0, 12.44), SILL, dark, ["west", "north"])
	K.tub_on_deck(root, body, TUB, 2.3, dark, ["north"], Color(0.55, 0.42, 0.30), 1.1)
	K.screen(root, body, Vector2(TUB.x - 2.6, TUB.y - 2.0), Vector2(TUB.x - 2.6, TUB.y + 2.5), 2.4, Color(0.42, 0.55, 0.28))
	K.cabin_sauna(root, body, Rect2(-20.0, 1.0, 3.0, 3.0), 2.4)
	K.cold_plunge(root, body, Vector2(-16.0, 1.8), 0.7)
	# A koi pond with stepping stones and lanterns.
	K.box(root, Vector3(-19.0, 0.06, -3.0), Vector3(4.4, 0.04, 3.0), K.mat(Color(0.15, 0.35, 0.40, 0.85), 0.05, 0.1))
	for p in [Vector2(-17.5, -1.2), Vector2(-16.3, -0.6), Vector2(-15.1, -0.2)]:
		K.cyl(root, Vector3(p.x, 0.06, p.y), 0.35, 0.1, K.mat(K.STONE, 0.95))
	for p in [Vector2(-21.6, -4.8), Vector2(-16.4, -4.8), Vector2(-13.2, 2.0), Vector2(-9.0, -8.2)]:
		K.lantern(root, p)
	# A pavilion with a sunken-look fire table and floor cushions round it.
	var pav := Rect2(-15.6, -9.6, 5.6, 5.0)
	K.pavilion(root, body, pav, 2.8, "gable", Color(0.25, 0.18, 0.14), Color(0.18, 0.18, 0.2), 3)
	K.box(root, Vector3(pav.get_center().x, 0.1, pav.get_center().y), Vector3(pav.size.x - 0.4, 0.2, pav.size.y - 0.4), dark)
	K.fire_table(root, body, pav.get_center(), Vector2(1.6, 0.8), false, 0.45, K.SLATE)
	for d in [Vector2(0, 1), Vector2(0, -1), Vector2(1, 0), Vector2(-1, 0)]:
		K.box(root, Vector3(pav.get_center().x + d.x * 1.5, 0.3, pav.get_center().y + d.y * 1.2), Vector3(0.7, 0.15, 0.7), K.mat(Color(0.75, 0.3, 0.2), 0.95))
	K.kitchen(root, body, Vector2(-23.0, -9.2), Vector2(1, 0), Vector2(0, 1), 4.6, ["counter", "sink", "grill", "flat_top"])
	for z in [-7.0, 6.0]:
		for x in [-23.0, -21.5]:
			K.shrub(root, Vector2(x, z), 0.7)

# 9 ----------------------------------------------------------------------------
func _two_level_deck(root: Node3D, body: StaticBody3D) -> void:
	var upper := K.boards(Color(0.56, 0.42, 0.30))
	var lower := K.boards(Color(0.48, 0.36, 0.26))
	# Upper level at the sliders, a wide stair down to a lower level that
	# holds the tub deck, an octagonal gazebo and the sauna.
	K.landing(root, body, Rect2(-10.6, -5.2, _wall + 10.6, 12.44), SILL, upper, ["west", "north"])
	K.landing(root, body, Rect2(-19.4, -5.0, 8.8, 12.2), 0.2, lower, ["west", "north", "south"])
	K.tub_on_deck(root, body, TUB, 2.3, upper, ["north"], K.CHARCOAL, 1.0, 0.6)
	var on := _raised(root, SILL)
	K.kitchen(on, body, Vector2(-10.3, -4.4), Vector2(1, 0), Vector2(0, 1), 4.4, ["fridge", "sink", "counter", "grill", "pizza"])
	K.box(on, Vector3(-8.0, 0.55, -2.7), Vector3(3.2, 1.1, 0.6), K.mat(K.STONE, 0.9), body)
	for x in [-9.2, -8.4, -7.6, -6.8]:
		K.stool(on, Vector2(x, -2.0))
	var low := _raised(root, 0.2)
	K.gazebo(low, body, Vector2(-15.0, -1.2), 2.6, 2.7, K.WHITE, K.SLATE, Vector2(1, 0))
	K.fire_table(low, body, Vector2(-15.0, -1.2), Vector2(1.1, 1.1), true)
	for k in 5:
		var a := PI * 0.45 + PI * 1.1 * k / 4.0
		K.chair(low, Vector2(-15.0 + cos(a) * 1.7, -1.2 + sin(a) * 1.7), Vector2(-cos(a), -sin(a)), Color(0.2, 0.3, 0.45))
	K.barrel_sauna(low, body, Vector2(-17.0, 4.6), 0.0, 2.4)
	K.string_lights(root, body, [Vector2(-19.2, -4.8), Vector2(-19.2, 6.8)], 3.0)

# 10 ---------------------------------------------------------------------------
func _glass_spa(root: Node3D, body: StaticBody3D) -> void:
	var porcelain := K.paving(Color(0.82, 0.81, 0.78), 1.0, "porcelain")
	_patio(root, -24.0, -10.0, porcelain)
	_garage_strip(root, porcelain)
	_stoops(root, body, K.mat(Color(0.82, 0.81, 0.78)))
	var ipe := K.boards(Color(0.36, 0.22, 0.15))
	K.tub_on_deck(root, body, TUB, 2.3, ipe, ["north", "west"], K.CHARCOAL, 1.2)
	# A glass-walled sauna: a dark frame, glass all round, a flat roof.
	var sauna := Rect2(-22.5, -1.0, 3.6, 3.0)
	K.mark(root, Vector3(sauna.get_center().x, 0, sauna.get_center().y), "sauna")
	K.box(root, Vector3(sauna.get_center().x, 1.2, sauna.get_center().y), Vector3(sauna.size.x, 2.4, sauna.size.y), K.mat(Color(0.25, 0.32, 0.35, 0.45), 0.05, 0.3), body)
	K.box(root, Vector3(sauna.get_center().x, 1.0, sauna.position.y + 0.3), Vector3(sauna.size.x - 0.3, 0.45, 0.5), K.mat(K.CEDAR))
	K.box(root, Vector3(sauna.get_center().x, 2.5, sauna.get_center().y), Vector3(sauna.size.x + 0.3, 0.2, sauna.size.y + 0.3), K.mat(K.CHARCOAL, 0.5, 0.4))
	# A raised plunge pool beside it.
	K.box(root, Vector3(-16.9, 0.45, -1.6), Vector3(2.4, 0.9, 3.0), K.mat(K.CHARCOAL, 0.6), body)
	K.box(root, Vector3(-16.9, 0.91, -1.6), Vector3(2.1, 0.02, 2.7), K.mat(Color(0.35, 0.7, 0.85, 0.8), 0.05, 0.1, 0.2))
	K.mark(root, Vector3(-16.9, 0, -1.6), "plunge")
	# A long flat-roofed pavilion with a linear fire table and a kitchen wall.
	var pav := Rect2(-22.5, -9.8, 11.0, 5.2)
	K.pavilion(root, body, pav, 3.0, "flat", K.CHARCOAL, K.CHARCOAL, 4)
	K.fire_table(root, body, Vector2(-15.5, -6.4), Vector2(3.2, 0.7), false, 0.45, K.CHARCOAL)
	K.sofa(root, Vector2(-15.5, -5.0), Vector2(0, -1), 3.4, K.CHARCOAL, Color(0.9, 0.9, 0.88))
	K.sofa(root, Vector2(-15.5, -7.9), Vector2(0, 1), 3.4, K.CHARCOAL, Color(0.9, 0.9, 0.88))
	K.kitchen(root, body, Vector2(-22.0, -9.0), Vector2(1, 0), Vector2(0, 1), 4.2, ["fridge", "sink", "pizza", "grill"], K.CHARCOAL, Color(0.85, 0.85, 0.83))
	for p in [Vector2(-23.5, -3.0), Vector2(-23.5, 5.5), Vector2(-12.5, 5.0)]:
		K.shrub(root, p, 0.7)

# 11 ---------------------------------------------------------------------------
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

# 12 ---------------------------------------------------------------------------
func _gravel_pergola(root: Node3D, body: StaticBody3D) -> void:
	var gravel := K.paving(Color(0.72, 0.68, 0.60), 0.12, "pea")
	_patio(root, -14.5, -7.42, gravel)
	_garage_strip(root, gravel)
	_stoops(root, body, K.mat(K.STONE))
	K.tub_on_deck(root, body, TUB, 2.3, K.boards(K.CEDAR), ["north", "west"], K.CEDAR_DARK)
	K.pavilion(root, body, Rect2(-14.0, -6.9, 4.4, 4.0), 2.6, "flat", K.CEDAR, Color(0.85, 0.9, 0.95, 0.55))
	K.fire_table(root, body, Vector2(-11.8, -4.9))
	for p in [[Vector2(-11.8, -6.1), Vector2(0, 1)], [Vector2(-11.8, -3.7), Vector2(0, -1)], [Vector2(-13.2, -4.9), Vector2(1, 0)], [Vector2(-10.4, -4.9), Vector2(-1, 0)]]:
		K.chair(root, p[0], p[1], Color(0.2, 0.42, 0.45))
	K.kitchen(root, body, Vector2(-14.0, -1.8), Vector2(1, 0), Vector2(0, 1), 1.6, ["grill", "counter"])
	for p in [Vector2(-8.9, 0.9), Vector2(-9.5, 0.1)]:
		K.cyl(root, Vector3(p.x, 0.06, p.y), 0.3, 0.06, K.mat(K.STONE, 0.95))

# 13 ---------------------------------------------------------------------------
func _garage_kitchen(root: Node3D, body: StaticBody3D) -> void:
	var pavers := K.paving(Color(0.66, 0.60, 0.54), 0.5, "brick")
	_patio(root, -17.0, -7.42, pavers)
	_garage_strip(root, pavers)
	_stoops(root, body, K.mat(K.STONE))
	# A kitchen pavilion a few steps from the garage door.
	K.pavilion(root, body, Rect2(-14.1, -7.3, 5.4, 3.9), 2.8, "gable", K.CEDAR, K.SLATE, 3)
	K.kitchen(root, body, Vector2(-13.8, -6.6), Vector2(1, 0), Vector2(0, 1), 4.8, ["fridge", "sink", "counter", "grill", "burner"])
	K.dining(root, Vector2(-11.4, -4.6), 2.4)
	K.fire_table(root, body, Vector2(-14.6, -1.2), Vector2(1.0, 1.0), true)
	K.sofa(root, Vector2(-16.1, -1.2), Vector2(1, 0), 2.2)
	K.chair(root, Vector2(-13.2, -1.8), Vector2(-1, 0.4))
	K.chair(root, Vector2(-13.2, -0.6), Vector2(-1, -0.4))
	K.tub_on_deck(root, body, TUB, 2.3, K.boards(K.CEDAR), ["north"], K.CEDAR_DARK)

# 14 ---------------------------------------------------------------------------
func _tub_gazebo(root: Node3D, body: StaticBody3D) -> void:
	var pavers := K.paving(Color(0.60, 0.58, 0.56), 0.6, "gazebo")
	_patio(root, -14.5, -7.42, pavers)
	_garage_strip(root, pavers)
	_stoops(root, body, K.mat(K.STONE))
	# The tub in a wide deck under its own gazebo, open toward the house.
	K.tub_on_deck(root, body, TUB, 2.3, K.boards(K.CEDAR), ["north"], K.CEDAR_DARK, 1.4)
	K.gazebo(root, body, TUB, 2.3, 3.2, K.CEDAR, K.SLATE, Vector2(0, -1))
	K.pavilion(root, body, Rect2(-14.0, -6.8, 4.6, 4.0), 2.7, "shed", K.CEDAR, K.CHARCOAL)
	K.fire_table(root, body, Vector2(-11.7, -4.8), Vector2(1.4, 0.8))
	K.sofa(root, Vector2(-11.7, -3.4), Vector2(0, -1), 2.4)
	K.sofa(root, Vector2(-13.4, -4.8), Vector2(1, 0), 1.8)
	K.kitchen(root, body, Vector2(_wall - 0.7, -5.6), Vector2(0, 1), Vector2(-1, 0), 2.2, ["grill", "sink"])

# 15 ---------------------------------------------------------------------------
func _lean_to(root: Node3D, body: StaticBody3D) -> void:
	var concrete := K.paving(K.CONCRETE, 1.2, "lean")
	_patio(root, -14.0, -7.42, concrete)
	_garage_strip(root, concrete)
	_stoops(root, body, K.mat(K.CONCRETE))
	# A lean-to roof off the house wall over the patio, on three posts.
	K.mark(root, Vector3(-7.5, 0, -0.7), "cover")
	for z in [-5.0, -1.6, 1.8]:
		K.box(root, Vector3(-9.3, 1.25, z), Vector3(0.16, 2.5, 0.16), K.mat(K.CEDAR, 0.8), body)
	K.box(root, Vector3(-9.3, 2.5, -1.6), Vector3(0.18, 0.2, 7.4), K.mat(K.CEDAR, 0.8))
	var roof := K.box(root, Vector3(-7.55, 2.68, -0.7), Vector3(3.7, 0.08, 9.2), K.mat(K.CHARCOAL, 0.6, 0.3))
	roof.rotation.z = -0.07
	K.fire_table(root, body, Vector2(-8.4, -4.0), Vector2(1.2, 0.8))
	K.sofa(root, Vector2(-8.4, -5.3), Vector2(0, 1), 2.0)
	K.chair(root, Vector2(-8.4, -2.8), Vector2(0, -1))
	K.kitchen(root, body, Vector2(-9.4, 2.9), Vector2(1, 0), Vector2(0, -1), 2.4, ["grill", "sink", "counter"])
	K.tub_on_deck(root, body, TUB, 2.3, K.boards(Color(0.55, 0.53, 0.50)), ["north", "west"])

# 16 ---------------------------------------------------------------------------
func _spa_deck_sauna(root: Node3D, body: StaticBody3D) -> void:
	var pavers := K.paving(Color(0.68, 0.64, 0.58), 0.6, "spa")
	_patio(root, -14.5, -7.42, pavers)
	_garage_strip(root, pavers)
	_stoops(root, body, K.mat(K.STONE))
	# One cedar spa deck: the tub, and beside it on the same deck the barrel
	# sauna and a shower.
	var cedar := K.boards(K.CEDAR)
	K.tub_on_deck(root, body, TUB, 2.3, cedar, ["north"], K.CEDAR_DARK)
	K.landing(root, body, Rect2(-19.8, 1.75, 5.95, 4.3), 0.5, cedar, ["north", "west"])
	var up := _raised(root, 0.5)
	K.barrel_sauna(up, body, Vector2(-17.6, 4.2), 0.0, 2.4)
	K.cyl(up, Vector3(-15.0, 1.1, 2.4), 0.04, 2.2, K.mat(K.STEEL, 0.3, 0.8), body)
	K.pavilion(root, body, Rect2(-14.0, -6.8, 4.6, 4.4), 2.8, "gable", K.CEDAR, K.SLATE, 2)
	K.fire_table(root, body, Vector2(-11.7, -4.6), Vector2(1.0, 1.0), true)
	K.sofa(root, Vector2(-11.7, -3.2), Vector2(0, -1), 2.2)
	K.chair(root, Vector2(-13.2, -4.6), Vector2(1, 0))
	K.kitchen(root, body, Vector2(_wall - 0.7, -5.6), Vector2(0, 1), Vector2(-1, 0), 2.2, ["grill", "sink"])

# 17 ---------------------------------------------------------------------------
func _spa_corner(root: Node3D, body: StaticBody3D) -> void:
	var pavers := K.paving(Color(0.56, 0.56, 0.55), 0.45, "corner")
	_patio(root, -15.0, -7.42, pavers)
	_garage_strip(root, pavers)
	_stoops(root, body, K.mat(K.STONE))
	# A private spa corner: the tub deck screened on the west and south, with a
	# shower and a bench.
	K.tub_on_deck(root, body, TUB, 2.3, K.boards(K.CEDAR_DARK), ["north"], K.CHARCOAL)
	K.screen(root, body, TUB + Vector2(-2.3, -2.1), TUB + Vector2(-2.3, 2.3), 2.4, K.CEDAR_DARK)
	K.screen(root, body, TUB + Vector2(-2.3, 2.3), TUB + Vector2(2.1, 2.3), 2.4, K.CEDAR_DARK)
	K.shower(root, body, Vector2(-14.6, 0.6))
	K.box(root, Vector3(-14.6, 0.23, -0.6), Vector3(1.2, 0.46, 0.4), K.mat(K.CEDAR_DARK))
	K.pavilion(root, body, Rect2(-14.4, -6.8, 4.8, 4.2), 2.7, "shed", K.CHARCOAL, K.CHARCOAL)
	K.fire_table(root, body, Vector2(-12.0, -4.7), Vector2(1.5, 0.8), false, 0.5, K.SLATE)
	K.sofa(root, Vector2(-12.0, -3.3), Vector2(0, -1), 2.4, K.CHARCOAL, Color(0.6, 0.65, 0.7))
	K.sofa(root, Vector2(-13.8, -4.7), Vector2(1, 0), 1.8, K.CHARCOAL, Color(0.6, 0.65, 0.7))
	K.kitchen(root, body, Vector2(-14.2, -1.6), Vector2(1, 0), Vector2(0, 1), 2.4, ["grill", "sink", "counter"])

# 18 ---------------------------------------------------------------------------
func _pizza_patio(root: Node3D, body: StaticBody3D) -> void:
	var pavers := K.paving(Color(0.72, 0.50, 0.38), 0.4, "terracotta")
	_patio(root, -18.5, -7.42, pavers)
	_garage_strip(root, pavers)
	_stoops(root, body, K.mat(K.STONE))
	K.pavilion(root, body, Rect2(-15.0, -7.3, 5.4, 5.4), 2.8, "gable", K.CEDAR, Color(0.6, 0.3, 0.2), 3)
	K.kitchen(root, body, Vector2(-14.7, -6.6), Vector2(1, 0), Vector2(0, 1), 4.6, ["pizza", "counter", "grill", "sink", "fridge"])
	K.dining(root, Vector2(-12.3, -3.8), 2.8)
	K.fire_table(root, body, Vector2(-16.6, 0.6), Vector2(1.0, 1.0), true)
	for k in 4:
		var a := TAU * (k + 0.5) / 4.0
		K.chair(root, Vector2(-16.6 + cos(a) * 1.5, 0.6 + sin(a) * 1.5), Vector2(-cos(a), -sin(a)), Color(0.85, 0.75, 0.55))
	K.tub_on_deck(root, body, TUB, 2.3, K.boards(K.CEDAR), ["north"], K.CEDAR_DARK)
	K.string_lights(root, body, [Vector2(-18.2, -1.6), Vector2(-15.6, 3.6), Vector2(-9.0, -1.6)], 3.0)

# 19 ---------------------------------------------------------------------------
func _pool_and_spa(root: Node3D, body: StaticBody3D) -> void:
	var pavers := K.paving(Color(0.86, 0.83, 0.76), 0.6, "pool")
	_patio(root, -31.0, -8.4, pavers)
	_garage_strip(root, pavers)
	_stoops(root, body, K.mat(K.WHITE))
	K.tub_on_deck(root, body, TUB, 2.3, K.boards(Color(0.55, 0.40, 0.30)), ["north", "west"], K.WHITE)
	# A raised lap pool with coping, loungers along its south side.
	var pool := Rect2(-27.0, -3.4, 11.0, 4.4)
	K.box(root, Vector3(pool.get_center().x, 0.4, pool.get_center().y), Vector3(pool.size.x, 0.8, pool.size.y), K.mat(K.WHITE, 0.6), body)
	K.box(root, Vector3(pool.get_center().x, 0.81, pool.get_center().y), Vector3(pool.size.x - 0.5, 0.02, pool.size.y - 0.5), K.mat(Color(0.25, 0.65, 0.88, 0.8), 0.05, 0.1, 0.3))
	K.mark(root, Vector3(pool.get_center().x, 0, pool.get_center().y), "pool")
	for x in [-25.5, -23.5, -21.5, -19.5]:
		K.box(root, Vector3(x, 0.3, 2.4), Vector3(0.7, 0.12, 1.9), K.mat(K.WHITE, 0.6))
		K.box(root, Vector3(x, 0.55, 1.7), Vector3(0.7, 0.5, 0.1), K.mat(K.WHITE, 0.6)).rotation.x = -0.6
	# The pool house: a flat-roofed cabana with the kitchen and a fire table.
	var cabana := Rect2(-30.0, -8.0, 7.6, 3.8)
	K.pavilion(root, body, cabana, 3.0, "flat", K.WHITE, K.CHARCOAL, 3)
	K.kitchen(root, body, Vector2(-29.7, -7.3), Vector2(1, 0), Vector2(0, 1), 4.2, ["fridge", "sink", "grill", "burner"])
	K.fire_table(root, body, Vector2(-24.4, -5.9), Vector2(1.4, 0.7), false, 0.5, K.WHITE)
	K.sofa(root, Vector2(-24.4, -4.7), Vector2(0, -1), 2.2, K.WHITE, Color(0.25, 0.45, 0.65))
	for p in [Vector2(-30.0, 2.0), Vector2(-15.5, 4.5)]:
		K.shrub(root, p, 0.7)

# 20 ---------------------------------------------------------------------------
func _mountain_lodge(root: Node3D, body: StaticBody3D) -> void:
	var flag := K.paving(Color(0.52, 0.50, 0.46), 0.8, "flagstone")
	_patio(root, -23.0, -9.6, flag)
	_garage_strip(root, flag)
	_stoops(root, body, K.mat(K.STONE))
	var log_color := Color(0.45, 0.30, 0.18)
	# A heavy log pavilion round a two-storey stone fireplace.
	var lodge := Rect2(-17.0, -8.8, 7.4, 5.6)
	K.pavilion(root, body, lodge, 3.0, "gable", log_color, Color(0.22, 0.32, 0.24), 3)
	K.box(root, Vector3(lodge.get_center().x, 3.0, lodge.position.y + 0.3), Vector3(2.4, 6.0, 1.0), K.mat(K.STONE, 0.95), body)
	K.flames(root, Vector3(lodge.get_center().x, 0.5, lodge.position.y + 0.85), 0.5, 5, 0.45)
	K.fire_table(root, body, Vector2(lodge.get_center().x, -6.0), Vector2(1.8, 0.9), false, 0.45, K.STONE)
	K.sofa(root, Vector2(lodge.get_center().x, -4.4), Vector2(0, -1), 2.6, log_color, Color(0.45, 0.25, 0.18))
	K.sofa(root, Vector2(lodge.position.x + 0.9, -6.0), Vector2(1, 0), 2.0, log_color, Color(0.45, 0.25, 0.18))
	K.sofa(root, Vector2(lodge.end.x - 0.9, -6.0), Vector2(-1, 0), 2.0, log_color, Color(0.45, 0.25, 0.18))
	K.kitchen(root, body, Vector2(-22.6, -8.6), Vector2(1, 0), Vector2(0, 1), 4.2, ["smoker", "grill", "counter", "sink"], K.STONE)
	K.cabin_sauna(root, body, Rect2(-21.5, 0.0, 3.4, 3.2), 2.4)
	K.box(root, Vector3(-19.8, 0.15, 3.6), Vector3(3.4, 0.3, 1.0), K.boards(log_color))
	K.cold_plunge(root, body, Vector2(-17.2, 0.6))
	K.tub_on_deck(root, body, TUB, 2.3, K.boards(log_color), ["north", "west"], log_color)
	for p in [Vector2(-22.4, -2.0), Vector2(-9.2, -8.3)]:
		K.shrub(root, p, 0.8)

# 21 ---------------------------------------------------------------------------
func _round_pavilion(root: Node3D, body: StaticBody3D) -> void:
	var pavers := K.paving(Color(0.64, 0.62, 0.66), 0.5, "round")
	_patio(root, -23.5, -9.0, pavers)
	_garage_strip(root, pavers)
	_stoops(root, body, K.mat(K.STONE))
	# A big round pavilion: a ring of sofas round a wide fire table.
	var c := Vector2(-16.2, -3.6)
	K.gazebo(root, body, c, 4.2, 3.0, K.CHARCOAL, Color(0.5, 0.52, 0.55), Vector2(1, 0))
	K.fire_table(root, body, c, Vector2(1.6, 1.6), true, 0.45, K.SLATE)
	for k in 6:
		var a := TAU * (k + 0.5) / 6.0
		if k == 0 or k == 5:
			continue
		K.sofa(root, c + Vector2(cos(a), sin(a)) * 2.7, -Vector2(cos(a), sin(a)), 2.0, K.CHARCOAL, Color(0.82, 0.78, 0.7))
	K.kitchen(root, body, Vector2(-22.4, -7.0), Vector2(0, 1), Vector2(1, 0), 3.6, ["grill", "sink", "pizza", "fridge"])
	K.barrel_sauna(root, body, Vector2(-21.0, 3.6), 0.0, 2.6)
	K.tub_on_deck(root, body, TUB, 2.3, K.boards(K.CEDAR), ["north"], K.CEDAR_DARK)

# 22 ---------------------------------------------------------------------------
func _desert_modern(root: Node3D, body: StaticBody3D) -> void:
	var sand := K.paving(Color(0.86, 0.80, 0.68), 0.9, "sand")
	_patio(root, -23.0, -8.0, sand)
	_garage_strip(root, sand)
	_stoops(root, body, K.mat(Color(0.86, 0.80, 0.68)))
	var stucco := K.mat(Color(0.93, 0.91, 0.86), 0.95)
	var rust := K.mat(Color(0.55, 0.28, 0.14), 0.8, 0.3)
	# White stucco privacy walls on the west, with a gap to walk through.
	for seg in [[-7.5, -1.0], [1.0, 6.5]]:
		K.box(root, Vector3(-22.6, 1.1, (seg[0] + seg[1]) / 2.0), Vector3(0.3, 2.2, seg[1] - seg[0]), stucco, body)
	# A steel ramada with a slatted wood roof over a long fire table.
	var ram := Rect2(-20.6, -7.4, 7.2, 4.8)
	K.pavilion(root, body, ram, 2.9, "flat", K.CHARCOAL, Color(0.55, 0.42, 0.30), 3)
	K.kitchen(root, body, Vector2(-20.3, -6.7), Vector2(1, 0), Vector2(0, 1), 3.6, ["grill", "sink", "counter", "fridge"], Color(0.93, 0.91, 0.86))
	K.fire_table(root, body, Vector2(-15.4, -5.2), Vector2(2.2, 0.6), false, 0.4, K.CHARCOAL)
	K.sofa(root, Vector2(-15.4, -3.8), Vector2(0, -1), 2.6, K.CHARCOAL, Color(0.9, 0.86, 0.78))
	K.sofa(root, Vector2(-15.4, -6.6), Vector2(0, 1), 2.6, K.CHARCOAL, Color(0.9, 0.86, 0.78))
	# Plunge pool and sauna.
	K.box(root, Vector3(-18.5, 0.45, 0.4), Vector3(2.4, 0.9, 3.0), stucco, body)
	K.box(root, Vector3(-18.5, 0.91, 0.4), Vector3(2.1, 0.02, 2.7), K.mat(Color(0.35, 0.7, 0.85, 0.8), 0.05, 0.1, 0.2))
	K.cabin_sauna(root, body, Rect2(-21.8, 2.6, 2.8, 2.8), 2.3)
	K.tub_on_deck(root, body, TUB, 2.3, K.boards(Color(0.36, 0.22, 0.15)), ["north"], K.CHARCOAL)
	# Cor-ten planters with agaves.
	for p in [Vector2(-21.6, -1.6), Vector2(-14.6, -1.4), Vector2(-14.6, 6.8), Vector2(-9.4, -8.6)]:
		K.box(root, Vector3(p.x, 0.3, p.y), Vector3(0.9, 0.6, 0.9), rust)
		for k in 5:
			var a := TAU * k / 5.0
			K.cyl(root, Vector3(p.x + cos(a) * 0.15, 0.85, p.y + sin(a) * 0.15), 0.08, 0.6, K.mat(Color(0.45, 0.55, 0.45), 0.8), null, 0.0, 6)

# 23 ---------------------------------------------------------------------------
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

# --- sauna-ready ideas: room left for a sauna -----------------------------------

func _sauna_pad_patio(root: Node3D, body: StaticBody3D) -> void:
	var concrete := K.paving(K.CONCRETE, 1.2, "padpatio")
	_patio(root, -20.0, -7.42, concrete)
	_garage_strip(root, concrete)
	_stoops(root, body, K.mat(K.CONCRETE))
	K.tub_on_deck(root, body, TUB, 2.3, K.boards(K.CEDAR), ["north"], K.CEDAR_DARK)
	K.pavilion(root, body, Rect2(-14.2, -6.9, 4.6, 4.2), 2.7, "shed", K.CEDAR, K.CHARCOAL)
	K.fire_table(root, body, Vector2(-11.9, -4.8))
	for p in [[Vector2(-11.9, -6.0), Vector2(0, 1)], [Vector2(-11.9, -3.6), Vector2(0, -1)], [Vector2(-13.3, -4.8), Vector2(1, 0)], [Vector2(-10.5, -4.8), Vector2(-1, 0)]]:
		K.chair(root, p[0], p[1])
	K.kitchen(root, body, Vector2(_wall - 0.7, -5.6), Vector2(0, 1), Vector2(-1, 0), 2.2, ["grill", "sink"])
	K.sauna_spot(root, Rect2(-18.6, 2.0, 2.8, 3.2))

func _boardwalk_sauna(root: Node3D, body: StaticBody3D) -> void:
	var pavers := K.paving(Color(0.66, 0.62, 0.56), 0.6, "boardwalk")
	_patio(root, -14.5, -7.42, pavers)
	_garage_strip(root, pavers)
	_stoops(root, body, K.mat(K.STONE))
	var cedar := K.boards(K.CEDAR)
	# The tub deck carries on west as a boardwalk to an empty sauna deck.
	K.tub_on_deck(root, body, TUB, 2.3, cedar, ["north"], K.CEDAR_DARK)
	K.landing(root, body, Rect2(-16.4, 3.3, 2.6, 1.2), 0.5, cedar, [])
	K.landing(root, body, Rect2(-19.8, 2.0, 3.4, 3.6), 0.5, cedar, ["north", "west", "south"])
	K.sauna_spot(root, Rect2(-19.6, 2.2, 3.0, 3.2), 0.5, false)
	K.pavilion(root, body, Rect2(-14.4, -7.2, 4.8, 4.6), 2.8, "gable", K.CEDAR, K.SLATE, 2)
	K.fire_table(root, body, Vector2(-12.0, -4.9), Vector2(1.0, 1.0), true)
	K.sofa(root, Vector2(-12.0, -3.5), Vector2(0, -1), 2.2)
	K.chair(root, Vector2(-13.5, -4.9), Vector2(1, 0))
	K.kitchen(root, body, Vector2(_wall - 0.7, -5.6), Vector2(0, 1), Vector2(-1, 0), 2.2, ["grill", "sink"])

func _pergola_row(root: Node3D, body: StaticBody3D) -> void:
	var pavers := K.paving(Color(0.58, 0.58, 0.60), 0.5, "row")
	_patio(root, -21.0, -7.42, pavers)
	_garage_strip(root, pavers)
	_stoops(root, body, K.mat(K.STONE))
	K.tub_on_deck(root, body, TUB, 2.3, K.boards(K.CEDAR), ["north", "west"], K.CEDAR_DARK)
	# A row along the north of the patio: a roofed pergola over the fire
	# table, an open one over the kitchen, then the sauna's spot.
	K.pavilion(root, body, Rect2(-13.8, -6.8, 4.0, 4.0), 2.6, "flat", K.CEDAR, Color(0.85, 0.9, 0.95, 0.55))
	K.fire_table(root, body, Vector2(-11.8, -4.8))
	for p in [[Vector2(-11.8, -6.0), Vector2(0, 1)], [Vector2(-11.8, -3.6), Vector2(0, -1)], [Vector2(-13.2, -4.8), Vector2(1, 0)]]:
		K.chair(root, p[0], p[1], Color(0.25, 0.4, 0.3))
	K.pergola(root, body, Rect2(-19.0, -7.2, 3.8, 2.6), 2.6)
	K.kitchen(root, body, Vector2(-18.6, -6.2), Vector2(1, 0), Vector2(0, 1), 3.0, ["grill", "counter", "sink"])
	K.sauna_spot(root, Rect2(-20.6, -3.4, 2.8, 3.0))

func _garden_corner(root: Node3D, body: StaticBody3D) -> void:
	var pavers := K.paving(Color(0.70, 0.66, 0.58), 0.6, "garden")
	_patio(root, -21.0, -10.5, pavers)
	_garage_strip(root, pavers)
	_stoops(root, body, K.mat(K.STONE))
	K.tub_on_deck(root, body, TUB, 2.3, K.boards(K.CEDAR), ["north", "west"], K.CEDAR_DARK)
	K.pavilion(root, body, Rect2(-14.0, -6.6, 4.6, 4.2), 2.7, "flat", K.CEDAR, K.CEDAR_DARK)
	K.fire_table(root, body, Vector2(-11.7, -4.5), Vector2(1.4, 0.8))
	K.sofa(root, Vector2(-11.7, -3.1), Vector2(0, -1), 2.4)
	K.sofa(root, Vector2(-13.4, -4.5), Vector2(1, 0), 1.6)
	K.kitchen(root, body, Vector2(_wall - 0.7, -5.6), Vector2(0, 1), Vector2(-1, 0), 2.2, ["grill", "sink"])
	# Raised beds, and the sauna's spot in the quiet north-west corner.
	for p in [Vector2(-15.4, -9.2), Vector2(-16.4, -1.0), Vector2(-19.6, 2.4)]:
		K.box(root, Vector3(p.x, 0.25, p.y), Vector3(2.4, 0.5, 1.0), K.mat(K.CEDAR_DARK, 0.9), body)
		for k in 3:
			K.shrub(root, p + Vector2(-0.8 + k * 0.8, 0), 0.35)
	K.sauna_spot(root, Rect2(-20.6, -10.0, 3.0, 2.9))

func _gazebo_firepit(root: Node3D, body: StaticBody3D) -> void:
	var gravel := K.paving(Color(0.70, 0.66, 0.60), 0.12, "firepit")
	_patio(root, -18.0, -7.42, gravel)
	_garage_strip(root, gravel)
	_stoops(root, body, K.mat(K.STONE))
	K.tub_on_deck(root, body, TUB, 2.3, K.boards(K.CEDAR), ["north"], K.CEDAR_DARK)
	K.gazebo(root, body, Vector2(-12.5, -3.8), 2.6, 2.7, K.CEDAR, K.SLATE, Vector2(1, 0))
	K.fire_table(root, body, Vector2(-12.5, -3.8), Vector2(1.0, 1.0), true)
	for k in 5:
		var a := PI * 0.35 + PI * 1.3 * k / 4.0
		K.chair(root, Vector2(-12.5 + cos(a) * 1.6, -3.8 + sin(a) * 1.6), Vector2(-cos(a), -sin(a)), Color(0.55, 0.25, 0.2))
	K.kitchen(root, body, Vector2(-9.8, -6.6), Vector2(1, 0), Vector2(0, 1), 1.6, ["grill", "counter"])
	K.sauna_spot(root, Rect2(-18.4, 1.6, 2.8, 3.2))

func _l_patio(root: Node3D, body: StaticBody3D) -> void:
	var pavers := K.paving(Color(0.62, 0.56, 0.50), 0.45, "lpatio")
	K.slab(root, Rect2(-11.0, -7.42, _wall + 11.0, 14.66), 0.05, pavers)
	K.slab(root, Rect2(-21.0, -7.42, 10.0, 3.6), 0.05, pavers)
	_garage_strip(root, pavers)
	_stoops(root, body, K.mat(K.STONE))
	K.tub_on_deck(root, body, TUB, 2.3, K.boards(K.CEDAR), ["north"], K.CEDAR_DARK)
	# The L's west arm: a kitchen pavilion, then the sauna's spot at its end.
	K.pavilion(root, body, Rect2(-16.4, -7.3, 5.0, 3.3), 2.7, "gable", K.CEDAR, K.SLATE, 2)
	K.kitchen(root, body, Vector2(-16.1, -6.6), Vector2(1, 0), Vector2(0, 1), 4.4, ["fridge", "sink", "grill", "counter"])
	K.fire_table(root, body, Vector2(-9.2, -3.8), Vector2(1.0, 1.0), true)
	for k in 3:
		var a := PI * 0.6 + PI * 0.8 * k / 2.0
		K.chair(root, Vector2(-9.2 + cos(a) * 1.4, -3.8 + sin(a) * 1.4), Vector2(-cos(a), -sin(a)))
	K.pergola(root, body, Rect2(-10.6, -5.2, 2.8, 2.8), 2.6)
	K.box(root, Vector3(-9.2, 2.75, -3.8), Vector3(3.0, 0.04, 3.0), K.mat(Color(0.85, 0.9, 0.95, 0.55), 0.4))
	K.mark(root, Vector3(-9.2, 0, -3.8), "cover")
	K.sauna_spot(root, Rect2(-20.8, -7.2, 3.0, 3.1))

func _screened_spa_court(root: Node3D, body: StaticBody3D) -> void:
	var pavers := K.paving(Color(0.60, 0.60, 0.58), 0.6, "court")
	_patio(root, -14.5, -7.42, pavers)
	_garage_strip(root, pavers)
	_stoops(root, body, K.mat(K.STONE))
	K.tub_on_deck(root, body, TUB, 2.3, K.boards(K.CEDAR_DARK), ["north"], K.CHARCOAL)
	# A spa court west of the tub, screened on three sides, open toward it:
	# a shower now, the sauna's spot for later.
	K.slab(root, Rect2(-20.0, 0.6, 4.4, 6.4), 0.05, K.paving(Color(0.55, 0.55, 0.53), 0.45, "courtfloor"))
	K.screen(root, body, Vector2(-20.0, 0.6), Vector2(-20.0, 7.0), 2.2, K.CEDAR_DARK)
	K.screen(root, body, Vector2(-20.0, 0.6), Vector2(-16.8, 0.6), 2.2, K.CEDAR_DARK)
	K.screen(root, body, Vector2(-20.0, 7.0), Vector2(-15.6, 7.0), 2.2, K.CEDAR_DARK)
	K.sauna_spot(root, Rect2(-19.5, 1.2, 2.8, 3.0))
	K.shower(root, body, Vector2(-16.4, 5.6))
	K.pavilion(root, body, Rect2(-14.2, -6.9, 4.6, 4.2), 2.7, "shed", K.CHARCOAL, K.CHARCOAL)
	K.fire_table(root, body, Vector2(-11.9, -4.8), Vector2(1.4, 0.8), false, 0.5, K.SLATE)
	K.sofa(root, Vector2(-11.9, -3.4), Vector2(0, -1), 2.4, K.CHARCOAL, Color(0.6, 0.65, 0.7))
	K.kitchen(root, body, Vector2(_wall - 0.7, -5.6), Vector2(0, 1), Vector2(-1, 0), 2.2, ["grill", "sink"])

func _plunge_ready(root: Node3D, body: StaticBody3D) -> void:
	var pavers := K.paving(Color(0.66, 0.64, 0.60), 0.6, "plunge")
	_patio(root, -20.0, -7.42, pavers)
	_garage_strip(root, pavers)
	_stoops(root, body, K.mat(K.STONE))
	K.tub_on_deck(root, body, TUB, 2.3, K.boards(K.CEDAR), ["north"], K.CEDAR_DARK)
	K.cold_plunge(root, body, Vector2(-17.8, -0.6))
	K.shower(root, body, Vector2(-15.6, -0.9))
	K.sauna_spot(root, Rect2(-19.2, 1.8, 2.8, 3.2))
	K.pavilion(root, body, Rect2(-14.4, -7.2, 4.8, 4.4), 2.8, "gable", K.CEDAR, K.SLATE, 2)
	K.kitchen(root, body, Vector2(-14.1, -6.5), Vector2(1, 0), Vector2(0, 1), 3.6, ["grill", "sink", "counter"])
	K.fire_table(root, body, Vector2(-12.0, -4.3), Vector2(1.4, 0.8))
	K.sofa(root, Vector2(-12.0, -3.2), Vector2(0, -1), 2.2)

func _big_pavilion(root: Node3D, body: StaticBody3D) -> void:
	var pavers := K.paving(Color(0.64, 0.60, 0.55), 0.6, "bigpav")
	_patio(root, -19.0, -7.42, pavers)
	_garage_strip(root, pavers)
	_stoops(root, body, K.mat(K.STONE))
	K.tub_on_deck(root, body, TUB, 2.3, K.boards(K.CEDAR), ["north"], K.CEDAR_DARK)
	# One roof over everything: the kitchen along the back, the fire table
	# and sofa in front.
	K.pavilion(root, body, Rect2(-16.6, -7.3, 6.6, 5.6), 2.9, "gable", K.CEDAR, K.SLATE, 3)
	K.kitchen(root, body, Vector2(-16.3, -6.6), Vector2(1, 0), Vector2(0, 1), 5.0, ["fridge", "sink", "counter", "grill", "burner"])
	K.fire_table(root, body, Vector2(-13.3, -3.9), Vector2(1.6, 0.8))
	K.sofa(root, Vector2(-13.3, -2.5), Vector2(0, -1), 2.6)
	K.chair(root, Vector2(-15.2, -3.9), Vector2(1, 0))
	K.chair(root, Vector2(-11.4, -3.9), Vector2(-1, 0))
	K.sauna_spot(root, Rect2(-18.6, 0.8, 2.8, 3.2))

func _porch_swing(root: Node3D, body: StaticBody3D) -> void:
	var concrete := K.paving(K.CONCRETE, 1.2, "swing")
	_patio(root, -14.0, -7.42, concrete)
	_garage_strip(root, concrete)
	_stoops(root, body, K.mat(K.CONCRETE))
	# A lean-to roof off the house over a fire table and a porch swing.
	K.mark(root, Vector3(-7.5, 0, -0.7), "cover")
	for z in [-5.0, -1.6, 1.8]:
		K.box(root, Vector3(-9.3, 1.25, z), Vector3(0.16, 2.5, 0.16), K.mat(K.WHITE, 0.8), body)
	K.box(root, Vector3(-9.3, 2.5, -1.6), Vector3(0.18, 0.2, 7.4), K.mat(K.WHITE, 0.8))
	var roof := K.box(root, Vector3(-7.55, 2.68, -0.7), Vector3(3.7, 0.08, 9.2), K.mat(K.SLATE, 0.6, 0.2))
	roof.rotation.z = -0.07
	K.fire_table(root, body, Vector2(-8.4, -4.0), Vector2(1.2, 0.8))
	K.chair(root, Vector2(-8.4, -5.3), Vector2(0, 1), K.WHITE)
	K.chair(root, Vector2(-8.4, -2.8), Vector2(0, -1), K.WHITE)
	K.box(root, Vector3(-8.7, 0.5, 0.4), Vector3(0.6, 0.08, 1.6), K.mat(K.WHITE, 0.8))
	K.box(root, Vector3(-8.95, 0.8, 0.4), Vector3(0.08, 0.55, 1.6), K.mat(K.WHITE, 0.8))
	for z in [-0.35, 1.15]:
		K.cyl(root, Vector3(-8.7, 1.5, z), 0.015, 2.0, K.mat(K.STEEL, 0.4, 0.7))
	K.kitchen(root, body, Vector2(-9.4, 2.9), Vector2(1, 0), Vector2(0, -1), 2.4, ["grill", "sink", "counter"])
	K.tub_on_deck(root, body, TUB, 2.3, K.boards(Color(0.55, 0.53, 0.50)), ["north"])
	K.sauna_spot(root, Rect2(-18.6, 1.8, 2.8, 3.2))

func _stepping_stones(root: Node3D, body: StaticBody3D) -> void:
	_garage_strip(root, K.mat(K.CONCRETE))
	_stoops(root, body, K.mat(K.STONE))
	# Mostly lawn: a small concrete pad under a clear-roofed pergola, and
	# stepping stones to the tub and to the sauna's spot.
	K.slab(root, Rect2(-12.6, -5.8, 4.0, 4.0), 0.05, K.paving(K.CONCRETE, 1.0, "stones"))
	K.pavilion(root, body, Rect2(-12.4, -5.6, 3.6, 3.6), 2.6, "flat", K.CEDAR, Color(0.85, 0.9, 0.95, 0.55))
	K.fire_table(root, body, Vector2(-10.6, -3.8), Vector2(1.2, 0.7))
	for p in [[Vector2(-10.6, -4.9), Vector2(0, 1)], [Vector2(-11.8, -3.8), Vector2(1, 0)], [Vector2(-9.4, -3.8), Vector2(-1, 0)]]:
		K.chair(root, p[0], p[1], Color(0.3, 0.45, 0.6))
	K.kitchen(root, body, Vector2(-10.6, -1.2), Vector2(1, 0), Vector2(0, 1), 1.4, ["grill"])
	K.tub_on_deck(root, body, TUB, 2.3, K.boards(K.CEDAR), ["north", "west"], K.CEDAR_DARK)
	for p in [Vector2(-8.6, 0.4), Vector2(-9.4, -0.1), Vector2(-10.3, -0.4), Vector2(-15.6, 1.2), Vector2(-16.4, 1.6)]:
		K.cyl(root, Vector3(p.x, 0.05, p.y), 0.32, 0.06, K.mat(K.STONE, 0.95))
	K.sauna_spot(root, Rect2(-18.2, 1.8, 2.8, 3.2))

func _hearth_room(root: Node3D, body: StaticBody3D) -> void:
	var pavers := K.paving(Color(0.56, 0.52, 0.48), 0.6, "hearth")
	_patio(root, -19.5, -9.0, pavers)
	_garage_strip(root, pavers)
	_stoops(root, body, K.mat(K.STONE))
	K.tub_on_deck(root, body, TUB, 2.3, K.boards(K.CEDAR), ["north"], K.CEDAR_DARK)
	# A pavilion with a low stone wall along its back, a long fire table and
	# two sofas facing across it.
	var pav := Rect2(-15.6, -8.6, 5.4, 5.0)
	K.pavilion(root, body, pav, 2.8, "gable", K.CEDAR_DARK, K.SLATE, 3)
	K.box(root, Vector3(pav.get_center().x, 0.6, pav.position.y + 0.3), Vector3(pav.size.x - 0.6, 1.2, 0.35), K.mat(K.STONE, 0.95), body)
	K.fire_table(root, body, Vector2(pav.get_center().x, -6.2), Vector2(2.0, 0.7), false, 0.45, K.STONE)
	K.sofa(root, Vector2(pav.get_center().x, -4.8), Vector2(0, -1), 2.6)
	K.sofa(root, Vector2(pav.get_center().x, -7.5), Vector2(0, 1), 2.6)
	K.kitchen(root, body, Vector2(-18.6, -8.2), Vector2(0, 1), Vector2(1, 0), 3.0, ["grill", "sink", "counter"])
	K.sauna_spot(root, Rect2(-18.6, 0.6, 2.8, 3.2))
