class_name GameMain
extends Node3D
## Oyun akisi: sinif secimi -> savas -> sonuc. Savas kurallari core/ icindedir;
## bu dosya yalnizca komut gonderir ve olaylari ekrana yansitir.
## Canli 1v1: odayi acan savasi calistirir, katilan gelen durumu aynalayarak gosterir
## (iki oyuncu da kendini solda gorur).

const TEST_LEVEL := 8
const BOT_OFFER := 20.0 # hizli macta rakip cikmazsa bu kadar saniye sonra bot onerilir
const TEST_FOES := ["Kukla", "Düz Vuruş", "Bot", "Usta Bot"]
const CAM_FOV := 30.0
const CAM_LOOK_Y := 1.12
const CAM_HEIGHT := 1.28 # Doom Forge gibi alcak ve yakin: savascilar ekrani doldurur
const CAM_DIST := 7.7
const FIELD_WIDTH := 7.3 # kadrajda her zaman gorunen savas alani genisligi (metre)
const CAM_NEAR := 5.6 # takip kamerasinin en yakin uzakligi
const CAM_MARGIN := 3.6 # iki savascinin disinda kadraja giren pay (metre)
const CAM_FOLLOW := 2.2 # kamera yetisme hizi: yumusak, sarsintisiz
const COMBO_WINDOW := 2.2 # bu surede gelen sonraki isabet komboyu surdurur
const STATE_EVERY := 2 # 30 adimda 15 durum
const PREDICT_LIMIT_MS := 1500 # bu surede onay gelmezse tahmin geri alinir
const SNAP_DISTANCE := 2.0 # bundan buyuk farkta karakter dogrudan yerine gecer

const SKILL_COLORS := {
	"power": Color(1.0, 0.72, 0.3), "lunge": Color(1.0, 0.9, 0.55), "bash": Color(0.5, 0.75, 1.0), "cry": Color(1.0, 0.55, 0.2), "second": Color(0.4, 1.0, 0.5), "whirl": Color(1.0, 0.8, 0.4),
	"backstab": Color(0.75, 0.4, 1.0), "hamstring": Color(0.95, 0.3, 0.45), "poison": Color(0.45, 1.0, 0.3), "expose": Color(1.0, 0.3, 0.6), "frenzy": Color(1.0, 0.2, 0.2), "flurry": Color(0.85, 0.5, 1.0),
	"smash": Color(1.0, 0.6, 0.2), "crush": Color(0.95, 0.9, 0.75), "quake": Color(0.95, 0.55, 0.25), "slam": Color(1.0, 0.5, 0.3), "frost": Color(0.55, 0.85, 1.0), "ruin": Color(1.0, 0.35, 0.05),
	"wall": Color(0.6, 0.85, 1.0), "verdict": Color(1.0, 0.92, 0.6), "crossguard": Color(0.6, 0.85, 1.0), "leech": Color(0.9, 0.12, 0.25), "icearm": Color(0.6, 0.9, 1.0), "leap": Color(1.0, 0.85, 0.45), "judge": Color(1.0, 0.95, 0.75), "boot": Color(0.95, 0.6, 0.4), "rampage": Color(1.0, 0.25, 0.3), "spin": Color(1.0, 0.65, 0.3), "triple": Color(0.85, 0.75, 0.6), "trample": Color(0.85, 0.6, 0.35),
}
const NET_GRACE := 0.15 # gecikme henuz olculmediyse
## Saldiri yeteneklerinin hazirlik sesi: [grup, ek dB, perde]. Her yetenek baska bir imza; yeni dosya yok, mevcut sesler katmanlanir.
const CAST_CUES := {
	"power": [["heavy", -7.0, 0.8]], "lunge": [["swing", -3.0, 1.25]], "bash": [["low", -5.0, 1.35]],
	"whirl": [["tswing", -3.0, 0.8], ["swing", -6.0, 1.1]], "verdict": [["ring", -4.0, 0.8], ["holy", -2.0, 1.0]],
	"backstab": [["blade", -8.0, 1.45]], "hamstring": [["swing", -4.0, 1.55]], "poison": [["dark", -2.0, 1.1]],
	"expose": [["ring", -4.0, 1.35]], "flurry": [["swing", -2.0, 1.15], ["blade", -9.0, 1.3]], "leech": [["dark", -2.0, 0.85]],
	"smash": [["troar", -7.0, 1.0]], "crush": [["tthud", -7.0, 1.25]], "quake": [["tguard", -4.0, 0.7]],
	"slam": [["troar", -6.0, 1.1], ["swing", -4.0, 0.85]], "frost": [["ice", -3.0, 1.15]], "ruin": [["troar", -2.0, 0.82], ["heavy", -6.0, 0.7]],
	"trample": [["tthud", -4.0, 1.0]],
	"leap": [["heavy", -6.0, 0.9], ["swing", -4.0, 0.9]], "judge": [["slice", 0.0, 1.0], ["ring", -8.0, 1.1]], "boot": [["low", -5.0, 1.5]],
	"rampage": [["swing", -2.0, 1.0], ["blade", -9.0, 1.2]], "spin": [["tswing", -2.0, 0.85]], "triple": [["tswing", -3.0, 0.8]],
}
const HEAVY := ["smash", "ruin", "power"]
const SELF_RISE := ["second", "cry", "frenzy"]

enum Mode { AI, HOST, CLIENT }

var _arena: ArenaView
var _fx: Effects
var _hud: Hud
var _net: NetSession
var _camera: Camera3D
var _cam_x := 0.0
var _cam_d := CAM_DIST
var _previews: Array[CharacterView] = []
var _views: Array[CharacterView] = []

var _mode := Mode.AI
var _battle: Battle
var _me: Battle.Ent
var _foe: Battle.Ent
var _brains: Array[Brain] = []
var _cls := "warrior"
var _name := ""
var _rival_name := ""
var _rival_cls := ""
var _paused := false
var _acc := 0.0
var _ending := 0.0
var _hold_t := 0.0 # geri sayim / raunt arasi: tus basilamaz
var _round_title := ""
var _combo: Array[int] = [0, 0] # art arda isabet sayisi (vuran basina)
var _combo_at: Array[float] = [-9.0, -9.0]
var _ticks := 0
var _i_am_ready := false
var _rival_ready := false

var _in_battle := false
var _pred_id := ""
var _pred_time := 0
var _net_target := {}
var _last_skill := ""
var _profile: Profile
var _forfeited := false
var _search := 0 # hizli mac aramasi; iptal edilince eski bot onerisi gecersiz olur
var _testing := false # Test Modu: odul ve kayit yok
var _test_cls := "warrior"
var _test_foe := 0
var _test_free := false # bekleme sureleri kapali
var _test_immortal := false # Test Modu: istenirse kimse olmez (kullanici: varsayilan normal mac, olum acik)
var _reward := {}
var test: TestRunner # yalnizca gelistirici testlerinde dolu
var _slow_time := 0.0
var _low_quality := false
var _stats := {} # mac sonu ekrani: hasar, en buyuk vurus, savusturma, kesme
var _clock := 0.0 # macin gercek suresi; canli macta katilan taraf savasi hesaplamaz
var _new_ach: Array[Dictionary] = []


