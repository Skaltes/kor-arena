extends Node3D
## Oyun akisi: sinif secimi -> savas -> sonuc. Savas kurallari core/ icindedir;
## bu dosya yalnizca komut gonderir ve olaylari ekrana yansitir.
## Canli 1v1: odayi acan savasi calistirir, katilan gelen durumu aynalayarak gosterir
## (iki oyuncu da kendini solda gorur).

const TEST_LEVEL := 8
const CAM_FOV := 30.0
const CAM_LOOK_Y := 1.12
const CAM_HEIGHT := 1.28 # Doom Forge gibi alcak ve yakin: savascilar ekrani doldurur
const CAM_DIST := 7.7
const FIELD_WIDTH := 7.3 # kadrajda her zaman gorunen savas alani genisligi (metre)
const STATE_EVERY := 3 # 30 adimda 10 durum

const SKILL_COLORS := {
	"power": Color(1.0, 0.72, 0.3), "lunge": Color(1.0, 0.9, 0.55), "bash": Color(0.5, 0.75, 1.0), "cry": Color(1.0, 0.55, 0.2), "second": Color(0.4, 1.0, 0.5), "whirl": Color(1.0, 0.8, 0.4),
	"backstab": Color(0.75, 0.4, 1.0), "hamstring": Color(0.95, 0.3, 0.45), "poison": Color(0.45, 1.0, 0.3), "expose": Color(1.0, 0.3, 0.6), "frenzy": Color(1.0, 0.2, 0.2), "flurry": Color(0.85, 0.5, 1.0),
	"smash": Color(1.0, 0.6, 0.2), "crush": Color(0.95, 0.9, 0.75), "quake": Color(0.95, 0.55, 0.25), "iron": Color(0.7, 0.8, 0.95), "rage": Color(1.0, 0.25, 0.1), "ruin": Color(1.0, 0.35, 0.05),
}
const HEAVY := ["smash", "ruin", "power"]
const SELF_RISE := ["second", "cry", "frenzy", "iron", "rage"]

enum Mode { AI, HOST, CLIENT }

var _arena: ArenaView
var _fx: Effects
var _hud: Hud
var _net: NetSession
var _camera: Camera3D
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
var _ticks := 0
var _i_am_ready := false
var _rival_ready := false

var _in_battle := false
var _test_dir := ""
var _test_casts := 0
var _test_hit := 0
var _test_hit_skill := ""
var _test_gap := 0.0
var _last_skill := ""
var _streak := 0
var _worst_grip := 0.0
var _worst_clear := 9.0
var _worst_part := ""
var _slow_time := 0.0
var _low_quality := false


func _ready() -> void:
	_arena = ArenaView.new()
	add_child(_arena)
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
	_hud.play_ai.connect(_start_ai)
	_hud.host_room.connect(_host_room)
	_hud.join_room.connect(_join_room)
	_hud.cancel_online.connect(_leave_online)
	_hud.class_changed.connect(_on_class_changed)
	_hud.skill_pressed.connect(_use_skill)
	_hud.rematch.connect(_on_rematch)
	_hud.back.connect(_leave_online)
	_net.joined.connect(_on_rival_joined)
	_net.failed.connect(_on_net_failed)
	_net.disconnected.connect(_on_net_lost)
	_net.status.connect(_hud.set_lobby_status)
	_net.match_data.connect(_on_match_data)
	_net.state_received.connect(_on_state)
	_net.events_received.connect(_on_remote_events)
	_net.skill_received.connect(_on_remote_skill)
	_net.ready_received.connect(_on_rival_ready)
	_show_select()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--demo="):
			_test_dir = arg.trim_prefix("--demo=")
			_run_demo()
		elif arg.begins_with("--skills="):
			_test_dir = arg.trim_prefix("--skills=")
			_skill_test()
		elif arg.begins_with("--grip="):
			_test_dir = arg.trim_prefix("--grip=")
			await _grip_all()
			get_tree().quit()
		elif arg.begins_with("--audit="):
			_test_dir = arg.trim_prefix("--audit=")
			_run_audit()
		elif arg == "--calib":
			_calibrate()
		elif arg.begins_with("--sledge="):
			_test_dir = arg.trim_prefix("--sledge=")
			_sledge_test()
		elif arg.begins_with("--portraits="):
			_test_dir = arg.trim_prefix("--portraits=")
			_make_portraits()
		elif arg.begins_with("--net-host="):
			_test_dir = arg.trim_prefix("--net-host=")
			_run_net_test(true)
		elif arg.begins_with("--net-join="):
			_test_dir = arg.trim_prefix("--net-join=")
			_run_net_test(false)


