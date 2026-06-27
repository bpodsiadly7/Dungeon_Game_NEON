extends Node2D

# --- UI odwołania ---
@onready var lbl_player   := $CanvasLayer/UIRoot/Left/LabelPlayer
@onready var lbl_enemy    := $CanvasLayer/UIRoot/Right/LabelEnemy
@onready var btn_attack: BaseButton = get_node_or_null(
	"CanvasLayer/UIRoot/PanelAttack/AttackLayout/HBox/ColBasic/BtnAttack"
) as BaseButton
@onready var btn_safe_attack: BaseButton = get_node_or_null(
	"CanvasLayer/UIRoot/PanelAttack/AttackLayout/HBox/ColRight/SlotSafe/BtnSafeAttack"
) as BaseButton
@onready var btn_wild_attack: BaseButton = get_node_or_null(
	"CanvasLayer/UIRoot/PanelAttack/AttackLayout/HBox/ColRight/SlotWild/BtnWildAttack"
) as BaseButton
@onready var highlight_attack_basic: ColorRect = get_node_or_null(
	"CanvasLayer/UIRoot/PanelAttack/AttackLayout/HBox/ColBasic/HighlightBasic"
) as ColorRect
@onready var highlight_attack_safe: ColorRect = get_node_or_null(
	"CanvasLayer/UIRoot/PanelAttack/AttackLayout/HBox/ColRight/SlotSafe/HighlightSafe"
) as ColorRect
@onready var highlight_attack_wild: ColorRect = get_node_or_null(
	"CanvasLayer/UIRoot/PanelAttack/AttackLayout/HBox/ColRight/SlotWild/HighlightWild"
) as ColorRect

const _ATTACK_SLOT_HIGHLIGHT_SHADER := preload("res://ui/attack_slot_highlight.gdshader")
const _FLOATING_DAMAGE_NUMBERS := preload("res://ui/floating_damage_numbers.gd")
const _NEAR_DEATH_WARNING_SCRIPT := preload("res://ui/near_death_warning.gd")
const _ENEMY_DEATH_ICON_FX := preload("res://ui/enemy_death_icon_fx.gd")
const _ATTACK_SLOT_HIGHLIGHT_ACCENT_BASIC := Color(0.88, 0.94, 1.0, 1.0)
const _ATTACK_SLOT_HIGHLIGHT_ACCENT_SAFE := Color(0.78, 1.0, 0.86, 1.0)
const _ATTACK_SLOT_HIGHLIGHT_ACCENT_WILD := Color(1.0, 0.78, 0.72, 1.0)
const _ATTACK_SLOT_HIGHLIGHT_STRENGTH_HOVER := 0.92
const _ATTACK_SLOT_HIGHLIGHT_STRENGTH_PRESS := 1.18
const _ATTACK_SLOT_HIGHLIGHT_HOVER_SCALE := Vector2(1.03, 1.04)
const _ATTACK_SLOT_HIGHLIGHT_TWEEN_IN := 0.12
const _ATTACK_SLOT_HIGHLIGHT_TWEEN_OUT := 0.2

var _attack_highlight_tweens: Dictionary = {}
@onready var lbl_log      := $CanvasLayer/UIRoot/Bottom/HBoxContainer/CombatLog
@onready var next_dialog: AcceptDialog = get_node_or_null("CanvasLayer/UIRoot/NextEnemyDialog")
@onready var cam: Camera2D = $Camera2D
@onready var fx_root: Control = $CanvasLayer/UIRoot/FXRoot
@onready var player_hp_bar: ProgressBar = $CanvasLayer/UIRoot/Left/PlayerHPBar
@onready var enemy_hp_bar: ProgressBar = $CanvasLayer/UIRoot/Right/EnemyHPBar
@onready var lbl_player_hp_value: Label = get_node_or_null("CanvasLayer/UIRoot/Left/PlayerHPValue")
@onready var lbl_player_armor_value: Label = get_node_or_null("CanvasLayer/UIRoot/Left/PlayerArmorValue")
@onready var lbl_player_dmg_value: Label = get_node_or_null("CanvasLayer/UIRoot/Left/PlayerDmgValue")
@onready var lbl_enemy_hp_value: Label = get_node_or_null("CanvasLayer/UIRoot/Right/EnemyHPValue")
@onready var lbl_enemy_name: Label = get_node_or_null("CanvasLayer/UIRoot/Right/EnemyNameLabel")
@onready var lbl_enemy_armor_value: Label = get_node_or_null("CanvasLayer/UIRoot/Right/EnemyArmorValue")
@onready var lbl_enemy_dmg_value: Label = get_node_or_null("CanvasLayer/UIRoot/Right/EnemyDmgValue")
@onready var xp_bar: ProgressBar = $CanvasLayer/UIRoot/Left/XPBar
@onready var lbl_level: Label = $CanvasLayer/UIRoot/Left/LevelLabel
var unspent_points_label: Label = null
var _unspent_pulse_tween: Tween = null

# --- Kill context for boss-upgrades ---
var _last_kill_context: Dictionary = {}

@onready var btn_stats: Button = get_node_or_null("CanvasLayer/UIRoot/Left/StatsButton")
@onready var dice_viewport := $DiceViewport  # NIE $CanvasLayer/DiceViewport
@onready var dice_roller := $DiceViewport/DiceRoller
@onready var dice_display := $CanvasLayer/UIRoot/DiceDisplay
var inventory_screen: Control = null
 
var home_overlay: ColorRect

var is_in_home: bool = false
var _near_death_layer: CanvasLayer
var _near_death_warning: Control


# --- Potions UI ---
@onready var potion_icon: TextureRect = $CanvasLayer/UIRoot/Left/PotionsUI/PotionIcon
@onready var potion_label: Label = $CanvasLayer/UIRoot/Left/PotionsUI/PotionLabel
@onready var btn_use_potion: BaseButton = get_node_or_null("CanvasLayer/UIRoot/PanelPotion/BtnPotion") as BaseButton

# --- Boss choice dialog ---
@onready var dungeon_choice: ConfirmationDialog = get_node_or_null("CanvasLayer/UIRoot/DungeonChoiceDialog")

var next_enemy_data: Dictionary = {}
var DMG_FONT: FontFile = preload("res://MedievalSharp-Bold.ttf")

enum Turn { PLAYER, ENEMY }
enum AttackMode { BASIC, SAFE, WILD }

const SAFE_ATTACK_CRIT := CombatDefs.SAFE_ATTACK_CRIT
const WILD_D10_DMG_PER_POINT := CombatDefs.WILD_D10_DMG_PER_POINT

var turn: Turn = Turn.PLAYER
var enemy_turn_delay: float = 0.6

## Modyfikator pancerza gracza (Safe: +wynik d6 / Wild: -1) — do początku następnej tury gracza.
var player_temp_armor_delta: int = 0
## Jednorazowe obniżenie armor wroga przy następnym trafieniu gracza (np. Riposta).
var enemy_armor_penalty: int = 0
var _default_dice_set: Array[DiceDef] = []

var current_enemy_data: Dictionary = {}
var resolving_turn: bool = false
var _chest_reward_handled: bool = false
var _game_pause_depth: int = 0
var _inventory_pause_active: bool = false

var _dice: DicePlayback
var _player_attacks: PlayerAttacks
var _weapon_skills: WeaponSkills
var _class_skills: ClassSkills
var _skill_runtime: SkillRuntime
var _weapon_equipment: WeaponEquipment

var _heal_particles: GPUParticles2D

# --- Postacie ---
@onready var player := $Player
@onready var enemy  := $Enemy

# --- Ewolucja Krasnoluda ---
const EVOLVE_LEVEL := 10  # ← do testów; docelowo 10
var has_evolved: bool = false
var chosen_class: String = ""  # "warrior" / "assassin" / "guardian" / "barbarian"

const CLASS_TEXTURES := {
	"warrior":   "res://player_classes/dwarf_warrior.png",
	"assassin":  "res://player_classes/dwarf_assasin.png",
	"guardian":  "res://player_classes/dwarf_guardian.png",
	"barbarian": "res://player_classes/dwarf_barbarian.png",
}

const CLASS_EVOLUTION_INFO := {
	"warrior": {
		"name": "Warrior",
		"tagline": "Iron master of the blade.",
		"active": "Power Strike — guaranteed critical hit (costs 10% HP).",
		"passive": "Weapon Mastery — +10% weapon damage.",
		"accent": Color(0.95, 0.55, 0.35),
	},
	"assassin": {
		"name": "Assassin",
		"tagline": "Swift and unseen.",
		"active": "Quick Slash — two fast hits (60–100% dmg each).",
		"passive": "Cat Movement — 5% chance to dodge a hit.",
		"accent": Color(0.45, 0.90, 0.65),
	},
	"guardian": {
		"name": "Guardian",
		"tagline": "Unbreakable bulwark.",
		"active": "Shield — block the next incoming hit.",
		"passive": "Heavily Armed — +1 Armor.",
		"accent": Color(0.45, 0.70, 1.0),
	},
	"barbarian": {
		"name": "Barbarian",
		"tagline": "Uncontrolled fury.",
		"active": "Fury — two back-to-back attacks.",
		"passive": "Bloodlust — heal 10% of damage on CRIT.",
		"accent": Color(0.95, 0.35, 0.30),
	},
}

var _evolution_overlay: Control = null
var _evolution_tooltip: VBoxContainer = null
var _evolution_hint_label: Label = null
var _evolution_particles: Dictionary = {}
var _evolution_slot_nodes: Dictionary = {}
var _evolution_hovered_key: String = ""
var _evolution_particles_root: Node2D = null
var _evolution_title_host: Control = null
var _evolution_content: Control = null
var _evolution_dim: ColorRect = null
var _evolution_suppressed_ui: Array = []
var _evolution_ready: bool = false
var _evolution_pending: bool = false

# --- SKILLS ---
const SKILL_COOLDOWN_TURNS := CombatDefs.SKILL_COOLDOWN_TURNS
const WEAPON_SKILL_SLOT := CombatDefs.WEAPON_SKILL_SLOT
const WEAPON_SKILL_CD_LONG := CombatDefs.WEAPON_SKILL_CD_LONG
const WEAPON_SKILL_CD_BOW := CombatDefs.WEAPON_SKILL_CD_BOW
const WEAPON_ICON_NAME_KEYS := CombatDefs.WEAPON_ICON_NAME_KEYS

# slot->skill dict (na start tylko slot 1 = Power Strike)
var skills: Dictionary = {}
# slot->pozostałe tury cooldownu
var skill_cooldowns: Dictionary = {}

const RING_SKILLS := {
	"ring_skill_placeholder": {"key":"quick_slash", "name":"Quick Slash", "type":"active", "desc":"Two fast hits."},
}

# Flagi/parametry pod przyszłe klasy (pasywki)
var shield_active: bool = false                 # Guardian active: blok 100% next hit
var passive_dodge_chance: float = 0.0           # Assassin passive
var passive_armor_bonus: int = 0                # Guardian passive (flat armor, capped with total)
var bloodlust_lifesteal: float = 0.0            # Barbarian passive (ułamek leczenia z crita)

# --- Modularne UI: sloty aktywne/pasywne z main.tscn (liczba wg sceny) ---
var skill_bar_buttons: Array[BaseButton] = []
var skill_bar_slot_numbers: Array[int] = []
var passive_skill_slots: Array[TextureRect] = []
var skills_hotbar_wired: bool = false
var _style_skill_hotbar_empty: StyleBoxFlat

const _SKILL_BAR_STYLE_STATES := [
	"normal", "hover", "pressed", "disabled", "focus",
]

var lbl_dungeon_name: Label

# --- SKILL ICONS MAP ---
const SKILL_ICONS: Dictionary = {
	"Basic Strike": "res://ikony/basic_strike.png",
	"Basic strike": "res://ikony/basic_strike.png",
	"Power Strike": "res://ikony/power_strike.png",
	"Quick Slash":  "res://ikony/quick_slash.png",
	"Shield":       "res://ikony/shield_block.png",
	"Shield Block": "res://ikony/shield_block.png",
	"Fury":         "res://ikony/fury.png",
}

func _skill_icon_for(skill_name: String) -> Texture2D:
	if skill_name == "":
		return null
	if SKILL_ICONS.has(skill_name):
		var t1 = load(String(SKILL_ICONS[skill_name]))
		if t1 is Texture2D: return t1
	# fallback: res://ikony/<nazwa_mala_z_podkreslnikami>.png
	var guess := "res://ikony/%s.png" % skill_name.to_lower().replace(" ", "_")
	if ResourceLoader.exists(guess):
		var t2 = load(guess)
		if t2 is Texture2D: return t2
	return null


# --- Parametry walki ---
const HIT_DC := 11
const CRIT := 20
const CRIT_MULT := 2.0

# --- Skalowanie obrażeń i kryta ---
const STR_DMG_PER_POINT := 0.04
const AGI_DMG_PER_POINT := 0.03
const CRIT_PER_POINT    := 0.05
## Zgodnie z player.gd VIT_HP_PER_POINT — używane przy max_hp z bazy + VIT (+ hełm).
const PLAYER_VIT_HP_PER_POINT := 12

# Broń gracza
var weapon = {
	"name": "Rusty Sword",
	"base": 10,
	"scale": {"str": 1.0, "agi": 0}
}

# --- Dungeon progres ---
var dungeon_level:int = 1
var enemies_defeated:int = 0

# --- HP potions ---
const POTION_HEAL := 50
const POTION_MAX := 3
const POTION_DROP_CHANCE := 0.15
const TEX_HP_BOTTLE_1: Texture2D = preload("res://ikony/HpBottleIcon.png")
const TEX_HP_BOTTLE_2: Texture2D = preload("res://ikony/HpBottleIcon2.png")
const TEX_HP_BOTTLE_3: Texture2D = preload("res://ikony/HpBottleIcon3.png")
var potions:int = 0

# --- LOOT / DROP ---
# Szansa na drop jakiegokolwiek itemu vs. trudność przeciwnika
const DROP_CHANCE_BY_DIFF := {
	1: 0.15,  # łatwy
	2: 0.15,
	3: 0.20,
	4: 0.33,
	5: 0.42   # boss/trudny
}

# Wagi rzadkości w zależności od trudności (im trudniej, tym większa szansa na lepsze)
const RARITY_WEIGHTS_BY_DIFF := {
	# Legend/Unique are excluded from normal rolls (Legend=0% drop, Unique=boss-defined)
	1: {Rarity.COMMON: 80, Rarity.RARE: 18, Rarity.EPIC: 2},
	2: {Rarity.COMMON: 65, Rarity.RARE: 28, Rarity.EPIC: 7},
	3: {Rarity.COMMON: 50, Rarity.RARE: 35, Rarity.EPIC: 15},
	4: {Rarity.COMMON: 38, Rarity.RARE: 38, Rarity.EPIC: 24},
	5: {Rarity.COMMON: 25, Rarity.RARE: 35, Rarity.EPIC: 40}
}

# --- PERMANENT badge (kolory) ---
const PERMA_COL_BG      := Color(0.18, 0.32, 0.12, 0.95)
const PERMA_COL_BORDER  := Color(0.45, 0.80, 0.35, 1.0)
const PERMA_COL_TEXT    := Color(0.92, 1.00, 0.92, 1.0)


# --- INVENTORY: sloty, rzadkości, stan UI ---
enum Rarity { COMMON, RARE, EPIC, LEGEND, UNIQUE }
const RARITY_COLORS := {
	Rarity.COMMON: Color(1,1,1),
	Rarity.RARE: Color(0.45,0.75,1.0),
	Rarity.EPIC: Color(0.75,0.55,0.95),
	Rarity.LEGEND: Color(1.0,0.85,0.2),
	Rarity.UNIQUE: Color(0.30, 1.00, 0.85)
}

# Spójne klucze: "weapon", "armor", "helmet", "necklace"
var inventory: Dictionary = {
	"weapon":  [],   # Array[Dictionary]
	"armor":   [],   # Array[Dictionary]
	"helmet":  [],   # Array[Dictionary]
	"necklace":[],   # Array[Dictionary]
	"gloves":  [],   # Array[Dictionary]
	"boots":   [],   # Array[Dictionary]
	"ring1":   [],   # Array[Dictionary]
	"ring2":   [],   # Array[Dictionary]
}

# Założone przedmioty
var equipped_armor:   Dictionary = {}
var equipped_helmet:  Dictionary = {}
var equipped_necklace:Dictionary = {}
var equipped_gloves:  Dictionary = {}
var equipped_boots:   Dictionary = {}
var equipped_ring1:   Dictionary = {}
var equipped_ring2:   Dictionary = {}

# --- INVENTORY ICONS (mapowanie typów) ---

const ICON_BY_TYPE := {
	"sword":     "res://ikony/sword_icon.png",
	"axe":       "res://ikony/axe_icon.png",
	"dagger":    "res://ikony/dagger_icon.png",
	"mace":      "res://ikony/mace_icon.png",
	"spear":     "res://ikony/spear_icon.png",
	"hammer":    "res://ikony/hammer_icon.png",
	"blade":     "res://ikony/blade_icon.png",
	"saber":     "res://ikony/saber_icon.png",
	"bow":       "res://ikony/bow_icon.png",
	"crossbow":  "res://ikony/crossbow_icon.png",
	"armor":     "res://ikony/armor_icon.png",
	"armor_light":     "res://ikony/armor_light_icon.png",
	"armor_medium":    "res://ikony/armor_medium_icon.png",
	"armor_heavy":     "res://ikony/armor_heavy_icon.png",
	"armor_berserker": "res://ikony/armor_berserker_icon.png",
	"helmet":    "res://ikony/helmet_icon.png",
	"helmet_light":     "res://ikony/helmet_light_icon.png",
	"helmet_medium":    "res://ikony/helmet_medium_icon.png",
	"helmet_heavy":     "res://ikony/helmet_heavy_icon.png",
	"helmet_berserker": "res://ikony/helmet_berserker_icon.png",
	"necklace":  "res://ikony/necklace_icon.png",
	"gloves":    "res://ikony/gloves_icon.png",
	"gloves_light":     "res://ikony/gloves_light_icon.png",
	"gloves_medium":    "res://ikony/gloves_medium_icon.png",
	"gloves_heavy":     "res://ikony/gloves_heavy_icon.png",
	"gloves_berserker": "res://ikony/gloves_berserker_icon.png",
	"boots":     "res://ikony/boots_icon.png",
	"boots_light":     "res://ikony/boots_light_icon.png",
	"boots_medium":    "res://ikony/boots_medium_icon.png",
	"boots_heavy":     "res://ikony/boots_heavy_icon.png",
	"boots_berserker": "res://ikony/boots_berserker_icon.png",
	"ring1": "res://ikony/ring_icon.png",
	"ring2": "res://ikony/ring_icon.png",
	"potion":    "res://ikony/potion_icon.png"
}

# --- ITEM BONUSY OD RZADKOŚCI ---
const BONUS_CHANCE_RARE    := 0.6   # Rare: 60% szans na bonus +1
const BONUS_CHANCE_EPIC    := 1.0   # Epic: zawsze bonus +2..+3
const BONUS_CHANCE_LEG     := 1.0   # Legend: zawsze bonus +3..+8
const BONUS_STATS := ["str","agi","vit","crit"]  # które staty mogą wypaść

# Unique: boss-defined items (not rolled randomly)
# Keying by enemy name for now; can be switched to boss_id later.
const UNIQUE_ITEMS_BY_BOSS := {
	# Example:
	# "Lich King": {
	# 	"type":"weapon",
	# 	"name":"Soulrender (Unique)",
	# 	"rarity": Rarity.UNIQUE,
	# 	"base": 12,
	# 	"scale": {"str": 0.6, "agi": 0.6},
	# 	"bonuses": {"crit": 2},
	# 	"unique_effect": "On Crit: gain 1 potion charge.",
	# }
}


# --- UI THEME / COLORS ---
const UI_COL = {
	"panel": Color(0.08, 0.09, 0.12, 0.94),
	"panel_dark": Color(0.05, 0.06, 0.08, 0.98),
	"border": Color(0.25, 0.28, 0.35, 1.0),
	"accent": Color(0.95, 0.82, 0.30, 1.0),
	"text_dim": Color(0.85, 0.85, 0.88, 0.9),
	"equip_badge": Color(0.35, 0.75, 1.0, 1.0),
}

