class_name Battle
extends RefCounted
## Savas motoru. Ekrani bilmez: girdi = komutlar, cikti = olaylar (yalnizca duz veri).
## Oyuncu da yapay zeka da command() cagirir; PvP'de komutlar agdan gelecek.

const STEP := 1.0 / 30.0
const OPEN_WAIT := 1.2 # mac basinda menzile girince ilk duz vurustan once beklenen sure (kullanici istegi)
# "sap" artik hicbir yetenekte yok; bit sirasi ag paketiyle uyumlu kalsin diye listede durur.
const FX_BITS: Array[String] = ["stun", "slow", "dot", "reel", "buff", "sap", "freeze", "down"]
const MAX_GRACE := 0.45 # katilan oyuncu icin en cok bu kadar darbe bekletilir
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
	var basic_t := 0.0 # duz vurus hareketi (hazirlik + toparlanma) bitene kadar yetenek kullanilamaz
	var open_t := OPEN_WAIT # ilk duz vurustan once menzilde beklenecek sure; yetenek kullanilinca biter
	var atk_t := 0.4
	var lock := 0.0
	var guard_t := 0.0 # siper: bu surede gelen tum hasar engellenir
	var parry_t := 0.0 # siperin ilk ani: gelen saldiri yarida kesilir
	var raise_t := 0.0 # siper kalkiyor: bitince siper baslar
	var raise_id := ""
	var grace := 0.0 # ag gecikmesi: bu oyuncuya inen darbe bu kadar bekletilir ki tusu zamaninda sayilsin
	var gcd := 0.0 # yetenekler arasi ortak bekleme (= son yetenegin hareket suresi)
	var gcd_max := 1.0 # gostergenin dolulugu icin
	var cast_t := 0.0 # hazirlanan yetenegin kalan suresi
	var cast_id := ""
	var slide := Vector2.ZERO # itmeden kalan yol
	var queued := "" # menzile girince atilacak yetenek
	var queued_t := 0.0
	var combo_n := 0 # ard arda yedigi isabet (yere dusme icin)
	var combo_t := -9.0
	var alive := true
	var cds := {}
	var fx: Array[Dictionary] = []
	var skills: Array[String] = []


var rng := RandomNumberGenerator.new()
var t := 0.0
var ents: Array[Ent] = []
var events: Array[Dictionary] = []
var over := false
var immortal := false # Test Modu: can bitince dolar, mac bitmez
var winner := -1
## Raunt: iki raunt kazanan maci alir (kullanici istegi). Raunt arasinda ve geri sayimda karakterler hareket etmez.
const ROUNDS_TO_WIN := 2
const ROUND_GAP := 3.0 # raunt bitince: olum dususu ve sonuc yazisi
const COUNTDOWN := 3.0 # "3-2-1 SAVAS"
var wins: Array[int] = [0, 0]
var round_no := 1
var countdown := true # Test Modunda geri sayim yok
var pause_t := 0.0 # geri sayim
var gap_t := 0.0 # raunt arasi
var _spawn: Array = [] # [konum, bakis] her karakterin raunt basi yeri
var _cmds: Array[Dictionary] = []
var _projs: Array[Dictionary] = []
var _delayed: Array[Dictionary] = []
var _follow: Array[Dictionary] = [] # cok vuruslu yeteneklerin sonraki darbeleri
var _next_proj := 0
var _last_dmg := 0.0


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
			_spawn.append([e.pos, e.face])


## Raunt basi. count: geri sayim olsun mu (Test Modunda yok).
func start_round(count := true) -> void:
	countdown = count
	pause_t = COUNTDOWN if count else 0.0
	events.append({"t": "round_start", "round": round_no, "count": pause_t, "wins": wins.duplicate()})


## Yeni raunt: herkes tam canla, bekleme ve etkiler sifir, baslangic yerinde.
func _reset_round() -> void:
	for e in ents:
		e.pos = _spawn[e.id][0]
		e.face = _spawn[e.id][1]
		e.hp = e.s["max_hp"]
		e.alive = true
		e.moving = false
		e.shield = 0.0
		e.shield_t = 0.0
		e.swing = 0.0
		e.basic_t = 0.0
		e.open_t = OPEN_WAIT
		e.atk_t = 0.4
		e.lock = 0.0
		e.guard_t = 0.0
		e.parry_t = 0.0
		e.raise_t = 0.0
		e.gcd = 0.0
		e.cast_t = 0.0
		e.cast_id = ""
		e.slide = Vector2.ZERO
		e.queued = ""
		e.cds.clear()
		e.combo_n = 0
		e.fx.clear()
	_delayed.clear()
	_follow.clear()
	_projs.clear()


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


