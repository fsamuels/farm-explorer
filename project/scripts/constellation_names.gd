extends RefCounted
## Names for the constellations whose lines the night sky draws (D-110), each
## with a point near the middle of its pattern as [name, ra_deg, dec_deg]
## (J2000). The labels are placed on screen by time_of_day.gd. Hand-kept: the
## generated star_data.gd has no names, and the anchors only need to sit
## somewhere sensible inside each figure.

const SkyMath := preload("res://scripts/sky_math.gd")

const ENTRIES := [
	["Ursa Major (Big Dipper)", 187.0, 56.0],
	["Ursa Minor (Little Dipper)", 240.0, 80.0],
	["Cassiopeia", 15.0, 60.0],
	["Orion", 83.0, 0.0],
	["Cygnus", 305.0, 40.0],
	["Lyra", 283.0, 36.0],
	["Aquila", 297.0, 8.0],
	["Leo", 163.0, 16.0],
	["Pegasus", 355.0, 22.0],
	["Andromeda", 17.0, 36.0],
	["Scorpius", 244.0, -24.0],
	["Corona Borealis", 235.0, 28.0],
]

## Names are only readable against a properly dark sky, so they show at night
## and not at dusk or dawn (the lines still do), fading in over the last stretch
## of darkness and out with cloud. `stars` is the star level (0..1) and
## `overcast` the cloud cover.
static func label_alpha(stars: float, overcast: float) -> float:
	return smoothstep(0.75, 1.0, clampf(stars, 0.0, 1.0)) * clampf(1.0 - overcast, 0.0, 1.0)

## Unit world direction (+x east, +y up, -z north) of entry `i` at sidereal
## time `lst_deg`.
static func direction(i: int, lst_deg: float) -> Vector3:
	var e: Array = ENTRIES[i]
	return SkyMath.celestial_to_world(SkyMath.LATITUDE, lst_deg) * SkyMath.radec_to_vector(e[1], e[2])

## Whether a direction is clear enough above the horizon to label.
static func above_horizon(dir: Vector3) -> bool:
	return dir.y > 0.03
