class_name Profile
extends RefCounted
## Oyuncunun kalici kaydi. Cihazda JSON olarak durur; ileride sunucuya tasinabilsin diye duz veridir.
## Yazma yarida kalsa ya da dosya bozulsa kayit kaybolmaz: bir onceki hali yedekte durur.

const VERSION := 2
const PATH := "user://kayit.json"
const MAX_NAME := 16

var path := "" # bos: kaydedilmez (gelistirici testleri oyuncunun kaydina dokunmaz)
var player_name := ""
var cls := "warrior"
var wins := 0
var losses := 0
var streak := 0
var best_streak := 0
var online_wins := 0
var online_losses := 0
var level := 1
var xp := 0
var gold := 0
var stage := 1 # arenada siradaki asama
var points := 0 # dagitilmamis stat puani
var spent := {"main": 0, "agi": 0, "vit": 0}
var equipped := {}
var bag: Array = []
var last_day := ""
var day_streak := 0
var day_wins := 0
var counts := {} # basarim sayaclari: parry, cut, boss, chest, legend, best_plus, win_<sinif>
var done: Array = [] # alinmis basarimlar
var seen_help := false


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for slot: String in GameData.SLOTS:
		equipped[slot] = Rules.make_item(slot, 1, 0, "warrior", rng)


static func open(file: String) -> Profile:
	var p := Profile.new()
	p.path = file
	for candidate: String in [file, _backup(file)]:
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(candidate)) if FileAccess.file_exists(candidate) else null
		if data is Dictionary and data.has("version"):
			p._read(data)
			break
	return p


static func _backup(file: String) -> String:
	return file + ".yedek"


func _read(d: Dictionary) -> void:
	player_name = str(d.get("name", "")).left(MAX_NAME)
	var c := str(d.get("cls", cls))
	cls = c if GameData.CLASSES.has(c) else cls
	wins = _count(d, "wins")
	losses = _count(d, "losses")
	streak = _count(d, "streak")
	best_streak = _count(d, "best_streak")
	online_wins = _count(d, "online_wins")
	online_losses = _count(d, "online_losses")
	level = clampi(_count(d, "level"), 1, GameData.MAX_LEVEL)
	xp = _count(d, "xp")
	gold = _count(d, "gold")
	stage = maxi(_count(d, "stage"), 1)
	points = _count(d, "points")
	day_streak = _count(d, "day_streak")
	day_wins = _count(d, "day_wins")
	last_day = str(d.get("last_day", ""))
	seen_help = d.get("seen_help", false) == true
	var old: Variant = d.get("spent")
	if old is Dictionary:
		for k: String in spent:
			spent[k] = _count(old, k)
	var worn: Variant = d.get("equipped")
	if worn is Dictionary:
		for slot: String in GameData.SLOTS:
			if _valid(worn.get(slot)) and worn[slot]["slot"] == slot:
				equipped[slot] = _clean(worn[slot])
	var carried: Variant = d.get("bag")
	if carried is Array:
		for it: Variant in carried.slice(0, GameData.BAG_SIZE):
			if _valid(it):
				bag.append(_clean(it))
	var tally: Variant = d.get("counts")
	if tally is Dictionary:
		for k: String in tally:
			counts[k] = _count(tally, k)
	var taken: Variant = d.get("done")
	if taken is Array:
		done = taken.filter(func(a: Variant) -> bool: return a is String)


func _valid(it: Variant) -> bool:
	return it is Dictionary and GameData.SLOTS.has(it.get("slot")) and it.get("stats") is Dictionary \
		and (it.get("rarity") is float or it.get("rarity") is int) and int(it["rarity"]) >= 0 and int(it["rarity"]) < GameData.RARITY.size()


## JSON sayilari ondalik okur; dizin olarak kullanilanlar tam sayiya doner.
func _clean(it: Dictionary) -> Dictionary:
	var c := it.duplicate(true)
	c["rarity"] = int(c["rarity"])
	c["level"] = int(c.get("level", 1))
	c["variant"] = int(c.get("variant", 0))
	c["plus"] = int(c.get("plus", 0))
	return c


func _count(d: Dictionary, key: String) -> int:
	var v: Variant = d.get(key, 0)
	return maxi(int(v), 0) if v is float or v is int else 0


func record(won: bool, hero_cls: String = "") -> void:
	wins += int(won)
	losses += int(not won)
	streak = streak + 1 if won else 0
	best_streak = maxi(best_streak, streak)
	if won and hero_cls != "":
		add_count("win_" + hero_cls)
	save()


func add_count(key: String, amount: int = 1) -> void:
	counts[key] = int(counts.get(key, 0)) + amount


