class_name ClipCheck
extends Node
## Gelistirici testi: oyunun gercek kamerasindan gorunen silah-govde gecmelerini kare kare olcer.
## Kalkan (Titan'da balyoz) ile vucut ayri ayri derinlik goruntusu olarak cizilir, piksel piksel karsilastirilir.
## Iki yuzey yan yana piksellerde yumusakca sira degistiriyorsa gercek kesisim vardir. Ani sira degisimi
## (kol kalkanin onunden geciyor) ve baska bir seyin arkasinda kalan pikseller sayilmaz.
## Sabit adimla calisir (--fixed-fps 60): ayni komut ayni tabloyu verir.

const LAYER_FIRST := 15 # S0, B0, S1, B1, W sirasiyla
const CONTINUITY := 25 # mm: bir pikselde bundan buyuk atlama kesisim degildir
const MIN_PIXELS := 3 # bundan azi gurultu sayilir
const OCCLUDE_MARGIN := 5
const EVERY := 2 # her 2. kare olculur (saniyede 30)
const CROP := 640
const CELL := 300
const HAND_SKIP := 0.13 # balyozu tutan eller sapa degebilir
const BONES := ["pelvis", "spine_01", "spine_03", "neck_01", "Head", "upperarm_l", "lowerarm_l", "hand_l", "upperarm_r", "lowerarm_r", "hand_r", "thigh_l", "calf_l", "thigh_r", "calf_r"]
const NAMES := {"warrior": "paladin", "brute": "titan", "assassin": "berserker"}
const SHADER := "shader_type spatial;
render_mode unshaded, shadows_disabled, fog_disabled, ambient_light_disabled;
float to_linear(float v) { return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4); }
void fragment() {
	float mm = clamp(round(length(VERTEX) * 1000.0), 0.0, 65000.0);
	float hi = floor(mm / 256.0);
	float lo = mm - hi * 256.0;
	ALBEDO = vec3(to_linear(hi / 255.0), to_linear(lo / 255.0), 1.0);
}"

var m: GameMain
var dir := ""
var cls := "warrior"
var tag := "once"
var mode := "" # ic / uzak / arka: aracin kendisini sinar
var _material: ShaderMaterial
var _ports: Array[SubViewport] = []
var _cams: Array[Camera3D] = []
var _bones: Array[Dictionary] = [{}, {}]
var _rows: Array[String] = []
var _cells: Array[Array] = [] # satir > taraf > [hazirlik, vurus, toparlanma, en kotu]
var _csv := PackedStringArray(["hareket,kare,sn,asama,taraf,kesisim_px,derin_mm,gomulen_yuzde,kemik"])
var _all: Array[Array] = []
var _main_image: Image


func run() -> void:
	seed(1)
	m._hud.visible = false
	await get_tree().create_timer(0.5).timeout
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	m._mode = GameMain.Mode.AI
	m._begin(Rules.new_character("A", cls, GameMain.TEST_LEVEL, 1, rng), Rules.new_character("B", cls, GameMain.TEST_LEVEL, 1, rng), 1, 0)
	m._hud.visible = false
	m._brains = []
	for e in m._battle.ents:
		e.s = e.s.duplicate()
		e.s["max_hp"] = 9000000.0
		e.hp = 9000000.0
		e.atk_t = 9999.0
	_build()
	await _wait(4)
	if not await _calibrate():
		get_tree().quit()
		return
	if mode != "":
		await _self_test()
		get_tree().quit()
		return
	var limit: float = float(m._me.s["range"]) + 0.15
	await _measure("yurume", 0.0, func() -> bool: return m._me.pos.distance_to(m._foe.pos) > limit, 4.0)
	await _measure("bekleme", 0.0, Callable(), 1.6)
	for n in 2:
		for e in m._battle.ents:
			e.atk_t = 0.0
		var swing: float = m._me.s["swing"]
		await _measure("normal%d" % (n + 1), swing, Callable(), swing + 1.3)
		for e in m._battle.ents:
			e.atk_t = 9999.0
	for id: String in GameData.CLASSES[cls]["skills"]:
		for e in m._battle.ents:
			e.cds.clear()
			e.gcd = 0.0
			m._battle.command({"ent": e.id, "type": "skill", "skill": id})
		var wind: float = GameData.SKILLS[id].get("windup", 0.0)
		await _measure(id, wind, Callable(), wind + 2.2)
	_save()
	get_tree().quit()


