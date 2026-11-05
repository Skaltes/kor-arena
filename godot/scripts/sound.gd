class_name SoundBank
extends Node
## Oyunun tum sesleri: kisa efektler ve iki parca arasinda yumusak gecisli muzik. Savas kodu bunu bilmez.
## Dosyalar assets/audio/ altindadir, ayarlar user://ayar.cfg dosyasina yazilir.

const FADE := 1.0
const VOICES := 18 # bir isabette 4-5 katman calar: sesler birbirini kesmesin
const PITCH := 0.1 # ayni ses arka arkaya tekrar etmesin diye rastgele perde farki (Feel Lab yontemi: makineli tufek gibi duyulmaz)
## grup: [dosya sayisi, seviye dB]
const GROUPS := {
	"blade": [4, -2.0],
	"clash": [3, -3.0],
	"click": [1, -10.0],
	"thit": [4, -1.0],
	"body": [3, -2.0], # her isabetin altindaki govde darbesi: sesi agir yapan katman
	"level": [1, -6.0], # seviye atlama: bu proje icin FFmpeg ile uretildi
	"coin": [1, -12.0], # altin sayaci
	"loot": [1, -7.0], # ganimet ve sandik acilisi
	# Sonniss GDC 2026 paketinden (ticari serbest, isim gerekmez; ham ses olarak dagitilmaz): LISANS_SONNISS.txt
	# Eski RPG paketi savurma/buyu/nara sesleri (kullanici: "kapi gicirtisi" gibi duyuluyordu) bunlarla degisti.
	"swing": [3, -12.9], # hava yaran savurma (344 Elemental Palette, CSD Woosh Debris, ESM swish)
	"tswing": [2, -1.8], # agir metal savurma (344 Metal Slow Whoosh, ESM derin ates vuzultusu): Titan
	"holy": [1, -11.0], # kutsal buyu (ESM Fantasy Game 2): Paladin narasi, ikinci nefes, hukum
	"dark": [2, -12.5], # karanlik buyu (Kopeikin Emotion and Magic): Berserker zehir, can emme, cilginlik
	"troar": [1, -13.2], # savas narasi (ESM Humanoid Creatures 4): Titan
	"tquake": [1, -11.3], # yer sarsan patlama (Federico Soler Trailer Booms 2)
	"tguard": [1, -4.5], # metal gumleme, siper (The Noisery Moaning Metal)
	"low": [1, -4.3], # derin darbe (Trailer Booms 2): olum, tekme
	"heavy": [2, 4.9], # cok agir darbe (Trailer Booms 2, CSD Colossal Impacts)
	"tthud": [1, 1.5], # karanlik agir tahta darbesi (344 Haunting Ambiences 3): yere dusus
	"ring": [1, -5.7], # metal cinlamasi (ESM HD Game Materials): kritik, savusturma
	"scut": [6, 2.5], # kilic kesigi, metalik (Historical Weapons Vol. 2): Paladin isabeti
	"punch": [5, -3.0], # govdeye yumruk/darbe (Cinematic Fight, ESM Anime Game): her isabetin govde katmani
	"hthud": [4, 1.5], # agir silah gumlemesi (David Dumais MWP2): Titan isabeti
	"gore": [1, -2.0], # en agir darbede ezilme (ESM Halloween)
	"splat": [1, -9.0], # kan sicramasi (ESM Tower Defense)
	"mhit": [1, 0.0], # celik celige carpma ve cinlama (David Dumais MWP2): savusturma
	"slice": [1, -12.0], # ozel kesik hissi (ESM Tower Defense): Yargi Kesigi, Paladin savurmasinin kenari
	"ice": [2, -9.0], # buz kirilmasi ve catlamasi (ESM, Alexander Kopeikin): donma
}
const MENU := "res://assets/audio/music/menu.ogg"
const BATTLE: Array[String] = ["res://assets/audio/music/savas1.ogg", "res://assets/audio/music/savas2.ogg"]

static var me: SoundBank

var music_volume := 0.6
var sfx_volume := 0.9
var counts := {} # test icin: hangi ses kac kez calindi
var current := ""

var _voices: Array[AudioStreamPlayer] = []
var _next := 0
var _streams := {}
var _deck: Array[AudioStreamPlayer] = []
var _active := 0
var _rng := RandomNumberGenerator.new()
var _last := {} # her grupta en son calan dosya


func _ready() -> void:
	me = self
	_rng.randomize()
	var limit := AudioEffectHardLimiter.new() # ayni anda cok ses: cikis asla bozulmaz
	limit.ceiling_db = -1.5
	AudioServer.add_bus_effect(0, limit)
	for bus: String in ["Muzik", "Efekt"]:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, bus)
		AudioServer.set_bus_send(i, "Master")
	for group: String in GROUPS:
		var list: Array[AudioStream] = []
		for n in int(GROUPS[group][0]):
			list.append(load("res://assets/audio/sfx/%s%d.ogg" % [group, n + 1]))
		_streams[group] = list
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "Efekt"
		add_child(p)
		_voices.append(p)
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Muzik"
		p.volume_db = -80.0
		add_child(p)
		_deck.append(p)
	music_volume = Settings.read("ses", "muzik", music_volume)
	sfx_volume = Settings.read("ses", "efekt", sfx_volume)
	_apply()


func _apply() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Muzik"), linear_to_db(maxf(music_volume, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Efekt"), linear_to_db(maxf(sfx_volume, 0.0001)))


func set_volumes(music: float, sfx: float) -> void:
	music_volume = music
	sfx_volume = sfx
	_apply()
	Settings.write("ses", "muzik", music)
	Settings.write("ses", "efekt", sfx)


## gain: ek ses (dB), pitch: perde carpani (agir darbe daha pes ve dolgun duyulur)
func play(group: String, gain := 0.0, pitch := 1.0) -> void:
	var list: Array = _streams[group]
	var p := _voices[_next]
	_next = (_next + 1) % VOICES
	var pick := _rng.randi_range(0, list.size() - 1)
	if list.size() > 1 and pick == int(_last.get(group, -1)): # ayni dosya art arda calmaz
		pick = (pick + 1 + _rng.randi_range(0, list.size() - 2)) % list.size()
	_last[group] = pick
	p.stream = list[pick]
	p.volume_db = GROUPS[group][1] + gain
	p.pitch_scale = _rng.randf_range(1.0 - PITCH, 1.0 + PITCH) * pitch
	p.play()
	counts[group] = int(counts.get(group, 0)) + 1


func menu_music() -> void:
	_music(MENU)


func battle_music() -> void:
	_music(BATTLE[_rng.randi_range(0, BATTLE.size() - 1)])


func _music(path: String) -> void:
	if path == current:
		return
	current = path
	var old := _deck[_active]
	_active = 1 - _active
	var fresh := _deck[_active]
	var stream: AudioStreamOggVorbis = load(path)
	stream.loop = true
	fresh.stream = stream
	fresh.volume_db = -40.0
	fresh.play()
	var tw := create_tween().set_parallel()
	tw.tween_property(fresh, "volume_db", 0.0, FADE)
	tw.tween_property(old, "volume_db", -60.0, FADE)
	tw.chain().tween_callback(old.stop)
