extends Node3D
## The little grey shed at the north-west corner of the back yard (D-193),
## after the owner's photos (Downloads/SHed): weathered horizontal boards, a
## steep shingled roof with a small overhang, a red door with white trim in the
## east gable end, and a low weathered deck in front of the door. A simple
## version: closed up and solid, no interior.
##
## The node's origin is the middle of the floor on the ground; local +X is the
## door end (east in the world as placed) and the ridge runs along X. Roof and
## wall textures are made here and mapped by world position so the boards and
## shingles keep their size.

## Plan size, metres: LENGTH along the ridge (gable to gable), WIDTH across it.
const LENGTH := 2.7
const WIDTH := 2.3
const WALL_HEIGHT := 1.9
const RIDGE_HEIGHT := 3.0
const OVERHANG := 0.3
## The deck in front of the door: how far it reaches, and how high it stands.
const DECK_REACH := 1.7
const DECK_WIDTH := 2.2
const DECK_HEIGHT := 0.2
## How far past the deck the walkable slope runs down to the ground.
const DECK_SLOPE := 0.5
const DOOR_WIDTH := 0.9
const DOOR_HEIGHT := 1.75
## The door's centre across the gable, a little off the middle as in the photo.
const DOOR_OFFSET := 0.15

## Where the shed stands in the world (x, z): in the yard's north-west corner,
## about a metre inside the north and west fences, door to the east. The
## birches (back_yard_birches.gd) run south from it along the west side.
const SPOT := Vector2(19.4, -47.9)

const BOARD_COLOR := Color(0.55, 0.52, 0.47)
const DECK_COLOR := Color(0.40, 0.38, 0.35)
const SHINGLE_COLOR := Color(0.42, 0.37, 0.31)
const DOOR_COLOR := Color(0.72, 0.1, 0.09)
const TRIM_COLOR := Color(0.86, 0.85, 0.8)
## One tile of board or shingle texture covers this many metres.
const TILE := 0.9

static var _board_image: Image
static var _shingle_image: Image

func _ready() -> void:
	_build_walls()
	_build_roof()
	_build_door()
	_build_deck()

func _build_walls() -> void:
	var mat := board_material(BOARD_COLOR)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(LENGTH, WALL_HEIGHT, WIDTH)
	var walls := MeshInstance3D.new()
	walls.name = "Walls"
	walls.mesh = mesh
	walls.material_override = mat
	walls.position.y = WALL_HEIGHT / 2.0
	add_child(walls)
	# The gable triangles, one on each end.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for sx in [1.0, -1.0]:
		var hx: float = sx * LENGTH / 2.0
		var tri := [Vector3(hx, WALL_HEIGHT, -WIDTH / 2.0), Vector3(hx, WALL_HEIGHT, WIDTH / 2.0), Vector3(hx, RIDGE_HEIGHT, 0)]
		var order := [0, 1, 2] if sx > 0.0 else [1, 0, 2]
		for i in order:
			st.set_normal(Vector3(sx, 0, 0))
			st.add_vertex(tri[i])
	var gables := MeshInstance3D.new()
	gables.name = "Gables"
	gables.mesh = st.commit()
	gables.material_override = mat
	add_child(gables)
	# One solid block, walls to the ridge (the roof is not solid).
	var body := StaticBody3D.new()
	body.name = "Body"
	var shape := BoxShape3D.new()
	shape.size = Vector3(LENGTH, RIDGE_HEIGHT, WIDTH)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = RIDGE_HEIGHT / 2.0
	body.add_child(cs)
	add_child(body)

## Two shingled planes meeting at the ridge, reaching OVERHANG past the walls
## on all sides; seen from both sides.
func _build_roof() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hx := LENGTH / 2.0 + OVERHANG
	var half := WIDTH / 2.0 + OVERHANG
	# The slope's height drop over its horizontal reach, from the ridge.
	var drop := (RIDGE_HEIGHT - WALL_HEIGHT) * half / (WIDTH / 2.0)
	for sz in [1.0, -1.0]:
		var a := Vector3(-hx, RIDGE_HEIGHT, 0)
		var b := Vector3(hx, RIDGE_HEIGHT, 0)
		var c := Vector3(hx, RIDGE_HEIGHT - drop, sz * half)
		var d := Vector3(-hx, RIDGE_HEIGHT - drop, sz * half)
		var normal := (Vector3(0, half, sz * drop)).normalized()
		var slope := Vector2(2.0 * hx, Vector3(0, drop, half).length()) / TILE
		var uv := [Vector2(0, 0), Vector2(slope.x, 0), Vector2(slope.x, slope.y), Vector2(0, slope.y)]
		var quad := [a, b, c, d]
		for i in ([0, 2, 1, 0, 3, 2] if sz > 0.0 else [0, 1, 2, 0, 2, 3]):
			st.set_normal(normal)
			st.set_uv(uv[i])
			st.add_vertex(quad[i])
	var mi := MeshInstance3D.new()
	mi.name = "Roof"
	mi.mesh = st.commit()
	mi.material_override = shingle_material()
	add_child(mi)

