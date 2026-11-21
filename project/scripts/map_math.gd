extends RefCounted
## Pure helpers for the minimap and the full-screen map (D-93), kept free of
## scene access so tests/test_map_math.gd can cover them headless.
##
## World positions are flattened to Vector2(x, z): +x is east and +z is south,
## so north is up on the map, matching the ground imagery.

const CARDINALS := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
const UNIT_BOX_CORNERS := [
	Vector3(-0.5, 0, -0.5), Vector3(0.5, 0, -0.5),
	Vector3(0.5, 0, 0.5), Vector3(-0.5, 0, 0.5),
]

static func flatten(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z)

static func world_to_screen(world: Vector2, center: Vector2, scale_px: float, view_size: Vector2) -> Vector2:
	return (world - center) * scale_px + view_size * 0.5

static func screen_to_world(screen: Vector2, center: Vector2, scale_px: float, view_size: Vector2) -> Vector2:
	return (screen - view_size * 0.5) / scale_px + center

## The view center after zooming from `scale_px` to `new_scale` so the world
## point under the screen position `pivot` stays under it.
static func zoom_center(center: Vector2, scale_px: float, new_scale: float, pivot: Vector2, view_size: Vector2) -> Vector2:
	var anchor := screen_to_world(pivot, center, scale_px, view_size)
	return anchor - (pivot - view_size * 0.5) / new_scale

## Footprint (x/z corners) of a unit box placed by `xform`, the way every
## building.tscn instance is sized and rotated.
static func box_footprint(xform: Transform3D) -> PackedVector2Array:
	var out := PackedVector2Array()
	for corner in UNIT_BOX_CORNERS:
		out.append(flatten(xform * corner))
	return out

## End points of a fence_segment.tscn, which runs along its local X axis.
static func segment_ends(xform: Transform3D, length: float) -> PackedVector2Array:
	return PackedVector2Array([
		flatten(xform * Vector3(-length / 2.0, 0, 0)),
		flatten(xform * Vector3(length / 2.0, 0, 0)),
	])

static func polygon_center(poly: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for p in poly:
		sum += p
	return sum / maxf(poly.size(), 1)

static func bounds_of(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var rect := Rect2(points[0], Vector2.ZERO)
	for p in points:
		rect = rect.expand(p)
	return rect

## Compass bearing (0 = north, 90 = east) of a node with this Y rotation.
## Godot nodes face -Z, which is north on the map.
static func yaw_to_bearing(yaw: float) -> float:
	return fposmod(rad_to_deg(-yaw), 360.0)

static func bearing_between(from: Vector2, to: Vector2) -> float:
	var d := to - from
	return fposmod(rad_to_deg(atan2(d.x, -d.y)), 360.0)

static func cardinal(bearing: float) -> String:
	return CARDINALS[roundi(fposmod(bearing, 360.0) / 45.0) % 8]

static func format_distance(meters: float) -> String:
	if meters < 1000.0:
		return "%d m" % roundi(meters)
	return "%.1f km" % (meters / 1000.0)

## The longest 1/2/5 × 10^n metre length that fits in `max_px` at `scale_px`
## pixels per metre, for the scale bar.
static func scale_bar_meters(scale_px: float, max_px: float) -> float:
	var max_m := max_px / scale_px
	var magnitude := pow(10.0, floor(log(max_m) / log(10.0)))
	for step in [5.0, 2.0]:
		if step * magnitude <= max_m:
			return step * magnitude
	return magnitude

## Appends `p` to the breadcrumb `trail` in place if it is at least
## `min_spacing` from the last point, dropping the oldest points past
## `max_points`. Returns whether it appended.
static func trail_append(trail: PackedVector2Array, p: Vector2, min_spacing: float, max_points: int) -> bool:
	if not trail.is_empty() and trail[trail.size() - 1].distance_to(p) < min_spacing:
		return false
	trail.append(p)
	if trail.size() > max_points:
		var overflow := trail.size() - max_points
		var kept := trail.slice(overflow)
		trail.clear()
		trail.append_array(kept)
	return true

## Index of the footprint containing `p`, or -1.
static func footprint_at(p: Vector2, footprints: Array) -> int:
	for i in footprints.size():
		if Geometry2D.is_point_in_polygon(p, footprints[i]):
			return i
	return -1

## Index of the footprint containing `p`, else the one whose edge is nearest
## within `max_dist`, else -1.
static func nearest_footprint(p: Vector2, footprints: Array, max_dist: float) -> int:
	var inside := footprint_at(p, footprints)
	if inside != -1:
		return inside
	var best := -1
	var best_dist := max_dist
	for i in footprints.size():
		var poly: PackedVector2Array = footprints[i]
		for j in poly.size():
			var a := poly[j]
			var b := poly[(j + 1) % poly.size()]
			var dist := p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))
			if dist <= best_dist:
				best_dist = dist
				best = i
	return best

## `point` if it lies inside `rect`, else where the line from the rect's
## center toward it crosses the rect's edge. Keeps off-screen markers pinned
## to the border of the minimap.
static func clamp_to_rect_edge(point: Vector2, rect: Rect2) -> Vector2:
	if rect.has_point(point):
		return point
	var c := rect.get_center()
	var d := point - c
	var half := rect.size * 0.5
	var t := INF
	if d.x != 0.0:
		t = minf(t, half.x / absf(d.x))
	if d.y != 0.0:
		t = minf(t, half.y / absf(d.y))
	return c + d * minf(t, 1.0)

## Grid spacing in metres for the map grid (D-97): the smallest "nice" step
## (5, 10, 25, 50, 100, 250 m) whose lines are at least `min_px` apart at
## `scale_px` pixels per metre.
static func grid_step(scale_px: float, min_px: float) -> float:
	for step in [5.0, 10.0, 25.0, 50.0, 100.0, 250.0]:
		if step * scale_px >= min_px:
			return step
	return 500.0

## Every multiple of `step` from `lo` to `hi` inclusive, in ascending order.
static func grid_values(lo: float, hi: float, step: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var v := ceilf(lo / step) * step
	while v <= hi:
		out.append(v)
		v += step
	return out
