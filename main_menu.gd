extends Control
## Menu główne — tło + przyciski Play / Settings / Quit.

const HOME_SCENE := "res://home_scene.tscn"
const PLAY_TEX_PATH := "res://menu/DwarfGuard_menu_play.png"
const SETTINGS_TEX_PATH := "res://menu/DwarfGuard_menu_settings.png"
const QUIT_TEX_PATH := "res://menu/DwarfGuard_menu_quit.png"
const PLAY_SHINE_SHADER_PATH := "res://menu/menu_play_shine.gdshader"
## Piksele bardziej przezroczyste niż ten próg nie reagują na klik.
const CLICK_ALPHA_THRESHOLD := 0.15

@onready var _play_btn: TextureButton = $PlayButton
@onready var _settings_btn: TextureButton = $SettingsButton
@onready var _quit_btn: TextureButton = $QuitButton

var _play_shine_mat: ShaderMaterial
var _play_hover_strength: float = 0.0
var _play_shine_time: float = 0.0
var _play_hover_tween: Tween
var _play_shine_ok: bool = false
var _menu_hover_tween: Tween
var _hovered_btn: TextureButton = null
## Przyciski są ogromne — bez tego mouse_entered odpala się przy starcie.
var _menu_hover_enabled: bool = false
var _starting: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if SettingsUI:
		SettingsUI.ensure_game_unblocked()
	_wire_menu_button(_play_btn, _on_play_pressed)
	_wire_menu_button(_settings_btn, _on_settings_pressed)
	_wire_menu_button(_quit_btn, _on_quit_pressed)
	call_deferred("_finish_menu_button_setup")


func _wire_menu_button(btn: TextureButton, pressed_cb: Callable) -> void:
	if btn == null:
		return
	btn.pressed.connect(func() -> void:
		if GameAudio:
			GameAudio.play_menu_click()
		pressed_cb.call()
	)
	btn.mouse_entered.connect(_on_menu_button_hover_in.bind(btn))
	btn.mouse_exited.connect(_on_menu_button_hover_out.bind(btn))


func _input(event: InputEvent) -> void:
	if _menu_hover_enabled:
		return
	if event is InputEventMouseMotion:
		_menu_hover_enabled = true
		for btn in _all_menu_buttons():
			if btn.get_global_rect().has_point(event.global_position):
				_on_menu_button_hover_in(btn)
				return


func _process(delta: float) -> void:
	if not _play_shine_ok or _play_shine_mat == null:
		return
	if _hovered_btn == _play_btn and _play_hover_strength > 0.001:
		_play_shine_time += delta
	_play_shine_mat.set_shader_parameter("shine_time", _play_shine_time)
	_play_shine_mat.set_shader_parameter("shine_strength", _play_hover_strength)


func _finish_menu_button_setup() -> void:
	_apply_click_mask(_play_btn, PLAY_TEX_PATH)
	_apply_click_mask(_settings_btn, SETTINGS_TEX_PATH)
	_apply_click_mask(_quit_btn, QUIT_TEX_PATH)
	_setup_play_shine()
	_reset_menu_hover_visual()


func _all_menu_buttons() -> Array[TextureButton]:
	var out: Array[TextureButton] = []
	for btn in [_play_btn, _settings_btn, _quit_btn]:
		if btn:
			out.append(btn)
	return out


func _reset_menu_hover_visual() -> void:
	_kill_menu_hover_tween()
	_kill_play_hover_tween()
	_hovered_btn = null
	_play_hover_strength = 0.0
	_play_shine_time = 0.0
	if _play_shine_ok and _play_shine_mat:
		_play_shine_mat.set_shader_parameter("shine_strength", 0.0)
		_play_shine_mat.set_shader_parameter("shine_time", 0.0)
	for btn in _all_menu_buttons():
		btn.modulate = Color.WHITE


func _setup_play_shine() -> void:
	if _play_btn == null:
		return
	var shader_res := load(PLAY_SHINE_SHADER_PATH) as Shader
	if shader_res == null:
		push_warning("MainMenu: brak shadera błysku Play.")
		return

	_play_shine_mat = ShaderMaterial.new()
	_play_shine_mat.shader = shader_res
	var tex: Texture2D = _play_btn.texture_normal
	if tex:
		_play_shine_mat.set_shader_parameter("play_tex", tex)
	_play_shine_mat.set_shader_parameter("shine_strength", 0.0)
	_play_shine_mat.set_shader_parameter("shine_time", 0.0)
	_play_btn.material = _play_shine_mat
	_play_shine_ok = true


