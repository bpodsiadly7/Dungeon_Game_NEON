extends Control

signal closed
signal loadout_changed
signal item_equipped(slot_key: String, idx: int)
signal item_dropped(slot_key: String, idx: int)
signal stat_spent(stat_key: String)
signal item_unequipped(slot_key: String)
signal item_hovered(item: Dictionary, slot_key: String, idx: int)
signal shrine_item_confirmed(slot_key: String, idx: int)
signal shrine_closed

const SLOT_CONFIG := {
	"helmet":   {"label": "Helmet",   "icon_key": "helmet",   "pos": Vector2(  0, -160)},
	"necklace": {"label": "Necklace", "icon_key": "necklace", "pos": Vector2(150,  -80)},
	"weapon":   {"label": "Weapon",   "icon_key": "sword",    "pos": Vector2(-160,   0)},
	"armor":    {"label": "Armor",    "icon_key": "armor",    "pos": Vector2( 160,   0)},
	"gloves":   {"label": "Gloves",   "icon_key": "gloves",   "pos": Vector2(-150,  110)},
	"boots":    {"label": "Boots",    "icon_key": "boots",    "pos": Vector2(  0,  180)},
	"ring1":    {"label": "Ring 1",   "icon_key": "necklace", "pos": Vector2( -70, -160)},
	"ring2":    {"label": "Ring 2",   "icon_key": "necklace", "pos": Vector2(  70, -160)},
}
const SLOT_SIZE := Vector2(72, 72)

const ICON_BY_TYPE := {
	"sword":    "res://ikony/sword_icon.png",
	"axe":      "res://ikony/axe_icon.png",
	"dagger":   "res://ikony/dagger_icon.png",
	"mace":     "res://ikony/mace_icon.png",
	"spear":    "res://ikony/spear_icon.png",
	"hammer":   "res://ikony/hammer_icon.png",
	"blade":    "res://ikony/blade_icon.png",
	"saber":    "res://ikony/saber_icon.png",
	"bow":      "res://ikony/bow_icon.png",
	"crossbow": "res://ikony/crossbow_icon.png",
	"armor":    "res://ikony/armor_icon.png",
	"armor_light":     "res://ikony/armor_light_icon.png",
	"armor_medium":    "res://ikony/armor_medium_icon.png",
	"armor_heavy":     "res://ikony/armor_heavy_icon.png",
	"armor_berserker": "res://ikony/armor_berserker_icon.png",
	"helmet":   "res://ikony/helmet_icon.png",
	"helmet_light":     "res://ikony/helmet_light_icon.png",
	"helmet_medium":    "res://ikony/helmet_medium_icon.png",
	"helmet_heavy":     "res://ikony/helmet_heavy_icon.png",
	"helmet_berserker": "res://ikony/helmet_berserker_icon.png",
	"necklace": "res://ikony/necklace_icon.png",
	"gloves":   "res://ikony/gloves_icon.png",
	"gloves_light":     "res://ikony/gloves_light_icon.png",
	"gloves_medium":    "res://ikony/gloves_medium_icon.png",
	"gloves_heavy":     "res://ikony/gloves_heavy_icon.png",
	"gloves_berserker": "res://ikony/gloves_berserker_icon.png",
	"boots":    "res://ikony/boots_icon.png",
	"boots_light":     "res://ikony/boots_light_icon.png",
	"boots_medium":    "res://ikony/boots_medium_icon.png",
	"boots_heavy":     "res://ikony/boots_heavy_icon.png",
	"boots_berserker": "res://ikony/boots_berserker_icon.png",
	"ring":    "res://ikony/ring_icon.png",
	"ring1":   "res://ikony/ring_icon.png",
	"ring2":   "res://ikony/ring_icon.png",
}

## Substrings matched against item name for weapon icons — longest first so "crossbow" beats "bow".
const WEAPON_ICON_NAME_KEYS := [
	"crossbow", "dagger", "hammer", "spear", "blade", "saber", "mace", "sword", "axe", "bow",
]

const CLASS_TEX := {
	"warrior":   "res://player_classes/dwarf_warrior.png",
	"assassin":  "res://player_classes/dwarf_assasin.png",
	"guardian":  "res://player_classes/dwarf_guardian.png",
	"barbarian": "res://player_classes/dwarf_barbarian.png",
	"":          "res://player_classes/dwarf_novice.png",
}

const RARITY_COLORS := [
	Color(0.85, 0.85, 0.85, 1.0),
	Color(0.30, 0.65, 1.00, 1.0),
	Color(0.70, 0.35, 1.00, 1.0),
	Color(1.00, 0.80, 0.10, 1.0),
	Color(0.30, 1.00, 0.85, 1.0),
]
const RARITY_NAMES := ["Common", "Rare", "Epic", "Legend", "Unique"]
const SHRINE_TEX_PATH := "res://treasures/shrine.png"
const SHRINE_DROP_SLOT_SIZE := Vector2(128, 128)

# Muszą być identyczne z main.gd (calc_player_weapon_damage / _calc_player_armor_total).
const STR_DMG_PER_POINT := 0.04
const AGI_DMG_PER_POINT := 0.03

var _font: FontFile = null
var inventory: Dictionary = {}
var equipped:  Dictionary = {}
var player_stats: Dictionary = {}
var selected_item: Dictionary = {}
var selected_slot: String = ""
var selected_idx:  int = -1
var _selected_tile: Control = null

enum SortMode { NONE, TYPE, RARITY }
var _sort_mode: SortMode = SortMode.NONE

var _slot_panels:  Dictionary = {}
var _item_grid:    GridContainer = null
var _item_name:    Label = null
var _details_panel: PanelContainer
var _item_stats:   RichTextLabel = null
var _equip_btn:    Button = null
var _drop_btn:     Button = null
var _stats_labels: Dictionary = {}
var _gear_summary_label: Label = null
var _backpack_scroll: ScrollContainer = null
var _char_sprite: TextureRect = null
var _stats_plus_buttons: Dictionary = {}
var _hovered_item: Dictionary = {}
var _hovered_slot: String = ""
var _hovered_idx: int = -1
var _showing_hover_details: bool = false
var _shift_compare_active: bool = false
var _dragging: bool = false
var _drag_item: Dictionary = {}
var _drag_slot: String = ""
var _drag_idx: int = -1
var _drag_preview: PanelContainer = null
var _drag_source: String = "" # "backpack" | "equipped"
var home_mode: bool = false
var shrine_mode: bool = false
var _screen_title: Label = null
var _backpack_title: Label = null
var _overlay: ColorRect = null
var _left_panel: Control = null
var _center_area: Control = null
var _shrine_bg: TextureRect = null
var _shrine_drop_slot: PanelContainer = null
var _shrine_slot_content: VBoxContainer = null
var _shrine_hint_label: Label = null
var _shrine_btn_row: HBoxContainer = null
var _shrine_confirm_btn: Button = null
var _shrine_cancel_btn: Button = null
var _shrine_pending_slot: String = ""
var _shrine_pending_idx: int = -1
## Zwraca Texture2D gracza z aktywnego runa (tak samo jak widoczna postać). Jeśli Callable pusty / null — fallback z GameState.
var _run_player_texture_supplier: Callable = Callable()

const PANEL_SIZE := Vector2i(1200, 720)
## Szerokości kolumn muszą się mieścić w ~1090 px treści (shell + marginesy).
## Środek >= 400 px — sloty ekwipunku sięgają ±196 px od centrum.
const COL_LEFT := 218
const COL_CENTER_MIN := 400
const COL_RIGHT := 456
const BACKPACK_COLS := 6
const BACKPACK_TILE := Vector2(62, 62)
## Stały podział wysokości prawej kolumny: plecak ~62%, szczegóły ~38%.
const RIGHT_BACKPACK_STRETCH := 10.0
const RIGHT_DETAILS_STRETCH := 7.0
const RIGHT_DETAILS_MIN_H := 210
const STAT_VALUE_COLOR := Color(0.92, 0.90, 0.88)
const OVERLAY_COLOR_INVENTORY := Color(0.012, 0.010, 0.008, 0.90)
const OVERLAY_COLOR_SHRINE := Color(0.015, 0.012, 0.010, 0.78)
const UI_ACCENT_GOLD := Color(0.72, 0.62, 0.44)
const SLOT_BORDER_COLOR := Color(0.32, 0.27, 0.21)
const SLOT_BORDER_EMPTY := Color(0.22, 0.19, 0.15)
const SLOT_BORDER_SELECTED := Color(0.48, 0.42, 0.34)

