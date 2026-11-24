extends Node3D
## The water in the irrigation ditch and the pond (D-141).
##
## The weir at the north-east corner lets water into the ditch while it is open
## (look at the weir and press E to open or shut it). The water runs along the
## ditch, through the buried culvert and pipe, and into the pond, which rises
## until it spills, then slowly falls again once the weir is shut. Rain tops up
## the pond and leaves standing water in the ditch. All the maths is in
## water_math.gd; this node steps it each frame, draws it (shaders/water.gdshader)
## and builds the little structures: the weir, and the mouths of the pipes.
##
## Times are real seconds, not game-clock time, so the fill is easy to watch;
## `time_scale` speeds the water up (the sky menu's Water row). It posts a toast
## when the pond becomes full or empty (toast.gd), and swimming birds ask it
## where the water is (wander.gd).

const TerrainMath := preload("res://scripts/terrain_math.gd")
const WaterData := preload("res://scripts/water_data.gd")
const WaterMath := preload("res://scripts/water_math.gd")
const WATER_SHADER := preload("res://shaders/water.gdshader")

## Half the width of the water ribbon along the ditch, wider than the channel so
## the banks always trim it.
const RIBBON_HALF_WIDTH := 1.9
## Spacing of the ribbon's cross-sections along the route.
const RIBBON_STEP := 1.5
## Per weather: [share of the ditch left as standing water, rain as a multiple of a steady rain].
const RAIN := {
	"drizzle": [0.12, 0.5],
	"rain": [0.3, 1.0],
	"downpour": [0.55, 2.5],
	"thunderstorm": [0.55, 2.5],
}
## How quickly standing rain water gathers and dries (seconds).
const POOL_RISE_SECONDS := 25.0
const POOL_FALL_SECONDS := 150.0
const CONCRETE := Color(0.62, 0.61, 0.58)
const STEEL := Color(0.3, 0.34, 0.36)
const WHEEL_RED := Color(0.72, 0.12, 0.1)

## Toast colours: a cool blue for full, an amber for empty.
const FULL_COLOR := Color(0.45, 0.72, 1.0)
const EMPTY_COLOR := Color(1.0, 0.72, 0.35)
## The pond counts as full at this share of its capacity, and is announced
## again only after it has fallen back below FULL_RESET; likewise empty.
const FULL_AT := 0.995
const FULL_RESET := 0.9
const EMPTY_AT := 0.004
const EMPTY_RESET := 0.05
## A bird can swim where the pond is at least this deep, and floats once the
## water is deeper than its ankles.
const SWIM_DEPTH := 0.6

signal weir_changed(open: bool)

## Water runs from the weir into the ditch while this is true.
@export var weir_open := false:
	set(value):
		if value != weir_open:
			weir_open = value
			_move_gate()
			weir_changed.emit(weir_open)
## Seconds for water to run from the weir to the pond.
@export var travel_seconds := 45.0
## Minutes for the weir's full flow to fill an empty pond.
@export var fill_minutes := 4.0
## Minutes for a full pond to dry out by evaporation and seepage with the weir shut.
@export var drain_minutes := 45.0
## Minutes of steady rain that would fill an empty pond.
@export var rain_fill_minutes := 20.0
## How full the pond starts, 0 (empty) to 1 (spilling).
@export_range(0.0, 1.0) var start_pond_fill := 0.0
## Start with the ditch already running full.
@export var start_ditch_full := false
@export var weather_path: NodePath = ^"../Weather"
## How fast the water runs compared with the clock: 1 is normal.
@export_range(0.1, 60.0) var time_scale := 1.0

## How full the ditch is at each station along the route (0 empty .. 1 flowing).
var flow := WaterMath.new_flow()
## Cubic metres in the pond, and the level (m, 0 = the rim's level ground) that makes.
var pond_volume := 0.0
var pond_level := -WaterData.POND_DEPTH
## Standing rain water in the ditch, 0..1 of a full ditch.
var rain_pool := 0.0

var _weather: Node
## Which toast the pond has already given, so a level that hovers near full or
## empty doesn't announce itself over and over.
var _said_full := false
var _said_empty := true
var _pond_surface: MeshInstance3D
var _ditch_surface: MeshInstance3D
var _pond_material: ShaderMaterial
var _ditch_material: ShaderMaterial
var _flow_image: Image
var _flow_texture: ImageTexture
var _flow_active := false
var _gate: Node3D
var _gate_tween: Tween
var _wheel: Node3D

