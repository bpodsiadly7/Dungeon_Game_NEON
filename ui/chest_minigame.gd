extends Control
class_name ChestMinigame

signal finished

const FONT_PATH := "res://MedievalSharp-Bold.ttf"
const BG_PATH := "res://treasures/chestminigame.png"
const POTION_ICONS := [
	preload("res://ikony/HpBottleIcon.png"),
	preload("res://ikony/HpBottleIcon2.png"),
	preload("res://ikony/HpBottleIcon3.png"),
]

const FACE_W := 460.0
const FACE_H := 520.0
const ICON_SIZE := 56.0
const SPIN_CYCLES := 11
const REEL_STAGGER := 0.38
const RESULT_HOLD_SEC := 0.55

# Normalized slot rects on chestminigame.png (x, y, w, h)
const SLOT_RECTS := [
	Rect2(0.145, 0.278, 0.205, 0.428),
	Rect2(0.398, 0.278, 0.205, 0.428),
	Rect2(0.651, 0.278, 0.205, 0.428),
]
const SLOT_X_NUDGES := [5.0, 0.0, -5.0]
const GLOW_WIDTH_RATIO := 0.96
const GLOW_HEIGHT_RATIO := 0.86

const FILLER_COLORS := [
	Color(1.0, 1.0, 1.0),
	Color(0.45, 0.75, 1.0),
	Color(0.75, 0.55, 0.95),
	Color(1.0, 0.85, 0.2),
	Color(0.30, 1.00, 0.85),
	Color(0.35, 0.95, 0.45),
	Color(0.85, 0.35, 0.35),
	Color(0.92, 0.78, 0.28),
]

var _reward: Dictionary = {}
var _active := false
var _started := false
var _finished := false
var _spinning := false
var _pending_reels := 0
var _reels: Array = []
var _machine_face: Control
var _hint_label: Label
var _result_label: Label
var _font: FontFile
var _bg_tex: Texture2D
var _bg_display_size := Vector2.ZERO
var _bg_offset := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 550
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = load(FONT_PATH) as FontFile
	_bg_tex = load(BG_PATH) as Texture2D
	_calc_bg_layout()
	_build_ui()
	set_process_input(true)


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


func _calc_bg_layout() -> void:
	if _bg_tex == null:
		_bg_display_size = Vector2(FACE_W, FACE_W)
		_bg_offset = Vector2(0.0, (FACE_H - FACE_W) * 0.5)
		return
	var tex_size := _bg_tex.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		_bg_display_size = Vector2(FACE_W, FACE_W)
		_bg_offset = Vector2(0.0, (FACE_H - FACE_W) * 0.5)
		return
	var scale := minf(FACE_W / tex_size.x, FACE_H / tex_size.y)
	_bg_display_size = tex_size * scale
	_bg_offset = Vector2(
		(FACE_W - _bg_display_size.x) * 0.5,
		(FACE_H - _bg_display_size.y) * 0.5
	)


func run(reward: Dictionary) -> void:
	_reward = reward
	_active = true
	_started = false
	_finished = false
	_spinning = false
	_pending_reels = 0
	_fit_to_viewport()
	await _wait_always(0.0)
	_fit_to_viewport()
	_reset_reels_idle()
	if _hint_label:
		_hint_label.text = "Tap the reels to spin!"
		_hint_label.visible = true
	if _result_label:
		_result_label.visible = false
	await finished


func _wait_always(sec: float) -> void:
	await get_tree().create_timer(sec, true).timeout


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	center.add_child(stack)

	var title := Label.new()
	title.text = "MYSTERY CHEST"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45))
	if _font:
		title.add_theme_font_override("font", _font)
	stack.add_child(title)

	_hint_label = Label.new()
	_hint_label.text = "Tap the reels to spin!"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 14)
	_hint_label.add_theme_color_override("font_color", Color(0.72, 0.68, 0.62))
	if _font:
		_hint_label.add_theme_font_override("font", _font)
	stack.add_child(_hint_label)

	_result_label = Label.new()
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", 20)
	_result_label.visible = false
	if _font:
		_result_label.add_theme_font_override("font", _font)
	stack.add_child(_result_label)

	var face_wrap := CenterContainer.new()
	face_wrap.custom_minimum_size = Vector2(FACE_W, FACE_H)
	stack.add_child(face_wrap)

	_machine_face = Control.new()
	_machine_face.custom_minimum_size = Vector2(FACE_W, FACE_H)
	_machine_face.mouse_filter = Control.MOUSE_FILTER_STOP
	face_wrap.add_child(_machine_face)

	var bg := TextureRect.new()
	bg.texture = _bg_tex
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bg.custom_minimum_size = Vector2(FACE_W, FACE_H)
	bg.set_anchors_preset(Control.PRESET_CENTER)
	bg.offset_left = -FACE_W * 0.5
	bg.offset_right = FACE_W * 0.5
	bg.offset_top = -FACE_H * 0.5
	bg.offset_bottom = FACE_H * 0.5
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_machine_face.add_child(bg)

	for i in SLOT_RECTS.size():
		_reels.append(_create_reel(i))


