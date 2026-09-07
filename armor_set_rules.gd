class_name ArmorSetRules
extends RefCounted

const SET_SLOTS: Array[String] = ["armor", "helmet", "gloves", "boots"]


static func infer_armor_type(item: Dictionary) -> String:
	if item.is_empty():
		return ""
	var t := String(item.get("armor_type", ""))
	if t != "":
		return t
	var bn: Dictionary = item.get("bonuses", {})
	if int(bn.get("weapon_dmg", 0)) > 0:
		return "berserker"
	if int(bn.get("agi", 0)) > 0:
		return "light"
	if int(bn.get("str", 0)) > 0:
		return "medium"
	if int(bn.get("vit", 0)) > 0:
		return "heavy"
	return ""


static func ensure_armor_type(item: Dictionary) -> void:
	if item.is_empty():
		return
	if String(item.get("armor_type", "")) != "":
		return
	var inferred := infer_armor_type(item)
	if inferred != "":
		item["armor_type"] = inferred


static func type_counts(equipped: Dictionary) -> Dictionary:
	var counts: Dictionary = {}
	for slot in SET_SLOTS:
		var it: Dictionary = equipped.get(slot, {})
		if it.is_empty():
			continue
		var t := infer_armor_type(it)
		if t == "":
			continue
		counts[t] = int(counts.get(t, 0)) + 1
	return counts


static func tier_bonus_for_count(count: int) -> int:
	if count >= 4:
		return 3
	if count >= 3:
		return 2
	if count >= 2:
		return 1
	return 0


static func armor_set_bonus(counts: Dictionary) -> int:
	var bonus := 0
	for t in counts.keys():
		if t == "berserker":
			continue
		bonus = max(bonus, tier_bonus_for_count(int(counts[t])))
	return bonus


static func berserker_set_dmg_bonus(counts: Dictionary) -> int:
	return tier_bonus_for_count(int(counts.get("berserker", 0)))


static func build_summary(equipped: Dictionary) -> String:
	var counts := type_counts(equipped)
	if counts.is_empty():
		return "Armor set: none"
	var parts: PackedStringArray = []
	for t in counts.keys():
		parts.append("%s ×%d" % [String(t).capitalize(), int(counts[t])])
	var lines: PackedStringArray = ["Set: " + ", ".join(parts)]
	var armor_bonus := armor_set_bonus(counts)
	if armor_bonus > 0:
		lines.append("Set bonus: +%d armor" % armor_bonus)
	var bers_dmg := berserker_set_dmg_bonus(counts)
	if bers_dmg > 0:
		lines.append("Berserker set: +%d flat DMG" % bers_dmg)
	return "\n".join(lines)
