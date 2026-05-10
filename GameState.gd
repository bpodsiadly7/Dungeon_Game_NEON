# res://GameState.gd
extends Node

## Wszystkie sloty ekwipunku (zg. z inventory_screen / main). Stare zapisy dostają brakujące klucze przy loadzie.
const EQUIPMENT_SLOT_KEYS: Array[String] = [
	"weapon", "armor", "helmet", "necklace", "gloves", "boots", "ring1", "ring2"
]

func _empty_equipment_buckets() -> Dictionary:
	var d := {}
	for k in EQUIPMENT_SLOT_KEYS:
		d[k] = []
	return d

func _ensure_equipment_dict_shape(d: Dictionary) -> void:
	for k in EQUIPMENT_SLOT_KEYS:
		if not d.has(k):
			d[k] = []
		elif typeof(d[k]) != TYPE_ARRAY:
			d[k] = []

func ensure_save_equipment_shape() -> void:
	_ensure_save_equipment_shape()

func _ensure_save_equipment_shape() -> void:
	_ensure_equipment_dict_shape(meta["permanent_chest"])
	if run.has("inventory"):
		_ensure_equipment_dict_shape(run["inventory"])
	else:
		run["inventory"] = _empty_equipment_buckets()
	if run.has("loadout"):
		_ensure_equipment_dict_shape(run["loadout"])
	else:
		run["loadout"] = _empty_equipment_buckets()

# ====== META (trwałe między runami) ======
var meta := {
	"permanent_chest": {},
	"gold": 0,
	"unlocked_dungeons": ["Goblin Cave"],
	"last_class": "",
	"visited_dungeons": [0],  
	"chosen_class": "",      
	"has_evolved": false      
}

# ====== AKTYWNY RUN ======
var run := {
	"active": false,
	"dungeon": "",
	"inventory": {},
	"loadout": {}
}

static func _deep_copy(v):
	return JSON.parse_string(JSON.stringify(v))

func _enter_tree() -> void:
	_ensure_save_equipment_shape()

# Gracz wybiera w domu co bierze — kopiujemy do run["loadout"] (wszystkie sloty)
func pack_loadout(selected: Dictionary) -> void:
	var merged := _empty_equipment_buckets()
	for k in EQUIPMENT_SLOT_KEYS:
		if selected.has(k) and typeof(selected[k]) == TYPE_ARRAY:
			merged[k] = _deep_copy(selected[k])
	run["loadout"] = merged

# Start runa — czyści run-inventory, loadout już ustawiony przez pack_loadout
func start_run(dungeon_name: String) -> void:
	run["active"] = true
	run["dungeon"] = dungeon_name
	run["inventory"] = _empty_equipment_buckets()

# Powrót do domu — loadout wraca do skrzynki, loot przepada
func end_run_to_home() -> void:
	_ensure_save_equipment_shape()
	for slot in EQUIPMENT_SLOT_KEYS:
		var bucket: Array = run["loadout"].get(slot, [])
		for it in bucket:
			meta["permanent_chest"][slot].append(_deep_copy(it))
	run["active"] = false
	run["dungeon"] = ""
	run["inventory"] = _empty_equipment_buckets()
	run["loadout"] = _empty_equipment_buckets()

# Śmierć — traci wszystko: i loot, i loadout
func on_player_death() -> void:
	run["active"] = false
	run["inventory"] = _empty_equipment_buckets()
	run["loadout"] = _empty_equipment_buckets()
	# Reset poziomu gracza
	meta["player"] = {
		"level": 1, "xp": 0,
		"strength": 1, "agility": 1, "vitality": 0, "crit": 0,
		"stat_points": 0, "max_hp": 100, "hp": 100,
		"has_evolved": false, "chosen_class": "",
		"stats_base_only": true,
	}
	# Klasa zostaje permanentna w meta
	meta["chosen_class"] = meta.get("chosen_class", "")
	meta["has_evolved"]  = meta.get("has_evolved", false)
	save(current_slot)

