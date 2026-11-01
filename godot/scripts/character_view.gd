class_name CharacterView
extends Node3D
## Karakterin 3D gorunumu: Quaternius insan modeli, govdeye Blender'da oturtulan zirhlar (tools/build_hero.py)
## ve Universal Animation Library. Savas kodu bu dosyayi bilmez.
## Her hareket uc fazlidir: yavas hazirlik, ani vurus, toparlanma. Vurus ani "--calib" testiyle olculmustur.

const PREFIX := {"warrior": "W_", "assassin": "A_", "brute": "B_"}
const BODY_PARTS := ["SuperHero_Male", "Eyes", "Eyebrows"]
const HELMETS := ["W_Helmet", "W_Crest", "B_Helmet", "B_Horns"]
const CAPES: Array[String] = []

## anim: oynatilacak hareket, hit: animasyonda silahin hedefe indigi saniye (olculdu)
const ATTACKS := {
	"sword": [{"anim": "Sword_Regular_A", "hit": 0.25, "next": "Sword_Regular_A_Rec"}, {"anim": "Sword_Regular_B", "hit": 0.27, "next": "Sword_Regular_B_Rec"}],
	"axe": [{"anim": "Sword_Regular_B", "hit": 0.27, "next": "Sword_Regular_B_Rec"}, {"anim": "Sword_Regular_A", "hit": 0.25, "next": "Sword_Regular_A_Rec"}],
	"sledge": [{"anim": "Sword_Attack", "hit": 0.4, "move": "overhead"}, {"anim": "Sword_Regular_B", "hit": 0.27, "move": "side"}],
}
## fwd: one atilma (metre), lift: ziplama, spin: kac tam donus, stop: isabette duraklama, knock: rakibi itme
const MOTIONS := {
	"power": {"anim": "Sword_Attack", "hit": 0.4, "fwd": 0.45, "stop": 0.13, "knock": 0.32},
	"lunge": {"anim": "Sword_Dash", "hit": 0.33, "fwd": 1.0, "stop": 0.09, "knock": 0.2},
	"bash": {"anim": "Shield_Dash", "hit": 0.07, "fwd": 0.6, "stop": 0.12, "knock": 0.4},
	"cry": {"anim": "Spell_Simple_Shoot"},
	"second": {"anim": "Consume"},
	"whirl": {"anim": "Sword_Regular_C", "hit": 0.21, "more": [0.0, 0.44], "spin": 2.0, "rec": 1.0, "stop": 0.07, "knock": 0.2},
	"backstab": {"anim": "OverhandThrow", "hit": 0.37, "fwd": 0.7, "stop": 0.11, "knock": 0.18},
	"hamstring": {"anim": "Melee_Hook", "hit": 0.25, "fwd": 0.3, "stop": 0.07, "knock": 0.1},
	"poison": {"anim": "Sword_Dash", "hit": 0.33, "fwd": 0.55, "stop": 0.07, "knock": 0.1},
	"expose": {"anim": "Sword_Attack", "hit": 0.4, "fwd": 0.4, "stop": 0.09, "knock": 0.2},
	"frenzy": {"anim": "NinjaJump_Land", "lift": 0.35},
	"flurry": {"anim": "Sword_Regular_Combo", "hit": 0.25, "more": [0.0, 0.48, 1.32], "fwd": 0.25, "rec": 1.0, "stop": 0.05, "knock": 0.12},
	"smash": {"anim": "Sword_Attack", "hit": 0.4, "move": "overhead", "fwd": 0.4, "stop": 0.16, "knock": 0.45},
	"crush": {"anim": "Melee_Hook", "hit": 0.25, "move": "side", "fwd": 0.3, "stop": 0.12, "knock": 0.3},
	"quake": {"anim": "NinjaJump_Land", "hit": 0.07, "move": "ground", "lift": 0.55, "stop": 0.14, "knock": 0.3},
	"iron": {"anim": "Sword_Block", "move": "plant"},
	"rage": {"anim": "Spell_Simple_Shoot", "move": "roar"},
	"ruin": {"anim": "Sword_Attack", "hit": 0.4, "move": "charge", "lift": 0.3, "fwd": 0.55, "stop": 0.2, "knock": 0.6},
}
const LOOPS := ["Sword_Idle", "Idle_Shield", "Jog_Fwd", "Walk", "Zombie_Idle", "Spell_Simple_Idle"]
const HOLD_ROT := Vector3(1.57, 0, 0)
## Test: [kemik, sonraki kemik, yaricap] vucut parcalari
const BODY := [["spine_01", "neck_01", 0.15], ["Head", "Head", 0.13], ["thigh_l", "calf_l", 0.08], ["thigh_r", "calf_r", 0.08], ["upperarm_l", "lowerarm_l", 0.05]]
const HOLD_POS := Vector3(0.0, 0.09, 0.03)
const STRIKE_TIME := 0.13 # kaldirilmis silahin hedefe inme suresi: ani olmali
const RECOVER_SPEED := 0.85
const MAX_RECOVER := 0.9