func _exit_tree() -> void:
	_net.close()


func _clear_views() -> void:
	if _battle != null:
		_battle.release()
	for v in _previews + _views:
		v.queue_free()
	_previews.clear()
	_views.clear()


func _show_select() -> void:
	_clear_views()
	_fx.clear()
	_battle = null
	_in_battle = false
	_show_hero()
	_hud.show_select(_cls, _name)


func _show_hero() -> void:
	for v in _previews:
		v.queue_free()
	_previews.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var v := CharacterView.new()
	add_child(v)
	v.setup(Rules.new_character("", _cls, TEST_LEVEL, 2, rng))
	v.rotation.y = 0.35
	_previews.append(v)


func _on_class_changed(cls: String) -> void:
	_cls = cls
	if _battle == null:
		_show_hero()

func _begin(a: Dictionary, b: Dictionary, seed_value: int, my_team: int) -> void:
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
	for e in _battle.ents:
		var v := CharacterView.new()
		add_child(v)
		v.setup(e.ch, e)
		_views.append(v)
	_acc = 0.0
	_ending = 0.0
	_ticks = 0
	_paused = false
	_in_battle = true
	_i_am_ready = false
	_rival_ready = false
	_hud.show_battle(_me, _foe, _mode == Mode.AI)
	_hud.announce("SAVAŞ!")


func _start_ai(cls: String, _player_name: String) -> void:
	_mode = Mode.AI
	_cls = cls
	var seed_value := randi()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var hero := Rules.new_character("Şampiyon", cls, TEST_LEVEL, 1, rng)
	var foe := Rules.make_opponent(TEST_LEVEL, GameData.ARENA_DUEL, rng)
	_begin(hero, foe, seed_value, 0)
	_brains = [Brain.new(_foe, GameData.ARENA_DUEL["ai"], rng)]


func _host_room(cls: String, player_name: String) -> void:
	_mode = Mode.HOST
	_cls = cls
	_name = player_name
	_net.host()
	_hud.show_lobby("Oda açılıyor...", "Kodu arkadaşına gönder. Kurulum ve VPN gerekmez.")


func _join_room(cls: String, player_name: String, code: String) -> void:
	_mode = Mode.CLIENT
	_cls = cls
	_name = player_name
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
	if _battle != null and not _battle.over:
		_battle.restore(data, true)


func _on_remote_events(list: Array) -> void:
	if _battle == null:
		return
	for ev: Dictionary in list:
		if ev.has("pos"):
			ev["pos"] = Vector2(-ev["pos"].x, ev["pos"].y)
		_battle.events.append(ev)


func _on_remote_skill(id: String) -> void:
	if _battle != null and not _battle.over:
		_battle.command({"ent": 1, "type": "skill", "skill": id})


func _on_rematch() -> void:
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
	_net.close()
	_mode = Mode.AI
	_hud.show_message(message)


func _on_net_lost() -> void:
	if _mode == Mode.AI:
		return
	print("baglanti koptu")
	_leave_online()
	_hud.show_message("Rakibin bağlantısı koptu.")


func _leave_online() -> void:
	_net.close()
	_mode = Mode.AI
	_show_select()


func _use_skill(id: String) -> void:
	if _battle == null or _battle.over:
		return
	if _mode == Mode.CLIENT:
		_net.send_skill(id)
	else:
		_battle.command({"ent": _me.id, "type": "skill", "skill": id})


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and _in_battle and not _battle.over:
		var ids: Array = GameData.CLASSES[_cls]["skills"]
		if event.keycode >= KEY_1 and event.keycode < KEY_1 + ids.size():
			_use_skill(ids[event.keycode - KEY_1])
		elif event.keycode == KEY_SPACE and _mode == Mode.AI:
			_paused = not _paused
			_hud.announce("DURAKLATILDI" if _paused else "DEVAM")


