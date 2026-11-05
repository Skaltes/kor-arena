class_name GripTarget
extends SkeletonModifier3D
## Titan'in sol eli balyoz sapini AVUCUYLA sarar. Iki parca:
## 1) Bu duzenleyici (IK'dan once): sag elin O KAREDEKI pozundan sapin yerini ve yonunu bulur (BoneAttachment bir kare
##    geriden gelir). Sol eli, kivrik parmaklarin olusturdugu "tunel" sapin yonune gelecek sekilde en kisa yoldan dondurur
##    ve bilegi, tunelin ortasi tam sapin uzerine oturacak yere koyar (IK hedefi).
## 2) GripTarget.Hand (IK'dan sonra): IK kolu bukunce degisen el acisini bu donuse geri getirir.

var target: Node3D
var socket := Transform3D.IDENTITY # sag el kemiginden balyoz yuvasina (sapin alt ucu, Y = sap yonu)
var tunnel := Vector3.UP # sol elin kemik uzayinda parmak tunelinin yonu
var center := Vector3.ZERO # sol elin kemik uzayinda tunelin ortasi (bilekten)
var rot := Basis.IDENTITY # sol elin istenen dunya acisi (Hand uygular)
## Sol avucun sap uzerindeki yeri SABIT DEGIL (kullanici: "fotograflardaki gibi tutsun"): hareketin kendi sol eli sapin
## neresine en yakinsa avuc oraya oturur. Balyozu capraz tasirken eller acik (biri sapin ucunda, biri basa yakin),
## savurusta hareket elleri birlestirir. Sinirlar: sapin ucu ile basin alti arasi, sag avucla ust uste binmez.
var right_at := 0.4 # sag avucun sap uzerindeki yeri (sap altindan)
var low := 0.06 # sapin alt ucu payi
var high := 0.8 # balyoz basinin alti
var gap := 0.13 # iki avuc arasi en az
var along := 0.17 # bu karedeki yer (yumusak izlenir)
var _right := -1
var _left := -1
var _shoulder := -1
var _reach := 0.0


func _process_modification_with_delta(delta: float) -> void:
	var sk := get_skeleton()
	if sk == null or target == null:
		return
	if _right < 0:
		_right = sk.find_bone("hand_r")
		_left = sk.find_bone("hand_l")
	var base := sk.get_bone_global_pose(_right) * socket # iskelet uzayinda sapin alt ucu
	var axis := base.basis.y
	var hand := sk.get_bone_global_pose(_left)
	var palm := hand.origin + hand.basis.orthonormalized() * center # hareketin istedigi avuc ortasi
	if _reach <= 0.0: # kol boyu (omuz-dirsek-bilek) + avuc: hedef bunun otesindeyse el sapa yetisemez
		var up := sk.find_bone("upperarm_l")
		_shoulder = up
		var a := sk.get_bone_global_rest(up).origin
		var b := sk.get_bone_global_rest(sk.find_bone("lowerarm_l")).origin
		var c := sk.get_bone_global_rest(_left).origin
		_reach = (a.distance_to(b) + b.distance_to(c)) * 0.97
	var shoulder := sk.get_bone_global_pose(_shoulder).origin
	# sapin uzerinde hareketin sol eline en yakin, kolun yetistigi nokta (iki avuc ust uste binmez)
	var s := along
	var best := INF
	var k := low
	while k <= high:
		if absf(k - right_at) >= gap:
			var p := base.origin + axis * k
			var wrist_at := p - (palm - hand.origin)
			var cost := p.distance_to(palm) + maxf(0.0, wrist_at.distance_to(shoulder) - _reach) * 6.0
			if cost < best:
				best = cost
				s = k
		k += 0.02
	along = lerpf(along, s, 1.0 - exp(-14.0 * delta))
	var grip := base * Transform3D(Basis.IDENTITY, Vector3(0.0, along, 0.0))
	var shaft := grip.basis.y.normalized()
	var now := (hand.basis.orthonormalized() * tunnel).normalized()
	if now.dot(shaft) < 0.0:
		shaft = -shaft
	rot = Basis(Quaternion(now, shaft)) * hand.basis.orthonormalized()
	var wrist := grip.origin - rot * center
	target.global_transform = sk.global_transform * Transform3D(rot, wrist)


## IK'dan sonra: sol elin acisini sapa gore ayarlanmis aciya getirir (konum IK'dan).
class Hand:
	extends SkeletonModifier3D
	var source: GripTarget
	var _left := -1

	func _process_modification_with_delta(_delta: float) -> void:
		var sk := get_skeleton()
		if sk == null or source == null or influence <= 0.0:
			return
		if _left < 0:
			_left = sk.find_bone("hand_l")
		var pose := sk.get_bone_global_pose(_left)
		pose.basis = source.rot.scaled(pose.basis.get_scale())
		sk.set_bone_global_pose(_left, pose)