static var _library: AnimationLibrary
static var _hero: PackedScene
static var _weapons: Node3D

var ent: Battle.Ent = null
var weapon_tip: Node3D
var rig: SledgeRig
var guard: ShieldRig
var worst_part := ""

var _model: Node3D
var _skeleton: Skeleton3D
var _ap: AnimationPlayer
var _meshes: Array[MeshInstance3D] = []
var _weapon := "sword"
var _action_t := 0.0
var _combo := 0
var _flash := 0.0
var _freeze := 0.0
var _died := false
var _flash_mat: StandardMaterial3D
var _phases: Array[Array] = [] # [sure, hiz] sirali fazlar
var _next_anim := ""
var _motion := {}
var _motion_t := -1.0
var _motion_wind := 0.0
var _knock := 0.0
var _hit_side := 0
var _charge_mat: StandardMaterial3D
var _charge := 0.0
var _trail_color := Color(1.0, 0.55, 0.15)
var _trail_width := 0.4
var _trail_mesh: ImmediateMesh
var _trail: Array[Array] = [] # silah izinin son konumlari
var _hand: Node3D
var _shield: Node3D
var _off_hand: Node3D
var _probes := {}


static func _load_shared() -> void:
	if _library != null:
		return
	_hero = load("res://assets/quaternius/Hero.glb")
	_weapons = load("res://assets/quaternius/Weapons.glb").instantiate()
	_library = AnimationLibrary.new()
	for file: String in ["UAL1", "UAL2"]:
		var src: Node = load("res://assets/quaternius/anim/%s.glb" % file).instantiate()
		var ap: AnimationPlayer = src.find_child("AnimationPlayer", true, false)
		for n: String in ap.get_animation_list():
			if not _library.has_animation(n):
				_library.add_animation(n, ap.get_animation(n))
		src.free()
	for n: String in LOOPS:
		_library.get_animation(n).loop_mode = Animation.LOOP_LINEAR


func setup(ch: Dictionary, battle_ent: Battle.Ent = null) -> void:
	_load_shared()
	ent = battle_ent
	_model = _hero.instantiate()
	add_child(_model)
	var big: float = 1.07 if ch["cls"] == "brute" else 1.0
	_model.scale = Vector3.ONE * big * (1.3 if ch.get("boss", false) else 1.0)
	_skeleton = _model.find_children("*", "Skeleton3D", true, false)[0]
	_ap = AnimationPlayer.new()
	_model.add_child(_ap)
	_ap.root_node = _ap.get_path_to(_skeleton.get_parent().get_parent())
	_ap.add_animation_library("", _library)
	for n in _model.find_children("*", "MeshInstance3D", true, false):
		_meshes.append(n)
	_dress(ch)
	_build_trail()
	_flash_mat = StandardMaterial3D.new()
	_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_mat.albedo_color = Color(1.0, 0.3, 0.2, 0.14)
	_charge_mat = StandardMaterial3D.new()
	_charge_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_charge_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_charge_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_ap.play(_idle_anim())
	_ap.seek(randf() * 1.0, true)
	if ent != null:
		_sync(1.0)


func _build_trail() -> void:
	_trail_mesh = ImmediateMesh.new()
	var node := MeshInstance3D.new()
	node.mesh = _trail_mesh
	node.top_level = true
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	node.material_override = m
	add_child(node)


