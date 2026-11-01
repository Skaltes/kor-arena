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
		"max_hp": roundf((120.0 + prim["vit"] * 15.0 + level * 8.0 + bonus["hp"]) * power * 2.15),
		"atk": roundf((6.0 + main_stat * 1.6 + bonus["atk"]) * power),
		"def": roundf((prim["vit"] * 0.5 + bonus["def"]) * power),
		"crit": minf(60.0, 5.0 + prim["agi"] * 0.3 + bonus["crit"]),
		"dodge": minf(25.0, prim["agi"] * 0.25),
		"aspd": float(c["aspd"]) * minf(1.8, 1.0 + prim["agi"] * 0.006),
		"speed": c["speed"], "range": c["range"], "ranged": c["ranged"], "swing": c["swing"],
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


## Rakip, oyuncuyla ayni bicimde karakterdir: PvP'de buraya gercek oyuncunun kopyasi gelir.
static func make_opponent(level: int, arena: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var cls: String = _pick(rng, GameData.CLASSES.keys())
	var title: String = "%s %s" % [_pick(rng, GameData.ENEMY_NAMES), _pick(rng, GameData.ENEMY_TITLES)]
	var ch := new_character(title, cls, maxi(1, level + int(arena["offset"])), int(arena["gear"]), rng)
	ch["look"] = {"skin": _pick(rng, GameData.SKINS), "hair": _pick(rng, GameData.HAIRS), "cloth": Color(0.78, 0.3, 0.26)}
	return ch
