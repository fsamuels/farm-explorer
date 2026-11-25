extends RefCounted
## Pure maths for the ditch and pond water (D-141), kept free of scene access so
## tests/test_water.gd can cover it headless.
##
## The ditch is a one-dimensional channel: `ROUTE_SEGMENTS` is the whole run from
## the weir to the pond, open stretches and buried pipes alike, and water on it
## is a row of stations along that route holding how full the channel is there
## (0 empty .. 1 flowing). Each frame the row slides downstream; the weir feeds
## the first station while it is open, and what leaves the last station fills
## the pond. Closing the weir lets the water already in the ditch run on and
## out, rather than vanishing.
##
## The pond is a basin, so its level comes from the volume in it: a table built
## from the carved floor turns volume into level and back, which is why the deep
## lobes fill first and the shallow necks join up later.

const TerrainMath := preload("res://scripts/terrain_math.gd")
const WaterData := preload("res://scripts/water_data.gd")

## Stations along the route (one per ~2 m), the resolution of the ditch water.
const STATIONS := 256
## Share of the ditch's depth that flowing water fills; the rest is freeboard.
const DITCH_MAX_FILL := 0.85
## The pond spills at this level, so it never rises over the rim.
const POND_SPILL_LEVEL := -0.25

## Corners of the box that holds the pond, and how finely it is sampled for the table.
const BASIN_MIN := Vector2(-66.0, -26.0)
const BASIN_MAX := Vector2(138.0, 56.0)
const BASIN_STEP := 1.5
const TABLE_STEPS := 96

static var _route_starts := PackedFloat32Array()
static var _route_length := 0.0
static var _out_starts := PackedFloat32Array()
static var _out_length := 0.0
static var _basin := {}

# --- the routes ------------------------------------------------------------
# Each function takes `overflow`: false for the weir-to-pond ditch, true for the
# overflow that leaves the pond (D-180). Both are chains of segments in flow order.

static func _segments(overflow: bool) -> PackedFloat32Array:
	return WaterData.OUTFLOW_SEGMENTS if overflow else WaterData.ROUTE_SEGMENTS

static func _starts(overflow: bool) -> PackedFloat32Array:
	_ensure_route()
	return _out_starts if overflow else _route_starts

static func _ensure_route() -> void:
	if _route_starts.size() > 0:
		return
	var measured := _measure(WaterData.ROUTE_SEGMENTS)
	_route_starts = measured[0]
	_route_length = measured[1]
	measured = _measure(WaterData.OUTFLOW_SEGMENTS)
	_out_starts = measured[0]
	_out_length = measured[1]

## [distance at the start of each segment, total length] of a chain of segments.
static func _measure(routes: PackedFloat32Array) -> Array:
	var starts := PackedFloat32Array()
	var s := 0.0
	var i := 0
	while i < routes.size():
		starts.append(s)
		s += Vector2(routes[i + 2] - routes[i], routes[i + 3] - routes[i + 1]).length()
		i += 5
	return [starts, s]

## Metres from the weir to the pond inlet along the route (or along the overflow).
static func route_length(overflow := false) -> float:
	_ensure_route()
	return _out_length if overflow else _route_length

static func segment_count(overflow := false) -> int:
	return _starts(overflow).size()

## Distance along the route at the start of segment `i`.
static func segment_start(i: int, overflow := false) -> float:
	return _starts(overflow)[i]

## The segment holding distance `s` along the route.
static func segment_at(s: float, overflow := false) -> int:
	var starts := _starts(overflow)
	var i := starts.size() - 1
	while i > 0 and starts[i] > s:
		i -= 1
	return i

## The point (x, z) at distance `s` along the route.
static func point_at(s: float, overflow := false) -> Vector2:
	var i := segment_at(clampf(s, 0.0, route_length(overflow)), overflow)
	var routes := _segments(overflow)
	var a := Vector2(routes[i * 5], routes[i * 5 + 1])
	var b := Vector2(routes[i * 5 + 2], routes[i * 5 + 3])
	var length := a.distance_to(b)
	return a if length <= 0.0 else a.lerp(b, clampf((s - _starts(overflow)[i]) / length, 0.0, 1.0))

