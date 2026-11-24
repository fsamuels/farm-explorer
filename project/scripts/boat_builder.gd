extends RefCounted
## Builds the kayak's model from primitives (D-150): a lofted hull, a seat and a
## double-bladed paddle. The origin is the waterline, the bow points to -Z.

const LENGTH := 3.4
const BEAM := 0.72
## How far the hull sits below the waterline, and how high the rim stands above.
const DRAFT := 0.12
const FREEBOARD := 0.24
const STATIONS := 15
const RING := 10
const HULL_COLOR := Color(0.92, 0.38, 0.08)
const SEAT_COLOR := Color(0.15, 0.16, 0.17)
const PADDLE_COLOR := Color(0.12, 0.14, 0.16)
const BLADE_COLOR := Color(0.95, 0.85, 0.15)

## Half the hull's width at `t` (-1 stern .. +1 bow): full amidships, pointed at
## both ends.
static func half_beam(t: float) -> float:
	return BEAM * 0.5 * pow(maxf(1.0 - pow(absf(t), 2.4), 0.0), 0.55)

## Height of the rim at `t`: the bow and stern ride up a little.
static func rim_height(t: float) -> float:
	return FREEBOARD + 0.14 * pow(absf(t), 3.0)

## Builds the hull, seat and paddle under `parent` and returns the paddle node
## (pivoting at the seat) so the kayak can swing it.
static func build(parent: Node3D) -> Node3D:
	var model := Node3D.new()
	model.name = "Model"
	parent.add_child(model)
	model.add_child(_hull())
	model.add_child(_seat())
	return _paddle(model)

static func _material(color: Color, double_sided := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.5
	if double_sided:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

## The hull skin: rings of points from the left rim down round the keel to the
## right rim at each station, joined with triangles.
static func _hull() -> MeshInstance3D:
	var rings: Array = []
	for i in STATIONS:
		var t := -1.0 + 2.0 * float(i) / (STATIONS - 1)
		var w := half_beam(t)
		var rim := rim_height(t)
		var ring: Array[Vector3] = []
		for j in RING:
			var a := PI * float(j) / (RING - 1)  # 0 = left rim .. PI = right rim
			ring.append(Vector3(w * cos(a), rim - (rim + DRAFT) * sin(a), t * LENGTH * 0.5))
		rings.append(ring)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in STATIONS - 1:
		for j in RING - 1:
			var a: Vector3 = rings[i][j]
			var b: Vector3 = rings[i][j + 1]
			var c: Vector3 = rings[i + 1][j]
			var d: Vector3 = rings[i + 1][j + 1]
			for v in [a, c, b, b, c, d]:
				st.add_vertex(v)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Hull"
	mi.mesh = st.commit()
	mi.material_override = _material(HULL_COLOR, true)
	return mi

static func _seat() -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = Vector3(0.42, 0.08, 0.4)
	var mi := MeshInstance3D.new()
	mi.name = "Seat"
	mi.mesh = box
	mi.position = Vector3(0.0, -0.02, 0.35)
	mi.material_override = _material(SEAT_COLOR)
	return mi

## The paddle: a shaft across the kayak with a blade at each end.
static func _paddle(model: Node3D) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "Paddle"
	pivot.position = Vector3(0.0, 0.55, 0.0)
	model.add_child(pivot)
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.018
	shaft.bottom_radius = 0.018
	shaft.height = 2.1
	var shaft_mi := MeshInstance3D.new()
	shaft_mi.name = "Shaft"
	shaft_mi.mesh = shaft
	shaft_mi.rotation.z = PI / 2.0
	shaft_mi.material_override = _material(PADDLE_COLOR)
	pivot.add_child(shaft_mi)
	var blade := BoxMesh.new()
	blade.size = Vector3(0.22, 0.015, 0.42)
	for side in [-1.0, 1.0]:
		var mi := MeshInstance3D.new()
		mi.name = "Blade%s" % ("L" if side < 0.0 else "R")
		mi.mesh = blade
		mi.position = Vector3(side * 1.12, 0.0, 0.0)
		mi.rotation.z = side * deg_to_rad(12.0)
		mi.material_override = _material(BLADE_COLOR)
		pivot.add_child(mi)
	return pivot
