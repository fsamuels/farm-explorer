extends SceneTree
## Tests for the House's front door, the trap door in the House Garage and the
## bomb shelter under them (D-145, D-186, D-188): the layout numbers hang
## together, the ground has a hole only at the stairs, and the real player can
## walk in the front door, stand on the closed trap door, go down the stairs,
## along the tunnel, through the blast door into every room, and back up. Run headless from project/:
##   godot --headless -s res://tests/test_bunker.gd

const Bunker := preload("res://scripts/bunker.gd")
const Shell := preload("res://scripts/building_shell.gd")
const TerrainMath := preload("res://scripts/terrain_math.gd")
const WaterData := preload("res://scripts/water_data.gd")

var _failures := 0

func _init() -> void:
	_run.call_deferred()

func _check(cond: bool, what: String) -> void:
	if not cond:
		_failures += 1
		push_error("FAIL: " + what)

func _step(n: int) -> void:
	for i in n:
		await physics_frame

func _run() -> void:
	_test_layout()
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _step(10)
	var player: CharacterBody3D = main.get_node("Player")
	var shell: Node3D = main.get_node("Buildings/HouseShell")
	var bunker: Node3D = main.get_node("Buildings/HouseBunker")
	var garage: Node3D = main.get_node("Buildings/GarageShell")
	_test_built(main, shell, garage, bunker)
	_test_ground(main, shell, bunker)
	await _test_front_door(player, shell)
	await _test_trap_door(player, bunker)
	await _test_rooms(player, bunker)
	await _test_back_up(player, bunker)
	print("bunker: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures else 0)

## Pure numbers: walkable stairs, headroom under the floor past the hatch, the
## shelter clear of the ditch and pond and above the old ground's safety box.
func _test_layout() -> void:
	var angle := rad_to_deg(atan(Bunker.rise() / Bunker.tread()))
	_check(angle < 40.0 and angle > 30.0, "stairs are steep but walkable: %.1f degrees" % angle)
	_check(Bunker.rise() > 0.15 and Bunker.rise() < 0.22, "risers are step sized: %.3f" % Bunker.rise())
	# Where the hatch ends the floor is overhead again: the player's 1.8 m
	# capsule (0.4 m radius) must pass under it while riding the ramp, where it
	# sits about 0.1 m higher than on the level, with its front 0.4 m ahead.
	var slope := Bunker.ramp_slope()
	_check(rad_to_deg(atan(slope)) < 42.0, "the walking ramp is under the player's 45 degree limit")
	var ride := 0.4 / cos(atan(slope)) - 0.4
	var feet := Bunker.HOUSE_FLOOR - (Bunker.HATCH_LEN - 0.4) * slope + ride
	_check(feet + 1.4 < -0.3, "headroom where the hatch ends (capsule front at %.2f)" % (feet + 1.4))
	_check(Bunker.FLOOR_Y - 0.2 > -WaterData.POND_DEPTH - 2.0 + 0.5, "the shelter's floor is above the old ground's safety box")
	# The stairs fit their stairwell and land before its south wall.
	var s: Rect2 = Bunker.ROOMS.stairwell
	_check(is_equal_approx(s.position.x + Bunker.WALL_T, Bunker.STAIR_X0) and is_equal_approx(s.end.x - Bunker.WALL_T, Bunker.STAIR_X0 + Bunker.STAIR_W), "stairs fill the stairwell's width")
	_check(Bunker.STAIR_Z0 + Bunker.STAIR_RUN <= s.end.y - Bunker.WALL_T + 0.001, "stairs end inside the stairwell")
	# Rooms do not overlap one another.
	var names: Array = Bunker.ROOMS.keys()
	for i in names.size():
		for j in range(i + 1, names.size()):
			var a: Rect2 = Bunker.ROOMS[names[i]]
			var b: Rect2 = Bunker.ROOMS[names[j]]
			_check(not a.grow(-0.01).intersects(b.grow(-0.01)), "rooms %s and %s do not overlap" % [names[i], names[j]])

## The rooms behind doors (not the stairwell, corridor or the tunnel to it).
func _rooms() -> Array:
	return Bunker.ROOMS.keys().filter(func(k): return not k in ["stairwell", "corridor", "tunnel", "passage"])

func _test_built(main: Node, shell: Node3D, garage: Node3D, bunker: Node3D) -> void:
	var box: Node3D = main.get_node("Buildings/House")
	_check(not (box.get_node("MeshInstance3D") as Node3D).visible, "House: placeholder box hidden")
	_check((box.get_node("CollisionShape3D") as CollisionShape3D).disabled, "House: placeholder collision off")
	_check(shell.get_node("Ceiling") != null, "House: has a ceiling")
	_check(shell.front_door_spot(3.0) != null, "House: the map has a way in")
	_check(bunker.global_transform.is_equal_approx(garage.global_transform), "shelter and garage share a frame")
	# The hatch and the stairwell sit inside the garage's walls.
	var g_inner := Rect2(-garage.width / 2.0 + Shell.WALL_T, -garage.depth / 2.0 + Shell.WALL_T, garage.width - 2 * Shell.WALL_T, garage.depth - 2 * Shell.WALL_T)
	_check(g_inner.encloses(bunker.hatch_rect().grow(0.5)), "the hatch is inside the garage with room to stand round it")
	_check(g_inner.encloses(Bunker.ROOMS.stairwell), "the stairwell is under the garage")
	# The garage's way in from the House's pantry is clear of the hatch.
	var opening: Vector3 = Vector3.ZERO
	for d: Dictionary in garage.doors:
		if not d.get("leaf", true):
			opening = Vector3(float(d.along), 0, garage.depth / 2.0)
	_check(opening != Vector3.ZERO, "the garage has an opening from the pantry")
	_check(not bunker.hatch_rect().grow(0.8).has_point(Vector2(opening.x, opening.z - 0.8)), "the pantry's way in is clear of the hatch")
	var inner := Rect2(-shell.width / 2.0 + Shell.WALL_T, -shell.depth / 2.0 + Shell.WALL_T, shell.width - 2 * Shell.WALL_T, shell.depth - 2 * Shell.WALL_T)
	# The shelter has 6-10 rooms off its corridor, each with a door, and the
	# bunk room is not the mess hall's neighbour (D-186).
	var rooms := _rooms()
	_check(rooms.size() >= 6 and rooms.size() <= 10, "6 to 10 rooms (%d)" % rooms.size())
	for room in rooms:
		_check(bunker.doors().has(room), "%s has a door" % room)
		_check(bunker.find_child("Sign_" + room, false, false) != null, "%s has a name plate" % room)
	var bunks: Rect2 = Bunker.ROOMS.bunks
	var mess: Rect2 = Bunker.ROOMS.mess
	_check(not bunks.grow(0.01).intersects(mess), "the bunks and the mess hall do not share a wall")
	_check(garage.floor_holes().size() == 1, "the garage's floor is cut for the hatch")
	_check(shell.floor_holes().is_empty(), "the House's floor has no hatch any more")
	var leaves := Bunker.DOORS.filter(func(d): return not d.get("open", false)).size()
	_check(bunker.doors().size() == leaves, "a door for every doorway (%d)" % bunker.doors().size())
	_check(bunker.trap_door != null and not bunker.trap_door.is_open, "the trap door starts closed")
	# The garage and south wing no longer push into the white room.
	for other in ["House Garage", "House South Wing"]:
		var o: Node3D = main.get_node("Buildings/" + other)
		for sx in [-0.5, 0.5]:
			for sz in [-0.5, 0.5]:
				var p := shell.to_local(o.global_transform * Vector3(sx, 0, sz))
				_check(not inner.grow(-0.005).has_point(Vector2(p.x, p.z)), "%s corner %s is not inside the House's room" % [other, Vector2(p.x, p.z)])

## The ground has a hole at the hatch and nowhere else nearby, and none of the
## shelter is under carved ground.
func _test_ground(main: Node, shell: Node3D, bunker: Node3D) -> void:
	var terrain: Node = main.get_node("Terrain")
	_check(terrain.stats.get("hole_tiles", 0) > 0, "the terrain was told about the hole")
	var space := root.get_world_3d().direct_space_state
	var hatch: Rect2 = bunker.hatch_rect()
	var at_hatch := bunker.to_global(Vector3(hatch.get_center().x, 0.0, hatch.get_center().y))
	_check(not _hits_terrain(space, terrain, at_hatch), "no ground under the hatch")
	var beside := bunker.to_global(Vector3(hatch.get_center().x - 2.0, 0.0, hatch.get_center().y))
	_check(_hits_terrain(space, terrain, beside), "ground 2 m beside the hatch")
	var outside := shell.front_door_spot(3.0) as Vector3
	_check(_hits_terrain(space, terrain, outside), "ground outside the front door")
	var holes: PackedFloat32Array = bunker.terrain_holes()
	_check(TerrainMath.in_hole(at_hatch.x, at_hatch.z, holes) and not TerrainMath.in_hole(beside.x, beside.z, holes), "in_hole agrees")
	var fp := Bunker.footprint()
	for i in 11:
		for j in 11:
			var w := bunker.to_global(Vector3(lerpf(fp.position.x, fp.end.x, i / 10.0), 0.0, lerpf(fp.position.y, fp.end.y, j / 10.0)))
			if TerrainMath.height_at(w.x, w.z) != 0.0:
				_check(false, "the shelter is under level ground (not at %s)" % w)
				return

func _hits_terrain(space: PhysicsDirectSpaceState3D, terrain: Node, at: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 0.5, 0), at + Vector3(0, -0.5, 0))
	var excluded: Array[RID] = []
	for _i in 6:
		q.exclude = excluded
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return false
		if hit.collider == terrain:
			return true
		excluded.append(hit.rid)
	return false

