extends Node2D

signal defeated
signal hp_changed(current_hp, max_hp)
signal damaged(amount: int)

var name_display: String = ""
var max_hp: int = 0
var hp: int = 0
var damage: int = 0

var _spr: Sprite2D = null

func _ready() -> void:
	# 1) jeśli masz dziecko o nazwie "Sprite":
	if has_node("Sprite") and get_node("Sprite") is Sprite2D:
		_spr = get_node("Sprite")
	else:
		# 2) znajdź pierwsze dziecko typu Sprite2D
		for c in get_children():
			if c is Sprite2D:
				_spr = c
				break

func setup_enemy(name_in: String, hp_in: int, dmg_in: int, tex_path: String = "") -> void:
	name_display = name_in
	max_hp = hp_in
	hp = max_hp
	damage = dmg_in

	# DEBUG: zobaczysz w Output, co trafia do wroga
	print("Enemy setup:", name_display, " tex:", tex_path)

	if tex_path != "":
		_set_texture_safely(tex_path)
	else:
		# jeśli nowy wpis nie ma tex, wyczyść starą teksturę, żeby nie zostawała poprzednia
		if _spr:
			_spr.texture = null

	emit_signal("hp_changed", hp, max_hp)

func take_damage(amount: int) -> void:
	hp = max(hp - amount, 0)
	emit_signal("damaged", amount)
	emit_signal("hp_changed", hp, max_hp)
	play_hit_flash()  # 🔴 MIGANIE
	if hp == 0:
		emit_signal("defeated")

func is_alive() -> bool:
	return hp > 0

func play_hit_flash() -> void:
	if _spr == null:
		return
	var start_color := _spr.modulate
	var start_scale := _spr.scale
	var t := get_tree().create_tween()
	t.tween_property(_spr, "modulate", Color(1, 0.3, 0.3, 1.0), 0.08).from(start_color)
	t.parallel().tween_property(_spr, "scale", start_scale * Vector2(1.08, 0.92), 0.08).from(start_scale)
	t.tween_interval(0.05)
	t.tween_property(_spr, "modulate", start_color, 0.10)
	t.parallel().tween_property(_spr, "scale", start_scale, 0.10)

# ---------- POMOCNICZA ----------


func _set_texture_safely(path: String) -> void:
	if _spr == null:
		push_warning("Enemy sprite not found in scene; cannot set texture.")
		return
	var t := load(path)
	if t and t is Texture2D:
		_spr.texture = t
		print(" → Enemy texture set OK:", path)  # DEBUG
	else:
		push_warning("Enemy texture not found or invalid: %s" % path)
