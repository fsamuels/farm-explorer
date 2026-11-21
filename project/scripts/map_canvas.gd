extends Control
## Draws the farm map for one view (center + zoom): aerial imagery, fences, the
## property line, building footprints and names, horses, the breadcrumb trail,
## the waypoint and the player (D-93). The minimap and the full-screen map are
## two of these with different settings.
##
## Everything comes from scene groups (see collect()), so a building, fence or
## horse added to main.tscn shows up on the map without touching this script.

const MapMath := preload("res://scripts/map_math.gd")

const BACKDROP := Color(0.08, 0.1, 0.08)
const BUILDING_FILL := Color(0.96, 0.92, 0.82, 0.6)
const BUILDING_HOVER_FILL := Color(1.0, 0.8, 0.35, 0.85)
const BUILDING_EDGE := Color(0.12, 0.08, 0.04, 0.95)
const FENCE_COLOR := Color(1.0, 1.0, 0.95, 0.55)
const BOUNDARY_COLOR := Color(1.0, 0.8, 0.2, 0.95)
const HORSE_COLOR := Color(0.62, 0.38, 0.18)
const TRAIL_COLOR := Color(0.35, 0.82, 1.0, 0.8)
const WAYPOINT_COLOR := Color(0.25, 0.95, 0.45)
const PLAYER_COLOR := Color(1.0, 0.22, 0.15)
const LABEL_COLOR := Color(1, 1, 1)
const OUTLINE_COLOR := Color(0, 0, 0)
## Half-angle of the view cone drawn in front of the player arrow.
const VIEW_CONE_HALF_ANGLE := deg_to_rad(35.0)
## How far outside a building's front door a teleport puts you, metres.
const FRONT_CLEARANCE := 2.5
## Horse names only appear once zoomed in this far (px per metre).
const HORSE_LABEL_MIN_SCALE := 4.0

## Scene data shared by every canvas; see collect().
var data := {}
var player: Node3D
var trail := PackedVector2Array()
## Vector2 world position, or null when no waypoint is set.
var waypoint = null

var center := Vector2.ZERO
## Pixels per metre. (Not `scale`, which Control already uses.)
var scale_px := 1.0
var show_labels := true
var show_fences := true
var show_horses := true
var show_trail := true
## Coordinate grid in world X / Z metres, labelled on the top and left edges
## (D-97). Matches the X / Z readouts under the cursor and on the HUD.
var show_grid := true
var show_compass := false
var show_scale_bar := false
## Pin the waypoint to the canvas border when it's out of view (minimap).
var pin_waypoint_to_edge := false
var font_size := 20
## Multiplies marker and line sizes; the minimap draws smaller than the full map.
var marker_scale := 1.0
## Index into data.buildings to highlight, or -1.
var highlighted_building := -1

## Screen rects of the labels drawn so far this frame, to avoid overlaps.
var _placed_labels: Array[Rect2] = []

## Reads the map's static geometry from the scene. Call once the scene is
## ready; horses are kept as nodes because they move.
static func collect(tree: SceneTree) -> Dictionary:
	var imagery := []
	var bounds_points := PackedVector2Array()
	for node in tree.get_nodes_in_group("map_imagery"):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or not mesh_instance.mesh is PlaneMesh:
			continue
		var plane: PlaneMesh = mesh_instance.mesh
		var material := mesh_instance.get_active_material(0) as StandardMaterial3D
		if material == null or material.albedo_texture == null:
			continue
		var xform := mesh_instance.global_transform
		imagery.append({"texture": material.albedo_texture, "xform": xform, "size": plane.size})
		bounds_points.append_array(MapMath.box_footprint(xform.scaled_local(Vector3(plane.size.x, 1, plane.size.y))))

	# Walk-in buildings know where their front door is (D-118); the rest get
	# a spot outside the south wall.
	var door_spots := {}
	for shell in tree.get_nodes_in_group("front_door_spot"):
		var at: Variant = shell.front_door_spot(FRONT_CLEARANCE)
		if at != null:
			door_spots[shell.spot_building()] = MapMath.flatten(at)
	var buildings := []
	for node in tree.get_nodes_in_group("map_building"):
		var poly := MapMath.box_footprint((node as Node3D).global_transform)
		var building_name := String(node.name)
		buildings.append({
			"name": building_name,
			"poly": poly,
			"center": MapMath.polygon_center(poly),
			"front": door_spots.get(building_name, MapMath.front_spot(poly, FRONT_CLEARANCE)),
		})

	var fences := []
	for node in tree.get_nodes_in_group("map_fence"):
		var path := node as Path3D
		if path == null or path.curve == null or path.curve.point_count < 2:
			continue
		var line := PackedVector2Array()
		for i in path.curve.point_count:
			line.append(MapMath.flatten(path.global_transform * path.curve.get_point_position(i)))
		if path.get("closed"):
			line.append(line[0])
		fences.append(line)

	var boundary := []
	for node in tree.get_nodes_in_group("map_boundary"):
		boundary.append(MapMath.segment_ends((node as Node3D).global_transform, node.get("length")))

	return {
		"imagery": imagery,
		"bounds": MapMath.bounds_of(bounds_points),
		"buildings": buildings,
		"footprints": buildings.map(func(b): return b.poly),
		"fences": fences,
		"boundary": boundary,
		"horses": tree.get_nodes_in_group("map_horse"),
	}

