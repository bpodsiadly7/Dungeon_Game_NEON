extends Control

signal closed
signal item_equipped(slot_key: String, idx: int)
signal item_dropped(slot_key: String, idx: int)
signal stat_spent(stat_key: String)
signal item_unequipped(slot_key: String)
signal item_hovered(item: Dictionary, slot_key: String, idx: int)

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
var _item_stats:   RichTextLabel = null
var _equip_btn:    Button = null
var _drop_btn:     Button = null
var _stats_labels: Dictionary = {}
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
## Zwraca Texture2D gracza z aktywnego runa (tak samo jak widoczna postać). Jeśli Callable pusty / null — fallback z GameState.
var _run_player_texture_supplier: Callable = Callable()

func _ready() -> void:
	if ResourceLoader.exists("res://MedievalSharp-Bold.ttf"):
		_font = load("res://MedievalSharp-Bold.ttf")
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_clear_selection()
	visible = false

func _process(_delta: float) -> void:
	if not visible:
		return
	var shift_now := Input.is_key_pressed(KEY_SHIFT)
	if shift_now != _shift_compare_active:
		_shift_compare_active = shift_now
		if not _hovered_item.is_empty():
			_show_item_details(_hovered_item, _hovered_slot, true, _hovered_idx)
	if _dragging and _drag_preview:
		_drag_preview.size = Vector2(90, 30)
		_drag_preview.global_position = get_global_mouse_position() + Vector2(12, 12)

func _build_ui() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.72)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1200, 660)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left   = -600
	panel.offset_right  =  600
	panel.offset_top    = -330
	panel.offset_bottom =  330
	_style_main_panel(panel)
	add_child(panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	panel.add_child(root_vbox)

	# Header
	var header := HBoxContainer.new()
	root_vbox.add_child(header)
	var title := _make_label("INVENTORY", 28, Color(0.95, 0.82, 0.30))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(44, 44)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(_on_close)
	_style_close_btn(close_btn)
	header.add_child(close_btn)

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.35, 0.30, 0.22, 0.8))
	root_vbox.add_child(sep)

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(content)

	_build_left_panel(content)
	_build_center_panel(content)
	_build_right_panel(content)

func _build_left_panel(parent: HBoxContainer) -> void:
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(200, 0)
	vbox.add_theme_constant_override("separation", 8)
	parent.add_child(vbox)

	var title := _make_label("STATISTICS", 16, Color(0.95, 0.82, 0.30))
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
		var lbl_val := _make_label("0", 15, def[2] as Color)
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
	var sp_val := _make_label("0", 15, Color(1.0, 0.92, 0.30))
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

func _build_center_panel(parent: HBoxContainer) -> void:
	var area := Control.new()
	area.custom_minimum_size = Vector2(400, 0)
	area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(area)

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
	_set_panel_border(panel, Color(0.30, 0.26, 0.18))
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)
	var lbl := _make_label(label_text, 10, Color(0.38, 0.36, 0.32))
	lbl.name = "SlotLabel"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(lbl)
	return panel

func _build_right_panel(parent: HBoxContainer) -> void:
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(480, 0)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	parent.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)
	var bp_title := _make_label("BACKPACK", 16, Color(0.95, 0.82, 0.30))
	bp_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(bp_title)

	for sort_label in ["All", "Type", "Rarity"]:
		var captured_label: String = sort_label
		var btn := Button.new()
		btn.text = sort_label
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(70, 30)
		btn.add_theme_font_size_override("font_size", 13)
		if _font: btn.add_theme_font_override("font", _font)
		btn.pressed.connect(func():
			match captured_label:
				"All":    _sort_mode = SortMode.NONE
				"Type":   _sort_mode = SortMode.TYPE
				"Rarity": _sort_mode = SortMode.RARITY
			_refresh_backpack()
		)
		_style_small_btn(btn, Color(0.55, 0.75, 1.0))
		header.add_child(btn)

	vbox.add_child(_make_hsep())

	_backpack_scroll = ScrollContainer.new()
	_backpack_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_backpack_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_backpack_scroll)

	_item_grid = GridContainer.new()
	_item_grid.columns = 6
	_item_grid.add_theme_constant_override("h_separation", 8)
	_item_grid.add_theme_constant_override("v_separation", 8)
	_item_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_backpack_scroll.add_child(_item_grid)

	vbox.add_child(_make_hsep())

	var details := PanelContainer.new()
	details.custom_minimum_size = Vector2(0, 130)
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = Color(0.05, 0.04, 0.07, 0.95)
	dsb.border_color = Color(0.30, 0.26, 0.18, 0.8)
	dsb.set_border_width_all(1)
	dsb.set_corner_radius_all(8)
	details.add_theme_stylebox_override("panel", dsb)
	vbox.add_child(details)

	var det_vbox := VBoxContainer.new()
	det_vbox.add_theme_constant_override("separation", 6)
	details.add_child(det_vbox)

	_item_name = _make_label("[Select an item]", 17, Color(0.90, 0.88, 0.85))
	det_vbox.add_child(_item_name)
	_item_stats = RichTextLabel.new()
	_item_stats.bbcode_enabled = true
	_item_stats.fit_content = true
	_item_stats.scroll_active = false
	_item_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_item_stats.add_theme_font_size_override("normal_font_size", 13)
	_item_stats.add_theme_color_override("default_color", Color(0.78, 0.75, 0.70))
	if _font:
		_item_stats.add_theme_font_override("normal_font", _font)
	det_vbox.add_child(_item_stats)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	det_vbox.add_child(btn_row)

	_equip_btn = Button.new()
	_equip_btn.text = "EQUIP"
	_equip_btn.custom_minimum_size = Vector2(120, 38)
	_equip_btn.focus_mode = Control.FOCUS_NONE
	_equip_btn.pressed.connect(_on_equip)
	_style_action_btn(_equip_btn, Color(0.95, 0.82, 0.30))
	btn_row.add_child(_equip_btn)

	_drop_btn = Button.new()
	_drop_btn.text = "DROP"
	_drop_btn.custom_minimum_size = Vector2(120, 38)
	_drop_btn.focus_mode = Control.FOCUS_NONE
	_drop_btn.pressed.connect(_on_drop)
	_style_action_btn(_drop_btn, Color(0.75, 0.25, 0.20))
	btn_row.add_child(_drop_btn)

