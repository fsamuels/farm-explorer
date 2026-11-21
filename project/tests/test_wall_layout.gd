extends SceneTree
## Unit tests for scripts/wall_layout.gd (D-98). Run headless from project/:
##   godot --headless -s res://tests/test_wall_layout.gd

const WallLayout := preload("res://scripts/wall_layout.gd")

var _failures := 0

func _init() -> void:
	# A solid wall is one piece.
	var solid := WallLayout.pieces(10.0, 4.0, [])
	_check(solid.size() == 1 and solid[0] == Rect2(-5, 0, 10, 4), "solid wall: %s" % [solid])

	# A door from the ground leaves two side pieces and a header.
	var door := {c = 1.0, w = 1.0, y0 = 0.0, y1 = 2.0}
	var p := WallLayout.pieces(10.0, 4.0, [door])
	_check(p.size() == 3, "door: left, header, right: %s" % [p])
	_near(WallLayout.area(p), 40.0 - 2.0, "door area")

	# A window has a sill piece below and a header above.
	var window := {c = -2.0, w = 1.5, y0 = 1.0, y1 = 2.1}
	p = WallLayout.pieces(10.0, 4.0, [window])
	_check(p.size() == 4, "window: left, sill, header, right: %s" % [p])
	_near(WallLayout.area(p), 40.0 - 1.5 * 1.1, "window area")

	# Order of the input doesn't matter and several openings add up.
	var openings := [door, window]
	var shuffled := [window, door]
	_near(WallLayout.area(WallLayout.pieces(10.0, 4.0, openings)), 40.0 - 2.0 - 1.65, "two openings")
	_near(WallLayout.area(WallLayout.pieces(10.0, 4.0, shuffled)), 40.0 - 2.0 - 1.65, "unsorted openings")

	# An opening flush with the wall's end leaves no zero-width sliver.
	p = WallLayout.pieces(10.0, 4.0, [{c = 4.5, w = 1.0, y0 = 0.0, y1 = 2.0}])
	_check(p.all(func(r): return r.size.x > 0.01 and r.size.y > 0.01), "no slivers: %s" % [p])

	print("wall_layout: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures else 0)

func _check(cond: bool, what: String) -> void:
	if not cond:
		_failures += 1
		push_error("FAIL: " + what)

func _near(a: float, b: float, what: String) -> void:
	_check(absf(a - b) < 0.001, "%s: %s vs %s" % [what, a, b])
