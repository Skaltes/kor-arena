class_name ArenaView
extends Node3D
## Doom Forge atmosferinde karanlik, seyircisiz Roma amfisi: mavi golgeler, kor isigi, kan. Sade (kullanici istegi):
## zincir, diken, mizrak, sutun parcalari ve alev parcaciklari kaldirildi; mangallarda yalniz parlayan kor ve sicak isik.
## Kamera amfinin icinde durur, her sey arkadadir; hicbir parca hareket etmez.

const CENTER := Vector3(0, 0, 10) # amfi halkalarinin merkezi
const WALL_R := 18.0 # savas alani duvarinin yaricapi
const WALL_H := 2.0
const SEAT_ROWS := 4
const SEAT_DEPTH := 1.0
const SEAT_RISE := 0.55


var _env: Environment


func _ready() -> void:
	_build_environment()
	_build_sand()
	_build_podium()
	_build_gate()
	_build_seats()
	_build_arcade()
	_build_war_props()
	_build_fires()


func _build_environment() -> void:
	var sky_mat := PanoramaSkyMaterial.new()
	sky_mat.panorama = load("res://assets/pbr/sky.hdr")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128 # dusuk: hafif, yansimalar yine gercekci
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.sky_rotation = Vector3(0, deg_to_rad(200), 0)
	env.background_energy_multiplier = 0.012 # gece: kemerlerin ardi koyu
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.2, 0.27, 0.44)
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.1
	env.tonemap_white = 3.5
	env.glow_enabled = true
	env.glow_intensity = 0.85
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	env.ssao_enabled = true
	env.ssao_radius = 0.9
	env.ssao_intensity = 2.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.07, 0.13)
	env.fog_density = 0.022
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	env.adjustment_contrast = 1.12
	var world := WorldEnvironment.new()
	world.environment = env
	_env = env
	add_child(world)

	# Ay isigi: soguk golgeler
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-48, -24, 0)
	moon.light_color = Color(0.55, 0.68, 1.0)
	moon.light_energy = 0.55
	moon.shadow_enabled = true
	moon.shadow_blur = 1.5
	moon.directional_shadow_max_distance = 45.0
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(moon)

	# Savas alanina dusen isik havuzu: Doom Forge'daki gibi savascilar karanliktan ayrilir
	var key := SpotLight3D.new()
	key.position = Vector3(0.0, 7.5, 4.5)
	key.rotation_degrees = Vector3(-62, 0, 0)
	key.light_color = Color(1.0, 0.9, 0.78)
	key.light_energy = 42.0
	key.spot_range = 14.0
	key.spot_angle = 36.0
	key.spot_angle_attenuation = 0.8
	key.shadow_enabled = true
	add_child(key)

	# Zirhlarin one bakan yuzu kararmasin
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 1.8, 6.5)
	fill.light_color = Color(1.0, 0.78, 0.6)
	fill.light_energy = 1.3
	fill.omni_range = 9.0
	add_child(fill)

	# Arkadan soguk kenar isigi: koyu zirhlar karanlik duvardan ayrilir, silueti okunur
	var rim := OmniLight3D.new()
	rim.position = Vector3(0, 2.6, -2.2)
	rim.light_color = Color(0.45, 0.62, 1.0)
	rim.light_energy = 2.2
	rim.omni_range = 5.5
	add_child(rim)

