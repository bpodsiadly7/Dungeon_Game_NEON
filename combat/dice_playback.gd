extends RefCounted
class_name DicePlayback

var _g: Node2D

func _init(game: Node2D) -> void:
	_g = game


static func _to_int_array(src: Array) -> Array[int]:
	var out: Array[int] = []
	out.assign(src)
	return out


static func _to_string_array(src: Array) -> Array[String]:
	var out: Array[String] = []
	out.assign(src)
	return out


func cache_default_dice_set() -> void:
	if _g.dice_roller == null or _g.dice_roller.dice_set.is_empty():
		return
	_g._default_dice_set.clear()
	for dd in _g.dice_roller.dice_set:
		if dd is DiceDef:
			_g._default_dice_set.append((dd as DiceDef).duplicate(true))


func apply_dice_set_shapes_on(roller: DiceRoller, shape_ids: Array[String]) -> void:
	if roller == null:
		return
	var new_set: Array[DiceDef] = []
	for sid in shape_ids:
		var dd := DiceDef.new()
		dd.name = sid
		dd.shape = DiceShape.new(sid)
		dd.color = Color(0.92, 0.88, 0.78)
		new_set.append(dd)
	roller.dice_set = new_set


func apply_dice_set_shapes(shape_ids: Array[String]) -> void:
	apply_dice_set_shapes_on(_g.dice_roller, shape_ids)


func restore_default_dice_set_on(roller: DiceRoller) -> void:
	if roller == null:
		return
	if _g._default_dice_set.is_empty():
		var dd := DiceDef.new()
		dd.name = "D20"
		dd.shape = DiceShape.new("D20")
		roller.dice_set = [dd]
	else:
		roller.dice_set = _g._default_dice_set.duplicate(true)


func restore_default_dice_set() -> void:
	restore_default_dice_set_on(_g.dice_roller)


func play_d20_animation(final_roll: int) -> void:
	await play_roll_animation([final_roll], ["D20"])


func play_roll_animation(faces: Array, shape_ids: Array) -> void:
	var typed_faces := _to_int_array(faces)
	var typed_shapes := _to_string_array(shape_ids)
	if not _g.dice_display or not _g.dice_roller:
		return
	if typed_faces.is_empty() or typed_shapes.is_empty() or typed_faces.size() != typed_shapes.size():
		push_warning("Dice animation: faces/shapes mismatch.")
		return
	if typed_faces.size() == 1:
		await play_legacy_roll_animation(typed_faces, typed_shapes)
	else:
		await play_multi_dice_cinematic(typed_faces, typed_shapes)


func play_legacy_roll_animation(
	faces: Array[int],
	shape_ids: Array[String],
	lane_offset_x: float = 0.0,
	time_scale: float = 1.0
) -> void:
	if not _g.dice_display or not _g.dice_roller:
		return
	time_scale = clampf(time_scale, 0.25, 1.0)

	apply_dice_set_shapes(shape_ids)

	var is_crit := false
	var is_miss := false
	if shape_ids[0] == "D20":
		is_crit = (faces[0] == _g.CRIT)
	elif shape_ids[0] == "D10":
		is_crit = (faces[0] == 0 or faces[0] == CombatDefs.SAFE_ATTACK_CRIT)

	var rand_offset := Vector2(randf_range(-60, 60), randf_range(-30, 30))
	var land_pos := Vector2(
		_g.get_viewport_rect().size.x / 2.0 - 250,
		_g.get_viewport_rect().size.y / 2.0 - 250
	) + rand_offset + Vector2(lane_offset_x, 0)

	_g.dice_display.position = Vector2(-600, land_pos.y)
	_g.dice_display.modulate = Color(1, 1, 1, 1)
	_g.dice_display.visible = true

	_g.dice_display.pivot_offset = Vector2(250, 250)
	var tw_spin := _g.get_tree().create_tween()
	tw_spin.tween_property(_g.dice_display, "rotation_degrees", 360.0, 0.4 * time_scale)

	var tw_in := _g.get_tree().create_tween()
	tw_in.set_ease(Tween.EASE_OUT)
	tw_in.set_trans(Tween.TRANS_CUBIC)
	tw_in.tween_property(_g.dice_display, "position:x", land_pos.x, 0.5 * time_scale)

	_g.dice_roller.show_faces(faces)
	await _g.get_tree().create_timer(0.35 * time_scale).timeout
	for dice in _g.dice_roller.dices:
		dice.dehighlight()

	await tw_in.finished

	tw_spin.kill()
	_g.dice_display.rotation_degrees = 0.0
	await dice_burst_effect(is_crit, is_miss, land_pos, time_scale)

	if is_crit:
		_g.shake_camera(10.0, 0.2 * time_scale)
	elif is_miss:
		_g.shake_camera(4.0, 0.15 * time_scale)

	await _g.get_tree().create_timer(0.8 * time_scale).timeout

	var tw_out := _g.get_tree().create_tween()
	tw_out.set_ease(Tween.EASE_IN)
	tw_out.set_trans(Tween.TRANS_CUBIC)
	tw_out.tween_property(_g.dice_display, "position:x", _g.get_viewport_rect().size.x + 200, 0.35 * time_scale)
	await tw_out.finished

	_g.dice_display.rotation_degrees = 0.0
	_g.dice_display.visible = false
	restore_default_dice_set()


