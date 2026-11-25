extends RefCounted
## Pale blue lap siding for the farmhouse (D-170), after the owner's photo of
## the back of the House (Downloads/back yard deck.jpg): horizontal boards with
## an 8 inch (0.2 m) reveal, each a little lighter toward its bottom edge where
## it kicks out, with a thin shadow line under the lap and faint grain.
##
## The texture is made in code (no image file) and mapped with world-space
## triplanar, so any box, gable or wall piece gets level boards that line up
## across separate pieces with no UV work. Horizontal boards look the same
## along their length, so it does not matter that the House is turned about
## 20 degrees to the world's axes.

## Board reveal, metres, and boards per texture tile (one tile is square).
const REVEAL := 0.2
const BOARDS := 4
const TILE := REVEAL * BOARDS
const SIZE := 256
## The paint, matched by eye to the photo in daylight.
const COLOR := Color(0.70, 0.84, 0.86)

static var _cache: StandardMaterial3D

## The shared siding material.
static func material() -> StandardMaterial3D:
	if _cache == null:
		var m := StandardMaterial3D.new()
		m.albedo_texture = ImageTexture.create_from_image(image())
		m.roughness = 0.8
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_triplanar_sharpness = 4.0
		m.uv1_scale = Vector3.ONE / TILE
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_cache = m
	return _cache

## Shade (0..1, times COLOR) of the board at fraction `f` down from the top of
## one board: a soft shadow just under the lap above, brightening toward the
## bottom edge, then a dark line where the next board overlaps.
static func board_shade(f: float) -> float:
	if f > 0.94:
		return 0.55
	var s := 0.86 + 0.14 * f
	if f < 0.12:
		s -= 0.08 * (1.0 - f / 0.12)
	return s

## One tile of siding, `SIZE` px square, rows top to bottom.
static func image() -> Image:
	var img := Image.create(SIZE, SIZE, true, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = 170
	noise.frequency = 0.02
	var board_px := float(SIZE) / BOARDS
	for y in SIZE:
		var f := fmod(float(y), board_px) / board_px
		var shade := board_shade(f)
		for x in SIZE:
			# Stretched noise reads as faint grain and weathering along the
			# boards; x goes round a circle so the tile wraps with no seam.
			var a := TAU * float(x) / SIZE
			var grain := noise.get_noise_3d(cos(a) * 12.0, sin(a) * 12.0, float(y) * 4.0) * 0.035
			var c := COLOR * (shade + grain)
			c.a = 1.0
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return img
