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
	"whirl": {"anim": "Sword_Regular_C", "hit": 0.21, "spin": 2.0, "stop": 0.07, "knock": 0.2},
	"backstab": {"anim": "OverhandThrow", "hit": 0.37, "fwd": 0.7, "stop": 0.11, "knock": 0.18},
	"hamstring": {"anim": "Melee_Hook", "hit": 0.25, "fwd": 0.3, "stop": 0.07, "knock": 0.1},
	"poison": {"anim": "Sword_Dash", "hit": 0.33, "fwd": 0.55, "stop": 0.07, "knock": 0.1},
	"expose": {"anim": "Sword_Attack", "hit": 0.4, "fwd": 0.4, "stop": 0.09, "knock": 0.2},
	"frenzy": {"anim": "NinjaJump_Land", "lift": 0.35},
	"flurry": {"anim": "Sword_Regular_Combo", "hit": 0.25, "more": [0.0, 0.48, 1.32], "fwd": 0.25, "rec": 1.0, "stop": 0.05, "knock": 0.12},
	"smash": {"anim": "Sword_Attack", "hit": 0.4, "move": "overhead", "fwd": 0.4, "stop": 0.16, "knock": 0.45},
	"crush": {"anim": "Melee_Hook", "hit": 0.25, "move": "side", "fwd": 0.3, "stop": 0.12, "knock": 0.3},
	"quake": {"anim": "NinjaJump_Land", "hit": 0.07, "move": "ground", "lift": 0.55, "stop": 0.14, "knock": 0.3},
	"grab": {"anim": "Melee_Hook", "hit": 0.25, "move": "side", "fwd": 0.75, "stop": 0.18, "knock": 0.9},
	"frost": {"anim": "Spell_Simple_Shoot", "hit": 0.5, "move": "roar", "stop": 0.1, "knock": 0.1},
	"ruin": {"anim": "Sword_Attack", "hit": 0.4, "move": "charge", "lift": 0.3, "fwd": 0.55, "stop": 0.2, "knock": 0.6},
	"wall": {"anim": "Sword_Block"},
	"crossguard": {"anim": "Sword_Block"},
	"icearm": {"anim": "Sword_Block", "move": "plant"},
	"verdict": {"anim": "Sword_Attack", "hit": 0.4, "fwd": 0.4, "stop": 0.12, "knock": 0.3},
	"leech": {"anim": "Sword_Dash", "hit": 0.33, "fwd": 0.6, "stop": 0.09, "knock": 0.15},
	"trample": {"anim": "Melee_Hook", "hit": 0.25, "move": "side", "fwd": 0.55, "stop": 0.13, "knock": 0.3},
	"leap": {"anim": "Sword_Attack", "hit": 0.4, "stop": 0.18, "knock": 0.6},
	"judge": {"anim": "Sword_Attack", "hit": 0.4, "stop": 0.13, "knock": 0.4},
	"boot": {"anim": "Melee_Hook", "hit": 0.25, "stop": 0.1, "knock": 0.45},
	"rampage": {"anim": "Sword_Regular_Combo", "hit": 0.25, "stop": 0.1, "knock": 0.25},
	"spin": {"anim": "Sword_Regular_C", "hit": 0.21, "stop": 0.1, "knock": 0.3},
	"triple": {"anim": "Melee_Hook", "hit": 0.25, "stop": 0.1, "knock": 0.25},
}
const LOOPS := ["Sword_Idle", "Idle_Shield", "Jog_Fwd", "Walk", "Zombie_Idle", "Spell_Simple_Idle", "P_Idle", "P_Walk", "B_Idle", "B_Walk", "T_Idle", "T_Walk", "T_Lobby", "P_Run", "B_Run", "T_Run"]
const MODELS := {"assassin": "res://assets/sketchfab/berserker.glb", "warrior": "res://assets/sketchfab/paladin.glb", "brute": "res://assets/sketchfab/titan.glb"}
## Modelin kendi silahi (tools/extract_weapon.py): sap ortasi orijinde, namlu +Y. Bu sinifta Weapons.glb parcalari yerine kullanilir.
const MODEL_WEAPONS := {} # Berserker artik iki elinde birer BALTA tasir (kullanici karari); eski kilic: res://assets/sketchfab/berserker_sword.glb
const MIXAMO := ["res://assets/mixamo/paladin_anim.glb", "res://assets/mixamo/berserker_anim.glb", "res://assets/mixamo/titan_anim.glb"]
## Mixamo hareketleri (tools/mixamo_bake.py), silah turune gore: her yetenegin kendi hareketi. Vurus anlari, silahin/ayagin
## rakibe ulastigi kare yandan cizilen karelere bakilarak secildi. Dosya yoksa yukaridaki eski hareketler kullanilir.
## Ortak adlar: <onek>Idle, Walk, Hit, HitHeavy, BlockHit, Death, Victory, Attack1, Attack2.
## start: hareket bu saniyeden baslar (uzun kurulma kisa hazirliga sigsin diye hizlandirilmaz, atlanir).
## end (duz vurus): karakterin bekleme durusuna dondugu an; toparlanma sinifin "recover" suresinde dogal hizla buraya
## kadar oynar, sonra bekleme hareketine yumusakca gecer (sonda ani dikelme olmasin, kullanici istegi).
const MX := {
	"sword": {"prefix": "P_", "attacks": [{"anim": "P_Attack1", "hit": 0.5, "end": 0.95}, {"anim": "P_Attack2", "hit": 0.6, "end": 1.2}], "motions": {
		"power": {"anim": "P_Power", "hit": 0.83, "fwd": 0.0},
		"lunge": {"anim": "P_Lunge", "hit": 0.6, "fwd": 0.0},
		"bash": {"anim": "P_Kick", "hit": 0.6, "fwd": 0.0},
		"cry": {"anim": "P_Cry"},
		"second": {"anim": "P_Second"},
		# Ilk vurus sicrayistan inisteki kesis, ikincisi kilicin yere indigi an (havadaki donus vurmaz). rec: ikinci
		# vurus 0,44 sn sonra, arada isabet duraklamasi (~0,11 sn) hareketi yavaslatir.
		"whirl": {"anim": "P_Whirl", "hit": 1.35, "end": 1.37, "spin": 0.0, "fwd": 0.0}, # tek vurus: kilic gogse iner ve durur
		"verdict": {"anim": "P_Verdict", "hit": 1.68, "end": 1.7, "fwd": 0.0}, # kilic gogse iner ve durur: yere kadar comelmez
		"wall": {"anim": "P_Wall"},
		"leap": {"anim": "P_Leap", "hit": 1.17, "start": 0.25, "end": 1.35, "fwd": 0.0}, # sicrayip yukaridan iner
		"judge": {"anim": "P_Twin", "hit": 0.8, "start": 0.15, "end": 0.95, "fwd": 0.0}, # yukaridan sert kesis
	}},
	"axe": {"prefix": "B_", "attacks": [{"anim": "B_Attack1", "hit": 0.92, "start": 0.3, "end": 1.5}, {"anim": "B_Attack2", "hit": 0.83, "start": 0.25, "end": 1.45}], "motions": {
		"backstab": {"anim": "B_Backstab", "hit": 1.0, "start": 0.4, "fwd": 0.0},
		"hamstring": {"anim": "B_Hamstring", "hit": 1.0, "start": 0.65, "fwd": 0.0},
		"poison": {"anim": "B_Poison", "hit": 1.0, "start": 0.45, "fwd": 0.0},
		"expose": {"anim": "B_Expose", "hit": 1.05, "fwd": 0.0}, # donusun basindan: ortadan baslayinca govde once ters yone donup isinlaniyor gibiydi
		"frenzy": {"anim": "B_Frenzy", "lift": 0.0},
		# uc vurus: 1,0 / 1,6 / 2,67; oyunda 0 / 0,48 / 1,32 sn arayla, aradaki isabet duraklamalari hesaba katildi.
		# fwd 0: balta hareketleri kendi adimini atar, oyunun ek one atilmasi rakibin icine sokuyordu.
		"flurry": {"anim": "B_Flurry", "hit": 1.0, "more": [0.0, 0.6, 1.67], "rec": 1.35, "fwd": 0.0},
		"crossguard": {"anim": "B_Guard"},
		"leech": {"anim": "B_Leech", "hit": 1.75, "start": 1.0, "fwd": 0.0, "lift": 0.0}, # sicrayip iki baltayi gomer
		"boot": {"anim": "B_Kick", "hit": 0.7, "start": 0.3, "fwd": 0.0},
		"rampage": {"anim": "B_Rampage", "hit": 2.0, "start": 1.5, "more": [0.0, 0.9], "rec": 1.2, "fwd": 0.0}, # iki buyuk balta vurusu; rec isabet donmasini telafi eder
	}},
	# Titan: iki elli buyuk kilic (Great Sword) ve buyu hareketleri balyoza uyarlandi; SledgeRig kullanilmaz.
	# lift 0: Mixamo sicrayislari kendi icinde, oyunun ek ziplatmasi gerekmez.
	"sledge": {"prefix": "T_", "attacks": [{"anim": "T_Attack1", "hit": 0.68, "start": 0.25}], "motions": { # tek duz vurus: yukaridan asagi (kullanici istegi)
		"smash": {"anim": "T_Smash", "hit": 0.77, "end": 0.8}, # balyozun one ilk inisi vurus: sonraki ikinci savurma kesildi (kullanici istegi)
		"crush": {"anim": "T_Crush", "hit": 0.9, "fwd": 0.0},
		"quake": {"anim": "T_Quake", "hit": 1.3, "start": 0.75, "end": 1.42, "lift": 0.0}, # 2H Magic Area Attack 01: balyoz basin ustunden yere iner (eski hareket govdeyi cok egiyordu)
		"grab": {"anim": "T_Grab", "hit": 0.62, "start": 0.3},
		"frost": {"anim": "T_Frost", "hit": 1.2},
		"ruin": {"anim": "T_Ruin", "hit": 1.18, "lift": 0.0, "fwd": 0.2},
		"icearm": {"anim": "P_Wall"}, # buz kalkani kalkan hareketiyle kaldirilir (balyoz gizli)
		"trample": {"anim": "T_Trample", "hit": 0.6, "start": 0.25, "fwd": 0.0, "knock": 0.12}, # kisa itme: rakip yakininda kalir
		"spin": {"anim": "T_Spin", "hit": 1.17, "start": 0.55, "end": 1.5}, # basin ustunde dondurup TEK agir savurus (kullanici: agir balyoz art arda vurmaz)
		"triple": {"anim": "T_Triple", "hit": 0.9, "start": 0.4, "end": 1.25, "fwd": 0.0}, # yalniz ilk buyuk savurus: sonraki vuruslar kesildi (kullanici istegi)
	}},
}
const MX_SLEDGE_GRIP := 0.40 # sag elin sap uzerindeki yeri (sap altindan basa dogru metre): kilic tutusu gibi sag el ustte, sol el altta
const UPRIGHT := {"brute": 26.0} # dik durus: omurganin geriye acilmasi (derece). Titan hareketlerde ~23 derece one egikti
const DUAL_AXE_SCALE := 1.08 # Berserker'in el baltalari
const DARK_WEAPON := {"M_Shield": "M_IronDark", "M_Wood": "M_WoodDark", "M_Bronze": "M_IronDark", "M_Gold": "M_IronDark", "M_Steel": "M_SteelDark", "M_Metal": "M_SteelDark"}
## Kalkan sol onkolun dis yuzune bagli: Mixamo hareketleri kalkanla yapildigi icin kol kalkani kendisi tasir.
const MX_SHIELD_ALONG := 0.55 # onkol boyunca dirsekten bileke oran
const MX_SHIELD_OUT := 0.12 # onkolun dis yuzunden kalkan yuzune
const HOLD_ROT := Vector3(1.57, 0, 0)
## Test: [kemik, sonraki kemik, yaricap] vucut parcalari
const HOLD_POS := Vector3(0.0, 0.09, 0.03)
const STRIKE_TIME := 0.3 # silahin hedefe inisi: savurma sesi isabetten bu kadar once baslar
const STRIKE_ANIM := 0.35 # vurustan onceki inis (animasyon saniyesi): dogal hizda oynar
const STRIKE_SPEED := {"sword": 1.0, "axe": 1.0, "sledge": 0.85} # inisin oynatma hizi; balyoz biraz agir iner
const TAIL := 0.6 # vurustan sonra oynanan animasyon payi; geri kalani sikistirilip hizla oynatilmaz, beklemeye gecilir
const RECOVER_END := 0.45 # toparlanmanin sonundaki oynatma hizi (yavaslayarak durur)
const RECOVER_SPEED := 0.85
const RECOIL_MAX := 0.42
## Modelin ayak tabani yere oturur: olculen taban yerin altinda kaliyordu (Paladin 6, Berserker 5, Titan ~1,5 cm)
const FOOT_LIFT := {"P_": 0.062, "B_": 0.048, "T_": 0.016}
## Ayak tabaninin kemiklere uzakligi: [parmak kemiginden, bilekten] (olculdu). Hareket ayagi yere bastirirsa govde
## o kadar kaldirilir (`_ground_lift`): taban hicbir karede yere girmez.
const SOLE := {"P_": [0.033, 0.134], "B_": [0.047, 0.119], "T_": [0.106, 0.165]}
const DOWN_SPAN := {"P_": [1.0, 1.65], "B_": [1.0, 1.65], "T_": [0.9, 1.5]} # olum hareketinde dusus baslangici ve yere degme ani