func _on_menu_button_hover_in(btn: TextureButton) -> void:
	if not _menu_hover_enabled or btn == null:
		return
	_hovered_btn = btn
	if btn == _play_btn:
		_kill_play_hover_tween()
		_play_hover_tween = create_tween()
		_play_hover_tween.tween_method(_set_play_hover_strength, _play_hover_strength, 1.0, 0.22)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		_kill_menu_hover_tween()
		_menu_hover_tween = create_tween()
		_menu_hover_tween.tween_property(btn, "modulate", Color(1.12, 1.05, 0.88, 1.0), 0.18)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _on_menu_button_hover_out(btn: TextureButton) -> void:
	if not _menu_hover_enabled or btn == null:
		return
	if _hovered_btn == btn:
		_hovered_btn = null
	if btn == _play_btn:
		_kill_play_hover_tween()
		_play_hover_tween = create_tween()
		_play_hover_tween.tween_method(_set_play_hover_strength, _play_hover_strength, 0.0, 0.3)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	else:
		_kill_menu_hover_tween()
		_menu_hover_tween = create_tween()
		_menu_hover_tween.tween_property(btn, "modulate", Color.WHITE, 0.24)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _set_play_hover_strength(v: float) -> void:
	_play_hover_strength = v
	if not _play_shine_ok and _play_btn:
		_play_btn.modulate = Color(1.0, 1.0, 1.0, 1.0).lerp(Color(1.15, 1.05, 0.85, 1.0), v)


func _kill_play_hover_tween() -> void:
	if _play_hover_tween != null and _play_hover_tween.is_valid():
		_play_hover_tween.kill()
	_play_hover_tween = null


func _kill_menu_hover_tween() -> void:
	if _menu_hover_tween != null and _menu_hover_tween.is_valid():
		_menu_hover_tween.kill()
	_menu_hover_tween = null


func _apply_click_mask(btn: TextureButton, tex_path: String) -> void:
	if btn == null:
		return
	var tex: Texture2D = btn.texture_normal
	var img: Image = _load_texture_image(tex, tex_path)
	if img == null or img.is_empty():
		push_warning("MainMenu: nie udało się zbudować click mask dla %s." % btn.name)
		return
	var mask := BitMap.new()
	mask.create_from_image_alpha(img, CLICK_ALPHA_THRESHOLD)
	btn.texture_click_mask = mask


func _load_texture_image(tex: Texture2D, path: String) -> Image:
	if tex != null:
		var from_tex := tex.get_image()
		if from_tex != null and not from_tex.is_empty():
			return from_tex
	if path != "" and ResourceLoader.exists(path):
		var loaded := Image.new()
		if loaded.load(path) == OK:
			return loaded
	return null


func _set_menu_buttons_disabled(disabled: bool) -> void:
	for btn in _all_menu_buttons():
		btn.disabled = disabled


func _on_play_pressed() -> void:
	if _starting or (SceneTransition and SceneTransition.is_busy()):
		return
	_starting = true
	_set_menu_buttons_disabled(true)
	_kill_play_hover_tween()
	_kill_menu_hover_tween()
	_reset_menu_hover_visual()
	_play_menu_press_punch()
	GameState.current_slot = 1
	GameState.reset_meta()
	GameState.save(GameState.current_slot)
	if SceneTransition:
		await SceneTransition.play_menu_to_home(HOME_SCENE)
	else:
		get_tree().change_scene_to_file(HOME_SCENE)


func _on_settings_pressed() -> void:
	if SettingsUI:
		SettingsUI.open_settings_from_menu()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _play_menu_press_punch() -> void:
	var bg := get_node_or_null("Background") as Control
	if bg == null:
		return
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(bg, "modulate", Color(1.08, 0.98, 0.88, 1.0), 0.12)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(bg, "modulate", Color(0.72, 0.68, 0.62, 1.0), 0.38)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
