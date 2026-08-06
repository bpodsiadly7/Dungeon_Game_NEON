class_name StatusEffectDefs
extends RefCounted

const ID_BLEED := "bleed"
const ID_BURN := "burn"
const ID_POISON := "poison"
const ID_STUN := "stun"

const ICONS := {
	ID_BLEED: "res://ikony/bleeding_icon.png",
	ID_BURN: "res://ikony/burn_icon.png",
	ID_POISON: "res://ikony/poison_icon.png",
	ID_STUN: "res://ikony/stun_icon.png",
}

const DISPLAY_NAMES := {
	ID_BLEED: "Bleeding",
	ID_BURN: "Burning",
	ID_POISON: "Poisoned",
	ID_STUN: "Stunned",
}

## Bronie tnące — mogą nakładać krwawienie (bazowa szansa zależy od rarity broni).
const BLEED_WEAPON_FORMS := ["sword", "blade", "saber", "dagger", "axe"]

## Klucze rarity (zgodne z main.gd: COMMON=0 … UNIQUE=4).
const BLEED_PROC_BY_RARITY := {
	0: 0.10,
	1: 0.16,
	2: 0.24,
	3: 0.32,
	4: 0.40,
}

const BLEED_CRIT_PROC_BONUS := 0.06
const BLEED_GLANCING_PROC_MULT := 0.50

const ENEMY_BLEED_NAME_KEYS := [
	"knife", "blade", "sword", "dagger", "axe", "cut", "slash", "claw",
]

const BLEED := {
	"max_stacks": 3,
	"duration_turns": 3,
	"damage_attacker_mult": 0.80,
	"enemy_proc_chance": 0.22,
}

## DEV — zostawione puste; włącz tylko do lokalnych testów proców.
const DEV_FORCE_BLEED_WEAPON_NAMES: Array[String] = []
const DEV_FORCE_BLEED_ENEMY_NAMES: Array[String] = []


static func bleed_weapon_form(form: String) -> bool:
	return form in BLEED_WEAPON_FORMS


static func weapon_form_from_name(item_name: String) -> String:
	var n := item_name.to_lower()
	if n == "unarmed" or n == "":
		return ""
	for k in CombatDefs.WEAPON_ICON_NAME_KEYS:
		if k in n:
			return k
	return ""


## Bazowa szansa bleed na trafieniu (0.0–1.0), albo -1 gdy broń nie krwawi.
static func bleed_base_proc_chance_for_item(item: Dictionary) -> float:
	var form := weapon_form_from_name(String(item.get("name", "")))
	if not bleed_weapon_form(form):
		return -1.0
	return bleed_proc_chance_for_weapon(item, false, false)


static func bleed_proc_chance_for_weapon(weapon: Dictionary, crit: bool, glancing: bool) -> float:
	var rarity := clampi(int(weapon.get("rarity", 0)), 0, 4)
	var chance := float(BLEED_PROC_BY_RARITY.get(rarity, BLEED_PROC_BY_RARITY[0]))
	if glancing:
		chance *= BLEED_GLANCING_PROC_MULT
	if crit:
		chance += BLEED_CRIT_PROC_BONUS
	return clampf(chance, 0.0, 0.95)


static func enemy_bleed_proc_chance(enemy_data: Dictionary) -> float:
	return float(BLEED.get("enemy_proc_chance", 0.22))


static func enemy_can_bleed(enemy_data: Dictionary) -> bool:
	var explicit := String(enemy_data.get("status_on_hit", ""))
	if explicit == ID_BLEED:
		return true
	if explicit != "":
		return false
	var name_lower := String(enemy_data.get("name", "")).to_lower()
	for key in ENEMY_BLEED_NAME_KEYS:
		if key in name_lower:
			return true
	return false
