extends PanelContainer
## Tooltip zawsze nad kursorem (używany przez UIRoot._make_custom_tooltip).

const _MIN_WIDTH := 240.0
const _CURSOR_GAP := 16.0


func setup(for_text: String) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_level = true
	theme_type_variation = &"TooltipPanel"
	var lbl := Label.new()
	lbl.theme_type_variation = &"TooltipLabel"
	lbl.text = for_text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(_MIN_WIDTH, 0)
	add_child(lbl)


func _ready() -> void:
	call_deferred("_position_above_cursor")


func _process(_delta: float) -> void:
	_position_above_cursor()


func _position_above_cursor() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	reset_size()
	var mouse := vp.get_mouse_position()
	var vp_size := vp.get_visible_rect().size
	var x := clampf(mouse.x - size.x * 0.5, 8.0, vp_size.x - size.x - 8.0)
	var y := mouse.y - size.y - _CURSOR_GAP
	global_position = Vector2(x, maxf(8.0, y))
