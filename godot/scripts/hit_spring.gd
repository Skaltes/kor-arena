class_name HitSpring
extends SkeletonModifier3D
## Darbe tepkisi icin yay fizigi: govde, boyun ve bas darbenin geldigi yonun tersine itilir, sonumlu yay gibi
## salinip animasyona geri doner. Animasyonun USTUNE eklenir, onu bozmaz. Gercek fizik motoru kullanmaz:
## titremez, carpisma gerekmez, her modelde ayni calisir (kemik adlari model_prep ile Quaternius adlaridir).

const STIFF := 170.0 # yay sertligi: buyudukce daha cabuk geri doner
const DAMP := 17.0 # sonum: titresmesin, bir kez salinip dursun
const LIMIT := 0.75 # en buyuk toplam egilme (radyan): govde kirilmis gibi durmasin
## [kemik, egilme payi, burkulma payi]: kuvvet omurgaya yayilir, bas en serbest olandir
const CHAIN := [["spine_01", 0.22, 0.25], ["spine_02", 0.26, 0.3], ["spine_03", 0.28, 0.3], ["neck_01", 0.2, 0.1], ["Head", 0.32, 0.15]]

var _ids: Array[int] = []
var _scale := 1.0 # eksik kemigin egilme payi kalanlara dagitilir
var _bend := Vector3.ZERO # iskelet uzayinda egilme ekseni x aci (yonlu vektor)
var _bend_v := Vector3.ZERO
var _twist := 0.0 # dikey eksen etrafinda burkulma
var _twist_v := 0.0
var _head_boost := 0.0 # kafaya gelen darbede bas daha cok gider
var _last_out := {} # kemik -> en son yazdigimiz durus. Animasyon o kemigi yeniden yazmadiysa (donuk/durmus animasyon)
var _clean := {} # kemik -> yaydan onceki temiz durus; pay ust uste binmesin diye ondan hesaplanir


func _ready() -> void:
	var sk := get_skeleton()
	for c: Array in CHAIN:
		_ids.append(sk.find_bone(c[0]))
	var have := 0.0
	var total := 0.0
	for i in CHAIN.size():
		total += float(CHAIN[i][1])
		if _ids[i] >= 0:
			have += float(CHAIN[i][1])
	_scale = total / have if have > 0.0 else 1.0


## from: vuranin dunya konumu, weight: darbe agirligi (0,2-1,6), head: kafaya mi geldi.
func hit(from: Vector3, weight: float, head := false) -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	var away := sk.global_position - from
	away.y = 0.0
	if away.length() < 0.01:
		return
	var local := (sk.global_transform.basis.inverse() * away.normalized()).normalized()
	var axis := Vector3.UP.cross(local).normalized() # bu eksen etrafinda donus ust govdeyi "away" yonune iter
	_bend_v += axis * (3.2 + weight * 5.5)
	_twist_v += (1.6 + weight * 2.4) * (1.0 if randf() < 0.5 else -1.0)
	_head_boost = 1.0 if head else 0.0


func _process_modification_with_delta(delta: float) -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	var dt := minf(delta, 1.0 / 30.0)
	# sonumlu yay (yari kapali Euler: buyuk adimda da kararli)
	_bend_v += (-_bend * STIFF - _bend_v * DAMP) * dt
	_bend += _bend_v * dt
	if _bend.length() > LIMIT:
		_bend = _bend.normalized() * LIMIT
		_bend_v *= 0.5
	_twist_v += (-_twist * STIFF - _twist_v * DAMP) * dt
	_twist += _twist_v * dt
	_twist = clampf(_twist, -LIMIT * 0.5, LIMIT * 0.5)
	_head_boost = maxf(0.0, _head_boost - dt * 2.0)
	if _bend.length() < 0.002 and absf(_twist) < 0.002:
		_restore(sk)
		return
	var angle := _bend.length()
	var axis := _bend / angle if angle > 0.0 else Vector3.RIGHT
	for i in _ids.size():
		var id := _ids[i]
		if id < 0: # bazi modellerde omurga kemigi eksik (Titan: spine_02 yok); payi digerlerine kalir
			continue
		var share: float = CHAIN[i][1] * _scale * (1.0 + _head_boost * (1.5 if i == 4 else 0.0))
		var parent := sk.get_bone_parent(id)
		var pb := sk.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis.IDENTITY
		# iskelet uzayindaki eksenler kemigin yerel uzayina cevrilir: egilme yonu modelin durusundan bagimsiz
		var q := Quaternion((pb.inverse() * axis).normalized(), angle * share)
		q = Quaternion((pb.inverse() * Vector3.UP).normalized(), _twist * float(CHAIN[i][2])) * q
		var base := _base(sk, id)
		var out := q * base
		sk.set_bone_pose_rotation(id, out)
		_last_out[id] = out
		_clean[id] = base


## Kemigin animasyondan gelen temiz durusu: kemik hala bizim son yazdigimizsa animasyon yazmamistir, saklanan temiz durus doner.
func _base(sk: Skeleton3D, id: int) -> Quaternion:
	var cur := sk.get_bone_pose_rotation(id)
	if _last_out.has(id) and absf(cur.dot(_last_out[id])) > 0.9999999:
		return _clean[id]
	return cur


## Yay durdu: animasyon yazmadiysa kemik temiz durusuna geri konur.
func _restore(sk: Skeleton3D) -> void:
	for id: int in _last_out:
		sk.set_bone_pose_rotation(id, _base(sk, id))
	_last_out.clear()
	_clean.clear()
