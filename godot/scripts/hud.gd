class_name Hud
extends CanvasLayer
## MMORPG tarzi arayuz: sinif kartlari, oyuncu cerceveleri, yetenek cubugu, oda ve sonuc ekranlari.
## Gorseller art/ui/ icindeki SVG'lerdir; PixelLab gorselleri ayni adlarla degistirilebilir.

signal play_ai(cls: String, player_name: String)
signal host_room(cls: String, player_name: String)
signal join_room(cls: String, player_name: String, code: String)
signal cancel_online
signal class_changed(cls: String)
signal skill_pressed(id: String)
signal rematch
signal forfeit
signal pause_pressed
signal restart_pressed # aninda yeniden baslatma (R tusu / duraklatma menusu)
signal character_closed
signal quick_match(cls: String, player_name: String)
signal bot_match
signal test_mode(cls: String, player_name: String)
signal test_action(what: String)
signal leave_match # canli macta oyuncu kendi istegiyle ayrilir
signal quality_changed
signal back

const GOLD := Color(0.93, 0.74, 0.38)
const PALE := Color(0.95, 0.9, 0.82)
const MUTED := Color(0.78, 0.72, 0.62)
const BRONZE := Color(0.5, 0.36, 0.17)
const BAR_BACK := Color(0.03, 0.025, 0.02, 0.9)
const PHONE_SLOT := 96.0 # telefonda yetenek yuvasi, parmak ucu boyunda
const ROLES := {"warrior": "Dengeli · Kalkan", "assassin": "Hızlı · Çift Balta", "brute": "Yavaş · İki Elli Balyoz"}
const VIGNETTE := """
shader_type canvas_item;
void fragment() {
	float d = distance(UV, vec2(0.5));
	COLOR = vec4(0.03, 0.015, 0.01, smoothstep(0.42, 0.82, d) * 0.72);
}
"""
const ROUND := """
shader_type canvas_item;
void fragment() {
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= 1.0 - smoothstep(0.47, 0.5, distance(UV, vec2(0.5)));
}
"""

var _root: Control
var _bars := {}
var _skills: Array[Dictionary] = []
var _test_box: Control
var _selected := "warrior"
var _name_edit: LineEdit
var _lobby_box: VBoxContainer
var _result_note: Label
var _cast := {}
var _my_cast: Control
var _result_won := false
var _result_offline := true
var _title_font: FontVariation
var _body_font: FontVariation
var forfeit_button: Button
var record_text := ""
var ai_text := "Yapay Zekâya Karşı"
var again_text := "Tekrar Savaş"
var _pause_box: Control
var profile: Profile
var name_memo := ""
var screens: Screens
var _overlays: Array[Control] = []
var _result_info := {}
var _status_cache := {}


func _ready() -> void:
	var cinzel: FontFile = load("res://assets/fonts/Cinzel-Variable.ttf")
	_title_font = FontVariation.new()
	_title_font.base_font = cinzel
	_title_font.variation_opentype = {"wght": 700}
	var alegreya: FontFile = load("res://assets/fonts/Alegreya-Variable.ttf")
	_body_font = FontVariation.new()
	_body_font.base_font = alegreya
	_body_font.variation_opentype = {"wght": 500}
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = Theme.new()
	_root.theme.default_font = _body_font
	add_child(_root)
	screens = Screens.new(self)


func _clear() -> void:
	for c in _root.get_children():
		c.queue_free()
	_skills.clear()
	_overlays.clear()
	_status_cache.clear()
	var v := ColorRect.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = VIGNETTE
	mat.shader = sh
	v.material = mat
	_root.add_child(v)


func _ui(name_: String, margin: float) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = load("res://art/ui/%s.svg" % name_)
	s.set_texture_margin_all(margin)
	return s


func _panel_style() -> StyleBoxTexture:
	var s := _ui("panel", 30.0)
	s.set_content_margin_all(26.0)
	return s


func _button(text: String, size: int = 20) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE # Bosluk tusu dugmeye basmasin
	b.pressed.connect(func() -> void: SoundBank.me.play("click"))
	b.add_theme_font_override("font", _title_font)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", PALE)
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.7))
	var n := _ui("button", 18.0)
	n.set_content_margin_all(13.0)
	n.content_margin_left = 22.0
	n.content_margin_right = 22.0
	var h: StyleBoxTexture = n.duplicate()
	h.texture = load("res://art/ui/button_hover.svg")
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	return b


func _label(text: String, size: int, color := PALE, title := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if title:
		l.add_theme_font_override("font", _title_font)
	l.add_theme_constant_override("outline_size", 7)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.0, 0.9))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _anchored(c: Control, preset: Control.LayoutPreset, offset := Vector2.ZERO) -> void:
	_root.add_child(c)
	c.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE)
	c.position += offset


func _name_text() -> String:
	var t := _name_edit.text.strip_edges()
	return t if t != "" else "Şampiyon"


func _edit(text: String, hint: String, width: int) -> LineEdit:
	var e := LineEdit.new()
	e.text = text
	e.placeholder_text = hint
	e.custom_minimum_size = Vector2(width, 50)
	e.add_theme_font_size_override("font_size", 19)
	var s := _ui("bar_back", 10.0)
	s.set_content_margin_all(12.0)
	e.add_theme_stylebox_override("normal", s)
	e.add_theme_stylebox_override("focus", s)
	e.add_theme_color_override("font_color", PALE)
	return e


func _portrait(cls: String, size: int) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(size, size)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path := "res://art/portraits/%s.png" % cls
	if ResourceLoader.exists(path):
		var pic := TextureRect.new()
		pic.texture = load(path)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.set_anchors_preset(Control.PRESET_FULL_RECT)
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = ROUND
		mat.shader = sh
		pic.material = mat
		box.add_child(pic)
	var ring := TextureRect.new()
	ring.texture = load("res://art/ui/ring.svg")
	ring.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(ring)
	return box


