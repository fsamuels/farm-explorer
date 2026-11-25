extends RefCounted
## Building blocks for the back-yard mockups (backyard_mockups.gd):
## hot tubs, fire tables, pavilions, outdoor kitchens, saunas, seating, paving
## and the like, all from primitives. Every builder takes the Node3D to put
## the pieces under and, for solid things, the StaticBody3D to put their
## collision in. Positions are in that parent's frame (the House's frame in
## the mockups: +x east-ish, +z south-ish, y up from the ground).

const FIRE_COLOR := Color(1.0, 0.55, 0.15)

# Colours used across the mockups.
const CEDAR := Color(0.62, 0.40, 0.25)
const CEDAR_DARK := Color(0.42, 0.27, 0.17)
const CHARCOAL := Color(0.16, 0.16, 0.17)
const STEEL := Color(0.72, 0.73, 0.74)
const CONCRETE := Color(0.66, 0.65, 0.62)
const STONE := Color(0.50, 0.48, 0.45)
const SLATE := Color(0.30, 0.31, 0.33)
const WHITE := Color(0.93, 0.93, 0.91)
const CUSHION := Color(0.80, 0.77, 0.70)
const WATER := Color(0.25, 0.62, 0.78, 0.75)
const GREEN := Color(0.30, 0.48, 0.22)

static var _materials := {}

