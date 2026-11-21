extends RefCounted
## Pure maths for the night sky (D-104): where the stars are over the farm at a
## given date and clock hour, and how a catalogue star is drawn. No scene
## access, so tests/test_night_sky.gd can check it directly.
##
## World axes (see map_math.gd / time_of_day.gd): +x east, +y up, -z north.
## Celestial axes: x towards the vernal equinox (RA 0h, Dec 0), z towards the
## north celestial pole, y towards RA 6h.

## Lowden, WA. Longitude doesn't matter: the clock is local solar time.
const LATITUDE := 46.05

## Days from J2000 noon (2000-01-01 12:00 UTC) to noon of the given date.
static func days_since_j2000(year: int, month: int, day: int) -> float:
	var unix := Time.get_unix_time_from_datetime_dict({"year": year, "month": month, "day": day, "hour": 12, "minute": 0, "second": 0})
	return (unix - 946728000.0) / 86400.0

## Local sidereal time in degrees (the right ascension on the meridian) at
## local solar `hour` on the day `days` after J2000 noon. At noon the meridian
## is the mean sun's right ascension; it then advances 15 degrees an hour.
## Good to a few degrees (it ignores the equation of time), which is plenty for
## recognising constellations.
static func sidereal_degrees(days: float, hour: float) -> float:
	return fposmod(280.46 + 0.9856474 * days + 15.0 * (hour - 12.0), 360.0)

## Unit vector in celestial axes for right ascension / declination in degrees.
static func radec_to_vector(ra_deg: float, dec_deg: float) -> Vector3:
	var ra := deg_to_rad(ra_deg)
	var dec := deg_to_rad(dec_deg)
	return Vector3(cos(dec) * cos(ra), cos(dec) * sin(ra), sin(dec))

## Rotation taking celestial vectors to world vectors for an observer at
## `lat_deg` when the sidereal time is `lst_deg`. Its transpose (= inverse)
## takes a view direction in the world to a position on the celestial sphere,
## which is what the sky shader looks up stars with. The zenith of the world
## is (0, 1, 0), and the celestial pole sits `lat_deg` above the northern
## (-z) horizon.
static func celestial_to_world(lat_deg: float, lst_deg: float) -> Basis:
	var phi := deg_to_rad(lat_deg)
	var th := deg_to_rad(lst_deg)
	var sp := sin(phi)
	var cp := cos(phi)
	return Basis(
		Vector3(-sin(th), cp * cos(th), sp * cos(th)),   # where celestial x goes
		Vector3(cos(th), cp * sin(th), sp * sin(th)),    # celestial y
		Vector3(0.0, sp, -cp))                           # celestial z (the pole)

## Altitude above the horizon, in degrees, of a star at (ra, dec) for the
## given latitude and sidereal time (test helper: the same rotation as above).
static func altitude_degrees(ra_deg: float, dec_deg: float, lat_deg: float, lst_deg: float) -> float:
	var world := celestial_to_world(lat_deg, lst_deg) * radec_to_vector(ra_deg, dec_deg)
	return rad_to_deg(asin(clampf(world.y, -1.0, 1.0)))

## Approximate colour of a star of `kelvin` surface temperature, softened
## towards white (to the eye most stars read as white with a tint).
static func star_color(kelvin: float) -> Color:
	var t := clampf(kelvin, 1500.0, 40000.0) / 100.0
	var r := 255.0 if t <= 66.0 else 329.698727446 * pow(t - 60.0, -0.1332047592)
	var g := 99.4708025861 * log(t) - 161.1195681661 if t <= 66.0 else 288.1221695283 * pow(t - 60.0, -0.0755148492)
	var b := 255.0 if t >= 66.0 else (0.0 if t <= 19.0 else 138.5177312231 * log(t - 10.0) - 305.0447927307)
	var c := Color(clampf(r / 255.0, 0.0, 1.0), clampf(g / 255.0, 0.0, 1.0), clampf(b / 255.0, 0.0, 1.0))
	return c.lerp(Color.WHITE, 0.45)

## 0 (faintest drawn) .. 1 (Sirius): how bright a star of visual magnitude
## `mag` is on a perceptual scale.
static func star_level(mag: float) -> float:
	return clampf((5.2 - mag) / 6.7, 0.0, 1.0)

## Peak brightness (0..1) of a star's dot in the star map.
static func star_peak(mag: float) -> float:
	return 0.16 + 0.84 * pow(star_level(mag), 1.3)

## Radius of a star's dot in star-map pixels: brighter stars are bigger.
static func star_sigma(mag: float) -> float:
	return 0.9 + 0.9 * star_level(mag)

## Column / row (in pixels, fractional) of a celestial unit vector in a
## `width` x `height` equirectangular map: right ascension runs along x, and
## declination +90 is the top row.
static func map_pixel(v: Vector3, width: int, height: int) -> Vector2:
	var lon := atan2(v.y, v.x)
	var lat := asin(clampf(v.z, -1.0, 1.0))
	return Vector2((lon / TAU + 0.5) * width, (0.5 - lat / PI) * height)

