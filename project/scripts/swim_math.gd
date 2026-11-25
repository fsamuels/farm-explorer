extends RefCounted
## Pure maths for swimming (D-152), kept free of scene access so
## tests/test_swim.gd can cover it headless.
##
## You swim once the water is deeper than `ENTER_DEPTH` where you stand and walk
## again once it is shallower than `EXIT_DEPTH` (the gap stops a bobbing swimmer
## flickering between the two). While swimming the body floats with the origin
## `DRAFT` metres under the surface, so the eyes (1.6 m up) sit just above it.
##
## The stroke is freestyle (front crawl): one `phase` (0..1) is one full cycle,
## each arm pulling once. An arm reaches forward, pulls down and back under the
## body, then swings forward over the water with a high elbow; the other arm is
## half a cycle behind. The legs flutter-kick and the body rolls with the arms.
## Directions are for an upright model (rest pose): +Y is the way the swimmer
## heads once laid flat, +Z is the way the belly faces (down toward the floor),
## +X is the swimmer's left. `arm_dirs` and `leg_dirs` return where each bone
## should point.

const ENTER_DEPTH := 1.5
const EXIT_DEPTH := 1.3
## How far the player's origin sits below the water surface while floating.
const DRAFT := 1.45
## Ground speed of a steady stroke, and with Shift held.
const SPEED := 2.0
const SLOW_SPEED := 1.0
## Ground speed with Ctrl held, a fast crawl (D-173), and how much faster the arms turn over for it.
const FAST_SPEED := 8.0
const FAST_STROKE_RATE := 2.2
## Seconds per full cycle (both arms) while swimming, and how much slower the stroke ticks over
## while just treading water.
const STROKE_SECONDS := 1.8
const IDLE_STROKE_RATE := 0.25
## Flutter kicks per full stroke cycle, and how far the body rolls each way.
const KICKS_PER_CYCLE := 6.0
const ROLL := deg_to_rad(38.0)
## Pitch (radians) of the body from upright to flat on the water.
const BODY_PITCH := deg_to_rad(86.0)

## Whether the player is swimming given the water `depth` where they stand and
## whether they `was_swimming` a moment ago.
static func is_swimming(depth: float, was_swimming: bool) -> bool:
	return depth >= (EXIT_DEPTH if was_swimming else ENTER_DEPTH)

## Shift (slow) wins over Ctrl (fast), as it does for running.
static func swim_speed(slow: bool, fast := false) -> float:
	if slow:
		return SLOW_SPEED
	return FAST_SPEED if fast else SPEED

## The height the origin floats at: `DRAFT` under `surface`, with a small bob.
static func float_y(surface: float, time: float) -> float:
	return surface - DRAFT + 0.04 * sin(time * 2.1)

## Vertical speed that closes the gap to `target_y` smoothly, capped so a drop
## from a jump settles instead of bouncing.
static func float_velocity(y: float, target_y: float) -> float:
	return clampf((target_y - y) * 6.0, -4.0, 4.0)

## Advance the stroke phase by `delta` seconds: full rate while moving through
## the water, a slow tread when still.
static func advance_phase(phase: float, delta: float, moving: bool, fast := false) -> float:
	var rate := (FAST_STROKE_RATE if fast else 1.0) if moving else IDLE_STROKE_RATE
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

## Where one arm is in its cycle as an angle (radians): 0 reaching straight
## ahead, PI/2 pointing down at the floor, PI pointing straight back, 3 PI / 2
## pointing up at the sky. The pull (underwater) takes the first half of the
## cycle and the recovery (in the air) the second.
static func arm_angle(t: float) -> float:
	return t * TAU

## How bent the elbow is, 0 (straight) .. 1: a little in the pull, fully
## bent and high in the recovery.
static func elbow_bend(t: float) -> float:
	return _curve([[0.0, 0.05], [0.25, 0.65], [0.5, 0.1], [0.75, 0.85], [1.0, 0.05]], t)

## Where the upper arm and forearm point (unit vectors, upright-model axes)
## for a stroke at `phase`; `side` is +1 for the left arm, -1 for the right,
## which runs half a cycle behind.
static func arm_dirs(phase: float, side: float) -> Dictionary:
	var t := fposmod(phase + (0.0 if side > 0.0 else 0.5), 1.0)
	var a := arm_angle(t)
	# The recovery swings the elbow out to the side; the pull stays near the body.
	var out := 0.12 + 0.3 * maxf(-sin(a), 0.0)
	var upper := Vector3(side * out, cos(a), sin(a)).normalized()
	# The forearm folds toward forward-and-down, the hand hanging toward the water.
	var folded := Vector3(side * 0.1, 0.5, 0.85).normalized()
	var lower := upper.slerp(folded, elbow_bend(t)).normalized()
	return {"upper": upper, "lower": lower}

## Where the thigh and calf point: a flutter kick, the legs alternating,
## trailing behind (-Y) with the knees bending a little as each leg comes up.
static func leg_dirs(phase: float, side: float) -> Dictionary:
	var w := TAU * KICKS_PER_CYCLE * phase * 0.5 + (0.0 if side > 0.0 else PI)
	var hip := 0.3 * sin(w)  # + swings the leg toward the floor (+Z)
	var knee := hip - 0.35 * (1.0 - cos(w)) * 0.5
	var thigh := Vector3(side * 0.06, -cos(hip), sin(hip)).normalized()
	var calf := Vector3(side * 0.06, -cos(knee), sin(knee)).normalized()
	return {"thigh": thigh, "calf": calf}

## How far the body is rolled about its long axis (radians, + to the left): it
## rolls toward each arm as that arm pulls.
static func body_roll(phase: float) -> float:
	return ROLL * cos(TAU * phase)
