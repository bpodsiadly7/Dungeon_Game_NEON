extends RefCounted
class_name EnemyDeathIconFx
## Ikona śmierci wylatująca z pokonanego przeciwnika.

const _ICON_PATH := "res://ikony/death_icon.png"
const _ICON_SIZE := Vector2(160, 160)


static func spawn(fx_root: Control, enemy: Node2D) -> void:
	if fx_root == null or enemy == null or not is_instance_valid(enemy):
		return
	if not fx_root.visible:
		fx_root.visible = true

	var start := _pos_in_fx_root(enemy, fx_root)
	var fly := Vector2(randf_range(-55.0, 55.0), randf_range(-95.0, -135.0))
	var end_pos := start + fly

	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.z_index = 320
	root.position = start
	fx_root.add_child(root)

	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = load(_ICON_PATH) as Texture2D
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = _ICON_SIZE
	icon.size = _ICON_SIZE
	icon.pivot_offset = _ICON_SIZE * 0.5
	icon.position = -_ICON_SIZE * 0.5
	icon.modulate = Color(1.0, 0.85, 0.85, 1.0)
	icon.scale = Vector2(0.4, 0.4)
	icon.rotation = randf_range(-0.35, 0.35)
	root.add_child(icon)

	var tree := fx_root.get_tree()
	if tree == null:
		root.queue_free()
		return

	var move := tree.create_tween()
	move.tween_property(root, "position", end_pos, 0.72)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	move.parallel().tween_property(icon, "modulate:a", 0.0, 0.55)\
		.set_delay(0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	move.parallel().tween_property(icon, "rotation", icon.rotation + randf_range(-0.5, 0.5), 0.72)

	var scale_tw := tree.create_tween()
	scale_tw.tween_property(icon, "scale", Vector2(1.35, 1.35), 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	scale_tw.tween_property(icon, "scale", Vector2(0.6, 0.6), 0.52)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	move.finished.connect(func() -> void:
		if is_instance_valid(root):
			root.queue_free()
	)


static func _pos_in_fx_root(enemy: Node2D, fx_root: Control) -> Vector2:
	var canvas_pt := enemy.get_global_transform_with_canvas().origin
	if enemy.has_node("Sprite2D"):
		var spr := enemy.get_node("Sprite2D") as Sprite2D
		if spr:
			canvas_pt = spr.get_global_transform_with_canvas().origin
	return fx_root.get_global_transform_with_canvas().affine_inverse() * canvas_pt
