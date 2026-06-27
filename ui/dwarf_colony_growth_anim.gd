extends CanvasLayer
## Licznik „Dwarfs: N” — najpierw komunikat, potem animacja w górę / w dół.

const FONT_PATH := "res://MedievalSharp-Bold.ttf"
const STEP_SEC := 0.68
const INTRO_HOLD_SEC := 1.55
const INTRO_FADE_SEC := 0.45
const COUNT_FADE_SEC := 0.32

const MSG_LOSS := "Another hero has died."
const MSG_GROWTH := "New warriors report for duty."

const COLOR_GROWTH := Color(0.98, 0.88, 0.55)
const COLOR_LOSS := Color(1.0, 0.52, 0.42)
const COLOR_INTRO := Color(0.94, 0.90, 0.82)

var _font: Font
var _dim: ColorRect
var _intro_label: Label
var _label: Label


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)

	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.02, 0.01, 0.0, 0.0)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	_intro_label = _make_centered_label(28, COLOR_INTRO, -118.0, -22.0)
	add_child(_intro_label)

	_label = _make_centered_label(52, COLOR_GROWTH, -48.0, 48.0)
	_label.add_theme_constant_override("outline_size", 8)
	add_child(_label)


func _make_centered_label(font_size: int, col: Color, top_off: float, bottom_off: float) -> Label:
	var lbl := Label.new()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_CENTER)
	lbl.offset_left = -360.0
	lbl.offset_right = 360.0
	lbl.offset_top = top_off
	lbl.offset_bottom = bottom_off
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.0, 0.92))
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _font:
		lbl.add_theme_font_override("font", _font)
	lbl.modulate = Color(1, 1, 1, 0)
	return lbl


func play(from_count: int, to_count: int) -> void:
	if to_count == from_count:
		queue_free()
		return

	var is_loss := to_count < from_count
	var accent := COLOR_LOSS if is_loss else COLOR_GROWTH
	_label.add_theme_color_override("font_color", accent)
	_dim.color = Color(0.08, 0.01, 0.01, 0.0) if is_loss else Color(0.02, 0.01, 0.0, 0.0)

	_intro_label.text = MSG_LOSS if is_loss else MSG_GROWTH
	_label.text = "Dwarfs: %d" % from_count
	_label.scale = Vector2(0.92, 0.92)

	await _fade_dim_in()
	await _show_intro()
	await get_tree().create_timer(INTRO_HOLD_SEC).timeout
	await _hide_intro()
	await get_tree().create_timer(0.28).timeout
	await _show_counter(from_count)

	if is_loss:
		for n in range(from_count - 1, to_count - 1, -1):
			_label.text = "Dwarfs: %d" % n
			_play_count_tick_sfx(true)
			await _punch_label(true)
			if n > to_count:
				await get_tree().create_timer(STEP_SEC).timeout
	else:
		for n in range(from_count + 1, to_count + 1):
			_label.text = "Dwarfs: %d" % n
			_play_count_tick_sfx(false)
			await _punch_label(false)
			if n < to_count:
				await get_tree().create_timer(STEP_SEC).timeout

	await get_tree().create_timer(0.55).timeout
	await _fade_all_out()
	queue_free()


func _fade_dim_in() -> void:
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_dim, "color:a", 0.62, INTRO_FADE_SEC)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished


func _show_intro() -> void:
	_intro_label.scale = Vector2(0.94, 0.94)
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_intro_label, "modulate:a", 1.0, INTRO_FADE_SEC)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_intro_label, "scale", Vector2.ONE, INTRO_FADE_SEC)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished


func _hide_intro() -> void:
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_intro_label, "modulate:a", 0.0, 0.32)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished


func _show_counter(from_count: int) -> void:
	_label.text = "Dwarfs: %d" % from_count
	_label.modulate = Color(1, 1, 1, 0)
	_label.scale = Vector2(0.92, 0.92)
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_label, "modulate:a", 1.0, COUNT_FADE_SEC)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_label, "scale", Vector2.ONE, COUNT_FADE_SEC)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished


func _fade_all_out() -> void:
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_dim, "color:a", 0.0, 0.38)
	tw.parallel().tween_property(_label, "modulate:a", 0.0, 0.38)
	await tw.finished


func _play_count_tick_sfx(is_loss: bool) -> void:
	var audio := get_node_or_null("/root/GameAudio")
	if audio == null:
		return
	if is_loss:
		audio.play_colony_loss_tick()
	else:
		audio.play_colony_growth_tick()


func _punch_label(is_loss: bool) -> void:
	_label.scale = Vector2.ONE
	var punch := create_tween()
	punch.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var peak := Vector2(0.9, 0.9) if is_loss else Vector2(1.1, 1.1)
	punch.tween_property(_label, "scale", peak, 0.14)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	punch.tween_property(_label, "scale", Vector2.ONE, 0.18)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await punch.finished
