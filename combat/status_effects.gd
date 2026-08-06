extends RefCounted
class_name StatusEffects

const _WorldMarker := preload("res://combat/status_world_marker.gd")

## Odstęp ikony nad górną krawędzią bounding boxa tekstury (mniejsza = niżej).
const STATUS_ICON_GAP_ABOVE_HEAD := 48
## Ikona nie może być wyżej niż ta odległość nad środkiem sprite'a (px na ekranie).
const STATUS_ICON_MAX_RISE_ABOVE_CENTER := 250
## Kropelki startują tuż pod dolną krawędzią ikony statusu.
const BLEED_VFX_ORIGIN_BELOW_ICON := StatusWorldMarker.ICON_PX * 0.52

var _g: Node2D
var _player_effects: Array[Dictionary] = []
var _enemy_effects: Array[Dictionary] = []
var _player_marker: _WorldMarker
var _enemy_marker: _WorldMarker
var _marker_layer: CanvasLayer
var _icon_cache: Dictionary = {}


func _init(game: Node2D) -> void:
	_g = game


func setup_world_markers(player_anchor: Node2D, enemy_anchor: Node2D) -> void:
	_marker_layer = CanvasLayer.new()
	_marker_layer.name = "StatusEffectMarkers"
	_marker_layer.layer = 11
	_g.add_child(_marker_layer)

	_player_marker = _WorldMarker.new()
	_player_marker.name = "PlayerBleedMarker"
	_marker_layer.add_child(_player_marker)
	if _g.DMG_FONT:
		_player_marker.set_font(_g.DMG_FONT)

	_enemy_marker = _WorldMarker.new()
	_enemy_marker.name = "EnemyBleedMarker"
	_marker_layer.add_child(_enemy_marker)
	if _g.DMG_FONT:
		_enemy_marker.set_font(_g.DMG_FONT)

	_player_marker.visible = false
	_enemy_marker.visible = false
	_sync_marker_positions(player_anchor, enemy_anchor)
	_refresh_ui()


func sync_marker_positions(player_anchor: Node2D, enemy_anchor: Node2D) -> void:
	_sync_marker_positions(player_anchor, enemy_anchor)


func set_markers_layer_visible(visible: bool) -> void:
	if _marker_layer and is_instance_valid(_marker_layer):
		_marker_layer.visible = visible
	if visible:
		_refresh_ui()


func clear_target(target: String) -> void:
	if target == "player":
		_player_effects.clear()
	elif target == "enemy":
		_enemy_effects.clear()
	_refresh_ui()


func clear_all() -> void:
	_player_effects.clear()
	_enemy_effects.clear()
	_refresh_ui()


func has_effect(target: String, effect_id: String) -> bool:
	return not _find_effect(target, effect_id).is_empty()


func on_player_hit_enemy(crit: bool = false, glancing: bool = false) -> void:
	if _g.enemy == null or not _g.enemy.is_alive():
		return
	var form: String = _g._weapon_equipment.form_from_name(String(_g.weapon.get("name", "")))
	if not StatusEffectDefs.bleed_weapon_form(form):
		return
	var chance := StatusEffectDefs.bleed_proc_chance_for_weapon(_g.weapon, crit, glancing)
	if randf() > chance:
		return
	_apply_bleed("enemy", 1)


func on_enemy_hit_player() -> void:
	if not StatusEffectDefs.enemy_can_bleed(_g.current_enemy_data):
		return
	var chance := StatusEffectDefs.enemy_bleed_proc_chance(_g.current_enemy_data)
	if randf() > chance:
		return
	_apply_bleed("player", 1)


func tick_turn_start_async(target: String) -> void:
	var bleed: Dictionary = _find_effect(target, StatusEffectDefs.ID_BLEED)
	if bleed.is_empty():
		return
	if not _target_alive(target):
		return

	var stacks := int(bleed.get("stacks", 1))
	var dmg := _bleed_tick_damage(target, stacks)

	var target_node: Node2D = _g.player if target == "player" else _g.enemy
	var who := "You" if target == "player" else String(_g.current_enemy_data.get("name", "Enemy"))

	_g.resolving_turn = true
	_g._set_attack_buttons_disabled(true)
	_g._update_potions_ui()
	_g.combat_log("%s is bleeding..." % who)

	await BleedTickVfx.play(_marker_layer, _bleed_vfx_origin(target_node, target == "player"))

	if not _target_alive(target):
		_remove_effect(target, StatusEffectDefs.ID_BLEED)
		_refresh_ui()
		return

	_deal_tick_damage(target, dmg, StatusEffectDefs.ID_BLEED)

	bleed["turns_left"] = int(bleed.get("turns_left", 1)) - 1
	if int(bleed["turns_left"]) <= 0:
		_remove_effect(target, StatusEffectDefs.ID_BLEED)

	_g.combat_log("%s bleeds for %d." % [who, dmg])

	await _g.get_tree().create_timer(0.45).timeout
	_refresh_ui()


func _target_alive(target: String) -> bool:
	if target == "player":
		return _g.player != null and _g.player.is_alive()
	return _g.enemy != null and _g.enemy.is_alive()


func _remove_effect(target: String, effect_id: String) -> void:
	var effects: Array[Dictionary] = _effects_for(target)
	for i in range(effects.size() - 1, -1, -1):
		if String(effects[i].get("id", "")) == effect_id:
			effects.remove_at(i)


