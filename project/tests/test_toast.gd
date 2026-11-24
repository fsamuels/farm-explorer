extends SceneTree
## Tests for the toast notices (D-142, scripts/toast.gd). Run headless from project/:
##   godot --headless -s res://tests/test_toast.gd

const Toast := preload("res://scripts/toast.gd")

var _failures := 0

func _init() -> void:
	_run.call_deferred()

func _check(cond: bool, what: String) -> void:
	if not cond:
		_failures += 1
		push_error("FAIL: " + what)

func _run() -> void:
	var toast := Toast.new()
	root.add_child(toast)
	await process_frame
	_check(toast.is_in_group("toast"), "the toast joins the toast group")
	_check(not toast.is_showing(), "nothing showing to start with")

	# Posting through the group, the way the water does.
	get_first_node_in_group("toast").show_toast("The pond is full", Color(0.4, 0.7, 1.0))
	_check(toast.is_showing() and toast.current_text == "The pond is full", "a toast shows: '%s'" % toast.current_text)
	toast.show_toast("The pond is full")
	_check(toast.queued() == 0, "the same notice is not repeated while it is on screen")
	toast.show_toast("The pond is empty")
	toast.show_toast("The pond is empty")
	_check(toast.queued() == 1, "a different one waits its turn, once: %s" % toast.queued())
	for i in 20:
		toast.show_toast("Notice %d" % i)
	_check(toast.queued() <= Toast.MAX_QUEUED, "the queue is bounded: %s" % toast.queued())

	# It fades in, and then out.
	await create_timer(Toast.FADE_IN + 0.15).timeout
	await process_frame
	_check(toast._panel.visible and toast._panel.modulate.a > 0.9, "it has faded in: %s" % toast._panel.modulate.a)
	var panel_y: float = toast._panel.position.y
	_check(is_equal_approx(panel_y, Toast.TOP_MARGIN), "and settled at the top margin: %s" % panel_y)
	var view_width: float = root.get_visible_rect().size.x / root.content_scale_factor
	_check(is_equal_approx(toast._panel.position.x, (view_width - toast._panel.size.x) * 0.5), "centred horizontally: %s" % toast._panel.position.x)

	# After its time the next one follows.
	await create_timer(Toast.HOLD + Toast.FADE_OUT + 0.4).timeout
	_check(toast.current_text != "The pond is full", "the next notice takes over: '%s'" % toast.current_text)
	_check(toast.is_showing(), "and is showing")

	# clear() drops everything.
	toast.clear()
	_check(not toast.is_showing() and toast.queued() == 0 and not toast._panel.visible, "clear() empties the screen and the queue")

	# Toasts keep running while the game is paused (the sky menu, the map).
	paused = true
	toast.show_toast("While paused")
	await create_timer(Toast.FADE_IN + 0.2).timeout
	_check(toast._panel.modulate.a > 0.9, "a toast fades in while the game is paused: %s" % toast._panel.modulate.a)
	paused = false
	toast.clear()
	print("toast: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures else 0)