func _process(delta: float) -> void:
	_watch_speed(delta)
	if _test_dir != "":
		for v in _views:
			if v.rig != null and not v.rig.released:
				_worst_grip = maxf(_worst_grip, v.rig.measure())
			if v.ent.alive:
				var gap: float = v.clearance()
				if gap < _worst_clear:
					_worst_clear = gap
					_worst_part = v.worst_part
	if _battle != null:
		if _mode != Mode.CLIENT and not _paused and not _battle.over:
			_acc += delta
			while _acc >= Battle.STEP:
				_acc -= Battle.STEP
				for br in _brains:
					br.update(_battle, Battle.STEP)
				_battle.tick()
				_ticks += 1
				if _mode == Mode.HOST and _ticks % STATE_EVERY == 0:
					_net.send_state(_battle.snapshot())
		_drain_events()
		if _in_battle:
			_hud.update_battle(_me, _foe)
		if _ending > 0.0:
			_ending -= delta
			if _ending <= 0.0:
				_in_battle = false
				_hud.show_result(_battle.winner == _me.team, _mode == Mode.AI, _cls, "Galibiyet serisi: %d" % _streak if _streak >= 2 else "")
				if _rival_ready:
					_hud.set_result_note("Rakibin tekrar savaşmak istiyor.")
	_update_camera()


## 5 sn boyunca 40 kare/sn alti gorulurse kalite kendiliginden duser.
func _watch_speed(delta: float) -> void:
	if _low_quality or Time.get_ticks_msec() < 6000:
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
			"cast":
				_on_cast(ev)
			"hit":
				_on_hit(ev)
			"miss":
				_fx.number(_at(_battle.ents[ev["ent"]].pos, 1.95), "Kaçtı", Color(0.85, 0.85, 0.85), 48)
			"death":
				if _last_skill != "":
					_fx.title(_at(_battle.ents[ev["ent"]].pos, 2.5), "ÖLÜMCÜL DARBE!", Color(1.0, 0.25, 0.15))
				_battle.ents[ev["ent"]].alive = false
				_battle.ents[ev["ent"]].hp = 0.0
			"heal":
				var healed := _battle.ents[ev["ent"]]
				_fx.number(_at(healed.pos, 1.95), "+%d" % ev["amount"], Color(0.5, 1.0, 0.5))
			"aoe":
				_on_aoe(ev)
			"combo":
				_fx.title(_at(_battle.ents[ev["ent"]].pos, 2.5), "KOMBO!", Color(1.0, 0.85, 0.3))
			"interrupt":
				_views[ev["ent"]].interrupt()
				_hud.cast_stop("A" if ev["ent"] == _me.id else "B", "KESİLDİ!")
				_fx.title(_at(_battle.ents[ev["ent"]].pos, 2.5), "KESİLDİ!", Color(0.5, 0.8, 1.0))
				_fx.flash(_at(_battle.ents[ev["ent"]].pos, 1.3), Color(0.5, 0.8, 1.0), 2.4)
			"end":
				_battle.over = true
				_battle.winner = ev["winner"]
				_ending = 1.6
				_hud.announce("ZAFER!" if ev["winner"] == _me.team else "YENİLDİN")
				_streak = _streak + 1 if ev["winner"] == _me.team else 0


func _on_cast(ev: Dictionary) -> void:
	var v := _views[ev["ent"]]
	var id: String = ev["skill"]
	var sk: Dictionary = GameData.SKILLS[id]
	var color: Color = SKILL_COLORS[id]
	if ev["ent"] == _me.id:
		_test_casts += 1
	v.play_skill(id, color)
	var dur: float = ev.get("dur", 0.0)
	var key := "A" if ev["ent"] == _me.id else "B"
	if dur > 0.0:
		_hud.cast_start(key, id, dur, color)
	if ev["ent"] == _me.id:
		_hud.show_my_skill(id, color)
	var e := _battle.ents[ev["ent"]]
	_fx.title(_at(e.pos + Vector2(0.9 * signf(e.pos.x - _battle.ents[1 - e.id].pos.x), 0.0), 2.25), sk["name"], color)
	if sk["kind"] == "self":
		_fx.aura(v, color, 1.1)
		_fx.rise(v, color)
		_fx.ring(e.pos, 2.2, color, 0.7)
		_fx.burst(_at(e.pos, 1.0), color, 26, 2.2)
	else:
		_fx.charge(v, color, maxf(float(sk.get("windup", 0.3)), 0.4))


