extends RefCounted
## Bakes the catalogue stars and constellation lines (star_data.gd) into two
## equirectangular images for the night-sky shader (D-101): a colour image of
## the stars and a one-channel image of the constellation lines. Every dot is
## drawn by angular distance, not pixel distance, so stars stay round near the
## celestial poles where an equirectangular map stretches (Polaris).

const SkyMath := preload("res://scripts/sky_math.gd")
const StarData := preload("res://scripts/star_data.gd")

## How far from a star's centre its dot is drawn, in sigmas.
const CUTOFF_SIGMAS := 3.0

## Colour image of every star in StarData.STARS.
static func bake_stars(width: int, height: int) -> Image:
	var img := Image.create(width, height, false, Image.FORMAT_RGB8)
	var s := StarData.STARS
	for i in range(0, s.size(), 4):
		var mag := s[i + 2]
		var colour := SkyMath.star_color(s[i + 3]) * SkyMath.star_peak(mag)
		splat(img, SkyMath.radec_to_vector(s[i], s[i + 1]), SkyMath.star_sigma(mag), colour, true)
	return img

## One-channel image of the constellation lines in StarData.LINES, as thin
## faint-looking strokes (the shader scales them down further).
static func bake_lines(width: int, height: int) -> Image:
	var img := Image.create(width, height, false, Image.FORMAT_L8)
	var l := StarData.LINES
	for i in range(0, l.size(), 4):
		var a := SkyMath.radec_to_vector(l[i], l[i + 1])
		var b := SkyMath.radec_to_vector(l[i + 2], l[i + 3])
		var angle := a.angle_to(b)
		# One dot per map pixel along the great circle between the two stars.
		var steps := maxi(2, int(ceilf(angle / (PI / height))))
		for k in range(steps + 1):
			var p := a.slerp(b, float(k) / steps)
			splat(img, p, 0.6, Color.WHITE, false)
	return img

## Draw a Gaussian dot of `sigma` pixels (measured along a row at the equator)
## centred on celestial unit vector `v`. `add` sums with what's there (stars
## that overlap); otherwise the brighter wins (line segments).
static func splat(img: Image, v: Vector3, sigma: float, colour: Color, add: bool) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var centre := SkyMath.map_pixel(v, w, h)
	var lat := asin(clampf(v.z, -1.0, 1.0))
	var rad_per_px := PI / h
	var sigma_rad := sigma * rad_per_px
	var reach_y := ceili(CUTOFF_SIGMAS * sigma)
	# A row at latitude `lat` is shorter by cos(lat), so a dot is wider in pixels.
	var cos_lat := maxf(cos(lat), 1e-4)
	var reach_x := mini(ceili(CUTOFF_SIGMAS * sigma / cos_lat), w / 2)
	var cx := int(floorf(centre.x))
	var cy := int(floorf(centre.y))
	for y in range(cy - reach_y, cy + reach_y + 1):
		if y < 0 or y >= h:
			continue
		var py_lat := (0.5 - (y + 0.5) / h) * PI
		for x in range(cx - reach_x, cx + reach_x + 1):
			var wx := posmod(x, w)
			var px_lon := ((wx + 0.5) / w - 0.5) * TAU
			var dir := Vector3(cos(py_lat) * cos(px_lon), cos(py_lat) * sin(px_lon), sin(py_lat))
			var d2 := 2.0 * (1.0 - clampf(dir.dot(v), -1.0, 1.0))
			var k := exp(-d2 / (2.0 * sigma_rad * sigma_rad))
			if k < 0.01:
				continue
			var add_c := colour * k
			var old := img.get_pixel(wx, y)
			if add:
				img.set_pixel(wx, y, Color(minf(old.r + add_c.r, 1.0), minf(old.g + add_c.g, 1.0), minf(old.b + add_c.b, 1.0)))
			else:
				img.set_pixel(wx, y, Color(maxf(old.r, add_c.r), maxf(old.g, add_c.g), maxf(old.b, add_c.b)))