func _ready() -> void:
	add_to_group("water")
	_weather = get_node_or_null(weather_path)
	pond_volume = WaterMath.pond_capacity() * start_pond_fill
	pond_level = WaterMath.pond_level_at(pond_volume)
	# Starting full or empty is not news.
	_said_full = pond_fill_fraction() >= FULL_AT
	_said_empty = pond_fill_fraction() <= EMPTY_AT
	if start_ditch_full:
		flow = WaterMath.new_flow(1.0)
		_flow_active = true
	_build_pond_surface()
	_build_ditch_surface()
	_build_weir()
	_build_pipe_mouths()
	_upload_flow()
	_update_pond_surface()
	if weir_open:
		_move_gate(true)

func _process(delta: float) -> void:
	_step(delta * time_scale)

## Advance the water by `dt` seconds. Public so tests can run time forward.
func _step(dt: float) -> void:
	if weir_open or _flow_active:
		flow = WaterMath.flow_step(flow, weir_open, travel_seconds, dt)
		_flow_active = false
		for i in flow.size():
			if flow[i] < 0.004:
				flow[i] = 0.0
			else:
				_flow_active = true
		_upload_flow()

	var rain := _rain()
	rain_pool = _approach(rain_pool, rain[0], dt, POOL_RISE_SECONDS if rain[0] > rain_pool else POOL_FALL_SECONDS)
	if rain_pool < 0.002 and rain[0] <= 0.0:
		rain_pool = 0.0
	_ditch_material.set_shader_parameter("rain_pool", rain_pool)

	var rain_per_second: float = rain[1] / (maxf(rain_fill_minutes, 0.01) * 60.0)
	pond_volume = WaterMath.pond_step(pond_volume, WaterMath.outflow(flow), 1.0 / (maxf(fill_minutes, 0.01) * 60.0), rain_per_second, 1.0 / (maxf(drain_minutes, 0.01) * 60.0), dt)
	pond_level = WaterMath.pond_level_at(pond_volume)
	_update_pond_surface()
	_announce_pond()

## Post a toast when the pond has just become full or empty.
func _announce_pond() -> void:
	var fill := pond_fill_fraction()
	if not _said_full and fill >= FULL_AT:
		_said_full = true
		_toast("The pond is full", FULL_COLOR)
	elif _said_full and fill < FULL_RESET:
		_said_full = false
	if not _said_empty and fill <= EMPTY_AT:
		_said_empty = true
		_toast("The pond is empty", EMPTY_COLOR)
	elif _said_empty and fill > EMPTY_RESET:
		_said_empty = false

func _toast(text: String, accent: Color) -> void:
	if is_inside_tree():
		get_tree().call_group("toast", "show_toast", text, accent)

## [standing-water share, rain multiple] for the weather right now.
func _rain() -> Array:
	var current: String = _weather.get("current") if _weather else ""
	return RAIN.get(current, [0.0, 0.0])

func _approach(value: float, target: float, dt: float, seconds: float) -> float:
	return lerpf(value, target, 1.0 - exp(-dt / maxf(seconds, 0.001)))

# --- the player-facing parts -------------------------------------------------

func get_interact_prompt() -> String:
	return "Shut the weir" if weir_open else "Open the weir"

func interact(_actor: Node3D) -> void:
	weir_open = not weir_open

## How full the pond is, 0 (empty) to 1 (at its spill level).
func pond_fill_fraction() -> float:
	return pond_volume / maxf(WaterMath.pond_capacity(), 1.0)

## Put the pond at a fill (0..1), e.g. to look at it brim-full.
func set_pond_fill(fraction: float) -> void:
	pond_volume = WaterMath.pond_capacity() * clampf(fraction, 0.0, 1.0)
	pond_level = WaterMath.pond_level_at(pond_volume)
	_update_pond_surface()
	_announce_pond()

## Set the whole ditch running full (or empty) at once.
func set_ditch_full(full: bool) -> void:
	flow = WaterMath.new_flow(1.0 if full else 0.0)
	_flow_active = full
	_upload_flow()

## How deep the pond's water is above its floor at (x, z), 0 where there is none
## (the ditch is left out). Cheap enough for a flock to ask every frame.
func pond_depth_at(x: float, z: float) -> float:
	if TerrainMath.pond_sdf(x, z) >= 0.0:
		return 0.0
	return maxf(0.0, pond_level - TerrainMath.height_at(x, z))

## The pond's surface height at (x, z), or NAN where the pond holds no water there.
func pond_surface_at(x: float, z: float) -> float:
	return pond_level if pond_depth_at(x, z) > 0.0 else NAN

## True once the pond holds enough water for a bird to swim on.
func pond_has_water() -> bool:
	return pond_level > -WaterData.POND_DEPTH + SWIM_DEPTH

