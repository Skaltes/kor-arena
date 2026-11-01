class_name GameData
## Oyunun dengesi ve icerigi. core/ klasoru sahneye dokunmaz; PvP'de sunucuda da calisir.

const MAX_LEVEL := 30
const SLOTS: Array[String] = ["weapon", "helmet", "armor", "accessory"]

const CLASSES: Dictionary = {
	"warrior": {
		"name": "Paladin", "desc": "Kılıç ve kalkanla dengeli savaşçı. Yüksek can ve sersemletme.",
		"main": "str", "range": 1.6, "aspd": 0.26, "speed": 4.6, "ranged": false, "swing": 0.75,
		"base": {"str": 12.0, "agi": 6.0, "int": 3.0, "vit": 12.0},
		"grow": {"str": 3.0, "agi": 1.0, "int": 0.5, "vit": 2.6},
		"skills": ["power", "lunge", "bash", "cry", "second", "whirl"], "weapons": ["sword"],
		"color": Color(0.71, 0.28, 0.18),
	},
	"assassin": {
		"name": "Berserker", "desc": "Çift baltasıyla hızlı ve ölümcül. Kritik vuruş ve zehir.",
		"main": "agi", "range": 1.4, "aspd": 0.37, "speed": 5.4, "ranged": false, "swing": 0.62,
		"base": {"str": 6.0, "agi": 12.0, "int": 4.0, "vit": 8.0},
		"grow": {"str": 1.2, "agi": 3.0, "int": 0.7, "vit": 2.2},
		"skills": ["backstab", "hamstring", "poison", "expose", "frenzy", "flurry"], "weapons": ["axe"],
		"color": Color(0.24, 0.48, 0.37),
	},
	"brute": {
		"name": "Titan", "desc": "Ağır balyozuyla yavaş vurur ama her darbesi yıkıcıdır.",
		"main": "str", "range": 1.9, "aspd": 0.26, "speed": 3.7, "ranged": false, "swing": 1.15,
		"base": {"str": 16.5, "agi": 3.0, "int": 3.0, "vit": 13.5},
		"grow": {"str": 3.8, "agi": 0.5, "int": 0.4, "vit": 2.85},
		"skills": ["smash", "crush", "quake", "iron", "rage", "ruin"], "weapons": ["sledge"],
		"color": Color(0.55, 0.36, 0.18),
	},
}

## kind: melee | proj | aoe_self | aoe_ground | self | dash
const GCD := 2.0 # bir yetenekten sonra digerine gecis suresi: her basis bir karar olsun

