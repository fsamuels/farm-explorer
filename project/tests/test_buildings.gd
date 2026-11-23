extends SceneTree
## Tests for the walk-in Sally's House and Front Barn (D-115): the shells are
## built over the placeholder boxes, doors sit where the photographed doors
## are, and the real player can walk in through an open doorway but not
## through a wall. Run headless from project/:
##   godot --headless -s res://tests/test_buildings.gd

const Shell := preload("res://scripts/building_shell.gd")
const Profile := preload("res://scripts/barn_profile.gd")

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
	_test_math()
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _step(10)
	var player: CharacterBody3D = main.get_node("Player")
	var house: Node3D = main.get_node("Buildings/SallysHouseShell")
	var barn: Node3D = main.get_node("Buildings/FrontBarnShell")
	_test_built(main, house, "Sally's House")
	_test_built(main, barn, "Front Barn")
	await _walk_tests(player, house, "south", "Sally's House south door")
	await _walk_tests(player, house, "east", "Sally's House front door")
	var back: Node3D = main.get_node("Buildings/BackBarnShell")
	_test_built(main, back, "Back Barn")
	_test_back_barn(back)
	await _walk_tests(player, back, "east", "Back Barn east door")
	await _walk_tests(player, back, "west", "Back Barn west door")
	await _open_side_tests(player, barn)
	_facade_tests(main, barn)
	await _interior_tests(main, player)
	print("buildings: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures else 0)

func _test_math() -> void:
	# The barn's cross-section: wing roofs fall outward, the central one peaks in the middle.
	var w := 16.25
	_check(is_equal_approx(Profile.roof_y(0.0, w), Profile.RIDGE), "barn ridge height")
	_check(is_equal_approx(Profile.roof_y(w / 2.0 - Profile.WING_W - 0.0001, w), Profile.EAVE), "central eave at the junction (%s)" % Profile.roof_y(w / 2.0 - Profile.WING_W - 0.0001, w))
	_check(is_equal_approx(Profile.roof_y(w / 2.0 - Profile.WING_W, w), Profile.WING_HIGH), "wing roof is high at the junction")
	_check(is_equal_approx(Profile.roof_y(-w / 2.0, w), Profile.WING_LOW), "wing roof is low at the outer wall")
	_check(is_equal_approx(Profile.roof_y(3.0, w), Profile.roof_y(-3.0, w)), "the roof is symmetric")
	_check(Profile.WING_LOW > Profile.CLEARANCE and Profile.WING_HIGH < Profile.EAVE and Profile.EAVE < Profile.RIDGE, "barn heights are ordered")
	# Left to right seen from outside: south runs +x, north -x, east +z, west -z.
	_check(is_equal_approx(Shell.along_for("south", 0.75, 10.0), 2.5), "south wall: right of centre is +x")
	_check(is_equal_approx(Shell.along_for("north", 0.75, 10.0), -2.5), "north wall: right of centre is -x")
	_check(is_equal_approx(Shell.along_for("east", 0.75, 10.0), 2.5), "east wall: right of centre is +z")
	_check(is_equal_approx(Shell.along_for("west", 0.75, 10.0), -2.5), "west wall: right of centre is -z")
	_check(is_zero_approx(Shell.along_for("south", 0.5, 10.0)), "the middle of a wall is its centre")

func _test_built(main: Node, shell: Node3D, nm: String) -> void:
	var box: Node3D = main.get_node("Buildings/" + shell.building_name)
	_check(not (box.get_node("MeshInstance3D") as Node3D).visible, "%s: placeholder box hidden" % nm)
	_check((box.get_node("CollisionShape3D") as CollisionShape3D).disabled, "%s: placeholder collision off" % nm)
	# Closed shells keep the old bar (liners cut around doors); an open one needs a collider per closed wall.
	var walls: int = 8 if shell.open_walls.is_empty() else 4 - shell.open_walls.size()
	_check(shell.get_node("Walls").get_child_count() >= walls, "%s: walls have collision (%d)" % [nm, shell.get_node("Walls").get_child_count()])
	var door_count := 0
	for c in shell.get_children():
		if c.has_meta("wall"):
			door_count += 1
	_check(door_count == shell.live_doors().size() and (door_count > 0 or not shell.open_walls.is_empty()), "%s: a working door for each entry (%d)" % [nm, door_count])
	_check(shell.front_door_spot(3.0) != null, "%s: the map has a way-in spot" % nm)
	_check(not shell.ceiling or shell.get_node("Ceiling") != null, "%s: has a ceiling" % nm)

## The Back Barn: Shop-style corrugated walls and a big sliding door on each end.
func _test_back_barn(shell: Node3D) -> void:
	var Corr := preload("res://scripts/corrugated.gd")
	_check(shell.corrugated_skin and shell._skin.albedo_texture != null, "Back Barn: corrugated skin")
	_check(shell._skin.albedo_texture == Corr.material().albedo_texture, "Back Barn: same texture as the Shop")
	_check(shell.live_doors().size() == 2, "Back Barn: two doors")
	for wall in ["east", "west"]:
		var door := _door(shell, wall)
		_check(door != null and door.kind == preload("res://scripts/shop_door.gd").Kind.SLIDE, "Back Barn: %s door slides" % wall)
		var spec: Dictionary = Shell.WALLS[wall]
		var out: Vector3 = shell.global_basis * (spec.out as Vector3)
		_check(out.x * (1.0 if wall == "east" else -1.0) > 0.9, "Back Barn: %s door faces world %s (%s)" % [wall, wall, out])
		_check(door.width <= shell.depth - 1.0 and door.height < shell.height, "Back Barn: %s opening fits the wall" % wall)

func _door(shell: Node3D, wall: String) -> Node3D:
	for c in shell.get_children():
		if c.has_meta("wall") and c.get_meta("wall") == wall:
			return c
	return null

## Stand 3 m outside the door, face in and walk: in through the doorway (after
## opening it when it is a slider), and, from 4 m to the side, not through the wall.
func _walk_tests(player: CharacterBody3D, shell: Node3D, wall: String, nm: String) -> void:
	var door := _door(shell, wall)
	_check(door != null, "%s exists" % nm)
	if door == null:
		return
	var spec: Dictionary = Shell.WALLS[wall]
	var out: Vector3 = shell.global_basis * (spec.out as Vector3)
	out.y = 0.0
	out = out.normalized()
	# The doorway's centre on the wall line, from the door's own origin.
	var centre: Vector3 = door.global_position + door.global_basis.x * (float(door.width) / 2.0)
	centre.y = 0.0
	# A closed door is solid: walking at it gets nowhere.
	player.global_position = centre + out * 3.0 + Vector3(0, 0.1, 0)
	player.velocity = Vector3.ZERO
	player.global_basis = Basis.looking_at(-out, Vector3.UP)
	Input.action_press("move_forward")
	await _step(80)
	Input.action_release("move_forward")
	_check(not _inside(shell, player.global_position), "%s: closed, it blocks the player" % nm)
	# Open it and the doorway must be clear.
	door.set_open(true)
	await _step(120)
	# Through the wall first: offset sideways from the door.
	var side := out.cross(Vector3.UP).normalized()
	var wall_start: Vector3 = centre + out * 3.0 + side * (float(door.width) / 2.0 + 2.5)
	var inside_before := _inside(shell, wall_start)
	player.global_position = wall_start + Vector3(0, 0.1, 0)
	player.velocity = Vector3.ZERO
	player.global_basis = Basis.looking_at(-out, Vector3.UP)
	Input.action_press("move_forward")
	await _step(80)
	Input.action_release("move_forward")
	_check(not inside_before and not _inside(shell, player.global_position), "%s: a plain wall stops the player" % nm)
	# Now through the doorway.
	player.global_position = centre + out * 3.0 + Vector3(0, 0.1, 0)
	player.velocity = Vector3.ZERO
	player.global_basis = Basis.looking_at(-out, Vector3.UP)
	Input.action_press("move_forward")
	await _step(80)
	Input.action_release("move_forward")
	_check(_inside(shell, player.global_position), "%s: the player walks in (at %s)" % [nm, player.global_position])
	door.set_open(false)
	await _step(120)

func _walk_local(player: CharacterBody3D, interior: Node3D, from: Vector3, toward: Vector3, frames: int) -> Vector3:
	var start := interior.to_global(from)
	player.global_position = start + Vector3(0, 0.1, 0)
	player.velocity = Vector3.ZERO
	var dir := (interior.to_global(toward) - start)
	dir.y = 0.0
	player.global_basis = Basis.looking_at(dir.normalized(), Vector3.UP)
	Input.action_press("move_forward")
	await _step(frames)
	Input.action_release("move_forward")
	return interior.to_local(player.global_position)

## The pole barn: its south, north and east sides are open (walk straight in
## from each, no door), and the west side is a wall.
func _open_side_tests(player: CharacterBody3D, shell: Node3D) -> void:
	_check(shell.open_walls.size() == 3 and not shell.open_walls.has("west"), "the barn is open on three sides")
	# From 4 m outside the middle of each side, walk in. The north run reaches the
	# aisle and the east run a stall front. The hay pile fills the south end's
	# middle (D-135), so the south run comes in through its open west bay.
	for wall in ["south", "north", "east", "west"]:
		var spec: Dictionary = Shell.WALLS[wall]
		var out: Vector3 = spec.out
		var half: float = shell.depth / 2.0 if spec.along_x else shell.width / 2.0
		var start := out * (half + 4.0)
		var aim := Vector3.ZERO
		if wall == "south":
			start.x = -3.2
			aim = Vector3(-3.2, 0.0, 0.0)
		var at: Vector3 = await _walk_local(player, shell, start, aim, 120)
		var inside: bool = absf(at.x) < shell.width / 2.0 - 0.3 and absf(at.z) < shell.depth / 2.0 - 0.3
		if wall == "west":
			_check(not inside, "the west wall stops the player (at %s)" % at)
		else:
			_check(inside, "the player walks in through the open %s side (at %s)" % [wall, at])

## The north-side photo (D-125): lower wings, a tall middle, siding above the
## open bays, a closed skirted west wing, and a way in on the north side.
func _facade_tests(main: Node, shell: Node3D) -> void:
	var facade: Node3D = main.get_node("Buildings/FrontBarnFacade")
	_check(facade.width == shell.width and facade.depth == shell.depth, "the facade follows the shell's footprint")
	_check(facade.posts.size() >= 10 and facade.posts.size() % 2 == 0, "the same posts on each end (%d)" % facade.posts.size())
	var Interior := preload("res://scripts/barn_interior.gd")
	_check(Interior.new().tack_height + 0.04 < Profile.WING_LOW - 0.12, "the tack room ceiling stays under the wing roof")
	_check(facade.siding_pieces >= 10 and facade.skirt_pieces >= 4, "siding and skirt are built (%d, %d)" % [facade.siding_pieces, facade.skirt_pieces])
	_check(facade.get_node_or_null("RoofMiddle") != null and facade.get_node_or_null("RoofWing_East") != null and facade.get_node_or_null("RoofWing_West") != null, "the roof is three sections")
	_check(absf((Profile.EAVE - Profile.WING_HIGH) - 0.3) < 0.01, "each wing roof stands about a foot below the middle roof's eave")
	_check(((facade.get_node("RoofMiddle") as MeshInstance3D).mesh as ArrayMesh).get_surface_count() == 2, "the middle roof has an east and a west slope")
	# The roofs and walls stay under the ridge: the highest vertex is the ridge.
	var top := 0.0
	for child in facade.get_children():
		if child is MeshInstance3D and child.mesh is ArrayMesh:
			top = maxf(top, (child as MeshInstance3D).get_aabb().end.y)
	_check(absf(top - Profile.RIDGE) < 0.01, "nothing stands above the ridge (%s)" % top)
	_check(shell.wall_height == Profile.WING_LOW, "the west wall is as tall as the wing's outer eave")
	_check(not main.has_node("Buildings/FrontBarn_Gable_North"), "the old tall gable ends are gone")
	# The teleport spot is outside the north end, in the middle.
	var spot: Vector3 = shell.front_door_spot(4.0)
	var local := shell.to_local(spot)
	_check(absf(local.x) < 0.01 and absf(local.z + shell.depth / 2.0 + 4.0) < 0.01, "the barn's front spot is 4 m north of the middle of its north end (%s)" % local)

func _interior_tests(main: Node, player: CharacterBody3D) -> void:
	var interior: Node3D = main.get_node("Buildings/FrontBarnInterior")
	var Interior := preload("res://scripts/barn_interior.gd")
	var centres := Interior.bay_centres(interior.depth - 2.0 * interior.wall_t, 3)
	_check(centres.size() == 3 and is_zero_approx(centres[1]) and is_equal_approx(centres[0], -centres[2]), "three equal bays: %s" % [centres])
	for i in 3:
		_check(absf(interior.to_local(interior.gates[i].global_position).z - (centres[i] + (interior.stall_gate_width + 0.04) / 2.0)) < 0.01, "gate %d sits in its bay" % i)
	_check(interior.gates.size() == 3, "three stall gates (%d)" % interior.gates.size())
	# The stall walls are four spaced boards, open between them (D-128).
	var boards := 0
	for child in interior.get_children():
		if child is MeshInstance3D and (child.mesh as BoxMesh).size.y == interior.BOARD_H:
			boards += 1
	_check(boards >= 4 * 5, "the stall fronts and dividers are runs of boards (%d)" % boards)
	_check(interior.board_count == 4 and 0.2 + 4.0 * interior.BOARD_H < interior.stall_wall_height - 0.3, "four boards leave gaps between them")
	_check(interior.tack_door != null, "a tack room door")
	_check(interior.hay_size.y >= 3.0 * 0.45 and interior.hay_size.y <= 4.0 * 0.45 + 0.01, "the hay pile is 3-4 bales high: %s" % interior.hay_size)
	_check(interior.hay_center.z - interior.hay_size.z / 2.0 >= interior.depth / 6.0 - 0.01, "the hay pile is in the southern third (north edge z %s)" % (interior.hay_center.z - interior.hay_size.z / 2.0))
	_check(interior.hay_step_tiers == PackedInt32Array([1, 2, 3, 4]), "the pile climbs one bale a step")
	var front_x: float = interior.width / 2.0 - interior.wall_t - interior.side_depth
	var tack_front: float = -interior.width / 2.0 + interior.wall_t + interior.side_depth
	# The middle of the barn is clear now: walking through it from the north reaches the pile.
	var north_edge: float = interior.hay_center.z - interior.hay_size.z / 2.0
	var at: Vector3 = await _walk_local(player, interior, Vector3(0, 0, -4.5), Vector3(0, 0, 14.0), 160)
	_check(at.z > 0.0, "the aisle is clear of hay (z %s)" % at.z)
	# The tallest step is solid: walking at it from the north of the pile ends up on it or short of it.
	_check(at.z < interior.hay_center.z + interior.hay_size.z / 2.0, "the pile stops the player at the south wall (z %s)" % at.z)
	_check(north_edge > interior.depth / 6.0 - 0.01, "the pile starts in the southern third")
	# The tack room: a closed door blocks, an open one lets you in.
	var aisle := Vector3(tack_front + 2.0, 0, 0)
	at = await _walk_local(player, interior, aisle, Vector3(-8, 0, 0), 100)
	_check(at.x > tack_front - 0.1, "the closed tack room door blocks (x %s)" % at.x)
	interior.tack_door.set_open(true)
	await _step(80)
	at = await _walk_local(player, interior, aisle, Vector3(-8, 0, 0), 100)
	_check(at.x < tack_front - 0.8, "the player walks into the tack room (x %s)" % at.x)
	interior.tack_door.set_open(false)
	# A stall: the wall beside a gate stops you; through the open gate you get in.
	var c: float = Interior.bay_centres(interior.depth - 2.0 * interior.wall_t, 3)[2]
	at = await _walk_local(player, interior, Vector3(front_x - 2.0, 0, c + 1.0), Vector3(8, 0, c + 1.0), 100)
	_check(at.x < front_x + 0.3, "the stall front stops the player (x %s)" % at.x)
	var gate: Node3D = interior.gates[2]
	gate.set_open(true)
	await _step(80)
	# The open leaf swings into the stall, not out across the aisle.
	var leaf: Vector3 = interior.to_local(gate._shape.global_position)
	_check(leaf.x > front_x + 0.1, "the open gate leaf lies inside the stall (x %s, front %s)" % [leaf.x, front_x])
	at = await _walk_local(player, interior, Vector3(front_x - 2.0, 0, c), Vector3(8, 0, c), 100)
	_check(at.x > front_x + 0.8, "the player walks into the stall through its gate (x %s)" % at.x)
	gate.set_open(false)
	# The south stall is closed at its south end (D-129); the north end stays open.
	at = await _walk_local(player, interior, Vector3(5.1, 0, 8.0), Vector3(5.1, 0, 15.0), 100)
	_check(at.z < interior.depth / 2.0 - 0.3, "the south stall's end wall stops the player (z %s)" % at.z)
	at = await _walk_local(player, interior, Vector3(5.1, 0, -8.0), Vector3(5.1, 0, -15.0), 100)
	_check(at.z < -interior.depth / 2.0 - 0.3, "the north end of the stalls is open (z %s)" % at.z)

func _inside(shell: Node3D, world: Vector3) -> bool:
	var p := shell.to_local(world)
	return absf(p.x) < shell.width / 2.0 - 0.1 and absf(p.z) < shell.depth / 2.0 - 0.1
