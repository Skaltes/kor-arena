extends SceneTree
## Ekransiz savas testi. Calistirma: Godot --headless --path . --script res://tests/test_core.gd

const LEVEL := 8

var tally := {}


func _duel(seed_value: int, a: String, b_cls: String, player_brain: float) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var me := Rules.new_character("A", a, LEVEL, 1, rng)
	var foe := Rules.new_character("B", b_cls, LEVEL, 1, rng)
	var b := Battle.new([[{"ch": me, "stats": Rules.calc_stats(me)}], [{"ch": foe, "stats": Rules.calc_stats(foe)}]], seed_value)
	var brains: Array[Brain] = [Brain.new(b.ents[1], 0.8, rng)]
	if player_brain > 0.0: # 0 = tus basmayan oyuncu
		brains.append(Brain.new(b.ents[0], player_brain, rng))
	var counts := {"cast0": 0, "cast1": 0, "attack0": 0}
	var ticks := 0
	while not b.over and ticks < 9000: # 5 dk: yetenek agirlikli uzun maclar (Paladin aynasi ~1,5-2 dk)
		for br in brains:
			br.update(b, Battle.STEP)
		b.tick()
		ticks += 1
		for ev in b.events:
			if ev["t"] == "cast":
				counts["cast%d" % ev["ent"]] += 1
			elif ev["t"] == "interrupt":
				tally[ev["t"]] = int(tally.get(ev["t"], 0)) + 1
			elif ev["t"] == "parry" or ev["t"] == "blocked":
				tally[ev["t"]] = int(tally.get(ev["t"], 0)) + 1
			elif ev["t"] == "attack" and ev["ent"] == 0:
				counts["attack0"] += 1
		b.events.clear()
	b.release()
	counts.merge({"over": b.over, "win": b.winner == 0, "time": b.t, "hp": [b.ents[0].hp, b.ents[1].hp]})
	return counts


func _cooldown_check() -> bool:
	var rng := RandomNumberGenerator.new()
	var me := Rules.new_character("A", "warrior", LEVEL, 1, rng)
	var foe := Rules.new_character("B", "brute", LEVEL, 1, rng)
	var b := Battle.new([[{"ch": me, "stats": Rules.calc_stats(me)}], [{"ch": foe, "stats": Rules.calc_stats(foe)}]], 5)
	var e := b.ents[0]
	while e.target == null or e.pos.distance_to(e.target.pos) > 1.8:
		b.tick()
	e.atk_t = 999.0 # duz vurus yetenegi kilitlemesin
	e.swing = 0.0
	e.basic_t = 0.0
	b.command({"ent": 0, "type": "skill", "skill": "power"})
	b.tick()
	var used: bool = e.cds["power"] > 3.9
	for i in 20:
		b.tick()
	var blocked := not b.can_cast(e, "power")
	var cd: float = GameData.SKILLS["power"]["cd"]
	for i in int(cd / Battle.STEP) + 2:
		if b.over:
			break
		b.tick()
	for i in 90: # o an duz vurus suruyorsa bitmesi beklenir
		if b.over or e.basic_t <= 0.0:
			break
		b.tick()
	var ready := b.over or b.can_cast(e, "power")
	b.release()
	return used and blocked and ready


## Teslim olan takim kaybeder, bitis olayi tek kez gelir, mac ilerlemez.
func _surrender_check() -> bool:
	var rng := RandomNumberGenerator.new()
	var me := Rules.new_character("A", "warrior", LEVEL, 1, rng)
	var foe := Rules.new_character("B", "brute", LEVEL, 1, rng)
	var b := Battle.new([[{"ch": me, "stats": Rules.calc_stats(me)}], [{"ch": foe, "stats": Rules.calc_stats(foe)}]], 5)
	b.tick()
	b.surrender(0)
	b.surrender(0)
	var ends := b.events.filter(func(ev: Dictionary) -> bool: return ev["t"] == "end")
	var ok: bool = b.over and b.winner == 1 and ends.size() == 1 and ends[0]["winner"] == 1
	b.release()
	return ok