static var _library: AnimationLibrary
static var _hero: PackedScene
static var _models := {} # sinif -> kendi modeli
static var _weapons: Node3D

var ent: Battle.Ent = null
var weapon_tip: Node3D
var rig: SledgeRig
var guard: ShieldRig
var spring: HitSpring # darbe tepkisi: govde/boyun/bas yay fizigi

var _model: Node3D
var _skeleton: Skeleton3D
var _ap: AnimationPlayer
var _meshes: Array[MeshInstance3D] = []
var _weapon := "sword"
var _action_t := 0.0
var _combo := 0
var _flash := 0.0
var _freeze := 0.0
var _drag := 0.0 # isabet donmasindan sonra silah direnci yarar gibi yavas baslayip hizlanir (kalan sure)
var _drag_len := 0.0
var _lag := 0.0 # vuranin animasyonu takilma yuzunden ne kadar geride kaldi; sonra hafif hizlanarak kapatilir (sonraki vurus zamaninda gelsin)
var _catch := false
## Silahin agirligi: isabette vuranin takilmasi ve sonrasindaki yavas cikis buna gore uzar.
const WEAPON_MASS := {"sledge": 1.3, "axe": 1.0, "sword": 1.0}
const CATCH_UP := 1.35
var cloth_sim: SpringBoneSimulator3D # etek/pelerin sallanmasi (modelde kumas_ kemikleri varsa)
var _blob: MeshInstance3D # telefonda leke golgesi (yerde kalir, govdenin kaymasini izler)
var _died := false
var _last_from := Vector3.INF # son darbeyi vuranin konumu ve agirligi: olumde beden buna gore savrulur
var _last_w := 0.5
var _slide := 0.0 # olumde darbenin tersine kayma (metre)
var _slide_goal := 0.0
var _slide_dir := Vector3.BACK
var _flash_mat: StandardMaterial3D
var _ice_mat: StandardMaterial3D
var _iced := false
var _phases: Array[Array] = [] # [sure, hiz] sirali fazlar
var _next_anim := ""
var _settle_t := 0.0 # kirpilmis hareketten bekleme durusuna gecis suresi (eski poz yavaslatilir)
var _down := false # yere dusmus: kalkana kadar baska hareket oynamaz
var _ground_fix := 0.0 # yere oturtma icin ek yukseklik
var _motion := {}
var _motion_t := -1.0
var _motion_wind := 0.0
var _knock := 0.0
var _recoil := 0.0 # hasarda govdenin geriye yatisi (radyan)
var _recoil_goal := 0.0
var _twist := 0.0 # vurulan govdenin darbeden uzaga burkulmasi (radyan)
var _twist_goal := 0.0
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
var _ice_shield: Node3D # Titan Buz Kolu: siper boyunca balyozun yerine sol kolda buz kalkani
var _ice_t := 0.0
var _kilt: MeshInstance3D
var _kilt_hip: BoneAttachment3D
var _mx := false # bu silah icin Mixamo hareketleri kullaniliyor
var _px := "" # Mixamo hareket adi oneki (P_, B_)
## Kosu hareketinde yere basan ayagin geriye kayma hizi (m/sn, mixamo_bake raporundan olculdu). Kosu bu hiza gore
## hizlandirilir ki ayak yerde kaymasin (oyundaki ilerleme: Paladin 4,6, Berserker 5,4, Titan 3,7 m/sn).
const RUN_STRIDE := {"P_": 4.15, "B_": 2.5, "T_": 1.85}
var _loco := 1.0 # kosu hiz carpani (animasyon hizina eklenir)
var _vel := 0.0 # ekrandaki gercek yatay hiz (yumusatilmis)
var prev_pos := Vector2.INF # bir onceki savas adimindaki konum (Main yazar)
var step_frac := -1.0 # iki savas adimi arasindaki kesir; -1 = ara konum yok, yumusak yetisme
var _last_pos := Vector3.INF
var _cls := ""


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
	for path: String in MIXAMO:
		if not ResourceLoader.exists(path):
			continue
		var src: Node = load(path).instantiate()
		var ap: AnimationPlayer = src.find_child("AnimationPlayer", true, false)
		for n: String in ap.get_animation_list():
			_library.add_animation(n, ap.get_animation(n))
		src.free()
	for n: String in LOOPS:
		if _library.has_animation(n):
			_library.get_animation(n).loop_mode = Animation.LOOP_LINEAR


