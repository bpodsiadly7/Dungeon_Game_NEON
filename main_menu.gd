extends Control

const HOME_SCENE := "res://home_scene.tscn"

@onready var slot_container := $VBoxContainer/SlotContainer

func _ready() -> void:
	# Ustaw pełny ekran dla głównego VBox
	var main_vbox = $VBoxContainer
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 40)
	
	# Wycentruj zawartość VBoxa
	main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# Wycentruj tytuł
	var title = main_vbox.get_child(0) as Label
	if title:
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 48)
	
	# SlotContainer też wyśrodkuj
	if slot_container:
		slot_container.add_theme_constant_override("separation", 16)
	
	_refresh_slots()

func _refresh_slots() -> void:
	for c in slot_container.get_children():
		c.queue_free()
	
	for slot in [1, 2, 3]:
		var info := GameState.slot_info(slot)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		
		var lbl := Label.new()
		lbl.text = "Slot %d" % slot
		lbl.custom_minimum_size = Vector2(120, 0)
		lbl.add_theme_font_size_override("font_size", 24)
		row.add_child(lbl)
		
		if info["exists"]:
			var btn_cont := Button.new()
			btn_cont.text = "Continue"
			btn_cont.custom_minimum_size = Vector2(140, 48)
			btn_cont.pressed.connect(func(): _continue_slot(slot))
			row.add_child(btn_cont)
			
			var btn_del := Button.new()
			btn_del.text = "Delete"
			btn_del.custom_minimum_size = Vector2(100, 48)
			btn_del.pressed.connect(func(): _delete_slot(slot))
			row.add_child(btn_del)
		else:
			var btn_new := Button.new()
			btn_new.text = "New Game"
			btn_new.custom_minimum_size = Vector2(140, 48)
			btn_new.pressed.connect(func(): _new_game(slot))
			row.add_child(btn_new)
		
		slot_container.add_child(row)

func _new_game(slot: int) -> void:
	GameState.current_slot = slot
	GameState.reset_meta()
	GameState.save(slot)
	get_tree().change_scene_to_file(HOME_SCENE)

func _continue_slot(slot: int) -> void:
	GameState.current_slot = slot
	GameState.load_game(slot)
	get_tree().change_scene_to_file(HOME_SCENE)

func _delete_slot(slot: int) -> void:
	GameState.delete_slot(slot)
	_refresh_slots()