func _on_hit(ev: Dictionary) -> void:
	var e := _battle.ents[ev["ent"]]
	if _mode == Mode.CLIENT: # bir sonraki durum gelene kadar can cubugu da hemen dussun
		e.hp = maxf(0.0, e.hp - float(ev["dmg"]))
	var crit: bool = ev["crit"]
	var skill: String = ev.get("skill", "")
	var dot: bool = ev["dot"]
	_last_skill = skill
	if ev["src"] == _me.id and not dot:
		_test_hit = Time.get_ticks_msec()
		_test_gap = _views[_me.id].hit_error_ms()
		_test_hit_skill = skill
	if not dot:
		_views[e.id].react(skill, crit)
		_views[ev["src"]].impact_pause(skill)
	if not dot and not ev["absorbed"]:
		_fx.blood(_at(e.pos, 1.25), 34 if crit or skill != "" else 12, 3.0)
		_fx.stain(e.pos + Vector2(randf_range(-0.6, 0.6), randf_range(-0.4, 0.4)), randf_range(0.08, 0.2))
	if skill != "":
		_skill_impact(skill, e, signf(e.pos.x - _battle.ents[ev["src"]].pos.x))
	elif dot:
		_fx.burst(_at(e.pos, 1.25), Color(0.44, 0.88, 0.3), 10, 1.6)
	elif crit:
		_fx.flash(_at(e.pos, 1.25), Color(1.0, 0.7, 0.4), 1.4)
	if ev["absorbed"]:
		_fx.number(_at(e.pos, 1.95), "Emildi", Color(0.56, 0.88, 1.0), 48)
	elif crit:
		_fx.number(_at(e.pos, 1.95), str(ev["dmg"]), Color(1.0, 0.42, 0.2), 110)
	else:
		_fx.number(_at(e.pos, 1.95), str(ev["dmg"]), Color(1.0, 0.89, 0.69))


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
		_:
			_fx.slash(chest, side, color, 2.2)

func _on_aoe(ev: Dictionary) -> void:
	var color: Color = SKILL_COLORS[ev["skill"]]
	_fx.ring(ev["pos"], ev["r"], color, 0.55)
	_fx.crater(ev["pos"], color, float(ev["r"]) * 0.8)
	_fx.burst(_at(ev["pos"], 0.3), color, 34, float(ev["r"]) * 1.1, 0.06, 0.6)
	_fx.dust(_at(ev["pos"], 0.1), 14, float(ev["r"]) * 0.8)

## Sabit yan kamera: savas boyunca hic hareket etmez. Dar ekranda yalnizca alanin sigmasi icin geri cekilir.
func _update_camera() -> void:
	if _battle == null:
		_camera.position = Vector3(0, 1.3, 6.2)
		_camera.look_at(Vector3(0, 1.0, 0))
		return
	var size := get_viewport().get_visible_rect().size
	var width_per_metre := 2.0 * tan(deg_to_rad(CAM_FOV * 0.5)) * size.x / size.y
	_camera.position = Vector3(0, CAM_HEIGHT, maxf(CAM_DIST, FIELD_WIDTH / width_per_metre))
	_camera.look_at(Vector3(0, CAM_LOOK_Y, 0))


## Gelistirici testi: gercek tus olaylari gonderir, ekran goruntuleri alip kapanir.
## Godot ... -- --demo=<klasor>
func _run_demo() -> void:
	await _snap("secim.png", 2.0)
	for cls: String in GameData.CLASSES:
		_start_ai(cls, "")
		_test_casts = 0
		await get_tree().create_timer(0.1).timeout
		var cam_start := _camera.global_transform
		await _snap(cls + "_baslangic.png", 0.5)
		await get_tree().create_timer(1.0).timeout
		print("%s: %d kare/sn, 3B cizim %.1f ms" % [cls, Engine.get_frames_per_second(), RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())])
		await get_tree().create_timer(3.0).timeout
		await _strip(cls + "_normal.png")
		print("%s: tus basilmadan kendi yetenegi = %d" % [cls, _test_casts])
		for key: Key in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6]:
			_press(key)
			await get_tree().create_timer(0.15).timeout
			await _strip("%s_yetenek_%d.png" % [cls, key - KEY_0])
		await _snap(cls + "_sure.png", 0.1)
		print("%s: kamera sabit = %s" % [cls, _camera.global_transform == cam_start])
		print("%s: 6 tustan sonra kendi yetenegi = %d" % [cls, _test_casts])
	print("BALYOZ gercek savas: en buyuk bosluk %.1f mm" % (_worst_grip * 1000.0))
	while _in_battle:
		await get_tree().process_frame
	await _snap("sonuc.png", 0.3)
	get_tree().quit()