func _pair(a: String, c: String) -> Battle:
	var rng := RandomNumberGenerator.new()
	var me := Rules.new_character("A", a, LEVEL, 1, rng)
	var foe := Rules.new_character("B", c, LEVEL, 1, rng)
	var b := Battle.new([[{"ch": me, "stats": Rules.calc_stats(me)}], [{"ch": foe, "stats": Rules.calc_stats(foe)}]], 5)
	while b.ents[0].target == null or b.ents[0].pos.distance_to(b.ents[1].pos) > 1.8:
		b.tick()
	b.ents[0].atk_t = 999.0
	b.ents[1].atk_t = 999.0
	b.ents[0].swing = 0.0
	b.ents[1].swing = 0.0
	b.events.clear()
	return b


func _damage_to(b: Battle, id: int, seconds: float) -> int:
	var total := 0
	for i in int(seconds / Battle.STEP):
		b.tick()
		for ev in b.events:
			if ev["t"] == "hit" and ev["ent"] == id:
				total += int(ev["dmg"])
		b.events.clear()
	return total


## Duz vurus basladiysa, hazirlik ve toparlanma bitene kadar hicbir yetenek (siper dahil) kullanilamaz.
func _basic_lock_check() -> bool:
	var ok := true
	for cls: String in GameData.CLASSES:
		var b := _pair(cls, "warrior")
		var e := b.ents[0]
		e.cds.clear()
		e.gcd = 0.0
		e.atk_t = 0.0
		for i in 60: # menzile girip duz vurusa baslar
			b.tick()
			if e.basic_t > 0.0:
				break
		var started := e.basic_t > 0.0
		e.atk_t = 999.0
		var lock := e.basic_t
		var expected := float(e.s["swing"]) + float(e.s["recover"])
		var blocked := true
		while e.basic_t > 0.0:
			for id: String in e.skills:
				blocked = blocked and not b.can_cast(e, id)
			b.tick()
		b.tick()
		var free := e.skills.any(func(id: String) -> bool: return b.can_cast(e, id))
		if not (blocked and free and started and lock > expected - 0.05):
			print("  duz vurus kilidi ", cls, ": basladi=", started, " kilitli=", blocked, " sonra serbest=", free)
		ok = ok and blocked and free and started and lock > expected - 0.05
		b.release()
		# Vurusun en basinda basilan yetenek kaybolmaz: vurus tamamen bitince atilir, daha once degil
		var q := _pair(cls, "warrior")
		var me := q.ents[0]
		me.cds.clear()
		me.gcd = 0.0
		me.atk_t = 0.0
		for i in 60:
			q.tick()
			if me.basic_t > 0.0:
				break
		me.atk_t = 999.0
		var id: String = me.skills[0]
		q.command({"ent": 0, "type": "skill", "skill": id})
		var early := false
		while me.basic_t > 0.0:
			q.tick()
			early = early or (float(me.cds.get(id, 0.0)) > 0.0 and me.basic_t > 0.0)
		for i in 2:
			q.tick()
		var fired := float(me.cds.get(id, 0.0)) > 0.0
		if early or not fired:
			print("  duz vurus kuyrugu ", cls, ": erken=", early, " atildi=", fired)
		ok = ok and not early and fired
		q.release()
	return ok


## Kesilen hazirligin darbesi hic inmemeli.
func _interrupt_check() -> bool:
	var b := _pair("warrior", "brute")
	b.command({"ent": 1, "type": "skill", "skill": "ruin"})
	b.tick()
	b.command({"ent": 0, "type": "skill", "skill": "bash"})
	var hurt := _damage_to(b, 0, 3.0)
	b.release()
	print("  kesilen Yikim'in hasari: ", hurt)
	return hurt == 0


## Normal saldiri tam inerken parry: hasar yok, saldiran sarsilir, siper biter.
## Kalkan once kalkar (hazirlik): kalkmadan inen darbe isler.
func _parry_basic_check() -> bool:
	var b := _pair("warrior", "brute")
	b.ents[1].swing = 0.25
	b.command({"ent": 0, "type": "skill", "skill": "wall"})
	b.tick()
	var rising := b.ents[0].guard_t <= 0.0 and b.ents[0].raise_t > 0.0
	for i in int(0.17 / Battle.STEP):
		b.tick()
	var guarded := b.ents[0].guard_t > 0.0
	var hurt := _damage_to(b, 0, 0.3)
	var ok := rising and guarded and hurt == 0 and b.has_fx(b.ents[1], "reel") and b.ents[0].guard_t <= 0.0 and b.ents[0].lock <= 0.0
	b.release()
	var c := _pair("warrior", "brute")
	c.ents[1].swing = 0.05
	c.command({"ent": 0, "type": "skill", "skill": "wall"})
	var too_late := _damage_to(c, 0, 0.3) > 0
	c.release()
	return ok and too_late


