extends RefCounted
## The named roads around the farm (D-146): road_data.gd holds each road's
## centreline from Census TIGERweb; this resamples them and builds the ribbon of
## asphalt for one road piece, draped on the ground with world_math.gd.
##
## Roads are resampled to a point every SPACING metres and cut into pieces
## (one per pair of neighbouring points). Each piece belongs to the chunk that
## holds its first point, so world_terrain.gd draws exactly the pieces of the
## chunks it has loaded and nothing is drawn twice.

const RoadData := preload("res://scripts/road_data.gd")
const WorldMath := preload("res://scripts/world_math.gd")

## Metres between resampled centreline points.
const SPACING := 8.0
## Verge of gravel drawn each side of the asphalt.
const SHOULDER := 1.2
## Points across the ribbon (left shoulder edge to right shoulder edge).
const ACROSS := 7
## Lift above the ground so the ribbon never sinks into it.
const LIFT := 0.05
## Roads that cross each other are lifted a little apart so their markings
## don't z-fight: road `i` rides `(i * 7) % 11` of these above the others.
const STACK := 0.004

static var _roads: Array = []
static var _by_chunk: Dictionary = {}

## Every road as {"name", "kind", "width", "points": PackedVector2Array (resampled),
## "along": PackedFloat32Array (metres from the road's start to each point)}.
static func roads() -> Array:
	if _roads.is_empty():
		_build_index()
	return _roads

## Piece lists keyed by chunk: Vector2i -> Array of Vector2i(road index, point index).
static func pieces_in(chunk: Vector2i) -> Array:
	if _roads.is_empty():
		_build_index()
	return _by_chunk.get(chunk, [])

static func _build_index() -> void:
	var raw := Marshalls.base64_to_raw(RoadData.POINTS_B64)
	for row in RoadData.ROADS:
		var first: int = row[3]
		var count: int = row[4]
		var pts := PackedVector2Array()
		for k in count:
			var o := (first + k) * 8
			pts.append(Vector2(raw.decode_float(o), raw.decode_float(o + 4)))
		var sampled := resample(pts, SPACING)
		var along := PackedFloat32Array()
		var s := 0.0
		for k in sampled.size():
			if k > 0:
				s += sampled[k].distance_to(sampled[k - 1])
			along.append(s)
		_roads.append({"name": RoadData.NAMES[row[0]], "kind": row[1], "width": row[2],
				"points": sampled, "along": along})
	for r in _roads.size():
		var p: PackedVector2Array = _roads[r].points
		for k in p.size() - 1:
			var chunk := WorldMath.chunk_at(p[k].x, p[k].y)
			if chunk.x < 0:
				continue
			if not _by_chunk.has(chunk):
				_by_chunk[chunk] = []
			_by_chunk[chunk].append(Vector2i(r, k))

## `points` resampled so neighbours are `spacing` apart along the line (the last
## step may be shorter), keeping the first and last points exactly.
static func resample(points: PackedVector2Array, spacing: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if points.size() < 2:
		return points
	out.append(points[0])
	var carry := 0.0
	for k in range(1, points.size()):
		var a := points[k - 1]
		var b := points[k]
		var seg := a.distance_to(b)
		if seg < 1e-6:
			continue
		var at := spacing - carry
		while at < seg:
			out.append(a.lerp(b, at / seg))
			at += spacing
		carry = seg - (at - spacing)
	if out[out.size() - 1].distance_to(points[points.size() - 1]) > 1e-3:
		out.append(points[points.size() - 1])
	return out

## Direction of the centreline at point `k` (the mean of the two neighbouring
## directions, so joins don't kink).
static func tangent(points: PackedVector2Array, k: int) -> Vector2:
	var before := points[k] - points[maxi(k - 1, 0)]
	var after := points[mini(k + 1, points.size() - 1)] - points[k]
	var t := before.normalized() + after.normalized()
	if t.length() < 1e-4:
		t = after if after.length() > 0.0 else before
	return t.normalized()

## A cross-section of the ribbon at point `k` of road `r`: ACROSS points from
## the left edge to the right edge, at ground height plus the lift.
static func cross_section(road_index: int, k: int) -> PackedVector3Array:
	var road: Dictionary = roads()[road_index]
	var pts: PackedVector2Array = road.points
	var t := tangent(pts, k)
	var right := Vector2(-t.y, t.x)  # to the right of travel; z is south
	var half: float = road.width * 0.5 + SHOULDER
	var out := PackedVector3Array()
	var lift := LIFT + STACK * ((road_index * 7) % 11)
	for a in ACROSS:
		var off := lerpf(-half, half, float(a) / (ACROSS - 1))
		var p: Vector2 = pts[k] + right * off
		out.append(Vector3(p.x, WorldMath.height_at(p.x, p.y) + lift, p.y))
	return out

## Ribbon geometry for the given pieces (Vector2i(road, point) from pieces_in)
## as ArrayMesh arrays. UV.x runs 0..1 across the ribbon, UV.y is metres along
## the road; COLOR is (kind / 2, half-width / 10, shoulder / 10, 1).
static func build_arrays(pieces: Array) -> Array:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for piece in pieces:
		var road_index: int = piece.x
		var k: int = piece.y
		var road: Dictionary = roads()[road_index]
		var half: float = road.width * 0.5
		var tint := Color(road.kind / 2.0, half / 10.0, SHOULDER / 10.0, 1.0)
		var base := vertices.size()
		for end in 2:
			var section := cross_section(road_index, k + end)
			for a in ACROSS:
				vertices.append(section[a])
				normals.append(WorldMath.normal_at(section[a].x, section[a].z))
				uvs.append(Vector2(float(a) / (ACROSS - 1), road.along[k + end]))
				colors.append(tint)
		# The two sections are ACROSS apart in the vertex list; quads join them.
		# The right edge is at +right (t rotated so that travel is -Z for a
		# north-bound road), which makes (left, right, next-left) wind upward.
		for a in ACROSS - 1:
			var l0 := base + a
			var r0 := base + a + 1
			var l1 := base + ACROSS + a
			var r1 := base + ACROSS + a + 1
			for t in [l0, l1, r0, r0, l1, r1]:
				indices.append(t)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays

## Nearest road point to (x, z) within `radius`: {"name", "kind", "distance"} or {}.
static func nearest(x: float, z: float, radius: float) -> Dictionary:
	var here := WorldMath.chunk_at(x, z)
	if here.x < 0:
		return {}
	var best := {}
	var best_d := radius
	var reach := int(ceil(radius / WorldMath.chunk_size()))
	var q := Vector2(x, z)
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			for piece in pieces_in(Vector2i(here.x + dx, here.y + dz)):
				var road: Dictionary = roads()[piece.x]
				var pts: PackedVector2Array = road.points
				var c := Geometry2D.get_closest_point_to_segment(q, pts[piece.y], pts[piece.y + 1])
				var d := c.distance_to(q)
				if d < best_d:
					best_d = d
					best = {"name": road.name, "kind": road.kind, "distance": d}
	return best
