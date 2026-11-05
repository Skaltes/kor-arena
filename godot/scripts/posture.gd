class_name Posture
extends SkeletonModifier3D
## Dik durus (kullanici istegi: Titan kambur duruyordu). Hazir hareketler bu modele aktarilinca govde ~23 derece one
## egik kaliyordu. Omurga, kalcanin O ANKI yan ekseni etrafinda geriye acilir (donen hareketlerde de dogru yone);
## boyun ayni acinin bir kismini geri verir, bakis one kalir. Yay fizigi ve el duzeltmelerinden ONCE calisir.

var angle := 0.0 # toplam geri acilma (radyan)
var _pelvis := -1
var _spines: Array[int] = []
var _neck := -1
var _side := Vector3.RIGHT # kalcanin dinlenme uzayinda yan eksen


func _ready() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	_pelvis = sk.find_bone("pelvis")
	for b: String in ["spine_01", "spine_03"]:
		if sk.find_bone(b) >= 0:
			_spines.append(sk.find_bone(b))
	_neck = sk.find_bone("neck_01")
	if _pelvis >= 0:
		_side = (sk.get_bone_global_rest(_pelvis).basis.orthonormalized().inverse() * Vector3.RIGHT).normalized()


func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if sk == null or _pelvis < 0 or _spines.is_empty() or angle == 0.0:
		return
	var side := (sk.get_bone_global_pose(_pelvis).basis.orthonormalized() * _side).normalized()
	# karakter +Z'ye bakar: +X ekseni etrafinda eksi donus ust govdeyi geriye (-Z) yatirir
	var back := Basis(side, -angle / _spines.size())
	for b in _spines:
		var pose := sk.get_bone_global_pose(b)
		var s := pose.basis.get_scale()
		pose.basis = (back * pose.basis.orthonormalized()).scaled(s)
		sk.set_bone_global_pose(b, pose)
	if _neck >= 0: # bas yukari bakmasin: acinin yarisi boyunda geri alinir
		var pose := sk.get_bone_global_pose(_neck)
		var s := pose.basis.get_scale()
		pose.basis = (Basis(side, angle * 0.5) * pose.basis.orthonormalized()).scaled(s)
		sk.set_bone_global_pose(_neck, pose)