## Basarimin ilerlemesi: oyuncunun alanlarindan ya da sayaclardan okunur.
func stat(key: String) -> int:
	match key:
		"wins":
			return wins
		"stage":
			return stage
		"level":
			return level
		"best_streak":
			return best_streak
		"online_wins":
			return online_wins
		"classes":
			return GameData.CLASSES.keys().filter(func(c: String) -> bool: return int(counts.get("win_" + c, 0)) > 0).size()
	return int(counts.get(key, 0))


## Yeni tamamlanan basarimlar altinini verir ve kayda gecer; ayni basarim iki kez odullendirmez.
func check_achievements() -> Array[Dictionary]:
	var fresh: Array[Dictionary] = []
	for a: Dictionary in GameData.ACHIEVEMENTS:
		if not done.has(a["id"]) and stat(a["stat"]) >= int(a["goal"]):
			done.append(a["id"])
			gold += int(a["gold"])
			fresh.append(a)
	if not fresh.is_empty():
		save()
	return fresh


## Savasta olan biteni sayaclara ekler; maclar arasinda baska bir sey yazmaz.
func note_match(parries: int, cuts: int) -> void:
	add_count("parry", parries)
	add_count("cut", cuts)
	save()


## Savasa girecek karakter: silahin turu sinifa gore belirlenir, boylece esyalar her sinifta giyilir.
func character(char_name: String, hero_cls: String) -> Dictionary:
	var worn := {}
	for slot: String in GameData.SLOTS:
		worn[slot] = equipped[slot].duplicate(true)
	worn["weapon"]["type"] = GameData.CLASSES[hero_cls]["weapons"][0]
	return {"name": char_name, "cls": hero_cls, "level": level, "equipped": worn, "spent": spent.duplicate(),
		"look": {"skin": GameData.SKINS[0], "hair": GameData.HAIRS[0], "cloth": GameData.CLASSES[hero_cls]["color"]}}


func spend(stat_key: String) -> void:
	if points > 0 and spent.has(stat_key):
		points -= 1
		spent[stat_key] += 1
		save()


func spent_total() -> int:
	return int(spent["main"]) + int(spent["agi"]) + int(spent["vit"])


func reset_price() -> int:
	return 30 + spent_total() * 15


## Puanlari geri alir: yanlis dagitim kalici ceza olmasin.
func reset_points() -> bool:
	if spent_total() == 0 or gold < reset_price():
		return false
	gold -= reset_price()
	points += spent_total()
	for k: String in spent:
		spent[k] = 0
	save()
	return true


func equip(index: int) -> void:
	var it: Dictionary = bag[index]
	bag[index] = equipped[it["slot"]]
	equipped[it["slot"]] = it
	save()


func sell(index: int) -> void:
	gold += Rules.sell_price(bag[index])
	bag.remove_at(index)
	save()


## Giyilenden zayif her seyi satar: canta doldukca tek tek ugrastirmasin.
func sell_weak() -> int:
	var earned := 0
	var keep: Array = []
	for it: Dictionary in bag:
		if Rules.item_power(it) < Rules.item_power(equipped[it["slot"]]):
			earned += Rules.sell_price(it)
		else:
			keep.append(it)
	bag = keep
	gold += earned
	save()
	return earned


## Demirci: altin harcanacak ikinci yer, esyaya bagli kalici gelisim.
func can_upgrade(slot: String) -> bool:
	var it: Dictionary = equipped[slot]
	return int(it.get("plus", 0)) < GameData.MAX_PLUS and gold >= Rules.upgrade_cost(it)


func upgrade(slot: String) -> bool:
	if not can_upgrade(slot):
		return false
	var it: Dictionary = equipped[slot]
	gold -= Rules.upgrade_cost(it)
	Rules.raise_item(it)
	counts["best_plus"] = maxi(int(counts.get("best_plus", 0)), int(it["plus"]))
	save()
	return true


func chest_price() -> int:
	return 60 + stage * 12


## Sandik: altinla rastgele esya. Altin birikip anlamsiz kalmasin.
func open_chest(rng: RandomNumberGenerator) -> Dictionary:
	if gold < chest_price() or bag.size() >= GameData.BAG_SIZE:
		return {}
	gold -= chest_price()
	var it := _new_item(rng, false)
	bag.append(it)
	add_count("chest")
	save()
	return it


func _new_item(rng: RandomNumberGenerator, boss: bool) -> Dictionary:
	var slot: String = GameData.SLOTS[rng.randi_range(0, GameData.SLOTS.size() - 1)]
	var it := Rules.make_item(slot, Rules.stage_foe(stage)["level"], Rules.roll_rarity(rng, boss), cls, rng)
	if int(it["rarity"]) == GameData.RARITY.size() - 1:
		add_count("legend")
	return it