func open(inv: Dictionary, eq: Dictionary, stats: Dictionary) -> void:
	inventory    = inv
	equipped     = eq
	player_stats = stats
	_sync_char_portrait()
	_refresh_stats()
	_refresh_all_slots()
	_refresh_backpack()
	_clear_selection()
	visible = true
	move_to_front()

func _on_close() -> void:
	visible = false
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("toggle_inventory") or event.is_action_pressed("ui_cancel"):
		_on_close()
		get_viewport().set_input_as_handled()

func _refresh_stats() -> void:
	for key in _stats_labels:
		var lbl: Label = _stats_labels[key]
		if key == "hp":
			lbl.text = "%d / %d" % [int(player_stats.get("hp", 0)), int(player_stats.get("max_hp", 0))]
		elif key == "total_armor":
			lbl.text = str(_calc_total_armor())
		elif key == "total_dmg":
			lbl.text = str(_calc_total_dmg())
		else:
			lbl.text = str(int(player_stats.get(key, 0)))
	var has_points := int(player_stats.get("stat_points", 0)) > 0
	for key in _stats_plus_buttons:
		var btn: Button = _stats_plus_buttons[key]
		btn.disabled = not has_points

func _calc_total_armor() -> int:
	var base := 0
	var armor_item: Dictionary = equipped.get("armor", {})
	if not armor_item.is_empty():
		base = int(armor_item.get("armor", 0))
	var types: Array[String] = []
	for k in ["armor", "helmet", "gloves", "boots"]:
		var it: Dictionary = equipped.get(k, {})
		if not it.is_empty():
			var t := String(it.get("armor_type", ""))
			if t != "" and t != "berserker":
				types.append(t)
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
	var extra_armor := int(player_stats.get("passive_armor_bonus", 0))
	return clamp(base + bonus + extra_armor, 0, 15)

func _flat_weapon_dmg_from_armor_pieces() -> int:
	var total := 0
	for k in ["helmet", "armor", "gloves", "boots"]:
		var it: Dictionary = equipped.get(k, {})
		if it.is_empty():
			continue
		var b: Dictionary = it.get("bonuses", {})
		total += int(b.get("weapon_dmg", 0))
	return total


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

