class_name Rules
## Karakter kurallari: stat hesabi, esya ve rakip uretimi.


static func _pick(rng: RandomNumberGenerator, list: Array) -> Variant:
	return list[rng.randi_range(0, list.size() - 1)]


static func calc_stats(ch: Dictionary, power: float = 1.0) -> Dictionary:
	var c: Dictionary = GameData.CLASSES[ch["cls"]]
	var level: int = ch["level"]
	var prim := {}
	for k: String in c["base"]:
		prim[k] = float(c["base"][k]) + float(c["grow"][k]) * (level - 1)
	var spent: Dictionary = ch.get("spent", {})
	# Cevikligi ana olan sinifta bir puan hem saldiri hem kritik/hiz verir; bu yuzden daha az sayilir
	prim[c["main"]] += float(spent.get("main", 0)) * GameData.POINT_VALUE * (0.55 if c["main"] == "agi" else 1.0)
	prim["agi"] += float(spent.get("agi", 0)) * GameData.POINT_VALUE
	prim["vit"] += float(spent.get("vit", 0)) * GameData.POINT_VALUE
	var bonus := {"atk": 0.0, "def": 0.0, "hp": 0.0, "crit": 0.0}
	for slot: String in GameData.SLOTS:
		var it: Variant = ch["equipped"].get(slot)
		if it == null:
			continue
		for k: String in it["stats"]:
			if prim.has(k):
				prim[k] += float(it["stats"][k])
			else:
				bonus[k] += float(it["stats"][k])
	var main_stat: float = prim[c["main"]]
	return {
		"level": level,
		"max_hp": roundf((120.0 + prim["vit"] * 15.0 + level * 8.0 + bonus["hp"]) * power * 0.82 * float(c.get("hp_mult", 1.0))), # raunt kisa surer (kullanici istegi; eskisi 2,15 / 1,45 / 0,95); sinif dengesi hp_mult
		"atk": roundf((6.0 + main_stat * 1.6 + bonus["atk"]) * power),
		"def": roundf((prim["vit"] * 0.5 + bonus["def"]) * power),
		"crit": minf(60.0, 5.0 + prim["agi"] * 0.3 + bonus["crit"]),
		"aspd": float(c["aspd"]) * minf(1.8, 1.0 + prim["agi"] * 0.006),
		"speed": c["speed"], "range": c["range"], "ranged": c["ranged"], "swing": c["swing"], "recover": c["recover"],
	}


static func make_item(slot: String, level: int, rarity: int, cls: String, rng: RandomNumberGenerator) -> Dictionary:
	var budget: float = (4.0 + level * 2.2) * float(GameData.RARITY[rarity]["mult"])
	var stats := {}
	var type := slot
	match slot:
		"weapon":
			type = _pick(rng, GameData.CLASSES[cls]["weapons"])
			stats["atk"] = roundf(budget * 1.1)
		"armor":
			stats["def"] = roundf(budget)
			stats["hp"] = roundf(budget * 2.5)
		"helmet":
			stats["def"] = roundf(budget * 0.55)
			stats["hp"] = roundf(budget * 1.2)
		"accessory":
			stats["crit"] = roundf(1.0 + rarity * 1.2)
			stats["atk"] = roundf(budget * 0.35)
	return {"slot": slot, "type": type, "rarity": rarity, "level": level, "stats": stats,
		"variant": rng.randi_range(0, 3)}


static func new_character(char_name: String, cls: String, level: int, rarity: int, rng: RandomNumberGenerator) -> Dictionary:
	var ch := {
		"name": char_name, "cls": cls, "level": level,
		"look": {"skin": GameData.SKINS[0], "hair": GameData.HAIRS[0], "cloth": GameData.CLASSES[cls]["color"]},
		"equipped": {},
	}
	for slot: String in GameData.SLOTS:
		ch["equipped"][slot] = make_item(slot, level, rarity, cls, rng)
	return ch


## Arena asamasinin rakibi: asama ilerledikce seviye ve zekasi artar, patron asamalari bir adim onde gider.
static func stage_foe(stage: int) -> Dictionary:
	var boss := stage % GameData.BOSS_EVERY == 0
	var hard := boss and stage > GameData.BOSS_EVERY # ilk patron yeni oyuncuyu duvara carpmasin
	var level := mini(1 + (stage - 1) * 3 / 4 + int(hard), GameData.MAX_LEVEL)
	return {"level": level, "gear": int(hard), "ai": minf(0.35 + stage * 0.02, 0.85) + (0.1 if boss else 0.0), "boss": boss}


