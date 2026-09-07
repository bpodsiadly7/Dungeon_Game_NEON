extends CanvasLayer
## Pełnoekranowy ekran końca kampanii — brak krasnoludów w kolonii.

const MENU_SCENE := "res://main_menu.tscn"
const FONT_PATH := "res://MedievalSharp-Bold.ttf"

var _font: Font


func _ready() -> void:
	layer = 250
	process_mode = Node.PROCESS_MODE_ALWAYS
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)


func play() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.0, 0.0, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -300.0
	panel.offset_right = 300.0
	panel.offset_top = -170.0
	panel.offset_bottom = 170.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.03, 0.03, 0.97)
	sb.border_color = Color(0.75, 0.12, 0.08, 1.0)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.shadow_size = 12
	sb.shadow_color = Color(0, 0, 0, 0.65)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var title := _make_label("☠  CLAN FALLEN  ☠", 40, Color(0.92, 0.20, 0.15))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(_make_hsep())

	var body := _make_label(
		"No dwarfs remain.\nThe colony is lost.",
		22,
		Color(0.92, 0.86, 0.78)
	)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(body)

	var note := _make_label(
		"Your campaign save will be deleted.",
		16,
		Color(0.72, 0.68, 0.62)
	)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(note)

	vbox.add_child(_make_hsep())

	var btn := Button.new()
	btn.text = "Main Menu"
	btn.custom_minimum_size = Vector2(220, 48)
	btn.add_theme_font_size_override("font_size", 20)
	if _font:
		btn.add_theme_font_override("font", _font)
	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color = Color(0.18, 0.08, 0.06, 0.95)
	sb_n.border_color = Color(0.85, 0.35, 0.22)
	sb_n.set_border_width_all(2)
	sb_n.set_corner_radius_all(10)
	var sb_h := sb_n.duplicate() as StyleBoxFlat
	sb_h.bg_color = Color(0.28, 0.12, 0.08, 0.98)
	btn.add_theme_stylebox_override("normal", sb_n)
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_color_override("font_color", Color(1.0, 0.88, 0.72))
	vbox.add_child(btn)

	modulate = Color(1, 1, 1, 0)
	var fade := create_tween()
	fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade.tween_property(dim, "color:a", 0.88, 0.45)
	fade.parallel().tween_property(self, "modulate:a", 1.0, 0.35)

	await btn.pressed
	btn.disabled = true

	GameState.finalize_colony_defeat()
	get_tree().change_scene_to_file(MENU_SCENE)


func _make_label(text: String, size: int, col: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", col)
	if _font:
		lbl.add_theme_font_override("font", _font)
	return lbl


func _make_hsep() -> HSeparator:
	var s := HSeparator.new()
	s.add_theme_color_override("color", Color(0.45, 0.12, 0.08, 0.75))
	return s