## Vurus sirasinda silah ucunun cizdigi parlak yay
func _update_trail() -> void:
	if _action_t <= 0.0:
		_trail_color = Color(1.0, 0.55, 0.15)
		_trail_width = 0.4
	if _action_t > 0.0 and not _died:
		_trail.push_front([weapon_tip.global_position, _hand.global_position.lerp(weapon_tip.global_position, 0.88 if rig != null else 0.4)])
	if _trail.size() > 16 or (_action_t <= 0.0 and not _trail.is_empty()):
		_trail.pop_back()
	_trail_mesh.clear_surfaces()
	if _trail.size() < 2:
		return
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in _trail.size():
		var a := _trail_width * (1.0 - float(i) / _trail.size())
		_trail_mesh.surface_set_color(Color(_trail_color, a))
		_trail_mesh.surface_add_vertex(_trail[i][0])
		_trail_mesh.surface_set_color(Color(_trail_color, 0.0))
		_trail_mesh.surface_add_vertex(_trail[i][1])
	_trail_mesh.surface_end()


## Portre uretimi icin bas kemiginin dunya konumu
func head_position() -> Vector3:
	return _skeleton.global_transform * _skeleton.get_bone_global_pose(_skeleton.find_bone("Head")).origin


func _part(part: String) -> MeshInstance3D:
	for m in _meshes:
		if m.name == part:
			return m
	return null


func _dress(ch: Dictionary) -> void:
	var prefix: String = PREFIX[ch["cls"]]
	var eq: Dictionary = ch["equipped"]
	var cloth := Color(ch["look"]["cloth"]).lerp(Color.WHITE, 0.25)
	var armor_rarity: int = eq["armor"]["rarity"] if eq.get("armor") != null else 0
	var shine: Color = Color(GameData.RARITY[armor_rarity]["color"]).lerp(Color.WHITE, 0.65)
	for m in _meshes:
		var part := String(m.name)
		if BODY_PARTS.has(part):
			continue
		if not part.begins_with(prefix) or part == "W_Cape": # pelerin eglince sert levha gibi donuyordu
			m.visible = false
			continue
		if HELMETS.has(part):
			m.visible = eq.get("helmet") != null
		if CAPES.has(part):
			m.visible = armor_rarity >= 1
		for i in m.mesh.get_surface_count():
			var src: Material = m.mesh.surface_get_material(i)
			var id: String = src.resource_name if src != null else ""
			if Mats.RECIPES.has(id):
				var tint := Color.WHITE
				if id in ["M_Cloth", "M_Plume"]:
					tint = cloth
				elif id in ["M_Bronze", "M_Metal"]:
					tint = shine
				m.set_surface_override_material(i, Mats.get_mat(id, tint))
	var weapon: Dictionary = eq["weapon"]
	_weapon = weapon["type"]
	_attach_weapons(weapon)


func _piece(name_: String, parent: Node3D, tint := Color.WHITE, glow := 0.0) -> MeshInstance3D:
	var src: MeshInstance3D = _weapons.find_child(name_, true, false)
	var m := MeshInstance3D.new()
	m.mesh = src.mesh
	m.transform = src.transform
	parent.add_child(m)
	var mat: Material = src.mesh.surface_get_material(0)
	var id: String = mat.resource_name if mat != null else ""
	if Mats.RECIPES.has(id):
		m.material_override = Mats.get_mat(id, tint, glow)
	return m


func _bone_socket(bone: String, xf: Transform3D) -> Node3D:
	var a := BoneAttachment3D.new()
	_skeleton.add_child(a)
	a.bone_name = bone
	var n := Node3D.new()
	n.transform = xf
	a.add_child(n)
	return n


