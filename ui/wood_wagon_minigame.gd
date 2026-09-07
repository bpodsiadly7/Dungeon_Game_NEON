extends Control
class_name WoodWagonMinigame

signal finished(caught: int)

const FONT_PATH := "res://MedievalSharp-Bold.ttf"
const WOOD_PATH := "res://resources/wood.png"

const BOARD_COUNT := 20
## Większy hitbox niż sama grafika — łatwiej trafić w ruchu.
const HIT_SIZE := 132.0
const BOARD_VISUAL_SIZE := 96.0
const FALL_SPEED_MIN := 420.0
const FALL_SPEED_MAX := 620.0
const SPAWN_INTERVAL_MIN := 0.22
const SPAWN_INTERVAL_MAX := 0.40
const RESULT_HOLD_SEC := 1.05
const MARGIN_X := 40.0

var _active := false
var _finished := false
var _caught := 0
var _resolved := 0
var _spawned := 0
var _font: FontFile
var _wood_tex: Texture2D
var _hint_label: Label
var _score_label: Label
var _result_label: Label
var _play_area: Control
var _boards: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 550
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = load(FONT_PATH) as FontFile
	_wood_tex = load(WOOD_PATH) as Texture2D
	_build_ui()
	set_process(false)


func _enter_tree() -> void:
	_fit_to_viewport()
	var vp := get_viewport()
	if vp and not vp.size_changed.is_connected(_fit_to_viewport):
		vp.size_changed.connect(_fit_to_viewport)


func _exit_tree() -> void:
	var vp := get_viewport()
	if vp and vp.size_changed.is_connected(_fit_to_viewport):
		vp.size_changed.disconnect(_fit_to_viewport)


func _fit_to_viewport() -> void:
	var vp := get_viewport_rect().size
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = vp.x
	offset_bottom = vp.y
	position = Vector2.ZERO
	size = vp


func run() -> int:
	_active = true
	_finished = false
	_caught = 0
	_resolved = 0
	_spawned = 0
	_boards.clear()
	_fit_to_viewport()
	await _wait_always(0.0)
	_fit_to_viewport()
	_update_score()
	if _hint_label:
		_hint_label.text = "Click the falling wood before it hits the ground!"
		_hint_label.visible = true
	if _result_label:
		_result_label.visible = false
	set_process(true)
	_spawn_loop()
	await finished
	return _caught


func _wait_always(sec: float) -> void:
	await get_tree().create_timer(sec, true).timeout


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.04, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_play_area = Control.new()
	_play_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_play_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_play_area)

	var hud := VBoxContainer.new()
	hud.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hud.anchor_left = 0.0
	hud.anchor_right = 1.0
	hud.anchor_top = 0.0
	hud.anchor_bottom = 0.0
	hud.offset_top = 28.0
	hud.offset_bottom = 140.0
	hud.offset_left = 24.0
	hud.offset_right = -24.0
	hud.add_theme_constant_override("separation", 6)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)

	var title := Label.new()
	title.text = "WOOD WAGON"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.92, 0.78, 0.42))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _font:
		title.add_theme_font_override("font", _font)
	hud.add_child(title)

	_hint_label = Label.new()
	_hint_label.text = "Click the falling wood before it hits the ground!"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 15)
	_hint_label.add_theme_color_override("font_color", Color(0.78, 0.72, 0.62))
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _font:
		_hint_label.add_theme_font_override("font", _font)
	hud.add_child(_hint_label)

	_score_label = Label.new()
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.add_theme_font_size_override("font_size", 22)
	_score_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.68))
	_score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _font:
		_score_label.add_theme_font_override("font", _font)
	hud.add_child(_score_label)

	_result_label = Label.new()
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", 26)
	_result_label.add_theme_color_override("font_color", Color(0.55, 0.95, 0.55))
	_result_label.visible = false
	_result_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _font:
		_result_label.add_theme_font_override("font", _font)
	hud.add_child(_result_label)

	_update_score()


func _update_score() -> void:
	if _score_label == null:
		return
	_score_label.text = "Caught: %d / %d" % [_caught, BOARD_COUNT]


func _spawn_loop() -> void:
	while _active and not _finished and _spawned < BOARD_COUNT:
		_spawn_board()
		if _spawned >= BOARD_COUNT:
			break
		await _wait_always(randf_range(SPAWN_INTERVAL_MIN, SPAWN_INTERVAL_MAX))


