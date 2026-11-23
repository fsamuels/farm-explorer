extends RefCounted
## Turns CHANGELOG.md into the data the What's New dialog shows (D-130), and
## counts the game's size for its "by the numbers" panel. Pure functions, so
## tests/test_release_notes.gd can check them headless. The generator
## (tools/build_release_notes.gd) writes the result into release_data.gd, since
## a web export can read neither CHANGELOG.md nor the source tree.
##
## CHANGELOG.md format, one block per release, newest first:
##   ## November 23: A UTV in the barn
##   > One line for players: the headline of this release.
##   - **Bold lead.** A bullet; a wrapped line indented two spaces continues it.

## Longest allowed one-line summary, in characters.
const MAX_SUMMARY := 140

## The entries in `text` (a CHANGELOG.md): each {title, summary, bullets}.
static func parse(text: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var current := {}
	for raw in text.split("\n"):
		var line := raw.trim_suffix("\r")
		if line.begins_with("## "):
			current = {"title": line.substr(3).strip_edges(), "summary": "", "bullets": []}
			entries.append(current)
		elif current.is_empty():
			continue
		elif line.begins_with("> "):
			var part := line.substr(2).strip_edges()
			current.summary = part if current.summary == "" else current.summary + " " + part
		elif line.begins_with("- "):
			current.bullets.append(line.substr(2).strip_edges())
		elif line.begins_with("  ") and line.strip_edges() != "" and not current.bullets.is_empty():
			current.bullets[-1] += " " + line.strip_edges()
	return entries

## What is wrong with `entries`, one sentence each (empty when all is well):
## every release needs a short one-line summary and at least one bullet.
static func problems(entries: Array) -> Array[String]:
	var out: Array[String] = []
	if entries.is_empty():
		out.append("the changelog has no '## ' release blocks")
	for e: Dictionary in entries:
		var title: String = e.title
		if e.summary == "":
			out.append("'%s' has no one-line '> summary'" % title)
		elif e.summary.length() > MAX_SUMMARY:
			out.append("'%s' summary is %d characters (max %d)" % [title, e.summary.length(), MAX_SUMMARY])
		if e.bullets.is_empty():
			out.append("'%s' has no bullets" % title)
	return out

## A changelog bullet as BBCode for a RichTextLabel: **bold** becomes bold and a
## literal "[" is escaped so it is not read as a tag.
static func bullet_bbcode(text: String) -> String:
	var escaped := text.replace("[", "[lb]")
	var out := ""
	var bold := false
	for piece in escaped.split("**"):
		out += ("[b]%s[/b]" if bold else "%s") % piece
		bold = not bold
	return out

## 1234567 -> "1,234,567".
static func with_commas(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += ","
		out += s[i]
	return ("-" if n < 0 else "") + out

## The (label, value) rows of the "by the numbers" panel for a stats dictionary.
static func stats_rows(stats: Dictionary) -> Array:
	return [
		["Lines of code", with_commas(stats.code_lines)],
		["Lines of tests", with_commas(stats.test_lines)],
		["Scripts", with_commas(stats.scripts)],
		["Scenes", with_commas(stats.scenes)],
		["3D models", with_commas(stats.models)],
		["Images and textures", with_commas(stats.textures)],
		["Drivable vehicles", with_commas(stats.vehicles)],
		["Game files", "%.1f MB" % (float(stats.size_kb) / 1024.0)],
		["Decisions logged", with_commas(stats.decisions)],
		["Commits", with_commas(stats.commits)],
	]

const SKIP_DIRS := [".godot", ".import", "builds"]
const IMAGE_EXTENSIONS := ["png", "jpg", "jpeg", "webp"]
## The generated data file, left out of the counts so regenerating it
## doesn't change them.
const GENERATED := "release_data.gd"

## Count the game in `project_dir` (the folder holding project.godot; the repo
## root is its parent). Sizes are of the source files, not of an export.
static func collect_stats(project_dir: String) -> Dictionary:
	var stats := {"code_lines": 0, "test_lines": 0, "scripts": 0, "scenes": 0, "models": 0,
			"textures": 0, "vehicles": 0, "size_kb": 0, "decisions": 0, "commits": 0}
	var bytes := 0
	var files: Array[String] = []
	_walk(project_dir, files)
	for path in files:
		if path.get_file() != GENERATED:
			bytes += FileAccess.get_file_as_bytes(path).size()
		var ext := path.get_extension().to_lower()
		var in_tests := path.contains("/tests/")
		if ext == "gd" and path.get_file() != GENERATED:
			var lines := _count_lines(path)
			if in_tests:
				stats.test_lines += lines
			else:
				stats.code_lines += lines
				stats.scripts += 1
		elif ext == "gdshader":
			stats.code_lines += _count_lines(path)
			stats.scripts += 1
		elif ext == "tscn":
			stats.scenes += 1
			var scene := FileAccess.get_file_as_string(path)
			if scene.contains("scripts/vehicle.gd") or scene.contains("scripts/utv.gd"):
				stats.vehicles += 1
		elif ext == "glb":
			stats.models += 1
		elif ext in IMAGE_EXTENSIONS:
			stats.textures += 1
	stats.size_kb = int(ceil(float(bytes) / 1024.0))
	var repo := project_dir.path_join("..").simplify_path()
	var decisions := repo.path_join("docs/project/decisions.md")
	if FileAccess.file_exists(decisions):
		for line in FileAccess.get_file_as_string(decisions).split("\n"):
			if line.begins_with("| D-"):
				stats.decisions += 1
	var out := []
	if OS.execute("git", ["-C", repo, "rev-list", "--count", "HEAD"], out) == 0 and not out.is_empty():
		stats.commits = int(String(out[0]).strip_edges())
	return stats

static func _walk(dir: String, into: Array[String]) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.list_dir_begin()
	var entry := d.get_next()
	while entry != "":
		if not entry.begins_with(".") and not SKIP_DIRS.has(entry):
			var path := dir.path_join(entry)
			if d.current_is_dir():
				_walk(path, into)
			else:
				into.append(path)
		entry = d.get_next()
	d.list_dir_end()

static func _count_lines(path: String) -> int:
	var text := FileAccess.get_file_as_string(path)
	return text.count("\n") + (0 if text == "" or text.ends_with("\n") else 1)

## How far apart two counts may be, as a fraction (and at least MIN_SLACK
## counts), before the committed stats count as stale. The test cares that they
## are regenerated now and then, not on every change.
const STALE_FRACTION := 0.05
const MIN_SLACK := 5.0
## Shown in the dialog but never compared: the commit count moves with every
## merge, and a shallow clone reports a tiny one.
const UNCOMPARED := ["commits"]

## True when every compared stat in `shown` is within STALE_FRACTION (and at
## least MIN_SLACK counts) of the same stat in `fresh`.
static func stats_current(shown: Dictionary, fresh: Dictionary) -> bool:
	for key in fresh:
		if UNCOMPARED.has(key):
			continue
		if not shown.has(key):
			return false
		var a: float = shown[key]
		var b: float = fresh[key]
		if absf(a - b) > maxf(MIN_SLACK, STALE_FRACTION * b):
			return false
	return true