func _class_card(cls: String, selected: String, on_pick: Callable = Callable(), width: float = 270.0) -> Control:
	var c: Dictionary = GameData.CLASSES[cls]
	var on := cls == selected
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(width, 112)
	var s := _ui("card_on" if on else "card", 22.0)
	b.add_theme_stylebox_override("normal", s)
	b.add_theme_stylebox_override("hover", _ui("card_on", 22.0))
	b.add_theme_stylebox_override("pressed", _ui("card_on", 22.0))
	if on_pick.is_valid():
		b.pressed.connect(on_pick.bind(cls))
	else:
		b.pressed.connect(func() -> void:
			class_changed.emit(cls)
			show_select(cls, _name_edit.text))
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 16
	row.offset_right = -12
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pic := _portrait(cls, 72)
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pic)
	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 1)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(_label(c["name"], 24, GOLD if on else PALE)) # Cinzel kucuk harf cizmez: sinif adlari normal yaziyla
	text.add_child(_label(ROLES[cls], 15, MUTED))
	row.add_child(text)
	b.add_child(row)
	return b


## Yan yana esit genislikte dugmeler.
func _row(buttons: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for b: Control in buttons:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	return row


func _menu_button(text: String, action: Callable, size: int = 17) -> Button:
	var b := _button(text, size)
	b.pressed.connect(action)
	return b


## Ince cubuk: tecrube, basarim ilerlemesi gibi her yerde ayni gorunsun.
func _thin_bar(value: float, color: Color, height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = height
	bar.step = 0.01
	bar.value = value
	bar.add_theme_stylebox_override("fill", _flat_tex(_gradient(color.lightened(0.25), color.darkened(0.35))))
	bar.add_theme_stylebox_override("background", _line_box(BAR_BACK, BRONZE, 1))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar


## Menude gelisim her an gorunur: seviye, unvan, tecrube cubugu, altin ve guc puani.
func _progress_box() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.add_child(_label("Seviye %d · %s" % [profile.level, Rules.league(profile.stage)], 19, GOLD))
	var need := Rules.xp_need(profile.level)
	var full := profile.level >= GameData.MAX_LEVEL
	v.add_child(_thin_bar(100.0 if full else 100.0 * profile.xp / need, Color(0.85, 0.6, 0.2), 12))
	v.add_child(_label("En yüksek seviye" if full else "Tecrübe %d/%d" % [profile.xp, need], 14, MUTED))
	v.add_child(_label("%d Altın · Güç %d" % [profile.gold, Rules.score(profile.character("", _selected))], 16, PALE))
	v.add_child(_label(record_text, 14, MUTED))
	return v


## Doom Forge giris ekrani duzeni: ortada isik altinda kahraman, sagda sinif, solda ad ve savas secimi.
func show_select(selected: String, player_name: String) -> void:
	_clear()
	_selected = selected
	var title := _label("KOR ARENA", 66, GOLD, true)
	_anchored(title, Control.PRESET_CENTER_TOP, Vector2(0, 18))
	var sub := _label("Küllerin içinden bir şampiyon doğuyor", 19, MUTED)
	_anchored(sub, Control.PRESET_CENTER_TOP, Vector2(0, 104))

	var classes := VBoxContainer.new()
	classes.add_theme_constant_override("separation", 12)
	classes.add_child(_label("SINIFINI SEÇ", 22, GOLD, true))
	for cls: String in GameData.CLASSES:
		classes.add_child(_class_card(cls, selected))
	_anchored(classes, Control.PRESET_CENTER_RIGHT, Vector2(-44, 0))

	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 330
	left.add_theme_constant_override("separation", 9)
	left.add_child(_label("KAHRAMANIN ADI", 20, GOLD, true))
	_name_edit = _edit(player_name, "Adını yaz", 330)
	_name_edit.max_length = 16
	left.add_child(_name_edit)
	left.add_child(_progress_box())
	left.add_child(_menu_button(ai_text, func() -> void: play_ai.emit(_selected, _name_text()), 18))
	left.add_child(_menu_button("Hızlı Maç", func() -> void: quick_match.emit(_selected, _name_text()), 18))
	left.add_child(_row([_menu_button("Oda Aç", func() -> void: host_room.emit(_selected, _name_text())), _menu_button("Odaya Katıl", _show_join)]))
	var badge := profile.points + profile.bag.size()
	var hero := _menu_button("Karakter" + (" · %d" % badge if badge > 0 else ""), func() -> void:
		name_memo = _name_text()
		show_character())
	left.add_child(_row([hero, _menu_button("Başarımlar", func() -> void: screens.achievements(profile))]))
	left.add_child(_row([_menu_button("Test Modu", func() -> void: test_mode.emit(_selected, _name_text())), _menu_button("Yetenekler", func() -> void: screens.skills(_selected, profile.level))]))
	var bottom: Array = [_menu_button("Ayarlar", screens.settings), _menu_button("Nasıl Oynanır", screens.help)]
	if not OS.has_feature("web"):
		bottom.append(_menu_button("Çıkış", func() -> void: get_tree().quit()))
	left.add_child(_row(bottom))
	left.add_child(_label(profile.daily_text(), 14, MUTED))
	_anchored(left, Control.PRESET_CENTER_LEFT, Vector2(44, 0))

	var version := _label("Sürüm %d" % Version.BUILD, 15, MUTED)
	_anchored(version, Control.PRESET_BOTTOM_RIGHT, Vector2(-14, -8))
	var desc := _label(GameData.CLASSES[selected]["desc"], 20, PALE)
	_anchored(desc, Control.PRESET_CENTER_BOTTOM, Vector2(0, -26))

## Ses ayari: secim hemen duyulur ve bir sonraki acilisa kalir.
func _volume_row(text: String, music: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var name_l := _label(text, 16, MUTED)
	name_l.custom_minimum_size.x = 64
	row.add_child(name_l)
	var s := HSlider.new()
	s.max_value = 1.0
	s.step = 0.05
	s.value = SoundBank.me.music_volume if music else SoundBank.me.sfx_volume
	s.focus_mode = Control.FOCUS_NONE
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.value_changed.connect(func(v: float) -> void:
		if music:
			SoundBank.me.set_volumes(v, SoundBank.me.sfx_volume)
		else:
			SoundBank.me.set_volumes(SoundBank.me.music_volume, v)
			SoundBank.me.play("blade"))
	row.add_child(s)
	return row


const STAT_HINTS := {"main": "saldırı", "agi": "saldırı hızı", "vit": "can, savunma"}


## Karakter ekrani: stat puani, giyilenler ve demirci, canta ve sandik. Her islem aninda kaydedilir.
func show_character() -> void:
	_clear()
	var c: Dictionary = GameData.CLASSES[_selected]
	var ch := profile.character("", _selected)
	var s := Rules.calc_stats(ch)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)

	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation", 6)
	stats.custom_minimum_size.x = 290
	stats.add_child(_small("%s · Sv. %d" % [c["name"], profile.level], 26, GOLD))
	stats.add_child(_small("Güç Puanı %d" % Rules.score(ch), 18, GOLD))
	stats.add_child(_small("Can %d · Saldırı %d\nSavunma %d" % [s["max_hp"], s["atk"], s["def"]], 16)) # kritik yok (kullanici karari)
	stats.add_child(_small("Dağıtılacak puan: %d" % profile.points, 17, GOLD))
	var names := {"main": "Güç", "agi": "Çeviklik", "vit": "Dayanıklılık"}
	if c["main"] == "agi":
		names = {"main": "Hız", "agi": "Çeviklik", "vit": "Dayanıklılık"}
	for key: String in names:
		var line := HBoxContainer.new()
		var text := VBoxContainer.new()
		text.add_theme_constant_override("separation", 0)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_child(_small("%s: %d" % [names[key], profile.spent[key]], 17))
		text.add_child(_small(STAT_HINTS["agi" if c["main"] == "agi" and key == "main" else key], 13, MUTED))
		line.add_child(text)
		var add := _button("+", 18)
		add.disabled = profile.points <= 0
		add.pressed.connect(func() -> void:
			profile.spend(key)
			show_character())
		line.add_child(add)
		stats.add_child(line)
	var reset := _button("Puanları Sıfırla (%d Altın)" % profile.reset_price(), 14)
	reset.disabled = profile.spent_total() == 0 or profile.gold < profile.reset_price()
	reset.pressed.connect(func() -> void:
		profile.reset_points()
		show_character())
	stats.add_child(reset)
	stats.add_child(_small(profile.daily_text(), 15, MUTED))
	var close := _button("Geri", 17)
	close.pressed.connect(func() -> void: character_closed.emit())
	stats.add_child(close)
	row.add_child(stats)

	var worn := VBoxContainer.new()
	worn.add_theme_constant_override("separation", 5)
	worn.custom_minimum_size.x = 310
	worn.add_child(_small("GİYİLENLER · DEMİRCİ", 20, GOLD, true))
	for slot: String in GameData.SLOTS:
		var it: Dictionary = profile.equipped[slot]
		worn.add_child(_small(Rules.item_name(it), 17, _rarity_color(it)))
		worn.add_child(_small(Rules.item_stats(it), 14, MUTED))
		var plus := int(it.get("plus", 0))
		var up := _button("En yüksek derece" if plus >= GameData.MAX_PLUS else "Güçlendir +%d (%d Altın)" % [plus + 1, Rules.upgrade_cost(it)], 14)
		up.disabled = not profile.can_upgrade(slot)
		up.pressed.connect(func() -> void:
			if profile.upgrade(slot):
				SoundBank.me.play("thit")
				SoundBank.me.play("ring")
			show_character())
		worn.add_child(up)
	row.add_child(worn)

	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 8)
	side.custom_minimum_size.x = 390
	side.add_child(_small("ÇANTA %d/%d · %d Altın" % [profile.bag.size(), GameData.BAG_SIZE, profile.gold], 20, GOLD, true))
	var chest := _button("Sandık Aç (%d Altın)" % profile.chest_price(), 15)
	chest.disabled = profile.gold < profile.chest_price() or profile.bag.size() >= GameData.BAG_SIZE
	chest.pressed.connect(func() -> void:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var it := profile.open_chest(rng)
		show_character()
		if not it.is_empty():
			screens.reveal(profile, it, show_character))
	var weak := _button("Zayıfları Sat", 15)
	weak.disabled = not profile.bag.any(func(it: Dictionary) -> bool: return Rules.item_power(it) < Rules.item_power(profile.equipped[it["slot"]]))
	weak.pressed.connect(func() -> void:
		if profile.sell_weak() > 0:
			SoundBank.me.play("coin")
		show_character())
	side.add_child(_row([chest, weak]))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(390, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var order := range(profile.bag.size())
	order.sort_custom(func(a: int, b: int) -> bool: return Rules.item_power(profile.bag[a]) > Rules.item_power(profile.bag[b]))
	for i: int in order:
		list.add_child(_bag_row(i))
	if profile.bag.is_empty():
		list.add_child(_small("Çanta boş. Ganimet arenada kazanılır ya da sandıktan çıkar.", 14, MUTED))
	scroll.add_child(list)
	side.add_child(scroll)
	row.add_child(side)
	_center_panel(row)


func _rarity_color(it: Dictionary) -> Color:
	return GameData.RARITY[int(it["rarity"])]["color"].lightened(0.2)


## Esyayi giyilene gore karsilastiran kisa satir: yesil artar, kirmizi azalir.
func _diff_label(it: Dictionary, worn: Dictionary, size: int) -> RichTextLabel:
	var parts: Array[String] = []
	for d: Array in Rules.item_diff(it, worn):
		parts.append("[color=%s]%s %+d[/color]" % ["#8fe36a" if int(d[1]) > 0 else "#ff6a55", d[0], d[1]])
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_OFF
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_size_override("normal_font_size", size + 5 if Version.phone() else size)
	r.text = ", ".join(parts) if not parts.is_empty() else "[color=#c7b89e]Giydiğinle aynı[/color]"
	return r


func _bag_row(i: int) -> Control:
	var it: Dictionary = profile.bag[i]
	var line := HBoxContainer.new()
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	text.add_child(_small(Rules.item_name(it), 16, _rarity_color(it)))
	text.add_child(_diff_label(it, profile.equipped[it["slot"]], 13))
	line.add_child(text)
	var wear := _button("Giy", 14)
	wear.pressed.connect(func() -> void:
		profile.equip(i)
		show_character())
	line.add_child(wear)
	var sell := _button("Sat %d" % Rules.sell_price(it), 14)
	sell.pressed.connect(func() -> void:
		profile.sell(i)
		SoundBank.me.play("coin")
		show_character())
	line.add_child(sell)
	return line


## Esya karti: nadirlik renginde cerceve, ad, statlar ve giyilene gore fark.
func item_card(it: Dictionary, worn: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	var st := _line_box(Color(0.05, 0.035, 0.03, 0.95), _rarity_color(it), 2)
	st.set_content_margin_all(12.0)
	card.add_theme_stylebox_override("panel", st)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.add_child(_small(Rules.item_name(it), 20, _rarity_color(it)))
	v.add_child(_small("%s · Sv. %d" % [GameData.RARITY[int(it["rarity"])]["name"], it["level"]], 14, MUTED))
	v.add_child(_small(Rules.item_stats(it), 16))
	v.add_child(_diff_label(it, worn, 15))
	card.add_child(v)
	return card


func bag_index(it: Dictionary) -> int:
	for i in profile.bag.size():
		if is_same(profile.bag[i], it):
			return i
	return -1


## Karakter ekraninda yazi cok; telefonda okunabilsin diye buyur.
func _small(text: String, size: int, color := PALE, title := false) -> Label:
	return _label(text, size + 5 if Version.phone() else size, color, title)


func _center_panel(content: Control) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.add_child(content)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(panel)
	_root.add_child(center)


## Ekranin ustune acilan pencere: arkasi kararir ve tiklanmaz. Esc ya da Kapat en ustteki pencereyi kapatir.
func overlay(content: Control) -> Control:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.add_child(content)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(panel)
	dim.add_child(center)
	_root.add_child(dim)
	_overlays.append(dim)
	return dim


func has_overlay() -> bool:
	_overlays = _overlays.filter(func(o: Control) -> bool: return is_instance_valid(o) and not o.is_queued_for_deletion())
	return not _overlays.is_empty()


func close_overlay() -> bool:
	if not has_overlay():
		return false
	var top: Control = _overlays.pop_back()
	if top.has_meta("on_close"): # ornek: sandik penceresi Esc ile kapaninca karakter ekrani yenilenir
		var done: Callable = top.get_meta("on_close")
		top.remove_meta("on_close")
		done.call_deferred()
	top.queue_free()
	return true


func _show_join() -> void:
	var player_name := _name_text()
	var cls := _selected
	_clear()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.custom_minimum_size.x = 430
	v.add_child(_label("Odaya Katıl", 30, GOLD, true))
	v.add_child(_label("Arkadaşının verdiği oda kodunu yaz:", 18))
	var code := _edit("", "Örnek: A7XQ2M", 400)
	v.add_child(code)
	var go := _button("Bağlan", 20)
	go.pressed.connect(func() -> void: join_room.emit(cls, player_name, code.text))
	v.add_child(go)
	var cancel := _button("Geri", 16)
	cancel.pressed.connect(func() -> void: cancel_online.emit())
	v.add_child(cancel)
	_center_panel(v)


func show_lobby(title: String, details: String) -> void:
	_clear()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.custom_minimum_size.x = 540
	v.add_child(_label(title, 28, GOLD, true))
	_lobby_box = VBoxContainer.new()
	_lobby_box.add_theme_constant_override("separation", 8)
	v.add_child(_lobby_box)
	if details != "":
		v.add_child(_label(details, 18, MUTED))
	var cancel := _button("İptal", 17)
	cancel.pressed.connect(func() -> void: cancel_online.emit())
	v.add_child(cancel)
	_center_panel(v)


func set_lobby_status(text: String) -> void:
	if _lobby_box == null or not is_instance_valid(_lobby_box):
		return
	var big := text.contains("KOD")
	_lobby_box.add_child(_label(text, 30 if big else 18, GOLD if big else PALE, big))
	if big:
		var code := text.get_slice(": ", 1)
		var copy := _button("Kodu Kopyala", 16)
		copy.pressed.connect(func() -> void: DisplayServer.clipboard_set(code))
		_lobby_box.add_child(copy)


## Rakip uzun sure cikmazsa ustte belirir; arama arkada surer.
func offer_bot() -> void:
	var b := _button("Rakip bulunamadı · Botla Eşleş", 18)
	b.pressed.connect(func() -> void: bot_match.emit())
	_anchored(b, Control.PRESET_CENTER_TOP, Vector2(0, 24))


func show_message(text: String) -> void:
	var l := _label(text, 24, Color(1.0, 0.75, 0.55))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.anchor_right = 1.0
	l.offset_top = 150.0
	_root.add_child(l)


func _gradient(top: Color, bottom: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, top)
	g.set_color(1, bottom)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 4
	t.height = 32
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(0, 1)
	return t


func _flat_tex(tex: Texture2D) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = tex
	return s


func _bar(top: Color, bottom: Color) -> ProgressBar:
	var p := ProgressBar.new()
	p.show_percentage = false
	p.step = 0.001
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.offset_left = 2
	p.offset_right = -2
	p.offset_top = 2
	p.offset_bottom = -2
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("fill", _flat_tex(_gradient(top, bottom)))
	p.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	return p


## Ince cerceveli koyu zemin: can cubugu, hazirlik cubugu ve yetenek yuvalari ayni dili konusur.
func _line_box(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(width)
	return s


## Hazirlik cubugu: can cubugunun altinda, ekranin ortasina yakin ucta. Rakip buyuk bir yetenege hazirlaniyorsa kesme firsati burada gorunur.
func _cast_row(key: String, mirror: bool) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(340, 26 if Version.phone() else 15)
	box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if mirror else Control.SIZE_SHRINK_END
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar := _bar(Color(1.0, 0.8, 0.3), Color(0.8, 0.4, 0.1))
	bar.offset_left = 0
	bar.offset_right = 0
	bar.offset_top = 0
	bar.offset_bottom = 0
	bar.fill_mode = ProgressBar.FILL_END_TO_BEGIN if mirror else ProgressBar.FILL_BEGIN_TO_END
	bar.add_theme_stylebox_override("background", _line_box(BAR_BACK, BRONZE, 1))
	box.add_child(bar)
	var text := _label("", 20 if Version.phone() else 12)
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(text)
	box.modulate.a = 0.0
	_cast[key] = {"box": box, "bar": bar, "text": text, "t": 0.0, "dur": 1.0}
	return box


## Oyuncu cercevesi: kucuk ad, ekran kenarina yasli uzun ince can cubugu, kirmizi hasar izi. mirror: sag taraf aynalanir.
func _fighter(e: Battle.Ent, key: String, mirror: bool) -> Control:
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_l := _label("%s <Kor> [%d]" % [e.ch["name"], e.s["level"]], 16, GOLD, true)
	var head := HBoxContainer.new() # ad + kazanilan raunt isaretleri
	head.add_theme_constant_override("separation", 8)
	head.alignment = BoxContainer.ALIGNMENT_END if mirror else BoxContainer.ALIGNMENT_BEGIN
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 4)
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in Battle.ROUNDS_TO_WIN:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(13, 13)
		pip.add_theme_stylebox_override("panel", _line_box(Color(0.08, 0.06, 0.05), BRONZE, 1))
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pips.add_child(pip)
	_bars["pips" + key] = pips
	if mirror:
		head.add_child(pips)
		head.add_child(name_l)
	else:
		head.add_child(name_l)
		head.add_child(pips)
	info.add_child(head)
	var frame := Control.new()
	frame.custom_minimum_size = Vector2(0, 22)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := Panel.new()
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.add_theme_stylebox_override("panel", _line_box(BAR_BACK, BRONZE, 1))
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(back)
	var lag := _bar(Color(0.95, 0.2, 0.1), Color(0.6, 0.05, 0.03))
	frame.add_child(lag)
	var hp := _bar(Color(0.55, 0.92, 0.2), Color(0.12, 0.48, 0.06))
	frame.add_child(hp)
	lag.fill_mode = ProgressBar.FILL_END_TO_BEGIN if mirror else ProgressBar.FILL_BEGIN_TO_END
	hp.fill_mode = lag.fill_mode
	var num := _label("", 13)
	num.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	num.offset_left = 10
	num.offset_right = -10
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if mirror else HORIZONTAL_ALIGNMENT_LEFT
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	frame.add_child(num)
	info.add_child(frame)
	info.add_child(_cast_row(key, mirror))
	var fx := HBoxContainer.new()
	fx.add_theme_constant_override("separation", 4)
	fx.alignment = BoxContainer.ALIGNMENT_END if mirror else BoxContainer.ALIGNMENT_BEGIN
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(fx)
	_bars["fx" + key] = fx
	_bars["hp" + key] = hp
	_bars["lag" + key] = lag
	_bars["num" + key] = num
	return info


func show_battle(me: Battle.Ent, foe: Battle.Ent, vs_ai: bool) -> void:
	_clear()
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 30)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_fighter(me, "A", false))
	top.add_child(_fighter(foe, "B", true))
	_root.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 14
	top.offset_right = -14
	top.offset_top = 8

	var plate := PanelContainer.new()
	var ps := _line_box(Color(0.035, 0.03, 0.03, 0.94), BRONZE, 0)
	ps.border_width_top = 2
	ps.content_margin_left = 12.0
	ps.content_margin_right = 12.0
	ps.content_margin_top = 8.0
	ps.content_margin_bottom = 2.0
	plate.add_theme_stylebox_override("panel", ps)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 3)
	var ids: Array = GameData.CLASSES[me.ch["cls"]]["skills"]
	for i in ids.size():
		bar.add_child(_skill_button(i, ids[i], me))
	plate.add_child(bar)
	_anchored(plate, Control.PRESET_CENTER_BOTTOM)
	if vs_ai:
		forfeit_button = _button("Maçı Bitir", 15)
		forfeit_button.pressed.connect(_on_forfeit_press)
		_anchored(forfeit_button, Control.PRESET_BOTTOM_RIGHT, Vector2(-14, -12))
		var pause := _button("Duraklat", 15)
		pause.pressed.connect(func() -> void: pause_pressed.emit())
		_anchored(pause, Control.PRESET_BOTTOM_LEFT, Vector2(14, -12))
	else:
		var menu := _button("Menü", 15)
		menu.pressed.connect(func() -> void: screens.online_menu(me.ch["cls"]))
		_anchored(menu, Control.PRESET_BOTTOM_LEFT, Vector2(14, -12))
		var pause := _button("Duraklat", 15) # canli macta da (kullanici istegi): ikisinde birden durur
		pause.pressed.connect(func() -> void: pause_pressed.emit())
		_anchored(pause, Control.PRESET_BOTTOM_RIGHT, Vector2(-14, -12))


