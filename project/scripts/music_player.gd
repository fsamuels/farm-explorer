extends Node
## The game's soundtrack (D-173, D-174): one slow, wistful looping piece, OFF
## until the player turns it on. The bottom hint bar (minimap.gd) has a "P —
## Music" button that shows its state and keys: P turns it on and off, [ and ]
## change the volume (five steps); the button works when the mouse is free. The
## music keeps playing while the map or a menu pauses the game. The track is
## rendered by tools/make_music.py.

const TRACK := preload("res://audio/farm_theme.wav")
## Volume steps in dB, quiet to loud; the game starts on the middle one.
const LEVELS := [-38.0, -32.0, -27.0, -22.0, -17.0]
const DEFAULT_LEVEL := 2
const SILENT_DB := -60.0
const FADE_TIME := 1.5

var enabled := false
var level := DEFAULT_LEVEL
var _player: AudioStreamPlayer
var _tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.name = "Theme"
	_player.stream = TRACK
	_player.volume_db = SILENT_DB
	# The WAV has no loop points of its own: start it again when it ends.
	_player.finished.connect(_player.play)
	add_child(_player)
	add_to_group("music")

## The label of the bottom bar's music button (minimap.gd): the state, and the
## keys that change it.
func chip_text() -> String:
	if not enabled:
		return "P — Music: Off"
	return "P — Music: On %s   [ ] volume" % _bars()

func _bars() -> String:
	return "▮".repeat(level + 1) + "▯".repeat(LEVELS.size() - level - 1)

func toggle() -> void:
	set_enabled(not enabled)

func set_enabled(on: bool) -> void:
	enabled = on
	if on and not _player.playing:
		_player.play()
	_fade_to(LEVELS[level] if on else SILENT_DB)

func set_level(new_level: int) -> void:
	level = clampi(new_level, 0, LEVELS.size() - 1)
	if enabled:
		_fade_to(LEVELS[level])

func _fade_to(db: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", db, FADE_TIME if not enabled or db == SILENT_DB else 0.3)
	if db == SILENT_DB:
		_tween.tween_callback(func(): if not enabled: _player.stop())

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.ctrl_pressed or key.meta_pressed or key.alt_pressed:
		return
	match key.physical_keycode:
		KEY_P:
			toggle()
		KEY_BRACKETLEFT:
			set_level(level - 1)
		KEY_BRACKETRIGHT:
			set_level(level + 1)
		_:
			return
	get_viewport().set_input_as_handled()
