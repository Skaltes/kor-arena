class_name GameData
## Oyunun dengesi ve icerigi. core/ klasoru sahneye dokunmaz; PvP'de sunucuda da calisir.

const MAX_LEVEL := 30
const SLOTS: Array[String] = ["weapon", "helmet", "armor", "accessory"]

const CLASSES: Dictionary = {
	"warrior": {
		"name": "Paladin", "desc": "Kılıç ve kalkanla dengeli savaşçı. Yüksek can ve sersemletme.",
		"main": "str", "hp_mult": 1.24, "range": 1.6, "aspd": 0.36, "speed": 4.6, "ranged": false, "swing": 0.8, "recover": 0.65,
		"base": {"str": 12.0, "agi": 6.0, "int": 3.0, "vit": 12.0},
		"grow": {"str": 4.6, "agi": 1.0, "int": 0.5, "vit": 3.3},
		"skills": ["power", "lunge", "bash", "cry", "second", "whirl", "wall", "verdict", "leap", "judge"], "weapons": ["sword"],
		"color": Color(0.71, 0.28, 0.18),
	},
	"assassin": {
		"name": "Berserker", "desc": "İki baltasıyla hızlı ve ölümcül. Kritik vuruş ve zehir.",
		"main": "agi", "hp_mult": 1.7, "range": 1.4, "aspd": 0.5, "speed": 5.4, "ranged": false, "swing": 0.65, "recover": 0.55,
		"base": {"str": 6.0, "agi": 12.0, "int": 4.0, "vit": 8.4},
		"grow": {"str": 1.2, "agi": 2.7, "int": 0.7, "vit": 1.45},
		"skills": ["backstab", "hamstring", "poison", "expose", "frenzy", "flurry", "crossguard", "leech", "boot", "rampage"], "weapons": ["axe"],
		"color": Color(0.24, 0.48, 0.37),
	},
	"brute": {
		"name": "Titan", "desc": "Ağır balyozuyla yavaş vurur ama her darbesi yıkıcıdır.",
		"main": "str", "hp_mult": 0.92, "range": 1.9, "aspd": 0.3, "speed": 3.7, "ranged": false, "swing": 1.15, "recover": 1.05,
		"base": {"str": 16.5, "agi": 3.0, "int": 3.0, "vit": 14.0},
		"grow": {"str": 4.8, "agi": 0.5, "int": 0.4, "vit": 4.3},
		"skills": ["smash", "crush", "quake", "grab", "frost", "ruin", "icearm", "trample", "spin", "triple"], "weapons": ["sledge"],
		"color": Color(0.55, 0.36, 0.18),
	},
}

## kind: melee | proj | aoe_self | aoe_ground | self | dash | guard
const GCD := 2.0 # eski sabit ortak bekleme; artik yalniz siper disi yetenekte ust sinir degil, bilgi icin

## Yetenegin hareket suresi (hazirlik + son vurus + toparlanma). Ortak bekleme buna esittir:
## hareket biter bitmez siradaki yetenek kullanilabilir (kullanici karari).
static func skill_lock(id: String) -> float:
	var sk: Dictionary = SKILLS[id]
	var extra: Array = sk.get("hits", [0.0])
	return float(sk.get("after", 0.55)) + float(sk.get("windup", 0.0)) + float(extra[-1])
const SKILL_REST := 0.7 # yetenek bitince duz vurusa gecmeden once soluklanma: hareket dogal biter (kullanici karari)
const PARRY_TIME := 0.35 # siperin ilk ani (kalkan kalktiktan sonra): bu surede inen darbe saldiriyi yarida keser
const PARRY_LAG := 0.6 # gecikme (gidis-donus sn) basina savusturma anina eklenen sure
const BASIC_GRACE := 1.0 # ortak bekleme bitince bu sure duz vurus baslamaz: hazir yetenegi basmaya firsat (kullanici karari)
const PARRY_REEL := 1.2 # parry yiyen saldiranin sarsinti suresi
const STAGGER_TIME := 0.5 # agir/kesme yeteneginin rakibi afallatma suresi
const COMBO_WINDOW := 2.2 # bu surede gelen sonraki isabet komboyu surdurur
const KNOCK_COMBO := 4 # rakip araya vurus sokamadan yenen bu kacinci isabet yere yatirir
const DOWN_TIME := 1.25 # yerde kalma (dusme + kalkma)
const KNOCK_PUSH := 0.7 # yere dusen geriye kayar (metre)
const PUSH_SPEED := 8.0 # itilen rakibin kayma hizi (m/sn)