func _build() -> void:
	_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SHADER
	_material.shader = shader
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	var size: Vector2i = get_viewport().get_texture().get_image().get_size()
	for i in 5:
		var port := SubViewport.new()
		port.size = size
		port.world_3d = get_viewport().world_3d
		port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(port)
		var cam := Camera3D.new()
		port.add_child(cam)
		cam.fov = m._camera.fov
		cam.near = m._camera.near
		cam.far = m._camera.far
		cam.global_transform = m._camera.global_transform
		cam.environment = env
		cam.cull_mask = 1 << (LAYER_FIRST + i)
		cam.make_current()
		_ports.append(port)
		_cams.append(cam)
	for bit in 5:
		m._camera.cull_mask &= ~(1 << (LAYER_FIRST + bit))
	for i in 2:
		var v: CharacterView = m._views[i]
		for mesh: MeshInstance3D in v._meshes:
			if mesh.visible:
				_copy(mesh, LAYER_FIRST + 1 + i * 2)
		for mesh: MeshInstance3D in _weapon_meshes(v):
			_copy(mesh, LAYER_FIRST + i * 2)
		if v.rig == null:
			for n in v._hand.get_children():
				if n is MeshInstance3D:
					_copy(n, LAYER_FIRST + 4)
		for bone: String in BONES:
			var a := BoneAttachment3D.new()
			v._skeleton.add_child(a)
			a.bone_name = bone
			_bones[i][bone] = a


func _weapon_meshes(v: CharacterView) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var holder: Node3D = v.rig.weapon if v.rig != null else v._shield
	for n in holder.get_children():
		if n is MeshInstance3D:
			out.append(n)
	return out


func _copy(src: MeshInstance3D, layer: int) -> void:
	var d := MeshInstance3D.new()
	d.mesh = src.mesh
	d.skin = src.skin
	d.transform = src.transform
	d.layers = 1 << layer
	d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	d.material_override = _material
	src.get_parent().add_child(d)
	if src.skin != null:
		d.skeleton = d.get_path_to(src.get_node(src.skeleton))


func _wait(frames: int) -> void:
	for i in frames:
		await RenderingServer.frame_post_draw


## Bilinen mesafedeki duzlem: derinlik kodlamasi gercek milimetreyi vermeli.
func _calibrate() -> bool:
	var cam := _cams[0]
	var want := 7123
	var quad := MeshInstance3D.new()
	var plane := QuadMesh.new()
	plane.size = Vector2(0.6, 0.6)
	quad.mesh = plane
	quad.layers = 1 << LAYER_FIRST
	quad.material_override = _material
	add_child(quad)
	quad.global_transform = cam.global_transform
	quad.global_position += -cam.global_transform.basis.z * want / 1000.0
	await _wait(4)
	var s := _ports[0].size / 2
	var got := _decode(_ports[0].get_texture().get_image(), Rect2i(s.x, s.y, 1, 1))[0]
	quad.queue_free()
	await _wait(2)
	print("KALIBRASYON beklenen %d mm, olculen %d mm" % [want, got])
	return absi(got - want) <= 3


func _decode(img: Image, rect: Rect2i) -> PackedInt32Array:
	img.convert(Image.FORMAT_RGBA8)
	var d := img.get_region(rect).get_data()
	var out := PackedInt32Array()
	out.resize(rect.size.x * rect.size.y)
	for i in out.size():
		if d[i * 4 + 2] >= 128:
			out[i] = d[i * 4] * 256 + d[i * 4 + 1]
	return out