# Shrine — item z run["inventory"] trafia do skrzynki w domu (oznaczony jako permanent)
# Ale uwaga: zostaje też w run["inventory"] do końca runa
func make_permanent(slot_key: String, item: Dictionary) -> bool:
	if not meta["permanent_chest"].has(slot_key):
		return false
	var copy = _deep_copy(item)
	copy["permanent"] = true
	meta["permanent_chest"][slot_key].append(copy)
	return true

# Zwraca wszystkie permanenty z meta (skrzynka domowa) — używane przez home_scene
func get_permanent_chest() -> Dictionary:
	return meta["permanent_chest"]

# ====== SAVE / LOAD ======
static func _slot_path(slot: int) -> String:
	return "user://save_slot_%d.save" % slot

func save(slot: int) -> bool:
	slot = clamp(slot, 1, 3)
	var f := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if f == null:
		push_warning("Cannot open save file: %s" % _slot_path(slot))
		return false
	f.store_string(JSON.stringify({"meta": meta, "run": run}))
	f.flush(); f.close()
	print("[SAVE] Saved to slot %d" % slot)
	return true

# Alias dla kompatybilności z home_scene.gd
func save_to_slot(slot: int) -> bool:
	return save(slot)

func load_game(slot: int) -> bool:
	slot = clamp(slot, 1, 3)
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path): return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null: return false
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY: return false
	if data.has("meta"): meta = data["meta"]
	if data.has("run"): run = data["run"]
	_ensure_save_equipment_shape()
	print("[SAVE] Loaded from slot %d" % slot)
	return true

# Alias dla kompatybilności z home_scene.gd
func load_from_slot(slot: int) -> bool:
	return load_game(slot)

func delete_slot(slot: int) -> void:
	slot = clamp(slot, 1, 3)
	var path := _slot_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

func slot_info(slot: int) -> Dictionary:
	return {"exists": FileAccess.file_exists(_slot_path(slot)), "path": _slot_path(slot)}

var current_slot: int = 1  # aktualnie wybrany slot

func reset_meta() -> void:
	meta = {
		"permanent_chest": _empty_equipment_buckets(),
		"gold": 0,
		"unlocked_dungeons": ["Goblin Cave"],
		"last_class": "",
		"visited_dungeons": [0],
		"chosen_class": "",
		"has_evolved": false
	}
	run = {
		"active": false,
		"dungeon": "",
		"inventory": _empty_equipment_buckets(),
		"loadout": _empty_equipment_buckets()
	}
func save_player(p: Node, evolved: bool, cls: String) -> void:
	meta["player"] = {
		"level":        p.level,
		"xp":           p.xp,
		"strength":     p.strength,
		"agility":      p.agility,
		"vitality":     p.vitality,
		"crit":         p.crit,
		"stat_points":  p.stat_points,
		"max_hp":       p.max_hp,
		"hp":           p.hp,
		"has_evolved":  evolved,
		"chosen_class": cls,
		## Gracz: strength/agi/vit/crit w save = TYLKO baza (bez bonusów z przedmiotów).
		## Ekwipunek zmienia walkę/UI przez osobne obliczenia w main.gd.
		"stats_base_only": true,
	}

func load_player(p: Node) -> Dictionary:
	var d: Dictionary = meta.get("player", {})
	if d.is_empty():
		return {}
	p.level       = int(d.get("level", 1))
	p.xp          = int(d.get("xp", 0))
	p.strength    = int(d.get("strength", 1))
	p.agility     = int(d.get("agility", 1))
	p.vitality    = int(d.get("vitality", 0))
	p.crit        = int(d.get("crit", 0))
	p.stat_points = int(d.get("stat_points", 0))
	p.max_hp      = int(d.get("max_hp", 100))
	p.hp          = int(d.get("hp", p.max_hp))
	return d

func set_class(cls: String) -> void:
	meta["chosen_class"] = cls
	meta["has_evolved"] = true

func get_chosen_class() -> String:
	return String(meta.get("chosen_class", ""))

func has_class() -> bool:
	return bool(meta.get("has_evolved", false))