func _ready() -> void:
	# Test parametreleriyle acilista oyuncunun kaydina dokunulmaz
	_profile = Profile.open(Profile.PATH) if OS.get_cmdline_user_args().is_empty() else Profile.new()
	if _profile.path == "":
		_profile.level = TEST_LEVEL
		_profile.stage = 11
		var test_rng := RandomNumberGenerator.new()
		_profile.equipped = Rules.new_character("", "warrior", TEST_LEVEL, 2, test_rng)["equipped"]
	_cls = _profile.cls
	_name = _profile.player_name
	_arena = ArenaView.new()
	add_child(_arena)
	if Version.phone() or Settings.quality() == Settings.Quality.LOW:
		_low_quality = true
		_arena.set_low_quality()
	_fx = Effects.new()
	add_child(_fx)
	_camera = Camera3D.new()
	_camera.fov = CAM_FOV
	add_child(_camera)
	_camera.make_current()
	_hud = Hud.new()
	add_child(_hud)
	_net = NetSession.new()
	_net.name = "Net"
	add_child(_net)
	add_child(SoundBank.new())
	_hud.play_ai.connect(_start_ai)
	_hud.host_room.connect(_host_room)
	_hud.join_room.connect(_join_room)
	_hud.cancel_online.connect(_leave_online)
	_hud.class_changed.connect(_on_class_changed)
	_hud.skill_pressed.connect(_use_skill)
	_hud.rematch.connect(_on_rematch)
	_hud.back.connect(_leave_online)
	_hud.forfeit.connect(_on_forfeit)
	_hud.pause_pressed.connect(_on_pause)
	_hud.quick_match.connect(_quick_match)
	_hud.bot_match.connect(_bot_match)
	_hud.test_mode.connect(_start_test)
	_hud.test_action.connect(_on_test_action)
	_hud.leave_match.connect(_leave_match)
	_hud.quality_changed.connect(func() -> void:
		if Settings.quality() == Settings.Quality.LOW and not _low_quality:
			_low_quality = true
			_arena.set_low_quality())
	_net.role_set.connect(func(is_host: bool) -> void: _mode = Mode.HOST if is_host else Mode.CLIENT)
	_hud.character_closed.connect(func() -> void:
		_name = _hud.name_memo
		_show_select())
	_net.joined.connect(_on_rival_joined)
	_net.failed.connect(_on_net_failed)
	_net.disconnected.connect(_on_net_lost)
	_net.status.connect(_hud.set_lobby_status)
	_net.match_data.connect(_on_match_data)
	_net.state_received.connect(_on_state)
	_net.events_received.connect(_on_remote_events)
	_net.skill_received.connect(_on_remote_skill)
	_net.ready_received.connect(_on_rival_ready)
	_net.pause_received.connect(_on_remote_pause)
	_net.restart_received.connect(_on_remote_restart)
	_hud.restart_pressed.connect(_restart_now)
	_show_select()
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		test = TestRunner.new()
		test.m = self
		add_child(test)
		test.start(args)


func _exit_tree() -> void:
	_net.close()
	_release_statics()


## Kapanista sinif duzeyindeki onbellekler oyun motorundan once bosaltilir. Bosaltilmazsa yayinlanan exe
## kapanirken cizim sunucusu gittikten sonra doku ve modelleri silmeye calisir ve cokebilir.
func _release_statics() -> void:
	IconLibrary._cache.clear()
	Mats._cache.clear()
	Effects._dot_tex = null
	Effects._arc_tex = null
	Effects._streak_tex = null
	CharacterView._library = null
	CharacterView._hero = null
	CharacterView._models = {}
	if CharacterView._weapons != null:
		CharacterView._weapons.free()
		CharacterView._weapons = null
	Settings._cfg = null
	SoundBank.me = null


func _clear_views() -> void:
	if _battle != null:
		_battle.release()
	for v in _previews + _views:
		v.queue_free()
	_previews.clear()
	_views.clear()


func _show_select() -> void:
	_testing = false
	Engine.time_scale = 1.0
	_clear_views()
	_fx.clear()
	_battle = null
	_in_battle = false
	_show_hero()
	var daily := 0
	if _profile.path != "":
		var now := int(Time.get_unix_time_from_system())
		daily = _profile.claim_daily(Time.get_date_string_from_system(), Time.get_date_string_from_unix_time(now - 86400))
	_hud.record_text = _profile.summary()
	_hud.ai_text = "Arena · Aşama %d" % _profile.stage
	_hud.profile = _profile
	_hud.show_select(_cls, _name)
	if daily > 0:
		_hud.announce("Günlük Ödül: +%d Altın" % daily)
	if _profile.path != "" and not _profile.seen_help: # ilk acilista kurallar bir kez gosterilir
		_profile.seen_help = true
		_profile.save()
		_hud.screens.help()
	SoundBank.me.menu_music()


func _show_hero() -> void:
	for v in _previews:
		v.queue_free()
	_previews.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var v := CharacterView.new()
	add_child(v)
	v.setup(_profile.character("", _cls))
	v.rotation.y = 0.35
	_previews.append(v)


## Secilen ad ve sinif bir sonraki acilisa kalir.
func _remember(cls: String, player_name: String) -> void:
	_cls = cls
	_name = player_name
	_profile.cls = cls
	_profile.player_name = player_name
	_profile.save()


func _on_class_changed(cls: String) -> void:
	_remember(cls, _name)
	if _battle == null:
		_show_hero()

func _begin(a: Dictionary, b: Dictionary, seed_value: int, my_team: int, title := "SAVAŞ!") -> void:
	_search += 1
	_clear_views()
	_fx.clear()
	_battle = Battle.new([[{"ch": a, "stats": Rules.calc_stats(a)}], [{"ch": b, "stats": Rules.calc_stats(b)}]], seed_value)
	_me = _battle.ents[my_team]
	_foe = _battle.ents[1 - my_team]
	if my_team == 1:
		for e in _battle.ents:
			e.pos.x = -e.pos.x
			e.face = -e.face
	_brains = []
	_spawn_views()
	_acc = 0.0
	_ending = 0.0
	_ticks = 0
	_reward = {}
	_clock = 0.0
	_stats = {"dmg": 0, "best": 0, "parry": 0, "cut": 0}
	_combo = [0, 0]
	_new_ach = []
	Engine.time_scale = 1.0
	if test != null:
		test.on_match_start()
	_pred_id = ""
	_net_target.clear()
	_set_paused(false) # yeni mac: duraklatma penceresi de kapanir (yeniden baslatmada acik kalmasin)
	_in_battle = true
	_i_am_ready = false
	_rival_ready = false
	_hud.show_battle(_me, _foe, _mode == Mode.AI)
	_round_title = title
	_hold_t = 0.0
	if _mode == Mode.CLIENT: # katilan taraf savasi isletmez: ilk raunt sayimini kendi gosterir, sonrakiler hostun olayindan gelir
		_on_round_start({"round": 1, "count": Battle.COUNTDOWN, "wins": [0, 0]})
	else:
		_battle.start_round(not _testing)
	SoundBank.me.battle_music()