## Test Modu ayarlari: her dugme adini gosterir, basinca main yeni adlari yollar.
func show_test_panel(items: Dictionary) -> void:
	if _test_box != null and is_instance_valid(_test_box):
		_test_box.queue_free()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	for what: String in items:
		var b := _button(items[what], 16)
		b.add_theme_font_override("font", _body_font)
		b.pressed.connect(func() -> void: test_action.emit(what))
		v.add_child(b)
	_anchored(v, Control.PRESET_CENTER_RIGHT, Vector2(-14, 0))
	_test_box = v


func show_pause(on: bool, testing := false, who := "") -> void:
	if _pause_box != null and is_instance_valid(_pause_box):
		_pause_box.queue_free()
	if not on:
		return
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.custom_minimum_size.x = 340
	v.add_child(_label("DURAKLATILDI", 34, GOLD, true))
	if who != "": # canli mac: kimin durdurdugu; iki taraf da devam ettirebilir
		v.add_child(_label(who, 18, Color(0.85, 0.82, 0.75), true))
	v.add_child(_menu_button("Devam Et", func() -> void: pause_pressed.emit(), 20))
	if testing:
		v.add_child(_menu_button("Yeniden Oyna", func() -> void: test_action.emit("restart")))
	else:
		v.add_child(_menu_button("Yeniden Başlat (R)", func() -> void: restart_pressed.emit()))
	v.add_child(_menu_button("Yetenekler", func() -> void: screens.skills(_selected, profile.level)))
	v.add_child(_menu_button("Ayarlar", screens.settings))
	v.add_child(_menu_button("Nasıl Oynanır", screens.help))
	_pause_box = overlay(v)
	_overlays.erase(_pause_box) # Esc once ustteki pencereleri kapatir, sonra oyunu surdurur