func _attach_weapons(item: Dictionary) -> void:
	var rarity: int = item["rarity"]
	var tint: Color = Color(GameData.RARITY[rarity]["color"]).lerp(Color.WHITE, 0.6)
	var glow: float = 0.4 if rarity >= 3 else 0.0
	var hand: Node3D
	if _weapon == "sledge":
		rig = SledgeRig.new()
		hand = Node3D.new()
		_skeleton.add_child(hand)
		rig.weapon = hand
		rig.flip = ent != null and ent.pos.x > 0.0
		_skeleton.add_child(rig)
	else:
		hand = _bone_socket("hand_r", Transform3D(Basis.from_euler(HOLD_ROT), HOLD_POS))
	_hand = hand
	var names: Dictionary = {"sword": "Sword", "greatsword": "Great", "axe": "Axe"}
	if _weapon == "sledge":
		_piece("Sledge_Shaft", hand)
		_piece("Sledge_Head", hand, tint, glow)
		_piece("Sledge_Band", hand)
	else:
		var n: String = names[_weapon]
		_piece(n + "_Blade", hand, tint, glow)
		_piece(n + "_Guard", hand)
		_piece(n + "_Grip", hand)
	if _weapon == "axe":
		var off := _bone_socket("hand_l", _mirror_mount())
		_off_hand = off
		_add_hand_rig([["hand_r", Basis.from_euler(HOLD_ROT) * Vector3.UP], ["hand_l", off.transform.basis * Vector3.UP]], true)
		_piece("Axe_Blade", off, tint, glow)
		_piece("Axe_Guard", off)
		_piece("Axe_Grip", off)
	if _weapon == "sword":
		_shield = Node3D.new()
		_skeleton.add_child(_shield)
		guard = ShieldRig.new()
		guard.shield = _shield
		_skeleton.add_child(guard)
		var sword_axis := Basis.from_euler(HOLD_ROT) * Vector3.UP
		_add_hand_rig([["hand_r", sword_axis]], false)
		_piece("Shield_Body", _shield, Color(0.82, 0.8, 0.78))
		_piece("Shield_Boss", _shield)
	weapon_tip = Node3D.new()
	hand.add_child(weapon_tip)
	weapon_tip.position = Vector3(0, {"sword": 0.8, "greatsword": 1.15, "axe": 0.62, "sledge": 1.1}[_weapon], 0)


## Sag eldeki tutusun sol ele aynasi: balta kolun degil avucun icinde durur.
func _mirror_mount() -> Transform3D:
	var right := _skeleton.get_bone_global_rest(_skeleton.find_bone("hand_r"))
	var left := _skeleton.get_bone_global_rest(_skeleton.find_bone("hand_l"))
	var hold := right * Transform3D(Basis.from_euler(HOLD_ROT), HOLD_POS)
	var flip := Basis.from_scale(Vector3(-1, 1, 1))
	var basis := flip * hold.basis * Basis.from_scale(Vector3(-1, 1, 1))
	var origin := flip * hold.origin
	return left.affine_inverse() * Transform3D(basis, origin)


func _add_hand_rig(hands: Array, curl: bool) -> void:
	var h := HandRig.new()
	h.hands = hands
	h.curl_left = curl
	_skeleton.add_child(h)

func _idle_anim() -> String:
	return "Idle_Shield" if _weapon == "sword" else "Sword_Idle"


## Hazirlik -> ani vurus -> toparlanma. "wind" sonunda silah animasyonda tam hedefe iner.
func _run(m: Dictionary, wind: float) -> void:
	var anim: String = m["anim"]
	var length := _ap.get_animation(anim).length
	_phases.clear()
	_next_anim = m.get("next", "")
	_ap.play(anim, 0.2, 1.0)
	if m.has("hit") and wind > 0.0:
		var hit: float = m["hit"]
		var strike := minf(STRIKE_TIME, wind * 0.4)
		var cocked := maxf(hit - strike * 1.1, 0.0)
		_phases.append([wind - strike, cocked / (wind - strike)])
		_phases.append([strike, (hit - cocked) / strike])
		var rec: float = m.get("rec", RECOVER_SPEED)
		var rest := (length - hit) / rec
		if not m.has("rec"):
			rest = minf(rest, MAX_RECOVER)
		_phases.append([rest, rec])
		_action_t = wind + rest
	else:
		var total := maxf(length, wind)
		_phases.append([total, length / total])
		_action_t = total
	if _next_anim != "":
		_action_t += _ap.get_animation(_next_anim).length / RECOVER_SPEED
	if rig != null:
		rig.play(m.get("move", "plant" if not m.has("hit") else "overhead"), maxf(wind, 0.3), _action_t)
	_motion = m
	_motion_t = 0.0
	_motion_wind = wind


