class_name Brain
extends RefCounted
## Rakip yapay zekasi: oyuncuyla ayni komutlari gonderir, yalnizca bekleme surelerine bakar. skill 0-1 arasi tepki ve secim kalitesidir.

const PARRY_SKILL := 0.7
const PARRY_BASIC := 0.2
const HEAVY_WINDUP := 1.1

var _e: Battle.Ent
var _skill: float
var _rng: RandomNumberGenerator
var _wait := 0.8
var _judged := false # gelen darbe icin parry karari bir kez verilir


func _init(ent: Battle.Ent, skill: float, rng: RandomNumberGenerator) -> void:
	_e = ent
	_skill = skill
	_rng = rng


func update(b: Battle, dt: float) -> void:
	_try_parry(b)
	_wait -= dt
	if _wait > 0.0:
		return
	_wait = 0.25 + (1.0 - _skill) * 0.9
	if not _e.alive:
		return
	var foe := _e.target
	if foe != null and (foe.guard_t > 0.0 or foe.raise_t > 0.0) and _rng.randf() < _skill:
		return # usta rakip kalkmis sipere vurmaz, inmesini bekler
	if foe != null and _rng.randf() < _skill and _punish(b, foe):
		return
	for i in range(_e.skills.size() - 1, -1, -1):
		var id := _e.skills[i]
		if not b.can_cast(_e, id) or _rng.randf() > 0.4 + _skill * 0.6:
			continue
		if _good(b, id):
			b.command({"ent": _e.id, "type": "skill", "skill": id})
			return


## Insan gibi: darbe inmeden hemen once hamle yapar, bazen kacirir. Yetenekleri normal saldiridan daha cok izler.
func _try_parry(b: Battle) -> void:
	var foe := _e.target
	if foe == null or not _e.alive:
		return
	var left := foe.cast_t if foe.cast_t > 0.0 else foe.swing
	if left <= 0.0 or left > 0.3:
		_judged = false
		return
	if _judged:
		return
	_judged = true
	if _rng.randf() > _skill * (PARRY_SKILL if foe.cast_t > 0.0 else PARRY_BASIC):
		return
	for id in _e.skills:
		if GameData.SKILLS[id]["kind"] == "guard" and b.can_cast(_e, id):
			b.command({"ent": _e.id, "type": "skill", "skill": id})


## Rakip sersem/sarsik/donmus (savusturma, kesme sonrasi): kalan surede yetisecek en agir darbe secilir.
func _punish(b: Battle, foe: Battle.Ent) -> bool:
	var left := 0.0
	for f in foe.fx:
		if f["type"] in ["stun", "reel", "freeze"]:
			left = maxf(left, float(f["t"]))
	if left <= 0.0:
		return false
	var best := ""
	var best_mult := 0.0
	for id in _e.skills:
		var sk: Dictionary = GameData.SKILLS[id]
		if not sk.has("mult") or not b.can_cast(_e, id):
			continue
		if float(sk.get("windup", 0.0)) > left + 0.15:
			continue
		if float(sk["mult"]) > best_mult:
			best = id
			best_mult = float(sk["mult"])
	if best == "":
		return false
	b.command({"ent": _e.id, "type": "skill", "skill": best})
	return true


## Agir yetenek: rakibin hazir hizli kesmesi varsa bozulma riski yuksektir.
func _foe_can_cut(b: Battle, foe: Battle.Ent) -> bool:
	for id in foe.skills:
		var sk: Dictionary = GameData.SKILLS[id]
		if (sk.has("stun") or sk.get("interrupt", false) or float(sk.get("windup", 9.0)) <= 0.5) and float(foe.cds.get(id, 0.0)) <= 0.0:
			return true
	return false


func _good(b: Battle, id: String) -> bool:
	var sk: Dictionary = GameData.SKILLS[id]
	if sk["kind"] == "guard":
		return false # siper yalnizca _try_parry ile acilir
	var health := _e.hp / float(_e.s["max_hp"])
	var foe := _e.target
	if sk.get("grab", false): # kavrama yalnizca hazirlanan rakibi yakalar
		return foe != null and foe.cast_t > 0.3 and _rng.randf() < _skill * 0.6 # insan gibi: her hazirligi yakalayamaz
	if foe != null and foe.cast_t > 0.25 and (sk.has("stun") or sk.get("interrupt", false)):
		return _rng.randf() < _skill # hazirlik goren usta rakip keser
	if foe != null and foe.cast_t > 0.0 and sk.has("mult") and float(sk.get("windup", 9.0)) < foe.cast_t:
		return _rng.randf() < _skill # hazirligi goren once vurup afallatir
	if float(sk.get("windup", 0.0)) >= HEAVY_WINDUP and foe != null:
		if b.stopped(foe):
			return true # agir yetenegi rakip acik verince kullanir
		if _foe_can_cut(b, foe) and _rng.randf() < _skill:
			return false # rakibin kesmesi hazirken uzun hazirliga girmez
		return _rng.randf() < 0.2
	if sk["kind"] == "aoe_self":
		var radius: float = sk["radius"]
		return b.enemies_of(_e).any(func(o: Battle.Ent) -> bool: return _e.pos.distance_to(o.pos) <= radius)
	if sk.has("heal"):
		return health < 0.6
	if sk.has("slow"):
		return not b.has_fx(_e.target, "slow")
	if sk.has("stun"):
		return not b.has_fx(_e.target, "stun")
	if sk.has("dot"):
		return not b.has_fx(_e.target, "dot")
	return true