## A shared plain material (opaque, or alpha-blended when `color.a` < 1).
static func mat(color: Color, roughness := 0.85, metallic := 0.0, emission := 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%.2f" % [color.to_html(), roughness, metallic, emission]
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = roughness
		m.metallic = metallic
		if color.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		if emission > 0.0:
			m.emission_enabled = true
			m.emission = Color(color.r, color.g, color.b)
			m.emission_energy_multiplier = emission
		_materials[key] = m
	return _materials[key]

## A paving material: square units `unit` metres with dark joints, mapped in
## world space so it lines up across pieces.
static func paving(color: Color, unit := 0.6, key := "") -> StandardMaterial3D:
	var k := "pave|%s|%.2f|%s" % [color.to_html(), unit, key]
	if not _materials.has(k):
		var size := 64
		var img := Image.create(size, size, true, Image.FORMAT_RGB8)
		var noise := FastNoiseLite.new()
		noise.frequency = 0.15
		for y in size:
			for x in size:
				var c := color * (0.92 + 0.12 * noise.get_noise_2d(x, y))
				if x < 2 or y < 2:
					c = color * 0.55
				c.a = 1.0
				img.set_pixel(x, y, c)
		img.generate_mipmaps()
		var m := StandardMaterial3D.new()
		m.albedo_texture = ImageTexture.create_from_image(img)
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE / unit
		m.roughness = 0.9
		_materials[k] = m
	return _materials[k]

## Boards: like paving but long and narrow (decking), along local x.
static func boards(color: Color) -> StandardMaterial3D:
	var k := "boards|%s" % color.to_html()
	if not _materials.has(k):
		var img := Image.create(128, 32, true, Image.FORMAT_RGB8)
		for y in 32:
			for x in 128:
				var c := color * (0.9 + 0.1 * sin(float(x) * 0.3 + y))
				if y < 2:
					c = color * 0.5
				c.a = 1.0
				img.set_pixel(x, y, c)
		img.generate_mipmaps()
		var m := StandardMaterial3D.new()
		m.albedo_texture = ImageTexture.create_from_image(img)
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3(1.0 / 0.6, 1.0 / 0.15, 1.0 / 0.15)
		m.roughness = 0.85
		_materials[k] = m
	return _materials[k]

# --- primitives --------------------------------------------------------------

## An invisible marker saying what a feature is ("hot_tub", "cover",
## "fire_table", "kitchen", "sauna"), for the tests and the card.
static func mark(parent: Node3D, at: Vector3, kind: String, info := {}) -> Marker3D:
	var m := Marker3D.new()
	m.name = "Mark_" + kind
	m.position = at
	m.set_meta("kind", kind)
	for k in info:
		m.set_meta(k, info[k])
	parent.add_child(m)
	return m

static func box(parent: Node3D, center: Vector3, size: Vector3, material: Material, body: StaticBody3D = null, yaw := 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = center
	mi.rotation.y = yaw
	parent.add_child(mi)
	if body:
		var shape := BoxShape3D.new()
		shape.size = size
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.transform = body.global_transform.affine_inverse() * mi.global_transform
		body.add_child(cs)
	return mi

static func cyl(parent: Node3D, center: Vector3, radius: float, height: float, material: Material, body: StaticBody3D = null, top_radius := -1.0, sides := 24) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = sides
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = center
	parent.add_child(mi)
	if body:
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.transform = body.global_transform.affine_inverse() * mi.global_transform
		body.add_child(cs)
	return mi

static func ball(parent: Node3D, center: Vector3, radius: float, material: Material, squash := 1.0) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0 * squash
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = center
	parent.add_child(mi)
	return mi

## A flat surface over plan rectangle `r` (x, z) whose top is at `top`.
static func slab(parent: Node3D, r: Rect2, top: float, material: Material, thickness := 0.06) -> MeshInstance3D:
	var c := r.get_center()
	return box(parent, Vector3(c.x, top - thickness / 2.0, c.y), Vector3(r.size.x, thickness, r.size.y), material)

## A 3D sign.
static func label(parent: Node3D, at: Vector3, text: String, size_px := 64, color := Color.WHITE, yaw := 0.0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size_px
	l.pixel_size = 0.01
	l.modulate = color
	l.outline_size = 8
	l.position = at
	l.rotation.y = yaw
	parent.add_child(l)
	return l

# --- ground ------------------------------------------------------------------

## A raised platform (deck, stoop or stone landing) over `r`, `top` high,
## with two steps and a sloped walking hull on each side named in `sides`
## ("west", "east", "north", "south" in the parent's frame).
static func landing(parent: Node3D, body: StaticBody3D, r: Rect2, top: float, material: Material, sides: Array) -> void:
	var c := r.get_center()
	box(parent, Vector3(c.x, top / 2.0, c.y), Vector3(r.size.x, top, r.size.y), material, body)
	var tread := 0.35
	var steps := maxi(1, roundi(top / 0.18))
	var rise := top / (steps + 1)
	for side in sides:
		for k in range(1, steps + 1):
			var h := top - k * rise
			var g := tread * k
			var sr := _grow_side(r, side, g)
			var sc := sr.get_center()
			box(parent, Vector3(sc.x, h / 2.0, sc.y), Vector3(sr.size.x, h, sr.size.y), material)
		# Walk-up hull from the platform's edge to the ground past the steps.
		var out := tread * (steps + 1)
		var edge := _edge(r, side)
		var foot := _edge(_grow_side(r, side, out), side)
		var pts := PackedVector3Array([
			Vector3(edge[0].x, top, edge[0].y), Vector3(edge[1].x, top, edge[1].y),
			Vector3(foot[0].x, 0.0, foot[0].y), Vector3(foot[1].x, 0.0, foot[1].y),
			Vector3(edge[0].x, 0.0, edge[0].y), Vector3(edge[1].x, 0.0, edge[1].y)])
		var shape := ConvexPolygonShape3D.new()
		shape.points = pts
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)

## The strip `g` metres wide just outside side `side` of `r`, as long as that side.
static func _grow_side(r: Rect2, side: String, g: float) -> Rect2:
	match side:
		"west": return Rect2(r.position.x - g, r.position.y, g, r.size.y)
		"east": return Rect2(r.end.x, r.position.y, g, r.size.y)
		"north": return Rect2(r.position.x, r.position.y - g, r.size.x, g)
		_: return Rect2(r.position.x, r.end.y, r.size.x, g)

## The outer edge of `r` on `side`, as two (x, z) points.
static func _edge(r: Rect2, side: String) -> Array:
	match side:
		"west": return [Vector2(r.position.x, r.position.y), Vector2(r.position.x, r.end.y)]
		"east": return [Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y)]
		"north": return [Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y)]
		_: return [Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y)]

# --- the main features -------------------------------------------------------

