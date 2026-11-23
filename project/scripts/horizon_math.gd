extends RefCounted
## The pure maths behind the distant terrain and wind turbines (D-133), kept
## apart from the node that builds them so the tests can check it without a
## scene. horizon_data.gd holds the real elevations and turbine positions;
## this turns them into what the game draws:
##
## * Vertical exaggeration. The Blue Mountains rise only 1-1.7 degrees above
##   the farm's horizon at real scale, so heights are stretched by up to
##   EXAGGERATION, ramped in with distance (none within EXAGGERATION_START, all
##   of it past EXAGGERATION_FULL) so nearby hills keep their real shape while
##   the far ranges read like the user's telephoto photos. Bearings and
##   distances stay real, so the parallax as you walk around is right.
## * Earth curvature (with standard refraction), which sinks the far plains.
## * Flattening near the farm: inside NEAR_FLAT the ground sits just under the
##   farm's own ground plane, rising to the real terrain by NEAR_REAL.
## * Distance squeezing (`compressed_distance`), applied in the shaders: the
##   camera's far plane is 4 km and the Blue Mountains are 35-65 km away, so
##   each vertex is pulled along its line of sight from the camera to a
##   distance under SQUEEZE_MAX. Its direction, and so where it appears on
##   screen, doesn't change; only depth is compressed, and in order, so nearer
##   ridges still hide farther ones. shaders/horizon.gdshaderinc has the same
##   formula and constants (test_horizon.gd checks they match).

const HorizonData := preload("res://scripts/horizon_data.gd")

const EXAGGERATION := 2.5
const EXAGGERATION_START := 5000.0
const EXAGGERATION_FULL := 30000.0
const EARTH_RADIUS := 6371000.0
## Standard atmospheric refraction: light bends over the curve, so the earth
## looks this much flatter than it is.
const REFRACTION := 0.13
const NEAR_FLAT := 350.0
const NEAR_REAL := 900.0
## Height of the flattened ground near the farm: just under the ground plane.
const NEAR_Y := -0.5
const SQUEEZE_START := 2400.0
const SQUEEZE_RANGE := 1150.0
const SQUEEZE_SCALE := 25000.0
const SQUEEZE_MAX := SQUEEZE_START + SQUEEZE_RANGE
## A far nacelle may be drawn at most this many times its true size.
const NACELLE_MAX_STRETCH := 2.0
## Rotor tip speed (m/s) used to give each turbine a believable spin rate.
const TIP_SPEED := 70.0

## How much heights are stretched at distance `r` (m) from the farm.
static func exaggeration(r: float) -> float:
	return 1.0 + (EXAGGERATION - 1.0) * smoothstep(EXAGGERATION_START, EXAGGERATION_FULL, r)

## How far the earth's curve (less refraction) drops the ground at distance `r`.
static func curvature_drop(r: float) -> float:
	return r * r * (1.0 - REFRACTION) / (2.0 * EARTH_RADIUS)

## Scene height (y, m) of ground with real elevation `elevation` at distance
## `r` from the farm.
static func scene_height(elevation: float, r: float) -> float:
	var real := (elevation - HorizonData.OBSERVER_ELEVATION) * exaggeration(r) - curvature_drop(r)
	return lerpf(NEAR_Y, real, smoothstep(NEAR_FLAT, NEAR_REAL, r))

## Pull a distance `d` (m, from the camera) in under the far plane. Distances up
## to SQUEEZE_START are unchanged; beyond, they approach SQUEEZE_MAX. Always
## increasing, so depth order survives.
static func compressed_distance(d: float) -> float:
	if d <= SQUEEZE_START:
		return d
	return SQUEEZE_START + SQUEEZE_RANGE * (1.0 - exp(-(d - SQUEEZE_START) / SQUEEZE_SCALE))

## Compass bearing (degrees, 0 = north, clockwise) of scene point (x, z).
static func bearing(x: float, z: float) -> float:
	return fposmod(rad_to_deg(atan2(x, -z)), 360.0)

