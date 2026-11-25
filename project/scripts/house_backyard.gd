extends Node3D
## The back yard of the main House (D-170), after the owner's photo
## (Downloads/back yard deck.jpg), taken from the lawn west of the House: the
## garage on the left (north), the House's long west wall with its patio
## slider in the middle, and the South Wing coming forward on the right.
##
## This node builds, in the House's own frame (building_shell.gd's
## `frame_for`, so +x is east-ish and +z south-ish, the west wall at
## x = -width / 2):
##  - the concrete pad: a 5 cm slab along the whole back of the House, from
##    the garage to the South Wing, its outer edge flush with the Wing's west
##    end, and on north along the front of the garage, with the air-conditioner
##    on it.
##  - the deck on the pad: a low rectangle of weathered wood in the corner
##    between the west wall and the Wing's north wall, from just south of the
##    second window, with two steps along its front and north end; the bottom
##    step stops `INSET` (about 1.5 ft) inside the concrete's outer edge. A
##    sloped collision hull covers the steps so the player walks up them.
##  - the willows (willow.gd, D-171): seven big ones in an L just inside the
##    chicken run's fence, roughly evenly spaced (each a little off the line)
##    along the south side, south of the coop, then turning north up the west
##    side and ending level with the House's south edge, in a bed of brown
##    mulch.
##  - the pale blue lap siding (siding.gd) on the garage and on the House's,
##    garage's and Wing's gable triangles. The House and Wing walls get theirs
##    from their building_shell nodes (`siding`), which also cut the patio
##    sliders and windows.

const Shell := preload("res://scripts/building_shell.gd")
const Siding := preload("res://scripts/siding.gd")
const Willow := preload("res://scripts/willow.gd")

## Sizes, metres. `PAD_REACH` is how far the concrete stands out from the west
## wall (flush with the Wing's west end); the deck's bottom step stops `INSET`
## inside that, so the deck top stands out `REACH`. `RUN` is how far north of
## the Wing the deck runs along the wall; `CORNER_Z` is the Wing's north wall
## in the House's frame.
const PAD_REACH := 4.02
const INSET := 0.45
const RUN := 11.24
const CORNER_Z := 7.24
const RISE := 0.12
const TREAD := 0.35
const STEPS := 2
const REACH := PAD_REACH - INSET - STEPS * TREAD
## Deck top: a riser per step plus the deck's own edge.
const TOP := RISE * (STEPS + 1)
## The garage's west wall in the House's frame (it leans a little; this is
## its south end), and its north end.
const GARAGE_WEST := -8.35
const GARAGE_NORTH := -14.9
const GARAGE_SOUTH := -7.42
## One square of deck texture: four 5.5 inch boards.
const BOARD := 0.14
const DECK_TILE := BOARD * 4
const DECK_COLOR := Color(0.50, 0.38, 0.31)

const PAD_COLOR := Color(0.62, 0.61, 0.58)
const PAD_TOP := 0.05

## The willows' row in this frame: along the south leg at `ROW_Z`, from
## `ROW_EAST` to the corner at `ROW_WEST`, then north up the west leg to
## `ROW_NORTH`, just short of the line of the Wing's south wall (z 12.7). The
## chicken run's fence is about 2 m outside the south leg and the south end of
## the west leg. Each tree is nudged up to `JITTER` metres off its even spot
## along the row and a little less across it: they were not planted by line.
const ROW_Z := 26.3
const ROW_WEST := -16.0
const ROW_EAST := 2.5
const ROW_NORTH := 14.6
const TREES := 7
const TREE_HEIGHT := 20.0
const JITTER := 0.8
## The mulch bed is this wide, centred on the row.
const BED_WIDTH := 3.0
const BED_TOP := 0.06
const MULCH_COLOR := Color(0.36, 0.25, 0.17)

