extends RefCounted
class_name PlayerAttacks

var _g: Node2D

func _init(game: Node2D) -> void:
	_g = game


func d10_face_value(roll_1_to_10: int) -> int:
	if roll_1_to_10 >= 10:
		return 0
	return roll_1_to_10


func damage_multiplier_from_roll(roll: int, armor: int, max_non_crit: int = 19) -> float:
	var min_roll: int = clampi(armor + 1, 1, max_non_crit)
	var max_roll: int = max_non_crit
	if roll <= min_roll:
		return 1.0
	if roll >= max_roll:
		return 1.8
	var t := float(roll - min_roll) / float(max(1, max_roll - min_roll))
	return lerpf(1.0, 1.8, t)


func enemy_armor_for_player(armor_ignore: int = 0) -> int:
	var base := clampi(int(_g.current_enemy_data.get("armor", 0)), 0, 15)
	return maxi(0, base - armor_ignore - _g.enemy_armor_penalty)


func consume_enemy_armor_penalty() -> void:
	_g.enemy_armor_penalty = 0


func attack_round_with_roll(
	roll: int,
	extra_dmg_mult: float = 1.0,
	crit_on: int = -1,
	armor_ignore: int = 0,
	allow_crit: bool = true,
	wide_crit_from: int = -1
) -> String:
	if crit_on < 0:
		crit_on = _g.CRIT
	var text := ""
	_g._last_kill_context = {"roll": roll, "weapon_before": _g.weapon.duplicate(true)}
	var enemy_armor: int = enemy_armor_for_player(armor_ignore)
	consume_enemy_armor_penalty()

	if roll < enemy_armor:
		_g.show_damage_popup(_g.enemy, "dodge", "miss")
		text += "You roll %d vs Armor %d → MISS.\n" % [roll, enemy_armor]
		return text

	var base_dmg: int = _g.calc_player_weapon_damage()
	var kind := "hit"
	var mult := 1.0
	var crit := false
	if allow_crit:
		if wide_crit_from >= 0 and roll >= wide_crit_from:
			crit = true
		elif roll == crit_on:
			crit = true
	if crit:
		kind = "crit"
		mult = _g.calc_crit_multiplier()
	elif roll == enemy_armor:
		mult = 0.5
	else:
		mult = damage_multiplier_from_roll(roll, enemy_armor, crit_on - 1)

	var dmg: int = maxi(1, int(round(float(base_dmg) * mult * extra_dmg_mult)))
	_g.enemy.take_damage(dmg)
	_g.show_damage_popup(_g.enemy, str(dmg), kind)
	text += "You roll %d vs Armor %d → %s for %d dmg.\n" % [
		roll, enemy_armor, "CRIT" if crit else ("HALF" if roll == enemy_armor else "HIT"), dmg
	]

	if crit and _g.bloodlust_lifesteal > 0.0 and _g.player.is_alive():
		var heal = maxi(1, int(round(dmg * _g.bloodlust_lifesteal)))
		_g.player.hp = mini(_g.player.max_hp, _g.player.hp + heal)
		_g.player.emit_signal("hp_changed", _g.player.hp, _g.player.max_hp)
		_g.show_damage_popup(_g.player, "+" + str(heal), "heal")

	if not _g.enemy.is_alive():
		text += "Enemy defeated!"
	return text


func safe_attack_round(atk_roll: int, guard_roll: int) -> String:
	var text := "Safe Attack: d10=%d, Guard d6=%d. +%d Armor until your next turn.\n" % [
		atk_roll, guard_roll, guard_roll
	]
	text += attack_round_with_roll(atk_roll, 1.0, CombatDefs.SAFE_ATTACK_CRIT)
	return text


func execute_attack(mode: int) -> void:
	if _g.resolving_turn:
		return
	if _g.turn != _g.Turn.PLAYER or not _g.player.is_alive() or not _g.enemy.is_alive():
		return

	if _g.player_temp_armor_delta != 0:
		_g.player_temp_armor_delta = 0
		_g._refresh_player_armor_label()

	if bool(_g.current_enemy_data.get("treasure", false)):
		_g.resolving_turn = true
		if _g.lbl_log:
			_g.lbl_log.text = "You open the chest..."
		await _g.get_tree().create_timer(0.3).timeout
		_g.enemy.take_damage(_g.enemy.hp)
		_g.resolving_turn = false
		return

	_g.resolving_turn = true
	var desc: String = ""

	match mode:
		CombatDefs.AttackMode.BASIC:
			var roll: int = randi_range(1, 20)
			await _g._dice.play_roll_animation([roll], ["D20"])
			desc = attack_round_with_roll(roll)

		CombatDefs.AttackMode.SAFE:
			var atk_roll: int = randi_range(1, 10)
			var guard_roll: int = randi_range(1, 6)
			await _g._dice.play_roll_animation(
				[d10_face_value(atk_roll), guard_roll],
				["D10", "D6"]
			)
			_g.player_temp_armor_delta += guard_roll
			_g._refresh_player_armor_label()
			desc = safe_attack_round(atk_roll, guard_roll)

		CombatDefs.AttackMode.WILD:
			var d20_roll: int = randi_range(1, 20)
			var d10_roll: int = randi_range(1, 10)
			await _g._dice.play_roll_animation(
				[d20_roll, d10_face_value(d10_roll)],
				["D20", "D10"]
			)
			_g.player_temp_armor_delta -= 1
			_g._refresh_player_armor_label()
			var wild_mult: float = 1.0 + float(d10_roll - 1) * CombatDefs.WILD_D10_DMG_PER_POINT
			desc = attack_round_with_roll(d20_roll, wild_mult)
			desc += "Wild d10=%d → +%d%% dmg. Armor -1 until your next turn.\n" % [
				d10_roll, int(round((wild_mult - 1.0) * 100.0))
			]

	if _g.lbl_log:
		_g.lbl_log.text = desc
	await _g.get_tree().create_timer(0.1).timeout
	if _g.enemy.is_alive():
		_g.set_turn(_g.Turn.ENEMY)
	_g._tick_skill_cooldowns()
	_g.resolving_turn = false