## The red door in the east gable with white trim round it.
func _build_door() -> void:
	var x := LENGTH / 2.0
	var z := DOOR_OFFSET
	_slab("Door", Vector3(0.05, DOOR_HEIGHT, DOOR_WIDTH), Vector3(x + 0.02, DOOR_HEIGHT / 2.0, z), DOOR_COLOR)
	var t := 0.09
	_slab("TrimTop", Vector3(0.07, t, DOOR_WIDTH + 2.0 * t), Vector3(x + 0.025, DOOR_HEIGHT + t / 2.0, z), TRIM_COLOR)
	for s in [-1.0, 1.0]:
		_slab("TrimSide", Vector3(0.07, DOOR_HEIGHT + t, t), Vector3(x + 0.025, (DOOR_HEIGHT + t) / 2.0, z + s * (DOOR_WIDTH + t) / 2.0), TRIM_COLOR)
	_slab("Handle", Vector3(0.08, 0.12, 0.03), Vector3(x + 0.06, 0.95, z - DOOR_WIDTH * 0.32), Color(0.15, 0.14, 0.13))

func _slab(label: String, size: Vector3, at: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	var mi := MeshInstance3D.new()
	mi.name = label
	mi.mesh = mesh
	mi.material_override = m
	mi.position = at
	add_child(mi)

## The low deck in front of the door, with a ramp-shaped hull from its top
## edge down to the ground so the player walks up instead of being stopped by
## its front.
func _build_deck() -> void:
	var x0 := LENGTH / 2.0
	var mesh := BoxMesh.new()
	mesh.size = Vector3(DECK_REACH, DECK_HEIGHT, DECK_WIDTH)
	var mi := MeshInstance3D.new()
	mi.name = "Deck"
	mi.mesh = mesh
	mi.material_override = board_material(DECK_COLOR)
	mi.position = Vector3(x0 + DECK_REACH / 2.0, DECK_HEIGHT / 2.0, 0)
	add_child(mi)
	var hw := DECK_WIDTH / 2.0
	var x1 := x0 + DECK_REACH
	var shape := ConvexPolygonShape3D.new()
	shape.points = PackedVector3Array([
		Vector3(x0, DECK_HEIGHT, -hw), Vector3(x1, DECK_HEIGHT, -hw), Vector3(x0, DECK_HEIGHT, hw), Vector3(x1, DECK_HEIGHT, hw),
		Vector3(x0, 0, -hw), Vector3(x1 + DECK_SLOPE, 0, -hw), Vector3(x0, 0, hw), Vector3(x1 + DECK_SLOPE, 0, hw)])
	var cs := CollisionShape3D.new()
	cs.name = "DeckHull"
	cs.shape = shape
	($Body as StaticBody3D).add_child(cs)

## Triplanar, world-mapped board material, `color` over the texture.
static func board_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(board_texture())
	m.albedo_color = color
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / TILE
	m.roughness = 0.95
	return m

static func shingle_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(shingle_texture())
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.95
	return m

## Six grey boards one above another, each a different weathered tone with
## grain, and a dark seam between. Tiles.
static func board_texture() -> Image:
	if _board_image:
		return _board_image
	var size := 64
	var img := Image.create(size, size, true, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = 193
	noise.frequency = 0.04
	var rng := RandomNumberGenerator.new()
	rng.seed = 1931
	var rows := 6
	var per := size / rows + 1
	var tone: Array[float] = []
	for r in rows + 1:
		tone.append(rng.randf_range(0.78, 1.12))
	for y in size:
		var r := mini(y * rows / size, rows - 1)
		var edge := (y * rows) % size
		for x in size:
			# Grain runs along the board; it wraps in x so the tile joins.
			var a := TAU * float(x) / size
			var v := noise.get_noise_3d(cos(a) * 12.0, sin(a) * 12.0, y * 2.5)
			var c := tone[r] * (0.9 + 0.3 * v)
			if edge < rows:
				c *= 0.45
			img.set_pixel(x, y, Color(c, c * 0.97, c * 0.92, 1.0))
	img.generate_mipmaps()
	_board_image = img
	return img

## Rows of asphalt shingles, staggered, grey-brown with a few darker and
## mossier ones. Tiles.
static func shingle_texture() -> Image:
	if _shingle_image:
		return _shingle_image
	var size := 64
	var img := Image.create(size, size, true, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1932
	var rows := 8
	var cols := 4
	var rh := size / rows
	var cw := size / cols
	for r in rows:
		var shift := (r % 2) * cw / 2
		for k in cols:
			var tone := rng.randf_range(0.7, 1.15)
			var moss := rng.randf() < 0.18
			var base := SHINGLE_COLOR * tone
			if moss:
				base = base.lerp(Color(0.3, 0.36, 0.2), 0.5)
			for y in rh:
				for x in cw:
					var px := (k * cw + x + shift) % size
					var c := base
					if y == rh - 1 or x == 0:
						c = c * 0.55
					elif y >= rh - 3:
						c = c * 0.85
					c.a = 1.0
					img.set_pixel(px, r * rh + y, c)
	img.generate_mipmaps()
	_shingle_image = img
	return img
