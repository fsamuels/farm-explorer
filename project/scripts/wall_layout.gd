extends RefCounted
## Pure helper for the Shop shell (D-98): cuts a wall into solid boxes around
## its door / window openings, kept free of scene access so
## tests/test_wall_layout.gd can cover it headless.

## Splits a wall `length` metres long and `height` tall into rectangles that
## leave the openings clear. Each opening is {c: centre along the wall, w:
## width, y0: bottom, y1: top} (c measured from the wall's centre). Returns
## Rect2s in (along-wall, height) space, along-wall running -length/2..length/2.
## Openings must not overlap and must lie inside the wall.
static func pieces(length: float, height: float, openings: Array) -> Array[Rect2]:
	var sorted := openings.duplicate()
	sorted.sort_custom(func(a, b): return a.c < b.c)
	var out: Array[Rect2] = []
	var cursor := -length / 2.0
	for o in sorted:
		var left: float = o.c - o.w / 2.0
		var right: float = o.c + o.w / 2.0
		if left > cursor + 0.001:
			out.append(Rect2(cursor, 0.0, left - cursor, height))
		if o.y0 > 0.001:
			out.append(Rect2(left, 0.0, o.w, o.y0))
		if o.y1 < height - 0.001:
			out.append(Rect2(left, o.y1, o.w, height - o.y1))
		cursor = right
	if cursor < length / 2.0 - 0.001:
		out.append(Rect2(cursor, 0.0, length / 2.0 - cursor, height))
	return out

## Total area of the pieces; with the openings' area it must equal the wall's.
static func area(rects: Array[Rect2]) -> float:
	var total := 0.0
	for r in rects:
		total += r.size.x * r.size.y
	return total
