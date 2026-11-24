extends RefCounted
## The pure maths behind the driveable world beyond the farm (D-148), kept apart
## from the node that builds it so tests can check it without a scene.
##
## world_data.gd holds real USGS 3DEP ground elevation on a 20 m grid over an
## 11.2 km square centred on the scene origin. This turns it into scene heights:
##
## * Heights are metres above the farm's own ground (y = 0 at the origin's
##   elevation).
## * The farm itself, the 520 m ground square that terrain.gd carves the ditch
##   and pond into, stays dead level: `height_at` fades the real relief in over
##   BLEND metres beyond the square's edge, so there is no step where the two
##   meet. The farm's relief is only +-2.3 m, so nothing is lost.
## * The ground is a grid of cells, each split into two triangles along the same
##   diagonal everywhere. `height_at` interpolates on those very triangles, so a
##   road or a car wheel placed with it sits exactly on the mesh and collider.
## * The ground is cut into CHUNK_CELLS x CHUNK_CELLS-cell chunks that
##   world_terrain.gd builds around the player and drops behind them.

const WorldData := preload("res://scripts/world_data.gd")

## Cells per chunk side (16 cells of 20 m = 320 m).
const CHUNK_CELLS := 16
## The farm's ground square: Ground node at (49.4, -33.7), 520 m on a side.
const FARM := Rect2(-210.6, -293.7, 520.0, 520.0)
## Distance beyond the farm square over which real relief fades in.
const BLEND := 250.0
## Under the farm square the ground is dropped slightly so the two surfaces
## never z-fight where they overlap (cells straddling the square's edge).
const FARM_SINK := 0.08
const FARM_SINK_RUN := 4.0

static var _heights := PackedFloat32Array()

## All grid elevations in metres above the origin, row by row (north first).
static func heights() -> PackedFloat32Array:
	if _heights.is_empty():
		_heights = decode_heights(WorldData.HEIGHTS_B64, WorldData.ORIGIN_ELEVATION)
	return _heights

static func decode_heights(b64: String, origin_elevation: float) -> PackedFloat32Array:
	var raw := Marshalls.base64_to_raw(b64)
	var count := raw.size() / 2
	var out := PackedFloat32Array()
	out.resize(count)
	for i in count:
		out[i] = raw.decode_s16(i * 2) * 0.1 - origin_elevation
	return out

## Number of chunks along each side of the world.
static func chunk_count() -> int:
	return (WorldData.NODES - 1) / CHUNK_CELLS

## Side of a chunk in metres.
static func chunk_size() -> float:
	return CHUNK_CELLS * WorldData.CELL

## South-west... (north-west) corner of chunk (cx, cz) in scene metres.
static func chunk_corner(cx: int, cz: int) -> Vector2:
	return Vector2(-WorldData.HALF + cx * chunk_size(), -WorldData.HALF + cz * chunk_size())

## The chunk that holds scene point (x, z), or (-1, -1) outside the world.
static func chunk_at(x: float, z: float) -> Vector2i:
	var cx := floori((x + WorldData.HALF) / chunk_size())
	var cz := floori((z + WorldData.HALF) / chunk_size())
	if cx < 0 or cz < 0 or cx >= chunk_count() or cz >= chunk_count():
		return Vector2i(-1, -1)
	return Vector2i(cx, cz)

static func inside_world(x: float, z: float) -> bool:
	return absf(x) <= WorldData.HALF and absf(z) <= WorldData.HALF

## Metres from (x, z) to the farm square (0 inside it).
static func farm_distance(x: float, z: float) -> float:
	var dx := maxf(maxf(FARM.position.x - x, x - FARM.end.x), 0.0)
	var dz := maxf(maxf(FARM.position.y - z, z - FARM.end.y), 0.0)
	return sqrt(dx * dx + dz * dz)

static func in_farm(x: float, z: float) -> bool:
	return FARM.has_point(Vector2(x, z))

