extends SceneTree
## Unit tests for scripts/map_math.gd (D-93). Run headless from project/:
##   godot --headless -s res://tests/test_map_math.gd

const MapMath := preload("res://scripts/map_math.gd")

var _failures := 0

func _init() -> void:
	_test_screen_round_trip()
	_test_zoom_keeps_pivot_fixed()
	_test_box_footprint()
	_test_segment_ends()
	_test_bearings()
	_test_format_distance()
	_test_scale_bar()
	_test_trail()
	_test_footprint_lookup()
	_test_clamp_to_rect_edge()
	_test_grid()
	print("map_math: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures else 0)

func _check(cond: bool, what: String) -> void:
	if not cond:
		_failures += 1
		push_error("FAIL: " + what)

func _near(a, b, what: String, eps := 0.001) -> void:
	var ok: bool
	if a is Vector2:
		ok = a.distance_to(b) <= eps
	else:
		ok = absf(a - b) <= eps
	_check(ok, "%s: got %s, want %s" % [what, a, b])

func _test_screen_round_trip() -> void:
	var view := Vector2(800, 600)
	var center := Vector2(50, -30)
	_near(MapMath.world_to_screen(center, center, 3.0, view), view / 2.0, "center maps to middle")
	_near(MapMath.world_to_screen(center + Vector2(10, 0), center, 3.0, view), Vector2(430, 300), "east is right")
	_near(MapMath.world_to_screen(center + Vector2(0, -10), center, 3.0, view), Vector2(400, 270), "north is up")
	var w := Vector2(123.4, -56.7)
	_near(MapMath.screen_to_world(MapMath.world_to_screen(w, center, 2.5, view), center, 2.5, view), w, "round trip")

func _test_zoom_keeps_pivot_fixed() -> void:
	var view := Vector2(800, 600)
	var center := Vector2(10, 20)
	var pivot := Vector2(100, 450)
	var before := MapMath.screen_to_world(pivot, center, 2.0, view)
	var new_center := MapMath.zoom_center(center, 2.0, 5.0, pivot, view)
	_near(MapMath.screen_to_world(pivot, new_center, 5.0, view), before, "zoom pivot stays put")

func _test_box_footprint() -> void:
	var xform := Transform3D(Basis.from_scale(Vector3(10, 4, 6)), Vector3(100, 2, -50))
	var poly := MapMath.box_footprint(xform)
	_check(poly.size() == 4, "footprint has 4 corners")
	_near(poly[0], Vector2(95, -53), "footprint corner")
	_near(poly[2], Vector2(105, -47), "opposite corner")
	_near(MapMath.polygon_center(poly), Vector2(100, -50), "footprint center")
	var rotated := Transform3D(Basis(Vector3.UP, PI / 2.0) * Basis.from_scale(Vector3(10, 1, 2)), Vector3.ZERO)
	var bounds := MapMath.bounds_of(MapMath.box_footprint(rotated))
	_near(bounds.size, Vector2(2, 10), "rotated footprint swaps extents")

func _test_segment_ends() -> void:
	var ends := MapMath.segment_ends(Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(5, 0, 5)), 10.0)
	_near(ends[0].distance_to(ends[1]), 10.0, "segment length")
	_near((ends[0] + ends[1]) / 2.0, Vector2(5, 5), "segment midpoint")
	_near(absf(ends[0].x - ends[1].x), 0.0, "rotated 90° runs north-south")

func _test_bearings() -> void:
	_near(MapMath.yaw_to_bearing(0.0), 0.0, "yaw 0 faces north")
	_near(MapMath.yaw_to_bearing(-PI / 2.0), 90.0, "turning right faces east")
	_near(MapMath.yaw_to_bearing(PI / 2.0), 270.0, "turning left faces west")
	_near(MapMath.bearing_between(Vector2.ZERO, Vector2(0, -5)), 0.0, "north bearing")
	_near(MapMath.bearing_between(Vector2.ZERO, Vector2(5, 0)), 90.0, "east bearing")
	_near(MapMath.bearing_between(Vector2.ZERO, Vector2(0, 5)), 180.0, "south bearing")
	_check(MapMath.cardinal(0.0) == "N", "cardinal N")
	_check(MapMath.cardinal(44.0) == "NE", "cardinal NE")
	_check(MapMath.cardinal(200.0) == "S", "cardinal S")
	_check(MapMath.cardinal(350.0) == "N", "cardinal wraps to N")
	_check(MapMath.cardinal(-90.0) == "W", "negative bearing")