## Yanlislikla basilmasin: ilk tik sorar, 3 sn icinde ikinci tik maci bitirir.
func _on_forfeit_press() -> void:
	if forfeit_button.text == "Emin misin?":
		forfeit.emit()
		return
	forfeit_button.text = "Emin misin?"
	var ref: WeakRef = weakref(forfeit_button) # dugme 3 sn icinde silinebilir
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		var b: Button = ref.get_ref()
		if b != null:
			b.text = "Maçı Bitir")

## Kare yuva: ikon, bekleme perdesi, kalan sure; tus numarasi yuvanin altinda.
func _skill_button(i: int, id: String, me: Battle.Ent) -> Control:
	var k: Dictionary = GameData.SKILLS[id]
	var slot := VBoxContainer.new()
	slot.add_theme_constant_override("separation", 0)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS # parmak degdigi an: parry zamanlamasi kacmasin
	b.custom_minimum_size = Vector2.ONE * (PHONE_SLOT if Version.phone() else 68.0)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.tooltip_text = "%s (%d sn, hazırlık %.1f sn)\n%s" % [k["name"], k["cd"], k.get("windup", 0.0), k["desc"]]
	b.disabled = not me.skills.has(id)
	b.tooltip_text += "\n%d. seviyede açılır" % k["unlock"] if b.disabled else ""
	b.pressed.connect(func() -> void: skill_pressed.emit(id))
	var icon := TextureRect.new()
	icon.texture = IconLibrary.get_icon(id, GameData.CLASSES[me.ch["cls"]]["color"].lightened(0.25))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)
	var cover := TextureProgressBar.new() # saat yonunde acilan bekleme gostergesi
	cover.fill_mode = TextureProgressBar.FILL_COUNTER_CLOCKWISE
	cover.texture_progress = _gradient(Color(0, 0, 0, 0.78), Color(0, 0, 0, 0.78))
	cover.nine_patch_stretch = true
	cover.max_value = 1.0
	cover.step = 0.001
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(cover)
	var frame := Panel.new()
	frame.add_theme_stylebox_override("panel", _line_box(Color(0, 0, 0, 0), BRONZE, 2))
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(frame)
	var num := _label("", 23)
	num.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_child(num)
	var block := _label("X", 52, Color(0.95, 0.22, 0.15), true) # duz vurus surerken yetenek basilamaz
	block.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	block.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	block.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.visible = false
	b.add_child(block)
	var glow := Panel.new() # basilan yetenegin cevresi kendi renginde yanar
	var gs := StyleBoxFlat.new()
	gs.bg_color = Color(0, 0, 0, 0)
	gs.set_border_width_all(4)
	gs.set_corner_radius_all(4)
	gs.shadow_size = 12
	glow.add_theme_stylebox_override("panel", gs)
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.offset_left = -4
	glow.offset_top = -4
	glow.offset_right = 4
	glow.offset_bottom = 4
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.modulate.a = 0.0
	b.add_child(glow)
	b.move_child(glow, 0) # simgenin arkasinda: yalnizca kenarlarda parlar, simgeyi ortmez
	slot.add_child(b)
	var key := _label(str((i + 1) % 10), 13, Color(0.92, 0.3, 0.16), true) # 10. yuvanin tusu 0
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key.visible = not Version.phone()
	slot.add_child(key)
	_skills.append({"id": id, "button": b, "cover": cover, "num": num, "glow": glow, "block": block})
	return slot