func _spawn_views() -> void:
	for e in _battle.ents:
		var v := CharacterView.new()
		add_child(v)
		v.setup(e.ch, e)
		_views.append(v)


## Raunt basi: karakterler yeniden kurulur (olum dususu, kumas, donma sifirlanir), sayim gosterilir.
func _on_round_start(ev: Dictionary) -> void:
	var n: int = ev["round"]
	if n > 1:
		for v in _views:
			v.queue_free()
		_views.clear()
		_spawn_views()
		_fx.clear()
		_hud.cast_stop("A", "")
		_hud.cast_stop("B", "")
	var w: Array = ev.get("wins", [0, 0])
	_hud.set_rounds(int(w[_me.team]), int(w[_foe.team]))
	var title := _round_title if n == 1 else "RAUNT %d" % n
	if float(ev["count"]) > 0.0:
		_hold_t = float(ev["count"])
		_hud.countdown(title, float(ev["count"]))
	else:
		_hud.announce(title)


## Raunt bitti: kim aldi, skor.
func _on_round_end(ev: Dictionary) -> void:
	var w: Array = ev["wins"]
	_hud.set_rounds(int(w[_me.team]), int(w[_foe.team]))
	_hold_t = Battle.ROUND_GAP
	_hud.announce("RAUNT SENİN" if int(ev["winner"]) == _me.team else "RAUNT RAKİBİN")
	for v in _views:
		if v.ent.team == int(ev["winner"]):
			v.celebrate()


func _start_ai(cls: String, player_name: String, bot := false) -> void:
	_mode = Mode.AI
	_remember(cls, player_name)
	var seed_value := randi()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := Rules.stage_foe(_profile.stage)
	var hero := _profile.character(player_name, cls)
	var foe := Rules.make_opponent(st["level"], {"offset": 0, "gear": st["gear"]}, rng)
	if st["boss"]:
		foe["name"] = "Arena Efendisi"
	if bot:
		foe["name"] = "Bot · %s" % foe["name"]
	_forfeited = false
	_reward = {}
	_begin(hero, foe, seed_value, 0, "ARENA EFENDİSİ" if st["boss"] else "AŞAMA %d" % _profile.stage)
	_brains = [Brain.new(_foe, st["ai"], rng)]


func _quick_match(cls: String, player_name: String) -> void:
	_mode = Mode.HOST
	_remember(cls, player_name)
	_net.quick(player_name, cls)
	_hud.show_lobby("Rakip aranıyor...", "Herkes eşit: 8. seviye, tüm yetenekler açık.")
	_search += 1
	var search := _search
	await get_tree().create_timer(BOT_OFFER).timeout
	if search == _search:
		_hud.offer_bot()


## Test Modu: butun yetenekler acik, odul ve kayit yok. Olum acik; Olumsuzluk dugmesiyle kapatilir.
func _start_test(cls: String, player_name: String) -> void:
	_mode = Mode.AI
	_remember(cls, player_name)
	_testing = true
	var seed_value := randi()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_forfeited = false
	_reward = {}
	_begin(_fighter(player_name, cls, rng), _fighter(TEST_FOES[_test_foe], _test_cls, rng), seed_value, 0)
	_battle.immortal = _test_immortal
	_apply_test_foe()
	_show_test_panel()


func _apply_test_foe() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_brains = []
	if _test_foe >= 2:
		_brains.append(Brain.new(_foe, 0.5 if _test_foe == 2 else 1.0, rng))
	_foe.atk_t = 99999.0 if _test_foe == 0 else 0.4


func _show_test_panel() -> void:
	_hud.show_test_panel({
		"restart": "Yeniden Oyna",
		"me": "Sınıfım: %s" % GameData.CLASSES[_cls]["name"],
		"cls": "Rakip: %s" % GameData.CLASSES[_test_cls]["name"],
		"foe": "Davranış: %s" % TEST_FOES[_test_foe],
		"free": "Bekleme: %s" % ("Kapalı" if _test_free else "Açık"),
		"immortal": "Ölümsüzlük: %s" % ("Açık" if _test_immortal else "Kapalı"),
		"heal": "Canları Doldur",
	})


func _next_class(cls: String) -> String:
	var list: Array = GameData.CLASSES.keys()
	return list[(list.find(cls) + 1) % list.size()]


func _on_test_action(what: String) -> void:
	match what:
		"restart": # ayni sinif ve rakiple test modu bastan acilir
			if _paused:
				_set_paused(false)
			_start_test(_cls, _name)
		"me":
			_start_test(_next_class(_cls), _name)
		"cls":
			_test_cls = _next_class(_test_cls)
			_start_test(_cls, _name)
		"foe":
			_test_foe = (_test_foe + 1) % TEST_FOES.size()
			_start_test(_cls, _name)
		"free":
			_test_free = not _test_free
			_show_test_panel()
		"immortal":
			_test_immortal = not _test_immortal
			_battle.immortal = _test_immortal
			_show_test_panel()
		"heal":
			for e in _battle.ents:
				e.hp = float(e.s["max_hp"])


func _bot_match() -> void:
	_net.close()
	_start_ai(_cls, _name, true)


func _host_room(cls: String, player_name: String) -> void:
	_mode = Mode.HOST
	_remember(cls, player_name)
	_net.host()
	_hud.show_lobby("Oda açılıyor...", "Kodu arkadaşına gönder. Kurulum ve VPN gerekmez.")


func _join_room(cls: String, player_name: String, code: String) -> void:
	_mode = Mode.CLIENT
	_remember(cls, player_name)
	_hud.show_lobby("Bağlanılıyor...", "")
	_net.join(code, player_name, cls)


func _fighter(player_name: String, cls: String, rng: RandomNumberGenerator) -> Dictionary:
	return Rules.new_character(player_name, cls, TEST_LEVEL, 1, rng)


func _on_rival_joined(player_name: String, cls: String) -> void:
	_rival_name = player_name
	_rival_cls = cls
	_start_host_match()


func _start_host_match() -> void:
	var seed_value := randi()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var data := {"seed": seed_value, "a": _fighter(_name, _cls, rng), "b": _fighter(_rival_name, _rival_cls, rng)}
	_net.send_match(data)
	_begin(data["a"], data["b"], seed_value, 0)


func _on_match_data(data: Dictionary) -> void:
	_begin(data["a"], data["b"], data["seed"], 1)


