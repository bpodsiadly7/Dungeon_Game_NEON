# res://GameState.gd
extends Node

## Wszystkie sloty ekwipunku (zg. z inventory_screen / main). Stare zapisy dostają brakujące klucze przy loadzie.
const EQUIPMENT_SLOT_KEYS: Array[String] = [
	"weapon", "armor", "helmet", "necklace", "gloves", "boots", "ring1", "ring2"
]

const COLONY_STARTING_DWARFS := 1
const COLONY_RECRUITS_PER_SUCCESS := 3

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
	_ensure_colony_shape()


func _default_colony() -> Dictionary:
	return {
		"dwarf_count": COLONY_STARTING_DWARFS,
		"pending_growth_from": -1,
		"pending_loss_from": -1,
	}


func _ensure_colony_shape() -> void:
	if not meta.has("colony") or typeof(meta["colony"]) != TYPE_DICTIONARY:
		meta["colony"] = _default_colony()
		return
	var colony: Dictionary = meta["colony"]
	if not colony.has("dwarf_count"):
		colony["dwarf_count"] = COLONY_STARTING_DWARFS
	if not colony.has("pending_growth_from"):
		colony["pending_growth_from"] = -1
	if not colony.has("pending_loss_from"):
		colony["pending_loss_from"] = -1


func get_dwarf_count() -> int:
	_ensure_colony_shape()
	return maxi(0, int(meta["colony"].get("dwarf_count", COLONY_STARTING_DWARFS)))


func lose_dwarf_on_death() -> void:
	_ensure_colony_shape()
	var colony: Dictionary = meta["colony"]
	var from_count := get_dwarf_count()
	if from_count <= 0:
		return
	colony["pending_loss_from"] = from_count
	colony["dwarf_count"] = from_count - 1
	colony["pending_growth_from"] = -1


func is_colony_defeated() -> bool:
	return get_dwarf_count() <= 0


func finalize_colony_defeat() -> void:
	var slot := current_slot
	delete_slot(slot)
	reset_meta()
	current_slot = slot


func grant_colony_growth_on_success() -> void:
	_ensure_colony_shape()
	var from_count := get_dwarf_count()
	meta["colony"]["pending_growth_from"] = from_count
	meta["colony"]["pending_loss_from"] = -1
	meta["colony"]["dwarf_count"] = from_count + COLONY_RECRUITS_PER_SUCCESS


func consume_pending_loss_animation() -> Dictionary:
	_ensure_colony_shape()
	var colony: Dictionary = meta["colony"]
	var from_count := int(colony.get("pending_loss_from", -1))
	if from_count < 0:
		return {}
	colony["pending_loss_from"] = -1
	return {
		"from": from_count,
		"to": get_dwarf_count(),
	}


func consume_pending_growth_animation() -> Dictionary:
	_ensure_colony_shape()
	var colony: Dictionary = meta["colony"]
	var from_count := int(colony.get("pending_growth_from", -1))
	if from_count < 0:
		return {}
	colony["pending_growth_from"] = -1
	return {
		"from": from_count,
		"to": get_dwarf_count(),
	}

func duplicate_equipment_buckets(src: Dictionary) -> Dictionary:
	var out := _empty_equipment_buckets()
	for k in EQUIPMENT_SLOT_KEYS:
		if not src.has(k):
			continue
		for it in src[k]:
			if typeof(it) == TYPE_DICTIONARY:
				out[k].append(_deep_copy(it))
	return out


func loadout_as_equipped_dict() -> Dictionary:
	_ensure_save_equipment_shape()
	var eq := {}
	for k in EQUIPMENT_SLOT_KEYS:
		var arr: Array = run["loadout"].get(k, [])
		if arr.size() > 0 and typeof(arr[0]) == TYPE_DICTIONARY:
			eq[k] = _deep_copy(arr[0])
		else:
			eq[k] = {}
	return eq


## Przed powrotem do bazy: zapisz aktualnie założony gear (np. po boss-upgrade) do run["loadout"].
func sync_run_loadout_from_equipped(equipped: Dictionary) -> void:
	_ensure_save_equipment_shape()
	var loadout := _empty_equipment_buckets()
	for slot in EQUIPMENT_SLOT_KEYS:
		var it: Variant = equipped.get(slot, {})
		if typeof(it) != TYPE_DICTIONARY or it.is_empty():
			continue
		if slot == "weapon" and String(it.get("name", "")) == "Unarmed":
			continue
		loadout[slot] = [_deep_copy(it)]
	run["loadout"] = loadout


func remove_item_from_bucket(bucket: Array, item: Dictionary) -> bool:
	var target_name := String(item.get("name", ""))
	for i in bucket.size():
		if String(bucket[i].get("name", "")) == target_name:
			bucket.remove_at(i)
			return true
	return false


func remove_all_items_by_name_from_bucket(bucket: Array, item_name: String) -> int:
	if item_name == "":
		return 0
	var removed := 0
	for i in range(bucket.size() - 1, -1, -1):
		if String(bucket[i].get("name", "")) == item_name:
			bucket.remove_at(i)
			removed += 1
	return removed


func _return_loadout_item_to_chest(slot: String, item: Dictionary) -> void:
	var bucket: Array = meta["permanent_chest"][slot]
	var item_name := String(item.get("name", ""))
	# Zastąp stare kopie (np. sprzed boss-upgrade), zamiast dokładać duplikat.
	remove_all_items_by_name_from_bucket(bucket, item_name)
	bucket.append(_deep_copy(item))


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
func end_run_to_home(grant_colony_growth: bool = false) -> void:
	_ensure_save_equipment_shape()
	for slot in EQUIPMENT_SLOT_KEYS:
		var bucket: Array = run["loadout"].get(slot, [])
		for it in bucket:
			_return_loadout_item_to_chest(slot, it)
	run["active"] = false
	run["dungeon"] = ""
	run["inventory"] = _empty_equipment_buckets()
	run["loadout"] = _empty_equipment_buckets()
	if grant_colony_growth:
		grant_colony_growth_on_success()

# Śmierć — traci wszystko: i loot, i loadout, i krasnoluda z wyprawy
func on_player_death() -> void:
	run["active"] = false
	run["inventory"] = _empty_equipment_buckets()
	run["loadout"] = _empty_equipment_buckets()
	lose_dwarf_on_death()
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
	_ensure_colony_shape()
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
		"has_evolved": false,
		"colony": _default_colony(),
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