func _apply_bleed(target: String, stacks_to_add: int) -> void:
	var cfg: Dictionary = StatusEffectDefs.BLEED
	var max_stacks := int(cfg.get("max_stacks", 3))
	var duration := int(cfg.get("duration_turns", 3))
	var effects: Array[Dictionary] = _effects_for(target)
	var existing: Dictionary = _find_effect(target, StatusEffectDefs.ID_BLEED)
	if existing.is_empty():
		effects.append({
			"id": StatusEffectDefs.ID_BLEED,
			"stacks": clampi(stacks_to_add, 1, max_stacks),
			"turns_left": duration,
		})
	else:
		existing["stacks"] = clampi(int(existing.get("stacks", 0)) + stacks_to_add, 1, max_stacks)
		existing["turns_left"] = duration
	_refresh_ui()
	_show_applied_popup(target, StatusEffectDefs.ID_BLEED)


func _bleed_tick_damage(target: String, stacks: int) -> int:
	var mult := float(StatusEffectDefs.BLEED.get("damage_attacker_mult", 0.80))
	var attacker_base := 0
	if target == "enemy":
		attacker_base = _g.calc_player_weapon_damage()
	elif _g.enemy != null:
		attacker_base = int(_g.enemy.damage)
	else:
		attacker_base = int(_g.current_enemy_data.get("damage", 1))
	return maxi(1, int(round(float(attacker_base) * mult * float(maxi(1, stacks)))))


func _deal_tick_damage(target: String, dmg: int, effect_id: String) -> void:
	if dmg <= 0:
		return
	if target == "player":
		if not _g.player.is_alive():
			return
		_g.player.take_damage(dmg)
		_g.show_damage_popup(_g.player, str(dmg), effect_id)
	elif target == "enemy":
		if _g.enemy == null or not _g.enemy.is_alive():
			return
		_g.enemy.take_damage(dmg)
		_g.show_damage_popup(_g.enemy, str(dmg), effect_id)


func _show_applied_popup(target: String, effect_id: String) -> void:
	var label: String = String(StatusEffectDefs.DISPLAY_NAMES.get(effect_id, effect_id.capitalize()))
	var node: Node2D = _g.player if target == "player" else _g.enemy
	if node != null and is_instance_valid(node):
		_g.show_damage_popup(node, label, effect_id)


func _effects_for(target: String) -> Array[Dictionary]:
	if target == "player":
		return _player_effects
	return _enemy_effects


func _find_effect(target: String, effect_id: String) -> Dictionary:
	for eff in _effects_for(target):
		if String(eff.get("id", "")) == effect_id:
			return eff
	return {}


func _refresh_ui() -> void:
	_sync_marker_positions(_g.player, _g.enemy)
	_update_bleed_marker(_player_marker, _player_effects)
	_update_bleed_marker(_enemy_marker, _enemy_effects)


func _update_bleed_marker(marker: _WorldMarker, effects: Array[Dictionary]) -> void:
	if marker == null or not is_instance_valid(marker):
		return
	var bleed: Dictionary = {}
	for eff in effects:
		if String(eff.get("id", "")) == StatusEffectDefs.ID_BLEED:
			bleed = eff
			break
	if bleed.is_empty():
		marker.hide_marker()
		return
	var tex := _load_icon(String(StatusEffectDefs.ICONS.get(StatusEffectDefs.ID_BLEED, "")))
	marker.show_bleed(int(bleed.get("turns_left", 0)), tex)


func _sync_marker_positions(player_anchor: Node2D, enemy_anchor: Node2D) -> void:
	if _player_marker and is_instance_valid(_player_marker) and player_anchor and is_instance_valid(player_anchor):
		_player_marker.position = _status_icon_canvas_pos(player_anchor, true)
	if _enemy_marker and is_instance_valid(_enemy_marker) and enemy_anchor and is_instance_valid(enemy_anchor):
		_enemy_marker.position = _status_icon_canvas_pos(enemy_anchor, false)


func _status_icon_canvas_pos(anchor: Node2D, _is_player: bool) -> Vector2:
	var spr := _main_sprite(anchor)
	var canvas_center := spr.get_global_transform_with_canvas().origin if spr else anchor.get_global_transform_with_canvas().origin
	var sprite_h := _sprite_display_height(anchor)
	var head_top_y := canvas_center.y - sprite_h * 0.5
	var ideal_y := head_top_y - STATUS_ICON_GAP_ABOVE_HEAD
	var max_rise_y := canvas_center.y - STATUS_ICON_MAX_RISE_ABOVE_CENTER
	return Vector2(canvas_center.x, maxf(ideal_y, max_rise_y))


func _bleed_vfx_origin(anchor: Node2D, is_player: bool) -> Vector2:
	var pos := _status_icon_canvas_pos(anchor, is_player)
	pos.y += BLEED_VFX_ORIGIN_BELOW_ICON
	return pos


func _main_sprite(node: Node2D) -> Sprite2D:
	if node is Sprite2D:
		return node as Sprite2D
	for child in node.get_children():
		if child is Sprite2D:
			return child as Sprite2D
	return null


func _sprite_display_height(node: Node2D) -> float:
	var spr := _main_sprite(node)
	if spr and spr.texture:
		return float(spr.texture.get_height()) * absf(spr.scale.y)
	return 80.0


func _load_icon(path: String) -> Texture2D:
	if path == "":
		return null
	if _icon_cache.has(path):
		return _icon_cache[path] as Texture2D
	if not ResourceLoader.exists(path):
		return null
	var tex := load(path) as Texture2D
	if tex:
		_icon_cache[path] = tex
	return tex