## Sinifin kendi modeli (Sketchfab, tools/model_prep.py ile Quaternius iskelet adlarina ve T durusuna getirildi).
## Model ya da o sinifin Mixamo hareketleri yoksa Quaternius karakteri kullanilir.
static func _scene_of(cls: String) -> PackedScene:
	var path: String = MODELS.get(cls, "")
	var weapon: String = GameData.CLASSES[cls]["weapons"][0]
	if path == "" or not ResourceLoader.exists(path) or not MX.has(weapon) or not _library.has_animation(MX[weapon]["prefix"] + "Attack1"):
		return _hero
	if not _models.has(cls):
		_models[cls] = load(path)
	return _models[cls]


func setup(ch: Dictionary, battle_ent: Battle.Ent = null) -> void:
	_load_shared()
	ent = battle_ent
	_cls = ch["cls"]
	_model = _scene_of(_cls).instantiate()
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
	var posture := Posture.new() # dik durus: hareketin one egikligi azaltilir (yay fizigi ustune biner)
	posture.angle = deg_to_rad(float(UPRIGHT.get(_cls, 0.0)))
	_skeleton.add_child(posture)
	spring = HitSpring.new() # el/kalkan duzeltmelerinden ONCE calissin: govde egilir, eller onu izler
	_skeleton.add_child(spring)
	_build_foot_lock() # yere basan ayak kaymaz, yere batmaz: bacak IK
	_skeleton.add_child(FootPlant.new()) # ayak tabani yere duz basar (parmaklar yere batmaz)
	_dress(ch)
	_foot_lock.sole = SOLE.get(_px, [0.0, 0.0])
	_build_kilt()
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
	_build_cloth()
	if _weapon == "sledge" and _mx:
		_build_grip()
	if Version.phone():
		_build_blob()


## Ayak kilidi: iki bacak icin TwoBoneIK3D (hedef ve diz yonu FootLock'tan), ardindan ayak acisi geri alinir.
var _foot_lock: FootLock


func _build_foot_lock() -> void:
	_foot_lock = FootLock.new()
	_foot_lock.view = self
	_skeleton.add_child(_foot_lock)
	for side: String in ["l", "r"]:
		var target := Node3D.new()
		var pole := Node3D.new()
		add_child(target)
		add_child(pole)
		var ik: SkeletonModifier3D = ClassDB.instantiate("TwoBoneIK3D")
		ik.call("set_setting_count", 1)
		ik.influence = 0.0
		_skeleton.add_child(ik)
		ik.call("set_target_node", 0, ik.get_path_to(target))
		ik.call("set_pole_node", 0, ik.get_path_to(pole))
		_foot_lock.add_leg(side, ik, target, pole)
	var after := FootLock.After.new()
	after.source = _foot_lock
	_skeleton.add_child(after)


## Titan balyozu IKI ELLE tutar (kullanici istegi): sol el her karede sapin uzerine kilitlenir (TwoBoneIK3D: omuz-dirsek-
## bilek). Hazir hareketlerin bazilari tek elli ya da kol oranlari farkli oldugu icin sol el sapi kaciriyordu.
## Bilek, sap noktasinin avuc kadar disinda durur; dirsek govdenin yanina ve asagi bakar. Buz kalkani, yere dusus ve
## olumde sol el serbest kalir (influence 0).
const LEFT_GRIP := 0.17 # sol avucun sap uzerindeki yeri (sap altindan; sag avucun ~23 cm ALTINDA: Mixamo iki elli tutusta sol el kabzaya yakin, eskiden ustte isteniyor, kollar caprazlaniyordu)
var _grip: SkeletonModifier3D
var _grip_follow: GripTarget
var _grip_hand: SkeletonModifier3D


func _build_grip() -> void:
	var at := Node3D.new()
	_skeleton.add_child(at)
	var follow := GripTarget.new() # hedef sag elin bu karedeki pozundan: hizli savurusta geride kalmaz
	follow.target = at
	follow.socket = _hand.transform
	follow.right_at = MX_SLEDGE_GRIP
	follow.along = LEFT_GRIP
	# kivrik parmak tuneli (HandRig._curl_side ile ayni geometri): yonu ve bilekten ortasi, sol elin kemik uzayinda
	var rest := _skeleton.get_bone_global_rest(_skeleton.find_bone("hand_l"))
	var f := (_skeleton.get_bone_global_rest(_skeleton.find_bone("middle_01_l")).origin - rest.origin)
	var reach := f.length()
	f = f.normalized()
	var palm := (Vector3.DOWN - f * Vector3.DOWN.dot(f)).normalized()
	var inv := rest.basis.orthonormalized().inverse()
	follow.tunnel = (inv * f.cross(palm)).normalized()
	follow.center = inv * (f * reach * 1.25 + palm * reach * 0.45)
	_skeleton.add_child(follow)
	_grip_follow = follow
	var pole := Node3D.new()
	_skeleton.add_child(pole)
	pole.position = Vector3(0.65, 0.7, -0.35) # dirsek: sol yan, asagi ve geri
	_grip = ClassDB.instantiate("TwoBoneIK3D")
	_grip.call("set_setting_count", 1)
	_skeleton.add_child(_grip) # son duzenleyici: animasyon, yay fizigi ve el sarma sonrasinda calisir
	_grip.call("set_target_node", 0, _grip.get_path_to(at))
	_grip.call("set_pole_node", 0, _grip.get_path_to(pole))
	var hand_fix := GripTarget.Hand.new() # IK sonrasi: sol elin acisi sapa gore
	hand_fix.source = _grip_follow
	_skeleton.add_child(hand_fix)
	_grip_hand = hand_fix


