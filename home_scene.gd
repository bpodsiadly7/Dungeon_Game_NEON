extends Node2D


const DUNGEON_SCENE := "res://main.tscn"  # wracamy tutaj po naciśnięciu Start Run

@onready var bg: Sprite2D        = $Background
@onready var player: Sprite2D    = $Player
@onready var ui: Control         = $CanvasLayer/UI
@onready var btn_start: Button   = $CanvasLayer/UI/StartRunButton
@onready var btn_chest: Button   = $CanvasLayer/UI/ChestButton
@onready var btn_save: Button    = $CanvasLayer/UI/SaveBtn
@onready var btn_load: Button    = $CanvasLayer/UI/LoadBtn
@onready var btn_exit: Button    = $CanvasLayer/UI/ExitBtn

# --- UI Elements for the Chest panel ---
var chest_panel: PanelContainer
var chest_scroll: ScrollContainer
var chest_list: VBoxContainer


func _ready() -> void:
	# Ustawiamy tło na grafikę domu
	if ResourceLoader.exists("res://backgrounds/home.png"):
		bg.texture = load("res://backgrounds/home.png")

	# Gracz na środku ekranu
	player.position = get_viewport_rect().size * 0.5 + Vector2(0, 60)

	# Podłączamy przyciski
	btn_start.pressed.connect(_on_start_run)
	btn_chest.pressed.connect(_on_open_chest)
	btn_save.pressed.connect(_on_save_slot1)
	btn_load.pressed.connect(_on_load_slot1)
	btn_exit.pressed.connect(_on_exit_to_menu)
	
	# stylizuj przyciski
	if btn_start: _apply_home_button_style(btn_start)
	if btn_chest: _apply_home_button_style(btn_chest)
	if btn_save: _apply_home_button_style(btn_save)
	if btn_load: _apply_home_button_style(btn_load)
	if btn_exit: _apply_home_button_style(btn_exit)

	_create_chest_panel_if_needed()


func _on_start_run() -> void:
	print("[HOME] Start Run -> dungeon")
	get_tree().change_scene_to_file(DUNGEON_SCENE)

func _on_open_chest() -> void:
	_toggle_chest(true)


# POPRAWKA: używamy GameState.save() zamiast save_to_slot()
func _on_save_slot1() -> void:
	var ok := GameState.save(1)
	_show_toast_home("Game Saved!" if ok else "Save failed!", 1.5)

# POPRAWKA: używamy GameState.load_game() zamiast load_from_slot()
func _on_load_slot1() -> void:
	var ok := GameState.load_game(1)
	_show_toast_home("Game Loaded!" if ok else "No save found.", 1.5)

func _on_exit_to_menu() -> void:
	get_tree().quit()

# --- Ścieżki do skóry UI ---
const TEX_LEATHER_BG := "res://ui/textures/leather_bg.png"  # kafelkowane tło
const TEX_FRAME := "res://ui/frames/inventory_frame.png"     # ramka 9-slice (opcjonalnie)

# szybki loader z fallbackiem
func _load_tex(p: String) -> Texture2D:
	if ResourceLoader.exists(p):
		return load(p) as Texture2D
	else:
		return null

# prosta ramka „skórzana" dla PanelContainer/Button
func _make_leather_panel_style() -> StyleBox:
	var tex := _load_tex(TEX_FRAME)
	if tex:
		var sb := StyleBoxTexture.new()
		sb.texture = tex
		sb.set_texture_margin(SIDE_LEFT, 16)
		sb.set_texture_margin(SIDE_TOP, 16)
		sb.set_texture_margin(SIDE_RIGHT, 16)
		sb.set_texture_margin(SIDE_BOTTOM, 16)
		return sb
	else:
		var flat := StyleBoxFlat.new()
		flat.bg_color = Color(0.08, 0.09, 0.12, 0.95)
		flat.border_color = Color(0.35, 0.30, 0.22, 1.0)
		flat.set_border_width_all(2)
		return flat


# kafelkowane tło do Control
func _apply_tiled_bg(ctrl: Control) -> void:
	var tex := _load_tex(TEX_LEATHER_BG)
	if tex == null:
		return

	# jeśli już istnieje wcześniejsze tło, nie dodawaj kolejnego
	var existing_bg := ctrl.get_node_or_null("TiledBG") as TextureRect
	if existing_bg:
		existing_bg.texture = tex
		return

	var bg_rect := TextureRect.new()
	bg_rect.name = "TiledBG"
	bg_rect.texture = tex
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_rect.stretch_mode = TextureRect.STRETCH_TILE
	bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_rect.modulate = Color(1, 1, 1, 0.95)

	# wstaw jako pierwsze dziecko, żeby było pod zawartością
	if ctrl.get_child_count() > 0:
		ctrl.add_child(bg_rect)
		ctrl.move_child(bg_rect, 0)
	else:
		ctrl.add_child(bg_rect)



# mini styl do Buttonów
func _apply_home_button_style(btn: Button) -> void:
	btn.custom_minimum_size = Vector2(220, 42)
	btn.focus_mode = Control.FOCUS_ALL

	var base := StyleBoxFlat.new()
	base.bg_color = Color(0.08, 0.09, 0.12, 0.92)
	base.border_color = Color(0.35, 0.30, 0.22)
	base.set_border_width_all(2)
	base.set_corner_radius_all(12)

	var hover := base.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.12, 0.13, 0.17, 0.96)
	hover.border_color = Color(0.95, 0.82, 0.30)

	var pressed := base.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.06, 0.07, 0.09, 0.96)

	btn.add_theme_stylebox_override("normal", base)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color(0.90, 0.88, 0.85))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.60))
	btn.add_theme_font_size_override("font_size", 18)