## Kullanilan yetenegin simgesi yalnizca basildigi an kendi renginde kisa bir parlama yapar (kullanici karari).
func _light_slot(id: String, color: Color) -> void:
	for s in _skills:
		var glow: Panel = s["glow"]
		if s.has("glow_tween") and s["glow_tween"].is_valid():
			s["glow_tween"].kill()
		if s["id"] != id:
			glow.modulate.a = 0.0
			continue
		var gs: StyleBoxFlat = glow.get_theme_stylebox("panel")
		gs.border_color = color.lightened(0.25)
		gs.shadow_color = Color(color, 0.75)
		glow.modulate.a = 1.0
		var tw := create_tween()
		tw.tween_interval(0.12)
		tw.tween_property(glow, "modulate:a", 0.0, 0.3)
		s["glow_tween"] = tw

## Basis hemen hissedilsin: gecen tus iceri cokar, gecmeyen tus kizarip kisa ses verir.
func press_feedback(id: String, ok: bool) -> void:
	for s in _skills:
		if s["id"] != id:
			continue
		var b: Button = s["button"]
		if s.has("tween") and s["tween"].is_valid():
			s["tween"].kill()
		b.pivot_offset = b.size / 2.0
		b.scale = Vector2.ONE * 0.88
		b.modulate = Color.WHITE if ok else Color(1.0, 0.3, 0.25)
		var tw := create_tween().set_parallel()
		tw.tween_property(b, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "modulate", Color.WHITE, 0.22)
		s["tween"] = tw
		if not ok:
			SoundBank.me.play("click")


