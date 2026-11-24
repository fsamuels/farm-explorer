extends RefCounted
## The fire's fuel grid and its spread (D-156). Pure: no scene, no clock, no
## audio, so tests/test_fire.gd can run a burn headless in a blink.
##
## The ground beside the ditch is cut into square cells. Each holds some fuel
## (0 bare .. 1 thick dry grass), belongs to a zone (the strip we mean to burn,
## or land that must not burn), and is unburnt, burning or burnt. A burning cell
## lights its eight neighbours at a rate that depends on the fuel, the wind
## along the line between them (downwind is several times faster than upwind),
## the slope (fire runs uphill) and how wet the cell is. Burning cells also
## throw embers downwind, harder in a gust, which can land well past the
## nearest fuel. Rain slows ignition and puts fires out.
##
## Cell (cx, cz) covers world x in [origin.x + cx * size, +size) and the same in
## z, with +x east and +z south as everywhere in the scene.

const NONE := 0
const TARGET := 1
const PROTECTED := 2

const UNBURNT := 0
const BURNING := 1
const BURNT := 2

## Chance per second (before the wind, fuel and slope factors) that a burning
## cell lights one neighbour.
const BASE_RATE := 0.06
## Spread speeds up by exp(WIND_K * wind speed along the line, in m/s).
const WIND_K := 0.3
const WIND_FACTOR_MIN := 0.05
const WIND_FACTOR_MAX := 12.0
const SLOPE_K := 2.0
## A cell burns this long (seconds): thin grass is quick, thick weeds linger.
const BURN_MIN := 4.0
const BURN_FUEL := 8.0
## Embers per burning cell per second, per (m/s of wind) squared.
const SPOT_RATE := 0.00004
const SPOT_MIN_DISTANCE := 2.0
## How far an ember flies per m/s of wind, at most.
const SPOT_PER_WIND := 1.2
## Chance that an ember lights the unburnt, dry fuel it lands on.
const SPOT_LIGHTS := 0.45
## Rain (wetness 1) puts a burning cell out at this rate per second.
const RAIN_OUT_RATE := 0.35
## Wetness above this and nothing will light.
const WET_NO_LIGHT := 0.75

const NEIGHBOURS := [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]

var width := 0
var height := 0
var origin := Vector2.ZERO
var cell_size := 1.0

var fuel := PackedFloat32Array()
var zone := PackedByteArray()
var ground := PackedFloat32Array()
## 0 dry .. 1 soaked: standing water in the ditch, or a hosed strip.
var moisture := PackedFloat32Array()
var state := PackedByteArray()
var left := PackedFloat32Array()
var total := PackedFloat32Array()
## Indices of the burning cells.
var burning := PackedInt32Array()

## Cells with fuel, per zone, and how many of them have been lit.
var target_total := 0
var protected_total := 0
var target_lit := 0
var protected_lit := 0
## Embers that landed on fuel, whether or not they took.
var embers := 0

var rng := RandomNumberGenerator.new()
## Set when something changed that the picture needs to redraw.
var dirty := true

func _init(w: int, h: int, grid_origin: Vector2, size := 1.0, seed_value := 1) -> void:
	width = w
	height = h
	origin = grid_origin
	cell_size = size
	var n := w * h
	fuel.resize(n)
	zone.resize(n)
	ground.resize(n)
	moisture.resize(n)
	state.resize(n)
	left.resize(n)
	total.resize(n)
	rng.seed = seed_value

func index(cx: int, cz: int) -> int:
	return cz * width + cx

func in_bounds(cx: int, cz: int) -> bool:
	return cx >= 0 and cz >= 0 and cx < width and cz < height

## The cell holding world point (x, z), or -1 outside the grid.
func cell_at(x: float, z: float) -> int:
	var cx := int(floor((x - origin.x) / cell_size))
	var cz := int(floor((z - origin.y) / cell_size))
	return index(cx, cz) if in_bounds(cx, cz) else -1

## World position of the middle of cell `i`.
func center_of(i: int) -> Vector2:
	return origin + Vector2((i % width) + 0.5, (i / width) + 0.5) * cell_size

