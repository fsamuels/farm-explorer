extends RefCounted
## Pure driving helpers for vehicle.gd (D-106), kept free of scene access so
## tests/test_vehicle.gd can cover them headless.
##
## Speed is signed metres per second along the car's forward axis (negative is
## reversing). `throttle` is -1..1 (W is +1, S is -1), `steer` is -1..1 with
## +1 turning left.

const MPH_PER_MS := 2.2369362920544
## Below this speed the throttle counts as "from rest" and picks the direction.
const REST_SPEED := 0.05
## You can only get out at or below this speed (m/s), about a brisk walk.
const MAX_EXIT_SPEED := 2.0

## Next signed speed after `delta` seconds. Pushing the throttle the way the car
## is already moving accelerates (up to `max_speed` / `max_reverse`); pushing
## the other way brakes at `brake_decel` and stops at 0, after which the held
## key reverses the car on the next step. With no throttle the car coasts down
## at `drag`; `handbrake` stops it at `hand_decel` and ignores the throttle.
static func next_speed(speed: float, throttle: float, handbrake: bool, delta: float, accel: float,
		brake_decel: float, hand_decel: float, drag: float, max_speed: float, max_reverse: float) -> float:
	if handbrake:
		return move_toward(speed, 0.0, hand_decel * delta)
	if absf(throttle) < 0.01:
		return move_toward(speed, 0.0, drag * delta)
	var opposing := absf(speed) > REST_SPEED and signf(throttle) != signf(speed)
	if opposing:
		return move_toward(speed, 0.0, brake_decel * delta)
	return clampf(speed + throttle * accel * delta, -max_reverse, max_speed)

## Yaw rate (rad/s, positive turns left) of a bicycle model with the given
## wheelbase, front-wheel angle `steer * max_steer`, capped so the sideways
## acceleration never exceeds `max_lat_accel` (the car understeers at speed
## instead of pivoting). Reversing flips the sign, as a real car does.
static func yaw_rate(speed: float, steer: float, wheelbase: float, max_steer: float, max_lat_accel: float) -> float:
	var rate := speed / wheelbase * tan(steer * max_steer)
	if absf(speed) > 0.01:
		var cap := max_lat_accel / absf(speed)
		rate = clampf(rate, -cap, cap)
	return rate

## How strongly the headlights are wanted (0..1) for a scene whose sun has
## `sun_energy` (time_of_day.gd: about 1 by day, 0.25-0.3 at dusk and night,
## and dimmed further under cloud). Off at 0.7 or above, fully on at 0.4 or
## below, fading between so dusk and dawn don't snap.
static func headlight_demand(sun_energy: float) -> float:
	return clampf((0.7 - sun_energy) / 0.3, 0.0, 1.0)

static func to_mph(speed: float) -> float:
	return absf(speed) * MPH_PER_MS

## Where to try putting the player when they get out, as offsets in the car's
## local frame (x right, z back) on the ground: the driver's side first, then
## the other side, behind and in front, then the four corners. `seat_x` is the seat's local x and
## `half_width` / `half_length` the car body's half extents; `margin` is the
## clearance from the body to the player's centre.
static func exit_offsets(seat_x: float, seat_z: float, half_width: float, half_length: float, margin: float) -> Array[Vector3]:
	var side := signf(seat_x) if absf(seat_x) > 0.01 else -1.0
	var out: Array[Vector3] = []
	out.append(Vector3(side * (half_width + margin), 0.0, seat_z))
	out.append(Vector3(-side * (half_width + margin), 0.0, seat_z))
	out.append(Vector3(0.0, 0.0, half_length + margin))
	out.append(Vector3(0.0, 0.0, -(half_length + margin)))
	for z in [half_length + margin, -(half_length + margin)]:
		out.append(Vector3(side * (half_width + margin), 0.0, z))
		out.append(Vector3(-side * (half_width + margin), 0.0, z))
	return out
