@tool
extends MeshInstance3D

const WALL_COLOR := Color(0.6, 0.55, 0.5)

@export var width := 1.0:
	set(value):
		width = value
		_rebuild()
@export var rise := 1.0:
	set(value):
		rise = value
		_rebuild()

func _ready() -> void:
	_rebuild()

func _rebuild() -> void:
	if width <= 0.0 or rise <= 0.0:
		return

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var normal := Vector3(0.0, 0.0, 1.0)
	st.set_normal(normal)
	st.add_vertex(Vector3(width / 2.0, 0.0, 0.0))
	st.set_normal(normal)
	st.add_vertex(Vector3(-width / 2.0, 0.0, 0.0))
	st.set_normal(normal)
	st.add_vertex(Vector3(0.0, rise, 0.0))

	var material := StandardMaterial3D.new()
	material.albedo_color = WALL_COLOR
	material.roughness = 0.9

	mesh = st.commit()
	material_override = material
