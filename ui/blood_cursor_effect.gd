extends CanvasLayer
## Czerwona poświata / drobna krew podążająca za kursorem (autoload).

@export var enabled: bool = true
@export_range(0.0, 1.0, 0.01) var glow_strength: float = 0.55
@export_range(0.0, 1.0, 0.01) var particle_strength: float = 0.7

const _LAYER: int = 90
const _BLOB_TEX_SIZE: int = 64

var _cursor_root: Node2D
var _trail_root: Node2D
var _glow_inner: Sprite2D
var _glow_outer: Sprite2D
var _particles: CPUParticles2D
var _cursor_pos: Vector2 = Vector2.ZERO
var _trail_pos: Vector2 = Vector2.ZERO
var _blob_tex: ImageTexture


func _ready() -> void:
	layer = _LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_blob_tex = _make_soft_blob_texture(_BLOB_TEX_SIZE)

	_trail_root = Node2D.new()
	_trail_root.name = "Trail"
	add_child(_trail_root)

	_cursor_root = Node2D.new()
	_cursor_root.name = "Cursor"
	add_child(_cursor_root)

	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	_glow_outer = _make_glow_sprite(add_mat, 3.6, Color(0.72, 0.02, 0.06, 0.22))
	_trail_root.add_child(_glow_outer)

	_glow_inner = _make_glow_sprite(add_mat, 2.2, Color(0.95, 0.08, 0.1, 0.38))
	_cursor_root.add_child(_glow_inner)

	_particles = _build_particles()
	_cursor_root.add_child(_particles)

	var vp := get_viewport()
	if vp:
		_cursor_pos = vp.get_mouse_position()
		_trail_pos = _cursor_pos
	_trail_root.position = _trail_pos
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
	var trail_speed: float = clampf(8.0 * delta, 0.0, 1.0)
	_trail_pos = _trail_pos.lerp(mouse, trail_speed)
	_cursor_root.position = _cursor_pos
	_trail_root.position = _trail_pos
	_set_visible(true)


func set_effect_enabled(on: bool) -> void:
	enabled = on
	_apply_strength()


func _set_visible(on: bool) -> void:
	_cursor_root.visible = on
	_trail_root.visible = on


func _apply_strength() -> void:
	var on := enabled
	_glow_inner.visible = on
	_glow_outer.visible = on
	_particles.emitting = on and particle_strength > 0.01
	if not on:
		return
	_glow_inner.modulate.a = glow_strength * 0.7
	_glow_outer.modulate.a = glow_strength * 0.45
	_particles.amount = int(lerpf(8.0, 36.0, particle_strength))


func _make_glow_sprite(mat: CanvasItemMaterial, scale_mul: float, tint: Color) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.texture = _blob_tex
	spr.centered = true
	spr.scale = Vector2(scale_mul, scale_mul)
	spr.modulate = tint
	spr.material = mat
	return spr


func _build_particles() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = _blob_tex
	p.emitting = true
	p.amount = 28
	p.lifetime = 0.55
	p.preprocess = 0.4
	p.explosiveness = 0.0
	p.randomness = 0.85
	p.local_coords = true
	p.direction = Vector2.ZERO
	p.spread = 180.0
	p.gravity = Vector2(0, 90)
	p.initial_velocity_min = 12.0
	p.initial_velocity_max = 55.0
	p.angular_velocity_min = -4.0
	p.angular_velocity_max = 4.0
	p.damping_min = 40.0
	p.damping_max = 80.0
	p.scale_amount_min = 0.15
	p.scale_amount_max = 0.55
	p.hue_variation_min = -0.03
	p.hue_variation_max = 0.06

	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	ramp.colors = PackedColorArray([
		Color(0.95, 0.12, 0.1, 0.85),
		Color(0.55, 0.02, 0.04, 0.45),
		Color(0.15, 0.0, 0.0, 0.0),
	])
	p.color_ramp = ramp

	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = add_mat
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
