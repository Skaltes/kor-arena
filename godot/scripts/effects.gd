class_name Effects
extends Node3D
## Gecici savas efektleri: kivilcim, toz, halka, hasar yazisi. Hepsi kisa omurlu ve az sayida parcacikli.

static var _dot_tex: GradientTexture2D

var _font: FontVariation
var _stains: Array[MeshInstance3D] = []


func _ready() -> void:
	_font = FontVariation.new()
	_font.base_font = load("res://assets/fonts/Cinzel-Variable.ttf")
	_font.variation_opentype = {"wght": 800}
	if _dot_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		_dot_tex = GradientTexture2D.new()
		_dot_tex.gradient = g
		_dot_tex.fill = GradientTexture2D.FILL_RADIAL
		_dot_tex.fill_from = Vector2(0.5, 0.5)
		_dot_tex.fill_to = Vector2(1.0, 0.5)


func _quad(size: float, additive: bool) -> QuadMesh:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _dot_tex
	var q := QuadMesh.new()
	q.size = Vector2.ONE * size
	q.material = m
	return q


func _emit(p: CPUParticles3D, life: float) -> void:
	add_child(p)
	p.emitting = true
	get_tree().create_timer(life + 0.3).timeout.connect(p.queue_free)


## Parlak kivilcim: yercekimine duser, cizgi gibi sonumlenir
func burst(pos: Vector3, color: Color, count: int, spread: float, size := 0.05, life := 0.4) -> void:
	var ramp := Gradient.new()
	ramp.set_color(0, Color(color.r * 3.0, color.g * 3.0, color.b * 3.0, 1.0))
	ramp.set_color(1, Color(color.r, color.g * 0.5, color.b * 0.4, 0.0))
	var p := CPUParticles3D.new()
	p.mesh = _quad(size * 2.4, true)
	p.amount = count
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.95
	p.spread = 180.0
	p.gravity = Vector3(0, -9, 0)
	p.initial_velocity_min = spread * 0.5
	p.initial_velocity_max = spread * 1.5
	p.color_ramp = ramp
	p.position = pos
	_emit(p, life)


## Kum tozu: agir vuruslarda yerden kalkar
func dust(pos: Vector3, amount: int, reach: float) -> void:
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.6, 0.55, 0.5, 0.3))
	ramp.set_color(1, Color(0.6, 0.55, 0.5, 0.0))
	var p := CPUParticles3D.new()
	p.mesh = _quad(0.55, false)
	p.amount = amount
	p.lifetime = 0.7
	p.one_shot = true
	p.explosiveness = 0.9
	p.direction = Vector3.UP
	p.spread = 80.0
	p.gravity = Vector3(0, -0.6, 0)
	p.initial_velocity_min = reach * 0.4
	p.initial_velocity_max = reach * 1.1
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	p.color_ramp = ramp
	p.position = pos
	_emit(p, 0.7)


## Beyaz parlama: kritik ve agir vuruslarin ani
func flash(pos: Vector3, color: Color, size: float) -> void:
	var s := Sprite3D.new()
	s.texture = _dot_tex
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.no_depth_test = true
	s.modulate = Color(color.r * 2.0, color.g * 2.0, color.b * 2.0, 0.6)
	s.pixel_size = size / 64.0 * 0.3
	s.position = pos
	add_child(s)
	var tw := create_tween().set_parallel()
	tw.tween_property(s, "pixel_size", size / 64.0 * 0.55, 0.12)
	tw.tween_property(s, "modulate:a", 0.0, 0.14)
	tw.chain().tween_callback(s.queue_free)


func ring(at: Vector2, radius: float, color: Color, dur := 0.45) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.93
	torus.outer_radius = 1.0
	torus.rings = 64
	torus.ring_segments = 6
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.BLACK
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.5
	var m := MeshInstance3D.new()
	m.mesh = torus
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = Vector3(at.x, 0.05, at.y)
	m.scale = Vector3(radius * 0.2, 0.1, radius * 0.2)
	add_child(m)
	var tw := create_tween().set_parallel()
	tw.tween_property(m, "scale", Vector3(radius, 0.1, radius), dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "emission_energy_multiplier", 0.0, dur)
	tw.chain().tween_callback(m.queue_free)