## Iki kopya arasinda gercek ag testi: iki mac oynanir, sonra oda sahibi kapanir.
func _run_net_test(as_host: bool) -> void:
	var tag := "host" if as_host else "join"
	await get_tree().create_timer(1.0).timeout
	if as_host:
		_host_room("warrior", "Ev Sahibi")
		while _net.room_code == "" or not _net._online:
			await get_tree().process_frame
		FileAccess.open(_test_dir.path_join("kod.txt"), FileAccess.WRITE).store_string(NetSession.CODE_LETTERS[_net._broker] + _net.room_code)
		print("sunucu: ", NetSession.BROKERS[_net._broker])
		await _snap("host_lobi.png", 0.5)
	else:
		var code_file := _test_dir.path_join("kod.txt")
		while not FileAccess.file_exists(code_file):
			await get_tree().create_timer(0.3).timeout
		_join_room("brute", "Misafir", FileAccess.get_file_as_string(code_file))
	for round_no in 2:
		while not _in_battle:
			await get_tree().process_frame
		_test_casts = 0
		await get_tree().create_timer(1.5).timeout
		var keys: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6]
		var i := 0
		var shot_taken := false
		while _in_battle:
			_press(keys[i % 6])
			i += 1
			await get_tree().create_timer(0.8).timeout
			if not shot_taken and _in_battle:
				shot_taken = true
				await _snap("%s_tur%d.png" % [tag, round_no], 0.0)
		print("%s tur %d: sinif=%s/%s kazanan takim=%d benim takim=%d yetenegim=%d can A=%d B=%d gecikme=%d ms" % [tag, round_no, _battle.ents[0].ch["cls"], _battle.ents[1].ch["cls"], _battle.winner, _me.team, _test_casts, _battle.ents[0].hp, _battle.ents[1].hp, _net.rtt_ms])
		await _snap("%s_sonuc%d.png" % [tag, round_no], 0.3)
		if round_no == 0:
			_cls = "assassin" if as_host else "warrior" # mac sonu sinif degistirme testi
			_on_rematch()
			while _battle.over:
				await get_tree().process_frame
	if as_host:
		await get_tree().create_timer(5.0).timeout
		get_tree().quit()
	else:
		await get_tree().create_timer(6.0).timeout
		await _snap("join_koptu.png", 0.0)
		get_tree().quit()


## art/portraits/ icin sinif basina yuvarlak portre fotografi cekip kapanir.
func _make_portraits() -> void:
	_hud.visible = false
	set_process(false)
	for cls: String in GameData.CLASSES:
		_cls = cls
		_show_hero()
		await get_tree().create_timer(0.7).timeout
		if _previews[0].rig != null:
			_previews[0].rig.weapon.visible = false # balyoz yuzu kapatmasin
		var head := _previews[0].head_position()
		_camera.position = head + Vector3(0.0, 0.03, 1.5)
		_camera.look_at(head + Vector3(0, 0.03, 0))
		await get_tree().process_frame
		var img: Image = await _shot()
		var h := img.get_height()
		var side := int(h * 0.62)
		var crop := img.get_region(Rect2i((img.get_width() - side) / 2, (h - side) / 2, side, side))
		crop.resize(192, 192, Image.INTERPOLATE_LANCZOS)
		crop.save_png(_test_dir.path_join(cls + ".png"))
	get_tree().quit()

## Her animasyonda elin en hizli oldugu anlari olcer: vurus zamanlamasi buradan gelir.
func _calibrate() -> void:
	_hud.visible = false
	await get_tree().create_timer(0.6).timeout
	var v := _previews[0]
	var ap: AnimationPlayer = v._ap
	var sk: Skeleton3D = v._skeleton
	var bone := sk.find_bone("hand_r")
	var tip := Transform3D(Basis.from_euler(CharacterView.HOLD_ROT), CharacterView.HOLD_POS) * Vector3(0, 0.8, 0)
	for anim: String in ["Sword_Regular_A", "Sword_Regular_B", "Sword_Regular_C", "Sword_Attack", "Sword_Dash", "Sword_Regular_Combo", "Shield_Dash", "Melee_Hook", "Punch_Cross", "Punch_Jab", "OverhandThrow"]:
		ap.play(anim, 0.0, 0.0)
		var length: float = ap.get_animation(anim).length
		var prev := Vector3.ZERO
		var speeds: Array[float] = []
		var step := 1.0 / 60.0
		var t := 0.0
		while t <= length:
			ap.seek(t, true)
			var p := sk.get_bone_global_pose(bone) * tip
			speeds.append(p.distance_to(prev) / step if t > 0.0 else 0.0)
			prev = p
			t += step
		var peaks := []
		for i in range(3, speeds.size() - 3):
			var window := speeds.slice(i - 6 if i > 6 else 0, i + 7)
			if speeds[i] == window.max() and speeds[i] > 2.5:
				peaks.append("%.2f(%.0f)" % [i * step, speeds[i]])
		print("ANIM %s %.2f sn: %s" % [anim, length, " ".join(peaks)])
	get_tree().quit()