## Sersemlik, donma, parry sarsintisi ve yere dusme ayni seyi durdurur.
func stopped(e: Ent) -> bool:
	return has_fx(e, "stun") or has_fx(e, "reel") or has_fx(e, "freeze") or has_fx(e, "down")


func _busy(e: Ent) -> bool:
	return e.cast_t > 0.0 or (_delayed + _follow).any(func(d: Dictionary) -> bool: return d["src"] == e.id and not d.has("basic") and not d.get("off", false))


func can_cast(e: Ent, id: String) -> bool:
	var sk: Dictionary = GameData.SKILLS[id]
	if e.basic_t > 0.0: # duz vurus + yetenek kombosu yok (kullanici karari), siper de beklenir
		return false
	if sk["kind"] == "guard": # ortak beklemeye takilmaz, toparlanmayi yarida keser
		return e.alive and e.skills.has(id) and float(e.cds.get(id, 0.0)) <= 0.0 and e.guard_t <= 0.0 and e.raise_t <= 0.0 and not stopped(e) and not _busy(e)
	if not e.alive or not e.skills.has(id) or e.lock > 0.0 or stopped(e):
		return false
	if float(e.cds.get(id, 0.0)) > 0.0 or e.gcd > 0.0 or e.cast_t > 0.0:
		return false
	if sk["kind"] == "self" or sk["kind"] == "aoe_self":
		return true
	return e.target != null and e.target.alive and e.pos.distance_to(e.target.pos) <= float(sk["range"])


## Yalnizca bitmek uzereyken basilan tus bekletilir.
func can_queue(e: Ent, id: String) -> bool:
	return float(e.cds.get(id, 0.0)) <= 0.0 and e.gcd <= 0.4 and e.cast_t <= 0.4


func tick() -> void:
	if over:
		return
	t += STEP
	if gap_t > 0.0: # raunt arasi: yeni raunt hazirlanir
		gap_t -= STEP
		_cmds = []
		if gap_t <= 0.0:
			_reset_round()
			start_round(countdown)
		return
	if pause_t > 0.0: # geri sayim: basilan tuslar sayilmaz
		pause_t -= STEP
		_cmds = []
		return
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
		if d.get("off", false):
			continue
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
		elif can_queue(e, c["skill"]):
			e.queued = c["skill"]
			# duz vurus ya da onceki hareket sirasinda basilan tus, o bitince atilir (eskiden kilit 0,5 sn'yi asinca tus siliniyordu)
			e.queued_t = 0.5 + maxf(e.basic_t, e.lock)
			events.append({"t": "queued", "ent": e.id, "skill": c["skill"]}) # katilan oyuncu tahmini hareketini birakir
		else:
			events.append({"t": "refused", "ent": e.id, "skill": c["skill"]})