func _refresh_slot(slot_key: String) -> void:
	var panel: PanelContainer = _slot_panels.get(slot_key)
	if not panel: return
	# Sloty nie mogą zmieniać rozmiaru (zawartość nie może ich "rozpychać")
	panel.custom_minimum_size = SLOT_SIZE
	panel.size = SLOT_SIZE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for c in panel.get_children():
		c.queue_free()
	var item: Dictionary = equipped.get(slot_key, {})
	var cfg: Dictionary  = SLOT_CONFIG.get(slot_key, {})
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(vbox)

	if item.is_empty():
		_set_panel_border(panel, Color(0.28, 0.24, 0.16))
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
			tr.custom_minimum_size = Vector2(46, 46)
			tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			vbox.add_child(tr)
		var name_lbl := _make_label(str(item.get("name", "?")), 9, col)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_lbl.clip_text = true
		name_lbl.custom_minimum_size = Vector2(SLOT_SIZE.x - 8.0, 0)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		vbox.add_child(name_lbl)
		if bool(item.get("permanent", false)):
			var perm := _make_label("*", 11, Color(0.55, 0.90, 0.45))
			perm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(perm)
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
			if not eq_item.is_empty() and eq_item.get("name", "") == item.get("name", ""):
				continue
			all_items.append({"item": item, "slot": slot_key, "idx": i})

	match _sort_mode:
		SortMode.TYPE:
			all_items.sort_custom(func(a, b): return str(a["slot"]) < str(b["slot"]))
		SortMode.RARITY:
			all_items.sort_custom(func(a, b): return int(a["item"].get("rarity", 0)) > int(b["item"].get("rarity", 0)))

	if all_items.is_empty():
		_item_grid.add_child(_make_label("Backpack is empty.", 15, Color(0.45, 0.45, 0.45)))
		return

	for entry in all_items:
		var item: Dictionary    = entry["item"]
		var slot_key: String    = entry["slot"]
		var idx: int            = entry["idx"]
		var r: int              = clamp(int(item.get("rarity", 0)), 0, RARITY_COLORS.size() - 1)
		var col: Color          = RARITY_COLORS[r]

		var tile := PanelContainer.new()
		tile.custom_minimum_size = Vector2(68, 68)
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
			tr.custom_minimum_size = Vector2(36, 36)
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
	_set_panel_border(tile, Color(1, 1, 1))

	_show_item_details(item, slot_key, false, idx)
	_equip_btn.visible = true
	_drop_btn.visible  = not bool(item.get("permanent", false))

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
	if selected_idx >= 0:
		item_equipped.emit(selected_slot, selected_idx)
		_clear_selection()
		_refresh_backpack()

func _on_drop() -> void:
	if selected_idx >= 0 and not bool(selected_item.get("permanent", false)):
		item_dropped.emit(selected_slot, selected_idx)
		_clear_selection()
		_refresh_backpack()

func _show_item_details(item: Dictionary, slot_key: String, from_hover: bool, idx: int = -1) -> void:
	var r: int = clamp(int(item.get("rarity", 0)), 0, RARITY_COLORS.size() - 1)
	_item_name.text = "%s  [%s]" % [str(item.get("name", "?")), RARITY_NAMES[r]]
	_item_name.add_theme_color_override("font_color", RARITY_COLORS[r])
	var lines := _build_item_description(item, slot_key)
	if Input.is_key_pressed(KEY_SHIFT):
		var eq_item: Dictionary = equipped.get(slot_key, {})
		if not eq_item.is_empty():
			lines += "\n\nCOMPARE\n%s" % _build_compare_block(item, eq_item, slot_key)
		else:
			lines += "\n\nCOMPARE\nNo equipped item in this slot."
	_item_stats.text = lines
	_showing_hover_details = from_hover and idx != selected_idx

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
	var armor_type := String(item.get("armor_type", ""))
	match slot_key:
		"weapon":
			lines += "\nDMG base: %d" % int(item.get("base", 0))
			var scale_dict: Dictionary = item.get("scale", {})
			if not scale_dict.is_empty():
				var s := ""
				for k in scale_dict:
					s += "  %s×%.1f" % [k.to_upper(), float(scale_dict[k])]
				lines += "\nScaling:%s" % s
		"armor":
			if item.has("armor"):
				lines += "\nArmor: %d" % int(item.get("armor", 0))
			else:
				lines += "\nDamage Reduction: %.0f%%" % (float(item.get("dr", 0)) * 100)
		"helmet":
			lines += "\nHP Bonus: +%d" % int(item.get("hp_bonus", 0))
		"necklace":
			lines += "\nCrit mult: +%.0f%%" % (float(item.get("crit_bonus", 0.0)) * 100.0)
			lines += "\nBonus stat: %s" % str(item.get("bonus_stat", "—")).to_upper()
		"ring1", "ring2":
			lines += "\nSkill: %s" % String(item.get("skill_id", "—"))
	if armor_type != "" and slot_key in ["armor", "helmet", "gloves", "boots"]:
		lines += "\nType: %s" % armor_type.capitalize()
		if armor_type != "berserker":
			lines += "\n(Set bonus: counts toward light/medium/heavy)"
		else:
			lines += "\n(No armor set bonus — adds flat damage)"
	lines = _append_item_bonus_lines(lines, _item_bonus_totals(item, slot_key))
	if bool(item.get("permanent", false)):
		lines += "\n★ PERMANENT"
	return lines