## A square acrylic hot tub in a cabinet, `size` metres across, its rim
## `height` up, with a step on the side facing `step_dir`. Returns its centre.
static func hot_tub(parent: Node3D, body: StaticBody3D, center: Vector2, size := 2.3, height := 0.95, cabinet := CHARCOAL, step_dir := Vector2(1, 0)) -> Vector3:
	var base := Vector3(center.x, 0.0, center.y)
	box(parent, base + Vector3(0, height / 2.0, 0), Vector3(size, height, size), mat(cabinet, 0.8), body)
	# Rim, shell and water.
	box(parent, base + Vector3(0, height + 0.02, 0), Vector3(size, 0.04, size), mat(Color(0.85, 0.85, 0.83), 0.4))
	box(parent, base + Vector3(0, height + 0.045, 0), Vector3(size - 0.25, 0.02, size - 0.25), mat(WATER, 0.05, 0.1, 0.25))
	# Headrests in the corners.
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			box(parent, base + Vector3(sx * (size / 2.0 - 0.25), height + 0.08, sz * (size / 2.0 - 0.25)), Vector3(0.22, 0.06, 0.22), mat(CHARCOAL, 0.6))
	mark(parent, base, "hot_tub", {"size": size})
	if step_dir == Vector2.ZERO:
		return base
	var s := step_dir.normalized() * (size / 2.0 + 0.3)
	box(parent, base + Vector3(s.x, 0.2, s.y), Vector3(0.9 if absf(step_dir.y) > 0.5 else 0.6, 0.4, 0.6 if absf(step_dir.y) > 0.5 else 0.9), mat(cabinet, 0.8))
	return base

## A propane fire table: a base, a glass-bead tray and flames, lit.
static func fire_table(parent: Node3D, body: StaticBody3D, center: Vector2, size := Vector2(1.3, 0.8), round_table := false, height := 0.6, base_color := CONCRETE) -> void:
	var base := Vector3(center.x, 0.0, center.y)
	mark(parent, base, "fire_table")
	if round_table:
		cyl(parent, base + Vector3(0, height / 2.0, 0), size.x / 2.0, height, mat(base_color), body)
		cyl(parent, base + Vector3(0, height + 0.01, 0), size.x / 2.0 * 0.55, 0.03, mat(Color(0.25, 0.35, 0.42), 0.2, 0.4))
	else:
		box(parent, base + Vector3(0, height / 2.0, 0), Vector3(size.x, height, size.y), mat(base_color), body)
		box(parent, base + Vector3(0, height + 0.01, 0), Vector3(size.x * 0.6, 0.03, size.y * 0.45), mat(Color(0.25, 0.35, 0.42), 0.2, 0.4))
	flames(parent, base + Vector3(0, height, 0), size.x * (0.25 if round_table else 0.28), 5)

## A row of flames along local x at `at`, `half` metres either side, with a
## warm light.
static func flames(parent: Node3D, at: Vector3, half: float, count := 5, tall := 0.35) -> void:
	for i in count:
		var f := (float(i) + 0.5) / count * 2.0 - 1.0
		var h := tall * (0.7 + 0.3 * cos(f * 1.4))
		cyl(parent, at + Vector3(f * half, h / 2.0, 0), 0.07, h, mat(FIRE_COLOR, 1.0, 0.0, 3.0), null, 0.0, 8)
	var light := OmniLight3D.new()
	light.position = at + Vector3(0, 0.6, 0)
	light.light_color = Color(1.0, 0.6, 0.3)
	light.light_energy = 1.2
	light.omni_range = 5.0
	parent.add_child(light)