func _tick_ent(e: Ent) -> void:
	for id: String in e.cds:
		e.cds[id] = maxf(0.0, e.cds[id] - STEP)
	e.lock = maxf(0.0, e.lock - STEP)
	e.basic_t = maxf(0.0, e.basic_t - STEP)
	e.gcd = maxf(0.0, e.gcd - STEP)
	if e.cast_t > 0.0:
		e.cast_t -= STEP
	e.guard_t = maxf(0.0, e.guard_t - STEP)
	e.parry_t = maxf(0.0, e.parry_t - STEP)
	if e.raise_t > 0.0:
		e.raise_t -= STEP
		if e.raise_t <= 0.0:
			_raise_guard(e)
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
				if e.guard_t <= 0.0:
					_damage(ents[f["src"]], e, f["dps"], {"dot": true})
	e.fx = e.fx.filter(func(f: Dictionary) -> bool: return f["t"] > 0.0)
	if not e.alive:
		return
	if e.slide != Vector2.ZERO: # itme bir anda degil, kayarak olur
		var step := e.slide.limit_length(GameData.PUSH_SPEED * STEP)
		e.slide -= step
		e.pos += step
		e.pos.x = clampf(e.pos.x, -FIELD_HALF, FIELD_HALF)

	if e.queued != "":
		e.queued_t -= STEP
		if can_cast(e, e.queued):
			_cast(e, e.queued)
			e.queued = ""
		elif e.queued_t <= 0.0:
			events.append({"t": "refused", "ent": e.id, "skill": e.queued})
			e.queued = ""
	e.moving = false
	if e.swing > 0.0: # vurus geciktirilir ki animasyonla ayni ana gelsin
		e.swing -= STEP
		if e.swing <= 0.0 and e.target != null and e.target.alive:
			_land_basic(e)
	if stopped(e):
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
	elif e.open_t > 0.0: # macin ilk temasi: oyuncu once yetenek atabilsin diye duz vurus biraz bekler
		e.open_t -= STEP
	elif e.atk_t <= 0.0 and e.swing <= 0.0 and e.queued == "": # bekleyen yetenek tusu varsa duz vurus baslamaz
		e.atk_t = 1.0 / float(e.s["aspd"])
		e.swing = float(e.s["swing"])
		e.basic_t = e.swing + float(e.s["recover"]) # vurus + dogal hizda toparlanma (kullanici karari)
		events.append({"t": "attack", "ent": e.id})


func _land_basic(e: Ent) -> void:
	if e.s["ranged"]:
		_spawn_proj(e, e.target, 16.0, "", 1.0, "bolt")
	elif e.target.grace > 0.0:
		_follow.append({"t": e.target.grace, "src": e.id, "dst": e.target.id, "basic": true})
	else:
		_basic_strike(e, e.target)


func _basic_strike(e: Ent, dst: Ent) -> void:
	if dst.alive and e.pos.distance_to(dst.pos) <= float(e.s["range"]) * 1.5 and not _guarded(e, dst, false):
		_hit(e, dst, 1.0, {"basic": true})


func _guard_skill(e: Ent) -> Dictionary:
	for id: String in e.skills:
		if GameData.SKILLS[id]["kind"] == "guard":
			return GameData.SKILLS[id]
	return {}


## Siper gelen darbeyi durdurur; ilk andaysa saldiriyi da yarida keser.
## Karsi saldiri siperi (Buz Kolu) butun suresince her darbeye karsilik verir, saldirani dondurur (kullanici istegi).
func _guarded(src: Ent, dst: Ent, _skill := true) -> bool:
	var gsk := _guard_skill(dst)
	# Buz Kolu: buz kalkani tusa basildigi an gorunur; kalkis anindaki (raise) darbe de karsilanir (gorunen = gecerli)
	var counter: bool = gsk.get("counter", false) and dst.raise_id == "icearm" and dst.raise_t > 0.0
	if dst.guard_t <= 0.0 and not counter:
		return false
	if dst.parry_t <= 0.0 and not counter: # Buz Kolu butun suresince her darbeye (duz vurus dahil) karsilik verir
		events.append({"t": "blocked", "ent": dst.id, "src": src.id})
		return true
	for d: Dictionary in _delayed + _follow:
		if d["src"] == src.id:
			d["off"] = true
	src.swing = 0.0
	src.basic_t = 0.0
	src.cast_t = 0.0
	src.lock = 0.0
	src.queued = ""
	if gsk.has("freeze"):
		src.fx.append({"type": "freeze", "t": gsk["freeze"]})
	else:
		src.fx.append({"type": "reel", "t": gsk.get("reel", GameData.PARRY_REEL)})
	dst.guard_t = 0.0 # siper biter, oyuncu istedigi yetenegi secer
	dst.raise_t = 0.0
	dst.parry_t = 0.0
	dst.lock = 0.0
	events.append({"t": "parry", "ent": dst.id, "src": src.id, "freeze": gsk.has("freeze")})
	return true


func _spawn_proj(src: Ent, dst: Ent, speed: float, skill: String, mult: float, fx: String) -> void:
	_next_proj += 1
	_projs.append({"id": _next_proj, "src": src.id, "dst": dst.id, "pos": src.pos, "speed": speed, "skill": skill, "mult": mult})
	events.append({"t": "proj", "id": _next_proj, "src": src.id, "dst": dst.id, "speed": speed, "fx": fx})


