extends Node
## Ustawienia gry — zapis i audio. Display: fullscreen przez Window API (Godot 4).

const SAVE_PATH := "user://settings.cfg"
const DEFAULT_WINDOW_SIZE := Vector2i(1280, 720)
## Muzyka ma być wyraźnie cichsza od SFX — offset na busie + niższy domyślny suwak.
const MUSIC_BUS_OFFSET_DB := -14.0

var master_volume: float = 1.0
var music_volume: float = 0.5
var sfx_volume: float = 1.0
var fullscreen: bool = false


func _ready() -> void:
	_ensure_audio_buses()
	load_settings()
	call_deferred("_apply_on_startup")


func _apply_on_startup() -> void:
	apply_audio()
	apply_display()
	call_deferred("_ensure_music_started")


func _ensure_music_started() -> void:
	await get_tree().process_frame
	var music := get_node_or_null("/root/GameMusic")
	if music and music.has_method("start_if_needed"):
		music.start_if_needed()


func _ensure_audio_buses() -> void:
	if AudioServer.get_bus_index(&"Music") < 0:
		AudioServer.add_bus()
		var music_idx := AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(music_idx, "Music")
		AudioServer.set_bus_send(music_idx, &"Master")
		AudioServer.set_bus_mute(music_idx, false)
	if AudioServer.get_bus_index(&"SFX") < 0:
		AudioServer.add_bus()
		var sfx_idx := AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(sfx_idx, "SFX")
		AudioServer.set_bus_send(sfx_idx, &"Master")
		AudioServer.set_bus_mute(sfx_idx, false)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		fullscreen = false
		return
	master_volume = clampf(float(cfg.get_value("audio", "master", master_volume)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value("audio", "music", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)
	fullscreen = bool(cfg.get_value("display", "fullscreen", fullscreen))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.save(SAVE_PATH)


func apply_audio() -> void:
	AudioServer.set_bus_mute(0, false)
	AudioServer.set_bus_volume_db(0, _linear_to_bus_db(master_volume))
	var music_idx := AudioServer.get_bus_index(&"Music")
	if music_idx >= 0:
		AudioServer.set_bus_mute(music_idx, false)
		AudioServer.set_bus_volume_db(music_idx, _linear_to_bus_db(music_volume) + MUSIC_BUS_OFFSET_DB)
	var sfx_idx := AudioServer.get_bus_index(&"SFX")
	if sfx_idx >= 0:
		AudioServer.set_bus_mute(sfx_idx, false)
		AudioServer.set_bus_volume_db(sfx_idx, _linear_to_bus_db(sfx_volume))
	var music := get_node_or_null("/root/GameMusic")
	if music and music.has_method("ensure_playing"):
		music.ensure_playing()


func apply_display() -> void:
	call_deferred("_apply_display_now")


func _apply_display_now() -> void:
	var win := _game_window()
	if win == null:
		if fullscreen:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		return
	if fullscreen:
		win.borderless = false
		win.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
	else:
		win.mode = Window.MODE_WINDOWED
		win.borderless = false
		win.size = DEFAULT_WINDOW_SIZE
		var screen_size := DisplayServer.screen_get_size(win.current_screen)
		win.position = (screen_size - DEFAULT_WINDOW_SIZE) / 2
	_sync_fullscreen_flag_from_window()


func is_fullscreen_active() -> bool:
	var win := _game_window()
	if win == null:
		return DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED
	return win.mode == Window.MODE_FULLSCREEN or win.mode == Window.MODE_EXCLUSIVE_FULLSCREEN


func is_embedded_in_editor() -> bool:
	return Engine.is_embedded_in_editor()


func can_toggle_fullscreen() -> bool:
	return not is_embedded_in_editor()


func set_master_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	apply_audio()
	save_settings()


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	apply_audio()
	save_settings()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	apply_audio()
	save_settings()


func set_fullscreen(enabled: bool) -> void:
	if is_embedded_in_editor():
		fullscreen = false
		_sync_fullscreen_flag_from_window()
		return
	fullscreen = enabled
	apply_display()
	call_deferred("_finish_fullscreen_toggle")


func _finish_fullscreen_toggle() -> void:
	_sync_fullscreen_flag_from_window()
	save_settings()


func _sync_fullscreen_flag_from_window() -> void:
	fullscreen = is_fullscreen_active()


func _game_window() -> Window:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root as Window


func _linear_to_bus_db(linear: float) -> float:
	return linear_to_db(maxf(linear, 0.001))