func _weapon_box(i: int) -> Rect2i:
	var v: CharacterView = m._views[i]
	var center: Vector3
	var radius := 0.42
	if v.rig != null:
		center = v.rig.weapon.global_position + v.rig.weapon.global_transform.basis.y * 0.5
		radius = 0.85
	elif v._shield != null:
		center = v._shield.global_position
	else: # Mixamo Titan: balyoz sag el yuvasinda (rig yok); sapin ortasi
		center = v._hand.global_position + v._hand.global_transform.basis.y * 0.6
		radius = 0.85
	var cam := _cams[i * 2]
	var c := cam.unproject_position(center)
	var r := int(c.distance_to(cam.unproject_position(center + cam.global_transform.basis.x * radius))) + 2
	return Rect2i(int(c.x) - r, int(c.y) - r, r * 2, r * 2).intersection(Rect2i(Vector2i.ZERO, _ports[0].size))


## Tek kare, tek savasci: {px, deep, pct, spots, bone}
func _check(i: int, images: Array[Image]) -> Dictionary:
	var box := _weapon_box(i)
	var result := {"px": 0, "deep": 0, "pct": 0.0, "spots": PackedVector2Array(), "bone": ""}
	if box.size.x < 4 or box.size.y < 4:
		return result
	var other := 1 - i
	var w := box.size.x
	var h := box.size.y
	var ds := _decode(images[i * 2], box)
	var db := _decode(images[i * 2 + 1], box)
	var os0 := _decode(images[other * 2], box)
	var ob0 := _decode(images[other * 2 + 1], box)
	var wp := _decode(images[4], box)
	var size := w * h
	var diff := PackedInt32Array()
	diff.resize(size)
	var valid := PackedByteArray()
	valid.resize(size)
	var shield_px := 0
	for p in size:
		if ds[p] > 0:
			shield_px += 1
			if db[p] > 0:
				valid[p] = 1
				diff[p] = ds[p] - db[p] # artiysa vucut kalkanin onunde
	var hands: Array[Vector2] = []
	var v: CharacterView = m._views[i]
	if v.rig != null:
		var cam := _cams[i * 2]
		for bone: String in ["hand_l", "hand_r"]:
			var at: Vector3 = _bones[i][bone].global_position
			hands.append(cam.unproject_position(at))
			hands.append(cam.unproject_position(at + cam.global_transform.basis.x * HAND_SKIP))
	var stack := PackedInt32Array()
	var seen := PackedByteArray()
	seen.resize(size)
	var spots := PackedVector2Array()
	var line := PackedInt32Array()
	for y in h:
		for x in w:
			var p := y * w + x
			if valid[p] == 0:
				continue
			for q: int in [p + 1 if x + 1 < w else -1, p + w if y + 1 < h else -1]:
				if q < 0 or valid[q] == 0:
					continue
				var a := diff[p]
				var b := diff[q]
				if (a >= 0) == (b >= 0) or absi(a) + absi(b) > CONTINUITY:
					continue
				var front := mini(ds[p], db[p])
				var hidden := false
				for o: int in [os0[p], ob0[p], wp[p]]:
					if o > 0 and o < front - OCCLUDE_MARGIN:
						hidden = true
				if hidden:
					continue
				var pos := Vector2(box.position.x + x, box.position.y + y)
				var skip := false
				for n in range(0, hands.size(), 2):
					if pos.distance_to(hands[n]) < hands[n].distance_to(hands[n + 1]):
						skip = true
				if skip:
					continue
				spots.append(pos)
				line.append(p)
				var inside := p if a >= 0 else q
				if seen[inside] == 0:
					seen[inside] = 1
					stack.append(inside)
	result["px"] = spots.size()
	result["spots"] = spots
	if spots.size() < MIN_PIXELS:
		return result
	# Kesisim cizgisinden baslayip vucudun altinda kalan kalkan bolgesini yay
	var area := PackedInt32Array()
	while not stack.is_empty():
		var p: int = stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		area.append(p)
		var x := p % w
		for q: int in [p - 1 if x > 0 else -1, p + 1 if x + 1 < w else -1, p - w, p + w]:
			if q >= 0 and q < size and valid[q] == 1 and seen[q] == 0 and diff[q] >= 0 and absi(diff[q] - diff[p]) <= CONTINUITY:
				seen[q] = 1
				stack.append(q)
	result["pct"] = 100.0 * area.size() / maxi(shield_px, 1)
	# Derinlik: kalkan yuzeyinin kesisim cizgisinden vucudun icine dogru ilerledigi gercek 3B mesafe
	var cam := _cams[i * 2]
	var edge: Array[Vector3] = []
	for n in range(0, line.size(), maxi(line.size() / 60, 1)):
		edge.append(_point(cam, box, line[n], ds[line[n]]))
	var deep := 0.0
	var far_point := Vector3.ZERO
	for n in range(0, area.size(), maxi(area.size() / 400, 1)):
		var at := _point(cam, box, area[n], ds[area[n]])
		var near := INF
		for e: Vector3 in edge:
			near = minf(near, at.distance_to(e))
		if near > deep:
			deep = near
			far_point = at
	result["deep"] = int(deep * 1000.0)
	var best := INF
	for bone: String in BONES:
		var d: float = far_point.distance_to(_bones[i][bone].global_position)
		if d < best:
			best = d
			result["bone"] = bone
	return result