## Hazirlik baslar: secilen yetenegin adi ve suresi ustte akar.
func cast_start(key: String, id: String, dur: float, color: Color) -> void:
	var c: Dictionary = _cast[key]
	c["t"] = dur
	c["dur"] = maxf(dur, 0.01)
	c["text"].text = GameData.SKILLS[id]["name"]
	c["box"].modulate = Color.WHITE
	c["bar"].modulate = color.lightened(0.2)


func cast_stop(key: String, text: String) -> void:
	var c: Dictionary = _cast[key]
	c["t"] = 0.0
	c["text"].text = text
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(c["box"], "modulate:a", 0.0, 0.3)


## Secilen yetenek ekranin ortasinda ikon ve adiyla gorunur: ne bastigin hic karismaz.
func show_my_skill(id: String, color: Color) -> void:
	_light_slot(id, color)
	if _my_cast != null and is_instance_valid(_my_cast):
		_my_cast.queue_free()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pic := TextureRect.new()
	pic.texture = IconLibrary.get_icon(id)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.custom_minimum_size = Vector2(58, 58)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pic)
	var name_l := _label(GameData.SKILLS[id]["name"], 34, color.lightened(0.3), true)
	name_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_l)
	_anchored(row, Control.PRESET_CENTER_BOTTOM, Vector2(0, -(PHONE_SLOT + 44.0) if Version.phone() else -118.0))
	_my_cast = row
	var tw := create_tween()
	tw.tween_interval(0.9)
	tw.tween_property(row, "modulate:a", 0.0, 0.4)
	tw.tween_callback(row.queue_free)