func _spawn_board() -> void:
	if not _active or _finished or _play_area == null:
		return
	var area_size := _play_area.size
	if area_size.x <= 1.0 or area_size.y <= 1.0:
		area_size = size

	## Duży niewidoczny hitbox (bez rotacji) + obrócona grafika w środku.
	var hit := Button.new()
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.mouse_filter = Control.MOUSE_FILTER_STOP
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit.custom_minimum_size = Vector2(HIT_SIZE, HIT_SIZE)
	hit.size = Vector2(HIT_SIZE, HIT_SIZE)
	hit.pivot_offset = Vector2(HIT_SIZE * 0.5, HIT_SIZE * 0.5)
	hit.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	hit.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	hit.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	hit.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	hit.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())

	var icon := TextureRect.new()
	icon.texture = _wood_tex
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(BOARD_VISUAL_SIZE, BOARD_VISUAL_SIZE)
	icon.size = Vector2(BOARD_VISUAL_SIZE, BOARD_VISUAL_SIZE)
	icon.position = Vector2(
		(HIT_SIZE - BOARD_VISUAL_SIZE) * 0.5,
		(HIT_SIZE - BOARD_VISUAL_SIZE) * 0.5
	)
	icon.pivot_offset = Vector2(BOARD_VISUAL_SIZE * 0.5, BOARD_VISUAL_SIZE * 0.5)
	icon.rotation = deg_to_rad(randf_range(-28.0, 28.0))
	icon.modulate = Color(1.0, 1.0, 1.0, 0.0)
	hit.add_child(icon)

	var max_x := maxf(area_size.x - HIT_SIZE - MARGIN_X, MARGIN_X)
	var x := randf_range(MARGIN_X, max_x)
	hit.position = Vector2(x, -HIT_SIZE - randf_range(0.0, 40.0))
	_play_area.add_child(hit)

	var entry := {
		"node": hit,
		"icon": icon,
		"speed": randf_range(FALL_SPEED_MIN, FALL_SPEED_MAX),
		"alive": true,
	}
	_boards.append(entry)
	_spawned += 1

	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(icon, "modulate:a", 1.0, 0.08)

	hit.pressed.connect(_catch_board.bind(entry))


func _catch_board(entry: Dictionary) -> void:
	if not _active or _finished:
		return
	if not bool(entry.get("alive", false)):
		return
	entry["alive"] = false
	_caught += 1
	_resolved += 1
	_update_score()

	var board: Control = entry.get("node") as Control
	if board == null or not is_instance_valid(board):
		_check_complete()
		return

	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if board is BaseButton:
		(board as BaseButton).disabled = true

	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_BACK)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(board, "scale", Vector2(1.2, 1.2), 0.12)
	tw.tween_property(board, "modulate:a", 0.0, 0.12)
	tw.chain().tween_callback(func():
		if is_instance_valid(board):
			board.queue_free()
	)
	_check_complete()


func _miss_board(entry: Dictionary) -> void:
	if not bool(entry.get("alive", false)):
		return
	entry["alive"] = false
	_resolved += 1

	var board: Control = entry.get("node") as Control
	if board != null and is_instance_valid(board):
		board.queue_free()
	_check_complete()


func _process(delta: float) -> void:
	if not _active or _finished:
		return
	var bottom := size.y + HIT_SIZE + 8.0
	for entry in _boards:
		if not bool(entry.get("alive", false)):
			continue
		var board: Control = entry.get("node") as Control
		if board == null or not is_instance_valid(board):
			entry["alive"] = false
			_resolved += 1
			_check_complete()
			continue
		board.position.y += float(entry.get("speed", FALL_SPEED_MIN)) * delta
		var icon: Control = entry.get("icon") as Control
		if icon != null and is_instance_valid(icon):
			icon.rotation += deg_to_rad(22.0) * delta * signf(icon.rotation + 0.001)
		if board.position.y >= bottom:
			_miss_board(entry)


func _check_complete() -> void:
	if _finished:
		return
	if _spawned < BOARD_COUNT:
		return
	if _resolved < BOARD_COUNT:
		return
	_finish_sequence()


func _finish_sequence() -> void:
	if _finished:
		return
	_finished = true
	_active = false
	set_process(false)

	if _hint_label:
		_hint_label.visible = false
	if _result_label:
		_result_label.text = "Gathered %d wood!" % _caught
		_result_label.visible = true

	await _wait_always(RESULT_HOLD_SEC)
	finished.emit(_caught)
