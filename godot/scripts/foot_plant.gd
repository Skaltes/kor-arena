class_name FootPlant
extends SkeletonModifier3D
## Ayak tabani yere duz basar (kullanici istegi): Mixamo hareketleri bu modellere aktarilinca ayak ucu asagi donuyor,
## parmaklar yere batiyordu. Ayak yere yakinken (bilek yuksekligi dinlenme durusuna yakin) taban yere paralel cevrilir
## ve parmak kemigi dinlenme acisina doner; ayak kalktikca (adim, tekme) etki yumusakca sifirlanir.

const LIFT_START := 0.03 # bilek dinlenme yuksekliginin bu kadar ustune kadar tam duzeltme
const LIFT_END := 0.14 # bu kadar ustunde duzeltme yok

var _feet: Array[Array] = [] # [ayak kemigi, parmak kemigi, tabanin ayak uzayindaki yukari yonu, dinlenme bilek yuksekligi]


func _ready() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for side: String in ["l", "r"]:
		var foot := sk.find_bone("foot_" + side)
		if foot < 0:
			continue
		var rest := sk.get_bone_global_rest(foot)
		_feet.append([foot, sk.find_bone("ball_" + side), (rest.basis.orthonormalized().inverse() * Vector3.UP).normalized(), rest.origin.y])


func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for f: Array in _feet:
		var pose := sk.get_bone_global_pose(f[0])
		var w := 1.0 - smoothstep(float(f[3]) + LIFT_START, float(f[3]) + LIFT_END, pose.origin.y)
		if w <= 0.0:
			continue
		var scale := pose.basis.get_scale()
		var b := pose.basis.orthonormalized()
		var sole: Vector3 = (b * f[2]).normalized()
		var fix := Quaternion(sole, Vector3.UP).slerp(Quaternion.IDENTITY, 1.0 - w)
		pose.basis = Basis(fix * b.get_rotation_quaternion()).scaled(scale)
		sk.set_bone_global_pose(f[0], pose)
		if f[1] >= 0:
			var toe := sk.get_bone_pose_rotation(f[1]).slerp(sk.get_bone_rest(f[1]).basis.get_rotation_quaternion(), w)
			sk.set_bone_pose_rotation(f[1], toe)
