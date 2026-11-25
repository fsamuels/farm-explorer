extends RefCounted
## A tree-form willow made in code (D-171), after the owner's photo of the back
## yard (Downloads/back yard deck.jpg): two or three stems leaning out from the
## base, limbs that fork upward and then arch over, and at every twig tip
## strands of narrow leaves hanging down. Each tree grows from a seed, so a row
## of them is not a row of copies.
##
## build() returns a Node3D whose origin is the base of the trunk on the
## ground: one bark mesh, one leaf mesh (crossed cards with an alpha-scissor
## leaf-strand texture, also made here) and a solid cylinder round the base of
## the trunk. The canopy is walk-through.

## How many times limbs fork above the stems; twig tips carry the leaves.
const DEPTH := 3
const SIDES := 6
const BARK_COLOR := Color(0.36, 0.32, 0.27)
const LEAF_COLOR := Color(0.47, 0.57, 0.28)
const STRAND_WIDTH := 0.55
## Radius of the solid part of the trunk, metres, for a REF_HEIGHT tree; wood
## thickness scales with the tree's height.
const TRUNK_RADIUS := 0.3
const REF_HEIGHT := 10.0

static var _leaf_material: StandardMaterial3D
static var _bark_material: StandardMaterial3D

## A willow about `height` metres tall from `seed`.
static func build(seed: int, height: float) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var bark := SurfaceTool.new()
	bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Wood thickens a little slower than the tree grows taller.
	var girth := pow(height / REF_HEIGHT, 0.8)
	var stems := rng.randi_range(2, 3)
	var turn := rng.randf() * TAU
	for i in stems:
		var az := turn + TAU * float(i) / stems + rng.randf_range(-0.4, 0.4)
		var lean := deg_to_rad(rng.randf_range(8.0, 18.0))
		var dir := Vector3(sin(lean) * cos(az), cos(lean), sin(lean) * sin(az))
		_limb(rng, bark, leaves, Vector3(0, -0.1, 0), dir, height * rng.randf_range(0.36, 0.44), (0.2 if stems == 2 else 0.17) * girth, 0, height)
	# A short common base so the stems grow from one trunk.
	_tube(bark, [Vector3(0, -0.1, 0), Vector3(0, 0.9 * girth, 0)], [TRUNK_RADIUS * girth, 0.24 * girth])

	var root := Node3D.new()
	root.name = "Willow"
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
	shape.height = 3.0
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = 1.5
	body.add_child(cs)
	root.add_child(body)
	return root

## One limb from `start` along `dir`, `length` long, `radius` at its base,
## bending: young limbs reach up, older ones arch over under their own weight.
## Forks until DEPTH, then hangs leaf strands.
static func _limb(rng: RandomNumberGenerator, bark: SurfaceTool, leaves: SurfaceTool, start: Vector3, dir: Vector3, length: float, radius: float, depth: int, height: float) -> void:
	var sag := 0.0 if depth == 0 else 0.12 * depth
	var pts: Array[Vector3] = []
	var radii: Array[float] = []
	var end_radius := radius * 0.62
	for i in 5:
		var t := float(i) / 4.0
		pts.append(start + dir * length * t + Vector3.DOWN * length * sag * t * t)
		radii.append(lerpf(radius, end_radius, t))
	_tube(bark, pts, radii)
	var tip := pts[4]
	var tip_dir := (pts[4] - pts[3]).normalized()
	if depth >= DEPTH:
		_strands(rng, leaves, pts, height)
		return
	var forks := rng.randi_range(2, 3)
	var spin := rng.randf() * TAU
	for i in forks:
		var side := _perpendicular(tip_dir).rotated(tip_dir, spin + TAU * float(i) / forks)
		var spread := deg_to_rad(rng.randf_range(22.0, 40.0))
		var child := (tip_dir * cos(spread) + side * sin(spread))
		# Upward pull on the main limbs, outward on the twigs.
		child = (child + Vector3.UP * (0.35 if depth < 1 else 0.1)).normalized()
		_limb(rng, bark, leaves, tip, child, length * rng.randf_range(0.6, 0.78), end_radius * 0.8, depth + 1, height)
	# A side twig from the middle of older limbs fills the crown out.
	if depth >= 1:
		var mid := pts[2]
		var side := _perpendicular(dir).rotated(dir, rng.randf() * TAU)
		_limb(rng, bark, leaves, mid, (dir + side * 0.9).normalized(), length * 0.5, radii[2] * 0.6, DEPTH, height)