const SKILLS: Dictionary = {
	"power": {"name": "Güçlü Darbe", "breaks": true, "unlock": 1, "cd": 4, "kind": "melee", "range": 1.9, "mult": 1.9, "windup": 0.75, "desc": "Ağır darbe."},
	"lunge": {"name": "Hamle", "unlock": 2, "cd": 5, "kind": "melee", "range": 2.3, "mult": 1.3, "windup": 0.6, "slow": {"pct": 0.3, "dur": 5.0}, "desc": "Hedefi 5 sn yavaşlatır."},
	"bash": {"name": "Tekme", "unlock": 3, "cd": 8, "kind": "melee", "range": 1.9, "mult": 0.8, "stun": 0.8, "windup": 0.4, "desc": "Çok hızlı. Rakibin hazırlığını KESER ve sersemletir."},
	"cry": {"name": "Savaş Narası", "unlock": 5, "cd": 12, "kind": "self", "windup": 0.5, "buff": {"atk": 0.35, "def": 0.25, "dur": 8.0}, "desc": "8 sn saldırı %35, savunma %25 artar."},
	"second": {"name": "İkinci Nefes", "unlock": 6, "cd": 20, "kind": "self", "windup": 0.6, "heal": 0.22, "desc": "Canının %22'sini geri kazanır. Hazırlıkta vurulursa boşa gider."},
	"whirl": {"name": "Kasırga", "breaks": true, "down": true, "unlock": 8, "cd": 9, "kind": "aoe_self", "radius": 3.4, "mult": 2.4, "windup": 1.1, "desc": "Uzun hazırlık, sıçrayıp dönerek tek güçlü darbe."},
	"wall": {"name": "Kalkan Duvarı", "unlock": 7, "cd": 9, "kind": "guard", "windup": 0.15, "dur": 1.1, "desc": "1,1 sn tüm hasarı engeller. Darbeden hemen önce basarsan saldırıyı yarıda keser."},
	"verdict": {"name": "Kutsal Hüküm", "breaks": true, "down": true, "unlock": 8, "cd": 8, "kind": "melee", "range": 1.9, "mult": 2.0, "windup": 1.5, "desc": "Kutsal güçle sert bir darbe."},

	"backstab": {"name": "Sırt Yaran", "breaks": true, "unlock": 1, "cd": 4, "kind": "melee", "range": 1.75, "mult": 1.6, "force_crit": true, "windup": 0.55, "desc": "Hep kritik."},
	"hamstring": {"name": "Topuk Kesiği", "unlock": 2, "cd": 7, "kind": "melee", "range": 1.75, "mult": 1.0, "windup": 0.35, "interrupt": true, "slow": {"pct": 0.5, "dur": 3.0}, "desc": "Çok hızlı. Rakibin hazırlığını KESER, yavaşlatır."},
	"poison": {"name": "Zehirli Balta", "unlock": 3, "cd": 6, "kind": "melee", "range": 1.75, "mult": 0.95, "windup": 0.5, "dot": {"mult": 0.28, "dur": 7.0}, "desc": "7 sn zehir."},
	"expose": {"name": "Zayıf Nokta", "breaks": true, "unlock": 5, "cd": 6, "kind": "melee", "range": 1.75, "mult": 1.9, "windup": 0.8, "desc": "Orta hızda sert bir kesik."},
	"frenzy": {"name": "Kan Hırsı", "unlock": 6, "cd": 15, "kind": "self", "windup": 0.5, "buff": {"atk": 0.3, "dur": 7.0}, "desc": "7 sn saldırı +%30."},
	"flurry": {"name": "Balta Fırtınası", "unlock": 8, "cd": 9, "kind": "melee", "range": 1.75, "mult": 1.05, "windup": 0.85, "hits": [0.0, 0.48, 1.32], "desc": "Üç vuruş."},
	"crossguard": {"name": "Çapraz Siper", "unlock": 7, "cd": 8, "kind": "guard", "windup": 0.15, "dur": 0.9, "desc": "0,9 sn tüm hasarı engeller. Darbeden hemen önce basarsan saldırıyı yarıda keser."},
	"leech": {"name": "Kan Emici", "breaks": true, "unlock": 8, "cd": 7, "kind": "melee", "range": 1.75, "mult": 1.4, "windup": 0.6, "leech": 0.7, "desc": "Verdiği hasarın %70'ini can olarak geri alır."},

	"smash": {"name": "Balyoz Darbesi", "breaks": true, "unlock": 1, "cd": 4.5, "kind": "melee", "range": 2.2, "mult": 0.85, "windup": 0.75, "desc": "Yavaş ve ağır darbe."},
	"crush": {"name": "Kemik Kırma", "breaks": true, "unlock": 2, "cd": 7, "kind": "melee", "range": 2.2, "mult": 0.7, "windup": 0.7, "desc": "Orta hızda sert bir darbe."},
	"quake": {"name": "Yer Sarsıntısı", "unlock": 3, "cd": 10, "kind": "aoe_self", "radius": 3.6, "mult": 1.0, "stun": 0.95, "windup": 0.5, "desc": "Rakibi 0,95 sn sersemletir, hazırlığını keser."},
	"grab": {"name": "Gırtlak Kavrama", "unlock": 5, "cd": 9, "kind": "melee", "range": 2.2, "mult": 1.0, "windup": 0.45, "grab": true, "stun": 0.6, "push": 1.8, "desc": "Hızlı. Rakip bir yeteneğe HAZIRLANIRKEN basarsan boğazından yakalayıp fırlatır, hazırlığını keser. Hazırlanmıyorsa boşa gider."},
	"frost": {"name": "Buz Mührü", "unlock": 6, "cd": 12, "kind": "melee", "range": 6.6, "mult": 0.35, "windup": 1, "freeze": 2.0, "desc": "Uzun büyü. Rakip hazırlık bitmeden bir yetenekle vurup bozamazsa 2 sn donar: hemen ardından Yıkım yetişir."},
	"ruin": {"name": "Yıkım", "breaks": true, "down": true, "unlock": 8, "cd": 14, "kind": "melee", "range": 2.2, "mult": 1.8, "windup": 1, "desc": "En uzun hazırlık, en büyük darbe. Kesilebilir!"},
	"icearm": {"name": "Buz Kolu", "unlock": 7, "cd": 12, "kind": "guard", "windup": 0.15, "dur": 0.8, "counter": true, "freeze": 0.7, "desc": "0,8 sn buzdan bir kalkan kaldırır, tüm hasarı engeller. Rakip bu sırada vurursa donar."},
	"trample": {"name": "Ezici Hamle", "unlock": 8, "cd": 11, "kind": "melee", "range": 2.2, "mult": 1.0, "windup": 0.45, "push": 0.25, "reel": 0.8, "after": 0.3, "slow": {"pct": 0.4, "dur": 4.0}, "desc": "Rakibi iter, 0,8 sn afallatır, 4 sn %40 yavaşlatır. Hemen ardından başka yetenek kullanabilirsin."},

	# Yeni yetenekler (sinif basina 10, kullanici karari): eldeki Mixamo paketlerinin kullanilmayan hareketlerinden
	"leap": {"name": "Gökten İniş", "breaks": true, "down": true, "unlock": 8, "cd": 12, "kind": "melee", "range": 2.2, "mult": 2.3, "windup": 0.95, "desc": "Havaya sıçrayıp kılıcını yukarıdan indirir. Rakibi yere serer."},
	"judge": {"name": "Yargı Kesiği", "breaks": true, "unlock": 8, "cd": 7, "kind": "melee", "range": 1.9, "mult": 1.9, "windup": 0.65, "push": 0.5, "desc": "Yukarıdan sert bir kesiş, rakibi geri iter."},
	"boot": {"name": "Sert Tekme", "unlock": 8, "cd": 11, "kind": "melee", "range": 1.6, "mult": 0.7, "windup": 0.45, "push": 0.6, "reel": 0.4, "desc": "Çok hızlı. Rakibi iter, hazırlığını keser ve sarsar."},
	"rampage": {"name": "Yıkıcı Seri", "breaks": true, "unlock": 8, "cd": 10, "kind": "melee", "range": 1.75, "mult": 1.1, "windup": 0.5, "hits": [0.0, 0.85], "desc": "İki baltayla iki ağır vuruş."},
	"spin": {"name": "Balyoz Çöküşü", "breaks": true, "unlock": 8, "cd": 12, "kind": "aoe_self", "radius": 3.2, "mult": 1.2, "windup": 0.6, "desc": "Balyozu başının üstüne kaldırıp yere çakar, çevresindekilere tek ağır darbe vurur."},
	"triple": {"name": "Demir Savuruş", "breaks": true, "unlock": 8, "cd": 14, "kind": "melee", "range": 2.2, "mult": 1.5, "windup": 0.5, "desc": "Balyozu arkadan getirip tek ve çok ağır bir savuruşla vurur."},
}

