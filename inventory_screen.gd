extends Control

signal closed
signal item_equipped(slot_key: String, idx: int)
signal item_dropped(slot_key: String, idx: int)


@onready var close_btn     := $MainPanel/MainVBox/Header/CloseBtn
@onready var weapon_slot   := $MainPanel/MainVBox/Content/LeftPanel/WeaponSlot
@onready var armor_slot    := $MainPanel/MainVBox/Content/LeftPanel/ArmorSlot
@onready var helmet_slot   := $MainPanel/MainVBox/Content/LeftPanel/TopRow/HelmetSlot
@onready var necklace_slot := $MainPanel/MainVBox/Content/LeftPanel/TopRow/NecklaceSlot
@onready var stats_label   := $MainPanel/MainVBox/Content/LeftPanel/StatsLabel
@onready var item_grid     := $MainPanel/MainVBox/Content/RightPanel/BackpackScroll/ItemGrid
@onready var item_name     := $MainPanel/MainVBox/Content/RightPanel/ItemDetails/DetailsVBox/ItemName
@onready var item_stats    := $MainPanel/MainVBox/Content/RightPanel/ItemDetails/DetailsVBox/ItemStats
@onready var equip_btn     := $MainPanel/MainVBox/Content/RightPanel/ItemDetails/DetailsVBox/ButtonsRow/EquipBtn
@onready var drop_btn      := $MainPanel/MainVBox/Content/RightPanel/ItemDetails/DetailsVBox/ButtonsRow/DropBtn

const RARITY_COLORS := [
	Color(0.85, 0.85, 0.85, 1.0),  # Common
	Color(0.30, 0.65, 1.00, 1.0),  # Rare
	Color(0.70, 0.35, 1.00, 1.0),  # Epic
	Color(1.00, 0.80, 0.10, 1.0),  # Legendary
]
const RARITY_NAMES := ["Common", "Rare", "Epic", "Legendary"]

# Ta sama mapa co w main.gd
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
	"helmet":   "res://ikony/helmet_icon.png",
	"necklace": "res://ikony/necklace_icon.png",
}

var _font: FontFile = null
var inventory: Dictionary = {}
var equipped:  Dictionary = {}
var selected_item: Dictionary = {}
var selected_slot: String = ""
var selected_idx:  int = -1
var _selected_tile: PanelContainer = null

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists("res://MedievalSharp-Bold.ttf"):
		_font = load("res://MedievalSharp-Bold.ttf")
	mouse_filter = Control.MOUSE_FILTER_STOP
	close_btn.pressed.connect(_on_close)
	equip_btn.pressed.connect(_on_equip)
	drop_btn.pressed.connect(_on_drop)
	close_btn.focus_mode = Control.FOCUS_NONE
	equip_btn.focus_mode = Control.FOCUS_NONE
	drop_btn.focus_mode  = Control.FOCUS_NONE
	_style_panel()
	_clear_selection()
	visible = false

func open(inv: Dictionary, eq: Dictionary, player_stats: Dictionary) -> void:
	inventory = inv
	equipped  = eq
	_refresh_stats(player_stats)
	_refresh_equipped()
	_refresh_backpack()
	_clear_selection()
	visible = true
	move_to_front()

func _on_close() -> void:
	visible = false
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible: return
	if event.is_action_pressed("ui_cancel"):
		_on_close()
		get_viewport().set_input_as_handled()

# ─────────────────────────────────────────────────────────────
# IKONA — rozpoznaj po nazwie itemu (tak jak w main.gd)
# ─────────────────────────────────────────────────────────────
func _resolve_icon(item: Dictionary) -> Texture2D:
	var item_name_lower: String = str(item.get("name", "")).to_lower()
	var slot_key: String = str(item.get("type", ""))

	# Dla broni szukaj słowa kluczowego w nazwie
	var guess_type := slot_key
	if slot_key == "weapon":
		for t in ICON_BY_TYPE.keys():
			if item_name_lower.find(t) >= 0:
				guess_type = t
				break

	var path: String = ICON_BY_TYPE.get(guess_type, "")
	if path != "" and ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

# ─────────────────────────────────────────────────────────────
# STATYSTYKI
# ─────────────────────────────────────────────────────────────
func _refresh_stats(stats: Dictionary) -> void:
	stats_label.text = "STR: %d   AGI: %d\nVIT: %d   CRIT: %d\nHP: %d / %d" % [
		int(stats.get("str",    0)),
		int(stats.get("agi",    0)),
		int(stats.get("vit",    0)),
		int(stats.get("crit",   0)),
		int(stats.get("hp",     0)),
		int(stats.get("max_hp", 0)),
	]