func _ready() -> void:
	if ResourceLoader.exists("res://MedievalSharp-Bold.ttf"):
		_font = load("res://MedievalSharp-Bold.ttf")
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_purge_legacy_scene_nodes()
	_build_ui()
	_clear_selection()
	visible = false


func _purge_legacy_scene_nodes() -> void:
	for node_name in ["MainPanel", "TempBG", "BG"]:
		var legacy := get_node_or_null(node_name)
		if legacy:
			legacy.free()

func _process(_delta: float) -> void:
	if not visible:
		return
	var shift_now := Input.is_key_pressed(KEY_SHIFT)
	if shift_now != _shift_compare_active:
		_shift_compare_active = shift_now
		if not _hovered_item.is_empty():
			_show_item_details(_hovered_item, _hovered_slot, true, _hovered_idx)
		elif selected_idx >= 0 and not selected_item.is_empty():
			_show_item_details(selected_item, selected_slot, false, selected_idx)
	if _dragging and _drag_preview:
		_drag_preview.size = Vector2(90, 30)
		_drag_preview.global_position = get_global_mouse_position() + Vector2(12, 12)

func _build_ui() -> void:
	_overlay = ColorRect.new()
	_overlay.color = OVERLAY_COLOR_INVENTORY
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	var shell := Control.new()
	shell.custom_minimum_size = Vector2(PANEL_SIZE)
	shell.set_anchors_preset(Control.PRESET_CENTER)
	shell.offset_left = -PANEL_SIZE.x * 0.5
	shell.offset_right = PANEL_SIZE.x * 0.5
	shell.offset_top = -PANEL_SIZE.y * 0.5
	shell.offset_bottom = PANEL_SIZE.y * 0.5
	shell.clip_contents = true
	add_child(shell)

	var outer := PanelContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.clip_contents = true
	outer.add_theme_stylebox_override("panel", FantasyUiAssets.shell_border())
	shell.add_child(outer)

	var inset := MarginContainer.new()
	inset.set_anchors_preset(Control.PRESET_FULL_RECT)
	inset.add_theme_constant_override("margin_left", 12)
	inset.add_theme_constant_override("margin_right", 12)
	inset.add_theme_constant_override("margin_top", 12)
	inset.add_theme_constant_override("margin_bottom", 12)
	outer.add_child(inset)

	var inner := PanelContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.clip_contents = true
	inner.add_theme_stylebox_override("panel", FantasyUiAssets.shell_fill())
	inset.add_child(inner)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 6)
	inner.add_child(root_vbox)

	var header := PanelContainer.new()
	header.add_theme_stylebox_override("panel", FantasyUiAssets.title_panel_loose())
	root_vbox.add_child(header)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 10)
	header.add_child(header_row)

	var title := _make_label("INVENTORY", 24, UI_ACCENT_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title)
	_screen_title = title

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(32, 32)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(_on_close)
	_style_close_btn(close_btn)
	header_row.add_child(close_btn)

	root_vbox.add_child(_make_gold_rule())

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.clip_contents = true
	root_vbox.add_child(content)

	_build_left_panel(content)
	_build_center_panel(content)
	_build_right_panel(content)

func _build_left_panel(parent: HBoxContainer) -> void:
	var col := Control.new()
	col.custom_minimum_size = Vector2(COL_LEFT, 0)
	col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.clip_contents = true
	parent.add_child(col)

	var section := PanelContainer.new()
	section.set_anchors_preset(Control.PRESET_FULL_RECT)
	section.clip_contents = true
	section.add_theme_stylebox_override("panel", FantasyUiAssets.section_box_loose())
	col.add_child(section)

	var pad := MarginContainer.new()
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_left", 6)
	pad.add_theme_constant_override("margin_right", 6)
	pad.add_theme_constant_override("margin_top", 4)
	pad.add_theme_constant_override("margin_bottom", 6)
	section.add_child(pad)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pad.add_child(vbox)
	_left_panel = vbox

	var title := _make_label("STATISTICS", 15, UI_ACCENT_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	vbox.add_child(_make_hsep())

	# Dodaj nowe statystyki tutaj w przyszlosci
	var stat_defs := [
		["str",  "Strength", Color(0.95, 0.55, 0.35)],
		["agi",  "Agility",  Color(0.35, 0.95, 0.55)],
		["vit",  "Vitality", Color(0.35, 0.65, 0.95)],
		["crit", "Crit",     Color(0.95, 0.85, 0.25)],
	]
	for def in stat_defs:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		vbox.add_child(row)
		var lbl_name := _make_label(str(def[1]) + ":", 15, Color(0.72, 0.70, 0.66))
		lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl_name)
		var lbl_val := _make_label("0", 15, STAT_VALUE_COLOR)
		lbl_val.custom_minimum_size = Vector2(40, 0)
		lbl_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(lbl_val)
		var plus_btn := Button.new()
		plus_btn.text = "+"
		plus_btn.custom_minimum_size = Vector2(22, 22)
		plus_btn.focus_mode = Control.FOCUS_NONE
		plus_btn.add_theme_font_size_override("font_size", 14)
		if _font: plus_btn.add_theme_font_override("font", _font)
		var captured_key := str(def[0])
		plus_btn.pressed.connect(func():
			if int(player_stats.get("stat_points", 0)) > 0:
				if GameAudio:
					GameAudio.play_menu_click()
				stat_spent.emit(captured_key)
		)
		_style_small_btn(plus_btn, def[2] as Color)
		row.add_child(plus_btn)
		_stats_labels[str(def[0])] = lbl_val
		_stats_plus_buttons[str(def[0])] = plus_btn
		vbox.add_child(_make_hsep())

	# Stat points
	var sp_row := HBoxContainer.new()
	sp_row.add_theme_constant_override("separation", 6)
	vbox.add_child(sp_row)
	var sp_lbl := _make_label("Stat Points:", 15, Color(0.72, 0.70, 0.66))
	sp_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp_row.add_child(sp_lbl)
	var sp_val := _make_label("0", 15, UI_ACCENT_GOLD)
	sp_row.add_child(sp_val)
	_stats_labels["stat_points"] = sp_val

	vbox.add_child(_make_hsep())
	var hp_row := HBoxContainer.new()
	vbox.add_child(hp_row)
	var hp_lbl := _make_label("HP:", 15, Color(0.72, 0.70, 0.66))
	hp_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_row.add_child(hp_lbl)
	var hp_val := _make_label("0 / 0", 15, Color(0.95, 0.35, 0.35))
	hp_row.add_child(hp_val)
	_stats_labels["hp"] = hp_val

	vbox.add_child(_make_hsep())
	var armor_row := HBoxContainer.new()
	vbox.add_child(armor_row)
	var armor_lbl := _make_label("Total Armor:", 15, Color(0.72, 0.70, 0.66))
	armor_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	armor_row.add_child(armor_lbl)
	var armor_val := _make_label("0", 15, Color(0.65, 0.85, 1.0))
	armor_row.add_child(armor_val)
	_stats_labels["total_armor"] = armor_val

	var dmg_row := HBoxContainer.new()
	vbox.add_child(dmg_row)
	var dmg_lbl := _make_label("Total DMG:", 15, Color(0.72, 0.70, 0.66))
	dmg_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dmg_row.add_child(dmg_lbl)
	var dmg_val := _make_label("0", 15, Color(1.0, 0.75, 0.35))
	dmg_row.add_child(dmg_val)
	_stats_labels["total_dmg"] = dmg_val

	vbox.add_child(_make_hsep())
	_gear_summary_label = _make_label("Armor set: none", 12, Color(0.58, 0.54, 0.46))
	_gear_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_gear_summary_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_gear_summary_label)