const SKILLS: Dictionary = {
	"power": {"name": "Güçlü Darbe", "unlock": 1, "cd": 8.0, "kind": "melee", "range": 1.9, "mult": 2.0, "windup": 0.8, "combo": {"fx": "slow", "bonus": 0.6}, "desc": "Ağır darbe. Yavaşlamış hedefe %60 fazla vurur."},
	"lunge": {"name": "Hamle", "unlock": 2, "cd": 12.0, "kind": "melee", "range": 2.3, "mult": 1.3, "windup": 0.6, "slow": {"pct": 0.3, "dur": 5.0}, "desc": "Hedefi 5 sn yavaşlatır. Güçlü Darbe'yi hazırlar."},
	"bash": {"name": "Kalkan Vuruşu", "unlock": 3, "cd": 15.0, "kind": "melee", "range": 1.9, "mult": 0.8, "stun": 0.9, "windup": 0.3, "desc": "Çok hızlı. Rakibin hazırlığını KESER ve sersemletir."},
	"cry": {"name": "Savaş Narası", "unlock": 5, "cd": 26.0, "kind": "self", "buff": {"atk": 0.35, "def": 0.25, "dur": 8.0}, "desc": "8 sn saldırı ve savunma artar."},
	"second": {"name": "İkinci Nefes", "unlock": 6, "cd": 30.0, "kind": "self", "heal": 0.18, "desc": "Canının %18'ini geri kazanır."},
	"whirl": {"name": "Kasırga", "unlock": 8, "cd": 20.0, "kind": "aoe_self", "radius": 3.4, "mult": 1.25, "windup": 1.0, "hits": [0.0, 0.44], "combo": {"fx": "stun", "bonus": 0.7}, "desc": "Uzun hazırlık. Sersemlemiş hedefe %70 fazla vurur."},

	"backstab": {"name": "Sırt Yaran", "unlock": 1, "cd": 9.0, "kind": "melee", "range": 1.75, "mult": 1.15, "force_crit": true, "windup": 0.6, "combo": {"fx": "dot", "bonus": 0.6}, "desc": "Hep kritik. Zehirli hedefe %60 fazla vurur."},
	"hamstring": {"name": "Topuk Kesiği", "unlock": 2, "cd": 14.0, "kind": "melee", "range": 1.75, "mult": 0.7, "windup": 0.3, "interrupt": true, "slow": {"pct": 0.5, "dur": 3.0}, "desc": "Çok hızlı. Rakibin hazırlığını KESER, yavaşlatır."},
	"poison": {"name": "Zehirli Balta", "unlock": 3, "cd": 12.0, "kind": "melee", "range": 1.75, "mult": 0.8, "windup": 0.55, "dot": {"mult": 0.4, "dur": 7.0}, "desc": "7 sn zehir. Sırt Yaran'ı hazırlar."},
	"expose": {"name": "Zayıf Nokta", "unlock": 5, "cd": 16.0, "kind": "melee", "range": 1.75, "mult": 1.0, "windup": 0.55, "weaken": {"def": -0.3, "dur": 6.0}, "desc": "6 sn savunmayı %30 düşürür. Balta Fırtınası'nı hazırlar."},
	"frenzy": {"name": "Kan Hırsı", "unlock": 6, "cd": 26.0, "kind": "self", "buff": {"atk": 0.3, "dur": 7.0}, "desc": "7 sn saldırı +%30."},
	"flurry": {"name": "Balta Fırtınası", "unlock": 8, "cd": 22.0, "kind": "melee", "range": 1.75, "mult": 0.8, "windup": 0.9, "hits": [0.0, 0.48, 1.32], "combo": {"fx": "weak", "bonus": 0.7}, "desc": "Zayıf Nokta'lı hedefe %70 fazla vurur."},

	"smash": {"name": "Balyoz Darbesi", "unlock": 1, "cd": 9.0, "kind": "melee", "range": 2.2, "mult": 2.3, "windup": 1.15, "combo": {"fx": "stun", "bonus": 0.6}, "desc": "Sersemlemiş hedefe %60 fazla vurur."},
	"crush": {"name": "Kemik Kırma", "unlock": 2, "cd": 15.0, "kind": "melee", "range": 2.2, "mult": 1.2, "windup": 0.9, "weaken": {"def": -0.25, "dur": 6.0}, "desc": "6 sn savunmayı düşürür. Yıkım'ı hazırlar."},
	"quake": {"name": "Yer Sarsıntısı", "unlock": 3, "cd": 16.0, "kind": "aoe_self", "radius": 3.6, "mult": 1.1, "stun": 0.8, "windup": 0.5, "desc": "Rakibin hazırlığını KESER ve sersemletir."},
	"iron": {"name": "Demir Deri", "unlock": 5, "cd": 24.0, "kind": "self", "buff": {"def": 0.5, "dur": 5.0}, "desc": "5 sn savunma +%50. Büyük darbeye karşı sakla."},
	"rage": {"name": "Öfke", "unlock": 6, "cd": 28.0, "kind": "self", "buff": {"atk": 0.4, "dur": 7.0}, "desc": "7 sn saldırı +%40."},
	"ruin": {"name": "Yıkım", "unlock": 8, "cd": 30.0, "kind": "melee", "range": 2.2, "mult": 4.5, "windup": 1.7, "combo": {"fx": "weak", "bonus": 0.8}, "desc": "En uzun hazırlık, en büyük darbe. Kesilebilir!"},
}

const RARITY: Array[Dictionary] = [
	{"name": "Sıradan", "color": Color(0.53, 0.51, 0.48), "mult": 1.0, "bonus": 0},
	{"name": "Sağlam", "color": Color(0.71, 0.74, 0.77), "mult": 1.25, "bonus": 1},
	{"name": "Nadir", "color": Color(0.44, 0.66, 0.88), "mult": 1.6, "bonus": 2},
	{"name": "Destansı", "color": Color(0.66, 0.42, 0.88), "mult": 2.1, "bonus": 3},
	{"name": "Efsanevi", "color": Color(0.94, 0.63, 0.19), "mult": 2.8, "bonus": 4},
]

const ARENA_DUEL: Dictionary = {"count": 1, "offset": 0, "power": 1.0, "ai": 0.65, "gear": 0}

const ENEMY_NAMES: Array[String] = ["Varg", "Krom", "Selene", "Thane", "Morra", "Dreth", "Ilya", "Korvan", "Nyx", "Vex"]
const ENEMY_TITLES: Array[String] = ["Kül Yürüyen", "Kemik Kıran", "Sessiz", "Kanlı", "Kor Dişli", "Demir Yürek"]

const SKINS: Array[Color] = [Color(0.95, 0.79, 0.65), Color(0.85, 0.64, 0.49), Color(0.66, 0.44, 0.29), Color(0.43, 0.27, 0.19)]
const HAIRS: Array[Color] = [Color(0.16, 0.11, 0.08), Color(0.42, 0.23, 0.12), Color(0.79, 0.64, 0.29), Color(0.85, 0.87, 0.89), Color(0.64, 0.13, 0.13)]
