extends Node3D
## The main House's ground floor (D-195), after the owner's photos taken from
## the west sliding door: an open plan with the kitchen on the left (north-west),
## the dining table on the right (south-west) under a navy accent wall, and the
## living room ahead and to the left (north-east), by the front door. A small
## pantry off the kitchen's north side has the door into the garage, where the
## bomb shelter's trap door now is (bunker.gd). The south-east corner is a
## closed, yellow-walled block for rooms not built yet.
##
## Built in the House shell's frame (building_shell.gd `frame_for`): x across
## the House, west to east (-x is west); z along it, north to south (-z is
## north); y up. The shell supplies the outside walls, windows, doors, the flat
## ceiling and the wall paint; this node adds the floors, the inside walls, the
## kitchen and a little furniture. Clutter in the photos is left out on purpose.

const Shell := preload("res://scripts/building_shell.gd")

@export var building_name := "House"

const FLOOR_Y := Shell.FLOOR_TOP
## Height of the inside walls: the House box's height, up to the flat ceiling.
const WALL_H := 2.68
const WALL_T := 0.12
const COUNTER_H := 0.91
const BASE_D := 0.6
const UPPER_D := 0.33
const UPPER_Y0 := 1.45
const UPPER_Y1 := 2.2

## Areas (Rect2 in x, z). The kitchen's tile runs to the end of the peninsula.
const KITCHEN := Rect2(-5.52, -7.145, 5.64, 5.245)
## The pantry's outside walls; its doorway faces the kitchen, and the shell's
## north wall door at x -3.25 leads into the garage.
const PANTRY := Rect2(-4.25, -7.145, 2.0, 1.845)
const PANTRY_DOOR_X := -3.25
const PANTRY_DOOR_W := 0.85
## The wall between the kitchen and the living room.
const PARTITION_X := 0.12
const PARTITION_Z1 := -3.3
## The closed block in the south-east corner.
const BLOCK := Rect2(0.3, 3.4, 5.22, 3.745)
const DINING_TABLE := Vector3(-2.7, 0.0, 5.3)

const GREEN := Color(0.56, 0.66, 0.2)
const YELLOW := Color(0.93, 0.8, 0.33)
const CREAM := Color(0.93, 0.89, 0.74)

var _body: StaticBody3D
var _mats := {}

func _ready() -> void:
	var box := get_node_or_null("../" + building_name) as Node3D
	if box == null:
		push_warning("house_interior: no building named '%s'" % building_name)
		return
	global_transform = Shell.frame_for(box)
	_make_materials()
	_body = StaticBody3D.new()
	_body.name = "Walls"
	add_child(_body)
	_build_floors()
	_build_walls()
	_build_kitchen()
	_build_pantry()
	_build_dining()
	_build_living()
	_build_entry()

# --- materials -------------------------------------------------------------

func _make_materials() -> void:
	_mats.green = _mat(GREEN, 0.85)
	_mats.yellow = _mat(YELLOW, 0.85)
	_mats.cream = _mat(CREAM, 0.85)
	_mats.oak = _mat(Color(0.74, 0.5, 0.24), 0.6)
	_mats.counter = _mat(Color(0.9, 0.87, 0.77), 0.4)
	_mats.black = _mat(Color(0.05, 0.05, 0.06), 0.3, 0.2)
	_mats.steel = _mat(Color(0.7, 0.71, 0.72), 0.3, 0.8)
	_mats.white = _mat(Color(0.95, 0.95, 0.93), 0.3)
	_mats.dark_wood = _mat(Color(0.2, 0.12, 0.08), 0.6)
	_mats.chest = _mat(Color(0.62, 0.38, 0.2), 0.7)
	_mats.leather = _mat(Color(0.25, 0.18, 0.14), 0.55)
	_mats.futon = _mat(Color(0.62, 0.68, 0.72), 0.95)
	_mats.rug = _mat(Color(0.9, 0.86, 0.74), 1.0)
	_mats.rug_border = _mat(Color(0.25, 0.35, 0.55), 1.0)
	_mats.mat = _mat(Color(0.23, 0.19, 0.16), 1.0)
	_mats.stool = _mat(Color(0.48, 0.6, 0.38), 0.6)
	_mats.screen = _mat(Color(0.02, 0.02, 0.03), 0.15, 0.3)
	_mats.dresser = _mat(Color(0.12, 0.12, 0.13), 0.6)
	_mats.shelf = _mat(Color(0.85, 0.8, 0.68), 0.7)
	_mats.wood_floor = _floor_mat(wood_texture(), Vector2(1.0 / 1.2, 1.0 / 2.4))
	_mats.tile_floor = _floor_mat(tile_texture(), Vector2(1.0 / 0.9, 1.0 / 0.9))