## An open-sided pavilion over `r`: posts, beams and a roof ("gable" with the
## ridge along x, "shed" falling to +z, or "flat"), `height` to the eaves.
static func pavilion(parent: Node3D, body: StaticBody3D, r: Rect2, height := 2.7, roof := "gable", post := CEDAR, roof_color := SLATE, posts_per_side := 2) -> void:
	var c := r.get_center()
	mark(parent, Vector3(c.x, 0, c.y), "cover")
	var post_m := mat(post, 0.8)
	var xs := []
	for i in posts_per_side:
		xs.append(lerpf(r.position.x + 0.15, r.end.x - 0.15, float(i) / maxi(posts_per_side - 1, 1)))
	for x in xs:
		for z in [r.position.y + 0.15, r.end.y - 0.15]:
			box(parent, Vector3(x, height / 2.0, z), Vector3(0.18, height, 0.18), post_m, body)
	for z in [r.position.y + 0.15, r.end.y - 0.15]:
		box(parent, Vector3(c.x, height - 0.1, z), Vector3(r.size.x, 0.2, 0.15), post_m)
	for x in [r.position.x + 0.15, r.end.x - 0.15]:
		box(parent, Vector3(x, height - 0.1, c.y), Vector3(0.15, 0.2, r.size.y), post_m)
	var roof_m := mat(roof_color, 0.6, 0.2)
	var over := 0.35
	match roof:
		"gable":
			var rise := r.size.y * 0.3
			var half := r.size.y / 2.0 + over
			var slope := sqrt(half * half + rise * rise)
			var ang := atan2(rise, half)
			for sz in [-1.0, 1.0]:
				var mi := box(parent, Vector3(c.x, height + rise / 2.0, c.y + sz * half / 2.0), Vector3(r.size.x + 2 * over, 0.06, slope), roof_m)
				mi.rotation.x = sz * ang
			# Gable triangles of the ceiling, as a cedar-boarded underside.
			box(parent, Vector3(c.x, height + 0.02, c.y), Vector3(r.size.x, 0.03, r.size.y), mat(post, 0.8))
		"shed":
			var fall := 0.45
			var mi := box(parent, Vector3(c.x, height + fall / 2.0, c.y), Vector3(r.size.x + 2 * over, 0.06, sqrt(pow(r.size.y + 2 * over, 2) + fall * fall)), roof_m)
			mi.rotation.x = atan2(fall, r.size.y + 2 * over)
		_:
			box(parent, Vector3(c.x, height + 0.1, c.y), Vector3(r.size.x + 2 * over, 0.2, r.size.y + 2 * over), roof_m)

## An open pergola (slats, no roof) over `r`.
static func pergola(parent: Node3D, body: StaticBody3D, r: Rect2, height := 2.6, color := CEDAR) -> void:
	var m := mat(color, 0.8)
	for x in [r.position.x + 0.1, r.end.x - 0.1]:
		for z in [r.position.y + 0.1, r.end.y - 0.1]:
			box(parent, Vector3(x, height / 2.0, z), Vector3(0.15, height, 0.15), m, body)
	var n := int(r.size.x / 0.4)
	for i in n + 1:
		var x := r.position.x + r.size.x * float(i) / n
		box(parent, Vector3(x, height + 0.08, r.get_center().y), Vector3(0.05, 0.16, r.size.y + 0.4), m)

## An outdoor kitchen run starting at `start` (x, z of its left end, seen from
## the cook's side), running `length` metres along `along` with the cook on
## the `toward` side; `items` are placed in order along it.
static func kitchen(parent: Node3D, body: StaticBody3D, start: Vector2, along: Vector2, toward: Vector2, length: float, items: Array, cabinet := STONE, top := Color(0.2, 0.2, 0.21)) -> void:
	var depth := 0.7
	var a := along.normalized()
	var t := toward.normalized()
	var mid := start + a * length / 2.0 - t * depth / 2.0
	var yaw := atan2(-a.y, a.x)
	box(parent, Vector3(mid.x, 0.45, mid.y), Vector3(length, 0.9, depth), mat(cabinet, 0.9), body, yaw)
	box(parent, Vector3(mid.x, 0.92, mid.y), Vector3(length + 0.05, 0.04, depth + 0.05), mat(top, 0.3), null, yaw)
	mark(parent, Vector3(mid.x, 0, mid.y), "kitchen", {"items": items})
	var slot := length / maxi(items.size(), 1)
	for i in items.size():
		var p := start + a * slot * (i + 0.5) - t * depth / 2.0
		var at := Vector3(p.x, 0.94, p.y)
		match items[i]:
			"grill":
				box(parent, at + Vector3(0, 0.12, 0), Vector3(0.8, 0.22, 0.55), mat(STEEL, 0.3, 0.8), null, yaw)
				var hood := box(parent, at + Vector3(0, 0.3, 0) + Vector3(-t.x, 0, -t.y) * 0.15, Vector3(0.8, 0.35, 0.12), mat(STEEL, 0.3, 0.8), null, yaw)
				hood.rotation.x = 0.0
			"flat_top":
				box(parent, at + Vector3(0, 0.03, 0), Vector3(0.8, 0.06, 0.55), mat(CHARCOAL, 0.3, 0.7), null, yaw)
			"sink":
				box(parent, at + Vector3(0, -0.04, 0), Vector3(0.6, 0.05, 0.42), mat(STEEL, 0.2, 0.9), null, yaw)
				cyl(parent, at + Vector3(-t.x * 0.25, 0.18, -t.y * 0.25), 0.02, 0.36, mat(STEEL, 0.2, 0.9))
				box(parent, at + Vector3(-t.x * 0.15, 0.35, -t.y * 0.15), Vector3(0.04, 0.04, 0.2), mat(STEEL, 0.2, 0.9), null, yaw + PI / 2.0)
			"fridge":
				box(parent, Vector3(p.x, 0.42, p.y) + Vector3(t.x, 0, t.y) * 0.36, Vector3(0.55, 0.75, 0.02), mat(STEEL, 0.3, 0.7), null, yaw)
			"pizza":
				ball(parent, at + Vector3(0, 0.05, 0), 0.5, mat(Color(0.72, 0.45, 0.3), 0.9), 0.9)
				cyl(parent, at + Vector3(0, 0.75, 0), 0.08, 0.6, mat(CHARCOAL, 0.7))
			"smoker":
				cyl(parent, at + Vector3(0, 0.3, 0), 0.3, 0.6, mat(CHARCOAL, 0.6, 0.4))
				cyl(parent, at + Vector3(0.2, 0.8, 0), 0.05, 0.5, mat(CHARCOAL, 0.6, 0.4))
			"burner":
				cyl(parent, at + Vector3(0, 0.02, 0), 0.15, 0.04, mat(CHARCOAL, 0.4, 0.6))
			_:
				pass

