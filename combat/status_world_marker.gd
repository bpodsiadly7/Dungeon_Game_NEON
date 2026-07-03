extends Node2D
class_name StatusWorldMarker

const ICON_PX := 54.0

var _icon: Sprite2D
var _turns_lbl: Label
var _pulse_tween: Tween
var _icon_rest_scale := Vector2.ONE


func _ready() -> void:
	z_index = 12
	_icon = Sprite2D.new()
	_icon.centered = true
	_icon.position = Vector2.ZERO
	add_child(_icon)

	_turns_lbl = Label.new()
	_turns_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turns_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_turns_lbl.position = Vector2(-24, ICON_PX * 0.50)
	_turns_lbl.custom_minimum_size = Vector2(48, 18)
	_turns_lbl.add_theme_font_size_override("font_size", 17)
	_turns_lbl.add_theme_color_override("font_color", Color(0.95, 0.82, 0.78))
	_turns_lbl.add_theme_color_override("font_outline_color", Color(0.25, 0.02, 0.02))
	_turns_lbl.add_theme_constant_override("outline_size", 3)
	add_child(_turns_lbl)
	visible = false


func set_font(font: Font) -> void:
	if font and _turns_lbl:
		_turns_lbl.add_theme_font_override("font", font)


func show_bleed(turns_left: int, icon_tex: Texture2D) -> void:
	if icon_tex == null or turns_left <= 0:
		hide_marker()
		return
	visible = true
	_icon.texture = icon_tex
	_fit_icon_scale(icon_tex)
	_turns_lbl.text = str(turns_left)
	_start_pulse()


func hide_marker() -> void:
	visible = false
	_stop_pulse()
	if _icon:
		_icon.texture = null
	if _turns_lbl:
		_turns_lbl.text = ""


func _fit_icon_scale(tex: Texture2D) -> void:
	var tex_h := maxf(float(tex.get_height()), 1.0)
	var s := ICON_PX / tex_h
	_icon_rest_scale = Vector2(s, s)
	_icon.scale = _icon_rest_scale
	_icon.modulate = Color(1, 1, 1, 1)


func _start_pulse() -> void:
	_stop_pulse()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_icon, "scale", _icon_rest_scale * 1.14, 0.52)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.parallel().tween_property(_icon, "modulate", Color(1.15, 0.55, 0.5, 1.0), 0.52)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(_icon, "scale", _icon_rest_scale, 0.52)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.parallel().tween_property(_icon, "modulate", Color(1, 1, 1, 1), 0.52)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null
	if _icon:
		_icon.scale = _icon_rest_scale
		_icon.modulate = Color(1, 1, 1, 1)
