extends CanvasLayer
## Pauza + ustawienia (menu główne i rozgrywka) — styl RPG / Total War.

enum OpenContext { MENU, PAUSE }

const FONT_PATH := "res://MedievalSharp-Bold.ttf"
const MENU_SCENE := "res://main_menu.tscn"

const C_OVERLAY := Color(0.01, 0.01, 0.015, 0.82)
const C_PANEL_OUTER := Color(0.05, 0.04, 0.035, 1.0)
const C_PANEL_INNER := Color(0.08, 0.07, 0.06, 1.0)
const C_HEADER := Color(0.03, 0.025, 0.02, 1.0)
const C_SECTION := Color(0.1, 0.085, 0.065, 1.0)
const C_GOLD := Color(0.78, 0.62, 0.22, 1.0)
const C_GOLD_DIM := Color(0.48, 0.38, 0.14, 1.0)
const C_GOLD_BRIGHT := Color(0.92, 0.78, 0.38, 1.0)
const C_TEXT := Color(0.9, 0.86, 0.76, 1.0)
const C_TEXT_DIM := Color(0.58, 0.54, 0.46, 1.0)
const C_BTN := Color(0.11, 0.09, 0.07, 1.0)
const C_BTN_HOVER := Color(0.18, 0.14, 0.1, 1.0)
const C_BTN_PRESSED := Color(0.06, 0.05, 0.04, 1.0)
const C_SLIDER_TRACK := Color(0.14, 0.11, 0.08, 1.0)
const C_SLIDER_FILL := Color(0.55, 0.42, 0.16, 1.0)

var _font: FontFile
var _pause_root: Control
var _settings_root: Control
var _pause_depth: int = 0
var _context: OpenContext = OpenContext.MENU
var _pause_host: Node = null

var _master_slider: HSlider
var _music_slider: HSlider
var _sfx_slider: HSlider
var _master_pct: Label
var _music_pct: Label
var _sfx_pct: Label
var _fullscreen_check: CheckButton
var _fullscreen_embed_hint: Label


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = load(FONT_PATH) as FontFile
	_build_pause_ui()
	_build_settings_ui()
	ensure_game_unblocked()
	if not get_tree().scene_changed.is_connected(_on_scene_changed):
		get_tree().scene_changed.connect(_on_scene_changed)


func _on_scene_changed(_scene: Node) -> void:
	ensure_game_unblocked()


func ensure_game_unblocked() -> void:
	hide_roots()
	_pause_depth = 0
	_pause_host = null
	if get_tree():
		get_tree().paused = false


func hide_roots() -> void:
	if _pause_root:
		_pause_root.visible = false
		_pause_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _settings_root:
		_settings_root.visible = false
		_settings_root.mouse_filter = Control.MOUSE_FILTER_IGNORE


func is_pause_open() -> bool:
	return _pause_root != null and _pause_root.visible


func is_settings_open() -> bool:
	return _settings_root != null and _settings_root.visible


func open_settings_from_menu() -> void:
	ensure_game_unblocked()
	_context = OpenContext.MENU
	_show_settings()


func open_pause(host: Node) -> void:
	if is_pause_open() or is_settings_open():
		return
	_pause_host = host
	_context = OpenContext.PAUSE
	_pause_depth = 1
	get_tree().paused = true
	_pause_root.visible = true
	_pause_root.mouse_filter = Control.MOUSE_FILTER_STOP


func close_pause(resume_game: bool = true) -> void:
	if not is_pause_open() and not is_settings_open():
		return
	hide_roots()
	if resume_game and _pause_depth > 0:
		get_tree().paused = false
	_pause_depth = 0
	_pause_host = null


func close_settings() -> void:
	if not is_settings_open():
		return
	_settings_root.visible = false
	if _context == OpenContext.PAUSE:
		_pause_root.visible = true
	else:
		close_pause(true)


func _show_settings() -> void:
	_sync_settings_ui()
	if _context == OpenContext.PAUSE:
		_pause_root.visible = false
		_pause_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_root.visible = true
	_settings_root.mouse_filter = Control.MOUSE_FILTER_STOP


