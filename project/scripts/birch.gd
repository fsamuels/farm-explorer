extends RefCounted
## A paper birch made in code (D-192): a tall, slender white trunk with dark
## horizontal scars, a light crown of thin up-swept branches, and small
## yellow-green leaves in clusters at the branch tips. Each tree grows from a
## seed, so a stand of them is not a row of copies.
##
## build() returns a Node3D whose origin is the base of the trunk on the
## ground: one bark mesh, one leaf mesh (crossed cards with an alpha-scissor
## leaf-cluster texture, also made here) and a solid cylinder round the base of
## the trunk. The crown is walk-through.

const SIDES := 7
const BARK_COLOR := Color(0.93, 0.91, 0.85)
const LEAF_COLOR := Color(0.52, 0.62, 0.25)
## Radius of the solid part of the trunk, metres, for a REF_HEIGHT tree; wood
## thickness scales with the tree's height.
const TRUNK_RADIUS := 0.14
const REF_HEIGHT := 12.0
## How far up the trunk the lowest branch is, as a share of the height.
const CROWN_START := 0.3
## A metre of trunk is this much of the bark texture's height.
const BARK_TILE := 1.6

static var _leaf_material: StandardMaterial3D
static var _bark_material: StandardMaterial3D

## A birch about `height` metres tall from `seed`.
static func build(seed: int, height: float) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var bark := SurfaceTool.new()
	bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var scale := height / REF_HEIGHT
	var girth := pow(scale, 0.8)

	# The trunk: nearly straight, wandering a little and thinning to the top.
	var lean := deg_to_rad(rng.randf_range(0.0, 4.0))
	var lean_az := rng.randf() * TAU
	var drift := Vector3(sin(lean) * cos(lean_az), 0, sin(lean) * sin(lean_az))
	var trunk: Array[Vector3] = []
	var radii: Array[float] = []
	var wobble := rng.randf() * TAU
	var steps := 8
	for i in steps + 1:
		var t := float(i) / steps
		var wander := Vector3(sin(wobble + t * 5.0), 0, cos(wobble * 1.3 + t * 4.0)) * 0.12 * scale * t
		trunk.append(Vector3(0, -0.1 + (height * 0.96 + 0.1) * t, 0) + drift * height * t * t + wander)
		radii.append(TRUNK_RADIUS * girth * lerpf(1.0, 0.18, pow(t, 0.8)) * (1.0 + 0.35 * pow(1.0 - t, 6.0)))
	_tube(bark, trunk, radii)

	# Branches spiral up from CROWN_START; they are longest low in the crown and
	# shorten to the top.
	var branches := rng.randi_range(15, 20)
	var az := rng.randf() * TAU
	for i in branches:
		var t := float(i) / (branches - 1)
		var at := CROWN_START + (0.93 - CROWN_START) * t
		az += rng.randf_range(2.0, 2.8)
		var base := _along(trunk, at)
		var reach := height * lerpf(0.26, 0.06, pow(t, 1.2)) * rng.randf_range(0.8, 1.15)
		reach *= lerpf(0.75, 1.0, minf(t * 3.0, 1.0))
		var up := deg_to_rad(rng.randf_range(32.0, 58.0))
		var dir := Vector3(sin(up) * cos(az), cos(up), sin(up) * sin(az))
		_branch(rng, bark, leaves, base, dir, reach, TRUNK_RADIUS * girth * lerpf(0.4, 0.2, t), scale, true)
	# The leader carries a cluster of its own.
	_cluster(rng, leaves, trunk[steps], 1.3 * scale, 3)

	var root := Node3D.new()
	root.name = "Birch"
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

## The trunk's centre line at share `t` (0 to 1) of the way up.
static func _along(trunk: Array[Vector3], t: float) -> Vector3:
	var f := clampf(t, 0.0, 1.0) * (trunk.size() - 1)
	var i := mini(int(f), trunk.size() - 2)
	return trunk[i].lerp(trunk[i + 1], f - i)

## One branch from `start` along `dir`, `length` long: it rises, then its tip
## droops a little under the leaves' weight. Main branches fork once near the
## end; every tip carries a leaf cluster.
static func _branch(rng: RandomNumberGenerator, bark: SurfaceTool, leaves: SurfaceTool, start: Vector3, dir: Vector3, length: float, radius: float, scale: float, fork: bool) -> void:
	var pts: Array[Vector3] = []
	var radii: Array[float] = []
	for i in 4:
		var t := float(i) / 3.0
		pts.append(start + dir * length * t + Vector3.DOWN * length * 0.18 * t * t)
		radii.append(lerpf(radius, radius * 0.35, t))
	_tube(bark, pts, radii)
	var tip_dir := (pts[3] - pts[2]).normalized()
	if fork and length > 1.2 * scale:
		for k in 2:
			var side := _perpendicular(tip_dir).rotated(tip_dir, rng.randf() * TAU)
			var child := (tip_dir + side * rng.randf_range(0.5, 0.9) + Vector3.UP * 0.25).normalized()
			_branch(rng, bark, leaves, pts[2], child, length * rng.randf_range(0.45, 0.6), radii[2], scale, false)
		_cluster(rng, leaves, pts[3], rng.randf_range(0.9, 1.3) * scale, 2)
	else:
		_cluster(rng, leaves, pts[3], rng.randf_range(0.8, 1.2) * scale, 2)
		_cluster(rng, leaves, pts[2], rng.randf_range(0.6, 0.9) * scale, 1)

