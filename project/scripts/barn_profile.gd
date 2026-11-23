extends RefCounted
## The Front Barn's cross-section (D-125), read off the north-side photo: a
## tall central section with a low-pitched roof, and a lower lean-to wing each
## side whose roof falls away from the centre. Heights are metres above the
## ground, x is across the barn from its middle (+x east). Shared by the
## facade (barn_facade.gd) and the interior (barn_interior.gd).

## How far in from each side the wing runs (the stalls and the tack room are
## this deep, see barn_interior.gd `side_depth`).
const WING_W := 4.0
## Open bays: the siding on the end faces starts this high; under it you can walk.
const CLEARANCE := 2.3
## The big middle opening: how wide, and the height of its header beam.
const OPENING_W := 4.6
const HEADER := 3.3
## The central roof: eave at the wings, ridge in the middle.
const EAVE := 3.55
const RIDGE := 4.7
## How far each wing roof stands below the middle roof's eave, about a foot as
## in the photo (D-129): a siding riser fills the step.
const STEP := 0.3
## The wing roof: high at the central section, low at the outer wall.
const WING_HIGH := EAVE - STEP
const WING_LOW := 2.6
## The blue corrugated skirt along the bottom of the closed walls.
const SKIRT := 1.1

## Roof height at `x` for a barn `width` wide: the wing slope outside
## +/-(width/2 - WING_W), the central pitch inside it.
static func roof_y(x: float, width: float) -> float:
	var half := width / 2.0
	var junction := half - WING_W
	var a := minf(absf(x), half)
	if a >= junction:
		return lerpf(WING_HIGH, WING_LOW, (a - junction) / WING_W)
	return lerpf(RIDGE, EAVE, a / junction)
