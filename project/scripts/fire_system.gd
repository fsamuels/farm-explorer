extends Node3D
## Burning the ditch (D-156). Every spring the irrigation ditch and the strip
## between it and the road are choked with last year's dry bunch grass, and the
## way to clear them for the water is to burn them, south to north, with the
## usual south-west wind. This node is that burn.
##
## The fuel grid and the way fire spreads live in fire_grid.gd (pure, tested).
## This node builds the grid from the real ditch and road, draws the tall dry
## grass and the scorch, and shows the fire: flames, smoke and embers are three
## GPU particle systems that emit from the burning cells, plus a few firelights
## on the busiest clusters. The player's propane torch (key 1 to take it out,
## hold the left mouse button to burn) is built here too, with a propane tank
## by the road to refill it and start the quest.
##
## The quest is "Burn the Ditch": light it, keep it in the strip, then open
## the weir. Fire that gets across the line (the pasture to the west, the field
## beyond the road) costs points, and after a while the fire department puts
## it out. The ditch cannot burn while water runs in it, and rain, snow and
## wet ground stop a fire, so the weir has to be shut and the weather dry.

const FireGrid := preload("res://scripts/fire_grid.gd")
const FireHud := preload("res://scripts/fire_hud.gd")
const FireSound := preload("res://scripts/fire_sound.gd")
const RoadMath := preload("res://scripts/road_math.gd")
const TerrainMath := preload("res://scripts/terrain_math.gd")
const WaterMath := preload("res://scripts/water_math.gd")
const GRASS_SHADER := preload("res://shaders/fire_grass.gdshader")
const CHAR_SHADER := preload("res://shaders/fire_char.gdshader")
const PARTICLE_SHADER := preload("res://shaders/fire_particle.gdshader")

## The patch of ground the fire lives on, in scene metres (+x east, +z south):
## from the ditch's west bank to the field beyond the road, weir to south corner.
const GRID_ORIGIN := Vector2(240.0, -92.0)
const GRID_W := 50
const GRID_H := 166
## Cells within this of a road's centreline are asphalt and shoulder: bare.
const ROAD_CLEAR := 4.4
## The road runs north-south at about this x; the field is east of it.
const ROAD_X := 276.0
## The open ditch's bed and banks, half-width from the centreline.
const DITCH_HALF := 1.6
const DITCH_FUEL := 1.0
const STRIP_FUEL := 0.75
const PASTURE_FUEL := 0.6
const FIELD_FUEL := 0.5
## The west pasture starts this far from the ditch's centreline, with bare
## ground between (the bank and a grazed margin, a natural fire break), and
## counts out to PASTURE_REACH.
const PASTURE_GAP := 3.4
const PASTURE_REACH := 14.0
## The driveway crosses the strip here (z): gravel with a few weeds.
const DRIVEWAY_Z := Vector2(-54.0, -39.5)
const DRIVEWAY_FUEL := 0.2
## The ditch turns west at the south end and runs along here (z); that stretch
## does not burn yet (the hose and rake come first), so it is bare.
const EAST_WEST_Z := Vector2(62.0, 76.0)
## Patches with less fuel than this are bare dirt.
const BARE_BELOW := 0.14
## Where the propane tank stands, by the road at the south end.
const TANK_POS := Vector2(262.0, 62.0)
const TANK_CLEAR := 1.8

## The usual wind: from the south-west, blowing toward the north-east.
const WIND_DIR := Vector2(1.0, -1.0)
## The sim runs in steps of this many seconds.
const TICK := 0.1
const MAX_TICKS_PER_FRAME := 8

## Torch.
const TORCH_REACH := 7.0
const TORCH_RADIUS := 0.8
## Tall grass: a flame this low over the ground catches it.
const GRASS_HEIGHT := 1.0
const TANK_SECONDS := 110.0
## Seconds after fire gets across the line before the fire department arrives.
const DEPT_DELAY := 25.0
const DEPT_PENALTY := 10
## Seconds with nothing burning before the burn counts as finished.
const FINISH_AFTER := 3.0

## How wet each weather leaves the air for burning, 0 dry .. 1 pouring.
const WEATHER_WET := {
	"drizzle": 0.45, "rain": 0.85, "downpour": 1.0, "thunderstorm": 1.0,
	"snow": 0.7, "heavy_snow": 0.9,
}

const MAX_POINTS := 2048
const FLAME_AMOUNT := 2600
const SMOKE_AMOUNT := 1500
const EMBER_AMOUNT := 500
const LIGHT_COUNT := 6
const LIGHT_BIN := 6.0

const FLAME_COLOR := Color(1.0, 0.62, 0.2)
const QUEST_COLOR := Color(1.0, 0.78, 0.35)
const BAD_COLOR := Color(1.0, 0.45, 0.35)
const GOOD_COLOR := Color(0.6, 0.9, 0.5)

enum Quest { IDLE, STARTED, BURNED, DONE }

signal quest_changed(state: int)

