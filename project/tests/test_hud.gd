extends SceneTree

const Overlay := preload("res://scripts/controls_overlay.gd")
const HudStyle := preload("res://scripts/hud_style.gd")
## Pure checks for the HUD makeover (D-132). Run from project/:
##   godot --headless -s res://tests/test_hud.gd

var _failures := 0

func _check(cond: bool, what: String) -> void:
	if not cond:
		_failures += 1
		push_error("FAIL: " + what)

func _init() -> void:
	var t := 0.0
	for i in 4:
		t = Overlay.advance_move_time(t, true, 1.0)
	_check(not Overlay.should_auto_hide(t), "4 s of moving keeps the help open")
	t = Overlay.advance_move_time(t, false, 10.0)
	_check(is_equal_approx(t, 4.0), "standing still doesn't count")
	t = Overlay.advance_move_time(t, true, 1.0)
	_check(Overlay.should_auto_hide(t), "5 s of moving hides it")
	var style := HudStyle.backing()
	_check(style.bg_color.a > 0.5 and style.bg_color.a < 1.0, "backing is dark and translucent")
	print("test_hud: %s" % ("ok" if _failures == 0 else "%d failure(s)" % _failures))
	quit(1 if _failures else 0)
