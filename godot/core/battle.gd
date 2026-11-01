class_name Battle
extends RefCounted
## Savas motoru. Ekrani bilmez: girdi = komutlar, cikti = olaylar (yalnizca duz veri).
## Oyuncu da yapay zeka da command() cagirir; PvP'de komutlar agdan gelecek.

const STEP := 1.0 / 30.0
const FX_BITS: Array[String] = ["stun", "slow", "weak", "dot"]
const FIELD_HALF := 3.3 # sabit kameranin gordugu savas alaninin yarisi


class Ent:
	extends RefCounted
	var id: int
	var team: int
	var ch: Dictionary
	var s: Dictionary
	var pos := Vector2.ZERO # x, z duzlemi
	var face := 0.0
	var moving := false
	var hp := 0.0
	var shield := 0.0
	var shield_t := 0.0
	var target: Ent = null
	var swing := 0.0
	var atk_t := 0.4
	var lock := 0.0
	var gcd := 0.0 # yetenekler arasi ortak bekleme
	var cast_t := 0.0 # hazirlanan yetenegin kalan suresi
	var cast_id := ""
	var queued := "" # menzile girince atilacak yetenek
	var queued_t := 0.0
	var alive := true
	var cds := {}
	var fx: Array[Dictionary] = []
	var skills: Array[String] = []


var rng := RandomNumberGenerator.new()
var t := 0.0
var ents: Array[Ent] = []
var events: Array[Dictionary] = []
var over := false
var winner := -1
var _cmds: Array[Dictionary] = []
var _projs: Array[Dictionary] = []
var _delayed: Array[Dictionary] = []
var _follow: Array[Dictionary] = [] # cok vuruslu yeteneklerin sonraki darbeleri
var _next_proj := 0


## teams: iki takim, her uye {"ch": karakter, "stats": calc_stats sonucu}
func _init(teams: Array, seed_value: int) -> void:
	rng.seed = seed_value
	for ti in teams.size():
		var team: Array = teams[ti]
		for i in team.size():
			var e := Ent.new()
			e.id = ents.size()
			e.team = ti
			e.ch = team[i]["ch"]
			e.s = team[i]["stats"]
			# Yandan bakis: takimlar X ekseninde karsilikli durur
			e.pos = Vector2(-2.2 if ti == 0 else 2.2, (i - (team.size() - 1) / 2.0) * 2.5)
			e.face = PI / 2.0 if ti == 0 else -PI / 2.0
			e.hp = e.s["max_hp"]
			e.atk_t = 0.4 + i * 0.3
			for id: String in GameData.CLASSES[e.ch["cls"]]["skills"]:
				if int(GameData.SKILLS[id]["unlock"]) <= int(e.s["level"]):
					e.skills.append(id)
			ents.append(e)


## Birbirini hedefleyen karakterler bellekte kalmasin diye savas bitince cagrilir.
func release() -> void:
	for e in ents:
		e.target = null


## Canli oyun: ents'in tek satirlik ozeti. Sira degismez; karsi taraf restore() ile okur.
func snapshot() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for e in ents:
		var flags := 0
		for k in FX_BITS.size():
			if has_fx(e, FX_BITS[k]):
				flags |= 1 << k
		out.append_array([e.pos.x, e.pos.y, e.face, 1.0 if e.moving else 0.0, e.hp, e.shield, float(flags), e.gcd])
		for id in e.skills:
			out.append(float(e.cds.get(id, 0.0)))
	return out


## mirror: katilan oyuncu kendini solda gorsun diye X ekseni ters cevrilir.
func restore(data: PackedFloat32Array, mirror: bool) -> void:
	var i := 0
	for e in ents:
		e.pos = Vector2(-data[i] if mirror else data[i], data[i + 1])
		e.face = -data[i + 2] if mirror else data[i + 2]
		e.moving = data[i + 3] > 0.5
		e.hp = data[i + 4]
		e.alive = e.hp > 0.0
		e.shield = data[i + 5]
		e.fx.clear()
		var flags := int(data[i + 6])
		for k in FX_BITS.size():
			if flags & (1 << k):
				e.fx.append({"type": FX_BITS[k], "t": 1.0})
		e.gcd = data[i + 7]
		i += 8
		for id in e.skills:
			e.cds[id] = data[i]
			i += 1


func command(c: Dictionary) -> void:
	_cmds.append(c)