@export var weather_path: NodePath = ^"../Weather"
@export var water_path: NodePath = ^"../Water"
@export var player_path: NodePath = ^"../Player"
## How fast the fire runs compared with the clock: 1 is normal.
@export_range(0.1, 20.0) var time_scale := 1.0
## The wind's usual speed, m/s (11 mph), and a multiplier on it (the sky menu).
@export var base_wind_speed := 5.0
@export_range(0.0, 3.0) var wind_scale := 1.0
## Light a stretch of the strip at the start, for looking at the fire.
@export var start_burning := false

var grid: FireGrid
var wind := Vector2.ZERO
var clock := 0.0
var tank_level := 1.0
var torch_equipped := false
var firing := false
var quest := Quest.IDLE
var score := 0
var dept_called := false

var _weather: Node
var _water: Node
var _player: Node
var _head: Node3D
var _accum := 0.0
var _protected_since := -1.0
var _idle_since := -1.0
var _tank_empty_said := false
var _moisture_timer := 0.0
var _hud_timer := 0.0
## A step has changed the fire since the picture was last redrawn.
var _view_stale := false
## Cells of the open ditch bed and how far along the route each is.
var _ditch_cells := PackedInt32Array()
var _ditch_stations := PackedFloat32Array()

var _state_image: Image
var _state_texture: ImageTexture
var _state_bytes := PackedByteArray()
var _grass_material: ShaderMaterial
var _char_material: ShaderMaterial
var _points_image: Image
var _points_texture: ImageTexture
var _flame: GPUParticles3D
var _smoke: GPUParticles3D
var _embers: GPUParticles3D
var _flame_process: ParticleProcessMaterial
var _smoke_process: ParticleProcessMaterial
var _ember_process: ParticleProcessMaterial
var _lights: Array[OmniLight3D] = []
var _light_targets: Array[Vector3] = []
var _light_energy: Array[float] = []
var _torch: Node3D
var _tip: Node3D
var _jet: GPUParticles3D
var _torch_light: OmniLight3D
var _tank_body: StaticBody3D
var _hud: Control
var _hud_layer: CanvasLayer
var _audio: AudioStreamPlayer
var _synth := FireSound.new()
var _playback: AudioStreamGeneratorPlayback
var _roar := 0.0
var _crackle := 0.0
var _noise := FastNoiseLite.new()
## Real frames spent updating the picture, for the tests to read.
var frames_drawn := 0

func _ready() -> void:
	add_to_group("fire")
	_weather = get_node_or_null(weather_path)
	_water = get_node_or_null(water_path)
	_player = get_node_or_null(player_path)
	_noise.seed = 11
	_noise.frequency = 0.16
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_build_grid()
	_build_state_texture()
	_build_grass()
	_build_char()
	_build_particles()
	_build_lights()
	_build_tank()
	_build_hud()
	_build_audio()
	if _player:
		_build_torch()
	if _water and _water.has_signal("weir_changed"):
		_water.weir_changed.connect(_on_weir_changed)
	wind = _current_wind()
	_apply_wind()
	if start_burning:
		light_at(Vector2(258.0, 60.0), 2.0)
	_refresh(true)

# --- the ground ------------------------------------------------------------

## Ground height at (x, z). Only the ditch is carved here: the road-side run
## in a narrow band of x, and the east-west run along the south edge of the
## grid. Everywhere else is level and need not be looked up.
static func ground_height(x: float, z: float) -> float:
	if x > 262.0 or (x < 250.0 and (z < EAST_WEST_Z.x or z > EAST_WEST_Z.y)):
		return 0.0
	return TerrainMath.height_at(x, z)

## What stands at (x, z): {"fuel", "zone", "ditch_s"}. `patch` (-1..1) is a
## smooth noise that makes the fuel patchy. ditch_s is how far along the water
## route the cell is when it is the bed of the open ditch, else -1.
static func classify(x: float, z: float, patch: float) -> Dictionary:
	var out := {"fuel": 0.0, "zone": FireGrid.NONE, "ditch_s": -1.0}
	if x < 253.0 and z > EAST_WEST_Z.x:
		return out
	if not RoadMath.nearest(x, z, ROAD_CLEAR).is_empty():
		return out
	var near := WaterMath.nearest_on_route(x, z)
	var on_route := WaterMath.point_at(near.x)
	var buried := WaterMath.is_buried_at(near.x)
	var fuel := 0.0
	var zone := FireGrid.NONE
	var thick := 0.65 + 0.6 * patch
	if not buried and near.y <= DITCH_HALF:
		fuel = DITCH_FUEL * maxf(thick, 0.7)
		zone = FireGrid.TARGET
		out["ditch_s"] = near.x
	elif x > ROAD_X:
		fuel = FIELD_FUEL * thick
		zone = FireGrid.PROTECTED
	elif x > on_route.x + 0.5:
		fuel = STRIP_FUEL * thick
		zone = FireGrid.TARGET
	elif near.y > PASTURE_GAP and near.y <= PASTURE_REACH:
		fuel = PASTURE_FUEL * thick
		zone = FireGrid.PROTECTED
	if z >= DRIVEWAY_Z.x and z <= DRIVEWAY_Z.y and out["ditch_s"] < 0.0:
		fuel = minf(fuel, DRIVEWAY_FUEL)
	if fuel < BARE_BELOW:
		return out
	out["fuel"] = clampf(fuel, 0.0, 1.0)
	out["zone"] = zone
	return out