## Gunde bir kez giris odulu; ust uste gelen gunlerde artar. Odul verilmediyse 0 doner.
func claim_daily(today: String, yesterday: String) -> int:
	if today == last_day:
		return 0
	day_streak = day_streak + 1 if last_day == yesterday else 1
	last_day = today
	day_wins = 0
	var got := (40 + stage * 5) * mini(day_streak, 7)
	gold += got
	save()
	return got


func daily_text() -> String:
	return "Günlük görev: %d/%d galibiyet" % [mini(day_wins, GameData.DAILY_WINS), GameData.DAILY_WINS]


func _daily_win() -> int:
	day_wins += 1
	return 100 + stage * 10 if day_wins == GameData.DAILY_WINS else 0


## Tecrube ve altini ekler, seviye atlatir. Odul ekraninin canlandiracagi once/sonra degerlerini doner.
func _gain(got_xp: int, got_gold: int) -> Dictionary:
	var start := level
	var start_xp := xp
	var skills: Array[String] = []
	xp += got_xp
	gold += got_gold
	while level < GameData.MAX_LEVEL and xp >= Rules.xp_need(level):
		xp -= Rules.xp_need(level)
		level += 1
		points += GameData.POINTS_PER_LEVEL
	if level >= GameData.MAX_LEVEL:
		xp = 0
	for id: String in GameData.CLASSES[cls]["skills"]:
		if int(GameData.SKILLS[id]["unlock"]) > start and int(GameData.SKILLS[id]["unlock"]) <= level:
			skills.append(id)
	return {"xp": got_xp, "gold": got_gold, "levels": level - start, "skills": skills, "from_level": start, "from_xp": start_xp}


## Arena maci odulu. Kazanan bir sonraki asamaya gecer, kaybeden ayni rakiple yeniden dener ama bos donmez.
func grant(won: bool, rng: RandomNumberGenerator) -> Dictionary:
	var boss := stage % GameData.BOSS_EVERY == 0
	var scale := 2 if boss else 1
	var loot := {}
	var quest := 0
	var sold := false
	if won and (boss or rng.randf() < GameData.DROP_CHANCE):
		loot = _new_item(rng, boss)
		if bag.size() < GameData.BAG_SIZE:
			bag.append(loot)
		else:
			gold += Rules.sell_price(loot)
			sold = true
	if won:
		quest = _daily_win()
		add_count("boss", int(boss))
	var got_xp: int = (GameData.XP_WIN + stage * 10 if won else GameData.XP_LOSS + stage * 3) * scale
	var got_gold: int = (GameData.GOLD_WIN + stage * 3 if won else GameData.GOLD_LOSS + stage) * scale
	var out := _gain(got_xp, got_gold)
	gold += quest
	stage += int(won)
	out.merge({"loot": loot, "sold": sold, "quest": quest, "boss": boss and won})
	save()
	return out


## Canli mac odulu: asama atlatmaz, ganimet vermez; kazanmak arena galibiyetinden daha degerlidir.
func grant_online(won: bool) -> Dictionary:
	online_wins += int(won)
	online_losses += int(not won)
	var quest := _daily_win() if won else 0
	var bonus := GameData.ONLINE_BONUS if won else 1.0
	var got_xp := int((GameData.XP_WIN + stage * 10 if won else GameData.XP_LOSS + stage * 3) * bonus)
	var got_gold := int((GameData.GOLD_WIN + stage * 3 if won else GameData.GOLD_LOSS + stage) * bonus)
	var out := _gain(got_xp, got_gold)
	gold += quest
	out.merge({"loot": {}, "sold": false, "quest": quest, "boss": false})
	save()
	return out


func summary() -> String:
	return "%s · %d Galibiyet · %d Yenilgi" % [Rules.league(stage), wins, losses]


func save() -> void:
	if path == "":
		return
	var tmp := path + ".yeni"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"version": VERSION, "name": player_name, "cls": cls, "wins": wins,
		"losses": losses, "streak": streak, "best_streak": best_streak, "online_wins": online_wins, "online_losses": online_losses,
		"level": level, "xp": xp, "gold": gold, "stage": stage, "points": points, "spent": spent, "equipped": equipped, "bag": bag,
		"last_day": last_day, "day_streak": day_streak, "day_wins": day_wins, "counts": counts, "done": done, "seen_help": seen_help}))
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(_backup(path))
		DirAccess.rename_absolute(path, _backup(path))
	DirAccess.rename_absolute(tmp, path)
