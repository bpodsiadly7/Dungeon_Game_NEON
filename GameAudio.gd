extends Node
## Prosty menedżer SFX — współdzielona pula odtwarzaczy.

const SFX_DICE_ROLL := "res://sound/GameDiceRoll.wav"
const SFX_ENEMY_HIT_LOW := "res://sound/male_fighting_hit_effort_01.wav"
const SFX_ENEMY_HIT_HIGH := "res://sound/beast_pain_big_damaged_hit.wav"
const SFX_PLAYER_HIT := "res://sound/ESM_Dwarf_Vocal_One_Shot_Groan_1_Human_Game_Voice.wav"
const SFX_PLAYER_CRIT_GRUNT := "res://sound/FightGrunt_BW.54993.wav"
const SFX_PLAYER_CRIT_SPLATTER := "res://sound/ESM_Game_Deep_Blood_Splatter_Impact_Cinematic_Hit_Wet_Drop_Impale_Slam_Horror_Juicy_Squirt_Break.wav"
const SFX_BOSS_ANNOUNCE := "res://sound/BS_KSPS_Synth_WarHorn_Leji_D.wav"
const SFX_ENEMY_TRANSITION := "res://sound/ESM_Braaam_Strike_2_Hit_One_Shot_Wooden_Eclipse_Glide_Cinematic_Impact_Stinger_Movie_Trailer.wav"
const SFX_POTION_HEAL := "res://sound/ESM_Ancient_Game_Magic_Buff_Heal_2_Fantasy_Tonal_Accent_Hit_Stab.wav"
const SFX_COLONY_LOSS := "res://sound/ESM_GB_fx_foley_one_shot_firebrst_flame_extinguish_short_01_burn_fire_flame.wav"
const SFX_COLONY_GROWTH := "res://sound/ESM_DGF_fx_foley_footstep_stone_warrior_walk_faster_armor_war_03.wav"

const COMBAT_SFX_DB := -20.0

const _POOL_SIZE := 8

var _players: Array[AudioStreamPlayer] = []
var _stream_cache: Dictionary = {}


func _ready() -> void:
	for i in _POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = &"Master"
		add_child(player)
		_players.append(player)


func play_dice_roll() -> void:
	_play(SFX_DICE_ROLL, -8.0, randf_range(0.97, 1.03))


func play_enemy_hit(difficulty: int) -> void:
	var diff := clampi(difficulty, 1, 5)
	if diff > 3:
		_play(SFX_ENEMY_HIT_HIGH, COMBAT_SFX_DB, randf_range(0.94, 1.06))
	else:
		_play(SFX_ENEMY_HIT_LOW, COMBAT_SFX_DB, randf_range(0.94, 1.06))


func play_player_hit(is_crit: bool) -> void:
	if is_crit:
		_play(SFX_PLAYER_CRIT_GRUNT, COMBAT_SFX_DB, randf_range(0.94, 1.06))
		_play(SFX_PLAYER_CRIT_SPLATTER, COMBAT_SFX_DB, randf_range(0.94, 1.06))
	else:
		_play(SFX_PLAYER_HIT, COMBAT_SFX_DB, randf_range(0.94, 1.06))


func play_boss_announce() -> void:
	_play(SFX_BOSS_ANNOUNCE, COMBAT_SFX_DB, randf_range(0.97, 1.03))


func play_enemy_transition() -> void:
	_play(SFX_ENEMY_TRANSITION, COMBAT_SFX_DB, randf_range(0.92, 1.08))


func play_potion_heal() -> void:
	_play(SFX_POTION_HEAL, COMBAT_SFX_DB, randf_range(0.96, 1.04))


func play_colony_loss_tick() -> void:
	_play(SFX_COLONY_LOSS, -6.0, randf_range(0.97, 1.03))


func play_colony_growth_tick() -> void:
	_play(SFX_COLONY_GROWTH, -8.0, randf_range(0.92, 1.08))


func _play(path: String, volume_db: float, pitch_scale: float) -> void:
	var stream := _get_stream(path)
	if stream == null:
		return
	var player := _pick_player()
	if player == null:
		return
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()


func _get_stream(path: String) -> AudioStream:
	if _stream_cache.has(path):
		return _stream_cache[path] as AudioStream
	if not ResourceLoader.exists(path):
		push_warning("GameAudio: brak pliku %s" % path)
		return null
	var loaded := load(path) as AudioStream
	if loaded:
		_stream_cache[path] = loaded
	return loaded


func _pick_player() -> AudioStreamPlayer:
	for player in _players:
		if not player.playing:
			return player
	return _players[0]