func _build_compare_block(candidate: Dictionary, equipped_item: Dictionary, slot_key: String) -> String:
	var cmp_lines := "Current: %s" % str(equipped_item.get("name", "—"))
	match slot_key:
		"weapon", "gloves", "boots", "ring1", "ring2":
			var cand_base := int(candidate.get("base", 0))
			var eq_base := int(equipped_item.get("base", 0))
			var delta_base := cand_base - eq_base
			cmp_lines += "\nBase: %d (%s)" % [cand_base, _fmt_delta(delta_base, false)]
		"armor":
			if candidate.has("armor") or equipped_item.has("armor"):
				var cand_a := int(candidate.get("armor", 0))
				var eq_a := int(equipped_item.get("armor", 0))
				var delta_a := cand_a - eq_a
				cmp_lines += "\nArmor: %d (%s)" % [cand_a, _fmt_delta(delta_a, false)]
			else:
				var cand_dr := float(candidate.get("dr", 0))
				var eq_dr := float(equipped_item.get("dr", 0))
				var delta_dr := (cand_dr - eq_dr) * 100.0
				cmp_lines += "\nDR: %.0f%% (%s)" % [cand_dr * 100.0, _fmt_delta(delta_dr, true)]
		"helmet":
			var cand_hp := int(candidate.get("hp_bonus", 0))
			var eq_hp := int(equipped_item.get("hp_bonus", 0))
			var delta_hp := cand_hp - eq_hp
			cmp_lines += "\nHP Bonus: %d (%s)" % [cand_hp, _fmt_delta(delta_hp, false)]
		"necklace":
			cmp_lines += "\nBonus stat: %s -> %s" % [
				str(equipped_item.get("bonus_stat", "—")).to_upper(),
				str(candidate.get("bonus_stat", "—")).to_upper()
			]
	if slot_key in ["armor", "helmet", "gloves", "boots"]:
		var cand_wd := _bonus_weapon_dmg_from_item(candidate)
		var eq_wd := _bonus_weapon_dmg_from_item(equipped_item)
		if cand_wd != 0 or eq_wd != 0:
			cmp_lines += "\nFlat DMG: %d (%s)" % [cand_wd, _fmt_delta(cand_wd - eq_wd, false)]
	var cand_bonus_value := int(candidate.get("bonus_value", 0))
	var eq_bonus_value := int(equipped_item.get("bonus_value", 0))
	if str(candidate.get("bonus_stat", "")) != "":
		var delta_bonus := cand_bonus_value - eq_bonus_value
		cmp_lines += "\nBonus value: %d (%s)" % [cand_bonus_value, _fmt_delta(delta_bonus, false)]
	return cmp_lines

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
	var target_slot := _slot_key_from_global_pos(mouse)
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
	if _drag_preview and is_instance_valid(_drag_preview):
		_drag_preview.queue_free()
	_drag_preview = null
	_dragging = false
	_drag_item = {}
	_drag_slot = ""
	_drag_idx = -1
	_drag_source = ""

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

func _make_hsep() -> HSeparator:
	var s := HSeparator.new()
	s.add_theme_color_override("color", Color(0.35, 0.30, 0.22, 0.7))
	return s

func _set_panel_border(panel: PanelContainer, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.10, 0.95)
	sb.border_color = col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", sb)

func _style_main_panel(panel: PanelContainer) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color     = Color(0.07, 0.06, 0.09, 0.97)
	sb.border_color = Color(0.40, 0.35, 0.25, 1.0)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.shadow_size  = 18
	sb.shadow_color = Color(0, 0, 0, 0.65)
	panel.add_theme_stylebox_override("panel", sb)

func _style_close_btn(btn: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color     = Color(0.45, 0.10, 0.10, 0.9)
	sb.border_color = Color(0.75, 0.20, 0.18)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_color_override("font_color", Color(1, 0.6, 0.6))
	btn.add_theme_font_size_override("font_size", 18)
	if _font: btn.add_theme_font_override("font", _font)

func _style_action_btn(btn: Button, col: Color) -> void:
	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color     = Color(col.r*0.20, col.g*0.20, col.b*0.20, 0.95)
	sb_n.border_color = col
	sb_n.set_border_width_all(2)
	sb_n.set_corner_radius_all(8)
	var sb_h := sb_n.duplicate() as StyleBoxFlat
	sb_h.bg_color = Color(col.r*0.35, col.g*0.35, col.b*0.35, 0.95)
	btn.add_theme_stylebox_override("normal", sb_n)
	btn.add_theme_stylebox_override("hover",  sb_h)
	btn.add_theme_color_override("font_color",       col)
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	btn.add_theme_font_size_override("font_size", 15)
	if _font: btn.add_theme_font_override("font", _font)

func _style_small_btn(btn: Button, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color     = Color(col.r*0.15, col.g*0.15, col.b*0.15, 0.95)
	sb.border_color = col
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	var sb_h := sb.duplicate() as StyleBoxFlat
	sb_h.bg_color = Color(col.r*0.28, col.g*0.28, col.b*0.28, 0.95)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover",  sb_h)
	btn.add_theme_color_override("font_color", col)
