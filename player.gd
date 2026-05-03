extends Sprite2D

signal died
signal hp_changed(current_hp, max_hp)
signal damaged(amount: int)
signal xp_changed(xp:int, xp_to_next:int)
signal level_changed(level:int, stat_points:int)
signal stats_changed(strength:int, agility:int, vitality:int, crit:int, stat_points:int)

var _heal_particles: GPUParticles2D = null

# --- LEVEL / XP ---
var level:int = 1
var xp:int = 0
var xp_to_next:int = 0
var stat_points:int = 0
# --- STATY POD ROZDZIAŁ ---
var strength:int = 1
var agility:int = 1
var vitality:int = 0
var crit:int = 0
var base_max_hp: int = 0
const VIT_HP_PER_POINT := 12


@export var max_hp:int = 100
var hp:int = max_hp

func _ready() -> void:
	hp = max_hp  # startowe HP
	base_max_hp = max_hp              # zapamiętaj bazę ze sceny (np. 100)
	_recalc_xp_to_next()
	_recalc_max_hp_from_stats(true)   # od razu dostosuj do startowego VIT
	emit_signal("xp_changed", xp, xp_to_next)
	emit_signal("level_changed", level, stat_points)
	emit_signal("stats_changed", strength, agility, vitality, crit, stat_points)
	_ensure_heal_particles()

func take_damage(amount:int) -> void:
	hp = max(hp - amount, 0)
	emit_signal("damaged", amount)       # powiadom Main.gd
	emit_signal("hp_changed", hp, max_hp)
	play_hit_flash()                     # 🔴 miganie na czerwono
	if hp == 0:
		emit_signal("died")

func is_alive() -> bool:
	return hp > 0

func play_hit_flash() -> void:
	var start_color := modulate
	var start_scale := scale
	var t := get_tree().create_tween()
	# mignięcie na czerwono + lekkie „ściśnięcie”
	t.tween_property(self, "modulate", Color(1, 0.3, 0.3, 1.0), 0.08).from(start_color)
	t.parallel().tween_property(self, "scale", start_scale * Vector2(1.08, 0.92), 0.08).from(start_scale)
	t.tween_interval(0.05)
	# powrót do normalnego koloru i skali
	t.tween_property(self, "modulate", start_color, 0.10)
	t.parallel().tween_property(self, "scale", start_scale, 0.10)

func add_xp(amount:int) -> void:
	xp += max(0, amount)
	while xp >= xp_to_next:
		xp -= xp_to_next
		_level_up()
	emit_signal("xp_changed", xp, xp_to_next)

func _level_up() -> void:
	level += 1
	stat_points += 3  # ile punktów rozdajesz na level
	_recalc_xp_to_next()
	emit_signal("level_changed", level, stat_points)
	emit_signal("stats_changed", strength, agility, vitality, crit, stat_points)

func _recalc_xp_to_next() -> void:
	# prosty rosnący koszt: baza 100 i mnożnik skali
	var base := 100
	var mult := 1.25
	xp_to_next = int(round(base * pow(mult, level - 1)))

func _recalc_max_hp_from_stats(keep_ratio: bool = true) -> void:
	var prev_max := max_hp
	var prev_hp := hp
	var new_max := base_max_hp + vitality * VIT_HP_PER_POINT
	new_max = max(new_max, 1)
	max_hp = new_max
	if keep_ratio and prev_max > 0:
		hp = clamp(int(round(float(prev_hp) / float(prev_max) * float(max_hp))), 1, max_hp)
	else:
		hp = max_hp
	emit_signal("hp_changed", hp, max_hp)


# Wywoływane przez przyciski w oknie statystyk:
func add_strength() -> void:
	if stat_points <= 0: return
	strength += 1; stat_points -= 1
	emit_signal("stats_changed", strength, agility, vitality, crit, stat_points)

func add_agility() -> void:
	if stat_points <= 0: return
	agility += 1; stat_points -= 1
	emit_signal("stats_changed", strength, agility, vitality, crit, stat_points)

func add_vitality() -> void:
	if stat_points <= 0:
		return
	vitality += 1
	stat_points -= 1
	_recalc_max_hp_from_stats(true)  # ← AKTUALIZACJA max_hp i hp + emit hp_changed
	emit_signal("stats_changed", strength, agility, vitality, crit, stat_points)


func add_crit() -> void:
	if stat_points <= 0: return
	crit += 1
	stat_points -= 1
	emit_signal("stats_changed", strength, agility, vitality, crit, stat_points)
	
# ▶️ Emisja cząsteczek
func play_heal_particles() -> void:
	if _heal_particles == null:
		_ensure_heal_particles()
	_heal_particles.emitting = false
	_heal_particles.restart()
	_heal_particles.emitting = true



