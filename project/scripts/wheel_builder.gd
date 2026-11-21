extends RefCounted
## Turns a car's wheel meshes into four separately turning wheels (D-107).
##
## The downloaded car models don't have wheel nodes: the BMW has one mesh per
## axle (both tyres together) and the TR6 one mesh for all four tyres, another
## for all four rims, and so on. build() takes those meshes, sorts every
## triangle into the wheel it belongs to by where it sits in the car, and
## returns one entry per wheel with its centre, radius and re-centred meshes,
## ready to hang under pivot nodes at the centre. The source meshes can then be
## deleted.
##
## The car faces local -Z (front wheels have the smaller z) and is symmetric
## about x = 0. Quadrant numbers: 0 front-left, 1 front-right, 2 rear-left,
## 3 rear-right.

## Which wheel a car-space point belongs to; `mid_z` is the z between the axles.
static func quadrant(p: Vector3, mid_z: float) -> int:
	return (0 if p.z < mid_z else 2) + (0 if p.x < 0.0 else 1)

## `sources` are the MeshInstance3Ds holding wheel geometry, in the tree under
## `car`. Returns an Array of Dictionaries (one per wheel that got geometry):
##   quadrant: int, front: bool, center: Vector3 (car space), radius: float,
##   meshes: Array[Mesh] (vertices relative to `center`, materials set).
static func build(sources: Array, car: Node3D) -> Array[Dictionary]:
	var to_car := car.global_transform.affine_inverse()
	var union := AABB()
	var first := true
	for mi: MeshInstance3D in sources:
		var box: AABB = (to_car * mi.global_transform) * mi.get_aabb()
		union = box if first else union.merge(box)
		first = false
	var mid_z := union.get_center().z

	var parts: Array = [[], [], [], []]
	var lows: Array[Vector3] = [Vector3.INF, Vector3.INF, Vector3.INF, Vector3.INF]
	var highs: Array[Vector3] = [-Vector3.INF, -Vector3.INF, -Vector3.INF, -Vector3.INF]
	for mi: MeshInstance3D in sources:
		var xf := to_car * mi.global_transform
		var normal_basis := xf.basis.inverse().transposed()
		for s in mi.mesh.get_surface_count():
			var material := mi.get_active_material(s)
			_split_surface(mi.mesh.surface_get_arrays(s), xf, normal_basis, mid_z, material, parts, lows, highs)

	var wheels: Array[Dictionary] = []
	for q in 4:
		if parts[q].is_empty():
			continue
		var center: Vector3 = (lows[q] + highs[q]) * 0.5
		var meshes: Array[Mesh] = []
		for part in parts[q]:
			var arrays: Array = part.arrays
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for i in verts.size():
				verts[i] -= center
			arrays[Mesh.ARRAY_VERTEX] = verts
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_material(0, part.material)
			meshes.append(mesh)
		wheels.append({
			"quadrant": q,
			"front": q < 2,
			"center": center,
			"radius": maxf((highs[q].y - lows[q].y) * 0.5, 0.05),
			"meshes": meshes,
		})
	return wheels

## Sends each triangle of one surface to the wheel its centroid is in, copying
## the vertices it uses (positions and normals into car space) into that
## wheel's surface arrays. Appends {arrays, material} to parts[q] and grows the
## wheel's bounds in lows / highs.
static func _split_surface(src: Array, xf: Transform3D, normal_basis: Basis, mid_z: float,
		material: Material, parts: Array, lows: Array[Vector3], highs: Array[Vector3]) -> void:
	var verts: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = src[Mesh.ARRAY_NORMAL] if src[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	var uvs: PackedVector2Array = src[Mesh.ARRAY_TEX_UV] if src[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var tangents: PackedFloat32Array = src[Mesh.ARRAY_TANGENT] if src[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
	var index: PackedInt32Array
	if src[Mesh.ARRAY_INDEX] != null:
		index = src[Mesh.ARRAY_INDEX]
	else:
		index = PackedInt32Array()
		index.resize(verts.size())
		for i in verts.size():
			index[i] = i

	var car_verts := PackedVector3Array()
	car_verts.resize(verts.size())
	for i in verts.size():
		car_verts[i] = xf * verts[i]

	var out_v: Array[PackedVector3Array] = [PackedVector3Array(), PackedVector3Array(), PackedVector3Array(), PackedVector3Array()]
	var out_n: Array[PackedVector3Array] = [PackedVector3Array(), PackedVector3Array(), PackedVector3Array(), PackedVector3Array()]
	var out_uv: Array[PackedVector2Array] = [PackedVector2Array(), PackedVector2Array(), PackedVector2Array(), PackedVector2Array()]
	var out_t: Array[PackedFloat32Array] = [PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array()]
	var out_i: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array(), PackedInt32Array(), PackedInt32Array()]
	var remap: Array[Dictionary] = [{}, {}, {}, {}]

	# A mirroring transform (negative determinant) reverses every triangle's
	# facing, which the engine would have corrected at draw time; bake that in.
	var mirrored := xf.basis.determinant() < 0.0
	for t in range(0, index.size() - 2, 3):
		var a := index[t]
		var b := index[t + 1]
		var c := index[t + 2]
		var q := quadrant((car_verts[a] + car_verts[b] + car_verts[c]) / 3.0, mid_z)
		for old in ([a, c, b] if mirrored else [a, b, c]):
			var mapped: Dictionary = remap[q]
			if not mapped.has(old):
				mapped[old] = out_v[q].size()
				var p := car_verts[old]
				out_v[q].append(p)
				lows[q] = lows[q].min(p)
				highs[q] = highs[q].max(p)
				if normals.size() > old:
					out_n[q].append((normal_basis * normals[old]).normalized())
				if uvs.size() > old:
					out_uv[q].append(uvs[old])
				if tangents.size() >= old * 4 + 4:
					var tangent := (xf.basis * Vector3(tangents[old * 4], tangents[old * 4 + 1], tangents[old * 4 + 2])).normalized()
					out_t[q].append_array([tangent.x, tangent.y, tangent.z, tangents[old * 4 + 3]])
			out_i[q].append(mapped[old])

	for q in 4:
		if out_i[q].is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = out_v[q]
		if not out_n[q].is_empty():
			arrays[Mesh.ARRAY_NORMAL] = out_n[q]
		if not out_uv[q].is_empty():
			arrays[Mesh.ARRAY_TEX_UV] = out_uv[q]
		if not out_t[q].is_empty():
			arrays[Mesh.ARRAY_TANGENT] = out_t[q]
		arrays[Mesh.ARRAY_INDEX] = out_i[q]
		parts[q].append({"arrays": arrays, "material": material})