func _build_grid() -> void:
	grid = FireGrid.new(GRID_W, GRID_H, GRID_ORIGIN, 1.0, 20261124)
	for i in grid.fuel.size():
		var c := grid.center_of(i)
		var info := classify(c.x, c.y, _noise.get_noise_2d(c.x, c.y))
		var fuel: float = info["fuel"]
		if c.distance_to(TANK_POS) < TANK_CLEAR:
			fuel = 0.0
		grid.set_cell(i, fuel, info["zone"] if fuel > 0.0 else FireGrid.NONE, ground_height(c.x, c.y))
		if info["ditch_s"] >= 0.0 and fuel > 0.0:
			_ditch_cells.append(i)
			_ditch_stations.append(info["ditch_s"])
	grid.count_fuel()

func _build_state_texture() -> void:
	_state_bytes.resize(GRID_W * GRID_H * 4)
	_state_image = Image.create_from_data(GRID_W, GRID_H, false, Image.FORMAT_RGBA8, _state_bytes)
	_state_texture = ImageTexture.create_from_image(_state_image)

func _extent() -> Vector2:
	return Vector2(GRID_W, GRID_H) * grid.cell_size

func _tint_materials(material: ShaderMaterial) -> void:
	material.set_shader_parameter("state_tex", _state_texture)
	material.set_shader_parameter("grid_origin", GRID_ORIGIN)
	material.set_shader_parameter("grid_extent", _extent())

# --- the grass -------------------------------------------------------------

## One clump of tall bunch grass: a fan of tapered, leaning blades about a
## metre high. UV.y runs 0 at the root to 1 at the tip (the shader colours and
## sways by it).
static func clump_mesh() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var rows: Array[float] = [0.0, 0.55, 1.0]
	for b in 11:
		var yaw := rng.randf() * TAU
		var radius := rng.randf_range(0.0, 0.16)
		var base := Vector3(cos(yaw) * radius, 0.0, sin(yaw) * radius)
		var lean_yaw := yaw + rng.randf_range(-0.6, 0.6)
		var lean_dir := Vector3(cos(lean_yaw), 0.0, sin(lean_yaw))
		var h := rng.randf_range(0.7, 1.15)
		var lean := rng.randf_range(0.12, 0.38)
		var half := rng.randf_range(0.012, 0.022)
		var across := Vector3(-lean_dir.z, 0.0, lean_dir.x)
		var normal := (Vector3.UP * 0.9 - lean_dir * 0.3).normalized()
		var first := verts.size()
		for t in rows:
			var centre := base + lean_dir * (lean * t * t) + Vector3(0.0, h * t, 0.0)
			var w: float = half * (1.0 - 0.9 * t)
			verts.append(centre - across * w)
			verts.append(centre + across * w)
			normals.append(normal)
			normals.append(normal)
			uvs.append(Vector2(0.0, t))
			uvs.append(Vector2(1.0, t))
		for r in 2:
			var a := first + r * 2
			indices.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _build_grass() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var transforms: Array[Transform3D] = []
	for i in grid.fuel.size():
		var f := grid.fuel[i]
		if f <= 0.0:
			continue
		var count := 1 + (1 if f > 0.5 else 0) + (1 if f > 0.85 else 0)
		var c := grid.center_of(i)
		for k in count:
			var x := c.x + rng.randf_range(-0.45, 0.45)
			var z := c.y + rng.randf_range(-0.45, 0.45)
			var tall := rng.randf_range(0.85, 1.35) * (0.65 + 0.45 * f)
			var wide := rng.randf_range(0.8, 1.3)
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(wide, tall, wide))
			transforms.append(Transform3D(basis, Vector3(x, ground_height(x, z), z)))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = clump_mesh()
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
	_grass_material = ShaderMaterial.new()
	_grass_material.shader = GRASS_SHADER
	_tint_materials(_grass_material)
	var grass := MultiMeshInstance3D.new()
	grass.name = "Grass"
	grass.multimesh = multimesh
	grass.material_override = _grass_material
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grass.visibility_range_end = 160.0
	add_child(grass)

