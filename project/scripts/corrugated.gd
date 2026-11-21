extends RefCounted
## The blue corrugated-metal material shared by the Shop's walls, gables and
## barn door (D-98). `.import` files aren't committed, so mipmaps (needed to
## stop the ribs shimmering at a distance) are generated here rather than in
## the texture's import settings.

const ALBEDO := "res://textures/buildings/corrugated_blue.png"
const NORMAL := "res://textures/buildings/corrugated_blue_normal.png"
## One 256 px tile holds 8 ribs; a 1.25 scale gives a ~10 cm rib pitch.
const TILE_SCALE := 1.25

static var _cache := {}

static func _mipmapped(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var image := (load(path) as Texture2D).get_image()
	if image.is_compressed():
		image.decompress()
	image.generate_mipmaps()
	_cache[path] = ImageTexture.create_from_image(image)
	return _cache[path]

## World-space triplanar keeps the ribs continuous across separate wall
## pieces and facing in the same direction on every wall.
static func material(tint := Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _mipmapped(ALBEDO)
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = _mipmapped(NORMAL)
	m.metallic = 0.45
	m.metallic_specular = 0.6
	m.roughness = 0.42
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(TILE_SCALE, TILE_SCALE, TILE_SCALE)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m