func _point(cam: Camera3D, box: Rect2i, p: int, mm: int) -> Vector3:
	var pix := Vector2(box.position.x + p % box.size.x, box.position.y + p / box.size.x)
	return cam.project_ray_origin(pix) + cam.project_ray_normal(pix) * mm / 1000.0

func _measure(label: String, wind: float, until: Callable, secs: float) -> void:
	_rows.append(label)
	var row: Array = [[null, null, null, null], [null, null, null, null]]
	_cells.append(row)
	var times := [wind * 0.6, wind + 0.02, wind + 0.45] if wind > 0.0 else [0.3, 0.8, 1.3]
	var worst := [-1, -1]
	var frame := 0
	var done := [false, false, false]
	while true:
		var t := frame / 60.0
		var going: bool = until.call() if until.is_valid() and t < secs else t < secs
		if not going:
			break
		await RenderingServer.frame_post_draw
		frame += 1
		var key := -1
		for k in 3:
			if not done[k] and t >= times[k]:
				key = k
				done[k] = true
		if frame % EVERY != 0 and key < 0:
			continue
		var images: Array[Image] = []
		for port in _ports:
			images.append(port.get_texture().get_image())
		_main_image = null
		for i in 2:
			var r := _check(i, images)
			var side := "sol" if i == 0 else "sag"
			var phase := "bekleme" if wind <= 0.0 else ("hazirlik" if t < wind else ("vurus" if t < wind + 0.3 else "toparlanma"))
			_csv.append("%s,%d,%.3f,%s,%s,%d,%d,%.1f,%s" % [label, frame, t, phase, side, r["px"], r["deep"], r["pct"], r["bone"]])
			var hit: bool = r["px"] >= MIN_PIXELS
			if hit:
				_all.append([label, t, phase, side, r["px"], r["deep"], r["pct"], r["bone"]])
			if key >= 0:
				row[i][key] = _cell(i, r)
			if hit and int(r["deep"]) * 1000 + int(r["px"]) > int(worst[i]):
				worst[i] = int(r["deep"]) * 1000 + int(r["px"])
				row[i][3] = _cell(i, r)


func _cell(i: int, r: Dictionary) -> Image:
	if _main_image == null:
		_main_image = get_viewport().get_texture().get_image()
		_main_image.convert(Image.FORMAT_RGBA8)
	var c := _cams[0].unproject_position(m._views[i].global_position + Vector3(0, 1.05, 0))
	var bounds := Rect2i(Vector2i.ZERO, _main_image.get_size())
	var rect := Rect2i(int(c.x) - CROP / 2, int(c.y) - CROP / 2, CROP, CROP).intersection(bounds)
	var img := _main_image.get_region(rect)
	var hit: bool = r["px"] >= MIN_PIXELS
	if hit:
		for s: Vector2 in r["spots"]:
			var at := Vector2i(s) - rect.position
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var q := at + Vector2i(dx, dy)
					if q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height():
						img.set_pixelv(q, Color.RED)
	img.resize(CELL, CELL)
	if hit:
		for k in 6:
			for n in CELL:
				img.set_pixel(n, k, Color.RED)
				img.set_pixel(n, CELL - 1 - k, Color.RED)
				img.set_pixel(k, n, Color.RED)
				img.set_pixel(CELL - 1 - k, n, Color.RED)
	return img


