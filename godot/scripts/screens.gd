class_name Screens
extends RefCounted
## Menu ve savas ustune acilan pencereler: ayarlar, nasil oynanir, yetenekler, basarimlar, emegi gecenler,
## sandik acilisi ve canli mac menusu. Hepsi Hud.overlay ile acilir, Esc ya da Kapat ile kapanir.

const HELP := [
	["SAVAŞ NASIL İŞLER", [
		"Savaşçın rakibe kendisi yürür, menzile girince normal saldırıyı kendisi yapar. Sen yalnızca yetenek kullanırsın: 1-8 tuşları ya da alttaki düğmeler.",
		"Mana yoktur. Her yeteneğin kendi bekleme süresi vardır ve bir yetenekten sonra 2 saniye ortak bekleme gelir. Her basış bir karardır.",
	]],
	["ZAMANLAMA", [
		"Yeteneklerin çoğu önce hazırlanır. Rakibin hazırlığı, can çubuğunun altındaki ince çubukta görünür.",
		"İnen her yetenek rakibi kısa bir an afallatır: hazırladığı yetenek boşa gider ve tam bekleme süresine girer. Önce vuran kazanır.",
		"Sersemletme ve kesme etkisi olan yetenekler rakibin hazırlığını yarıda bırakır.",
	]],
	["SAVUNMA", [
		"Siper yetenekleri (Kalkan Duvarı, Çapraz Siper, Buz Kolu) kısa süre bütün hasarı engeller ve ortak beklemeye takılmaz.",
		"Darbeden hemen önce basarsan savuşturursun: saldırı yarıda kesilir, rakip sarsılır.",
		"Titan'ın Buz Kolu karşı saldırıdır: açıkken bir yetenekle vuran rakip donar. Gırtlak Kavrama yalnızca hazırlanan rakibi yakalar, Buz Mührü ise zamanında bozulmazsa rakibi dondurur.",
	]],
	["ARENA VE GELİŞİM", [
		"Arenada kazanınca bir sonraki aşamaya geçersin. Her 5. aşamada Arena Efendisi bekler: çift ödül ve kesin ganimet.",
		"Tecrübe seviye getirir; seviye yeni yetenek ve stat puanı açar. Altınla sandık açar, demircide giydiğin eşyayı güçlendirirsin.",
		"Her gün giriş ödülü ve günlük görev (3 galibiyet) yenilenir. Başarımlar ek altın verir.",
	]],
	["CANLI MAÇ", [
		"Hızlı Maç rastgele bir rakip arar. Oda Aç ile arkadaşına 6 harfli kod gönderirsin.",
		"Canlı maçta herkes eşittir: 8. seviye, bütün yetenekler açık; eşya ve puan sayılmaz. Kazanmak tecrübe ve altın getirir.",
	]],
	["TUŞLAR", [
		"1-8: yetenekler · Esc: menü, duraklat ve pencere kapatma · Boşluk: duraklat (yapay zekâ maçında)",
	]],
]
const CREDITS := [
	"Godot Engine: MIT lisansı",
	"Karakterler ve animasyonlar: Quaternius (CC0)",
	"Hareketler: Mixamo (Adobe), oyun içinde kullanım serbest",
	"Paladin modeli: \"Medieval Knight | Sculpture | Game ready\", by__Rx (Sketchfab, CC BY 4.0)",
	"Titan modeli: \"Paladin\", DJMaesen (Sketchfab, CC BY 4.0)",
	"Berserker modeli: \"Armored Warrior - Game Asset\", kanesk06 (Sketchfab, CC BY 4.0)",
	"Yetenek simgeleri: game-icons.net, Lorc, Delapouite (CC BY 3.0)",
	"Dokular ve gökyüzü: Poly Haven (CC0)",
	"Müzik: emmama, spring-spring, tad (OpenGameArt, CC0)",
	"Ses efektleri: Kenney, starninjas, artisticdude (CC0)",
	"Yazı tipleri: Cinzel ve Alegreya (SIL Open Font License)",
	"Zırh, silah, ikon, arayüz ve bazı sesler bu oyun için üretildi.",
]

var h: Hud


func _init(hud: Hud) -> void:
	h = hud