func _make_stylebox(bg: Color, border: Color, radius: int = 10, border_w: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = border_w
	sb.border_width_right = border_w
	sb.border_width_top = border_w
	sb.border_width_bottom = border_w
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.anti_aliasing = true
	# Delikatny cień (Godot 4)
	sb.shadow_size = 6
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_offset = Vector2(0, 2)
	return sb

func _rarity_strip_color(r: int) -> Color:
	return RARITY_COLORS.get(r, Color.WHITE)

# --- BACKGROUNDS (jedno tło w warstwie świata) ---
var bg_sprite: Sprite2D = null  # tło w warstwie świata (zawsze za postaciami)

# Klucze muszą być identyczne jak DUNGEONS[i]["name"]
const BG_BY_DUNGEON := {
	"Goblin Cave":      "res://backgrounds/goblin_cave.png",
	"Undead Crypt":     "res://backgrounds/undead_crypt.png",
	"Highlands":        "res://backgrounds/highlands.png",
	"Orc Warcamps":     "res://backgrounds/orc_warcamps.png",
	"Dark Elf Depths":  "res://backgrounds/dark_elf_depths.png",
	"Elderwood":        "res://backgrounds/elderwood.png",
}

# --- TREASURE (random event) ---
const MIN_EVENT_INTERVAL := 8        # ile zwykłych starć musi minąć między eventami
var _event_gap_counter: int = 0      # rośnie przy zwykłych wrogach, reset przy evencie


const TREASURE_EVENT_CHANCE := 0.10  # 10% szansy zamiast przeciwnika (zmień, jeśli chcesz)
const TREASURE_TEX := "res://treasures/mystery_chest.png"  # opcjonalna grafika skrzyni

const SHRINE_CHANCE: float = 0.10  # TESTOWO (łatwo wywołać). Po teście zmień np. na 0.10.
var _shrine_open: bool = false
var _shrine_locked: bool = false
var _shrine_in_progress: bool = false
var shrine_cooldown: int = 0              # ile zwykłych walk jeszcze blokuje Shrine
var _encounter_replaced_by_event: bool = false  # czy aktualny encounter to event (Shrine/Chest)





const TREASURE_CHEST_DATA := {
	"name": "Mystery Chest",
	"hp": 50,
	"damage": 0,
	"difficulty": 5,   # żeby użyć tych samych wag jak boss (drop/rarity)
	"treasure": true,
	"tex": TREASURE_TEX
}



# --- Dungeon 1 (Goblin Cave) ---
const MASTER_ENEMIES: Array[Dictionary] = [
	{"name":"Goblin Servant",  "hp":18, "damage":1,  "difficulty":1, "xp":5,  "tex":"res://gobliny/goblin_servant.png"},
	{"name":"Goblin Gatherer", "hp":22, "damage":3,  "difficulty":1, "xp":12, "tex":"res://gobliny/goblin_gatherer.png"},
	{"name":"Goblin Knife",    "hp":28, "damage":7,  "difficulty":2, "xp":16, "tex":"res://gobliny/goblin_knife.png"},
	{"name":"Goblin Warrior",  "hp":34, "damage":9,  "difficulty":2, "xp":20, "tex":"res://gobliny/goblin_warrior.png"},
	{"name":"Goblin Guard",    "hp":40, "damage":11, "difficulty":3, "xp":25, "tex":"res://gobliny/goblin_guard.png"},
	{"name":"Goblin Elite",    "hp":48, "damage":13, "difficulty":3, "xp":30, "tex":"res://gobliny/goblin_elite.png"},
	{"name":"Goblin Captain",  "hp":56, "damage":13, "difficulty":4, "xp":35, "tex":"res://gobliny/goblin_captain.png"},
	{"name":"Goblin Champion", "hp":66, "damage":15, "difficulty":4, "xp":40, "tex":"res://gobliny/goblin_champion.png"},
	{"name":"Goblin General",  "hp":78, "damage":20, "difficulty":5, "xp":45, "tex":"res://gobliny/goblin_general.png"},
	{"name":"Goblin King",     "hp":95, "damage":24, "difficulty":5, "xp":80, "tex":"res://gobliny/goblin_king.png"},
]

# --- Dungeon 2 (Undead Crypt) – placeholder ---
const UNDEAD_ENEMIES: Array[Dictionary] = [
	{"name":"Skeleton Grunt",   "hp":40, "damage":10, "difficulty":2, "xp":28, "tex":"res://skeletons/skeleton_grunt.png"},
	{"name":"Skeleton Archer",  "hp":44, "damage":12, "difficulty":3, "xp":32, "tex":"res://skeletons/skeleton_archer.png"},
	{"name":"Bone Knight",      "hp":100, "damage":16, "difficulty":4, "xp":42, "tex":"res://skeletons/bone_knight.png"},
	{"name":"Bone Warlock",     "hp":80, "damage":20, "difficulty":4, "xp":48, "tex":"res://skeletons/bone_warlock.png"},
	{"name":"Lich",             "hp":200, "damage":30, "difficulty":5, "xp":100, "tex":"res://skeletons/lich.png"},
]

# --- Dungeon 3: Highlands (Mountain Men) ---
const MOUNTAIN_MEN_ENEMIES: Array[Dictionary] = [
	{"name":"Highland Recruit",   "hp":70,  "damage":14, "difficulty":2, "xp":36, "tex":"res://humans/highland_recruit.png"},
	{"name":"Highland Slinger",   "hp":76,  "damage":16, "difficulty":2, "xp":38, "tex":"res://humans/highland_slinger.png"},
	{"name":"Spearman",           "hp":84,  "damage":18, "difficulty":3, "xp":42, "tex":"res://humans/spearman.png"},
	{"name":"Sword Adept",        "hp":92,  "damage":20, "difficulty":3, "xp":46, "tex":"res://humans/sword_adept.png"},
	{"name":"Shield Guard",       "hp":104, "damage":22, "difficulty":3, "xp":50, "tex":"res://humans/shield_guard.png"},
	{"name":"Crossbowman",        "hp":98,  "damage":24, "difficulty":4, "xp":56, "tex":"res://humans/crossbowman.png"},
	{"name":"War Priest",         "hp":110, "damage":26, "difficulty":4, "xp":62, "tex":"res://humans/war_priest.png"},
	{"name":"Veteran Captain",    "hp":126, "damage":28, "difficulty":4, "xp":68, "tex":"res://humans/veteran_captain.png"},
	{"name":"Mountain Champion",  "hp":145, "damage":30, "difficulty":5, "xp":78, "tex":"res://humans/mountain_champion.png"},
	{"name":"High King of Peaks", "hp":230, "damage":35, "difficulty":5, "xp":120,"tex":"res://humans/high_king.png"},
]

# --- Dungeon 4: Orc Warcamps ---
const ORC_ENEMIES: Array[Dictionary] = [
	{"name":"Orc Grunt",       "hp":80,  "damage":18, "difficulty":2, "xp":40, "tex":"res://orcs/orc_grunt.png"},
	{"name":"Orc Skirmisher",  "hp":86,  "damage":20, "difficulty":2, "xp":42, "tex":"res://orcs/orc_skirmisher.png"},
	{"name":"Orc Berserker",   "hp":94,  "damage":24, "difficulty":3, "xp":48, "tex":"res://orcs/orc_berserker.png"},
	{"name":"Orc Ravager",     "hp":102, "damage":26, "difficulty":3, "xp":52, "tex":"res://orcs/orc_ravager.png"},
	{"name":"Boar Rider",      "hp":110, "damage":28, "difficulty":3, "xp":56, "tex":"res://orcs/boar_rider.png"},
	{"name":"Demolisher",      "hp":118, "damage":30, "difficulty":4, "xp":64, "tex":"res://orcs/demolisher.png"},
	{"name":"War Shaman",      "hp":120, "damage":34, "difficulty":4, "xp":70, "tex":"res://orcs/war_shaman.png"},
	{"name":"Blackguard",      "hp":134, "damage":36, "difficulty":4, "xp":78, "tex":"res://orcs/blackguard.png"},
	{"name":"Warmaster",       "hp":150, "damage":40, "difficulty":5, "xp":88, "tex":"res://orcs/warmaster.png"},
	{"name":"Orc Warlord",     "hp":260, "damage":42, "difficulty":5, "xp":140,"tex":"res://orcs/orc_warlord.png"},
] 

# --- Dungeon 5: Dark Elf Depths ---
const DARK_ELF_ENEMIES: Array[Dictionary] = [
	{"name":"Drow Initiate",     "hp":72,  "damage":20, "difficulty":2, "xp":44, "tex":"res://darkelves/drow_initiate.png"},
	{"name":"Drow Scout",        "hp":78,  "damage":22, "difficulty":2, "xp":46, "tex":"res://darkelves/drow_scout.png"},
	{"name":"Shade Duelist",     "hp":86,  "damage":24, "difficulty":3, "xp":52, "tex":"res://darkelves/shade_duelist.png"},
	{"name":"Gloom Archer",      "hp":92,  "damage":26, "difficulty":3, "xp":56, "tex":"res://darkelves/gloom_archer.png"},
	{"name":"Umbral Adept",      "hp":100, "damage":28, "difficulty":3, "xp":60, "tex":"res://darkelves/umbral_adept.png"},
	{"name":"Nightblade",        "hp":108, "damage":32, "difficulty":4, "xp":68, "tex":"res://darkelves/nightblade.png"},
	{"name":"Whisper Sorcerer",  "hp":112, "damage":36, "difficulty":4, "xp":76, "tex":"res://darkelves/whisper_sorcerer.png"},
	{"name":"Matron Guard",      "hp":126, "damage":38, "difficulty":4, "xp":84, "tex":"res://darkelves/matron_guard.png"},
	{"name":"House Champion",    "hp":144, "damage":44, "difficulty":5, "xp":96, "tex":"res://darkelves/house_champion.png"},
	{"name":"Dread Matriarch",   "hp":240, "damage":48, "difficulty":5, "xp":150,"tex":"res://darkelves/dread_matriarch.png"},
]

# --- Dungeon 6: Elderwood (Ents) ---
const ENT_ENEMIES: Array[Dictionary] = [
	{"name":"Sapling",           "hp":90,  "damage":14, "difficulty":2, "xp":40, "tex":"res://ents/sapling.png"},
	{"name":"Rootling",          "hp":98,  "damage":16, "difficulty":2, "xp":42, "tex":"res://ents/rootling.png"},
	{"name":"Barkguard",         "hp":112, "damage":18, "difficulty":3, "xp":48, "tex":"res://ents/barkguard.png"},
	{"name":"Spinebough",        "hp":126, "damage":20, "difficulty":3, "xp":54, "tex":"res://ents/spinebough.png"},
	{"name":"Thorncaster",       "hp":138, "damage":22, "difficulty":3, "xp":58, "tex":"res://ents/thorncaster.png"},
	{"name":"Oakwarden",         "hp":156, "damage":24, "difficulty":4, "xp":68, "tex":"res://ents/oakwarden.png"},
	{"name":"Ironwood Ancient",  "hp":174, "damage":26, "difficulty":4, "xp":76, "tex":"res://ents/ironwood_ancient.png"},
	{"name":"Grove Sentinel",    "hp":192, "damage":30, "difficulty":4, "xp":86, "tex":"res://ents/grove_sentinel.png"},
	{"name":"Primeval Husk",     "hp":220, "damage":34, "difficulty":5, "xp":98, "tex":"res://ents/primeval_husk.png"},
	{"name":"Ancient Worldroot", "hp":320, "damage":38, "difficulty":5, "xp":160,"tex":"res://ents/ancient_worldroot.png"},
]

const DUNGEONS := {
	0: {"name":"Goblin Cave",   "enemies":MASTER_ENEMIES},
	1: {"name":"Undead Crypt",  "enemies":UNDEAD_ENEMIES},
	2: {"name":"Highlands",     "enemies":MOUNTAIN_MEN_ENEMIES}, # Mountain Men
	3: {"name":"Orc Warcamps",  "enemies":ORC_ENEMIES},
	4: {"name":"Dark Elf Depths","enemies":DARK_ELF_ENEMIES},
	5: {"name":"Elderwood",     "enemies":ENT_ENEMIES},
}

# --- Aktywny dungeon/roster ---
var current_roster: Array[Dictionary] = []
var current_dungeon_index: int = 0  # 0 = Goblin Cave, 1 = Undead Crypt, 2..5 = nowe

# --- Odwiedzone dungeony (start od 0) ---
var visited_dungeons: Array[int] = [0]
# Stałe połączenia między dungeonami — klucz: skąd, wartości: dokąd można przejść
const DUNGEON_CONNECTIONS := {
	0: [1, 2],   # Goblin Cave → Undead Crypt, Highlands
	1: [3, 4],   # Undead Crypt → Orc Warcamps, Dark Elf Depths
	2: [3, 5],   # Highlands → Orc Warcamps, Elderwood
	3: [4, 5],   # Orc Warcamps → Dark Elf Depths, Elderwood
	4: [5],      # Dark Elf Depths → Elderwood
	5: [],       # Elderwood — ostatni dungeon
}



# --- Start ---
func _ready() -> void:
	print("[DEBUG] _ready() START")
	for e in current_roster:
		if typeof(e) != TYPE_DICTIONARY or not (e.has("name") and e.has("hp") and e.has("damage") and e.has("difficulty")):
			push_warning("Bad ENEMIES entry: %s" % str(e))
	randomize()
	# Sygnały HP / śmierci
	player.hp_changed.connect(_on_player_hp_changed)
	player.died.connect(_on_player_died)
	enemy.hp_changed.connect(_on_enemy_hp_changed)
	enemy.defeated.connect(_on_enemy_defeated)
	# Sygnały XP / poziom / staty
	player.xp_changed.connect(_on_player_xp_changed)
	player.level_changed.connect(_on_player_level_changed)
	player.stats_changed.connect(_on_player_stats_changed)
	if btn_stats:
		btn_stats.pressed.connect(_toggle_inventory_from_stats_button)
	# Boss choice dialog
	if dungeon_choice:
		dungeon_choice.confirmed.connect(_on_dungeon_choice_confirmed)
		dungeon_choice.canceled.connect(_on_dungeon_choice_canceled)
	# Stan startowy panelu
	_on_player_stats_changed(player.strength, player.agility, player.vitality, player.crit, player.stat_points)
	# Attack (Basic / Safe / Wild)
	turn = Turn.PLAYER
	_init_combat_modules()
	if fx_root:
		fx_root.visible = true
		fx_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fx_root.z_index = 200
	_setup_near_death_warning()
	_dice.cache_default_dice_set()
	_set_attack_buttons_disabled(false)
	_wire_attack_slot_ui()
	# Next enemy dialog
	if next_dialog:
		next_dialog.confirmed.connect(Callable(self, "_on_next_enemy_confirmed"))
	else:
		push_error("NextEnemyDialog not found.")
		print_tree()
	player.damaged.connect(_on_player_damaged)
	# XP/Level UI
	if xp_bar:
		xp_bar.show_percentage = true
		_on_player_xp_changed(player.xp, player.xp_to_next)
	if lbl_level:
		_on_player_level_changed(player.level, player.stat_points)
	# Potions
	_update_potions_ui()
	if btn_use_potion:
		btn_use_potion.pressed.connect(_on_use_potion_pressed)
	_ensure_heal_particles()

	# Załaduj statystyki gracza z poprzedniego runa
	var saved_player := GameState.load_player(player)
	if not saved_player.is_empty():
		_on_player_stats_changed(player.strength, player.agility, player.vitality, player.crit, player.stat_points)
		_on_player_xp_changed(player.xp, player.xp_to_next)
		_on_player_level_changed(player.level, player.stat_points)
	if player.level >= EVOLVE_LEVEL:
		_request_evolution_choice()

	# Inventory + UI
	_load_permanent_items_into_inventory()
	_sync_player_max_hp_from_gear()

	# ===== SKILLS: START =====
	# Slot [1] = Basic Strike (zastąpiony później przez Power Strike po wyborze Warrior)
	skills.clear()
	skill_cooldowns.clear()
	skills[1] = {"key":"basic_strike", "name":"Basic Strike", "type":"active", "desc":"Reliable hit."}
	skill_cooldowns[1] = 0
	# slot [2] zostawiamy pusty – do klasowych umiejętności
	_create_skills_ui()
	_refresh_weapon_skill()
	_update_skills_ui()
	# ===== SKILLS: END =====
	_apply_global_font()

	# ===== background =====
	_ensure_world_background()
	_apply_world_background_for_current_dungeon()
	_update_world_background_position()

	# Pierwszy przeciwnik

	# Załaduj dungeon wybrany w home_scene
	var start_idx: int = int(GameState.run.get("dungeon_index", 0))
	if DUNGEONS.has(start_idx):
		current_dungeon_index = start_idx
		current_roster = (DUNGEONS[start_idx]["enemies"] as Array[Dictionary]).duplicate(true)
	else:
		current_dungeon_index = 0
		current_roster = (DUNGEONS[0]["enemies"] as Array[Dictionary]).duplicate(true)
	_apply_world_background_for_current_dungeon()

	# Załaduj visited_dungeons z GameState
	var saved_visited: Array = GameState.meta.get("visited_dungeons", [0])
	visited_dungeons.clear()
	for v in saved_visited:
		visited_dungeons.append(int(v))
	if not visited_dungeons.has(current_dungeon_index):
		visited_dungeons.append(current_dungeon_index)

	_spawn_enemy(_pick_enemy())

	# --- Label aktualnego dungeonu ---
	lbl_dungeon_name = Label.new()
	lbl_dungeon_name.text = "Current dungeon: %s" % String(DUNGEONS[current_dungeon_index]["name"])
	lbl_dungeon_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_dungeon_name.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	lbl_dungeon_name.add_theme_font_size_override("font_size", 22)
	lbl_dungeon_name.position = Vector2(get_viewport_rect().size.x / 2 - 200, 10)
	lbl_dungeon_name.size = Vector2(400, 40)
	lbl_dungeon_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	lbl_dungeon_name.z_index = 99

	# czcionka
	var font_res: FontFile = load("res://MedievalSharp-Bold.ttf")
	lbl_dungeon_name.add_theme_font_override("font", font_res)

	# dodaj na CanvasLayer, jeśli masz
	if $CanvasLayer:
		$CanvasLayer.add_child(lbl_dungeon_name)
	else:
		add_child(lbl_dungeon_name)

	set_turn(Turn.PLAYER)
	# tylko w wersji testowej gry:
	#_dev_fill_inventory()
	set_process_unhandled_input(true)
	_dev_create_panel()
	# Stwórz wyższy CanvasLayer dla inventory
	var inv_layer := CanvasLayer.new()
	inv_layer.layer = 10
	inv_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(inv_layer)
	var inv_scene := load("res://inventory_screen.tscn") as PackedScene
	inventory_screen = inv_scene.instantiate()
	inv_layer.add_child(inventory_screen)
	inventory_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Podłącz inventory screen
	if inventory_screen:
		inventory_screen.closed.connect(_on_inventory_closed)
		inventory_screen.shrine_item_confirmed.connect(_on_shrine_item_confirmed)
		inventory_screen.shrine_closed.connect(_on_shrine_closed)
		inventory_screen.item_equipped.connect(_on_inventory_equip)
		inventory_screen.item_dropped.connect(_on_inventory_drop)
		inventory_screen.item_unequipped.connect(_on_inventory_unequip)
		inventory_screen.stat_spent.connect(func(key: String):
			if player.stat_points <= 0:
				return
			match key:
				"str":  player.add_strength()
				"agi":  player.add_agility()
				"vit":  player.add_vitality()
				"crit": player.add_crit()
			inventory_screen.player_stats["stat_points"] = player.stat_points
			_apply_effective_primary_stats_to_inventory_screen()
			inventory_screen.player_stats["hp"] = player.hp
			inventory_screen.player_stats["max_hp"] = player.max_hp
			inventory_screen.player_stats["chosen_class"] = chosen_class
			inventory_screen.player_stats["passive_armor_bonus"] = passive_armor_bonus
			inventory_screen._refresh_stats()
		)
		inventory_screen.set_run_player_texture_supplier(func() -> Variant:
			return player.texture
		)

	# ... koniec _ready() 
	print("[DEBUG] _ready() END")
	_ensure_unspent_points_label()
	_update_unspent_points_indicator(player.stat_points)


func _init_combat_modules() -> void:
	_dice = DicePlayback.new(self)
	_player_attacks = PlayerAttacks.new(self)
	_weapon_skills = WeaponSkills.new(self)
	_class_skills = ClassSkills.new(self)
	_skill_runtime = SkillRuntime.new(self)
	_weapon_equipment = WeaponEquipment.new(self)


func _sync_inventory_screen_if_open() -> void:
	if inventory_screen == null or not is_instance_valid(inventory_screen):
		return
	if not inventory_screen.visible:
		return
	inventory_screen.equipped = {
		"weapon": weapon,
		"armor": equipped_armor,
		"helmet": equipped_helmet,
		"necklace": equipped_necklace,
		"gloves": equipped_gloves,
		"boots": equipped_boots,
		"ring1": equipped_ring1,
		"ring2": equipped_ring2,
	}
	_apply_effective_primary_stats_to_inventory_screen()
	inventory_screen.player_stats["stat_points"] = player.stat_points
	inventory_screen.player_stats["hp"] = player.hp
	inventory_screen.player_stats["max_hp"] = player.max_hp
	inventory_screen.player_stats["chosen_class"] = chosen_class
	inventory_screen.player_stats["passive_armor_bonus"] = passive_armor_bonus
	inventory_screen._refresh_stats()
	inventory_screen._refresh_all_slots()
	inventory_screen._refresh_backpack()


func _inventory_ui_stats() -> Dictionary:
	var e := _player_effective_stat_pack_for_ui()
	return {
		"str": int(e["str"]),
		"agi": int(e["agi"]),
		"vit": int(e["vit"]),
		"crit": int(e["crit"]),
		"stat_points": player.stat_points,
		"hp": player.hp,
		"max_hp": player.max_hp,
		"chosen_class": chosen_class,
		"passive_armor_bonus": passive_armor_bonus,
	}


func _inventory_ui_equipped() -> Dictionary:
	return {
		"weapon": weapon,
		"armor": equipped_armor,
		"helmet": equipped_helmet,
		"necklace": equipped_necklace,
		"gloves": equipped_gloves,
		"boots": equipped_boots,
		"ring1": equipped_ring1,
		"ring2": equipped_ring2,
	}


func open_inventory() -> void:
	if _shrine_open:
		return
	if inventory_screen:
		inventory_screen.open(inventory, _inventory_ui_equipped(), _inventory_ui_stats())
		_set_inventory_paused(true)

func _on_inventory_closed() -> void:
	_set_inventory_paused(false)
	_update_near_death_warning()
	print("[INVENTORY] Closed")

func _on_inventory_equip(slot_key: String, idx: int) -> void:
	_equip_item(slot_key, idx)
	inventory_screen.equipped = {
		"weapon":   weapon,
		"armor":    equipped_armor,
		"helmet":   equipped_helmet,
		"necklace": equipped_necklace,
		"gloves":   equipped_gloves,
		"boots":    equipped_boots,
		"ring1":    equipped_ring1,
		"ring2":    equipped_ring2,
	}
	_apply_effective_primary_stats_to_inventory_screen()
	inventory_screen.player_stats["stat_points"] = player.stat_points
	inventory_screen.player_stats["hp"] = player.hp
	inventory_screen.player_stats["max_hp"] = player.max_hp
	inventory_screen.player_stats["chosen_class"] = chosen_class
	inventory_screen.player_stats["passive_armor_bonus"] = passive_armor_bonus
	inventory_screen._refresh_stats()
	inventory_screen._refresh_all_slots()
	inventory_screen._refresh_backpack()

func _on_inventory_drop(slot_key: String, idx: int) -> void:
	# TODO: dodaj potwierdzenie drop
	inventory[slot_key].remove_at(idx)
	inventory_screen._refresh_backpack()

func _on_inventory_unequip(slot_key: String) -> void:
	_unequip_item(slot_key)
	inventory_screen.equipped = {
		"weapon":   weapon,
		"armor":    equipped_armor,
		"helmet":   equipped_helmet,
		"necklace": equipped_necklace,
		"gloves":   equipped_gloves,
		"boots":    equipped_boots,
		"ring1":    equipped_ring1,
		"ring2":    equipped_ring2,
	}
	_apply_effective_primary_stats_to_inventory_screen()
	inventory_screen.player_stats["stat_points"] = player.stat_points
	inventory_screen.player_stats["hp"] = player.hp
	inventory_screen.player_stats["max_hp"] = player.max_hp
	inventory_screen.player_stats["chosen_class"] = chosen_class
	inventory_screen.player_stats["passive_armor_bonus"] = passive_armor_bonus
	inventory_screen._refresh_stats()
	inventory_screen._refresh_all_slots()
	inventory_screen._refresh_backpack()



func enter_home() -> void:
	# Zapisz odwiedzone dungeony do meta
	GameState.meta["visited_dungeons"] = visited_dungeons.duplicate()
	_strip_all_equipment_bonuses_for_save()
	GameState.save_player(player, has_evolved, chosen_class)
	GameState.end_run_to_home(true)
	GameState.save(GameState.current_slot)
	get_tree().change_scene_to_file("res://home_scene.tscn")


func start_run_from_home() -> void:
	print("[HOME] start_run_from_home()")
	# NIE zmieniamy player.visible ani player.position
	# (jeśli chcesz tu wywołać start encounteru, zrób to poniżej:
	# _spawn_next_enemy() )


func _apply_global_font() -> void:
	var font_res: FontFile = preload("res://MedievalSharp-Bold.ttf")
	if font_res == null:
		push_warning("MedievalSharp-Bold.ttf not found!")
		return

	# Pobierz Theme z głównego UI
	var theme := Theme.new()
	theme.set_default_font(font_res)

	# Opcjonalnie: ustaw wielkości bazowe
	theme.default_font_size = 18

	# Tooltipy: czytelniejsze (większa czcionka + ciemne tło)
	theme.set_font_size("font_size", "TooltipLabel", 22)
	theme.set_color("font_color", "TooltipLabel", Color(0.95, 0.95, 0.97, 1.0))
	theme.set_color("font_outline_color", "TooltipLabel", Color(0, 0, 0, 1.0))
	theme.set_constant("outline_size", "TooltipLabel", 6)
	var tip_panel := StyleBoxFlat.new()
	tip_panel.bg_color = Color(0.05, 0.06, 0.08, 0.96)
	tip_panel.border_color = Color(0.85, 0.75, 0.30, 0.95)
	tip_panel.border_width_left = 2
	tip_panel.border_width_top = 2
	tip_panel.border_width_right = 2
	tip_panel.border_width_bottom = 2
	tip_panel.corner_radius_top_left = 10
	tip_panel.corner_radius_top_right = 10
	tip_panel.corner_radius_bottom_left = 10
	tip_panel.corner_radius_bottom_right = 10
	tip_panel.shadow_size = 8
	tip_panel.shadow_color = Color(0, 0, 0, 0.45)
	tip_panel.shadow_offset = Vector2(0, 2)
	theme.set_stylebox("panel", "TooltipPanel", tip_panel)
	theme.set_constant("margin_left", "TooltipPanel", 10)
	theme.set_constant("margin_top", "TooltipPanel", 8)
	theme.set_constant("margin_right", "TooltipPanel", 10)
	theme.set_constant("margin_bottom", "TooltipPanel", 8)

	# Zastosuj do całego drzewa UI pod CanvasLayer
	var root_canvas := $CanvasLayer
	if root_canvas:
		# Podpinamy theme do korzenia UI, żeby tooltips też go używały
		var ui_root := get_node_or_null("CanvasLayer/UIRoot") as Control
		if ui_root:
			ui_root.theme = theme
		for node in root_canvas.find_children("*", "Control", true, false):
			if node is Control:
				node.add_theme_font_override("font", font_res)
	else:
		push_warning("CanvasLayer not found to apply font theme.")


func set_turn(t: Turn) -> void:
	turn = t
	if t == Turn.PLAYER:
		_refresh_player_armor_label()
	_update_near_death_warning()
	_set_attack_buttons_disabled(turn != Turn.PLAYER or _is_evolution_choice_open())
	if turn == Turn.PLAYER:
		if lbl_log: lbl_log.text = "Your turn. Choose an attack."
	else:
		if lbl_log: lbl_log.text = "Enemy is thinking..."
		if _is_evolution_choice_open():
			return
		await get_tree().create_timer(enemy_turn_delay).timeout
		if _is_evolution_choice_open():
			return
		_enemy_take_turn()
	_update_potions_ui()

func _enemy_take_turn() -> void:
	if _is_evolution_choice_open():
		return
	if resolving_turn: return
	if turn != Turn.ENEMY or not enemy.is_alive() or not player.is_alive(): return
	resolving_turn = true
	var desc: String = await _enemy_attack_round_async()
	if lbl_log: lbl_log.text = desc
	await get_tree().create_timer(0.1).timeout
	if player.is_alive():
		set_turn(Turn.PLAYER)
	resolving_turn = false

func shake_camera(intensity: float = 6.0, duration: float = 0.15) -> void:
	if cam == null:
		return
	var original := cam.offset
	var t := get_tree().create_tween()
	var steps := 6
	for i in range(steps):
		var dir := Vector2(randf() * 2.0 - 1.0, randf() * 2.0 - 1.0).normalized()
		var off := dir * intensity
		t.tween_property(cam, "offset", off, duration / steps * 0.9)
	t.tween_property(cam, "offset", original, duration * 0.2)

func _push_game_pause() -> void:
	_game_pause_depth += 1
	get_tree().paused = true


func _pop_game_pause() -> void:
	_game_pause_depth = maxi(0, _game_pause_depth - 1)
	get_tree().paused = _game_pause_depth > 0


func _set_inventory_paused(active: bool) -> void:
	if active:
		if _inventory_pause_active:
			return
		_inventory_pause_active = true
		_push_game_pause()
	else:
		if not _inventory_pause_active:
			return
		_inventory_pause_active = false
		_pop_game_pause()


func hitstop(time_sec: float = 0.07) -> void:
	_push_game_pause()
	await get_tree().create_timer(time_sec, true).timeout
	_pop_game_pause()

func _pick_enemy() -> Dictionary:
	# 1) Eventy (Shrine / Chest) tylko gdy minął odstęp
	if _event_gap_counter >= MIN_EVENT_INTERVAL:
		# --- Sacred Shrine (EVENT) ---
		if randf() < SHRINE_CHANCE:
			_event_gap_counter = 0
			return {"name":"Sacred Shrine","hp":0,"damage":0,"difficulty":0,"shrine":true}
		# --- Mystery Chest (EVENT) ---
		if randf() < TREASURE_EVENT_CHANCE:
			_event_gap_counter = 0
			return TREASURE_CHEST_DATA.duplicate(true)

	# 2) Budowa puli zwykłych przeciwników
	var pool: Array[Dictionary] = []
	var valid_all: Array[Dictionary] = []
	var cap: int = max(1, dungeon_level + 1)

	for ed in current_roster:
		if not (ed.has("name") and ed.has("hp") and ed.has("damage")):
			continue
		var diff: int = int(ed.get("difficulty", 1))
		valid_all.append(ed)
		if diff <= cap:
			var weight: int = max(1, 6 - diff)
			for _i in range(weight):
				pool.append(ed)

	print("[PICK] dungeon_level=%d cap=%d | pool=%d | valid_all=%d" %
		[dungeon_level, cap, pool.size(), valid_all.size()])

	# 3) Awaryjne wybory zwykłych przeciwników + inkrementacja licznika odstępu
	if pool.is_empty() and not valid_all.is_empty():
		var pick_any: Dictionary = valid_all[randi() % valid_all.size()]
		if _event_gap_counter < MIN_EVENT_INTERVAL:
			_event_gap_counter += 1
		return pick_any

	if pool.is_empty():
		if _event_gap_counter < MIN_EVENT_INTERVAL:
			_event_gap_counter += 1
		return {"name":"Fallback Goblin","hp":20,"damage":5,"difficulty":1}

	# 4) Normalny wybór z puli + inkrementacja licznika odstępu
	if _event_gap_counter < MIN_EVENT_INTERVAL:
		_event_gap_counter += 1
	return pool[randi() % pool.size()]
	




func _spawn_enemy_impl(data: Dictionary) -> void:
	var name := String(data.get("name", ""))
	if name.to_lower().find("shrine") != -1 or bool(data.get("shrine", false)):
		# awaryjne przekierowanie – gdyby coś ominęło router
		call_deferred("_open_shrine_dialog")
		return


	player_temp_armor_delta = 0
	enemy_armor_penalty = 0
	current_enemy_data = data.duplicate(true)
	# Ensure armor exists (new armor system). Fallback from difficulty.
	if not current_enemy_data.has("armor"):
		var diff = clamp(int(current_enemy_data.get("difficulty", 1)), 1, 5)
		current_enemy_data["armor"] = clamp(diff + 2, 0, 15)
	enemy.setup_enemy(
		current_enemy_data["name"],
		current_enemy_data["hp"],
		current_enemy_data["damage"],
		current_enemy_data.get("tex", ""),
		int(current_enemy_data.get("difficulty", 1)),
		bool(current_enemy_data.get("treasure", false))
	)
	_update_labels()
	_update_near_death_warning()


	if data.get("treasure", false):
		if lbl_log:
			lbl_log.text = "A mysterious chest appears! Press Attack to open it."
	else:
		if lbl_log:
			lbl_log.text = "A wild %s appears!" % data["name"]
		if _is_current_boss(name):
			var audio := get_node_or_null("/root/GameAudio")
			if audio:
				audio.play_boss_announce()



func _prepare_next_enemy_with_popup() -> void:
	next_enemy_data = _pick_enemy().duplicate(true)
	if typeof(next_enemy_data) != TYPE_DICTIONARY \
	or not (next_enemy_data.has("name") and next_enemy_data.has("hp") and next_enemy_data.has("damage")):
		push_warning("Bad next_enemy_data: %s" % str(next_enemy_data))
		next_enemy_data = {"name":"Fallback Goblin","hp":20,"damage":5,"difficulty":1}

	if next_dialog:
		next_dialog.dialog_text = "Next enemy!: %s" % next_enemy_data["name"]
		if _is_current_boss(String(next_enemy_data.get("name", ""))):
			var audio := get_node_or_null("/root/GameAudio")
			if audio:
				audio.play_boss_announce()
		next_dialog.popup_centered()
	else:
		_request_spawn(next_enemy_data)

func _on_next_enemy_confirmed() -> void:
	if next_enemy_data.is_empty():
		next_enemy_data = _pick_enemy().duplicate(true)
		if typeof(next_enemy_data) != TYPE_DICTIONARY \
		or not (next_enemy_data.has("name") and next_enemy_data.has("hp") and next_enemy_data.has("damage")):
			next_enemy_data = {"name":"Fallback Goblin","hp":20,"damage":5,"difficulty":1}
	_request_spawn(next_enemy_data)
	next_enemy_data = {}
	set_turn(Turn.PLAYER)

func _process(_d: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):  # ESC
		if inventory_screen and inventory_screen.visible:
			inventory_screen._on_close()
	
	if Input.is_action_just_pressed("attack"):
		_try_attack_hotkey(AttackMode.BASIC)
	elif Input.is_action_just_pressed("attack_safe"):
		_try_attack_hotkey(AttackMode.SAFE)
	elif Input.is_action_just_pressed("attack_wild"):
		_try_attack_hotkey(AttackMode.WILD)
	# unspent points indicator is positioned under dungeon label
	_update_world_background_position()


func _prepare_attack_highlight(slot: ColorRect, accent: Color) -> void:
	if slot == null:
		return
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.color = Color(1, 1, 1, 1)
	slot.scale = Vector2.ONE
	var mat := ShaderMaterial.new()
	mat.shader = _ATTACK_SLOT_HIGHLIGHT_SHADER
	mat.set_shader_parameter("glow_color", accent)
	mat.set_shader_parameter("strength", 0.0)
	slot.material = mat
	slot.resized.connect(func() -> void:
		slot.pivot_offset = slot.size * 0.5
	)
	slot.pivot_offset = slot.size * 0.5


func _kill_attack_highlight_tween(slot: ColorRect) -> void:
	if slot == null:
		return
	var key: int = slot.get_instance_id()
	if not _attack_highlight_tweens.has(key):
		return
	var tw: Variant = _attack_highlight_tweens[key]
	if tw is Tween and (tw as Tween).is_valid():
		(tw as Tween).kill()
	_attack_highlight_tweens.erase(key)


func _set_attack_slot_highlight(slot: ColorRect, active: bool, pressed: bool = false) -> void:
	if slot == null or not is_instance_valid(slot):
		return
	_kill_attack_highlight_tween(slot)

	var mat := slot.material as ShaderMaterial
	if mat == null:
		return

	var target_strength: float = 0.0
	var target_scale: Vector2 = Vector2.ONE
	var duration: float = _ATTACK_SLOT_HIGHLIGHT_TWEEN_OUT
	var trans: Tween.TransitionType = Tween.TRANS_CUBIC
	var ease: Tween.EaseType = Tween.EASE_OUT

	if active:
		if pressed:
			target_strength = _ATTACK_SLOT_HIGHLIGHT_STRENGTH_PRESS
			duration = 0.07
			trans = Tween.TRANS_QUAD
		else:
			target_strength = _ATTACK_SLOT_HIGHLIGHT_STRENGTH_HOVER
			target_scale = _ATTACK_SLOT_HIGHLIGHT_HOVER_SCALE
			duration = _ATTACK_SLOT_HIGHLIGHT_TWEEN_IN

	var current_strength: float = float(mat.get_shader_parameter("strength"))
	var tw := create_tween()
	tw.set_parallel(true)
	tw.set_trans(trans)
	tw.set_ease(ease)
	tw.tween_method(
		func(v: float) -> void:
			mat.set_shader_parameter("strength", v),
		current_strength,
		target_strength,
		duration
	)
	tw.tween_property(slot, "scale", target_scale, duration)
	_attack_highlight_tweens[slot.get_instance_id()] = tw


func _clear_attack_slot_highlights() -> void:
	_set_attack_slot_highlight(highlight_attack_basic, false)
	_set_attack_slot_highlight(highlight_attack_safe, false)
	_set_attack_slot_highlight(highlight_attack_wild, false)


func _wire_attack_slot_ui() -> void:
	_prepare_attack_highlight(highlight_attack_basic, _ATTACK_SLOT_HIGHLIGHT_ACCENT_BASIC)
	_prepare_attack_highlight(highlight_attack_safe, _ATTACK_SLOT_HIGHLIGHT_ACCENT_SAFE)
	_prepare_attack_highlight(highlight_attack_wild, _ATTACK_SLOT_HIGHLIGHT_ACCENT_WILD)
	_wire_one_attack_slot(btn_attack, highlight_attack_basic, AttackMode.BASIC)
	_wire_one_attack_slot(btn_safe_attack, highlight_attack_safe, AttackMode.SAFE)
	_wire_one_attack_slot(btn_wild_attack, highlight_attack_wild, AttackMode.WILD)


func _wire_one_attack_slot(btn: BaseButton, highlight: ColorRect, mode: AttackMode) -> void:
	if btn == null:
		return
	btn.pressed.connect(func(): _execute_player_attack(mode))
	btn.mouse_entered.connect(func():
		if not btn.disabled:
			_set_attack_slot_highlight(highlight, true)
	)
	btn.mouse_exited.connect(func():
		_set_attack_slot_highlight(highlight, false)
	)
	btn.button_down.connect(func():
		if not btn.disabled:
			_set_attack_slot_highlight(highlight, true, true)
	)
	btn.button_up.connect(func():
		if not btn.disabled and btn.is_hovered():
			_set_attack_slot_highlight(highlight, true, false)
		else:
			_set_attack_slot_highlight(highlight, false)
	)


func _set_attack_buttons_disabled(disabled: bool) -> void:
	if btn_attack:
		btn_attack.disabled = disabled
	if btn_safe_attack:
		btn_safe_attack.disabled = disabled
	if btn_wild_attack:
		btn_wild_attack.disabled = disabled
	if disabled:
		_clear_attack_slot_highlights()


func _refresh_player_armor_label() -> void:
	if lbl_player_armor_value:
		lbl_player_armor_value.text = str(_calc_player_armor_total())
	_update_near_death_warning()


func _try_attack_hotkey(mode: AttackMode) -> void:
	if resolving_turn:
		return
	if inventory_screen and inventory_screen.visible:
		return
	if turn != Turn.PLAYER or not player.is_alive() or not enemy.is_alive():
		return
	_execute_player_attack(mode)


func _execute_player_attack(mode: AttackMode) -> void:
	await _player_attacks.execute_attack(mode)


func _player_safe_attack_round(atk_roll: int, guard_roll: int) -> String:
	return _player_attacks.safe_attack_round(atk_roll, guard_roll)


func _enemy_armor_for_player(armor_ignore: int = 0) -> int:
	return _player_attacks.enemy_armor_for_player(armor_ignore)


func _consume_enemy_armor_penalty() -> void:
	_player_attacks.consume_enemy_armor_penalty()


func _player_attack_round_with_roll(
	roll: int,
	extra_dmg_mult: float = 1.0,
	crit_on: int = CRIT,
	armor_ignore: int = 0,
	allow_crit: bool = true,
	wide_crit_from: int = -1
) -> String:
	return _player_attacks.attack_round_with_roll(
		roll, extra_dmg_mult, crit_on, armor_ignore, allow_crit, wide_crit_from
	)


func damage_multiplier_from_roll(roll: int, armor: int, max_non_crit: int = 19) -> float:
	return _player_attacks.damage_multiplier_from_roll(roll, armor, max_non_crit)


func _d10_face_value(roll_1_to_10: int) -> int:
	return _player_attacks.d10_face_value(roll_1_to_10)


# --- Tura przeciwnika ---
func _enemy_attack_round_async(force_crit: bool = false) -> String:
	if not enemy.is_alive() or not player.is_alive():
		return ""
	if bool(current_enemy_data.get("treasure", false)):
		return "The chest does nothing..."

	var roll: int = CRIT if force_crit else randi_range(1, 20)
	var player_armor: int = _calc_player_armor_total()

	if roll == CRIT:
		if passive_dodge_chance > 0.0 and randf() < passive_dodge_chance:
			show_damage_popup(player, "dodge", "miss")
			return "Enemy rolls %d → would CRIT, but you DODGE!" % roll
		var parried := await _run_crit_parry_minigame()
		if parried:
			show_damage_popup(player, "PARRY", "miss")
			return "Enemy rolls %d → CRIT, but you PARRY! No damage." % roll
		var dmg_crit: int = int(round(enemy.damage * CRIT_MULT))
		_apply_player_damage(dmg_crit, "crit")
		return "Enemy rolls %d vs Armor %d → CRIT for %d dmg." % [roll, player_armor, dmg_crit]

	if roll < player_armor:
		show_damage_popup(player, "dodge", "miss")
		return "Enemy rolls %d vs Armor %d → MISS." % [roll, player_armor]

	if roll == player_armor:
		var dmg_half: int = max(1, int(round(float(enemy.damage) * 0.5)))
		_apply_player_damage(dmg_half, "hit")
		return "Enemy rolls %d vs Armor %d → HALF for %d dmg." % [roll, player_armor, dmg_half]

	if roll > player_armor:
		if passive_dodge_chance > 0.0 and randf() < passive_dodge_chance:
			show_damage_popup(player, "dodge", "miss")
			return "Enemy rolls %d → would HIT, but you DODGE!" % roll
		var mult := damage_multiplier_from_roll(roll, player_armor)
		var dmg_hit: int = max(1, int(round(float(enemy.damage) * mult)))
		_apply_player_damage(dmg_hit, "hit")
		return "Enemy rolls %d vs Armor %d → HIT for %d dmg." % [roll, player_armor, dmg_hit]
	return ""


func _crit_parry_rot_speed_for_enemy() -> float:
	var diff := clampi(int(current_enemy_data.get("difficulty", 1)), 1, 5)
	return lerpf(5.0, 12.0, float(diff - 1) / 4.0)


func _run_crit_parry_minigame() -> bool:
	var layer := $CanvasLayer
	if layer == null:
		return false
	var mg := CritParryMinigame.new()
	layer.add_child(mg)
	var ok: bool = await mg.run(_crit_parry_rot_speed_for_enemy())
	if is_instance_valid(mg):
		mg.queue_free()
	return ok


func _roll_treasure_chest_reward() -> Dictionary:
	var boss_drop_chance := float(DROP_CHANCE_BY_DIFF.get(5, 0.42))
	if randf() <= boss_drop_chance:
		var slot_roll := randi() % 100
		var slot_key := ""
		if slot_roll < 40:
			slot_key = "weapon"
		elif slot_roll < 75:
			slot_key = "armor"
		elif slot_roll < 90:
			slot_key = "helmet"
		else:
			slot_key = "necklace"
		var rarity := _weighted_rarity_by_diff(5)
		var item := _gen_random_item(slot_key, rarity, 5)
		return {
			"kind": "item",
			"item": item,
			"color": RARITY_COLORS.get(rarity, Color.WHITE),
		}
	return {
		"kind": "heal",
		"icons": [TEX_HP_BOTTLE_1, TEX_HP_BOTTLE_2, TEX_HP_BOTTLE_3],
	}


func _apply_treasure_chest_reward(reward: Dictionary) -> void:
	if reward.get("kind") == "item":
		var item: Dictionary = reward.get("item", {})
		var ref := _add_item_to_inventory(item)
		if lbl_log:
			lbl_log.text = "Treasure: %s (%s)" % [
				str(item.get("name", "???")),
				_rarity_name(int(item.get("rarity", Rarity.COMMON)))
			]
		show_damage_popup(player, str(item.get("name", "???")), "heal")
		_sync_inventory_screen_if_open()
		if not ref.is_empty():
			_show_loot_toast(item)
	else:
		player.hp = player.max_hp
		player.emit_signal("hp_changed", player.hp, player.max_hp)
		if potions < POTION_MAX:
			potions = POTION_MAX
			_update_potions_ui()
		show_damage_popup(player, "FULL HEAL", "heal")
		if lbl_log:
			lbl_log.text = "Treasure: fully healed and potions refilled!"


func _run_chest_minigame(reward: Dictionary) -> void:
	var layer := $CanvasLayer
	if layer == null:
		return
	var mg := ChestMinigame.new()
	layer.add_child(mg)
	await mg.run(reward)
	if is_instance_valid(mg):
		mg.queue_free()



# Wspólna aplikacja obrażeń na gracza
func _apply_player_damage(dmg:int, kind:String = "hit") -> void:
	# BLOCK z Guardiana – całkowicie anuluje jedno kolejne trafienie
	if shield_active:
		shield_active = false
		show_damage_popup(player, "BLOCK", "heal")
		if lbl_log:
			lbl_log.text = "Your shield blocks the entire hit!"
		return

	var original:int = clamp(dmg, 0, 99999)

	var final_dmg:int = max(0, original)

	if final_dmg <= 0:
		show_damage_popup(player, "0", "hit")
		return

	var audio := get_node_or_null("/root/GameAudio")
	if audio:
		audio.play_player_hit(kind == "crit")

	player.take_damage(final_dmg)
	show_damage_popup(player, str(final_dmg), kind)



func _transition_to_next_enemy() -> void:
	if btn_attack:
		btn_attack.disabled = true

	var audio := get_node_or_null("/root/GameAudio")
	if audio:
		audio.play_enemy_transition()

	var start_pos: Vector2 = enemy.position
	var tw_out := get_tree().create_tween()
	tw_out.tween_property(enemy, "modulate:a", 0.0, 0.18)
	tw_out.parallel().tween_property(enemy, "position:x", start_pos.x + 60.0, 0.18)
	await tw_out.finished

	# Wybór następnego encounteru
	var next_data: Dictionary = _pick_enemy()

	# Przygotuj scenę pod nowe wejście
	enemy.modulate.a = 0.0
	enemy.position = Vector2(start_pos.x - 60.0, start_pos.y)

	# KLUCZOWE: spawn zawsze przez router (obsłuży Shrine/Chest itd.)
	_request_spawn(next_data)

	# Daj jedną–dwie klatki na zmianę sprite/labeli zanim wjedziemy tweenem
	await get_tree().process_frame
	await get_tree().process_frame

	# „Wejście” nowego przeciwnika
	var tw_in := get_tree().create_tween()
	tw_in.tween_property(enemy, "modulate:a", 1.0, 0.22)
	tw_in.parallel().tween_property(enemy, "position:x", start_pos.x, 0.22)
	await tw_in.finished

	if btn_attack:
		btn_attack.disabled = false


func _flat_weapon_dmg_from_armor_pieces() -> int:
	var total := 0
	for it in [equipped_helmet, equipped_armor, equipped_gloves, equipped_boots]:
		if typeof(it) != TYPE_DICTIONARY or (it as Dictionary).is_empty():
			continue
		var b: Dictionary = (it as Dictionary).get("bonuses", {})
		total += int(b.get("weapon_dmg", 0))
	return total


func calc_player_weapon_damage() -> int:
	var base:int = int(weapon.get("base", weapon.get("damage", 10)))
	var bonuses: Dictionary = weapon.get("bonuses", {})
	base += int(bonuses.get("weapon_dmg", 0))
	base += _flat_weapon_dmg_from_armor_pieces()
	var gb: Dictionary = _equipment_primary_bonuses_total()
	var wscale:Dictionary = weapon.get("scale", {})
	var mult := 1.0
	mult += float(player.strength + int(gb["str"])) * STR_DMG_PER_POINT * float(wscale.get("str", 0.0))
	mult += float(player.agility + int(gb["agi"])) * AGI_DMG_PER_POINT * float(wscale.get("agi", 0.0))

	# Warrior passive: Weapon Mastery (~+10% dmg)
	if chosen_class == "warrior":
		mult *= 1.10

	return max(1, int(round(base * mult)))


# --- (opcjonalne) Losowanie nowego przeciwnika bez popupa ---
# _load_next_enemy() -- usunięta (martwy kod; zastąpiona przez _transition_to_next_enemy + _request_spawn)

# --- Aktualizacje UI ---
func _on_player_hp_changed(cur:int, maxv:int) -> void:
	if player_hp_bar:
		player_hp_bar.max_value = maxv
		player_hp_bar.value = cur
	var a := _calc_player_armor_total()
	var dmg: int = calc_player_weapon_damage()
	if lbl_player_hp_value:
		lbl_player_hp_value.text = "%d/%d" % [cur, maxv]
	if lbl_player_armor_value:
		lbl_player_armor_value.text = str(a)
	if lbl_player_dmg_value:
		lbl_player_dmg_value.text = str(dmg)
	# legacy corner label: keep empty for new HUD
	if lbl_player:
		lbl_player.text = ""
	_update_potions_ui()
	_update_near_death_warning()

func _calc_player_armor_total() -> int:
	var base := 0
	if not equipped_armor.is_empty():
		base = int(equipped_armor.get("armor", 0))
	var types := []
	for it in [equipped_armor, equipped_helmet, equipped_gloves, equipped_boots]:
		if typeof(it) == TYPE_DICTIONARY and not (it as Dictionary).is_empty():
			var t := String((it as Dictionary).get("armor_type", ""))
			# Berserker nie daje bonusu setowego do armor — tylko flat dmg z bonuses.
			if t != "" and t != "berserker":
				types.append(t)
	# set bonus: 2 same -> +1, 3 same -> +2
	var bonus := 0
	if types.size() >= 2:
		var counts := {}
		for t in types:
			counts[t] = int(counts.get(t, 0)) + 1
		for t in counts.keys():
			var c := int(counts[t])
			if c == 2:
				bonus = max(bonus, 1)
			elif c >= 3:
				bonus = max(bonus, 2)
	return clamp(base + bonus + passive_armor_bonus + player_temp_armor_delta, 0, 15)

func _on_enemy_hp_changed(cur:int, maxv:int) -> void:
	if enemy_hp_bar:
		enemy_hp_bar.max_value = maxv
		enemy_hp_bar.value = cur
	var a = clamp(int(current_enemy_data.get("armor", 0)), 0, 15)
	if lbl_enemy_hp_value:
		lbl_enemy_hp_value.text = "%d/%d" % [cur, maxv]
	if lbl_enemy_name:
		lbl_enemy_name.text = str(enemy.name_display)
	if lbl_enemy_armor_value:
		lbl_enemy_armor_value.text = str(a)
	if lbl_enemy_dmg_value:
		lbl_enemy_dmg_value.text = str(int(enemy.damage))
	# legacy corner label: keep empty for new HUD
	if lbl_enemy:
		lbl_enemy.text = ""

func _on_enemy_defeated() -> void:
	_spawn_enemy_death_icon_fx()
	var last_enemy: Dictionary = {}
	if typeof(current_enemy_data) == TYPE_DICTIONARY:
		last_enemy = current_enemy_data.duplicate(true)
		# --- Treasure Chest reward flow ---
	if bool(last_enemy.get("treasure", false)):
		if not _chest_reward_handled:
			var reward := _roll_treasure_chest_reward()
			_apply_treasure_chest_reward(reward)
		else:
			_chest_reward_handled = false
		await _transition_to_next_enemy()
		set_turn(Turn.PLAYER)
		return
	var gained_xp := 15
	var killed_name := "???"
	if not last_enemy.is_empty():
		killed_name = str(last_enemy.get("name", "???"))
		var diff := int(last_enemy.get("difficulty", 1))
		var base := int(last_enemy.get("xp", 10 + 10 * (diff - 1)))
		gained_xp = base + int(diff * (player.level * 0.2))
		print("[XP] Killed: %s | diff=%d | base=%d | lvl=%d → gained=%d" %
			[killed_name, diff, base, player.level, gained_xp])
	else:
		push_warning("last_enemy snapshot empty; using fallback XP=%d" % gained_xp)
	player.add_xp(gained_xp)
	if lbl_log:
		lbl_log.text = "Enemy defeated! +%d XP" % gained_xp
	_try_drop_potion()
		# PRÓBA DROPu ITEMU
	_roll_enemy_loot_drop(last_enemy)
	enemies_defeated += 1
	if enemies_defeated % 20 == 0:
		dungeon_level += 1
		print("[DUNGEON] Level up → dungeon_level=", dungeon_level)
	if _is_current_boss(killed_name):
		await _try_upgrade_weapon_on_boss_kill(last_enemy)
		_offer_branch_choice_after_boss()
		return




	await _transition_to_next_enemy()
	set_turn(Turn.PLAYER)

func _try_upgrade_weapon_on_boss_kill(enemy_data: Dictionary) -> void:
	# Upgrade rule: weapon used to kill boss upgrades by +1 tier (in-place)
	if _last_kill_context.is_empty():
		return
	var w_before: Dictionary = _last_kill_context.get("weapon_before", {})
	if w_before.is_empty():
		return
	var old_r := int(w_before.get("rarity", Rarity.COMMON))
	var new_r := _next_rarity(old_r)
	if new_r == -1:
		return

	var deltas := upgrade_item_rarity_in_place(weapon, new_r)
	await _show_weapon_upgrade_popup(w_before, weapon, deltas)
	_update_labels()

func _next_rarity(r: int) -> int:
	match r:
		Rarity.COMMON: return Rarity.RARE
		Rarity.RARE:   return Rarity.EPIC
		Rarity.EPIC:   return Rarity.LEGEND
		_:            return -1

func upgrade_item_rarity_in_place(item: Dictionary, new_rarity: int) -> Dictionary:
	var deltas := {}
	var old_r := int(item.get("rarity", Rarity.COMMON))
	item["rarity"] = new_rarity

	# If it's a weapon, bump base damage into the new rarity band.
	if String(item.get("type", "")) == "weapon":
		var mm: Vector2i = _weapon_base_minmax_for_rarity(new_rarity)
		var old_base: int = int(item.get("base", 0))
		# guarantee a bump if possible (prevents "no base gain" upgrades)
		var min_target: int = max(old_base + 1, mm.x)
		if min_target > mm.y:
			min_target = mm.y
		var target: int = int(randi_range(min_target, mm.y))
		var new_base: int = target
		if new_base != old_base:
			item["base"] = new_base
			deltas["base_dmg"] = new_base - old_base

	# add one new rolled bonus appropriate for new rarity (guaranteed for boss upgrades)
	var b := _roll_bonus_for_rarity_guaranteed(new_rarity)
	if not b.is_empty():
		var stat := String(b.get("stat", ""))
		var val := int(b.get("value", 0))
		if stat != "" and val > 0:
			# prefer bonuses dict
			var bonuses: Dictionary = item.get("bonuses", {})
			bonuses[stat] = int(bonuses.get(stat, 0)) + val
			item["bonuses"] = bonuses
			deltas[stat] = int(deltas.get(stat, 0)) + val
	# legacy fields stay as-is; we don't add new ones (prevents duplicate displays)
	return deltas

func _roll_bonus_for_rarity_guaranteed(rarity: int) -> Dictionary:
	# Boss upgrades should always grant a visible stat gain.
	match rarity:
		Rarity.RARE:
			return {"stat": _rand_bonus_stat(), "value": 1}
		Rarity.EPIC:
			return {"stat": _rand_bonus_stat(), "value": randi_range(2, 3)}
		Rarity.LEGEND:
			return {"stat": _rand_bonus_stat(), "value": randi_range(3, 8)}
		_:
			return {}

func _show_weapon_upgrade_popup(old_w: Dictionary, new_w: Dictionary, deltas: Dictionary) -> void:
	if not $CanvasLayer:
		return
	# Use Control-based popup (Window doesn't support modulate/scale tweens reliably)
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 500
	$CanvasLayer.add_child(overlay)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 260)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -260
	panel.offset_right = 260
	panel.offset_top = -130
	panel.offset_bottom = 130
	panel.z_index = 501
	$CanvasLayer.add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)

	var hdr := Label.new()
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.text = "%s → %s" % [_rarity_name(int(old_w.get("rarity", 0))), _rarity_name(int(new_w.get("rarity", 0)))]
	hdr.add_theme_font_size_override("font_size", 22)
	hdr.modulate = RARITY_COLORS.get(int(new_w.get("rarity", 0)), Color.WHITE)
	if DMG_FONT: hdr.add_theme_font_override("font", DMG_FONT)
	root.add_child(hdr)

	var name := Label.new()
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.text = String(new_w.get("name", "Weapon"))
	name.add_theme_font_size_override("font_size", 18)
	root.add_child(name)

	var gained := Label.new()
	gained.text = "Gained stats:"
	gained.add_theme_font_size_override("font_size", 16)
	root.add_child(gained)

	var list := VBoxContainer.new()
	root.add_child(list)
	if deltas.is_empty():
		# Fallback (should be rare now)
		var l := Label.new()
		l.text = "+0 (no bonus roll)"
		list.add_child(l)
	else:
		for k in deltas.keys():
			var stat := String(k).to_upper()
			var val := int(deltas[k])
			var l := Label.new()
			if String(k) == "base_dmg":
				l.text = "+%d BASE DMG" % val
			else:
				l.text = "+%d %s" % [val, stat]
			l.modulate = Color(0.35, 1.0, 0.55, 1.0)
			l.add_theme_font_size_override("font_size", 18)
			if DMG_FONT: l.add_theme_font_override("font", DMG_FONT)
			list.add_child(l)
			# small pop animation per line
			l.scale = Vector2.ONE * 0.9
			var twl := get_tree().create_tween()
			twl.tween_property(l, "scale", Vector2.ONE * 1.08, 0.12).from(l.scale)
			twl.tween_property(l, "scale", Vector2.ONE, 0.12)

	var close := Button.new()
	close.text = "OK"
	close.custom_minimum_size = Vector2(120, 40)
	close.pressed.connect(func():
		if is_instance_valid(panel): panel.queue_free()
		if is_instance_valid(overlay): overlay.queue_free()
	)
	root.add_child(close)

	panel.modulate.a = 0.0
	panel.scale = Vector2(1.06, 1.06)
	var tw := get_tree().create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.15).from(0.0)
	tw.parallel().tween_property(panel, "scale", Vector2.ONE, 0.15).from(panel.scale)

	# Auto-continue after short time even if player doesn't click
	await get_tree().create_timer(2.6).timeout
	if is_instance_valid(panel):
		panel.queue_free()
	if is_instance_valid(overlay):
		overlay.queue_free()

