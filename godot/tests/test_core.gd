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
	while not b.over and ticks < 5400:
		for br in brains:
			br.update(b, Battle.STEP)
		b.tick()
		ticks += 1
		for ev in b.events:
			if ev["t"] == "cast":
				counts["cast%d" % ev["ent"]] += 1
			elif ev["t"] == "interrupt" or ev["t"] == "combo":
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
	var ready := b.over or b.can_cast(e, "power")
	b.release()
	return used and blocked and ready


func _initialize() -> void:
	var failed := false
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
	print("Kesme ve kombo sayisi: ", tally)
	var cd_ok := _cooldown_check()
	print("Bekleme suresi: ", cd_ok)
	var x := _duel(77, "brute", "warrior", 0.8)
	var y := _duel(77, "brute", "warrior", 0.8)
	var same: bool = x["hp"] == y["hp"] and x["time"] == y["time"]
	print("Ayni tohum ayni sonuc: ", same)
	failed = failed or not same or not cd_ok
	print("SONUC: ", "BASARISIZ" if failed else "BASARILI")
	quit(1 if failed else 0)