## Which way the route runs at `s` (unit vector in x, z).
static func direction_at(s: float, overflow := false) -> Vector2:
	var i := segment_at(clampf(s, 0.0, route_length(overflow)), overflow)
	var routes := _segments(overflow)
	return (Vector2(routes[i * 5 + 2], routes[i * 5 + 3]) - Vector2(routes[i * 5], routes[i * 5 + 1])).normalized()

static func is_buried_at(s: float, overflow := false) -> bool:
	return _segments(overflow)[segment_at(clampf(s, 0.0, route_length(overflow)), overflow) * 5 + 4] > 0.5

## Distance along the route of the point nearest (x, z), and how far off it is.
static func nearest_on_route(x: float, z: float, overflow := false) -> Vector2:
	var routes := _segments(overflow)
	var starts := _starts(overflow)
	var best := Vector2(0.0, INF)
	var p := Vector2(x, z)
	for i in segment_count(overflow):
		var a := Vector2(routes[i * 5], routes[i * 5 + 1])
		var b := Vector2(routes[i * 5 + 2], routes[i * 5 + 3])
		var closest := Geometry2D.get_closest_point_to_segment(p, a, b)
		var d := p.distance_to(closest)
		if d < best.y:
			best = Vector2(starts[i] + a.distance_to(closest), d)
	return best

# --- the ditch water ------------------------------------------------------

## A fresh row of stations, all of them `fill` (0 empty .. 1 flowing).
static func new_flow(fill := 0.0) -> PackedFloat32Array:
	var flow := PackedFloat32Array()
	flow.resize(STATIONS)
	flow.fill(fill)
	return flow

