extends SceneTree
## Tests for the House's back yard (D-170): the lap siding, the deck and its
## steps, the concrete pad, and the two patio sliders, which the real player
## walks up to, through and back out of. Run headless from project/:
##   godot --headless -s res://tests/test_house_backyard.gd

const Backyard := preload("res://scripts/house_backyard.gd")
const Siding := preload("res://scripts/siding.gd")
const Shell := preload("res://scripts/building_shell.gd")

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
	_test_pure()
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _step(10)
	var player: CharacterBody3D = main.get_node("Player")
	var shell: Node3D = main.get_node("Buildings/HouseShell")
	var wing: Node3D = main.get_node("Buildings/WingShell")
	var yard: Node3D = main.get_node("Buildings/HouseBackyard")
	_test_built(main, shell, wing, yard)
	await _test_deck_height(yard)
	_test_teleport(main, player, shell)
	_test_trees(main, shell, yard)
	await _test_trunk_blocks(player, yard)
	await _test_slider(player, shell, "west", Vector3.LEFT, "House")
	await _test_slider(player, wing, "north", Vector3.FORWARD, "Wing")
	print("house backyard: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures else 0)

func _test_pure() -> void:
	# Siding: a dark lap line at the bottom of each board, lighter boards.
	_check(Siding.board_shade(0.97) < Siding.board_shade(0.5) - 0.2, "siding has a shadow line under each lap")
	_check(Siding.board_shade(0.9) > Siding.board_shade(0.2), "each board is lighter toward its bottom edge")
	var img := Siding.image()
	_check(img.get_width() == Siding.SIZE and img.has_mipmaps(), "siding image is a mipmapped tile")
	_check(is_equal_approx(Siding.TILE, 0.8), "four 8 inch boards a tile")
	# Deck: three risers, walkable slope over the steps.
	_check(is_equal_approx(Backyard.TOP, 0.36), "deck top is 0.36 m")
	var slope := rad_to_deg(atan(Backyard.TOP / ((Backyard.STEPS + 1) * Backyard.TREAD)))
	_check(slope < 30.0, "the hull over the steps is gentle: %.1f degrees" % slope)
	var wall := -5.67
	_check(is_equal_approx(Backyard.height_at(wall - 1.0, 0.0, wall), Backyard.TOP), "on the deck in front of the slider")
	_check(is_equal_approx(Backyard.height_at(wall - Backyard.REACH - 0.2, Backyard.CORNER_Z - 0.1, wall), Backyard.TOP - Backyard.RISE), "first step past the deck edge by the Wing")
	_check(Backyard.height_at(wall - 10.0, 0.0, wall) == 0.0, "lawn beyond the steps")
	_check(Backyard.height_at(wall + 1.0, 0.0, wall) == 0.0, "nothing inside the House")
	_check(Backyard.height_at(wall - 1.0, Backyard.CORNER_Z + 0.1, wall) == 0.0, "no deck inside the Wing")
	var bottom: Rect2 = Backyard.levels(wall)[Backyard.STEPS][0]
	_check(is_equal_approx(bottom.position.x, wall - Backyard.PAD_REACH + Backyard.INSET), "the bottom step stops 0.45 m inside the concrete's edge")
	_check(Backyard.height_at(wall - Backyard.PAD_REACH + 0.2, 0.0, wall) == 0.0, "bare concrete between the steps and the pad's edge")
	_check(is_equal_approx(Backyard.height_at(wall - 1.0, Backyard.CORNER_Z - Backyard.RUN - 0.5, wall), Backyard.TOP - 2.0 * Backyard.RISE), "steps on the north end")
	# Rectangular: every level is made of axis-aligned rectangles that touch the wall.
	var top: Array = Backyard.levels(wall)[0]
	_check(top.size() == 1 and is_equal_approx((top[0] as Rect2).end.x, wall), "the deck is one rectangle against the west wall")
	# The pad runs from the garage to the Wing under the deck, flush with the Wing's end.
	var pad: Rect2 = Backyard.pad_rects(wall)[0]
	_check(is_equal_approx(pad.position.x, wall - Backyard.PAD_REACH) and is_equal_approx(pad.end.x, wall), "pad flush with the Wing's west end, up to the wall")
	_check(is_equal_approx(pad.end.y, Backyard.CORNER_Z) and is_equal_approx(pad.position.y, Backyard.GARAGE_SOUTH), "pad runs from the garage to the Wing")
	_check(pad.encloses(Backyard.levels(wall)[Backyard.STEPS][0]), "the deck and its steps sit on the pad")

func _test_built(main: Node, shell: Node3D, wing: Node3D, yard: Node3D) -> void:
	_check(yard.global_transform.is_equal_approx(shell.global_transform), "back yard builds in the House's frame")
	_check(is_equal_approx(yard.wall_x, -shell.width / 2.0), "back yard knows where the west wall is")
	_check(shell._skin == Siding.material() and wing._skin == Siding.material(), "House and Wing walls wear the siding")
	var garage := main.get_node("Buildings/House Garage/MeshInstance3D") as MeshInstance3D
	_check(garage.material_override == Siding.material(), "the garage wears the siding")
	for g in Backyard.GABLES:
		_check((main.get_node("Buildings/" + g) as MeshInstance3D).material_override == Siding.material(), "%s wears the siding" % g)
	# The deck fits the corner: the Wing's north wall and west end, measured off
	# the Wing's own box, are where the deck's constants say.
	var box := main.get_node("Buildings/House South Wing") as Node3D
	var nw := shell.to_local(box.global_transform * Vector3(-0.5, 0, -0.5))
	_check(absf(nw.z - Backyard.CORNER_Z) < 0.1, "deck corner on the Wing's north wall (%.2f)" % nw.z)
	_check(absf(nw.x - (yard.wall_x - Backyard.PAD_REACH)) < 0.1, "the pad reaches the Wing's west end (%.2f)" % nw.x)
	# The House's west wall has four windows and the slider; the ramp inside
	# the slider is clear of the trap door.
	_check(shell.windows.filter(func(w): return w.wall == "west").size() == 4, "four windows on the back wall")
	var hatch: Rect2 = main.get_node("Buildings/HouseBunker").hatch_rect()
	var ramp := Rect2(-shell.width / 2.0, -1.6, Shell.WALL_T + Shell.RAMP_RUN, 3.2)
	_check(not ramp.intersects(hatch), "slider ramp clear of the trap door")
	# The pad is under the steps' north end and not under the deck top.
	for r in Backyard.pad_rects(yard.wall_x):
		_check(r.end.x <= yard.wall_x + 0.001, "pad outside the House")

## The map's Back Yard spot puts you on the lawn west of the deck, facing the
## House's back wall.
func _test_teleport(main: Node, player: CharacterBody3D, shell: Node3D) -> void:
	var pad := main.get_node_or_null("TransportPads/Pad_BackYard")
	_check(pad != null and pad.pad_name == "Back Yard", "a Back Yard teleport spot")
	if pad == null:
		return
	pad.receive(player)
	var p := shell.to_local(player.global_position)
	_check(p.x < -5.67 - Backyard.PAD_REACH - 1.0 and p.x > -16.0 and absf(p.z) < 2.0, "it lands on the lawn west of the deck (at %s)" % p)
	var facing := shell.global_transform.basis.inverse() * -player.global_basis.z
	_check(facing.x > 0.99, "facing the House's back wall")

## The willows: seven, roughly evenly spaced in an L inside the chicken run's
## fence (south side, then north up the west side), each a little off the line,
## clear of the coop, ending short of the House, on mulch; leaves high enough
## to walk under.
func _test_trees(main: Node, shell: Node3D, yard: Node3D) -> void:
	var spots := Backyard.tree_spots()
	var row := Backyard.row_spots()
	_check(spots.size() == 7, "seven willows")
	var off := 0.0
	for i in spots.size():
		var d := spots[i].distance_to(row[i])
		_check(d <= Backyard.JITTER * 1.42, "willow %d is near its place in the row (%.2f m off)" % [i, d])
		off = maxf(off, d)
	_check(off > 0.3, "the willows are not in a perfect line")
	var gaps := []
	for i in row.size() - 1:
		gaps.append(row[i].distance_to(row[i + 1]))
	_check(gaps.max() - gaps.min() < 1.6, "the row is evenly spaced along the L (gaps %s)" % str(gaps))
	_check(is_equal_approx(row[0].y, Backyard.ROW_Z) and is_equal_approx(row[row.size() - 1].x, Backyard.ROW_WEST), "a south row that turns north up the west side")
	var coop := main.get_node("Buildings/ChickenCoop") as Node3D
	var coop_at := shell.to_local(coop.global_position)
	_check(row[row.size() - 1].x < coop_at.x - 5.0, "the north leg is west of the coop")
	var wing := main.get_node("Buildings/House South Wing") as Node3D
	var wing_south := shell.to_local(wing.global_transform * Vector3(0, 0, 0.5)).z
	_check(spots[spots.size() - 1].y > wing_south + 0.8 and spots[spots.size() - 1].y < wing_south + 3.5, "the row ends just short of the House's south edge (%.1f vs %.1f)" % [spots[spots.size() - 1].y, wing_south])
	var run := main.get_node("BackFences/ChickenRun_Fence") as Path3D
	for p in spots:
		_check(Vector2(coop_at.x, coop_at.z).distance_to(p) > 4.0, "willow at %s clear of the coop" % p)
		var bed := false
		for r in Backyard.bed_rects():
			bed = bed or r.grow(-0.6).has_point(p)
		_check(bed, "willow at %s stands well inside the mulch" % p)
		# The run's fence stops north of z 20.5 on the west, so only the south
		# leg is checked for being just inside it; none is on or past it.
		var nearest := INF
		for i in run.curve.point_count:
			var f := shell.to_local(run.global_transform * run.curve.get_point_position(i))
			nearest = minf(nearest, Vector2(f.x, f.z).distance_to(p))
		_check(nearest > 1.0, "willow at %s clear of the run's fence (%.1f m)" % [p, nearest])
		if p.y > 23.0:
			_check(nearest < 4.0, "willow at %s just inside the south fence (%.1f m)" % [p, nearest])
	var tree := yard.get_node("Willow1") as Node3D
	var leaf_mesh := (tree.get_node("Leaves") as MeshInstance3D).mesh
	var bark_aabb := (tree.get_node("Bark") as MeshInstance3D).mesh.get_aabb()
	_check(leaf_mesh.get_aabb().position.y > 2.3, "leaves hang no lower than 2.3 m (%.2f)" % leaf_mesh.get_aabb().position.y)
	_check(bark_aabb.end.y > 13.0 and bark_aabb.end.y < 26.0, "a big willow, about 20 m (%.1f m)" % bark_aabb.end.y)

## Walking into a trunk stops you.
func _test_trunk_blocks(player: CharacterBody3D, yard: Node3D) -> void:
	var p: Vector2 = Backyard.tree_spots()[2]
	var at := await _walk(player, yard, Vector3(p.x, 0, p.y - 4.0), Vector3(p.x, 0, p.y), 90)
	_check(Vector2(at.x, at.z).distance_to(p) > 0.5, "a willow's trunk blocks the player (%.2f m off)" % Vector2(at.x, at.z).distance_to(p))

## A ray down onto the deck in front of the main slider and onto the bottom step.
func _test_deck_height(yard: Node3D) -> void:
	var space := yard.get_world_3d().direct_space_state
	for probe in [[Vector3(yard.wall_x - 1.0, 0, -0.3), Backyard.TOP, "deck top"], [Vector3(yard.wall_x - 10.0, 0, -0.3), 0.0, "lawn"]]:
		var p: Vector3 = probe[0]
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(yard.to_global(p + Vector3(0, 3, 0)), yard.to_global(p - Vector3(0, 1, 0))))
		var y: float = yard.to_local(hit.position).y if not hit.is_empty() else -9.0
		_check(absf(y - float(probe[1])) < 0.05, "%s is at %.2f (got %.2f)" % [probe[2], probe[1], y])

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

