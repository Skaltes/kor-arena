class_name SledgeRig
extends SkeletonModifier3D
## Iki elli balyoz. Hazir animasyonlar tek elle yapildigi icin kollar burada yeniden cozulur:
## balyoz gogse gore hareket eder, iki avuc her karede sapin uzerinde durur, parmaklar sapi sarar.
## Hedef kol boyundan uzaksa balyoz govdeye dogru cekilir: temas hicbir pozda kopmaz.

const GRIP_LOW := -0.14 # alt el sapin ucuna yakin: sap vucuda dogru tasmaz
const GRIP_HIGH := 0.3 # ust el: eller belirgin aralikli, iki el net gorunur
const SHAFT_BACK := 0.2 # sapin alt ucu
const SHAFT_FRONT := 1.2 # balyoz basinin ucu
const BODY_R := 0.25 # sap ile govde/bas/bacak arasinda kalacak en az mesafe
const PALM_FORWARD := 0.085 # bilekten avuc ortasina
const PALM_DEPTH := 0.032 # avuc yuzeyinden sapa
const REACH_MARGIN := 0.03
const SPINE_LEAN := 0.7 # egilme iki omurga kemigine paylasilir
## [gogse gore iki elin ortasi, sapin yonu, govde egilmesi] karakter +Z yonune bakar
const IDLE := [Vector3(0.0, -0.14, 0.27), Vector3(0.62, 0.35, 0.7), 0.1] # sap gogsun onunde capraz, bas rakibe bakar
const RAISED := [Vector3(0.0, 0.3, 0.26), Vector3(0.0, 0.8, -0.6), -0.3] # eller alnin onunde: ikisi de gorunur
const SLAM := [Vector3(0.0, -0.3, 0.26), Vector3(0.0, -0.52, 0.85), 0.5]
const WIDE_BACK := [Vector3(-0.1, -0.2, 0.26), Vector3(-0.7, 0.3, -0.65), -0.1]
const WIDE_FRONT := [Vector3(0.12, -0.14, 0.3), Vector3(0.76, 0.0, 0.65), 0.3]
const UP := [Vector3(0.0, 0.32, 0.28), Vector3(0.0, 0.96, 0.28), -0.2]
const GROUND := [Vector3(0.0, -0.32, 0.22), Vector3(0.0, -0.84, 0.54), 0.65]
const LOW_BACK := [Vector3(-0.04, -0.36, 0.26), Vector3(-0.16, -0.5, -0.85), 0.25]
const HIGH_BACK := [Vector3(0.0, 0.32, 0.22), Vector3(0.0, 0.58, -0.81), -0.42]
const PLANT := [Vector3(0.1, -0.1, 0.32), Vector3(0.1, -0.9, 0.42), 0.1]
const ABOVE := [Vector3(0.0, 0.3, 0.06), Vector3(0.98, 0.14, 0.1), -0.25]
## Hareket adi: [hazirligin yuzde kacinda, poz, yaklasma hizi] sirali anahtarlar. -1 = silahin inisi: isabetten STRIKE once.
const STRIKE := 0.11
const MOVES := {
	"overhead": [[0.0, RAISED, 7.0], [-1.0, SLAM, 34.0], [1.25, IDLE, 4.0]],
	"side": [[0.0, WIDE_BACK, 7.0], [-1.0, WIDE_FRONT, 34.0], [1.3, IDLE, 4.0]],
	"ground": [[0.0, UP, 8.0], [-1.0, GROUND, 40.0], [1.5, IDLE, 3.0]],
	"charge": [[0.0, WIDE_BACK, 5.0], [0.42, RAISED, 5.0], [-1.0, SLAM, 44.0], [1.3, IDLE, 3.0]],
	"plant": [[0.0, PLANT, 9.0]],
	"roar": [[0.0, ABOVE, 8.0]],
}
var weapon: Node3D
var released := false # olumde kollar serbest kalir
var frozen := false # isabet duraklamasi
var flip := false # sagdaki savasci: pozlar aynalanir, balyoz yine rakibe bakar
var worst_gap := 0.0 # test icin: avuc ile sap arasinda gorulen en buyuk mesafe

var _chest := -1
var _probes := {}
var _body_bones: Array[Array] = []
var _arms := {}
var _frames := {} # el kemigi uzayinda parmak, basparmak, avuc yonleri
var _curls: Array[Array] = []
var _center: Vector3 = IDLE[0]
var _dir: Vector3 = IDLE[1].normalized()
var _lean: float = IDLE[2]
var _spine: Array[int] = []
var _move: Array = []
var _t := -1.0
var _impact := 0.0
var _total := 0.0


