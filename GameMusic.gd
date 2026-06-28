extends Node
## Muzyka w tle — loop przez całą grę.

const THEME_PATH := "res://music/dungeongame_theme2_prev6.wav"

var _player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.bus = &"Music"
	_player.volume_db = 0.0
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_player)
	var tree := get_tree()
	if tree and not tree.scene_changed.is_connected(_on_scene_changed):
		tree.scene_changed.connect(_on_scene_changed)
	call_deferred("start_if_needed")


func _on_scene_changed(_scene: Node) -> void:
	call_deferred("ensure_playing")


func start_if_needed() -> void:
	if _player == null:
		return
	if _player.stream == null and not _load_stream():
		return
	ensure_playing()


func _load_stream() -> bool:
	var loaded := load(THEME_PATH)
	if loaded == null:
		push_warning("GameMusic: brak pliku %s" % THEME_PATH)
		return false
	_player.stream = loaded as AudioStream
	return _player.stream != null


func ensure_playing() -> void:
	if _player == null:
		return
	if _player.stream == null and not _load_stream():
		return
	if not _player.playing:
		_player.play()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		call_deferred("ensure_playing")