## Yere dusme (kullanici istegi, Doom Forge gibi): "down" yetenegi (en agir darbeler) ya da rakip araya vurus
## sokamadan yenen KNOCK_COMBO'uncu isabet rakibi yere yatirir; yerdeyken hareket edemez, sonra kalkar.
func _knockdown_check(src: Ent, dst: Ent, skill: String) -> void:
	if not dst.alive or has_fx(dst, "down"):
		return
	dst.combo_n = dst.combo_n + 1 if t - dst.combo_t < GameData.COMBO_WINDOW else 1
	dst.combo_t = t
	src.combo_n = 0 # vuran kendi komboyu yemiyor
	var heavy: bool = skill != "" and GameData.SKILLS[skill].get("down", false)
	if not heavy and dst.combo_n < GameData.KNOCK_COMBO:
		return
	dst.combo_n = 0
	_interrupt(src, dst, true)
	for d: Dictionary in _delayed + _follow:
		if d["src"] == dst.id:
			d["off"] = true
	dst.swing = 0.0
	dst.basic_t = 0.0
	dst.lock = 0.0
	dst.queued = ""
	dst.raise_t = 0.0
	dst.slide = (dst.pos - src.pos).normalized() * GameData.KNOCK_PUSH
	dst.fx.append({"type": "down", "t": GameData.DOWN_TIME})
	events.append({"t": "down", "ent": dst.id, "src": src.id})


func _buffed(e: Ent, key: String) -> float:
	var v: float = e.s[key]
	for f in e.fx:
		if f.has(key): # guclendirme ya da zayiflatma
			v *= 1.0 + float(f[key])
	return v


## Sans eseri kacma YOK (kullanici karari): vurus menzilde ve siperle karsilanmadiysa hep isabet eder.
func _hit(src: Ent, dst: Ent, mult: float, opt: Dictionary) -> bool:
	# KRITIK ve hasar oynamasi YOK (kullanici karari: "her skill ayni vursun, iyi oynayan kazansin"): ayni vurus hep ayni hasar
	var crit := false
	var dmg := _buffed(src, "atk") * mult
	var def := _buffed(dst, "def")
	dmg *= 1.0 - def / (def + 40.0 + float(dst.s["level"]) * 6.0)
	_last_dmg = dmg
	_damage(src, dst, dmg, {"crit": crit, "skill": opt.get("skill", "")})
	_knockdown_check(src, dst, opt.get("skill", ""))
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
	if dst.hp <= 0.0 and immortal:
		dst.hp = float(dst.s["max_hp"])
	if dst.hp <= 0.0:
		dst.hp = 0.0
		dst.alive = false
		dst.moving = false
		events.append({"t": "death", "ent": dst.id})


func _cast(e: Ent, id: String) -> void:
	var sk: Dictionary = GameData.SKILLS[id]
	var tgt := e.target
	e.open_t = 0.0
	e.cds[id] = sk["cd"]
	var wind: float = sk.get("windup", 0.0) # hasar, animasyonda silah inince islenir
	if sk["kind"] == "guard": # silah/kol once kalkar, siper ondan sonra baslar
		e.raise_t = wind
		e.raise_id = id
		e.lock = wind + float(sk["dur"])
		e.atk_t = maxf(e.atk_t, e.lock + GameData.SKILL_REST)
		e.swing = 0.0
		e.basic_t = 0.0
		events.append({"t": "cast", "ent": e.id, "skill": id, "dur": wind})
		if wind <= 0.0:
			_raise_guard(e)
		return
	# hareket suresi: "after" yalniz Ezici Hamlede kisa (kullanici karari: rakibi bozunca hemen cezalandirabilmeli)
	e.lock = GameData.skill_lock(id)
	e.gcd = e.lock # hareket bitince siradaki yetenek hemen kullanilabilir
	e.gcd_max = e.gcd
	e.atk_t = maxf(e.atk_t, maxf(e.lock + GameData.SKILL_REST, e.gcd + GameData.BASIC_GRACE)) # yetenekten sonra duz vurus araya girmez: once siradaki yetenek basilabilir
	e.cast_t = wind
	e.cast_id = id
	e.swing = 0.0
	e.basic_t = 0.0
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
		"self": # etki hazirlik bitince gelir; hazirlikta vurulursa bozulur
			if wind > 0.0:
				_delayed.append({"t": wind, "src": e.id, "skill": id, "self": true})
			else:
				_apply_self(e, sk)


