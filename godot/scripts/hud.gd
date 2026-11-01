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
signal back

const GOLD := Color(0.93, 0.74, 0.38)
const PALE := Color(0.95, 0.9, 0.82)
const MUTED := Color(0.78, 0.72, 0.62)
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


func _clear() -> void:
	for c in _root.get_children():
		c.queue_free()
	_skills.clear()
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


func _class_card(cls: String, selected: String, on_pick: Callable = Callable()) -> Control:
	var c: Dictionary = GameData.CLASSES[cls]
	var on := cls == selected
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(270, 112)
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
	text.add_child(_label(c["name"], 21, GOLD if on else PALE, true))
	text.add_child(_label(ROLES[cls], 15, MUTED))
	row.add_child(text)
	b.add_child(row)
	return b


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
	left.custom_minimum_size.x = 300
	left.add_theme_constant_override("separation", 12)
	left.add_child(_label("KAHRAMANIN ADI", 22, GOLD, true))
	_name_edit = _edit(player_name, "Adını yaz", 300)
	_name_edit.max_length = 16
	left.add_child(_name_edit)
	var gap := Control.new()
	gap.custom_minimum_size.y = 10
	left.add_child(gap)
	var ai := _button("Yapay Zekâya Karşı", 18)
	ai.pressed.connect(func() -> void: play_ai.emit(_selected, _name_text()))
	left.add_child(ai)
	var host := _button("Oda Aç", 18)
	host.pressed.connect(func() -> void: host_room.emit(_selected, _name_text()))
	left.add_child(host)
	var join := _button("Odaya Katıl", 18)
	join.pressed.connect(_show_join)
	left.add_child(join)
	_anchored(left, Control.PRESET_CENTER_LEFT, Vector2(44, 0))

	var version := _label("Sürüm %d" % Version.BUILD, 15, MUTED)
	_anchored(version, Control.PRESET_BOTTOM_RIGHT, Vector2(-14, -8))
	var desc := _label(GameData.CLASSES[selected]["desc"], 20, PALE)
	_anchored(desc, Control.PRESET_CENTER_BOTTOM, Vector2(0, -26))

func _center_panel(content: Control) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.add_child(content)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(panel)
	_root.add_child(center)


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
	p.offset_left = 7
	p.offset_right = -7
	p.offset_top = 6
	p.offset_bottom = -6
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("fill", _flat_tex(_gradient(top, bottom)))
	p.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	return p


## Hazirlik cubugu: rakip buyuk bir yetenege hazirlaniyorsa kesme firsati burada gorunur.
func _cast_row(key: String, mirror: bool) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(620, 20)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar := _bar(Color(1.0, 0.8, 0.3), Color(0.8, 0.4, 0.1))
	bar.offset_left = 0
	bar.offset_right = 0
	bar.offset_top = 2
	bar.offset_bottom = -2
	bar.fill_mode = ProgressBar.FILL_END_TO_BEGIN if mirror else ProgressBar.FILL_BEGIN_TO_END
	bar.add_theme_stylebox_override("background", _ui("bar_back", 8.0))
	box.add_child(bar)
	var text := _label("", 15)
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(text)
	box.modulate.a = 0.0
	_cast[key] = {"box": box, "bar": bar, "text": text, "t": 0.0, "dur": 1.0}
	return box


## Oyuncu cercevesi: portre + ad + susleme cerceveli can cubugu. mirror: sag taraf aynalanir.
## Doom Forge duzeni: uzun yesil can cubugu, kirmizi hasar izi, altinda ince hazirlik cubugu.
func _fighter(e: Battle.Ent, key: String, mirror: bool) -> Control:
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 2)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_l := _label("%s <Kor> [%d]" % [e.ch["name"], e.s["level"]], 19, GOLD, true)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if mirror else HORIZONTAL_ALIGNMENT_LEFT
	info.add_child(name_l)
	var frame := Control.new()
	frame.custom_minimum_size = Vector2(620, 32)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := Panel.new()
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.add_theme_stylebox_override("panel", _ui("bar_back", 10.0))
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(back)
	var lag := _bar(Color(0.95, 0.2, 0.1), Color(0.6, 0.05, 0.03))
	frame.add_child(lag)
	var hp := _bar(Color(0.55, 0.92, 0.2), Color(0.12, 0.48, 0.06))
	frame.add_child(hp)
	lag.fill_mode = ProgressBar.FILL_END_TO_BEGIN if mirror else ProgressBar.FILL_BEGIN_TO_END
	hp.fill_mode = lag.fill_mode
	var over := Panel.new()
	over.set_anchors_preset(Control.PRESET_FULL_RECT)
	over.add_theme_stylebox_override("panel", _ui("bar_frame", 12.0))
	over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(over)
	var num := _label("", 16)
	num.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	frame.add_child(num)
	info.add_child(frame)
	info.add_child(_cast_row(key, mirror))
	_bars["hp" + key] = hp
	_bars["lag" + key] = lag
	_bars["num" + key] = num
	return info

