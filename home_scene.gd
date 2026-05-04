extends Node2D

const DUNGEON_SCENE := "res://main.tscn"
const MENU_SCENE    := "res://main_menu.tscn"

const CLASS_TEX := {
	"warrior":   "res://player_classes/dwarf_warrior.png",
	"assassin":  "res://player_classes/dwarf_assasin.png",
	"guardian":  "res://player_classes/dwarf_guardian.png",
	"barbarian": "res://player_classes/dwarf_barbarian.png",
	"":          "res://player_classes/dwarf_novice.png"
}

const DUNGEON_NAMES := {
	0: "Goblin Cave",
	1: "Undead Crypt",
	2: "Highlands",
	3: "Orc Warcamps",
	4: "Dark Elf Depths",
	5: "Elderwood"
}

const DUNGEON_ICONS := {
	0: "💀", 1: "☠", 2: "⛰", 3: "🪓", 4: "🌑", 5: "🌲"
}

var _font: FontFile = null
var _chest_panel: PanelContainer = null
var _dungeon_panel: PanelContainer = null
var _player_sprite: TextureRect = null

func _ready() -> void:
	if ResourceLoader.exists("res://MedievalSharp-Bold.ttf"):
		_font = load("res://MedievalSharp-Bold.ttf")
	_build_ui()

# ─────────────────────────────────────────────────────────────
# BUDOWANIE UI
# ─────────────────────────────────────────────────────────────
func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(root)

	# ── Lewy panel: postać ───────────────────────────────────
	var left_panel := _make_panel(Vector2(260, 420))
	left_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	left_panel.position = Vector2(20, 20)
	root.add_child(left_panel)

	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 10)
	left_panel.add_child(left_vbox)

	var char_title := _make_label("CHARACTER", 14, Color(0.95, 0.82, 0.30))
	char_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_vbox.add_child(char_title)
	left_vbox.add_child(_make_hsep())

	# Portret krasnoludka
	_player_sprite = TextureRect.new()
	_player_sprite.custom_minimum_size = Vector2(120, 120)
	_player_sprite.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_player_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_player_sprite.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_refresh_player_sprite()
	left_vbox.add_child(_player_sprite)

	# Klasa i poziom
	var cls: String = String(GameState.meta.get("chosen_class", ""))
	var lvl: int = int(GameState.meta.get("player", {}).get("level", 1))
	var cls_label := _make_label(
		"%s  •  Lv %d" % [cls.capitalize() if cls != "" else "Novice", lvl],
		18, Color(1.0, 0.92, 0.70)
	)
	cls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_vbox.add_child(cls_label)

	left_vbox.add_child(_make_hsep())

	# Statystyki
	var pd: Dictionary = GameState.meta.get("player", {})
	var stats := [
		["⚔ STR",      pd.get("strength",   1)],
		["🏃 AGI",      pd.get("agility",    1)],
		["❤ VIT",      pd.get("vitality",   0)],
		["🎯 CRIT",     pd.get("crit",       0)],
		["✨ Stat pts", pd.get("stat_points", 0)],
	]
	for stat in stats:
		var row := HBoxContainer.new()
		var lbl_name := _make_label(str(stat[0]), 15, Color(0.75, 0.72, 0.68))
		lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var lbl_val  := _make_label(str(stat[1]), 15, Color(1.0, 0.95, 0.80))
		row.add_child(lbl_name)
		row.add_child(lbl_val)
		left_vbox.add_child(row)

	left_vbox.add_child(_make_hsep())

	# Permanenty w skrzynce
	var perm_count := _count_permanents()
	var perm_lbl := _make_label("💎 Permanents: %d" % perm_count, 15, Color(0.55, 0.90, 0.45))
	perm_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_vbox.add_child(perm_lbl)

	var runs: int = int(pd.get("runs_completed", 0))
	var runs_lbl := _make_label("🔄 Runs: %d" % runs, 14, Color(0.65, 0.65, 0.65))
	runs_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_vbox.add_child(runs_lbl)

	# ── Prawy panel: akcje ───────────────────────────────────
	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 12)
	right_vbox.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right_vbox.position = Vector2(-220, 20)
	root.add_child(right_vbox)

	right_vbox.add_child(_make_btn("▶  Start Run",      Color(0.95, 0.82, 0.30), _on_start_run))
	right_vbox.add_child(_make_btn("🗺  Choose Dungeon", Color(0.55, 0.75, 1.0),  _on_open_dungeon))
	right_vbox.add_child(_make_btn("📦  Open Chest",    Color(0.75, 0.55, 0.95), _on_open_chest))
	right_vbox.add_child(_make_btn("💾  Save",          Color(0.45, 0.85, 0.50), _on_save))
	right_vbox.add_child(_make_btn("🚪  Main Menu",     Color(0.6,  0.6,  0.6),  _on_main_menu))

	# ── Panele overlay ──────────────────────────────────────
	_build_chest_panel(root)
	_build_dungeon_panel(root)