## The scorch: a skin laid just over the ground on every fuel cell, split into
## 2 x 2 so it follows the ditch's banks.
func _build_char() -> void:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for i in grid.fuel.size():
		if grid.fuel[i] <= 0.0:
			continue
		var corner := grid.center_of(i) - Vector2(0.5, 0.5) * grid.cell_size
		var first := verts.size()
		for iz in 3:
			for ix in 3:
				var x := corner.x + ix * 0.5 * grid.cell_size
				var z := corner.y + iz * 0.5 * grid.cell_size
				verts.append(Vector3(x, ground_height(x, z) + 0.035, z))
				normals.append(Vector3.UP)
		for iz in 2:
			for ix in 2:
				var a := first + iz * 3 + ix
				indices.append_array([a, a + 1, a + 3, a + 1, a + 4, a + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_char_material = ShaderMaterial.new()
	_char_material.shader = CHAR_SHADER
	_tint_materials(_char_material)
	var skin := MeshInstance3D.new()
	skin.name = "Scorch"
	skin.mesh = mesh
	skin.material_override = _char_material
	skin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(skin)

# --- flames, smoke, embers -------------------------------------------------

func _curve_texture(points: Array) -> CurveTexture:
	var curve := Curve.new()
	for p in points:
		curve.add_point(Vector2(p[0], p[1]))
	var tex := CurveTexture.new()
	tex.curve = curve
	return tex

func _particle_material(mode: int, strength := 1.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PARTICLE_SHADER
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("strength", strength)
	return m

func _emitter(node_name: String, amount: int, lifetime: float, process: ParticleProcessMaterial, size: Vector2, offset: float, material: ShaderMaterial) -> GPUParticles3D:
	var quad := QuadMesh.new()
	quad.size = size
	quad.center_offset = Vector3(0.0, offset, 0.0)
	quad.material = material
	var p := GPUParticles3D.new()
	p.name = node_name
	p.amount = amount
	p.lifetime = lifetime
	p.process_material = process
	p.draw_pass_1 = quad
	p.local_coords = false
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(GRID_ORIGIN.x - 30.0, -5.0, GRID_ORIGIN.y - 30.0), Vector3(GRID_W + 60.0, 70.0, GRID_H + 60.0))
	add_child(p)
	return p

func _points_process(v_min: float, v_max: float, s_min: float, s_max: float, scale_curve: Array, spread: float) -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINTS
	m.emission_point_texture = _points_texture
	m.emission_point_count = 1
	m.direction = Vector3.UP
	m.spread = spread
	m.initial_velocity_min = v_min
	m.initial_velocity_max = v_max
	m.scale_min = s_min
	m.scale_max = s_max
	m.scale_curve = _curve_texture(scale_curve)
	m.angle_min = -180.0
	m.angle_max = 180.0
	return m

func _build_particles() -> void:
	_points_image = Image.create(MAX_POINTS, 1, false, Image.FORMAT_RGBF)
	_points_texture = ImageTexture.create_from_image(_points_image)
	_flame_process = _points_process(1.0, 2.6, 0.8, 1.7, [[0.0, 0.65], [0.25, 1.0], [1.0, 0.2]], 14.0)
	_smoke_process = _points_process(0.8, 2.2, 1.6, 3.2, [[0.0, 0.5], [1.0, 1.9]], 20.0)
	_ember_process = _points_process(2.0, 6.0, 0.6, 1.2, [[0.0, 1.0], [1.0, 0.5]], 40.0)
	_flame = _emitter("Flames", FLAME_AMOUNT, 0.9, _flame_process, Vector2(1.0, 1.7), 0.85, _particle_material(0))
	_smoke = _emitter("Smoke", SMOKE_AMOUNT, 7.0, _smoke_process, Vector2(1.0, 1.0), 0.0, _particle_material(1))
	_embers = _emitter("Embers", EMBER_AMOUNT, 2.5, _ember_process, Vector2(0.12, 0.12), 0.0, _particle_material(2))

## Lean the flames, smoke and embers with the wind.
func _apply_wind() -> void:
	_flame_process.gravity = Vector3(wind.x * 0.45, 1.3, wind.y * 0.45)
	_smoke_process.gravity = Vector3(wind.x * 0.8, 0.5, wind.y * 0.8)
	_ember_process.gravity = Vector3(wind.x * 1.1, -0.4, wind.y * 1.1)
	if _grass_material:
		_grass_material.set_shader_parameter("wind", wind)

func _jitter(i: int, k: int) -> Vector2:
	var a := fposmod(sin(float(i * 2 + k) * 12.9898) * 43758.5453, 1.0)
	var b := fposmod(sin(float(i * 2 + k) * 78.233) * 24634.6345, 1.0)
	return Vector2(a - 0.5, b - 0.5) * 0.9

## Write the burning cells' positions into the emitters' point texture; returns
## how many points there are.
func _upload_points() -> int:
	var n := 0
	for i in grid.burning:
		var s := grid.flame_strength(i)
		if s < 0.12:
			continue
		var c := grid.center_of(i)
		for k in (1 if s < 0.5 else 2):
			if n >= MAX_POINTS:
				break
			var j := _jitter(i, k)
			_points_image.set_pixel(n, 0, Color(c.x + j.x, grid.ground[i] + 0.1, c.y + j.y))
			n += 1
	_points_texture.update(_points_image)
	return n

func _update_emitters(points: int) -> void:
	var on := points > 0
	for p in [_flame, _smoke, _embers]:
		p.emitting = on
	if not on:
		return
	var count := maxi(points, 1)
	for process in [_flame_process, _smoke_process, _ember_process]:
		process.emission_point_count = count
	_flame.amount_ratio = clampf(count / 500.0, 0.04, 1.0)
	_smoke.amount_ratio = clampf(count / 900.0, 0.03, 1.0)
	_embers.amount_ratio = clampf(count / 1500.0, 0.02, 1.0) * clampf(wind.length() / 5.0, 0.3, 2.0) * 0.5

# --- firelight -------------------------------------------------------------

func _build_lights() -> void:
	for i in LIGHT_COUNT:
		var light := OmniLight3D.new()
		light.name = "Firelight%d" % i
		light.light_color = Color(1.0, 0.55, 0.2)
		light.omni_range = 16.0
		light.light_energy = 0.0
		light.shadow_enabled = false
		light.visible = false
		add_child(light)
		_lights.append(light)
		_light_targets.append(Vector3.ZERO)
		_light_energy.append(0.0)

## Put the firelights over the busiest clusters of flame nearest the viewer.
func _place_lights(viewer: Vector3) -> void:
	var bins := {}
	for i in grid.burning:
		if grid.flame_strength(i) < 0.15:
			continue
		var c := grid.center_of(i)
		var key := Vector2i(int(floor(c.x / LIGHT_BIN)), int(floor(c.y / LIGHT_BIN)))
		var b: Vector3 = bins.get(key, Vector3.ZERO)
		bins[key] = Vector3(b.x + c.x, b.y + c.y, b.z + 1.0)
	var picked: Array = []
	for key in bins:
		var b: Vector3 = bins[key]
		var centre := Vector2(b.x, b.y) / b.z
		var dist := centre.distance_to(Vector2(viewer.x, viewer.z))
		picked.append([dist - b.z * 0.6, centre, b.z])
	picked.sort_custom(func(a, c): return a[0] < c[0])
	for k in LIGHT_COUNT:
		if k < picked.size():
			var centre: Vector2 = picked[k][1]
			_light_targets[k] = Vector3(centre.x, ground_height(centre.x, centre.y) + 1.4, centre.y)
			_light_energy[k] = clampf(sqrt(picked[k][2]) * 0.9, 0.8, 5.0)
		else:
			_light_energy[k] = 0.0

func _animate_lights(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	for k in LIGHT_COUNT:
		var light := _lights[k]
		var want := _light_energy[k]
		if want > 0.0 and not light.visible:
			light.global_position = _light_targets[k]
			light.visible = true
		if light.visible:
			light.global_position = light.global_position.lerp(_light_targets[k], clampf(delta * 3.0, 0.0, 1.0))
			var flicker := 0.82 + 0.18 * sin(t * 13.0 + k * 2.1) * sin(t * 7.3 + k) + 0.08 * sin(t * 31.0 + k * 5.0)
			light.light_energy = move_toward(light.light_energy, want * flicker, delta * 8.0)
			if want == 0.0 and light.light_energy <= 0.02:
				light.visible = false

# --- the torch and the tank ------------------------------------------------

func _build_torch() -> void:
	_head = _player.get_node_or_null("Head") as Node3D
	if _head == null:
		return
	_torch = Node3D.new()
	_torch.name = "Torch"
	_torch.visible = false
	_torch.position = Vector3(0.26, -0.28, -0.3)
	_head.add_child(_torch)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.5, 0.52, 0.55)
	steel.metallic = 0.7
	steel.roughness = 0.4
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.75, 0.55, 0.2)
	brass.metallic = 0.8
	brass.roughness = 0.35
	var grip := StandardMaterial3D.new()
	grip.albedo_color = Color(0.15, 0.13, 0.12)
	grip.roughness = 0.8
	_torch.add_child(_cylinder(0.018, 0.62, steel, Vector3(0.0, 0.0, -0.31)))
	_torch.add_child(_cylinder(0.03, 0.08, brass, Vector3(0.0, 0.0, -0.66)))
	var handle := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.035, 0.13, 0.04)
	handle.mesh = box
	handle.material_override = grip
	handle.position = Vector3(0.0, -0.07, -0.08)
	_torch.add_child(handle)
	_tip = Node3D.new()
	_tip.name = "Tip"
	_tip.position = Vector3(0.0, 0.0, -0.72)
	_torch.add_child(_tip)
	var jet_process := ParticleProcessMaterial.new()
	jet_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	jet_process.emission_sphere_radius = 0.03
	jet_process.direction = Vector3(0.0, 0.0, -1.0)
	jet_process.spread = 4.0
	jet_process.initial_velocity_min = 9.0
	jet_process.initial_velocity_max = 12.0
	jet_process.gravity = Vector3(0.0, 1.2, 0.0)
	jet_process.scale_min = 0.5
	jet_process.scale_max = 0.9
	jet_process.scale_curve = _curve_texture([[0.0, 0.4], [0.5, 1.0], [1.0, 1.5]])
	var quad := QuadMesh.new()
	quad.size = Vector2(0.7, 1.0)
	quad.center_offset = Vector3(0.0, 0.3, 0.0)
	quad.material = _particle_material(3)
	_jet = GPUParticles3D.new()
	_jet.name = "Jet"
	_jet.amount = 240
	_jet.lifetime = 0.5
	_jet.process_material = jet_process
	_jet.draw_pass_1 = quad
	_jet.local_coords = false
	_jet.emitting = false
	_jet.visibility_aabb = AABB(Vector3(-8, -8, -8), Vector3(16, 16, 16))
	_tip.add_child(_jet)
	_torch_light = OmniLight3D.new()
	_torch_light.light_color = Color(1.0, 0.7, 0.35)
	_torch_light.omni_range = 9.0
	_torch_light.light_energy = 0.0
	_torch_light.position = Vector3(0.0, 0.0, -0.8)
	_tip.add_child(_torch_light)