## Cok vuruslu yetenek ilk darbede parry yerse kalan darbeler iptal olur.
func _parry_multi_check() -> bool:
	var b := _pair("warrior", "assassin")
	b.ents[0].pos = b.ents[1].pos - Vector2(1.5, 0)
	b.command({"ent": 1, "type": "skill", "skill": "flurry"})
	for i in int((float(GameData.SKILLS["flurry"]["windup"]) - 0.25) / Battle.STEP): # siper, ilk vurustan hemen once kalkar
		b.tick()
	b.command({"ent": 0, "type": "skill", "skill": "wall"})
	var hurt := _damage_to(b, 0, 3.0)
	var free := not b.has_fx(b.ents[1], "stun") and b.ents[1].cast_t <= 0.0
	b.release()
	return hurt == 0 and free


## Kullanici karari: savunma kiran ve sonraki yetenegi hizlandiran etki yok. Her yetenekten sonra tam ortak bekleme gelir,
## savusturma da beklemeyi sifirlamaz.
func _no_shortcut_check() -> bool:
	for id: String in GameData.SKILLS:
		var sk: Dictionary = GameData.SKILLS[id]
		for bad: String in ["weaken", "opener", "combo"]:
			if sk.has(bad):
				print("Yasak etki: %s/%s" % [id, bad])
				return false
		# Tek istisna (kullanici karari): Ezici Hamle rakibi sarsar, ardindan hemen yetenek atilabilir
		if sk.has("after") and id != "trample":
			print("Kisa yol yalniz Ezici Hamlede olabilir: %s" % id)
			return false
	for cls: String in GameData.CLASSES:
		for id: String in GameData.CLASSES[cls]["skills"]:
			if GameData.SKILLS[id]["kind"] == "guard":
				continue
			var b := _pair(cls, "warrior")
			b.ents[0].pos = b.ents[1].pos - Vector2(1.5, 0)
			b.ents[0].atk_t = 9999.0
			b.ents[1].atk_t = 9999.0
			b.tick()
			b.command({"ent": 0, "type": "skill", "skill": id})
			b.tick()
			var gcd: float = b.ents[0].gcd
			b.release()
			if absf(gcd + Battle.STEP - GameData.skill_lock(id)) > 0.01:
				print("Kisa ortak bekleme: %s %.2f" % [id, gcd])
				return false
	var p := _pair("warrior", "brute")
	p.ents[0].pos = p.ents[1].pos - Vector2(1.8, 0)
	p.ents[0].atk_t = 9999.0
	p.ents[1].atk_t = 9999.0
	p.tick()
	p.command({"ent": 0, "type": "skill", "skill": "bash"})
	for i in int(0.5 / Battle.STEP):
		p.tick()
	p.ents[1].cds.clear()
	p.ents[1].gcd = 0.0
	p.ents[1].fx.clear()
	p.ents[0].gcd = GameData.GCD # Balyoz Darbesi uzun hazirlanir: savusturmaya kadar ortak bekleme bitmesin
	p.command({"ent": 1, "type": "skill", "skill": "smash"})
	var parried := false
	for i in int(2.2 / Battle.STEP):
		p.tick()
		if not parried and p.ents[1].cast_t > 0.0 and p.ents[1].cast_t < 0.25:
			p.command({"ent": 0, "type": "skill", "skill": "wall"})
		for ev: Dictionary in p.events:
			parried = parried or ev["t"] == "parry"
		p.events.clear()
		if parried:
			break
	var left: float = p.ents[0].gcd
	p.release()
	print("Savusturma sonrasi ortak bekleme %.2f sn (savusturuldu=%s)" % [left, parried])
	return parried and left > 0.1


