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

## Real photo texture for this gable, exported by the elevation-rectifier
## tool's "gable crop" -- tall enough to reach the traced ridge point AND
## wide enough to reach the fascia overhang past the wall's own left/right
## edges (see D-53/D-57). Leave unset for the plain WALL_COLOR fill the
## other (unphotographed) gables still use.
@export var wall_texture: Texture2D:
	set(value):
		wall_texture = value
		_rebuild()
## Real-world height (meters, ground to top) the texture image spans --
## must match the elevation-rectifier tool's own gable_height_m for this
## wall exactly, or the photo will sit at the wrong scale on the mesh.
@export var texture_height_m := 0.0:
	set(value):
		texture_height_m = value
		_rebuild()
## Real-world width (meters) the texture image spans -- NOT necessarily
## the same as `width` above, since the tool widens the crop to also cover
## the fascia overhang on both sides (gable_width_m in its saved data).
## Leaving this at 0 falls back to `width` (pre-D-57 crops that didn't
## widen for the overhang; will show minor stretch/clamping on the
## overhang triangles, same artifact D-57 fixed at the source).
@export var texture_width_m := 0.0:
	set(value):
		texture_width_m = value
		_rebuild()
## Real-world x (meters, in the wall's own left-edge-at-0 frame) that the
## texture's left edge (u=0) starts at -- negative when the crop widened
## to the left to cover an overhang (gable_x_offset_m in the tool's saved
## data). 0 is correct for a texture that starts exactly at the wall's
## left edge (including any pre-D-57 crop).
@export var texture_x_offset_m := 0.0:
	set(value):
		texture_x_offset_m = value
		_rebuild()
## Height (meters) of local y=0 above the ground -- the eave line the wall
## texture below this gable was itself rectified against (4.0 for every
## building box in this scene so far).
@export var eave_height_m := 4.0:
	set(value):
		eave_height_m = value
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
	var pts: Array[Vector3] = [
		Vector3(hw, 0.0, 0.0),
		Vector3(outer, 0.0, 0.0),
		Vector3(outer, fascia_height, 0.0),
		Vector3(0.0, rise, 0.0),
		Vector3(-outer, fascia_height, 0.0),
		Vector3(-outer, 0.0, 0.0),
		Vector3(-hw, 0.0, 0.0),
	]

	var has_texture := wall_texture != null and texture_height_m > 0.0
	var tex_width: float = texture_width_m if texture_width_m > 0.0 else width

	# UV per point, matching the elevation-rectifier's own convention: image
	# row 0 (v=0) is the TOP of what it rendered (the ridge, for a gable
	# crop), row max (v=1) is the ground; u=0/1 are the texture's own left/
	# right edges, which may extend past the wall's left/right edges to
	# cover the fascia overhang (texture_x_offset_m/tex_width) -- getting
	# this wrong sends the overhang triangles' UVs outside [0,1], which is
	# exactly what produced the washed-out patches D-57 fixes.
	var uvs: Array[Vector2] = []
	if has_texture:
		for p: Vector3 in pts:
			var real_x: float = p.x + hw
			var real_y: float = eave_height_m + p.y
			uvs.append(Vector2((real_x - texture_x_offset_m) / tex_width, 1.0 - real_y / texture_height_m))

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
		if has_texture: st.set_uv(uvs[0])
		st.add_vertex(pts[0])
		st.set_normal(normal)
		if has_texture: st.set_uv(uvs[i + 1])
		st.add_vertex(pts[i + 1])
		st.set_normal(normal)
		if has_texture: st.set_uv(uvs[i])
		st.add_vertex(pts[i])

	var material := StandardMaterial3D.new()
	if has_texture:
		material.albedo_texture = wall_texture
	else:
		material.albedo_color = WALL_COLOR
	material.roughness = 0.9
	# Belt-and-suspenders alongside the winding fix above: this shape is new,
	# untested-in-render code (unlike gable_end.gd's already-verified
	# triangle), so don't let a residual winding mistake make it disappear
	# from one side again.
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	mesh = st.commit()
	material_override = material