func _on_state(data: PackedFloat32Array) -> void:
	if test != null:
		test.on_state()
	if _battle != null and not _battle.over:
		var shown: Array[Vector2] = []
		for e in _battle.ents:
			shown.append(e.pos)
		_battle.restore(data, true)
		for e in _battle.ents:
			_net_target[e.id] = e.pos
			if shown[e.id].distance_to(e.pos) < SNAP_DISTANCE:
				e.pos = shown[e.id]
		_keep_prediction()


func _on_remote_events(list: Array) -> void:
	if _battle == null:
		return
	for ev: Dictionary in list:
		if ev.has("pos"):
			ev["pos"] = Vector2(-ev["pos"].x, ev["pos"].y)
		_battle.events.append(ev)


func _on_remote_skill(id: String) -> void:
	if _battle != null and not _battle.over:
		if test != null:
			test.on_remote_skill(id)
		_battle.command({"ent": 1, "type": "skill", "skill": id})


func _on_forfeit() -> void:
	if _testing:
		_show_select()
	elif _mode == Mode.AI and _in_battle and not _battle.over:
		_set_paused(false)
		_forfeited = true
		_battle.surrender(_me.team)


func _set_paused(on: bool, who := "") -> void:
	_paused = on
	_hud.show_pause(on, _testing, who)


## Canli mac (arkadaslarla) da duraklatilabilir (kullanici istegi): duraklatan taraf rakibe bildirir, oda sahibi savasi
## ilerletmeyi keser; iki taraftan biri "Devam Et" deyince ikisinde de surer.
func _on_pause() -> void:
	if not _in_battle or _battle == null or _battle.over:
		return
	if not _paused and (_hold_t > 0.0 or _battle.pause_t > 0.0): # 3-2-1 geri sayim / raunt arasi: HUD sayaci gercek saatle akar, kayardi
		return
	if _mode == Mode.AI:
		_set_paused(not _paused)
	else:
		_set_paused(not _paused, "Sen duraklattın" if not _paused else "")
		_net.send_pause(_paused)


func _on_remote_pause(on: bool) -> void:
	if _mode == Mode.AI or not _in_battle or _battle == null or _battle.over:
		return
	_set_paused(on, "Rakip duraklattı" if on else "")


## Maç sonu ekranina gidenler: odul, mac sayilari, yeni basarimlar.
func _result_info() -> Dictionary:
	var s := _stats.duplicate()
	s["time"] = int(_clock)
	var why := "Teslim olunca ödül verilmez."
	if _mode != Mode.AI:
		why = "15 saniyeden kısa canlı maç ödül vermez."
	if _testing:
		why = "Test Modu ödül vermez."
	return {"reward": _reward, "stats": s, "ach": _new_ach, "why": why,
		"note": "Galibiyet serisi: %d" % _profile.streak if _profile.streak >= 2 else ""}


## Mac biter: kayit, odul, mac sayaclari ve basarimlar tek yerde islenir.
func _settle(won: bool) -> void:
	_profile.record(won, _cls)
	if _mode == Mode.AI and not _forfeited: # teslim olmak odul getirmez, yoksa bedava tecrube olur
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		_reward = _profile.grant(won, rng)
	elif _mode != Mode.AI and _clock >= GameData.ONLINE_MIN_TIME:
		_reward = _profile.grant_online(won)
	_profile.note_match(_stats["parry"], _stats["cut"])
	_new_ach = _profile.check_achievements()


func _on_rematch() -> void:
	if _testing:
		_start_test(_cls, _name)
		return
	if _mode == Mode.AI:
		_start_ai(_cls, _name)
		return
	_i_am_ready = true
	_hud.set_result_note("Rakibin hazır olması bekleniyor...")
	_net.send_ready(_cls)
	_try_rematch()


func _on_rival_ready(cls: String) -> void:
	_rival_ready = true
	if _mode == Mode.HOST:
		_rival_cls = cls
	if not _i_am_ready:
		_hud.set_result_note("Rakibin tekrar savaşmak istiyor.")
	_try_rematch()


func _try_rematch() -> void:
	if _mode == Mode.HOST and _i_am_ready and _rival_ready:
		_start_host_match()


func _on_net_failed(message: String) -> void:
	_search += 1
	_net.close()
	_mode = Mode.AI
	_hud.show_message(message)


func _on_net_lost() -> void:
	if _mode == Mode.AI:
		return
	print("baglanti koptu")
	if _in_battle and _battle != null and not _battle.over: # rakip savasin ortasinda gitti: galibiyet
		_search += 1
		_net.close()
		_battle.over = true
		_battle.winner = _me.team
		_settle(true)
		_mode = Mode.AI
		_in_battle = false
		SoundBank.me.menu_music()
		var info := _result_info()
		info["ended"] = true
		info["note"] = "Rakip maçtan ayrıldı. Zafer senin."
		_hud.show_result(true, false, _cls, info)
		return
	_leave_online()
	_hud.show_message("Rakibin bağlantısı koptu.")


## Canli macta oyuncu kendisi ayrilir: yenilgi sayilir, odul yok.
func _leave_match() -> void:
	if _in_battle and _battle != null and not _battle.over and _mode != Mode.AI:
		_forfeited = true
		_profile.record(false, _cls)
	_leave_online()


func _leave_online() -> void:
	_search += 1
	_net.close()
	_mode = Mode.AI
	_show_select()


func _use_skill(id: String) -> void:
	if _battle == null or _battle.over or _paused or _hold_t > 0.0:
		return
	_hud.press_feedback(id, _battle.can_cast(_me, id) or _battle.can_queue(_me, id))
	if _mode == Mode.CLIENT:
		var guard: bool = GameData.SKILLS[id]["kind"] == "guard" # parry beklemez
		if float(_me.cds.get(id, 0.0)) > 0.4 or (not guard and (_pred_id != "" or _me.gcd > 0.4)):
			return
		if test != null:
			test.on_skill_sent()
		_net.send_skill(id)
		if _pred_id == "" and _can_predict(id):
			_predict(id)
	else:
		_battle.command({"ent": _me.id, "type": "skill", "skill": id})


func _can_predict(id: String) -> bool:
	var sk: Dictionary = GameData.SKILLS[id]
	if not _me.alive or not _me.skills.has(id) or float(_me.cds.get(id, 0.0)) > 0.0 or _battle.stopped(_me) or _me.basic_t > 0.0:
		return false
	if sk["kind"] == "guard":
		return true
	if _me.gcd > 0.0:
		return false
	return not sk.has("range") or _me.pos.distance_to(_foe.pos) <= float(sk["range"])


## Katilan oyuncu: hareket tusla ayni anda baslar, hasar yine hosttan gelir.
## Hazirlik ag gecikmesi kadar uzatilir ki silah, hasar geldigi anda insin.
func _predict(id: String) -> void:
	_pred_id = id
	_pred_time = Time.get_ticks_msec()
	var extra := clampf(_net.rtt_ms / 1000.0, 0.0, 0.5) if _net.rtt_ms > 0 else 0.15
	_show_cast(_me.id, id, float(GameData.SKILLS[id].get("windup", 0.0)) + extra, extra)
	_keep_prediction()