## A bar stool at `at`.
static func stool(parent: Node3D, at: Vector2, color := CHARCOAL) -> void:
	cyl(parent, Vector3(at.x, 0.38, at.y), 0.03, 0.76, mat(color, 0.4, 0.6))
	cyl(parent, Vector3(at.x, 0.78, at.y), 0.2, 0.06, mat(color, 0.6))

## A lounge chair facing `facing` (x, z).
static func chair(parent: Node3D, at: Vector2, facing: Vector2, color := CEDAR) -> void:
	var yaw := atan2(facing.x, facing.y)
	var holder := Node3D.new()
	holder.position = Vector3(at.x, 0, at.y)
	holder.rotation.y = yaw
	parent.add_child(holder)
	var m := mat(color, 0.8)
	box(holder, Vector3(0, 0.35, 0), Vector3(0.7, 0.1, 0.65), m)
	box(holder, Vector3(0, 0.7, -0.33), Vector3(0.7, 0.75, 0.08), m).rotation.x = -0.25
	for sx in [-1, 1]:
		box(holder, Vector3(sx * 0.37, 0.55, 0), Vector3(0.08, 0.06, 0.7), m)
		box(holder, Vector3(sx * 0.33, 0.17, 0.25), Vector3(0.06, 0.34, 0.06), m)
		box(holder, Vector3(sx * 0.33, 0.17, -0.25), Vector3(0.06, 0.34, 0.06), m)

## A sofa `length` long, centred at `at`, facing `facing`.
static func sofa(parent: Node3D, at: Vector2, facing: Vector2, length := 2.2, frame := CHARCOAL, cushion := CUSHION) -> void:
	var holder := Node3D.new()
	holder.position = Vector3(at.x, 0, at.y)
	holder.rotation.y = atan2(facing.x, facing.y)
	parent.add_child(holder)
	box(holder, Vector3(0, 0.2, 0), Vector3(length, 0.4, 0.85), mat(frame, 0.7))
	box(holder, Vector3(0, 0.47, 0.03), Vector3(length - 0.1, 0.14, 0.75), mat(cushion, 0.95))
	box(holder, Vector3(0, 0.7, -0.35), Vector3(length, 0.6, 0.18), mat(cushion, 0.95))
	for sx in [-1, 1]:
		box(holder, Vector3(sx * (length / 2.0 - 0.08), 0.5, 0), Vector3(0.16, 0.6, 0.85), mat(frame, 0.7))

