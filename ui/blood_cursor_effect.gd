extends CanvasLayer
## Poświata krwi przy kursorze + krótka smuga za ruchem (autoload).

@export var enabled: bool = true
@export_range(0.0, 1.0, 0.01) var glow_strength: float = 0.5
@export_range(0.0, 1.0, 0.01) var particle_strength: float = 0.65
@export_range(0.15, 0.8, 0.01) var streak_fade_sec: float = 0.38

const _LAYER: int = 90
const _BLOB_TEX_SIZE: int = 64

var _cursor_root: Node2D
var _streak: Node2D
var _glow_inner: Sprite2D
var _glow_outer: Sprite2D
var _particles: CPUParticles2D
var _cursor_pos: Vector2 = Vector2.ZERO
var _blob_tex: ImageTexture
var _add_mat: CanvasItemMaterial


func _ready() -> void:
	layer = _LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_blob_tex = _make_soft_blob_texture(_BLOB_TEX_SIZE)
	_add_mat = CanvasItemMaterial.new()
	_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	_streak = BloodStreak.new()
	_streak.fade_sec = streak_fade_sec
	add_child(_streak)

	_cursor_root = Node2D.new()
	_cursor_root.name = "Cursor"
	add_child(_cursor_root)

	_glow_outer = _make_glow_sprite(2.8, Color(0.72, 0.02, 0.06, 0.2))
	_cursor_root.add_child(_glow_outer)

	_glow_inner = _make_glow_sprite(2.0, Color(0.95, 0.08, 0.1, 0.35))
	_cursor_root.add_child(_glow_inner)

	_particles = _build_particles()
	_cursor_root.add_child(_particles)

	var vp := get_viewport()
	if vp:
		_cursor_pos = vp.get_mouse_position()
	_cursor_root.position = _cursor_pos
	_apply_strength()


func _process(delta: float) -> void:
	if not enabled:
		_set_visible(false)
		return
	var vp := get_viewport()
	if vp == null:
		return
	var mouse := vp.get_mouse_position()
	_cursor_pos = mouse
	_cursor_root.position = _cursor_pos
	_streak.fade_sec = streak_fade_sec
	(_streak as BloodStreak).track(mouse, delta)
	_set_visible(true)


func set_effect_enabled(on: bool) -> void:
	enabled = on
	if not on:
		(_streak as BloodStreak).clear()
	_apply_strength()


func _set_visible(on: bool) -> void:
	_cursor_root.visible = on
	_streak.visible = on


func _apply_strength() -> void:
	var on := enabled
	_glow_inner.visible = on
	_glow_outer.visible = on
	_streak.visible = on
	_particles.emitting = on and particle_strength > 0.01
	if not on:
		return
	_glow_inner.modulate.a = glow_strength * 0.7
	_glow_outer.modulate.a = glow_strength * 0.42
	_particles.amount = int(lerpf(8.0, 32.0, particle_strength))


func _make_glow_sprite(scale_mul: float, tint: Color) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.texture = _blob_tex
	spr.centered = true
	spr.scale = Vector2(scale_mul, scale_mul)
	spr.modulate = tint
	spr.material = _add_mat
	return spr


func _build_particles() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = _blob_tex
	p.emitting = true
	p.amount = 24
	p.lifetime = 0.5
	p.preprocess = 0.35
	p.explosiveness = 0.0
	p.randomness = 0.85
	p.local_coords = true
	p.direction = Vector2.ZERO
	p.spread = 180.0
	p.gravity = Vector2(0, 90)
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 48.0
	p.angular_velocity_min = -3.0
	p.angular_velocity_max = 3.0
	p.damping_min = 45.0
	p.damping_max = 85.0
	p.scale_amount_min = 0.12
	p.scale_amount_max = 0.5
	p.hue_variation_min = -0.03
	p.hue_variation_max = 0.05

	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	ramp.colors = PackedColorArray([
		Color(0.95, 0.12, 0.1, 0.75),
		Color(0.55, 0.02, 0.04, 0.4),
		Color(0.15, 0.0, 0.0, 0.0),
	])
	p.color_ramp = ramp
	p.material = _add_mat
	return p


func _make_soft_blob_texture(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var cx := float(size) * 0.5
	var r := float(size) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(float(x) - cx, float(y) - cx).length() / r
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a * a
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)


class BloodStreak:
	extends Node2D

	var fade_sec: float = 0.38
	const _MIN_STEP: float = 4.0

	var _points: PackedVector2Array = PackedVector2Array()
	var _ages: PackedFloat32Array = PackedFloat32Array()
	var _add_mat: CanvasItemMaterial


	func _init() -> void:
		_add_mat = CanvasItemMaterial.new()
		_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = _add_mat


	func clear() -> void:
		_points.clear()
		_ages.clear()
		queue_redraw()


	func track(pos: Vector2, delta: float) -> void:
		_age_points(delta)
		if _points.is_empty() or _points[_points.size() - 1].distance_to(pos) >= _MIN_STEP:
			_points.append(pos)
			_ages.append(0.0)
		queue_redraw()


	func _age_points(delta: float) -> void:
		var i := 0
		while i < _ages.size():
			_ages[i] += delta
			if _ages[i] >= fade_sec:
				_points.remove_at(i)
				_ages.remove_at(i)
			else:
				i += 1


	func _draw() -> void:
		if _points.size() < 2:
			return
		for seg in range(1, _points.size()):
			var t := 1.0 - (_ages[seg] / fade_sec)
			t = t * t
			var a := 0.42 * t
			var w := lerpf(1.2, 5.5, t)
			var col := Color(0.9, 0.07, 0.09, a)
			draw_line(_points[seg - 1], _points[seg], col, w, true)
			# Cieńsza, jaśniejsza nitka w środku smugi.
			if t > 0.25:
				draw_line(_points[seg - 1], _points[seg], Color(1.0, 0.15, 0.12, a * 0.35), w * 0.45, true)