## Set a cell's starting fuel, zone and ground height. Call before the burn,
## then `count_fuel()`.
func set_cell(i: int, fuel_amount: float, zone_id: int, ground_height := 0.0) -> void:
	fuel[i] = fuel_amount
	zone[i] = zone_id
	ground[i] = ground_height

func count_fuel() -> void:
	target_total = 0
	protected_total = 0
	for i in fuel.size():
		if fuel[i] > 0.0:
			if zone[i] == TARGET:
				target_total += 1
			elif zone[i] == PROTECTED:
				protected_total += 1

## Put every cell back to unburnt (the grass has grown back).
func regrow() -> void:
	state.fill(UNBURNT)
	left.fill(0.0)
	total.fill(0.0)
	burning.clear()
	target_lit = 0
	protected_lit = 0
	embers = 0
	dirty = true

## Light cell `i` if it has fuel, isn't alight or burnt, and isn't too wet.
func ignite_cell(i: int) -> bool:
	if i < 0 or state[i] != UNBURNT or fuel[i] <= 0.0 or moisture[i] >= WET_NO_LIGHT:
		return false
	state[i] = BURNING
	total[i] = BURN_MIN + BURN_FUEL * fuel[i]
	left[i] = total[i]
	burning.append(i)
	if zone[i] == TARGET:
		target_lit += 1
	elif zone[i] == PROTECTED:
		protected_lit += 1
	dirty = true
	return true

## Light every cell whose centre is within `radius` of (x, z). Returns how many took.
func ignite_at(x: float, z: float, radius: float) -> int:
	var lit := 0
	var r_cells := int(ceil(radius / cell_size))
	var cx0 := int(floor((x - origin.x) / cell_size))
	var cz0 := int(floor((z - origin.y) / cell_size))
	for dz in range(-r_cells, r_cells + 1):
		for dx in range(-r_cells, r_cells + 1):
			var cx := cx0 + dx
			var cz := cz0 + dz
			if not in_bounds(cx, cz):
				continue
			var i := index(cx, cz)
			if center_of(i).distance_to(Vector2(x, z)) <= radius + cell_size * 0.5 and ignite_cell(i):
				lit += 1
	return lit

## How much faster than still air a fire spreads along `dir` (a unit vector)
## in `wind` (m/s).
static func wind_factor(wind: Vector2, dir: Vector2) -> float:
	return clampf(exp(WIND_K * wind.dot(dir)), WIND_FACTOR_MIN, WIND_FACTOR_MAX)

## The speed-up for spreading uphill (`slope` is rise over run), slowing downhill.
static func slope_factor(slope: float) -> float:
	return clampf(exp(SLOPE_K * slope), 0.4, 2.5)

## Per-second chance that a burning cell lights its neighbour at offset `step`.
func spread_rate(from: int, to: int, step: Vector2i, wind: Vector2) -> float:
	var dist := Vector2(step).length() * cell_size
	var dir := Vector2(step).normalized()
	var rate := BASE_RATE * (0.3 + 0.7 * fuel[to]) * wind_factor(wind, dir)
	rate *= slope_factor((ground[to] - ground[from]) / dist)
	rate *= 1.0 / Vector2(step).length()
	return rate * (1.0 - moisture[to])

