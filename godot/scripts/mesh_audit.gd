class_name MeshAudit
extends RefCounted
## Test araci: gorunen gercek model yuzeyinin (govde + zirh) silah hacmine girip girmedigini olcer.
## Her yuzey noktasi en etkili kemigine baglanir, silahlar parca parca hacim olarak denetlenir.

const WRIST := 0.13
const STEP := 5 # her 5. kose: yaklasik 3000 nokta
const SKIP := ["hand_", "index", "middle", "ring", "pinky", "thumb"] # silahi tutan el sayilmaz

var _view: CharacterView
var _pts: Array[Array] = [] # [baglanti, bone uzayinda nokta, kemik adi]
var _probes := {}
var _wrists: Array[BoneAttachment3D] = []


func _init(view: CharacterView) -> void:
	_view = view
	var sk: Skeleton3D = view._skeleton
	for bone: String in ["hand_r", "hand_l"]:
		var w := BoneAttachment3D.new()
		sk.add_child(w)
		w.bone_name = bone
		_wrists.append(w)
	for m: MeshInstance3D in view._meshes:
		if not m.visible or m.skin == null:
			continue
		var arrays := m.mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var per := bones.size() / verts.size()
		for i in range(0, verts.size(), STEP):
			var best := 0
			for k in per:
				if weights[i * per + k] > weights[i * per + best]:
					best = k
			var name_ := String(m.skin.get_bind_name(bones[i * per + best]))
			if name_ == "":
				name_ = sk.get_bone_name(m.skin.get_bind_bone(bones[i * per + best]))
			if SKIP.any(func(s: String) -> bool: return name_.begins_with(s)):
				continue
			var idx := sk.find_bone(name_)
			if idx < 0:
				continue
			if not _probes.has(name_):
				var a := BoneAttachment3D.new()
				sk.add_child(a)
				a.bone_name = name_
				_probes[name_] = a
			_pts.append([_probes[name_], sk.get_bone_global_rest(idx).affine_inverse() * verts[i], name_])


## [giren nokta sayisi, en derin mm, en cok giren kemik]
func check() -> Array:
	var world: Array[Vector3] = []
	world.resize(_pts.size())
	var wr: Vector3 = _wrists[0].global_position
	var wl: Vector3 = _wrists[1].global_position
	for i in _pts.size():
		world[i] = _pts[i][0].global_transform * _pts[i][1]
		if world[i].distance_to(wr) < WRIST or world[i].distance_to(wl) < WRIST:
			world[i] = Vector3(0, -50, 0) # silahi tutan bilek sapa degebilir
	var count := 0
	var deep := 0.0
	var parts := {}
	for w: Array in _view.audit_volumes():
		var to_local: Transform3D = w[0].global_transform.affine_inverse()
		for i in world.size():
			var d := _depth(to_local * world[i], w[1])
			if d > 0.0:
				count += 1
				deep = maxf(deep, d)
				parts[_pts[i][2]] = int(parts.get(_pts[i][2], 0)) + 1
	var top := ""
	var most := 0
	for p: String in parts:
		if int(parts[p]) > most:
			most = parts[p]
			top = p
	return [count, deep * 1000.0, top]


## Silah uzayindaki nokta hacmin ne kadar icinde (metre), disindaysa 0
static func _depth(p: Vector3, kind: String) -> float:
	var r := Vector2(p.x, p.z).length()
	match kind:
		"sledge":
			var best := 0.0
			if p.y > -0.2 and p.y < 1.05 and r < 0.03:
				best = 0.03 - r
			if absf(p.x) < 0.215 and absf(p.y - 1.0) < 0.09 and absf(p.z) < 0.1:
				best = maxf(best, minf(0.215 - absf(p.x), minf(0.09 - absf(p.y - 1.0), 0.1 - absf(p.z))))
			return best
		"shield":
			var disc := Vector2(p.x, p.z).length() # kalkan yuzeyi Y eksenine bakar
			if disc >= 0.33:
				return 0.0
			var half := 0.09 * sqrt(1.0 - disc * disc / 0.1089)
			return maxf(0.0, minf(half - absf(p.y), 0.33 - disc))
		"axe":
			var best := 0.0
			if p.y > -0.15 and p.y < 0.63 and r < 0.024:
				best = 0.024 - r
			if p.x > 0.0 and p.x < 0.25 and p.y > 0.36 and p.y < 0.7 and absf(p.z) < 0.02:
				best = maxf(best, 0.02 - absf(p.z))
			return best
		"sword":
			if p.y > -0.12 and p.y < 0.85 and absf(p.x) < 0.04 and absf(p.z) < 0.016:
				return 0.016 - absf(p.z)
	return 0.0