func _ready() -> void:
	var sk := get_skeleton()
	_chest = sk.find_bone("spine_03")
	_spine = [sk.find_bone("spine_01"), sk.find_bone("spine_02")]
	_body_bones = [[sk.find_bone("pelvis"), sk.find_bone("neck_01"), BODY_R], [sk.find_bone("Head"), sk.find_bone("Head"), 0.32], [sk.find_bone("thigh_l"), sk.find_bone("calf_l"), 0.14], [sk.find_bone("thigh_r"), sk.find_bone("calf_r"), 0.14], [sk.find_bone("upperarm_l"), sk.find_bone("upperarm_l"), 0.2], [sk.find_bone("upperarm_r"), sk.find_bone("upperarm_r"), 0.2]]
	for side: String in ["l", "r"]:
		var ids := [sk.find_bone("upperarm_" + side), sk.find_bone("lowerarm_" + side), sk.find_bone("hand_" + side)]
		_arms[side] = ids
		var probe := BoneAttachment3D.new()
		sk.add_child(probe)
		probe.bone_name = "hand_" + side
		_probes[side] = probe
		var hand := sk.get_bone_global_rest(ids[2])
		var f := (sk.get_bone_global_rest(sk.find_bone("middle_01_" + side)).origin - hand.origin).normalized()
		var thumb := sk.get_bone_global_rest(sk.find_bone("thumb_01_" + side)).origin - hand.origin
		var palm := (Vector3.DOWN - f * Vector3.DOWN.dot(f)).normalized() # T duruşunda avuc yere bakar
		var t := (thumb - f * thumb.dot(f) - palm * thumb.dot(palm)).normalized()
		var to_local := hand.basis.inverse()
		_frames[side] = Basis(to_local * f, to_local * t, to_local * palm)
		var axis := f.cross(palm).normalized() # parmagi avuca kapatan eksen
		for finger: String in ["index", "middle", "ring", "pinky"]:
			for joint in range(1, 4):
				var bone := sk.find_bone("%s_0%d_%s" % [finger, joint, side])
				var local := sk.get_bone_global_rest(bone).basis.inverse() * axis
				_curls.append([bone, Quaternion(local.normalized(), 1.0 if joint == 1 else 1.25)])
		var thumb2 := sk.find_bone("thumb_02_" + side)
		var local2 := sk.get_bone_global_rest(thumb2).basis.inverse() * axis
		_curls.append([thumb2, Quaternion(local2.normalized(), 0.6)])


## impact: silahin hedefe indigi an, total: hareketin tamami (saniye)
func play(move: String, impact: float, total: float) -> void:
	_move = MOVES[move]
	_t = 0.0
	_impact = maxf(impact, 0.2)
	_total = total


## Test: isabet ani ile planlanan vurus ani arasindaki fark (saniye).
func strike_error() -> float:
	return absf(_t - _impact)


func cancel() -> void:
	_t = -1.0


func _wanted() -> Array:
	if _t < 0.0:
		return [IDLE, 7.0]
	var found: Array = _move[0]
	for key: Array in _move:
		var at: float = _impact - STRIKE if float(key[0]) < 0.0 else float(key[0]) * _impact
		if _t >= at:
			found = key
	return [found[1], found[2]]

func _process_modification_with_delta(step: float) -> void:
	var delta := step * (0.08 if frozen else 1.0)
	var sk := get_skeleton()
	if sk == null or _chest < 0 or weapon == null:
		return
	if released:
		weapon.position = sk.get_bone_global_pose(_arms["r"][2]).origin
		return
	if _t >= 0.0:
		_t += delta
		if _t > _total:
			_t = -1.0
	var w: Array = _wanted()
	var pose: Array = w[0]
	var k := 1.0 - exp(-delta * float(w[1]))
	var mirror := Vector3(-1.0 if flip else 1.0, 1.0, 1.0)
	_center = _center.lerp(pose[0] * mirror, k)
	_dir = _dir.lerp(pose[1] * mirror, k).normalized()
	_lean = lerpf(_lean, pose[2], k)
	for bone in _spine: # govde de vurusa katilir
		var g := sk.get_bone_global_pose(bone)
		g.basis = Basis(Vector3.RIGHT, _lean * SPINE_LEAN) * g.basis
		sk.set_bone_global_pose(bone, g)
	var base := sk.get_bone_global_pose(_chest).origin + _center - _dir * ((GRIP_LOW + GRIP_HIGH) * 0.5)
	for i in 3:
		base = _keep_clear(sk, base)
		base = _fit_reach(sk, base) # son soz temasin: eller saptan asla ayrilmaz
	var side := _dir.cross(Vector3.FORWARD)
	if side.length_squared() < 0.01:
		side = Vector3.RIGHT
	side = side.normalized()
	weapon.transform = Transform3D(Basis(side, _dir, side.cross(_dir)), base)
	_grip("l" if flip else "r", base + _dir * GRIP_LOW)
	_grip("r" if flip else "l", base + _dir * GRIP_HIGH)
	for c: Array in _curls:
		sk.set_bone_pose_rotation(c[0], sk.get_bone_rest(c[0]).basis.get_rotation_quaternion() * c[1])


## Sap govdeye, basa ya da bacaga giriyorsa balyozun tamami vucuttan disari itilir.
func _keep_clear(sk: Skeleton3D, base: Vector3) -> Vector3:
	var p: Vector3
	for seg: Array in _body_bones:
		var a := sk.get_bone_global_pose(seg[0]).origin
		var b := sk.get_bone_global_pose(seg[1]).origin
		var near := Geometry3D.get_closest_points_between_segments(base - _dir * SHAFT_BACK, base + _dir * SHAFT_FRONT, a, b)
		p = near[0] - near[1]
		p.y *= 0.3 # one ve yana itmek yukari itmekten dogal
		var gap := p.length()
		if gap < float(seg[2]):
			base += (p.normalized() if gap > 0.01 else Vector3.BACK) * (float(seg[2]) - gap)
	return base