## Host onayi gelene kadar bekleme gostergesi geri sicramasin
func _keep_prediction() -> void:
	if _pred_id == "":
		return
	var sk: Dictionary = GameData.SKILLS[_pred_id]
	var spent := (Time.get_ticks_msec() - _pred_time) / 1000.0
	_me.cds[_pred_id] = maxf(float(sk["cd"]) - spent, 0.0)
	if sk["kind"] != "guard":
		_me.gcd_max = GameData.skill_lock(_pred_id)
		_me.gcd = maxf(_me.gcd_max - spent, 0.0)


func _update_client(delta: float) -> void:
	for e in _battle.ents:
		e.basic_t = maxf(0.0, e.basic_t - delta) # hostta da ayni sure isler; tus erken gonderilmez
		if _net_target.has(e.id):
			e.pos = e.pos.move_toward(_net_target[e.id], float(e.s["speed"]) * 1.35 * delta)
	if _pred_id != "" and Time.get_ticks_msec() - _pred_time > PREDICT_LIMIT_MS:
		_drop_prediction(true)


## Katilan oyuncunun tusla baslattigi hareket host tarafinda baslamadi: hareket yumusakca beklemeye doner.
func _drop_prediction(timed_out := false) -> void:
	_views[_me.id].cancel_action()
	_hud.cast_stop("A", "")
	_pred_id = ""
	if test != null:
		test.on_prediction_rejected() if timed_out else test.on_prediction_queued()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_ESCAPE:
		_on_escape()
		return
	if not _in_battle or _battle.over:
		return
	var ids: Array = GameData.CLASSES[_cls]["skills"]
	var n := -1
	if event.keycode >= KEY_1 and event.keycode <= KEY_9:
		n = event.keycode - KEY_1
	elif event.keycode >= KEY_KP_1 and event.keycode <= KEY_KP_9: # sayi tus takimi da calisir
		n = event.keycode - KEY_KP_1
	elif event.keycode == KEY_0 or event.keycode == KEY_KP_0: # 10. yetenek (kullanici karari: sinif basina 10)
		n = 9
	if n >= 0 and n < ids.size():
		_use_skill(ids[n])
	elif event.keycode == KEY_R and not _testing:
		_restart_now()
	elif event.keycode == KEY_SPACE:
		_on_pause()
	elif event.keycode == KEY_P and _testing: # Test Modu: P ile duraklat / surdur
		_on_pause()


## Esc: once acik pencere kapanir, sonra duraklatma surer ya da acilir; canli macta oyun durmaz, menu acilir.
func _on_escape() -> void:
	if _hud.close_overlay():
		return
	if not _in_battle or _battle == null or _battle.over:
		return
	if _mode == Mode.AI or _paused:
		_on_pause()
	else:
		_hud.screens.online_menu(_cls)


## Pencere arkaya gecince yapay zeka maci kendiliginden durur.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and test == null and _mode == Mode.AI and _in_battle and _battle != null \
			and not _battle.over and not _paused:
		_set_paused(true)


func _process(delta: float) -> void:
	_watch_speed(delta)
	if _battle != null:
		if _mode != Mode.CLIENT and not _paused and not _battle.over:
			_acc += delta
			while _acc >= Battle.STEP:
				_acc -= Battle.STEP
				for v in _views:
					if v.ent != null:
						v.prev_pos = v.ent.pos
				for br in _brains:
					br.update(_battle, Battle.STEP)
				_battle.tick()
				_ticks += 1
				if _test_free and _testing:
					_me.cds.clear()
					_me.gcd = 0.0
				if _mode == Mode.HOST and _ticks % STATE_EVERY == 0:
					_net.send_state(_battle.snapshot())
					_foe.grace = clampf(_net.rtt_ms / 1000.0 if _net.rtt_ms > 0 else NET_GRACE, 0.0, Battle.MAX_GRACE)
		# 30 adimlik savas ile ekran karesi arasindaki kesir: karakter iki adim arasinda tam yerine konur
		var frac := clampf(_acc / Battle.STEP, 0.0, 1.0) if _mode != Mode.CLIENT and not _paused and not _battle.over else -1.0
		for v in _views:
			v.step_frac = frac
		_drain_events()
		if _in_battle and not _paused and not _battle.over:
			_clock += delta
			_hold_t = maxf(0.0, _hold_t - delta)
		if _mode == Mode.CLIENT and _in_battle:
			_update_client(delta)
		if _in_battle:
			_hud.update_battle(_me, _foe)
		if _ending > 0.0:
			_ending -= delta
			if _ending <= 0.0:
				_in_battle = false
				SoundBank.me.menu_music()
				_hud.again_text = "Sonraki Rakip" if _mode == Mode.AI and not _testing and _battle.winner == _me.team else "Tekrar Savaş"
				_hud.show_result(_battle.winner == _me.team, _mode == Mode.AI, _cls, _result_info())
				if _rival_ready:
					_hud.set_result_note("Rakibin tekrar savaşmak istiyor.")
	_update_camera()


## 5 sn boyunca 40 kare/sn alti gorulurse kalite kendiliginden duser.
func _watch_speed(delta: float) -> void:
	if _low_quality or Settings.quality() != Settings.Quality.AUTO or Time.get_ticks_msec() < 6000:
		return
	_slow_time = _slow_time + delta if Engine.get_frames_per_second() < 40.0 else 0.0
	if _slow_time > 5.0:
		_low_quality = true
		_arena.set_low_quality()


func _at(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, p.y)


