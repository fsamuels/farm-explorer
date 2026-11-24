extends RefCounted
## Pure maths for swimming (D-151), kept free of scene access so
## tests/test_swim.gd can cover it headless.
##
## You swim once the water is deeper than `ENTER_DEPTH` where you stand and walk
## again once it is shallower than `EXIT_DEPTH` (the gap stops a bobbing swimmer
## flickering between the two). While swimming the body floats with the origin
## `DRAFT` metres under the surface, so the eyes (1.6 m up) sit just above it.
##
## The stroke is a breaststroke: one `phase` (0..1) per stroke. The pull sweeps
## the arms out and back, the recovery tucks the hands under the chin and the
## legs draw up and kick, then both stretch out to glide. Directions are for an
## upright model (rest pose): +Y is the way the swimmer heads once laid flat,
## +Z is the way the belly faces (down toward the floor), +X is the swimmer's
## left. `arm_dirs` and `leg_dirs` return where each bone should point.

const ENTER_DEPTH := 1.5
const EXIT_DEPTH := 1.3
## How far the player's origin sits below the water surface while floating.
const DRAFT := 1.45
## Ground speed of a steady stroke, and with Shift held.
const SPEED := 2.0
const SLOW_SPEED := 1.0
## Seconds per stroke while swimming, and how much slower the stroke ticks over
## while just treading water.
const STROKE_SECONDS := 3.0
const IDLE_STROKE_RATE := 0.3
## Pitch (radians) of the body from upright to flat on the water.
const BODY_PITCH := deg_to_rad(86.0)

## Whether the player is swimming given the water `depth` where they stand and
## whether they `was_swimming` a moment ago.
static func is_swimming(depth: float, was_swimming: bool) -> bool:
	return depth >= (EXIT_DEPTH if was_swimming else ENTER_DEPTH)

static func swim_speed(slow: bool) -> float:
	return SLOW_SPEED if slow else SPEED

## The height the origin floats at: `DRAFT` under `surface`, with a small bob.
static func float_y(surface: float, time: float) -> float:
	return surface - DRAFT + 0.04 * sin(time * 2.1)

## Vertical speed that closes the gap to `target_y` smoothly, capped so a drop
## from a jump settles instead of bouncing.
static func float_velocity(y: float, target_y: float) -> float:
	return clampf((target_y - y) * 6.0, -4.0, 4.0)

## Advance the stroke phase by `delta` seconds: full rate while moving through
## the water, a slow tread when still.
static func advance_phase(phase: float, delta: float, moving: bool) -> float:
	var rate := 1.0 if moving else IDLE_STROKE_RATE
	return fposmod(phase + delta * rate / STROKE_SECONDS, 1.0)

## Piecewise-smooth lookup: the value of `keys` (an array of [phase, value]
## sorted by phase, first at 0 and last at 1) at `phase`.
static func _curve(keys: Array, phase: float) -> float:
	for i in range(1, keys.size()):
		if phase <= keys[i][0]:
			var a: Array = keys[i - 1]
			var b: Array = keys[i]
			var t: float = (phase - a[0]) / maxf(b[0] - a[0], 0.0001)
			return lerpf(a[1], b[1], smoothstep(0.0, 1.0, t))
	return keys[keys.size() - 1][1]

## How far the arms sweep out from straight ahead (radians): in a glide they are
## nearly together, the pull takes them wide, the recovery brings them back.
static func arm_sweep(phase: float) -> float:
	return _curve([[0.0, 0.26], [0.4, 1.65], [0.72, 0.5], [1.0, 0.26]], phase)

## How bent the elbows are, 0 (straight) .. 1 (hands folded in under the chin).
static func arm_bend(phase: float) -> float:
	return _curve([[0.0, 0.0], [0.4, 0.9], [0.62, 1.0], [0.9, 0.1], [1.0, 0.0]], phase)

## How drawn up the knees are, 0 (legs straight) .. 1 (heels to the seat). The
## legs lag the arms: they draw up during the arm recovery and snap out after.
static func knee_draw(phase: float) -> float:
	return _curve([[0.0, 0.0], [0.45, 0.1], [0.75, 1.0], [0.86, 0.95], [0.95, 0.0], [1.0, 0.0]], phase)

## How far apart the feet are: wide at the start of the kick, closing as the
## legs straighten.
static func leg_spread(phase: float) -> float:
	return _curve([[0.0, 0.08], [0.45, 0.1], [0.75, 0.5], [0.86, 0.6], [0.95, 0.12], [1.0, 0.08]], phase)

## Where the upper arm and forearm point (unit vectors, upright-model axes) for
## a stroke at `phase`; `side` is +1 for the left arm, -1 for the right.
static func arm_dirs(phase: float, side: float) -> Dictionary:
	var w := arm_sweep(phase)
	var upper := Vector3(side * sin(w), cos(w), 0.1 * sin(w)).normalized()
	# Folded, the forearm points across the chest toward the chin: down toward
	# the floor and in toward the middle.
	var folded := Vector3(-side * 0.55, 0.25, 0.8).normalized()
	var lower := upper.slerp(folded, arm_bend(phase)).normalized()
	return {"upper": upper, "lower": lower}

## Where the thigh and calf point for a stroke at `phase`; `side` as above. At
## rest the legs trail straight behind (-Y). Drawing up swings the thigh a
## little toward the belly (+Z) and folds the calf back over it.
static func leg_dirs(phase: float, side: float) -> Dictionary:
	var draw := knee_draw(phase)
	var spread := leg_spread(phase)
	var thigh := Vector3(side * spread, -cos(draw * 0.9), sin(draw * 0.9) * 0.7).normalized()
	var calf := Vector3(side * (spread + 0.35 * draw), -cos(draw * 0.6), -sin(draw * 1.3) * 0.9).normalized()
	return {"thigh": thigh, "calf": calf}
