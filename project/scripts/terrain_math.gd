extends RefCounted
## Pure maths for the carved ground (D-138): how deep the ditch and the pond cut
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

## Signed distance from (x, z) to the pond outline given as capsules: negative inside.
static func pond_sdf_in(x: float, z: float, capsules: PackedFloat32Array) -> float:
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
	return height_in(x, z, WaterData.DITCH_SEGMENTS, _pond_capsules)

## Signed distance to the pond outline at (x, z): negative inside.
static func pond_sdf(x: float, z: float) -> float:
	return pond_sdf_in(x, z, _pond_capsules)

## Distance to the open (carved) ditch at (x, z).
static func ditch_distance(x: float, z: float) -> float:
	return ditch_distance_in(x, z, WaterData.DITCH_SEGMENTS)

## Surface normal of the carved ground at (x, z), from a small central difference.
static func normal_at(x: float, z: float, eps := 0.1) -> Vector3:
	var dx := height_at(x - eps, z) - height_at(x + eps, z)
	var dz := height_at(x, z - eps) - height_at(x, z + eps)
	return Vector3(dx, 2.0 * eps, dz).normalized()

## The pond's capsules (x0, z0, r0, x1, z1, r1 each), for callers that filter them.
static func pond_capsules() -> PackedFloat32Array:
	return _pond_capsules
