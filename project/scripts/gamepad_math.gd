extends RefCounted
## Controller look (D-182), pure so it can be tested. The right stick turns the
## view: a squared response so a small push is a slow, fine turn and a full push
## is a quick one.

## Full-stick turn rate, radians per second (about 150 degrees).
const LOOK_RATE := 2.6

## The turn rate for a stick push: `stick` is (right - left, down - up), each
## 0..1 after the dead zone. Returns radians per second as (yaw, pitch) with
## the stick's sign kept.
static func look_rate(stick: Vector2) -> Vector2:
	var length := minf(stick.length(), 1.0)
	if length <= 0.0:
		return Vector2.ZERO
	return stick.normalized() * length * length * LOOK_RATE

## The turn for one frame: radians to add to (yaw, pitch) as (x, y), where x
## is right-positive and y is down-positive, like the mouse's relative motion.
static func look_step(stick: Vector2, delta: float) -> Vector2:
	return look_rate(stick) * delta