## Up the deck to a shut slider (it blocks), open it, walk in; turn round and
## walk back out onto the deck. `out_dir` is the wall's outward direction in
## the shell's frame.
func _test_slider(player: CharacterBody3D, shell: Node3D, wall: String, out_dir: Vector3, what: String) -> void:
	var door: Node3D = null
	for c in shell.get_children():
		if c.has_meta("wall") and c.get_meta("wall") == wall and c.get("glass"):
			door = c
	_check(door != null, "%s: a glass slider on the %s wall" % [what, wall])
	if door == null:
		return
	_check(door.get_interact_prompt() == "Open sliding door", "%s: slider prompt" % what)
	# The walkable gap's centre: the half of the opening the sliding panel covers.
	var gap: Vector3 = door.global_position + door.global_basis.x * (float(door.width) - door.glass_panel_width() / 2.0)
	var at := shell.to_local(gap)
	var face: float = (shell.width if wall == "west" or wall == "east" else shell.depth) / 2.0
	var axis := Vector3(at.x, 0, 0) if wall == "north" or wall == "south" else Vector3(0, 0, at.z)
	var outside: Vector3 = axis + out_dir * (face + 6.0)
	var inside: Vector3 = axis + out_dir * (face - 2.5)
	var p := await _walk(player, shell, outside, inside, 90)
	var depth_out := p.dot(out_dir)
	_check(depth_out > face, "%s: the shut slider blocks (%.2f out)" % [what, depth_out])
	_check(p.y > Backyard.TOP - 0.15, "%s: up the steps onto the deck (y %.2f)" % [what, p.y])
	door.interact(player)
	await _step(90)
	p = await _walk(player, shell, outside, inside, 150)
	depth_out = p.dot(out_dir)
	_check(depth_out < face - 1.0 and p.y < 0.2, "%s: in through the slider onto the floor (at %s)" % [what, p])
	p = await _walk(player, shell, axis + out_dir * (face - 2.0), outside, 90)
	depth_out = p.dot(out_dir)
	_check(depth_out > face + 0.3, "%s: back out over the sill ramp onto the deck (at %s)" % [what, p])
	door.interact(player)
	await _step(90)
