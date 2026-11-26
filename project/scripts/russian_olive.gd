extends RefCounted
## An older Russian olive made in code (D-194), after the grey-green trees
## along the farm's north side in the base imagery: two to four crooked stems
## leaning out from one base, rough dark bark, a wide uneven crown of forking
## limbs that sweep out and droop, and silvery-green narrow leaves in clusters
## along them. Each tree grows from a seed, so a row of them is not a row of
## copies. About 15 to 25 ft (4.5 to 7.6 m).
##
## build() returns a Node3D whose origin is the base of the trunk on the
## ground: one bark mesh, one leaf mesh (crossed cards with an alpha-scissor
## leaf-cluster texture, also made here) and a solid cylinder round the base.
## The crown is walk-through. The bark tube and leaf card come from birch.gd.

const Birch := preload("res://scripts/birch.gd")

## How many times limbs fork above the stems; tips carry the leaves.
const DEPTH := 3
const BARK_COLOR := Color(0.27, 0.22, 0.18)
const LEAF_COLOR := Color(0.55, 0.64, 0.5)
## Radius of the solid part of the trunk, metres, for a REF_HEIGHT tree; wood
## thickness scales with the tree's height.
const TRUNK_RADIUS := 0.28
const REF_HEIGHT := 6.0

static var _leaf_material: StandardMaterial3D
static var _bark_material: StandardMaterial3D

## A Russian olive about `height` metres tall from `seed`.
static func build(seed: int, height: float) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var bark := SurfaceTool.new()
	bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var scale := height / REF_HEIGHT
	var girth := pow(scale, 0.8)
	var stems := rng.randi_range(2, 4)
	var turn := rng.randf() * TAU
	for i in stems:
		var az := turn + TAU * float(i) / stems + rng.randf_range(-0.5, 0.5)
		var lean := deg_to_rad(rng.randf_range(12.0, 30.0))
		var dir := Vector3(sin(lean) * cos(az), cos(lean), sin(lean) * sin(az))
		_limb(rng, bark, leaves, Vector3(0, -0.1, 0), dir, height * rng.randf_range(0.34, 0.42), 0.15 * girth, 0, scale)
	# A short common base so the stems grow from one trunk.
	var base: Array[Vector3] = [Vector3(0, -0.1, 0), Vector3(0, 0.5 * scale, 0)]
	var base_radii: Array[float] = [TRUNK_RADIUS * girth, 0.2 * girth]
	Birch._tube(bark, base, base_radii)

	var root := Node3D.new()
	root.name = "RussianOlive"
	var bark_mi := MeshInstance3D.new()
	bark_mi.name = "Bark"
	bark_mi.mesh = bark.commit()
	bark_mi.material_override = bark_material()
	root.add_child(bark_mi)
	var leaf_mi := MeshInstance3D.new()
	leaf_mi.name = "Leaves"
	leaf_mi.mesh = leaves.commit()
	leaf_mi.material_override = leaf_material()
	root.add_child(leaf_mi)
	var body := StaticBody3D.new()
	body.name = "Trunk"
	var shape := CylinderShape3D.new()
	shape.radius = TRUNK_RADIUS * girth
	shape.height = 2.5
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = 1.25
	body.add_child(cs)
	root.add_child(body)
	return root