## A horizontal cedar barrel sauna, its axis along local x turned by `yaw`,
## `length` long, with a glass door at the +x end and a chimney.
static func barrel_sauna(parent: Node3D, body: StaticBody3D, at: Vector2, yaw := 0.0, length := 2.4, radius := 1.0) -> void:
	var holder := Node3D.new()
	holder.position = Vector3(at.x, 0, at.y)
	holder.rotation.y = yaw
	parent.add_child(holder)
	mark(parent, Vector3(at.x, 0, at.y), "sauna")
	var barrel := cyl(holder, Vector3(0, radius + 0.15, 0), radius, length, mat(CEDAR, 0.85), null, -1.0, 18)
	barrel.rotation.z = PI / 2.0
	for x in [-length / 2.0 + 0.2, length / 2.0 - 0.2]:
		var band := cyl(holder, Vector3(x, radius + 0.15, 0), radius + 0.02, 0.04, mat(CHARCOAL, 0.5, 0.6), null, -1.0, 18)
		band.rotation.z = PI / 2.0
		box(holder, Vector3(x, 0.08, 0), Vector3(0.15, 0.16, radius * 1.6), mat(CEDAR_DARK))
	var door := box(holder, Vector3(length / 2.0 + 0.01, radius * 0.9 + 0.15, 0), Vector3(0.03, radius * 1.5, 0.65), mat(Color(0.35, 0.25, 0.18, 0.7), 0.1))
	door.name = "SaunaDoor"
	cyl(holder, Vector3(-length / 4.0, radius * 2.0 + 0.5, 0), 0.08, 0.9, mat(STEEL, 0.4, 0.7))
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = length
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.transform = body.global_transform.affine_inverse() * barrel.global_transform
	body.add_child(cs)

## A cedar cabin sauna over `r` with a glass front on its +z side, a shed roof
## and a chimney.
static func cabin_sauna(parent: Node3D, body: StaticBody3D, r: Rect2, height := 2.4) -> void:
	var c := r.get_center()
	mark(parent, Vector3(c.x, 0, c.y), "sauna")
	box(parent, Vector3(c.x, height / 2.0, c.y - 0.1), Vector3(r.size.x, height, r.size.y - 0.2), mat(CEDAR, 0.85), body)
	box(parent, Vector3(c.x, height / 2.0, r.end.y - 0.12), Vector3(r.size.x - 0.3, height - 0.3, 0.04), mat(Color(0.2, 0.25, 0.27, 0.6), 0.05, 0.4))
	var roof := box(parent, Vector3(c.x, height + 0.15, c.y), Vector3(r.size.x + 0.5, 0.08, r.size.y + 0.6), mat(CHARCOAL, 0.6, 0.3))
	roof.rotation.x = -0.1
	cyl(parent, Vector3(r.position.x + 0.5, height + 0.7, c.y - 0.4), 0.1, 1.2, mat(STEEL, 0.4, 0.7))

## A galvanised cold-plunge stock tank.
static func cold_plunge(parent: Node3D, body: StaticBody3D, at: Vector2, radius := 0.8) -> void:
	cyl(parent, Vector3(at.x, 0.35, at.y), radius, 0.7, mat(STEEL, 0.4, 0.7), body)
	cyl(parent, Vector3(at.x, 0.66, at.y), radius - 0.05, 0.02, mat(Color(0.5, 0.75, 0.85, 0.8), 0.05))

## An outdoor shower post.
static func shower(parent: Node3D, body: StaticBody3D, at: Vector2) -> void:
	cyl(parent, Vector3(at.x, 1.1, at.y), 0.04, 2.2, mat(STEEL, 0.3, 0.8), body)
	cyl(parent, Vector3(at.x, 2.15, at.y + 0.2), 0.12, 0.03, mat(STEEL, 0.3, 0.8))
	box(parent, Vector3(at.x, 0.03, at.y + 0.2), Vector3(0.9, 0.06, 0.9), boards(CEDAR))

## A slatted privacy screen from `a` to `b`.
static func screen(parent: Node3D, body: StaticBody3D, a: Vector2, b: Vector2, height := 1.9, color := CEDAR) -> void:
	var d := b - a
	var mid := (a + b) / 2.0
	var yaw := atan2(-d.y, d.x)
	for i in int(height / 0.14):
		box(parent, Vector3(mid.x, 0.12 + i * 0.14, mid.y), Vector3(d.length(), 0.1, 0.04), mat(color, 0.8), null, yaw)
	for p in [a, b]:
		box(parent, Vector3(p.x, height / 2.0, p.y), Vector3(0.1, height, 0.1), mat(color, 0.8), body)
	box(parent, Vector3(mid.x, height / 2.0, mid.y), Vector3(d.length(), height, 0.05), mat(Color(0, 0, 0, 0)), body, yaw).visible = false