## Yetenekler sabittir: ayni darbe rakibin durumuna gore degismez.
func _fixed_effect_check() -> bool:
	for id: String in GameData.SKILLS:
		if GameData.SKILLS[id].has("combo"):
			return false
	var hits: Array[int] = []
	for stunned: bool in [false, true]:
		var b := _pair("brute", "warrior")
		b.ents[0].pos = b.ents[1].pos - Vector2(1.8, 0)
		b.ents[0].atk_t = 9999.0
		b.ents[1].atk_t = 9999.0
		b.ents[0].s = b.ents[0].s.duplicate()
		b.ents[0].s["crit"] = 0.0
		if stunned:
			b.ents[1].fx.append({"type": "stun", "t": 5.0})
		b.command({"ent": 0, "type": "skill", "skill": "smash"})
		hits.append(_damage_to(b, 1, 2.0))
		b.release()
	print("Sabit etki: normal %d, sersem %d" % hits)
	return hits[0] > 0 and absf(hits[0] - hits[1]) <= hits[0] * 0.2


## Itme: rakip kayarak geri gider, alanin disina cikmaz.
func _push_check() -> bool:
	var b := _pair("brute", "assassin")
	b.ents[1].pos = Vector2(1.0, 0)
	b.ents[0].pos = Vector2(-0.3, 0)
	b.ents[0].atk_t = 9999.0
	b.ents[1].atk_t = 9999.0
	var start: float = b.ents[1].pos.x
	b.command({"ent": 0, "type": "skill", "skill": "trample"})
	for i in int(0.75 / Battle.STEP):
		b.tick()
	var moved: float = b.ents[1].pos.x - start
	b.ents[1].pos.x = 3.2
	b.ents[1].slide = Vector2(2.0, 0)
	for i in int(0.4 / Battle.STEP):
		b.tick()
	var inside: bool = b.ents[1].pos.x <= Battle.FIELD_HALF
	b.release()
	print("Itme: %.2f m" % moved)
	return absf(moved - 0.25) < 0.05 and inside # Ezici Hamle 0,25 m iter (kullanici istegi: 1,2 ve 0,5 m cok uzakti)


## Parry anindan sonra siper yine tum hasari keser ama saldiriyi kesmez; zehir de islemez.
func _block_check() -> bool:
	var b := _pair("warrior", "brute")
	b.ents[0].fx.append({"type": "dot", "t": 3.0, "src": 1, "tick": 0.5, "dps": 50.0})
	b.command({"ent": 0, "type": "skill", "skill": "wall"})
	for i in int(0.5 / Battle.STEP):
		b.tick()
	b.events.clear()
	b.ents[1].swing = 0.1
	var hurt := _damage_to(b, 0, 0.3)
	var ok := hurt == 0 and not b.has_fx(b.ents[1], "reel")
	b.release()
	return ok


## Siper bitince darbe yine isler ve bir yetenegin bekleme suresi dolar.
func _guard_end_check() -> bool:
	var b := _pair("warrior", "brute")
	b.command({"ent": 0, "type": "skill", "skill": "wall"})
	for i in int(1.3 / Battle.STEP):
		b.tick()
	b.events.clear()
	b.ents[1].swing = 0.05
	var hurt := _damage_to(b, 0, 0.2)
	var waits: bool = b.ents[0].cds["wall"] > float(GameData.SKILLS["wall"]["cd"]) * 0.7 and not b.can_cast(b.ents[0], "wall")
	b.release()
	return hurt > 0 and waits


## Ortak bekleme sirasinda basilabilir; hazirlik sirasinda basilamaz.
func _guard_gcd_check() -> bool:
	var b := _pair("warrior", "brute")
	b.command({"ent": 0, "type": "skill", "skill": "cry"})
	for i in int(0.7 / Battle.STEP): # Savas Narasi'nin hazirligi biter
		b.tick()
	var in_gcd: bool = b.ents[0].gcd > 0.1 and b.can_cast(b.ents[0], "wall") and b.has_fx(b.ents[0], "buff")
	b.release()
	var c := _pair("warrior", "brute")
	c.command({"ent": 0, "type": "skill", "skill": "power"})
	c.tick()
	var in_cast: bool = c.can_cast(c.ents[0], "wall")
	c.release()
	return in_gcd and not in_cast