func _build_center_panel(parent: HBoxContainer) -> void:
	var area := Control.new()
	area.custom_minimum_size = Vector2(COL_CENTER_MIN, 0)
	area.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	area.clip_contents = true
	parent.add_child(area)
	_center_area = area

	var center_bg := PanelContainer.new()
	center_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_bg.offset_left = 4
	center_bg.offset_right = -4
	center_bg.offset_top = 4
	center_bg.offset_bottom = -4
	center_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_bg.add_theme_stylebox_override("panel", FantasyUiAssets.center_panel())
	area.add_child(center_bg)

	_shrine_bg = TextureRect.new()
	if ResourceLoader.exists(SHRINE_TEX_PATH):
		_shrine_bg.texture = load(SHRINE_TEX_PATH) as Texture2D
	_shrine_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shrine_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_shrine_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shrine_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shrine_bg.visible = false
	area.add_child(_shrine_bg)

	_shrine_drop_slot = PanelContainer.new()
	_shrine_drop_slot.custom_minimum_size = SHRINE_DROP_SLOT_SIZE
	_shrine_drop_slot.set_anchors_preset(Control.PRESET_CENTER)
	_shrine_drop_slot.offset_left = -SHRINE_DROP_SLOT_SIZE.x * 0.5
	_shrine_drop_slot.offset_right = SHRINE_DROP_SLOT_SIZE.x * 0.5
	_shrine_drop_slot.offset_top = -SHRINE_DROP_SLOT_SIZE.y * 0.5
	_shrine_drop_slot.offset_bottom = SHRINE_DROP_SLOT_SIZE.y * 0.5
	_shrine_drop_slot.visible = false
	_set_panel_border(_shrine_drop_slot, UI_ACCENT_GOLD)
	area.add_child(_shrine_drop_slot)

	var shrine_vbox := VBoxContainer.new()
	shrine_vbox.add_theme_constant_override("separation", 6)
	shrine_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_shrine_drop_slot.add_child(shrine_vbox)
	_shrine_slot_content = shrine_vbox

	_shrine_hint_label = _make_label("Drag item here\nto sanctify", 12, Color(0.95, 0.88, 0.55))
	_shrine_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shrine_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_shrine_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_shrine_slot_content.add_child(_shrine_hint_label)

	var char_tex := TextureRect.new()
	char_tex.name = "CharSprite"
	char_tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	char_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	char_tex.set_anchors_preset(Control.PRESET_CENTER)
	char_tex.offset_left   = -75
	char_tex.offset_right  =  75
	char_tex.offset_top    = -100
	char_tex.offset_bottom =  100
	area.add_child(char_tex)
	_char_sprite = char_tex
	_sync_char_portrait()

	for slot_key in SLOT_CONFIG:
		var cfg: Dictionary = SLOT_CONFIG[slot_key]
		var slot_panel := _build_slot_panel(slot_key, str(cfg["label"]))
		slot_panel.set_anchors_preset(Control.PRESET_CENTER)
		var pos: Vector2 = cfg["pos"] as Vector2
		slot_panel.offset_left   = pos.x - SLOT_SIZE.x / 2.0
		slot_panel.offset_right  = pos.x + SLOT_SIZE.x / 2.0
		slot_panel.offset_top    = pos.y - SLOT_SIZE.y / 2.0
		slot_panel.offset_bottom = pos.y + SLOT_SIZE.y / 2.0
		area.add_child(slot_panel)
		_slot_panels[slot_key] = slot_panel

func _build_slot_panel(slot_key: String, label_text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = SLOT_SIZE
	panel.clip_contents = true
	_set_panel_border(panel, SLOT_BORDER_COLOR)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)
	var lbl := _make_label(label_text, 10, Color(0.68, 0.62, 0.5))
	lbl.name = "SlotLabel"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(lbl)
	return panel

func _build_right_panel(parent: HBoxContainer) -> void:
	var col := Control.new()
	col.custom_minimum_size = Vector2(COL_RIGHT, 0)
	col.size_flags_horizontal = Control.SIZE_SHRINK_END
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.clip_contents = true
	parent.add_child(col)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer_vbox.add_theme_constant_override("separation", 6)
	outer_vbox.clip_contents = true
	col.add_child(outer_vbox)

	var grid_section := PanelContainer.new()
	grid_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_section.size_flags_stretch_ratio = RIGHT_BACKPACK_STRETCH
	grid_section.clip_contents = true
	grid_section.add_theme_stylebox_override("panel", FantasyUiAssets.section_box_compact())
	outer_vbox.add_child(grid_section)

	var grid_pad := MarginContainer.new()
	grid_pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_pad.add_theme_constant_override("margin_left", 0)
	grid_pad.add_theme_constant_override("margin_right", 0)
	grid_pad.add_theme_constant_override("margin_top", 0)
	grid_pad.add_theme_constant_override("margin_bottom", 0)
	grid_section.add_child(grid_pad)

	var grid_vbox := VBoxContainer.new()
	grid_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_vbox.add_theme_constant_override("separation", 2)
	grid_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	grid_pad.add_child(grid_vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	header.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	grid_vbox.add_child(header)
	var bp_title := _make_label("BACKPACK", 14, UI_ACCENT_GOLD)
	bp_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(bp_title)
	_backpack_title = bp_title

	for sort_label in ["All", "Type", "Rarity"]:
		var captured_label: String = sort_label
		var btn := Button.new()
		btn.text = sort_label
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(52, 24)
		btn.add_theme_font_size_override("font_size", 12)
		if _font:
			btn.add_theme_font_override("font", _font)
		btn.pressed.connect(func():
			match captured_label:
				"All":    _sort_mode = SortMode.NONE
				"Type":   _sort_mode = SortMode.TYPE
				"Rarity": _sort_mode = SortMode.RARITY
			_refresh_backpack()
		)
		_style_small_btn(btn, UI_ACCENT_GOLD)
		header.add_child(btn)

	_backpack_scroll = ScrollContainer.new()
	_backpack_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_backpack_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_backpack_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_backpack_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_style_backpack_scroll(_backpack_scroll)
	grid_vbox.add_child(_backpack_scroll)

	_item_grid = GridContainer.new()
	_item_grid.columns = BACKPACK_COLS
	_item_grid.add_theme_constant_override("h_separation", 4)
	_item_grid.add_theme_constant_override("v_separation", 4)
	_item_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_backpack_scroll.add_child(_item_grid)

	var details := PanelContainer.new()
	details.custom_minimum_size = Vector2(0, RIGHT_DETAILS_MIN_H)
	details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.size_flags_stretch_ratio = RIGHT_DETAILS_STRETCH
	details.clip_contents = true
	details.add_theme_stylebox_override("panel", FantasyUiAssets.section_box_compact())
	outer_vbox.add_child(details)
	_details_panel = details

	var det_pad := MarginContainer.new()
	det_pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	det_pad.add_theme_constant_override("margin_left", 0)
	det_pad.add_theme_constant_override("margin_right", 0)
	det_pad.add_theme_constant_override("margin_top", 0)
	det_pad.add_theme_constant_override("margin_bottom", 0)
	details.add_child(det_pad)

	var det_vbox := VBoxContainer.new()
	det_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	det_vbox.add_theme_constant_override("separation", 2)
	det_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	det_pad.add_child(det_vbox)

	_item_name = _make_label("[Select an item]", 14, Color(0.90, 0.88, 0.85))
	_item_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_item_name.max_lines_visible = 1
	_item_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	_item_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_name.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	det_vbox.add_child(_item_name)

	_item_stats = RichTextLabel.new()
	_item_stats.bbcode_enabled = true
	_item_stats.fit_content = false
	_item_stats.scroll_active = true
	_item_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_item_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_stats.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_item_stats.size_flags_stretch_ratio = 1.0
	_item_stats.add_theme_font_size_override("normal_font_size", 12)
	_item_stats.add_theme_color_override("default_color", Color(0.78, 0.75, 0.70))
	if _font:
		_item_stats.add_theme_font_override("normal_font", _font)
	det_vbox.add_child(_item_stats)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)
	btn_row.size_flags_vertical = Control.SIZE_SHRINK_END
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	det_vbox.add_child(btn_row)

	_equip_btn = Button.new()
	_equip_btn.text = "EQUIP"
	_equip_btn.custom_minimum_size = Vector2(88, 26)
	_equip_btn.focus_mode = Control.FOCUS_NONE
	_equip_btn.pressed.connect(_on_equip)
	_style_action_btn(_equip_btn, Color(0.95, 0.82, 0.30))
	btn_row.add_child(_equip_btn)

	_drop_btn = Button.new()
	_drop_btn.text = "DROP"
	_drop_btn.custom_minimum_size = Vector2(88, 26)
	_drop_btn.focus_mode = Control.FOCUS_NONE
	_drop_btn.pressed.connect(_on_drop)
	_style_action_btn(_drop_btn, Color(0.75, 0.25, 0.20))
	btn_row.add_child(_drop_btn)

	_shrine_btn_row = HBoxContainer.new()
	_shrine_btn_row.add_theme_constant_override("separation", 10)
	_shrine_btn_row.visible = false
	_shrine_btn_row.size_flags_vertical = Control.SIZE_SHRINK_END
	det_vbox.add_child(_shrine_btn_row)

	_shrine_confirm_btn = Button.new()
	_shrine_confirm_btn.text = "MAKE PERMANENT"
	_shrine_confirm_btn.custom_minimum_size = Vector2(160, 32)
	_shrine_confirm_btn.focus_mode = Control.FOCUS_NONE
	_shrine_confirm_btn.pressed.connect(_on_shrine_confirm_pressed)
	_style_action_btn(_shrine_confirm_btn, Color(0.55, 0.90, 0.45))
	_shrine_btn_row.add_child(_shrine_confirm_btn)

	_shrine_cancel_btn = Button.new()
	_shrine_cancel_btn.text = "REMOVE"
	_shrine_cancel_btn.custom_minimum_size = Vector2(110, 32)
	_shrine_cancel_btn.focus_mode = Control.FOCUS_NONE
	_shrine_cancel_btn.pressed.connect(_clear_shrine_offer)
	_style_action_btn(_shrine_cancel_btn, Color(0.75, 0.25, 0.20))
	_shrine_btn_row.add_child(_shrine_cancel_btn)

