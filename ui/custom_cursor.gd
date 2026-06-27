extends Node
## Skalowany kursor systemowy — duży PNG zostaje w pełnej rozdzielczości, rozmiar w grze ustawiasz tutaj.

@export var cursor_texture: Texture2D = preload("res://ikony/cursor.png")
## Mnożnik rozmiaru (np. 0.25 = 25% oryginału). Nie zmienia pliku PNG.
@export_range(0.05, 2.0, 0.01) var cursor_scale: float = 0.22
## Punkt kliknięcia w pikselach ORYGINALNEJ tekstury (przed skalowaniem).
@export var hotspot: Vector2 = Vector2(12, 12)
@export var pixel_art: bool = false

var _scaled_tex: ImageTexture


func _ready() -> void:
	_apply_cursor()


func _apply_cursor() -> void:
	_scaled_tex = _build_scaled_texture()
	if _scaled_tex == null:
		return
	var scaled_hotspot := hotspot * cursor_scale
	Input.set_custom_mouse_cursor(_scaled_tex, Input.CURSOR_ARROW, scaled_hotspot)


func _build_scaled_texture() -> ImageTexture:
	if cursor_texture == null:
		return null
	var img: Image
	var path := cursor_texture.resource_path
	if path != "":
		var loaded := Image.new()
		if loaded.load(path) == OK:
			img = loaded
	if img == null:
		img = cursor_texture.get_image()
	if img == null or img.is_empty():
		push_warning("CustomCursor: nie udało się wczytać obrazu kursora.")
		return null
	var w := maxi(1, int(round(float(img.get_width()) * cursor_scale)))
	var h := maxi(1, int(round(float(img.get_height()) * cursor_scale)))
	var interp := Image.INTERPOLATE_NEAREST if pixel_art else Image.INTERPOLATE_LANCZOS
	img = img.duplicate()
	img.resize(w, h, interp)
	return ImageTexture.create_from_image(img)
