extends RefCounted
## Synthesized fire sound for the ditch burn (D-156). The repo carries no audio
## files, so, like the engine note (engine_sound.gd), it is generated: a low
## roar of filtered noise, random crackle pops, and the torch's hiss. Pure
## except for its own filter state, so tests/test_fire.gd can check it
## without an audio device.

const MIX_RATE := 22050
## Pops per second at full crackle.
const POPS_PER_SECOND := 30.0
## How fast a pop dies away, per sample.
const POP_DECAY := 0.985

var _rng := RandomNumberGenerator.new()
var _low1 := 0.0
var _low2 := 0.0
var _hiss_low := 0.0
var _pop := 0.0
var _phase := 0.0

func _init() -> void:
	_rng.seed = 7

## The next `frames` stereo samples. `roar`, `crackle` and `hiss` are 0..1: the
## wall of flame nearby, the sharp pops of grass catching, and the torch jet.
func render(frames: int, roar: float, crackle: float, hiss: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(frames)
	var pop_chance := crackle * POPS_PER_SECOND / MIX_RATE
	for i in frames:
		var white := _rng.randf_range(-1.0, 1.0)
		_low1 += 0.035 * (white - _low1)
		_low2 += 0.2 * (white - _low2)
		_phase += 1.3 / MIX_RATE
		var swell := 0.75 + 0.25 * sin(TAU * _phase) * sin(TAU * _phase * 2.7)
		var s := _low1 * 6.0 * roar * swell + (_low2 - _low1) * 0.9 * roar
		if _rng.randf() < pop_chance:
			_pop = _rng.randf_range(0.4, 1.0)
		_pop *= POP_DECAY
		s += white * _pop * 0.55 * crackle
		_hiss_low += 0.3 * (white - _hiss_low)
		s += (white - _hiss_low) * 0.45 * hiss
		s = tanh(s * 1.2) * 0.8
		out[i] = Vector2(s, s)
	return out