func _build_pause_ui() -> void:
	_pause_root = Control.new()
	_pause_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_pause_root)
	_add_overlay(_pause_root)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_root.add_child(center)

	var shell := _make_ornate_shell(Vector2(400, 300))
	center.add_child(shell)

	var body := _populate_shell_body(shell, 12)
	body.add_child(_make_title_header("PAUSED"))
	body.add_child(_make_ornate_rule())
	body.add_child(_make_menu_button("Resume", _on_resume_pressed))
	body.add_child(_make_menu_button("Settings", _on_pause_settings_pressed))
	body.add_child(_make_menu_button("Main Menu", _on_main_menu_pressed))


func _build_settings_ui() -> void:
	_settings_root = Control.new()
	_settings_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_settings_root)
	_add_overlay(_settings_root)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_root.add_child(center)

	var shell := _make_ornate_shell(Vector2(580, 600))
	center.add_child(shell)

	var body := _populate_shell_body(shell, 10)
	body.add_child(_make_title_header("SETTINGS"))
	body.add_child(_make_ornate_rule())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 14)
	scroll.add_child(vbox)

	_add_settings_section(vbox, "AUDIO", func(section: VBoxContainer) -> void:
		_master_slider = _add_volume_row(section, "Master", GameSettings.master_volume, _on_master_changed, true)
		_music_slider = _add_volume_row(section, "Music", GameSettings.music_volume, _on_music_changed, true)
		_sfx_slider = _add_volume_row(section, "SFX", GameSettings.sfx_volume, _on_sfx_changed, true)
	)

	_add_settings_section(vbox, "DISPLAY", func(section: VBoxContainer) -> void:
		var fs_row := HBoxContainer.new()
		fs_row.add_theme_constant_override("separation", 16)
		section.add_child(fs_row)
		fs_row.add_child(_make_label("Fullscreen", 15, C_TEXT))
		_fullscreen_check = CheckButton.new()
		_fullscreen_check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_fullscreen_check.button_pressed = GameSettings.is_fullscreen_active()
		_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
		_style_check(_fullscreen_check)
		fs_row.add_child(_fullscreen_check)
		section.add_child(_make_hint_label("Resolution: 1280 x 720 (scaled to screen)"))
		_fullscreen_embed_hint = _make_hint_label("")
		section.add_child(_fullscreen_embed_hint)
	)

	_add_settings_section(vbox, "CONTROLS", func(section: VBoxContainer) -> void:
		_add_control_row(section, "Active skills", "1 - 7")
		_add_control_row(section, "Inventory", "I")
		_add_control_row(section, "Safe attack", "Q")
		_add_control_row(section, "Wild attack", "W")
		_add_control_row(section, "Change weapon", "E")
		_add_control_row(section, "Basic attack", "Space")
		_add_control_row(section, "HP potion", "H")
		_add_control_row(section, "Pause", "Esc")
	)

	body.add_child(_make_ornate_rule())
	body.add_child(_make_menu_button("Back", _on_settings_back_pressed))


func _add_overlay(parent: Control) -> void:
	var dim := ColorRect.new()
	dim.color = C_OVERLAY
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(dim)


func _make_ornate_shell(size: Vector2) -> PanelContainer:
	var outer := PanelContainer.new()
	outer.custom_minimum_size = size
	var outer_sb := StyleBoxFlat.new()
	outer_sb.bg_color = C_PANEL_OUTER
	outer_sb.border_color = C_GOLD_DIM
	outer_sb.set_border_width_all(2)
	outer_sb.set_corner_radius_all(2)
	outer_sb.shadow_color = Color(0, 0, 0, 0.55)
	outer_sb.shadow_size = 10
	outer_sb.shadow_offset = Vector2(0, 4)
	outer_sb.content_margin_left = 6
	outer_sb.content_margin_right = 6
	outer_sb.content_margin_top = 6
	outer_sb.content_margin_bottom = 6
	outer.add_theme_stylebox_override("panel", outer_sb)

	var inner := PanelContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var inner_sb := StyleBoxFlat.new()
	inner_sb.bg_color = C_PANEL_INNER
	inner_sb.border_color = C_GOLD
	inner_sb.set_border_width_all(1)
	inner_sb.set_corner_radius_all(1)
	inner_sb.content_margin_left = 18
	inner_sb.content_margin_right = 18
	inner_sb.content_margin_top = 14
	inner_sb.content_margin_bottom = 14
	inner.add_theme_stylebox_override("panel", inner_sb)
	outer.add_child(inner)
	return outer