## Advance the fire by `dt` seconds in `wind` (m/s, a velocity in x/z) and
## `wetness` (0 dry .. 1 pouring rain or snow).
func step(dt: float, wind: Vector2, wetness := 0.0) -> void:
	if burning.is_empty():
		return
	var light_scale := 1.0 - clampf(wetness * 1.3, 0.0, 1.0)
	var out_chance := 1.0 - exp(-RAIN_OUT_RATE * wetness * dt)
	var speed := wind.length()
	var spot_chance := SPOT_RATE * speed * speed * dt
	var finished: Array[int] = []
	# Cells lit this step join `burning` after the loop, so they don't spread
	# in the same step they were lit.
	var lit: Array[int] = []
	for k in burning.size():
		var i := burning[k]
		left[i] -= dt
		if left[i] <= 0.0 or (out_chance > 0.0 and rng.randf() < out_chance):
			finished.append(i)
			continue
		var cx := i % width
		var cz := i / width
		if light_scale > 0.0:
			for step_vec in NEIGHBOURS:
				var nx: int = cx + step_vec.x
				var nz: int = cz + step_vec.y
				if not in_bounds(nx, nz):
					continue
				var j := index(nx, nz)
				if state[j] != UNBURNT or fuel[j] <= 0.0:
					continue
				var p := 1.0 - exp(-spread_rate(i, j, step_vec, wind) * light_scale * dt)
				if rng.randf() < p:
					lit.append(j)
		if spot_chance > 0.0 and rng.randf() < spot_chance * fuel[i]:
			_throw_ember(i, wind, light_scale, lit)
	for i in finished:
		state[i] = BURNT
		left[i] = 0.0
		_remove_burning(i)
	for j in lit:
		ignite_cell(j)
	if not finished.is_empty() or not lit.is_empty():
		dirty = true

func _throw_ember(from: int, wind: Vector2, light_scale: float, lit: Array[int]) -> void:
	var speed := wind.length()
	if speed < 0.01:
		return
	var dir := wind / speed
	var dist := SPOT_MIN_DISTANCE + rng.randf() * speed * SPOT_PER_WIND
	var side := Vector2(-dir.y, dir.x) * rng.randfn(0.0, dist * 0.2)
	var land := center_of(from) + dir * dist + side
	var j := cell_at(land.x, land.y)
	if j < 0 or state[j] != UNBURNT or fuel[j] <= 0.0:
		return
	embers += 1
	if rng.randf() < SPOT_LIGHTS * (1.0 - moisture[j]) * light_scale:
		lit.append(j)

func _remove_burning(i: int) -> void:
	for k in burning.size():
		if burning[k] == i:
			burning[k] = burning[burning.size() - 1]
			burning.resize(burning.size() - 1)
			return

## Put out every burning cell in `zone_id` (the fire department arriving).
## Returns how many.
func extinguish_zone(zone_id: int) -> int:
	var put_out := 0
	var keep := PackedInt32Array()
	for i in burning:
		if zone[i] == zone_id:
			state[i] = BURNT
			left[i] = 0.0
			put_out += 1
		else:
			keep.append(i)
	burning = keep
	if put_out > 0:
		dirty = true
	return put_out

## Burn progress of cell `i`, 0 untouched .. 1 burnt out.
func burn_progress(i: int) -> float:
	match state[i]:
		BURNING:
			return clampf(1.0 - left[i] / maxf(total[i], 0.001), 0.0, 1.0)
		BURNT:
			return 1.0
	return 0.0

## Flame strength of cell `i`, 0..1: it takes a moment to catch, burns hot, then dies down.
func flame_strength(i: int) -> float:
	if state[i] != BURNING:
		return 0.0
	var p := burn_progress(i)
	return clampf(minf(p / 0.12, (1.0 - p) / 0.45), 0.0, 1.0)

## Share of the target strip's fuel that has been lit, 0..1.
func target_coverage() -> float:
	return float(target_lit) / float(target_total) if target_total > 0 else 0.0

## Wind (m/s, x east and z south) at `time` seconds, blowing mostly toward
## `base_dir` at `base_speed`, wandering a few tens of degrees either side and
## gusting now and then. A sum of slow sines, so it is smooth, repeatable and
## needs no state.
static func wind_at(time: float, base_dir: Vector2, base_speed: float) -> Vector2:
	var angle := base_dir.angle() + 0.35 * sin(time * 0.031 + 1.3) + 0.15 * sin(time * 0.113 + 0.4)
	var gust := maxf(0.0, sin(time * 0.37) * sin(time * 0.91 + 1.1)) * 0.6
	var speed := base_speed * (1.0 + 0.25 * sin(time * 0.047) + 0.2 * sin(time * 0.21 + 2.0) + gust)
	return Vector2.from_angle(angle) * maxf(speed, 0.5)
