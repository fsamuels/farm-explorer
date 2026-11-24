extends Node3D
## The driveable world beyond the farm (D-146): real 3DEP ground with the named
## roads laid on it, out to 5.6 km each way, built in 320 m chunks around the
## camera and dropped behind it. The maths is in world_math.gd and road_math.gd;
## this node only decides which chunks exist.
##
## Each chunk is a ground mesh with its own trimesh collider and the road
## ribbons whose pieces start inside it. The farm's own ground (terrain.gd) sits
## in the middle and stays as it was; the world meets it at the edge of the
## 520 m ground square. Beyond LOAD_RADIUS the land is the coarse distant
## terrain (distant_terrain.gd), which sinks out of the way where the chunks are.

const WorldData := preload("res://scripts/world_data.gd")
const WorldMath := preload("res://scripts/world_math.gd")
const RoadMath := preload("res://scripts/road_math.gd")
const GROUND_SHADER := preload("res://shaders/world_ground.gdshader")
const ROAD_SHADER := preload("res://shaders/road.gdshader")
const NAIP: Texture2D = preload("res://textures/world/naip_world.jpg")

## Chunks within this distance (m) of the camera exist. It stays under the
## distant terrain's squeeze start (2.4 km), where the real depths end.
@export var load_radius := 2300.0
## A loaded chunk is dropped once it is this much farther than load_radius.
@export var unload_margin := 320.0
## Most milliseconds a frame spends building chunks (one is always built).
@export var build_budget_ms := 4.0
@export var weather_path: NodePath = ^"../Weather"

var _chunks := {}  # Vector2i -> Node3D
var _ground_material: ShaderMaterial
var _road_material: ShaderMaterial
var _weather: Node
var _last_focus := Vector2(INF, INF)

func _ready() -> void:
	_weather = get_node_or_null(weather_path)
	_ground_material = ShaderMaterial.new()
	_ground_material.shader = GROUND_SHADER
	_ground_material.set_shader_parameter("naip", NAIP)
	_road_material = ShaderMaterial.new()
	_road_material.shader = ROAD_SHADER
	_add_map_imagery()
	_add_edge_walls()
	# Roads wanted before the first frame draws: whatever's around the origin.
	update_around(Vector2.ZERO, true)

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var at := camera.global_position
	update_around(Vector2(at.x, at.z), false)

## Chunks that should exist for a camera at `focus` (x, z): every chunk whose
## nearest point is within `radius`, nearest first.
static func wanted_chunks(focus: Vector2, radius: float) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var size := WorldMath.chunk_size()
	var here := WorldMath.chunk_at(clampf(focus.x, -WorldData.HALF + 1.0, WorldData.HALF - 1.0),
			clampf(focus.y, -WorldData.HALF + 1.0, WorldData.HALF - 1.0))
	var reach := int(ceil(radius / size)) + 1
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var c := Vector2i(here.x + dx, here.y + dz)
			if c.x < 0 or c.y < 0 or c.x >= WorldMath.chunk_count() or c.y >= WorldMath.chunk_count():
				continue
			if chunk_distance(c, focus) <= radius:
				out.append(c)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return chunk_distance(a, focus) < chunk_distance(b, focus))
	return out

## Distance (m) from `focus` to the nearest point of chunk `c`.
static func chunk_distance(c: Vector2i, focus: Vector2) -> float:
	var corner := WorldMath.chunk_corner(c.x, c.y)
	var size := WorldMath.chunk_size()
	var dx := maxf(maxf(corner.x - focus.x, focus.x - (corner.x + size)), 0.0)
	var dz := maxf(maxf(corner.y - focus.y, focus.y - (corner.y + size)), 0.0)
	return sqrt(dx * dx + dz * dz)

