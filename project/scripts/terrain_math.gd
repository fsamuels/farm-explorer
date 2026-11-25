extends RefCounted
## Pure maths for the carved ground (D-140): how deep the ditch and the pond cut
## into the otherwise level farm, kept free of scene access so
## tests/test_terrain.gd can cover it headless.
##
## Everything is in scene metres (+x east, +z south). Heights are 0 on level
## ground and negative where the ground is cut away. The ditch and pond shapes
## come from the owner's traced route (water_data.gd, generated from
## docs/gis/water-features-340732310005.json).
##
## The ditch is a trapezoid cut along each open run: a flat bottom, banks that
## ease in at the lip and the toe, and a top width wide enough that the banks
## stay under 45 degrees (a player can climb out). The pond is the union of
## tapered circles along its spine: the floor drops from the rim to full depth
## over `POND_BANK_RUN`, so narrow necks are shallower than the two lobes.

const WaterData := preload("res://scripts/water_data.gd")

const DITCH_TOP_HALF := WaterData.DITCH_TOP_WIDTH * 0.5
const DITCH_BOTTOM_HALF := WaterData.DITCH_BOTTOM_WIDTH * 0.5

## The pond as capsules, six numbers each: x0, z0, r0, x1, z1, r1 (built once).
static var _pond_capsules := capsules_from_spine(WaterData.POND_SPINE)

## Every open channel that is carved: the irrigation ditch and the pond's overflow.
static var _carved_segments := _joined(WaterData.DITCH_SEGMENTS, WaterData.OUTFLOW_DITCH_SEGMENTS)

static func _joined(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out := a.duplicate()
	out.append_array(b)
	return out

static func smooth(edge0: float, edge1: float, x: float) -> float:
	var t := clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

## Consecutive spine points (x, z, half-width) as capsules (x0, z0, r0, x1, z1, r1).
static func capsules_from_spine(spine: PackedFloat32Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var i := 0
	while i + 5 < spine.size():
		out.append_array(PackedFloat32Array([
			spine[i], spine[i + 1], spine[i + 2],
			spine[i + 3], spine[i + 4], spine[i + 5],
		]))
		i += 3
	return out

## How far the ditch cuts into the ground (metres, >= 0) at `r` metres from its
## centerline. Zero beyond the lip, full depth across the bottom; the banks mix a
## straight slope with a smooth one so the steepest point stays near 40 degrees.
static func ditch_profile(r: float) -> float:
	var u := clampf((DITCH_TOP_HALF - r) / (DITCH_TOP_HALF - DITCH_BOTTOM_HALF), 0.0, 1.0)
	return WaterData.DITCH_DEPTH * (0.5 * u + 0.5 * smooth(0.0, 1.0, u))

## How far the pond cuts into the ground (metres, >= 0) where the signed distance
## to its outline is `sdf` (negative inside).
static func pond_profile(sdf: float) -> float:
	return WaterData.POND_DEPTH * smooth(0.0, WaterData.POND_BANK_RUN, -sdf)

## Signed distance to the pond's cut-back north shore (D-180), a polyline `cut`
## of x, z pairs running east to west: positive on the north side (cut away),
## negative on the south side (pond). It applies only between the line's first
## and last x; elsewhere it is -INF, which leaves the pond as it was.
static func cut_sdf_in(x: float, z: float, cut: PackedFloat32Array) -> float:
	var n := cut.size() / 2
	if n < 2 or x > cut[0] or x < cut[(n - 1) * 2]:
		return -INF
	var p := Vector2(x, z)
	var best := INF
	var line_z := cut[1]
	for k in n - 1:
		var a := Vector2(cut[k * 2], cut[k * 2 + 1])
		var b := Vector2(cut[k * 2 + 2], cut[k * 2 + 3])
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)))
		if x <= a.x and x >= b.x:
			var span := a.x - b.x
			line_z = lerpf(a.y, b.y, (a.x - x) / span) if span > 0.0 else a.y
	return best if z < line_z else -best

## Signed distance from (x, z) to the pond outline given as capsules: negative
## inside, and with the north shore cut back (D-180).
static func pond_sdf_in(x: float, z: float, capsules: PackedFloat32Array) -> float:
	return maxf(_capsule_sdf(x, z, capsules), cut_sdf_in(x, z, WaterData.POND_CUT))