## Tum siniflarin tum yetenekleri: gercek savas kamerasindan kareler, hasar ile silah vurusu arasi fark, balyoz temasi.
func _skill_test() -> void:
	await get_tree().create_timer(1.0).timeout
	for cls: String in GameData.CLASSES:
		_start_ai(cls, "")
		_brains = []
		_me.s = _me.s.duplicate()
		_foe.s = _foe.s.duplicate()
		_me.s["max_hp"] = 9000000.0
		_foe.s["max_hp"] = 9000000.0
		_me.hp = 9000000.0
		_foe.hp = 9000000.0
		_foe.atk_t = 9999.0
		_me.atk_t = 9999.0
		var view := _views[0]
		var sheet := Image.create(1600, 2100, false, Image.FORMAT_RGBA8)
		var ids: Array = GameData.CLASSES[cls]["skills"]
		while _me.pos.distance_to(_foe.pos) > float(_me.s["range"]) + 0.2:
			await get_tree().process_frame
		for i in ids.size():
			var id: String = ids[i]
			var sk: Dictionary = GameData.SKILLS[id]
			var wind: float = sk.get("windup", 0.0)
			_me.cds.clear()
			_me.gcd = 0.0
			_worst_grip = 0.0
			_worst_clear = 9.0
			_test_hit = 0
			var samples: Array = []
			_press(KEY_1 + i)
			var shots := [maxf(wind * 0.5, 0.2), wind + 0.02, wind + 0.32, wind + 0.8]
			var start := Time.get_ticks_msec()
			var prev: Vector3 = view.weapon_tip.global_position
			var slot := 0
			var last := Time.get_ticks_msec()
			while (Time.get_ticks_msec() - start) / 1000.0 < wind + 1.7:
				await get_tree().process_frame
				var now := Time.get_ticks_msec()
				var p: Vector3 = view.weapon_tip.global_position
				var dt := maxf((now - last) / 1000.0, 0.001)
				samples.append([now, p.distance_to(prev) / dt])
				prev = p
				last = now
				if slot < 4 and (now - start) / 1000.0 >= shots[slot]:
					var img: Image = await _shot()
					img.convert(Image.FORMAT_RGBA8)
					var c := img.get_region(Rect2i(img.get_width() / 2 - 480, img.get_height() - 700, 960, 700))
					c.resize(400, 350)
					sheet.blit_rect(c, Rect2i(0, 0, 400, 350), Vector2i(slot * 400, i * 350))
					slot += 1
			var note := "yetenek kendine" if _test_hit == 0 else "hasar ile silah vurusu arasi %.0f ms" % _test_gap
			print("YETENEK %s/%s: %s, kullanildi=%s, vucut payi %.0f mm%s" % [cls, id, note, float(_me.cds.get(id, 0.0)) > 0.0, _worst_clear * 1000.0, ", balyoz bosluk %.1f mm" % (_worst_grip * 1000.0) if cls == "brute" else ""])
		sheet.save_png(_test_dir.path_join(cls + "_yetenekler.png"))
		for n in 2:
			_test_hit = 0
			_worst_clear = 9.0
			_me.atk_t = 0.05
			var limit := Time.get_ticks_msec() + 4000
			while _test_hit == 0 and Time.get_ticks_msec() < limit:
				await get_tree().process_frame
			_me.atk_t = 9999.0
			await get_tree().create_timer(1.5).timeout
			print("NORMAL %s %d: hasar ile silah vurusu arasi %.0f ms, vurus goruldu=%s, vucut payi %.0f mm" % [cls, n, _test_gap, _test_hit > 0, _worst_clear * 1000.0])
	await _grip_all()
	get_tree().quit()

func _grip_all() -> void:
	await _grip_views("brute", ["smash", "crush", "quake", "ruin"])
	await _grip_views("warrior", ["power", "bash", "lunge", "whirl"])
	await _grip_views("assassin", ["backstab", "hamstring", "expose", "flurry"])