## Ganimet nadirligi: patron en az Saglam verir, ust dereceler seyrektir.
static func roll_rarity(rng: RandomNumberGenerator, boss: bool) -> int:
	var r := rng.randf()
	var rarity := 4 if r > 0.985 else 3 if r > 0.93 else 2 if r > 0.75 else 1 if r > 0.4 else 0
	return maxi(rarity, int(boss))


static func item_name(it: Dictionary) -> String:
	var word: String = GameData.ITEM_WORDS[int(it.get("variant", 0)) % GameData.ITEM_WORDS.size()]
	var plus := int(it.get("plus", 0))
	return "%s %s %s%s" % [GameData.RARITY[int(it["rarity"])]["name"], word, GameData.SLOT_NAMES[it["slot"]], " +%d" % plus if plus > 0 else ""]


static func item_stats(it: Dictionary) -> String:
	var parts: Array[String] = []
	for k: String in it["stats"]:
		parts.append("%s +%d" % [GameData.STAT_NAMES.get(k, k), int(it["stats"][k])])
	return ", ".join(parts)


## Esyalari karsilastirmak icin kaba guc puani.
static func item_power(it: Dictionary) -> float:
	var s: Dictionary = it["stats"]
	return float(s.get("atk", 0)) * 2.0 + float(s.get("def", 0)) * 1.5 + float(s.get("hp", 0)) * 0.3 + float(s.get("crit", 0)) * 3.0


## Yeni esya giyilince statlar nasil degisir: [ad, fark] listesi.
static func item_diff(it: Dictionary, worn: Dictionary) -> Array:
	var out := []
	for k: String in GameData.STAT_NAMES:
		var change := int(it["stats"].get(k, 0)) - int(worn["stats"].get(k, 0))
		if change != 0:
			out.append([GameData.STAT_NAMES[k], change])
	return out


## Karakterin tek sayilik gucu: arayuzde gelisimi gosterir, savas hesabina girmez.
static func score(ch: Dictionary) -> int:
	var s := calc_stats(ch)
	return int(float(s["atk"]) * 6.0 + float(s["max_hp"]) * 0.2 + float(s["def"]) * 3.0 + float(s["crit"]) * 4.0)


static func league(stage: int) -> String:
	var name_now: String = GameData.LEAGUES[0][1]
	for row: Array in GameData.LEAGUES:
		if stage >= int(row[0]):
			name_now = row[1]
	return name_now


static func sell_price(it: Dictionary) -> int:
	return int((5 + int(it["level"]) * 2) * (int(it["rarity"]) + 1) * (1.0 + int(it.get("plus", 0)) * 0.5))


## Demirci: derece arttikca ve esya degerlendikce pahalilasir.
static func upgrade_cost(it: Dictionary) -> int:
	return (40 + int(it["level"]) * 8) * (int(it.get("plus", 0)) + 1) * (int(it["rarity"]) + 2) / 2


## Temel deger bir kez saklanir ki derece artislari birbirine binmesin.
static func raise_item(it: Dictionary) -> void:
	if not it.has("base"):
		it["base"] = it["stats"].duplicate()
	it["plus"] = int(it.get("plus", 0)) + 1
	for k: String in it["base"]:
		if k != "crit":
			it["stats"][k] = maxf(float(it["stats"][k]) + 1.0, roundf(float(it["base"][k]) * (1.0 + GameData.UPGRADE_STEP * it["plus"])))


## Bir seviye icin gereken tecrube.
static func xp_need(level: int) -> int:
	return 120 + level * 35


## Rakip, oyuncuyla ayni bicimde karakterdir: PvP'de buraya gercek oyuncunun kopyasi gelir.
static func make_opponent(level: int, arena: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var cls: String = _pick(rng, GameData.CLASSES.keys())
	var title: String = "%s %s" % [_pick(rng, GameData.ENEMY_NAMES), _pick(rng, GameData.ENEMY_TITLES)]
	var ch := new_character(title, cls, maxi(1, level + int(arena["offset"])), int(arena["gear"]), rng)
	ch["look"] = {"skin": _pick(rng, GameData.SKINS), "hair": _pick(rng, GameData.HAIRS), "cloth": Color(0.78, 0.3, 0.26)}
	var points: int = (int(ch["level"]) - 1) * GameData.POINTS_PER_LEVEL
	ch["spent"] = {"main": points / 2, "vit": points - points / 2} # rakip de oyuncu gibi gelisir
	return ch
