extends RefCounted
class_name WeaponSkills

var _g: Node2D

func _init(game: Node2D) -> void:
	_g = game


func use(slot: int) -> void:
	if not _g.skills.has(slot):
		return
	var form := String(_g.skills[slot].get("weapon_form", ""))
	_g.resolving_turn = true
	match form:
		"sword":
			await riposte(slot)
		"axe":
			await skull_cleave(slot)
		"dagger":
			await needle_flurry(slot)
		"mace":
			await shatter_guard(slot)
		"spear":
			await lunge(slot)
		"hammer":
			await earthshaker(slot)
		"blade":
			await flowing_cut(slot)
		"saber":
			await duelist_gambit(slot)
		"bow":
			await aimed_shot(slot)
		"crossbow":
			await overdraw(slot)
		_:
			if _g.lbl_log:
				_g.lbl_log.text = "Unknown weapon skill."
			_g.resolving_turn = false


func riposte(slot: int) -> void:
	var atk_roll: int = randi_range(1, 10)
	var guard_roll: int = randi_range(1, 6)
	await _g._dice.play_roll_animation(
		[_g._player_attacks.d10_face_value(atk_roll), guard_roll], ["D10", "D6"]
	)
	var log := "Riposte: d10=%d, d6=%d.\n" % [atk_roll, guard_roll]
	log += _g._player_attacks.attack_round_with_roll(atk_roll, 1.15, CombatDefs.SAFE_ATTACK_CRIT)
	if guard_roll >= 5:
		_g.player_temp_armor_delta += 1
		_g._refresh_player_armor_label()
		log += "+1 Armor until your next action.\n"
	if guard_roll == 6:
		_g.enemy_armor_penalty = 1
		log += "Enemy Armor −1 on your next hit.\n"
	if _g.lbl_log:
		_g.lbl_log.text = log
	await _g._skill_runtime.finish_active_skill_turn(slot)


func skull_cleave(slot: int) -> void:
	var roll: int = randi_range(1, 20)
	await _g._dice.play_roll_animation([roll], ["D20"])
	_g._last_kill_context = {"roll": roll, "weapon_before": _g.weapon.duplicate(true)}
	var enemy_armor: int = _g._player_attacks.enemy_armor_for_player()
	_g._player_attacks.consume_enemy_armor_penalty()
	var base_dmg: int = _g.calc_player_weapon_damage()
	var log := "Skull Cleave: d20=%d vs Armor %d.\n" % [roll, enemy_armor]
	if roll >= enemy_armor:
		var dmg: int = maxi(1, int(round(float(base_dmg) * 1.45)))
		_g.enemy.take_damage(dmg)
		_g.show_damage_popup(_g.enemy, str(dmg), "hit")
		log += "Hit for %d dmg (145%%).\n" % dmg
	else:
		var dmg: int = maxi(1, int(round(float(base_dmg) * 0.45)))
		_g.enemy.take_damage(dmg)
		_g.show_damage_popup(_g.enemy, str(dmg), "hit")
		log += "Glancing blow for %d dmg (45%%).\n" % dmg
	if _g.lbl_log:
		_g.lbl_log.text = log
	await _g._skill_runtime.finish_active_skill_turn(slot)


func needle_flurry(slot: int) -> void:
	var r1: int = randi_range(1, 10)
	var r2: int = randi_range(1, 10)
	await _g._dice.play_roll_animation(
		[_g._player_attacks.d10_face_value(r1), _g._player_attacks.d10_face_value(r2)],
		["D10", "D10"]
	)
	var log := "Needle Flurry:\n"
	log += _g._player_attacks.attack_round_with_roll(r1, 0.55, CombatDefs.SAFE_ATTACK_CRIT)
	if _g.enemy.is_alive():
		log += _g._player_attacks.attack_round_with_roll(r2, 0.55, CombatDefs.SAFE_ATTACK_CRIT)
	if _g.lbl_log:
		_g.lbl_log.text = log
	await _g._skill_runtime.finish_active_skill_turn(slot)


func shatter_guard(slot: int) -> void:
	var roll: int = randi_range(1, 20)
	var crush: int = randi_range(1, 6)
	await _g._dice.play_roll_animation([roll, crush], ["D20", "D6"])
	var ignore: int = int(ceil(float(crush) / 2.0))
	var log := "Shatter Guard: d20=%d, d6=%d (ignore %d Armor).\n" % [roll, crush, ignore]
	log += _g._player_attacks.attack_round_with_roll(roll, 1.10, _g.CRIT, ignore)
	if _g.lbl_log:
		_g.lbl_log.text = log
	await _g._skill_runtime.finish_active_skill_turn(slot)


func lunge(slot: int) -> void:
	var roll: int = randi_range(1, 10)
	await _g._dice.play_roll_animation([_g._player_attacks.d10_face_value(roll)], ["D10"])
	var log := "Lunge: d10=%d (Armor−3).\n" % roll
	log += _g._player_attacks.attack_round_with_roll(roll, 1.25, CombatDefs.SAFE_ATTACK_CRIT, 3)
	if _g.lbl_log:
		_g.lbl_log.text = log
	await _g._skill_runtime.finish_active_skill_turn(slot)


