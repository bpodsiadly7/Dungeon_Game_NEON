extends RefCounted
class_name FloatingDamageNumbers
## Unoszące się liczby obrażeń — wywoływane z Main.show_damage_popup().

const _TIER_MED := 10
const _TIER_HIGH := 22
const _TIER_BRUTAL := 40


static func spawn(
	fx_root: Control,
	cam: Camera2D,
	target: Node2D,
	text: String,
	kind: String,
	font: Font
) -> void:
	if fx_root == null or target == null or not is_instance_valid(target):
		return
	if not fx_root.visible:
		fx_root.visible = true

	var style := _style_for(text, kind)
	var start_pos := _screen_pos_for(target, cam, fx_root)
	var drift_x := randf_range(-style.drift, style.drift)
	var rise := style.rise + randf_range(-10.0, 14.0)
	var end_pos := start_pos + Vector2(drift_x, -rise)

	var outer := Control.new()
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.z_index = 300
	outer.position = start_pos
	outer.modulate = Color(1, 1, 1, 1)
	fx_root.add_child(outer)

	var inner := Control.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.scale = Vector2(0.2, 0.2)
	outer.add_child(inner)

	var half := _build_labels(inner, text, kind, style, font)
	inner.pivot_offset = half

	var tree := fx_root.get_tree()
	if tree == null:
		outer.queue_free()
		return

	var pop := tree.create_tween()
	pop.tween_property(inner, "scale", Vector2.ONE * style.pop_peak, 0.08)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(inner, "scale", Vector2.ONE * style.rest_scale, 0.1)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	if style.shake > 0.0:
		var shake_tw := tree.create_tween()
		shake_tw.tween_method(
			func(t: float) -> void:
				inner.position.x = sin(t * 44.0) * style.shake,
			0.0, 1.0, 0.24
		)

	var move := tree.create_tween()
	move.tween_property(outer, "position", end_pos, style.duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	move.parallel().tween_property(outer, "modulate:a", 0.0, style.fade_from)\
		.set_delay(maxf(0.0, style.duration - style.fade_from))\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	move.parallel().tween_property(inner, "scale", Vector2.ONE * style.end_scale, style.duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	move.finished.connect(func() -> void:
		if is_instance_valid(outer):
			outer.queue_free()
	)


class _PopupStyle:
	var font_size: int = 40
	var main_color: Color = Color(1.0, 0.22, 0.18)
	var outline_color: Color = Color(0.35, 0.0, 0.02)
	var outline_size: int = 10
	var glow_color: Color = Color(0.85, 0.05, 0.05, 0.55)
	var pop_peak: float = 1.45
	var rest_scale: float = 1.0
	var end_scale: float = 1.12
	var rise: float = 72.0
	var duration: float = 0.82
	var fade_from: float = 0.38
	var drift: float = 12.0
	var shake: float = 0.0


static func _style_for(text: String, kind: String) -> _PopupStyle:
	var s := _PopupStyle.new()
	var amount := _parse_amount(text)

	if kind == "miss":
		s.font_size = 34
		s.main_color = Color(0.72, 0.72, 0.78)
		s.outline_color = Color(0.15, 0.15, 0.18)
		s.outline_size = 6
		s.glow_color = Color(0.4, 0.4, 0.45, 0.25)
		s.pop_peak = 1.15
		s.rise = 48.0
		s.duration = 0.65
		s.drift = 6.0
		return s

	if kind == "heal":
		s.font_size = 38
		s.main_color = Color(0.45, 1.0, 0.55)
		s.outline_color = Color(0.05, 0.28, 0.08)
		s.glow_color = Color(0.2, 0.75, 0.35, 0.4)
		s.pop_peak = 1.25
		s.rise = 58.0
		s.duration = 0.75
		s.drift = 8.0
		return s

	if kind == "crit":
		s.font_size = 58
		s.main_color = Color(1.0, 0.92, 0.35)
		s.outline_color = Color(0.45, 0.08, 0.0)
		s.outline_size = 12
		s.glow_color = Color(1.0, 0.35, 0.1, 0.75)
		s.pop_peak = 1.75
		s.rest_scale = 1.08
		s.end_scale = 1.28
		s.rise = 95.0
		s.duration = 0.95
		s.shake = 5.0
		s.drift = 18.0
		return s

	var tier := _tier_for_amount(amount)
	match tier:
		0:
			s.font_size = 36
			s.pop_peak = 1.32
			s.rise = 62.0
		1:
			s.font_size = 44
			s.main_color = Color(1.0, 0.28, 0.2)
			s.pop_peak = 1.48
			s.rise = 74.0
			s.drift = 14.0
		2:
			s.font_size = 52
			s.main_color = Color(1.0, 0.18, 0.12)
			s.outline_size = 11
			s.pop_peak = 1.62
			s.rest_scale = 1.05
			s.end_scale = 1.18
			s.rise = 86.0
			s.shake = 3.0
			s.drift = 16.0
		3:
			s.font_size = 64
			s.main_color = Color(1.0, 0.12, 0.08)
			s.outline_color = Color(0.55, 0.0, 0.0)
			s.outline_size = 13
			s.glow_color = Color(0.95, 0.0, 0.0, 0.85)
			s.pop_peak = 1.85
			s.rest_scale = 1.1
			s.end_scale = 1.32
			s.rise = 108.0
			s.duration = 1.05
			s.shake = 7.0
			s.drift = 22.0

	return s


static func _build_labels(
	parent: Control,
	text: String,
	kind: String,
	style: _PopupStyle,
	font: Font
) -> Vector2:
	var amount := _parse_amount(text)
	var display := text
	if amount > 0 and (kind == "hit" or kind == "crit"):
		display = str(amount)

	var half := _measure_text(display, font, style.font_size) * 0.5
	var box := half * 2.0 + Vector2(16, 12)

	var glow := _make_label(display, style.font_size + 8, style.glow_color, font, 0, box)
	glow.position = -half + Vector2(-4, 3)
	parent.add_child(glow)

	var outline := _make_label(display, style.font_size, style.outline_color, font, style.outline_size, box)
	outline.position = -half
	parent.add_child(outline)

	var main := _make_label(
		display, style.font_size, style.main_color, font, maxi(2, style.outline_size - 4), box
	)
	main.position = -half
	parent.add_child(main)

	return half


static func _make_label(
	text: String,
	font_size: int,
	color: Color,
	font: Font,
	outline_size: int,
	box: Vector2
) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size = box
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.modulate = color
	if font:
		lbl.add_theme_font_override("font", font)
	lbl.add_theme_font_size_override("font_size", font_size)
	if outline_size > 0:
		lbl.add_theme_constant_override("outline_size", outline_size)
		lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.0, 0.0, 0.95))
	return lbl


static func _measure_text(text: String, font: Font, font_size: int) -> Vector2:
	if font:
		return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	return Vector2(float(text.length()) * float(font_size) * 0.52, float(font_size) * 1.15)


static func _screen_pos_for(target: Node2D, _cam: Camera2D, fx_root: Control) -> Vector2:
	var canvas_pt := target.get_global_transform_with_canvas().origin
	if target is Sprite2D:
		canvas_pt = (target as Sprite2D).get_global_transform_with_canvas().origin
	elif target.has_node("Sprite2D"):
		var spr := target.get_node("Sprite2D") as Sprite2D
		if spr:
			canvas_pt = spr.get_global_transform_with_canvas().origin

	var local := fx_root.get_global_transform_with_canvas().affine_inverse() * canvas_pt
	return local + Vector2(0, -36)


static func _parse_amount(text: String) -> int:
	var digits := ""
	for i in text.length():
		var c := text[i]
		if c >= "0" and c <= "9":
			digits += c
	if digits.is_empty():
		return 0
	return int(digits)


static func _tier_for_amount(amount: int) -> int:
	if amount >= _TIER_BRUTAL:
		return 3
	if amount >= _TIER_HIGH:
		return 2
	if amount >= _TIER_MED:
		return 1
	return 0