func show_battle(me: Battle.Ent, foe: Battle.Ent, _can_pause: bool) -> void:
	_clear()
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 44)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_fighter(me, "A", false))
	top.add_child(_fighter(foe, "B", true))
	_anchored(top, Control.PRESET_CENTER_TOP, Vector2(0, 10))

	var plate := PanelContainer.new()
	var ps := _ui("plate", 30.0)
	ps.content_margin_left = 30.0
	ps.content_margin_right = 30.0
	ps.content_margin_top = 12.0
	ps.content_margin_bottom = 12.0
	plate.add_theme_stylebox_override("panel", ps)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	var ids: Array = GameData.CLASSES[me.ch["cls"]]["skills"]
	for i in ids.size():
		bar.add_child(_skill_button(i, ids[i], me))
	plate.add_child(bar)
	_anchored(plate, Control.PRESET_CENTER_BOTTOM, Vector2(0, -8))


func _skill_button(i: int, id: String, me: Battle.Ent) -> Control:
	var k: Dictionary = GameData.SKILLS[id]
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(78, 78)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.tooltip_text = "%s (%d sn)\n%s" % [k["name"], k["cd"], k["desc"]]
	b.disabled = not me.skills.has(id)
	b.pressed.connect(func() -> void: skill_pressed.emit(id))
	var icon := TextureRect.new()
	icon.texture = IconLibrary.get_icon(id, GameData.CLASSES[me.ch["cls"]]["color"].lightened(0.25))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 5
	icon.offset_top = 5
	icon.offset_right = -5
	icon.offset_bottom = -5
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)
	var cover := TextureProgressBar.new() # saat yonunde acilan bekleme gostergesi
	cover.fill_mode = TextureProgressBar.FILL_COUNTER_CLOCKWISE
	cover.texture_progress = _gradient(Color(0, 0, 0, 0.74), Color(0, 0, 0, 0.74))
	cover.nine_patch_stretch = true
	cover.max_value = 1.0
	cover.step = 0.001
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.offset_left = 5
	cover.offset_top = 5
	cover.offset_right = -5
	cover.offset_bottom = -5
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(cover)
	var frame := TextureRect.new()
	frame.texture = load("res://art/ui/slot.svg")
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(frame)
	var key := _label(str(i + 1), 16, GOLD, true)
	key.position = Vector2(9, 3)
	b.add_child(key)
	var num := _label("", 27)
	num.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_child(num)
	_skills.append({"id": id, "button": b, "cover": cover, "num": num})
	return b


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
	_anchored(row, Control.PRESET_CENTER_BOTTOM, Vector2(0, -132))
	_my_cast = row
	var tw := create_tween()
	tw.tween_interval(0.9)
	tw.tween_property(row, "modulate:a", 0.0, 0.4)
	tw.tween_callback(row.queue_free)


func _hp(key: String, e: Battle.Ent, delta: float) -> void:
	var pct := e.hp / float(e.s["max_hp"]) * 100.0
	_bars["hp" + key].value = pct
	var lag: ProgressBar = _bars["lag" + key]
	lag.value = maxf(pct, lag.value - delta * 22.0) if lag.value > pct else pct
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
	for s in _skills:
		var k: Dictionary = GameData.SKILLS[s["id"]]
		var cd: float = me.cds.get(s["id"], 0.0)
		var wait := maxf(cd / float(k["cd"]), me.gcd / GameData.GCD)
		s["cover"].value = wait
		s["num"].text = ("%.1f" % cd if cd < 3.0 else str(ceili(cd))) if cd > 0.0 else ""


func announce(text: String) -> void:
	var l := _label(text, 78, GOLD, true)
	_anchored(l, Control.PRESET_CENTER, Vector2(0, -170))
	l.pivot_offset = l.size / 2.0
	l.scale = Vector2.ONE * 1.5
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(l.queue_free)


func set_result_note(text: String) -> void:
	if _result_note != null and is_instance_valid(_result_note):
		_result_note.text = text


## Mac sonunda sinif degistirilebilir: "Tekrar Savas" secili sinifla baslar.
func show_result(won: bool, offline: bool, cls: String, note: String = "") -> void:
	_clear()
	_selected = cls
	_result_won = won
	_result_offline = offline
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	var title := _label("ZAFER" if won else "YENİLGİ", 62, GOLD if won else Color(0.9, 0.3, 0.2), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	v.add_child(_label("Sınıfını seç", 19, MUTED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for k: String in GameData.CLASSES:
		row.add_child(_class_card(k, cls, func(picked: String) -> void:
			class_changed.emit(picked)
			show_result(_result_won, _result_offline, picked, _result_note.text)))
	v.add_child(row)
	var again := _button("Tekrar Savaş", 21)
	again.pressed.connect(func() -> void: rematch.emit())
	v.add_child(again)
	_result_note = _label(note, 17)
	_result_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_result_note)
	var home := _button("Sınıf Seçimi" if offline else "Odadan Çık", 17)
	home.pressed.connect(func() -> void: back.emit())
	v.add_child(home)
	v.custom_minimum_size.x = 340
	_center_panel(v)