func _hp(key: String, e: Battle.Ent, delta: float) -> void:
	var pct := e.hp / float(e.s["max_hp"]) * 100.0
	_bars["hp" + key].value = pct
	var lag: ProgressBar = _bars["lag" + key]
	lag.value = maxf(pct, lag.value - delta * 14.0) if lag.value > pct else pct
	_bars["num" + key].text = "%d / %d" % [e.hp, e.s["max_hp"]]


func update_battle(me: Battle.Ent, foe: Battle.Ent) -> void:
	var delta := get_process_delta_time()
	for key: String in _cast:
		var c: Dictionary = _cast[key]
		if float(c["t"]) > 0.0:
			c["t"] -= delta
			c["bar"].value = (1.0 - float(c["t"]) / float(c["dur"])) * 100.0
			if float(c["t"]) <= 0.0:
				cast_stop(key, c["text"].text)
	_hp("A", me, delta)
	_hp("B", foe, delta)
	_status("A", me)
	_status("B", foe)
	for s in _skills:
		var k: Dictionary = GameData.SKILLS[s["id"]]
		if s["button"].disabled:
			s["cover"].value = 1.0
			s["num"].text = "Sv %d" % k["unlock"]
			continue
		var cd: float = me.cds.get(s["id"], 0.0)
		var wait := maxf(cd / float(k["cd"]), me.gcd / maxf(me.gcd_max, 0.1))
		s["cover"].value = wait
		var swinging := me.basic_t > 0.0 and me.cast_t <= 0.0
		s["block"].visible = swinging
		s["num"].text = "" if swinging else (("%.1f" % cd if cd < 3.0 else str(ceili(cd))) if cd > 0.0 else "")


## Kombo sayaci (Doom Forge gibi): ust ortada vuranin tarafinda "KOMBO xN" buyuyerek belirir, her vurusta yenilenir.
func combo(key: String, n: int) -> void:
	var old: Variant = _bars.get("combo" + key) # silinmis olabilir: tipli degiskene atanmaz
	if old != null and is_instance_valid(old):
		old.queue_free()
	var l := _label("KOMBO x%d" % n, 30 + mini(n, 8) * 3, GOLD if key == "A" else Color(0.95, 0.35, 0.2), true)
	_anchored(l, Control.PRESET_CENTER_TOP, Vector2(-260 if key == "A" else 260, 92))
	l.pivot_offset = l.size / 2.0
	l.scale = Vector2.ONE * 1.6
	_bars["combo" + key] = l
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.3)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)


## Kazanilan raunt isaretleri altin renge doner.
func set_rounds(mine: int, theirs: int) -> void:
	for key: String in ["A", "B"]:
		if not _bars.has("pips" + key) or not is_instance_valid(_bars["pips" + key]):
			continue
		var won := mine if key == "A" else theirs
		var row: HBoxContainer = _bars["pips" + key]
		for i in row.get_child_count():
			var fill := GOLD if i < won else Color(0.08, 0.06, 0.05)
			(row.get_child(i) as Panel).add_theme_stylebox_override("panel", _line_box(fill, BRONZE, 1))


## Raunt basi: baslik, sonra 3-2-1 ve SAVAS! Her yazi bir oncekinin yerine gecer.
func countdown(title: String, total: float) -> void:
	var step := total / 4.0
	var words := [title, "3", "2", "1"]
	for i in words.size():
		get_tree().create_timer(step * i).timeout.connect(announce.bind(words[i], maxf(0.2, step - 0.45)))
	get_tree().create_timer(total).timeout.connect(announce.bind("SAVAŞ!"))


func announce(text: String, hold := 0.6) -> void:
	var l := _label(text, 78, GOLD, true)
	_anchored(l, Control.PRESET_CENTER, Vector2(0, -170))
	l.pivot_offset = l.size / 2.0
	l.scale = Vector2.ONE * 1.5
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(l.queue_free)


func set_result_note(text: String) -> void:
	if _result_note != null and is_instance_valid(_result_note):
		_result_note.text = text


const STATUS := {"stun": ["Sersem", Color(1.0, 0.85, 0.3)], "slow": ["Yavaş", Color(0.45, 0.7, 1.0)], "dot": ["Zehir", Color(0.5, 0.95, 0.35)],
	"buff": ["Güçlenmiş", Color(1.0, 0.6, 0.25)], "sap": ["Zayıflamış", Color(0.85, 0.5, 1.0)], "freeze": ["Donmuş", Color(0.6, 0.9, 1.0)]}


## Can cubugunun altinda etki isaretleri. Afallama bilerek gosterilmez (kullanici karari: animasyonla belli olur).
func _status(key: String, e: Battle.Ent) -> void:
	var now := []
	for type: String in STATUS:
		if e.fx.any(func(f: Dictionary) -> bool: return f["type"] == type):
			now.append(type)
	if _status_cache.get(key, []) == now:
		return
	_status_cache[key] = now
	var row: HBoxContainer = _bars["fx" + key]
	for c in row.get_children():
		c.queue_free()
	for type in now:
		var chip := PanelContainer.new()
		var st := _line_box(Color(0.03, 0.02, 0.02, 0.85), STATUS[type][1], 1)
		st.content_margin_left = 7.0
		st.content_margin_right = 7.0
		chip.add_theme_stylebox_override("panel", st)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(_label(STATUS[type][0], 18 if Version.phone() else 13, STATUS[type][1]))
		row.add_child(chip)