func _on_player_damaged(amount:int) -> void:
	shake_camera(8.0, 0.18)
	if amount >= 15:
		hitstop(0.06)

# func _on_enemy_damaged(_amount:int) -> void:
# 	shake_camera(5.0, 0.12)

func _on_player_died() -> void:
	_update_near_death_warning()
	# New HUD: keep corners empty; show death via log/other UI later.
	if lbl_player:
		lbl_player.text = ""
	if lbl_player_hp_value:
		lbl_player_hp_value.text = "0/%d" % player.max_hp
	if lbl_player_dmg_value:
		lbl_player_dmg_value.text = "0"
	if lbl_player_armor_value:
		lbl_player_armor_value.text = str(_calc_player_armor_total())
	lbl_log.text = "Game Over."
	if btn_attack:
		btn_attack.disabled = true
 
 
	# Odczekaj chwilę, żeby gracz zobaczył komunikat, potem pokaż Game Over screen
	await get_tree().create_timer(1.2).timeout
	_show_game_over_screen()
 
 
func _show_game_over_screen() -> void:
	# Zapisz śmierć w GameState
	GameState.on_player_death()
	GameState.save(GameState.current_slot)
	var colony_lost := GameState.is_colony_defeated()

	# Overlay
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 300
	$CanvasLayer.add_child(overlay)

	var tw_fade := get_tree().create_tween()
	tw_fade.tween_property(overlay, "modulate:a", 0.85, 0.6)
	await tw_fade.finished

	# Panel — szerszy żeby zmieścić więcej info
	var panel := PanelContainer.new()
	panel.z_index = 301
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.04, 0.04, 0.97)
	sb.border_color = Color(0.7, 0.15, 0.10, 1.0)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(16)
	sb.shadow_size = 14
	sb.shadow_color = Color(0, 0, 0, 0.6)
	panel.add_theme_stylebox_override("panel", sb)
	panel.anchor_left   = 0.5
	panel.anchor_right  = 0.5
	panel.anchor_top    = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left   = -280
	panel.offset_right  =  280
	panel.offset_top    = -240
	panel.offset_bottom =  240

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# ── Tytuł ──────────────────────────────────────────
	var title := Label.new()
	title.text = "☠  CLAN FALLEN  ☠" if colony_lost else "☠  GAME OVER  ☠"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.9, 0.22, 0.18))
	title.add_theme_font_size_override("font_size", 44)
	if DMG_FONT: title.add_theme_font_override("font", DMG_FONT)
	vbox.add_child(title)

	# ── Separator ──────────────────────────────────────
	var sep1 := HSeparator.new()
	sep1.add_theme_color_override("color", Color(0.5, 0.1, 0.1, 0.8))
	vbox.add_child(sep1)

	# ── Statystyki runa — każda w osobnym wierszu ──────
	var cls: String = chosen_class.capitalize() if chosen_class != "" else "Novice"
	var dungeon_name: String = String(DUNGEONS[current_dungeon_index]["name"])
	var dungeons_visited: int = visited_dungeons.size()

	var run_stats := [
		["⚔  Enemies defeated",  str(enemies_defeated)],
		["🏔  Died in",           dungeon_name],
		["🗺  Dungeons visited",  str(dungeons_visited)],
		["📊  Level reached",     str(player.level)],
		["🧙  Class",             cls],
		["⚔  STR / AGI",         "%d / %d" % [_effective_strength(), _effective_agility()]],
		["❤  VIT / CRIT",        "%d / %d" % [_effective_vitality(), _effective_crit_stat()]],
	]

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(grid)

	for row in run_stats:
		var lbl_key := Label.new()
		lbl_key.text = str(row[0])
		lbl_key.add_theme_font_size_override("font_size", 17)
		lbl_key.add_theme_color_override("font_color", Color(0.70, 0.67, 0.63))
		if DMG_FONT: lbl_key.add_theme_font_override("font", DMG_FONT)

		var lbl_val := Label.new()
		lbl_val.text = str(row[1])
		lbl_val.add_theme_font_size_override("font_size", 17)
		lbl_val.add_theme_color_override("font_color", Color(1.0, 0.95, 0.80))
		if DMG_FONT: lbl_val.add_theme_font_override("font", DMG_FONT)

		grid.add_child(lbl_key)
		grid.add_child(lbl_val)

	# ── Separator ──────────────────────────────────────
	var sep2 := HSeparator.new()
	sep2.add_theme_color_override("color", Color(0.5, 0.1, 0.1, 0.8))
	vbox.add_child(sep2)

	# ── Nota o permanentach ────────────────────────────
	var perm_count := 0
	var chest: Dictionary = GameState.meta.get("permanent_chest", {})
	for s in chest:
		perm_count += (chest[s] as Array).size()

	var perm_note := Label.new()
	if colony_lost:
		perm_note.text = "No dwarfs remain. Your campaign save will be deleted."
		perm_note.add_theme_color_override("font_color", Color(0.92, 0.45, 0.35))
	else:
		perm_note.text = "💎 %d permanent item(s) safe in your chest." % perm_count
		perm_note.add_theme_color_override("font_color", Color(0.55, 0.90, 0.45))
	perm_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	perm_note.add_theme_font_size_override("font_size", 16)
	if DMG_FONT: perm_note.add_theme_font_override("font", DMG_FONT)
	vbox.add_child(perm_note)

	# ── Przyciski ──────────────────────────────────────
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var btn_retry := _make_styled_button("▶  Play Again", Color(0.95, 0.82, 0.30))
	var btn_home := _make_styled_button(
		"Main Menu" if colony_lost else "🏠  Return Home",
		Color(0.55, 0.75, 1.0) if not colony_lost else Color(0.85, 0.35, 0.22)
	)
	if colony_lost:
		btn_row.add_child(btn_home)
	else:
		btn_row.add_child(btn_retry)
		btn_row.add_child(btn_home)

	if colony_lost:
		btn_home.pressed.connect(func():
			GameState.finalize_colony_defeat()
			get_tree().change_scene_to_file("res://main_menu.tscn")
		)
	else:
		btn_retry.pressed.connect(func():
			get_tree().reload_current_scene()
		)
		btn_home.pressed.connect(func():
			get_tree().change_scene_to_file("res://home_scene.tscn")
		)

	$CanvasLayer.add_child(panel)

	# Pop-in animacja
	panel.modulate = Color(1, 1, 1, 0)
	panel.scale = Vector2(0.88, 0.88)
	var tw_in := get_tree().create_tween()
	tw_in.tween_property(panel, "modulate:a", 1.0, 0.22)
	tw_in.parallel().tween_property(panel, "scale", Vector2(1, 1), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
 
# Pomocnicza funkcja do tworzenia przycisków Game Over screena
func _make_styled_button(label_text: String, col: Color) -> Button:
	var b := Button.new()
	b.text = label_text
	b.custom_minimum_size = Vector2(180, 48)
	b.add_theme_font_size_override("font_size", 20)
	if DMG_FONT:
		b.add_theme_font_override("font", DMG_FONT)
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(col.r * 0.25, col.g * 0.25, col.b * 0.25, 0.95)
	bsb.border_color = col
	bsb.set_border_width_all(2)
	bsb.set_corner_radius_all(10)
	var bhov := bsb.duplicate() as StyleBoxFlat
	bhov.bg_color = Color(col.r * 0.40, col.g * 0.40, col.b * 0.40, 0.95)
	b.add_theme_stylebox_override("normal", bsb)
	b.add_theme_stylebox_override("hover", bhov)
	b.add_theme_color_override("font_color", col)
	return b

func _update_labels() -> void:
	_on_player_hp_changed(player.hp, player.max_hp)
	_on_enemy_hp_changed(enemy.hp, enemy.max_hp)

func show_damage_popup(target: Node2D, text: String, kind: String = "hit") -> void:
	_FLOATING_DAMAGE_NUMBERS.spawn(fx_root, cam, target, text, kind, DMG_FONT)


func _spawn_enemy_death_icon_fx() -> void:
	_ENEMY_DEATH_ICON_FX.spawn(fx_root, enemy)


func _setup_near_death_warning() -> void:
	if _near_death_warning != null and is_instance_valid(_near_death_warning):
		return
	_near_death_layer = CanvasLayer.new()
	_near_death_layer.name = "NearDeathLayer"
	_near_death_layer.layer = 88
	add_child(_near_death_layer)
	_near_death_warning = _NEAR_DEATH_WARNING_SCRIPT.new()
	_near_death_layer.add_child(_near_death_warning)


func _worst_enemy_hit_damage() -> int:
	if not enemy.is_alive():
		return 0
	var base := float(enemy.damage)
	var armor := _calc_player_armor_total()
	var worst := maxi(1, int(round(base * CRIT_MULT)))
	if armor <= 19:
		var mult := damage_multiplier_from_roll(19, armor)
		worst = maxi(worst, maxi(1, int(round(base * mult))))
	if armor >= 0 and armor <= CRIT:
		worst = maxi(worst, maxi(1, int(round(base * 0.5))))
	return worst


func _should_show_near_death_warning() -> bool:
	if is_in_home or not player.is_alive() or not enemy.is_alive():
		return false
	if bool(current_enemy_data.get("treasure", false)):
		return false
	if inventory_screen != null and inventory_screen.visible:
		return false
	if turn != Turn.PLAYER:
		return false
	if shield_active:
		return false
	return player.hp <= _worst_enemy_hit_damage()


func _update_near_death_warning() -> void:
	if _near_death_warning == null or not is_instance_valid(_near_death_warning):
		return
	var active := _should_show_near_death_warning()
	if _near_death_warning.has_method("set_warning_active"):
		_near_death_warning.call("set_warning_active", active)

func _on_player_xp_changed(current_xp: int, xp_to_next: int) -> void:
	if xp_bar:
		xp_bar.max_value = max(1, xp_to_next)
		var tween := get_tree().create_tween()
		tween.tween_property(xp_bar,"value",clamp(current_xp, 0, xp_to_next),0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_player_level_changed(level: int, stat_points_now: int) -> void:
	if lbl_level:
		lbl_level.text = "LVL %d" % level
	if xp_bar:
		var original_modulate := xp_bar.modulate
		var t := get_tree().create_tween()
		t.tween_property(xp_bar, "modulate", Color(1.0, 0.9, 0.4, 1.0), 0.12).from(original_modulate)
		t.tween_interval(0.05)
		t.tween_property(xp_bar, "modulate", original_modulate, 0.2)
	if not has_evolved and level >= EVOLVE_LEVEL:
		_request_evolution_choice()
	# Do not auto-open stats panel on level up.
	# Player spends points from Inventory; we only nudge via the unspent indicator.
	_update_unspent_points_indicator(stat_points_now)

func _cache_default_dice_set() -> void:
	_dice.cache_default_dice_set()


func _apply_dice_set_shapes_on(roller: DiceRoller, shape_ids: Array[String]) -> void:
	_dice.apply_dice_set_shapes_on(roller, shape_ids)


func _apply_dice_set_shapes(shape_ids: Array[String]) -> void:
	_dice.apply_dice_set_shapes(shape_ids)


func _restore_default_dice_set_on(roller: DiceRoller) -> void:
	_dice.restore_default_dice_set_on(roller)


func _restore_default_dice_set() -> void:
	_dice.restore_default_dice_set()


func _play_d20_animation(final_roll: int) -> void:
	await _dice.play_d20_animation(final_roll)


func _play_dice_roll_animation(faces: Array[int], shape_ids: Array[String]) -> void:
	await _dice.play_roll_animation(faces, shape_ids)


func _play_legacy_dice_roll_animation(
	faces: Array[int],
	shape_ids: Array[String],
	lane_offset_x: float = 0.0,
	time_scale: float = 1.0
) -> void:
	await _dice.play_legacy_roll_animation(faces, shape_ids, lane_offset_x, time_scale)


func _play_multi_dice_cinematic(faces: Array[int], shape_ids: Array[String]) -> void:
	await _dice.play_multi_dice_cinematic(faces, shape_ids)

func _dice_burst_effect(
	is_crit: bool,
	is_miss: bool,
	land_pos: Vector2,
	time_scale: float = 1.0
) -> void:
	await _dice.dice_burst_effect(is_crit, is_miss, land_pos, time_scale)


func _spawn_dice_particles(center: Vector2, cfg: Dictionary, speed_scale: float = 1.0) -> void:
	_dice.spawn_dice_particles(center, cfg, speed_scale)


func _spawn_dice_glow(center: Vector2, col: Color, radius: float, duration: float) -> void:
	_dice.spawn_dice_glow(center, col, radius, duration)


# _offer_branch_after_lich() -- usunięta (martwy kod; zastąpiona przez _offer_branch_choice_after_boss)

func _switch_to_dungeon(idx:int) -> void:
	if not DUNGEONS.has(idx):
		push_warning("Unknown dungeon index: %d" % idx)
		return

	current_dungeon_index = idx
	current_roster = (DUNGEONS[idx]["enemies"] as Array[Dictionary]).duplicate(true)
	dungeon_level = 1
	enemies_defeated = 0
	
	_apply_world_background_for_current_dungeon()


	# Zapisz jako odwiedzony
	if not visited_dungeons.has(idx):
		visited_dungeons.append(idx)
		GameState.meta["visited_dungeons"] = visited_dungeons.duplicate()

	if lbl_log:
		lbl_log.text = "Entering: %s" % String(DUNGEONS[idx]["name"])
	
	if lbl_dungeon_name:
		lbl_dungeon_name.text = "Current dungeon: %s" % String(DUNGEONS[current_dungeon_index]["name"])

	_request_spawn(_pick_enemy())
	set_turn(Turn.PLAYER)



func _toggle_inventory_from_stats_button() -> void:
	if inventory_screen and inventory_screen.visible:
		inventory_screen._on_close()
	else:
		open_inventory()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_stats"):
		_toggle_inventory_from_stats_button()
	if event.is_action_pressed("use_potion"):
		_use_potion()

	if event.is_action_pressed("toggle_inventory"):
		if inventory_screen and inventory_screen.visible:
			inventory_screen._on_close()
		else:
			open_inventory()
		get_viewport().set_input_as_handled()
		return

	# --- SKILLS HOTKEYS (1 i 2) ---
	var inv_blocks_skills := inventory_screen and inventory_screen.visible
	if event is InputEventKey and event.pressed and not event.echo and not inv_blocks_skills:
		if event.keycode == KEY_1:
			_try_use_skill(1)
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_2:
			_try_use_skill(2)
			get_viewport().set_input_as_handled()
			return

	if turn == Turn.PLAYER and not (inventory_screen and inventory_screen.visible):
		_set_attack_buttons_disabled(false)


func _on_player_stats_changed(strn:int, agi:int, vit:int, crit:int, points:int) -> void:
	_sync_player_max_hp_from_gear()
	_update_labels()
	_update_unspent_points_indicator(points)
	_sync_inventory_screen_if_open()
	if inventory_screen and inventory_screen.visible and points <= 0 and turn == Turn.PLAYER:
		_set_attack_buttons_disabled(false)

func _ensure_unspent_points_label() -> void:
	if unspent_points_label and is_instance_valid(unspent_points_label):
		return
	unspent_points_label = Label.new()
	unspent_points_label.name = "UnspentPointsLabel"
	unspent_points_label.visible = false
	unspent_points_label.z_index = 1000
	unspent_points_label.add_theme_font_size_override("font_size", 22)
	unspent_points_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.30))
	unspent_points_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	unspent_points_label.add_theme_constant_override("outline_size", 4)
	if DMG_FONT:
		unspent_points_label.add_theme_font_override("font", DMG_FONT)
	unspent_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	unspent_points_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	unspent_points_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	unspent_points_label.size = Vector2(420, 30)
	if $CanvasLayer:
		$CanvasLayer.add_child(unspent_points_label)
	else:
		add_child(unspent_points_label)

