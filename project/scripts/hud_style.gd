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

## Dialog panels (sky menu, What's New): near-opaque, with a gold border.
static func dialog(border: Color = Color(1.0, 0.86, 0.55)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.1, 0.97)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(22)
	style.border_color = border
	style.set_border_width_all(2)
	return style

## Overlay panel on the full map: translucent dark, `margin` px of padding.
static func panel(margin: float, alpha: float = BACKING_ALPHA) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, alpha)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(margin)
	return style

## The window height the HUD's pixel sizes were drawn for.
const DESIGN_HEIGHT := 1728.0
const MAX_SCALE := 2.0

## UI scale for a window `height` px tall: 1 up to the design height, growing
## with it so text stays readable on 4K and 5K screens (never shrinks).
static func scale_for(height: float) -> float:
	return clampf(height / DESIGN_HEIGHT, 1.0, MAX_SCALE)

## Minimap edge lengths, px, cycled with Tab: medium, large, small.
const MINIMAP_SIZES := [360.0, 520.0, 240.0]

static func next_minimap_index(i: int) -> int:
	return (i + 1) % MINIMAP_SIZES.size()

## Seconds with no key or click before the hint bar starts to fade, and how
## long the fade takes.
const IDLE_BEFORE_FADE := 8.0
const FADE_SECONDS := 1.5

## Opacity of the hint bar after `idle` seconds without input.
static func fade_alpha(idle: float) -> float:
	return clampf(1.0 - (idle - IDLE_BEFORE_FADE) / FADE_SECONDS, 0.0, 1.0)
