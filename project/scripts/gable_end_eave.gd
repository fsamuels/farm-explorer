@tool
extends MeshInstance3D

## Same flat vertical gable-end fill as gable_end.gd, but with a fascia/eave
## overhang step at the base of each side instead of a plain 3-point triangle
## -- measured from a real photo via the elevation-rectifier tool's profile
## trace (see D-50/D-51) rather than assumed.

const WALL_COLOR := Color(0.6, 0.55, 0.5)

@export var width := 1.0:
	set(value):
		width = value
		_rebuild()
@export var rise := 1.0:
	set(value):
		rise = value
		_rebuild()
@export var overhang := 0.0:
	set(value):
		overhang = value
		_rebuild()
@export var fascia_height := 0.0:
	set(value):
		fascia_height = value
		_rebuild()

func _ready() -> void:
	_rebuild()

func _rebuild() -> void:
	if width <= 0.0 or rise <= 0.0:
		return

	var hw := width / 2.0
	var outer := hw + overhang
	# Perimeter, box-top-right around through the peak to box-top-left --
	# same winding sense as gable_end.gd's (right, left, peak) triangle.
	var pts := [
		Vector3(hw, 0.0, 0.0),
		Vector3(outer, 0.0, 0.0),
		Vector3(outer, fascia_height, 0.0),
		Vector3(0.0, rise, 0.0),
		Vector3(-outer, fascia_height, 0.0),
		Vector3(-outer, 0.0, 0.0),
		Vector3(-hw, 0.0, 0.0),
	]

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var normal := Vector3(0.0, 0.0, 1.0)
	# Fan from pts[0], visiting the rest in REVERSE (pts[i+1] before pts[i]) --
	# matches gable_end.gd's (right, left, peak) winding order exactly when
	# overhang/fascia_height collapse to 0 (verified by hand: with those at 0,
	# the one surviving non-degenerate triangle here is (P0, P4, P3) = (right,
	# left, peak), the original's own vertex order). Getting this backwards is
	# exactly what made the eave gables render as invisible/"transparent" from
	# outside the first time -- see D-52.
	for i in range(1, pts.size() - 1):
		st.set_normal(normal)
		st.add_vertex(pts[0])
		st.set_normal(normal)
		st.add_vertex(pts[i + 1])
		st.set_normal(normal)
		st.add_vertex(pts[i])

	var material := StandardMaterial3D.new()
	material.albedo_color = WALL_COLOR
	material.roughness = 0.9
	# Belt-and-suspenders alongside the winding fix above: this shape is new,
	# untested-in-render code (unlike gable_end.gd's already-verified
	# triangle), so don't let a residual winding mistake make it disappear
	# from one side again.
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	mesh = st.commit()
	material_override = material
