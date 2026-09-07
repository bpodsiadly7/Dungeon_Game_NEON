extends Control
## Korzeń UI — wspólne tooltipy nad kursorem dla wszystkich dzieci.

const _TOOLTIP_PANEL := preload("res://ui/custom_tooltip_panel.gd")


func _make_custom_tooltip(for_text: String) -> Object:
	if for_text.is_empty():
		return null
	var panel: PanelContainer = _TOOLTIP_PANEL.new()
	if theme:
		panel.theme = theme
	panel.setup(for_text)
	return panel
