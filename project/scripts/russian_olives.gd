extends Node3D
## The Russian olives along the farm's north side (D-194): older trees, 15 to
## 25 ft (4.5 to 7.6 m), strung out from (-54.1, -60.3) to (141.2, -70.5), the
## line the owner read off the base imagery. Thin at the west end; along the
## House and its back yard an old-growth thicket (D-199), a band about 17 m
## deep over the grove in the imagery, from 10 m north of the line to 7 m
## south of it, short of the track along the back yard's north fence: tall
## old trees with younger ones coming up between; and thick again in a
## narrower band toward the round corral in the east. The spots are made the
## same way every run from a seed.
##
## Spots are world (x, z) in metres.

const RussianOlive := preload("res://scripts/russian_olive.gd")
const TerrainMath := preload("res://scripts/terrain_math.gd")

const START := Vector2(-54.1, -60.3)
const END := Vector2(141.2, -70.5)
## 15 ft and 25 ft.
const MIN_HEIGHT := 4.6
const MAX_HEIGHT := 7.6
## The young trees under the old growth, grown this tall; their limbs droop,
## so their leaves reach about 10 to 13 ft.
const YOUNG_MIN := 3.7
const YOUNG_MAX := 5.0
const SEED := 1940

## Along the line, x from..to with the gap between trees and how far a tree
## may stand off the line: `north` metres to the north, `south` to the south
## (toward the House). A `forest` stretch is old growth, with an understory.
const STRETCHES := [
	{"to": -5.0, "gap": 7.0, "north": 2.5, "south": 2.5},
	{"to": 95.0, "gap": 1.4, "north": 10.0, "south": 7.0, "forest": true},
	{"to": 142.0, "gap": 3.5, "north": 4.5, "south": 4.5},
]
## The share of the forest's trees that are young ones under the old.
const UNDERSTORY := 0.3
## The forest's trees share VARIANTS grown shapes, each grown POOL_HEIGHT tall
## and scaled to the tree's height and turned, so seventy-odd trees cost
## sixteen meshes to build and hold (the game also runs in a browser).
const VARIANTS := 16
const POOL_HEIGHT := 6.0

## The stretch a point `x` along the line falls in.
static func stretch_at(x: float) -> Dictionary:
	for s in STRETCHES:
		if x <= s.to:
			return s
	return STRETCHES[STRETCHES.size() - 1]

static func spots() -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var out := PackedVector2Array()
	var along := (END - START).normalized()
	var across := Vector2(-along.y, along.x)
	var d := 0.0
	var length := START.distance_to(END)
	while d < length:
		var p := START + along * d
		var stretch := stretch_at(p.x)
		var spot: Vector2 = p + across * rng.randf_range(-stretch.north, stretch.south)
		# Not down in the ditch.
		if TerrainMath.height_at(spot.x, spot.y) > -0.15:
			out.append(spot)
		d += stretch.gap * rng.randf_range(0.7, 1.3)
	return out

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 1
	var all := spots()
	var pool := {}
	for i in all.size():
		# Most are mid-sized; a few are the big old ones. In the forest most
		# are old and tall, with young ones coming up between.
		var height := lerpf(MIN_HEIGHT, MAX_HEIGHT, pow(rng.randf(), 0.8))
		var tree: Node3D
		if stretch_at(all[i].x).get("forest", false):
			height = rng.randf_range(YOUNG_MIN, YOUNG_MAX) if rng.randf() < UNDERSTORY \
					else lerpf(MIN_HEIGHT, MAX_HEIGHT, pow(rng.randf(), 0.45))
			var k := rng.randi() % VARIANTS
			if not pool.has(k):
				pool[k] = RussianOlive.build(SEED + 500 + k, POOL_HEIGHT)
			tree = _scaled(pool[k], height / POOL_HEIGHT)
		else:
			tree = RussianOlive.build(SEED + 10 + i, height)
		tree.name = "RussianOlive%d" % (i + 1)
		tree.position = Vector3(all[i].x, TerrainMath.height_at(all[i].x, all[i].y), all[i].y)
		tree.rotation.y = rng.randf() * TAU
		add_child(tree)
	for k in pool:
		(pool[k] as Node3D).free()

## A tree sharing `template`'s bark and leaf meshes, scaled by `s`, with its
## own trunk collider sized to match (a collider is never scaled).
static func _scaled(template: Node3D, s: float) -> Node3D:
	var root := Node3D.new()
	for part in ["Bark", "Leaves"]:
		var src := template.get_node(part) as MeshInstance3D
		var mi := MeshInstance3D.new()
		mi.name = part
		mi.mesh = src.mesh
		mi.material_override = src.material_override
		mi.scale = Vector3.ONE * s
		root.add_child(mi)
	var src_cs := template.get_node("Trunk").get_child(0) as CollisionShape3D
	var shape := CylinderShape3D.new()
	shape.radius = (src_cs.shape as CylinderShape3D).radius * s
	shape.height = 2.5
	var body := StaticBody3D.new()
	body.name = "Trunk"
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = 1.25
	body.add_child(cs)
	root.add_child(body)
	return root