func to_screen(world: Vector2) -> Vector2:
	return MapMath.world_to_screen(world, center, scale_px, size)

func to_world(screen: Vector2) -> Vector2:
	return MapMath.screen_to_world(screen, center, scale_px, size)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKDROP)
	if data.is_empty():
		return
	for image in data.imagery:
		_draw_imagery(image)
	if show_grid:
		_draw_grid()
	if show_fences:
		for line in data.fences:
			draw_polyline(_screen_points(line), FENCE_COLOR, 1.5 * marker_scale, true)
	for seg in data.boundary:
		draw_dashed_line(to_screen(seg[0]), to_screen(seg[1]), BOUNDARY_COLOR, 2.5 * marker_scale, 10.0 * marker_scale)
	for i in data.buildings.size():
		var pts := _screen_points(data.buildings[i].poly)
		draw_colored_polygon(pts, BUILDING_HOVER_FILL if i == highlighted_building else BUILDING_FILL)
		pts.append(pts[0])
		draw_polyline(pts, BUILDING_EDGE, 2.0 * marker_scale, true)
	if show_trail and trail.size() >= 2:
		draw_polyline(_screen_points(trail), TRAIL_COLOR, 3.0 * marker_scale, true)
	_placed_labels.clear()
	if show_labels:
		_draw_building_labels()
	if show_horses:
		_draw_horses()
	if waypoint != null:
		_draw_waypoint()
	if player:
		_draw_player()
	if show_compass:
		_draw_compass(Vector2(size.x - 90, 90))
	if show_scale_bar:
		_draw_scale_bar(Vector2(32, size.y - 40))
	if show_grid:
		_draw_grid_labels()

func _screen_points(world_points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(world_points.size())
	for i in world_points.size():
		out[i] = to_screen(world_points[i])
	return out

## A textured PlaneMesh drawn flat: rotated about its own center by its yaw.
func _draw_imagery(image: Dictionary) -> void:
	var xform: Transform3D = image.xform
	var extent: Vector2 = image.size * Vector2(xform.basis.x.length(), xform.basis.z.length()) * scale_px
	draw_set_transform(to_screen(MapMath.flatten(xform.origin)), atan2(xform.basis.x.z, xform.basis.x.x))
	draw_texture_rect(image.texture, Rect2(-extent * 0.5, extent), false)
	draw_set_transform(Vector2.ZERO)

func _draw_horses() -> void:
	var font := get_theme_default_font()
	var radius := 5.0 * marker_scale
	for horse in data.horses:
		if not is_instance_valid(horse):
			continue
		var p := to_screen(MapMath.flatten(horse.global_position))
		draw_circle(p, radius + 1.5, OUTLINE_COLOR)
		draw_circle(p, radius, HORSE_COLOR)
		if show_labels and scale_px >= HORSE_LABEL_MIN_SCALE:
			# Horses bunch up; drop a name rather than draw it over another.
			var text := String(horse.name)
			var label_size := font_size - 4
			var at := p + Vector2(0, -radius - 4 - label_size * 0.5)
			var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size)
			if _try_place(Rect2(at - text_size * 0.5, text_size)):
				_draw_label(font, text, at, label_size, Color(1, 0.9, 0.75))