## A random point on the pond's open water (deep enough to swim), nearest to
## `from` of a handful tried and within `reach` metres of it; Vector2.INF if
## there is none. Used by swimming birds.
func random_swim_spot(from: Vector2, reach: float) -> Vector2:
	if not pond_has_water():
		return Vector2.INF
	var best := Vector2.INF
	var best_distance := reach
	for i in 30:
		var at := Vector2(
			randf_range(WaterMath.BASIN_MIN.x, WaterMath.BASIN_MAX.x),
			randf_range(WaterMath.BASIN_MIN.y, WaterMath.BASIN_MAX.y))
		var d := from.distance_to(at)
		if d > 2.0 and d < best_distance and pond_depth_at(at.x, at.y) >= SWIM_DEPTH:
			best = at
			best_distance = d
	return best

## The water's surface height at (x, z), or NAN where there is no water: the
## pond's level where the pond holds water, the ditch's where the ditch does.
func water_surface_at(x: float, z: float) -> float:
	var depth := water_depth_at(x, z)
	if depth <= 0.0:
		return NAN
	return TerrainMath.height_at(x, z) + depth

## How deep the water is above the ground at (x, z), 0 on dry ground.
func water_depth_at(x: float, z: float) -> float:
	var ground := TerrainMath.height_at(x, z)
	var depth := 0.0
	if TerrainMath.pond_sdf(x, z) < 0.0:
		depth = maxf(0.0, pond_level - ground)
	var near := WaterMath.nearest_on_route(x, z)
	if near.y < TerrainMath.DITCH_TOP_HALF and not WaterMath.is_buried_at(near.x):
		var surface := -WaterData.DITCH_DEPTH + WaterMath.ditch_depth_at(flow, near.x, rain_pool)
		depth = maxf(depth, surface - ground)
	return depth

# --- drawing ---------------------------------------------------------------

