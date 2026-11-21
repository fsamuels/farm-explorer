extends Node3D
## A simple walk-in building (D-115): the same idea as the Shop's shell
## (shop_shell.gd, D-98) but driven by data, so a house or a barn is a few lines
## of scene. The solid placeholder box named `building_name` under Buildings
## stays as the map footprint (this node hides its mesh and turns its collision off); this
## node builds one big hollow room over its footprint in the box's own frame:
## inside wall liners with the door openings cut out (collidable), a visual
## floor, a ceiling (flat, or pitched when `rise` > 0) and a few lights, plus
## working doors (shop_door.gd, E to open).
##
## Exteriors: the house keeps the photo-textured wall planes it already has;
## for a door in one of those, the hole is cut in the plane's texture (alpha)
## where the photographed door is. Walls with no plane are listed in
## `skin_walls` and get a plain skin in `skin_color`, or the Shop's blue
## corrugated metal (corrugated.gd) when `corrugated_skin` is on.
##
## Each entry of `doors` is a Dictionary:
##   wall    "north" | "south" | "east" | "west"
##   u       0..1 across the wall as seen from OUTSIDE, left to right. With a
##           `plane` it is across that plane's texture instead.
##   plane   optional name (under Buildings) of the photo wall plane to cut
##   width, height   the opening, metres (default 0.9 x 2.1)
##   kind    DoorScript.Kind (SWING default, SLIDE for big barn doors)
##   label   shown in the prompt ("Open <label>")
##   ribbed, color   optional leaf look
##
## `open_walls` names walls that are not there at all (a pole barn's open
## sides, D-121): no liner, skin, collision or doors, just the roof above.

const WallLayout := preload("res://scripts/wall_layout.gd")
const DoorScript := preload("res://scripts/shop_door.gd")
const Corrugated := preload("res://scripts/corrugated.gd")

const WALL_T := 0.15
const SKIN_T := 0.03
const FLOOR_TOP := 0.05  # above the 0.03-0.04 ortho patches

## Per wall: outward axis, whether it runs along local x, the direction left to
## right (seen from outside) runs along that axis, the door yaw and the
## direction of a door's local +X along the axis.
const WALLS := {
	"south": {out = Vector3.BACK, along_x = true, sign = 1.0, yaw = 180.0, dir = -1.0},
	"north": {out = Vector3.FORWARD, along_x = true, sign = -1.0, yaw = 0.0, dir = 1.0},
	"east": {out = Vector3.RIGHT, along_x = false, sign = 1.0, yaw = -90.0, dir = 1.0},
	"west": {out = Vector3.LEFT, along_x = false, sign = -1.0, yaw = 90.0, dir = -1.0},
}

@export var building_name := ""
@export var skin_walls := PackedStringArray()
@export var open_walls := PackedStringArray()
@export var skin_color := Color(0.6, 0.55, 0.5)
@export var corrugated_skin := false
@export var liner_color := Color(0.84, 0.82, 0.78)
@export var floor_color := Color(0.45, 0.36, 0.29)
@export var rise := 0.0
@export var ridge_along_z := false
@export var light_count := 1
@export var doors: Array = []

var width := 1.0
var depth := 1.0
var height := 1.0

var _walls_body: StaticBody3D
var _liner: StandardMaterial3D
var _skin: StandardMaterial3D
var _floor: StandardMaterial3D
var _lights: Array[OmniLight3D] = []

## Where a door's centre sits along a wall's axis (local x or z, from the
## footprint centre), for fraction `u` left to right seen from outside.
static func along_for(wall: String, u: float, length: float) -> float:
	return (u - 0.5) * length * float(WALLS[wall].sign)