## Gecikme telafisi: darbe indikten sonra gelen tus, telafi suresindeyse parry sayilir.
func _grace_check() -> bool:
	var b := _pair("warrior", "brute")
	b.ents[0].grace = 0.2
	b.ents[1].swing = 0.05
	for i in 6:
		b.tick()
	b.command({"ent": 0, "type": "skill", "skill": "wall"})
	var late_ok := _damage_to(b, 0, 0.5) == 0 and b.has_fx(b.ents[1], "reel")
	b.release()
	var c := _pair("warrior", "brute")
	c.ents[0].grace = 0.2
	c.ents[1].swing = 0.05
	var lands := _damage_to(c, 0, 0.5) > 0
	c.release()
	return late_ok and lands


func _new_skill_check() -> bool:
	var b := _pair("assassin", "warrior")
	b.ents[0].pos = b.ents[1].pos - Vector2(1.5, 0)
	b.ents[0].hp = 100.0
	b.command({"ent": 0, "type": "skill", "skill": "leech"})
	_damage_to(b, 1, 1.2)
	var healed := b.ents[0].hp > 100.0
	b.release()
	var c := _pair("warrior", "brute")
	c.command({"ent": 0, "type": "skill", "skill": "verdict"})
	_damage_to(c, 1, 1.6)
	var hit := c.ents[1].hp < float(c.ents[1].s["max_hp"])
	# Kullanici karari: hicbir yetenek rakibin saldirisini/savunmasini dusurmez
	var clean: bool = not c.has_fx(c.ents[1], "sap") and c._buffed(c.ents[1], "atk") == float(c.ents[1].s["atk"])
	c.release()
	for id: String in GameData.SKILLS:
		var sk: Dictionary = GameData.SKILLS[id]
		if sk.has("sap") or sk.has("weaken"):
			clean = false
		for v: float in sk.get("buff", {}).values():
			if v < 0.0:
				clean = false
	return healed and hit and clean


## Buz Mührü: bozulmazsa rakip donar ve hicbir sey yapamaz; hazirlikta bir yetenek yerse bozulur.
func _frost_check() -> bool:
	var b := _pair("brute", "warrior")
	b.command({"ent": 0, "type": "skill", "skill": "frost"})
	for i in int(2.0 / Battle.STEP):
		b.tick()
	var frozen := b.has_fx(b.ents[1], "freeze") and b.stopped(b.ents[1]) and not b.can_cast(b.ents[1], "bash") and not b.can_cast(b.ents[1], "wall")
	for i in int(2.1 / Battle.STEP):
		b.tick()
	var thawed := not b.has_fx(b.ents[1], "freeze")
	b.release()
	var c := _pair("brute", "warrior")
	c.command({"ent": 0, "type": "skill", "skill": "frost"})
	for i in int(0.4 / Battle.STEP):
		c.tick()
	c.command({"ent": 1, "type": "skill", "skill": "bash"})
	for i in int(2.0 / Battle.STEP):
		c.tick()
	var broken: bool = not c.has_fx(c.ents[1], "freeze") and c.ents[0].cast_t <= 0.0 and c.ents[0].cds["frost"] > float(GameData.SKILLS["frost"]["cd"]) * 0.8
	c.release()
	var g := _pair("brute", "warrior") # siper engellemez (kullanici karari): Kalkan Duvari acik olsa da donar
	g.command({"ent": 0, "type": "skill", "skill": "frost"})
	for i in int(0.8 / Battle.STEP):
		g.tick()
	g.command({"ent": 1, "type": "skill", "skill": "wall"})
	var walled := false
	for i in int(0.6 / Battle.STEP):
		g.tick()
		walled = walled or g.ents[1].guard_t > 0.0
	var through: bool = walled and g.has_fx(g.ents[1], "freeze")
	g.release()
	print("Buz Muhru: dondu=%s cozuldu=%s bozuldu=%s siper=%s sipere ragmen dondu=%s" % [frozen, thawed, broken, walled, through])
	return frozen and thawed and broken and through


