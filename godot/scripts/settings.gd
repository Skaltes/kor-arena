class_name Settings
## Oyuncu ayarlari: ses, tam ekran, grafik kalitesi, titresim. Hepsi user://ayar.cfg dosyasinda durur.
## Dosya bir kez okunur, bellekte tutulur; her yazmada butun ayarlar birlikte kaydedilir, hicbiri silinmez.

const FILE := "user://ayar.cfg"
const QUALITY_NAMES: Array[String] = ["Otomatik", "Yüksek", "Düşük"] # otomatik: yavaslarsa kendiliginden duser
enum Quality { AUTO, HIGH, LOW }

static var _cfg: ConfigFile


static func _file() -> ConfigFile:
	if _cfg == null:
		_cfg = ConfigFile.new()
		_cfg.load(FILE)
	return _cfg


static func read(section: String, key: String, default: Variant) -> Variant:
	return _file().get_value(section, key, default)


static func write(section: String, key: String, value: Variant) -> void:
	_file().set_value(section, key, value)
	_file().save(FILE)


static func quality() -> int:
	return int(read("goruntu", "kalite", Quality.AUTO))


static func vibration() -> bool:
	return bool(read("oyun", "titresim", true))


static func fullscreen() -> bool:
	return DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]


static func set_fullscreen(on: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
	if not OS.has_feature("web"): # tarayicida tam ekran her acilista dokunusla istenir, saklanmaz
		write("goruntu", "tam_ekran", on)


## Acilista: bilgisayarda son tam ekran secimi geri gelir.
static func apply_window() -> void:
	if not OS.has_feature("web") and bool(read("goruntu", "tam_ekran", false)):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
