extends Control
## Acilis ekrani: yeni surum varsa indirir, exe'yi degistirir ve oyunu yeniden baslatir.
## Internet yoksa ya da bir sey ters giderse oyun oldugu gibi acilir; guncelleme oyunu asla engellemez.

const GAME := "res://scenes/main.tscn"
const CHECK_TIMEOUT := 6.0
const ZIP_PATH := "user://guncelleme.zip"
const PHONE_UI := 1.4 # kucuk ekranda arayuz parmakla basilacak boyda olsun

var _http: HTTPRequest
var _text: Label
var _bar: ProgressBar
var _downloading := false


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.03, 0.025)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(460, 90)
	box.position = Vector2(-230, -45)
	add_child(box)
	_text = Label.new()
	_text.text = "Kor Arena açılıyor..."
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.add_theme_font_size_override("font_size", 22)
	_text.add_theme_color_override("font_color", Color(0.93, 0.74, 0.38))
	box.add_child(_text)
	_bar = ProgressBar.new()
	_bar.visible = false
	box.add_child(_bar)

	if Version.phone():
		get_window().content_scale_factor = PHONE_UI
	if OS.get_cmdline_user_args().is_empty(): # gelistirici testleri pencere boyunu kendisi secer
		Settings.apply_window()
	# Web surumunde guncelleme yok: sayfa her acilista son yayini getirir
	if OS.has_feature("web"):
		_start_game.call_deferred()
		return
	var exe := OS.get_executable_path()
	if FileAccess.file_exists(exe + ".eski"):
		DirAccess.remove_absolute(exe + ".eski")
	# Editorden ya da test parametreleriyle acilista guncelleme denenmez
	if not OS.has_feature("template") or not OS.get_cmdline_user_args().is_empty() or Version.REPO == "":
		_start_game.call_deferred()
		return
	_http = HTTPRequest.new()
	_http.max_redirects = 8
	_http.timeout = CHECK_TIMEOUT
	add_child(_http)
	_http.request_completed.connect(_on_version)
	if _http.request(Version.url("surum.txt")) != OK:
		_start_game.call_deferred()


func _start_game() -> void:
	get_tree().change_scene_to_file(GAME)


func _on_version(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_http.request_completed.disconnect(_on_version)
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_start_game()
		return
	var remote := body.get_string_from_utf8().strip_edges()
	if not remote.is_valid_int() or int(remote) <= Version.BUILD:
		_start_game()
		return
	_text.text = "Yeni sürüm indiriliyor..."
	_bar.visible = true
	_downloading = true
	_http.timeout = 0.0
	_http.download_file = ZIP_PATH
	_http.request_completed.connect(_on_zip)
	if _http.request(Version.url("KorArena.zip")) != OK:
		_start_game()


func _process(_delta: float) -> void:
	if _downloading and _http.get_body_size() > 0:
		_bar.value = 100.0 * _http.get_downloaded_bytes() / _http.get_body_size()


func _on_zip(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_downloading = false
	if result == HTTPRequest.RESULT_SUCCESS and code == 200 and _install():
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ZIP_PATH))
	_start_game()


## Calisan exe silinemez ama adi degistirilebilir: yenisi yerine yazilir, eskisi sonraki acilista silinir.
func _install() -> bool:
	_text.text = "Güncelleme kuruluyor..."
	var zip := ZIPReader.new()
	if zip.open(ZIP_PATH) != OK or not zip.file_exists("KorArena.exe"):
		return false
	var data := zip.read_file("KorArena.exe")
	zip.close()
	if data.size() < 10000000:
		return false
	var exe := OS.get_executable_path()
	if DirAccess.rename_absolute(exe, exe + ".eski") != OK:
		return false
	var f := FileAccess.open(exe, FileAccess.WRITE)
	if f == null:
		DirAccess.rename_absolute(exe + ".eski", exe)
		return false
	f.store_buffer(data)
	f.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ZIP_PATH))
	OS.create_process(exe, [])
	get_tree().quit()
	return true