func earthshaker(slot: int) -> void:
	var d20_roll: int = randi_range(1, 20)
	var d10_roll: int = randi_range(1, 10)
	await _g._dice.play_roll_animation(
		[d20_roll, _g._player_attacks.d10_face_value(d10_roll)], ["D20", "D10"]
	)
	_g._last_kill_context = {"roll": d20_roll, "weapon_before": _g.weapon.duplicate(true)}
	var enemy_armor: int = _g._player_attacks.enemy_armor_for_player()
	_g._player_attacks.consume_enemy_armor_penalty()
	var base_dmg: int = _g.calc_player_weapon_damage()
	var log := "Earthshaker: d20=%d, d10=%d vs Armor %d.\n" % [d20_roll, d10_roll, enemy_armor]
	if d20_roll >= enemy_armor:
		var bonus: float = 1.0 + float(d10_roll - 1) * 0.04
		var dmg: int = maxi(1, int(round(float(base_dmg) * 1.55 * bonus)))
		var crit: bool = (d20_roll == _g.CRIT)
		var kind: String = "crit" if crit else "hit"
		if crit:
			dmg = maxi(1, int(round(float(dmg) * _g.calc_crit_multiplier())))
		_g.enemy.take_damage(dmg)
		_g.show_damage_popup(_g.enemy, str(dmg), kind)
		log += "Hit for %d dmg.\n" % dmg
	else:
		var dmg: int = maxi(1, int(round(float(base_dmg) * 0.55)))
		_g.enemy.take_damage(dmg)
		_g.show_damage_popup(_g.enemy, str(dmg), "hit")
		log += "Shockwave for %d dmg (55%%).\n" % dmg
	if _g.lbl_log:
		_g.lbl_log.text = log
	await _g._skill_runtime.finish_active_skill_turn(slot, CombatDefs.WEAPON_SKILL_CD_LONG)


func flowing_cut(slot: int) -> void:
	var flow: int = randi_range(1, 6)
	var roll: int = randi_range(1, 20)
	await _g._dice.play_roll_animation([flow, roll], ["D6", "D20"])
	var two_slash := flow >= 4
	var log := "Flowing Cut: d6=%d → %s.\n" % [flow, "2 slashes" if two_slash else "1 slash"]
	log += _g._player_attacks.attack_round_with_roll(roll, 1.0, _g.CRIT)
	if two_slash and _g.enemy.is_alive():
		var roll2: int = randi_range(1, 20)
		await _g._dice.play_roll_animation([roll2], ["D20"])
		log += _g._player_attacks.attack_round_with_roll(roll2, 0.5, _g.CRIT, 0, false)
	if _g.lbl_log:
		_g.lbl_log.text = log
	await _g._skill_runtime.finish_active_skill_turn(slot)


func duelist_gambit(slot: int) -> void:
	var r1: int = randi_range(1, 20)
	var r2: int = randi_range(1, 20)
	await _g._dice.play_roll_animation([r1, r2], ["D20", "D20"])
	var roll: int = maxi(r1, r2)
	var log := "Duelist's Gambit: d20 %d & %d → use %d.\n" % [r1, r2, roll]
	log += _g._player_attacks.attack_round_with_roll(roll, 1.0, _g.CRIT, 0, true, 19)
	if _g.lbl_log:
		_g.lbl_log.text = log
	await _g._skill_runtime.finish_active_skill_turn(slot)


func aimed_shot(slot: int) -> void:
	var roll: int = randi_range(1, 10)
	await _g._dice.play_roll_animation([_g._player_attacks.d10_face_value(roll)], ["D10"])
	var log := "Aimed Shot: d10=%d (Armor−2).\n" % roll
	log += _g._player_attacks.attack_round_with_roll(roll, 1.20, CombatDefs.SAFE_ATTACK_CRIT, 2)
	if _g.lbl_log:
		_g.lbl_log.text = log
	await _g._skill_runtime.finish_active_skill_turn(slot, CombatDefs.WEAPON_SKILL_CD_BOW)


func overdraw(slot: int) -> void:
	var d20_roll: int = randi_range(1, 20)
	var d10_roll: int = randi_range(1, 10)
	await _g._dice.play_roll_animation(
		[d20_roll, _g._player_attacks.d10_face_value(d10_roll)], ["D20", "D10"]
	)
	_g.player_temp_armor_delta -= 1
	_g._refresh_player_armor_label()
	var enemy_armor: int = _g._player_attacks.enemy_armor_for_player()
	var log := "Overdraw: d20=%d, d10=%d vs Armor %d. Armor −1 until your next action.\n" % [
		d20_roll, d10_roll, enemy_armor
	]
	log += _g._player_attacks.attack_round_with_roll(d20_roll, 1.0, _g.CRIT)
	if d20_roll >= enemy_armor and _g.enemy.is_alive() and d10_roll > 0:
		var bonus_dmg: int = maxi(1, int(round(float(_g.calc_player_weapon_damage()) * 0.08 * float(d10_roll))))
		_g.enemy.take_damage(bonus_dmg)
		_g.show_damage_popup(_g.enemy, str(bonus_dmg), "hit")
		log += "Overdraw burst +%d dmg.\n" % bonus_dmg
	if _g.lbl_log:
		_g.lbl_log.text = log
	await _g._skill_runtime.finish_active_skill_turn(slot, CombatDefs.WEAPON_SKILL_CD_LONG)