# ─────────────────────────────────────────────────────────────
# PANEL: CHEST
# ─────────────────────────────────────────────────────────────
func _build_chest_panel(root: Control) -> void:
	_chest_panel = _make_panel(Vector2(500, 420))
	_chest_panel.set_anchors_preset(Control.PRESET_CENTER)
	_chest_panel.offset_left   = -250
	_chest_panel.offset_right  =  250
	_chest_panel.offset_top    = -210
	_chest_panel.offset_bottom =  210
	_chest_panel.visible = false
	_chest_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_chest_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_chest_panel.add_child(vbox)

	var title := _make_label("📦  PERMANENT CHEST", 20, Color(0.95, 0.82, 0.30))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	vbox.add_child(_make_hsep())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.name = "ChestList"
	list.add_theme_constant_override("separation", 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	vbox.add_child(_make_hsep())
	vbox.add_child(_make_btn("Close", Color(0.7, 0.3, 0.25), func(): _chest_panel.visible = false))

func _refresh_chest() -> void:
	var list := _chest_panel.find_child("ChestList", true, false) as VBoxContainer
	for c in list.get_children():
		c.queue_free()

	var chest: Dictionary = GameState.meta.get("permanent_chest", {})
	var any := false
	var rarity_colors := [Color(1,1,1), Color(0.45,0.75,1), Color(0.75,0.55,0.95), Color(1.0,0.85,0.2)]

	for slot_key in ["weapon", "armor", "helmet", "necklace"]:
		var arr: Array = chest.get(slot_key, [])
		for item in arr:
			any = true
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			var r: int = clamp(int(item.get("rarity", 0)), 0, 3)
			var name_lbl := _make_label(
				"%s  (%s)" % [str(item.get("name","?")), slot_key.capitalize()],
				15, rarity_colors[r]
			)
			name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			var captured_slot: String = slot_key
			var captured_item: Dictionary = item.duplicate(true)
			var take_btn := _make_btn("Take", Color(0.55, 0.90, 0.45), func():
				_take_from_chest(captured_slot, captured_item)
			)
			take_btn.custom_minimum_size = Vector2(80, 32)

			row.add_child(name_lbl)
			row.add_child(take_btn)
			list.add_child(row)

	if not any:
		var empty := _make_label("No permanent items yet.", 16, Color(0.55, 0.55, 0.55))
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list.add_child(empty)

func _take_from_chest(slot_key: String, item: Dictionary) -> void:
	var arr: Array = GameState.meta["permanent_chest"].get(slot_key, [])
	for j in arr.size():
		if arr[j].get("name","") == item.get("name",""):
			arr.remove_at(j)
			break
	if not GameState.run["loadout"].has(slot_key):
		GameState.run["loadout"][slot_key] = []
	var copy := item.duplicate(true)
	copy["permanent"] = true
	GameState.run["loadout"][slot_key].append(copy)
	_show_toast("Taken: %s" % str(item.get("name","?")))
	_refresh_chest()

# ─────────────────────────────────────────────────────────────
# PANEL: WYBÓR DUNGEONU
# ─────────────────────────────────────────────────────────────
func _build_dungeon_panel(root: Control) -> void:
	_dungeon_panel = _make_panel(Vector2(460, 380))
	_dungeon_panel.set_anchors_preset(Control.PRESET_CENTER)
	_dungeon_panel.offset_left   = -230
	_dungeon_panel.offset_right  =  230
	_dungeon_panel.offset_top    = -190
	_dungeon_panel.offset_bottom =  190
	_dungeon_panel.visible = false
	_dungeon_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_dungeon_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_dungeon_panel.add_child(vbox)

	var title := _make_label("🗺  CHOOSE STARTING DUNGEON", 19, Color(0.95, 0.82, 0.30))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	vbox.add_child(_make_hsep())

	var list := VBoxContainer.new()
	list.name = "DungeonList"
	list.add_theme_constant_override("separation", 8)
	vbox.add_child(list)

	vbox.add_child(_make_hsep())
	vbox.add_child(_make_btn("Close", Color(0.6, 0.6, 0.6), func(): _dungeon_panel.visible = false))

func _refresh_dungeons() -> void:
	var list := _dungeon_panel.find_child("DungeonList", true, false) as VBoxContainer
	for c in list.get_children():
		c.queue_free()

	var visited: Array = GameState.meta.get("visited_dungeons", [0])

	for idx in DUNGEON_NAMES.keys():
		var dname: String = DUNGEON_NAMES[idx]
		var icon: String  = DUNGEON_ICONS.get(idx, "•")
		var is_visited: bool = visited.has(idx)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var lbl := _make_label(
			"%s  %s" % [icon, dname], 16,
			Color(0.90, 0.88, 0.85) if is_visited else Color(0.40, 0.40, 0.40)
		)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var captured_idx: int = idx
		var captured_name := dname
		var btn: Button
		if is_visited:
			btn = _make_btn("Start here", Color(0.55, 0.75, 1.0), func():
				GameState.run["dungeon_index"] = captured_idx
				_dungeon_panel.visible = false
				_show_toast("%s selected!" % captured_name)
			)
		else:
			btn = _make_btn("Locked", Color(0.4, 0.4, 0.4), func(): pass)
			btn.disabled = true
		btn.custom_minimum_size = Vector2(120, 34)

		row.add_child(lbl)
		row.add_child(btn)
		list.add_child(row)

# ─────────────────────────────────────────────────────────────
# AKCJE
# ─────────────────────────────────────────────────────────────
func _on_start_run() -> void:
	GameState.save(GameState.current_slot)
	get_tree().change_scene_to_file(DUNGEON_SCENE)

func _on_open_chest() -> void:
	_refresh_chest()
	_chest_panel.visible = true
	_dungeon_panel.visible = false

func _on_open_dungeon() -> void:
	_refresh_dungeons()
	_dungeon_panel.visible = true
	_chest_panel.visible = false

func _on_save() -> void:
	var ok := GameState.save(GameState.current_slot)
	_show_toast("Saved! (Slot %d)" % GameState.current_slot if ok else "Save failed!")

func _on_main_menu() -> void:
	GameState.save(GameState.current_slot)
	get_tree().change_scene_to_file(MENU_SCENE)

# ─────────────────────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────────────────────
func _refresh_player_sprite() -> void:
	var cls: String = String(GameState.meta.get("chosen_class", ""))
	var path: String = CLASS_TEX.get(cls, CLASS_TEX[""])
	if ResourceLoader.exists(path):
		_player_sprite.texture = load(path)

func _count_permanents() -> int:
	var count := 0
	var chest: Dictionary = GameState.meta.get("permanent_chest", {})
	for s in chest:
		count += (chest[s] as Array).size()
	return count

func _make_panel(min_size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = min_size
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.06, 0.09, 0.92)
	sb.border_color = Color(0.35, 0.30, 0.22, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.shadow_size = 10
	sb.shadow_color = Color(0, 0, 0, 0.55)
	p.add_theme_stylebox_override("panel", sb)
	return p

func _make_label(txt: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if _font: l.add_theme_font_override("font", _font)
	return l

func _make_btn(txt: String, col: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(200, 44)
	b.add_theme_font_size_override("font_size", 17)
	if _font: b.add_theme_font_override("font", _font)
	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color = Color(col.r*0.18, col.g*0.18, col.b*0.18, 0.95)
	sb_n.border_color = col
	sb_n.set_border_width_all(2)
	sb_n.set_corner_radius_all(10)
	var sb_h := sb_n.duplicate() as StyleBoxFlat
	sb_h.bg_color = Color(col.r*0.32, col.g*0.32, col.b*0.32, 0.95)
	b.add_theme_stylebox_override("normal", sb_n)
	b.add_theme_stylebox_override("hover",  sb_h)
	b.add_theme_color_override("font_color",       col)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.pressed.connect(cb)
	return b

func _make_hsep() -> HSeparator:
	var s := HSeparator.new()
	s.add_theme_color_override("color", Color(0.35, 0.30, 0.22, 0.7))
	return s

func _show_toast(msg: String) -> void:
	var lbl := Label.new()
	lbl.text = msg
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(1, 0.92, 0.4))
	if _font: lbl.add_theme_font_override("font", _font)
	lbl.position = Vector2(get_viewport_rect().size.x / 2.0 - 150, get_viewport_rect().size.y * 0.80)
	lbl.z_index = 200
	add_child(lbl)
	var t := create_tween()
	t.tween_property(lbl, "modulate:a", 0.0, 1.8).from(1.0).set_delay(0.4)
	t.parallel().tween_property(lbl, "position:y", lbl.position.y - 50, 1.8)
	t.tween_callback(lbl.queue_free)