func _walk(player: CharacterBody3D, frame: Node3D, from: Vector3, toward: Vector3, frames: int) -> Vector3:
	var start := frame.to_global(from)
	player.global_position = start + Vector3(0, 0.1, 0)
	player.velocity = Vector3.ZERO
	var dir := frame.to_global(toward) - start
	dir.y = 0.0
	player.global_basis = Basis.looking_at(dir.normalized(), Vector3.UP)
	Input.action_press("move_forward")
	await _step(frames)
	Input.action_release("move_forward")
	await _step(5)
	return frame.to_local(player.global_position)

func _in_room(bunker: Node3D, room: String, p: Vector3) -> bool:
	var r: Rect2 = Bunker.ROOMS[room]
	return r.grow(-0.05).has_point(Vector2(p.x, p.z)) and absf(p.y - Bunker.FLOOR_Y) < 0.3

## The front door: shut it blocks, open it lets you into the white room.
func _test_front_door(player: CharacterBody3D, shell: Node3D) -> void:
	var door: Node3D = null
	for c in shell.get_children():
		if c.has_meta("wall") and c.get_meta("wall") == "east":
			door = c
	_check(door != null, "House: a front door on the east wall")
	if door == null:
		return
	var centre := shell.to_local(door.global_position + door.global_basis.x * (float(door.width) / 2.0))
	var outside := Vector3(shell.width / 2.0 + 3.0, 0.0, centre.z)
	var inside := Vector3(0.0, 0.0, centre.z)
	var p := await _walk(player, shell, outside, inside, 80)
	_check(p.x > shell.width / 2.0, "House: the closed front door blocks (x %.2f)" % p.x)
	door.set_open(true)
	await _step(60)
	p = await _walk(player, shell, outside, inside, 90)
	_check(absf(p.x) < shell.width / 2.0 - 0.3 and absf(p.z) < shell.depth / 2.0 and p.y > 0.0 and p.y < 0.3, "House: in through the front door onto the floor (at %s)" % p)