## Leaf strands hanging from points along a twig: each two crossed cards from
## the twig down, a little swept out, longer toward the tip.
static func _strands(rng: RandomNumberGenerator, leaves: SurfaceTool, twig: Array[Vector3], height: float) -> void:
	# A flatter spray along the twig itself, so the crown also reads from above
	# (hanging strands are edge-on to a camera looking down).
	var along := twig[4] - twig[0]
	var flat := Vector3(along.x, 0, along.z)
	var leaf_scale := height / REF_HEIGHT
	var across_twig := (Vector3.UP.cross(flat).normalized() if flat.length() > 0.01 else Vector3.RIGHT) * 0.5 * leaf_scale
	across_twig += Vector3.DOWN * 0.15
	var spray := [twig[0] - across_twig, twig[0] + across_twig, twig[4] + across_twig, twig[4] - across_twig]
	var spray_uv := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for idx in [0, 1, 2, 0, 2, 3]:
		leaves.set_normal(Vector3.UP)
		leaves.set_uv(spray_uv[idx])
		leaves.add_vertex(spray[idx])
	var n := rng.randi_range(5, 8)
	for i in n:
		var t := (float(i) + 0.5) / n
		var seg := mini(int(t * 4.0), 3)
		var top := twig[seg].lerp(twig[seg + 1], t * 4.0 - seg)
		# Strands stop well clear of the ground and of people walking under.
		var length := minf(rng.randf_range(1.0, 2.2) * (0.6 + 0.6 * t) * leaf_scale, top.y - 2.6)
		if length < 0.4:
			continue
		var out := Vector3(top.x, 0, top.z)
		out = out.normalized() if out.length() > 0.01 else Vector3.RIGHT
		var bottom := top + Vector3.DOWN * length + out * length * 0.15
		var face := rng.randf() * PI
		for k in 2:
			var across := Vector3(cos(face + k * PI / 2.0), 0, sin(face + k * PI / 2.0)) * STRAND_WIDTH * leaf_scale / 2.0
			# Lit as if facing out and up, so both sides of a card read alike.
			var n_out := (out + Vector3.UP * 0.6).normalized()
			var quad := [top - across, top + across, bottom + across, bottom - across]
			var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
			for idx in [0, 1, 2, 0, 2, 3]:
				leaves.set_normal(n_out)
				leaves.set_uv(uvs[idx])
				leaves.add_vertex(quad[idx])

## A tube of SIDES faces through `pts`, radius per point.
static func _tube(st: SurfaceTool, pts: Array, radii: Array) -> void:
	var rings := []
	for i in pts.size():
		var p: Vector3 = pts[i]
		var forward: Vector3 = ((pts[mini(i + 1, pts.size() - 1)] as Vector3) - (pts[maxi(i - 1, 0)] as Vector3)).normalized()
		var a := _perpendicular(forward)
		var b := forward.cross(a)
		var ring := []
		for s in SIDES + 1:
			var ang := TAU * float(s) / SIDES
			var n := a * cos(ang) + b * sin(ang)
			ring.append([p + n * float(radii[i]), n])
		rings.append(ring)
	for i in rings.size() - 1:
		for s in SIDES:
			var quad := [rings[i][s], rings[i][s + 1], rings[i + 1][s + 1], rings[i + 1][s]]
			for idx in [0, 2, 1, 0, 3, 2]:
				st.set_normal(quad[idx][1])
				st.add_vertex(quad[idx][0])

static func _perpendicular(v: Vector3) -> Vector3:
	var other := Vector3.RIGHT if absf(v.dot(Vector3.UP)) > 0.9 else Vector3.UP
	return v.cross(other).normalized()

static func bark_material() -> StandardMaterial3D:
	if _bark_material == null:
		_bark_material = StandardMaterial3D.new()
		_bark_material.albedo_color = BARK_COLOR
		_bark_material.roughness = 0.95
	return _bark_material

static func leaf_material() -> StandardMaterial3D:
	if _leaf_material == null:
		var m := StandardMaterial3D.new()
		m.albedo_texture = ImageTexture.create_from_image(strand_image())
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.4
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.roughness = 0.8
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_leaf_material = m
	return _leaf_material

## A hanging strand of narrow willow leaves on a thin stem, top to bottom of
## the image, transparent between the leaves.
static func strand_image() -> Image:
	var w := 64
	var h := 256
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 171
	# The stem, swaying a little.
	for y in h:
		var x := int(w / 2.0 + sin(float(y) / 40.0) * 3.0)
		img.set_pixel(x, y, Color(0.32, 0.36, 0.2, 1))
	for i in 90:
		var y0 := rng.randf_range(4.0, h - 10.0)
		var x0 := w / 2.0 + sin(y0 / 40.0) * 3.0
		# Leaves hang down and out to either side of the stem.
		var side := -1.0 if i % 2 == 0 else 1.0
		var ang := deg_to_rad(rng.randf_range(15.0, 45.0)) * side
		var length := rng.randf_range(16.0, 26.0)
		var half_w := rng.randf_range(1.6, 2.4)
		var along := Vector2(sin(ang), cos(ang))
		var across := Vector2(along.y, -along.x)
		var tone := LEAF_COLOR * rng.randf_range(0.8, 1.2)
		tone.a = 1.0
		for py in range(int(y0 - 2), int(y0 + length + 2)):
			for px in range(int(x0 - length), int(x0 + length)):
				if px < 0 or px >= w or py < 0 or py >= h:
					continue
				var d := Vector2(px - x0, py - y0)
				var s := d.dot(along) / length
				if s < 0.0 or s > 1.0:
					continue
				# Lance-shaped: widest a third of the way along, pointed at the end.
				var width := half_w * sin(PI * pow(s, 0.7))
				if absf(d.dot(across)) <= width:
					img.set_pixel(px, py, tone.lightened(0.15 * (1.0 - s)))
	img.generate_mipmaps()
	return img
