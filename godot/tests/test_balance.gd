extends SceneTree
## Denge olcumu: her eslesme iki tarafta da oynanir, boylece sol tarafin avantaji sonucu bozmaz.
## Calistirma: Godot --headless --path . --script res://tests/test_balance.gd
## Hedef: her eslesme %45-55, ortalama mac 25-45 sn.

const LEVEL := 8
const GAMES := 400 # eslesme ve taraf basina
const BRAINS: Array[float] = [0.8]
const LOW := 45.0
const HIGH := 55.0


func _duel(seed_value: int, left: String, right: String, skill: float) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var a := Rules.new_character("A", left, LEVEL, 1, rng)
	var b_ch := Rules.new_character("B", right, LEVEL, 1, rng)
	var b := Battle.new([[{"ch": a, "stats": Rules.calc_stats(a)}], [{"ch": b_ch, "stats": Rules.calc_stats(b_ch)}]], seed_value)
	var brains: Array[Brain] = [Brain.new(b.ents[0], skill, rng), Brain.new(b.ents[1], skill, rng)]
	var ticks := 0
	while not b.over and ticks < 5400:
		for br in brains:
			br.update(b, Battle.STEP)
		b.tick()
		ticks += 1
		b.events.clear()
	b.release()
	return {"winner": b.winner, "time": b.t, "over": b.over}


func _pair(x: String, y: String, skill: float) -> Array:
	var wins := 0
	var total := 0.0
	var unfinished := 0
	for i in GAMES:
		var r := _duel(3000 + i, x, y, skill)
		wins += int(r["winner"] == 0)
		total += r["time"]
		unfinished += int(not r["over"])
		r = _duel(7000 + i, y, x, skill)
		wins += int(r["winner"] == 1)
		total += r["time"]
		unfinished += int(not r["over"])
	return [100.0 * wins / (GAMES * 2), total / (GAMES * 2), unfinished]


func _initialize() -> void:
	var classes: Array = GameData.CLASSES.keys()
	var failed := false
	for skill: float in BRAINS:
		for i in classes.size():
			for j in range(i, classes.size()):
				var r := _pair(classes[i], classes[j], skill)
				print("%-8s - %-8s %%%4.1f  %2.0f sn  bitmeyen %d" % [classes[i], classes[j], r[0], r[1], r[2]])
				failed = failed or r[2] > 0
				if i != j:
					failed = failed or r[0] < LOW or r[0] > HIGH
	print("DENGE: ", "DISINDA" if failed else "HEDEFTE")
	quit(0)