func _cylinder(radius: float, length: float, material: Material, at: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = length
	m.mesh = c
	m.material_override = material
	m.position = at
	m.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	return m

## The propane tank by the road: look at it and press E to refill the torch
## (and to begin the quest the first time).
func _build_tank() -> void:
	_tank_body = StaticBody3D.new()
	_tank_body.name = "PropaneTank"
	var y := ground_height(TANK_POS.x, TANK_POS.y)
	_tank_body.position = Vector3(TANK_POS.x, y, TANK_POS.y)
	add_child(_tank_body)
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.82, 0.83, 0.8)
	paint.roughness = 0.45
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.2, 0.2, 0.22)
	dark.roughness = 0.6
	var body := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.3
	cyl.bottom_radius = 0.3
	cyl.height = 0.9
	body.mesh = cyl
	body.material_override = paint
	body.position = Vector3(0.0, 0.5, 0.0)
	_tank_body.add_child(body)
	var dome := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	dome.mesh = sphere
	dome.material_override = paint
	dome.position = Vector3(0.0, 0.95, 0.0)
	_tank_body.add_child(dome)
	var collar := MeshInstance3D.new()
	var ring := CylinderMesh.new()
	ring.top_radius = 0.16
	ring.bottom_radius = 0.2
	ring.height = 0.1
	collar.mesh = ring
	collar.material_override = dark
	collar.position = Vector3(0.0, 1.27, 0.0)
	_tank_body.add_child(collar)
	var valve := MeshInstance3D.new()
	var knob := CylinderMesh.new()
	knob.top_radius = 0.05
	knob.bottom_radius = 0.05
	knob.height = 0.14
	valve.mesh = knob
	valve.material_override = dark
	valve.position = Vector3(0.0, 1.38, 0.0)
	_tank_body.add_child(valve)
	var shape := CollisionShape3D.new()
	var cap := CylinderShape3D.new()
	cap.radius = 0.35
	cap.height = 1.4
	shape.shape = cap
	shape.position = Vector3(0.0, 0.7, 0.0)
	_tank_body.add_child(shape)