func _raise_guard(e: Ent) -> void:
	var sk: Dictionary = GameData.SKILLS[e.raise_id]
	e.raise_t = 0.0
	e.guard_t = sk["dur"]
	# gecikmeli oyuncuya savusturma ani gecikmesiyle orantili uzar: az gecikmede tam zamanlama, cok gecikmede daha kolay (kullanici karari)
	e.parry_t = sk["dur"] if sk.get("counter", false) else GameData.PARRY_TIME + e.grace * GameData.PARRY_LAG


func _apply_self(e: Ent, sk: Dictionary) -> void:
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
	var src := ents[d["src"]]
	if d.has("self"):
		_apply_self(src, GameData.SKILLS[d["skill"]])
		return
	# gecikme telafisiyle bekletilen darbe: oyuncu sipere basmis ve kalkan kalkiyorsa onu da bekler
	if d.has("dst") and (d.has("basic") or d.get("late", false)) and ents[d["dst"]].raise_t > 0.0 and not d.get("raised", false):
		var wait_up := d.duplicate()
		wait_up["raised"] = true
		wait_up["t"] = ents[d["dst"]].raise_t
		_follow.append(wait_up)
		return
	if d.has("basic"):
		_basic_strike(src, ents[d["dst"]])
		return
	var wait := _grace_for(d)
	if wait > 0.0 and not d.get("late", false): # gecikme: darbe katilan oyuncunun tusunu bekler
		var held := d.duplicate()
		held["late"] = true
		held["t"] = wait
		_follow.append(held)
		return
	var sk_all: Dictionary = GameData.SKILLS[d["skill"]]
	var times: Array = sk_all.get("hits", [0.0])
	var n: int = d.get("n", 0) + 1
	if n < times.size():
		var next := d.duplicate()
		next["n"] = n
		next["late"] = false
		next["t"] = maxf(float(times[n]) - float(times[n - 1]) - (wait if d.get("late", false) else 0.0), 0.0)
		_follow.append(next)
	if not d.has("dst"):
		_resolve_aoe(src, d["skill"], d["at"])
		return
	var sk: Dictionary = GameData.SKILLS[d["skill"]]
	var tgt := ents[d["dst"]]
	if sk.get("grab", false) and tgt.cast_t <= 0.0: # kavrama yalnizca hazirlanan rakibi yakalar; bekleme suresi aynen isler
		events.append({"t": "whiff", "ent": src.id, "skill": d["skill"]})
		return
	# Engellenemez (Buz Muhru, kullanici karari): siper/Buz Kolu ve uzaklasma ise yaramaz; tek cozum hazirlikta Titani vurup bozmak
	var sure: bool = sk.get("unblockable", false)
	if tgt.alive and (sure or (src.pos.distance_to(tgt.pos) <= float(sk["range"]) * 1.4 and not _guarded(src, tgt))):
		if _hit(src, tgt, sk["mult"], {"force_crit": sk.get("force_crit", false), "skill": d["skill"]}):
			_riders(src, tgt, sk)
			_stagger(src, tgt, sk)


func _grace_for(d: Dictionary) -> float:
	if d.has("dst"):
		return ents[d["dst"]].grace
	var most := 0.0
	for o in enemies_of(ents[d["src"]]):
		most = maxf(most, o.grace)
	return most


## Hazirlanan yetenek iptal olur, bekleme suresi aynen isler: yanlis zamanda basmanin bedeli (kullanici karari).
func _interrupt(_src: Ent, tgt: Ent, stagger := false) -> void:
	if tgt.cast_t <= 0.0:
		return
	var id := tgt.cast_id
	for d: Dictionary in _delayed + _follow: # dizi su an tick icinde geziliyor olabilir, isaretlenir
		if d["src"] == tgt.id:
			d["off"] = true
	tgt.cast_t = 0.0
	tgt.lock = 0.0
	events.append({"t": "interrupt", "ent": tgt.id, "skill": id, "stagger": stagger})


