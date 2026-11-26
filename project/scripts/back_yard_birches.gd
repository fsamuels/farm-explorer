extends Node3D
## The birches round the back yard (D-192): about forty feet tall, in two
## short north-south lines west of the middle of the yard. The first line is
## where the owner stood each tree; the second runs just west of it, its trees
## between the first line's. Together they close off the yard's north-west and
## leave the way south-west open, a small view out to the wind-farm ridges
## (distant_terrain.gd).
##
## Spots are world (x, z) in metres.

const Birch := preload("res://scripts/birch.gd")

## About 40 ft.
const TREE_HEIGHT := 12.2

## The four the owner placed, north to south in the order given.
const FIRST_LINE := [Vector2(24.5, -30.7), Vector2(23.7, -33.6), Vector2(23.8, -37.9), Vector2(27.4, -40.6)]
## Three more in a line just west of them, between their gaps.
const SECOND_LINE := [Vector2(19.4, -32.2), Vector2(19.1, -36.0), Vector2(19.7, -39.6)]

static func spots() -> PackedVector2Array:
	var out := PackedVector2Array()
	out.append_array(PackedVector2Array(FIRST_LINE))
	out.append_array(PackedVector2Array(SECOND_LINE))
	return out

func _ready() -> void:
	var all := spots()
	for i in all.size():
		var tree := Birch.build(1920 + i, TREE_HEIGHT * (0.92 + 0.16 * fmod(float(i) * 0.618, 1.0)))
		tree.name = "Birch%d" % (i + 1)
		tree.position = Vector3(all[i].x, 0.0, all[i].y)
		tree.rotation.y = float(i) * 2.4
		add_child(tree)
