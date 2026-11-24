extends SceneTree
## Checks docs/project/decisions.md: every row's ID is unique, the rows run in
## order, and no number is skipped. Parallel branches each claim "the next free
## number", so a merge can leave two rows with the same ID, or a hole after a
## renumbering; this fails when that happens. Run headless from project/:
##   godot --headless -s res://tests/test_decisions.gd
## If it fails after merging or rebasing onto main, renumber your row to the next
## free number and fix the D-numbers you cite elsewhere (code comments, docs).

var _failures := 0

func _init() -> void:
	_run.call_deferred()

func _check(cond: bool, what: String) -> void:
	if not cond:
		_failures += 1
		push_error("FAIL: " + what)

## The numbers of the decision rows ("| D-12 | ..."), in file order.
static func row_numbers(text: String) -> Array[int]:
	var re := RegEx.new()
	re.compile("^\\| D-(\\d+) \\|")
	var out: Array[int] = []
	for line in text.split("\n"):
		var m := re.search(line)
		if m:
			out.append(m.get_string(1).to_int())
	return out

## Human-readable problems with a list of row numbers; empty when it is sound.
static func problems(numbers: Array[int]) -> Array[String]:
	var out: Array[String] = []
	if numbers.is_empty():
		out.append("no decision rows found")
		return out
	var seen := {}
	for i in numbers.size():
		var n := numbers[i]
		if seen.has(n):
			out.append("D-%d appears more than once" % n)
		seen[n] = true
		if i > 0 and n < numbers[i - 1]:
			out.append("D-%d comes after D-%d (rows must be in order)" % [n, numbers[i - 1]])
		elif i > 0 and n > numbers[i - 1] + 1:
			out.append("D-%d is missing (D-%d is followed by D-%d)" % [numbers[i - 1] + 1, numbers[i - 1], n])
	if numbers[0] != 1:
		out.append("the log starts at D-%d, not D-1" % numbers[0])
	return out

func _run() -> void:
	# The checker itself, on made-up logs.
	var good := "| ID | Date |\n| --- | --- |\n| D-1 | x |\n| D-2 | y |\nnot a row\n| D-3 | z |\n"
	_check(str(row_numbers(good)) == "[1, 2, 3]", "reads the rows and ignores the header: %s" % [row_numbers(good)])
	_check(problems(row_numbers(good)).is_empty(), "a sound log has no problems")
	var dup: Array[int] = [1, 2, 2, 3]
	var gap: Array[int] = [1, 2, 4]
	var unordered: Array[int] = [1, 3, 2]
	var late_start: Array[int] = [2, 3]
	var empty: Array[int] = []
	_check(not problems(dup).is_empty(), "a duplicate is caught")
	_check(not problems(gap).is_empty(), "a gap is caught")
	_check(not problems(unordered).is_empty(), "rows out of order are caught")
	_check(not problems(late_start).is_empty(), "a log that does not start at D-1 is caught")
	_check(not problems(empty).is_empty(), "an empty log is caught")
	var prose := "| D-1 | a |\n  | D-1 | indented, not a row |\nD-1 in prose\n"
	_check(str(row_numbers(prose)) == "[1]", "only lines that start with a row cell count")

	# The real log.
	var project_dir := ProjectSettings.globalize_path("res://").trim_suffix("/")
	var path := project_dir.path_join("../docs/project/decisions.md").simplify_path()
	_check(FileAccess.file_exists(path), "docs/project/decisions.md exists")
	var numbers := row_numbers(FileAccess.get_file_as_string(path))
	for p in problems(numbers):
		_check(false, "decisions.md: " + p)
	_check(numbers.size() >= 145, "the log has all the rows it had when this test was written: %d" % numbers.size())

	print("decisions: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures else 0)