# 🟢 Cząsteczki leczenia – lazy init
func _ensure_heal_particles() -> void:
	if _heal_particles != null:
		return
	var p: GPUParticles2D = GPUParticles2D.new()
	p.one_shot = true
	p.lifetime = 0.8
	p.amount = 36
	p.explosiveness = 0.25
	p.emitting = false
	p.position = Vector2(0, -10)
	p.z_index = 10

	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.gravity = Vector3(0, -10, 0)
	mat.initial_velocity_min = 60.0
	mat.initial_velocity_max = 110.0
	mat.angle_min = -35.0
	mat.angle_max = 35.0
	mat.scale_min = 0.6
	mat.scale_max = 1.0
	mat.radial_accel = Vector2(-5.0, -5.0)
	mat.damping      = Vector2(2.0, 2.0)

	var grad: Gradient = Gradient.new()
	grad.colors = [
		Color(0.35, 1.0, 0.55, 0.95),
		Color(0.35, 1.0, 0.55, 0.5),
		Color(0.35, 1.0, 0.55, 0.0),
	]
	var grad_tex: GradientTexture1D = GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex

	p.process_material = mat
	p.texture = _make_circle_texture(6)  # 👈 widoczna tekstura cząsteczki
	add_child(p)
	_heal_particles = p


# 🔆 Zielony błysk leczenia
func play_heal_flash() -> void:
	var target: CanvasItem = self
	if has_node("Sprite") and get_node("Sprite") is Sprite2D:
		target = get_node("Sprite") as Sprite2D

	var start_color: Color = target.modulate
	var start_scale: Vector2 = Vector2.ONE
	if "scale" in target:
		start_scale = target.scale as Vector2

	var t: Tween = get_tree().create_tween()

	# mocny zielony błysk i lekki pop
	t.tween_property(target, "modulate", Color(0.1, 1.0, 0.1, 1.0), 0.13).from(start_color)
	t.parallel().tween_property(target, "scale", start_scale * Vector2(1.08, 1.08), 0.13).from(start_scale)
	t.tween_interval(0.07)
	t.tween_property(target, "modulate", start_color, 0.18)
	t.parallel().tween_property(target, "scale", start_scale, 0.18)


# 🟢 Mała tekstura kółka jako sprite cząsteczki
func _make_circle_texture(radius: int = 6) -> Texture2D:
	var size_px: int = radius * 2 + 2
	var img: Image = Image.create(size_px, size_px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center: Vector2 = Vector2(radius + 1, radius + 1)
	for y in range(size_px):
		for x in range(size_px):
			var d: float = (Vector2(x, y) - center).length()
			if d <= float(radius):
				var a: float = clamp(1.0 - (d / float(radius)), 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a))
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	return tex

# --- EVOLUTION FX (class change) ---
var _evo_particles: GPUParticles2D

func play_class_change(new_tex: Texture2D) -> void:
	# przygotuj cząsteczki
	_ensure_evo_particles()

	# faza 1: rozbłysk i lekkie powiększenie
	var start_mod := modulate
	var start_scale: Vector2 = scale
	var tw1 := get_tree().create_tween()
	tw1.tween_property(self, "modulate", Color(1.0, 0.95, 0.6, 1.0), 0.08).from(start_mod)
	tw1.parallel().tween_property(self, "scale", start_scale * Vector2(1.12, 1.12), 0.12).from(start_scale)
	await tw1.finished

	# faza 2: szybki fade-out, podmiana tekstury
	var tw2 := get_tree().create_tween()
	tw2.tween_property(self, "modulate:a", 0.0, 0.10)
	await tw2.finished

	texture = new_tex

	# odpal cząsteczki
	if _evo_particles:
		_evo_particles.restart()
		_evo_particles.emitting = true

	# faza 3: wejście nowej formy
	modulate.a = 0.0
	scale = start_scale * Vector2(1.06, 1.06)
	var tw3 := get_tree().create_tween()
	tw3.tween_property(self, "modulate:a", 1.0, 0.14)
	tw3.parallel().tween_property(self, "scale", start_scale, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _ensure_evo_particles() -> void:
	if _evo_particles:
		return
	_evo_particles = GPUParticles2D.new()
	_evo_particles.one_shot = true
	_evo_particles.lifetime = 0.9
	_evo_particles.amount = 36
	_evo_particles.explosiveness = 0.3
	_evo_particles.emitting = false
	_evo_particles.position = Vector2(0, -8)

	var mat := ParticleProcessMaterial.new()
	mat.gravity = Vector3(0, -10, 0)
	mat.initial_velocity_min = 70
	mat.initial_velocity_max = 120
	mat.angle_min = -40.0
	mat.angle_max = 40.0
	mat.scale_min = 0.5
	mat.scale_max = 0.9
	mat.color = Color(1.0, 0.85, 0.2, 1.0)  # złota iskra

	var grad := Gradient.new()
	grad.colors = [
		Color(1.0, 0.9, 0.4, 1.0),
		Color(1.0, 0.7, 0.2, 0.6),
		Color(1.0, 0.7, 0.2, 0.0),
	]
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex

	_evo_particles.process_material = mat
	add_child(_evo_particles)