const GABLES := ["House_Gable_South", "House_Gable_North", "HouseGarage_Gable_North",
		"HouseSouthWing_Gable_East", "HouseSouthWing_Gable_West"]

var wall_x := -5.67
var _body: StaticBody3D
## The deck, its steps' hulls and the concrete pad: what a back-yard mockup
## (backyard_mockups.gd) tears out.
var _as_built: Array[Node] = []

func _ready() -> void:
	var house := get_node_or_null("../House") as Node3D
	if house == null:
		push_warning("house_backyard: no House under Buildings")
		return
	global_transform = Shell.frame_for(house)
	wall_x = -house.global_transform.basis.x.length() / 2.0
	_body = StaticBody3D.new()
	_body.name = "Body"
	add_child(_body)
	_build_deck()
	_build_pad()
	_build_ac_unit()
	_build_trees()
	_dress_siding()

## Plan rectangles in this frame's (x, z) of each level, top first: the deck,
## then one per step. Each step is the deck grown by TREAD per step on the
## west and north; the south side is against the Wing.
## Show or tear out the deck, its steps and the concrete pad (a mockup builds
## its own ground). The AC unit, the willows and the mulch stay.
func set_as_built(on: bool) -> void:
	for node in _as_built:
		if node is CollisionShape3D:
			(node as CollisionShape3D).disabled = not on
		else:
			(node as Node3D).visible = on

func is_as_built() -> bool:
	return _as_built.is_empty() or (_as_built[0] as Node3D).visible

static func levels(wall: float) -> Array:
	var out := []
	var x0 := wall - REACH
	var zn := CORNER_Z - RUN
	for k in STEPS + 1:
		var g := k * TREAD
		var rects: Array[Rect2] = [Rect2(x0 - g, zn - g, wall - (x0 - g), CORNER_Z - (zn - g))]
		out.append(rects)
	return out

## Deck height at (x, z) in this frame: TOP on the deck, stepping down by RISE
## per tread, 0 off the deck.
static func height_at(x: float, z: float, wall: float) -> float:
	var all := levels(wall)
	for k in all.size():
		for r: Rect2 in all[k]:
			if r.has_point(Vector2(x, z)):
				return TOP - k * RISE
	return 0.0

func _build_deck() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var all := levels(wall_x)
	for k in all.size():
		for r: Rect2 in all[k]:
			_deck_box(st, r, TOP - k * RISE)
	var mi := MeshInstance3D.new()
	mi.name = "Deck"
	mi.mesh = st.commit()
	mi.material_override = deck_material()
	add_child(mi)
	_as_built.append(mi)
	# A sloped hull from the deck top's edges to the ground past the bottom
	# step (about 19 degrees, its toe still on the concrete), so the player
	# walks up instead of being stopped by each riser. It stops at the Wing's
	# north wall.
	var x0 := wall_x - REACH
	var zn := CORNER_Z - RUN
	var out := (STEPS + 1) * TREAD
	_hull([Vector3(x0, TOP, zn), Vector3(wall_x, TOP, zn), Vector3(x0, TOP, CORNER_Z), Vector3(wall_x, TOP, CORNER_Z),
			Vector3(x0 - out, 0, zn - out), Vector3(wall_x, 0, zn - out), Vector3(x0 - out, 0, CORNER_Z), Vector3(wall_x, 0, CORNER_Z)])

func _hull(points: Array) -> void:
	var shape := ConvexPolygonShape3D.new()
	shape.points = PackedVector3Array(points)
	var cs := CollisionShape3D.new()
	cs.name = "DeckHull"
	cs.shape = shape
	_body.add_child(cs)
	_as_built.append(cs)