## Building names, nudged above or below their footprint center when they'd
## overlap a name already drawn (House / House Garage / House South Wing sit
## close together).
func _draw_building_labels() -> void:
	var font := get_theme_default_font()
	for building in data.buildings:
		var text: String = building.name
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var anchor := to_screen(building.center)
		# Every building keeps its name: if no spot is free, it overlaps at center.
		var chosen := anchor
		var placed := false
		for offset in [0.0, -text_size.y, text_size.y, -2.0 * text_size.y, 2.0 * text_size.y]:
			var candidate := anchor + Vector2(0, offset)
			if _try_place(Rect2(candidate - text_size * 0.5, text_size)):
				chosen = candidate
				placed = true
				break
		if not placed:
			_placed_labels.append(Rect2(chosen - text_size * 0.5, text_size))
		_draw_label(font, text, chosen, font_size, LABEL_COLOR)

## Reserves `rect` for a label if it overlaps none placed so far this frame.
func _try_place(rect: Rect2) -> bool:
	if _placed_labels.any(func(r): return r.intersects(rect)):
		return false
	_placed_labels.append(rect)
	return true

## Draws `text` centered on `at` with a dark outline for legibility.
func _draw_label(font: Font, text: String, at: Vector2, label_size: int, color: Color) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size)
	var baseline := at + Vector2(-text_size.x * 0.5, text_size.y * 0.5 - font.get_descent(label_size))
	draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, 6, OUTLINE_COLOR)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, color)

func _draw_waypoint() -> void:
	var p := to_screen(waypoint)
	var view := Rect2(Vector2.ZERO, size).grow(-12.0 * marker_scale)
	if pin_waypoint_to_edge and not view.has_point(p):
		# Off the minimap: an arrow on the border pointing toward it.
		var edge := MapMath.clamp_to_rect_edge(p, view)
		var dir := (p - edge).normalized()
		var s := 10.0 * marker_scale
		var side := dir.orthogonal() * s * 0.6
		draw_colored_polygon(PackedVector2Array([edge + dir * s, edge - dir * s * 0.5 + side, edge - dir * s * 0.5 - side]), WAYPOINT_COLOR)
		return
	var s := 9.0 * marker_scale
	var head := p + Vector2(0, -2.6 * s)
	draw_line(p, head, OUTLINE_COLOR, 3.0 * marker_scale)
	draw_circle(head, s + 2.0, OUTLINE_COLOR)
	draw_circle(head, s, WAYPOINT_COLOR)
	draw_circle(p, 3.0 * marker_scale, OUTLINE_COLOR)

func _draw_player() -> void:
	var p := to_screen(MapMath.flatten(player.global_position))
	var yaw := player.global_rotation.y
	var forward := Vector2(-sin(yaw), -cos(yaw))
	var cone_length := 70.0 * marker_scale
	var cone := PackedVector2Array([p])
	for i in 9:
		var angle := lerpf(-VIEW_CONE_HALF_ANGLE, VIEW_CONE_HALF_ANGLE, i / 8.0)
		cone.append(p + forward.rotated(angle) * cone_length)
	draw_colored_polygon(cone, Color(PLAYER_COLOR, 0.22))

	# A slow pulse ring so "you are here" is easy to spot on the full map.
	var pulse := fmod(Time.get_ticks_msec() / 1400.0, 1.0)
	draw_arc(p, (10.0 + 26.0 * pulse) * marker_scale, 0, TAU, 40, Color(PLAYER_COLOR, 0.8 * (1.0 - pulse)), 2.5 * marker_scale)

	var s := 11.0 * marker_scale
	var arrow := PackedVector2Array([Vector2(0, -1.3 * s), Vector2(s * 0.7, s * 0.7), Vector2(0, s * 0.2), Vector2(-s * 0.7, s * 0.7)])
	for i in arrow.size():
		arrow[i] = p + arrow[i].rotated(-yaw)
	var outline := arrow.duplicate()
	outline.append(arrow[0])
	draw_colored_polygon(arrow, PLAYER_COLOR)
	draw_polyline(outline, Color(1, 1, 1), 2.0 * marker_scale, true)