func enemies_of(e: Ent) -> Array[Ent]:
	return ents.filter(func(o: Ent) -> bool: return o.alive and o.team != e.team)


func has_fx(e: Ent, type: String) -> bool:
	return e.fx.any(func(f: Dictionary) -> bool: return f["type"] == type)


func can_cast(e: Ent, id: String) -> bool:
	var sk: Dictionary = GameData.SKILLS[id]
	if not e.alive or not e.skills.has(id) or e.lock > 0.0 or has_fx(e, "stun"):
		return false
	if float(e.cds.get(id, 0.0)) > 0.0 or e.gcd > 0.0 or e.cast_t > 0.0:
		return false
	if sk["kind"] == "self" or sk["kind"] == "aoe_self":
		return true
	return e.target != null and e.target.alive and e.pos.distance_to(e.target.pos) <= float(sk["range"])


func tick() -> void:
	if over:
		return
	t += STEP
	var cmds := _cmds
	_cmds = []
	for c in cmds:
		_apply(c)
	for e in ents:
		if e.alive:
			_tick_ent(e)
	_tick_projectiles()
	var waiting: Array[Dictionary] = []
	for d in _delayed:
		d["t"] -= STEP
		if d["t"] <= 0.0:
			if ents[d["src"]].alive:
				_land_delayed(d)
		else:
			waiting.append(d)
	waiting.append_array(_follow)
	_follow = []
	_delayed = waiting
	_check_end()


func _apply(c: Dictionary) -> void:
	var e := ents[c["ent"]]
	if not e.alive:
		return
	if c["type"] == "target":
		var o := ents[c["target"]]
		if o.alive and o.team != e.team:
			e.target = o
	elif c["type"] == "skill":
		if can_cast(e, c["skill"]):
			_cast(e, c["skill"])
		elif float(e.cds.get(c["skill"], 0.0)) <= 0.0 and e.gcd <= 0.4 and e.cast_t <= 0.4:
			e.queued = c["skill"] # yalnizca bitmek uzereyken basilan tus bekletilir
			e.queued_t = 0.5


func _tick_ent(e: Ent) -> void:
	for id: String in e.cds:
		e.cds[id] = maxf(0.0, e.cds[id] - STEP)
	e.lock = maxf(0.0, e.lock - STEP)
	e.gcd = maxf(0.0, e.gcd - STEP)
	if e.cast_t > 0.0:
		e.cast_t -= STEP
	if e.shield_t > 0.0:
		e.shield_t -= STEP
		if e.shield_t <= 0.0:
			e.shield = 0.0

	for f in e.fx:
		f["t"] -= STEP
		if f["type"] == "dot":
			f["tick"] -= STEP
			if f["tick"] <= 0.0:
				f["tick"] = 1.0
				_damage(ents[f["src"]], e, f["dps"], {"dot": true})
	e.fx = e.fx.filter(func(f: Dictionary) -> bool: return f["t"] > 0.0)
	if not e.alive:
		return

	if e.queued != "":
		e.queued_t -= STEP
		if can_cast(e, e.queued):
			_cast(e, e.queued)
			e.queued = ""
		elif e.queued_t <= 0.0:
			e.queued = ""
	e.moving = false
	if e.swing > 0.0: # vurus geciktirilir ki animasyonla ayni ana gelsin
		e.swing -= STEP
		if e.swing <= 0.0 and e.target != null and e.target.alive:
			_land_basic(e)
	if has_fx(e, "stun"):
		return
	if e.target == null or not e.target.alive:
		e.target = null
		var best := INF
		for o in enemies_of(e):
			var d := e.pos.distance_to(o.pos)
			if d < best:
				best = d
				e.target = o
	if e.target == null:
		return
	var to := e.target.pos - e.pos
	e.face = atan2(to.x, to.y)
	e.atk_t -= STEP
	if e.lock > 0.0:
		return
	var dist := to.length()
	var reach: float = e.s["range"]
	if dist > reach:
		var speed: float = e.s["speed"]
		for f in e.fx:
			if f["type"] == "slow":
				speed *= 1.0 - float(f["pct"])
		e.pos += to.normalized() * minf(speed * STEP, dist - reach + 0.05)
		e.moving = true
		e.pos.x = clampf(e.pos.x, -FIELD_HALF, FIELD_HALF)
	elif e.atk_t <= 0.0 and e.swing <= 0.0:
		e.atk_t = 1.0 / float(e.s["aspd"])
		e.swing = float(e.s["swing"])
		events.append({"t": "attack", "ent": e.id})