## A box of deck from the ground to `top` over plan rectangle `r`: boards along
## the wall on top, running round the sides.
func _deck_box(st: SurfaceTool, r: Rect2, top: float) -> void:
	var a := r.position
	var b := r.end
	var corners := [Vector2(a.x, a.y), Vector2(b.x, a.y), Vector2(b.x, b.y), Vector2(a.x, b.y)]
	for i in [0, 1, 2, 0, 2, 3]:
		var p: Vector2 = corners[i]
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(wall_x - p.x, p.y) / DECK_TILE)
		st.add_vertex(Vector3(p.x, top, p.y))
	var centre := r.get_center()
	for i in 4:
		var p0: Vector2 = corners[i]
		var p1: Vector2 = corners[(i + 1) % 4]
		var mid := (p0 + p1) / 2.0 - centre
		var n := Vector3(signf(mid.x) if absf(mid.x) > absf(mid.y) else 0.0, 0.0, signf(mid.y) if absf(mid.y) >= absf(mid.x) else 0.0)
		var quad := [[p0, 0.0], [p1, 0.0], [p1, top], [p0, top]]
		for idx in [0, 1, 2, 0, 2, 3]:
			var q: Array = quad[idx]
			var pp: Vector2 = q[0]
			st.set_normal(n)
			st.set_uv(Vector2(q[1] * 4.0, pp.x + pp.y) / DECK_TILE)
			st.add_vertex(Vector3(pp.x, q[1], pp.y))

## Weathered deck boards running along the west wall, a few millimetres apart.
static func deck_material() -> StandardMaterial3D:
	var size := 256
	var img := Image.create(size, size, true, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = 1701
	noise.frequency = 0.03
	var board_px := size / 4
	for x in size:
		var board := floori(float(x) / board_px)
		var f := float(x - board * board_px) / board_px
		var tone := 0.92 + 0.08 * sin(float(board) * 2.3)
		for y in size:
			var a := TAU * float(y) / size
			var grain := noise.get_noise_3d(float(x) * 2.0, cos(a) * 8.0, sin(a) * 8.0) * 0.12
			var shade := tone + grain
			if f < 0.04 or f > 0.97:
				shade = 0.35
			var c := DECK_COLOR * shade
			c.a = 1.0
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.roughness = 0.9
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

## The concrete: along the whole back of the House under the deck, flush with
## the Wing's west end, and on along the front of the garage. Visual only; it
## is only 5 cm proud of the ground.
func _build_pad() -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = PAD_COLOR
	m.roughness = 0.95
	for r: Rect2 in pad_rects(wall_x):
		var mesh := BoxMesh.new()
		mesh.size = Vector3(r.size.x, PAD_TOP, r.size.y)
		var mi := MeshInstance3D.new()
		mi.name = "Pad"
		_as_built.append(mi)
		mi.mesh = mesh
		mi.material_override = m
		mi.position = Vector3(r.get_center().x, PAD_TOP / 2.0, r.get_center().y)
		add_child(mi)

## The pad's rectangles in this frame's (x, z).
static func pad_rects(wall: float) -> Array[Rect2]:
	var x0 := wall - PAD_REACH
	return [
		Rect2(x0, GARAGE_SOUTH, wall - x0, CORNER_Z - GARAGE_SOUTH),
		Rect2(x0, GARAGE_NORTH, GARAGE_WEST - x0, GARAGE_SOUTH - GARAGE_NORTH),
	]

## The air-conditioner on the pad by the garage's west wall.
func _build_ac_unit() -> void:
	var at := Vector3(wall_x - 3.3, 0.0, -11.2)
	var case_mat := StandardMaterial3D.new()
	case_mat.albedo_color = Color(0.55, 0.55, 0.52)
	case_mat.roughness = 0.6
	case_mat.metallic = 0.3
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.8, 0.8, 0.8)
	var unit := MeshInstance3D.new()
	unit.name = "ACUnit"
	unit.mesh = mesh
	unit.material_override = case_mat
	unit.position = at + Vector3(0, PAD_TOP + 0.4, 0)
	add_child(unit)
	var fan := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.3
	disc.bottom_radius = 0.3
	disc.height = 0.02
	fan.mesh = disc
	var fan_mat := StandardMaterial3D.new()
	fan_mat.albedo_color = Color(0.12, 0.12, 0.12)
	fan.material_override = fan_mat
	fan.position = at + Vector3(0, PAD_TOP + 0.81, 0)
	add_child(fan)
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = unit.position
	_body.add_child(cs)

