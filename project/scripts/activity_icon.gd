extends Control
## A little cartoon icon for a Things to Do row (D-166), drawn in code so there
## are no image files: a flame, the weir's hand wheel, a kayak, the Cub Cadet, a
## car. Once the thing is done a green badge with a tick sits in its corner.
## Also draws the row of stars that fill in as things get done (kind "stars").

const FLAME := Color(1.0, 0.55, 0.15)
const FLAME_CORE := Color(1.0, 0.88, 0.3)
const STEEL := Color(0.55, 0.6, 0.66)
const WHEEL_RED := Color(0.9, 0.22, 0.18)
const WATER := Color(0.35, 0.65, 0.95)
const KAYAK_GREEN := Color(0.2, 0.7, 0.4)
const UTV_ORANGE := Color(0.95, 0.5, 0.12)
const CAR_RED := Color(0.85, 0.2, 0.22)
const GLASS := Color(0.75, 0.9, 1.0)
const TYRE := Color(0.12, 0.12, 0.14)
const BADGE := Color(0.3, 0.78, 0.38)
const STAR_ON := Color(1.0, 0.82, 0.25)
const STAR_OFF := Color(1.0, 1.0, 1.0, 0.18)

## "burn", "weir", "paddle", "utv", "car", or "stars".
var kind := "burn":
	set(value):
		kind = value
		queue_redraw()
var ticked := false:
	set(value):
		ticked = value
		queue_redraw()
## For "stars": how many of `total` are lit.
var lit := 0:
	set(value):
		lit = value
		queue_redraw()
var total := 5

func _init(icon_size := 64.0) -> void:
	custom_minimum_size = Vector2(icon_size, icon_size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _p(x: float, y: float) -> Vector2:
	return Vector2(x * size.x, y * size.y)

func _poly(points: Array, color: Color) -> void:
	var out := PackedVector2Array()
	for point: Vector2 in points:
		out.append(_p(point.x, point.y))
	draw_colored_polygon(out, color)

func _wheel(centre: Vector2, radius: float) -> void:
	draw_circle(_p(centre.x, centre.y), radius * size.x, TYRE)
	draw_circle(_p(centre.x, centre.y), radius * 0.45 * size.x, STEEL)

func _draw() -> void:
	match kind:
		"burn":
			_poly([Vector2(0.5, 0.02), Vector2(0.68, 0.32), Vector2(0.84, 0.58), Vector2(0.76, 0.84), Vector2(0.5, 0.98), Vector2(0.24, 0.84), Vector2(0.16, 0.58), Vector2(0.32, 0.34), Vector2(0.42, 0.5)], FLAME)
			_poly([Vector2(0.5, 0.46), Vector2(0.64, 0.7), Vector2(0.58, 0.88), Vector2(0.5, 0.93), Vector2(0.42, 0.88), Vector2(0.36, 0.7)], FLAME_CORE)
		"weir":
			var centre := _p(0.5, 0.42)
			draw_arc(centre, size.x * 0.3, 0.0, TAU, 32, WHEEL_RED, size.x * 0.09)
			for i in 6:
				var a := i * TAU / 6.0
				draw_line(centre, centre + Vector2(cos(a), sin(a)) * size.x * 0.3, WHEEL_RED, size.x * 0.05)
			draw_circle(centre, size.x * 0.07, STEEL)
			draw_line(_p(0.5, 0.72), _p(0.5, 0.84), STEEL, size.x * 0.07)
			for row in 2:
				var y := 0.88 + row * 0.1
				var wave := PackedVector2Array()
				for i in 9:
					wave.append(_p(0.08 + i * 0.105, y + (0.03 if i % 2 == 0 else -0.03)))
				draw_polyline(wave, WATER, size.x * 0.05)
		"paddle":
			# A paddle across the boat, the boat, and waves.
			draw_line(_p(0.18, 0.12), _p(0.82, 0.58), Color(0.75, 0.55, 0.3), size.x * 0.05)
			_poly([Vector2(0.1, 0.06), Vector2(0.22, 0.04), Vector2(0.26, 0.2), Vector2(0.14, 0.22)], Color(0.95, 0.85, 0.3))
			_poly([Vector2(0.04, 0.58), Vector2(0.96, 0.58), Vector2(0.78, 0.8), Vector2(0.22, 0.8)], KAYAK_GREEN)
			draw_circle(_p(0.5, 0.5), size.x * 0.1, Color(1.0, 0.8, 0.6))
			for row in 2:
				var wave := PackedVector2Array()
				for i in 9:
					wave.append(_p(0.04 + i * 0.115, 0.88 + row * 0.08 + (0.025 if i % 2 == 0 else -0.025)))
				draw_polyline(wave, WATER, size.x * 0.05)
		"utv":
			_poly([Vector2(0.06, 0.44), Vector2(0.4, 0.44), Vector2(0.4, 0.68), Vector2(0.06, 0.68)], UTV_ORANGE)
			_poly([Vector2(0.44, 0.38), Vector2(0.94, 0.34), Vector2(0.94, 0.66), Vector2(0.44, 0.68)], Color(0.35, 0.38, 0.42))
			draw_polyline(PackedVector2Array([_p(0.12, 0.44), _p(0.14, 0.2), _p(0.38, 0.2), _p(0.4, 0.44)]), UTV_ORANGE, size.x * 0.05)
			_wheel(Vector2(0.24, 0.76), 0.14)
			_wheel(Vector2(0.78, 0.76), 0.14)
		"car":
			_poly([Vector2(0.04, 0.52), Vector2(0.96, 0.52), Vector2(0.96, 0.7), Vector2(0.04, 0.7)], CAR_RED)
			_poly([Vector2(0.22, 0.52), Vector2(0.34, 0.28), Vector2(0.68, 0.28), Vector2(0.82, 0.52)], CAR_RED)
			_poly([Vector2(0.3, 0.5), Vector2(0.38, 0.34), Vector2(0.48, 0.34), Vector2(0.48, 0.5)], GLASS)
			_poly([Vector2(0.52, 0.5), Vector2(0.52, 0.34), Vector2(0.64, 0.34), Vector2(0.74, 0.5)], GLASS)
			_wheel(Vector2(0.26, 0.74), 0.13)
			_wheel(Vector2(0.76, 0.74), 0.13)
		"stars":
			for i in total:
				_star(Vector2((i + 0.5) / total, 0.5), 0.5 / total * 0.95, STAR_ON if i < lit else STAR_OFF)
	if ticked and kind != "stars":
		var badge := _p(0.8, 0.8)
		draw_circle(badge, size.x * 0.22, Color(0.04, 0.06, 0.1))
		draw_circle(badge, size.x * 0.18, BADGE)
		draw_polyline(PackedVector2Array([badge + Vector2(-0.09, 0.0) * size.x, badge + Vector2(-0.02, 0.07) * size.x, badge + Vector2(0.1, -0.07) * size.x]), Color.WHITE, size.x * 0.045)

## A five-pointed star centred at `centre` (in 0..1 of the control's width).
func _star(centre: Vector2, radius: float, color: Color) -> void:
	var points: Array = []
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		var r := radius if i % 2 == 0 else radius * 0.45
		points.append(Vector2(centre.x + cos(a) * r, centre.y + sin(a) * r * size.x / size.y))
	_poly(points, color)
