class_name IconLibrary
## Oyundaki tum ikonlar buradan alinir. res://art/icons/<id>.png, yoksa .svg kullanilir,
## yoksa kodla cizilen yedek ikon gelir. PixelLab gorselleri geldiginde kod degismez.

const DIR := "res://art/icons/%s.%s"

static var _cache := {}


static func get_icon(id: String, color: Color = Color(0.8, 0.5, 0.2)) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var tex: Texture2D = _placeholder(color)
	for ext: String in ["svg", "png"]: # png sonra gelir: PixelLab gorseli varsa ustun gelir
		var path := DIR % [id, ext]
		if ResourceLoader.exists(path):
			tex = load(path)
	_cache[id] = tex
	return tex


static func _placeholder(color: Color) -> Texture2D:
	const SIZE := 96
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var c := Vector2(SIZE, SIZE) * 0.5
	for y in SIZE:
		for x in SIZE:
			var p := Vector2(x, y) - c
			var d := (absf(p.x) + absf(p.y)) / (SIZE * 0.46) # baklava bicimi
			if d <= 1.0:
				img.set_pixel(x, y, color.lerp(Color.WHITE, (1.0 - d) * 0.65))
	return ImageTexture.create_from_image(img)