func open(inv: Dictionary, eq: Dictionary, stats: Dictionary) -> void:
	home_mode = false
	shrine_mode = false
	_apply_mode_ui()
	inventory    = inv
	equipped     = eq
	_sync_equipped_armor_types()
	player_stats = stats
	_sync_char_portrait()
	_refresh_stats()
	_refresh_all_slots()
	_refresh_backpack()
	_clear_selection()
	visible = true
	_play_inventory_flap_sfx()
	move_to_front()


func open_shrine(inv: Dictionary, eq: Dictionary, stats: Dictionary) -> void:
	home_mode = false
	shrine_mode = true
	inventory = inv
	equipped = eq
	_sync_equipped_armor_types()
	player_stats = stats
	_clear_shrine_offer()
	_apply_mode_ui()
	_sync_char_portrait()
	_refresh_stats()
	_refresh_all_slots()
	_refresh_backpack()
	_clear_selection()
	visible = true
	_play_inventory_flap_sfx()
	move_to_front()


func open_home_loadout() -> void:
	home_mode = true
	shrine_mode = false
	_apply_mode_ui()
	_reload_home_data()
	_sync_equipped_armor_types()
	player_stats = _build_home_player_stats()
	_sync_char_portrait()
	_refresh_stats()
	_refresh_all_slots()
	_refresh_backpack()
	_clear_selection()
	visible = true
	_play_inventory_flap_sfx()
	move_to_front()


func _play_inventory_flap_sfx() -> void:
	if GameAudio:
		GameAudio.play_inventory_flap()


func _apply_mode_ui() -> void:
	if _screen_title:
		if shrine_mode:
			_screen_title.text = "SACRED SHRINE"
		elif home_mode:
			_screen_title.text = "LOADOUT"
		else:
			_screen_title.text = "INVENTORY"
	if _backpack_title:
		if shrine_mode:
			_backpack_title.text = "YOUR ITEMS"
		elif home_mode:
			_backpack_title.text = "PERMANENT STORAGE"
		else:
			_backpack_title.text = "BACKPACK"
	if _overlay:
		_overlay.color = OVERLAY_COLOR_SHRINE if shrine_mode else OVERLAY_COLOR_INVENTORY
	if _left_panel:
		_left_panel.visible = not shrine_mode
	for key in _stats_plus_buttons:
		var btn: Button = _stats_plus_buttons[key]
		if btn:
			btn.visible = not home_mode and not shrine_mode
	if _equip_btn:
		_equip_btn.text = "TAKE" if home_mode else "EQUIP"
		_equip_btn.visible = not shrine_mode
	if _drop_btn:
		_drop_btn.visible = not shrine_mode
	if _shrine_btn_row:
		_shrine_btn_row.visible = shrine_mode and _shrine_pending_idx >= 0
	_apply_center_mode_visibility()


func _apply_center_mode_visibility() -> void:
	var show_gear := not shrine_mode
	if _char_sprite and is_instance_valid(_char_sprite):
		_char_sprite.visible = show_gear
	for slot_key in _slot_panels:
		var panel: PanelContainer = _slot_panels[slot_key]
		if panel and is_instance_valid(panel):
			panel.visible = show_gear
	if _shrine_bg and is_instance_valid(_shrine_bg):
		_shrine_bg.visible = shrine_mode
	if _shrine_drop_slot and is_instance_valid(_shrine_drop_slot):
		_shrine_drop_slot.visible = shrine_mode


func _build_home_player_stats() -> Dictionary:
	var pd: Dictionary = GameState.meta.get("player", {})
	var cls: String = String(GameState.meta.get("chosen_class", ""))
	return {
		"str": int(pd.get("strength", 1)),
		"agi": int(pd.get("agility", 1)),
		"vit": int(pd.get("vitality", 0)),
		"crit": int(pd.get("crit", 0)),
		"stat_points": 0,
		"hp": int(pd.get("hp", pd.get("max_hp", 100))),
		"max_hp": int(pd.get("max_hp", 100)),
		"chosen_class": cls,
		"passive_armor_bonus": 0,
	}


func _reload_home_data() -> void:
	GameState.ensure_save_equipment_shape()
	inventory = GameState.duplicate_equipment_buckets(GameState.meta["permanent_chest"])
	equipped = GameState.loadout_as_equipped_dict()


func _sync_equipped_armor_types() -> void:
	for slot_key in ArmorSetRules.SET_SLOTS:
		var it: Dictionary = equipped.get(slot_key, {})
		ArmorSetRules.ensure_armor_type(it)


func _home_equip_item(slot_key: String, idx: int) -> void:
	var arr: Array = inventory.get(slot_key, [])
	if idx < 0 or idx >= arr.size():
		return
	var item: Dictionary = arr[idx].duplicate(true)
	ArmorSetRules.ensure_armor_type(item)
	item["permanent"] = true

	var old_eq: Dictionary = equipped.get(slot_key, {})
	if not old_eq.is_empty():
		var old_copy: Dictionary = old_eq.duplicate(true)
		old_copy["permanent"] = true
		GameState.meta["permanent_chest"][slot_key].append(old_copy)

	GameState.remove_all_items_by_name_from_bucket(
		GameState.meta["permanent_chest"][slot_key],
		String(item.get("name", ""))
	)
	GameState.run["loadout"][slot_key] = [item.duplicate(true)]
	equipped[slot_key] = item
	_reload_home_data()
	if GameAudio:
		GameAudio.play_item_equip()
	loadout_changed.emit()


func _home_unequip_item(slot_key: String) -> void:
	var item: Dictionary = equipped.get(slot_key, {})
	if item.is_empty():
		return
	var copy: Dictionary = item.duplicate(true)
	copy["permanent"] = true
	GameState.meta["permanent_chest"][slot_key].append(copy)
	GameState.run["loadout"][slot_key] = []
	equipped[slot_key] = {}
	_reload_home_data()
	loadout_changed.emit()

func _on_close() -> void:
	_play_inventory_flap_sfx()
	var was_shrine := shrine_mode
	visible = false
	if shrine_mode:
		shrine_mode = false
	if home_mode:
		home_mode = false
	_apply_mode_ui()
	_clear_shrine_offer()
	closed.emit()
	if was_shrine:
		shrine_closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if shrine_mode:
		if event.is_action_pressed("ui_cancel"):
			_on_close()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("toggle_inventory") or event.is_action_pressed("ui_cancel"):
		_on_close()
		get_viewport().set_input_as_handled()

func _refresh_stats() -> void:
	var home_gear := _equipment_primary_bonus_totals() if home_mode else {}
	for key in _stats_labels:
		var lbl: Label = _stats_labels[key]
		if key == "hp":
			var max_hp := int(player_stats.get("max_hp", 0))
			if home_mode:
				var helm: Dictionary = equipped.get("helmet", {})
				if not helm.is_empty():
					max_hp += int(helm.get("hp_bonus", 0))
			lbl.text = "%d / %d" % [int(player_stats.get("hp", 0)), max_hp]
		elif key == "total_armor":
			lbl.text = str(_calc_total_armor())
		elif key == "total_dmg":
			lbl.text = str(_calc_total_dmg())
		elif key in ["str", "agi", "vit", "crit"]:
			var val := int(player_stats.get(key, 0))
			if home_mode:
				val += int(home_gear.get(key, 0))
			lbl.text = str(val)
		else:
			lbl.text = str(int(player_stats.get(key, 0)))
	var has_points := int(player_stats.get("stat_points", 0)) > 0
	for key in _stats_plus_buttons:
		var btn: Button = _stats_plus_buttons[key]
		btn.disabled = not has_points
	if _gear_summary_label:
		_gear_summary_label.text = _build_gear_summary_text()


