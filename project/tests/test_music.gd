extends SceneTree
## The soundtrack (D-173): the track exists, the player is in the main scene and
## it starts off, and the chip and P turn it on.

var _failures := 0

func _check(cond: bool, what: String) -> void:
	if not cond:
		_failures += 1
		printerr("FAIL: " + what)

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var music := main.get_node_or_null("Music")
	_check(music != null, "the main scene has a Music node")
	if music:
		var track: AudioStreamWAV = music.TRACK
		_check(track.get_length() > 30.0, "the theme is a full track: %.1f s" % track.get_length())
		_check(not music.enabled and not music.get_node("Theme").playing, "music starts off")
		_check(music.chip_text().contains("Off") and music.chip_text().contains("P"), "the chip says it is off and how to turn it on: %s" % music.chip_text())
		var button: Button = main.get_node("Minimap/Root").music_button
		_check(button.text == music.chip_text() or button.text == "P — Music: Off", "the bottom bar has a music button: %s" % button.text)
		button.pressed.emit()
		_check(music.enabled and music.get_node("Theme").playing, "the bar's button turns it on")
		_check(music.chip_text().contains("On") and music.chip_text().contains("[ ]"), "the chip shows the keys: %s" % music.chip_text())
		var start: int = music.level
		music.set_level(start + 1)
		_check(music.level == start + 1, "] turns it up")
		music.set_level(99)
		_check(music.level == music.LEVELS.size() - 1, "volume stops at the top")
		music.set_level(-5)
		_check(music.level == 0, "volume stops at the bottom")
		music.toggle()
		_check(not music.enabled, "P turns it off again")
		_check(music.LEVELS[music.DEFAULT_LEVEL] <= -25.0, "the default volume is quiet")
	print("music: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures else 0)
