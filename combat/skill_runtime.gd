extends RefCounted
class_name SkillRuntime

var _g: Node2D

func _init(game: Node2D) -> void:
	_g = game


func weapon_skill_cd_for(slot: int) -> int:
	var form := String(_g.skills.get(slot, {}).get("weapon_form", ""))
	var def: Dictionary = CombatDefs.WEAPON_SKILLS.get(form, {})
	return int(def.get("cd", CombatDefs.SKILL_COOLDOWN_TURNS))


func finish_active_skill_turn(slot: int, cd_turns: int = -1) -> void:
	if cd_turns < 0:
		cd_turns = weapon_skill_cd_for(slot) if slot == CombatDefs.WEAPON_SKILL_SLOT else CombatDefs.SKILL_COOLDOWN_TURNS
	_g.skill_cooldowns[slot] = cd_turns
	_g._update_skills_ui()
	await _g.get_tree().create_timer(0.1).timeout
	if _g.enemy.is_alive():
		_g.set_turn(_g.Turn.ENEMY)
	_g._tick_skill_cooldowns()
	_g.resolving_turn = false