func _update_grip(delta: float) -> void:
	if _grip == null:
		return
	if int(_grip.call("get_root_bone", 0)) < 0 and _grip.get_skeleton() != null: # kemik adlari iskelet hazir olunca cozulur
		_grip.call("set_root_bone_name", 0, "upperarm_l")
		_grip.call("set_middle_bone_name", 0, "lowerarm_l")
		_grip.call("set_end_bone_name", 0, "hand_l")
	var want := 0.0 if OS.has_environment("KOR_NOGRIP") or _died or _down or _ice_t > 0.0 else 1.0
	_grip.influence = move_toward(_grip.influence, want, delta * 6.0)
	_grip_hand.influence = _grip.influence


## Kumas: modelde tools/cloth_rig.py ile eklenmis "kumas_<ad>_0..n" zincirleri yay fizigiyle sallanir (kosu, donus, darbe).
## Bacak ve kalca kapsulleri kumasin govdenin icinden gecmesini engeller. Son eklenen duzenleyici: son durusu izler.
## [geri donus gucu, sonum, yercekimi]: dusuk guc agir ve gec, yuksek guc sert kumas. Titan etegi zincir zirh: daha agir.
const CLOTH_FEEL := {"brute": [3.0, 0.55, 1.6]}
const CLOTH_DEFAULT := [2.2, 0.45, 1.0]
const CLOTH_LIMBS := [["thigh_l", "calf_l", 0.09], ["thigh_r", "calf_r", 0.09], ["calf_l", "foot_l", 0.07], ["calf_r", "foot_r", 0.07], ["pelvis", "spine_02", 0.15]]


## Telefonda gercek golge yok (ArenaView.set_low_quality): ayaklarin altinda yumusak koyu leke, karakter havada durmasin.
func _build_blob() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.55))
	grad.set_color(1, Color(0, 0, 0, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.3, 0.9) * _model.scale.x
	_blob = MeshInstance3D.new()
	_blob.mesh = plane
	_blob.material_override = mat
	_blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_blob.position.y = 0.02
	add_child(_blob)


func _build_cloth() -> void:
	var roots: Array[String] = []
	for i in _skeleton.get_bone_count():
		var n := _skeleton.get_bone_name(i)
		if n.begins_with("kumas_") and n.ends_with("_0"):
			roots.append(n)
	if roots.is_empty():
		return
	cloth_sim = SpringBoneSimulator3D.new()
	_skeleton.add_child(cloth_sim)
	cloth_sim.set_setting_count(roots.size())
	for i in roots.size():
		var base := roots[i].trim_suffix("_0")
		var last := 0
		while _skeleton.find_bone("%s_%d" % [base, last + 1]) >= 0:
			last += 1
		var end_id := _skeleton.find_bone("%s_%d" % [base, last])
		cloth_sim.set_root_bone_name(i, roots[i])
		cloth_sim.set_end_bone_name(i, "%s_%d" % [base, last])
		cloth_sim.set_extend_end_bone(i, true)
		cloth_sim.set_end_bone_direction(i, SkeletonModifier3D.BONE_DIRECTION_FROM_PARENT)
		cloth_sim.set_end_bone_length(i, _skeleton.get_bone_rest(end_id).origin.length())
		cloth_sim.set_radius(i, 0.03)
		var feel: Array = CLOTH_FEEL.get(_cls, CLOTH_DEFAULT)
		cloth_sim.set_stiffness(i, feel[0])
		cloth_sim.set_drag(i, feel[1])
		cloth_sim.set_gravity(i, feel[2])
		cloth_sim.set_enable_all_child_collisions(i, true)
	for limb: Array in CLOTH_LIMBS:
		var a := _skeleton.find_bone(limb[0])
		var b := _skeleton.find_bone(limb[1])
		if a < 0 or b < 0:
			continue
		var ga := _skeleton.get_bone_global_rest(a)
		var along := ga.basis.inverse() * (_skeleton.get_bone_global_rest(b).origin - ga.origin) # kemik uzayinda cocuga dogru
		var length := along.length()
		var cap := SpringBoneCollisionCapsule3D.new()
		cap.bone_name = limb[0]
		cap.radius = limb[2]
		cap.height = length + limb[2] * 2.0
		cap.position_offset = along * 0.5 # kapsul kemigin ortasinda, cocuga dogru uzanir
		cap.rotation_offset = Quaternion(Vector3.UP, along.normalized())
		cloth_sim.add_child(cap)
	var ground := SpringBoneCollisionPlane3D.new() # yere yatan bedende kumas zeminden gecmesin
	ground.position = Vector3(0.0, 0.02, 0.0)
	cloth_sim.add_child(ground)
	cloth_sim.reset()


## Gorsel hile: etek bacaklarla gerilmesin diye asil etek gizlenir, yerine kalcayi izleyen ama hep dik sarkan
## pileli bir huni gelir. Sabit kameradan bacaklar icinde kalir.
func _build_kilt() -> void:
	var skirt := _part("W_Skirt")
	if skirt == null or not skirt.visible:
		return
	_kilt_hip = BoneAttachment3D.new()
	_skeleton.add_child(_kilt_hip)
	_kilt_hip.bone_name = "pelvis"
	var shape := CylinderMesh.new()
	shape.top_radius = 0.19
	shape.bottom_radius = 0.37
	shape.height = 0.36
	shape.radial_segments = 14
	shape.rings = 1
	shape.cap_top = false
	shape.cap_bottom = false
	var cloth: Material = skirt.get_surface_override_material(0).duplicate()
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	shape.material = cloth
	_kilt = MeshInstance3D.new()
	_kilt.mesh = shape
	_kilt.scale = Vector3(1.0, 1.0, 1.15)
	_skeleton.add_child(_kilt)
	skirt.visible = false


func _update_kilt() -> void:
	if _kilt != null:
		_kilt.position = _skeleton.to_local(_kilt_hip.global_position) + Vector3(0.0, -0.13, 0.0)

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
	var wide := _trail_width >= 0.9 # yetenek: Doom Forge gibi genis, parlak yay (elden ucun otesine)
	if _action_t > 0.0 and not _died and not _down: # yere duserken silah iz birakmaz
		var tip := weapon_tip.global_position
		var base := _hand.global_position
		if wide:
			_trail.push_front([tip + (tip - base) * 0.3, base.lerp(tip, 0.1)])
		else:
			_trail.push_front([tip, base.lerp(tip, 0.88 if rig != null else 0.4)])
	if _trail.size() > (26 if wide else 16) or (_action_t <= 0.0 and not _trail.is_empty()):
		_trail.pop_back()
	_trail_mesh.clear_surfaces()
	if _trail.size() < 2:
		return
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var glow := _trail_color * (1.8 if wide else 1.0) # yetenek izi daha parlak
	for i in _trail.size():
		var a := _trail_width * (1.0 - float(i) / _trail.size())
		_trail_mesh.surface_set_color(Color(glow, a))
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
	if _scene_of(ch["cls"]) != _hero: # kendi modeli: zirhi ve dokulari ustunde, yalniz silah takilir
		_weapon = ch["equipped"]["weapon"]["type"]
		_px = MX[_weapon]["prefix"]
		_mx = true
		_attach_weapons(ch["equipped"]["weapon"])
		return
	var prefix: String = PREFIX[ch["cls"]]
	var eq: Dictionary = ch["equipped"]
	var cloth := Color(ch["look"]["cloth"]).lerp(Color.WHITE, 0.25)
	var armor_rarity: int = eq["armor"]["rarity"] if eq.get("armor") != null else 0
	var shine: Color = Color(GameData.RARITY[armor_rarity]["color"]).lerp(Color.WHITE, 0.35)
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
	_px = MX[_weapon]["prefix"] if MX.has(_weapon) else ""
	_mx = _px != "" and _library.has_animation(_px + "Attack1")
	_model.position.y = float(FOOT_LIFT.get(_px, 0.0)) # lobide de ayaklar yere otursun
	_attach_weapons(weapon)


func _piece(name_: String, parent: Node3D, tint := Color.WHITE, glow := 0.0) -> MeshInstance3D:
	var src: MeshInstance3D = _weapons.find_child(name_, true, false)
	var m := MeshInstance3D.new()
	m.mesh = src.mesh
	m.transform = src.transform
	parent.add_child(m)
	var mat: Material = src.mesh.surface_get_material(0)
	var id: String = mat.resource_name if mat != null else ""
	if _scene_of(_cls) != _hero: # kendi zirhli modeli: silah da koyu tonlarda, zirhla uyumlu
		id = DARK_WEAPON.get(id, id)
		if tint != Color.WHITE:
			tint = tint.lerp(Color.WHITE, 0.55) # nadirlik rengi yalniz hafif bir ton olarak kalir
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


## Sinifin kendi modeline ait silah (yalniz kendi modeli kullaniliyorsa).
func _own_weapon() -> PackedScene:
	var path: String = MODEL_WEAPONS.get(_cls, "")
	if path == "" or _scene_of(_cls) == _hero or not ResourceLoader.exists(path):
		return null
	if not _models.has(path):
		_models[path] = load(path)
	return _models[path]


func _attach_weapons(item: Dictionary) -> void:
	var rarity: int = item["rarity"]
	var tint: Color = Color(GameData.RARITY[rarity]["color"]).lerp(Color.WHITE, 0.3)
	var glow: float = [0.0, 0.0, 0.2, 0.45, 0.8][rarity] # iyi silah uzaktan da belli olsun
	var hand: Node3D
	if _weapon == "sledge" and not _mx:
		rig = SledgeRig.new()
		hand = Node3D.new()
		_skeleton.add_child(hand)
		rig.weapon = hand
		rig.flip = ent != null and ent.pos.x > 0.0
		_skeleton.add_child(rig)
	elif _weapon == "sledge": # Mixamo iki elli kilic hareketleri: sag el sapin ust tutusunda, sol el altinda
		hand = _bone_socket("hand_r", Transform3D(Basis.from_euler(HOLD_ROT), HOLD_POS) * Transform3D(Basis.IDENTITY, Vector3(0, -MX_SLEDGE_GRIP, 0)))
		_add_hand_rig([["hand_r", Basis.from_euler(HOLD_ROT) * Vector3.UP]], true, true) # iki avuc sapi kavrar
	else:
		hand = _bone_socket("hand_r", Transform3D(Basis.from_euler(HOLD_ROT), HOLD_POS))
	_hand = hand
	# Berserker (silah turu "axe") kullanici karariyla iki elinde birer BALTA tasir (balta hareketleriyle uyumlu)
	var names: Dictionary = {"sword": "Sword", "greatsword": "Great", "axe": "Axe"}
	var own: PackedScene = _own_weapon()
	if own != null:
		hand.add_child(own.instantiate())
	elif _weapon == "sledge":
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
		if own != null:
			off.add_child(own.instantiate())
		else:
			off.scale = Vector3.ONE * DUAL_AXE_SCALE
			hand.scale = Vector3.ONE * DUAL_AXE_SCALE
			_piece("Axe_Blade", off, tint, glow)
			_piece("Axe_Guard", off)
			_piece("Axe_Grip", off)
	if _weapon == "sword" and _mx:
		_shield = _bone_socket("lowerarm_l", _forearm_mount())
	elif _weapon == "sword":
		_shield = Node3D.new()
		_skeleton.add_child(_shield)
		guard = ShieldRig.new()
		guard.shield = _shield
		_skeleton.add_child(guard)
	if _weapon == "sword":
		var sword_axis := Basis.from_euler(HOLD_ROT) * Vector3.UP
		_add_hand_rig([["hand_r", sword_axis]], false)
		_piece("Shield_Body", _shield, Color(0.82, 0.8, 0.78) if _scene_of(_cls) == _hero else Color.WHITE)
		_piece("Shield_Boss", _shield)
		_shield.add_child(_shield_handle())
	if _weapon == "axe" and own == null: # iki baltanin bicagi ve sapi okunur malzemede
		for holder: Node3D in [hand, _off_hand]:
			for m: Node in holder.get_children():
				if m is MeshInstance3D:
					var src_mat: Material = (m as MeshInstance3D).mesh.surface_get_material(0)
					var mid: String = src_mat.resource_name if src_mat != null else ""
					if mid == "M_Steel":
						(m as MeshInstance3D).material_override = Mats.get_mat("M_AxeSteel", tint.lerp(Color.WHITE, 0.55), glow)
					elif mid == "M_Wood":
						(m as MeshInstance3D).material_override = Mats.get_mat("M_AxeGrip")
	weapon_tip = Node3D.new()
	hand.add_child(weapon_tip)
	weapon_tip.position = Vector3(0, {"sword": 0.8, "greatsword": 1.15, "axe": 0.7, "sledge": 1.1}[_weapon], 0)


## Kalkan arkasindaki deri tutamak: dik cubuk ve iki ayak. Sol el bu cubugu kavrar.
func _shield_handle() -> Node3D:
	var holder := Node3D.new()
	var leather := StandardMaterial3D.new()
	leather.albedo_color = Color(0.09, 0.05, 0.03)
	leather.roughness = 0.8
	var y := -ShieldRig.STRAP / (ShieldRig.SHIELD_SCALE * ShieldRig.SHIELD_THIN)
	var bar := MeshInstance3D.new()
	var rod := CylinderMesh.new()
	rod.top_radius = 0.016
	rod.bottom_radius = 0.016
	rod.height = 0.26
	rod.material = leather
	bar.mesh = rod
	bar.transform = Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, y, 0))
	holder.add_child(bar)
	for z: float in [-0.13, 0.13]:
		var leg := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.04, -y, 0.02)
		box.material = leather
		leg.mesh = box
		leg.position = Vector3(0, y / 2.0, z)
		holder.add_child(leg)
	return holder