func get_interact_prompt() -> String:
	return "Start the ditch burn and fill the torch" if quest == Quest.IDLE else "Refill the torch"

func interact(_actor: Node3D) -> void:
	refill()
	if quest == Quest.IDLE:
		_begin_quest()
	else:
		_toast("Torch refilled", FLAME_COLOR)

func refill() -> void:
	tank_level = 1.0
	_tank_empty_said = false

func _can_use_torch() -> bool:
	if _player == null or _torch == null:
		return false
	return _player.get("vehicle") == null and not _player.get("swimming")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("torch") and _can_use_torch():
		torch_equipped = not torch_equipped
		if torch_equipped:
			_toast("Propane torch out: hold the left mouse button to burn", FLAME_COLOR)

func _update_torch(delta: float) -> void:
	if _torch == null:
		return
	if torch_equipped and not _can_use_torch():
		torch_equipped = false
	_torch.visible = torch_equipped
	var want := torch_equipped and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_action_pressed("use_tool") and tank_level > 0.0
	if torch_equipped and tank_level <= 0.0 and Input.is_action_pressed("use_tool") and not _tank_empty_said:
		_tank_empty_said = true
		_toast("The propane is out: refill at the tank by the road", BAD_COLOR)
	firing = want
	_jet.emitting = firing
	_torch_light.light_energy = move_toward(_torch_light.light_energy, 2.2 + sin(Time.get_ticks_msec() * 0.04) * 0.4 if firing else 0.0, delta * 20.0)
	if firing:
		tank_level = maxf(tank_level - delta / TANK_SECONDS, 0.0)
		_torch_ignite()

## Light the grass the torch's flame reaches: walk along the jet and light
## whatever it passes within grass height of the ground, up to the first ground it hits.
func _torch_ignite() -> int:
	if wetness() >= FireGrid.WET_NO_LIGHT:
		return 0
	var tip := _tip.global_position
	var dir := -_head.global_transform.basis.z
	var lit := 0
	var t := 0.3
	while t <= TORCH_REACH:
		var p := tip + dir * t
		var above := p.y - ground_height(p.x, p.z)
		if above < GRASS_HEIGHT:
			lit += grid.ignite_at(p.x, p.z, TORCH_RADIUS)
			if above < 0.4:
				break
		t += 0.5
	return lit