const RARITY: Array[Dictionary] = [
	{"name": "Sıradan", "color": Color(0.53, 0.51, 0.48), "mult": 1.0, "bonus": 0},
	{"name": "Sağlam", "color": Color(0.71, 0.74, 0.77), "mult": 1.25, "bonus": 1},
	{"name": "Nadir", "color": Color(0.44, 0.66, 0.88), "mult": 1.6, "bonus": 2},
	{"name": "Destansı", "color": Color(0.66, 0.42, 0.88), "mult": 2.1, "bonus": 3},
	{"name": "Efsanevi", "color": Color(0.94, 0.63, 0.19), "mult": 2.8, "bonus": 4},
]

const ARENA_DUEL: Dictionary = {"count": 1, "offset": 0, "power": 1.0, "ai": 0.65, "gear": 0}
const BOSS_EVERY := 5 # her bu kadar asamada bir Arena Efendisi: daha guclu, cift odul
const XP_WIN := 100
const XP_LOSS := 35
const GOLD_WIN := 30
const GOLD_LOSS := 10
const POINTS_PER_LEVEL := 2 # her seviye atlamada dagitilacak stat puani
const POINT_VALUE := 2.0 # bir puanin stat karsiligi
const DROP_CHANCE := 0.4 # galibiyette ganimet sansi; patron her zaman dusurur
const BAG_SIZE := 24 # canta dolunca ganimet kendiliginden satilir
const DAILY_WINS := 3 # gunluk gorev: bu kadar arena galibiyeti
const SLOT_NAMES := {"weapon": "Silah", "helmet": "Miğfer", "armor": "Zırh", "accessory": "Takı"}
const STAT_NAMES := {"atk": "Saldırı", "def": "Savunma", "hp": "Can", "crit": "Kritik"}
const ITEM_WORDS: Array[String] = ["Demir", "Kül", "Kan", "Kor"] # esyanin variant numarasina gore
const MAX_PLUS := 10 # demircide bir esyanin cikabilecegi en yuksek derece
const UPGRADE_STEP := 0.08 # her derece temel degerin bu kadarini ekler
const ONLINE_BONUS := 1.5 # canli galibiyet ayni asamadaki arena galibiyetinden bu kadar kat kazandirir
const ONLINE_MIN_TIME := 15.0 # bundan kisa suren canli mac kayda ve odule yazilmaz
## Arena asamasina gore unvan: [baslangic asamasi, ad]
const LEAGUES: Array = [[1, "Çırak"], [10, "Gladyatör"], [20, "Şampiyon"], [30, "Kor Şövalyesi"], [40, "Küllerin Efendisi"]]

