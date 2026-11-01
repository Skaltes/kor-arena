class_name Brain
extends RefCounted
## Rakip yapay zekasi: oyuncuyla ayni komutlari gonderir, yalnizca bekleme surelerine bakar. skill 0-1 arasi tepki ve secim kalitesidir.

var _e: Battle.Ent
var _skill: float
var _rng: RandomNumberGenerator
var _wait := 0.8


func _init(ent: Battle.Ent, skill: float, rng: RandomNumberGenerator) -> void:
	_e = ent
	_skill = skill
	_rng = rng


func update(b: Battle, dt: float) -> void:
	_wait -= dt
	if _wait > 0.0:
		return
	_wait = 0.25 + (1.0 - _skill) * 0.9
	if not _e.alive:
		return
	for i in range(_e.skills.size() - 1, -1, -1):
		var id := _e.skills[i]
		if not b.can_cast(_e, id) or _rng.randf() > 0.4 + _skill * 0.6:
			continue
		if _good(b, id):
			b.command({"ent": _e.id, "type": "skill", "skill": id})
			return


func _good(b: Battle, id: String) -> bool:
	var sk: Dictionary = GameData.SKILLS[id]
	var health := _e.hp / float(_e.s["max_hp"])
	var foe := _e.target
	if foe != null and foe.cast_t > 0.25 and (sk.has("stun") or sk.get("interrupt", false)):
		return _rng.randf() < _skill # hazirlik goren usta rakip keser
	if sk.has("combo") and foe != null and not b.has_fx(foe, sk["combo"]["fx"]):
		return _rng.randf() < 0.25 # kombo hazir degilse agir yetenegi genelde saklar
	if sk["kind"] == "aoe_self":
		var radius: float = sk["radius"]
		return b.enemies_of(_e).any(func(o: Battle.Ent) -> bool: return _e.pos.distance_to(o.pos) <= radius)
	if sk.has("weaken"):
		return not b.has_fx(_e.target, "weak")
	if sk.has("buff") and id == "iron":
		return health < 0.75
	if sk.has("heal"):
		return health < 0.6
	if sk.has("slow"):
		return not b.has_fx(_e.target, "slow")
	if sk.has("stun"):
		return not b.has_fx(_e.target, "stun")
	if sk.has("dot"):
		return not b.has_fx(_e.target, "dot")
	return true
