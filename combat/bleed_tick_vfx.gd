extends RefCounted
class_name BleedTickVfx

const DRIP_COUNT := 14
const DRIP_DURATION := 1.05
const SETTLE_PAUSE := 0.35


static func play(layer: Node, origin_canvas: Vector2) -> void:
	if layer == null or not is_instance_valid(layer):
		return
	var tree := layer.get_tree()
	if tree == null:
		return

	var root := Node2D.new()
	root.z_index = 50
	root.position = origin_canvas
	layer.add_child(root)

	var mist := _make_particles()
	root.add_child(mist)
	mist.emitting = true

	var trail := _make_particles()
	trail.amount = 28
	trail.lifetime = 1.1
	trail.initial_velocity_min = 55.0
	trail.initial_velocity_max = 140.0
	trail.scale_amount_min = 0.35
	trail.scale_amount_max = 0.85
	root.add_child(trail)
	trail.emitting = true

	for i in DRIP_COUNT:
		if not is_instance_valid(layer) or not is_instance_valid(root):
			return
		var drop := _make_drop_sprite()
		root.add_child(drop)
		drop.position = Vector2(randf_range(-18, 18), randf_range(-10, 2))
		drop.modulate.a = 0.0
		var tw := layer.create_tween()
		tw.tween_interval(randf_range(0.0, 0.28))
		tw.tween_property(drop, "modulate:a", 1.0, 0.1)
		tw.parallel().tween_property(drop, "position:y", drop.position.y + randf_range(36, 64), DRIP_DURATION)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(drop, "scale", drop.scale * Vector2(1.15, 1.35), DRIP_DURATION * 0.55)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(drop, "modulate:a", 0.0, 0.22).set_delay(DRIP_DURATION - 0.22)

	await tree.create_timer(DRIP_DURATION + 0.15).timeout
	if not is_instance_valid(root):
		return
	if is_instance_valid(mist):
		mist.emitting = false
	if is_instance_valid(trail):
		trail.emitting = false
	await tree.create_timer(SETTLE_PAUSE).timeout
	if is_instance_valid(root):
		root.queue_free()


static func _make_drop_sprite() -> Sprite2D:
	var drop := Sprite2D.new()
	drop.texture = _circle_texture()
	drop.scale = Vector2(0.18, 0.28)
	drop.modulate = Color(0.95, 0.06, 0.07, 0.98)
	return drop


static func _circle_texture() -> ImageTexture:
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 12:
		for x in 12:
			var d := Vector2(x - 5.5, y - 5.5).length()
			if d <= 5.0:
				img.set_pixel(x, y, Color(1, 1, 1, 1))
	return ImageTexture.create_from_image(img)


static func _make_particles() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.lifetime = 0.95
	p.amount = 42
	p.explosiveness = 0.22
	p.direction = Vector2(0, 1)
	p.spread = 38.0
	p.gravity = Vector2(0, 520)
	p.initial_velocity_min = 45.0
	p.initial_velocity_max = 130.0
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.7
	p.color = Color(0.92, 0.05, 0.06, 0.95)
	return p