func _build_gear_summary_text() -> String:
	return ArmorSetRules.build_summary(equipped)


func _calc_total_armor() -> int:
	var base := 0
	var armor_item: Dictionary = equipped.get("armor", {})
	if not armor_item.is_empty():
		base = int(armor_item.get("armor", 0))
	var bonus := ArmorSetRules.armor_set_bonus(ArmorSetRules.type_counts(equipped))
	var extra_armor := int(player_stats.get("passive_armor_bonus", 0))
	return clamp(base + bonus + extra_armor, 0, 15)


func _flat_weapon_dmg_from_armor_pieces() -> int:
	var counts := ArmorSetRules.type_counts(equipped)
	var total := ArmorSetRules.berserker_set_dmg_bonus(counts)
	for slot_key in ArmorSetRules.SET_SLOTS:
		var it: Dictionary = equipped.get(slot_key, {})
		if it.is_empty():
			continue
		var b: Dictionary = it.get("bonuses", {})
		total += int(b.get("weapon_dmg", 0))
	return total


func _equipment_primary_bonus_totals() -> Dictionary:
	var acc := {"str": 0, "agi": 0, "vit": 0, "crit": 0}
	for slot_key in SLOT_CONFIG.keys():
		var it: Dictionary = equipped.get(slot_key, {})
		if it.is_empty():
			continue
		var totals := _item_bonus_totals(it, slot_key)
		for k in acc.keys():
			acc[k] = int(acc[k]) + int(totals.get(k, 0))
	return acc


func _calc_total_dmg() -> int:
	var w: Dictionary = equipped.get("weapon", {})
	if w.is_empty():
		return 0
	var base: int = int(w.get("base", 0))
	var bdict: Dictionary = w.get("bonuses", {})
	base += int(bdict.get("weapon_dmg", 0))
	base += _flat_weapon_dmg_from_armor_pieces()
	var sc: Dictionary = w.get("scale", {})
	var mult := 1.0
	mult += float(int(player_stats.get("str", 0))) * STR_DMG_PER_POINT * float(sc.get("str", 0.0))
	mult += float(int(player_stats.get("agi", 0))) * AGI_DMG_PER_POINT * float(sc.get("agi", 0.0))
	if String(player_stats.get("chosen_class", "")) == "warrior":
		mult *= 1.10
	return max(1, int(round(float(base) * mult)))

func _refresh_all_slots() -> void:
	for slot_key in _slot_panels:
		_refresh_slot(slot_key)


func _pin_slot_geometry(panel: PanelContainer, pos: Vector2) -> void:
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = pos.x - SLOT_SIZE.x * 0.5
	panel.offset_right = pos.x + SLOT_SIZE.x * 0.5
	panel.offset_top = pos.y - SLOT_SIZE.y * 0.5
	panel.offset_bottom = pos.y + SLOT_SIZE.y * 0.5


func _refresh_slot(slot_key: String) -> void:
	var panel: PanelContainer = _slot_panels.get(slot_key)
	if not panel: return
	var cfg: Dictionary = SLOT_CONFIG.get(slot_key, {})
	_pin_slot_geometry(panel, cfg.get("pos", Vector2.ZERO) as Vector2)
	panel.clip_contents = true
	panel.custom_minimum_size = SLOT_SIZE
	panel.size = SLOT_SIZE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for c in panel.get_children():
		c.queue_free()
	var item: Dictionary = equipped.get(slot_key, {})
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 2
	vbox.offset_right = -2
	vbox.offset_top = 2
	vbox.offset_bottom = -2
	panel.add_child(vbox)

	if item.is_empty():
		_set_panel_border(panel, SLOT_BORDER_EMPTY)
		var lbl := _make_label(str(cfg.get("label", slot_key)), 10, Color(0.38, 0.36, 0.32))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(lbl)
	else:
		var r: int     = clamp(int(item.get("rarity", 0)), 0, RARITY_COLORS.size() - 1)
		var col: Color = RARITY_COLORS[r]
		_set_panel_border(panel, col)
		var tex: Texture2D = _resolve_icon(item)
		if tex:
			var tr := TextureRect.new()
			tr.texture = tex
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.custom_minimum_size = Vector2(40, 40)
			tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			tr.size_flags_vertical = Control.SIZE_EXPAND_FILL
			vbox.add_child(tr)
		else:
			var short_name := str(item.get("name", "?"))
			if short_name.length() > 7:
				short_name = short_name.substr(0, 7) + "."
			var name_lbl := _make_label(short_name, 8, col)
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			name_lbl.clip_text = true
			name_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
			vbox.add_child(name_lbl)
		var hover_btn := Button.new()
		hover_btn.flat = true
		hover_btn.focus_mode = Control.FOCUS_NONE
		hover_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		hover_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		hover_btn.mouse_entered.connect(func():
			_hovered_item = item.duplicate(true)
			_hovered_slot = slot_key
			_hovered_idx = -1
			_show_item_details(item, slot_key, true, -1)
		)
		hover_btn.mouse_exited.connect(func():
			if _hovered_slot == slot_key:
				_hovered_item = {}
				_hovered_slot = ""
				_hovered_idx = -1
				if selected_idx >= 0:
					_show_item_details(selected_item, selected_slot, false, selected_idx)
				else:
					_clear_selection()
		)
		hover_btn.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton:
				var mb := event as InputEventMouseButton
				if mb.button_index == MOUSE_BUTTON_LEFT:
					if mb.pressed:
						_start_drag_item(item, slot_key, -1, col, "equipped")
					else:
						_finish_drag_item()
		)
		panel.add_child(hover_btn)

func _refresh_backpack() -> void:
	for c in _item_grid.get_children():
		c.queue_free()

	var all_items: Array = []
	for slot_key in ["weapon", "armor", "helmet", "necklace", "gloves", "boots", "ring1", "ring2"]:
		var arr: Array = inventory.get(slot_key, [])
		for i in arr.size():
			var item: Dictionary = arr[i]
			var eq_item: Dictionary = equipped.get(slot_key, {})
			if not shrine_mode and not eq_item.is_empty() and eq_item.get("name", "") == item.get("name", ""):
				continue
			all_items.append({"item": item, "slot": slot_key, "idx": i})

	match _sort_mode:
		SortMode.TYPE:
			all_items.sort_custom(func(a, b): return str(a["slot"]) < str(b["slot"]))
		SortMode.RARITY:
			all_items.sort_custom(func(a, b): return int(a["item"].get("rarity", 0)) > int(b["item"].get("rarity", 0)))

	if all_items.is_empty():
		var empty_msg := "No items to sanctify." if shrine_mode else ("No permanent items stored." if home_mode else "Backpack is empty.")
		_item_grid.add_child(_make_label(empty_msg, 15, Color(0.58, 0.54, 0.46)))
		return

	for entry in all_items:
		var item: Dictionary    = entry["item"]
		var slot_key: String    = entry["slot"]
		var idx: int            = entry["idx"]
		var r: int              = clamp(int(item.get("rarity", 0)), 0, RARITY_COLORS.size() - 1)
		var col: Color          = RARITY_COLORS[r]

		var tile := PanelContainer.new()
		tile.custom_minimum_size = BACKPACK_TILE
		tile.size = BACKPACK_TILE
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_set_panel_border(tile, col)
		tile.mouse_filter = Control.MOUSE_FILTER_STOP

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 2)
		tile.add_child(vbox)

		var tex: Texture2D = _resolve_icon(item)
		if tex:
			var tr := TextureRect.new()
			tr.texture = tex
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.custom_minimum_size = Vector2(34, 34)
			tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			vbox.add_child(tr)

		var full_name: String = str(item.get("name", "?"))
		var short_name: String = full_name.substr(0, 8) + ("..." if full_name.length() > 8 else "")
		var name_lbl := _make_label(short_name, 9, col)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(name_lbl)

		if bool(item.get("permanent", false)):
			var perm := _make_label("*", 11, Color(0.55, 0.90, 0.45))
			perm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(perm)

		if shrine_mode and bool(item.get("permanent", false)):
			tile.modulate = Color(0.55, 0.55, 0.55, 0.65)

		var captured_item: Dictionary = item.duplicate(true)
		var captured_slot: String     = slot_key
		var captured_idx: int         = idx
		tile.mouse_entered.connect(func():
			_hovered_item = captured_item
			_hovered_slot = captured_slot
			_hovered_idx = captured_idx
			_show_item_details(captured_item, captured_slot, true, captured_idx)
		)
		tile.mouse_exited.connect(func():
			if _hovered_idx == captured_idx and _hovered_slot == captured_slot:
				_hovered_item = {}
				_hovered_slot = ""
				_hovered_idx = -1
				if _showing_hover_details:
					if selected_idx >= 0:
						_show_item_details(selected_item, selected_slot, false, selected_idx)
					else:
						_clear_selection()
		)
		tile.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton:
				var mb := event as InputEventMouseButton
				if mb.button_index == MOUSE_BUTTON_LEFT:
					if mb.pressed:
						_start_drag_item(captured_item, captured_slot, captured_idx, col, "backpack")
					else:
						_finish_drag_item()
		)
		var btn := Button.new()
		btn.flat = true
		btn.mouse_filter = Control.MOUSE_FILTER_PASS
		btn.focus_mode = Control.FOCUS_NONE
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.pressed.connect(func(): _select_item(captured_item, captured_slot, captured_idx, tile))
		tile.add_child(btn)
		_item_grid.add_child(tile)