## Buz Kolu: acikken inen yetenek de duz vurus da engellenir ve saldiran donar (kullanici istegi).
func _counter_check() -> bool:
	var b := _pair("brute", "warrior")
	b.command({"ent": 1, "type": "skill", "skill": "power"})
	for i in int(0.35 / Battle.STEP): # Guclu Darbe (0,75 sn) inmeden Buz Kolu kalkar
		b.tick()
	b.command({"ent": 0, "type": "skill", "skill": "icearm"})
	var hurt := _damage_to(b, 0, 0.6)
	var froze := b.has_fx(b.ents[1], "freeze")
	b.release()
	var c := _pair("brute", "warrior")
	c.command({"ent": 0, "type": "skill", "skill": "icearm"})
	c.tick()
	c.ents[1].swing = 0.1
	var basic_hurt := _damage_to(c, 0, 0.3)
	var basic_ok: bool = c.has_fx(c.ents[1], "freeze")
	c.release()
	print("Buz Kolu: yetenek hasari=%d dondu=%s, normal saldiri hasari=%d" % [hurt, froze, basic_hurt])
	return hurt == 0 and froze and basic_hurt == 0 and basic_ok


## Hazirligi olmayan yetenek yok; kendine yonelik yetenek hazirlikta vurulursa etkisi gelmez.
func _windup_check() -> bool:
	for id: String in GameData.SKILLS:
		if float(GameData.SKILLS[id].get("windup", 0.0)) <= 0.0:
			print("Hazirliksiz yetenek: ", id)
			return false
	var b := _pair("warrior", "brute")
	b.command({"ent": 0, "type": "skill", "skill": "cry"})
	b.tick()
	var early := not b.has_fx(b.ents[0], "buff")
	b.command({"ent": 1, "type": "skill", "skill": "trample"}) # eskiden Girtlak Kavrama (kaldirildi, 0.45 sn); Ezici Hamle de 0.45 sn ve sarsar
	for i in int(1.0 / Battle.STEP):
		b.tick()
	var cut := not b.has_fx(b.ents[0], "buff")
	b.release()
	return early and cut


## Titan kendini guclendirmez: butun yetenekleri rakibe yoneliktir.
func _titan_active_check() -> bool:
	for id: String in GameData.CLASSES["brute"]["skills"]:
		if GameData.SKILLS[id].has("buff") or GameData.SKILLS[id]["kind"] == "self":
			return false
	return true


## Kayit geri okunur; ana dosya bozulursa yedekten, ikisi de bozuksa temiz baslar; gecersiz veri oyunu bozmaz.
func _profile_check() -> bool:
	var file := "user://test_kayit.json"
	var clean := func() -> void:
		for f: String in [file, file + ".yedek", file + ".yeni"]:
			DirAccess.remove_absolute(f)
	clean.call()
	var fresh := Profile.open(file)
	var empty := fresh.wins == 0 and fresh.cls == "warrior" and fresh.player_name == ""
	fresh.player_name = "Kor"
	fresh.cls = "brute"
	fresh.record(true)
	fresh.record(true)
	fresh.record(false)
	var back := Profile.open(file)
	var same := back.player_name == "Kor" and back.cls == "brute" and back.wins == 2 and back.losses == 1 and back.streak == 0 and back.best_streak == 2
	FileAccess.open(file, FileAccess.WRITE).store_string("{bozuk")
	var saved := Profile.open(file)
	var from_backup := saved.player_name == "Kor" and saved.wins == 2 and saved.losses == 0
	FileAccess.open(file + ".yedek", FileAccess.WRITE).store_string("[]")
	var reset := Profile.open(file).wins == 0
	FileAccess.open(file, FileAccess.WRITE).store_string('{"version":1,"name":5,"cls":"yok","wins":"cok","losses":-4}')
	var odd := Profile.open(file)
	var safe := odd.cls == "warrior" and odd.wins == 0 and odd.losses == 0
	var unsaved := Profile.new()
	unsaved.record(true)
	clean.call()
	return empty and same and from_backup and reset and safe and unsaved.wins == 1


