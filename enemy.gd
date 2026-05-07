extends Node2D

signal defeated
signal hp_changed(current_hp, max_hp)
signal damaged(amount: int)

var name_display: String = ""
var max_hp: int = 0
var hp: int = 0
var damage: int = 0

var _spr: Sprite2D = null
var _hit_flash_tween: Tween = null
## Wartości ze sceny / edytora — nie wolno nadpisywać Vector2.ONE (sprite'y są zwykle pomniejszone).
var _spr_rest_modulate: Color = Color.WHITE
var _spr_rest_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	# 1) jeśli masz dziecko o nazwie "Sprite":
	if has_node("Sprite") and get_node("Sprite") is Sprite2D:
		_spr = get_node("Sprite") as Sprite2D
	else:
		# 2) znajdź pierwsze dziecko typu Sprite2D
		for c in get_children():
			if c is Sprite2D:
				_spr = c
				break
	if _spr:
		_spr_rest_modulate = _spr.modulate
		_spr_rest_scale = _spr.scale

func _kill_hit_flash() -> void:
	if _hit_flash_tween != null and is_instance_valid(_hit_flash_tween):
		_hit_flash_tween.kill()
	_hit_flash_tween = null

func setup_enemy(name_in: String, hp_in: int, dmg_in: int, tex_path: String = "") -> void:
	name_display = name_in
	max_hp = hp_in
	hp = max_hp
	damage = dmg_in

	_kill_hit_flash()
	if _spr:
		# Stan po poprzedniej walce / tweenie — z powrotem do rozmiaru koloru ze sceny.
		_spr.modulate = _spr_rest_modulate
		_spr.scale = _spr_rest_scale

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
	# Nakładające się tweeny (Quick Slash) — zabij poprzedni, snap do spoczynku ze sceny, potem jeden pełny flash.
	_kill_hit_flash()
	_spr.modulate = _spr_rest_modulate
	_spr.scale = _spr_rest_scale
	var flash_col := Color(1, 0.3, 0.3, _spr_rest_modulate.a)
	var punch_scale := _spr_rest_scale * Vector2(1.08, 0.92)
	_hit_flash_tween = create_tween()
	var t := _hit_flash_tween
	t.tween_property(_spr, "modulate", flash_col, 0.08)
	t.parallel().tween_property(_spr, "scale", punch_scale, 0.08)
	t.tween_interval(0.05)
	t.tween_property(_spr, "modulate", _spr_rest_modulate, 0.10)
	t.parallel().tween_property(_spr, "scale", _spr_rest_scale, 0.10)

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
