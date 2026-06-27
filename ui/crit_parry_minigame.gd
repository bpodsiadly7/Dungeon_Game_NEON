extends Control
class_name CritParryMinigame

signal completed(success: bool)

const FONT_PATH := "res://MedievalSharp-Bold.ttf"
const CURSOR_PATH := "res://ikony/cursor.png"
const BG_PATH := "res://treasures/critminigame.png"
const CURSOR_DISPLAY_SCALE := 0.34

const FACE_SIZE := 360.0
const SLOT_RADIUS := 118.0
const ROT_SPEED_MIN := 5.0
const ROT_SPEED_MAX := 12.0
const TIMEOUT_SEC := 3.4
const HIT_TOLERANCE_RAD := deg_to_rad(24.0)
const SWORD_ROT_OFFSET := PI * 0.75

# Godot: 0 = prawo, PI/2 = dół, PI = lewo, -PI/2 = góra
const CARDINAL_ANGLES := [-PI * 0.5, 0.0, PI * 0.5, PI]

var _active := false
var _finished := false
var _angle := 0.0
var _target_slot := 0
var _ring_face: Control
var _glow_marker: PanelContainer
var _sword: TextureRect
var _result_label: Label
var _timeout_left := TIMEOUT_SEC
var _font: FontFile
var _sword_tex: Texture2D
var _bg_tex: Texture2D
var _rot_speed := ROT_SPEED_MIN


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 550
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = load(FONT_PATH) as FontFile
	_sword_tex = _build_sword_texture()
	_bg_tex = load(BG_PATH) as Texture2D
	_build_ui()
	set_process(false)


func _enter_tree() -> void:
	_fit_to_viewport()
	var vp := get_viewport()
	if vp and not vp.size_changed.is_connected(_fit_to_viewport):
		vp.size_changed.connect(_fit_to_viewport)


func _exit_tree() -> void:
	var vp := get_viewport()
	if vp and vp.size_changed.is_connected(_fit_to_viewport):
		vp.size_changed.disconnect(_fit_to_viewport)


func _fit_to_viewport() -> void:
	var vp := get_viewport_rect().size
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = vp.x
	offset_bottom = vp.y
	position = Vector2.ZERO
	size = vp


func run(rot_speed: float = ROT_SPEED_MIN) -> bool:
	_rot_speed = maxf(rot_speed, 0.1)
	_fit_to_viewport()
	await get_tree().process_frame
	_fit_to_viewport()
	_pick_target_slot()
	_angle = 0.0
	_active = true
	_finished = false
	_timeout_left = TIMEOUT_SEC
	_update_sword_transform()
	_place_glow_marker()
	if _result_label:
		_result_label.visible = false
	set_process(true)
	var ok: bool = await completed
	return ok