## Light the ground at a world position (the torch does this; so do the tests).
func light_at(at: Vector2, radius := TORCH_RADIUS) -> int:
	return grid.ignite_at(at.x, at.y, radius)

# --- time, weather, water --------------------------------------------------

func _current_wind() -> Vector2:
	return FireGrid.wind_at(clock, WIND_DIR.normalized(), base_wind_speed) * wind_scale

## How wet the air and ground are for burning, 0..1.
func wetness() -> float:
	var w := 0.0
	if _weather:
		w = WEATHER_WET.get(_weather.get("current"), 0.0)
		w = maxf(w, float(_weather.get("surface_wet")) * 0.9)
		w = maxf(w, float(_weather.get("surface_snow")) * 0.9)
	return w

## Wet the ditch bed where the water is running.
func _update_moisture() -> void:
	if _water == null or not "flow" in _water:
		return
	for k in _ditch_cells.size():
		var depth := WaterMath.ditch_depth_at(_water.flow, _ditch_stations[k], _water.rain_pool)
		grid.moisture[_ditch_cells[k]] = clampf(depth / 0.12, 0.0, 1.0)

func _on_weir_changed(open: bool) -> void:
	if open and quest == Quest.BURNED:
		_set_quest(Quest.DONE)
		var clear := grid.target_coverage() >= 0.9
		_toast("Quest complete: the water runs %s" % ("clear" if clear else "through the ditch"), GOOD_COLOR)
		if not clear:
			_toast("Unburnt weeds will slow it", QUEST_COLOR)

func _process(delta: float) -> void:
	var dt := delta * time_scale
	_accum += dt
	var ticks := 0
	while _accum >= TICK and ticks < MAX_TICKS_PER_FRAME:
		_accum -= TICK
		_tick(TICK)
		ticks += 1
	if ticks == MAX_TICKS_PER_FRAME:
		_accum = 0.0
	if _view_stale:
		_view_stale = false
		_refresh(false)
	_update_torch(delta)
	_animate_lights(delta)
	_update_audio()
	_hud_timer += delta
	if _hud_timer >= 0.15:
		_hud_timer = 0.0
		_update_hud()
	frames_drawn += 1

## Advance the fire by one step of `dt` seconds. Public so tests can run time forward.
func _tick(dt: float) -> void:
	clock += dt
	wind = _current_wind()
	_moisture_timer += dt
	if _moisture_timer >= 1.0:
		_moisture_timer = 0.0
		_update_moisture()
	grid.step(dt, wind, wetness())
	_apply_wind()
	_update_rules()
	_view_stale = true