## Yalniz agir ve kesme yetenekleri rakibi afallatir: elindeki saldiri iptal olur, once vuran kazanir. Hafif yetenekler
## rakibi sadece sarsar (gorunumde), saldirisi surer ve karsilikli vurus olur: hizli tempoda hareketler surekli
## yarida kesilip sicramaz (kullanici onayi, Doom Forge gibi).
func _breaks(sk: Dictionary) -> bool:
	return sk.get("breaks", false) or sk.has("stun") or sk.has("freeze") or sk.get("interrupt", false) or sk.has("reel") or sk.get("grab", false)


func _stagger(src: Ent, tgt: Ent, sk: Dictionary) -> void:
	if not _breaks(sk):
		return
	_interrupt(src, tgt, true)
	tgt.raise_t = 0.0 # kalkmakta olan siper de bozulur
	for d: Dictionary in _delayed + _follow:
		if d["src"] == tgt.id:
			d["off"] = true
	tgt.swing = 0.0
	tgt.basic_t = 0.0
	tgt.lock = 0.0
	tgt.queued = ""
	tgt.fx.append({"type": "reel", "t": sk.get("reel", GameData.STAGGER_TIME)})


func _riders(src: Ent, tgt: Ent, sk: Dictionary) -> void:
	if sk.has("stun"):
		tgt.fx.append({"type": "stun", "t": sk["stun"]})
		tgt.swing = 0.0
		tgt.basic_t = 0.0
		_interrupt(src, tgt)
	if sk.has("freeze"):
		tgt.fx.append({"type": "freeze", "t": sk["freeze"]})
		tgt.swing = 0.0
		tgt.basic_t = 0.0
		_interrupt(src, tgt)
	if sk.get("interrupt", false):
		_interrupt(src, tgt)
	if sk.has("push"):
		tgt.slide = (tgt.pos - src.pos).normalized() * float(sk["push"])
	if sk.has("slow"):
		tgt.fx.append({"type": "slow", "t": sk["slow"]["dur"], "pct": sk["slow"]["pct"]})
	if sk.has("leech"):
		var amount := roundf(_last_dmg * float(sk["leech"]))
		src.hp = minf(float(src.s["max_hp"]), src.hp + amount)
		events.append({"t": "heal", "ent": src.id, "amount": int(amount)})
	if sk.has("dot"):
		tgt.fx.append({"type": "dot", "t": sk["dot"]["dur"], "src": src.id, "tick": 1.0,
			"dps": _buffed(src, "atk") * float(sk["dot"]["mult"])})


func _resolve_aoe(src: Ent, id: String, at: Vector2) -> void:
	var sk: Dictionary = GameData.SKILLS[id]
	events.append({"t": "aoe", "pos": at, "r": sk["radius"], "skill": id})
	for o in enemies_of(src):
		if o.pos.distance_to(at) > float(sk["radius"]) or _guarded(src, o):
			continue
		if _hit(src, o, sk["mult"], {"skill": id}):
			_riders(src, o, sk)
			_stagger(src, o, sk)


func _tick_projectiles() -> void:
	var flying: Array[Dictionary] = []
	for p in _projs:
		var dst := ents[p["dst"]]
		var to: Vector2 = dst.pos - p["pos"]
		var step: float = float(p["speed"]) * STEP
		if to.length() <= step + 0.3:
			events.append({"t": "proj_end", "id": p["id"]})
			if dst.alive and not _guarded(ents[p["src"]], dst, p["skill"] != ""):
				_hit(ents[p["src"]], dst, p["mult"], {"basic": p["skill"] == ""})
		else:
			p["pos"] += to.normalized() * step
			flying.append(p)
	_projs = flying


## Oyuncu maci birakir: kalan takim kazanir.
func surrender(team: int) -> void:
	if over:
		return
	over = true
	winner = 1 - team
	events.append({"t": "end", "winner": winner})


func _check_end() -> void:
	var a := ents.any(func(e: Ent) -> bool: return e.alive and e.team == 0)
	var b := ents.any(func(e: Ent) -> bool: return e.alive and e.team == 1)
	if a and b:
		return
	var w := 0 if a else 1
	wins[w] += 1
	if wins[w] >= ROUNDS_TO_WIN:
		over = true
		winner = w
		events.append({"t": "end", "winner": winner, "wins": wins.duplicate()})
		return
	events.append({"t": "round_end", "winner": w, "wins": wins.duplicate(), "round": round_no})
	round_no += 1
	gap_t = ROUND_GAP