## Poly Haven CC0 tas dokusu. Doku dunya olcegine gore dosenir; uzun duvarda esnemez.
func _pbr(tex: String, world_scale: float, tint := Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/pbr/%s_albedo.jpg" % tex)
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load("res://assets/pbr/%s_normal.jpg" % tex)
	m.normal_scale = 1.3
	m.roughness_texture = load("res://assets/pbr/%s_rough.jpg" % tex)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * world_scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _stone_material(world_scale: float) -> StandardMaterial3D:
	return _pbr("wall", world_scale * 0.5, Color(0.55, 0.58, 0.68))

func _mesh(mesh: Mesh, mat: Material, pos: Vector3, shadow := true) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	return m


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _cyl(top: float, bottom: float, h: float, segments := 16, caps := true) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = segments
	c.cap_top = caps
	c.cap_bottom = caps
	return c


func _color_mat(color: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m


func _build_sand() -> void:
	var m := _pbr("wall", 0.2, Color(0.5, 0.54, 0.66))
	_mesh(_cyl(WALL_R + 0.2, WALL_R + 0.2, 0.1, 96), m, CENTER + Vector3(0, -0.05, 0), false)

	# Savas alanini gosteren eski kan izi ve iz halkasi
	var mark := _color_mat(Color(0.12, 0.01, 0.012), 0.3)
	mark.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mark.albedo_color.a = 0.78
	for p: Vector3 in [Vector3(-2.9, 0.006, -1.3), Vector3(3.0, 0.006, 1.0), Vector3(0.8, 0.006, -2.4), Vector3(-1.2, 0.006, 2.0), Vector3(5.2, 0.006, -2.8)]:
		var stain := _cyl(0.5, 0.5, 0.004, 14)
		_mesh(stain, mark, p, false).scale = Vector3(1.4, 1, 0.7)


func _on_wall(x: float, offset := 0.0) -> float:
	var r := WALL_R - offset
	return CENTER.z - sqrt(r * r - x * x)


func _build_podium() -> void:
	var stone := _pbr("wall", 0.21, Color(0.55, 0.58, 0.68))
	_mesh(_cyl(WALL_R, WALL_R, WALL_H, 96, false), stone, CENTER + Vector3(0, WALL_H / 2.0, 0))
	var cap := _cyl(WALL_R + 0.22, WALL_R - 0.16, 0.22, 96, false)
	_mesh(cap, _pbr("marble", 0.5, Color(0.86, 0.8, 0.7)), CENTER + Vector3(0, WALL_H + 0.1, 0), false)


func _build_gate() -> void:
	var z := _on_wall(0.0, 0.02)
	var dark := _color_mat(Color(0.012, 0.01, 0.01))
	_mesh(_box(Vector3(3.6, WALL_H - 0.05, 0.1)), dark, Vector3(0, WALL_H / 2.0, z), false)
	var iron := _color_mat(Color(0.14, 0.12, 0.11), 0.5, 0.8)
	for i in 8:
		_mesh(_box(Vector3(0.07, WALL_H - 0.1, 0.07)), iron, Vector3(-1.56 + i * 0.446, WALL_H / 2.0, z + 0.1))
	for y: float in [0.55, 1.35]:
		_mesh(_box(Vector3(3.5, 0.07, 0.07)), iron, Vector3(0, y, z + 0.13))
	var frame := _stone_material(0.5)
	for x: float in [-2.0, 2.0]:
		_mesh(_box(Vector3(0.42, WALL_H + 0.1, 0.5)), frame, Vector3(x, WALL_H / 2.0, _on_wall(x, 0.2)))
	_mesh(_box(Vector3(4.5, 0.42, 0.5)), frame, Vector3(0, WALL_H + 0.16, z + 0.2))


func _build_seats() -> void:
	var stone := _stone_material(0.3)
	for i in SEAT_ROWS:
		var r := WALL_R + (i + 1) * SEAT_DEPTH
		var y := WALL_H + 0.2 + (i + 1) * SEAT_RISE
		_mesh(_cyl(r - SEAT_DEPTH, r - SEAT_DEPTH, SEAT_RISE, 96, false), stone, CENTER + Vector3(0, y - SEAT_RISE / 2.0, 0))
		_mesh(_cyl(r, r - SEAT_DEPTH, 0.01, 96, false), stone, CENTER + Vector3(0, y, 0), false)


## Ortasi kemer bicimli bos duvar parcasi. Tek parca yapilip amfi boyunca cogaltilir.
func _arch_mesh(width: float, height: float, opening: float, spring: float, depth: float) -> ArrayMesh:
	var outline := PackedVector2Array()
	outline.append(Vector2(-width / 2.0, 0))
	outline.append(Vector2(-opening, 0))
	outline.append(Vector2(-opening, spring))
	for i in range(1, 16):
		var a := PI - PI * i / 16.0
		outline.append(Vector2(cos(a) * opening, spring + sin(a) * opening))
	outline.append(Vector2(opening, spring))
	outline.append(Vector2(opening, 0))
	outline.append(Vector2(width / 2.0, 0))
	outline.append(Vector2(width / 2.0, height))
	outline.append(Vector2(-width / 2.0, height))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tris := Geometry2D.triangulate_polygon(outline)
	var front := depth / 2.0
	for i in range(0, tris.size(), 3):
		var a := outline[tris[i]]
		var b := outline[tris[i + 1]]
		var c := outline[tris[i + 2]]
		_tri(st, Vector3(a.x, a.y, front), Vector3(b.x, b.y, front), Vector3(c.x, c.y, front), Vector3.BACK)
		_tri(st, Vector3(a.x, a.y, -front), Vector3(b.x, b.y, -front), Vector3(c.x, c.y, -front), Vector3.FORWARD)
	var centre := Vector2(0, height / 2.0)
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		var n := Vector3(b.y - a.y, a.x - b.x, 0).normalized()
		var inside_arch := i >= 1 and i <= 17
		if (Vector2(n.x, n.y).dot((a + b) / 2.0 - centre) < 0.0) != inside_arch:
			n = -n
		var p1 := Vector3(a.x, a.y, front)
		var p2 := Vector3(b.x, b.y, front)
		var p3 := Vector3(b.x, b.y, -front)
		var p4 := Vector3(a.x, a.y, -front)
		_tri(st, p1, p2, p3, n)
		_tri(st, p1, p3, p4, n)
	return st.commit()


## Godot on yuzu saat yonunde sayar: sira normale gore duzeltilir.
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		var swap := b
		b = c
		c = swap
	st.set_normal(n)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


func _build_arcade() -> void:
	var r := WALL_R + SEAT_ROWS * SEAT_DEPTH + 0.5
	var base_y := WALL_H + 0.2 + SEAT_ROWS * SEAT_RISE
	var bay := 3.0
	var step := bay / r
	var count := int(PI * 1.1 / step)
	var stone := _stone_material(0.42)
	var tall := _arch_mesh(bay + 0.04, 3.2, 1.0, 1.6, 0.9)
	var inst := MultiMesh.new()
	inst.transform_format = MultiMesh.TRANSFORM_3D
	inst.mesh = tall
	inst.instance_count = count * 2
	for storey in 2:
		var y := base_y + storey * 3.3
		for i in count:
			var a := (i - (count - 1) / 2.0) * step
			var basis := Basis(Vector3.UP, -a)
			inst.set_instance_transform(i + storey * count, Transform3D(basis, CENTER + Vector3(sin(a) * r, y, -cos(a) * r)))
	var node := MultiMeshInstance3D.new()
	node.multimesh = inst
	node.material_override = stone
	node.custom_aabb = AABB(Vector3(-40, 0, -40), Vector3(80, 30, 80))
	add_child(node)
	# Kemerler arasindaki sutunlar: amfiye asil derinligi bunlar verir
	var pillar := _cyl(0.2, 0.25, 3.0, 12)
	var pillars := MultiMesh.new()
	pillars.transform_format = MultiMesh.TRANSFORM_3D
	pillars.mesh = pillar
	pillars.instance_count = count * 2
	for storey in 2:
		var y := base_y + storey * 3.3 + 1.5
		for i in count:
			var a := (i - (count - 1) / 2.0 + 0.5) * step
			pillars.set_instance_transform(i + storey * count, Transform3D(Basis.IDENTITY, CENTER + Vector3(sin(a) * (r - 0.55), y, -cos(a) * (r - 0.55))))
	var column_node := MultiMeshInstance3D.new()
	column_node.multimesh = pillars
	column_node.material_override = _pbr("marble", 0.6, Color(0.88, 0.82, 0.72))
	column_node.custom_aabb = AABB(Vector3(-40, 0, -40), Vector3(80, 30, 80))
	add_child(column_node)
	# Kat aralarindaki saclik silmeleri
	var band := _pbr("marble", 0.5, Color(0.86, 0.8, 0.7))
	for storey in 3:
		var y := base_y + storey * 3.3 - 0.02
		var ledge := _cyl(r + 0.62, r - 0.62, 0.2, 96, false)
		_mesh(ledge, band, CENTER + Vector3(0, y, 0), false)


func _build_war_props() -> void:
	# Duvar flamalari: savas kartali yerine kor arenasinin isareti
	var red := _pbr("leather", 1.2, Color(0.3, 0.05, 0.05))
	var gold := _color_mat(Color(0.8, 0.58, 0.2), 0.45, 0.5)
	for x: float in [-11.0, -6.5, 6.5, 11.0]:
		var z := _on_wall(x, 0.06)
		var a := atan2(x, CENTER.z - z)
		_mesh(_box(Vector3(1.5, 1.55, 0.04)), red, Vector3(x, 1.15, z), false).rotation.y = -a
		_mesh(_box(Vector3(1.6, 0.08, 0.06)), gold, Vector3(x, 1.95, z), false).rotation.y = -a

	# Duvara asili kalkanlar
	var bronze := _color_mat(Color(0.62, 0.38, 0.16), 0.35, 0.85)
	var hide_mat := _pbr("wood", 1.5, Color(0.42, 0.12, 0.09))
	for x: float in [-3.4, 3.4, -8.8, 8.8]:
		var z := _on_wall(x, 0.1)
		var disc := _mesh(_cyl(0.46, 0.46, 0.08, 20), hide_mat, Vector3(x, 1.25, z))
		disc.rotation.x = PI / 2.0
		var boss := _mesh(_cyl(0.13, 0.13, 0.14, 12), bronze, Vector3(x, 1.25, z + 0.05))
		boss.rotation.x = PI / 2.0


## Kor: alev yerine mangalda duragan parlayan kor yuzeyi ve sicak isik (telefon cizimi parlak alevi beyaz kare yapiyordu).
## coals false: yalniz isik (duvar lambalari).
func _fire(pos: Vector3, size: float, coals := true) -> void:
	if coals:
		var coal := _color_mat(Color(0.12, 0.04, 0.02))
		coal.emission_enabled = true
		coal.emission = Color(1.0, 0.38, 0.1)
		coal.emission_energy_multiplier = 2.2
		_mesh(_cyl(0.44, 0.44, 0.04, 16), coal, pos, false)
	var l := OmniLight3D.new()
	l.position = pos + Vector3(0, 0.5, 0.6)
	l.light_color = Color(1.0, 0.5, 0.2)
	l.light_energy = 2.4 * size
	l.omni_range = 9.0
	add_child(l)


func _build_fires() -> void:
	var iron := _color_mat(Color(0.1, 0.09, 0.09), 0.45, 0.85)
	for x: float in [-5.4, 5.4]:
		var base := Vector3(x, 0.0, -5.2)
		_mesh(_cyl(0.06, 0.13, 1.5, 8), iron, base + Vector3(0, 0.75, 0))
		_mesh(_cyl(0.5, 0.22, 0.32, 12), iron, base + Vector3(0, 1.6, 0))
		_fire(base + Vector3(0, 1.77, 0), 1.3)
	for x: float in [-10.5, 10.5]:
		_fire(Vector3(x, 2.6, _on_wall(x, 0.5)), 0.9, false)

## Zayif bilgisayarda en pahali iki efekt kapanir, oyun gorunumu bozulmadan akici kalir.
func set_low_quality() -> void:
	_env.ssao_enabled = false
	_env.glow_enabled = false
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	get_viewport().scaling_3d_scale = 0.8
	if Version.phone(): # telefonun piksel sayisi ne olursa olsun yuk ayni kalsin; web cizimi renkleri zaten daha doygun gosterir
		var side: int = get_window().size[get_window().size.max_axis_index()]
		get_viewport().scaling_3d_scale = minf(1280.0 / side, 1.0)
		_env.adjustment_saturation = 1.0
		_env.adjustment_contrast = 1.0
		# Gercek zamanli golgeler telefonda ucgen yukunu ~3 katina cikariyordu (ay isigi iki parca + spot). Telefonda kapanir,
		# karakterlerin altinda ucuz leke golgesi durur (CharacterView._build_blob). PC degismez.
		for l: Light3D in find_children("*", "Light3D", true, false):
			l.shadow_enabled = false