func _mat(color: Color, roughness: float, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m

## A floor material mapped in this node's space (triplanar), so a tile is the
## same size on any patch of floor: `scale` is tiles per metre in x and z.
func _floor_mat(tex: Texture2D, scale: Vector2) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(scale.x, 1.0, scale.y)
	m.roughness = 0.45
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

## Honey-coloured laminate planks running east to west (along x), as in the
## photos: one texture is 1.2 m by 2.4 m, six 0.2 m boards with staggered
## end joints, a dark seam round each and a little grain.
static func wood_texture() -> ImageTexture:
	var w := 192
	var h := 384
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1880
	var rows := 12  # boards across the 2.4 m (z) side, 0.2 m each
	var row_h := h / rows
	var base := Color(0.72, 0.44, 0.25)
	var shades: Array[float] = []
	var joints: Array[int] = []
	for r in rows:
		shades.append(rng.randf_range(-0.07, 0.07))
		joints.append(rng.randi_range(0, w - 1))
	for y in h:
		var r := y / row_h
		var in_row := y % row_h
		for x in w:
			var c := base.lightened(shades[r]) if shades[r] > 0.0 else base.darkened(-shades[r])
			# Grain: soft stripes along the board.
			var g := sin(float(x) * 0.09 + float(in_row) * 0.9 + float(r) * 3.0) * 0.5 + 0.5
			c = c.darkened(g * 0.08)
			if in_row == 0 or absi(x - joints[r]) < 1:
				c = c.darkened(0.45)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

## The kitchen's square tiles: beige and brown in a checker, 0.45 m each with
## thin grout lines; one texture is 2 x 2 tiles.
static func tile_texture() -> ImageTexture:
	var n := 256
	var half := n / 2
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var light := Color(0.86, 0.78, 0.62)
	var dark := Color(0.55, 0.4, 0.24)
	var grout := Color(0.7, 0.66, 0.58)
	for y in n:
		for x in n:
			var c := light if ((x / half) + (y / half)) % 2 == 0 else dark
			var gx := x % half
			var gy := y % half
			if gx < 2 or gy < 2:
				c = grout
			else:
				var mottle := sin(float(x) * 0.31) * sin(float(y) * 0.27)
				c = c.darkened(0.04 * (mottle + 1.0))
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# --- floors and walls --------------------------------------------------------

func _build_floors() -> void:
	var inner := Rect2(-5.52, -7.145, 11.04, 14.29)
	_floor_patch(inner, FLOOR_Y + 0.002, _mats.wood_floor, "WoodFloor")
	_floor_patch(KITCHEN, FLOOR_Y + 0.004, _mats.tile_floor, "TileFloor")

func _floor_patch(r: Rect2, y: float, mat: Material, node_name: String) -> void:
	var mesh := PlaneMesh.new()
	mesh.size = r.size
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = Vector3(r.get_center().x, y, r.get_center().y)
	add_child(mi)

func _build_walls() -> void:
	# Kitchen | living room: green both sides, from the north wall to the end
	# of the kitchen's east counter.
	_wall_z(PARTITION_X, -7.145, PARTITION_Z1, _mats.green)
	# The south-east block: one closed, yellow-walled mass.
	_add_box(Vector3(BLOCK.get_center().x, FLOOR_Y + WALL_H / 2.0, BLOCK.get_center().y),
			Vector3(BLOCK.size.x, WALL_H, BLOCK.size.y), _mats.yellow, true, "SouthEastBlock")

## A wall running along z at x, from z0 to z1.
func _wall_z(x: float, z0: float, z1: float, mat: Material) -> void:
	_add_box(Vector3(x, FLOOR_Y + WALL_H / 2.0, (z0 + z1) / 2.0), Vector3(WALL_T, WALL_H, absf(z1 - z0)), mat, true)

## A wall running along x at z, from x0 to x1, with a doorway (centre, width,
## 2.05 m high) when `door_w` > 0.
func _wall_x(z: float, x0: float, x1: float, mat: Material, door_x := 0.0, door_w := 0.0) -> void:
	if door_w <= 0.0:
		_add_box(Vector3((x0 + x1) / 2.0, FLOOR_Y + WALL_H / 2.0, z), Vector3(x1 - x0, WALL_H, WALL_T), mat, true)
		return
	var a := door_x - door_w / 2.0
	var b := door_x + door_w / 2.0
	_wall_x(z, x0, a, mat)
	_wall_x(z, b, x1, mat)
	var head := 2.05
	_add_box(Vector3(door_x, FLOOR_Y + (head + WALL_H) / 2.0, z), Vector3(door_w, WALL_H - head, WALL_T), mat, true)
	# Oak casing round the opening on both faces.
	for side in [-1.0, 1.0]:
		var face: float = z + side * (WALL_T / 2.0 + 0.01)
		for jamb in [a - 0.04, b + 0.04]:
			_add_box(Vector3(jamb, FLOOR_Y + head / 2.0, face), Vector3(0.08, head, 0.02), _mats.oak, false)
		_add_box(Vector3(door_x, FLOOR_Y + head + 0.04, face), Vector3(door_w + 0.16, 0.08, 0.02), _mats.oak, false)

# --- kitchen ---------------------------------------------------------------

## The west wall's windows, as z ranges, so the upper cabinets stop at them.
const WEST_WINDOWS := [Vector2(-6.5, -5.48), Vector2(-4.68, -3.6)]
const STOVE_Z := -2.5
const SINK_Z := -4.14

func _build_kitchen() -> void:
	var x_west := -5.52
	var west_end := -1.75
	# West run: oak base cabinets and counter from the north wall to the slider.
	_base_run(Rect2(x_west, -7.145, BASE_D, west_end + 7.145), [Vector2(STOVE_Z - 0.38, STOVE_Z + 0.38)])
	# Stove: a black range with a glass top, and a steel hood over it.
	var sx := x_west + BASE_D / 2.0
	_add_box(Vector3(sx, FLOOR_Y + COUNTER_H / 2.0, STOVE_Z), Vector3(BASE_D, COUNTER_H, 0.76), _mats.black, true, "Stove")
	_add_box(Vector3(x_west + 0.25, FLOOR_Y + 1.62, STOVE_Z), Vector3(0.5, 0.14, 0.76), _mats.steel, false, "RangeHood")
	_add_box(Vector3(x_west + 0.17, FLOOR_Y + 1.92, STOVE_Z), Vector3(UPPER_D, 0.46, 0.76), _mats.oak, false)
	# Sink under the second window: a white basin set into the counter.
	_add_box(Vector3(sx + 0.05, FLOOR_Y + COUNTER_H + 0.012, SINK_Z), Vector3(0.42, 0.02, 0.75), _mats.white, false, "Sink")
	_add_box(Vector3(x_west + 0.08, FLOOR_Y + COUNTER_H + 0.15, SINK_Z), Vector3(0.04, 0.3, 0.04), _mats.steel, false)
	# Uppers along the west wall, stopping at the windows and the hood.
	var stops: Array = WEST_WINDOWS.duplicate()
	stops.append(Vector2(STOVE_Z - 0.38, STOVE_Z + 0.38))
	_uppers_along_z(x_west, -7.145, west_end, stops)
	# North-west corner, west of the pantry.
	_base_run(Rect2(x_west + BASE_D, -7.145, PANTRY.position.x - x_west - BASE_D, BASE_D), [])
	_add_box(Vector3((x_west + BASE_D + PANTRY.position.x) / 2.0, FLOOR_Y + (UPPER_Y0 + UPPER_Y1) / 2.0, -7.145 + UPPER_D / 2.0),
			Vector3(PANTRY.position.x - x_west - BASE_D, UPPER_Y1 - UPPER_Y0, UPPER_D), _mats.oak, true)
	# East of the pantry: the fridge, then a corner counter with a microwave.
	var fx0 := PANTRY.end.x + 0.05
	_add_box(Vector3(fx0 + 0.45, FLOOR_Y + 0.89, -7.145 + 0.38), Vector3(0.9, 1.78, 0.76), _mats.black, true, "Fridge")
	_add_box(Vector3(fx0 + 0.45, FLOOR_Y + 2.05, -7.145 + 0.3), Vector3(0.9, 0.36, 0.6), _mats.oak, true)
	var east_face := PARTITION_X - WALL_T / 2.0
	var cx0 := fx0 + 0.95
	_base_run(Rect2(cx0, -7.145, east_face - cx0, BASE_D), [])
	_add_box(Vector3(cx0 + 0.35, FLOOR_Y + COUNTER_H + 0.16, -7.145 + 0.25), Vector3(0.5, 0.3, 0.38), _mats.steel, false, "Microwave")
	_add_box(Vector3((cx0 + east_face) / 2.0, FLOOR_Y + (UPPER_Y0 + UPPER_Y1) / 2.0, -7.145 + UPPER_D / 2.0),
			Vector3(east_face - cx0, UPPER_Y1 - UPPER_Y0, UPPER_D), _mats.oak, true)
	# East run along the partition, carrying on past its end as the peninsula.
	var px := east_face - BASE_D
	_base_run(Rect2(px, -7.145 + BASE_D, BASE_D, KITCHEN.end.y - 0.05 - (-7.145 + BASE_D)), [])
	_add_box(Vector3(east_face - UPPER_D / 2.0, FLOOR_Y + (UPPER_Y0 + UPPER_Y1) / 2.0, (-7.145 + BASE_D + PARTITION_Z1) / 2.0),
			Vector3(UPPER_D, UPPER_Y1 - UPPER_Y0, PARTITION_Z1 + 7.145 - BASE_D), _mats.oak, true)
	# The peninsula's open end gets an oak back panel on the living side.
	_add_box(Vector3(east_face + 0.01, FLOOR_Y + COUNTER_H / 2.0, (PARTITION_Z1 + KITCHEN.end.y - 0.05) / 2.0),
			Vector3(0.02, COUNTER_H, KITCHEN.end.y - 0.05 - PARTITION_Z1), _mats.oak, false)
	# One stool at the peninsula's end, as in the photos.
	_stool(Vector3(east_face + 0.35, FLOOR_Y, KITCHEN.end.y - 0.45))

## Base cabinets with a counter on top over `r`, leaving gaps (z ranges, for
## an appliance) where listed. Doors are suggested by a darker kick strip.
func _base_run(r: Rect2, gaps: Array) -> void:
	var along_z := r.size.y > r.size.x
	var spans: Array = [Vector2(r.position.y, r.end.y)] if along_z else [Vector2(r.position.x, r.end.x)]
	for g: Vector2 in gaps:
		var next: Array = []
		for s: Vector2 in spans:
			if g.y <= s.x or g.x >= s.y:
				next.append(s)
				continue
			if g.x > s.x:
				next.append(Vector2(s.x, g.x))
			if g.y < s.y:
				next.append(Vector2(g.y, s.y))
		spans = next
	for s: Vector2 in spans:
		var span := s.y - s.x
		if span < 0.05:
			continue
		var mid := (s.x + s.y) / 2.0
		var c := Vector3(r.get_center().x, 0.0, mid) if along_z else Vector3(mid, 0.0, r.get_center().y)
		var size := Vector3(r.size.x, 0.0, span) if along_z else Vector3(span, 0.0, r.size.y)
		_add_box(c + Vector3(0, FLOOR_Y + (COUNTER_H - 0.04) / 2.0, 0), size + Vector3(0, COUNTER_H - 0.04, 0), _mats.oak, true)
		_add_box(c + Vector3(0, FLOOR_Y + COUNTER_H - 0.02, 0), size + Vector3(0.03, 0.04, 0.03), _mats.counter, false)

## Upper cabinets on a wall running along z at `x` (its inside face), from z0
## to z1, leaving out the `stops` (z ranges).
func _uppers_along_z(x: float, z0: float, z1: float, stops: Array) -> void:
	var cursor := z0
	var sorted := stops.duplicate()
	sorted.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	for s: Vector2 in sorted + [Vector2(z1, z1)]:
		var end := minf(s.x, z1)
		if end - cursor > 0.25:
			_add_box(Vector3(x + UPPER_D / 2.0, FLOOR_Y + (UPPER_Y0 + UPPER_Y1) / 2.0, (cursor + end) / 2.0),
					Vector3(UPPER_D, UPPER_Y1 - UPPER_Y0, end - cursor), _mats.oak, true)
		cursor = maxf(cursor, s.y)

func _stool(base: Vector3) -> void:
	_add_box(base + Vector3(0, 0.66, 0), Vector3(0.4, 0.05, 0.4), _mats.dark_wood, false, "Stool")
	for dx in [-0.16, 0.16]:
		for dz in [-0.16, 0.16]:
			_add_box(base + Vector3(dx, 0.32, dz), Vector3(0.04, 0.64, 0.04), _mats.stool, false)
	for dz in [-0.16, 0.16]:
		_add_box(base + Vector3(0, 0.22, dz), Vector3(0.32, 0.03, 0.03), _mats.stool, false)
	_add_collider(base + Vector3(0, 0.35, 0), Vector3(0.4, 0.7, 0.4))

# --- pantry ----------------------------------------------------------------

func _build_pantry() -> void:
	var p := PANTRY
	# Its west and east walls and the kitchen-side wall with the doorway.
	# Green on the kitchen side, cream inside.
	_wall_z(p.position.x + WALL_T / 2.0, -7.145, p.end.y, _mats.green)
	_wall_z(p.end.x - WALL_T / 2.0, -7.145, p.end.y, _mats.green)
	_wall_x(p.end.y - WALL_T / 2.0, p.position.x, p.end.x, _mats.green, PANTRY_DOOR_X, PANTRY_DOOR_W)
	var coat := 0.004
	var depth := p.end.y - WALL_T + 7.145
	var mid_z := (-7.145 + p.end.y - WALL_T) / 2.0
	_add_box(Vector3(p.position.x + WALL_T + coat / 2.0, FLOOR_Y + WALL_H / 2.0, mid_z), Vector3(coat, WALL_H, depth), _mats.cream, false)
	_add_box(Vector3(p.end.x - WALL_T - coat / 2.0, FLOOR_Y + WALL_H / 2.0, mid_z), Vector3(coat, WALL_H, depth), _mats.cream, false)
	var face := p.end.y - WALL_T - coat / 2.0
	var a := PANTRY_DOOR_X - PANTRY_DOOR_W / 2.0
	var b := PANTRY_DOOR_X + PANTRY_DOOR_W / 2.0
	var x0 := p.position.x + WALL_T
	var x1 := p.end.x - WALL_T
	_add_box(Vector3((x0 + a) / 2.0, FLOOR_Y + WALL_H / 2.0, face), Vector3(a - x0, WALL_H, coat), _mats.cream, false)
	_add_box(Vector3((b + x1) / 2.0, FLOOR_Y + WALL_H / 2.0, face), Vector3(x1 - b, WALL_H, coat), _mats.cream, false)
	_add_box(Vector3(PANTRY_DOOR_X, FLOOR_Y + (2.05 + WALL_H) / 2.0, face), Vector3(PANTRY_DOOR_W, WALL_H - 2.05, coat), _mats.cream, false)
	# Shelves down both sides, leaving the walk to the garage door clear.
	var z0 := -7.145 + 0.05
	var z1 := p.end.y - WALL_T - 0.05
	for side in [[x0, 1.0], [x1, -1.0]]:
		var wall_x: float = side[0]
		var dir: float = side[1]
		var shelf_d := 0.32
		var cx := wall_x + dir * shelf_d / 2.0
		for k in 5:
			_add_box(Vector3(cx, FLOOR_Y + 0.15 + k * 0.45, (z0 + z1) / 2.0), Vector3(shelf_d, 0.025, z1 - z0), _mats.shelf, false)
		for z in [z0 + 0.02, z1 - 0.02]:
			_add_box(Vector3(cx, FLOOR_Y + 1.05, z), Vector3(shelf_d, 2.1, 0.03), _mats.shelf, false)
		_add_collider(Vector3(cx, FLOOR_Y + 1.05, (z0 + z1) / 2.0), Vector3(shelf_d, 2.1, z1 - z0))

# --- dining ----------------------------------------------------------------

func _build_dining() -> void:
	var t := DINING_TABLE
	var top := Vector2(1.8, 0.95)
	_add_box(t + Vector3(0, FLOOR_Y + 0.74, 0), Vector3(top.x, 0.04, top.y), _mats.dark_wood, false, "DiningTable")
	for dx in [-0.8, 0.8]:
		for dz in [-0.38, 0.38]:
			_add_box(t + Vector3(dx, FLOOR_Y + 0.36, dz), Vector3(0.07, 0.72, 0.07), _mats.dark_wood, false)
	_add_collider(t + Vector3(0, FLOOR_Y + 0.38, 0), Vector3(top.x, 0.76, top.y))
	# Four chairs, two along each long side, facing the table.
	for dx in [-0.45, 0.45]:
		for side in [-1.0, 1.0]:
			_chair(t + Vector3(dx, FLOOR_Y, side * 0.72), side)
	# A pendant over the table.
	var lamp_y := Shell.FLOOR_TOP + WALL_H - 0.02
	_add_box(t + Vector3(0, lamp_y - 0.35, 0), Vector3(0.015, 0.7, 0.015), _mats.black, false)
	_add_box(t + Vector3(0, lamp_y - 0.8, 0), Vector3(0.5, 0.2, 0.5), _mats.black, false, "Pendant")

## A dark X-back chair; `side` +1 sits south of the table, facing north.
func _chair(base: Vector3, side: float) -> void:
	_add_box(base + Vector3(0, 0.46, 0), Vector3(0.44, 0.04, 0.42), _mats.dark_wood, false, "Chair")
	for dx in [-0.19, 0.19]:
		for dz in [-0.18, 0.18]:
			_add_box(base + Vector3(dx, 0.23, dz), Vector3(0.04, 0.46, 0.04), _mats.dark_wood, false)
	var back_z := side * 0.19
	for dx in [-0.19, 0.19]:
		_add_box(base + Vector3(dx, 0.7, back_z), Vector3(0.04, 0.48, 0.04), _mats.dark_wood, false)
	_add_box(base + Vector3(0, 0.92, back_z), Vector3(0.42, 0.05, 0.04), _mats.dark_wood, false)
	for tilt in [-1.0, 1.0]:
		var bar := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.5, 0.03, 0.02)
		bar.mesh = mesh
		bar.material_override = _mats.dark_wood
		bar.position = base + Vector3(0, 0.69, back_z)
		bar.rotation.z = tilt * 0.75
		add_child(bar)
	_add_collider(base + Vector3(0, 0.25, 0), Vector3(0.44, 0.5, 0.42))