func play_multi_dice_cinematic(faces: Array[int], shape_ids: Array[String]) -> void:
	for i in range(faces.size()):
		var lane: float = 0.0
		if i < CombatDefs.DICE_PAIR_LANE_X.size():
			lane = CombatDefs.DICE_PAIR_LANE_X[i]
		await play_legacy_roll_animation(
			_to_int_array([faces[i]]),
			_to_string_array([shape_ids[i]]),
			lane,
			CombatDefs.DICE_PAIR_ANIM_SCALE
		)
		if i + 1 < faces.size():
			await _g.get_tree().create_timer(CombatDefs.DICE_PAIR_GAP_SEC).timeout


func dice_burst_effect(
	is_crit: bool,
	is_miss: bool,
	land_pos: Vector2,
	time_scale: float = 1.0
) -> void:
	var center := land_pos + Vector2(250, 250)
	time_scale = clampf(time_scale, 0.25, 1.0)
	var particle_speed := 1.0 / time_scale if time_scale < 1.0 else 1.0
	var burst_px := func(cfg: Dictionary) -> void:
		spawn_dice_particles(center, cfg, particle_speed)

	if is_crit:
		burst_px.call({
			"amount": 60, "lifetime": 0.6, "explosiveness": 0.98,
			"velocity_min": 260.0, "velocity_max": 480.0,
			"scale_min": 2.0, "scale_max": 4.0, "gravity": 220.0,
			"color_start": Color(1.0, 1.0, 0.5, 0.9),
			"color_end": Color(1.0, 0.6, 0.0, 0.0),
			"damping_min": 80.0, "damping_max": 160.0,
		})
		burst_px.call({
			"amount": 40, "lifetime": 0.4, "explosiveness": 1.0,
			"velocity_min": 180.0, "velocity_max": 350.0,
			"scale_min": 1.0, "scale_max": 2.5, "gravity": 150.0,
			"color_start": Color(1.0, 1.0, 1.0, 0.85),
			"color_end": Color(1.0, 0.9, 0.4, 0.0),
			"damping_min": 60.0, "damping_max": 100.0,
		})
		spawn_dice_glow(center, Color(1.0, 0.95, 0.3, 0.7), 220.0, 0.22)
		_g.shake_camera(10.0, 0.18)

	elif is_miss:
		burst_px.call({
			"amount": 18, "lifetime": 0.65, "explosiveness": 0.75,
			"velocity_min": 60.0, "velocity_max": 140.0,
			"scale_min": 2.0, "scale_max": 4.0, "gravity": 80.0,
			"color_start": Color(0.8, 0.8, 0.85, 0.7),
			"color_end": Color(0.5, 0.5, 0.55, 0.0),
			"damping_min": 40.0, "damping_max": 80.0,
		})
		burst_px.call({
			"amount": 12, "lifetime": 0.5, "explosiveness": 0.6,
			"velocity_min": 30.0, "velocity_max": 80.0,
			"scale_min": 1.5, "scale_max": 3.0, "gravity": 60.0,
			"color_start": Color(0.55, 0.53, 0.58, 0.5),
			"color_end": Color(0.3, 0.3, 0.35, 0.0),
			"damping_min": 20.0, "damping_max": 50.0,
		})
		_g.shake_camera(3.0, 0.10)

	else:
		burst_px.call({
			"amount": 35, "lifetime": 0.5, "explosiveness": 0.95,
			"velocity_min": 200.0, "velocity_max": 340.0,
			"scale_min": 2.0, "scale_max": 4.5, "gravity": 200.0,
			"color_start": Color(1.0, 0.55, 0.05, 0.85),
			"color_end": Color(0.8, 0.2, 0.0, 0.0),
			"damping_min": 60.0, "damping_max": 110.0,
		})
		burst_px.call({
			"amount": 20, "lifetime": 0.3, "explosiveness": 1.0,
			"velocity_min": 100.0, "velocity_max": 220.0,
			"scale_min": 1.5, "scale_max": 3.0, "gravity": 120.0,
			"color_start": Color(1.0, 1.0, 0.6, 0.7),
			"color_end": Color(1.0, 0.7, 0.1, 0.0),
			"damping_min": 40.0, "damping_max": 80.0,
		})
		spawn_dice_glow(center, Color(1.0, 0.6, 0.1, 0.45), 160.0, 0.16)

	var wait := 0.6 if is_crit else (0.65 if is_miss else 0.5)
	await _g.get_tree().create_timer(wait * 0.55 * time_scale).timeout


