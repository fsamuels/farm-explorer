extends SceneTree
## The parked cars stay on the ground when the game starts (D-147). The UTV is
## parked inside the Front Barn's solid placeholder box; if that box is still
## live on the first physics frame the car is shoved out of it, straight down
## through the thin terrain collider, and falls forever. Run headless from
## project/ (after the editor has imported assets once):
##   godot --headless -s res://tests/test_parked_cars.gd

var _failures := 0
var _frames := 0
var _main: Node

func _init() -> void:
	# Added in _init, like the real game's main scene, so the first physics
	# frame comes straight after the scene's own _ready calls.
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	physics_frame.connect(_tick)

func _check(cond: bool, what: String) -> void:
	if not cond:
		_failures += 1
		push_error("FAIL: " + what)

func _tick() -> void:
	_frames += 1
	if _frames < 30:
		return
	for car_name in ["BMW2002tii", "TR6", "CubCadetUTV"]:
		var y: float = _main.get_node(car_name).global_position.y
		_check(y > -0.1 and y < 0.2, "%s is still on the ground after %d frames (y %.2f)" % [car_name, _frames, y])
	print("parked_cars: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures else 0)