## Odul, seviye atlama, yeni yetenek, patron cift odulu; kaybeden asama atlamaz; seviye tavani asilmaz.
func _progress_check() -> bool:
	var p := Profile.new()
	var lost := p.grant(false, RandomNumberGenerator.new())
	var stayed: bool = p.stage == 1 and lost["xp"] == GameData.XP_LOSS + 3 and p.gold == GameData.GOLD_LOSS + 1
	p = Profile.new()
	p.xp = Rules.xp_need(1) - 1
	var won := p.grant(true, RandomNumberGenerator.new())
	var leveled: bool = p.stage == 2 and p.level == 2 and won["levels"] == 1 and won["skills"] == ["lunge"]
	var boss := Profile.new()
	boss.stage = GameData.BOSS_EVERY
	var doubled: bool = boss.grant(true, RandomNumberGenerator.new())["xp"] == (GameData.XP_WIN + GameData.BOSS_EVERY * 10) * 2
	var top := Profile.new()
	top.level = GameData.MAX_LEVEL
	top.grant(true, RandomNumberGenerator.new())
	var foes: bool = Rules.stage_foe(1)["level"] == 1 and Rules.stage_foe(5)["boss"] and Rules.stage_foe(500)["level"] == GameData.MAX_LEVEL
	return stayed and leveled and doubled and top.level == GameData.MAX_LEVEL and foes


## Once inen yetenek rakibi afallatir, onun saldirisi hic inmez. Normal saldiri hazirligi bozmaz.
func _stagger_check() -> bool:
	var b := _pair("warrior", "brute")
	b.command({"ent": 1, "type": "skill", "skill": "ruin"})
	b.tick()
	b.command({"ent": 0, "type": "skill", "skill": "power"}) # Guclu Darbe (agir, kesen) Yikim'dan once iner
	var hurt := _damage_to(b, 0, 1.0)
	var reeled := b.has_fx(b.ents[1], "reel") and b.ents[1].cast_t <= 0.0
	var waits: bool = b.ents[1].cds["ruin"] > float(GameData.SKILLS["ruin"]["cd"]) * 0.8
	hurt += _damage_to(b, 0, 2.0)
	b.release()
	var c := _pair("warrior", "assassin")
	c.ents[0].pos = c.ents[1].pos - Vector2(1.5, 0)
	c.command({"ent": 1, "type": "skill", "skill": "flurry"})
	for i in int((float(GameData.SKILLS["flurry"]["windup"]) + 0.1) / Battle.STEP):
		c.tick()
	c.events.clear()
	c._stagger(c.ents[0], c.ents[1], {"breaks": true}) # cok vuruslu yetenegin ilk darbesinden sonra agir bir darbe
	var flurry_left := _damage_to(c, 0, 2.0)
	var d := _pair("warrior", "brute")
	d.command({"ent": 0, "type": "skill", "skill": "whirl"})
	_damage_to(d, 0, 1.55)
	d.command({"ent": 1, "type": "skill", "skill": "trample"})
	var first_wins := _damage_to(d, 0, 1.0) == 0 # Kasirga once inip Ezici Hamle'yi bozar
	d.release()
	c.release()
	var e := _pair("warrior", "brute")
	e.command({"ent": 1, "type": "skill", "skill": "smash"})
	e.tick()
	e.ents[0].swing = 0.05
	var basic_lands := _damage_to(e, 0, 2.0) > 0
	e.release()
	print("  afallatma: hasar=%d sarsildi=%s bekliyor=%s once vuran=%s kalan vurus=%d normal bozmaz=%s" % [hurt, reeled, waits, first_wins, flurry_left, basic_lands])
	return hurt == 0 and reeled and waits and first_wins and flurry_left == 0 and basic_lands