func spawn_dice_particles(center: Vector2, cfg: Dictionary, speed_scale: float = 1.0) -> void:
	var p := GPUParticles2D.new()
	p.z_index = 320
	p.position = center
	p.one_shot = true
	p.emitting = false
	p.amount = int(cfg["amount"])
	p.lifetime = float(cfg["lifetime"])
	p.explosiveness = float(cfg["explosiveness"])
	p.speed_scale = speed_scale

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 18.0
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = float(cfg["velocity_min"])
	mat.initial_velocity_max = float(cfg["velocity_max"])
	mat.gravity = Vector3(0, float(cfg["gravity"]), 0)
	mat.damping_min = float(cfg["damping_min"])
	mat.damping_max = float(cfg["damping_max"])
	mat.scale_min = float(cfg["scale_min"])
	mat.scale_max = float(cfg["scale_max"])
	mat.angle_min = 0.0
	mat.angle_max = 360.0
	mat.angular_velocity_min = -180.0
	mat.angular_velocity_max = 180.0

	var grad := Gradient.new()
	grad.set_color(0, cfg["color_start"] as Color)
	grad.add_point(1.0, cfg["color_end"] as Color)
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex

	p.process_material = mat

	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in 16:
		for y in 16:
			var dx: float = x - 7.5
			var dy: float = y - 7.5
			var dist: float = sqrt(dx * dx + dy * dy)
			var alpha: float = clampf(1.0 - dist / 7.5, 0.0, 1.0)
			alpha = alpha * alpha
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	var tex := ImageTexture.create_from_image(img)
	p.texture = tex

	_g.get_node("CanvasLayer").add_child(p)
	p.emitting = true

	var cleanup_time: float = float(cfg["lifetime"]) + 0.3
	_g.get_tree().create_timer(cleanup_time).timeout.connect(func():
		if is_instance_valid(p):
			p.queue_free()
	)


func spawn_dice_glow(center: Vector2, col: Color, radius: float, duration: float) -> void:
	var glow := ColorRect.new()
	glow.color = col
	glow.size = Vector2(radius, radius)
	glow.position = center - Vector2(radius * 0.5, radius * 0.5)
	glow.pivot_offset = Vector2(radius * 0.5, radius * 0.5)
	glow.scale = Vector2(0.1, 0.1)
	glow.z_index = 315

	var shader_code := """
shader_type canvas_item;
void fragment() {
	vec2 uv = UV - vec2(0.5);
	float dist = length(uv);
	float alpha = smoothstep(0.5, 0.2, dist);
	COLOR = vec4(COLOR.rgb, COLOR.a * alpha);
}
"""
	var shader := Shader.new()
	shader.code = shader_code
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = shader
	glow.material = shader_mat

	_g.get_node("CanvasLayer").add_child(glow)

	var tw := _g.get_tree().create_tween()
	tw.tween_property(glow, "scale", Vector2(1.0, 1.0), duration * 0.3)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(glow, "modulate:a", 0.0, duration * 0.7)\
		.set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(glow.queue_free)