func _update_unspent_points_indicator(points: int) -> void:
	_ensure_unspent_points_label()
	if points <= 0:
		if _unspent_pulse_tween and is_instance_valid(_unspent_pulse_tween):
			_unspent_pulse_tween.kill()
		_unspent_pulse_tween = null
		unspent_points_label.visible = false
		return
	unspent_points_label.text = "Unspent points: %d" % points
	unspent_points_label.visible = true
	# place it under "Current dungeon"
	if lbl_dungeon_name and is_instance_valid(lbl_dungeon_name):
		unspent_points_label.position = lbl_dungeon_name.position + Vector2(0, lbl_dungeon_name.size.y - 6)
	else:
		unspent_points_label.position = Vector2(get_viewport_rect().size.x / 2 - 210, 44)
	# (Re)start a gentle pulse
	if _unspent_pulse_tween == null or not is_instance_valid(_unspent_pulse_tween):
		unspent_points_label.modulate = Color(1, 1, 1, 0.85)
		unspent_points_label.scale = Vector2.ONE
		_unspent_pulse_tween = get_tree().create_tween()
		_unspent_pulse_tween.set_loops()
		_unspent_pulse_tween.tween_property(unspent_points_label, "scale", Vector2(1.08, 1.08), 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_unspent_pulse_tween.parallel().tween_property(unspent_points_label, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_unspent_pulse_tween.tween_property(unspent_points_label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_unspent_pulse_tween.parallel().tween_property(unspent_points_label, "modulate:a", 0.75, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# --- POTIONS: UI i logika ---
func _update_potions_ui() -> void:
	if potion_label:
		potion_label.visible = false
	if potion_icon:
		if potions <= 0:
			potion_icon.visible = false
		else:
			var n: int = mini(potions, POTION_MAX)
			match n:
				1:
					potion_icon.texture = TEX_HP_BOTTLE_1
				2:
					potion_icon.texture = TEX_HP_BOTTLE_2
				_:
					potion_icon.texture = TEX_HP_BOTTLE_3
			potion_icon.visible = true
	# Przycisk potki (PanelPotion/BtnPotion): ta sama grafika co PotionIcon (1/2/3 butelki)
	if btn_use_potion is TextureButton:
		var tb: TextureButton = btn_use_potion as TextureButton
		if potions <= 0:
			tb.texture_normal = null
		else:
			var nb: int = mini(potions, POTION_MAX)
			match nb:
				1:
					tb.texture_normal = TEX_HP_BOTTLE_1
				2:
					tb.texture_normal = TEX_HP_BOTTLE_2
				_:
					tb.texture_normal = TEX_HP_BOTTLE_3
	var can_use: bool = (turn == Turn.PLAYER) and (potions > 0) and (player.hp < player.max_hp)
	if btn_use_potion:
		btn_use_potion.disabled = not can_use

func _on_use_potion_pressed() -> void:
	_use_potion()

func _use_potion() -> void:
	if turn != Turn.PLAYER or resolving_turn:
		_update_potions_ui()
		return
	if potions <= 0:
		_update_potions_ui()
		return
	if player.hp >= player.max_hp:
		_update_potions_ui()
		return

	var was_player_turn: bool = (turn == Turn.PLAYER)
	resolving_turn = true

	var missing: int = player.max_hp - player.hp
	var heal: int = min(POTION_HEAL, missing)

	player.hp = min(player.hp + heal, player.max_hp)
	player.emit_signal("hp_changed", player.hp, player.max_hp)
	potions -= 1
	_update_potions_ui()

	var audio := get_node_or_null("/root/GameAudio")
	if audio:
		audio.play_potion_heal()

	show_damage_popup(player, "+" + str(heal), "heal")
	if player.has_method("play_heal_flash"):
		player.play_heal_flash()
	if player.has_method("play_heal_particles"):
		player.play_heal_particles()

	await get_tree().create_timer(0.25).timeout

	if was_player_turn and player.is_alive() and enemy.is_alive():
		set_turn(Turn.ENEMY)
	else:
		if turn == Turn.PLAYER and btn_attack:
			btn_attack.disabled = false

	resolving_turn = false

func _try_drop_potion() -> void:
	if potions >= POTION_MAX:
		return
	if randf() <= POTION_DROP_CHANCE:
		potions += 1
		_update_potions_ui()
		if lbl_log:
			lbl_log.text = "You found a Health Potion! (%d/%d)" % [potions, POTION_MAX]
		show_damage_popup(player, "+Potion", "heal")

func play_heal_flash() -> void:
	var start_color := modulate
	var start_scale := scale
	var t := get_tree().create_tween()
	t.tween_property(self, "modulate", Color(0.2, 1.0, 0.2, 1.0), 0.12).from(start_color)
	t.parallel().tween_property(self, "scale", start_scale * Vector2(1.06, 1.06), 0.12).from(start_scale)
	t.tween_interval(0.06)
	t.tween_property(self, "modulate", start_color, 0.16)
	t.parallel().tween_property(self, "scale", start_scale, 0.16)

func _ensure_heal_particles() -> void:
	if _heal_particles: return
	_heal_particles = GPUParticles2D.new()
	_heal_particles.one_shot = true
	_heal_particles.lifetime = 0.7
	_heal_particles.amount = 24
	_heal_particles.explosiveness = 0.2
	_heal_particles.emitting = false
	_heal_particles.position = Vector2(0, -12)
	var mat := ParticleProcessMaterial.new()
	mat.gravity = Vector3(0, -5, 0)
	mat.initial_velocity_min = 45
	mat.initial_velocity_max = 80
	mat.angle_min = -25.0
	mat.angle_max = 25.0
	mat.scale_min = 0.4
	mat.scale_max = 0.8
	mat.color = Color(0.3, 1.0, 0.4, 0.9)
	var grad := Gradient.new()
	grad.colors = [
		Color(0.35, 1.0, 0.5, 0.95),
		Color(0.35, 1.0, 0.5, 0.4),
		Color(0.35, 1.0, 0.5, 0.0),
	]
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex
	_heal_particles.process_material = mat
	add_child(_heal_particles)

# --- BOSS / DUNGEON CHOICE ---
func _is_current_boss(enemy_name: String) -> bool:
	if current_dungeon_index == 0:
		return enemy_name == "Goblin King"
	elif current_dungeon_index == 1:
		return enemy_name == "Lich"
	elif current_dungeon_index == 2:
		return enemy_name == "High King of Peaks"
	elif current_dungeon_index == 3:
		return enemy_name == "Orc Warlord"
	elif current_dungeon_index == 4:
		return enemy_name == "Dread Matriarch"
	elif current_dungeon_index == 5:
		return enemy_name == "Ancient Worldroot"
	return false

func _offer_dungeon_choice(boss_name: String) -> void:
	if not dungeon_choice:
		print("[BOSS] %s defeated, but no dialog present. Auto-switch to next dungeon." % boss_name)
		_switch_to_next_dungeon()
		return
	dungeon_choice.title = "Dungeon Cleared!"
	dungeon_choice.ok_button_text = "Go to next dungeon"
	dungeon_choice.cancel_button_text = "Stay here"
	dungeon_choice.dialog_text = "%s defeated!\nStay here and keep farming XP, or go to the next dungeon?" % boss_name
	dungeon_choice.popup_centered()

func _on_dungeon_choice_confirmed() -> void:
	_switch_to_next_dungeon()

func _on_dungeon_choice_canceled() -> void:
	await _transition_to_next_enemy()
	set_turn(Turn.PLAYER)

func _switch_to_next_dungeon() -> void:
	if current_dungeon_index == 0:
		current_dungeon_index = 1
		current_roster = UNDEAD_ENEMIES.duplicate(true)
		dungeon_level = 1
		enemies_defeated = 0

		# zapisz jako odwiedzony
		if not visited_dungeons.has(1):
			visited_dungeons.append(1)

		if lbl_log:
			lbl_log.text = "Entering: Undead Crypt"

		# zaktualizuj pasek „Current dungeon: …”
		if lbl_dungeon_name:
			lbl_dungeon_name.text = "Current dungeon: %s" % String(DUNGEONS[current_dungeon_index]["name"])

		_apply_world_background_for_current_dungeon()
		_request_spawn(_pick_enemy())
		set_turn(Turn.PLAYER)
	else:
		# dalej nie używamy tego przejścia — od D2 decyduje _offer_branch_choice_after_boss()
		if lbl_log:
			lbl_log.text = "No further dungeons via linear path. Stay here."
		_request_spawn(_pick_enemy())
		set_turn(Turn.PLAYER)


# --- Evolution UI ---
func _request_evolution_choice() -> void:
	if has_evolved or _is_evolution_choice_open():
		return
	if GameState.has_class():
		_apply_class_evolution(GameState.get_chosen_class())
		return
	if _dev_panel_visible:
		_evolution_pending = true
		return
	_show_evolution_choice()


func _show_evolution_choice() -> void:
	if GameState.has_class():
		_apply_class_evolution(GameState.get_chosen_class())
		return
	if _is_evolution_choice_open():
		return
	_evolution_pending = false
	_dismiss_evolution_overlay()
	if btn_attack:
		btn_attack.disabled = true
	_evolution_ready = false
	_suppress_ui_for_evolution()

	var vp := get_viewport_rect().size
	var row_sep := clampi(int(vp.x * 0.018), 10, 28)
	var usable_w := vp.x - 80.0
	var char_w := clampf((usable_w - float(row_sep) * 3.0) / 4.0, 130.0, 220.0)
	var char_h := clampf(char_w * 1.35, 220.0, minf(vp.y * 0.48, 420.0))

	_evolution_overlay = Control.new()
	_evolution_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_evolution_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_evolution_overlay.z_index = 600

	_evolution_dim = ColorRect.new()
	_evolution_dim.color = Color(0.0, 0.0, 0.0, 0.0)
	_evolution_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_evolution_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_evolution_overlay.add_child(_evolution_dim)

	_evolution_title_host = Control.new()
	_evolution_title_host.set_anchors_preset(Control.PRESET_CENTER)
	_evolution_title_host.custom_minimum_size = Vector2(minf(vp.x * 0.8, 720.0), 72.0)
	_evolution_title_host.offset_left = -_evolution_title_host.custom_minimum_size.x * 0.5
	_evolution_title_host.offset_right = _evolution_title_host.custom_minimum_size.x * 0.5
	_evolution_title_host.offset_top = -36.0
	_evolution_title_host.offset_bottom = 36.0
	_evolution_title_host.modulate.a = 0.0
	_evolution_title_host.scale = Vector2(0.55, 0.55)
	_evolution_overlay.add_child(_evolution_title_host)

	var head := Label.new()
	head.name = "Title"
	head.text = "CHOOSE YOUR PATH"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.set_anchors_preset(Control.PRESET_FULL_RECT)
	head.add_theme_font_size_override("font_size", 34)
	head.add_theme_color_override("font_color", Color(0.92, 0.78, 0.28))
	if DMG_FONT:
		head.add_theme_font_override("font", DMG_FONT)
	_evolution_title_host.add_child(head)

	_evolution_content = Control.new()
	_evolution_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_evolution_content.modulate.a = 0.0
	_evolution_content.mouse_filter = Control.MOUSE_FILTER_PASS
	_evolution_overlay.add_child(_evolution_content)

	var hint := Label.new()
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hint.offset_top = clampf(vp.y * 0.11, 52.0, 88.0)
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.62, 0.58, 0.52))
	if DMG_FONT:
		hint.add_theme_font_override("font", DMG_FONT)
	_evolution_content.add_child(hint)
	_evolution_hint_label = hint

	_evolution_tooltip = _make_evolution_info_box()
	_evolution_tooltip.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_evolution_tooltip.offset_left = clampf(vp.x * 0.12, 80.0, 200.0)
	_evolution_tooltip.offset_right = -_evolution_tooltip.offset_left
	_evolution_tooltip.offset_top = hint.offset_top + 26.0
	_evolution_content.add_child(_evolution_tooltip)

	var char_area := CenterContainer.new()
	char_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	char_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	char_area.offset_top = hint.offset_top + 118.0
	char_area.offset_bottom = -80.0
	_evolution_content.add_child(char_area)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", row_sep)
	char_area.add_child(row)

	var layer := $CanvasLayer
	if layer:
		layer.add_child(_evolution_overlay)
		_set_process_mode_recursive(_evolution_overlay, Node.PROCESS_MODE_ALWAYS)
		_evolution_particles_root = Node2D.new()
		_evolution_particles_root.z_index = 601
		_evolution_particles_root.process_mode = Node.PROCESS_MODE_ALWAYS
		layer.add_child(_evolution_particles_root)
	else:
		add_child(_evolution_overlay)
		_set_process_mode_recursive(_evolution_overlay, Node.PROCESS_MODE_ALWAYS)
		_evolution_particles_root = null

	for class_key in ["warrior", "assassin", "guardian", "barbarian"]:
		var slot := _make_evolution_character_slot(class_key, Vector2(char_w, char_h))
		slot.modulate.a = 0.0
		row.add_child(slot)
		_evolution_slot_nodes[class_key] = slot
		var info: Dictionary = CLASS_EVOLUTION_INFO.get(class_key, {})
		var accent: Color = info.get("accent", Color(0.9, 0.8, 0.3))
		if _evolution_particles_root:
			var particles := _make_evolution_hover_particles(accent)
			_evolution_particles_root.add_child(particles)
			_evolution_particles[class_key] = particles

	call_deferred("_play_evolution_intro")
	get_tree().create_timer(4.0, true).timeout.connect(_force_evolution_intro_finish, CONNECT_ONE_SHOT)


func _is_evolution_choice_open() -> bool:
	return _evolution_overlay != null and is_instance_valid(_evolution_overlay)


func _play_evolution_intro() -> void:
	if _evolution_overlay == null or not is_instance_valid(_evolution_overlay):
		return
	if _evolution_title_host == null or _evolution_content == null:
		return

	await get_tree().process_frame
	if _evolution_title_host:
		_evolution_title_host.pivot_offset = _evolution_title_host.size * 0.5

	var tw := get_tree().create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_parallel(true)
	if _evolution_dim:
		tw.tween_method(
			func(a: float) -> void:
				if _evolution_dim and is_instance_valid(_evolution_dim):
					_evolution_dim.color = Color(0.0, 0.0, 0.0, a),
			0.0, 0.94, 0.55
		)
	tw.tween_property(_evolution_title_host, "modulate:a", 1.0, 0.75)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_evolution_title_host, "scale", Vector2.ONE, 0.85)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await tw.finished
	await get_tree().create_timer(0.55, true).timeout
	if _evolution_overlay == null or not is_instance_valid(_evolution_overlay):
		return

	var vp := get_viewport_rect().size
	var center_y := vp.y * 0.5
	var target_top := clampf(vp.y * 0.06, 36.0, 56.0)
	_evolution_title_host.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_evolution_title_host.offset_left = 0.0
	_evolution_title_host.offset_right = 0.0
	_evolution_title_host.offset_top = center_y - 36.0
	_evolution_title_host.offset_bottom = -(vp.y - (center_y + 36.0))

	var title_tw := get_tree().create_tween()
	title_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	title_tw.set_parallel(true)
	title_tw.tween_property(_evolution_title_host, "scale", Vector2(0.68, 0.68), 0.45)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	title_tw.tween_property(_evolution_title_host, "offset_top", target_top, 0.45)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	title_tw.tween_property(_evolution_title_host, "offset_bottom", -(vp.y - (target_top + 52.0)), 0.45)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	title_tw.tween_property(_evolution_content, "modulate:a", 1.0, 0.42)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	await title_tw.finished
	if _evolution_overlay == null or not is_instance_valid(_evolution_overlay):
		return

	var idx := 0
	for class_key in ["warrior", "assassin", "guardian", "barbarian"]:
		var slot: Control = _evolution_slot_nodes.get(class_key)
		if slot == null or not is_instance_valid(slot):
			continue
		var slot_tw := get_tree().create_tween()
		slot_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		slot_tw.tween_property(slot, "modulate:a", 1.0, 0.32)\
			.set_delay(float(idx) * 0.08)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		idx += 1

	_evolution_ready = true
	_layout_evolution_tooltip()


func _force_evolution_intro_finish() -> void:
	if _evolution_ready or not _is_evolution_choice_open():
		return
	if _evolution_dim and is_instance_valid(_evolution_dim):
		_evolution_dim.color = Color(0.0, 0.0, 0.0, 0.94)
	if _evolution_title_host and is_instance_valid(_evolution_title_host):
		_evolution_title_host.modulate.a = 1.0
		_evolution_title_host.scale = Vector2(0.68, 0.68)
	if _evolution_content and is_instance_valid(_evolution_content):
		_evolution_content.modulate.a = 1.0
	for class_key in _evolution_slot_nodes.keys():
		var slot: Control = _evolution_slot_nodes.get(class_key)
		if slot and is_instance_valid(slot):
			slot.modulate.a = 1.0
	_evolution_ready = true
	_layout_evolution_tooltip()


func _suppress_ui_for_evolution() -> void:
	_evolution_suppressed_ui.clear()
	for n in [lbl_dungeon_name, unspent_points_label]:
		if n and is_instance_valid(n) and n is CanvasItem:
			_evolution_suppressed_ui.append({"node": n, "visible": (n as CanvasItem).visible})
			(n as CanvasItem).visible = false
	_set_attack_buttons_disabled(true)


func _restore_ui_after_evolution() -> void:
	for entry in _evolution_suppressed_ui:
		var n: CanvasItem = entry.get("node")
		if n and is_instance_valid(n):
			n.visible = bool(entry.get("visible", true))
	_evolution_suppressed_ui.clear()
	if turn == Turn.PLAYER:
		_set_attack_buttons_disabled(false)


func _make_evolution_character_slot(class_key: String, portrait_size: Vector2) -> Control:
	var info: Dictionary = CLASS_EVOLUTION_INFO.get(class_key, {})
	var slot := Control.new()
	slot.custom_minimum_size = portrait_size + Vector2(0, 24)
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slot.mouse_filter = Control.MOUSE_FILTER_STOP

	var tex := TextureRect.new()
	tex.name = "Portrait"
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.custom_minimum_size = portrait_size
	tex.set_anchors_preset(Control.PRESET_CENTER_TOP)
	tex.offset_top = 0.0
	tex.offset_bottom = portrait_size.y
	tex.offset_left = -portrait_size.x * 0.5
	tex.offset_right = portrait_size.x * 0.5
	tex.pivot_offset = portrait_size * 0.5
	var tex_path: String = String(CLASS_TEXTURES.get(class_key, ""))
	if tex_path != "" and ResourceLoader.exists(tex_path):
		tex.texture = load(tex_path) as Texture2D
	slot.add_child(tex)

	var name_lbl := Label.new()
	name_lbl.text = String(info.get("name", class_key.capitalize()))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	name_lbl.offset_top = -20.0
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color(0.72, 0.68, 0.62))
	if DMG_FONT:
		name_lbl.add_theme_font_override("font", DMG_FONT)
	slot.add_child(name_lbl)

	slot.mouse_entered.connect(Callable(self, "_on_evolution_slot_hovered").bind(class_key))
	slot.mouse_exited.connect(Callable(self, "_on_evolution_slot_unhovered").bind(class_key))
	slot.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_on_class_picked(class_key)
	)
	return slot


