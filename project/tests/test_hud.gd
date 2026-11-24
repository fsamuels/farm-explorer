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
	_check(is_equal_approx(HudStyle.scale_for(1080.0), 1.0), "small windows are never shrunk")
	_check(is_equal_approx(HudStyle.scale_for(2160.0), 1.25), "4K grows the HUD 25%")
	_check(is_equal_approx(HudStyle.scale_for(9000.0), HudStyle.MAX_SCALE), "scale is capped")
	var seen := {}
	var idx := 0
	for i in HudStyle.MINIMAP_SIZES.size():
		seen[idx] = true
		idx = HudStyle.next_minimap_index(idx)
	_check(idx == 0 and seen.size() == HudStyle.MINIMAP_SIZES.size(), "Tab cycles through every minimap size and wraps")
	_check(HudStyle.fade_alpha(0.0) == 1.0 and HudStyle.fade_alpha(HudStyle.IDLE_BEFORE_FADE) == 1.0, "hint bar is solid until the idle delay")
	_check(HudStyle.fade_alpha(HudStyle.IDLE_BEFORE_FADE + HudStyle.FADE_SECONDS) == 0.0, "hint bar is gone after the fade")
	var mid := HudStyle.fade_alpha(HudStyle.IDLE_BEFORE_FADE + HudStyle.FADE_SECONDS * 0.5)
	_check(mid > 0.0 and mid < 1.0, "hint bar fades gradually")
	_check(HudStyle.dialog().bg_color.a > 0.9, "dialogs are near-opaque")
	print("test_hud: %s" % ("ok" if _failures == 0 else "%d failure(s)" % _failures))
	quit(1 if _failures else 0)
