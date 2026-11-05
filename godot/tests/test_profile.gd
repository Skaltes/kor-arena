extends SceneTree
## Kalici kayit, demirci, basarim ve odul kurallari. Calistirma: Godot --headless --path . --script res://tests/test_profile.gd

const FILE := "user://test_kayit.json"

var _failed := 0


func _check(label: String, ok: bool) -> void:
	print("%s: %s" % [label, ok])
	_failed += int(not ok)


func _wipe() -> void:
	for f: String in [FILE, FILE + ".yedek", FILE + ".yeni"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)


func _item(slot: String, rarity: int, level: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	return Rules.make_item(slot, level, rarity, "warrior", rng)


func _roundtrip() -> void:
	_wipe()
	var p := Profile.open(FILE)
	p.player_name = "Deneme"
	p.level = 12
	p.gold = 777
	p.stage = 9
	p.online_wins = 3
	p.counts = {"parry": 4, "win_brute": 2}
	p.done = ["win1"]
	p.seen_help = true
	p.gold += 5000
	p.upgrade("weapon")
	p.gold -= 5000
	p.bag.append(_item("armor", 3, 7))
	var cost_before := Rules.upgrade_cost(p.equipped["weapon"])
	p.save()
	var q := Profile.open(FILE)
	_check("Kayit geri okunur", q.player_name == "Deneme" and q.level == 12 and q.stage == 9 and q.online_wins == 3)
	_check("Sayac ve basarim kalir", q.stat("parry") == 4 and q.stat("classes") == 1 and q.done == ["win1"] and q.seen_help)
	_check("Derece kalir", q.equipped["weapon"]["plus"] == 1 and Rules.upgrade_cost(q.equipped["weapon"]) == cost_before)
	_check("Canta esyasi kalir", q.bag.size() == 1 and q.bag[0]["rarity"] == 3 and q.bag[0]["slot"] == "armor")
	Rules.calc_stats(q.character("A", "brute"))


func _old_save() -> void:
	_wipe()
	var f := FileAccess.open(FILE, FileAccess.WRITE)
	f.store_string('{"version":1,"name":"Eski","cls":"brute","wins":7,"losses":2,"level":5,"xp":10,"gold":40,"stage":6,"points":2,' +
		'"spent":{"main":1,"agi":0,"vit":1},"equipped":{"weapon":{"slot":"weapon","type":"sledge","rarity":2,"level":4,"stats":{"atk":12},"variant":1}},' +
		'"bag":[{"slot":"helmet","type":"helmet","rarity":1,"level":3,"stats":{"def":4,"hp":9},"variant":3}],"last_day":"2026-11-01","day_streak":2,"day_wins":1}')
	f.close()
	var p := Profile.open(FILE)
	_check("Eski surum kayit acilir", p.player_name == "Eski" and p.cls == "brute" and p.wins == 7 and p.equipped["weapon"]["rarity"] == 2 and p.bag.size() == 1)
	_check("Eski kayitta yeni alanlar bos", p.online_wins == 0 and p.done.is_empty() and p.counts.is_empty() and not p.seen_help)
	_check("Eski esya demirciye girer", int(p.equipped["weapon"]["plus"]) == 0 and Rules.upgrade_cost(p.equipped["weapon"]) > 0)
	_check("Eski kayitta basarim verilir", p.check_achievements().size() >= 1 and p.done.has("win1"))


func _broken_save() -> void:
	_wipe()
	var p := Profile.open(FILE)
	p.player_name = "Saglam"
	p.gold = 11
	p.save()
	p.gold = 22
	p.save() # simdi yedekte 11 altinli hali var
	var f := FileAccess.open(FILE, FileAccess.WRITE)
	f.store_string('{"version":2,"name":"Yar')
	f.close()
	var q := Profile.open(FILE)
	_check("Bozuk dosyada yedek okunur", q.player_name == "Saglam" and q.gold == 11)
	_wipe()
	var bad := FileAccess.open(FILE, FileAccess.WRITE)
	bad.store_string('{"version":2,"level":"cok","gold":-50,"cls":"yok","equipped":{"weapon":{"slot":"armor"}},"bag":[{"slot":"x"},5],"done":[1,"win1"]}')
	bad.close()
	var r := Profile.open(FILE)
	_check("Hatali deger guvenli okunur", r.level == 1 and r.gold == 0 and r.cls == "warrior" and r.bag.is_empty() and r.done == ["win1"])


func _forge() -> void:
	var p := Profile.new()
	p.equipped["weapon"] = _item("weapon", 2, 10)
	var it: Dictionary = p.equipped["weapon"]
	var base: float = it["stats"]["atk"]
	_check("Parasiz demirci calismaz", not p.upgrade("weapon") and int(it.get("plus", 0)) == 0)
	p.gold = 10000000
	var before: float = Rules.calc_stats(p.character("A", "warrior"))["atk"]
	var cost := Rules.upgrade_cost(it)
	_check("Derece atlar, altin duser", p.upgrade("weapon") and it["plus"] == 1 and p.gold == 10000000 - cost)
	_check("Saldiri artar", Rules.calc_stats(p.character("A", "warrior"))["atk"] > before)
	_check("Sonraki derece pahali", Rules.upgrade_cost(it) > cost)
	while p.upgrade("weapon"):
		pass
	_check("Sinirda durur", it["plus"] == GameData.MAX_PLUS and not p.can_upgrade("weapon"))
	_check("Artis binmez", absf(float(it["stats"]["atk"]) - roundf(base * (1.0 + GameData.UPGRADE_STEP * GameData.MAX_PLUS))) <= 1.0)
	_check("Ad derece gosterir", Rules.item_name(it).ends_with("+10"))
	var small := _item("helmet", 0, 1)
	var old_def: float = small["stats"]["def"]
	Rules.raise_item(small)
	_check("Kucuk esya da en az 1 artar", small["stats"]["def"] >= old_def + 1.0)


func _money() -> void:
	var p := Profile.new()
	p.spent = {"main": 3, "agi": 1, "vit": 2}
	p.gold = 0
	_check("Parasiz sifirlanmaz", not p.reset_points() and p.spent_total() == 6)
	p.gold = 1000
	var price := p.reset_price()
	_check("Puanlar geri gelir", p.reset_points() and p.points == 6 and p.spent_total() == 0 and p.gold == 1000 - price)
	_check("Bos sifirlama yok", not p.reset_points())
	p.equipped["armor"] = _item("armor", 2, 10)
	p.bag = [_item("armor", 0, 1), _item("armor", 4, 12), _item("helmet", 4, 12)]
	var worth := Rules.sell_price(p.bag[0])
	var gold_now := p.gold
	_check("Yalniz zayiflar satilir", p.sell_weak() == worth and p.bag.size() == 2 and p.gold == gold_now + worth)


func _rewards() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var p := Profile.new()
	p.stage = 4
	var r := p.grant(true, rng)
	_check("Arena asama atlatir", p.stage == 5 and r["from_level"] == 1 and r["from_xp"] == 0 and r["xp"] > 0)
	var stage_now := p.stage
	var bag_now := p.bag.size()
	var w := p.grant_online(true)
	_check("Canli mac asama ve ganimet vermez", p.stage == stage_now and p.bag.size() == bag_now and p.online_wins == 1 and w["loot"].is_empty())
	_check("Canli galibiyet daha degerli", w["gold"] > r["gold"])
	var l := p.grant_online(false)
	_check("Canli yenilgi az verir", l["gold"] > 0 and l["gold"] < w["gold"] and p.online_losses == 1)
	p.stage = 10
	var boss_wins := p.stat("boss")
	var b := p.grant(true, rng)
	_check("Patron sayilir ve ganimet verir", p.stat("boss") == boss_wins + 1 and b["boss"] and not b["loot"].is_empty())
	p.level = GameData.MAX_LEVEL - 1
	p.xp = 0
	p._gain(10000000, 0)
	_check("Son seviyede tecrube birikmez", p.level == GameData.MAX_LEVEL and p.xp == 0)
	var d := Profile.new()
	var total := 0
	d.day_wins = GameData.DAILY_WINS - 1
	total += d.grant_online(true)["quest"]
	total += d.grant_online(true)["quest"]
	_check("Gunluk gorev bir kez odeme yapar", total > 0 and total == 100 + d.stage * 10)


func _achievements() -> void:
	var p := Profile.new()
	_check("Baslangicta basarim yok", p.check_achievements().is_empty())
	p.record(true, "warrior")
	var gold_now := p.gold
	var got := p.check_achievements()
	_check("Basarim bir kez verilir", got.size() == 1 and got[0]["id"] == "win1" and p.gold == gold_now + 50 and p.check_achievements().is_empty())
	p.record(true, "assassin")
	p.record(true, "brute")
	_check("Uc sinif sayilir", p.stat("classes") == 3 and p.check_achievements().any(func(a: Dictionary) -> bool: return a["id"] == "classes"))
	p.note_match(2, 3)
	_check("Mac sayaclari islenir", p.stat("parry") == 2 and p.stat("cut") == 3)
	var ids := {}
	for a: Dictionary in GameData.ACHIEVEMENTS:
		ids[a["id"]] = true
		if not ["wins", "stage", "level", "best_streak", "online_wins", "classes", "boss", "parry", "cut", "chest", "legend", "best_plus"].has(a["stat"]):
			_check("Bilinmeyen basarim sayaci " + a["stat"], false)
	_check("Basarim kimlikleri benzersiz", ids.size() == GameData.ACHIEVEMENTS.size())


func _names() -> void:
	_check("Unvanlar", Rules.league(1) == "Çırak" and Rules.league(9) == "Çırak" and Rules.league(10) == "Gladyatör" and Rules.league(99) == "Küllerin Efendisi")
	var p := Profile.new()
	var low := Rules.score(p.character("A", "warrior"))
	p.level = 10
	_check("Guc puani seviyeyle artar", Rules.score(p.character("A", "warrior")) > low)
	var worn := _item("armor", 0, 1)
	var better := _item("armor", 3, 10)
	var diff := Rules.item_diff(better, worn)
	_check("Esya farki hesaplanir", diff.size() == 2 and int(diff[0][1]) > 0)


func _initialize() -> void:
	_roundtrip()
	_old_save()
	_broken_save()
	_forge()
	_money()
	_rewards()
	_achievements()
	_names()
	_wipe()
	print("SONUC: ", "BASARILI" if _failed == 0 else "HATALI (%d)" % _failed)
	quit(_failed)