func _drain_events() -> void:
	var list := _battle.events
	_battle.events = []
	if list.is_empty():
		return
	if _mode == Mode.HOST:
		_net.send_events(list)
	for ev in list:
		match ev["t"]:
			"attack":
				_views[ev["ent"]].attack()
				_swing_later(ev["ent"], float(_battle.ents[ev["ent"]].s["swing"]))
				if _mode == Mode.CLIENT: # katilan taraf vurus kilidini hostun olayindan ogrenir
					_battle.ents[ev["ent"]].basic_t = float(_battle.ents[ev["ent"]].s["swing"]) + float(_battle.ents[ev["ent"]].s["recover"])
			"cast":
				_on_cast(ev)
			"queued", "refused": # host tusu hemen baslatamadi: tahminle baslayan hareket birakilir, gercek yetenek gelince senkron oynar
				if _mode == Mode.CLIENT and ev["ent"] == _me.id and ev["skill"] == _pred_id:
					_drop_prediction()
			"hit":
				_on_hit(ev)
				if ev["src"] == _me.id and ev["ent"] != _me.id:
					_stats["dmg"] += int(ev["dmg"])
					_stats["best"] = maxi(_stats["best"], int(ev["dmg"]))
			"whiff": # kavrama bosa gitti: rakip hazirlanmiyordu
				_fx.number(_at(_battle.ents[ev["ent"]].pos, 1.95), "Boşa", Color(0.85, 0.85, 0.85), 48)
			"death":
				if _last_skill != "":
					_fx.title(_at(_battle.ents[ev["ent"]].pos, 1.9), "ÖLÜMCÜL DARBE!", Color(1.0, 0.25, 0.15))
				_battle.ents[ev["ent"]].alive = false
				_battle.ents[ev["ent"]].hp = 0.0
				SoundBank.me.play("low")
				Engine.time_scale = 0.35 # son darbe agir cekimde gorunur; savas zaten bitti, sonucu etkilemez
				get_tree().create_timer(0.55, true, false, true).timeout.connect(func() -> void: Engine.time_scale = 1.0)
			"heal":
				var healed := _battle.ents[ev["ent"]]
				_fx.number(_at(healed.pos, 1.95), "+%d" % ev["amount"], Color(0.5, 1.0, 0.5))
			"aoe":
				_on_aoe(ev)
			"blocked":
				_on_blocked(ev)
			"parry":
				_on_parry(ev)
				_stats["parry"] += int(ev["ent"] == _me.id)
			"interrupt":
				_views[ev["ent"]].interrupt()
				SoundBank.me.play("clash")
				_stats["cut"] += int(ev["ent"] == _foe.id)
				_hud.cast_stop("A" if ev["ent"] == _me.id else "B", "")
				if not ev.get("stagger", false): # afallama yazisiz, animasyonla belli olur
					var cut: String = GameData.SKILLS[ev["skill"]]["name"] if GameData.SKILLS.has(ev.get("skill", "")) else ""
					_fx.title(_at(_battle.ents[ev["ent"]].pos, 1.9), "KESİLDİ: " + cut if cut != "" else "KESİLDİ!", Color(0.5, 0.8, 1.0)) # hangi yetenegin kesildigi okunur
					_fx.flash(_at(_battle.ents[ev["ent"]].pos, 1.3), Color(0.5, 0.8, 1.0), 2.4)
			"round_start":
				if not (_mode == Mode.CLIENT and int(ev["round"]) == 1): # ilk raunt sayimini katilan taraf zaten gosterdi
					_on_round_start(ev)
			"down": # agir darbe ya da kombo: rakip yere yikilir
				_views[ev["ent"]].knockdown()
				SoundBank.me.play("tthud", -1.0, 0.85)
				_fx.dust(_at(_battle.ents[ev["ent"]].pos, 0.1), 26, 2.2)
				_fx.title(_at(_battle.ents[ev["ent"]].pos, 1.9), "YERE SERİLDİ!", Color(1.0, 0.5, 0.2))
			"round_end":
				_on_round_end(ev)
			"end":
				if ev.has("wins"):
					_hud.set_rounds(int(ev["wins"][_me.team]), int(ev["wins"][_foe.team]))
				_battle.over = true
				_battle.winner = ev["winner"]
				_ending = 2.8 # olum dususu yere oturana kadar gorunsun
				for v in _views:
					if v.ent.team == _battle.winner:
						v.celebrate()
				_hud.announce("ZAFER!" if ev["winner"] == _me.team else "YENİLDİN")
				if not _testing: # Test Modu kayit ve odul vermez
					_settle(ev["winner"] == _me.team)


func _on_cast(ev: Dictionary) -> void:
	var id: String = ev["skill"]
	if ev["ent"] == _me.id:
		if test != null:
			test.on_my_cast()
		if id == _pred_id: # hareket tus aninda baslamisti, tekrar oynatilmaz
			_pred_id = ""
			return
	_show_cast(ev["ent"], id, ev.get("dur", 0.0))


func _show_cast(ent: int, id: String, dur: float, extra: float = 0.0) -> void:
	var v := _views[ent]
	var sk: Dictionary = GameData.SKILLS[id]
	var color: Color = SKILL_COLORS[id]
	v.play_skill(id, color, extra)
	var key := "A" if ent == _me.id else "B"
	if dur > 0.0:
		_hud.cast_start(key, id, dur, color)
	if ent == _me.id:
		_hud.show_my_skill(id, color)
	var brute: bool = _battle.ents[ent].ch["cls"] == "brute"
	if sk["kind"] == "guard":
		SoundBank.me.play("tguard" if brute else "swing")
	elif sk["kind"] == "self":
		SoundBank.me.play("troar" if brute else ("holy" if _battle.ents[ent].ch["cls"] == "warrior" else "dark"))
	else:
		_swing_later(ent, float(sk.get("windup", 0.0)) + extra)
		for cue: Array in CAST_CUES.get(id, []): # hazirlik basinda yetenege ozel ses: kullanilan yetenek kulaktan taninir
			SoundBank.me.play(cue[0], cue[1], cue[2])
	var e := _battle.ents[ent]
	_fx.title(_at(e.pos + Vector2(0.9 * signf(e.pos.x - _battle.ents[1 - e.id].pos.x), 0.0), 2.0), sk["name"], color)
	if sk["kind"] == "guard":
		_fx.aura(v, color, float(sk["dur"]))
		_fx.ring(e.pos, 1.5, color, 0.3)
	elif sk["kind"] == "self":
		_fx.aura(v, color, 1.1)
		_fx.rise(v, color)
		_fx.ring(e.pos, 2.2, color, 0.7)
		_fx.burst(_at(e.pos, 1.0), color, 26, 2.2)
	else:
		_fx.charge(v, color, maxf(float(sk.get("windup", 0.3)), 0.4))


## Savurma sesi silah inmeye baslarken duyulur; hareket kesildiyse calinmaz.
func _swing_later(ent: int, wind: float) -> void:
	get_tree().create_timer(maxf(wind - CharacterView.STRIKE_TIME, 0.0)).timeout.connect(func() -> void:
		if _in_battle and ent < _views.size() and _views[ent]._action_t > 0.0:
			_swing_sound(_battle.ents[ent].ch["cls"]))


func _swing_sound(cls: String) -> void:
	match cls:
		"brute":
			SoundBank.me.play("tswing")
		"warrior": # uzun kilic: hava yaran savurma + ince celik kenari (eski metal surtunme sesi gicirti gibiydi, kaldirildi)
			SoundBank.me.play("swing")
			SoundBank.me.play("slice", -5.0, 1.15)
		_:
			SoundBank.me.play("swing")


## Vurus sesi silaha gore degisir; agir yetenek ve kritik ustune katman ekler.
## Darbenin agirligi: hasarin rakibin canina orani (yaklasik 0,2 hafif normal vurus - 1,6 en agir yetenek).
func _hit_weight(ev: Dictionary) -> float:
	var e := _battle.ents[ev["ent"]]
	return clampf(float(ev["dmg"]) / maxf(float(e.s["max_hp"]) * 0.1, 1.0), 0.2, 1.6)