## Ayni siniftan iki savasci karsilikli: normal saldiri ve yetenekler gercek kameradan, iki taraftan cekilir.
func _grip_views(cls: String, ids: Array) -> void:
	_hud.visible = false
	var rng := RandomNumberGenerator.new()
	var a := Rules.new_character("A", cls, TEST_LEVEL, 1, rng)
	var c := Rules.new_character("B", cls, TEST_LEVEL, 1, rng)
	_mode = Mode.AI
	_begin(a, c, 1, 0)
	_brains = []
	for e in _battle.ents:
		e.s = e.s.duplicate()
		e.s["max_hp"] = 9000000.0
		e.hp = 9000000.0
		e.atk_t = 9999.0
	_worst_grip = 0.0
	_worst_clear = 9.0
	var sheet := Image.create(2000, 3000, false, Image.FORMAT_RGBA8)
	await get_tree().create_timer(0.35).timeout
	await _grip_shot(sheet, 0, 0)
	var range_now: float = _me.s["range"] + 0.15
	while _me.pos.distance_to(_foe.pos) > range_now:
		await get_tree().process_frame
	await get_tree().create_timer(0.9).timeout
	await _grip_shot(sheet, 1, 0)
	print("%s bekleme/yurume vucut payi %.0f mm" % [cls, _worst_clear * 1000.0])
	_worst_clear = 9.0
	for e in _battle.ents:
		e.atk_t = 0.0
	var swing: float = _me.s["swing"]
	await get_tree().create_timer(swing * 0.5).timeout
	await _grip_shot(sheet, 0, 1)
	await get_tree().create_timer(swing * 0.5 - 0.03).timeout
	await _grip_shot(sheet, 1, 1)
	for e in _battle.ents:
		e.atk_t = 9999.0
	await get_tree().create_timer(1.6).timeout
	print("%s normal saldiri vucut payi %.0f mm (%s)" % [cls, _worst_clear * 1000.0, _worst_part])
	var row := 1
	for id: String in ids:
		row += 1
		_worst_clear = 9.0
		for e in _battle.ents:
			e.cds.clear()
			e.gcd = 0.0
			_battle.command({"ent": e.id, "type": "skill", "skill": id})
		var wind: float = GameData.SKILLS[id].get("windup", 0.0)
		await get_tree().create_timer(wind * 0.6).timeout
		await _grip_shot(sheet, 0, row)
		await get_tree().create_timer(maxf(wind * 0.4 - 0.02, 0.01)).timeout
		await _grip_shot(sheet, 1, row)
		await get_tree().create_timer(2.2).timeout
		print("%s/%s iki yon vucut payi %.0f mm (%s)" % [cls, id, _worst_clear * 1000.0, _worst_part])
	sheet.save_png(_test_dir.path_join(cls + "_yakin.png"))
	print("%s iki yon balyoz bosluk %.1f mm" % [cls, _worst_grip * 1000.0])

func _grip_shot(sheet: Image, col: int, row: int) -> void:
	var img: Image = await _shot()
	img.convert(Image.FORMAT_RGBA8)
	for i in 2:
		var s := _camera.unproject_position(_views[i].global_position + Vector3(0, 1.05, 0))
		var rect := Rect2i(int(s.x) - 310, int(s.y) - 310, 620, 620).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
		var crop := img.get_region(rect)
		crop.resize(500, 500)
		sheet.blit_rect(crop, Rect2i(0, 0, 500, 500), Vector2i(i * 1000 + col * 500, row * 500))

## Gercek model yuzeyiyle tam denetim: her sinif, her hareket, iki taraf. En kotu kare kaydedilir.
func _run_audit() -> void:
	_hud.visible = false
	await get_tree().create_timer(0.8).timeout
	for cls: String in GameData.CLASSES:
		var rng := RandomNumberGenerator.new()
		_mode = Mode.AI
		_begin(Rules.new_character("A", cls, TEST_LEVEL, 1, rng), Rules.new_character("B", cls, TEST_LEVEL, 1, rng), 1, 0)
		_hud.visible = false
		_brains = []
		for e in _battle.ents:
			e.s = e.s.duplicate()
			e.s["max_hp"] = 9000000.0
			e.hp = 9000000.0
			e.atk_t = 9999.0
		var audits: Array[MeshAudit] = [MeshAudit.new(_views[0]), MeshAudit.new(_views[1])]
		var limit: float = float(_me.s["range"]) + 0.15
		await _audit_step(cls, "yurume", audits, func() -> bool: return _me.pos.distance_to(_foe.pos) > limit, -1.0)
		await _audit_step(cls, "bekleme", audits, Callable(), 1.6)
		for n in 2:
			for e in _battle.ents:
				e.atk_t = 0.0
			await _audit_step(cls, "normal%d" % (n + 1), audits, Callable(), float(_me.s["swing"]) + 1.3)
			for e in _battle.ents:
				e.atk_t = 9999.0
		var ids: Array = GameData.CLASSES[cls]["skills"]
		for i in ids.size():
			var id: String = ids[i]
			for e in _battle.ents:
				e.cds.clear()
				e.gcd = 0.0
				_battle.command({"ent": e.id, "type": "skill", "skill": id})
			await _audit_step(cls, "yetenek%d_%s" % [i + 1, id], audits, Callable(), float(GameData.SKILLS[id].get("windup", 0.0)) + 2.2)
	get_tree().quit()