func _test_format_distance() -> void:
	_check(MapMath.format_distance(42.4) == "42 m", "metres")
	_check(MapMath.format_distance(999.4) == "999 m", "just under 1 km")
	_check(MapMath.format_distance(1260.0) == "1.3 km", "kilometres")

func _test_scale_bar() -> void:
	_near(MapMath.scale_bar_meters(1.0, 260.0), 200.0, "1 px/m")
	_near(MapMath.scale_bar_meters(3.0, 260.0), 50.0, "3 px/m")
	_near(MapMath.scale_bar_meters(26.0, 260.0), 10.0, "exact fit")
	_near(MapMath.scale_bar_meters(20.0, 260.0), 10.0, "13 m available")

func _test_trail() -> void:
	var trail := PackedVector2Array()
	_check(MapMath.trail_append(trail, Vector2.ZERO, 3.0, 3), "first point appended")
	_check(not MapMath.trail_append(trail, Vector2(1, 0), 3.0, 3), "too close skipped")
	_check(MapMath.trail_append(trail, Vector2(3, 0), 3.0, 3), "far enough appended")
	MapMath.trail_append(trail, Vector2(6, 0), 3.0, 3)
	MapMath.trail_append(trail, Vector2(9, 0), 3.0, 3)
	_check(trail.size() == 3, "trail capped")
	_near(trail[0], Vector2(3, 0), "oldest point dropped")
	_near(trail[2], Vector2(9, 0), "newest kept")

func _test_footprint_lookup() -> void:
	var a := PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)])
	var b := PackedVector2Array([Vector2(50, 0), Vector2(60, 0), Vector2(60, 10), Vector2(50, 10)])
	var prints := [a, b]
	_check(MapMath.footprint_at(Vector2(5, 5), prints) == 0, "inside first")
	_check(MapMath.footprint_at(Vector2(55, 5), prints) == 1, "inside second")
	_check(MapMath.footprint_at(Vector2(30, 5), prints) == -1, "between")
	_check(MapMath.nearest_footprint(Vector2(45, 5), prints, 20.0) == 1, "nearest by edge")
	_check(MapMath.nearest_footprint(Vector2(14, 5), prints, 20.0) == 0, "nearest by edge (first)")
	_check(MapMath.nearest_footprint(Vector2(30, 50), prints, 20.0) == -1, "too far")

func _test_clamp_to_rect_edge() -> void:
	var rect := Rect2(0, 0, 100, 100)
	_near(MapMath.clamp_to_rect_edge(Vector2(20, 30), rect), Vector2(20, 30), "inside unchanged")
	_near(MapMath.clamp_to_rect_edge(Vector2(250, 50), rect), Vector2(100, 50), "pinned right")
	_near(MapMath.clamp_to_rect_edge(Vector2(50, -150), rect), Vector2(50, 0), "pinned top")
	_near(MapMath.clamp_to_rect_edge(Vector2(150, 150), rect), Vector2(100, 100), "pinned corner")

func _test_grid() -> void:
	_near(MapMath.grid_step(1.8, 80.0), 50.0, "1.8 px/m picks 50 m")
	_near(MapMath.grid_step(20.0, 80.0), 5.0, "zoomed in picks 5 m")
	_near(MapMath.grid_step(0.01, 80.0), 500.0, "far out caps at 500 m")
	var v := MapMath.grid_values(-12.0, 31.0, 10.0)
	_check(v == PackedFloat32Array([-10, 0, 10, 20, 30]), "grid values: %s" % v)
	_check(MapMath.grid_values(1.0, 9.0, 10.0).is_empty(), "no line in range")
	_check(MapMath.grid_values(-INF, 10.0, 10.0).is_empty(), "non-finite range draws nothing instead of looping forever")
	_check(MapMath.grid_values(0.0, 10.0, 0.0).is_empty(), "zero step draws nothing")