## Mixamo: T-pozda avuc asagi bakar, onkolun dis yuzu yukaridadir. Kalkan yuzu oraya, duzlemi onkol boyunca durur.
func _forearm_mount() -> Transform3D:
	var fore := _skeleton.find_bone("lowerarm_l")
	var rest := _skeleton.get_bone_global_rest(fore)
	var length := rest.origin.distance_to(_skeleton.get_bone_global_rest(_skeleton.find_bone("hand_l")).origin)
	var n := (rest.basis.inverse() * Vector3.UP).normalized()
	var a := Vector3.UP # kemik kendi Y ekseni boyunca uzanir
	a = (a - n * a.dot(n)).normalized()
	var basis := Basis(n.cross(a), n, a).scaled_local(Vector3(ShieldRig.SHIELD_SCALE, ShieldRig.SHIELD_SCALE * ShieldRig.SHIELD_THIN, ShieldRig.SHIELD_SCALE))
	var scale := rest.basis.get_scale() # kemik olcegi: yerel uzunluklar dunya metresine cevrilir
	return Transform3D(basis, a * length * MX_SHIELD_ALONG / scale.y + n * MX_SHIELD_OUT / scale.y)


## Sag eldeki tutusun sol ele aynasi: balta kolun degil avucun icinde durur.
func _mirror_mount() -> Transform3D:
	var right := _skeleton.get_bone_global_rest(_skeleton.find_bone("hand_r"))
	var left := _skeleton.get_bone_global_rest(_skeleton.find_bone("hand_l"))
	var hold := right * Transform3D(Basis.from_euler(HOLD_ROT), HOLD_POS)
	var flip := Basis.from_scale(Vector3(-1, 1, 1))
	var basis := flip * hold.basis * Basis.from_scale(Vector3(-1, 1, 1))
	var origin := flip * hold.origin
	return left.affine_inverse() * Transform3D(basis, origin)


func _add_hand_rig(hands: Array, curl: bool, curl_r := false) -> void:
	var h := HandRig.new()
	h.hands = hands
	h.curl_left = curl
	h.curl_right = curl_r
	_skeleton.add_child(h)

func _idle_anim() -> String:
	if _mx and ent == null and _library.has_animation(_px + "Lobby"): # lobide sakin, silah tek elde (kullanici istegi)
		return _px + "Lobby"
	if _mx:
		return _px + "Idle"
	if _weapon == "sword":
		return "Idle_Shield"
	return "Sword_Idle"