static func _capsule_sdf(x: float, z: float, capsules: PackedFloat32Array) -> float:
	var best := INF
	var i := 0
	while i < capsules.size():
		var ax := capsules[i]
		var az := capsules[i + 1]
		var dx := capsules[i + 3] - ax
		var dz := capsules[i + 4] - az
		var len2 := dx * dx + dz * dz
		var t := 0.0
		if len2 > 0.0:
			t = clampf(((x - ax) * dx + (z - az) * dz) / len2, 0.0, 1.0)
		var d := Vector2(x - (ax + t * dx), z - (az + t * dz)).length() - lerpf(capsules[i + 2], capsules[i + 5], t)
		best = minf(best, d)
		i += 6
	return best

## Distance from (x, z) to the nearest of the ditch segments (ax, az, bx, bz each).
static func ditch_distance_in(x: float, z: float, segments: PackedFloat32Array) -> float:
	var best := INF
	var i := 0
	while i < segments.size():
		var ax := segments[i]
		var az := segments[i + 1]
		var dx := segments[i + 2] - ax
		var dz := segments[i + 3] - az
		var len2 := dx * dx + dz * dz
		var t := 0.0
		if len2 > 0.0:
			t = clampf(((x - ax) * dx + (z - az) * dz) / len2, 0.0, 1.0)
		best = minf(best, Vector2(x - (ax + t * dx), z - (az + t * dz)).length())
		i += 4
	return best

## Ground height at (x, z) given just the ditch segments and pond capsules that
## can reach it. The terrain mesh calls this per tile with the few that matter.
static func height_in(x: float, z: float, ditch_segments: PackedFloat32Array, capsules: PackedFloat32Array) -> float:
	var h := 0.0
	if capsules.size() > 0:
		var sdf := pond_sdf_in(x, z, capsules)
		if sdf < 0.0:
			h = -pond_profile(sdf)
	if ditch_segments.size() > 0:
		var r := ditch_distance_in(x, z, ditch_segments)
		if r < DITCH_TOP_HALF:
			h = minf(h, -ditch_profile(r))
	return h

## Ground height at (x, z): 0 on the level farm, negative in the ditch and pond.
static func height_at(x: float, z: float) -> float:
	return height_in(x, z, _carved_segments, _pond_capsules)

## Signed distance to the pond outline at (x, z): negative inside.
static func pond_sdf(x: float, z: float) -> float:
	return pond_sdf_in(x, z, _pond_capsules)

## Distance to the open (carved) ditch at (x, z).
static func ditch_distance(x: float, z: float) -> float:
	return ditch_distance_in(x, z, _carved_segments)

## Surface normal of the carved ground at (x, z), from a small central difference.
static func normal_at(x: float, z: float, eps := 0.1) -> Vector3:
	var dx := height_at(x - eps, z) - height_at(x + eps, z)
	var dz := height_at(x, z - eps) - height_at(x, z + eps)
	return Vector3(dx, 2.0 * eps, dz).normalized()

## The open channels that are carved (ditch and overflow), ax, az, bx, bz each.
static func carved_segments() -> PackedFloat32Array:
	return _carved_segments

## The pond's capsules (x0, z0, r0, x1, z1, r1 each), for callers that filter them.
static func pond_capsules() -> PackedFloat32Array:
	return _pond_capsules

## Openings cut right through the ground (D-145), such as the House's cellar
## stairwell: six numbers each, cx, cz, ux, uz, half_u, half_v, a rectangle
## centred on (cx, cz) whose first axis runs along the unit vector (ux, uz).
## True when (x, z) lies inside any of them.
static func in_hole(x: float, z: float, holes: PackedFloat32Array) -> bool:
	var i := 0
	while i + 5 < holes.size():
		var dx := x - holes[i]
		var dz := z - holes[i + 1]
		var u := dx * holes[i + 2] + dz * holes[i + 3]
		var v := -dx * holes[i + 3] + dz * holes[i + 2]
		if absf(u) <= holes[i + 4] and absf(v) <= holes[i + 5]:
			return true
		i += 6
	return false