func _land_basic(e: Ent) -> void:
	if e.s["ranged"]:
		_spawn_proj(e, e.target, 16.0, "", 1.0, "bolt")
	elif e.pos.distance_to(e.target.pos) <= float(e.s["range"]) * 1.5:
		_hit(e, e.target, 1.0, {"basic": true})


func _spawn_proj(src: Ent, dst: Ent, speed: float, skill: String, mult: float, fx: String) -> void:
	_next_proj += 1
	_projs.append({"id": _next_proj, "src": src.id, "dst": dst.id, "pos": src.pos, "speed": speed, "skill": skill, "mult": mult})
	events.append({"t": "proj", "id": _next_proj, "src": src.id, "dst": dst.id, "speed": speed, "fx": fx})


func _buffed(e: Ent, key: String) -> float:
	var v: float = e.s[key]
	for f in e.fx:
		if f.has(key): # guclendirme ya da zayiflatma
			v *= 1.0 + float(f[key])
	return v


func _hit(src: Ent, dst: Ent, mult: float, opt: Dictionary) -> bool:
	if opt.get("basic", false) and rng.randf() * 100.0 < float(dst.s["dodge"]):
		events.append({"t": "miss", "ent": dst.id})
		return false
	var crit: bool = opt.get("force_crit", false) or rng.randf() * 100.0 < float(src.s["crit"])
	var dmg := _buffed(src, "atk") * mult * (0.92 + rng.randf() * 0.16) * (1.75 if crit else 1.0)
	var def := _buffed(dst, "def")
	dmg *= 1.0 - def / (def + 40.0 + float(dst.s["level"]) * 6.0)
	_damage(src, dst, dmg, {"crit": crit, "skill": opt.get("skill", "")})
	return true


func _damage(src: Ent, dst: Ent, amount: float, opt: Dictionary) -> void:
	if not dst.alive:
		return
	var left := maxf(1.0, roundf(amount))
	var shown := left
	if dst.shield > 0.0:
		var ab := minf(dst.shield, left)
		dst.shield -= ab
		left -= ab
	dst.hp -= left
	events.append({"t": "hit", "ent": dst.id, "src": src.id, "dmg": int(shown),
		"crit": opt.get("crit", false), "dot": opt.get("dot", false), "absorbed": left <= 0.0, "skill": opt.get("skill", "")})
	if dst.hp <= 0.0:
		dst.hp = 0.0
		dst.alive = false
		dst.moving = false
		events.append({"t": "death", "ent": dst.id})


func _cast(e: Ent, id: String) -> void:
	var sk: Dictionary = GameData.SKILLS[id]
	var tgt := e.target
	e.cds[id] = sk["cd"]
	var wind: float = sk.get("windup", 0.0) # hasar, animasyonda silah inince islenir
	var extra: Array = sk.get("hits", [0.0])
	e.lock = 0.55 + wind + float(extra[-1])
	e.gcd = GameData.GCD
	e.cast_t = wind
	e.cast_id = id
	e.swing = 0.0
	events.append({"t": "cast", "ent": e.id, "skill": id, "dur": wind})
	match sk["kind"]:
		"melee":
			_delayed.append({"t": wind, "src": e.id, "skill": id, "dst": tgt.id})
		"proj":
			_spawn_proj(e, tgt, sk["speed"], id, sk["mult"], sk["fx"])
		"aoe_self":
			_delayed.append({"t": wind, "src": e.id, "skill": id, "at": e.pos})
		"aoe_ground":
			_delayed.append({"t": sk["delay"], "src": e.id, "skill": id, "at": tgt.pos})
			events.append({"t": "telegraph", "pos": tgt.pos, "r": sk["radius"], "dur": sk["delay"]})
		"self":
			if sk.has("buff"):
				var f: Dictionary = sk["buff"].duplicate()
				f["type"] = "buff"
				f["t"] = f["dur"]
				e.fx.append(f)
			if sk.has("heal"):
				var amount := roundf(float(e.s["max_hp"]) * float(sk["heal"]))
				e.hp = minf(float(e.s["max_hp"]), e.hp + amount)
				events.append({"t": "heal", "ent": e.id, "amount": int(amount)})
			if sk.has("shield"):
				e.shield = float(e.s["atk"]) * float(sk["shield"])
				e.shield_t = sk["dur"]


