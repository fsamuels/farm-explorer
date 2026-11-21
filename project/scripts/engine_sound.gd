extends RefCounted
## A synthesized engine note for vehicle.gd (D-107); the repo carries no audio
## files, so the sound is generated from the car's speed and throttle. Pure
## except for its own phase state, so tests/test_vehicle.gd can check it
## without an audio device.
##
## rpm_for_speed() turns road speed into engine revs through a few gears, so
## the pitch climbs and drops at each shift. render() then makes the next
## chunk of audio: a stack of harmonics of the firing frequency (cylinders / 2
## firings per revolution), with a half-order burble and a little intake noise.
## Harmonics fall off faster at low load, which is what makes an engine on
## the overrun sound duller than one under power.

const MIX_RATE := 22050
const HARMONICS := 8
## After a shift the revs fall back to this fraction of the rev range.
const SHIFT_FRACTION := 0.5

var cylinders := 4
var _phase := 0.0
var _sub_phase := 0.0
var _noise := 0.0
var _rng := RandomNumberGenerator.new()

func _init(cylinder_count := 4) -> void:
	cylinders = cylinder_count
	_rng.seed = 1

## Index of the gear for `speed`: the first whose top speed is at or above it.
static func gear_for_speed(speed: float, gear_tops: PackedFloat32Array) -> int:
	var s := absf(speed)
	var gear := 0
	while gear < gear_tops.size() - 1 and s > gear_tops[gear]:
		gear += 1
	return gear

## Engine rpm at road `speed` (m/s): idle at rest, rising to `redline` at the
## top of each gear and dropping back after each shift.
static func rpm_for_speed(speed: float, gear_tops: PackedFloat32Array, idle: float, redline: float) -> float:
	var gear := gear_for_speed(speed, gear_tops)
	var low := 0.0 if gear == 0 else gear_tops[gear - 1]
	var span := maxf(gear_tops[gear] - low, 0.001)
	var frac := clampf((absf(speed) - low) / span, 0.0, 1.0)
	var start := 0.0 if gear == 0 else SHIFT_FRACTION
	return idle + (redline - idle) * (start + (1.0 - start) * frac)

## How many times a second the cylinders fire (four-stroke: every cylinder
## fires once per two revolutions).
static func firing_hz(rpm: float, cylinder_count: int) -> float:
	return rpm / 60.0 * cylinder_count * 0.5

## The next `frames` stereo samples at `rpm` with throttle `load` (0..1).
func render(frames: int, rpm: float, load: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(frames)
	var fire := maxf(firing_hz(rpm, cylinders), 1.0)
	var step := fire / MIX_RATE
	var rolloff := 1.0 + (1.0 - load) * 0.9
	var gain := 0.2 + 0.25 * load
	var h_max := mini(HARMONICS, int(MIX_RATE * 0.45 / fire))
	var amps := PackedFloat32Array()
	var total := 0.0
	for h in range(1, h_max + 1):
		var a := pow(1.0 / h, rolloff)
		amps.append(a)
		total += a
	gain /= maxf(total, 0.001)
	for i in frames:
		_phase += step
		if _phase >= 1.0:
			_phase -= 1.0
		_sub_phase += step * 0.5
		if _sub_phase >= 1.0:
			_sub_phase -= 1.0
		var s := 0.0
		for h in h_max:
			s += amps[h] * sin(TAU * (h + 1) * _phase)
		s += 0.35 * sin(TAU * _sub_phase)
		_noise += 0.2 * (_rng.randf_range(-1.0, 1.0) - _noise)
		s += _noise * (0.1 + 0.25 * load)
		s = tanh(s * gain * 3.0)
		out[i] = Vector2(s, s)
	return out
