class_name HandRig
extends SkeletonModifier3D
## Tek elli silahlar: sap gövdeye ya da basa yonelirse bilek disari cevrilir. Kol hareketi animasyondan gelir.

const BACK := 0.16 # sapin elin arkasinda kalan boyu
const FRONT := 0.75
const TURN_SPEED := 9.0

## [kemik adi, silah ekseni kemik uzayinda]
var hands: Array = []
var curl_left := false

var _bones: Array[Array] = [] # [kemik, eksen, donus orani]
var _body: Array[Array] = []
var _spine: Array[int] = []
var _curls: Array[Array] = []


func _ready() -> void:
	var sk := get_skeleton()
	for h: Array in hands:
		_bones.append([sk.find_bone(h[0]), h[1], 0.0])
	_spine = [sk.find_bone("spine_01"), sk.find_bone("neck_01")]
	_body = [[_spine[0], _spine[1], 0.24], [sk.find_bone("Head"), sk.find_bone("Head"), 0.27]]
	for leg: String in ["l", "r"]:
		_body.append([sk.find_bone("thigh_" + leg), sk.find_bone("calf_" + leg), 0.15])
		_body.append([sk.find_bone("calf_" + leg), sk.find_bone("foot_" + leg), 0.12])
	if not curl_left:
		return
	var rest := sk.get_bone_global_rest(sk.find_bone("hand_l"))
	var f := (sk.get_bone_global_rest(sk.find_bone("middle_01_l")).origin - rest.origin).normalized()
	var palm := (Vector3.DOWN - f * Vector3.DOWN.dot(f)).normalized()
	var axis := f.cross(palm).normalized()
	for finger: String in ["index", "middle", "ring", "pinky"]:
		for joint in range(1, 4):
			var bone := sk.find_bone("%s_0%d_l" % [finger, joint])
			_curls.append([bone, Quaternion((sk.get_bone_global_rest(bone).basis.inverse() * axis).normalized(), 1.0 if joint == 1 else 1.25)])


func _clear(sk: Skeleton3D, p: Vector3, a: Vector3) -> bool:
	for seg: Array in _body:
		var near := Geometry3D.get_closest_points_between_segments(p - a * BACK, p + a * FRONT, sk.get_bone_global_pose(seg[0]).origin, sk.get_bone_global_pose(seg[1]).origin)
		if near[0].distance_to(near[1]) < float(seg[2]):
			return false
	return true


func _process_modification_with_delta(delta: float) -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for h: Array in _bones:
		var pose := sk.get_bone_global_pose(h[0])
		var a: Vector3 = (pose.basis * h[1]).normalized()
		var spine := Geometry3D.get_closest_point_to_segment(pose.origin, sk.get_bone_global_pose(_spine[0]).origin, sk.get_bone_global_pose(_spine[1]).origin)
		var out := ((pose.origin - spine).normalized() + Vector3(0, 0.25, 0.5)).normalized()
		var want := 1.0
		for t: float in [0.0, 0.25, 0.5, 0.75]:
			if _clear(sk, pose.origin, a.slerp(out, t).normalized()):
				want = t
				break
		h[2] = move_toward(h[2], want, delta * TURN_SPEED)
		if h[2] > 0.0:
			var turned := a.slerp(out, h[2]).normalized()
			pose.basis = Basis(Quaternion(a, turned)) * pose.basis
			sk.set_bone_global_pose(h[0], pose)
	for c: Array in _curls:
		sk.set_bone_pose_rotation(c[0], sk.get_bone_rest(c[0]).basis.get_rotation_quaternion() * c[1])
