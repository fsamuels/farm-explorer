extends StaticBody3D
## The farm's ground with the ditch and pond cut into it (D-140).
##
## Builds one mesh and one trimesh collider for the whole 520 m ground square.
## Level ground is a handful of big quads; only the tiles the ditch or pond reach
## are subdivided and given heights from terrain_math.gd, so the mesh stays
## small. Every carved tile's edge is level, so it meets the flat quads with no
## crack.
##
## Holes (D-145): any node in the `terrain_hole` group with a `terrain_holes()`
## method (six numbers per rectangle, see TerrainMath.in_hole) has those
## rectangles cut out of the mesh and the collider, on the fine ditch grid, so
## a stairwell can go down through the ground. Such nodes join the group in
## `_enter_tree`, which runs before this node's `_ready`.
##
## The old flat imagery planes (`Ground/MeshInstance3D` and the two orthomosaic
## patches) stay in the scene, hidden: the map and its tests read their
## textures and placement. This node reads the same textures and projects them
## onto the carved mesh with shaders/terrain.gdshader.

const TerrainMath := preload("res://scripts/terrain_math.gd")
const WaterData := preload("res://scripts/water_data.gd")
const TERRAIN_SHADER := preload("res://shaders/terrain.gdshader")

## Square tiles used to decide what is flat. Carved tiles are subdivided further.
const TILE := 4.0
## Vertex spacing inside tiles the ditch reaches (narrow, so finer) and the pond.
const DITCH_STEP := 0.25
const POND_STEP := 0.5

const KIND_FLAT := 0
const KIND_POND := 1
const KIND_DITCH := 2
const KIND_HOLE := 3

## The flat imagery plane that sets the area covered (centre and size).
@export var base_plane_path: NodePath = ^"../Ground/MeshInstance3D"
@export var front_plane_path: NodePath = ^"../FrontSectionOrthomosaic"
@export var middle_plane_path: NodePath = ^"../MiddleSectionOrthomosaic"
@export var surface_path: NodePath = ^"Surface"
@export var collision_path: NodePath = ^"Collision"

## Filled in by build(): how big the result is, for tests and curiosity.
var stats := {}

func _ready() -> void:
	build()