func _shell_inner(outer: PanelContainer) -> PanelContainer:
	return outer.get_child(0) as PanelContainer


func _populate_shell_body(outer: PanelContainer, separation: int) -> VBoxContainer:
	var inner := _shell_inner(outer)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", separation)
	inner.add_child(vbox)
	return vbox


func _make_title_header(text: String) -> Control:
	var wrap := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_HEADER
	sb.border_color = C_GOLD_DIM
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(1)
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	wrap.add_theme_stylebox_override("panel", sb)

	var title := _make_label(text, 28, C_GOLD_BRIGHT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wrap.add_child(title)
	return wrap


func _make_ornate_rule() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var left := ColorRect.new()
	left.custom_minimum_size = Vector2(0, 2)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.color = C_GOLD_DIM
	row.add_child(left)

	var gem := ColorRect.new()
	gem.custom_minimum_size = Vector2(10, 10)
	gem.color = C_GOLD
	row.add_child(gem)

	var right := ColorRect.new()
	right.custom_minimum_size = Vector2(0, 2)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.color = C_GOLD_DIM
	row.add_child(right)
	return row


func _add_settings_section(parent: VBoxContainer, title: String, build: Callable) -> void:
	var section_title := _make_label(title, 14, C_GOLD)
	section_title.add_theme_constant_override("outline_size", 2)
	section_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.65))
	parent.add_child(section_title)

	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_SECTION
	sb.border_color = C_GOLD_DIM
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	box.add_theme_stylebox_override("panel", sb)
	parent.add_child(box)

	var section := VBoxContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 10)
	box.add_child(section)
	build.call(section)