## Real ground height (m above the origin) at (x, z), on the grid's own
## triangles; the grid's nearest edge value beyond the world.
static func raw_height(x: float, z: float) -> float:
	var h := heights()
	var n: int = WorldData.NODES
	var gx := clampf((x + WorldData.HALF) / WorldData.CELL, 0.0, n - 1.001)
	var gz := clampf((z + WorldData.HALF) / WorldData.CELL, 0.0, n - 1.001)
	var i := int(gx)
	var j := int(gz)
	var u := gx - i
	var v := gz - j
	var h00 := h[j * n + i]
	var h10 := h[j * n + i + 1]
	var h01 := h[(j + 1) * n + i]
	var h11 := h[(j + 1) * n + i + 1]
	# Each cell is split along its (i, j)-(i+1, j+1) diagonal: the triangle
	# (00, 10, 11) where u >= v, and (00, 11, 01) where v > u.
	if u >= v:
		return h00 + (h10 - h00) * u + (h11 - h10) * v
	return h00 + (h11 - h01) * u + (h01 - h00) * v

## Ground height of the whole world at (x, z): level at the farm, real relief
## beyond the blend.
static func height_at(x: float, z: float) -> float:
	var d := farm_distance(x, z)
	var h := raw_height(x, z) * smoothstep(0.0, BLEND, d)
	return h - FARM_SINK * (1.0 - smoothstep(0.0, FARM_SINK_RUN, d))

## Ground normal at (x, z), from differences of `height_at` over a metre.
static func normal_at(x: float, z: float) -> Vector3:
	var e := 1.0
	var dx := height_at(x + e, z) - height_at(x - e, z)
	var dz := height_at(x, z + e) - height_at(x, z - e)
	return Vector3(-dx, 2.0 * e, -dz).normalized()

## Slope (rise over run, as a fraction) of the ground at (x, z).
static func slope_at(x: float, z: float) -> float:
	var n := normal_at(x, z)
	return sqrt(maxf(1.0 - n.y * n.y, 0.0)) / maxf(n.y, 1e-4)

## True when a whole grid cell lies inside the farm square, so the farm's own
## ground covers it and the world needs no mesh there.
static func cell_inside_farm(x0: float, z0: float) -> bool:
	var c: float = WorldData.CELL
	return in_farm(x0, z0) and in_farm(x0 + c, z0 + c) and in_farm(x0 + c, z0) and in_farm(x0, z0 + c)

## One chunk's ground: {"mesh": arrays for ArrayMesh, "faces": collision
## triangles, "bounds": AABB}. Vertices are in scene metres; the chunk node sits
## at the origin. UV is the scene position in the imagery's 0..1 frame.
static func chunk_arrays(cx: int, cz: int) -> Dictionary:
	var cell: float = WorldData.CELL
	var corner := chunk_corner(cx, cz)
	var side := CHUNK_CELLS + 1
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	vertices.resize(side * side)
	normals.resize(side * side)
	uvs.resize(side * side)
	var lo := INF
	var hi := -INF
	for j in side:
		for i in side:
			var x := corner.x + i * cell
			var z := corner.y + j * cell
			var y := height_at(x, z)
			lo = minf(lo, y)
			hi = maxf(hi, y)
			vertices[j * side + i] = Vector3(x, y, z)
			normals[j * side + i] = normal_at(x, z)
			uvs[j * side + i] = Vector2((x + WorldData.HALF) / (2.0 * WorldData.HALF), (z + WorldData.HALF) / (2.0 * WorldData.HALF))
	var indices := PackedInt32Array()
	var faces := PackedVector3Array()
	for j in CHUNK_CELLS:
		for i in CHUNK_CELLS:
			if cell_inside_farm(corner.x + i * cell, corner.y + j * cell):
				continue
			var a := j * side + i          # (i, j)
			var b := a + 1                 # (i+1, j)
			var c := a + side + 1          # (i+1, j+1)
			var d := a + side              # (i, j+1)
			# Winding that faces up (+Y) when x is east and z is south.
			for t in [a, b, c, a, c, d]:
				indices.append(t)
				faces.append(vertices[t])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	return {"mesh": arrays, "faces": faces,
			"bounds": AABB(Vector3(corner.x, lo, corner.y), Vector3(chunk_size(), hi - lo, chunk_size()))}