func _make_evolution_info_box() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "EvolutionInfoBox"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.visible = false
	box.add_theme_constant_override("separation", 4)

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.92, 0.78, 0.28))
	if DMG_FONT:
		title.add_theme_font_override("font", DMG_FONT)
	box.add_child(title)

	var tag := Label.new()
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag.add_theme_font_size_override("font_size", 13)
	tag.add_theme_color_override("font_color", Color(0.72, 0.68, 0.62))
	if DMG_FONT:
		tag.add_theme_font_override("font", DMG_FONT)
	box.add_child(tag)

	var active := Label.new()
	active.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	active.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active.add_theme_font_size_override("font_size", 12)
	active.add_theme_color_override("font_color", Color(0.88, 0.84, 0.78))
	if DMG_FONT:
		active.add_theme_font_override("font", DMG_FONT)
	box.add_child(active)

	var passive := Label.new()
	passive.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	passive.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	passive.add_theme_font_size_override("font_size", 12)
	passive.add_theme_color_override("font_color", Color(0.58, 0.74, 0.92))
	if DMG_FONT:
		passive.add_theme_font_override("font", DMG_FONT)
	box.add_child(passive)

	box.set_meta("lbl_title", title)
	box.set_meta("lbl_tagline", tag)
	box.set_meta("lbl_active", active)
	box.set_meta("lbl_passive", passive)
	return box


func _layout_evolution_tooltip() -> void:
	pass


func _evolution_slot_center(class_key: String) -> Vector2:
	var slot: Control = _evolution_slot_nodes.get(class_key)
	if slot == null or not is_instance_valid(slot):
		return Vector2.ZERO
	var tex: TextureRect = slot.get_node_or_null("Portrait") as TextureRect
	if tex:
		return tex.get_global_rect().get_center()
	return slot.get_global_rect().get_center()