# ─────────────────────────────────────────────────────────────
# EQUIPPED SLOTS
# ─────────────────────────────────────────────────────────────
func _refresh_equipped() -> void:
	var slots := {
		"weapon":   weapon_slot,
		"armor":    armor_slot,
		"helmet":   helmet_slot,
		"necklace": necklace_slot,
	}
	for slot_key in slots:
		var panel: PanelContainer = slots[slot_key]
		for c in panel.get_children():
			c.queue_free()

		var item: Dictionary = equipped.get(slot_key, {})
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)

		if item.is_empty():
			# Pusty slot — tylko nazwa slotu
			_set_panel_border(panel, Color(0.30, 0.26, 0.18))
			var lbl := _make_label(slot_key.capitalize(), 13, Color(0.38, 0.36, 0.32))
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			vbox.add_child(lbl)
		else:
			var r: int = clamp(int(item.get("rarity", 0)), 0, 3)
			var col: Color = RARITY_COLORS[r]
			_set_panel_border(panel, col)

			# Ikona PNG jeśli istnieje
			var tex: Texture2D = _resolve_icon(item)
			if tex:
				var tex_rect := TextureRect.new()
				tex_rect.texture = tex
				tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
				tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				tex_rect.custom_minimum_size = Vector2(40, 40)
				tex_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				vbox.add_child(tex_rect)

			# Nazwa
			var name_lbl := _make_label(str(item.get("name", "?")), 11, col)
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			vbox.add_child(name_lbl)

			# Badge PERMANENT
			if bool(item.get("permanent", false)):
				var perm := _make_label("★ PERM", 10, Color(0.55, 0.90, 0.45))
				perm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				vbox.add_child(perm)

		panel.add_child(vbox)

# ─────────────────────────────────────────────────────────────
# BACKPACK GRID
# ─────────────────────────────────────────────────────────────
func _refresh_backpack() -> void:
	for c in item_grid.get_children():
		c.queue_free()

	var all_items: Array = []
	for slot_key in ["weapon", "armor", "helmet", "necklace"]:
		var arr: Array = inventory.get(slot_key, [])
		for i in arr.size():
			all_items.append({"item": arr[i], "slot": slot_key, "idx": i})

	if all_items.is_empty():
		var lbl := _make_label("Backpack is empty.", 16, Color(0.5, 0.5, 0.5))
		item_grid.add_child(lbl)
		return

	for entry in all_items:
		var item: Dictionary    = entry["item"]
		var slot_key: String    = entry["slot"]
		var idx: int            = entry["idx"]
		var r: int              = clamp(int(item.get("rarity", 0)), 0, 3)
		var col: Color          = RARITY_COLORS[r]

		var tile := PanelContainer.new()
		tile.custom_minimum_size = Vector2(80, 80)
		_set_panel_border(tile, col)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 2)
		tile.add_child(vbox)

		# Ikona PNG jeśli istnieje
		var tex: Texture2D = _resolve_icon(item)
		if tex:
			var tex_rect := TextureRect.new()
			tex_rect.texture = tex
			tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.custom_minimum_size = Vector2(44, 44)
			tex_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			vbox.add_child(tex_rect)

		# Nazwa skrócona
		var full_name: String = str(item.get("name", "?"))
		var short_name: String = full_name.substr(0, 10) + ("…" if full_name.length() > 10 else "")
		var name_lbl := _make_label(short_name, 10, col)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(name_lbl)

		# Badge PERMANENT
		if bool(item.get("permanent", false)):
			var perm := _make_label("★", 12, Color(0.55, 0.90, 0.45))
			perm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(perm)

		# Przezroczysty przycisk do kliknięcia
		var captured_item: Dictionary = item.duplicate(true)
		var captured_slot: String     = slot_key
		var captured_idx: int         = idx
		var btn := Button.new()
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.pressed.connect(func():
			_select_item(captured_item, captured_slot, captured_idx, tile)
		)
		tile.add_child(btn)
		item_grid.add_child(tile)