## One limb from `start` along `dir`, `length` long, `radius` at its base: it
## wanders, and older ones sag. Forks until DEPTH, then carries leaves.
static func _limb(rng: RandomNumberGenerator, bark: SurfaceTool, leaves: SurfaceTool, start: Vector3, dir: Vector3, length: float, radius: float, depth: int, scale: float) -> void:
	var pts: Array[Vector3] = []
	var radii: Array[float] = []
	var end_radius := radius * 0.65
	var kink := Birch._perpendicular(dir).rotated(dir, rng.randf() * TAU) * rng.randf_range(0.1, 0.3)
	var sag := 0.08 * (depth + 1)
	for i in 4:
		var t := float(i) / 3.0
		pts.append(start + dir * length * t + kink * length * sin(t * PI) + Vector3.DOWN * length * sag * t * t)
		radii.append(lerpf(radius, end_radius, t))
	Birch._tube(bark, pts, radii)
	var tip := pts[3]
	var tip_dir := (pts[3] - pts[2]).normalized()
	if depth >= DEPTH:
		Birch._cluster(rng, leaves, tip, rng.randf_range(1.5, 2.1) * scale, 3)
		Birch._cluster(rng, leaves, pts[2], rng.randf_range(1.0, 1.5) * scale, 2)
		return
	var forks := rng.randi_range(2, 3)
	var spin := rng.randf() * TAU
	for i in forks:
		var side := Birch._perpendicular(tip_dir).rotated(tip_dir, spin + TAU * float(i) / forks)
		var spread := deg_to_rad(rng.randf_range(28.0, 55.0))
		var child := tip_dir * cos(spread) + side * sin(spread)
		# A little lift on the main limbs, none on the outer ones.
		child = (child + Vector3.UP * (0.25 if depth < 1 else 0.0)).normalized()
		_limb(rng, bark, leaves, tip, child, length * rng.randf_range(0.65, 0.85), end_radius * 0.8, depth + 1, scale)
	# A side limb part-way along fills the crown out and down.
	if depth >= 1:
		var side := Birch._perpendicular(dir).rotated(dir, rng.randf() * TAU)
		_limb(rng, bark, leaves, pts[1], (dir + side * 1.1).normalized(), length * 0.6, radii[1] * 0.6, DEPTH, scale)

static func bark_material() -> StandardMaterial3D:
	if _bark_material == null:
		var m := StandardMaterial3D.new()
		m.albedo_texture = ImageTexture.create_from_image(bark_image())
		m.roughness = 0.95
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_bark_material = m
	return _bark_material

static func leaf_material() -> StandardMaterial3D:
	if _leaf_material == null:
		var m := StandardMaterial3D.new()
		m.albedo_texture = ImageTexture.create_from_image(leaf_image())
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.4
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.roughness = 0.7
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_leaf_material = m
	return _leaf_material

## Dark, shaggy grey-brown bark: streaks running along the limb. Tiles.
static func bark_image() -> Image:
	var w := 64
	var h := 64
	var img := Image.create(w, h, true, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = 194
	noise.frequency = 0.09
	for y in h:
		for x in w:
			var a := TAU * float(x) / w
			var v := noise.get_noise_3d(cos(a) * 10.0, sin(a) * 10.0, y * 0.35)
			var c := BARK_COLOR * (1.0 + 0.9 * v)
			c.a = 1.0
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return img

## A spray of narrow silvery-green leaves, transparent between them.
static func leaf_image() -> Image:
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1941
	var centre := Vector2(size / 2.0, size / 2.0)
	for i in 80:
		var ang := rng.randf() * TAU
		var r := sqrt(rng.randf()) * size * 0.4
		var p := centre + Vector2(cos(ang), sin(ang)) * r
		# Leaves point outward from the middle, a little off.
		var heading := ang + rng.randf_range(-0.6, 0.6)
		var length := rng.randf_range(12.0, 19.0)
		var half_w := length * rng.randf_range(0.12, 0.18)
		var along := Vector2(cos(heading), sin(heading))
		var across := Vector2(-along.y, along.x)
		var tone := LEAF_COLOR * rng.randf_range(0.8, 1.2)
		tone.a = 1.0
		for py in range(int(p.y - length), int(p.y + length) + 1):
			for px in range(int(p.x - length), int(p.x + length) + 1):
				if px < 0 or px >= size or py < 0 or py >= size:
					continue
				var d := Vector2(px, py) - p
				var s := d.dot(along) / length
				if s < 0.0 or s > 1.0:
					continue
				# Lance-shaped: widest a third of the way along.
				var width := half_w * sin(PI * pow(s, 0.7))
				if absf(d.dot(across)) <= width:
					img.set_pixel(px, py, tone.lightened(0.15 * s))
	img.generate_mipmaps()
	return img