func _hit_sound(ev: Dictionary, skill: String) -> void:
	if ev["dot"]:
		return
	if ev["absorbed"]:
		SoundBank.me.play("clash")
		return
	var cls: String = _battle.ents[ev["src"]].ch["cls"]
	var heavy := cls == "brute"
	# Darbe agirligina gore katmanlar: hafif vurus ince ve kisa, agir darbe pes, dolgun ve govdeyi sarsan (kullanici istegi:
	# vurus hissi). Ilk katman silaha gore: kilic kesigi, balta dogramasi (kisa ve keskin), balyoz gumlemesi.
	var w: float = _hit_weight(ev)
	var low_pitch := 1.08 - w * 0.18
	var light := skill == "" and w < 0.6 # duz vurus: belirgin daha hafif duyulur
	# Gercek kayit sesleri (Sonniss) ana katman, eski sentetik sesler altta ince destek.
	match cls:
		"assassin": # balta: kisa, kuru ve keskin bir dogrus + sert govde darbesi
			SoundBank.me.play("thit", -6.0 + w * 3.0, 1.32 - w * 0.12)
			SoundBank.me.play("punch", -1.0 + w * 3.0, 1.12)
			SoundBank.me.play("blade", -11.0 + w * 2.0, 1.12)
		"brute": # balyoz: agir gumleme
			SoundBank.me.play("hthud", -3.0 + w * 3.0, low_pitch)
			SoundBank.me.play("thit", -8.0 + w * 2.0, low_pitch)
		_: # kilic: gercek celik kesigi + ince parlak kenar
			SoundBank.me.play("scut", -3.0 + w * 3.0, low_pitch + 0.04)
			SoundBank.me.play("blade", -10.0 + w * 2.0, low_pitch)
	SoundBank.me.play("punch", (-9.0 if light else -5.0) + w * 3.0, low_pitch)
	SoundBank.me.play("clash", (-14.0 if light else -11.0) + w * 2.0, 1.1) # zirha carpan metal
	if not light:
		SoundBank.me.play("splat", -3.0 + w * 3.0, low_pitch + 0.1)
	if not light and (w >= 0.6 or (skill != "" and float(CharacterView.MOTIONS[skill].get("knock", 0.0)) >= 0.3)):
		SoundBank.me.play("tthud" if heavy else "low", -4.0 + w * 2.0, low_pitch)
	if w >= 1.0:
		SoundBank.me.play("gore", -2.0, 0.95)
		SoundBank.me.play("heavy", -6.0, 0.9)
	if ev["crit"]:
		SoundBank.me.play("ring")


## Siper darbeyi tuttu: hasar yok, saldiri surer.
func _on_blocked(ev: Dictionary) -> void:
	var e := _battle.ents[ev["ent"]]
	SoundBank.me.play("clash")
	_views[ev["src"]].impact_pause("")
	_fx.flash(_at(e.pos, 1.3), Color(0.6, 0.85, 1.0), 1.4)
	_fx.number(_at(e.pos, 1.95), "Engellendi", Color(0.6, 0.85, 1.0), 48)


## Parry: saldiran yarida kesilir ve sarsilir, savunan serbest kalir.
func _on_parry(ev: Dictionary) -> void:
	var e := _battle.ents[ev["ent"]]
	var src := _battle.ents[ev["src"]]
	_views[src.id].interrupt()
	_hud.cast_stop("A" if src.id == _me.id else "B", "SAVUŞTURULDU!")
	SoundBank.me.play("mhit")
	SoundBank.me.play("clash", -4.0)
	SoundBank.me.play("ring", -3.0)
	var at := _at((e.pos + src.pos) * 0.5, 1.3)
	_fx.flash(at, Color(1.0, 0.95, 0.75), 3.2)
	_fx.burst(at, Color(1.0, 0.8, 0.4), 24, 2.6)
	_fx.title(_at(e.pos, 1.9), "SAVUŞTURMA!", Color(1.0, 0.9, 0.5))
	if ev.get("freeze", false):
		_ice_burst(src)


## Donma: buz parcaciklari ve halka; karakterin buzla kaplanmasi CharacterView'da.
func _ice_burst(e: Battle.Ent) -> void:
	var ice := Color(0.6, 0.9, 1.0)
	SoundBank.me.play("ice")
	SoundBank.me.play("ring", -6.0)
	_fx.flash(_at(e.pos, 1.2), ice, 3.0)
	_fx.burst(_at(e.pos, 1.1), ice, 40, 2.4, 0.07, 0.7)
	_fx.ring(e.pos, 1.7, ice, 0.6)


func _on_hit(ev: Dictionary) -> void:
	var e := _battle.ents[ev["ent"]]
	if _mode == Mode.CLIENT: # bir sonraki durum gelene kadar can cubugu da hemen dussun
		e.hp = maxf(0.0, e.hp - float(ev["dmg"]))
	var crit: bool = ev["crit"]
	var skill: String = ev.get("skill", "")
	var dot: bool = ev["dot"]
	_last_skill = skill
	_hit_sound(ev, skill)
	if test != null and ev["src"] == _me.id and not dot:
		test.on_my_hit()
	if not dot and not ev["absorbed"] and ev["src"] != e.id: # kombo: rakip araya vurus sokmadan art arda isabetler
		var src: int = ev["src"]
		_combo[src] = _combo[src] + 1 if _clock - _combo_at[src] < COMBO_WINDOW else 1
		_combo_at[src] = _clock
		_combo[e.id] = 0
		if _combo[src] >= 2:
			_hud.combo("A" if src == _me.id else "B", _combo[src])
	if not dot:
		if Version.phone() and Settings.vibration():
			Input.vibrate_handheld(60 if skill != "" or crit else 25)
		var w := _hit_weight(ev)
		_views[e.id].react(skill, crit, w, _views[ev["src"]].global_position)
		if ev["absorbed"]:
			_views[e.id].block()
		_views[ev["src"]].impact_pause(skill, w, true)
		var tip: Node3D = _views[ev["src"]].weapon_tip
		if tip != null and is_instance_valid(tip): # silahin degdigi yerde kivilcim: zirha carpan celik
			var at: Vector3 = tip.global_position.lerp(_at(e.pos, 1.25), 0.35)
			var push := signf(e.pos.x - _battle.ents[ev["src"]].pos.x)
			_fx.burst(at, Color(1.0, 0.82, 0.45), int(4 + 8 * w), 1.0 + 1.0 * w, 0.03, 0.2) # temas parlamasi
			if not ev["absorbed"]: # kivilcimlar darbenin gittigi yone fiskirir (eskiden her yone dagiliyordu)
				_fx.sparks(at, Vector3(push, 0.45, 0.0), Color(1.0, 0.78, 0.4), int(10 + 22 * w), 4.5 + 4.0 * w)
			if w >= 0.8:
				_fx.flash(at, Color(1.0, 0.92, 0.75), 0.6 + 0.5 * w)
	if not dot and not ev["absorbed"]:
		var away := signf(e.pos.x - _battle.ents[ev["src"]].pos.x)
		_fx.blood(_at(e.pos, 1.3), 56 if crit or skill != "" else 22, 3.4, away)
		_fx.stain(e.pos + Vector2(randf_range(-0.6, 0.6), randf_range(-0.4, 0.4)), randf_range(0.08, 0.2))
	if skill != "":
		_skill_impact(skill, e, signf(e.pos.x - _battle.ents[ev["src"]].pos.x))
	elif dot:
		_fx.burst(_at(e.pos, 1.25), Color(0.44, 0.88, 0.3), 10, 1.6)
	elif crit:
		_fx.flash(_at(e.pos, 1.25), Color(1.0, 0.7, 0.4), 1.4)
	var beside_head := _at(e.pos, 1.75) + Vector3(signf(e.pos.x - _battle.ents[ev["src"]].pos.x) * 0.5, 0, 0)
	if ev["absorbed"]:
		_fx.number(_at(e.pos, 1.95), "Emildi", Color(0.56, 0.88, 1.0), 48)
	elif crit:
		_fx.number(beside_head, str(ev["dmg"]), Color(1.0, 0.32, 0.12), 118)
	elif dot:
		_fx.number(beside_head, str(ev["dmg"]), Color(0.55, 0.9, 0.35), 60)
	else:
		_fx.number(beside_head, str(ev["dmg"]), Color(0.95, 0.14, 0.1), 86)