func _make_evolution_hover_particles(accent: Color) -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.emitting = false
	p.one_shot = false
	p.amount = 28
	p.lifetime = 1.1
	p.explosiveness = 0.0
	p.preprocess = 0.4
	p.z_index = 2

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_radius = 88.0
	mat.emission_ring_height = 14.0
	mat.emission_ring_inner_radius = 0.55
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 28.0
	mat.initial_velocity_min = 6.0
	mat.initial_velocity_max = 20.0
	mat.gravity = Vector3(0, -8, 0)
	mat.orbit_velocity_min = 0.6
	mat.orbit_velocity_max = 1.4
	mat.scale_min = 0.12
	mat.scale_max = 0.38
	mat.angular_velocity_min = -90.0
	mat.angular_velocity_max = 90.0

	var grad := Gradient.new()
	grad.set_color(0, accent.lightened(0.25))
	grad.add_point(0.55, Color(accent.r, accent.g, accent.b, 0.55))
	grad.add_point(1.0, Color(accent.r, accent.g, accent.b, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex
	p.process_material = mat
	p.texture = _make_evolution_particle_tex()
	return p


func _make_evolution_particle_tex() -> Texture2D:
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in 12:
		for y in 12:
			var dx := float(x) - 5.5
			var dy := float(y) - 5.5
			var a := clampf(1.0 - sqrt(dx * dx + dy * dy) / 5.5, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)


func _on_evolution_slot_hovered(class_key: String) -> void:
	if not _evolution_ready:
		return
	if _evolution_hovered_key == class_key:
		return
	_set_evolution_hover(_evolution_hovered_key, false)
	_evolution_hovered_key = class_key
	_set_evolution_hover(class_key, true)
	_show_evolution_tooltip(class_key)


func _on_evolution_slot_unhovered(class_key: String) -> void:
	if _evolution_hovered_key != class_key:
		return
	_set_evolution_hover(class_key, false)
	_evolution_hovered_key = ""
	_hide_evolution_tooltip()


func _set_evolution_hover(class_key: String, on: bool) -> void:
	if class_key == "":
		return
	var slot: Control = _evolution_slot_nodes.get(class_key)
	if slot and is_instance_valid(slot):
		var tex: TextureRect = slot.get_node_or_null("Portrait") as TextureRect
		if tex:
			var tw := get_tree().create_tween()
			tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(tex, "scale", Vector2.ONE * (1.07 if on else 1.0), 0.16)
			tw.parallel().tween_property(tex, "modulate", Color(1.12, 1.12, 1.12, 1.0) if on else Color.WHITE, 0.16)
	var particles: GPUParticles2D = _evolution_particles.get(class_key)
	if particles and is_instance_valid(particles):
		if on:
			particles.global_position = _evolution_slot_center(class_key)
			particles.restart()
			particles.emitting = true
		else:
			particles.emitting = false


func _show_evolution_tooltip(class_key: String) -> void:
	if _evolution_tooltip == null or not is_instance_valid(_evolution_tooltip):
		return
	var info: Dictionary = CLASS_EVOLUTION_INFO.get(class_key, {})
	var title: Label = _evolution_tooltip.get_meta("lbl_title") as Label
	var tag: Label = _evolution_tooltip.get_meta("lbl_tagline") as Label
	var active: Label = _evolution_tooltip.get_meta("lbl_active") as Label
	var passive: Label = _evolution_tooltip.get_meta("lbl_passive") as Label
	if title:
		title.text = String(info.get("name", class_key.capitalize()))
	if tag:
		tag.text = String(info.get("tagline", ""))
	if active:
		active.text = "Active — " + String(info.get("active", ""))
	if passive:
		passive.text = "Passive — " + String(info.get("passive", ""))
	_evolution_tooltip.visible = true
	if _evolution_hint_label and is_instance_valid(_evolution_hint_label):
		_evolution_hint_label.visible = false


func _hide_evolution_tooltip() -> void:
	if _evolution_tooltip and is_instance_valid(_evolution_tooltip):
		_evolution_tooltip.visible = false
	if _evolution_hint_label and is_instance_valid(_evolution_hint_label):
		_evolution_hint_label.visible = true


func _dismiss_evolution_overlay() -> void:
	var had_overlay := _evolution_overlay != null and is_instance_valid(_evolution_overlay)
	_evolution_hovered_key = ""
	_evolution_ready = false
	_evolution_slot_nodes.clear()
	_evolution_particles.clear()
	_restore_ui_after_evolution()
	_evolution_title_host = null
	_evolution_content = null
	_evolution_dim = null
	if _evolution_particles_root and is_instance_valid(_evolution_particles_root):
		_evolution_particles_root.queue_free()
	_evolution_particles_root = null
	_evolution_tooltip = null
	_evolution_hint_label = null
	_evolution_pending = false
	if had_overlay:
		_evolution_overlay.queue_free()
	_evolution_overlay = null


func _on_class_picked(class_key: String) -> void:
	if not _evolution_ready:
		return
	if has_evolved:
		return

	_apply_class_evolution(class_key)

	if lbl_log:
		lbl_log.text = "Evolution complete! You are now a " + class_key.capitalize() + "."

	if not skills_hotbar_wired:
		_create_skills_ui()
	_update_skills_ui()

	if turn == Turn.PLAYER and btn_attack and (not inventory_screen or not inventory_screen.visible):
		btn_attack.disabled = false


func _apply_class_evolution(key: String) -> void:
	if has_evolved:
		return

	has_evolved = true
	chosen_class = key
	GameState.set_class(key)
	GameState.save(GameState.current_slot)

	_grant_class_skills(key)
	_on_player_stats_changed(player.strength, player.agility, player.vitality, player.crit, player.stat_points)
	_update_skills_ui()

	_dismiss_evolution_overlay()

	if lbl_log:
		lbl_log.text = "Evolution complete! You are now a " + key.capitalize() + "."
	_animate_class_change(key)
	_post_evolution_breath()

	if turn == Turn.PLAYER and btn_attack and (not inventory_screen or not inventory_screen.visible):
		btn_attack.disabled = false



func _animate_class_change(class_key: String) -> void:
	var tex_path: String = (CLASS_TEXTURES.get(class_key, "") as String)
	var new_tex: Texture2D = null
	if tex_path != "":
		var loaded := load(tex_path)
		if loaded is Texture2D:
			new_tex = loaded

	var p := GPUParticles2D.new()
	p.one_shot = true
	p.lifetime = 0.7
	p.amount = 60
	p.emitting = false
	p.position = Vector2.ZERO
	var pm := ParticleProcessMaterial.new()
	pm.gravity = Vector3(0, 40, 0)
	pm.initial_velocity_min = 140
	pm.initial_velocity_max = 220
	pm.angle_min = -35.0
	pm.angle_max = 35.0
	pm.scale_min = 0.35
	pm.scale_max = 0.9
	pm.color = Color(1.0, 0.9, 0.5, 1.0)
	var grad := Gradient.new()
	grad.colors = [
		Color(1.0, 0.95, 0.6, 0.95),
		Color(1.0, 0.85, 0.3, 0.5),
		Color(1.0, 0.85, 0.3, 0.0),
	]
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	pm.color_ramp = grad_tex
	p.process_material = pm
	player.add_child(p)

	var flash := ColorRect.new()
	flash.color = Color(1,1,1,0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	$CanvasLayer.add_child(flash)
	flash.move_to_front()

	var ring := GPUParticles2D.new()
	ring.one_shot = true
	ring.lifetime = 0.5
	ring.amount = 36
	ring.emitting = false
	ring.position = Vector2.ZERO
	var rm := ParticleProcessMaterial.new()
	rm.gravity = Vector3(0, 0, 0)
	rm.initial_velocity_min = 140
	rm.initial_velocity_max = 220
	rm.direction = Vector3(1, 0, 0)
	rm.spread = 180.0
	rm.scale_min = 0.25
	rm.scale_max = 0.55
	rm.color = Color(0.9, 0.95, 1.0, 1.0)
	var rgrad := Gradient.new()
	rgrad.colors = [
		Color(0.9, 1.0, 1.0, 0.9),
		Color(0.6, 0.8, 1.0, 0.4),
		Color(0.6, 0.8, 1.0, 0.0),
	]
	var rtex := GradientTexture1D.new()
	rtex.gradient = rgrad
	rm.color_ramp = rtex
	ring.process_material = rm
	player.add_child(ring)

	var start_scale: Vector2 = player.scale
	var start_mod: Color = player.modulate
	var tw := get_tree().create_tween()
	tw.tween_property(player, "scale", start_scale * Vector2(1.12, 1.12), 0.10)
	tw.parallel().tween_property(player, "modulate", Color(1.2, 1.2, 1.2, 1.0), 0.10).from(start_mod)
	tw.tween_property(player, "scale", start_scale * Vector2(0.94, 0.94), 0.10)
	tw.tween_property(player, "scale", start_scale * Vector2(1.00, 1.00), 0.10)

	var twf := get_tree().create_tween()
	twf.tween_property(flash, "modulate:a", 0.35, 0.06).from(0.0)
	twf.tween_property(flash, "modulate:a", 0.0, 0.14)

	p.emitting = true
	ring.emitting = true
	get_tree().create_timer(0.08).timeout.connect(func():
		if new_tex:
			player.texture = new_tex
		if inventory_screen and is_instance_valid(inventory_screen):
			inventory_screen.refresh_run_portrait()
	)
	get_tree().create_timer(1.2).timeout.connect(func():
		if is_instance_valid(p): p.queue_free()
		if is_instance_valid(ring): ring.queue_free()
		if is_instance_valid(flash): flash.queue_free()
		if is_instance_valid(player):
			player.modulate = start_mod
			player.scale = start_scale
	)

func _post_evolution_breath() -> void:
	var s: Vector2 = player.scale
	var tw := get_tree().create_tween()
	tw.tween_property(player, "scale", s * Vector2(1.03, 1.03), 0.10)
	tw.tween_property(player, "scale", s, 0.12)

# --- INVENTORY: start z loadoutu / skrzynki; fallback Rusty Sword ---
func _load_permanent_items_into_inventory() -> void:
	GameState.ensure_save_equipment_shape()
	for k in GameState.EQUIPMENT_SLOT_KEYS:
		inventory[k] = []
 
	var loaded := 0

	# Itemy wybrane w bazie (run["loadout"]) — tylko te trafiają do dungeonu.
	var loadout: Dictionary = GameState.run.get("loadout", {})
	for slot in GameState.EQUIPMENT_SLOT_KEYS:
		var arr: Array = loadout.get(slot, [])
		for it in arr:
			if typeof(it) == TYPE_DICTIONARY:
				var copy: Dictionary = it.duplicate(true)
				copy["permanent"] = true
				inventory[slot].append(copy)
				loaded += 1
 
	# Jeśli brak czegokolwiek — daj startowy miecz
	if loaded == 0:
		var rusty := {
			"type": "weapon",
			"name": "Rusty Sword",
			"rarity": Rarity.COMMON,
			"base": 10,
			"scale": {"str": 0.7, "agi": 0.2}
		}
		inventory["weapon"].append(rusty)
		_equip_item("weapon", 0)
		print("[INVENTORY] First run — equipped Rusty Sword")
	else:
		print("[INVENTORY] Loaded %d item(s) from GameState." % loaded)
		for slot in GameState.EQUIPMENT_SLOT_KEYS:
			if not inventory[slot].is_empty():
				_equip_item(slot, 0)


func _inventory_item_line(it: Dictionary) -> String:
	var t := str(it.get("type","?"))
	var item_name := str(it.get("name","???"))
	var line := item_name
	match t:
		"weapon":
			var base := int(it.get("base",0))
			var sc:Dictionary = it.get("scale", {})
			var sstr := float(sc.get("str",0.0))
			var sagi := float(sc.get("agi",0.0))
			line = "%s  (base:%d | STRx%.1f AGIx%.1f)" % [item_name, base, sstr, sagi]
		"armor":
			var a := int(it.get("armor", 0))
			line = "%s  (Armor:%d)" % [item_name, a]
		"helmet":
			var hp := int(it.get("hp_bonus",0))
			line = "%s  (+%d HP)" % [item_name, hp]
		"necklace":
			var cb := int(round(100.0*float(it.get("crit_bonus",0.0))))
			line = "%s  (+%d%% crit mult)" % [item_name, cb]
		_:
			line = item_name

	# dopnij sufiks z bonusem do statów jeśli istnieje
	if it.has("bonus_stat") and int(it.get("bonus_value",0)) > 0:
		var s := String(it["bonus_stat"]).to_upper()
		var v := int(it["bonus_value"])
		line += "  [%s +%d]" % [s, v]
	if it.has("bonus_stat2") and int(it.get("bonus_value2",0)) > 0:
		var s2 := String(it["bonus_stat2"]).to_upper()
		var v2 := int(it["bonus_value2"])
		line += "  [%s +%d]" % [s2, v2]

	return line


func _is_item_equipped(key:String, idx:int) -> bool:
	match key:
		"weapon":
			var it:Dictionary = inventory["weapon"][idx]
			return weapon.get("name","") == it.get("name","")
		"armor":
			return (not equipped_armor.is_empty()) and (equipped_armor.get("name","") == inventory["armor"][idx].get("name",""))
		"helmet":
			return (not equipped_helmet.is_empty()) and (equipped_helmet.get("name","") == inventory["helmet"][idx].get("name",""))
		"necklace":
			return (not equipped_necklace.is_empty()) and (equipped_necklace.get("name","") == inventory["necklace"][idx].get("name",""))
		"gloves":
			return (not equipped_gloves.is_empty()) and (equipped_gloves.get("name","") == inventory["gloves"][idx].get("name",""))
		"boots":
			return (not equipped_boots.is_empty()) and (equipped_boots.get("name","") == inventory["boots"][idx].get("name",""))
		"ring1":
			return (not equipped_ring1.is_empty()) and (equipped_ring1.get("name","") == inventory["ring1"][idx].get("name",""))
		"ring2":
			return (not equipped_ring2.is_empty()) and (equipped_ring2.get("name","") == inventory["ring2"][idx].get("name",""))
		_:
			return false


func _consume_weapon_equip_turn() -> void:
	if resolving_turn:
		return
	if turn != Turn.PLAYER:
		return
	if not player.is_alive() or not enemy.is_alive():
		return
	if bool(current_enemy_data.get("treasure", false)):
		return
	if lbl_log:
		lbl_log.text = "You swap weapons — your turn ends."
	set_turn(Turn.ENEMY)
	_tick_skill_cooldowns()


func _equip_item(key:String, idx:int) -> void:
	var items: Array = inventory.get(key, [])
	if idx < 0 or idx >= items.size():
		return
	var it: Dictionary = items[idx]
	var weapon_changed_in_combat := false

	match key:
		"weapon":
			var prev_name := String(weapon.get("name", ""))
			# IMPORTANT: keep a reference to the inventory item (no copy),
			# otherwise shrine/permanent and boss-upgrade desync from backpack.
			weapon = it
			# ensure expected fields exist
			if not weapon.has("type"): weapon["type"] = "weapon"
			if not weapon.has("base"): weapon["base"] = int(weapon.get("damage", 10))
			if not weapon.has("scale"): weapon["scale"] = {"str": 1.0, "agi": 0.0}
			if not weapon.has("bonuses"): weapon["bonuses"] = {}
			weapon_changed_in_combat = String(weapon.get("name", "")) != prev_name
		"armor":
			equipped_armor = it
		"helmet":
			equipped_helmet = it
		"necklace":
			equipped_necklace = it
		"gloves":
			equipped_gloves = it
		"boots":
			equipped_boots = it
		"ring1":
			equipped_ring1 = it
		"ring2":
			equipped_ring2 = it
		_:
			pass

	_refresh_ring_skill()
	_refresh_weapon_skill()
	_sync_player_max_hp_from_gear()

	_update_labels()
	_sync_inventory_screen_if_open()

	if weapon_changed_in_combat:
		_consume_weapon_equip_turn()

func _unarmed_weapon() -> Dictionary:
	return {
		"type": "weapon",
		"name": "Unarmed",
		"base": 1,
		"scale": {"str": 1.0, "agi": 0.0},
		"bonus_stat": "",
		"bonus_value": 0,
		"rarity": 0
	}

func _unequip_item(key: String) -> void:
	var it: Dictionary = _get_equipped_item_for_slot(key)
	if it.is_empty():
		return

	# wyczyść slot
	match key:
		"weapon":
			weapon = _unarmed_weapon()
		"armor":
			equipped_armor = {}
		"helmet":
			equipped_helmet = {}
		"necklace":
			equipped_necklace = {}
		"gloves":
			equipped_gloves = {}
		"boots":
			equipped_boots = {}
		"ring1":
			equipped_ring1 = {}
		"ring2":
			equipped_ring2 = {}
		_:
			pass

	_refresh_ring_skill()
	_refresh_weapon_skill()
	_sync_player_max_hp_from_gear()

	_update_labels()
	_sync_inventory_screen_if_open()

func _weapon_form_from_name(item_name: String) -> String:
	return _weapon_equipment.form_from_name(item_name)


func _weapon_form_from_item(it: Dictionary) -> String:
	return _weapon_equipment.form_from_item(it)


func _refresh_weapon_skill() -> void:
	_weapon_equipment.refresh_weapon_skill()


func _skill_icon_texture_for(sd: Dictionary) -> Texture2D:
	var icon_key := String(sd.get("icon_key", ""))
	if icon_key != "" and ICON_BY_TYPE.has(icon_key):
		var t = load(String(ICON_BY_TYPE[icon_key]))
		if t is Texture2D:
			return t
	return _skill_icon_for(String(sd.get("name", "")))


func _refresh_ring_skill() -> void:
	var ring_skill_id := ""
	if not equipped_ring1.is_empty():
		ring_skill_id = String(equipped_ring1.get("skill_id", ""))
	if ring_skill_id == "" and not equipped_ring2.is_empty():
		ring_skill_id = String(equipped_ring2.get("skill_id", ""))

	# don't override class skill in slot 2
	if skills.has(2) and String(skills[2].get("source", "")) == "class":
		return

	if ring_skill_id == "":
		if skills.has(2) and String(skills[2].get("source", "")) == "ring":
			skills.erase(2)
		if skill_cooldowns.has(2):
			skill_cooldowns.erase(2)
		_update_skills_ui()
		return

	var sk: Dictionary = RING_SKILLS.get(ring_skill_id, {})
	if sk.is_empty():
		return
	skills[2] = {
		"key":  String(sk.get("key", "")),
		"name": String(sk.get("name", "Ring Skill")),
		"type": "active",
		"desc": String(sk.get("desc", "")),
		"source": "ring"
	}
	if not skill_cooldowns.has(2):
		skill_cooldowns[2] = 0
	_update_skills_ui()


func _rarity_name(r:int) -> String:
	match r:
		Rarity.COMMON:    return "COMMON"
		Rarity.RARE:      return "RARE"
		Rarity.EPIC:      return "EPIC"
		Rarity.LEGEND:    return "LEGEND"
		Rarity.UNIQUE:    return "UNIQUE"
		_:                return "?"

func _add_item_to_inventory(it:Dictionary) -> Dictionary:
	var t := str(it.get("type",""))
	match t:
		"weapon":
			inventory["weapon"].append(it)
			return {"key":"weapon","index":inventory["weapon"].size()-1}
		"armor":
			inventory["armor"].append(it)
			return {"key":"armor","index":inventory["armor"].size()-1}
		"helmet":
			inventory["helmet"].append(it)
			return {"key":"helmet","index":inventory["helmet"].size()-1}
		"necklace":
			inventory["necklace"].append(it)
			return {"key":"necklace","index":inventory["necklace"].size()-1}
		"gloves":
			inventory["gloves"].append(it)
			return {"key":"gloves","index":inventory["gloves"].size()-1}
		"boots":
			inventory["boots"].append(it)
			return {"key":"boots","index":inventory["boots"].size()-1}
		"ring1":
			inventory["ring1"].append(it)
			return {"key":"ring1","index":inventory["ring1"].size()-1}
		"ring2":
			inventory["ring2"].append(it)
			return {"key":"ring2","index":inventory["ring2"].size()-1}
		_:
			return {}

func _show_loot_toast(item: Dictionary) -> void:
	if not $CanvasLayer:
		return
	var rar:int = int(item.get("rarity", Rarity.COMMON))

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 120)
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 60
	panel.offset_right = -60
	panel.offset_top = 60
	panel.offset_bottom = 180
	panel.z_index = 450
	$CanvasLayer.add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	panel.add_child(root)

	var hdr := Label.new()
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.text = "ITEM FOUND"
	hdr.add_theme_font_size_override("font_size", 18)
	hdr.modulate = UI_COL["accent"]
	if DMG_FONT: hdr.add_theme_font_override("font", DMG_FONT)
	root.add_child(hdr)

	var name := Label.new()
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.text = "%s  (%s)" % [String(item.get("name","???")), _rarity_name(rar)]
	name.add_theme_font_size_override("font_size", 20)
	name.modulate = RARITY_COLORS.get(rar, Color.WHITE)
	if DMG_FONT: name.add_theme_font_override("font", DMG_FONT)
	root.add_child(name)

	var stats := Label.new()
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.text = _inventory_item_line(item)
	root.add_child(stats)

	panel.modulate.a = 0.0
	panel.position.y -= 10
	var tw := get_tree().create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.16).from(0.0)
	tw.parallel().tween_property(panel, "position:y", panel.position.y + 10, 0.16)
	tw.tween_interval(1.8)
	tw.tween_property(panel, "modulate:a", 0.0, 0.18)
	tw.finished.connect(func():
		if is_instance_valid(panel):
			panel.queue_free()
	)


func _roll_enemy_loot_drop(enemy_data: Dictionary) -> void:
	if enemy_data.is_empty(): return
	var diff := int(enemy_data.get("difficulty", 1))
	diff = clamp(diff, 1, 5)

	var base_chance := float(DROP_CHANCE_BY_DIFF.get(diff, 0.15))
	# bonus za „bossowate” nazwy
	var nm := str(enemy_data.get("name","")).to_lower()
	if nm.find("king") != -1 or nm.find("lich") != -1:
		base_chance += 0.08

	if randf() > base_chance:
		return

	# slot (faworyzuj broń/pancerz)
	var slot_roll := randi() % 100
	var slot_key := ""
	if slot_roll < 40:
		slot_key = "weapon"
	elif slot_roll < 75:
		slot_key = "armor"
	elif slot_roll < 90:
		slot_key = "helmet"
	else:
		slot_key = "necklace"


	# rarity → item → dodaj do ekwipunku
	var rarity := _weighted_rarity_by_diff(diff)
	var item := _gen_random_item(slot_key, rarity, diff)
	var ref := _add_item_to_inventory(item)

	# log + zielony popup tekstowy (jak było) + NOWE okienko
	if lbl_log:
		lbl_log.text = "Loot: %s (%s)" % [str(item.get("name","???")), _rarity_name(int(item.get("rarity", Rarity.COMMON)))]
	show_damage_popup(player, str(item.get("name","???")), "heal")

	_sync_inventory_screen_if_open()

	# popup z przyciskiem "Equip now"
	if not ref.is_empty():
		_show_loot_toast(item)



# Sklejenie sensownych widełek dla bazowego dmg wg rzadkości
func _weapon_base_minmax_for_rarity(r:int) -> Vector2i:
	match r:
		Rarity.COMMON:    return Vector2i(8, 16)
		Rarity.RARE:      return Vector2i(14, 20)
		Rarity.EPIC:      return Vector2i(18, 30)
		Rarity.LEGEND:    return Vector2i(30, 100)
		_:                return Vector2i(8, 16)

func _weighted_rarity_by_diff(diff:int) -> int:
	# DEV: wymuszony drop z panelu dev
	if _dev_forced_rarity >= 0:
		return _dev_forced_rarity
	var weights: Dictionary = RARITY_WEIGHTS_BY_DIFF.get(diff, RARITY_WEIGHTS_BY_DIFF[1])
	var total := 0
	# Legend/Unique never drop from normal weighted table
	for r in [Rarity.COMMON, Rarity.RARE, Rarity.EPIC]:
		total += int(weights.get(r, 0))
	if total <= 0:
		return Rarity.COMMON
	var pick := randi() % total
	var acc := 0
	for r in [Rarity.COMMON, Rarity.RARE, Rarity.EPIC]:
		acc += int(weights.get(r,0))
		if pick < acc:
			return r
	return Rarity.COMMON

func _gen_random_item(slot_key:String, rarity:int, diff:int) -> Dictionary:
	# DUŻO większe pule nazw
	var base_names: Dictionary = {
		"weapon": [
			"Rusty","Iron","Steel","Knight","Champion","Sun","Void","Ancient","Mythril","Dwarven","Runed","Oaken",
			"Storm","Blood","Moon","Star","Kingsguard","Vanguard","Highborn","Eclipse","Grim","Ashen","Sable",
			"Gilded","Dragon","Titan","Obsidian","Silver","Auric","Frost"
		],
		"armor": [
			"Leather","Chain","Scale","Knight","Dragon","Aegis","Titan","Celestial","Warden","Sentinel","Battlemage",
			"Runed","Vanguard","Sunguard","Stalwart","Bone","Grave","Ironbark","Stormplate","Lionheart","Highguard",
			"Thorn","Glacier","Ember","Dread","Ward","Oath","Kingsguard","Bloodforged","Eclipse"
		],
		"helmet": [
			"Cap","Hood","Helm","Visor","Crown","Mask","Greathelm","Halo","Barbute","Sallet","Basinet","Warhood",
			"Skullcap","Kite","Phoenix","Dragon","Wolf","Bear","Lion","Warden","Runed","Aegis","Gale","Dread",
			"Griffon","Raven","Owl","Auric","Iron","Frost"
		],
		"necklace": [
			"Beads","Charm","Talisman","Pendant","Amulet","Sigil","Relic","Emblem","Icon","Medallion","Torque","Locket",
			"Seal","Focus","Glimmer","Runestone","Sunshard","Moondrop","Aether","Spark","Halo","Glyph","Bond","Heart",
			"Starshard","Dawnstone","Nightstone","Spirit","Totem","Crest"
		],
		"gloves": ["Leather","Chain","Runed","Warden","Vanguard","Storm","Ashen","Auric","Frost"],
		"boots":  ["Leather","Chain","Runed","Warden","Vanguard","Storm","Ashen","Auric","Frost"],
		"ring":   ["Band","Loop","Signet","Seal","Circle","Oath","Mark","Glyph","Rune"]
	}

	var suffix_by_rar: Dictionary = {
		Rarity.COMMON:    ["","of the Field","of the Guard","of the Pawn","of the Footman"],
		Rarity.RARE:      ["of Swiftness","of the Wolf","of the Oak","of Sparks","of the Gale","of the Stallion"],
		Rarity.EPIC:      ["of Dawn","of the Storm","of Kings","of Nightfall","of the Colossus","of the Vanguard"],
		Rarity.LEGEND:    ["of Eternity","of the Sun","of the Ancients","of True North","of the First Forge"]
	}

	# delikatny wzrost mocy wraz z trudnością (łagodny, żeby balans nie odlatywał)
	var pow_mult: float = 1.0 + 0.06 * float(diff - 1)  # 6% / poziom trudności

	# Nazwa
	var names_arr: Array = base_names.get(slot_key, ["Old"])
	var core: String = str(names_arr[randi() % names_arr.size()])
	var suf_arr: Array = suffix_by_rar.get(rarity, [""])
	var suf: String = str(suf_arr[randi() % suf_arr.size()])

	var item_name: String = ""
	match slot_key:
		"weapon":
			var forms := ["Sword","Axe","Dagger","Mace","Spear","Hammer","Blade","Saber","Crossbow","Bow"]
			item_name = "%s %s %s" % [core, forms[randi()%forms.size()], suf]
		"armor":
			var forms2 := ["Vest","Mail","Cuirass","Plates","Hauberk","Breastplate","Carapace","Harness"]
			item_name = "%s %s %s" % [core, forms2[randi()%forms2.size()], suf]
		"helmet":
			item_name = "%s %s %s" % [core, "Helm", suf]
		"necklace":
			item_name = "%s %s" % [core, "Talisman"]
		"gloves":
			item_name = "%s Gloves %s" % [core, suf]
		"boots":
			item_name = "%s Boots %s" % [core, suf]
		"ring1", "ring2":
			item_name = "%s %s" % [core, "Ring"]
		_:
			item_name = core

	# Statystyki – BALANS
	match slot_key:
		"weapon":
			# bazę ograniczamy widełkami dla rzadkości, a następnie lekko skalujemy trudnością
			var mm: Vector2i = _weapon_base_minmax_for_rarity(rarity)     # Vector2i(min, max)
			var base0: float = lerpf(float(mm.x), float(mm.y), randf())   # los w widełkach rzadkości
			var base: int = int(round(base0 * pow_mult))                  # lekko rośnie z diff (6%/lvl)

			# skalowania STR/AGI – sumarycznie ~1.2–1.6, żeby dmg nie eksplodował
			var str_scale: float = randf_range(0.4, 1.2)
			var agi_scale: float = randf_range(0.0, 1.0)
			var sum: float = str_scale + agi_scale
			if sum < 1.2:
				var need: float = 1.2 - sum
				str_scale += need * randf()
				agi_scale += need * (1.0 - randf())
			elif sum > 1.6:
				var cut: float = sum - 1.6
				str_scale -= cut * randf()
				agi_scale -= cut * (1.0 - randf())

			# zaokrąglamy do 0.1 dla estetyki
			str_scale = snappedf(str_scale, 0.1)
			agi_scale = snappedf(agi_scale, 0.1)

			var item: Dictionary = {
				"type":"weapon","name":item_name,"rarity":rarity,
				"base": base,
				"scale": {"str": str_scale, "agi": agi_scale}
			}
			var b: Dictionary = _roll_bonus_for_rarity(rarity)
			if not b.is_empty():
				item["bonus_stat"] = b["stat"]
				item["bonus_value"] = int(b["value"])
			return item

		"armor":
			# Armor (0-15)
			var armor_base = clamp(1 + diff, 1, 10)
			var rare_boost := 0
			match rarity:
				Rarity.RARE:
					rare_boost = 1
				Rarity.EPIC:
					rare_boost = 2
				Rarity.LEGEND:
					rare_boost = 3
			var armor_val: int = clamp(armor_base + rare_boost, 0, 15)
			var at := _rand_armor_type()
			# Berserker = tylko dmg (weapon_dmg w bonuses), bez wartości pancerza na kaflu.
			if at == "berserker":
				armor_val = 0
			var item2: Dictionary = {
				"type":"armor","name":item_name,"rarity":rarity,
				"armor": armor_val,
				"armor_type": at,
				"bonuses": _roll_armor_family_bonuses("armor", rarity, at)
			}
			return item2

		"gloves":
			var gt := _rand_armor_type()
			return {
				"type":"gloves","name":item_name,"rarity":rarity,
				"armor_type": gt,
				"bonuses": _roll_armor_family_bonuses("gloves", rarity, gt)
			}

		"boots":
			var bt := _rand_armor_type()
			return {
				"type":"boots","name":item_name,"rarity":rarity,
				"armor_type": bt,
				"bonuses": _roll_armor_family_bonuses("boots", rarity, bt)
			}

		"ring1", "ring2":
			return {
				"type": slot_key, "name": item_name, "rarity": rarity,
				"skill_id": "ring_skill_placeholder"
			}

		"helmet":
			# HP bonus – łagodnie z diff i rare
			var hp_base: float = 6.0 + 4.0 * float(diff)
			var rare_mult: float = 1.0
			match rarity:
				Rarity.RARE:
					rare_mult = 1.15
				Rarity.EPIC:
					rare_mult = 1.32
				Rarity.LEGEND:
					rare_mult = 1.55
			var hp: int = int(round(hp_base * rare_mult))

			var ht := _rand_armor_type()
			var item3: Dictionary = {
				"type":"helmet","name":item_name,"rarity":rarity,
				"hp_bonus": hp,
				"armor_type": ht,
				"bonuses": _roll_armor_family_bonuses("helmet", rarity, ht)
			}
			return item3

		"necklace":
			# bonus do mnożnika kryta – skromny, ale odczuwalny
			var critb: float = (0.02 + 0.015 * float(diff))
			var rare_mult2: float = 1.0
			match rarity:
				Rarity.RARE:
					rare_mult2 = 1.15
				Rarity.EPIC:
					rare_mult2 = 1.35
				Rarity.LEGEND:
					rare_mult2 = 1.60
			critb = snappedf(critb * rare_mult2, 0.01)

			var item4: Dictionary = {
				"type":"necklace","name":item_name,"rarity":rarity,
				"crit_bonus": critb
			}
			var b4: Dictionary = _roll_bonus_for_rarity(rarity)
			if not b4.is_empty():
				item4["bonus_stat"] = b4["stat"]
				item4["bonus_value"] = int(b4["value"])
			return item4

		_:
			return {"type":"misc","name":"Shiny Pebble","rarity":Rarity.COMMON}


func _rand_bonus_stat() -> String:
	return BONUS_STATS[randi() % BONUS_STATS.size()]

func _roll_bonus_for_rarity(rarity:int) -> Dictionary:
	match rarity:
		Rarity.COMMON:
			return {}
		Rarity.RARE:
			if randf() <= BONUS_CHANCE_RARE:
				return {"stat":"str","value":1} if (randi() % 2 == 0) else {"stat":_rand_bonus_stat(), "value":1}
			return {}
		Rarity.EPIC:
			return {"stat": _rand_bonus_stat(), "value": randi_range(2, 3)}
		Rarity.LEGEND:
			return {"stat": _rand_bonus_stat(), "value": randi_range(3, 8)}
		Rarity.UNIQUE:
			return {}
		_:
			return {}

func _rand_armor_type() -> String:
	var types := ["light", "medium", "heavy", "berserker"]
	return types[randi() % types.size()]

func _bonus_range_for_rarity(rarity: int) -> Vector2i:
	match rarity:
		Rarity.COMMON:
			return Vector2i(0, 1)
		Rarity.RARE:
			return Vector2i(1, 2)
		Rarity.EPIC:
			return Vector2i(2, 4)
		Rarity.LEGEND:
			return Vector2i(4, 7)
		Rarity.UNIQUE:
			return Vector2i(0, 0)
		_:
			return Vector2i(0, 1)

func _roll_armor_family_bonuses(_slot: String, rarity: int, armor_type: String) -> Dictionary:
	# Slot currently doesn't change behavior; kept for future tuning.
	var t := armor_type
	var r := _bonus_range_for_rarity(rarity)
	var v := randi_range(r.x, r.y)
	var bonuses := {}
	match t:
		"light":
			bonuses["agi"] = v
		"medium":
			bonuses["str"] = v
		"heavy":
			bonuses["vit"] = v
		"berserker":
			bonuses["weapon_dmg"] = v
	return bonuses

func _get_equipped_item_for_slot(key:String) -> Dictionary:
	match key:
		"weapon":
			# weapon to u Ciebie luźny słownik – zwracamy go
			return weapon
		"armor":
			return equipped_armor
		"helmet":
			return equipped_helmet
		"necklace":
			return equipped_necklace
		"gloves":
			return equipped_gloves
		"boots":
			return equipped_boots
		"ring1":
			return equipped_ring1
		"ring2":
			return equipped_ring2
		_:
			return {}

# --- Staty: BAZA na węźle gracza + suma z założonych przedmiotów (osobno) ---

func _accumulate_item_primary_stats(it: Dictionary, acc: Dictionary) -> void:
	if it.is_empty():
		return
	var bn: Dictionary = it.get("bonuses", {})
	for kk in ["str", "agi", "vit", "crit"]:
		acc[kk] = int(acc[kk]) + int(bn.get(kk, 0))
	var pairs: Array = [["bonus_stat", "bonus_value"], ["bonus_stat2", "bonus_value2"]]
	for p in pairs:
		var sk := String(p[0])
		var vk := String(p[1])
		var nm := String(it.get(sk, ""))
		var val := int(it.get(vk, 0))
		if nm == "" or val <= 0:
			continue
		if acc.has(nm):
			acc[nm] = int(acc[nm]) + val


func _equipment_primary_bonuses_total() -> Dictionary:
	var acc := {"str": 0, "agi": 0, "vit": 0, "crit": 0}
	for slot_key in ["weapon", "armor", "helmet", "necklace", "gloves", "boots", "ring1", "ring2"]:
		_accumulate_item_primary_stats(_get_equipped_item_for_slot(slot_key), acc)
	return acc


func _effective_strength() -> int:
	return player.strength + int(_equipment_primary_bonuses_total()["str"])


func _effective_agility() -> int:
	return player.agility + int(_equipment_primary_bonuses_total()["agi"])


func _effective_vitality() -> int:
	return player.vitality + int(_equipment_primary_bonuses_total()["vit"])


func _effective_crit_stat() -> int:
	return player.crit + int(_equipment_primary_bonuses_total()["crit"])


func _player_effective_stat_pack_for_ui() -> Dictionary:
	var b := _equipment_primary_bonuses_total()
	return {
		"str": player.strength + int(b["str"]),
		"agi": player.agility + int(b["agi"]),
		"vit": player.vitality + int(b["vit"]),
		"crit": player.crit + int(b["crit"]),
	}


func _apply_effective_primary_stats_to_inventory_screen() -> void:
	if inventory_screen == null or not is_instance_valid(inventory_screen):
		return
	var e: Dictionary = _player_effective_stat_pack_for_ui()
	inventory_screen.player_stats["str"] = int(e["str"])
	inventory_screen.player_stats["agi"] = int(e["agi"])
	inventory_screen.player_stats["vit"] = int(e["vit"])
	inventory_screen.player_stats["crit"] = int(e["crit"])


func _sync_player_max_hp_from_gear() -> void:
	if player == null:
		return
	var b := _equipment_primary_bonuses_total()
	var evit: int = int(player.vitality) + int(b["vit"])
	var helm_flat := 0
	if not equipped_helmet.is_empty():
		helm_flat = int(equipped_helmet.get("hp_bonus", 0))
	var prev_max: int = player.max_hp
	var prev_hp: int = player.hp
	var new_max: int = max(1, int(player.base_max_hp) + evit * PLAYER_VIT_HP_PER_POINT + helm_flat)
	player.max_hp = new_max
	if prev_max > 0:
		player.hp = clamp(int(round(float(prev_hp) / float(prev_max) * float(new_max))), 1, new_max)
	else:
		player.hp = clamp(prev_hp, 1, new_max)
	player.emit_signal("hp_changed", player.hp, player.max_hp)


func _sync_run_loadout_from_equipment() -> void:
	var equipped := {}
	for slot in GameState.EQUIPMENT_SLOT_KEYS:
		equipped[slot] = _get_equipped_item_for_slot(slot)
	GameState.sync_run_loadout_from_equipped(equipped)


## Czyści sloty na postaci przed powrotem do domu (meta zapisuje już czystą bazę — bonusy są tylko z gear).
func _strip_all_equipment_bonuses_for_save() -> void:
	_sync_run_loadout_from_equipment()
	var order: Array[String] = [
		"necklace", "ring1", "ring2", "gloves", "boots", "armor", "helmet", "weapon",
	]
	for key in order:
		var it: Dictionary = _get_equipped_item_for_slot(key)
		if it.is_empty():
			continue
		if key == "weapon" and String(it.get("name", "Unarmed")) == "Unarmed":
			continue
		_unequip_item(key)
	_sync_player_max_hp_from_gear()
	_on_player_stats_changed(player.strength, player.agility, player.vitality, player.crit, player.stat_points)


func _style_skill_hotbar_empty_slot() -> StyleBoxFlat:
	if _style_skill_hotbar_empty != null:
		return _style_skill_hotbar_empty
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.13, 0.16, 0.28)
	sb.border_color = Color(0.55, 0.58, 0.65, 0.22)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.anti_aliasing = true
	_style_skill_hotbar_empty = sb
	return sb