# ─────────────────────────────────────────────────────────────
# SELEKCJA
# ─────────────────────────────────────────────────────────────
func _select_item(item: Dictionary, slot_key: String, idx: int, tile: PanelContainer) -> void:
	if _selected_tile and is_instance_valid(_selected_tile):
		var prev_r: int = clamp(int(selected_item.get("rarity", 0)), 0, 3)
		_set_panel_border(_selected_tile, RARITY_COLORS[prev_r])

	selected_item  = item
	selected_slot  = slot_key
	selected_idx   = idx
	_selected_tile = tile
	_set_panel_border(tile, Color(1, 1, 1, 1))

	var r: int = clamp(int(item.get("rarity", 0)), 0, 3)
	item_name.text = "%s  [%s]" % [str(item.get("name", "?")), RARITY_NAMES[r]]
	item_name.add_theme_color_override("font_color", RARITY_COLORS[r])

	var base: int              = int(item.get("base", 0))
	var scale_dict: Dictionary = item.get("scale", {})
	var bonuses: Array         = item.get("bonuses", [])
	var lines := "Slot: %s   Base: %d" % [slot_key.capitalize(), base]
	if not scale_dict.is_empty():
		var s := ""
		for k in scale_dict:
			s += "  %s×%.1f" % [k.to_upper(), float(scale_dict[k])]
		lines += "\nScaling:%s" % s
	if not bonuses.is_empty():
		var s := ""
		for b in bonuses:
			s += "  +%d %s" % [int(b.get("value", 0)), str(b.get("stat", "?")).to_upper()]
		lines += "\nBonuses:%s" % s
	if bool(item.get("permanent", false)):
		lines += "\n★ PERMANENT"
	item_stats.text = lines

	equip_btn.visible = true
	drop_btn.visible  = not bool(item.get("permanent", false))

func _clear_selection() -> void:
	selected_item  = {}
	selected_slot  = ""
	selected_idx   = -1
	_selected_tile = null
	item_name.text  = "[Select an item]"
	item_stats.text = ""
	equip_btn.visible = false
	drop_btn.visible  = false

# ─────────────────────────────────────────────────────────────
# AKCJE
# ─────────────────────────────────────────────────────────────
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

# ─────────────────────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────────────────────
func _make_label(txt: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if _font: l.add_theme_font_override("font", _font)
	return l

func _set_panel_border(panel: PanelContainer, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.10, 0.95)
	sb.border_color = col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", sb)

func _style_panel() -> void:
	var main_panel := $MainPanel as PanelContainer
	var sb := StyleBoxFlat.new()
	sb.bg_color     = Color(0.07, 0.06, 0.09, 0.97)
	sb.border_color = Color(0.40, 0.35, 0.25, 1.0)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.shadow_size  = 16
	sb.shadow_color = Color(0, 0, 0, 0.6)
	main_panel.add_theme_stylebox_override("panel", sb)

	var title := $MainPanel/MainVBox/Header/Title as Label
	title.add_theme_color_override("font_color", Color(0.95, 0.82, 0.30))
	if _font: title.add_theme_font_override("font", _font)

	var eq_title := $MainPanel/MainVBox/Content/LeftPanel/EquipmentTitle as Label
	if eq_title:
		eq_title.add_theme_color_override("font_color", Color(0.75, 0.72, 0.68))
		if _font: eq_title.add_theme_font_override("font", _font)

	var bp_title := $MainPanel/MainVBox/Content/RightPanel/BackpackTitle as Label
	if bp_title:
		bp_title.add_theme_color_override("font_color", Color(0.75, 0.72, 0.68))
		if _font: bp_title.add_theme_font_override("font", _font)

	stats_label.add_theme_color_override("font_color", Color(0.88, 0.85, 0.80))
	if _font: stats_label.add_theme_font_override("font", _font)

	if _font:
		item_name.add_theme_font_override("font", _font)
		item_stats.add_theme_font_override("font", _font)
	item_stats.add_theme_color_override("font_color", Color(0.78, 0.75, 0.70))

	var close_sb := StyleBoxFlat.new()
	close_sb.bg_color     = Color(0.45, 0.10, 0.10, 0.9)
	close_sb.border_color = Color(0.75, 0.20, 0.18)
	close_sb.set_border_width_all(2)
	close_sb.set_corner_radius_all(8)
	close_btn.add_theme_stylebox_override("normal", close_sb)
	close_btn.add_theme_color_override("font_color", Color(1, 0.6, 0.6))
	if _font: close_btn.add_theme_font_override("font", _font)

	_style_action_btn(equip_btn, Color(0.95, 0.82, 0.30))
	_style_action_btn(drop_btn,  Color(0.75, 0.25, 0.20))

	for panel in [weapon_slot, armor_slot, helmet_slot, necklace_slot]:
		_set_panel_border(panel, Color(0.30, 0.26, 0.18))

	var details_panel := $MainPanel/MainVBox/Content/RightPanel/ItemDetails as PanelContainer
	var dsb := StyleBoxFlat.new()
	dsb.bg_color     = Color(0.05, 0.04, 0.07, 0.95)
	dsb.border_color = Color(0.30, 0.26, 0.18, 0.8)
	dsb.set_border_width_all(1)
	dsb.set_corner_radius_all(8)
	details_panel.add_theme_stylebox_override("panel", dsb)

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
	btn.add_theme_font_size_override("font_size", 16)
	if _font: btn.add_theme_font_override("font", _font)
