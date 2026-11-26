extends Node3D
## The Russian olives along the farm's north side (D-194): older trees, 15 to
## 25 ft (4.5 to 7.6 m), strung out from (-54.1, -60.3) to (141.2, -70.5), the
## line the owner read off the base imagery. Thin at the west end, sparse
## through the middle and thick toward the east end, where the imagery shows
## them in a band beside the round corral. The spots are made the same way
## every run from a seed.
##
## Spots are world (x, z) in metres.

const RussianOlive := preload("res://scripts/russian_olive.gd")
const TerrainMath := preload("res://scripts/terrain_math.gd")

const START := Vector2(-54.1, -60.3)
const END := Vector2(141.2, -70.5)
## 15 ft and 25 ft.
const MIN_HEIGHT := 4.6
const MAX_HEIGHT := 7.6
const SEED := 1940

## Along the line, x from..to with the gap between trees and how far a tree
## may stand off the line either side.
const STRETCHES := [
	{"to": -5.0, "gap": 7.0, "off": 2.5},
	{"to": 75.0, "gap": 13.0, "off": 2.5},
	{"to": 142.0, "gap": 4.5, "off": 4.5},
]

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
		var stretch: Dictionary = STRETCHES[STRETCHES.size() - 1]
		for s in STRETCHES:
			if p.x <= s.to:
				stretch = s
				break
		var spot: Vector2 = p + across * rng.randf_range(-stretch.off, stretch.off)
		# Not down in the ditch.
		if TerrainMath.height_at(spot.x, spot.y) > -0.15:
			out.append(spot)
		d += stretch.gap * rng.randf_range(0.7, 1.3)
	return out

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 1
	var all := spots()
	for i in all.size():
		# Most are mid-sized; a few are the big old ones.
		var height := lerpf(MIN_HEIGHT, MAX_HEIGHT, pow(rng.randf(), 0.8))
		var tree := RussianOlive.build(SEED + 10 + i, height)
		tree.name = "RussianOlive%d" % (i + 1)
		tree.position = Vector3(all[i].x, TerrainMath.height_at(all[i].x, all[i].y), all[i].y)
		tree.rotation.y = rng.randf() * TAU
		add_child(tree)
