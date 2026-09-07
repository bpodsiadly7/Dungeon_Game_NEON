extends RefCounted
class_name GameBannerToast
## Pojedynczy baner powiadomień (loot / level up / toast) — zawsze tylko jeden na ekranie.
## Kolejne komunikaty czekają w kolejce zamiast nakładać się na siebie.

const BANNER_NAME := "GameBannerToast"

static var _queue: Array[Dictionary] = []
static var _busy: bool = false
static var _host: Node = null


static func show(
	parent: Node,
	title: String,
	body: String,
	subtitle: String = "",
	accent: Color = Color(0.95, 0.82, 0.30, 1.0),
	duration: float = 2.2,
	font: Font = null
) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	_host = parent
	_queue.append({
		"title": title,
		"body": body,
		"subtitle": subtitle,
		"accent": accent,
		"duration": duration,
		"font": font,
	})
	if not _busy:
		_busy = true
		_pump()


static func _pump() -> void:
	while true:
		if _queue.is_empty():
			_busy = false
			# Ochrona przed race: coś mogło dołączyć między empty a _busy=false.
			if _queue.is_empty():
				return
			_busy = true
			continue
		if _host == null or not is_instance_valid(_host):
			_queue.clear()
			_busy = false
			return
		var entry: Dictionary = _queue.pop_front()
		await _present(_host, entry)


static func _present(parent: Node, entry: Dictionary) -> void:
	_clear_existing(parent)

	var title := String(entry.get("title", ""))
	var body := String(entry.get("body", ""))
	var subtitle := String(entry.get("subtitle", ""))
	var accent: Color = entry.get("accent", Color(0.95, 0.82, 0.30, 1.0))
	var duration := float(entry.get("duration", 2.2))
	var font: Font = entry.get("font", null) as Font

	# Jeden zwarty panel fantasy (panel-015) — bez osobnej transparentnej ramki.
	# Duży 9-slice (32px) na małym banerze „zjadał” środkowe krawędzie.
	var shell := PanelContainer.new()
	shell.name = BANNER_NAME
	shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell.z_index = 450
	shell.add_theme_stylebox_override("panel", _banner_panel(accent))

	var root := VBoxContainer.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("separation", 4)
	shell.add_child(root)

	if title != "":
		var hdr := Label.new()
		hdr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hdr.text = title
		hdr.add_theme_font_size_override("font_size", 16)
		hdr.add_theme_color_override("font_color", accent)
		hdr.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, 0.95))
		hdr.add_theme_constant_override("outline_size", 4)
		if font:
			hdr.add_theme_font_override("font", font)
		root.add_child(hdr)

	var main := Label.new()
	main.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main.text = body
	main.add_theme_font_size_override("font_size", 26 if title != "" else 20)
	main.add_theme_color_override("font_color", accent if title == "" else Color(0.96, 0.93, 0.86, 1.0))
	main.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.95))
	main.add_theme_constant_override("outline_size", 5)
	if font:
		main.add_theme_font_override("font", font)
	root.add_child(main)

	if subtitle != "":
		var sub := Label.new()
		sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.text = subtitle
		sub.add_theme_font_size_override("font_size", 15)
		sub.add_theme_color_override("font_color", Color(0.78, 0.74, 0.66, 0.95))
		sub.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.9))
		sub.add_theme_constant_override("outline_size", 3)
		if font:
			sub.add_theme_font_override("font", font)
		root.add_child(sub)

	shell.set_anchors_preset(Control.PRESET_CENTER_TOP)
	shell.anchor_left = 0.5
	shell.anchor_right = 0.5
	shell.anchor_top = 0.0
	shell.anchor_bottom = 0.0
	shell.grow_horizontal = Control.GROW_DIRECTION_BOTH
	shell.offset_left = -300
	shell.offset_right = 300
	shell.offset_top = 88
	shell.offset_bottom = 88
	shell.modulate = Color(1, 1, 1, 0)
	parent.add_child(shell)

	await parent.get_tree().process_frame
	if not is_instance_valid(shell):
		return
	var h := maxf(shell.get_combined_minimum_size().y, 100.0)
	shell.offset_bottom = shell.offset_top + h

	var start_y := shell.offset_top
	shell.offset_top = start_y - 14.0
	shell.offset_bottom = shell.offset_top + h

	var tw := parent.get_tree().create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(shell, "modulate:a", 1.0, 0.18)
	tw.parallel().tween_property(shell, "offset_top", start_y, 0.18)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(shell, "offset_bottom", start_y + h, 0.18)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(duration)
	tw.tween_property(shell, "modulate:a", 0.0, 0.22)
	await tw.finished
	if is_instance_valid(shell):
		shell.queue_free()


static func _clear_existing(parent: Node) -> void:
	var old := parent.get_node_or_null(BANNER_NAME)
	if old != null and is_instance_valid(old):
		old.queue_free()
	for child in parent.get_children():
		if child is PanelContainer and String(child.name).begins_with("ToastPanel"):
			child.queue_free()


static func _banner_panel(accent: Color) -> StyleBoxTexture:
	# Mniejszy patch niż okno inventory — baner jest niski, 32px łamało środek krawędzi.
	var patch := FantasyUiAssets.PATCH_SLOT
	var fill := FantasyUiAssets.TINT_FILL_DARK
	var tint := Color(
		lerpf(fill.r, accent.r, 0.12),
		lerpf(fill.g, accent.g, 0.12),
		lerpf(fill.b, accent.b, 0.12),
		1.0
	)
	var sb := FantasyUiAssets.stylebox("Panel/panel-015.png", tint, patch, true, 16)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	return sb