## Slide the water downstream by `shift` stations (fractional), feeding the
## first station `inlet` (1 with the weir open, 0 shut). Linear interpolation
## spreads fronts out a little, the way a real surge rounds off.
static func advect(flow: PackedFloat32Array, shift: float, inlet: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(flow.size())
	for i in flow.size():
		var from := float(i) - shift
		if from < 0.0:
			out[i] = lerpf(inlet, flow[0], clampf(from + 1.0, 0.0, 1.0)) if from > -1.0 else inlet
		else:
			var lo := int(from)
			var t := from - lo
			out[i] = lerpf(flow[lo], flow[mini(lo + 1, flow.size() - 1)], t)
	return out

## One frame of ditch water: advance `dt` seconds with the water taking
## `travel_seconds` to run the whole route.
static func flow_step(flow: PackedFloat32Array, weir_open: bool, travel_seconds: float, dt: float) -> PackedFloat32Array:
	var shift := float(flow.size()) * dt / maxf(travel_seconds, 0.01)
	return advect(flow, shift, 1.0 if weir_open else 0.0)

## How much of the ditch's full flow reaches the pond: the last station.
static func outflow(flow: PackedFloat32Array) -> float:
	return flow[flow.size() - 1]

## Water depth (metres above the ditch floor) where the row holds `fill`, with
## `rain_pool` (0..1) of standing water from rain as a floor under it.
static func ditch_water_depth(fill: float, rain_pool := 0.0) -> float:
	return maxf(fill, rain_pool) * WaterData.DITCH_DEPTH * DITCH_MAX_FILL

## Water depth at distance `s` along the route.
static func ditch_depth_at(flow: PackedFloat32Array, s: float, rain_pool := 0.0, overflow := false) -> float:
	var f := clampf(s / maxf(route_length(overflow), 0.001), 0.0, 1.0) * float(flow.size() - 1)
	var lo := int(f)
	var fill := lerpf(flow[lo], flow[mini(lo + 1, flow.size() - 1)], f - lo)
	return ditch_water_depth(fill, rain_pool)

# --- the pond basin -------------------------------------------------------

## The pond's own floor height at (x, z): 0 outside it, negative inside. The
## ditch is left out; it never touches the pond.
static func pond_floor(x: float, z: float) -> float:
	return -TerrainMath.pond_profile(TerrainMath.pond_sdf(x, z))

static func _ensure_basin() -> void:
	if not _basin.is_empty():
		return
	var floors := PackedFloat32Array()
	var x := BASIN_MIN.x
	while x <= BASIN_MAX.x:
		var z := BASIN_MIN.y
		while z <= BASIN_MAX.y:
			var h := pond_floor(x, z)
			if h < -0.001:
				floors.append(h)
			z += BASIN_STEP
		x += BASIN_STEP
	floors.sort()
	# prefix[k] = sum of the k lowest floor heights.
	# 64-bit: a wide flat floor puts many cells at the same height, and a 32-bit
	# running sum of them loses thousands of cubic metres.
	var prefix := PackedFloat64Array()
	prefix.resize(floors.size() + 1)
	for k in floors.size():
		prefix[k + 1] = prefix[k] + floors[k]
	var cell := BASIN_STEP * BASIN_STEP
	var levels := PackedFloat32Array()
	var volumes := PackedFloat32Array()
	var areas := PackedFloat32Array()
	for k in TABLE_STEPS + 1:
		var level := -WaterData.POND_DEPTH + WaterData.POND_DEPTH * float(k) / TABLE_STEPS
		var count := floors.bsearch(level)
		levels.append(level)
		volumes.append(cell * (count * level - prefix[count]))
		areas.append(cell * count)
	_basin = {"levels": levels, "volumes": volumes, "areas": areas}

## Water the pond holds at `level` (m), in cubic metres.
static func pond_volume_at(level: float) -> float:
	_ensure_basin()
	return _interp(_basin["levels"], _basin["volumes"], level)

## Water surface area at `level`, in square metres.
static func pond_area_at(level: float) -> float:
	_ensure_basin()
	return _interp(_basin["levels"], _basin["areas"], level)

## The level the pond reaches holding `volume` cubic metres.
static func pond_level_at(volume: float) -> float:
	_ensure_basin()
	return _interp(_basin["volumes"], _basin["levels"], volume)

## What the pond holds when full, at its spill level.
static func pond_capacity() -> float:
	return pond_volume_at(POND_SPILL_LEVEL)

## Piecewise-linear lookup: y at x, clamped to the table, for rising `xs`.
static func _interp(xs: PackedFloat32Array, ys: PackedFloat32Array, x: float) -> float:
	if x <= xs[0]:
		return ys[0]
	if x >= xs[xs.size() - 1]:
		return ys[ys.size() - 1]
	var hi := maxi(xs.bsearch(x), 1)
	var lo := hi - 1
	var span := xs[hi] - xs[lo]
	return ys[lo] if span <= 0.0 else lerpf(ys[lo], ys[hi], (x - xs[lo]) / span)

## One frame of the pond: `inflow` (0..1 of the weir's full flow reaching it),
## `rain` (the rain's share of a full fill per second) and the slow loss to
## evaporation and seepage. Returns the new volume, held between empty and the
## spill level. Rates are fractions of the pond's capacity per second.
static func pond_step(volume: float, inflow: float, fill_per_second: float, rain_per_second: float, loss_per_second: float, dt: float) -> float:
	var capacity := pond_capacity()
	return clampf(volume + _pond_rate(volume, inflow, fill_per_second, rain_per_second, loss_per_second) * dt * capacity, 0.0, capacity)

## Net change in the pond, as a fraction of its capacity per second.
static func _pond_rate(volume: float, inflow: float, fill_per_second: float, rain_per_second: float, loss_per_second: float) -> float:
	var level := pond_level_at(volume)
	var wet_share := clampf(pond_area_at(level) / maxf(pond_area_at(POND_SPILL_LEVEL), 1.0), 0.25, 1.0)
	return inflow * fill_per_second + rain_per_second - loss_per_second * wet_share

## True while the pond is at its spill level with more water coming in than it
## loses, so the extra runs out through the overflow (D-180). Same arguments as `pond_step`.
static func pond_spills(volume: float, inflow: float, fill_per_second: float, rain_per_second: float, loss_per_second: float) -> bool:
	return volume >= pond_capacity() * 0.999 and _pond_rate(volume, inflow, fill_per_second, rain_per_second, loss_per_second) > 0.0
