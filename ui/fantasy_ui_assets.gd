class_name FantasyUiAssets
extends RefCounted
## Kenney Fantasy UI Borders (PNG/Double) — 9-slice dla paneli RPG.

const ROOT := "res://PNG/Double/"
## Grubość ozdobnej ramki w assetach 96x96.
const PATCH := 32
## Odstęp treści od krawędzi panelu (musi być >= grubość ramki).
const PAD_SHELL := 24
const PAD_SECTION := 36
const PAD_SECTION_LOOSE := 44
const PAD_SECTION_COMPACT := 24
const PAD_TITLE := 18
const PAD_TITLE_LOOSE := 22
const PAD_BUTTON := 14
const PATCH_SLOT := 22
const PAD_SLOT := 8

const TINT_FRAME := Color(0.40, 0.33, 0.26, 1.0)
const TINT_FILL_DARK := Color(0.11, 0.09, 0.07, 1.0)
const TINT_FILL_SECTION := Color(0.16, 0.13, 0.10, 1.0)
const TINT_HEADER := Color(0.18, 0.15, 0.11, 1.0)
const TINT_BTN := Color(0.22, 0.18, 0.14, 1.0)
const TINT_BTN_HOVER := Color(0.30, 0.25, 0.19, 1.0)
const TINT_BTN_PRESSED := Color(0.10, 0.08, 0.06, 1.0)
const TINT_DIVIDER := Color(0.34, 0.29, 0.22, 0.88)
const TINT_SLIDER_TRACK := Color(0.14, 0.11, 0.09, 1.0)
const TINT_SLIDER_FILL := Color(0.38, 0.30, 0.22, 1.0)


static func _tex(relative_path: String) -> Texture2D:
	return load(ROOT + relative_path) as Texture2D


static func stylebox(
	relative_path: String,
	tint: Color,
	margin: int = PATCH,
	draw_center: bool = true,
	content_pad: int = 12
) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = _tex(relative_path)
	sb.texture_margin_left = margin
	sb.texture_margin_top = margin
	sb.texture_margin_right = margin
	sb.texture_margin_bottom = margin
	sb.modulate_color = tint
	sb.draw_center = draw_center
	sb.content_margin_left = content_pad
	sb.content_margin_right = content_pad
	sb.content_margin_top = content_pad
	sb.content_margin_bottom = content_pad
	return sb


static func shell_border() -> StyleBoxTexture:
	var sb := stylebox("Transparent border/panel-transparent-border-000.png", TINT_FRAME, PATCH, false, 0)
	sb.expand_margin_left = 2
	sb.expand_margin_top = 2
	sb.expand_margin_right = 2
	sb.expand_margin_bottom = 2
	return sb


static func shell_fill() -> StyleBoxTexture:
	return stylebox("Transparent center/panel-transparent-center-000.png", TINT_FILL_DARK, PATCH, true, PAD_SHELL)


static func section_box() -> StyleBoxTexture:
	return stylebox("Panel/panel-015.png", TINT_FILL_SECTION, PATCH, true, PAD_SECTION)


static func section_box_loose() -> StyleBoxTexture:
	return stylebox("Panel/panel-015.png", TINT_FILL_SECTION, PATCH, true, PAD_SECTION_LOOSE)


static func section_box_compact() -> StyleBoxTexture:
	return stylebox("Panel/panel-015.png", TINT_FILL_SECTION, PATCH, true, PAD_SECTION_COMPACT)


static func title_panel() -> StyleBoxTexture:
	return stylebox("Panel/panel-015.png", TINT_HEADER, PATCH, true, PAD_TITLE)


static func title_panel_loose() -> StyleBoxTexture:
	return stylebox("Panel/panel-015.png", TINT_HEADER, PATCH, true, PAD_TITLE_LOOSE)


static func button_normal() -> StyleBoxTexture:
	return stylebox("Panel/panel-001.png", TINT_BTN, PATCH, true, PAD_BUTTON)


static func button_hover() -> StyleBoxTexture:
	return stylebox("Panel/panel-001.png", TINT_BTN_HOVER, PATCH, true, PAD_BUTTON)


static func button_pressed() -> StyleBoxTexture:
	return stylebox("Panel/panel-001.png", TINT_BTN_PRESSED, PATCH, true, PAD_BUTTON)


static func slider_track() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = TINT_SLIDER_TRACK
	sb.border_color = TINT_DIVIDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(1)
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	return sb


static func slider_fill() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = TINT_SLIDER_FILL
	sb.set_corner_radius_all(1)
	return sb


static func slot_panel(tint: Color = TINT_FILL_SECTION) -> StyleBoxTexture:
	return stylebox("Panel/panel-015.png", tint, PATCH_SLOT, true, PAD_SLOT)


static func close_button_normal() -> StyleBoxTexture:
	return stylebox("Panel/panel-001.png", Color(0.32, 0.1, 0.08), PATCH_SLOT, true, 8)


static func close_button_hover() -> StyleBoxTexture:
	return stylebox("Panel/panel-001.png", Color(0.45, 0.14, 0.1), PATCH_SLOT, true, 8)


static func center_panel() -> StyleBoxTexture:
	return stylebox("Transparent center/panel-transparent-center-000.png", Color(0.1, 0.08, 0.06), PATCH, true, 16)


static func tinted_button(base: Color, hover: Color) -> Array[StyleBoxTexture]:
	return [
		stylebox("Panel/panel-001.png", base, PATCH_SLOT, true, 8),
		stylebox("Panel/panel-001.png", hover, PATCH_SLOT, true, 8),
	]