func _advance_phases(delta: float) -> void:
	if _phases.is_empty():
		_ap.speed_scale = 1.0 if _freeze <= 0.0 else 0.08
		return
	var p: Array = _phases[0]
	p[0] -= delta
	_ap.speed_scale = float(p[1]) * (0.08 if _freeze > 0.0 else 1.0)
	if p[0] <= 0.0:
		_phases.pop_front()
		if _phases.is_empty() and _next_anim != "":
			_ap.play(_next_anim, 0.15, RECOVER_SPEED)
			_next_anim = ""


func attack() -> void:
	var list: Array = ATTACKS[_weapon]
	_combo = (_combo + 1) % list.size()
	_run(list[_combo], float(ent.s["swing"]))


## Yetenek hareketi: hazirlikta vucut parlar, silah izi yetenegin rengini alir.
func play_skill(id: String, color: Color) -> void:
	var sk: Dictionary = GameData.SKILLS[id]
	var wind: float = sk.get("windup", 0.0)
	_run(MOTIONS[id], wind)
	if guard != null and id == "bash":
		guard.thrust(wind)
	_trail_color = color
	_trail_width = 0.9
	_charge = maxf(wind, 0.45)
	_charge_mat.albedo_color = Color(color, 0.0)


## Isabet: hem vuran hem vurulan bir an durur, darbenin agirligi buradan gelir.
func impact_pause(skill: String) -> void:
	_freeze = maxf(_freeze, float(MOTIONS[skill].get("stop", 0.08)) if skill != "" else 0.045)


func react(skill: String, crit: bool) -> void:
	_flash = 0.1
	var force: float = float(MOTIONS[skill].get("knock", 0.15)) if skill != "" else (0.14 if crit else 0.07)
	_knock = maxf(_knock, force)
	impact_pause(skill)
	if not ent.alive or ent.moving or _action_t > 0.0:
		return
	_hit_side += 1
	var heavy := force >= 0.3 # yere yikilmaz: geri sarsilir, savas akisi kopmaz
	_ap.play("Hit_Chest" if _hit_side % 2 == 0 else "Hit_Head", 0.08, 0.55 if heavy else 0.85)
	_action_t = 0.6 if heavy else 0.4
	_phases.clear()
	_next_anim = ""


## Hazirlik kesildi: hareket yarida kalir, karakter sarsilir.
func interrupt() -> void:
	_charge = 0.0
	_motion_t = -1.0
	_next_anim = ""
	_phases.clear()
	for m in _meshes:
		if m.visible:
			m.material_overlay = null
	_ap.play("Hit_Head", 0.1, 0.7)
	_action_t = 0.5
	if rig != null:
		rig.cancel()


## Test: hasar anindaki animasyon konumu ile olculen vurus karesi arasindaki fark.
func hit_error_ms() -> float:
	if rig != null:
		return rig.strike_error() * 1000.0
	if not _motion.has("hit"):
		return 0.0
	var target: float = _motion["hit"]
	var best := INF
	for offset: float in _motion.get("more", [0.0]):
		best = minf(best, absf(_ap.current_animation_position - (target + offset)))
	return best * 1000.0


## Test: denetlenecek silah hacimleri
func audit_volumes() -> Array:
	if rig != null:
		return [[rig.weapon, "sledge"]]
	if _shield != null:
		return [[_shield, "shield"], [_hand, "sword"]]
	return [[_hand, "axe"], [_off_hand, "axe"]]


func _ensure_probes() -> void:
	if not _probes.is_empty():
		return
	for seg: Array in BODY:
		for bone: String in [seg[0], seg[1]]:
			if not _probes.has(bone):
				var a := BoneAttachment3D.new()
				_skeleton.add_child(a)
				a.bone_name = bone
				_probes[bone] = a