func _draw_compass(at: Vector2) -> void:
	var font := get_theme_default_font()
	var r := 46.0
	draw_circle(at, r + 8, Color(0, 0, 0, 0.55))
	draw_arc(at, r, 0, TAU, 48, Color(1, 1, 1, 0.6), 2.0)
	draw_colored_polygon(PackedVector2Array([at + Vector2(0, -r + 6), at + Vector2(9, 0), at + Vector2(-9, 0)]), PLAYER_COLOR)
	draw_colored_polygon(PackedVector2Array([at + Vector2(0, r - 6), at + Vector2(9, 0), at + Vector2(-9, 0)]), Color(0.9, 0.9, 0.9))
	var label_r := r + 22
	_draw_label(font, "N", at + Vector2(0, -label_r), font_size, Color(1, 0.85, 0.5))
	_draw_label(font, "S", at + Vector2(0, label_r), font_size - 4, LABEL_COLOR)
	_draw_label(font, "E", at + Vector2(label_r, 0), font_size - 4, LABEL_COLOR)
	_draw_label(font, "W", at + Vector2(-label_r, 0), font_size - 4, LABEL_COLOR)

func _draw_scale_bar(at: Vector2) -> void:
	var meters := MapMath.scale_bar_meters(scale_px, 260.0)
	var length := meters * scale_px
	draw_rect(Rect2(at + Vector2(-12, -38), Vector2(length + 24, 52)), Color(0, 0, 0, 0.55))
	draw_line(at, at + Vector2(length, 0), LABEL_COLOR, 3.0)
	draw_line(at + Vector2(0, -8), at + Vector2(0, 4), LABEL_COLOR, 3.0)
	draw_line(at + Vector2(length, -8), at + Vector2(length, 4), LABEL_COLOR, 3.0)
	_draw_label(get_theme_default_font(), MapMath.format_distance(meters), at + Vector2(length * 0.5, -20), font_size - 2, LABEL_COLOR)

const GRID_MIN_PX := 80.0
const GRID_COLOR := Color(1, 1, 1, 0.14)
const GRID_MAJOR_COLOR := Color(1, 1, 1, 0.3)
const GRID_LABEL_COLOR := Color(1, 1, 1, 0.8)

## Faint lines every grid_step() metres, every fifth one a little stronger.
## Drawn under everything else; the labels go on top in _draw_grid_labels().
func _draw_grid() -> void:
	var step := MapMath.grid_step(scale_px, GRID_MIN_PX)
	var lo := to_world(Vector2.ZERO)
	var hi := to_world(size)
	for x in MapMath.grid_values(lo.x, hi.x, step):
		var sx := to_screen(Vector2(x, 0)).x
		draw_line(Vector2(sx, 0), Vector2(sx, size.y), _grid_color(x, step), 1.0)
	for z in MapMath.grid_values(lo.y, hi.y, step):
		var sy := to_screen(Vector2(0, z)).y
		draw_line(Vector2(0, sy), Vector2(size.x, sy), _grid_color(z, step), 1.0)

## Each line's coordinate along the top (X) and left (Z) edges, drawn last so
## nothing covers them. Labels that would collide in the top-left corner are
## skipped.
func _draw_grid_labels() -> void:
	var step := MapMath.grid_step(scale_px, GRID_MIN_PX)
	var lo := to_world(Vector2.ZERO)
	var hi := to_world(size)
	var font := get_theme_default_font()
	var label_size := font_size - 4
	var corner := Vector2(font.get_string_size("Z -000", HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x + 8, font.get_height(label_size) + 6)
	for x in MapMath.grid_values(lo.x, hi.x, step):
		var sx := to_screen(Vector2(x, 0)).x
		if sx >= corner.x:
			_grid_label(font, "X %d" % int(x), Vector2(sx + 4, 4), label_size)
	for z in MapMath.grid_values(lo.y, hi.y, step):
		var sy := to_screen(Vector2(0, z)).y
		if sy >= corner.y:
			_grid_label(font, "Z %d" % int(z), Vector2(4, sy + 2), label_size)

func _grid_color(v: float, step: float) -> Color:
	return GRID_MAJOR_COLOR if is_zero_approx(fmod(v, step * 5.0)) else GRID_COLOR

func _grid_label(font: Font, text: String, at: Vector2, label_size: int) -> void:
	var baseline := at + Vector2(0, font.get_ascent(label_size))
	draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, 4, OUTLINE_COLOR)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, GRID_LABEL_COLOR)
