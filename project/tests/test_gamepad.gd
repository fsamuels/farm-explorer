extends SceneTree
## Tests for controller support (D-185): the stick curve (scripts/gamepad_math.gd),
## that every game action has a controller binding, and that a pushed stick or
## pressed trigger reaches the same actions as the keys. Run headless from project/:
##   godot --headless -s res://tests/test_gamepad.gd

const GamepadMath := preload("res://scripts/gamepad_math.gd")

## Every action a controller needs to play the whole game, with the face button
## or stick that does it written out in docs/project/decisions.md (D-185).
const PAD_ACTIONS := [
	"move_forward", "move_back", "move_left", "move_right", "look_left", "look_right",
	"look_up", "look_down", "jump", "interact", "walk", "super_sprint", "torch",
	"use_tool", "dump_bed", "camera_zoom_in", "camera_zoom_out", "toggle_map",
	"toggle_things_to_do", "open_sky_menu", "toggle_help", "cycle_time_of_day",
	"cycle_weather",
]

var _failures := 0

func _init() -> void:
	_test_math()
	_test_bindings()
	_test_input()
	print("gamepad: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures else 0)

func _check(cond: bool, what: String) -> void:
	if not cond:
		_failures += 1
		push_error("FAIL: " + what)

func _test_math() -> void:
	_check(GamepadMath.look_rate(Vector2.ZERO) == Vector2.ZERO, "no push, no turn")
	_check(is_equal_approx(GamepadMath.look_rate(Vector2(1, 0)).x, GamepadMath.LOOK_RATE), "full push turns at the full rate")
	_check(GamepadMath.look_rate(Vector2(0.5, 0)).x < GamepadMath.LOOK_RATE * 0.3, "half a push is much slower than half the rate")
	_check(GamepadMath.look_rate(Vector2(-1, 0)).x < 0.0, "left keeps its sign")
	_check(GamepadMath.look_rate(Vector2(1, 1)).length() <= GamepadMath.LOOK_RATE + 0.001, "a diagonal corner is not faster than straight")
	_check(is_equal_approx(GamepadMath.look_step(Vector2(1, 0), 0.5).x, GamepadMath.LOOK_RATE * 0.5), "the step scales with the frame time")

func _has_pad_event(action: String) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			return true
	return false

func _test_bindings() -> void:
	for action in PAD_ACTIONS:
		_check(InputMap.has_action(action), "%s exists" % action)
		_check(_has_pad_event(action), "%s has a controller binding" % action)
	for action in PAD_ACTIONS:
		_check(InputMap.has_action(action) and InputMap.action_get_events(action).size() >= 1, "%s keeps its keyboard/mouse binding" % action)
	# The keyboard must still do the same: the keys are untouched.
	var has_key := false
	for event in InputMap.action_get_events("move_forward"):
		has_key = has_key or event is InputEventKey
	_check(has_key, "move_forward still has its W key")

func _motion(axis: int, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	return e

func _button(index: int, pressed: bool) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = index as JoyButton
	e.pressed = pressed
	return e

func _test_input() -> void:
	Input.parse_input_event(_motion(JOY_AXIS_LEFT_Y, -1.0))
	Input.flush_buffered_events()
	_check(Input.is_action_pressed("move_forward"), "left stick up walks forward")
	_check(Input.get_action_strength("move_forward") > 0.9, "a full push is full strength")
	Input.parse_input_event(_motion(JOY_AXIS_LEFT_Y, 0.0))
	Input.flush_buffered_events()
	_check(not Input.is_action_pressed("move_forward"), "letting go stops")
	Input.parse_input_event(_motion(JOY_AXIS_LEFT_X, 0.1))
	Input.flush_buffered_events()
	_check(not Input.is_action_pressed("move_right"), "a stick resting a little off centre does not drift")
	Input.parse_input_event(_motion(JOY_AXIS_LEFT_X, 0.0))
	Input.parse_input_event(_motion(JOY_AXIS_RIGHT_X, 1.0))
	Input.flush_buffered_events()
	_check(Input.is_action_pressed("look_right"), "right stick right looks right")
	Input.parse_input_event(_motion(JOY_AXIS_RIGHT_X, 0.0))
	Input.parse_input_event(_motion(JOY_AXIS_TRIGGER_RIGHT, 1.0))
	Input.flush_buffered_events()
	_check(Input.is_action_pressed("use_tool"), "right trigger uses the tool")
	Input.parse_input_event(_motion(JOY_AXIS_TRIGGER_RIGHT, 0.0))
	Input.parse_input_event(_motion(JOY_AXIS_TRIGGER_LEFT, 1.0))
	Input.flush_buffered_events()
	_check(Input.is_action_pressed("super_sprint"), "left trigger super sprints")
	Input.parse_input_event(_motion(JOY_AXIS_TRIGGER_LEFT, 0.0))
	Input.parse_input_event(_button(JOY_BUTTON_A, true))
	Input.flush_buffered_events()
	_check(Input.is_action_pressed("jump"), "A jumps")
	Input.parse_input_event(_button(JOY_BUTTON_A, false))
	Input.parse_input_event(_button(JOY_BUTTON_X, true))
	Input.flush_buffered_events()
	_check(Input.is_action_pressed("interact"), "X interacts")
	Input.parse_input_event(_button(JOY_BUTTON_X, false))
	Input.flush_buffered_events()