## Where the willows would stand if planted by line: evenly spaced along the L
## from the east end of the south leg, round the corner and north.
static func row_spots() -> PackedVector2Array:
	var south := ROW_EAST - ROW_WEST
	var west := ROW_Z - ROW_NORTH
	var total := south + west
	var out := PackedVector2Array()
	for i in TREES:
		var d := total * float(i) / (TREES - 1)
		if d <= south:
			out.append(Vector2(ROW_EAST - d, ROW_Z))
		else:
			out.append(Vector2(ROW_WEST, ROW_Z - (d - south)))
	return out

## The willows' trunk spots in this frame's (x, z): the row's spots, each
## nudged off it by a fixed amount (the same every run).
static func tree_spots() -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1713
	var out := row_spots()
	for i in out.size():
		out[i] += Vector2(rng.randf_range(-JITTER, JITTER), rng.randf_range(-JITTER, JITTER) * 0.7)
	return out

## The mulch bed's rectangles in this frame's (x, z): the south leg, and the
## west leg north of it.
static func bed_rects() -> Array[Rect2]:
	var h := BED_WIDTH / 2.0
	return [
		Rect2(ROW_WEST - h, ROW_Z - h, ROW_EAST - ROW_WEST + BED_WIDTH + 0.5, BED_WIDTH),
		# Overlaps the south leg at the corner (same world-mapped texture, so
		# the overlap does not show).
		Rect2(ROW_WEST - h, ROW_NORTH - h - 0.5, BED_WIDTH, ROW_Z + h - (ROW_NORTH - h - 0.5)),
	]

func _build_trees() -> void:
	var spots := tree_spots()
	for i in spots.size():
		var tree := Willow.build(1710 + i, TREE_HEIGHT * (0.9 + 0.2 * fmod(float(i) * 0.618, 1.0)))
		tree.name = "Willow%d" % (i + 1)
		tree.position = Vector3(spots[i].x, 0.0, spots[i].y)
		tree.rotation.y = float(i) * 2.4
		add_child(tree)
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(mulch_image())
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / 1.5
	m.roughness = 1.0
	for r in bed_rects():
		var mesh := BoxMesh.new()
		mesh.size = Vector3(r.size.x, BED_TOP, r.size.y)
		var mi := MeshInstance3D.new()
		mi.name = "Mulch"
		mi.mesh = mesh
		mi.material_override = m
		mi.position = Vector3(r.get_center().x, BED_TOP / 2.0, r.get_center().y)
		add_child(mi)

## Bark mulch: brown chips of a few shades, speckled, tiling.
static func mulch_image() -> Image:
	var size := 128
	var img := Image.create(size, size, true, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = 1712
	noise.frequency = 0.25
	noise.fractal_octaves = 2
	for y in size:
		for x in size:
			var a := TAU * float(x) / size
			var b := TAU * float(y) / size
			var v := noise.get_noise_3d(cos(a) * 6.0 + sin(b) * 6.0, sin(a) * 6.0, cos(b) * 6.0)
			var c := MULCH_COLOR * (0.75 + 0.6 * v)
			c.a = 1.0
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return img

## Siding on the garage's solid box and on the gable triangles.
func _dress_siding() -> void:
	var siding := Siding.material()
	var garage := get_node_or_null("../House Garage/MeshInstance3D") as MeshInstance3D
	if garage:
		garage.material_override = siding
	for gable_name in GABLES:
		var gable := get_node_or_null("../" + gable_name) as MeshInstance3D
		if gable:
			gable.material_override = siding