## Hazirlik -> ani vurus -> toparlanma. "wind" sonunda silah animasyonda tam hedefe iner.
## settle > 0: toparlanma tam bu surede biter (duz vurus: savas kodu o ana kadar yetenegi kilitler).
func _run(m: Dictionary, wind: float, settle := -1.0) -> void:
	var anim: String = m["anim"]
	var length := _ap.get_animation(anim).length
	_phases.clear()
	_next_anim = m.get("next", "") if settle <= 0.0 else ""
	_ap.play(anim, 0.32, 1.0) # yumusak gecis: bekleme durusundan yetenek pozuna atlama olmasin
	var start: float = m.get("start", 0.0)
	if start > 0.0:
		_ap.seek(start, true)
	if m.has("hit") and wind > 0.0:
		# Hazirligin fazlasi kalkista harcanir, inis (vurustan onceki STRIKE_ANIM sn) dogal hizda oynar: silah
		# hedefe hizla iner, hasar/ses/tepki tam o karede gelir. Eskiden hazirligin sonu yavaslatiliyordu, son inis
		# agir cekim gibi oynuyor ve hasar silah inmis gibi gorundukten sonra geliyordu (kullanici geri bildirimi).
		var hit: float = m["hit"]
		var strike_anim := minf(STRIKE_ANIM, hit - start)
		var strike_real := minf(strike_anim / float(STRIKE_SPEED.get(_weapon, 1.0)), wind * 0.6)
		if hit - start <= STRIKE_ANIM: # hareket zaten yalniz inisten olusuyor: bekletmeden tek hizda oynar
			strike_real = wind
		var strike_speed := strike_anim / maxf(strike_real, 0.01)
		var lead := wind - strike_real
		if lead > 0.0: # 5. alan: evrenin basladigi kare (sapma duzeltmesi)
			# kalkis yavas baslar, inise dogru hizlanir: inis aniden patlamaz
			var lift := (hit - start - strike_anim) / lead
			var top := clampf(lift * 1.6, lift, maxf(strike_speed, lift)) # kalkis inisten hizliysa sabit hizda: basta firlamaz
			_phases.append([lead, 2.0 * lift - top, top, lead, start])
		_phases.append([strike_real, strike_speed, strike_speed, strike_real, hit - strike_anim])
		var rec: float = m.get("rec", RECOVER_SPEED)
		var rest := (length - hit) / rec
		var tail: float = minf(float(m.get("end", hit + TAIL)), length) - hit
		if settle > 0.0: # duz vurus: toparlanma "end" anina kadar, tam "settle" surede yavaslayarak biter
			rest = settle
			var left: float = float(m.get("end", length)) - hit
			var slow := minf(strike_speed, left / rest)
			_phases.append([rest, slow, 2.0 * left / rest - slow, rest])
		elif m.has("rec"): # cok vuruslu: sonraki darbeler animasyondaki yerinde kalmali
			_phases.append([rest, rec])
		else: # toparlanma: darbenin devami dogal hizla baslar, yavaslayip durur, sonra bekleme durusuna gecilir
			var s0 := minf(strike_speed, 1.0) * 0.9
			rest = tail / ((s0 + RECOVER_END) * 0.5)
			_phases.append([rest, s0, RECOVER_END, rest])
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
		# kirpilmis hareketin ("end") son pozu, bekleme durusuna gecis boyunca neredeyse donuk kalir: hareket akip egilmeye devam etmez
		var settle := 0.2 if _settle_t > 0.0 else 1.0
		_settle_t -= delta
		_ap.speed_scale = _impact_scale() * _loco * settle
		return
	var p: Array = _phases[0]
	p[0] -= delta
	var speed: float = p[1]
	if p.size() >= 4: # [kalan, baslangic hizi, bitis hizi, toplam]: hiz yumusakca degisir
		speed = lerpf(float(p[1]), float(p[2]), clampf(1.0 - float(p[0]) / float(p[3]), 0.0, 1.0))
	if p.size() == 5 and _freeze <= 0.0 and p[0] > 0.0:
		# Hazirlik: vurus ani oyunun saatine bagli. Hazirlikta yenen darbe animasyonu dondurup geride birakiyordu
		# (silah hasardan ~0,15 sn gec iniyordu). Animasyonun olmasi gereken kareden sapmasi 0,12 sn icinde kapatilir.
		var t := float(p[3]) - float(p[0])
		var ideal := float(p[4]) + float(p[1]) * t + (float(p[2]) - float(p[1])) * t * t / (2.0 * float(p[3]))
		speed = maxf(0.0, speed + (ideal - _ap.current_animation_position) / 0.12)
		_ap.speed_scale = speed # sapma duzeltmesi geri kazanmayi zaten yapar
	else:
		_ap.speed_scale = speed * _impact_scale()
	if p[0] <= 0.0:
		_phases.pop_front()
		if _phases.is_empty() and _motion.has("end") and not _motion.has("rec"):
			_settle_t = 0.4
		if _phases.is_empty() and _next_anim != "":
			_ap.play(_next_anim, 0.15, RECOVER_SPEED)
			_next_anim = ""


func attack() -> void:
	var list: Array = MX[_weapon]["attacks"] if _mx else ATTACKS[_weapon]
	_combo = (_combo + 1) % list.size()
	_run(list[_combo], float(ent.s["swing"]), float(ent.s["recover"]))


## Yetenek hareketi: hazirlikta vucut parlar, silah izi yetenegin rengini alir.
func play_skill(id: String, color: Color, extra: float = 0.0) -> void:
	var sk: Dictionary = GameData.SKILLS[id]
	var wind: float = float(sk.get("windup", 0.0)) + extra # katilan tarafta ag gecikmesi hazirliga eklenir
	_run(_motion_of(id), wind)
	if _mx and sk["kind"] == "guard":
		_action_t = maxf(_action_t, wind + float(sk.get("dur", 0.0))) # siper boyunca son poz tutulur
	if id == "icearm" and _mx:
		_show_ice_shield(wind + float(sk.get("dur", 0.0))) # kalkan gorundugu surece gecerli: fazladan gorunmez
	if guard != null and id == "bash":
		guard.thrust(wind)
	_trail_color = color
	_trail_width = 0.0 if _ice_t > 0.0 else 1.0 # gizli balyoz iz birakmaz; 1,0 = genis yetenek izi
	_charge = maxf(wind, 0.45)
	_charge_mat.albedo_color = Color(color, 0.0)