func _select_item(item: Dictionary, slot_key: String, idx: int, tile: PanelContainer) -> void:
	if _selected_tile and is_instance_valid(_selected_tile):
		var prev_r: int = clamp(int(selected_item.get("rarity", 0)), 0, RARITY_COLORS.size() - 1)
		_set_panel_border(_selected_tile as PanelContainer, RARITY_COLORS[prev_r])
	selected_item  = item
	selected_slot  = slot_key
	selected_idx   = idx
	_selected_tile = tile
	_set_panel_border(tile, SLOT_BORDER_SELECTED)

	_show_item_details(item, slot_key, false, idx)
	if shrine_mode:
		_equip_btn.visible = false
		_drop_btn.visible = false
	else:
		_equip_btn.visible = true
		_drop_btn.visible = false if home_mode else not bool(item.get("permanent", false))

func _clear_selection() -> void:
	selected_item  = {}
	selected_slot  = ""
	selected_idx   = -1
	_selected_tile = null
	if _item_name:  _item_name.text  = "[Select an item]"
	if _item_stats: _item_stats.text = ""
	if _equip_btn:  _equip_btn.visible = false
	if _drop_btn:   _drop_btn.visible  = false
	_showing_hover_details = false

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not _dragging:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_finish_drag_item()

func _on_equip() -> void:
	if selected_idx < 0:
		return
	if home_mode:
		_home_equip_item(selected_slot, selected_idx)
		_clear_selection()
		_refresh_stats()
		_refresh_all_slots()
		_refresh_backpack()
		return
	item_equipped.emit(selected_slot, selected_idx)
	_clear_selection()
	_refresh_backpack()


func _on_drop() -> void:
	if home_mode:
		return
	if selected_idx >= 0 and not bool(selected_item.get("permanent", false)):
		item_dropped.emit(selected_slot, selected_idx)
		_clear_selection()
		_refresh_backpack()

func _show_item_details(item: Dictionary, slot_key: String, from_hover: bool, idx: int = -1) -> void:
	var r: int = clamp(int(item.get("rarity", 0)), 0, RARITY_COLORS.size() - 1)
	_item_name.text = "%s  [%s]" % [str(item.get("name", "?")), RARITY_NAMES[r]]
	_item_name.add_theme_color_override("font_color", RARITY_COLORS[r])
	var lines := _build_item_description(item, slot_key)
	if _shift_compare_active or Input.is_key_pressed(KEY_SHIFT):
		var cmp_slot := _compare_slot_for_item(item, slot_key)
		var eq_item: Dictionary = equipped.get(cmp_slot, {})
		if not eq_item.is_empty():
			lines += "\n\n[b]COMPARE[/b] (vs %s)\n%s" % [cmp_slot.capitalize(), _build_compare_block(item, eq_item, cmp_slot)]
		else:
			lines += "\n\n[b]COMPARE[/b]\nNo equipped item in this slot."
	else:
		lines += "\n[font_size=11][color=#6A6258](Shift — compare with equipped)[/color][/font_size]"
	_item_stats.text = lines
	if _item_stats:
		_item_stats.scroll_to_line(0)
	_showing_hover_details = from_hover and idx != selected_idx


func _compare_slot_for_item(item: Dictionary, slot_key: String) -> String:
	var item_type := str(item.get("type", slot_key))
	if item_type in SLOT_CONFIG:
		return item_type
	return slot_key


func _bonus_weapon_dmg_from_item(item: Dictionary) -> int:
	return int(item.get("bonuses", {}).get("weapon_dmg", 0))


func _append_item_bonus_lines(lines: String, totals: Dictionary) -> String:
	for key in ["str", "agi", "vit", "crit"]:
		var v := int(totals.get(key, 0))
		if v != 0:
			lines += "\nBonus: %+d %s" % [v, key.to_upper()]
	var wdmg := int(totals.get("weapon_dmg", 0))
	if wdmg != 0:
		lines += "\nFlat DMG: %+d" % wdmg
	return lines


func _item_bonus_totals(item: Dictionary, slot_key: String) -> Dictionary:
	var totals: Dictionary = {}
	var bonuses: Dictionary = item.get("bonuses", {})
	if not bonuses.is_empty():
		for k in bonuses.keys():
			totals[String(k)] = int(bonuses.get(k, 0))
	var bonus_stat: String = str(item.get("bonus_stat", ""))
	var bonus_value: int = int(item.get("bonus_value", 0))
	var bonus_stat2: String = str(item.get("bonus_stat2", ""))
	var bonus_value2: int = int(item.get("bonus_value2", 0))
	if bonus_stat != "" and bonus_value != 0 and slot_key != "necklace":
		var k1 := bonus_stat.to_lower()
		totals[k1] = int(totals.get(k1, 0)) + bonus_value
	if bonus_stat2 != "" and bonus_value2 != 0 and slot_key != "necklace":
		var k2 := bonus_stat2.to_lower()
		totals[k2] = int(totals.get(k2, 0)) + bonus_value2
	return totals


func _build_item_description(item: Dictionary, slot_key: String) -> String:
	var lines := "Slot: %s" % slot_key.capitalize()
	var armor_type := ArmorSetRules.infer_armor_type(item)
	match slot_key:
		"weapon":
			lines += "\nDMG base: %d" % int(item.get("base", 0))
			var scale_dict: Dictionary = item.get("scale", {})
			if not scale_dict.is_empty():
				var s := ""
				for k in scale_dict:
					s += "  %s×%.1f" % [k.to_upper(), float(scale_dict[k])]
				lines += "\nScaling:%s" % s
			var bleed_chance := StatusEffectDefs.bleed_base_proc_chance_for_item(item)
			if bleed_chance >= 0.0:
				lines += "\nBleed chance: %d%%" % int(round(bleed_chance * 100.0))
		"armor":
			if item.has("armor"):
				lines += "\nArmor: %d" % int(item.get("armor", 0))
			else:
				lines += "\nDamage Reduction: %.0f%%" % (float(item.get("dr", 0)) * 100)
		"helmet":
			lines += "\nHP Bonus: +%d" % int(item.get("hp_bonus", 0))
		"gloves", "boots":
			if item.has("armor"):
				lines += "\nArmor: %d" % int(item.get("armor", 0))
		"necklace":
			lines += "\nCrit mult: +%.0f%%" % (float(item.get("crit_bonus", 0.0)) * 100.0)
			lines += "\nBonus stat: %s" % str(item.get("bonus_stat", "—")).to_upper()
		"ring1", "ring2":
			lines += "\nSkill: %s" % String(item.get("skill_id", "—"))
	if armor_type != "" and slot_key in ["armor", "helmet", "gloves", "boots"]:
		lines += "\nType: %s" % armor_type.capitalize()
		if armor_type != "berserker":
			lines += "\n(Set bonus: counts toward light/medium/heavy armor)"
		else:
			lines += "\n(Berserker set: +1/+2/+3 flat DMG at 2/3/4 pieces)"
	lines = _append_item_bonus_lines(lines, _item_bonus_totals(item, slot_key))
	if bool(item.get("permanent", false)):
		lines += "\n★ PERMANENT"
	return lines

