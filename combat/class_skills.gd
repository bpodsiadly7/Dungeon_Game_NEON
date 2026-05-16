extends RefCounted
class_name ClassSkills

var _g: Node2D

func _init(game: Node2D) -> void:
	_g = game


func basic_strike(slot: int) -> void:
	_g.resolving_turn = true
	var base_dmg: int = _g.calc_player_weapon_damage()
	var dmg := int(round(float(base_dmg) * 1.2))
	_g._last_kill_context = {"roll": -1, "weapon_before": _g.weapon.duplicate(true)}
	_g.enemy.take_damage(dmg)
	_g.show_damage_popup(_g.enemy, str(dmg), "hit")
	if _g.lbl_log:
		_g.lbl_log.text = "Basic Strike for %d dmg." % dmg
	_g.skill_cooldowns[slot] = CombatDefs.SKILL_COOLDOWN_TURNS
	_g._update_skills_ui()
	await _g.get_tree().create_timer(0.1).timeout
	if _g.enemy.is_alive():
		_g.set_turn(_g.Turn.ENEMY)
	_g._tick_skill_cooldowns()
	_g.resolving_turn = false


func power_strike(slot: int) -> void:
	_g.resolving_turn = true
	var cost = maxi(1, int(ceil(_g.player.hp * 0.10)))
	_g.player.hp = maxi(1, _g.player.hp - cost)
	_g.player.emit_signal("hp_changed", _g.player.hp, _g.player.max_hp)
	_g.show_damage_popup(_g.player, "-%d HP" % cost, "hit")
	await _g.get_tree().create_timer(0.12).timeout
	var base_dmg: int = _g.calc_player_weapon_damage()
	var dmg := int(round(float(base_dmg) * _g.calc_crit_multiplier_safe()))
	_g._last_kill_context = {"roll": _g.CRIT, "weapon_before": _g.weapon.duplicate(true)}
	_g.enemy.take_damage(dmg)
	_g.show_damage_popup(_g.enemy, str(dmg), "crit")
	if _g.lbl_log:
		_g.lbl_log.text = "Power Strike! Guaranteed CRIT for %d dmg (HP cost %d)." % [dmg, cost]
	if _g.bloodlust_lifesteal > 0.0 and _g.player.is_alive():
		var heal = maxi(1, int(round(dmg * _g.bloodlust_lifesteal)))
		_g.player.hp = mini(_g.player.max_hp, _g.player.hp + heal)
		_g.player.emit_signal("hp_changed", _g.player.hp, _g.player.max_hp)
		_g.show_damage_popup(_g.player, "+" + str(heal), "heal")
	_g.skill_cooldowns[slot] = CombatDefs.SKILL_COOLDOWN_TURNS
	_g._update_skills_ui()
	await _g.get_tree().create_timer(0.1).timeout
	if _g.enemy.is_alive():
		_g.set_turn(_g.Turn.ENEMY)
	_g._tick_skill_cooldowns()
	_g.resolving_turn = false


func quick_slash(slot: int) -> void:
	_g.resolving_turn = true
	var base: int = _g.calc_player_weapon_damage()
	var h1 = maxi(1, int(round(base * randf_range(0.60, 1.00))))
	var h2 = maxi(1, int(round(base * randf_range(0.60, 1.00))))
	var total = h1 + h2
	_g._last_kill_context = {"roll": -1, "weapon_before": _g.weapon.duplicate(true)}
	_g.enemy.take_damage(h1)
	_g.show_damage_popup(_g.enemy, str(h1), "hit")
	await _g.get_tree().create_timer(0.05).timeout
	if _g.enemy.is_alive():
		_g.enemy.take_damage(h2)
		_g.show_damage_popup(_g.enemy, str(h2), "hit")
	if _g.lbl_log:
		_g.lbl_log.text = "Quick Slash! %d + %d = %d dmg." % [h1, h2, total]
	_g.skill_cooldowns[slot] = CombatDefs.SKILL_COOLDOWN_TURNS
	_g._update_skills_ui()
	await _g.get_tree().create_timer(0.1).timeout
	if _g.enemy.is_alive():
		_g.set_turn(_g.Turn.ENEMY)
	_g._tick_skill_cooldowns()
	_g.resolving_turn = false


func shield_block(slot: int) -> void:
	_g.resolving_turn = true
	_g.shield_active = true
	if _g.lbl_log:
		_g.lbl_log.text = "Shield raised! Next incoming hit will be BLOCKED."
	_g.show_damage_popup(_g.player, "SHIELD", "heal")
	_g.skill_cooldowns[slot] = CombatDefs.SKILL_COOLDOWN_TURNS
	_g._update_skills_ui()
	await _g.get_tree().create_timer(0.1).timeout
	if _g.enemy.is_alive():
		_g.set_turn(_g.Turn.ENEMY)
	_g._tick_skill_cooldowns()
	_g.resolving_turn = false


func fury(slot: int) -> void:
	_g.resolving_turn = true
	var log_prefix := "Fury"
	for i in range(2):
		if not _g.player.is_alive() or not _g.enemy.is_alive():
			break
		var roll: int = randi_range(1, 20)
		await _g._dice.play_d20_animation(roll)
		var desc: String = _g._player_attacks.attack_round_with_roll(roll)
		if _g.lbl_log:
			_g.lbl_log.text = "%s: strike %d/2\n%s" % [log_prefix, i + 1, desc]
		await _g.get_tree().create_timer(0.08).timeout
		if not _g.enemy.is_alive():
			break
	_g.skill_cooldowns[slot] = CombatDefs.SKILL_COOLDOWN_TURNS
	_g._update_skills_ui()
	await _g.get_tree().create_timer(0.1).timeout
	if _g.enemy.is_alive():
		_g.set_turn(_g.Turn.ENEMY)
	_g._tick_skill_cooldowns()
	_g.resolving_turn = false