## Basarimlar: stat degeri goal'e ulasinca bir kez altin verir. Degerler Profile.stat ile okunur.
const ACHIEVEMENTS: Array[Dictionary] = [
	{"id": "win1", "name": "İlk Kan", "desc": "İlk galibiyetini al.", "stat": "wins", "goal": 1, "gold": 50},
	{"id": "win10", "name": "Arena Emektarı", "desc": "10 maç kazan.", "stat": "wins", "goal": 10, "gold": 150},
	{"id": "win50", "name": "Kumların Kralı", "desc": "50 maç kazan.", "stat": "wins", "goal": 50, "gold": 600},
	{"id": "win200", "name": "Yaşayan Efsane", "desc": "200 maç kazan.", "stat": "wins", "goal": 200, "gold": 2500},
	{"id": "boss1", "name": "Efendi Düştü", "desc": "Bir Arena Efendisi yen.", "stat": "boss", "goal": 1, "gold": 200},
	{"id": "boss5", "name": "Efendiler Avcısı", "desc": "5 Arena Efendisi yen.", "stat": "boss", "goal": 5, "gold": 800},
	{"id": "stage10", "name": "Gladyatör", "desc": "10. aşamaya ulaş.", "stat": "stage", "goal": 10, "gold": 300},
	{"id": "stage20", "name": "Şampiyon", "desc": "20. aşamaya ulaş.", "stat": "stage", "goal": 20, "gold": 800},
	{"id": "stage40", "name": "Küllerin Efendisi", "desc": "40. aşamaya ulaş.", "stat": "stage", "goal": 40, "gold": 3000},
	{"id": "level8", "name": "Tam Donanım", "desc": "8. seviyeye ulaş, bütün yeteneklerin açılsın.", "stat": "level", "goal": 8, "gold": 200},
	{"id": "level20", "name": "Usta Savaşçı", "desc": "20. seviyeye ulaş.", "stat": "level", "goal": 20, "gold": 1000},
	{"id": "streak5", "name": "Durdurulamaz", "desc": "Üst üste 5 maç kazan.", "stat": "best_streak", "goal": 5, "gold": 300},
	{"id": "parry1", "name": "Demir Bilek", "desc": "İlk savuşturmanı yap.", "stat": "parry", "goal": 1, "gold": 60},
	{"id": "parry50", "name": "Geçilmez", "desc": "50 savuşturma yap.", "stat": "parry", "goal": 50, "gold": 700},
	{"id": "cut25", "name": "Sözünü Kesme", "desc": "Rakibin 25 yeteneğini hazırlıkta kes.", "stat": "cut", "goal": 25, "gold": 400},
	{"id": "classes", "name": "Üç Yol", "desc": "Üç sınıfla da galibiyet al.", "stat": "classes", "goal": 3, "gold": 300},
	{"id": "plus5", "name": "Çekiç ve Örs", "desc": "Bir eşyayı +5'e çıkar.", "stat": "best_plus", "goal": 5, "gold": 400},
	{"id": "chest10", "name": "Define Avcısı", "desc": "10 sandık aç.", "stat": "chest", "goal": 10, "gold": 300},
	{"id": "legend", "name": "Efsane Peşinde", "desc": "Efsanevi bir eşya bul.", "stat": "legend", "goal": 1, "gold": 1000},
	{"id": "online1", "name": "Gerçek Rakip", "desc": "İlk canlı maçını kazan.", "stat": "online_wins", "goal": 1, "gold": 200},
	{"id": "online25", "name": "Arenanın Korkusu", "desc": "25 canlı maç kazan.", "stat": "online_wins", "goal": 25, "gold": 1500},
]

const ENEMY_NAMES: Array[String] = ["Varg", "Krom", "Selene", "Thane", "Morra", "Dreth", "Ilya", "Korvan", "Nyx", "Vex"]
const ENEMY_TITLES: Array[String] = ["Kül Yürüyen", "Kemik Kıran", "Sessiz", "Kanlı", "Kor Dişli", "Demir Yürek"]

const SKINS: Array[Color] = [Color(0.95, 0.79, 0.65), Color(0.85, 0.64, 0.49), Color(0.66, 0.44, 0.29), Color(0.43, 0.27, 0.19)]
const HAIRS: Array[Color] = [Color(0.16, 0.11, 0.08), Color(0.42, 0.23, 0.12), Color(0.79, 0.64, 0.29), Color(0.85, 0.87, 0.89), Color(0.64, 0.13, 0.13)]

