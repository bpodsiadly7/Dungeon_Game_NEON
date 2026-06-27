extends RefCounted
class_name CombatDefs

enum AttackMode { BASIC, SAFE, WILD }

const SAFE_ATTACK_CRIT := 10
const WILD_D10_DMG_PER_POINT := 0.06
const DICE_PAIR_LANE_X: Array[float] = [-115.0, 115.0]
const DICE_PAIR_ANIM_SCALE := 0.58
const DICE_PAIR_GAP_SEC := 0.04

const SKILL_COOLDOWN_TURNS := 10
const WEAPON_SKILL_SLOT := 5
const WEAPON_SKILL_CD_LONG := 12
const WEAPON_SKILL_CD_BOW := 9

const WEAPON_ICON_NAME_KEYS := [
	"crossbow", "dagger", "hammer", "spear", "blade", "saber", "mace", "sword", "axe", "bow",
]

const WEAPON_SKILLS := {
	"sword": {
		"name": "Riposte",
		"desc": "d10 attack + d6 parry. Hit: 115% dmg. d6≥5: +1 Armor. d6=6: enemy −1 Armor on your next hit.",
	},
	"axe": {
		"name": "Skull Cleave",
		"desc": "d20 strike: 145% on hit, 45% on miss. No crit.",
	},
	"dagger": {
		"name": "Needle Flurry",
		"desc": "Two d10 attacks (55% dmg each, crit on 10).",
	},
	"mace": {
		"name": "Shatter Guard",
		"desc": "d20 attack; d6 ignores up to 3 enemy Armor. Hit: 110% dmg.",
	},
	"spear": {
		"name": "Lunge",
		"desc": "d10 attack vs Armor−3. 125% dmg, crit on 10.",
	},
	"hammer": {
		"name": "Earthshaker",
		"desc": "d20 + d10: 155% on hit (+4% per d10 point); 55% on miss. No armor penalty.",
		"cd": WEAPON_SKILL_CD_LONG,
	},
	"blade": {
		"name": "Flowing Cut",
		"desc": "d6 then d20: 2 slashes if d6≥4 (2nd at 50%, no crit).",
	},
	"saber": {
		"name": "Duelist's Gambit",
		"desc": "Roll 2× d20, use higher. 100% dmg; 19–20 = crit.",
	},
	"bow": {
		"name": "Aimed Shot",
		"desc": "d10 vs Armor−2. 120% dmg, crit on 10.",
		"cd": WEAPON_SKILL_CD_BOW,
	},
	"crossbow": {
		"name": "Overdraw",
		"desc": "d20 hit + d10 bonus dmg (+8% per point). −1 Armor until your next action.",
		"cd": WEAPON_SKILL_CD_LONG,
	},
}