func _slot_pixel_rect(slot_idx: int) -> Rect2:
	var norm: Rect2 = SLOT_RECTS[slot_idx]
	return Rect2(
		_bg_offset.x + norm.position.x * _bg_display_size.x,
		_bg_offset.y + norm.position.y * _bg_display_size.y,
		norm.size.x * _bg_display_size.x,
		norm.size.y * _bg_display_size.y
	)


func _create_reel(slot_idx: int) -> Dictionary:
	var area := _slot_pixel_rect(slot_idx)
	var viewport := Control.new()
	viewport.position = area.position
	viewport.size = area.size
	viewport.custom_minimum_size = area.size
	viewport.clip_contents = true
	viewport.mouse_filter = Control.MOUSE_FILTER_STOP
	_machine_face.add_child(viewport)

	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.offset_left = 0.0
	host.offset_top = 0.0
	host.offset_right = 0.0
	host.offset_bottom = 0.0
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(host)

	return {"viewport": viewport, "host": host, "slot_idx": slot_idx}


func _place_in_reel(reel: Dictionary, widget: Control) -> void:
	var slot_sz: Vector2 = reel.viewport.size
	var sz := widget.custom_minimum_size
	if sz == Vector2.ZERO:
		sz = widget.size
	var nudge: float = SLOT_X_NUDGES[reel.slot_idx]
	widget.position = Vector2(
		(slot_sz.x - sz.x) * 0.5 + nudge,
		(slot_sz.y - sz.y) * 0.5
	)
	widget.pivot_offset = sz * 0.5
	reel.host.add_child(widget)


func _reset_reels_idle() -> void:
	for reel in _reels:
		_clear_slot(reel)
		var idle := _make_symbol_widget(_idle_symbol(), reel)
		idle.modulate.a = 0.35
		_place_in_reel(reel, idle)
		if idle is ShimmerColorSymbol:
			idle.call_deferred("run_idle_pulse")


func _clear_slot(reel: Dictionary) -> void:
	for child in reel.host.get_children():
		if child is ShimmerColorSymbol:
			(child as ShimmerColorSymbol).stop_effects()
		child.queue_free()


func _idle_symbol() -> Dictionary:
	return {"type": "color", "color": Color(0.55, 0.48, 0.38, 0.5)}


func _final_symbol_for_reel(reel_idx: int) -> Dictionary:
	if _reward.get("kind") == "heal":
		var icons: Array = _reward.get("icons", POTION_ICONS)
		var tex: Texture2D = icons[reel_idx % icons.size()] as Texture2D
		return {"type": "icon", "icon": tex}
	var color: Color = _reward.get("color", Color.WHITE)
	return {"type": "color", "color": color}


func _random_filler_symbol() -> Dictionary:
	if _reward.get("kind") == "heal" and randf() < 0.35:
		return {"type": "icon", "icon": POTION_ICONS[randi() % POTION_ICONS.size()]}
	return {"type": "color", "color": FILLER_COLORS[randi() % FILLER_COLORS.size()]}


func _glow_size_for_reel(reel: Dictionary) -> Vector2:
	var slot_sz: Vector2 = reel.viewport.size
	return Vector2(slot_sz.x * GLOW_WIDTH_RATIO, slot_sz.y * GLOW_HEIGHT_RATIO)


func _make_color_glow(color: Color, reel: Dictionary) -> ShimmerColorSymbol:
	var glow := ShimmerColorSymbol.new(_glow_size_for_reel(reel))
	glow.set_color(color)
	return glow


func _make_symbol_widget(sym: Dictionary, reel: Dictionary) -> Control:
	if sym.get("type") == "icon":
		var icon := TextureRect.new()
		icon.texture = sym.get("icon") as Texture2D
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return icon
	return _make_color_glow(sym.get("color", Color.WHITE), reel)


func _flash_interval(cycle: int, total: int) -> float:
	var t := float(cycle) / maxf(float(total), 1.0)
	return lerpf(0.09, 0.30, t * t)


func _input(event: InputEvent) -> void:
	if not _active or _finished or _spinning:
		return
	if not _started:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_begin_spin()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_accept"):
			_begin_spin()
			get_viewport().set_input_as_handled()


func _begin_spin() -> void:
	if _started or _spinning:
		return
	_started = true
	_spinning = true
	var audio := get_node_or_null("/root/GameAudio")
	if audio:
		audio.play_chest_event()
	if _hint_label:
		_hint_label.text = "Spinning..."

	_pending_reels = _reels.size()
	for i in _reels.size():
		_spin_reel_flash(_reels[i], i)

	while _pending_reels > 0:
		await _wait_always(0.03)

	_spinning = false
	_show_result()
	await _wait_always(RESULT_HOLD_SEC)
	_finish()