## Scene (x, z) of the point `r` metres out on compass bearing `bearing_deg`.
static func polar_point(bearing_deg: float, r: float) -> Vector2:
	var b := deg_to_rad(bearing_deg)
	return Vector2(r * sin(b), -r * cos(b))

## The elevation grid from horizon_data.gd, in metres: RINGS.size() rows of
## COLUMNS values each.
static func decode_heights(b64: String) -> PackedFloat32Array:
	var raw := Marshalls.base64_to_raw(b64)
	var out := PackedFloat32Array()
	out.resize(raw.size() / 2)
	for i in out.size():
		out[i] = raw.decode_s16(i * 2) * 0.1
	return out

## Real elevation (m) at scene point (x, z), read off the grid the same way the
## terrain mesh is drawn: linear between rings, linear between columns.
## Outside the outermost ring it uses that ring.
static func elevation_at(heights: PackedFloat32Array, rings: Array, columns: int, x: float, z: float) -> float:
	var r := Vector2(x, z).length()
	var col := bearing(x, z) / (360.0 / columns)
	var c0 := int(floor(col)) % columns
	var c1 := (c0 + 1) % columns
	var fc: float = col - floor(col)
	var i := 0
	while i < rings.size() - 2 and r > rings[i + 1]:
		i += 1
	var fr: float = clampf((r - rings[i]) / (rings[i + 1] - rings[i]), 0.0, 1.0)
	var a := lerpf(heights[i * columns + c0], heights[i * columns + c1], fc)
	var b := lerpf(heights[(i + 1) * columns + c0], heights[(i + 1) * columns + c1], fc)
	return lerpf(a, b, fr)

## Rotor speed (radians a second) for a rotor `diameter` metres across, from a
## typical tip speed: older small rotors spin fast, big new ones slowly.
static func rotor_speed(diameter: float) -> float:
	var rpm := clampf(TIP_SPEED * 60.0 / (PI * maxf(diameter, 1.0)), 8.0, 30.0)
	return rpm * TAU / 60.0

## Scale of a turbine's nacelle (modelled for a 100 m rotor) for a rotor
## `rotor` metres across, stretched by `s`, `min_width` being the thinnest it
## should draw at its distance. Kept to at most twice its true size: the
## distance floor alone grows without limit and made far nacelles bigger than
## their towers.
static func nacelle_scale(rotor: float, s: float, min_width: float) -> float:
	var true_scale := rotor / 100.0 * s
	return clampf(min_width / 4.0, true_scale, true_scale * NACELLE_MAX_STRETCH)

## How much to enlarge a warning light beyond its nacelle's scale so it is
## still about as big on screen as the distance floor asks (>= 1).
static func beacon_boost(head_scale: float, min_width: float) -> float:
	return maxf(1.0, (min_width / 4.0) / maxf(head_scale, 1e-3))

## `speed` (rad/s) nudged so a whole number of turns fits in `period` seconds:
## shader TIME wraps every `period` (time_rollover_secs, 3600 by default), and
## this keeps the blades from jumping when it does. Under 0.1 % off.
static func loop_safe_speed(speed: float, period: float) -> float:
	if speed <= 0.0 or period <= 0.0:
		return speed
	return maxf(1.0, roundf(speed * period / TAU)) * TAU / period

## How much haze (0..1) lies between the camera and ground `d` metres away,
## for an extinction of `per_metre`.
static func haze(d: float, per_metre: float) -> float:
	return 1.0 - exp(-d * per_metre)

## Extinction per metre for the distant terrain: clear-air haze plus what the
## weather adds (cloud cover, fog density added by the fog weathers, wildfire
## smoke and falling snow, all as TimeOfDay / Weather hold them).
static func haze_per_metre(overcast: float, fog_extra: float, smoke: float, snowing: bool) -> float:
	return 1.6e-5 + overcast * 2.0e-5 + fog_extra * 0.05 + smoke * 2.0e-4 + (1.5e-4 if snowing else 0.0)

## How dark it is (0 = day, 1 = night) from the sky colour: turbine warning
## lights come on as it falls.
static func darkness(sky_color: Color) -> float:
	return 1.0 - smoothstep(0.12, 0.4, sky_color.get_luminance())