## Stand on the closed trap door; open it and walk down to the blast door.
func _test_trap_door(player: CharacterBody3D, bunker: Node3D) -> void:
	var hatch: Rect2 = bunker.hatch_rect()
	var mid := Vector3(hatch.get_center().x, 0.05, hatch.get_center().y)
	player.global_position = bunker.to_global(mid + Vector3(0, 0.1, 0))
	player.velocity = Vector3.ZERO
	await _step(40)
	var p := bunker.to_local(player.global_position)
	_check(absf(p.y - 0.05) < 0.1, "the closed trap door holds the player up (y %.2f)" % p.y)
	_check(bunker.trap_door.get_interact_prompt() == "Open trap door", "trap door prompt")
	bunker.trap_door.interact(player)
	await _step(80)
	_check(bunker.trap_door.is_open and bunker.trap_door.get_interact_prompt() == "Close trap door", "the trap door opens")
	# Walk from the north end of the hatch down the stairs into the tunnel,
	# east along it and south down the passage: the closed blast door stops you.
	var x := hatch.get_center().x
	var t: Rect2 = Bunker.ROOMS.tunnel
	var pas: Rect2 = Bunker.ROOMS.passage
	var top := Vector3(x, 0.05, hatch.position.y - 0.6)
	p = await _walk(player, bunker, top, Vector3(x, Bunker.FLOOR_Y, t.get_center().y), 170)
	_check(absf(p.y - Bunker.FLOOR_Y) < 0.3, "down the stairs to the shelter floor (y %.2f)" % p.y)
	_check(_in_room(bunker, "tunnel", p), "on into the tunnel (at %s)" % p)
	p = await _walk(player, bunker, Vector3(x, Bunker.FLOOR_Y, t.get_center().y), Vector3(pas.get_center().x, Bunker.FLOOR_Y, t.get_center().y), 90)
	_check(_in_room(bunker, "tunnel", p) and p.x > pas.position.x, "along the tunnel to its east end (at %s)" % p)
	var start := Vector3(pas.get_center().x, Bunker.FLOOR_Y, t.get_center().y)
	p = await _walk(player, bunker, start, Vector3(start.x, Bunker.FLOOR_Y, Bunker.ROOMS.corridor.end.y), 110)
	_check(_in_room(bunker, "passage", p) and p.z > pas.end.y - 1.0, "the closed blast door stops you at the end of the passage (at %s)" % p)

