class_name FootLock
extends SkeletonModifier3D
## Ayak kilidi (kullanici istegi: ayaklar kayiyor, yere batiyor, bir karede sicriyordu). Hazir hareketler yerinde oynatilip
## karakter oyun tarafindan tasindigi icin yere basan ayak yerde kayiyordu (olculen: yetenek basina 0,5-2,4 m).
## Her bacak icin:
## - Taban yere degdiginde (LOCK_AT altinda) ayagin dunyadaki yeri kilitlenir; hareket ayagi kaldirana (RELEASE_AT ustu)
##   ya da gercek ayak kilitten REACH kadar uzaklasana kadar ayak orada kalir, diz ve kalca TwoBoneIK3D ile bukulur.
## - Taban hicbir karede yerin altina inmez (yalniz o ayak kalkar, govde zipzip olmaz).
## - Kilit cozulunce ayak hareketin yerine yumusakca kavusur (bir karede sicramaz).
## Siralama: durus/yay fizigi -> FootLock -> iki bacak IK -> FootLock.After (ayak acisi geri) -> FootPlant (taban duz).

const LOCK_AT := 0.025 # taban yerden bu kadar yuksekte ya da asagidaysa ayak basmis sayilir (metre)
const RELEASE_AT := 0.07 # bu kadar kalkinca kilit cozulur
const REACH := 0.32 # hareketin ayagi kilitten bu kadar uzaklasirsa ayak adim atar (bacak gerilmesin)
const BLEND := 18.0 # kilit cozulunce hareketin yerine kavusma hizi

var view: Node3D # zemin yuksekligi = view.global_position.y
var sole := [0.0, 0.0] # taban payi: [parmak kemiginden, bilekten] (metre)
var enabled := true
var legs: Array[Dictionary] = []


## side: "l"/"r". ik: o bacagin TwoBoneIK3D'si; target/pole: IK'nin hedef ve diz yonu dugumleri.
func add_leg(side: String, ik: SkeletonModifier3D, target: Node3D, pole: Node3D) -> void:
	legs.append({"side": side, "ik": ik, "target": target, "pole": pole, "locked": false, "lock": Vector3.ZERO,
		"cur": Vector3.INF, "basis": Basis.IDENTITY, "foot": -1, "ball": -1, "calf": -1, "thigh": -1, "named": false})


## Kemik adlari iskelet hazir olunca verilir (CharacterView her kare cagirir).
func prepare() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for leg in legs:
		if leg["named"]:
			continue
		var ik: SkeletonModifier3D = leg["ik"]
		if ik.get_skeleton() == null:
			continue
		var s: String = leg["side"]
		ik.call("set_root_bone_name", 0, "thigh_" + s)
		ik.call("set_middle_bone_name", 0, "calf_" + s)
		ik.call("set_end_bone_name", 0, "foot_" + s)
		leg["foot"] = sk.find_bone("foot_" + s)
		leg["ball"] = sk.find_bone("ball_" + s)
		leg["calf"] = sk.find_bone("calf_" + s)
		leg["thigh"] = sk.find_bone("thigh_" + s)
		leg["named"] = leg["foot"] >= 0 and leg["calf"] >= 0 and leg["thigh"] >= 0


func _process_modification_with_delta(delta: float) -> void:
	var sk := get_skeleton()
	if sk == null or view == null:
		return
	var gx := sk.global_transform
	var ground := view.global_position.y
	for leg in legs:
		var ik: SkeletonModifier3D = leg["ik"]
		if not leg["named"]:
			ik.influence = 0.0
			continue
		var fp := sk.get_bone_global_pose(leg["foot"])
		var anim := gx * fp.origin
		leg["basis"] = fp.basis
		var sole_y := anim.y - float(sole[1])
		if leg["ball"] >= 0:
			sole_y = minf(sole_y, (gx * sk.get_bone_global_pose(leg["ball"]).origin).y - float(sole[0]))
		sole_y -= ground
		if not enabled:
			leg["locked"] = false
			leg["cur"] = Vector3.INF
			ik.influence = move_toward(ik.influence, 0.0, delta * 8.0)
			continue
		var flat := Vector2(anim.x - leg["lock"].x, anim.z - leg["lock"].z).length()
		if leg["locked"] and (sole_y > RELEASE_AT or flat > REACH):
			leg["locked"] = false
		elif not leg["locked"] and sole_y < LOCK_AT:
			leg["locked"] = true
			leg["lock"] = anim if leg["cur"] == Vector3.INF else leg["cur"]
		var want := anim
		if leg["locked"]:
			want.x = leg["lock"].x
			want.z = leg["lock"].z
		want.y += maxf(0.0, -sole_y) # taban yerin altina inmez
		if leg["cur"] != Vector3.INF and leg["cur"].distance_to(want) > 0.6: # karakter isinlandi (raunt basi, yeniden dogma)
			leg["cur"] = Vector3.INF
			leg["locked"] = false
			want = anim
		if leg["cur"] == Vector3.INF or leg["locked"]:
			leg["cur"] = want
		else:
			var k := 1.0 - exp(-BLEND * delta)
			leg["cur"] = leg["cur"].lerp(want, k)
		var cur: Vector3 = leg["cur"]
		leg["target"].global_transform = Transform3D(gx.basis * fp.basis.orthonormalized(), cur)
		# diz, hareketteki dizin baktigi yone bukulur
		var knee := gx * sk.get_bone_global_pose(leg["calf"]).origin
		var hip := gx * sk.get_bone_global_pose(leg["thigh"]).origin
		var out := knee - (hip + anim) * 0.5
		if out.length() < 0.02:
			out = gx.basis.z
		leg["pole"].global_position = knee + out.normalized() * 0.6
		ik.influence = move_toward(ik.influence, 1.0, delta * 8.0)


## IK'dan sonra: ayagin acisi hareketteki aciya geri doner (konum IK'dan). FootPlant ardindan tabani duzler.
class After:
	extends SkeletonModifier3D
	var source: FootLock

	func _process_modification_with_delta(_delta: float) -> void:
		var sk := get_skeleton()
		if sk == null or source == null or not source.enabled:
			return
		for leg in source.legs:
			if not leg["named"]:
				continue
			var pose := sk.get_bone_global_pose(leg["foot"])
			pose.basis = leg["basis"]
			sk.set_bone_global_pose(leg["foot"], pose)