## A clump of leaves round `at`, `size` metres across: `upright` vertical
## cards crossed through the point, and one flat card so the crown also reads
## from above.
static func _cluster(rng: RandomNumberGenerator, leaves: SurfaceTool, at: Vector3, size: float, upright: int) -> void:
	var half := size / 2.0
	var face := rng.randf() * PI
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for k in upright:
		var across := Vector3(cos(face + k * PI / upright), 0, sin(face + k * PI / upright)) * half
		var quad := [at - across + Vector3.UP * half * 0.8, at + across + Vector3.UP * half * 0.8,
				at + across - Vector3.UP * half * 0.8, at - across - Vector3.UP * half * 0.8]
		for idx in [0, 1, 2, 0, 2, 3]:
			# Lit as if facing up, so both sides of a card read alike.
			leaves.set_normal(Vector3.UP)
			leaves.set_uv(uvs[idx])
			leaves.add_vertex(quad[idx])
	var ax := Vector3(cos(face), 0, sin(face)) * half
	var az := Vector3(-sin(face), 0, cos(face)) * half
	var flat := [at - ax - az, at + ax - az, at + ax + az, at - ax + az]
	for idx in [0, 1, 2, 0, 2, 3]:
		leaves.set_normal(Vector3.UP)
		leaves.set_uv(uvs[idx])
		leaves.add_vertex(flat[idx])

## A tube of SIDES faces through `pts`, radius per point; the bark texture's
## v runs up the tube in `BARK_TILE` metres.
static func _tube(st: SurfaceTool, pts: Array, radii: Array) -> void:
	var rings := []
	var run := 0.0
	for i in pts.size():
		var p: Vector3 = pts[i]
		if i > 0:
			run += p.distance_to(pts[i - 1] as Vector3)
		var forward: Vector3 = ((pts[mini(i + 1, pts.size() - 1)] as Vector3) - (pts[maxi(i - 1, 0)] as Vector3)).normalized()
		var a := _perpendicular(forward)
		var b := forward.cross(a)
		var ring := []
		for s in SIDES + 1:
			var ang := TAU * float(s) / SIDES
			var n := a * cos(ang) + b * sin(ang)
			ring.append([p + n * float(radii[i]), n, Vector2(float(s) / SIDES, run / BARK_TILE)])
		rings.append(ring)
	for i in rings.size() - 1:
		for s in SIDES:
			var quad := [rings[i][s], rings[i][s + 1], rings[i + 1][s + 1], rings[i + 1][s]]
			for idx in [0, 2, 1, 0, 3, 2]:
				st.set_normal(quad[idx][1])
				st.set_uv(quad[idx][2])
				st.add_vertex(quad[idx][0])

static func _perpendicular(v: Vector3) -> Vector3:
	var other := Vector3.RIGHT if absf(v.dot(Vector3.UP)) > 0.9 else Vector3.UP
	return v.cross(other).normalized()

static func bark_material() -> StandardMaterial3D:
	if _bark_material == null:
		var m := StandardMaterial3D.new()
		m.albedo_texture = ImageTexture.create_from_image(bark_image())
		m.roughness = 0.8
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_bark_material = m
	return _bark_material

static func leaf_material() -> StandardMaterial3D:
	if _leaf_material == null:
		var m := StandardMaterial3D.new()
		m.albedo_texture = ImageTexture.create_from_image(cluster_image())
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.4
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.roughness = 0.8
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_leaf_material = m
	return _leaf_material

## White bark, a little warm and grey in patches, with short dark horizontal
## scars (lenticels). Tiles in both directions.
static func bark_image() -> Image:
	var w := 64
	var h := 128
	var img := Image.create(w, h, true, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = 192
	noise.frequency = 0.06
	for y in h:
		for x in w:
			var a := TAU * float(x) / w
			var v := noise.get_noise_3d(cos(a) * 9.0, sin(a) * 9.0, y * 0.7)
			var c := BARK_COLOR * (0.93 + 0.14 * v)
			c.a = 1.0
			img.set_pixel(x, y, c)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1921
	for i in 26:
		var y0 := rng.randi_range(0, h - 1)
		var x0 := rng.randi_range(0, w - 1)
		var run := rng.randi_range(5, 16)
		var tone := rng.randf_range(0.12, 0.3)
		for k in run:
			var px := (x0 + k) % w
			var edge := 0.25 if (k == 0 or k == run - 1) else 0.0
			for dy in 2:
				img.set_pixel(px, (y0 + dy) % h, Color(tone + edge, tone + edge, tone + edge * 0.9, 1))
	img.generate_mipmaps()
	return img

## A spray of small leaves, transparent between them.
static func cluster_image() -> Image:
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1922
	var centre := Vector2(size / 2.0, size / 2.0)
	for i in 70:
		# Leaves cluster toward the middle of the card, thinning at the rim.
		var ang := rng.randf() * TAU
		var r := sqrt(rng.randf()) * size * 0.4
		var p := centre + Vector2(cos(ang), sin(ang)) * r
		var heading := rng.randf() * TAU
		var length := rng.randf_range(9.0, 14.0)
		var half_w := length * rng.randf_range(0.34, 0.46)
		var along := Vector2(cos(heading), sin(heading))
		var across := Vector2(-along.y, along.x)
		var tone := LEAF_COLOR * rng.randf_range(0.8, 1.25)
		tone.a = 1.0
		for py in range(int(p.y - length), int(p.y + length) + 1):
			for px in range(int(p.x - length), int(p.x + length) + 1):
				if px < 0 or px >= size or py < 0 or py >= size:
					continue
				var d := Vector2(px, py) - p
				var s := d.dot(along) / length
				if s < 0.0 or s > 1.0:
					continue
				# Ovate: broad near the stalk, pointed at the tip.
				var width := half_w * (1.0 - s * 0.6) * sin(PI * pow(s, 0.6))
				if absf(d.dot(across)) <= width:
					img.set_pixel(px, py, tone.lightened(0.2 * s))
	img.generate_mipmaps()
	return img