## --- Planets -------------------------------------------------------------
## Low-precision orbital elements (Paul Schlyter's, good to about a degree for
## a few decades around 2000): per planet [N, i, w, a, e, M] each as
## [value at d=0, change per day], d being days since 1999-12-31 0h UT.
## Enough to put Venus, Mars, Jupiter and Saturn in the right part of the sky.
const PLANETS := [
	{"name": "Venus", "color": Color(1.0, 0.97, 0.88), "mag": -4.0, "elements": [
		[76.6799, 2.46590e-5], [3.3946, 2.75e-8], [54.8910, 1.38374e-5],
		[0.723330, 0.0], [0.006773, -1.302e-9], [48.0052, 1.6021302244]]},
	{"name": "Mars", "color": Color(1.0, 0.55, 0.38), "mag": 0.2, "elements": [
		[49.5574, 2.11081e-5], [1.8497, -1.78e-8], [286.5016, 2.92961e-5],
		[1.523688, 0.0], [0.093405, 2.516e-9], [18.6021, 0.5240207766]]},
	{"name": "Jupiter", "color": Color(1.0, 0.93, 0.8), "mag": -2.3, "elements": [
		[100.4542, 2.76854e-5], [1.3030, -1.557e-7], [273.8777, 1.64505e-5],
		[5.20256, 0.0], [0.048498, 4.469e-9], [19.8950, 0.0830853001]]},
	{"name": "Saturn", "color": Color(1.0, 0.9, 0.7), "mag": 0.7, "elements": [
		[113.6634, 2.38980e-5], [2.4886, -1.081e-7], [339.3939, 2.97661e-5],
		[9.55475, 0.0], [0.055546, -9.499e-9], [316.9670, 0.0334442282]]},
]

static func _elem(pair: Array, d: float) -> float:
	return pair[0] + pair[1] * d

## Eccentric anomaly (radians) for mean anomaly `m_deg` and eccentricity `e`.
static func _kepler(m_deg: float, e: float) -> float:
	var m := deg_to_rad(m_deg)
	var big_e := m + e * sin(m) * (1.0 + e * cos(m))
	for i in 4:
		big_e -= (big_e - e * sin(big_e) - m) / (1.0 - e * cos(big_e))
	return big_e

## Heliocentric ecliptic position (AU) of a body with Schlyter elements.
static func _helio(el: Array, d: float) -> Vector3:
	var n := deg_to_rad(_elem(el[0], d))
	var inc := deg_to_rad(_elem(el[1], d))
	var w := deg_to_rad(_elem(el[2], d))
	var a: float = el[3][0]
	var e := _elem(el[4], d)
	var big_e := _kepler(fposmod(_elem(el[5], d), 360.0), e)
	var xv := a * (cos(big_e) - e)
	var yv := a * sqrt(1.0 - e * e) * sin(big_e)
	var v := atan2(yv, xv)
	var r := sqrt(xv * xv + yv * yv)
	var vw := v + w
	return Vector3(
		r * (cos(n) * cos(vw) - sin(n) * sin(vw) * cos(inc)),
		r * (sin(n) * cos(vw) + cos(n) * sin(vw) * cos(inc)),
		r * sin(vw) * sin(inc))

## The sun's geocentric ecliptic position (AU) on day `d` since 1999-12-31 0h.
static func _sun_ecliptic(d: float) -> Vector3:
	var w := 282.9404 + 4.70935e-5 * d
	var e := 0.016709 - 1.151e-9 * d
	var big_e := _kepler(fposmod(356.0470 + 0.9856002585 * d, 360.0), e)
	var xv := cos(big_e) - e
	var yv := sqrt(1.0 - e * e) * sin(big_e)
	var lon := atan2(yv, xv) + deg_to_rad(w)
	var r := sqrt(xv * xv + yv * yv)
	return Vector3(r * cos(lon), r * sin(lon), 0.0)

## Ecliptic (x toward the equinox) to equatorial axes, same frame as
## radec_to_vector.
static func _ecliptic_to_equatorial(v: Vector3, d: float) -> Vector3:
	var ecl := deg_to_rad(23.4393 - 3.563e-7 * d)
	return Vector3(v.x, v.y * cos(ecl) - v.z * sin(ecl), v.y * sin(ecl) + v.z * cos(ecl))

## Unit vector, in celestial axes, towards planet `index` of PLANETS on `days`
## after J2000 noon.
static func planet_vector(index: int, days: float) -> Vector3:
	var d := days + 1.5  # J2000 noon is 1.5 days after 1999-12-31 0h
	var geo := _helio(PLANETS[index].elements, d) + _sun_ecliptic(d)
	return _ecliptic_to_equatorial(geo, d).normalized()

## Unit vector, in celestial axes, towards the sun on `days` after J2000 noon.
## Used by the tests (to check the planet maths); the game draws the sun disc
## at the directional light's direction, not here (D-120).
static func sun_vector(days: float) -> Vector3:
	var d := days + 1.5
	return _ecliptic_to_equatorial(_sun_ecliptic(d), d).normalized()