func number(pos: Vector3, text: String, color: Color, font_size := 76) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = _font
	l.modulate = color
	l.font_size = font_size
	l.outline_size = 18
	l.outline_modulate = Color(0.06, 0.02, 0.01)
	l.pixel_size = 0.0042
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos + Vector3(randf_range(-0.3, 0.3), 0, 0)
	add_child(l)
	var tw := create_tween().set_parallel()
	tw.tween_property(l, "position:y", pos.y + 0.7, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.45)
	tw.tween_property(l, "outline_modulate:a", 0.0, 0.35).set_delay(0.45)
	tw.chain().tween_callback(l.queue_free)


## Kan: Doom Forge'daki gibi vuruslar kanli ve agirdir. Parcaciklar ustten kararir, parlamaz.
func blood(pos: Vector3, count: int, spread: float) -> void:
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.75, 0.04, 0.03, 1.0))
	ramp.set_color(1, Color(0.28, 0.01, 0.01, 0.0))
	var p := CPUParticles3D.new()
	p.mesh = _quad(0.09, false)
	p.amount = count
	p.lifetime = 0.6
	p.one_shot = true
	p.explosiveness = 0.92
	p.spread = 70.0
	p.direction = Vector3.UP
	p.gravity = Vector3(0, -11, 0)
	p.initial_velocity_min = spread * 0.5
	p.initial_velocity_max = spread * 1.5
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.4
	p.color_ramp = ramp
	p.position = pos
	_emit(p, 0.6)


## Yere damlayan kan: mac boyunca kalir, sayisi sinirli.
func stain(at: Vector2, radius: float) -> void:
	if _stains.size() >= 18:
		_stains.pop_front().queue_free()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = 0.004
	c.radial_segments = 12
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.15, 0.008, 0.01, 0.82)
	m.roughness = 0.25
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var n := MeshInstance3D.new()
	n.mesh = c
	n.material_override = m
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.position = Vector3(at.x, 0.01, at.y)
	n.scale = Vector3(1.0 + randf() * 0.5, 1, 0.7 + randf() * 0.4)
	add_child(n)
	_stains.append(n)


func clear() -> void:
	for c in get_children():
		c.queue_free()
	_stains.clear()


## Yetenegin adi: kim ne kullandi ekranda okunur
func title(pos: Vector3, text: String, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = _font
	l.font_size = 64
	l.outline_size = 16
	l.modulate = color.lightened(0.25)
	l.outline_modulate = Color(0.05, 0.02, 0.01)
	l.pixel_size = 0.0042
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos
	add_child(l)
	var tw := create_tween().set_parallel()
	tw.tween_property(l, "position:y", pos.y + 0.35, 1.1)
	tw.tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.75)
	tw.tween_property(l, "outline_modulate:a", 0.0, 0.4).set_delay(0.75)
	tw.chain().tween_callback(l.queue_free)


func _pillar(color: Color, radius: float, height: float) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = radius * 0.7
	c.bottom_radius = radius
	c.height = height
	c.cap_top = false
	c.cap_bottom = false
	c.radial_segments = 24
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(color, 0.0)
	var n := MeshInstance3D.new()
	n.mesh = c
	n.material_override = m
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.position.y = height / 2.0
	return n


## Guclendirme: karakterin cevresinde yukselen isik sutunu
func aura(target: Node3D, color: Color, dur: float) -> void:
	var n := _pillar(color, 0.62, 2.2)
	target.add_child(n)
	var mat: StandardMaterial3D = n.material_override
	var tw := create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.045, 0.18)
	tw.tween_property(mat, "albedo_color:a", 0.0, dur)
	tw.tween_callback(n.queue_free)


## Saldiri hazirligi: ayak altinda daralan halka, yukselen kivilcimlar
func charge(target: Node3D, color: Color, dur: float) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	torus.rings = 48
	torus.ring_segments = 5
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.BLACK
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 3.0
	var n := MeshInstance3D.new()
	n.mesh = torus
	n.material_override = m
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.position.y = 0.05
	n.scale = Vector3(1.5, 0.1, 1.5)
	target.add_child(n)
	var tw := create_tween()
	tw.tween_property(n, "scale", Vector3(0.45, 0.1, 0.45), dur).set_ease(Tween.EASE_IN)
	tw.tween_callback(n.queue_free)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(color.r * 3.0, color.g * 3.0, color.b * 3.0, 1.0))
	ramp.set_color(1, Color(color, 0.0))
	var p := CPUParticles3D.new()
	p.mesh = _quad(0.13, true)
	p.amount = 20
	p.lifetime = minf(dur, 0.6)
	p.one_shot = true
	p.explosiveness = 0.2
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.6
	p.direction = Vector3.UP
	p.spread = 20.0
	p.gravity = Vector3(0, 2.0, 0)
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.2
	p.color_ramp = ramp
	p.position.y = 0.5
	target.add_child(p)
	p.emitting = true
	get_tree().create_timer(dur + 0.3).timeout.connect(p.queue_free)