# --- living room -------------------------------------------------------------

func _build_living() -> void:
	# The rug and a cedar chest for a coffee table.
	var rug := Rect2(1.6, -5.9, 2.6, 3.4)
	_add_box(Vector3(rug.get_center().x, FLOOR_Y + 0.008, rug.get_center().y), Vector3(rug.size.x, 0.012, rug.size.y), _mats.rug_border, false, "Rug")
	_add_box(Vector3(rug.get_center().x, FLOOR_Y + 0.01, rug.get_center().y), Vector3(rug.size.x - 0.3, 0.012, rug.size.y - 0.3), _mats.rug, false)
	_add_box(Vector3(rug.get_center().x, FLOOR_Y + 0.22, rug.get_center().y), Vector3(0.6, 0.44, 1.1), _mats.chest, true, "Chest")
	# A brown leather sofa against the partition, facing east to the TV.
	var sx := PARTITION_X + WALL_T / 2.0
	var sofa := Rect2(sx, -6.1, 0.92, 2.3)
	_add_box(Vector3(sofa.get_center().x, FLOOR_Y + 0.22, sofa.get_center().y), Vector3(sofa.size.x, 0.44, sofa.size.y), _mats.leather, true, "Sofa")
	_add_box(Vector3(sx + 0.12, FLOOR_Y + 0.6, sofa.get_center().y), Vector3(0.24, 0.5, sofa.size.y), _mats.leather, false)
	for z in [sofa.position.y + 0.12, sofa.end.y - 0.12]:
		_add_box(Vector3(sofa.get_center().x, FLOOR_Y + 0.55, z), Vector3(sofa.size.x, 0.25, 0.24), _mats.leather, false)
	# A futon under the north window.
	var fut := Rect2(2.0, -7.145 + 0.05, 1.9, 0.85)
	_add_box(Vector3(fut.get_center().x, FLOOR_Y + 0.25, fut.get_center().y), Vector3(fut.size.x, 0.3, fut.size.y), _mats.futon, true, "Futon")
	_add_box(Vector3(fut.get_center().x, FLOOR_Y + 0.5, fut.position.y + 0.1), Vector3(fut.size.x, 0.5, 0.2), _mats.futon, false)
	_add_box(Vector3(fut.get_center().x, FLOOR_Y + 0.05, fut.get_center().y), Vector3(fut.size.x + 0.1, 0.1, fut.size.y), _mats.chest, false)
	# A dresser on the east wall between the windows, with the TV on it.
	var dz := -2.95
	var dx := 5.52 - 0.25
	_add_box(Vector3(dx, FLOOR_Y + 0.42, dz), Vector3(0.48, 0.84, 1.3), _mats.dresser, true, "Dresser")
	_add_box(Vector3(dx - 0.245, FLOOR_Y + 0.42, dz), Vector3(0.01, 0.72, 1.2), _mats.chest, false)
	_add_box(Vector3(dx + 0.05, FLOOR_Y + 0.86, dz), Vector3(0.22, 0.04, 0.3), _mats.black, false)
	_add_box(Vector3(dx + 0.05, FLOOR_Y + 1.2, dz), Vector3(0.05, 0.64, 1.1), _mats.screen, false, "TV")

# --- entry -------------------------------------------------------------------

func _build_entry() -> void:
	# Mats inside the front door and the sliding door.
	_add_box(Vector3(4.85, FLOOR_Y + 0.008, 2.0), Vector3(0.9, 0.012, 1.4), _mats.mat, false, "FrontMat")
	_add_box(Vector3(-4.4, FLOOR_Y + 0.008, -0.3), Vector3(1.5, 0.012, 0.75), _mats.mat, false, "SliderMat")

# --- helpers ---------------------------------------------------------------

func _add_box(pos: Vector3, size: Vector3, material: Material, collide: bool, node_name := "") -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	if node_name != "":
		mi.name = node_name
	add_child(mi)
	if collide:
		_add_collider(pos, size)

func _add_collider(pos: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = pos
	_body.add_child(cs)
