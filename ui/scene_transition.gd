extends CanvasLayer
## Cinematic fade / vignette / flavor text between scenes (persists as autoload).

const FONT_PATH := "res://MedievalSharp-Bold.ttf"

const DEFAULT_MENU_LINES: Array[String] = [
	"The gate grinds open…",
	"Your tale continues in the keep.",
]

var _root: Control
var _fade: ColorRect
var _vignette: ColorRect
var _vignette_mat: ShaderMaterial
var _line_primary: Label
var _line_secondary: Label
var _embers: CPUParticles2D
var _font: Font
var _busy: bool = false


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)
	_build_ui()


func is_busy() -> bool:
	return _busy


func play_menu_to_home(target_scene: String) -> void:
	var lines := DEFAULT_MENU_LINES.duplicate()
	if lines.is_empty():
		lines = ["…"]
	await play_rpg_transition(target_scene, lines)


func play_rpg_transition(target_scene: String, flavor_lines: Array[String]) -> void:
	if _busy:
		return
	if target_scene.is_empty() or not ResourceLoader.exists(target_scene):
		push_warning("SceneTransition: invalid scene path: %s" % target_scene)
		get_tree().change_scene_to_file(target_scene)
		return

	_busy = true
	visible = true
	_root.visible = true
	_root.modulate = Color.WHITE
	_fade.color = Color(0.05, 0.02, 0.01, 0.0)
	_vignette_mat.set_shader_parameter("strength", 0.0)
	_line_primary.modulate.a = 0.0
	_line_secondary.modulate.a = 0.0
	_line_primary.text = ""
	_line_secondary.text = ""
	_embers.emitting = false

	var line_a := String(flavor_lines[0]) if flavor_lines.size() > 0 else ""
	var line_b := String(flavor_lines[1]) if flavor_lines.size() > 1 else ""

	# Phase 1 — menu dims, vignette closes in, embers rise.
	var intro := create_tween()
	intro.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	intro.set_parallel(true)
	intro.tween_property(_fade, "color:a", 0.72, 0.55).from(0.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	intro.tween_method(_set_vignette_strength, 0.0, 0.95, 0.65)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await intro.finished

	_embers.emitting = true
	_line_primary.text = line_a
	var text_in := create_tween()
	text_in.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	text_in.tween_property(_line_primary, "modulate:a", 1.0, 0.45)\
		.from(0.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await text_in.finished
	await get_tree().create_timer(0.55).timeout

	if line_b != "":
		_line_secondary.text = line_b
		var swap := create_tween()
		swap.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		swap.set_parallel(true)
		swap.tween_property(_line_primary, "modulate:a", 0.35, 0.35)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		swap.tween_property(_line_secondary, "modulate:a", 1.0, 0.5)\
			.from(0.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await swap.finished
		await get_tree().create_timer(0.65).timeout
	else:
		await get_tree().create_timer(0.45).timeout

	# Phase 2 — full black, then load scene under cover.
	var blackout := create_tween()
	blackout.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	blackout.set_parallel(true)
	blackout.tween_property(_fade, "color:a", 1.0, 0.42)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	blackout.tween_property(_line_secondary, "modulate:a", 0.0, 0.28)
	blackout.tween_property(_line_primary, "modulate:a", 0.0, 0.28)
	blackout.tween_method(_set_vignette_strength, _vignette_mat.get_shader_parameter("strength"), 1.0, 0.42)
	await blackout.finished

	_embers.emitting = false
	get_tree().change_scene_to_file(target_scene)
	await get_tree().process_frame
	await get_tree().process_frame

	await _reveal_arrival(0.95)
	_busy = false
	visible = false


func _reveal_arrival(duration: float) -> void:
	_fade.color.a = 1.0
	_vignette_mat.set_shader_parameter("strength", 0.85)
	_line_primary.modulate.a = 0.0
	_line_secondary.modulate.a = 0.0

	var out := create_tween()
	out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	out.set_parallel(true)
	out.tween_property(_fade, "color:a", 0.0, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	out.tween_method(_set_vignette_strength, 0.85, 0.0, duration * 1.1)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await out.finished
	_embers.emitting = false


func _set_vignette_strength(v: float) -> void:
	if _vignette_mat:
		_vignette_mat.set_shader_parameter("strength", v)


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.color = Color(0.05, 0.02, 0.01, 0.0)
	_root.add_child(_fade)

	var vig_shader := load("res://ui/menu_transition_vignette.gdshader") as Shader
	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if vig_shader:
		_vignette_mat = ShaderMaterial.new()
		_vignette_mat.shader = vig_shader
		_vignette_mat.set_shader_parameter("strength", 0.0)
		_vignette.material = _vignette_mat
	else:
		_vignette.color = Color(0.1, 0.02, 0.0, 0.0)
	_root.add_child(_vignette)

	_embers = CPUParticles2D.new()
	_embers.amount = 48
	_embers.lifetime = 2.2
	_embers.one_shot = false
	_embers.explosiveness = 0.0
	_embers.direction = Vector2(0.0, -1.0)
	_embers.spread = 38.0
	_embers.initial_velocity_min = 28.0
	_embers.initial_velocity_max = 95.0
	_embers.gravity = Vector2(0, -18)
	_embers.scale_amount_min = 1.5
	_embers.scale_amount_max = 4.5
	_embers.color = Color(1.0, 0.55, 0.18, 0.85)
	_embers.emitting = false
	_root.add_child(_embers)
	get_viewport().size_changed.connect(_layout_particles)
	call_deferred("_layout_particles")

	_line_primary = _make_flavor_label(30)
	_line_secondary = _make_flavor_label(22)
	_root.add_child(_line_primary)
	_root.add_child(_line_secondary)


func _layout_particles() -> void:
	if _embers == null or _root == null:
		return
	var sz := _root.get_viewport_rect().size
	_embers.position = Vector2(sz.x * 0.5, sz.y * 0.88)
	_embers.emission_rect_extents = Vector2(sz.x * 0.42, 12.0)

	var center_y := sz.y * 0.52
	_line_primary.position = Vector2(0.0, center_y - 36.0)
	_line_primary.size = Vector2(sz.x, 48.0)
	_line_secondary.position = Vector2(0.0, center_y + 18.0)
	_line_secondary.size = Vector2(sz.x, 40.0)


func _make_flavor_label(font_size: int) -> Label:
	var lbl := Label.new()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	lbl.modulate = Color(1.0, 1.0, 1.0, 0.0)
	if _font:
		lbl.add_theme_font_override("font", _font)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", Color(0.98, 0.88, 0.55))
	lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.0, 0.9))
	lbl.add_theme_constant_override("outline_size", 5)
	return lbl
