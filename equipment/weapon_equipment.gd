extends RefCounted
class_name WeaponEquipment

var _g: Node2D

func _init(game: Node2D) -> void:
	_g = game


func form_from_name(item_name: String) -> String:
	var n := item_name.to_lower()
	if n == "unarmed" or n == "":
		return ""
	for k in CombatDefs.WEAPON_ICON_NAME_KEYS:
		if k in n:
			return k
	return ""


func form_from_item(it: Dictionary) -> String:
	return form_from_name(String(it.get("name", "")))


func refresh_weapon_skill() -> void:
	var form := form_from_item(_g.weapon)
	if _g.skills.has(CombatDefs.WEAPON_SKILL_SLOT) and String(_g.skills[CombatDefs.WEAPON_SKILL_SLOT].get("source", "")) == "weapon":
		_g.skills.erase(CombatDefs.WEAPON_SKILL_SLOT)
	if form == "":
		_g._update_skills_ui()
		return
	var def: Dictionary = CombatDefs.WEAPON_SKILLS.get(form, {})
	if def.is_empty():
		_g._update_skills_ui()
		return
	_g.skills[CombatDefs.WEAPON_SKILL_SLOT] = {
		"key": "weapon_skill",
		"weapon_form": form,
		"name": String(def.get("name", "Weapon Skill")),
		"type": "active",
		"desc": String(def.get("desc", "")),
		"source": "weapon",
		"icon_key": form,
	}
	if not _g.skill_cooldowns.has(CombatDefs.WEAPON_SKILL_SLOT):
		_g.skill_cooldowns[CombatDefs.WEAPON_SKILL_SLOT] = 0
	_g._update_skills_ui()