## Her yetenegin isabeti kendine ozgu gorunur; normal saldirida bunlarin hicbiri yoktur.
func _skill_impact(skill: String, e: Battle.Ent, side: float) -> void:
	var color: Color = SKILL_COLORS[skill]
	var chest := _at(e.pos, 1.2)
	match skill:
		"power", "smash":
			_fx.slash(chest, side, color, 3.2)
			_fx.flash(chest, color, 2.4)
			_fx.crater(e.pos, color, 1.8)
		"ruin":
			_fx.slash(chest, side, color, 4.4)
			_fx.flash(chest, Color(1.0, 0.8, 0.5), 4.0)
			_fx.crater(e.pos, color, 3.0)
			_fx.ring(e.pos, 4.5, color, 0.7)
			_fx.burst(_at(e.pos, 0.3), color, 40, 5.0)
		"lunge":
			_fx.thrust(chest, side, color)
			_fx.flash(chest, color, 1.4)
		"bash":
			_fx.flash(chest, color, 2.6)
			_fx.ring(e.pos, 1.6, color, 0.35)
		"backstab":
			_fx.cross(chest, color, 2.2)
			_fx.flash(chest, color, 1.8)
		"hamstring":
			_fx.slash(_at(e.pos, 0.35), side, color, 2.0)
		"poison":
			_fx.burst(chest, color, 26, 2.2)
			_fx.flash(chest, color, 1.2)
		"expose":
			_fx.cross(chest, color, 1.6)
			_fx.ring(e.pos, 1.3, color, 0.5)
		"flurry":
			_fx.slash(chest + Vector3(0, randf_range(-0.3, 0.3), 0), side, color, 2.0)
		"crush":
			_fx.slash(chest, side, color, 2.6)
			_fx.flash(chest, color, 2.0)
			_fx.burst(chest, color, 20, 3.0)
		"slam":
			_fx.flash(_at(e.pos, 1.55), color, 2.6)
			_fx.dust(_at(e.pos, 0.1), 30, 2.4)
			_fx.ring(e.pos, 1.8, color, 0.45)
		"frost":
			_ice_burst(e)
		_:
			_fx.slash(chest, side, color, 2.2)

func _on_aoe(ev: Dictionary) -> void:
	if ev["skill"] == "quake":
		SoundBank.me.play("tquake")
	elif ev["skill"] == "spin": # balyoz yere cakilir
		SoundBank.me.play("heavy", -3.0, 0.85)
	var color: Color = SKILL_COLORS[ev["skill"]]
	_fx.ring(ev["pos"], ev["r"], color, 0.55)
	_fx.crater(ev["pos"], color, float(ev["r"]) * 0.8)
	_fx.burst(_at(ev["pos"], 0.3), color, 34, float(ev["r"]) * 1.1, 0.06, 0.6)
	_fx.dust(_at(ev["pos"], 0.1), 14, float(ev["r"]) * 0.8)

## Yan kamera: savasin ortasini yumusakca takip eder (sarsinti yok).
func _update_camera() -> void:
	if _battle == null:
		_camera.position = Vector3(0, 1.3, 6.2)
		_camera.look_at(Vector3(0, 1.0, 0))
		return
	# Takip kamerasi (kullanici istegi, Doom Forge gibi): iki savascinin ortasini yumusakca izler, yakin dovuste
	# yaklasir, acilinca geri cekilir. Sarsinti YOK; yalniz yavas kayma.
	var size := get_viewport().get_visible_rect().size
	var width_per_metre := 2.0 * tan(deg_to_rad(CAM_FOV * 0.5)) * size.x / size.y
	var lo := INF
	var hi := -INF
	for v in _views:
		lo = minf(lo, v.global_position.x)
		hi = maxf(hi, v.global_position.x)
	if _views.is_empty():
		lo = -1.0
		hi = 1.0
	var want_x := (lo + hi) * 0.5
	var want_d := maxf(CAM_NEAR, (hi - lo + CAM_MARGIN) / width_per_metre)
	var k := 1.0 - exp(-get_process_delta_time() * CAM_FOLLOW)
	_cam_x = lerpf(_cam_x, want_x, k)
	_cam_d = lerpf(_cam_d, want_d, k)
	_camera.position = Vector3(_cam_x, CAM_HEIGHT, _cam_d)
	_camera.look_at(Vector3(_cam_x, CAM_LOOK_Y, 0))


## Aninda yeniden baslatma (kullanici istegi): R tusu ya da duraklatma menusu. Bilgisayara karsi: ayni sinif ve asamayla
## yeni mac (yarida birakilan mac sayilmaz, odul/yenilgi yok). Canli mac: oda sahibi hemen yeni maci baslatir,
## katilan oda sahibine "restart" yollar; iki tarafta da ayni anda yeni mac baslar. Mac bitmisse tekrar oyna gibi calisir.
func _restart_now() -> void:
	if _battle == null or not _in_battle:
		return
	if _paused: # duraklatma penceresi acik kalmasin
		_set_paused(false)
	if _battle.over:
		_on_rematch()
		return
	if _testing:
		_start_test(_cls, _name)
	elif _mode == Mode.AI:
		_start_ai(_cls, _name)
	elif _mode == Mode.HOST:
		_start_host_match()
	else:
		_set_paused(false)
		_net.send_restart()


func _on_remote_restart() -> void:
	if _mode == Mode.HOST and _in_battle and _battle != null:
		_start_host_match()
