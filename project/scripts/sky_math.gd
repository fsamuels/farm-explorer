extends RefCounted
## Pure maths for the night sky (D-101): where the stars are over the farm at a
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
