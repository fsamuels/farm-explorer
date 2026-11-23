extends RefCounted
## Shared look for on-screen text that sits straight on the 3D view (D-132).
## A black outline alone vanishes against bright daytime sky and grass, so
## hints, the clock and the minimap captions sit on a soft dark backing.

const BACKING_ALPHA := 0.62

## A rounded, translucent dark panel style for a hint or readout.
static func backing(margin_x: float = 10.0, margin_y: float = 4.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, BACKING_ALPHA)
	style.set_corner_radius_all(8)
	style.content_margin_left = margin_x
	style.content_margin_right = margin_x
	style.content_margin_top = margin_y
	style.content_margin_bottom = margin_y
	return style
