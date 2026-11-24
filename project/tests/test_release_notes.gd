extends SceneTree
## Tests for the What's New dialog and the changelog behind it (D-130): the
## CHANGELOG.md parser, the rule that every release carries a one-line summary,
## that the committed release_data.gd matches CHANGELOG.md and the game's
## current size, and the dialog itself. Run headless from project/:
##   godot --headless -s res://tests/test_release_notes.gd
## If the freshness checks fail, regenerate the data and commit it:
##   godot --headless -s ../tools/build_release_notes.gd

const ReleaseNotes := preload("res://scripts/release_notes.gd")
const ReleaseData := preload("res://scripts/release_data.gd")
const REGENERATE := "run: cd project && godot --headless -s ../tools/build_release_notes.gd"

var _failures := 0

func _init() -> void:
	_run.call_deferred()

func _check(cond: bool, what: String) -> void:
	if not cond:
		_failures += 1
		push_error("FAIL: " + what)

func _run() -> void:
	_test_parse()
	_test_format()
	_test_freshness()
	await _test_scene()
	print("release notes: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures else 0)

func _test_parse() -> void:
	var text := "# What's new\n\nIntro.\n\n## May 1: First\n> The headline.\n- **Bold.** A bullet that\n  wraps.\n- Plain.\n\n## April 2: Older\n- No summary here.\n"
	var entries := ReleaseNotes.parse(text)
	_check(entries.size() == 2, "two releases parsed: %d" % entries.size())
	_check(entries[0].title == "May 1: First" and entries[0].summary == "The headline.", "title and summary: %s" % [entries[0]])
	_check(entries[0].bullets == ["**Bold.** A bullet that wraps.", "Plain."], "bullets, with the wrapped line joined: %s" % [entries[0].bullets])
	_check(entries[1].summary == "" and entries[1].bullets.size() == 1, "a release without a summary parses empty")
	_check(ReleaseNotes.problems(entries).size() == 1 and "no one-line" in ReleaseNotes.problems(entries)[0], "only the missing summary is a problem")
	_check(not ReleaseNotes.problems([]).is_empty(), "an empty changelog is a problem")
	var long_entry := [{"title": "T", "summary": "x".repeat(ReleaseNotes.MAX_SUMMARY + 1), "bullets": ["b"]}]
	_check(not ReleaseNotes.problems(long_entry).is_empty(), "an over-long summary is a problem")
	var ok_entry := [{"title": "T", "summary": "x".repeat(ReleaseNotes.MAX_SUMMARY), "bullets": ["b"]}]
	_check(ReleaseNotes.problems(ok_entry).is_empty(), "a summary at the limit is fine")

func _test_format() -> void:
	_check(ReleaseNotes.with_commas(0) == "0" and ReleaseNotes.with_commas(999) == "999", "small numbers get no commas")
	_check(ReleaseNotes.with_commas(1000) == "1,000" and ReleaseNotes.with_commas(1234567) == "1,234,567", "thousands get commas")
	_check(ReleaseNotes.bullet_parts("**Weir.** Press E.") == ["Weir.", "Press E."], "bullet splits into lead-in and detail")
	_check(ReleaseNotes.bullet_parts("Plain **x** bit") == ["", "Plain x bit"], "a bullet with no leading bold has no lead-in")
	var listed := ReleaseNotes.bullet_list_bbcode("**A.** b [c]", 20, Color.WHITE)
	_check(listed.begins_with("[b]A.[/b]") and "[font_size=20]" in listed and "[lb]c]" in listed, "list BBCode: %s" % listed)
	_check(ReleaseNotes.bullet_bbcode("a **b** c") == "a [b]b[/b] c", "bold becomes BBCode: %s" % ReleaseNotes.bullet_bbcode("a **b** c"))
	_check(ReleaseNotes.bullet_bbcode("see [x]") == "see [lb]x]", "a literal bracket is escaped")
	var a := {"n": 1000, "m": 3}
	_check(ReleaseNotes.stats_current(a, {"n": 1040, "m": 7}), "within 5% or 5 counts is current")
	_check(not ReleaseNotes.stats_current(a, {"n": 1000, "m": 9}), "6 counts off a small stat is stale")
	_check(ReleaseNotes.stats_current({"commits": 5}, {"commits": 500}), "the commit count is never compared")
	_check(not ReleaseNotes.stats_current(a, {"n": 1100, "m": 3}), "10% off is stale")
	_check(ReleaseNotes.stats_current({"n": 1000, "extra": 7}, {"n": 1000}), "extra keys in the shown stats are ignored")
	_check(not ReleaseNotes.stats_current({"n": 1000}, {"n": 1000, "k": 5}), "a missing stat is stale")

## The rule that keeps the changelog current: CHANGELOG.md is well formed, the
## generated data matches it exactly, and the size stats are not badly stale.
func _test_freshness() -> void:
	var project_dir := ProjectSettings.globalize_path("res://").trim_suffix("/")
	var changelog := project_dir.path_join("../CHANGELOG.md").simplify_path()
	_check(FileAccess.file_exists(changelog), "CHANGELOG.md exists at the repo root")
	var entries := ReleaseNotes.parse(FileAccess.get_file_as_string(changelog))
	for problem in ReleaseNotes.problems(entries):
		_check(false, "CHANGELOG.md: " + problem)
	_check(JSON.stringify(entries) == JSON.stringify(ReleaseData.DATA.entries),
			"release_data.gd matches CHANGELOG.md (%s)" % REGENERATE)
	var fresh := ReleaseNotes.collect_stats(project_dir)
	_check(ReleaseNotes.stats_current(ReleaseData.DATA.stats, fresh),
			"the game stats in release_data.gd are stale: %s vs now %s (%s)" % [ReleaseData.DATA.stats, fresh, REGENERATE])

func _test_scene() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var dialog: CanvasLayer = main.get_node("WhatsNew")
	var entries: Array = ReleaseData.DATA.entries
	_check(not dialog.is_open() and not paused, "the dialog starts closed")
	_check(dialog.heading_labels.size() == entries.size(), "one heading per release: %d" % dialog.heading_labels.size())
	_check(dialog.heading_labels[0].text == entries[0].title, "the newest release is first")
	_check(dialog.summary_labels[0].text == entries[0].summary and entries[0].summary != "", "the newest summary is shown first")
	_check(dialog.detail_boxes[0] != null and dialog.detail_boxes[0].visible, "the newest release's details start open")
	_check(dialog.detail_boxes.size() < 2 or dialog.detail_boxes[1] == null or not dialog.detail_boxes[1].visible, "older releases' details start folded")
	for i in entries.size():
		_check(dialog.summary_labels[i].text == entries[i].summary, "summary %d shown" % i)
	_check(dialog.stat_values.has("Lines of code") and dialog.stat_values["Lines of code"].text.length() >= 4, "lines of code shown")
	_check(dialog.stat_values.size() == ReleaseNotes.stats_rows(ReleaseData.DATA.stats).size(), "every stat row is shown")

	var press := InputEventAction.new()
	press.action = "show_changelog"
	press.pressed = true
	dialog._input(press)
	_check(dialog.is_open() and paused, "C opens the dialog and pauses the game")
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "the mouse is freed while it is open")
	dialog._input(press)
	_check(not dialog.is_open() and not paused, "C closes it and resumes")
	dialog.set_open(true)
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	dialog._input(esc)
	_check(not dialog.is_open() and not paused, "Esc closes it")

	paused = true
	dialog._input(press)
	_check(not dialog.is_open(), "C does nothing while something else has the game paused")
	paused = false
	var sky: Node = main.get_node("SkyMenu")
	sky.set_open(true)
	dialog.set_open(true)
	_check(not dialog.is_open(), "it won't open over the sky menu")
	sky.set_open(false)

	var button: Button = main.get_node("Minimap/Root").news_button
	_check(button != null and button.mouse_filter == Control.MOUSE_FILTER_STOP, "the minimap's news icon takes clicks")
	button.pressed.emit()
	_check(dialog.is_open(), "the news icon opens the dialog")
	_check(dialog._panel.get_combined_minimum_size().y > 0 and dialog.FONT_SIZE >= 40, "the dialog's text is large")
	# It shrinks to a small window and grows (to a limit) in a big one.
	var panel_size := Vector2(1700, 1500)
	var small: float = dialog.ui_scale(Vector2(1280, 720), panel_size)
	var big: float = dialog.ui_scale(Vector2(3072, 1728), panel_size)
	var huge: float = dialog.ui_scale(Vector2(10000, 10000), panel_size)
	_check(small < 1.0 and big > small and huge == dialog.MAX_SCALE, "scale shrinks for a small window, grows for a big one, and is capped: %s %s %s" % [small, big, huge])
	_check(Vector2(1700, 1500) * small <= Vector2(1280, 720), "a small window still shows the whole dialog")
	dialog.set_open(false)
	var listed := false
	for row in preload("res://scripts/controls_overlay.gd").CONTROLS:
		listed = listed or row[0] == "C"
	_check(listed, "the controls panel lists C")
