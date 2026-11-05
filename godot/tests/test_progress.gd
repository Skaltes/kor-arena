extends SceneTree
## Arena merdiveni: orta beceride oyuncu asamalarda takilmadan ilerliyor mu?
## Calistirma: Godot --headless --path . --script res://tests/test_progress.gd

const RUNS := 12
const PLAYER := 0.65
const MATCHES := 60


func _duel(p: Profile, seed_value: int) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := Rules.stage_foe(p.stage)
	var me := p.character("A", p.cls)
	var foe := Rules.make_opponent(st["level"], {"offset": 0, "gear": st["gear"]}, rng)
	var b := Battle.new([[{"ch": me, "stats": Rules.calc_stats(me)}], [{"ch": foe, "stats": Rules.calc_stats(foe)}]], seed_value)
	var brains: Array[Brain] = [Brain.new(b.ents[0], PLAYER, rng), Brain.new(b.ents[1], st["ai"], rng)]
	var ticks := 0
	while not b.over and ticks < 5400:
		for br in brains:
			br.update(b, Battle.STEP)
		b.tick()
		ticks += 1
		b.events.clear()
	var won := b.winner == 0
	b.release()
	return won


## Oyuncu gibi: puanlari dagitir, altinin yarisini demircide en ucuz guclendirmeye, kalanini sandiga harcar, daha iyi esyayi giyer.
func _play_smart(p: Profile, rng: RandomNumberGenerator) -> void:
	while p.points > 0:
		p.spend("main" if p.points % 2 == 0 else "vit")
	var budget := p.gold / 2
	while true:
		var cheap := ""
		for slot: String in GameData.SLOTS:
			if p.can_upgrade(slot) and (cheap == "" or Rules.upgrade_cost(p.equipped[slot]) < Rules.upgrade_cost(p.equipped[cheap])):
				cheap = slot
		if cheap == "" or Rules.upgrade_cost(p.equipped[cheap]) > budget:
			break
		budget -= Rules.upgrade_cost(p.equipped[cheap])
		p.upgrade(cheap)
	while not p.open_chest(rng).is_empty():
		pass
	var i := p.bag.size() - 1
	while i >= 0:
		if Rules.item_power(p.bag[i]) > Rules.item_power(p.equipped[p.bag[i]["slot"]]):
			p.equip(i)
		p.sell(i)
		i -= 1


func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	var buckets := {}
	for cls: String in GameData.CLASSES:
		var stages := 0
		var levels := 0
		var pluses := 0
		for run in RUNS:
			var p := Profile.new()
			p.cls = cls
			for m in MATCHES:
				var key := (p.stage - 1) / 5
				var won := _duel(p, run * 1000 + m)
				var row: Array = buckets.get(key, [0, 0])
				row[0] += int(won)
				row[1] += 1
				buckets[key] = row
				p.grant(won, rng)
				p.check_achievements()
				_play_smart(p, rng)
			stages += p.stage
			levels += p.level
			pluses += GameData.SLOTS.reduce(func(s: int, slot: String) -> int: return s + int(p.equipped[slot].get("plus", 0)), 0)
		print("%s: %d macta ortalama asama %.1f, seviye %.1f, demirci derecesi toplami %.1f" % [cls, MATCHES, float(stages) / RUNS, float(levels) / RUNS, float(pluses) / RUNS])
	var keys := buckets.keys()
	keys.sort()
	for k: int in keys:
		print("Asama %2d-%2d: kazanma %%%d (%d mac)" % [k * 5 + 1, k * 5 + 5, 100 * buckets[k][0] / buckets[k][1], buckets[k][1]])
	quit()
