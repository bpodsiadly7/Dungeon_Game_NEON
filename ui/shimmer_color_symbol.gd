extends Control
class_name ShimmerColorSymbol

const SHADER_PATH := "res://ui/shaders/shimmer_glow.gdshader"

var _color: Color = Color.WHITE
var _mat: ShaderMaterial
var _glow: ColorRect
var _shimmer_tween: Tween
var _pulse_tween: Tween


func _init(size: Vector2 = Vector2(82.0, 168.0)) -> void:
	custom_minimum_size = size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _enter_tree() -> void:
	_build()
	set_color(_color)


func _build() -> void:
	if _glow != null:
		return
	_glow = ColorRect.new()
	_glow.color = Color.WHITE
	_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glow.offset_left = 0.0
	_glow.offset_top = 0.0
	_glow.offset_right = 0.0
	_glow.offset_bottom = 0.0
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_glow)

	var shader := load(SHADER_PATH) as Shader
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	_glow.material = _mat
	set_color(_color)


func set_color(color: Color) -> void:
	_color = color
	if _mat:
		_mat.set_shader_parameter("base_color", Vector4(color.r, color.g, color.b, color.a))


func stop_effects() -> void:
	if _shimmer_tween and _shimmer_tween.is_valid():
		_shimmer_tween.kill()
		_shimmer_tween = null
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
		_pulse_tween = null
	if _mat:
		_mat.set_shader_parameter("shimmer_pos", 0.0)
		_mat.set_shader_parameter("glow_strength", 1.0)


func run_shimmer_sweep(duration: float = 0.18) -> void:
	if _mat == null:
		return
	stop_effects()
	_mat.set_shader_parameter("shimmer_pos", -0.15)
	_shimmer_tween = create_tween()
	_shimmer_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_shimmer_tween.tween_method(_set_shimmer_pos, -0.15, 1.15, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func run_idle_pulse() -> void:
	if _mat == null:
		return
	if _pulse_tween and _pulse_tween.is_valid():
		return
	_pulse_tween = create_tween()
	_pulse_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_pulse_tween.set_loops()
	_pulse_tween.tween_method(_set_glow_strength, 0.88, 1.18, 0.42)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_method(_set_glow_strength, 1.18, 0.88, 0.42)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _set_shimmer_pos(v: float) -> void:
	if _mat:
		_mat.set_shader_parameter("shimmer_pos", v)


func _set_glow_strength(v: float) -> void:
	if _mat:
		_mat.set_shader_parameter("glow_strength", v)
