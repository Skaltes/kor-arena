class_name ShieldRig
extends SledgeRig
## Paladin: kalkan gogsun onunde kendi yerinde durur, sol kol her karede arkasina cozulur.
## Hazir animasyonlar kalkansiz yapildigi icin kol onlara birakilmaz: kalkan kola ve govdeye girmez.

const GUARD := [Vector3(0.36, -0.1, 0.32), Vector3(0.76, 0.05, 0.65)] # sol yanda: kilic kolunun yolunu kesmez
const THRUST := [Vector3(0.34, -0.04, 0.42), Vector3(0.6, 0.05, 0.8)]
const STRAP := 0.1 # kalkan yuzeyinden kayisa
const ARM_CLEAR := 0.36 # sag kolla kalkan merkezi arasindaki en az mesafe
const SHIELD_SCALE := 0.82

var shield: Node3D

var _pose: Array = GUARD
var _pos: Vector3 = GUARD[0]
var _normal: Vector3 = GUARD[1].normalized()
var _thrust_t := 0.0
var _slide := Vector3.ZERO


func thrust(impact: float) -> void:
	_thrust_t = impact + 0.35


func _process_modification_with_delta(delta: float) -> void:
	var sk := get_skeleton()
	if sk == null or _chest < 0 or shield == null:
		return
	if released:
		shield.position = sk.get_bone_global_pose(_arms["l"][2]).origin
		return
	_thrust_t -= delta
	_pose = THRUST if _thrust_t > 0.0 else GUARD
	var k := 1.0 - exp(-delta * (14.0 if _thrust_t > 0.0 else 7.0))
	_pos = _pos.lerp(_pose[0], k)
	_normal = _normal.lerp(_pose[1], k).normalized()
	var center := sk.get_bone_global_pose(_chest).origin + _pos
	# Kilic kolu kalkana dogru savrulursa kalkan yana acilir
	var near := Geometry3D.get_closest_point_to_segment(center, sk.get_bone_global_pose(_arms["r"][1]).origin, sk.get_bone_global_pose(_arms["r"][2]).origin)
	var gap := center.distance_to(near)
	var want := Vector3.ZERO
	if gap < ARM_CLEAR:
		var dir := center - near
		dir.y = 0.0
		want = (dir.normalized() if dir.length() > 0.01 else Vector3.RIGHT) * (ARM_CLEAR - gap)
	_slide = want if want.length() > _slide.length() else _slide.lerp(want, 1.0 - exp(-delta * 8.0))
	center += _slide
	var side := Vector3.UP.cross(_normal).normalized()
	var up := _normal.cross(side).normalized()
	shield.transform = Transform3D(Basis(side, up, _normal).scaled_local(Vector3.ONE * SHIELD_SCALE), center)

	var ids: Array = _arms["l"]
	var grip := center - _normal * STRAP
	var shoulder := sk.get_bone_global_pose(ids[0]).origin
	var along := grip - shoulder
	var f := (along - _normal * along.dot(_normal)).normalized()
	var local: Basis = _frames["l"]
	var palm := -_normal
	var t := palm.cross(f).normalized() * signf(local.x.cross(local.y).dot(local.z))
	var world := Basis(f, t, palm)
	_arm(ids, grip - f * PALM_FORWARD - palm * PALM_DEPTH, Vector3(0.9, -0.9, -0.2))
	var hand := sk.get_bone_global_pose(ids[2])
	hand.basis = world * local.inverse()
	sk.set_bone_global_pose(ids[2], hand)
	for c: Array in _curls:
		sk.set_bone_pose_rotation(c[0], sk.get_bone_rest(c[0]).basis.get_rotation_quaternion() * c[1])