## Run time forward `seconds` of game time without frames (the tests use this).
func step(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		_tick(TICK)
		t += TICK
	_view_stale = false
	_refresh(false)

# --- the picture -----------------------------------------------------------

func _refresh(force: bool) -> void:
	if not (force or grid.dirty or not grid.burning.is_empty()):
		return
	var n := grid.fuel.size()
	for i in n:
		var o := i * 4
		_state_bytes[o] = int(grid.burn_progress(i) * 255.0)
		_state_bytes[o + 1] = int(grid.flame_strength(i) * 255.0)
		_state_bytes[o + 2] = int(grid.fuel[i] * 255.0)
		_state_bytes[o + 3] = 255
	_state_image.set_data(GRID_W, GRID_H, false, Image.FORMAT_RGBA8, _state_bytes)
	_state_texture.update(_state_image)
	grid.dirty = false
	var points := _upload_points()
	_update_emitters(points)
	var viewer := _viewer_position()
	_place_lights(viewer)
	_measure_sound(viewer)
	_update_hud()

func _viewer_position() -> Vector3:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam:
		return cam.global_position
	return _player.global_position if _player is Node3D else Vector3(250.0, 1.5, 0.0)

# --- rules: quest, score, the fire department -------------------------------

func _toast(text: String, accent := QUEST_COLOR) -> void:
	var t := get_tree().get_first_node_in_group("toast") if is_inside_tree() else null
	if t and t.has_method("show_toast"):
		t.show_toast(text, accent)

func _set_quest(state: int) -> void:
	if quest != state:
		quest = state
		quest_changed.emit(state)

func _begin_quest() -> void:
	_set_quest(Quest.STARTED)
	_toast("Quest: Burn the Ditch", QUEST_COLOR)
	_toast("Light the dry grass at the south end; the wind carries it north", FLAME_COLOR)

func burn_score() -> int:
	var s := grid.target_coverage() * 100.0 - float(grid.protected_lit) - (DEPT_PENALTY if dept_called else 0)
	return maxi(int(round(s)), 0)

func _update_rules() -> void:
	if quest == Quest.IDLE and grid.target_lit > 0:
		_begin_quest()
	# Fire across the line.
	if grid.protected_lit > 0 and _protected_since < 0.0:
		_protected_since = clock
		_toast("The fire is across the line!", BAD_COLOR)
	if _protected_since >= 0.0 and not dept_called and clock - _protected_since >= DEPT_DELAY:
		dept_called = true
		grid.extinguish_zone(FireGrid.PROTECTED)
		for i in grid.fuel.size():
			if grid.zone[i] == FireGrid.PROTECTED:
				grid.moisture[i] = 1.0
		_toast("The fire department puts it out: -%d points" % DEPT_PENALTY, BAD_COLOR)
	# The burn is over once nothing has been alight for a few seconds.
	if grid.burning.is_empty() and grid.target_lit > 0:
		if _idle_since < 0.0:
			_idle_since = clock
		if clock - _idle_since >= FINISH_AFTER and quest == Quest.STARTED:
			_set_quest(Quest.BURNED)
			score = burn_score()
			_toast("The burn is finished: %d%% of the ditch and strip, score %d" % [int(round(grid.target_coverage() * 100.0)), score], GOOD_COLOR)
			if _water != null and _water.get("weir_open"):
				# Already open (the ditch burned where the water had not reached).
				_on_weir_changed(true)
			else:
				_toast("Now open the weir at the north end", QUEST_COLOR)
	else:
		_idle_since = -1.0
		if quest == Quest.BURNED:
			_set_quest(Quest.STARTED)

## Let the grass grow back and start over (the sky menu's button).
func regrow() -> void:
	grid.regrow()
	for i in grid.fuel.size():
		if grid.zone[i] == FireGrid.PROTECTED:
			grid.moisture[i] = 0.0
	_update_moisture()
	dept_called = false
	_protected_since = -1.0
	_idle_since = -1.0
	score = 0
	_set_quest(Quest.IDLE)
	_refresh(true)

# --- HUD -------------------------------------------------------------------

func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "FireHudLayer"
	_hud_layer.layer = 4
	add_child(_hud_layer)
	_hud = FireHud.new()
	_hud.visible = false
	_hud_layer.add_child(_hud)

func quest_line() -> Array:
	match quest:
		Quest.STARTED:
			return ["Quest: Burn the Ditch", "Burned %d%% of the ditch and strip.%s" % [int(round(grid.target_coverage() * 100.0)), "" if grid.protected_lit == 0 else " Escaped: %d m²." % grid.protected_lit]]
		Quest.BURNED:
			return ["Quest: Burn the Ditch", "Burn finished: %d%%, score %d. Open the weir at the north end." % [int(round(grid.target_coverage() * 100.0)), score]]
		Quest.DONE:
			return ["Quest complete", "Burn score %d. The water is running." % score]
	return ["Propane torch", "Hold the left mouse button to burn. Press E at the tank to start the quest."]

func _update_hud() -> void:
	if _hud == null:
		return
	var in_car: bool = _player != null and _player.get("vehicle") != null
	var show := not in_car and (torch_equipped or not grid.burning.is_empty() or quest != Quest.IDLE)
	_hud.visible = show
	if not show:
		return
	var cam := get_viewport().get_camera_3d()
	var right := Vector2(1.0, 0.0)
	var forward := Vector2(0.0, -1.0)
	if cam:
		right = Vector2(cam.global_transform.basis.x.x, cam.global_transform.basis.x.z).normalized()
		forward = Vector2(-cam.global_transform.basis.z.x, -cam.global_transform.basis.z.z).normalized()
	var text := quest_line()
	_hud.show_state({
		"wind": wind, "view_right": right, "view_forward": forward,
		"tank": tank_level, "show_tank": torch_equipped,
		"title": text[0], "line": text[1],
	})

# --- sound -----------------------------------------------------------------

func _build_audio() -> void:
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = FireSound.MIX_RATE
	stream.buffer_length = 0.2
	_audio = AudioStreamPlayer.new()
	_audio.name = "FireSound"
	_audio.stream = stream
	_audio.volume_db = -4.0
	add_child(_audio)

## How loud the fire is from where the viewer stands.
func _measure_sound(viewer: Vector3) -> void:
	var sum := 0.0
	var here := Vector2(viewer.x, viewer.z)
	for i in grid.burning:
		var d := grid.center_of(i).distance_to(here)
		sum += grid.flame_strength(i) / (1.0 + d * d / 100.0)
	_roar = clampf(sum / 40.0, 0.0, 1.0)
	_crackle = clampf(sum / 25.0, 0.0, 1.0)

func _update_audio() -> void:
	var hiss := 1.0 if firing else 0.0
	var loud := _roar > 0.01 or _crackle > 0.01 or firing
	if not loud:
		if _audio.playing:
			_audio.stop()
			_playback = null
		return
	if not _audio.playing:
		_audio.play()
		_playback = _audio.get_stream_playback() as AudioStreamGeneratorPlayback
	if _playback:
		var frames := mini(_playback.get_frames_available(), 2048)
		if frames > 0:
			_playback.push_buffer(_synth.render(frames, _roar, _crackle, hiss))