func _box(title: String, width: float) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.custom_minimum_size.x = width
	var t := h._label(title, 30, Hud.GOLD, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	return v


func _text(text: String, size: int, color := Hud.PALE) -> Label:
	var l := h._small(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _close(v: VBoxContainer, text := "Kapat") -> void:
	var b := h._button(text, 17)
	b.pressed.connect(func() -> void: h.close_overlay())
	v.add_child(b)


## Uzun icerik ekran boyunu asmasin: kaydirilir, telefonda da sigar.
func _scroll(content: Control, height: float) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.custom_minimum_size.y = height
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(content)
	return s


func settings() -> void:
	var v := _box("AYARLAR", 460)
	v.add_child(h._volume_row("Müzik", true))
	v.add_child(h._volume_row("Efekt", false))
	if not OS.has_feature("web") or Version.phone():
		var full := h._button("", 17)
		full.text = "Tam Ekran: %s" % ("Açık" if Settings.fullscreen() else "Kapalı")
		full.pressed.connect(func() -> void:
			Settings.set_fullscreen(not Settings.fullscreen())
			full.text = "Tam Ekran: %s" % ("Açık" if Settings.fullscreen() else "Kapalı"))
		v.add_child(full)
	var quality := h._button("Grafik: %s" % Settings.QUALITY_NAMES[Settings.quality()], 17)
	var note := _text("", 14, Hud.MUTED)
	quality.pressed.connect(func() -> void:
		var q := (Settings.quality() + 1) % Settings.QUALITY_NAMES.size()
		Settings.write("goruntu", "kalite", q)
		quality.text = "Grafik: %s" % Settings.QUALITY_NAMES[q]
		note.text = "Düşükten yükseğe geçiş oyun yeniden açılınca olur." if q != Settings.Quality.LOW else ""
		h.quality_changed.emit())
	v.add_child(quality)
	v.add_child(note)
	if Version.phone():
		var shake := h._button("Titreşim: %s" % ("Açık" if Settings.vibration() else "Kapalı"), 17)
		shake.pressed.connect(func() -> void:
			Settings.write("oyun", "titresim", not Settings.vibration())
			shake.text = "Titreşim: %s" % ("Açık" if Settings.vibration() else "Kapalı"))
		v.add_child(shake)
	var credits := h._button("Emeği Geçenler", 15)
	credits.pressed.connect(show_credits)
	v.add_child(credits)
	_close(v)
	h.overlay(v)


func help() -> void:
	var v := _box("NASIL OYNANIR", 780)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	for part: Array in HELP:
		body.add_child(h._small(part[0], 19, Hud.GOLD, true))
		for line: String in part[1]:
			body.add_child(_text("• " + line, 16))
	v.add_child(_scroll(body, 430))
	_close(v, "Anladım")
	h.overlay(v)


## Yetenek kitabi: her sinifin butun yetenekleri, kilitliler de gorunur. Telefonda ipucu kutusu olmadigi icin tek yer burasi.
func skills(cls: String, level: int) -> void:
	var v := _box("YETENEKLER", 720)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	var fill := func(pick: String) -> void:
		for c in list.get_children():
			c.queue_free()
		var ids: Array = GameData.CLASSES[pick]["skills"]
		for i in ids.size():
			list.add_child(_skill_row(i, ids[i], pick, level))
		for b: Button in tabs.get_children():
			b.modulate = Color.WHITE if b.get_meta("cls") == pick else Color(1, 1, 1, 0.55)
	for c: String in GameData.CLASSES:
		var b := h._button(GameData.CLASSES[c]["name"], 16)
		b.add_theme_font_override("font", h._body_font)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set_meta("cls", c)
		b.pressed.connect(func() -> void: fill.call(c))
		tabs.add_child(b)
	v.add_child(tabs)
	v.add_child(_scroll(list, 400))
	_close(v)
	h.overlay(v)
	fill.call(cls)


func _skill_row(i: int, id: String, cls: String, level: int) -> Control:
	var k: Dictionary = GameData.SKILLS[id]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var pic := TextureRect.new()
	pic.texture = IconLibrary.get_icon(id, GameData.CLASSES[cls]["color"].lightened(0.25))
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.custom_minimum_size = Vector2(56, 56)
	pic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var locked := int(k["unlock"]) > level
	pic.modulate = Color(1, 1, 1, 0.4) if locked else Color.WHITE
	row.add_child(pic)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(h._small("%d · %s" % [i + 1, k["name"]], 18, Hud.MUTED if locked else Hud.GOLD))
	var meta := "Bekleme %d sn" % int(k["cd"])
	if float(k.get("windup", 0.0)) > 0.0:
		meta += " · Hazırlık %s sn" % str(snappedf(float(k["windup"]), 0.05)).replace(".", ",")
	if k["kind"] == "guard":
		meta += " · Ortak beklemeye takılmaz"
	if locked:
		meta += " · %d. seviyede açılır" % int(k["unlock"])
	text.add_child(h._small(meta, 14, Hud.MUTED))
	text.add_child(_text(k["desc"], 15))
	row.add_child(text)
	return row


func achievements(p: Profile) -> void:
	var v := _box("BAŞARIMLAR %d/%d" % [p.done.size(), GameData.ACHIEVEMENTS.size()], 640)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	for a: Dictionary in GameData.ACHIEVEMENTS:
		var got := p.done.has(a["id"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var text := VBoxContainer.new()
		text.add_theme_constant_override("separation", 0)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_child(h._small(("✓ " if got else "") + a["name"], 18, Hud.GOLD if got else Hud.PALE))
		text.add_child(h._small(a["desc"], 14, Hud.MUTED))
		row.add_child(text)
		var right := VBoxContainer.new()
		right.custom_minimum_size.x = 150
		right.add_theme_constant_override("separation", 2)
		right.add_child(h._small("+%d Altın" % a["gold"], 15, Hud.GOLD if got else Hud.MUTED))
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size.y = 8
		bar.max_value = float(a["goal"])
		bar.value = minf(float(p.stat(a["stat"])), float(a["goal"]))
		bar.add_theme_stylebox_override("fill", h._line_box(Hud.GOLD if got else Color(0.6, 0.45, 0.2), Hud.BRONZE, 0))
		bar.add_theme_stylebox_override("background", h._line_box(Hud.BAR_BACK, Hud.BRONZE, 1))
		right.add_child(bar)
		right.add_child(h._small("%d/%d" % [mini(p.stat(a["stat"]), int(a["goal"])), a["goal"]], 13, Hud.MUTED))
		row.add_child(right)
		list.add_child(row)
	v.add_child(_scroll(list, 430))
	_close(v)
	h.overlay(v)


func show_credits() -> void:
	var v := _box("EMEĞİ GEÇENLER", 560)
	for line: String in CREDITS:
		v.add_child(_text(line, 16))
	v.add_child(_text("Lisans metinleri oyun dosyalarının içindedir (assets/fonts/OFL.txt ve LISANS_CC0.txt).", 13, Hud.MUTED))
	_close(v)
	h.overlay(v)


## Sandiktan cikan esya: nadirlik rengiyle buyur, giyilene gore farki gosterir, hemen giyilebilir ya da satilabilir.
func reveal(p: Profile, it: Dictionary, on_done: Callable) -> void:
	var v := _box("SANDIK", 460)
	var card := h.item_card(it, p.equipped[it["slot"]])
	v.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var done_with := func(action: String) -> void:
		var index := h.bag_index(it)
		if index >= 0 and action == "wear":
			p.equip(index)
		elif index >= 0 and action == "sell":
			p.sell(index)
		h.close_overlay()
		on_done.call()
	var wear := h._button("Giy", 17)
	wear.pressed.connect(done_with.bind("wear"))
	var sell := h._button("Sat %d" % Rules.sell_price(it), 17)
	sell.pressed.connect(done_with.bind("sell"))
	var keep := h._button("Çantaya Koy", 17)
	keep.pressed.connect(done_with.bind("keep"))
	for b: Button in [wear, sell, keep]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	v.add_child(row)
	var shown := h.overlay(v)
	shown.set_meta("on_close", on_done)
	card.pivot_offset = card.get_combined_minimum_size() / 2.0
	card.scale = Vector2.ONE * 0.4
	card.modulate = Color(3, 3, 3)
	var tw := h.create_tween().set_parallel()
	tw.tween_property(card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate", Color.WHITE, 0.45)
	SoundBank.me.play("loot")
	if int(it["rarity"]) >= 3:
		SoundBank.me.play("ring")


## Canli macta oyun durmaz; yine de ayarlara bakmak ya da maci birakmak icin.
func online_menu(cls: String) -> void:
	var v := _box("MENÜ", 380)
	var settings_b := h._button("Ayarlar", 17)
	settings_b.pressed.connect(settings)
	v.add_child(settings_b)
	var book := h._button("Yetenekler", 17)
	book.pressed.connect(func() -> void: skills(cls, GameMain.TEST_LEVEL))
	v.add_child(book)
	var leave := h._button("Maçtan Ayrıl", 17)
	leave.pressed.connect(func() -> void:
		if leave.text != "Emin misin? Yenilgi sayılır":
			leave.text = "Emin misin? Yenilgi sayılır"
			return
		h.close_overlay()
		h.leave_match.emit())
	v.add_child(leave)
	_close(v, "Geri Dön")
	h.overlay(v)