func _water_material(ribbon: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = WATER_SHADER
	material.set_shader_parameter("ribbon", ribbon)
	material.set_shader_parameter("bed_y", -WaterData.DITCH_DEPTH)
	material.set_shader_parameter("ditch_depth_max", WaterMath.ditch_water_depth(1.0))
	material.set_shader_parameter("stations", float(WaterMath.STATIONS))
	material.set_shader_parameter("ripple", 0.5 if ribbon else 1.0)
	return material

func _build_pond_surface() -> void:
	var plane := PlaneMesh.new()
	plane.size = WaterMath.BASIN_MAX - WaterMath.BASIN_MIN
	_pond_surface = MeshInstance3D.new()
	_pond_surface.name = "PondSurface"
	_pond_surface.mesh = plane
	_pond_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pond_material = _water_material(false)
	_pond_surface.material_override = _pond_material
	var centre := (WaterMath.BASIN_MAX + WaterMath.BASIN_MIN) * 0.5
	_pond_surface.position = Vector3(centre.x, pond_level, centre.y)
	add_child(_pond_surface)

func _update_pond_surface() -> void:
	if _pond_surface == null:
		return
	_pond_surface.position.y = pond_level
	# A dry pond has no sheet at all: it would only fight the floor.
	_pond_surface.visible = pond_level > -WaterData.POND_DEPTH + 0.03

func _build_ditch_surface() -> void:
	_flow_image = Image.create(WaterMath.STATIONS, 1, false, Image.FORMAT_R8)
	_flow_texture = ImageTexture.create_from_image(_flow_image)
	_ditch_material = _water_material(true)
	_ditch_material.set_shader_parameter("flow_tex", _flow_texture)
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var length := WaterMath.route_length()
	var count := WaterMath.segment_count()
	var i := 0
	while i < count:
		if WaterMath.is_buried_at(WaterMath.segment_start(i) + 0.01):
			i += 1
			continue
		# One open run: consecutive open segments become one strip.
		var run: Array[Vector3] = []   # (x, z, route distance)
		var j := i
		while j < count and not WaterMath.is_buried_at(WaterMath.segment_start(j) + 0.01):
			var s0 := WaterMath.segment_start(j)
			var s1 := WaterMath.segment_start(j + 1) if j + 1 < count else length
			var steps := maxi(1, ceili((s1 - s0) / RIBBON_STEP))
			for k in steps:
				var s := s0 + (s1 - s0) * float(k) / steps
				var p := WaterMath.point_at(s)
				run.append(Vector3(p.x, p.y, s))
			j += 1
		var end_s := WaterMath.segment_start(j) if j < count else length
		var end := WaterMath.point_at(end_s)
		run.append(Vector3(end.x, end.y, end_s))
		_add_strip(run, length, vertices, uvs, normals, indices)
		i = j
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	# The vertex stage lifts the surface, so the box must reach up to the full-ditch level.
	mesh.custom_aabb = mesh.get_aabb().grow(1.5)
	_ditch_surface = MeshInstance3D.new()
	_ditch_surface.name = "DitchSurface"
	_ditch_surface.mesh = mesh
	_ditch_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ditch_surface.material_override = _ditch_material
	add_child(_ditch_surface)

## A strip of water along `run` ((x, z, route distance) points), mitred at the corners.
func _add_strip(run: Array[Vector3], length: float, vertices: PackedVector3Array, uvs: PackedVector2Array, normals: PackedVector3Array, indices: PackedInt32Array) -> void:
	var base := vertices.size()
	for k in run.size():
		var here := Vector2(run[k].x, run[k].y)
		var before := (here - Vector2(run[k - 1].x, run[k - 1].y)).normalized() if k > 0 else Vector2.ZERO
		var after := (Vector2(run[mini(k + 1, run.size() - 1)].x, run[mini(k + 1, run.size() - 1)].y) - here).normalized() if k < run.size() - 1 else Vector2.ZERO
		var heading := (before + after).normalized() if before != Vector2.ZERO and after != Vector2.ZERO else (before if after == Vector2.ZERO else after)
		var side := Vector2(-heading.y, heading.x)
		# Widen at corners so the strip keeps its width across the bend.
		var corner := 1.0 / maxf(0.5, heading.dot(after) if after != Vector2.ZERO else 1.0)
		var u := run[k].z / maxf(length, 0.001)
		var left := here + side * RIBBON_HALF_WIDTH * corner
		var right := here - side * RIBBON_HALF_WIDTH * corner
		vertices.append(Vector3(left.x, -WaterData.DITCH_DEPTH, left.y))
		vertices.append(Vector3(right.x, -WaterData.DITCH_DEPTH, right.y))
		uvs.append(Vector2(u, 0.0))
		uvs.append(Vector2(u, 1.0))
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
	for k in range(run.size() - 1):
		var a := base + k * 2
		indices.append_array(PackedInt32Array([a, a + 1, a + 2, a + 1, a + 3, a + 2]))

func _upload_flow() -> void:
	if _flow_image == null:
		return
	for i in flow.size():
		_flow_image.set_pixel(i, 0, Color(flow[i], 0.0, 0.0))
	_flow_texture.update(_flow_image)

# --- the structures --------------------------------------------------------

func _concrete_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = CONCRETE
	material.roughness = 0.95
	return material

func _box(size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	return node

## The weir: concrete cheeks either side of the channel, a sill, and a steel
## slide gate that drops across it (closed) or lifts clear (open), worked by a
## hand wheel on the west bank. Looking at any of it offers "Open the weir".
func _build_weir() -> void:
	var weir := Node3D.new()
	weir.name = "Weir"
	add_child(weir)
	var at := Vector3(WaterData.WEIR.x, 0.0, WaterData.WEIR.y)
	var floor_y := -WaterData.DITCH_DEPTH
	var concrete := _concrete_material()
	var steel := StandardMaterial3D.new()
	steel.albedo_color = STEEL
	steel.metallic = 0.6
	steel.roughness = 0.5
	weir.position = at
	# Two cheeks and a sill, one metre apart at the throat.
	weir.add_child(_box(Vector3(0.45, 1.5, 1.0), Vector3(-0.95, floor_y + 0.75, 0.2), concrete))
	weir.add_child(_box(Vector3(0.45, 1.5, 1.0), Vector3(0.95, floor_y + 0.75, 0.2), concrete))
	weir.add_child(_box(Vector3(1.5, 0.25, 1.0), Vector3(0.0, floor_y + 0.12, 0.2), concrete))
	_gate = Node3D.new()
	_gate.name = "Gate"
	_gate.position = Vector3(0.0, floor_y + 0.25, 0.0)
	_gate.add_child(_box(Vector3(1.5, 1.0, 0.1), Vector3(0.0, 0.5, 0.0), steel))
	weir.add_child(_gate)
	# Hand wheel on a post on the west bank, level ground.
	var post_at := Vector3(-1.9, 0.0, 0.0)
	var post := MeshInstance3D.new()
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.07
	post_mesh.bottom_radius = 0.07
	post_mesh.height = 1.1
	post.mesh = post_mesh
	post.material_override = steel
	post.position = post_at + Vector3(0, 0.55, 0)
	weir.add_child(post)
	_wheel = Node3D.new()
	_wheel.position = post_at + Vector3(0, 1.1, 0)
	var rim := MeshInstance3D.new()
	var rim_mesh := TorusMesh.new()
	rim_mesh.inner_radius = 0.16
	rim_mesh.outer_radius = 0.22
	rim.mesh = rim_mesh
	var red := StandardMaterial3D.new()
	red.albedo_color = WHEEL_RED
	rim.material_override = red
	_wheel.add_child(rim)
	weir.add_child(_wheel)
	# Solid, and lit up for the interact ray: the gate and the post stop the player and answer E.
	var body := StaticBody3D.new()
	body.name = "WeirBody"
	var gate_shape := CollisionShape3D.new()
	var gate_box := BoxShape3D.new()
	gate_box.size = Vector3(1.5, 1.3, 0.4)
	gate_shape.shape = gate_box
	gate_shape.position = Vector3(0, floor_y + 0.65, 0.0)
	body.add_child(gate_shape)
	var post_shape := CollisionShape3D.new()
	var post_box := BoxShape3D.new()
	post_box.size = Vector3(0.6, 1.5, 0.6)
	post_shape.shape = post_box
	post_shape.position = post_at + Vector3(0, 0.75, 0)
	body.add_child(post_shape)
	weir.add_child(body)

## Slide the gate: down across the channel when shut, up out of the way when open.
func _move_gate(instant := false) -> void:
	if _gate == null:
		return
	var floor_y := -WaterData.DITCH_DEPTH
	var target := floor_y + (1.55 if weir_open else 0.25)
	if _gate_tween:
		_gate_tween.kill()
	if instant:
		_gate.position.y = target
		return
	_gate_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_gate_tween.tween_property(_gate, "position:y", target, 1.6)
	if _wheel:
		_gate_tween.parallel().tween_property(_wheel, "rotation:y", _wheel.rotation.y + (TAU if weir_open else -TAU), 1.6)

## A concrete ring with a dark opening where each buried run starts or ends: both
## ends of the driveway culvert, the start of the pipe, and where it meets the pond.
func _build_pipe_mouths() -> void:
	var routes := WaterData.ROUTE_SEGMENTS
	var concrete := _concrete_material()
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.02, 0.02, 0.02)
	var mouths: Array = []   # [position (x, z), direction (x, z)]
	var i := 0
	while i < routes.size():
		var a := Vector2(routes[i], routes[i + 1])
		var b := Vector2(routes[i + 2], routes[i + 3])
		var buried: bool = routes[i + 4] > 0.5
		var was_buried: bool = i > 0 and routes[i - 1] > 0.5
		var next_buried: bool = i + 9 < routes.size() and routes[i + 9] > 0.5
		var dir := (b - a).normalized()
		if buried and not was_buried:
			mouths.append([a, dir])
		if buried and not next_buried:
			mouths.append([b, dir])
		i += 5
	for mouth in mouths:
		var at: Vector2 = mouth[0]
		var dir: Vector2 = mouth[1]
		# The pipe that reaches the pond ends on its bank: come in until the ground has fallen away.
		if at.distance_to(Vector2(WaterData.ROUTE_SEGMENTS[WaterData.ROUTE_SEGMENTS.size() - 3], WaterData.ROUTE_SEGMENTS[WaterData.ROUTE_SEGMENTS.size() - 2])) < 0.01:
			var step := 0
			while TerrainMath.height_at(at.x, at.y) > -0.8 and step < 200:
				at -= dir * 0.2
				step += 1
		var ring := Node3D.new()
		# Cylinders stand on Y; turn this one so its axis runs along the pipe.
		var along := Vector3(dir.x, 0.0, dir.y)
		var sideways := along.cross(Vector3.UP).normalized()
		ring.transform = Transform3D(Basis(sideways, along, sideways.cross(along)).orthonormalized(),
			Vector3(at.x, TerrainMath.height_at(at.x, at.y) + 0.4, at.y))
		var outer := CylinderMesh.new()
		outer.top_radius = 0.55
		outer.bottom_radius = 0.55
		outer.height = 0.5
		var outer_node := MeshInstance3D.new()
		outer_node.mesh = outer
		outer_node.material_override = concrete
		ring.add_child(outer_node)
		var hole := CylinderMesh.new()
		hole.top_radius = 0.4
		hole.bottom_radius = 0.4
		hole.height = 0.52
		var hole_node := MeshInstance3D.new()
		hole_node.mesh = hole
		hole_node.material_override = dark
		ring.add_child(hole_node)
		add_child(ring)