## Bistro lights strung between `points` (x, z) at `height`, sagging between.
static func string_lights(parent: Node3D, body: StaticBody3D, points: Array, height := 3.0, posts := true) -> void:
	var bulb := mat(Color(1.0, 0.85, 0.55), 0.5, 0.0, 4.0)
	for i in points.size() - 1:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var n := int(a.distance_to(b) / 0.6)
		for k in n + 1:
			var t := float(k) / n
			var p := a.lerp(b, t)
			var sag := 0.45 * 4.0 * t * (1.0 - t)
			ball(parent, Vector3(p.x, height - sag, p.y), 0.05, bulb)
	if posts:
		for p in points:
			box(parent, Vector3(p.x, height / 2.0, p.y), Vector3(0.1, height, 0.1), mat(CHARCOAL, 0.6), body)

## A round shrub.
static func shrub(parent: Node3D, at: Vector2, radius := 0.5) -> void:
	ball(parent, Vector3(at.x, radius * 0.8, at.y), radius, mat(GREEN, 0.95), 0.85)

## A tiki torch.
static func torch(parent: Node3D, at: Vector2) -> void:
	cyl(parent, Vector3(at.x, 0.9, at.y), 0.03, 1.8, mat(CEDAR_DARK, 0.9))
	cyl(parent, Vector3(at.x, 1.85, at.y), 0.08, 0.2, mat(Color(0.75, 0.6, 0.35), 0.9))
	cyl(parent, Vector3(at.x, 2.07, at.y), 0.06, 0.25, mat(FIRE_COLOR, 1.0, 0.0, 3.0), null, 0.0, 8)

## A wall-mounted TV facing `facing`.
static func tv(parent: Node3D, at: Vector3, facing: Vector2) -> void:
	var yaw := atan2(facing.x, facing.y)
	box(parent, at, Vector3(1.6, 0.92, 0.06), mat(Color(0.04, 0.05, 0.07), 0.2, 0.3), null, yaw)

## A hot tub surrounded by a deck: a platform `top` high reaching `margin`
## metres beyond the tub on every side, with steps on `sides`, and the tub sunk
## into it so its rim stands at sitting height (about 0.45 m) above the deck.
## A grab rail stands at the tub's corner nearest the first step side.
static func tub_on_deck(parent: Node3D, body: StaticBody3D, center: Vector2, size: float, deck: Material, sides: Array, cabinet := CHARCOAL, margin := 1.0, top := 0.5) -> void:
	var half := size / 2.0 + margin
	landing(parent, body, Rect2(center.x - half, center.y - half, half * 2.0, half * 2.0), top, deck, sides)
	mark(parent, Vector3(center.x, 0, center.y), "tub_deck", {"top": top, "half": half})
	hot_tub(parent, body, center, size, top + 0.45, cabinet, Vector2.ZERO)
	if not sides.is_empty():
		var d: Vector2 = {"west": Vector2(-1, 0), "east": Vector2(1, 0), "north": Vector2(0, -1), "south": Vector2(0, 1)}[sides[0]]
		var side := Vector2(d.y, -d.x)
		var p := center + d * (size / 2.0 + 0.25) + side * (size / 2.0 - 0.2)
		cyl(parent, Vector3(p.x, top + 0.5, p.y), 0.025, 1.0, mat(STEEL, 0.3, 0.8))
		var bar := cyl(parent, Vector3(p.x - d.x * 0.15, top + 1.0, p.y - d.y * 0.15), 0.025, 0.35, mat(STEEL, 0.3, 0.8))
		bar.rotation = Vector3(PI / 2.0 if absf(d.y) > 0.5 else 0.0, 0.0, PI / 2.0 if absf(d.x) > 0.5 else 0.0)