## Test: silahin vucuda en yakin noktasi (metre). Eksi deger vucuda girdigini gosterir.
func clearance() -> float:
	var pts: Array[Vector3] = []
	if rig != null:
		for i in 14:
			pts.append(rig.weapon.global_transform * Vector3(0, -0.2 + i * 0.1, 0))
		for p: Vector3 in [Vector3(0.2, 1.0, 0), Vector3(-0.2, 1.0, 0), Vector3(0, 1.0, 0.09), Vector3(0, 1.0, -0.09)]:
			pts.append(rig.weapon.global_transform * p)
	else:
		return 1.0
	_ensure_probes()
	var best := 9.0
	for seg: Array in BODY:
		if rig != null and seg[0] == "upperarm_l": # silahi tutan kol sapa degebilir
			continue
		var a: Vector3 = _probes[seg[0]].global_position
		var c: Vector3 = _probes[seg[1]].global_position
		for p in pts:
			var d := p.distance_to(Geometry3D.get_closest_point_to_segment(p, a, c)) - float(seg[2])
			if d < best:
				best = d
				worst_part = seg[0]
	return best

func snap() -> void:
	_sync(1.0)


func _sync(k: float) -> void:
	position.x = lerpf(position.x, ent.pos.x, k)
	position.z = lerpf(position.z, ent.pos.y, k)
	# Kameraya donuk durus: yuz ve zirh okunur, balyozcunun iki eli birden gorunur
	var turn: float = 0.75 if _weapon == "sledge" else 0.35
	rotation.y = lerp_angle(rotation.y, ent.face - turn * signf(sin(ent.face)), k)


## Yetenege ozel govde hareketi: one atilma, ziplama, donus. Vuruslarda geri sekme de buradan.
func _update_skill_motion(delta: float) -> void:
	var forward := 0.0
	var lift := 0.0
	var spin := 0.0
	if _motion_t >= 0.0:
		_motion_t += delta
		var wind := maxf(_motion_wind, 0.01)
		var into := clampf(_motion_t / wind, 0.0, 1.0)
		var after := clampf((_motion_t - wind) / 0.55, 0.0, 1.0)
		var fwd: float = _motion.get("fwd", 0.0)
		forward = (lerpf(-0.14 * fwd, fwd, into * into * into)) * (1.0 - after * after)
		lift = sin(into * PI) * float(_motion.get("lift", 0.0))
		if _motion.has("spin"):
			var turns: float = _motion["spin"]
			spin = TAU * turns * clampf((_motion_t - wind + 0.15) / 0.9, 0.0, 1.0)
		if _motion_t > wind + 1.2:
			_motion_t = -1.0
	_knock *= exp(-delta * 7.0)
	_model.position = Vector3(0, lift, forward - _knock)
	_model.rotation.y = spin
	if _charge > 0.0:
		_charge -= delta
		_charge_mat.albedo_color.a = 0.0 if _charge <= 0.0 else 0.05 + sin(_charge * 22.0) * 0.02
		for m in _meshes:
			if m.visible:
				m.material_overlay = _charge_mat if _charge > 0.0 else null


func _process(delta: float) -> void:
	_update_flash(delta)
	if _freeze > 0.0:
		_freeze -= delta
	if rig != null:
		rig.frozen = _freeze > 0.0
	_advance_phases(delta)
	if ent == null:
		return
	_update_trail()
	_update_skill_motion(delta)
	_sync(1.0 - exp(-delta * 18.0))
	if not ent.alive:
		if not _died:
			_died = true
			_next_anim = ""
			_phases.clear()
			_ap.speed_scale = 1.0
			_ap.play("Death01", 0.2)
			if guard != null:
				guard.released = true
			if rig != null:
				rig.released = true
		return
	_action_t -= delta
	if _action_t > 0.0:
		return
	var want := _idle_anim()
	var speed := 1.0
	if ent.fx.any(func(f: Dictionary) -> bool: return f["type"] == "stun"):
		want = "Zombie_Idle"
	elif ent.moving:
		want = "Walk" if _weapon == "sledge" else "Jog_Fwd"
		speed = 1.6 if _weapon == "sledge" else 1.0
	if _ap.current_animation != want:
		_ap.play(want, 0.35, speed)


func _update_flash(delta: float) -> void:
	if _flash <= 0.0:
		return
	var overlay: Material = _flash_mat
	_flash -= delta
	if _flash <= 0.0:
		overlay = null
	for m in _meshes:
		if m.visible:
			m.material_overlay = overlay