func build() -> void:
	var base := get_node_or_null(base_plane_path) as MeshInstance3D
	if base == null or not base.mesh is PlaneMesh:
		push_warning("terrain: no base ground plane at %s; keeping the flat ground" % base_plane_path)
		return
	var plane: PlaneMesh = base.mesh
	var centre := Vector2(base.global_position.x, base.global_position.z)
	var origin := centre - plane.size * 0.5
	var tiles := Vector2i(ceili(plane.size.x / TILE), ceili(plane.size.y / TILE))

	var started := Time.get_ticks_msec()
	var carve := _classify(origin, tiles)
	_mark_holes(origin, tiles, carve)
	var arrays := _build_arrays(origin, tiles, carve)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays["mesh"])
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(arrays["faces"])

	var surface := get_node_or_null(surface_path) as MeshInstance3D
	if surface:
		surface.mesh = mesh
		surface.material_override = _make_material(base)
	var collider := get_node_or_null(collision_path) as CollisionShape3D
	if collider:
		collider.shape = shape
	stats = {
		"tiles": tiles.x * tiles.y,
		"carved_tiles": carve["count"],
		"hole_tiles": carve["holes"].size(),
		"vertices": (arrays["mesh"][Mesh.ARRAY_VERTEX] as PackedVector3Array).size(),
		"triangles": floori((arrays["mesh"][Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3.0),
		"build_ms": Time.get_ticks_msec() - started,
	}
	_hide_flat_planes(base)

## Marks every tile the ditch or pond can reach, and lists the ditch segments and
## pond capsules that matter to each, so heights are computed against a few
## shapes rather than all of them.
func _classify(origin: Vector2, tiles: Vector2i) -> Dictionary:
	var kinds := PackedByteArray()
	kinds.resize(tiles.x * tiles.y)
	var ditch_lists := {}
	var pond_lists := {}
	var half_diagonal := TILE * 0.5 * sqrt(2.0)
	var segments := WaterData.DITCH_SEGMENTS
	var capsules := TerrainMath.pond_capsules()

	var i := 0
	while i < segments.size():
		var a := Vector2(segments[i], segments[i + 1])
		var b := Vector2(segments[i + 2], segments[i + 3])
		var reach := TerrainMath.DITCH_TOP_HALF + half_diagonal
		for tile in _tiles_near(origin, tiles, minf(a.x, b.x) - reach, minf(a.y, b.y) - reach, maxf(a.x, b.x) + reach, maxf(a.y, b.y) + reach):
			var c := _tile_centre(origin, tile)
			var closest := Geometry2D.get_closest_point_to_segment(c, a, b)
			if c.distance_to(closest) < reach:
				var index := tile.y * tiles.x + tile.x
				kinds[index] = KIND_DITCH
				if not ditch_lists.has(index):
					ditch_lists[index] = PackedFloat32Array()
				ditch_lists[index].append_array(PackedFloat32Array([a.x, a.y, b.x, b.y]))
		i += 4

	i = 0
	while i < capsules.size():
		var a := Vector2(capsules[i], capsules[i + 1])
		var b := Vector2(capsules[i + 3], capsules[i + 4])
		var widest := maxf(capsules[i + 2], capsules[i + 5])
		var reach := widest + half_diagonal
		for tile in _tiles_near(origin, tiles, minf(a.x, b.x) - reach, minf(a.y, b.y) - reach, maxf(a.x, b.x) + reach, maxf(a.y, b.y) + reach):
			var c := _tile_centre(origin, tile)
			var closest := Geometry2D.get_closest_point_to_segment(c, a, b)
			var t := 0.0
			if a != b:
				t = clampf((closest - a).length() / (b - a).length(), 0.0, 1.0)
			if c.distance_to(closest) - lerpf(capsules[i + 2], capsules[i + 5], t) < half_diagonal:
				var index := tile.y * tiles.x + tile.x
				if kinds[index] == KIND_FLAT:
					kinds[index] = KIND_POND
				if not pond_lists.has(index):
					pond_lists[index] = PackedFloat32Array()
				pond_lists[index].append_array(PackedFloat32Array([
					capsules[i], capsules[i + 1], capsules[i + 2],
					capsules[i + 3], capsules[i + 4], capsules[i + 5],
				]))
		i += 6

	var count := 0
	for k in kinds:
		if k != KIND_FLAT:
			count += 1
	return {"kinds": kinds, "ditch": ditch_lists, "pond": pond_lists, "count": count}

## Marks the tiles a hole reaches, and lists the holes for each. Such a tile is
## built on the fine grid and leaves out the triangles inside a hole.
func _mark_holes(origin: Vector2, tiles: Vector2i, carve: Dictionary) -> void:
	var hole_lists := {}
	var kinds: PackedByteArray = carve["kinds"]
	var sources: Array[Node] = get_tree().get_nodes_in_group("terrain_hole") if is_inside_tree() else []
	for node in sources:
		if not node.has_method("terrain_holes"):
			continue
		var holes: PackedFloat32Array = node.terrain_holes()
		var i := 0
		while i + 5 < holes.size():
			var reach := Vector2(holes[i + 4], holes[i + 5]).length()
			for tile in _tiles_near(origin, tiles, holes[i] - reach, holes[i + 1] - reach, holes[i] + reach, holes[i + 1] + reach):
				var index := tile.y * tiles.x + tile.x
				if kinds[index] == KIND_FLAT:
					kinds[index] = KIND_HOLE
				if not hole_lists.has(index):
					hole_lists[index] = PackedFloat32Array()
				hole_lists[index].append_array(holes.slice(i, i + 6))
			i += 6
	carve["holes"] = hole_lists

func _tiles_near(origin: Vector2, tiles: Vector2i, min_x: float, min_z: float, max_x: float, max_z: float) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var x0 := clampi(floori((min_x - origin.x) / TILE), 0, tiles.x - 1)
	var x1 := clampi(floori((max_x - origin.x) / TILE), 0, tiles.x - 1)
	var z0 := clampi(floori((min_z - origin.y) / TILE), 0, tiles.y - 1)
	var z1 := clampi(floori((max_z - origin.y) / TILE), 0, tiles.y - 1)
	for tz in range(z0, z1 + 1):
		for tx in range(x0, x1 + 1):
			out.append(Vector2i(tx, tz))
	return out

func _tile_centre(origin: Vector2, tile: Vector2i) -> Vector2:
	return origin + (Vector2(tile) + Vector2(0.5, 0.5)) * TILE

## Mesh arrays and the flat triangle list for the collider.
func _build_arrays(origin: Vector2, tiles: Vector2i, carve: Dictionary) -> Dictionary:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var faces := PackedVector3Array()
	var kinds: PackedByteArray = carve["kinds"]

	# Level ground: merge each row's run of flat tiles into one quad.
	for tz in tiles.y:
		var run_start := -1
		for tx in range(tiles.x + 1):
			var flat := tx < tiles.x and kinds[tz * tiles.x + tx] == KIND_FLAT
			if flat and run_start < 0:
				run_start = tx
			elif not flat and run_start >= 0:
				_add_flat_quad(vertices, normals, indices, faces,
					origin.x + run_start * TILE, origin.y + tz * TILE,
					origin.x + tx * TILE, origin.y + (tz + 1) * TILE)
				run_start = -1

	for tz in tiles.y:
		for tx in tiles.x:
			var index := tz * tiles.x + tx
			if kinds[index] != KIND_FLAT:
				_add_carved_tile(vertices, normals, indices, faces,
					origin + Vector2(tx, tz) * TILE,
					carve["ditch"].get(index, PackedFloat32Array()),
					carve["pond"].get(index, PackedFloat32Array()),
					carve["holes"].get(index, PackedFloat32Array()))

	var mesh_arrays := []
	mesh_arrays.resize(Mesh.ARRAY_MAX)
	mesh_arrays[Mesh.ARRAY_VERTEX] = vertices
	mesh_arrays[Mesh.ARRAY_NORMAL] = normals
	mesh_arrays[Mesh.ARRAY_INDEX] = indices
	return {"mesh": mesh_arrays, "faces": faces}

func _add_flat_quad(vertices: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array, faces: PackedVector3Array, x0: float, z0: float, x1: float, z1: float) -> void:
	var base := vertices.size()
	vertices.append(Vector3(x0, 0, z0))
	vertices.append(Vector3(x1, 0, z0))
	vertices.append(Vector3(x0, 0, z1))
	vertices.append(Vector3(x1, 0, z1))
	for _i in 4:
		normals.append(Vector3.UP)
	_add_triangle(indices, faces, vertices, base, base + 1, base + 2)
	_add_triangle(indices, faces, vertices, base + 1, base + 3, base + 2)

## One subdivided tile, heights from terrain_math against just the shapes that
## reach it, less any cells whose centre falls in a hole.
func _add_carved_tile(vertices: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array, faces: PackedVector3Array, corner: Vector2, ditch: PackedFloat32Array, pond: PackedFloat32Array, holes := PackedFloat32Array()) -> void:
	var step := DITCH_STEP if ditch.size() > 0 or holes.size() > 0 else POND_STEP
	var n := roundi(TILE / step)
	# Heights on the tile's grid plus one ring outside it, so edge normals match the neighbour's.
	var side := n + 3
	var heights := PackedFloat32Array()
	heights.resize(side * side)
	for j in side:
		for i in side:
			heights[j * side + i] = TerrainMath.height_in(corner.x + (i - 1) * step, corner.y + (j - 1) * step, ditch, pond)
	var base := vertices.size()
	for j in range(n + 1):
		for i in range(n + 1):
			var k := (j + 1) * side + (i + 1)
			vertices.append(Vector3(corner.x + i * step, heights[k], corner.y + j * step))
			normals.append(Vector3(heights[k - 1] - heights[k + 1], 2.0 * step, heights[k - side] - heights[k + side]).normalized())
	for j in n:
		for i in n:
			if holes.size() > 0 and TerrainMath.in_hole(corner.x + (i + 0.5) * step, corner.y + (j + 0.5) * step, holes):
				continue
			var a := base + j * (n + 1) + i
			var b := a + 1
			var c := a + (n + 1)
			var d := c + 1
			_add_triangle(indices, faces, vertices, a, b, c)
			_add_triangle(indices, faces, vertices, b, d, c)

func _add_triangle(indices: PackedInt32Array, faces: PackedVector3Array, vertices: PackedVector3Array, a: int, b: int, c: int) -> void:
	indices.append(a)
	indices.append(b)
	indices.append(c)
	faces.append(vertices[a])
	faces.append(vertices[b])
	faces.append(vertices[c])

func _make_material(base: MeshInstance3D) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = TERRAIN_SHADER
	var base_tex := _plane_texture(base)
	material.set_shader_parameter("base_tex", base_tex)
	material.set_shader_parameter("base_inv", base.global_transform.affine_inverse())
	material.set_shader_parameter("base_size", (base.mesh as PlaneMesh).size)
	for patch in [["front", front_plane_path], ["middle", middle_plane_path]]:
		var node := get_node_or_null(patch[1]) as MeshInstance3D
		var tex := _plane_texture(node) if node and node.mesh is PlaneMesh else null
		var on := tex != null
		material.set_shader_parameter(patch[0] + "_on", 1.0 if on else 0.0)
		if on:
			material.set_shader_parameter(patch[0] + "_tex", tex)
			material.set_shader_parameter(patch[0] + "_inv", node.global_transform.affine_inverse())
			material.set_shader_parameter(patch[0] + "_size", (node.mesh as PlaneMesh).size)
	return material

func _plane_texture(node: MeshInstance3D) -> Texture2D:
	if node == null:
		return null
	var material := node.get_active_material(0) as StandardMaterial3D
	return material.albedo_texture if material else null

## The flat planes would draw over the carved ground, so hide them. They stay in
## the scene for the map, and the collision box under the old ground drops below
## the pond floor as a safety net.
func _hide_flat_planes(base: MeshInstance3D) -> void:
	base.visible = false
	for path in [front_plane_path, middle_plane_path]:
		var node := get_node_or_null(path) as Node3D
		if node:
			node.visible = false
	var old_collision := base.get_parent().get_node_or_null("CollisionShape3D") as Node3D
	if old_collision:
		old_collision.position.y = -WaterData.POND_DEPTH - 2.0

## Ground height at (x, z), the same value the mesh was built from.
func height_at(x: float, z: float) -> float:
	return TerrainMath.height_at(x, z)