func _save() -> void:
	var base := dir.path_join("%s_%s" % [NAMES[cls], tag])
	var sheet := Image.create(CELL * 8, CELL * _rows.size(), false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.08, 0.08, 0.1))
	for y in _rows.size():
		for side in 2:
			for k in 4:
				var img: Image = _cells[y][side][k]
				if img != null:
					sheet.blit_rect(img, Rect2i(0, 0, CELL, CELL), Vector2i((side * 4 + k) * CELL, y * CELL))
	sheet.save_png(base + "_ham.png")
	var f := FileAccess.open(base + ".csv", FileAccess.WRITE)
	f.store_string("\n".join(_csv) + "\n")
	FileAccess.open(base + "_satirlar.txt", FileAccess.WRITE).store_string("\n".join(_rows))
	_all.sort_custom(func(a: Array, b: Array) -> bool: return [a[5], a[4]] > [b[5], b[4]])
	var lines := PackedStringArray()
	var used := {}
	for e: Array in _all: # ayni hareket ve taraftan en cok 3 kare: tablo tek harekete sikismasin
		var k := "%s %s" % [e[0], e[3]]
		used[k] = int(used.get(k, 0)) + 1
		if used[k] <= 3 and lines.size() < 15:
			lines.append("%s | %.2f sn | %s | %s | %d px | %d mm | %.1f%% | %s" % e)
	FileAccess.open(base + "_en_kotu.txt", FileAccess.WRITE).store_string("\n".join(lines))
	print("ISARETLI KARE %d / %d" % [_all.size(), _csv.size() - 1])
	print("\n".join(lines))


## Bilinen durumlar: arac dogruyu soyluyor mu?
func _self_test() -> void:
	var v: CharacterView = m._views[0]
	if mode == "el":
		await _hand_report()
		return
	var sk_basis := v._skeleton.global_transform.basis
	if mode.begins_with("ic"): # ic5 = kalkan yuzey normali boyunca 5 cm govdeye
		v.guard.test_push = -Vector3(ShieldRig.GUARD[1]).normalized() * mode.trim_prefix("ic").to_float() / 100.0
	elif mode == "uzak":
		v.guard.test_push = sk_basis.inverse() * Vector3(0, 0, 0.7)
	elif mode == "arka":
		v.guard.test_push = sk_basis.inverse() * Vector3(0, 0, -0.7)
	await _wait(40)
	var px := 0
	var deep := 0
	var pct := 0.0
	for n in 20:
		await _wait(2)
		var images: Array[Image] = []
		for port in _ports:
			images.append(port.get_texture().get_image())
		var r := _check(0, images)
		px = maxi(px, r["px"])
		deep = maxi(deep, r["deep"])
		pct = maxf(pct, r["pct"])
		if n == 19:
			_main_image = null
			_cell(0, r).save_png(dir.path_join("sinama_%s.png" % mode))
			print("kemik ", r["bone"])
	print("SINAMA %s: kesisim %d px, derin %d mm, gomulen %.1f%%" % [mode, px, deep, pct])


## Kalkan eli: basparmak yukari mi, el yakin plan neye benziyor?
func _hand_report() -> void:
	var marks: Array[Dictionary] = [{}, {}]
	for i in 2:
		for bone: String in ["thumb_02_l", "hand_l", "middle_01_l"]:
			var a := BoneAttachment3D.new()
			m._views[i]._skeleton.add_child(a)
			a.bone_name = bone
			marks[i][bone] = a
	await _wait(60)
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	for i in 2:
		var hand: Vector3 = marks[i]["hand_l"].global_position
		var fingers: Vector3 = (marks[i]["middle_01_l"].global_position - hand).normalized()
		var thumb: Vector3 = marks[i]["thumb_02_l"].global_position - hand
		print("EL %d basparmak yukari orani %.2f" % [i, (thumb - fingers * thumb.dot(fingers)).normalized().y])
		var c := _cams[0].unproject_position(hand)
		var crop := img.get_region(Rect2i(int(c.x) - 100, int(c.y) - 100, 200, 200).intersection(Rect2i(Vector2i.ZERO, img.get_size())))
		crop.resize(900, 900)
		crop.save_png(dir.path_join("el_%d.png" % i))