## Mac sonunda sinif degistirilebilir: "Tekrar Savas" secili sinifla baslar. Solda kazanilanlar canlanarak gelir.
## info: reward (Profile odulu), stats (mac sayilari), ach (yeni basarimlar), note, ended (rakip yok: tekrar savas yok), animate.
func show_result(won: bool, offline: bool, cls: String, info: Dictionary = {}) -> void:
	_clear()
	_selected = cls
	_result_won = won
	_result_offline = offline
	_result_info = info
	var animate: bool = info.get("animate", true)
	info["animate"] = false # sinif secilip ekran yenilenince canlanma tekrar oynamaz
	var outer := HBoxContainer.new()
	outer.add_theme_constant_override("separation", 30)
	outer.add_child(_reward_box(info, animate))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	var title := _label("ZAFER" if won else "YENİLGİ", 62, GOLD if won else Color(0.9, 0.3, 0.2), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	if info.has("stats"):
		var s: Dictionary = info["stats"]
		var line := _small("Hasar %d · En büyük vuruş %d · Savuşturma %d · Kesme %d · %d sn" % [s["dmg"], s["best"], s["parry"], s["cut"], s["time"]], 15, MUTED)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(line)
	v.add_child(_label("Sınıfını seç", 19, MUTED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for k: String in GameData.CLASSES:
		row.add_child(_class_card(k, cls, func(picked: String) -> void:
			class_changed.emit(picked)
			_result_info["note"] = _result_note.text
			show_result(_result_won, _result_offline, picked, _result_info), 236.0))
	v.add_child(row)
	if not info.get("ended", false):
		var again := _button(again_text, 21)
		again.pressed.connect(func() -> void: rematch.emit())
		v.add_child(again)
	_result_note = _label(info.get("note", ""), 17)
	_result_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_result_note)
	var home := _button("Sınıf Seçimi" if offline or info.get("ended", false) else "Odadan Çık", 17)
	home.pressed.connect(func() -> void: back.emit())
	v.add_child(home)
	v.custom_minimum_size.x = 340
	outer.add_child(v)
	_center_panel(outer)


## Kazanilanlar: tecrube cubugu dolar, seviye atlanirsa ses ve buyume, altin sayilir, ganimet karti hemen giyilebilir.
func _reward_box(info: Dictionary, animate: bool) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 7)
	v.custom_minimum_size.x = 360
	v.add_child(_small("KAZANDIKLARIN", 20, GOLD, true))
	var r: Dictionary = info.get("reward", {})
	if r.is_empty():
		v.add_child(_small(info.get("why", "Bu maç ödül vermez."), 16, MUTED))
		return v
	var level_l := _small("Seviye %d" % (r["from_level"] if animate else profile.level), 22, GOLD, true)
	v.add_child(level_l)
	var bar := _thin_bar(0.0, Color(0.85, 0.6, 0.2), 14)
	v.add_child(bar)
	v.add_child(_small("+%d Tecrübe" % r["xp"], 16))
	var gold_total: int = int(r["gold"]) + int(r.get("quest", 0)) + info.get("ach", []).reduce(func(sum: int, a: Dictionary) -> int: return sum + int(a["gold"]), 0)
	var gold_l := _small("+%d Altın" % gold_total, 18, GOLD)
	v.add_child(gold_l)
	if int(r.get("quest", 0)) > 0:
		v.add_child(_small("Günlük görev tamam: +%d Altın" % r["quest"], 15, PALE))
	for a: Dictionary in info.get("ach", []):
		v.add_child(_small("Başarım: %s · +%d Altın" % [a["name"], a["gold"]], 15, GOLD))
	for id: String in r["skills"]:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		var pic := TextureRect.new()
		pic.texture = IconLibrary.get_icon(id)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.custom_minimum_size = Vector2(40, 40)
		line.add_child(pic)
		var name_l := _small("Yeni yetenek: %s" % GameData.SKILLS[id]["name"], 16, GOLD)
		name_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(name_l)
		v.add_child(line)
	var loot: Dictionary = r.get("loot", {})
	if not loot.is_empty():
		v.add_child(_small("Ganimet" + (" (çanta dolu, satıldı)" if r.get("sold", false) else ""), 16, MUTED))
		v.add_child(item_card(loot, profile.equipped[loot["slot"]]))
		if not r.get("sold", false) and bag_index(loot) >= 0:
			var wear := _button("Hemen Giy", 15)
			wear.pressed.connect(func() -> void:
				var i := bag_index(loot)
				if i >= 0:
					profile.equip(i)
				wear.text = "Giyildi"
				wear.disabled = true)
			v.add_child(wear)
	if r["levels"] > 0 and not animate:
		level_l.text = "Seviye %d" % profile.level
	if animate:
		_animate_reward(r, bar, level_l, gold_l, gold_total)
	else:
		bar.value = _xp_pct(profile.level, profile.xp)
	return v


func _xp_pct(level: int, xp: int) -> float:
	return 100.0 if level >= GameData.MAX_LEVEL else 100.0 * xp / Rules.xp_need(level)


func _animate_reward(r: Dictionary, bar: ProgressBar, level_l: Label, gold_l: Label, gold_total: int) -> void:
	var lvl: int = r["from_level"]
	bar.value = _xp_pct(lvl, r["from_xp"])
	var tw := bar.create_tween() # ekran kapaninca (hemen yeni mac) sayac da durur; silinmis yaziya yazmasin
	tw.tween_interval(0.35)
	while lvl < profile.level:
		lvl += 1
		var reached := lvl
		tw.tween_property(bar, "value", 100.0, 0.5)
		tw.tween_callback(func() -> void:
			level_l.text = "SEVİYE %d!" % reached
			level_l.pivot_offset = level_l.size / 2.0
			level_l.scale = Vector2.ONE * 1.35
			level_l.create_tween().tween_property(level_l, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			SoundBank.me.play("level")
			bar.value = 0.0)
	tw.tween_property(bar, "value", _xp_pct(profile.level, profile.xp), 0.5)
	gold_l.text = "+0 Altın"
	var count := gold_l.create_tween()
	count.tween_interval(0.35)
	count.tween_callback(func() -> void: SoundBank.me.play("coin"))
	count.tween_method(func(n: float) -> void: gold_l.text = "+%d Altın" % int(n), 0.0, float(gold_total), 0.8)
	count.tween_callback(func() -> void: SoundBank.me.play("coin"))