## Build the chunks wanted around `focus` and drop the ones left behind.
## `everything` builds them all now (start-up, tests); otherwise within the
## frame budget, except that chunks right under the camera are never put off.
func update_around(focus: Vector2, everything: bool) -> void:
	for c in _chunks.keys():
		if chunk_distance(c, focus) > load_radius + unload_margin:
			_free_chunk(c)
	var started := Time.get_ticks_usec()
	for c in wanted_chunks(focus, load_radius):
		if _chunks.has(c):
			continue
		var urgent := chunk_distance(c, focus) < WorldMath.chunk_size()
		if not everything and not urgent and (Time.get_ticks_usec() - started) / 1000.0 > build_budget_ms:
			break
		_build_chunk(c)
	_last_focus = focus

## The whole-world aerial photo as an invisible plane in group `map_world_imagery`,
## which the full map and minimap draw under the farm's own imagery
## (map_canvas.gd collect()), so the map shows the roads you drive.
func _add_map_imagery() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.0 * WorldData.HALF, 2.0 * WorldData.HALF)
	var material := StandardMaterial3D.new()
	material.albedo_texture = NAIP
	var node := MeshInstance3D.new()
	node.name = "MapImagery"
	node.mesh = plane
	node.material_override = material
	node.visible = false
	node.add_to_group("map_world_imagery")
	add_child(node)

## Invisible walls round the edge of the real ground, so nothing falls off the
## world: 5.6 km out the distant terrain carries on as scenery only.
func _add_edge_walls() -> void:
	var body := StaticBody3D.new()
	body.name = "EdgeWalls"
	var half: float = WorldData.HALF
	var thick := 10.0
	var height := 400.0
	for side in [[Vector3(0, 0, -half - thick * 0.5), Vector3(2 * half + 2 * thick, height, thick)],
			[Vector3(0, 0, half + thick * 0.5), Vector3(2 * half + 2 * thick, height, thick)],
			[Vector3(-half - thick * 0.5, 0, 0), Vector3(thick, height, 2 * half)],
			[Vector3(half + thick * 0.5, 0, 0), Vector3(thick, height, 2 * half)]]:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = side[1]
		shape.shape = box
		shape.position = side[0]
		body.add_child(shape)
	add_child(body)

func chunk_loaded(c: Vector2i) -> bool:
	return _chunks.has(c)

func loaded_count() -> int:
	return _chunks.size()

func _build_chunk(c: Vector2i) -> void:
	var node := Node3D.new()
	node.name = "Chunk_%d_%d" % [c.x, c.y]
	var ground := WorldMath.chunk_arrays(c.x, c.y)
	var ground_mesh := MeshInstance3D.new()
	ground_mesh.name = "Ground"
	var mesh := ArrayMesh.new()
	if ground.mesh[Mesh.ARRAY_INDEX].size() > 0:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ground.mesh)
		mesh.surface_set_material(0, _ground_material)
		mesh.custom_aabb = ground.bounds
	ground_mesh.mesh = mesh
	ground_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(ground_mesh)
	if ground.faces.size() > 0:
		var body := StaticBody3D.new()
		body.name = "Collision"
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(ground.faces)
		var owner_shape := CollisionShape3D.new()
		owner_shape.shape = shape
		body.add_child(owner_shape)
		node.add_child(body)
	var pieces := RoadMath.pieces_in(c)
	if not pieces.is_empty():
		var road_mesh := MeshInstance3D.new()
		road_mesh.name = "Roads"
		var rm := ArrayMesh.new()
		rm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, RoadMath.build_arrays(pieces))
		rm.surface_set_material(0, _road_material)
		road_mesh.mesh = rm
		road_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(road_mesh)
	add_child(node)
	_chunks[c] = node
	if _weather and _weather.has_method("add_surface"):
		_weather.add_surface(ground_mesh)

func _free_chunk(c: Vector2i) -> void:
	var node: Node3D = _chunks[c]
	_chunks.erase(c)
	if _weather and _weather.has_method("remove_surface"):
		_weather.remove_surface(node.get_node("Ground"))
	node.queue_free()