func _spin_reel_flash(reel: Dictionary, reel_idx: int) -> void:
	if reel_idx > 0:
		await _wait_always(reel_idx * REEL_STAGGER)

	var total_cycles := SPIN_CYCLES + reel_idx * 2
	for cycle in total_cycles:
		var sym := _random_filler_symbol()
		var hold := _flash_interval(cycle, total_cycles)
		await _show_symbol_flash(reel, sym, hold, false)

	var final_sym := _final_symbol_for_reel(reel_idx)
	await _show_symbol_flash(reel, final_sym, 0.38, true)
	_pending_reels -= 1


func _show_symbol_flash(reel: Dictionary, sym: Dictionary, hold_sec: float, is_final: bool) -> void:
	_clear_slot(reel)
	var is_color: bool = str(sym.get("type", "")) != "icon"
	var widget := _make_symbol_widget(sym, reel)
	widget.modulate.a = 0.0
	_place_in_reel(reel, widget)

	if is_color:
		await _animate_color_flash(widget as ShimmerColorSymbol, hold_sec, is_final)
	else:
		await _animate_icon_flash(widget, hold_sec, is_final)


func _animate_color_flash(widget: ShimmerColorSymbol, hold_sec: float, is_final: bool) -> void:
	widget.scale = Vector2(0.12, 0.42)
	widget.rotation = deg_to_rad(randf_range(-10.0, 10.0))

	var pop_dur := 0.08 if not is_final else 0.11
	var settle_dur := 0.06 if not is_final else 0.09
	var out_dur := 0.065

	var tw_pop := create_tween()
	tw_pop.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw_pop.set_parallel(true)
	tw_pop.set_trans(Tween.TRANS_BACK)
	tw_pop.set_ease(Tween.EASE_OUT)
	tw_pop.tween_property(widget, "scale", Vector2(1.2, 1.12) if not is_final else Vector2(1.24, 1.14), pop_dur)
	tw_pop.tween_property(widget, "modulate:a", 1.0, pop_dur * 0.55)
	tw_pop.tween_property(widget, "rotation", 0.0, pop_dur)
	tw_pop.tween_property(widget, "modulate", Color(1.45, 1.45, 1.45, 1.0), pop_dur * 0.45)
	await _wait_always(pop_dur)

	widget.run_shimmer_sweep(0.13 if not is_final else 0.24)

	var tw_settle := create_tween()
	tw_settle.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw_settle.set_parallel(true)
	tw_settle.set_trans(Tween.TRANS_QUAD)
	tw_settle.set_ease(Tween.EASE_OUT)
	tw_settle.tween_property(widget, "scale", Vector2.ONE, settle_dur)
	tw_settle.tween_property(widget, "modulate", Color.WHITE, settle_dur)
	await _wait_always(settle_dur)

	if is_final:
		widget.run_idle_pulse()
		return

	var visible_time := maxf(hold_sec - pop_dur - settle_dur, 0.015)
	await _wait_always(visible_time)

	if not is_instance_valid(widget):
		return

	var tw_out := create_tween()
	tw_out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw_out.set_parallel(true)
	tw_out.set_trans(Tween.TRANS_BACK)
	tw_out.set_ease(Tween.EASE_IN)
	tw_out.tween_property(widget, "scale", Vector2(1.34, 1.22), out_dur)
	tw_out.tween_property(widget, "modulate:a", 0.0, out_dur)
	widget.stop_effects()
	await _wait_always(out_dur)


func _animate_icon_flash(widget: Control, hold_sec: float, is_final: bool) -> void:
	widget.scale = Vector2(0.72, 0.72) if not is_final else Vector2(0.86, 0.86)

	var fade_in := minf(hold_sec * 0.38, 0.12)
	var fade_out := minf(hold_sec * 0.38, 0.12)
	var visible_time := maxf(hold_sec - fade_in - fade_out, 0.02)

	_tween_symbol(widget, 1.0, Vector2.ONE, fade_in)
	await _wait_always(fade_in)

	if is_final:
		widget.scale = Vector2.ONE
		widget.modulate.a = 1.0
		return

	await _wait_always(visible_time)

	if not is_instance_valid(widget):
		return

	_tween_symbol(widget, 0.0, widget.scale, fade_out)
	await _wait_always(fade_out)


func _tween_symbol(widget: Control, alpha: float, target_scale: Vector2, duration: float) -> void:
	if duration <= 0.0:
		widget.modulate.a = alpha
		widget.scale = target_scale
		return
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_QUAD)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(widget, "modulate:a", alpha, duration)
	tw.tween_property(widget, "scale", target_scale, duration)


func _show_result() -> void:
	if _result_label == null:
		return
	if _reward.get("kind") == "heal":
		_result_label.text = "FULL HEAL!"
		_result_label.add_theme_color_override("font_color", Color(0.45, 0.95, 0.55))
	elif _reward.has("item"):
		var item: Dictionary = _reward.get("item", {})
		_result_label.text = str(item.get("name", "Treasure"))
		var col: Color = _reward.get("color", Color.WHITE)
		_result_label.add_theme_color_override("font_color", col)
	else:
		_result_label.text = "Treasure!"
		_result_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45))
	_result_label.visible = true
	if _hint_label:
		_hint_label.visible = false


func _finish() -> void:
	if _finished:
		return
	_finished = true
	_active = false
	finished.emit()