## Ellerden biri kol boyunu asiyorsa balyozun tamami omuzlara dogru kaydirilir.
## Bagimsiz olcum: ekrana cizilen kemikleri izleyen baglanti noktalarindan avuc ile sap arasi mesafe (metre).
## Godot duzeltilmis pozu yalnizca cizime verir; get_bone_global_pose burada isimize yaramaz.
func measure() -> float:
	var worst := 0.0
	var inv := get_skeleton().global_transform.affine_inverse()
	var origin := weapon.position
	var axis := weapon.basis.y.normalized()
	for side: String in ["l", "r"]:
		var hand: Transform3D = inv * _probes[side].global_transform
		var local: Basis = _frames[side]
		var palm := hand.origin + hand.basis * (local.x.normalized() * PALM_FORWARD + local.z.normalized() * PALM_DEPTH)
		var along := palm - origin
		worst = maxf(worst, (along - axis * along.dot(axis)).length())
	return worst

func _fit_reach(sk: Skeleton3D, base: Vector3) -> Vector3:
	for i in 4:
		var pull := Vector3.ZERO
		for side: String in ["l", "r"]:
			var ids: Array = _arms[side]
			var shoulder := sk.get_bone_global_pose(ids[0]).origin
			var reach := shoulder.distance_to(sk.get_bone_global_pose(ids[1]).origin) + sk.get_bone_global_pose(ids[1]).origin.distance_to(sk.get_bone_global_pose(ids[2]).origin) - REACH_MARGIN
			var grip := base + _dir * (GRIP_HIGH if (side == "l") != flip else GRIP_LOW)
			var over := shoulder.distance_to(grip) - reach - PALM_FORWARD # avuc bilekten ileridedir
			if over > 0.0:
				pull += (shoulder - grip).normalized() * over
		if pull == Vector3.ZERO:
			break
		base += pull
	return base


## Avucu sapa oturtur: basparmak balyoz kafasina bakar, parmaklar sapi sarar, kol bileğe kadar cozulur.
func _grip(side: String, grip: Vector3) -> void:
	var sk := get_skeleton()
	var ids: Array = _arms[side]
	var shoulder := sk.get_bone_global_pose(ids[0]).origin
	var along := grip - shoulder
	var f := (along - _dir * along.dot(_dir)).normalized()
	var local: Basis = _frames[side]
	var hand_sign := signf(local.x.cross(local.y).dot(local.z))
	var palm := f.cross(_dir).normalized() * hand_sign
	var world := Basis(f, _dir, palm)
	var wrist := grip - f * PALM_FORWARD - palm * PALM_DEPTH
	_arm(ids, wrist, Vector3(-1.0 if side == "r" else 1.0, -0.5, -0.25)) # dirsekler disari: sap kollarin arasindan gecer
	var hand := sk.get_bone_global_pose(ids[2])
	hand.basis = world * local.inverse()
	sk.set_bone_global_pose(ids[2], hand)
	var real := hand.origin + world * Vector3(PALM_FORWARD, 0, 0) + palm * PALM_DEPTH
	worst_gap = maxf(worst_gap, real.distance_to(grip))


## Iki kemikli kol cozumu: omuz sabit, bilek hedefe gider, dirsek pole yonunde kirilir.
func _arm(ids: Array, target: Vector3, pole: Vector3) -> void:
	var sk := get_skeleton()
	var up := sk.get_bone_global_pose(ids[0])
	var low := sk.get_bone_global_pose(ids[1])
	var hand := sk.get_bone_global_pose(ids[2])
	var a := up.origin
	var b := low.origin
	var c := hand.origin
	var l1 := a.distance_to(b)
	var l2 := b.distance_to(c)
	var dist := clampf(a.distance_to(target), absf(l1 - l2) + 0.02, l1 + l2 - 0.005)
	var d := (target - a).normalized()
	var goal := a + d * dist
	var along := (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist)
	var rise := sqrt(maxf(0.0, l1 * l1 - along * along))
	var bend := pole - d * pole.dot(d)
	var elbow := a + d * along + bend.normalized() * rise

	var q1 := Quaternion((b - a).normalized(), (elbow - a).normalized())
	up.basis = Basis(q1) * up.basis
	sk.set_bone_global_pose(ids[0], up)
	low.origin = elbow
	low.basis = Basis(q1) * low.basis
	var wrist := elbow + q1 * (c - b)
	var q2 := Quaternion((wrist - elbow).normalized(), (goal - elbow).normalized())
	low.basis = Basis(q2) * low.basis
	sk.set_bone_global_pose(ids[1], low)
	hand.origin = goal
	hand.basis = Basis(q2) * Basis(q1) * hand.basis
	sk.set_bone_global_pose(ids[2], hand)
