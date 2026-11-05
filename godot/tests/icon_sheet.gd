extends SceneTree
## Tum yetenek simgelerini tek resimde gosterir (kontrol icin). Kullanim: --script res://tests/icon_sheet.gd -- <cikti.png>
func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var ids: Array = []
	for cls: String in GameData.CLASSES:
		ids.append_array(GameData.CLASSES[cls]["skills"])
	var sheet := Image.create(96 * 8, 96 * 3, false, Image.FORMAT_RGBA8)
	for i in ids.size():
		var img: Image = IconLibrary.get_icon(ids[i]).get_image()
		img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		img.resize(96, 96)
		sheet.blit_rect(img, Rect2i(0, 0, 96, 96), Vector2i((i % 8) * 96, (i / 8) * 96))
	sheet.save_png(out)
	quit()