func _land_delayed(d: Dictionary) -> void:
	var sk_all: Dictionary = GameData.SKILLS[d["skill"]]
	var times: Array = sk_all.get("hits", [0.0])
	var n: int = d.get("n", 0) + 1
	if n < times.size():
		var next := d.duplicate()
		next["n"] = n
		next["t"] = float(times[n]) - float(times[n - 1])
		_follow.append(next)
	var src := ents[d["src"]]
	if not d.has("dst"):
		_resolve_aoe(src, d["skill"], d["at"])
		return
	var sk: Dictionary = GameData.SKILLS[d["skill"]]
	var tgt := ents[d["dst"]]
	if tgt.alive and src.pos.distance_to(tgt.pos) <= float(sk["range"]) * 1.4:
		var mult: float = sk["mult"]
		if sk.has("combo") and has_fx(tgt, sk["combo"]["fx"]):
			mult *= 1.0 + float(sk["combo"]["bonus"])
			events.append({"t": "combo", "ent": tgt.id})
		if _hit(src, tgt, mult, {"force_crit": sk.get("force_crit", false), "skill": d["skill"]}):
			_riders(src, tgt, sk)


## Hazirlanan yetenek iptal olur, bekleme suresi yine de dolmaya devam eder: acele etmenin bedeli.
func _interrupt(_src: Ent, tgt: Ent) -> void:
	if tgt.cast_t <= 0.0:
		return
	var id := tgt.cast_id
	var kept: Array[Dictionary] = []
	for d in _delayed:
		if d["src"] != tgt.id:
			kept.append(d)
	_delayed = kept
	tgt.cast_t = 0.0
	tgt.lock = 0.0
	events.append({"t": "interrupt", "ent": tgt.id, "skill": id})


func _riders(src: Ent, tgt: Ent, sk: Dictionary) -> void:
	if sk.has("stun"):
		tgt.fx.append({"type": "stun", "t": sk["stun"]})
		tgt.swing = 0.0
		_interrupt(src, tgt)
	if sk.get("interrupt", false):
		_interrupt(src, tgt)
	if sk.has("slow"):
		tgt.fx.append({"type": "slow", "t": sk["slow"]["dur"], "pct": sk["slow"]["pct"]})
	if sk.has("weaken"):
		tgt.fx.append({"type": "weak", "t": sk["weaken"]["dur"], "def": sk["weaken"]["def"]})
	if sk.has("dot"):
		tgt.fx.append({"type": "dot", "t": sk["dot"]["dur"], "src": src.id, "tick": 1.0,
			"dps": _buffed(src, "atk") * float(sk["dot"]["mult"])})


func _resolve_aoe(src: Ent, id: String, at: Vector2) -> void:
	var sk: Dictionary = GameData.SKILLS[id]
	events.append({"t": "aoe", "pos": at, "r": sk["radius"], "skill": id})
	for o in enemies_of(src):
		var mult: float = sk["mult"]
		if sk.has("combo") and has_fx(o, sk["combo"]["fx"]):
			mult *= 1.0 + float(sk["combo"]["bonus"])
			events.append({"t": "combo", "ent": o.id})
		if o.pos.distance_to(at) <= float(sk["radius"]) and _hit(src, o, mult, {"skill": id}):
			_riders(src, o, sk)


func _tick_projectiles() -> void:
	var flying: Array[Dictionary] = []
	for p in _projs:
		var dst := ents[p["dst"]]
		var to: Vector2 = dst.pos - p["pos"]
		var step: float = float(p["speed"]) * STEP
		if to.length() <= step + 0.3:
			events.append({"t": "proj_end", "id": p["id"]})
			if dst.alive:
				_hit(ents[p["src"]], dst, p["mult"], {"basic": p["skill"] == ""})
		else:
			p["pos"] += to.normalized() * step
			flying.append(p)
	_projs = flying


func _check_end() -> void:
	var a := ents.any(func(e: Ent) -> bool: return e.alive and e.team == 0)
	var b := ents.any(func(e: Ent) -> bool: return e.alive and e.team == 1)
	if a and b:
		return
	over = true
	winner = 0 if a else 1
	events.append({"t": "end", "winner": winner})