func _test_rooms(player: CharacterBody3D, bunker: Node3D) -> void:
	var doors: Dictionary = bunker.doors()
	var hatch: Rect2 = bunker.hatch_rect()
	var x := hatch.get_center().x
	var pas: Rect2 = Bunker.ROOMS.passage
	var foot := Vector3(pas.get_center().x, Bunker.FLOOR_Y, pas.end.y - 0.7)
	var corridor: Rect2 = Bunker.ROOMS.corridor
	doors.corridor.set_open(true)
	await _step(120)
	var p := await _walk(player, bunker, foot, Vector3(foot.x, Bunker.FLOOR_Y, corridor.get_center().y), 50)
	_check(_in_room(bunker, "corridor", p), "through the blast door into the corridor (at %s)" % p)
	for room in _rooms():
		var d: Dictionary = {}
		for entry: Dictionary in Bunker.DOORS:
			if entry.room == room:
				d = entry
		var r: Rect2 = Bunker.ROOMS[room]
		var from := Vector3(float(d.x), Bunker.FLOOR_Y, corridor.get_center().y)
		var into := Vector3(float(d.x), Bunker.FLOOR_Y, r.get_center().y)
		# Shut, the door keeps you in the corridor; open, you walk in.
		p = await _walk(player, bunker, from, into, 60)
		_check(_in_room(bunker, "corridor", p), "%s: the closed door blocks (at %s)" % [room, p])
		doors[room].set_open(true)
		await _step(60)
		p = await _walk(player, bunker, from, into, 60)
		_check(_in_room(bunker, room, p), "%s: walk in through the open door (at %s)" % [room, p])
		# A plain wall 1.5 m along from the door stops you.
		var wall_from := from + Vector3(_wall_offset(d), 0, 0)
		p = await _walk(player, bunker, wall_from, wall_from + (into - from), 60)
		_check(_in_room(bunker, "corridor", p), "%s: the wall beside the door blocks (at %s)" % [room, p])

## From the passage, back along the tunnel and up the stairs into the garage.
func _test_back_up(player: CharacterBody3D, bunker: Node3D) -> void:
	var hatch: Rect2 = bunker.hatch_rect()
	var x := hatch.get_center().x
	var t: Rect2 = Bunker.ROOMS.tunnel
	var pas: Rect2 = Bunker.ROOMS.passage
	var mid := Vector3(pas.get_center().x, Bunker.FLOOR_Y, t.get_center().y)
	var p := await _walk(player, bunker, Vector3(mid.x, Bunker.FLOOR_Y, pas.get_center().y), mid, 60)
	_check(_in_room(bunker, "tunnel", p), "back up the passage into the tunnel (at %s)" % p)
	p = await _walk(player, bunker, mid, Vector3(x, Bunker.FLOOR_Y, t.get_center().y), 90)
	_check(_in_room(bunker, "tunnel", p) and p.x < pas.position.x, "back along the tunnel (at %s)" % p)
	p = await _walk(player, bunker, Vector3(x, Bunker.FLOOR_Y, t.get_center().y), Vector3(x, 0.0, -20.0), 200)
	_check(p.y > 0.0 and p.y < 0.3 and p.z < hatch.position.y, "back up the stairs into the garage (at %s)" % p)
	bunker.trap_door.set_open(false)
	await _step(80)
	_check(not bunker.trap_door.is_open, "the trap door closes")

## How far along the corridor from door `d` there is plain wall on its side:
## 1.6 m one way or the other, clear of other doors and inside the corridor.
func _wall_offset(d: Dictionary) -> float:
	var c: Rect2 = Bunker.inner("corridor")
	for off: float in [1.6, -1.6]:
		var x := float(d.x) + off
		if x < c.position.x + 0.5 or x > c.end.x - 0.5:
			continue
		var clear := true
		for other: Dictionary in Bunker.DOORS:
			if other != d and absf(float(other.z) - float(d.z)) < 0.01 and absf(float(other.x) - x) < 1.1:
				clear = false
		if clear:
			return off
	return 1.6