func _build_sword_texture() -> Texture2D:
	var src := load(CURSOR_PATH) as Texture2D
	if src == null:
		return null
	var img := src.get_image()
	if img == null or img.is_empty():
		return src
	var w := maxi(1, int(round(float(img.get_width()) * CURSOR_DISPLAY_SCALE)))
	var h := maxi(1, int(round(float(img.get_height()) * CURSOR_DISPLAY_SCALE)))
	img = img.duplicate()
	img.resize(w, h, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.76)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	center.add_child(stack)

	var title := Label.new()
	title.text = "CRITICAL BLOW!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.95, 0.45, 0.35))
	if _font:
		title.add_theme_font_override("font", _font)
	stack.add_child(title)

	var hint := Label.new()
	hint.text = "Stop the blade on the glowing rune — full block on success!"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.72, 0.68, 0.62))
	if _font:
		hint.add_theme_font_override("font", _font)
	stack.add_child(hint)

	_result_label = Label.new()
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", 20)
	_result_label.visible = false
	if _font:
		_result_label.add_theme_font_override("font", _font)
	stack.add_child(_result_label)

	var ring_wrap := CenterContainer.new()
	ring_wrap.custom_minimum_size = Vector2(FACE_SIZE, FACE_SIZE)
	stack.add_child(ring_wrap)

	_ring_face = Control.new()
	_ring_face.custom_minimum_size = Vector2(FACE_SIZE, FACE_SIZE)
	_ring_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring_wrap.add_child(_ring_face)

	var bg := TextureRect.new()
	bg.texture = _bg_tex
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bg.custom_minimum_size = Vector2(FACE_SIZE, FACE_SIZE)
	bg.set_anchors_preset(Control.PRESET_CENTER)
	bg.offset_left = -FACE_SIZE * 0.5
	bg.offset_right = FACE_SIZE * 0.5
	bg.offset_top = -FACE_SIZE * 0.5
	bg.offset_bottom = FACE_SIZE * 0.5
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring_face.add_child(bg)

	_glow_marker = PanelContainer.new()
	_glow_marker.custom_minimum_size = Vector2(54, 54)
	_glow_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glow_sb := StyleBoxFlat.new()
	glow_sb.bg_color = Color(0.28, 0.92, 0.40, 0.55)
	glow_sb.border_color = Color(0.55, 1.0, 0.62, 0.95)
	glow_sb.set_border_width_all(2)
	glow_sb.set_corner_radius_all(27)
	glow_sb.shadow_color = Color(0.2, 0.9, 0.35, 0.65)
	glow_sb.shadow_size = 10
	_glow_marker.add_theme_stylebox_override("panel", glow_sb)
	_ring_face.add_child(_glow_marker)

	_sword = TextureRect.new()
	_sword.texture = _sword_tex
	_sword.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sword.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sword.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _sword_tex:
		var sz := _sword_tex.get_size()
		_sword.custom_minimum_size = sz
		_sword.pivot_offset = sz * 0.5
	_ring_face.add_child(_sword)


func _place_glow_marker() -> void:
	if _glow_marker == null or _ring_face == null:
		return
	var center := _ring_center()
	var angle: float = _target_angle()
	var pos := center + Vector2(cos(angle), sin(angle)) * SLOT_RADIUS
	var half := _glow_marker.custom_minimum_size * 0.5
	_glow_marker.position = pos - half
	_glow_marker.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _pick_target_slot() -> void:
	_target_slot = randi() % 4


func _ring_center() -> Vector2:
	return _ring_face.size * 0.5


func _target_angle() -> float:
	return CARDINAL_ANGLES[_target_slot]


func _update_sword_transform() -> void:
	if _sword == null or _ring_face == null:
		return
	var center := _ring_center()
	var orbit := Vector2(cos(_angle), sin(_angle)) * SLOT_RADIUS
	var pos := center + orbit
	if _sword_tex:
		_sword.pivot_offset = _sword_tex.get_size() * 0.5
	_sword.position = pos - _sword.pivot_offset
	_sword.rotation = _angle + SWORD_ROT_OFFSET


func _process(delta: float) -> void:
	if not _active or _finished:
		return
	_timeout_left -= delta
	if _timeout_left <= 0.0:
		_finish(false)
		return
	_angle = fmod(_angle + _rot_speed * delta, TAU)
	_update_sword_transform()
	if _glow_marker:
		var pulse := 0.78 + 0.22 * sin(Time.get_ticks_msec() * 0.009)
		_glow_marker.modulate = Color(1.0, 1.0, 1.0, pulse)


func _input(event: InputEvent) -> void:
	if not _active or _finished:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_attempt_parry()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_attempt_parry()
		get_viewport().set_input_as_handled()


func _attempt_parry() -> void:
	var diff := absf(wrapf(_angle - _target_angle(), -PI, PI))
	_finish(diff <= HIT_TOLERANCE_RAD)


func _finish(success: bool) -> void:
	if _finished:
		return
	_finished = true
	_active = false
	set_process(false)
	var audio := get_node_or_null("/root/GameAudio")
	if audio:
		if success:
			audio.play_parry_success()
		else:
			audio.play_parry_fail()
	if _result_label:
		_result_label.text = "PARRIED!" if success else "MISSED!"
		_result_label.add_theme_color_override("font_color",
			Color(0.45, 0.95, 0.55) if success else Color(0.95, 0.4, 0.35))
		_result_label.visible = true
	await get_tree().create_timer(0.28, true).timeout
	completed.emit(success)