## Ganimet, giyme, satma, stat puani, sandik, gunluk odul ve kayda yazilip geri okunmasi.
func _gear_check() -> bool:
	var file := "user://test_esya.json"
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var p := Profile.open(file)
	p.stage = GameData.BOSS_EVERY
	var drop: Dictionary = p.grant(true, rng)["loot"]
	var dropped: bool = p.bag.size() == 1 and int(drop["rarity"]) >= 1
	var plain: float = Rules.calc_stats(p.character("A", "brute"))["atk"]
	var slot: String = drop["slot"]
	var old: Dictionary = p.equipped[slot]
	p.equip(0)
	var swapped: bool = p.equipped[slot] == drop and p.bag[0] == old
	p.points = 2
	p.spend("main")
	p.spend("vit")
	p.spend("vit")
	var limited: bool = p.points == 0 and p.spent["main"] == 1 and p.spent["vit"] == 1
	var boosted: bool = Rules.calc_stats(p.character("A", "brute"))["atk"] > plain
	var cash := p.gold
	p.sell(0)
	var sold: bool = p.gold > cash and p.bag.is_empty()
	p.gold = 0
	var broke := p.open_chest(rng).is_empty()
	p.gold = p.chest_price()
	var chest: bool = not p.open_chest(rng).is_empty() and p.gold == 0
	var first := p.claim_daily("2026-11-02", "2026-11-01")
	var again := p.claim_daily("2026-11-02", "2026-11-01")
	var second := p.claim_daily("2026-11-03", "2026-11-02")
	var daily: bool = first > 0 and again == 0 and second > first and p.day_streak == 2
	var back := Profile.open(file)
	var kept: bool = back.equipped[slot]["stats"] == drop["stats"] and back.equipped[slot]["rarity"] is int and back.bag.size() == 1 and back.spent["vit"] == 1 and back.day_streak == 2
	Rules.calc_stats(back.character("A", "assassin"))
	for f: String in [file, file + ".yedek", file + ".yeni"]:
		DirAccess.remove_absolute(f)
	var quest := Profile.new()
	quest.day_wins = GameData.DAILY_WINS - 1
	var paid: bool = quest.grant(true, rng)["quest"] > 0
	return dropped and swapped and limited and boosted and sold and broke and chest and daily and kept and paid


func _initialize() -> void:
	var failed := false
	var checks := {"Kalici kayit": _profile_check(), "Ilerleme": _progress_check(), "Esya ve puan": _gear_check(), "Hizli yavasi afallatir": _stagger_check(), "Kesme darbeyi siler": _interrupt_check(), "Parry normal saldiri": _parry_basic_check(), "Parry cok vurus": _parry_multi_check(),
		"Siper tum hasari keser": _block_check(), "Siper sonu ve bekleme": _guard_end_check(), "Siper ortak beklemeye takilmaz": _guard_gcd_check(),
		"Gecikme telafisi": _grace_check(), "Yeni yetenekler": _new_skill_check(),
		"Kisa yol yok": _no_shortcut_check(), "Etkiler sabit": _fixed_effect_check(), "Itme": _push_check(),
		"Buz Muhru": _frost_check(), "Buz Kolu": _counter_check(), "Titan kendini guclendirmez": _titan_active_check(), "Hazirliksiz yetenek yok": _windup_check(), "Duz vurus bitmeden yetenek yok": _basic_lock_check()}
	for k: String in checks:
		print(k, ": ", checks[k])
		failed = failed or not checks[k]
	var classes: Array = GameData.CLASSES.keys()
	for a: String in classes:
		var line := "%-9s" % a
		for c: String in classes:
			var wins := 0
			var total := 0.0
			for i in 100:
				var r := _duel(1000 + i, a, c, 0.8)
				failed = failed or not r["over"]
				wins += int(r["win"])
				total += r["time"]
			line += "  %s:%%%3d %2.0fsn" % [c.left(3), wins, total / 100.0]
		print(line)
	for a: String in classes:
		var wins := 0
		var casts := 0
		var foe_casts := 0
		var attacks := 0
		for i in 100:
			var r := _duel(2000 + i, a, a, 0.0)
			wins += int(r["win"])
			casts += r["cast0"]
			foe_casts += r["cast1"]
			attacks += r["attack0"]
		print("Tus basmayan %s: kazanma %%%d, kendi yetenegi %d, normal saldiri %d, rakip yetenegi %d" % [a, wins, casts, attacks, foe_casts])
		failed = failed or casts != 0 or attacks == 0 or foe_casts == 0
	print("Kesme sayisi: ", tally)
	var cd_ok := _cooldown_check()
	print("Bekleme suresi: ", cd_ok)
	var x := _duel(77, "brute", "warrior", 0.8)
	var y := _duel(77, "brute", "warrior", 0.8)
	var same: bool = x["hp"] == y["hp"] and x["time"] == y["time"]
	print("Ayni tohum ayni sonuc: ", same)
	var give_up := _surrender_check()
	print("Teslim olma: ", give_up)
	failed = failed or not same or not cd_ok or not give_up
	print("SONUC: ", "BASARISIZ" if failed else "BASARILI")
	quit(1 if failed else 0)