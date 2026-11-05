class_name FacingLock
extends SkeletonModifier3D
## Yon kilidi (kullanici sorunu: hazir hareketler vururken govdeyi 90-180 derece donduruyor, yandan kamerada
## karakter sirtini donuyordu). Kalca ve gogsun DIKEY eksen etrafindaki donusu `limit` ile sinirlanir; kollar ve silah
## hareketin kendisini yapar, yalniz govde rakibe dönük kalir. Yalniz `on` acikken (hareket kaydinda "face") calisir,
## yumusakca acilip kapanir. Posture'dan ONCE calisir.

var on := false
var limit := deg_to_rad(25.0)
var _w := 0.0
var _pelvis := -1
var _chest := -1
var _spine := -1
var _fp := Vector3.FORWARD # kalcanin dinlenme uzayinda ileri yon
var _fc := Vector3.FORWARD


func _ready() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	_pelvis = sk.find_bone("pelvis")
	_spine = sk.find_bone("spine_01")
	_chest = sk.find_bone("spine_03")
	if _pelvis >= 0:
		_fp = sk.get_bone_global_rest(_pelvis).basis.orthonormalized().inverse() * Vector3(0, 0, 1)
	if _chest >= 0:
		_fc = sk.get_bone_global_rest(_chest).basis.orthonormalized().inverse() * Vector3(0, 0, 1)


func _yaw(b: Basis, local: Vector3) -> float:
	var f := b.orthonormalized() * local
	return atan2(f.x, f.z) if Vector2(f.x, f.z).length() > 0.05 else 0.0


func _excess(a: float) -> float:
	return a - clampf(a, -limit, limit)


func _turn(sk: Skeleton3D, bone: int, ang: float) -> void:
	var pose := sk.get_bone_global_pose(bone)
	var s := pose.basis.get_scale()
	pose.basis = (Basis(Vector3.UP, ang) * pose.basis.orthonormalized()).scaled(s)
	sk.set_bone_global_pose(bone, pose)


func _process_modification_with_delta(delta: float) -> void:
	_w = move_toward(_w, 1.0 if on else 0.0, delta * 6.0)
	var sk := get_skeleton()
	if sk == null or _pelvis < 0 or _w <= 0.0:
		return
	var fix := -_excess(_yaw(sk.get_bone_global_pose(_pelvis).basis, _fp)) * _w
	if absf(fix) > 0.0001:
		_turn(sk, _pelvis, fix) # kalca tum govdeyi tasir (cocuk kemikler global pozda guncellenir)
	if _chest >= 0 and _spine >= 0:
		var c := -_excess(_yaw(sk.get_bone_global_pose(_chest).basis, _fc)) * _w
		if absf(c) > 0.0001:
			_turn(sk, _spine, c)
