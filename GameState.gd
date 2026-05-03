# res://GameState.gd
extends Node

# ====== META (trwałe między runami) ======
var meta := {
	# Skrzynka w domu — itemy permanentne bezpieczne na stałe
	"permanent_chest": {
		"weapon": [], "armor": [], "helmet": [], "necklace": []
	},
	"gold": 0,
	"unlocked_dungeons": ["Goblin Cave"],
	"last_class": ""
}

# ====== AKTYWNY RUN ======
var run := {
	"active": false,
	"dungeon": "",
	# Loot zebrany podczas runa — przepada przy śmierci i po powrocie
	"inventory": {
		"weapon": [], "armor": [], "helmet": [], "necklace": []
	},
	# Itemy świadomie zabrane z domu — przepadają przy śmierci, wracają do skrzynki po powrocie
	"loadout": {
		"weapon": [], "armor": [], "helmet": [], "necklace": []
	}
}

static func _deep_copy(v):
	return JSON.parse_string(JSON.stringify(v))

# Gracz wybiera w domu co bierze — kopiujemy do run["loadout"]
func pack_loadout(selected: Dictionary) -> void:
	run["loadout"] = _deep_copy(selected)

# Start runa — czyści run-inventory, loadout już ustawiony przez pack_loadout
func start_run(dungeon_name: String) -> void:
	run["active"] = true
	run["dungeon"] = dungeon_name
	run["inventory"] = {"weapon": [], "armor": [], "helmet": [], "necklace": []}

# Powrót do domu — loadout wraca do skrzynki, loot przepada
func end_run_to_home() -> void:
	for slot in run["loadout"]:
		for it in run["loadout"][slot]:
			meta["permanent_chest"][slot].append(_deep_copy(it))
	run["active"] = false
	run["dungeon"] = ""
	run["inventory"] = {"weapon": [], "armor": [], "helmet": [], "necklace": []}
	run["loadout"]   = {"weapon": [], "armor": [], "helmet": [], "necklace": []}

# Śmierć — traci wszystko: i loot, i loadout
func on_player_death() -> void:
	run["active"]    = false
	run["dungeon"]   = ""
	run["inventory"] = {"weapon": [], "armor": [], "helmet": [], "necklace": []}
	run["loadout"]   = {"weapon": [], "armor": [], "helmet": [], "necklace": []}

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
	if data.has("run"):  run  = data["run"]
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