func _clear_skill_bar_theme_overrides(btn: BaseButton) -> void:
	for sn in _SKILL_BAR_STYLE_STATES:
		btn.remove_theme_stylebox_override(sn)


func _on_skill_bar_slot_pressed(slot: int) -> void:
	_try_use_skill(slot)


func _collect_active_skill_slots(panel: Node) -> void:
	skill_bar_buttons.clear()
	skill_bar_slot_numbers.clear()
	var entries: Array[Dictionary] = []
	for node in panel.find_children("SkillSlot*", "BaseButton", true, false):
		if not node is BaseButton:
			continue
		var suffix := String(node.name).trim_prefix("SkillSlot")
		if not suffix.is_valid_int():
			continue
		entries.append({
			"slot": int(suffix),
			"btn": node as BaseButton,
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["slot"]) < int(b["slot"])
	)
	for e in entries:
		var slot_num: int = int(e["slot"])
		var btn: BaseButton = e["btn"] as BaseButton
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_skill_bar_slot_pressed.bind(slot_num))
		skill_bar_slot_numbers.append(slot_num)
		skill_bar_buttons.append(btn)


func _wire_modular_skills_ui() -> void:
	if skills_hotbar_wired:
		return
	var panel := get_node_or_null("CanvasLayer/UIRoot/PanelActiveSkills")
	var pgrid := get_node_or_null("CanvasLayer/UIRoot/PanelPassiveSkills/PassiveSkillsGrid") as GridContainer
	if panel == null:
		push_error("main.tscn: brak CanvasLayer/UIRoot/PanelActiveSkills — hotbar skilli nie działa.")
		return
	passive_skill_slots.clear()
	_collect_active_skill_slots(panel)
	if pgrid:
		# Sloty pasywne też są dynamiczne (np. 4)
		for pi in range(1, 33):
			var tr := pgrid.get_node_or_null("PassiveSlot%d" % pi) as TextureRect
			if tr == null:
				break
			tr.mouse_filter = Control.MOUSE_FILTER_STOP
			passive_skill_slots.append(tr)

	skills_hotbar_wired = (skill_bar_buttons.size() > 0)


func _create_skills_ui() -> void:
	if skills_hotbar_wired:
		return
	_wire_modular_skills_ui()


func _passive_ui_lines() -> PackedStringArray:
	var out: PackedStringArray = []
	var main := _current_passive_description().strip_edges()
	if main != "":
		out.append(main)
	return out


func _update_passive_skills_ui() -> void:
	if passive_skill_slots.is_empty():
		return
	var lines := _passive_ui_lines()
	for i in range(passive_skill_slots.size()):
		var tr: TextureRect = passive_skill_slots[i]
		if tr == null or not is_instance_valid(tr):
			continue
		if i < lines.size():
			tr.visible = true
			tr.tooltip_text = String(lines[i])
			tr.modulate = Color.WHITE
		else:
			tr.visible = true
			tr.tooltip_text = ""
			tr.modulate = Color(0.45, 0.45, 0.48, 0.35)


func _update_skills_ui() -> void:
	if not skills_hotbar_wired or skill_bar_buttons.is_empty():
		return
	for idx in range(skill_bar_buttons.size()):
		var slot: int = skill_bar_slot_numbers[idx] if idx < skill_bar_slot_numbers.size() else (idx + 1)
		var btn: BaseButton = skill_bar_buttons[idx]
		if btn == null or not is_instance_valid(btn):
			continue
		if skills.has(slot):
			_clear_skill_bar_theme_overrides(btn)
			if btn is Button:
				(btn as Button).flat = true
			var sd: Dictionary = skills[slot]
			var nm := String(sd.get("name", "—"))
			var cd := int(skill_cooldowns.get(slot, 0))
			var desc := String(sd.get("desc", ""))
			btn.visible = true
			btn.disabled = cd > 0
			if btn is Button:
				var bbtn := btn as Button
				bbtn.icon = _skill_icon_texture_for(sd)
				bbtn.expand_icon = true
				bbtn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
				bbtn.text = ""
			var tt := "[%d] %s\n%s" % [slot, nm, desc]
			if cd > 0:
				tt += "\nCooldown: %d" % cd
			btn.tooltip_text = tt
			btn.modulate = Color.WHITE if cd == 0 else Color(0.7, 0.7, 0.72, 1.0)
		else:
			var es := _style_skill_hotbar_empty_slot()
			for sn in _SKILL_BAR_STYLE_STATES:
				btn.add_theme_stylebox_override(sn, es)
			if btn is Button:
				var ebtn := btn as Button
				ebtn.flat = false
				ebtn.icon = null
				ebtn.text = ""
			btn.visible = true
			btn.disabled = true
			btn.tooltip_text = "Skill slot %d (empty)." % slot
			btn.modulate = Color(1, 1, 1, 0.85)

	_update_passive_skills_ui()





func _tick_skill_cooldowns() -> void:
	# co akcję redukuj wszystkie CD o 1, ale nie poniżej 0
	for k in skill_cooldowns.keys():
		var v: int = int(skill_cooldowns[k])
		if v > 0:
			skill_cooldowns[k] = v - 1
	_update_skills_ui()


func _try_use_skill(slot:int) -> void:
	if resolving_turn: return
	if turn != Turn.PLAYER: return
	if not player.is_alive() or not enemy.is_alive(): return
	if not skills.has(slot): return

	var cd: int = int(skill_cooldowns.get(slot, 0))
	if cd > 0:
		if lbl_log:
			lbl_log.text = "%s is on cooldown (%d turns)." % [String(skills[slot].get("name","Skill")), cd]
		return

	var skey := String(skills[slot].get("key",""))
	match skey:
		"basic_strike":
			await _skill_basic_strike(slot)
		"power_strike":
			await _skill_power_strike(slot)
		"fury":
			await _skill_fury(slot)
		"quick_slash":
			await _skill_quick_slash(slot)
		"shield":
			await _skill_shield_block(slot)
		"weapon_skill":
			await _use_weapon_skill(slot)
		_:
			if lbl_log:
				lbl_log.text = "Skill not implemented yet."

	_update_skills_ui()





func _skill_power_strike(slot: int) -> void:
	await _class_skills.power_strike(slot)


# drobny „bezpiecznik”: jeśli w przyszłości coś zepsuje naszyjnik/crit mult
func calc_crit_multiplier() -> float:
	# bazowy mnożnik + efektywny CRIT ze statów (baza + przedmioty) + część dodana z naszyjnika (float)
	var mult: float = CRIT_MULT + float(_effective_crit_stat()) * CRIT_PER_POINT
	if not equipped_necklace.is_empty():
		mult += float(equipped_necklace.get("crit_bonus", 0.0))
	return max(1.0, mult)  # bezpieczeństwo: nigdy poniżej 1.0

func calc_crit_multiplier_safe() -> float:
	var m: float = calc_crit_multiplier()
	if not is_finite(m) or m <= 0.0:
		return CRIT_MULT
	return m


func _skill_basic_strike(slot: int) -> void:
	await _class_skills.basic_strike(slot)


func _skill_quick_slash(slot: int) -> void:
	await _class_skills.quick_slash(slot)


func _skill_shield_block(slot: int) -> void:
	await _class_skills.shield_block(slot)


func _skill_fury(slot: int) -> void:
	await _class_skills.fury(slot)


func _weapon_skill_cd_for(slot: int) -> int:
	return _skill_runtime.weapon_skill_cd_for(slot)


func _finish_active_skill_turn(slot: int, cd_turns: int = -1) -> void:
	await _skill_runtime.finish_active_skill_turn(slot, cd_turns)


func _use_weapon_skill(slot: int) -> void:
	await _weapon_skills.use(slot)


func _grant_class_skills(class_key: String) -> void:
	# Slot [1] = podstawowa umiejętność (zostaje bez zmian, jeśli już masz)
	# Jeśli chcesz mieć pewność, że zawsze istnieje: odkomentuj poniższe 2 linie:
	# skills[1] = {"key":"basic_strike", "name":"Basic Strike", "type":"active", "desc":"Reliable hit."}
	# skill_cooldowns[1] = 0

	# Wyczyść poprzedni slot [2] i pasywki (na wypadek zmiany klasy w testach)
	if skills.has(2):
		skills.erase(2)
	if skill_cooldowns.has(2):
		skill_cooldowns.erase(2)
	passive_dodge_chance = 0.0
	passive_armor_bonus = 0
	bloodlust_lifesteal = 0.0

	match class_key:
		"warrior":
			# Active: Power Strike (gwarantowany CRIT, koszt HP) – slot [2]
			skills[2] = {
				"key":"power_strike",
				"name":"Power Strike",
				"type":"active",
				"desc":"Guaranteed critical hit, costs 10% current HP.",
				"source":"class"
			}
			skill_cooldowns[2] = 0
			# (brak pasywki – możesz dodać własną później)

		"assassin":
			# Active: Quick Slash (2 szybkie ciosy 60–100% dmg) – slot [2]
			skills[2] = {
				"key":"quick_slash",
				"name":"Quick Slash",
				"type":"active",
				"desc":"Two swift hits (60–100% dmg each).",
				"source":"class"
			}
			skill_cooldowns[2] = 0
			# Passive: Cat Movement (5% dodge)
			passive_dodge_chance = 0.05

		"guardian":
			# Active: Shield (blokuje następny cios) – slot [2]
			skills[2] = {
				"key":"shield",
				"name":"Shield",
				"type":"active",
				"desc":"Block the next incoming hit.",
				"source":"class"
			}
			skill_cooldowns[2] = 0
			# Passive: Heavily Armed (+1 armor)
			passive_armor_bonus = 1

		"barbarian":
			# Active: Fury (dwa losowania ataku pod rząd zamiast jednego) – slot [2]
			skills[2] = {
				"key":"fury",
				"name":"Fury",
				"type":"active",
				"desc":"Two back-to-back attacks.",
				"source":"class"
			}
			skill_cooldowns[2] = 0
			# Passive: Bloodlust – lekki lifesteal z CRIT (jeśli używasz w logice ataku)
			bloodlust_lifesteal = 0.10

		_:
			# brak/nieznana klasa – nic nie dodajemy
			pass

	_refresh_weapon_skill()
	# odśwież UI jeśli panel już istnieje
	_update_skills_ui()

func _current_passive_description() -> String:
	match chosen_class:
		"assassin":
			return "[PASSIVE] Cat Movement: +5% chance to dodge a hit."
		"guardian":
			return "[PASSIVE] Heavily Armed: +1 Armor."
		"barbarian":
			return "[PASSIVE] Bloodlust: Heal 10% of damage on CRIT."
		"warrior":
			return "[PASSIVE] Weapon Mastery: +10% weapon damage."
		_:
			return ""