func _build_compare_block(candidate: Dictionary, equipped_item: Dictionary, slot_key: String) -> String:
	var cmp_lines := "Current: %s" % str(equipped_item.get("name", "—"))
	match slot_key:
		"weapon":
			var cand_base := int(candidate.get("base", 0))
			var eq_base := int(equipped_item.get("base", 0))
			cmp_lines += "\nDMG base: %d (%s)" % [cand_base, _fmt_delta(cand_base - eq_base, false)]
			var cand_scale: Dictionary = candidate.get("scale", {})
			var eq_scale: Dictionary = equipped_item.get("scale", {})
			if not cand_scale.is_empty() or not eq_scale.is_empty():
				cmp_lines += "\nScaling: %s -> %s" % [_fmt_scale_dict(cand_scale), _fmt_scale_dict(eq_scale)]
			var cand_bleed := StatusEffectDefs.bleed_base_proc_chance_for_item(candidate)
			var eq_bleed := StatusEffectDefs.bleed_base_proc_chance_for_item(equipped_item)
			if cand_bleed >= 0.0 or eq_bleed >= 0.0:
				var cand_pct := int(round(cand_bleed * 100.0)) if cand_bleed >= 0.0 else 0
				var eq_pct := int(round(eq_bleed * 100.0)) if eq_bleed >= 0.0 else 0
				cmp_lines += "\nBleed chance: %d%% (%s)" % [cand_pct, _fmt_delta(float(cand_pct - eq_pct), true)]
		"armor":
			if candidate.has("armor") or equipped_item.has("armor"):
				var cand_a := int(candidate.get("armor", 0))
				var eq_a := int(equipped_item.get("armor", 0))
				cmp_lines += "\nArmor: %d (%s)" % [cand_a, _fmt_delta(cand_a - eq_a, false)]
			else:
				var cand_dr := float(candidate.get("dr", 0))
				var eq_dr := float(equipped_item.get("dr", 0))
				cmp_lines += "\nDR: %.0f%% (%s)" % [cand_dr * 100.0, _fmt_delta((cand_dr - eq_dr) * 100.0, true)]
		"helmet":
			var cand_hp := int(candidate.get("hp_bonus", 0))
			var eq_hp := int(equipped_item.get("hp_bonus", 0))
			cmp_lines += "\nHP Bonus: %d (%s)" % [cand_hp, _fmt_delta(cand_hp - eq_hp, false)]
		"necklace":
			var cand_crit := float(candidate.get("crit_bonus", 0.0))
			var eq_crit := float(equipped_item.get("crit_bonus", 0.0))
			cmp_lines += "\nCrit mult: +%.0f%% (%s)" % [
				cand_crit * 100.0,
				_fmt_delta((cand_crit - eq_crit) * 100.0, true)
			]
			cmp_lines += "\nBonus stat: %s -> %s" % [
				str(equipped_item.get("bonus_stat", "—")).to_upper(),
				str(candidate.get("bonus_stat", "—")).to_upper()
			]
		"ring1", "ring2":
			cmp_lines += "\nSkill: %s -> %s" % [
				String(equipped_item.get("skill_id", "—")),
				String(candidate.get("skill_id", "—"))
			]
		"gloves", "boots":
			if candidate.has("armor") or equipped_item.has("armor"):
				var cand_ga := int(candidate.get("armor", 0))
				var eq_ga := int(equipped_item.get("armor", 0))
				cmp_lines += "\nArmor: %d (%s)" % [cand_ga, _fmt_delta(cand_ga - eq_ga, false)]
	var cand_totals := _item_bonus_totals(candidate, slot_key)
	var eq_totals := _item_bonus_totals(equipped_item, slot_key)
	for key in ["str", "agi", "vit", "crit"]:
		var cand_v := int(cand_totals.get(key, 0))
		var eq_v := int(eq_totals.get(key, 0))
		if cand_v != 0 or eq_v != 0:
			cmp_lines += "\n%s: %d (%s)" % [key.to_upper(), cand_v, _fmt_delta(cand_v - eq_v, false)]
	var cand_wd := int(cand_totals.get("weapon_dmg", 0))
	var eq_wd := int(eq_totals.get("weapon_dmg", 0))
	if cand_wd != 0 or eq_wd != 0:
		cmp_lines += "\nFlat DMG: %d (%s)" % [cand_wd, _fmt_delta(cand_wd - eq_wd, false)]
	var cand_type := ArmorSetRules.infer_armor_type(candidate)
	var eq_type := ArmorSetRules.infer_armor_type(equipped_item)
	if cand_type != "" or eq_type != "":
		cmp_lines += "\nType: %s -> %s" % [eq_type.capitalize() if eq_type != "" else "—", cand_type.capitalize() if cand_type != "" else "—"]
	return cmp_lines


func _fmt_scale_dict(scale_dict: Dictionary) -> String:
	if scale_dict.is_empty():
		return "—"
	var parts: PackedStringArray = []
	for k in scale_dict:
		parts.append("%s×%.1f" % [k.to_upper(), float(scale_dict[k])])
	return ", ".join(parts)

func _fmt_delta(delta: float, with_percent: bool) -> String:
	var text := "%+d" % int(delta)
	if with_percent:
		text = "%+.0f%%" % delta
	var col := "#9AA0A6"
	if delta > 0.0:
		col = "#54D17A"
	elif delta < 0.0:
		col = "#E06C75"
	return "[color=%s]%s[/color]" % [col, text]

func _start_drag_item(item: Dictionary, slot_key: String, idx: int, border_col: Color, source: String) -> void:
	if shrine_mode and bool(item.get("permanent", false)):
		return
	_dragging = true
	_drag_item = item.duplicate(true)
	_drag_slot = slot_key
	_drag_idx = idx
	_drag_source = source
	if _drag_preview and is_instance_valid(_drag_preview):
		_drag_preview.queue_free()
	_drag_preview = PanelContainer.new()
	_drag_preview.custom_minimum_size = Vector2(96, 34)
	_drag_preview.size = Vector2(96, 34)
	_drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_preview.z_index = 999
	_set_panel_border(_drag_preview, border_col)
	var preview_name := str(item.get("name", "?"))
	if preview_name.length() > 11:
		preview_name = preview_name.substr(0, 11) + "..."
	var preview_lbl := _make_label(preview_name, 10, border_col)
	preview_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	preview_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_drag_preview.add_child(preview_lbl)
	add_child(_drag_preview)
	_drag_preview.global_position = get_global_mouse_position() + Vector2(12, 12)

func _finish_drag_item() -> void:
	if not _dragging:
		return
	var mouse := get_global_mouse_position()
	if shrine_mode:
		if _drag_source == "backpack" and _is_over_shrine_drop_slot(mouse):
			if not bool(_drag_item.get("permanent", false)):
				_stage_shrine_offer(_drag_slot, _drag_idx)
			elif _item_name:
				_item_name.text = "Already permanent"
		_cleanup_drag()
		return
	var target_slot := _slot_key_from_global_pos(mouse)
	if home_mode:
		if _drag_source == "backpack":
			if target_slot == "" and _is_over_character(mouse):
				target_slot = _drag_slot
			if target_slot != "" and target_slot == _drag_slot:
				_home_equip_item(_drag_slot, _drag_idx)
				_clear_selection()
				_refresh_stats()
				_refresh_all_slots()
				_refresh_backpack()
		elif _drag_source == "equipped":
			if _backpack_scroll and _backpack_scroll.get_global_rect().has_point(mouse):
				_home_unequip_item(_drag_slot)
				_clear_selection()
				_refresh_stats()
				_refresh_all_slots()
				_refresh_backpack()
	else:
		if _drag_source == "backpack":
			# Ułatwienie: drop na postaci = auto-equip do właściwego slota
			if target_slot == "" and _is_over_character(mouse):
				target_slot = _drag_slot
			if target_slot != "" and target_slot == _drag_slot:
				item_equipped.emit(_drag_slot, _drag_idx)
				_clear_selection()
				_refresh_all_slots()
				_refresh_backpack()
		elif _drag_source == "equipped":
			if _backpack_scroll and _backpack_scroll.get_global_rect().has_point(mouse):
				item_unequipped.emit(_drag_slot)
				_clear_selection()
				_refresh_all_slots()
				_refresh_backpack()
				_refresh_all_slots()
				_refresh_backpack()
	_cleanup_drag()

