extends Control
## Pulsująca ikona „near death” na środku ekranu.

const _ICON_PATH := "res://ikony/neardeath_icon.png"
const _ICON_SIZE := Vector2(168, 168)

var _icon: TextureRect
var _pulse: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon = TextureRect.new()
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.texture = load(_ICON_PATH) as Texture2D
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.custom_minimum_size = _ICON_SIZE
	_icon.size = _ICON_SIZE
	_icon.pivot_offset = _ICON_SIZE * 0.5
	_icon.modulate = Color(1.0, 0.35, 0.3, 0.0)
	_icon.scale = Vector2.ONE
	add_child(_icon)
	visible = false
	_layout_center()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_center()


func _layout_center() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var rect := vp.get_visible_rect()
	size = rect.size
	position = rect.position
	if _icon:
		# position = lewy górny róg; bez tego offsetu ikona „ucieka” w prawo/dół.
		_icon.position = (rect.size - _ICON_SIZE) * 0.5


func set_warning_active(active: bool) -> void:
	if active:
		_layout_center()
		visible = true
		_start_pulse()
	else:
		_stop_pulse()
		visible = false


func _start_pulse() -> void:
	_stop_pulse()
	if _icon == null:
		return
	_icon.modulate = Color(1.0, 0.4, 0.32, 0.55)
	_icon.scale = Vector2(0.92, 0.92)
	_pulse = create_tween()
	_pulse.set_loops()
	_pulse.tween_property(_icon, "scale", Vector2(1.14, 1.14), 0.42)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pulse.parallel().tween_property(_icon, "modulate:a", 0.95, 0.42)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pulse.tween_property(_icon, "scale", Vector2(0.9, 0.9), 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_pulse.parallel().tween_property(_icon, "modulate:a", 0.42, 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _stop_pulse() -> void:
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	_pulse = null
	if _icon:
		_icon.scale = Vector2.ONE
		_icon.modulate.a = 0.0