## An octagonal gazebo of radius `radius` round `at`, open on the side
## facing `open_dir`, with a pointed roof.
static func gazebo(parent: Node3D, body: StaticBody3D, at: Vector2, radius := 2.1, height := 2.7, post := CEDAR, roof := SLATE, open_dir := Vector2(0, -1)) -> void:
	mark(parent, Vector3(at.x, 0, at.y), "cover")
	for k in 8:
		var a := TAU * (k + 0.5) / 8.0
		var d := Vector2(cos(a), sin(a))
		if d.dot(open_dir.normalized()) > 0.95:
			continue
		box(parent, Vector3(at.x + d.x * radius, height / 2.0, at.y + d.y * radius), Vector3(0.14, height, 0.14), mat(post, 0.8), body)
	cyl(parent, Vector3(at.x, height + 0.55, at.y), radius + 0.5, 1.1, mat(roof, 0.6, 0.2), null, 0.0, 8)

## A dining table `length` long along x at `at`, with benches either side.
static func dining(parent: Node3D, at: Vector2, length := 2.6, wood := CEDAR_DARK) -> void:
	box(parent, Vector3(at.x, 0.74, at.y), Vector3(length, 0.06, 0.95), mat(wood, 0.8))
	for sx in [-1, 1]:
		box(parent, Vector3(at.x + sx * (length / 2.0 - 0.2), 0.36, at.y), Vector3(0.1, 0.72, 0.8), mat(wood, 0.8))
	for sz in [-0.75, 0.75]:
		box(parent, Vector3(at.x, 0.44, at.y + sz), Vector3(length, 0.05, 0.32), mat(wood, 0.8))
		box(parent, Vector3(at.x, 0.21, at.y + sz), Vector3(length - 0.3, 0.42, 0.06), mat(wood, 0.8))

## A stone lantern.
static func lantern(parent: Node3D, at: Vector2) -> void:
	box(parent, Vector3(at.x, 0.3, at.y), Vector3(0.3, 0.6, 0.3), mat(STONE, 0.95))
	box(parent, Vector3(at.x, 0.75, at.y), Vector3(0.45, 0.3, 0.45), mat(Color(1.0, 0.85, 0.55), 0.6, 0.0, 1.5))
	cyl(parent, Vector3(at.x, 1.05, at.y), 0.45, 0.3, mat(STONE, 0.95), null, 0.0, 4)

## Room left for a sauna to come later: plan rectangle `r` (x, z), a gravel
## pad edged in timber (or, with `gravel` off, just the marks, for a spot on a
## deck `top` high), stakes at the corners, a power stub for the heater's
## circuit, and SAUNA HERE written on the ground. Nothing solid stands in it.
static func sauna_spot(parent: Node3D, r: Rect2, top := 0.0, gravel := true) -> void:
	var c := r.get_center()
	mark(parent, Vector3(c.x, top, c.y), "sauna_spot", {"rect": r, "top": top})
	if gravel:
		slab(parent, r, top + 0.06, paving(Color(0.62, 0.60, 0.56), 0.15, "sauna_gravel"))
	var edge := mat(CEDAR_DARK, 0.9)
	box(parent, Vector3(c.x, top + 0.05, r.position.y), Vector3(r.size.x, 0.1, 0.06), edge)
	box(parent, Vector3(c.x, top + 0.05, r.end.y), Vector3(r.size.x, 0.1, 0.06), edge)
	box(parent, Vector3(r.position.x, top + 0.05, c.y), Vector3(0.06, 0.1, r.size.y), edge)
	box(parent, Vector3(r.end.x, top + 0.05, c.y), Vector3(0.06, 0.1, r.size.y), edge)
	for p in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		box(parent, Vector3(p.x, top + 0.3, p.y), Vector3(0.05, 0.6, 0.05), mat(CEDAR, 0.9))
		box(parent, Vector3(p.x, top + 0.62, p.y), Vector3(0.06, 0.06, 0.06), mat(Color(1.0, 0.45, 0.1), 0.6))
	# The power stub just outside the pad's north-east corner.
	var stub := Vector2(r.end.x + 0.25, r.position.y - 0.25)
	box(parent, Vector3(stub.x, top + 0.5, stub.y), Vector3(0.1, 1.0, 0.1), mat(CEDAR_DARK, 0.9))
	box(parent, Vector3(stub.x, top + 0.85, stub.y + 0.07), Vector3(0.18, 0.24, 0.08), mat(Color(0.55, 0.57, 0.6), 0.5, 0.4))
	var l := label(parent, Vector3(c.x, top + 0.1, c.y), "SAUNA HERE", 96, Color(1.0, 0.9, 0.7))
	l.rotation.x = -PI / 2.0