func _cleanup_drag() -> void:
	if _drag_preview and is_instance_valid(_drag_preview):
		_drag_preview.queue_free()
	_drag_preview = null
	_dragging = false
	_drag_item = {}
	_drag_slot = ""
	_drag_idx = -1
	_drag_source = ""

func _is_over_shrine_drop_slot(global_pos: Vector2) -> bool:
	if _shrine_drop_slot == null or not is_instance_valid(_shrine_drop_slot) or not _shrine_drop_slot.visible:
		return false
	return _shrine_drop_slot.get_global_rect().has_point(global_pos)

func _stage_shrine_offer(slot_key: String, idx: int) -> void:
	var arr: Array = inventory.get(slot_key, [])
	if idx < 0 or idx >= arr.size():
		return
	var item: Dictionary = arr[idx]
	if bool(item.get("permanent", false)):
		return
	_shrine_pending_slot = slot_key
	_shrine_pending_idx = idx
	_refresh_shrine_slot_visual(item)
	_show_item_details(item, slot_key, false, idx)
	if _shrine_btn_row:
		_shrine_btn_row.visible = true

func _clear_shrine_offer() -> void:
	_shrine_pending_slot = ""
	_shrine_pending_idx = -1
	_refresh_shrine_slot_visual({})
	if _shrine_btn_row:
		_shrine_btn_row.visible = false

func _refresh_shrine_slot_visual(item: Dictionary) -> void:
	if _shrine_slot_content == null:
		return
	for child in _shrine_slot_content.get_children():
		child.queue_free()
	if item.is_empty():
		_shrine_hint_label = _make_label("Drag item here\nto sanctify", 12, Color(0.95, 0.88, 0.55))
		_shrine_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_shrine_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_shrine_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_shrine_slot_content.add_child(_shrine_hint_label)
		return
	var r: int = clamp(int(item.get("rarity", 0)), 0, RARITY_COLORS.size() - 1)
	var col: Color = RARITY_COLORS[r]
	var tex: Texture2D = _resolve_icon(item)
	if tex:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(56, 56)
		tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_shrine_slot_content.add_child(tr)
	var name_lbl := _make_label(str(item.get("name", "?")), 11, col)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_shrine_slot_content.add_child(name_lbl)

func _on_shrine_confirm_pressed() -> void:
	if not shrine_mode or _shrine_pending_idx < 0 or _shrine_pending_slot == "":
		return
	shrine_item_confirmed.emit(_shrine_pending_slot, _shrine_pending_idx)

func _is_over_character(global_pos: Vector2) -> bool:
	if _char_sprite == null or not is_instance_valid(_char_sprite):
		return false
	return _char_sprite.get_global_rect().has_point(global_pos)

func _slot_key_from_global_pos(global_pos: Vector2) -> String:
	for slot_key in _slot_panels:
		var panel: PanelContainer = _slot_panels[slot_key]
		if not panel:
			continue
		var rect := panel.get_global_rect()
		if rect.has_point(global_pos):
			return slot_key
	return ""

func set_run_player_texture_supplier(supplier: Callable) -> void:
	_run_player_texture_supplier = supplier

func refresh_run_portrait() -> void:
	_sync_char_portrait()

func _sync_char_portrait() -> void:
	if _char_sprite == null or not is_instance_valid(_char_sprite):
		return
	var tex: Texture2D = null
	if _run_player_texture_supplier.is_valid():
		var v: Variant = _run_player_texture_supplier.call()
		if v is Texture2D:
			tex = v as Texture2D
	if tex != null:
		_char_sprite.texture = tex
		return
	var cls: String = String(GameState.meta.get("chosen_class", ""))
	var path: String = CLASS_TEX.get(cls, CLASS_TEX[""])
	if path != "" and ResourceLoader.exists(path):
		_char_sprite.texture = load(path) as Texture2D

func _resolve_icon(item: Dictionary) -> Texture2D:
	var name_lower: String = str(item.get("name", "")).to_lower()
	var slot_key: String   = str(item.get("type", ""))
	var guess := slot_key

	# Rings: allow mapping by "ring" (fallback) or exact "ring1"/"ring2"
	if slot_key == "ring1" or slot_key == "ring2":
		if ICON_BY_TYPE.has(slot_key):
			guess = slot_key
		elif ICON_BY_TYPE.has("ring"):
			guess = "ring"

	# Prefer slot-specific icon by armor_type (e.g. armor_light)
	var armor_type := String(item.get("armor_type", ""))
	if armor_type != "" and (slot_key == "armor" or slot_key == "gloves" or slot_key == "boots" or slot_key == "helmet"):
		var key := "%s_%s" % [slot_key, armor_type.to_lower()]
		if ICON_BY_TYPE.has(key):
			guess = key
	if slot_key == "weapon":
		for t in WEAPON_ICON_NAME_KEYS:
			if not ICON_BY_TYPE.has(t):
				continue
			if name_lower.find(t) >= 0:
				guess = t
				break
	var path: String = ICON_BY_TYPE.get(guess, "")
	if path != "" and ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func _make_label(txt: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if _font: l.add_theme_font_override("font", _font)
	return l

func _make_hsep() -> Control:
	return _make_gold_rule()


func _make_gold_rule() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 6)
	var line := ColorRect.new()
	line.color = FantasyUiAssets.TINT_DIVIDER
	line.custom_minimum_size = Vector2(0, 2)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(line)
	return row


func _style_backpack_scroll(scroll: ScrollContainer) -> void:
	scroll.clip_contents = true
	scroll.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var vsb := scroll.get_v_scroll_bar()
	if vsb == null:
		return
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(0.32, 0.27, 0.20, 0.85)
	grabber.set_corner_radius_all(2)
	vsb.add_theme_stylebox_override("grabber", grabber)
	vsb.add_theme_stylebox_override("grabber_highlight", grabber)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.08, 0.06, 0.05, 0.6)
	track.set_corner_radius_all(2)
	vsb.add_theme_stylebox_override("scroll", track)
	vsb.custom_minimum_size.x = 10


func _set_panel_border(panel: PanelContainer, col: Color) -> void:
	var tint := Color(
		clampf(col.r * 0.28 + 0.1, 0.0, 1.0),
		clampf(col.g * 0.28 + 0.08, 0.0, 1.0),
		clampf(col.b * 0.28 + 0.06, 0.0, 1.0),
		1.0
	)
	panel.add_theme_stylebox_override("panel", FantasyUiAssets.slot_panel(tint))


func _style_close_btn(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.32, 0.1, 0.08, 0.95)
	normal.border_color = FantasyUiAssets.TINT_DIVIDER
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(2)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.45, 0.14, 0.1, 0.98)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", normal)
	btn.add_theme_stylebox_override("focus", normal)
	btn.add_theme_color_override("font_color", Color(1.0, 0.72, 0.68))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 15)
	if _font:
		btn.add_theme_font_override("font", _font)


func _style_action_btn(btn: Button, col: Color) -> void:
	var styles := FantasyUiAssets.tinted_button(
		Color(col.r * 0.22 + 0.08, col.g * 0.22 + 0.06, col.b * 0.22 + 0.05, 1.0),
		Color(col.r * 0.32 + 0.12, col.g * 0.32 + 0.09, col.b * 0.32 + 0.07, 1.0)
	)
	btn.add_theme_stylebox_override("normal", styles[0])
	btn.add_theme_stylebox_override("hover", styles[1])
	btn.add_theme_stylebox_override("pressed", styles[0])
	btn.add_theme_stylebox_override("focus", styles[0])
	btn.add_theme_color_override("font_color", col)
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	btn.add_theme_font_size_override("font_size", 15)
	if _font:
		btn.add_theme_font_override("font", _font)


func _style_small_btn(btn: Button, col: Color) -> void:
	btn.add_theme_stylebox_override("normal", FantasyUiAssets.button_normal())
	btn.add_theme_stylebox_override("hover", FantasyUiAssets.button_hover())
	btn.add_theme_stylebox_override("pressed", FantasyUiAssets.button_pressed())
	btn.add_theme_stylebox_override("focus", FantasyUiAssets.button_normal())
	btn.add_theme_color_override("font_color", col)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	if _font:
		btn.add_theme_font_override("font", _font)