func _audit_step(cls: String, label: String, audits: Array[MeshAudit], until: Callable, secs: float) -> void:
	var start := Time.get_ticks_msec()
	var worst := [0, 0.0, ""]
	var at := 0.0
	var side := 0
	var picture: Image = null
	while (until.is_valid() and until.call()) or (not until.is_valid() and (Time.get_ticks_msec() - start) / 1000.0 < secs):
		await get_tree().process_frame
		for i in 2:
			var r: Array = audits[i].check()
			if float(r[1]) > float(worst[1]) + 1.0:
				worst = r
				at = (Time.get_ticks_msec() - start) / 1000.0
				side = i
				picture = get_viewport().get_texture().get_image()
				var s := _camera.unproject_position(_views[i].global_position + Vector3(0, 1.05, 0))
				var box := Rect2i(int(s.x) - 340, int(s.y) - 340, 680, 680).intersection(Rect2i(0, 0, picture.get_width(), picture.get_height()))
				picture = picture.get_region(box)
	print("DENETIM %s %s: %d nokta, %.0f mm derin, parca=%s, %.2f sn, %s" % [cls, label, worst[0], worst[1], worst[2], at, "sol" if side == 0 else "sag"])
	if picture != null:
		picture.save_png(_test_dir.path_join("%s_%s.png" % [cls, label]))

## 6 ardisik kareyi tek gorsele dizer: animasyon boyle incelenir.
func _strip(file: String) -> void:
	var sheet := Image.create(1920, 720, false, Image.FORMAT_RGBA8)
	for i in 6:
		var img: Image = await _shot()
		img.convert(Image.FORMAT_RGBA8)
		img.resize(640, 360)
		sheet.blit_rect(img, Rect2i(0, 0, 640, 360), Vector2i(i % 3 * 640, i / 3 * 360))
		await get_tree().create_timer(0.14).timeout
	sheet.save_png(_test_dir.path_join(file))

## Balyoz tutusunu her animasyonda olcer ve yandan gorunus kareleri ceker.
func _sledge_test() -> void:
	_hud.visible = false
	set_process(false)
	_cls = "brute"
	_show_hero()
	await get_tree().create_timer(1.0).timeout
	var v := _previews[0]
	v.rotation.y = PI / 2.0 - 0.35
	var anims := ["Sword_Idle", "Walk", "Jog_Fwd", "Sword_Attack", "TreeChopping", "Sword_Regular_B", "Hit_Chest", "Zombie_Idle", "Spell_Simple_Shoot"]
	var sheet := Image.create(2400, 1600, false, Image.FORMAT_RGBA8)
	var slot := 0
	_camera.position = Vector3(0, 1.2, 4.6)
	_camera.look_at(Vector3(0, 1.05, 0))
	for anim: String in anims:
		var ap: AnimationPlayer = v._ap
		ap.play(anim, 0.1, 1.0)
		var worst := 0.0
		v.rig.swing(0.7, 1.3)
		for i in 26:
			await get_tree().create_timer(0.05).timeout
			worst = maxf(worst, v.rig.measure())
			if slot < 12 and i in [7, 17] and anim in ["Sword_Idle", "Walk", "Jog_Fwd", "Sword_Attack", "TreeChopping", "Hit_Chest"]:
				var img: Image = await _shot()
				img.convert(Image.FORMAT_RGBA8)
				var h := img.get_height()
				var c := img.get_region(Rect2i((img.get_width() - h) / 2, 0, h, h))
				c.resize(400, 400)
				sheet.blit_rect(c, Rect2i(0, 0, 400, 400), Vector2i(slot % 6 * 400, slot / 6 * 400))
				slot += 1
		print("TUTUS %s: en buyuk bosluk %.1f mm" % [anim, worst * 1000.0])
	sheet.get_region(Rect2i(0, 0, 2400, 800)).save_png(_test_dir.path_join("balyoz.png"))
	get_tree().quit()

func _press(key: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = key
	e.physical_keycode = key
	e.pressed = true
	Input.parse_input_event(e)


func _shot() -> Image:
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _snap(file: String, wait: float) -> void:
	if wait > 0.0:
		await get_tree().create_timer(wait).timeout
	var img: Image = await _shot()
	img.save_png(_test_dir.path_join(file))