func _unvisited_candidate_dungeons() -> Array[int]:
	var out: Array[int] = []
	for k in DUNGEONS.keys():
		var i := int(k)
		# wybieramy tylko nowe dungeony 2..N, nie aktualny i nie odwiedzone
		if i >= 2 and i != current_dungeon_index and not visited_dungeons.has(i):
			out.append(i)
	return out

func _dungeon_name(idx:int) -> String:
	if DUNGEONS.has(idx):
		return String(DUNGEONS[idx]["name"])
	return "Unknown"

func _return_home_after_boss() -> void:
	print("[BOSS] Returning home — loadout saved to permanent_chest")
	_strip_all_equipment_bonuses_for_save()
	GameState.save_player(player, has_evolved, chosen_class)
	GameState.end_run_to_home(true)
	GameState.save(1)
	get_tree().change_scene_to_file("res://home_scene.tscn")


func _offer_branch_choice_after_boss() -> void:
	# Pobierz połączone dungeony których jeszcze nie odwiedzono
	var connected: Array = DUNGEON_CONNECTIONS.get(current_dungeon_index, [])
	var candidates: Array[int] = []
	for idx in connected:
		if not visited_dungeons.has(idx):
			candidates.append(idx)
	# Jeśli wszystkie odwiedzone — pokaż odwiedzone jako opcje (żeby nie blokować gry)
	if candidates.is_empty():
		for idx in connected:
			candidates.append(idx)

	var win := Window.new()
	win.title = "Boss defeated!"
	win.unresizable = true
	win.size = Vector2i(600, 320)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	win.add_child(root)

	var lbl := Label.new()
	lbl.text = "Boss defeated!\nChoose your next path:"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 20)
	if DMG_FONT: lbl.add_theme_font_override("font", DMG_FONT)
	root.add_child(lbl)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(row)

	# Przyciski dungeonów
	for idx in candidates:
		var b := Button.new()
		b.text = "➤  " + _dungeon_name(idx)
		b.custom_minimum_size = Vector2(200, 64)
		b.add_theme_font_size_override("font_size", 17)
		if DMG_FONT: b.add_theme_font_override("font", DMG_FONT)
		b.pressed.connect(func():
			if is_instance_valid(win): win.queue_free()
			_switch_to_dungeon(idx)
		)
		row.add_child(b)

	# Przycisk powrotu do domu
	var home_btn := Button.new()
	home_btn.text = "🏠  Return Home"
	home_btn.custom_minimum_size = Vector2(200, 64)
	home_btn.add_theme_font_size_override("font_size", 17)
	if DMG_FONT: home_btn.add_theme_font_override("font", DMG_FONT)
	home_btn.add_theme_color_override("font_color", Color(0.55, 0.90, 0.45))
	home_btn.pressed.connect(func():
		if is_instance_valid(win): win.queue_free()
		GameState.meta["visited_dungeons"] = visited_dungeons.duplicate()
		_strip_all_equipment_bonuses_for_save()
		GameState.save_player(player, has_evolved, chosen_class)
		GameState.end_run_to_home(true)
		GameState.save(GameState.current_slot)
		get_tree().change_scene_to_file("res://home_scene.tscn")
	)
	row.add_child(home_btn)

	if btn_attack: btn_attack.disabled = true

	if $CanvasLayer:
		$CanvasLayer.add_child(win)
	else:
		add_child(win)
	win.popup_centered()
	win.grab_focus()



func _ensure_world_background() -> void:
	if bg_sprite and is_instance_valid(bg_sprite):
		return
	bg_sprite = Sprite2D.new()
	bg_sprite.name = "WorldBackground"
	bg_sprite.centered = false           # lewy-górny narożnik w (0,0)
	bg_sprite.z_index = -1000            # pewnie ZA postaciami
	add_child(bg_sprite)                 # ← DO GŁÓWNEGO NODE2D, nie do CanvasLayer!

	# reaguj na zmianę rozmiaru okna
	get_viewport().size_changed.connect(_fit_background_to_viewport)

func _fit_background_to_viewport() -> void:
	if not bg_sprite or not bg_sprite.texture:
		return
	var tex_size: Vector2 = bg_sprite.texture.get_size()
	if tex_size.x <= 0 or tex_size.y <= 0:
		return
	var vp: Vector2 = get_viewport_rect().size
	var sx := vp.x / tex_size.x
	var sy := vp.y / tex_size.y
	var s = max(sx, sy)                 # COVER – wypełnij ekran
	bg_sprite.scale = Vector2(s, s)
	_update_world_background_position()
	bg_sprite.position = Vector2.ZERO    # lewy-górny róg ekranu

func _apply_world_background_for_current_dungeon() -> void:
	_ensure_world_background()
	var dname := String(DUNGEONS[current_dungeon_index]["name"])
	var path := String(BG_BY_DUNGEON.get(dname, ""))
	if path == "":
		bg_sprite.texture = null
		return
	var tex := load(path)
	if tex is Texture2D:
		bg_sprite.texture = tex
		_fit_background_to_viewport()
		_update_world_background_position()

func _update_world_background_position() -> void:
	if bg_sprite == null or not is_instance_valid(bg_sprite): return
	if cam == null: return
	if bg_sprite.texture == null: return

	var vp := get_viewport_rect().size
	var sc := bg_sprite.scale
	# world coords of screen center
	var center := cam.get_screen_center_position()
	# move bg so its top-left matches the screen top-left
	bg_sprite.global_position = center - Vector2(vp.x * 0.5 / sc.x, vp.y * 0.5 / sc.y)

# ===============================
# DEV / DEBUG: generuje po 10 losowych itemów każdego typu
# ===============================
func _dev_fill_inventory() -> void:
	var types := ["weapon", "armor", "helmet", "necklace", "gloves", "boots", "ring1", "ring2"]
	var _rarities := [Rarity.COMMON, Rarity.RARE, Rarity.EPIC, Rarity.LEGEND]

	for t in types:
		if not inventory.has(t):
			inventory[t] = []

		for i in range(10):
			# losowa rzadkość (większe szanse na common)
			var r_roll := randf()
			var rarity := Rarity.COMMON
			if r_roll > 0.9:
				rarity = Rarity.LEGEND
			elif r_roll > 0.7:
				rarity = Rarity.EPIC
			elif r_roll > 0.45:
				rarity = Rarity.RARE

			var diff := 1 + int(randf_range(0, 5))  # losowy poziom trudności (1–5)
			var item := _gen_random_item(t, rarity, diff)
			inventory[t].append(item)

	print("[DEV] Inventory test-fill complete!")
	_sync_inventory_screen_if_open()

# wywołaj to np. z przycisku "Start Run" w Home
# Wywołaj to na starcie (albo gdy wracasz do domu)

# Po kliknięciu "Start Run"


# wywołaj to w dungeonie z przycisku "Exit to Home"
func _return_to_home_and_save(slot: int) -> void:
	_sync_run_loadout_from_equipment()
	GameState.end_run_to_home(false)
	GameState.save(slot)

	_sync_inventory_screen_if_open()

	print("[HOME] Saved to slot %d" % slot)
	# przełącz UI na tryb Home

# ==========================
# HOME PANEL (menu główne w grze)
# ==========================
# Ustaw "process_mode" rekurencyjnie dla całego poddrzewa

# Spróbuj ustawić tło (działa zarówno gdy masz zmienną bg_sprite, jak i node "Background")
func _try_set_bg(path: String) -> void:
	if path == "" or not ResourceLoader.exists(path):
		return
	var bg: Sprite2D = null
	if "bg_sprite" in self:
		var v = get("bg_sprite")
		if v is Sprite2D:
			bg = v
	if bg == null:
		bg = get_node_or_null("Background") as Sprite2D
	if bg:
		bg.texture = load(path)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_go_home"):
		# świadomie ignorujemy w dungeonie
		print("[HOME] Blocked: cannot enter HOME during a run")
		return



func _set_process_mode_recursive(n: Node, mode: int) -> void:
	n.process_mode = mode
	for c in n.get_children():
		_set_process_mode_recursive(c, mode)


func _continue_run_after_event() -> void:
	call_deferred("_continue_run_after_event_async")

func _continue_run_after_event_async() -> void:
	if _encounter_replaced_by_event:
		_encounter_replaced_by_event = false
		var d: Dictionary = _pick_enemy()
		_request_spawn(d)

		return
	await _transition_to_next_enemy()

func _open_shrine_dialog() -> void:
	if not _has_any_items_in_inventory():
		_shrine_open = false
		_shrine_in_progress = false
		call_deferred("_continue_run_after_event")
		return
	if inventory_screen == null:
		_shrine_in_progress = false
		call_deferred("_continue_run_after_event")
		return

	_shrine_open = true
	_shrine_locked = false
	inventory_screen.open_shrine(inventory, _inventory_ui_equipped(), _inventory_ui_stats())
	_set_inventory_paused(true)


func _on_shrine_item_confirmed(slot_key: String, idx: int) -> void:
	_on_shrine_pick_permanent(slot_key, idx)


func _on_shrine_closed() -> void:
	_set_inventory_paused(false)
	_shrine_open = false
	_shrine_in_progress = false
	if shrine_cooldown <= 0:
		shrine_cooldown = 6
	_continue_run_after_event()


func _on_shrine_pick_permanent(slot_key: String, idx: int) -> void:
	if _shrine_locked:
		return
	_shrine_locked = true

	var items: Array = inventory.get(slot_key, [])
	if idx < 0 or idx >= items.size():
		_finish_shrine_after_pick()
		return

	var it: Dictionary = items[idx]
	if it.get("permanent", false):
		_finish_shrine_after_pick()
		return

	GameState.make_permanent(slot_key, it)
	it["permanent"] = true

	_show_toast("Item '" + str(it.get("name", "?")) + "' is now PERMANENT!")
	shrine_cooldown = max(shrine_cooldown, 8)
	_finish_shrine_after_pick()


func _finish_shrine_after_pick() -> void:
	_shrine_open = false
	_shrine_in_progress = false
	_shrine_locked = false
	if inventory_screen and inventory_screen.visible:
		inventory_screen.shrine_mode = false
		inventory_screen.visible = false
		inventory_screen._apply_mode_ui()
		inventory_screen._clear_shrine_offer()
		inventory_screen.closed.emit()
	_set_inventory_paused(false)
	_continue_run_after_event()


func _has_any_items_in_inventory() -> bool:
	for k in GameState.EQUIPMENT_SLOT_KEYS:
		var arr: Array = inventory.get(k, []) as Array
		if not arr.is_empty():
			return true
	return false


# TWARDY WRAPPER — każda próba bezpośredniego wywołania _spawn_enemy
# zostanie przekierowana do routera.
func _spawn_enemy(data: Dictionary) -> void:
	_request_spawn(data)


func _request_spawn(data: Dictionary) -> void:
	# Centralny router – zawsze tędy
	var __name := String(data.get("name", ""))
	var __flag := bool(data.get("shrine", false))
	var __is_shrine := __flag or __name.to_lower().find("shrine") != -1
	print("[SPAWN] router name=", __name, " shrine_flag=", __flag, " → is_shrine=", __is_shrine)

	if __is_shrine:
		# już trwa? ignoruj kolejne zgłoszenia
		if _shrine_in_progress or _shrine_open:
			print("[SHRINE_DEBUG] shrine request ignored (already in progress)")
			return

		# nie mamy żadnych przedmiotów? omiń wydarzenie
		if not _has_any_items_in_inventory():
			_encounter_replaced_by_event = false
			call_deferred("_continue_run_after_event")
			return

		_encounter_replaced_by_event = true
		_shrine_in_progress = true
		call_deferred("_open_shrine_dialog")
		return

	# Normalny przeciwnik – deleguj do istniejącego spawna
	call_deferred("_spawn_enemy_impl", data)  # ważne: deferred = stabilniej przy UI

func _is_item_permanent(it: Dictionary) -> bool:
	return bool(it.get("permanent", false))


func _make_permanent_badge() -> PanelContainer:
	var p := PanelContainer.new()

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.32, 0.12, 0.95)
	sb.border_color = Color(0.45, 0.80, 0.35, 1.0)
	# Godot 4: ustawiamy szerokości krawędzi osobno
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var box := MarginContainer.new()
	box.add_theme_constant_override("margin_left", 6)
	box.add_theme_constant_override("margin_right", 6)
	box.add_theme_constant_override("margin_top", 2)
	box.add_theme_constant_override("margin_bottom", 2)

	var lbl := Label.new()
	lbl.text = "PERMANENT"
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.92, 1.0, 0.92, 1.0))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	box.add_child(lbl)
	p.add_child(box)

	p.custom_minimum_size = Vector2(96, 20)
	return p

func _ui_root() -> Node:
	if has_node("CanvasLayer/UIRoot"):
		return $CanvasLayer/UIRoot
	if has_node("CanvasLayer"):
		return $CanvasLayer
	return self


func _show_toast(msg: String, duration: float = 1.5) -> void:
	var parent := _ui_root()

	var panel := PanelContainer.new()
	panel.name = "ToastPanel"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.75)
	sb.border_color = Color(1, 1, 1, 0.20)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", sb)
	panel.z_index = 100

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 16)
	pad.add_theme_constant_override("margin_right", 16)
	pad.add_theme_constant_override("margin_top", 10)
	pad.add_theme_constant_override("margin_bottom", 10)

	var lbl := Label.new()
	lbl.text = msg
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	pad.add_child(lbl)
	panel.add_child(pad)

	# wycentruj – lekko nad środkiem
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.35
	panel.anchor_bottom = 0.35
	panel.offset_left = -220
	panel.offset_right = 220
	panel.offset_top = -26
	panel.offset_bottom = 26
	panel.modulate = Color(1,1,1,0)

	parent.add_child(panel)

	var t := create_tween()
	t.tween_property(panel, "modulate:a", 1.0, 0.15)
	t.tween_interval(duration)
	t.tween_property(panel, "modulate:a", 0.0, 0.25)
	t.tween_callback(Callable(panel, "queue_free"))

func _go_to_home_test() -> void:
	# opcjonalnie: szybkie potwierdzenie w konsoli
	print("[TEST] Przechodzę do domu na żądanie")
	
	# jeśli chcesz zachować stan runu
	# GameState.end_run_to_home()
	
	get_tree().change_scene_to_file("res://home_scene.tscn")


# ==============================================================
# DEV PANEL
# Włącz/wyłącz przyciskiem [DEV] widocznym w prawym górnym rogu.
# ==============================================================

var _dev_panel: PanelContainer = null
var _dev_panel_visible: bool = false
var _dev_forced_rarity: int = -1  # -1 = losowa; 0-3 = wymuszony drop

func _dev_create_panel() -> void:
	if _dev_panel and is_instance_valid(_dev_panel):
		return

	# --- przycisk toggle (zawsze widoczny) ---
	var toggle_btn := Button.new()
	toggle_btn.text = "DEV"
	toggle_btn.add_theme_font_size_override("font_size", 13)
	toggle_btn.custom_minimum_size = Vector2(52, 28)
	toggle_btn.position = Vector2(get_viewport_rect().size.x - 60, 4)
	toggle_btn.z_index = 200
	toggle_btn.pressed.connect(_dev_toggle_panel)
	toggle_btn.focus_mode = Control.FOCUS_NONE
	if DMG_FONT: toggle_btn.add_theme_font_override("font", DMG_FONT)
	$CanvasLayer.add_child(toggle_btn)

	# --- główny panel ---
	_dev_panel = PanelContainer.new()
	_dev_panel.visible = false
	_dev_panel.z_index = 199
	_dev_panel.custom_minimum_size = Vector2(280, 0)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.10, 0.96)
	sb.border_color = Color(0.9, 0.75, 0.2, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	_dev_panel.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_dev_panel.add_child(vbox)

	# tytuł
	var title := Label.new()
	title.text = "— DEV PANEL —"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.9, 0.75, 0.2))
	title.add_theme_font_size_override("font_size", 15)
	if DMG_FONT: title.add_theme_font_override("font", DMG_FONT)
	vbox.add_child(title)

	vbox.add_child(_dev_separator())

	# --- SEKCJA: EVENTY ---
	vbox.add_child(_dev_section_label("EVENTY"))
	vbox.add_child(_dev_btn("⚡ Wywołaj Shrine",    func(): _dev_trigger_shrine()))
	vbox.add_child(_dev_btn("📦 Wywołaj Chest",     func(): _dev_trigger_chest()))
	vbox.add_child(_dev_btn("💀 Wywołaj bossa",     func(): _dev_spawn_boss()))
	vbox.add_child(_dev_btn("🏠 Wróć do domu",      func(): _dev_goto_home()))

	vbox.add_child(_dev_separator())

	# --- SEKCJA: GRACZ ---
	vbox.add_child(_dev_section_label("GRACZ"))
	vbox.add_child(_dev_btn("❤ Pełne leczenie",    func(): _dev_full_heal()))
	vbox.add_child(_dev_btn("⬆ +1 poziom",         func(): _dev_add_level()))
	vbox.add_child(_dev_btn("⬆⬆ +5 poziomów",      func(): _dev_add_levels(5)))
	vbox.add_child(_dev_btn("🎒 Wypełnij inventory", func(): _dev_fill_inventory(); _sync_inventory_screen_if_open()))

	vbox.add_child(_dev_separator())

	# --- SEKCJA: KOMBAT ---
	vbox.add_child(_dev_section_label("KOMBAT"))
	vbox.add_child(_dev_btn("💥 Wymuś CRIT przeciwnika", func(): _dev_trigger_enemy_crit()))

	vbox.add_child(_dev_separator())

	# --- SEKCJA: DROP RARITY ---
	vbox.add_child(_dev_section_label("WYMUSZ RZADKOŚĆ DROPU"))
	var rarity_row := HBoxContainer.new()
	rarity_row.add_theme_constant_override("separation", 4)
	for r in [["C", 0, Color(1,1,1)], ["R", 1, Color(0.45,0.75,1)], ["E", 2, Color(0.75,0.55,0.95)], ["L", 3, Color(1.0,0.85,0.2)]]:
		var rb := Button.new()
		rb.text = r[0]
		rb.custom_minimum_size = Vector2(44, 28)
		rb.add_theme_color_override("font_color", r[2])
		rb.add_theme_font_size_override("font_size", 13)
		if DMG_FONT: rb.add_theme_font_override("font", DMG_FONT)
		var rval: int = r[1]
		rb.pressed.connect(func(): _dev_set_forced_rarity(rval, rb))
		rarity_row.add_child(rb)
	var rb_off := Button.new()
	rb_off.text = "OFF"
	rb_off.custom_minimum_size = Vector2(44, 28)
	rb_off.add_theme_font_size_override("font_size", 12)
	if DMG_FONT: rb_off.add_theme_font_override("font", DMG_FONT)
	rb_off.pressed.connect(func(): _dev_set_forced_rarity(-1, rb_off))
	rarity_row.add_child(rb_off)
	vbox.add_child(rarity_row)

	vbox.add_child(_dev_separator())

	# --- SEKCJA: DUNGEONS ---
	vbox.add_child(_dev_section_label("TELEPORT DO DUNGEONU"))
	for i in DUNGEONS.keys():
		var dname: String = DUNGEONS[i]["name"]
		var idx: int = i
		vbox.add_child(_dev_btn("➤ " + dname, func(): _dev_goto_dungeon(idx)))

	# pozycja panelu: prawy górny róg, pod przyciskiem toggle
	$CanvasLayer.add_child(_dev_panel)
	_dev_panel.position = Vector2(get_viewport_rect().size.x - 292, 36)


func _dev_toggle_panel() -> void:
	_dev_panel_visible = !_dev_panel_visible
	_dev_panel.visible = _dev_panel_visible
	if not _dev_panel_visible and _evolution_pending and not has_evolved:
		call_deferred("_request_evolution_choice")


# --- helpery UI ---
func _dev_btn(label: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(260, 28)
	b.add_theme_font_size_override("font_size", 13)
	if DMG_FONT: b.add_theme_font_override("font", DMG_FONT)
	b.pressed.connect(cb)
	return b

func _dev_section_label(txt: String) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	l.add_theme_font_size_override("font_size", 12)
	if DMG_FONT: l.add_theme_font_override("font", DMG_FONT)
	return l

func _dev_separator() -> HSeparator:
	var s := HSeparator.new()
	s.add_theme_color_override("color", Color(0.3, 0.3, 0.3, 0.8))
	return s


# --- akcje DEV ---
func _dev_goto_home() -> void:
	GameState.meta["visited_dungeons"] = visited_dungeons.duplicate()
	_strip_all_equipment_bonuses_for_save()
	GameState.save_player(player, has_evolved, chosen_class)
	GameState.end_run_to_home(true)
	GameState.save(GameState.current_slot)
	get_tree().change_scene_to_file("res://home_scene.tscn")

func _dev_spawn_boss() -> void:
	var boss_names := {
		0: "Goblin King",
		1: "Lich",
		2: "High King of Peaks",
		3: "Orc Warlord",
		4: "Dread Matriarch",
		5: "Ancient Worldroot"
	}
	var boss_name: String = boss_names.get(current_dungeon_index, "")
	if boss_name == "":
		_show_toast("No boss for this dungeon!", 1.5)
		return
	# Znajdź bossa w rosterze aktualnego dungeonu
	var boss_data: Dictionary = {}
	for e in DUNGEONS[current_dungeon_index]["enemies"]:
		if e["name"] == boss_name:
			boss_data = e.duplicate(true)
			break
	if boss_data.is_empty():
		_show_toast("Boss not found in roster!", 1.5)
		return
	_request_spawn(boss_data)
	_show_toast("💀 " + boss_name + " appears!", 1.5)

func _dev_trigger_shrine() -> void:
	if _shrine_in_progress or _shrine_open:
		_show_toast("Shrine is already running!", 1.0)
		return
	_dev_toggle_panel()
	_request_spawn({"name": "Sacred Shrine", "hp": 0, "damage": 0, "difficulty": 0, "shrine": true})

func _dev_trigger_chest() -> void:
	_dev_toggle_panel()
	_request_spawn(TREASURE_CHEST_DATA.duplicate(true))

func _dev_full_heal() -> void:
	player.hp = player.max_hp
	player.emit_signal("hp_changed", player.hp, player.max_hp)
	show_damage_popup(player, "FULL HEAL", "heal")
	_show_toast("Dwarf healed!", 1.0)


func _dev_trigger_enemy_crit() -> void:
	if _is_evolution_choice_open():
		_show_toast("Close class choice first!", 1.5)
		return
	if not player.is_alive():
		_show_toast("Player is dead!", 1.5)
		return
	if not enemy.is_alive():
		_show_toast("No enemy to attack!", 1.5)
		return
	if bool(current_enemy_data.get("treasure", false)):
		_show_toast("Chest does not attack!", 1.5)
		return
	if resolving_turn:
		_show_toast("Wait for current action...", 1.2)
		return
	_dev_run_enemy_crit_attack()


func _dev_run_enemy_crit_attack() -> void:
	resolving_turn = true
	if btn_attack:
		btn_attack.disabled = true
	var desc: String = await _enemy_attack_round_async(true)
	if lbl_log:
		lbl_log.text = desc
	await get_tree().create_timer(0.1).timeout
	if player.is_alive():
		set_turn(Turn.PLAYER)
	resolving_turn = false
	_show_toast("Enemy CRIT test", 1.0)


func _dev_add_level() -> void:
	_dev_add_levels(1)

func _dev_add_levels(count: int) -> void:
	for i in range(count):
		player.add_xp(player.xp_to_next - player.xp)
	_show_toast("+%d level(s)! Now LVL %d" % [count, player.level], 1.5)

func _dev_set_forced_rarity(r: int, btn: Button) -> void:
	_dev_forced_rarity = r
	var names := {-1: "OFF", 0: "Common", 1: "Rare", 2: "Epic", 3: "Legendary"}
	_show_toast("Forced drop: %s" % names.get(r, "?"), 1.2)

func _dev_goto_dungeon(idx: int) -> void:
	_dev_toggle_panel()
	_switch_to_dungeon(idx)
	_show_toast("Teleport → %s" % DUNGEONS[idx]["name"], 1.5)