func _add_control_row(parent: VBoxContainer, action: String, keys: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var action_lbl := _make_label(action, 14, C_TEXT_DIM)
	action_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(action_lbl)

	var dots := _make_label(" ........ ", 14, C_GOLD_DIM)
	row.add_child(dots)

	var keys_lbl := _make_label(keys, 14, C_GOLD_BRIGHT)
	keys_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(keys_lbl)


func _make_label(text: String, size: int, color: Color = C_TEXT) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	if _font:
		lbl.add_theme_font_override("font", _font)
	return lbl


func _make_hint_label(text: String) -> Label:
	return _make_label(text, 13, C_TEXT_DIM)


func _make_menu_button(text: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = "  %s  " % text
	btn.custom_minimum_size = Vector2(0, 44)
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(cb)
	_style_button(btn)
	return btn


func _style_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = C_BTN
	normal.border_color = C_GOLD_DIM
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(1)
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4
	var hover := normal.duplicate()
	(hover as StyleBoxFlat).bg_color = C_BTN_HOVER
	(hover as StyleBoxFlat).border_color = C_GOLD
	var pressed := normal.duplicate()
	(pressed as StyleBoxFlat).bg_color = C_BTN_PRESSED
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", normal)
	btn.add_theme_color_override("font_color", C_GOLD_BRIGHT)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", C_TEXT_DIM)
	if _font:
		btn.add_theme_font_override("font", _font)
		btn.add_theme_font_size_override("font_size", 17)


func _style_check(chk: CheckButton) -> void:
	chk.add_theme_color_override("font_color", C_TEXT)
	chk.add_theme_color_override("font_hover_color", C_GOLD_BRIGHT)
	if _font:
		chk.add_theme_font_override("font", _font)


func _style_slider(slider: HSlider) -> void:
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.custom_minimum_size = Vector2(120, 18)

	var track := StyleBoxFlat.new()
	track.bg_color = C_SLIDER_TRACK
	track.border_color = C_GOLD_DIM
	track.set_border_width_all(1)
	track.set_corner_radius_all(1)
	track.content_margin_top = 4
	track.content_margin_bottom = 4

	var fill := StyleBoxFlat.new()
	fill.bg_color = C_SLIDER_FILL
	fill.set_corner_radius_all(1)

	var grabber := StyleBoxFlat.new()
	grabber.bg_color = C_GOLD_BRIGHT
	grabber.border_color = C_GOLD
	grabber.set_border_width_all(1)
	grabber.set_corner_radius_all(2)
	grabber.content_margin_left = 5
	grabber.content_margin_right = 5
	grabber.content_margin_top = 5
	grabber.content_margin_bottom = 5

	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	slider.add_theme_stylebox_override("grabber", grabber)


func _add_volume_row(
	parent: VBoxContainer,
	label: String,
	value: float,
	cb: Callable,
	with_pct: bool
) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var lbl := _make_label(label, 15, C_TEXT)
	lbl.custom_minimum_size = Vector2(78, 0)
	row.add_child(lbl)

	var slider := HSlider.new()
	_style_slider(slider)
	slider.value = value
	slider.value_changed.connect(cb)
	row.add_child(slider)

	if with_pct:
		var pct := _make_label(_pct_text(value), 14, C_GOLD)
		pct.custom_minimum_size = Vector2(42, 0)
		pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(pct)
		if label == "Master":
			_master_pct = pct
		elif label == "Music":
			_music_pct = pct
		elif label == "SFX":
			_sfx_pct = pct
		slider.value_changed.connect(func(v: float) -> void:
			pct.text = _pct_text(v)
		)

	return slider


func _pct_text(v: float) -> String:
	return "%d%%" % int(roundf(v * 100.0))


func _sync_settings_ui() -> void:
	if _master_slider:
		_master_slider.set_value_no_signal(GameSettings.master_volume)
		if _master_pct:
			_master_pct.text = _pct_text(GameSettings.master_volume)
	if _music_slider:
		_music_slider.set_value_no_signal(GameSettings.music_volume)
		if _music_pct:
			_music_pct.text = _pct_text(GameSettings.music_volume)
	if _sfx_slider:
		_sfx_slider.set_value_no_signal(GameSettings.sfx_volume)
		if _sfx_pct:
			_sfx_pct.text = _pct_text(GameSettings.sfx_volume)
	if _fullscreen_check:
		_fullscreen_check.set_pressed_no_signal(GameSettings.is_fullscreen_active())
		var embedded := not GameSettings.can_toggle_fullscreen()
		_fullscreen_check.disabled = embedded
		if _fullscreen_embed_hint:
			if embedded:
				_fullscreen_embed_hint.text = (
					"Fullscreen blocked while game is embedded in editor.\n"
					+ "Stop play (F8), open Game tab, uncheck Embed Game on Next Play, then F5."
				)
			else:
				_fullscreen_embed_hint.text = ""


func _on_fullscreen_toggled(on: bool) -> void:
	GameSettings.set_fullscreen(on)
	call_deferred("_sync_settings_ui")


func _on_master_changed(v: float) -> void:
	GameSettings.set_master_volume(v)


func _on_music_changed(v: float) -> void:
	GameSettings.set_music_volume(v)


func _on_sfx_changed(v: float) -> void:
	GameSettings.set_sfx_volume(v)
	var audio := get_node_or_null("/root/GameAudio")
	if audio:
		audio.play_chest_slot_land()


func _on_resume_pressed() -> void:
	close_pause(true)


func _on_pause_settings_pressed() -> void:
	_show_settings()


func _on_settings_back_pressed() -> void:
	GameSettings.save_settings()
	close_settings()


func _on_main_menu_pressed() -> void:
	GameState.save(GameState.current_slot)
	close_pause(false)
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)


func _input(event: InputEvent) -> void:
	if not is_pause_open() and not is_settings_open():
		return
	if event.is_action_pressed("ui_cancel"):
		if is_settings_open():
			close_settings()
		elif is_pause_open():
			close_pause(true)
		get_viewport().set_input_as_handled()