func _create_chest_panel_if_needed() -> void:
	if chest_panel and is_instance_valid(chest_panel):
		return

	chest_panel = PanelContainer.new()
	chest_panel.name = "ChestPanel"
	chest_panel.visible = false
	chest_panel.anchor_left = 0.5
	chest_panel.anchor_top = 0.5
	chest_panel.anchor_right = 0.5
	chest_panel.anchor_bottom = 0.5
	chest_panel.offset_left = -320
	chest_panel.offset_right = 320
	chest_panel.offset_top = -220
	chest_panel.offset_bottom = 220
	chest_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var frame := _make_leather_panel_style()
	chest_panel.add_theme_stylebox_override("panel", frame)

	var root := VBoxContainer.new()
	root.name = "Root"
	root.add_theme_constant_override("separation", 8)
	chest_panel.add_child(root)

	var title := Label.new()
	title.text = "Permanent Chest"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	root.add_child(title)

	chest_scroll = ScrollContainer.new()
	chest_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chest_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(chest_scroll)

	var bg_panel := PanelContainer.new()
	_apply_tiled_bg(bg_panel)
	chest_scroll.add_child(bg_panel)

	chest_list = VBoxContainer.new()
	chest_list.add_theme_constant_override("separation", 6)
	bg_panel.add_child(chest_list)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	root.add_child(actions)

	var close_btn := Button.new()
	close_btn.text = "Close"
	_apply_home_button_style(close_btn)
	close_btn.pressed.connect(func(): _toggle_chest(false))
	actions.add_child(close_btn)

	ui.add_child(chest_panel)
	chest_panel.move_to_front()

func _toggle_chest(show: bool) -> void:
	if not chest_panel or not is_instance_valid(chest_panel):
		_create_chest_panel_if_needed()
	chest_panel.visible = show
	if show:
		_refresh_chest_contents()

func _refresh_chest_contents() -> void:
	for c in chest_list.get_children():
		c.queue_free()
	
	# POPRAWKA: używamy GameState.meta["permanent_chest"] zamiast permanent_inventory
	var chest: Dictionary = GameState.meta.get("permanent_chest", {})
	
	var all_items: Array = []
	var all_keys: Array = []
	
	for slot_key in ["weapon", "armor", "helmet", "necklace"]:
		var arr: Array = chest.get(slot_key, [])
		for item in arr:
			all_items.append(item)
			all_keys.append(slot_key)
	
	if all_items.is_empty():
		var l := Label.new()
		l.text = "(No permanent items yet)\nComplete a run to unlock permanents."
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		chest_list.add_child(l)
		return
	
	for i in all_items.size():
		var it: Dictionary = all_items[i]
		var slot_key: String = all_keys[i]
		
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var name_lbl := Label.new()
		var rarity_suffix := ""
		match int(it.get("rarity", 0)):
			1: rarity_suffix = " [RARE]"
			2: rarity_suffix = " [EPIC]"
			3: rarity_suffix = " [LEG]"
		name_lbl.text = str(it.get("name", "Unknown")) + rarity_suffix + " (" + slot_key.capitalize() + ")"
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# Captury przez lokalne zmienne, żeby closure działało poprawnie
		var captured_slot := slot_key
		var captured_item := it.duplicate(true)
		
		var take_btn := Button.new()
		take_btn.text = "Take"
		take_btn.custom_minimum_size = Vector2(100, 36)
		_apply_home_button_style(take_btn)
		
		take_btn.pressed.connect(func():
			_take_item_from_chest(captured_slot, captured_item)
		)
		
		row.add_child(name_lbl)
		row.add_child(take_btn)
		chest_list.add_child(row)


func _take_item_from_chest(slot_key: String, item: Dictionary) -> void:
	# Usuń z permanent_chest
	var chest: Dictionary = GameState.meta.get("permanent_chest", {})
	var arr: Array = chest.get(slot_key, [])
	for j in arr.size():
		if arr[j].get("name", "") == item.get("name", "") and arr[j].get("permanent", false):
			arr.remove_at(j)
			break

	# Dodaj do run["loadout"] — main.gd załaduje to przy starcie runa
	if not GameState.run["loadout"].has(slot_key):
		GameState.run["loadout"][slot_key] = []
	var copy := item.duplicate(true)
	copy["permanent"] = true
	GameState.run["loadout"][slot_key].append(copy)

	_show_toast_home("Taken: " + str(item.get("name", "?")), 1.5)
	_refresh_chest_contents()


func _show_toast_home(msg: String, duration: float = 1.8) -> void:
	var toast := Label.new()
	toast.text = msg
	toast.add_theme_font_size_override("font_size", 22)
	toast.modulate = Color(1, 0.95, 0.6, 1)          # jasnożółty/złoty
	toast.position = Vector2(
		get_viewport_rect().size.x / 2 - 140,
		get_viewport_rect().size.y / 2 - 80
	)
	toast.z_index = 100
	add_child(toast)
	
	var t := create_tween()
	t.tween_property(toast, "modulate:a", 0.0, duration).from(1.0).set_delay(0.6)
	t.parallel().tween_property(toast, "position:y", toast.position.y - 60, duration)
	t.tween_callback(toast.queue_free)