static var _arc_tex: ImageTexture


## Hilal bicimli kesik izi: yetenegin isabet ettigi an
func slash(pos: Vector3, side: float, color: Color, size: float) -> void:
	if _arc_tex == null:
		var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
		for y in 128:
			for x in 128:
				var o := Vector2(x - 64, y - 64)
				var r := o.length() / 64.0
				var a := o.angle()
				var band := clampf(1.0 - absf(r - 0.78) / 0.16, 0.0, 1.0)
				var along := clampf(1.0 - absf(a) / 1.35, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, band * along * along))
		_arc_tex = ImageTexture.create_from_image(img)
	var s := Sprite3D.new()
	s.texture = _arc_tex
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.no_depth_test = true
	s.flip_h = side < 0.0
	s.modulate = Color(color.r * 2.2, color.g * 2.2, color.b * 2.2, 1.0)
	s.pixel_size = size / 128.0 * 0.5
	s.position = pos
	add_child(s)
	var tw := create_tween().set_parallel()
	tw.tween_property(s, "pixel_size", size / 128.0 * 0.85, 0.2).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "modulate:a", 0.0, 0.26)
	tw.chain().tween_callback(s.queue_free)


static var _streak_tex: GradientTexture2D


## Saplama: dusmani delip gecen ince isik cizgisi
func thrust(pos: Vector3, side: float, color: Color) -> void:
	if _streak_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 0))
		g.add_point(0.75, Color(1, 1, 1, 1))
		g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
		_streak_tex = GradientTexture2D.new()
		_streak_tex.gradient = g
		_streak_tex.width = 256
		_streak_tex.height = 8
	var s := Sprite3D.new()
	s.texture = _streak_tex
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.no_depth_test = true
	s.flip_h = side < 0.0
	s.modulate = Color(color.r * 2.5, color.g * 2.5, color.b * 2.5, 1.0)
	s.pixel_size = 0.012
	s.position = pos
	add_child(s)
	var tw := create_tween().set_parallel()
	tw.tween_property(s, "position:x", pos.x + side * 0.9, 0.2)
	tw.tween_property(s, "modulate:a", 0.0, 0.22)
	tw.chain().tween_callback(s.queue_free)


## Hedefte beliren capraz yara izi
func cross(pos: Vector3, color: Color, size: float) -> void:
	slash(pos + Vector3(-0.12, 0.1, 0), -1.0, color, size)
	slash(pos + Vector3(0.12, -0.1, 0), 1.0, color, size)


## Yukari dogru suzulen isik: iyilesme ve guclenme
func rise(target: Node3D, color: Color) -> void:
	var ramp := Gradient.new()
	ramp.set_color(0, Color(color.r * 2.5, color.g * 2.5, color.b * 2.5, 1.0))
	ramp.set_color(1, Color(color, 0.0))
	var p := CPUParticles3D.new()
	p.mesh = _quad(0.14, true)
	p.amount = 34
	p.lifetime = 1.0
	p.one_shot = true
	p.explosiveness = 0.25
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.5
	p.direction = Vector3.UP
	p.spread = 15.0
	p.gravity = Vector3(0, 1.5, 0)
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.6
	p.color_ramp = ramp
	p.position.y = 0.4
	target.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.4).timeout.connect(p.queue_free)


## Agir vurus: yerde koyu iz, toz ve sok halkasi
func crater(at: Vector2, color: Color, radius: float) -> void:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = 0.01
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.1, 0.06, 0.04, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var n := MeshInstance3D.new()
	n.mesh = c
	n.material_override = m
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.position = Vector3(at.x, 0.012, at.y)
	n.scale = Vector3(1, 1, 0.8)
	add_child(n)
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.9)
	tw.tween_callback(n.queue_free)
	ring(at, radius * 1.3, color, 0.4)
	dust(Vector3(at.x, 0.1, at.y), 12, radius * 0.9)