## Buz Kolu: balyoz gizlenir, sol onkolda buzdan kalkan belirir; sure bitince balyoz geri gelir (kullanici istegi).
func _show_ice_shield(t: float) -> void:
	if _ice_shield == null:
		_ice_shield = _bone_socket("lowerarm_l", _forearm_mount())
		var ice := Color(0.55, 0.85, 1.0)
		_piece("Shield_Body", _ice_shield, ice, 0.9)
		_piece("Shield_Boss", _ice_shield, ice, 1.2)
	_ice_t = t
	_ice_shield.visible = true
	_ice_shield.scale = Vector3.ONE * 0.2
	var tw := _ice_shield.create_tween() # buz hizla buyuyerek olusur
	tw.tween_property(_ice_shield, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hand.visible = false


func _hide_ice_shield() -> void:
	_ice_t = 0.0
	if _ice_shield != null:
		_ice_shield.visible = false
	_hand.visible = true


## Mixamo hareketi varsa yetenegin govde hareketi (one atilma, itme) korunur, animasyon degisir.
func _motion_of(id: String) -> Dictionary:
	if not _mx or not MX[_weapon]["motions"].has(id):
		return MOTIONS[id]
	var m: Dictionary = MOTIONS[id].duplicate()
	m.merge(MX[_weapon]["motions"][id], true)
	if float(m.get("spin", 0.0)) == 0.0:
		m.erase("spin")
	return m


## Mac kazanildi: Paladin zafer hareketini yapar.
func celebrate() -> void:
	if not _mx or not ent.alive:
		return
	if _weapon == "sledge": # Paladin zafer hareketi balyozu havada savurup titretiyordu: Titan sakin durur
		return
	_phases.clear()
	_next_anim = ""
	_motion_t = -1.0
	_ap.speed_scale = 1.0
	_ap.play(_px + "Victory", 0.3)
	_action_t = _ap.get_animation(_px + "Victory").length
	_trail_width = 0.0 # zafer hareketi silah izi birakmaz


## Isabet: hem vuran hem vurulan bir an durur, darbenin agirligi buradan gelir.
## weight: darbenin agirligi (hasar / can orani, 0,2-1,6): donma hafif vurusta kisa, agirda belirgin.
## attacker: vuran taraf. Silahi agirsa daha uzun takilir, sonra direnci yararak yavasca hizlanir.
func impact_pause(skill: String, weight := -1.0, attacker := false) -> void:
	var t: float = minf(float(MOTIONS[skill].get("stop", 0.08)) * 1.6, 0.16) if skill != "" else 0.07
	if weight >= 0.0:
		t = maxf(t, minf(0.05 + weight * 0.09, 0.2))
	if attacker:
		_catch = true
		var mass: float = WEAPON_MASS.get(_weapon, 1.0)
		_lag += t * (mass - 1.0) * 0.92 # agir silahin uzayan donmasi da sonra geri kazanilir
		t *= mass
		_drag_len = (0.08 + 0.07 * maxf(weight, 0.3)) * mass
		_drag = _drag_len
	_freeze = maxf(_freeze, t)


## Animasyon hiz carpani: donmada neredeyse durur, sonra yuzde 30 hizla cikip tam hiza yumusakca doner.
func _impact_scale() -> float:
	if _freeze > 0.0:
		return 0.08
	if _drag > 0.0:
		return lerpf(1.0, 0.3, _drag / _drag_len)
	if _lag > 0.0:
		return CATCH_UP
	return 1.0


## from: vuranin dunya konumu (darbenin yonu icin).
func react(skill: String, crit: bool, weight := 0.5, from := Vector3.INF) -> void:
	_last_from = from
	_last_w = weight
	if spring != null and from != Vector3.INF:
		spring.hit(from, minf(weight * 1.4, 1.8), crit) # belirgin tepki (kullanici istegi): govde daha cok esner
	_flash = 0.14
	if crit:
		_freeze = maxf(_freeze, 0.11)
	var force: float = float(MOTIONS[skill].get("knock", 0.15)) if skill != "" else (0.22 if crit else 0.12)
	force *= 1.1 + weight * 0.7 # darbe yiyen belirgin geri itilir (Doom Forge gibi)
	_knock = maxf(_knock, force)
	# tum govdenin ayaklardan yatmasi yalniz hafif kalir: asil tepkiyi yay fizigi omurgada verir
	_recoil_goal = maxf(_recoil_goal, minf(0.14 + force * 0.8, RECOIL_MAX) * (0.35 if spring != null else 1.0))
	if not _down: # yerdeyken darbe donmasi dusus/kalkis hareketini durdurmasin
		impact_pause(skill, weight)
	if _down: # yerdeyken yeni vurus dusmeyi bozmaz, yalniz govde sarsilir
		return
	if not ent.alive or ent.moving or _action_t > 0.0:
		# kendi hareketinin ortasinda vurulan karakter de sarsilsin: govde geri yatar ve darbeden uzaga burkulur
		# (eskiden yalniz kirmizi parlama oluyordu, vurus bos gitmis gibi duruyordu)
		_recoil_goal = maxf(_recoil_goal, minf(0.2 + weight * 0.22, RECOIL_MAX) * (0.35 if spring != null else 1.0))
		if spring == null:
			_twist_goal = (0.12 + weight * 0.16) * (1.0 if _hit_side % 2 == 0 else -1.0)
		_hit_side += 1
		return
	_hit_side += 1
	var heavy := force >= 0.3 # yere yikilmaz: geri sarsilir, savas akisi kopmaz
	if _mx:
		_ap.play(_px + ("HitHeavy" if heavy else "Hit"), 0.06, 1.0)
	else:
		_ap.play("Hit_Chest" if _hit_side % 2 == 0 else "Hit_Head", 0.08, 0.55 if heavy else 0.85)
	_action_t = 0.6 if heavy else 0.4
	_phases.clear()
	_next_anim = ""


## Tahmin edilen yetenegi host reddetti: hareket sessizce biter.
func cancel_action() -> void:
	_charge = 0.0
	_motion_t = -1.0
	_next_anim = ""
	_phases.clear()
	_action_t = 0.0
	_ap.speed_scale = 1.0
	for m in _meshes:
		if m.visible:
			m.material_overlay = null
	if rig != null:
		rig.cancel()


## Darbe tamamen emildi: siper durusunda darbeyi kalkanla/baltalarla karsilar.
func block() -> void:
	if not _mx or not ent.alive or ent.moving:
		return
	_ap.play(_px + "BlockHit", 0.05, 1.0)
	_action_t = maxf(_action_t, _ap.get_animation(_px + "BlockHit").length)


## Yere dusme (savas "down" etkisi): olum hareketinin dusus kismi oynar, yerde kisa bekler, ayni hareket geri
## sarilarak kalkar. Toplam sure savasin DOWN_TIME'i kadardir; kalkinca bekleme durusuna gecilir.
func knockdown() -> void:
	if _down or not ent.alive or not _mx:
		return
	_down = true
	_charge = 0.0
	_freeze = 0.0 # darbe donmasi dususu yavaslatip yarida birakiyordu
	_drag = 0.0
	_lag = 0.0
	_motion_t = -1.0
	_next_anim = ""
	_settle_t = 0.0
	for m in _meshes:
		if m.visible:
			m.material_overlay = null
	if rig != null:
		rig.cancel()
	var span: Array = DOWN_SPAN.get(_px, [1.0, 1.65])
	var fall := 0.5
	var rise := 0.55
	_ap.play(_px + "Death", 0.08, 1.0)
	_ap.seek(span[0], true)
	var dist: float = span[1] - span[0]
	_phases.clear()
	_phases.append([fall, dist / fall])
	_phases.append([maxf(GameData.DOWN_TIME - fall - rise, 0.05), 0.0])
	_phases.append([rise, -dist / rise])
	_action_t = GameData.DOWN_TIME
	if spring != null and _last_from != Vector3.INF:
		spring.hit(_last_from, 1.6)


## Hazirlik kesildi: hareket yarida kalir, karakter sarsilir.
func interrupt() -> void:
	if _down: # yerdeki karakterin dususu kesilmez
		return
	_charge = 0.0
	_motion_t = -1.0
	_next_anim = ""
	_phases.clear()
	for m in _meshes:
		if m.visible:
			m.material_overlay = null
	_ap.play(_px + "Hit" if _mx else "Hit_Head", 0.1, 1.0 if _mx else 0.7)
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
	if _weapon == "sledge":
		return [[_hand, "sledge"]]
	if _shield != null:
		return [[_shield, "shield"], [_hand, "sword"]]
	return [[_hand, "axe"], [_off_hand, "axe"]]


func snap() -> void:
	_sync(1.0)


func _sync(k: float) -> void:
	if step_frac >= 0.0 and prev_pos != Vector2.INF and prev_pos.distance_to(ent.pos) < 1.5:
		# yerel savas: son iki adim arasinda dogrudan ara konum (yumusatma gecikmesi yok, en cok bir adim geride)
		var p := prev_pos.lerp(ent.pos, step_frac)
		position.x = p.x
		position.z = p.y
	else: # online katilan taraf ya da isinlanma: ag konumuna yumusak yetisir
		position.x = lerpf(position.x, ent.pos.x, k)
		position.z = lerpf(position.z, ent.pos.y, k)
	# Kameraya donuk durus: yuz ve zirh okunur, balyozcunun iki eli birden gorunur
	var turn: float = 0.75 if _weapon == "sledge" and not _mx else 0.35
	if ent.moving and _mx:
		turn *= 0.1 # kosarken gittigi yone bakar: capraz duran govdede ayak yere yan basip kayiyordu
	rotation.y = lerp_angle(rotation.y, ent.face - turn * signf(sin(ent.face)), k)


## Olum: beden son darbenin geldigi yonun tersine savrulur; agir darbe daha uzaga atar (0,3-0,9 m).
## Olum hareketleri geriye dusenlerden secildi (vurandan uzaga), savrulma ayni yone ekler.
func _start_fall() -> void:
	var away := Vector3.ZERO
	if _last_from != Vector3.INF:
		away = global_position - _last_from
		away.y = 0.0
	if away.length() < 0.01:
		away = -global_transform.basis.z
	var local := global_transform.basis.inverse() * away.normalized()
	local.y = 0.0
	_slide_dir = local.normalized()
	_slide_goal = 0.25 + 0.4 * clampf(_last_w, 0.2, 1.6)
	if spring != null and _last_from != Vector3.INF:
		spring.hit(_last_from, minf(_last_w + 0.4, 1.6))


## Yere oturtma: onceki karenin ayak kemiklerinden en alttaki tabanin yuksekligi bulunur; yerin altindaysa govde hemen
## kalkar, ustundeyse yavasca eski yerine iner (zipzip olmaz).
func _ground_lift(delta: float) -> float:
	if _died or _down or not SOLE.has(_px):
		return move_toward(_ground_fix, 0.0, delta * 0.5)
	var s: Array = SOLE[_px]
	var low := INF
	for side: String in ["l", "r"]:
		var ball := _skeleton.find_bone("ball_" + side)
		var foot := _skeleton.find_bone("foot_" + side)
		if ball >= 0:
			low = minf(low, (_skeleton.global_transform * _skeleton.get_bone_global_pose(ball).origin).y - float(s[0]))
		if foot >= 0:
			low = minf(low, (_skeleton.global_transform * _skeleton.get_bone_global_pose(foot).origin).y - float(s[1]))
	if low == INF:
		return _ground_fix
	var want := maxf(0.0, _ground_fix - (low - global_position.y))
	return want if want > _ground_fix else move_toward(_ground_fix, want, delta * 0.25)


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
		forward = lerpf(-0.14 * fwd, fwd, into * into * (3.0 - 2.0 * into)) * (1.0 - after * after) # yumusak: one atilma sonda hizlanmaz
		lift = sin(into * PI) * float(_motion.get("lift", 0.0))
		if _motion.has("spin"):
			var turns: float = _motion["spin"]
			spin = TAU * turns * clampf((_motion_t - wind + 0.15) / 0.9, 0.0, 1.0)
		if _motion_t > wind + 1.2:
			_motion_t = -1.0
	_knock *= exp(-delta * 7.0)
	_recoil = lerpf(_recoil, _recoil_goal, 1.0 - exp(-delta * 34.0)) # ani savrulur, yavas doner
	_recoil_goal *= exp(-delta * 5.0)
	_twist = lerpf(_twist, _twist_goal, 1.0 - exp(-delta * 30.0))
	_twist_goal *= exp(-delta * 6.0)
	_slide = lerpf(_slide, _slide_goal, 1.0 - exp(-delta * 5.0))
	_ground_fix = _ground_lift(delta)
	_model.position = Vector3(0, lift + float(FOOT_LIFT.get(_px, 0.0)) + _ground_fix, forward - _knock) + _slide_dir * _slide
	if _blob != null:
		_blob.position = Vector3(_model.position.x, 0.02, _model.position.z)
	_model.rotation = Vector3(-_recoil, spin + _twist, 0.0)
	if _charge > 0.0:
		_charge -= delta
		_charge_mat.albedo_color.a = 0.0 if _charge <= 0.0 else 0.07 + sin(_charge * 9.0) * 0.03 # hafif: hareket boyanin altinda kaybolmasin (kullanici)
		for m in _meshes:
			if m.visible:
				m.material_overlay = _charge_mat if _charge > 0.0 else null


## Donmus karakter buzla kaplanir, hareketi oldugu yerde durur (Buz Muhru, Buz Kolu).
func _update_ice() -> void:
	var cold := ent.alive and ent.fx.any(func(f: Dictionary) -> bool: return f["type"] == "freeze")
	if not cold and not _iced:
		return
	_iced = cold
	if cold:
		_ap.speed_scale = 0.0
		if rig != null:
			rig.speed = 0.08
	if _ice_mat == null:
		_ice_mat = StandardMaterial3D.new()
		_ice_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ice_mat.albedo_color = Color(0.62, 0.88, 1.0, 0.5)
		_ice_mat.emission_enabled = true
		_ice_mat.emission = Color(0.25, 0.55, 0.85)
		_ice_mat.roughness = 0.08
		_ice_mat.metallic_specular = 1.0
	for m in _meshes:
		if m.visible:
			m.material_overlay = _ice_mat if cold else null


func _process(delta: float) -> void:
	_update_kilt()
	_update_flash(delta)
	var ts := _impact_scale()
	if _catch:
		# yalniz eklenen yavas cikis ve geri kazanma hesaba girer; eski donmanin gecikmesi zamanlamalarda zaten var
		if _freeze <= 0.0:
			_lag = maxf(0.0, _lag + delta * (1.0 - ts))
		if _lag <= 0.0 and _freeze <= 0.0 and _drag <= 0.0:
			_catch = false
	if _freeze > 0.0:
		_freeze -= delta
	elif _drag > 0.0:
		_drag -= delta
	if rig != null:
		rig.speed = _impact_scale()
	_advance_phases(delta)
	if ent == null:
		return
	_update_trail()
	_update_skill_motion(delta)
	_update_ice()
	_update_grip(delta)
	if _foot_lock != null:
		_foot_lock.prepare()
		_foot_lock.enabled = not (_died or _down)
	if _ice_t > 0.0:
		_ice_t -= delta
		if _ice_t <= 0.0 or not ent.alive:
			_hide_ice_shield()
	_sync(1.0 - exp(-delta * 18.0))
	if _last_pos != Vector3.INF and delta > 0.0:
		var step := Vector2(position.x - _last_pos.x, position.z - _last_pos.z).length() / delta
		_vel = lerpf(_vel, step, 1.0 - exp(-delta * 10.0))
	_last_pos = position
	_loco = 1.0
	if not ent.alive:
		if not _died:
			_died = true
			_next_anim = ""
			_phases.clear()
			_ap.speed_scale = 1.0
			if not _down: # yerdeyken olen karakter dususune devam eder, ayaga kalkip yeniden dusmez
				_ap.play(_px + "Death" if _mx else "Death01", 0.2)
			_start_fall()
			if guard != null:
				guard.released = true
			if rig != null:
				rig.released = true
		return
	_action_t -= delta
	if _action_t > 0.0:
		return
	_down = false
	var want := _idle_anim()
	var speed := 1.0
	if ent.fx.any(func(f: Dictionary) -> bool: return f["type"] == "stun"):
		# Mixamo iskeletinde Zombie_Idle govdeyi yere yigiyordu: sersem karakter yalniz agir ve yavas bekler
		if _mx:
			speed = 0.45
		else:
			want = "Zombie_Idle"
	elif ent.moving:
		want = _px + "Walk" if _mx else ("Walk" if _weapon == "sledge" else "Jog_Fwd")
		speed = 1.6 if _weapon == "sledge" and not _mx else 1.0
		if _mx and _ap.has_animation(_px + "Run"):
			# kosu, gercek ilerleme hizina gore hizlanir/yavaslar: ayak yere oturur (en cok 1,7 kat, telasli gorunmesin)
			want = _px + "Run"
			_loco = clampf(maxf(_vel, 1.0) / (float(RUN_STRIDE.get(_px, 3.0)) * _model.scale.x), 0.7, 1.7)
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