func _ready() -> void:
	var box := get_node_or_null("../" + building_name) as Node3D
	if box == null:
		push_warning("building_shell: no building named '%s'" % building_name)
		return
	add_to_group("front_door_spot")
	var b := box.global_transform.basis
	width = b.x.length()
	depth = b.z.length()
	height = b.y.length()
	var x_axis := (b.x / width).normalized()
	global_transform = Transform3D(
			Basis(x_axis, Vector3.UP, x_axis.cross(Vector3.UP)),
			Vector3(box.global_position.x, 0.0, box.global_position.z))
	# The placeholder box stays as the map footprint but stops being seen or hit.
	var box_mesh := box.get_node_or_null("MeshInstance3D") as Node3D
	if box_mesh:
		box_mesh.visible = false
	var box_shape := box.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if box_shape:
		box_shape.set_deferred("disabled", true)
	_liner = _material(liner_color, true)
	_skin = Corrugated.material() if corrugated_skin else _material(skin_color, false)
	_floor = _material(floor_color, false)
	_walls_body = StaticBody3D.new()
	_walls_body.name = "Walls"
	add_child(_walls_body)
	_build()

## The room's lights are on only while the camera is inside (or at the door):
## unshadowed omnis would otherwise shine through the walls and roof at night.
func _process(_delta: float) -> void:
	if _lights.is_empty():
		return
	var cam := get_viewport().get_camera_3d()
	var on := false
	if cam:
		var p := to_local(cam.global_position)
		on = absf(p.x) < width / 2.0 + 1.0 and absf(p.z) < depth / 2.0 + 1.0 and p.y < height + rise + 2.0
	if _lights[0].visible != on:
		for light in _lights:
			light.visible = on

func _material(color: Color, both_sides: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	if both_sides:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

## The building this shell belongs to, for the map's teleport (D-118).
func spot_building() -> String:
	return building_name

## The door entries that get built: those not on an open wall.
func live_doors() -> Array:
	return doors.filter(func(d: Dictionary) -> bool: return not open_walls.has(d.wall))

## World position `clearance` metres outside the building's front door: the
## door labelled "front door" if there is one, else the first. With no doors, the
## middle of the first open wall; null with neither.
func front_door_spot(clearance: float) -> Variant:
	var live := live_doors()
	if live.is_empty() and open_walls.is_empty():
		return null
	# With no doors, the middle of the first open side is the way in.
	var d: Dictionary = {"wall": open_walls[0], "u": 0.5} if live.is_empty() else live[0]
	for candidate: Dictionary in live:
		if candidate.get("label", "") == "front door":
			d = candidate
			break
	var spec: Dictionary = WALLS[d.wall]
	var out: Vector3 = spec.out
	var along := _door_along(d)
	var half: float = (depth if spec.along_x else width) / 2.0 + clearance
	var local := Vector3(along, 0.0, out.z * half) if spec.along_x else Vector3(out.x * half, 0.0, along)
	return to_global(local)

func _wall_length(wall: String) -> float:
	return width if WALLS[wall].along_x else depth

## A door entry's centre along its wall's axis, from the footprint centre. With
## a photo plane it follows that texture's `u`, else the wall's own.
func _door_along(d: Dictionary) -> float:
	var wall: String = d.wall
	if d.has("plane"):
		var plane := get_node("../" + String(d.plane)) as MeshInstance3D
		var size := (plane.mesh as PlaneMesh).size
		var world := plane.global_transform * Vector3((float(d.u) - 0.5) * size.x, 0.0, (0.5) * size.y)
		var local := to_local(world)
		return local.x if WALLS[wall].along_x else local.z
	return along_for(wall, float(d.u), _wall_length(wall))

func _build() -> void:
	var by_wall := {}
	for wall in WALLS:
		by_wall[wall] = []
	for d: Dictionary in doors:
		if open_walls.has(d.wall):
			push_warning("building_shell: a door on the open %s wall is skipped" % d.wall)
			continue
		var w := float(d.get("width", 0.9))
		var h := float(d.get("height", 2.1))
		var c := _door_along(d)
		by_wall[d.wall].append({c = c, w = w + 0.04, y0 = 0.0, y1 = h})
		if d.has("plane"):
			_cut_hole(d, c, w, h)
		_add_door(d, c, w, h)
	for wall in WALLS:
		if open_walls.has(wall):
			continue
		_build_wall(wall, by_wall[wall], skin_walls.has(wall))
	_build_floor()
	_build_ceiling()
	_build_lights()

## One wall's inside liner (and, when asked, an outside skin), cut around the
## openings.
func _build_wall(wall: String, openings: Array, with_skin: bool) -> void:
	var spec: Dictionary = WALLS[wall]
	var outward: Vector3 = spec.out
	var along_x: bool = spec.along_x
	var length := _wall_length(wall)
	var offset := (depth if along_x else width) / 2.0
	var body_t := WALL_T - SKIN_T
	for r in WallLayout.pieces(length, height, openings):
		var along := r.position.x + r.size.x / 2.0
		var y := r.position.y + r.size.y / 2.0
		var body_off := offset - SKIN_T - body_t / 2.0
		var skin_off := offset - SKIN_T / 2.0
		if along_x:
			_add_box(Vector3(along, y, outward.z * body_off), Vector3(r.size.x, r.size.y, body_t), _liner, true)
			if with_skin:
				_add_box(Vector3(along, y, outward.z * skin_off), Vector3(r.size.x, r.size.y, SKIN_T), _skin, false)
		else:
			_add_box(Vector3(outward.x * body_off, y, along), Vector3(body_t, r.size.y, r.size.x), _liner, true)
			if with_skin:
				_add_box(Vector3(outward.x * skin_off, y, along), Vector3(SKIN_T, r.size.y, r.size.x), _skin, false)

func _add_door(d: Dictionary, c: float, w: float, h: float) -> void:
	var spec: Dictionary = WALLS[d.wall]
	var door := DoorScript.new()
	door.kind = d.get("kind", DoorScript.Kind.SWING)
	door.width = w + 0.04
	door.height = h - 0.02
	door.label = d.get("label", "door")
	door.ribbed = d.get("ribbed", false)
	if d.has("color"):
		door.color = d.color
	var half: float = (depth if spec.along_x else width) / 2.0
	var start: float = c - float(spec.dir) * (w / 2.0 + 0.02)
	var out: Vector3 = spec.out
	var slide: bool = door.kind == DoorScript.Kind.SLIDE
	var perp := half if slide else half - WALL_T / 2.0
	if slide:
		door.thickness = 0.06
		door.offset_z = -0.04
		door.slide = float(spec.dir) * (w + 0.1)
		door.swing_time = 1.2
		door.window_pane = false
	else:
		door.window_pane = d.get("window_pane", true)
	if spec.along_x:
		door.position = Vector3(start, 0.0, out.z * perp)
	else:
		door.position = Vector3(out.x * perp, 0.0, start)
	door.rotation_degrees.y = float(spec.yaw)
	door.name = "Door_%s_%d" % [d.wall, get_child_count()]
	door.set_meta("wall", d.wall)
	add_child(door)

## Punch the doorway out of a photo wall plane: copy its texture, make the
## door's rectangle transparent and switch the material to alpha scissor.
func _cut_hole(d: Dictionary, c: float, w: float, h: float) -> void:
	var plane := get_node("../" + String(d.plane)) as MeshInstance3D
	var material := plane.get_surface_override_material(0) as StandardMaterial3D
	if material == null or material.albedo_texture == null:
		push_warning("building_shell: %s has no textured material to cut a doorway in" % d.plane)
		return
	var image := material.albedo_texture.get_image()
	if image == null:
		push_warning("building_shell: could not read the texture of %s" % d.plane)
		return
	if image.is_compressed() and image.decompress() != OK:
		push_warning("building_shell: could not decompress the texture of %s, so its doorway is not cut" % d.plane)
		return
	image.convert(Image.FORMAT_RGBA8)
	var size := (plane.mesh as PlaneMesh).size
	var spec: Dictionary = WALLS[d.wall]
	# The doorway's corners in the shell's frame, through the plane, to texture uv.
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for sa in [-0.5, 0.5]:
		for y in [0.0, h]:
			var a: float = c + float(sa) * w
			var local := Vector3(a, y, 0.0) if spec.along_x else Vector3(0.0, y, a)
			var on_plane := plane.to_local(to_global(local))
			var uv := Vector2(on_plane.x / size.x + 0.5, on_plane.z / size.y + 0.5)
			lo = lo.min(uv)
			hi = hi.max(uv)
	# Everything from the door's top edge to the bottom of the picture (the
	# stoop and foundation under the door) goes too, so the way in is clear.
	var px := Rect2i(Vector2i(floori(lo.x * image.get_width()), floori(lo.y * image.get_height())),
			Vector2i(ceili((hi.x - lo.x) * image.get_width()), image.get_height()))
	px = px.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	image.fill_rect(px, Color(0, 0, 0, 0))
	image.generate_mipmaps()
	var cut := material.duplicate() as StandardMaterial3D
	cut.albedo_texture = ImageTexture.create_from_image(image)
	cut.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	cut.alpha_scissor_threshold = 0.5
	plane.set_surface_override_material(0, cut)

func _build_floor() -> void:
	# Visual only: the player walks on the ground's own collision.
	_add_box(Vector3(0, FLOOR_TOP / 2.0, 0), Vector3(width - 2 * WALL_T, FLOOR_TOP, depth - 2 * WALL_T), _floor, false)

func _build_ceiling() -> void:
	var half_len := (depth if ridge_along_z else width) / 2.0 - WALL_T
	var half_cross := (width if ridge_along_z else depth) / 2.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := height - 0.02
	if rise <= 0.0:
		_quad(st, Vector3(-half_len, h, -half_cross), Vector3(half_len, h, -half_cross), Vector3(half_len, h, half_cross), Vector3(-half_len, h, half_cross), Vector3.DOWN)
	else:
		# Underside of both slopes, nudged down so it never z-fights the roof,
		# and the inside of the two end walls up to the ridge. Built with the
		# ridge along x (cross axis z), then turned if the ridge runs along z.
		var r := rise - 0.04
		_quad(st, Vector3(-half_len, h, -half_cross), Vector3(half_len, h, -half_cross), Vector3(half_len, h + r, 0), Vector3(-half_len, h + r, 0), Vector3(0, -half_cross, r).normalized())
		_quad(st, Vector3(-half_len, h + r, 0), Vector3(half_len, h + r, 0), Vector3(half_len, h, half_cross), Vector3(-half_len, h, half_cross), Vector3(0, -half_cross, -r).normalized())
		for sx in [-1.0, 1.0]:
			var n := Vector3(sx, 0, 0)
			st.set_normal(n); st.add_vertex(Vector3(sx * half_len, h, -half_cross))
			st.set_normal(n); st.add_vertex(Vector3(sx * half_len, h, half_cross))
			st.set_normal(n); st.add_vertex(Vector3(sx * half_len, h + r, 0))
	var mi := MeshInstance3D.new()
	mi.name = "Ceiling"
	mi.mesh = st.commit()
	mi.material_override = _liner
	if ridge_along_z:
		mi.rotation_degrees.y = 90.0
	add_child(mi)

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	for p in [a, b, c, a, c, d]:
		st.set_normal(n)
		st.add_vertex(p)

func _build_lights() -> void:
	for i in maxi(light_count, 1):
		var f := (float(i) + 0.5) / float(maxi(light_count, 1)) - 0.5
		var light := OmniLight3D.new()
		var long_axis := (depth if ridge_along_z else width)
		light.position = Vector3(0, height * 0.85 + rise * 0.3, f * long_axis * 0.8) if ridge_along_z \
				else Vector3(f * long_axis * 0.8, height * 0.85 + rise * 0.3, 0)
		light.omni_range = maxf(width, depth) * 0.7
		light.light_energy = 1.0
		light.light_color = Color(1.0, 0.95, 0.85)
		light.shadow_enabled = false
		light.visible = false
		add_child(light)
		_lights.append(light)

func _add_box(pos: Vector3, size: Vector3, material: Material, collide: bool) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	add_child(mi)
	if collide:
		var shape := BoxShape3D.new()
		shape.size = size
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position = pos
		_walls_body.add_child(cs)
