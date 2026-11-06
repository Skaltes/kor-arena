class_name TestRunner
extends Node
## Gelistirici testleri: komut satiri seceneklerini calistirir, olcum toplar. Normal oyunda hic olusmaz.
## Oyun kodu yalnizca asagidaki on_ kancalarini cagirir.

var m: GameMain
var _test_dir := ""
var _test_casts := 0
var _test_rejected := 0
var _test_queued := 0
var _lag_press := 0
var _lag_samples: Array[int] = []
var _state_gaps: Array[int] = []
var _state_last := 0
var _match_t0 := 0
var _test_hit := 0
var _test_gap := 0.0
var _worst_grip := 0.0
var _along_sum := 0.0
var _probes := {}
var _feet_last := {}
var _slide_max := 0.0
var _slide_sum := 0.0
var _along_n := 0


func start(args: PackedStringArray) -> void:
	for arg in args:
		if arg.begins_with("--demo="):
			_test_dir = arg.trim_prefix("--demo=")
			_run_demo()
		elif arg.begins_with("--skills="):
			_test_dir = arg.trim_prefix("--skills=")
			_skill_test()
		elif arg.begins_with("--film="): # --film=<klasor>:<sinif> her yetenegin kare seridi + durus/tutus/ayak olcumu
			var parts := arg.trim_prefix("--film=").rsplit(":", true, 1)
			_test_dir = parts[0]
			await _film(parts[1] if parts.size() > 1 and parts[1].length() < 10 else "brute")
			get_tree().quit()
		elif arg.begins_with("--closeups="):
			_test_dir = arg.trim_prefix("--closeups=")
			await _closeups_all()
			get_tree().quit()
		elif arg.begins_with("--audit="):
			_test_dir = arg.trim_prefix("--audit=")
			_run_audit()
		elif arg.begins_with("--clipcheck="):
			var c := ClipCheck.new()
			c.m = m
			c.dir = arg.trim_prefix("--clipcheck=")
			for opt in args:
				if opt.begins_with("--sinif="):
					c.cls = opt.trim_prefix("--sinif=")
				elif opt.begins_with("--etiket="):
					c.tag = opt.trim_prefix("--etiket=")
				elif opt.begins_with("--sinama="):
					c.mode = opt.trim_prefix("--sinama=")
			add_child(c)
			c.run()
		elif arg.begins_with("--hit="):
			_test_dir = arg.trim_prefix("--hit=")
			_hit_test()
		elif arg.begins_with("--atk="):
			var ap := arg.trim_prefix("--atk=").rsplit(":", true, 1)
			_test_dir = ap[0]
			_atk_test(ap[1] if ap.size() > 1 else "brute")
		elif arg == "--audio" or arg.begins_with("--audio="):
			_audio_test(arg.get_slice("=", 1) if "=" in arg else "brute")
		elif arg == "--forfeit":
			_forfeit_test()
		elif arg.begins_with("--parry="):
			_test_dir = arg.get_slice("=", 1)
			_parry_test()
		elif arg.begins_with("--titan="):
			_test_dir = arg.get_slice("=", 1)
			_titan_test()
		elif arg == "--calib":
			_calibrate()
		elif arg.begins_with("--portraits="):
			_test_dir = arg.trim_prefix("--portraits=")
			_make_portraits()
		elif arg == "--net-quick":
			_quick_test()
		elif arg.begins_with("--chain-view="):
			_test_dir = arg.trim_prefix("--chain-view=")
			_chain_view_test()
		elif arg.begins_with("--test-mode="):
			_test_dir = arg.trim_prefix("--test-mode=")
			_test_mode_test()
		elif arg.begins_with("--press="):
			_test_dir = arg.trim_prefix("--press=")
			_press_test()
		elif arg.begins_with("--perf="):
			_test_dir = arg.trim_prefix("--perf=")
			_perf_test(args.has("--telefon"))
		elif arg.begins_with("--screens="):
			_test_dir = arg.trim_prefix("--screens=")
			_screens_test(args.has("--telefon"))
		elif arg.begins_with("--bot-offer="):
			_test_dir = arg.trim_prefix("--bot-offer=")
			_bot_offer_test()
		elif arg.begins_with("--net-leave="):
			_test_dir = arg.get_slice("=", 1)
			_net_leave_test(args.has("--ev"))
		elif arg.begins_with("--net-host="):
			_test_dir = arg.trim_prefix("--net-host=")
			_run_net_test(true)
		elif arg.begins_with("--net-join="):
			_test_dir = arg.trim_prefix("--net-join=")
			_run_net_test(false)


func on_match_start() -> void:
	_state_last = 0
	_match_t0 = Time.get_ticks_msec()


func on_state() -> void:
	if m._in_battle and m._ending <= 0.0:
		var now := Time.get_ticks_msec()
		if _state_last > 0:
			_state_gaps.append(now - _state_last)
			if now - _state_last > 400:
				print("  BOSLUK %d ms, mac basindan %.1f sn" % [now - _state_last, (now - _match_t0) / 1000.0])
		_state_last = now


func on_skill_sent() -> void:
	if _lag_press == 0:
		_lag_press = Time.get_ticks_msec()


func on_prediction_rejected() -> void:
	_test_rejected += 1


func on_prediction_queued() -> void:
	_test_queued += 1


func on_my_cast() -> void:
	_test_casts += 1
	if _lag_press > 0:
		_lag_samples.append(Time.get_ticks_msec() - _lag_press)
		_lag_press = 0


func on_my_hit() -> void:
	_test_hit = Time.get_ticks_msec()
	_test_gap = m._views[m._me.id].hit_error_ms()


func _process(_delta: float) -> void:
	for v in m._views:
		if v.rig != null and not v.rig.released:
			_worst_grip = maxf(_worst_grip, v.rig.measure())

## Gelistirici testi: gercek tus olaylari gonderir, ekran goruntuleri alip kapanir.
## Godot ... -- --demo=<klasor>
func _run_demo() -> void:
	await _snap("secim.png", 2.0)
	for cls: String in GameData.CLASSES:
		m._start_ai(cls, "")
		_test_casts = 0
		await get_tree().create_timer(0.1).timeout
		var cam_start := m._camera.global_transform
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
		print("%s: kamera sabit = %s" % [cls, m._camera.global_transform == cam_start])
		print("%s: 6 tustan sonra kendi yetenegi = %d" % [cls, _test_casts])
	print("BALYOZ gercek savas: en buyuk bosluk %.1f mm" % (_worst_grip * 1000.0))
	while m._in_battle:
		await get_tree().process_frame
	await _snap("sonuc.png", 0.3)
	get_tree().quit()


## Iki kopya Hizli Mac der: biri oda acmali, digeri ilandan katilmali, savas baslamali.
func _quick_test() -> void:
	await get_tree().create_timer(1.0 + randf() * 3.0).timeout
	m._quick_match("warrior", "Hizli")
	var left := 75.0
	while not m._in_battle and left > 0.0:
		left -= 0.1
		await get_tree().create_timer(0.1).timeout
	print("HIZLI MAC: basladi=%s rol=%s" % [m._in_battle, "host" if m._mode == GameMain.Mode.HOST else "katilan"])
	await get_tree().create_timer(6.0).timeout # rakip de baslayabilsin diye hemen kapanma
	get_tree().quit()


## Tusa basistan silahin ilk gorunur hareketine (5 cm) gecen sure, yetenek yetenek.
func _press_test() -> void:
	await get_tree().create_timer(1.0).timeout
	for cls: String in GameData.CLASSES:
		m._start_ai(cls, "")
		m._brains = []
		m._foe.atk_t = 9999.0
		m._me.atk_t = 9999.0
		var view := m._views[0]
		var ids: Array = GameData.CLASSES[cls]["skills"]
		while m._me.pos.distance_to(m._foe.pos) > float(m._me.s["range"]) + 0.2:
			await get_tree().process_frame
		var line := PackedStringArray()
		for i in ids.size():
			var id: String = ids[i]
			if GameData.SKILLS[id]["kind"] == "guard":
				continue
			m._me.hp = float(m._me.s["max_hp"])
			m._foe.hp = float(m._foe.s["max_hp"])
			m._me.cds.clear()
			m._me.gcd = 0.0
			await get_tree().create_timer(1.6).timeout
			m._me.cds.clear()
			m._me.gcd = 0.0
			m._me.lock = 0.0
			var rest: Vector3 = view.weapon_tip.global_position
			var start := Time.get_ticks_msec()
			_press(KEY_1 + i if i < 9 else KEY_0)
			while view.weapon_tip.global_position.distance_to(rest) < 0.05 and Time.get_ticks_msec() - start < 1000:
				await get_tree().process_frame
			line.append("%s %d" % [id, Time.get_ticks_msec() - start])
		print("TEPKI %s (ms): %s" % [cls, ", ".join(line)])
	var spent: String = m._me.skills[0]
	m._me.cds[spent] = 5.0
	_press(KEY_1)
	await get_tree().process_frame
	var button: Button = m._hud._skills[0]["button"]
	print("TEPKI: gecmeyen tus kizardi=%s" % (button.modulate.g < 0.9))
	await _snap("basilamaz_tus.png", 0.02)
	m._me.cds.clear()
	m._me.gcd = 0.0
	m._me.lock = 0.0
	await get_tree().create_timer(0.4).timeout
	print("TEPKI: tus normale dondu=%s" % (button.modulate == Color.WHITE))
	await get_tree().create_timer(2.2).timeout
	m._me.cds.clear()
	m._me.gcd = 0.0
	_press(KEY_1)
	await _snap("hazirlik_parlamasi.png", 0.4)
	get_tree().quit()


## Titan iter, sersemletir ve agir yetenege gecer: kareler gozle kontrol icin.
func _chain_view_test() -> void:
	await get_tree().create_timer(1.0).timeout
	m._start_test("brute", "Titan")
	while m._me.pos.distance_to(m._foe.pos) > float(m._me.s["range"]) + 0.2:
		await get_tree().process_frame
	var start: Vector2 = m._foe.pos
	m._use_skill("trample")
	await _snap("itme_1.png", 0.4)
	await _snap("itme_2.png", 0.2)
	print("ZINCIR: rakip %.2f m geri gitti" % m._foe.pos.distance_to(start))
	await _snap("itme_3.png", 0.25)
	m._use_skill("ruin")
	await _snap("yikim_hazirlik.png", 0.8)
	await get_tree().create_timer(1.0).timeout
	print("ZINCIR: yikim bekleme=%s" % (m._me.cds.get("ruin", 0.0) > 0.0))
	get_tree().quit()


## Test Modu: yetenekler acik, kukla vurmaz, kimse olmez, bekleme kapanir, kayit degismez.
func _test_mode_test() -> void:
	await _snap("menu.png", 1.5)
	var before := [m._profile.xp, m._profile.gold, m._profile.wins, m._profile.losses, m._profile.level]
	m._hud.test_mode.emit("warrior", "Deneme")
	await get_tree().create_timer(1.0).timeout
	print("TEST MODU: yetenek %d/%d" % [m._me.skills.size(), GameData.CLASSES["warrior"]["skills"].size()])
	var hp: float = m._me.hp
	await get_tree().create_timer(5.0).timeout
	print("TEST MODU: kukla vurmadi=%s" % (m._me.hp == hp))
	await _snap("panel.png", 0.2)
	print("TEST MODU: olum varsayilan acik=%s" % (not m._battle.immortal))
	m._hud.test_action.emit("immortal")
	m._foe.hp = 1.0
	while m._foe.hp <= 1.0:
		m._battle.command({"ent": m._me.id, "type": "skill", "skill": m._me.skills[0]})
		await get_tree().create_timer(0.3).timeout
		m._me.cds.clear()
		m._me.gcd = 0.0
	print("TEST MODU: rakip olmedi=%s can=%d bitti=%s" % [m._foe.alive, m._foe.hp, m._battle.over])
	m._hud.test_action.emit("free")
	_press(KEY_1)
	await get_tree().create_timer(0.3).timeout
	print("TEST MODU: bekleme kapali=%s" % (m._me.gcd == 0.0 and m._me.cds.is_empty()))
	m._hud.test_action.emit("cls")
	m._hud.test_action.emit("foe")
	await get_tree().create_timer(4.0).timeout
	print("TEST MODU: rakip=%s davranis=%s beyin=%d vurdu=%s" % [m._foe.ch["cls"], m._foe.ch["name"], m._brains.size(), m._me.hp < float(m._me.s["max_hp"])])
	# Olumsuzluk kapali: normal mac gibi biter, kayit/odul yok, Tekrar Savas yine Test Modu acar
	m._hud.test_action.emit("immortal")
	m._foe.hp = 1.0
	var limit := Time.get_ticks_msec() + 8000
	while not m._battle.over and Time.get_ticks_msec() < limit:
		m._battle.command({"ent": m._me.id, "type": "skill", "skill": m._me.skills[0]})
		await get_tree().create_timer(0.3).timeout
	await get_tree().create_timer(2.0).timeout
	var mid := [m._profile.xp, m._profile.gold, m._profile.wins, m._profile.losses, m._profile.level]
	print("TEST MODU: olumlu mac bitti=%s kayit ayni=%s" % [m._battle.over, before == mid])
	await _snap("bitis.png", 0.2)
	m._on_rematch()
	await get_tree().create_timer(0.5).timeout
	print("TEST MODU: tekrar test modu=%s mac suruyor=%s" % [m._testing, not m._battle.over])
	m._on_forfeit()
	await get_tree().create_timer(0.3).timeout
	var after := [m._profile.xp, m._profile.gold, m._profile.wins, m._profile.losses, m._profile.level]
	print("TEST MODU: menuye dondu=%s kayit ayni=%s" % [m._battle == null, before == after])
	get_tree().quit()


func _bot_button() -> Button:
	for c in m._hud._root.get_children():
		if c is Button and c.text.contains("Botla"):
			return c
	return null


## Rakip yokken bot onerisi: iptal edilen aramada cikmamali, beklenince cikmali, basinca bot maci baslamali.
func _bot_offer_test() -> void:
	await get_tree().create_timer(1.0).timeout
	m._quick_match("warrior", "Bot Deneme")
	await get_tree().create_timer(1.0).timeout
	m._leave_online()
	await get_tree().create_timer(GameMain.BOT_OFFER + 1.0).timeout
	print("BOT ONERISI: iptalden sonra cikti=%s" % (_bot_button() != null))
	m._quick_match("warrior", "Bot Deneme")
	await get_tree().create_timer(GameMain.BOT_OFFER - 2.0).timeout
	print("BOT ONERISI: sure dolmadan cikti=%s" % (_bot_button() != null))
	await get_tree().create_timer(3.0).timeout
	var b := _bot_button()
	print("BOT ONERISI: sure dolunca cikti=%s" % (b != null))
	await _snap("bot_onerisi.png", 0.3)
	b.pressed.emit()
	await _snap("bot_maci.png", 1.5)
	print("BOT MACI: basladi=%s yapay_zeka=%s rakip=%s" % [m._in_battle, m._mode == GameMain.Mode.AI, m._foe.ch["name"]])
	await get_tree().create_timer(3.0).timeout
	print("BOT MACI: 3 sn sonra hala savasta=%s" % m._in_battle)
	get_tree().quit()


## Iki kopya arasinda gercek ag testi: iki mac oynanir, sonra oda sahibi kapanir.
func _run_net_test(as_host: bool) -> void:
	var tag := "host" if as_host else "join"
	await get_tree().create_timer(1.0).timeout
	if as_host:
		m._host_room("warrior", "Ev Sahibi")
		while m._net.room_code == "" or not m._net._online:
			await get_tree().process_frame
		FileAccess.open(_test_dir.path_join("kod.txt"), FileAccess.WRITE).store_string(NetSession.CODE_LETTERS[m._net._broker] + m._net.room_code)
		print("sunucu: ", NetSession.BROKERS[m._net._broker])
		await _snap("host_lobi.png", 0.5)
	else:
		var code_file := _test_dir.path_join("kod.txt")
		while not FileAccess.file_exists(code_file):
			await get_tree().create_timer(0.3).timeout
		m._join_room("brute", "Misafir", FileAccess.get_file_as_string(code_file))
	for round_no in 2:
		while not m._in_battle:
			await get_tree().process_frame
		_test_casts = 0
		await get_tree().create_timer(1.5).timeout
		if round_no == 0: # canli mac duraklatma: katilan Bosluk ile durdurur, iki tarafta da savas saati durmali
			if not as_host:
				while m._hold_t > 0.0 or m._battle.pause_t > 0.0: # geri sayimda duraklatma kapali
					await get_tree().process_frame
				await get_tree().create_timer(0.5).timeout
				_press(KEY_SPACE)
				await get_tree().create_timer(0.6).timeout
				var c0: float = m._clock
				await _snap("join_duraklat.png", 0.0)
				await get_tree().create_timer(1.5).timeout
				print("DURAKLAT join: durdu=%s saat ilerledi=%.2f" % [m._paused, m._clock - c0])
				_press(KEY_SPACE)
				await get_tree().create_timer(0.8).timeout
				print("DURAKLAT join devam: durdu=%s" % m._paused)
				var hp_before: float = m._battle.ents[0].hp + m._battle.ents[1].hp
				var clock_before: float = m._clock
				_press(KEY_R) # aninda yeniden baslatma: katilan ister, oda sahibi yeni maci baslatir
				var rw := 0.0
				while m._clock >= clock_before and rw < 5.0:
					await get_tree().process_frame
					rw += get_process_delta_time()
				print("YENIDEN BASLAT join: yeni mac=%s saat %.1f -> %.1f" % [m._clock < clock_before, clock_before, m._clock])
			else:
				var w := 0.0
				while not m._paused and w < 5.0:
					await get_tree().process_frame
					w += get_process_delta_time()
				var c1: float = m._clock
				var p1: Vector2 = m._battle.ents[1].pos
				await get_tree().create_timer(1.0).timeout
				await _snap("host_duraklat.png", 0.0)
				print("DURAKLAT host: durdu=%s saat ilerledi=%.2f rakip kaydi=%.3f" % [m._paused, m._clock - c1, m._battle.ents[1].pos.distance_to(p1)])
				w = 0.0
				while m._paused and w < 5.0:
					await get_tree().process_frame
					w += get_process_delta_time()
				print("DURAKLAT host devam: durdu=%s" % m._paused)
		var keys: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]
		var i := 0
		var shot_taken := false
		while m._in_battle:
			# Yalnizca hazir ve menzildeki yetenege basilir: olcum gercek tepkiyi gosterir
			await get_tree().create_timer(0.15).timeout
			var ids: Array = GameData.CLASSES[m._cls]["skills"]
			var ready: int = -1
			for k in ids.size():
				var sk: Dictionary = GameData.SKILLS[ids[(i + k) % ids.size()]]
				if float(m._me.cds.get(ids[(i + k) % ids.size()], 0.0)) <= 0.0 and (not sk.has("range") or m._me.pos.distance_to(m._foe.pos) <= float(sk["range"]) - 0.1):
					ready = (i + k) % ids.size()
					break
			if ready < 0 or m._me.gcd > 0.0 or not m._me.alive or _lag_press != 0:
				if _lag_press != 0 and Time.get_ticks_msec() - _lag_press > 1500:
					_lag_press = 0
				continue
			_press(keys[ready])
			i = ready + 1
			if not shot_taken and m._in_battle:
				shot_taken = true
				await _snap("%s_tur%d.png" % [tag, round_no], 0.0)
		print("%s tur %d: sinif=%s/%s kazanan takim=%d benim takim=%d yetenegim=%d can A=%d B=%d gecikme=%d ms" % [tag, round_no, m._battle.ents[0].ch["cls"], m._battle.ents[1].ch["cls"], m._battle.winner, m._me.team, _test_casts, m._battle.ents[0].hp, m._battle.ents[1].hp, m._net.rtt_ms])
		print("%s tur %d: 1 sn icinde en cok mesaj=%d" % [tag, round_no, m._net.peak_rate])
		m._net.peak_rate = 0
		await _snap("%s_sonuc%d.png" % [tag, round_no], 0.3)
		if round_no == 0:
			m._cls = "assassin" if as_host else "warrior" # mac sonu sinif degistirme testi
			m._on_rematch()
			while m._battle.over:
				await get_tree().process_frame
	if not as_host:
		_lag_samples.sort()
		_state_gaps.sort()
		var n := _state_gaps.size()
		var total := 0
		for g in _state_gaps:
			total += g
		print("OLCUM yetenek tepkisi orta=%d en kotu=%d ms, %d ornek; durum sikligi %.1f/sn, en uzun bosluk=%d ms, %%95=%d ms, gidis-donus=%d ms, reddedilen tahmin (zaman asimi)=%d, siraya alinip birakilan=%d" % [_lag_samples[_lag_samples.size() / 2], _lag_samples[-1], _lag_samples.size(), n * 1000.0 / maxf(total, 1), _state_gaps[-1], _state_gaps[int(n * 0.95)], m._net.rtt_ms, _test_rejected, _test_queued])
	if as_host:
		await get_tree().create_timer(5.0).timeout
		get_tree().quit()
	else:
		await get_tree().create_timer(6.0).timeout
		await _snap("join_koptu.png", 0.0)
		get_tree().quit()


## art/portraits/ icin sinif basina yuvarlak portre fotografi cekip kapanir.
func _make_portraits() -> void:
	m._hud.visible = false
	m.set_process(false)
	for cls: String in GameData.CLASSES:
		m._cls = cls
		m._show_hero()
		await get_tree().create_timer(0.7).timeout
		if m._previews[0].rig != null:
			m._previews[0].rig.weapon.visible = false # balyoz yuzu kapatmasin
		elif cls == "brute" and m._previews[0]._hand != null:
			m._previews[0]._hand.visible = false # Mixamo Titan: balyoz sag el yuvasinda, yuzu kapatmasin
		var head := m._previews[0].head_position()
		m._camera.position = head + Vector3(0.0, 0.03, 1.5)
		m._camera.look_at(head + Vector3(0, 0.03, 0))
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
	m._hud.visible = false
	await get_tree().create_timer(0.6).timeout
	var v := m._previews[0]
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
		m._start_ai(cls, "")
		m._brains = []
		m._me.s = m._me.s.duplicate()
		m._foe.s = m._foe.s.duplicate()
		m._me.s["max_hp"] = 9000000.0
		m._foe.s["max_hp"] = 9000000.0
		m._me.hp = 9000000.0
		m._foe.hp = 9000000.0
		m._foe.atk_t = 9999.0
		m._me.atk_t = 9999.0
		var view := m._views[0]
		var sheet := Image.create(1600, 3500, false, Image.FORMAT_RGBA8)
		var ids: Array = GameData.CLASSES[cls]["skills"]
		while m._me.pos.distance_to(m._foe.pos) > float(m._me.s["range"]) + 0.2:
			await get_tree().process_frame
		for i in ids.size():
			var id: String = ids[i]
			var sk: Dictionary = GameData.SKILLS[id]
			var wind: float = sk.get("windup", 0.0)
			m._me.cds.clear()
			m._me.gcd = 0.0
			_worst_grip = 0.0
			_test_hit = 0
			var samples: Array = []
			_press(KEY_1 + i if i < 9 else KEY_0)
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
			# Akicilik: hazirlik 0,1 sn dilimlere bolunur; bir dilimden sonrakine silah ucu hizinin en buyuk artisi (ani hizlanma)
			var bins: Array[float] = []
			var bin_n: Array[int] = []
			for smp: Array in samples:
				var at: float = (smp[0] - start) / 1000.0
				if at > wind:
					break
				var k := int(at / 0.1)
				while bins.size() <= k:
					bins.append(0.0)
					bin_n.append(0)
				bins[k] += smp[1]
				bin_n[k] += 1
			var mean := 0.0
			for k in bins.size():
				bins[k] /= maxf(bin_n[k], 1)
				mean += bins[k] / bins.size()
			var jump := 1.0
			for k in range(1, bins.size()):
				jump = maxf(jump, bins[k] / maxf(bins[k - 1], mean * 0.25))
			if bins.size() > 1:
				print("AKICILIK %s/%s: en buyuk ani hizlanma %.1f kat" % [cls, id, jump])
			var note := "yetenek kendine" if _test_hit == 0 else "hasar ile silah vurusu arasi %.0f ms" % _test_gap
			print("YETENEK %s/%s: %s, kullanildi=%s%s" % [cls, id, note, float(m._me.cds.get(id, 0.0)) > 0.0, ", balyoz bosluk %.1f mm" % (_worst_grip * 1000.0) if cls == "brute" else ""])
		sheet.save_png(_test_dir.path_join(cls + "_yetenekler.png"))
		for n in 2:
			_test_hit = 0
			m._me.atk_t = 0.05
			var limit := Time.get_ticks_msec() + 4000
			while _test_hit == 0 and Time.get_ticks_msec() < limit:
				await get_tree().process_frame
			m._me.atk_t = 9999.0
			await get_tree().create_timer(1.5).timeout
			print("NORMAL %s %d: hasar ile silah vurusu arasi %.0f ms, vurus goruldu=%s" % [cls, n, _test_gap, _test_hit > 0])
	await _closeups_all()
	get_tree().quit()

func _closeups_all() -> void:
	await _closeup_views("brute", ["smash", "crush", "quake", "ruin"])
	await _closeup_views("warrior", ["power", "bash", "lunge", "whirl"])
	await _closeup_views("assassin", ["backstab", "hamstring", "expose", "flurry"])


## Ayni siniftan iki savasci karsilikli: normal saldiri ve yetenekler gercek kameradan, iki taraftan cekilir.
func _closeup_views(cls: String, ids: Array) -> void:
	m._hud.visible = false
	var rng := RandomNumberGenerator.new()
	var a := Rules.new_character("A", cls, GameMain.TEST_LEVEL, 1, rng)
	var c := Rules.new_character("B", cls, GameMain.TEST_LEVEL, 1, rng)
	m._mode = GameMain.Mode.AI
	m._begin(a, c, 1, 0)
	m._brains = []
	for e in m._battle.ents:
		e.s = e.s.duplicate()
		e.s["max_hp"] = 9000000.0
		e.hp = 9000000.0
		e.atk_t = 9999.0
	_worst_grip = 0.0
	var sheet := Image.create(2000, 3000, false, Image.FORMAT_RGBA8)
	await get_tree().create_timer(0.35).timeout
	await _closeup_shot(sheet, 0, 0)
	var range_now: float = m._me.s["range"] + 0.15
	while m._me.pos.distance_to(m._foe.pos) > range_now:
		await get_tree().process_frame
	await get_tree().create_timer(0.9).timeout
	await _closeup_shot(sheet, 1, 0)
	for e in m._battle.ents:
		e.atk_t = 0.0
	var swing: float = m._me.s["swing"]
	await get_tree().create_timer(swing * 0.5).timeout
	await _closeup_shot(sheet, 0, 1)
	await get_tree().create_timer(swing * 0.5 - 0.03).timeout
	await _closeup_shot(sheet, 1, 1)
	for e in m._battle.ents:
		e.atk_t = 9999.0
	await get_tree().create_timer(1.6).timeout
	var row := 1
	for id: String in ids:
		row += 1
		for e in m._battle.ents:
			e.cds.clear()
			e.gcd = 0.0
			m._battle.command({"ent": e.id, "type": "skill", "skill": id})
		var wind: float = GameData.SKILLS[id].get("windup", 0.0)
		await get_tree().create_timer(wind * 0.6).timeout
		await _closeup_shot(sheet, 0, row)
		await get_tree().create_timer(maxf(wind * 0.4 - 0.02, 0.01)).timeout
		await _closeup_shot(sheet, 1, row)
		await get_tree().create_timer(2.2).timeout
	sheet.save_png(_test_dir.path_join(cls + "_yakin.png"))
	print("%s iki yon balyoz bosluk %.1f mm" % [cls, _worst_grip * 1000.0])

## Kare seridi: bir sinifin bekleme durusu, duz vurusu ve her yetenegi yandan 7 karede. Rakip hareketsiz.
## Her satir icin olcum: govde egikligi (pelvis->boyun dikeyle aci), sol elin sap ekseninden uzakligi (Titan),
## en alcak ayak bilegi/parmak yuksekligi (yerin altina inerse eksi).
func _film(cls: String) -> void:
	m._hud.visible = false
	var rng := RandomNumberGenerator.new()
	var a := Rules.new_character("A", cls, GameMain.TEST_LEVEL, 1, rng)
	var c := Rules.new_character("B", "warrior", GameMain.TEST_LEVEL, 1, rng)
	m._mode = GameMain.Mode.AI
	m._begin(a, c, 1, 0)
	m._brains = []
	for e in m._battle.ents:
		e.s = e.s.duplicate()
		e.s["max_hp"] = 9000000.0
		e.hp = 9000000.0
		e.atk_t = 9999.0
	await get_tree().create_timer(0.4).timeout
	var range_now: float = m._me.s["range"] + 0.15
	var guard := 0
	while m._me.pos.distance_to(m._foe.pos) > range_now and guard < 600:
		guard += 1
		await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	var ids: Array = ["", "*"] + Array(GameData.CLASSES[cls]["skills"])
	var cols := 7
	var cell := 300
	var sheet := Image.create(cols * cell, ids.size() * cell, false, Image.FORMAT_RGBA8)
	var v: CharacterView = m._views[m._me.id]
	for row in ids.size():
		var id: String = ids[row]
		var span := 1.4
		if id == "*":
			m._me.atk_t = 0.0
			span = float(m._me.s["swing"]) + 1.0
		elif id != "":
			m._me.cds.clear()
			m._me.gcd = 0.0
			m._battle.command({"ent": m._me.id, "type": "skill", "skill": id})
			var sk: Dictionary = GameData.SKILLS[id]
			var hits: Array = sk.get("hits", [0.0])
			span = float(sk.get("windup", 0.0)) + float(hits[hits.size() - 1]) + 1.0
		_feet_last.clear()
		var lean := 0.0
		var lean_sum := 0.0
		var gap := 0.0
		var low := 9.0
		var n := 0
		var t0 := Time.get_ticks_msec()
		var next_shot := 0.0
		var col := 0
		while (Time.get_ticks_msec() - t0) * 0.001 < span:
			await get_tree().process_frame
			var el := (Time.get_ticks_msec() - t0) * 0.001
			var q := _pose_metrics(v)
			lean = maxf(lean, q[0])
			lean_sum += q[0]
			gap = maxf(gap, q[1])
			low = minf(low, q[2])
			n += 1
			if el >= next_shot and col < cols:
				var img: Image = await _shot()
				img.convert(Image.FORMAT_RGBA8)
				var s := m._camera.unproject_position(v.global_position + Vector3(0, 1.05, 0))
				var rect := Rect2i(int(s.x) - 330, int(s.y) - 380, 660, 660).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
				var crop := img.get_region(rect)
				if col == 0 and row < 2:
					crop.save_png(_test_dir.path_join("%s_buyuk_%d.png" % [cls, row]))
				crop.resize(cell, cell)
				sheet.blit_rect(crop, Rect2i(0, 0, cell, cell), Vector2i(col * cell, row * cell))
				col += 1
				next_shot += span / cols
		m._me.atk_t = 9999.0
		print("FILM_SAP %s sol el sap boyunca ort %.1f cm" % [id, _along_sum / maxf(_along_n, 1) * 100.0])
		_along_sum = 0.0
		_along_n = 0
		print("FILM %-9s egiklik ort %4.1f max %4.1f derece | sol el-sap %5.1f cm | en alcak ayak %5.1f cm" % [
			"bekleme" if id == "" else ("duz" if id == "*" else id), lean_sum / maxf(n, 1), lean, gap * 100.0, low * 100.0])
		print("FILM_AYAK %s yere basan ayak kayma toplam %.0f cm, tek karede en cok %.1f cm" % [id, _slide_sum * 100.0, _slide_max * 100.0])
		_slide_max = 0.0
		_slide_sum = 0.0
		await get_tree().create_timer(0.8).timeout
	sheet.save_png(_test_dir.path_join(cls + "_film.png"))


## [govde egikligi derece, sol el sap ekseninden uzaklik m (yalniz balyoz), en alcak ayak noktasi m (dunya, yer=0)]
func _pose_metrics(v: CharacterView) -> Array:
	# Son poz (IK, ayak ve durus duzeltmeleri sonrasi) yalniz BoneAttachment ile okunur: get_bone_global_pose duzeltme oncesini verir.
	if not _probes.has(v):
		var d := {}
		for b: String in ["pelvis", "neck_01", "hand_l", "foot_l", "foot_r", "ball_l", "ball_r"]:
			var at := BoneAttachment3D.new()
			v._skeleton.add_child(at)
			at.bone_name = b
			var p := Node3D.new()
			at.add_child(p)
			if b == "hand_l" and v._grip_follow != null:
				p.position = v._grip_follow.center # avuc ortasi
			d[b] = p
		_probes[v] = d
	var pr: Dictionary = _probes[v]
	var lean := rad_to_deg((pr["neck_01"].global_position - pr["pelvis"].global_position).angle_to(Vector3.UP))
	var gap := 0.0
	if v._weapon == "sledge" and v._hand != null:
		var axis := v._hand.global_transform.basis.y.normalized()
		var d: Vector3 = pr["hand_l"].global_position - v._hand.global_position
		gap = (d - axis * d.dot(axis)).length()
		_along_sum += d.dot(axis)
		_along_n += 1
	# taban: parmak/bilek kemiginden olculmus taban payi (CharacterView.SOLE) dusulur, yer = karakterin y'si. Eksi = yere gomulu.
	var s: Array = CharacterView.SOLE.get(v._px, [0.0, 0.0])
	var low := 9.0
	var slide := 0.0
	for side: String in ["l", "r"]:
		var sole := minf(pr["ball_" + side].global_position.y - float(s[0]), pr["foot_" + side].global_position.y - float(s[1])) - v.global_position.y
		low = minf(low, sole)
		var key := str(v.get_instance_id()) + side
		var p: Vector3 = pr["foot_" + side].global_position
		if sole < 0.02 and _feet_last.has(key): # yere basan ayak kaymamali
			var q: Vector3 = _feet_last[key]
			var step := Vector2(p.x - q.x, p.z - q.z).length()
			slide = maxf(slide, step)
			_slide_sum += step
		_feet_last[key] = p
	_slide_max = maxf(_slide_max, slide)
	return [lean, gap, low]


func _closeup_shot(sheet: Image, col: int, row: int) -> void:
	var img: Image = await _shot()
	img.convert(Image.FORMAT_RGBA8)
	for i in 2:
		var s := m._camera.unproject_position(m._views[i].global_position + Vector3(0, 1.05, 0))
		var rect := Rect2i(int(s.x) - 310, int(s.y) - 310, 620, 620).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
		var crop := img.get_region(rect)
		crop.resize(500, 500)
		sheet.blit_rect(crop, Rect2i(0, 0, 500, 500), Vector2i(i * 1000 + col * 500, row * 500))

## Gercek model yuzeyiyle tam denetim: her sinif, her hareket, iki taraf. En kotu kare kaydedilir.
func _run_audit() -> void:
	m._hud.visible = false
	await get_tree().create_timer(0.8).timeout
	for cls: String in GameData.CLASSES:
		var rng := RandomNumberGenerator.new()
		m._mode = GameMain.Mode.AI
		m._begin(Rules.new_character("A", cls, GameMain.TEST_LEVEL, 1, rng), Rules.new_character("B", cls, GameMain.TEST_LEVEL, 1, rng), 1, 0)
		m._hud.visible = false
		m._brains = []
		for e in m._battle.ents:
			e.s = e.s.duplicate()
			e.s["max_hp"] = 9000000.0
			e.hp = 9000000.0
			e.atk_t = 9999.0
		var audits: Array[MeshAudit] = [MeshAudit.new(m._views[0]), MeshAudit.new(m._views[1])]
		var limit: float = float(m._me.s["range"]) + 0.15
		await _audit_step(cls, "yurume", audits, func() -> bool: return m._me.pos.distance_to(m._foe.pos) > limit, -1.0)
		await _audit_step(cls, "bekleme", audits, Callable(), 1.6)
		for n in 2:
			for e in m._battle.ents:
				e.atk_t = 0.0
			await _audit_step(cls, "normal%d" % (n + 1), audits, Callable(), float(m._me.s["swing"]) + 1.3)
			for e in m._battle.ents:
				e.atk_t = 9999.0
		var ids: Array = GameData.CLASSES[cls]["skills"]
		for i in ids.size():
			var id: String = ids[i]
			for e in m._battle.ents:
				e.cds.clear()
				e.gcd = 0.0
				m._battle.command({"ent": e.id, "type": "skill", "skill": id})
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
				var s := m._camera.unproject_position(m._views[i].global_position + Vector3(0, 1.05, 0))
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

## Titan'in uc zamanlama yetenegi gercek ekranda: kavrama, Buz Muhru ve Buz Kolu karsi saldirisi.
func _titan_test() -> void:
	await get_tree().create_timer(0.5).timeout
	m._start_ai("brute", "Test")
	m._brains = []
	var me := m._me
	var foe := m._foe
	for e: Battle.Ent in [me, foe]:
		e.s = e.s.duplicate()
		e.s["max_hp"] = 9000000.0
		e.hp = 9000000.0
		e.atk_t = 9999.0
	me.skills.assign(GameData.CLASSES["brute"]["skills"])
	if not foe.skills.has("power"):
		foe.skills.append("power")
	while me.pos.distance_to(foe.pos) > float(me.s["range"]) + 0.2:
		await get_tree().process_frame
	var reset := func() -> void:
		for e: Battle.Ent in [me, foe]:
			e.cds.clear()
			e.gcd = 0.0
			e.fx.clear()
	m._battle.command({"ent": foe.id, "type": "skill", "skill": "power"})
	await get_tree().create_timer(0.1).timeout
	m._battle.command({"ent": me.id, "type": "skill", "skill": "slam"})
	await _snap("1_sicrayis_a.png", 0.4)
	await _snap("1_sicrayis_b.png", 0.3)
	await get_tree().create_timer(2.5).timeout
	reset.call()
	m._battle.command({"ent": me.id, "type": "skill", "skill": "frost"})
	await _snap("2_buz_muhru_hazirlik.png", 0.8)
	await _snap("2_buz_muhru_dondu.png", 0.95)
	await get_tree().create_timer(2.5).timeout
	reset.call()
	m._battle.command({"ent": foe.id, "type": "skill", "skill": "power"})
	await get_tree().create_timer(0.45).timeout
	m._battle.command({"ent": me.id, "type": "skill", "skill": "icearm"})
	await _snap("3_buz_kolu_a.png", 0.2)
	await _snap("3_buz_kolu_b.png", 0.3)
	print("TITAN TEST BITTI donmus=%s" % m._battle.has_fx(foe, "freeze"))
	get_tree().quit()


## Mac bitirme dugmesi: tek tik bitirmez, iki tik yenilgi ekranina goturur, tekrar savas calisir.
## Gercek ekranda: rakip Yikim hazirlarken tus 7 tam darbe aninda basilir; ekran goruntusu ve hasar yazilir.
func _parry_test() -> void:
	await get_tree().create_timer(0.5).timeout
	m._start_ai("warrior", "Test")
	m._brains = []
	m._foe.ch = m._foe.ch.duplicate()
	while m._me.pos.distance_to(m._foe.pos) > 2.2:
		await get_tree().process_frame
	m._foe.skills = ["ruin"] as Array[String]
	m._me.atk_t = 999.0
	m._foe.atk_t = 999.0
	var hp: float = m._me.hp
	m._battle.command({"ent": m._foe.id, "type": "skill", "skill": "ruin"})
	await get_tree().create_timer(float(GameData.SKILLS["ruin"]["windup"]) - 0.2).timeout
	await _snap("parry_oncesi.png", 0.0)
	_press(KEY_7)
	await get_tree().create_timer(0.3).timeout
	await _snap("parry_ani.png", 0.0)
	await get_tree().create_timer(0.5).timeout
	await _snap("parry_sonrasi.png", 0.0)
	print("PARRY hasar=%d sarsinti=%s" % [hp - m._me.hp, m._battle.has_fx(m._foe, "reel") or m._foe.cast_t <= 0.0])
	get_tree().quit()


func _forfeit_test() -> void:
	await get_tree().create_timer(0.5).timeout
	m._start_ai("warrior", "Test")
	await get_tree().create_timer(1.5).timeout
	var b: Button = m._hud.forfeit_button
	b.pressed.emit()
	await get_tree().create_timer(0.3).timeout
	print("MAC BITIR tek tik: mac suruyor=", not m._battle.over, " yazi=", b.text)
	b.pressed.emit()
	await get_tree().create_timer(0.2).timeout
	print("MAC BITIR iki tik: bitti=", m._battle.over, " kazandim=", m._battle.winner == m._me.team)
	await get_tree().create_timer(2.2).timeout
	print("MAC BITIR sonuc ekrani: savasta=", m._in_battle)
	m._on_rematch()
	await get_tree().create_timer(1.5).timeout
	print("MAC BITIR tekrar: savasta=", m._in_battle, " bitti=", m._battle.over)
	get_tree().quit()

## Hasar tepkisi: gercek vurustan hemen sonraki kareler ve en buyuk geriye yatma acisi.
func _hit_test() -> void:
	await get_tree().create_timer(0.5).timeout
	var rng := RandomNumberGenerator.new()
	m._mode = GameMain.Mode.AI
	m._begin(Rules.new_character("A", "brute", GameMain.TEST_LEVEL, 1, rng), Rules.new_character("B", "warrior", GameMain.TEST_LEVEL, 1, rng), 1, 0)
	m._brains = []
	m._foe.atk_t = 9999.0
	m._me.atk_t = 9999.0
	for e in m._battle.ents:
		e.s = e.s.duplicate()
		e.s["max_hp"] = 9000000.0
		e.hp = 9000000.0
	while m._me.pos.distance_to(m._foe.pos) > float(m._me.s["range"]) + 0.1:
		await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	var foe: CharacterView = m._views[1]
	for label: String in ["hafif", "agir"]:
		_test_hit = 0
		foe._recoil = 0.0
		if label == "hafif":
			m._me.atk_t = 0.05
		else:
			m._me.cds.clear()
			m._me.gcd = 0.0
			m._battle.command({"ent": m._me.id, "type": "skill", "skill": "smash"})
		while _test_hit == 0:
			await get_tree().process_frame
		m._me.atk_t = 9999.0
		var sheet := Image.create(1800, 600, false, Image.FORMAT_RGBA8)
		var most := 0.0
		for i in 3:
			await get_tree().create_timer(0.07).timeout
			var img: Image = await _shot()
			img.convert(Image.FORMAT_RGBA8)
			most = maxf(most, foe._recoil)
			var c := m._camera.unproject_position(foe.global_position + Vector3(0, 1.0, 0))
			var crop := img.get_region(Rect2i(int(c.x) - 330, int(c.y) - 330, 660, 660).intersection(Rect2i(Vector2i.ZERO, img.get_size())))
			crop.resize(600, 600)
			sheet.blit_rect(crop, Rect2i(0, 0, 600, 600), Vector2i(i * 600, 0))
		sheet.save_png(_test_dir.path_join("hasar_%s.png" % label))
		print("HASAR %s: geriye yatma %.0f derece" % [label, rad_to_deg(most)])
		await get_tree().create_timer(2.2).timeout
	get_tree().quit()

## Normal saldiri kare seridi: --atk=<klasor>:<sinif>. Saldiri baslar baslamaz 0,06 sn arayla 16 kare (4x4).
func _atk_test(cls: String) -> void:
	await get_tree().create_timer(0.5).timeout
	var rng := RandomNumberGenerator.new()
	m._mode = GameMain.Mode.AI
	m._begin(Rules.new_character("A", cls, GameMain.TEST_LEVEL, 1, rng), Rules.new_character("B", "warrior", GameMain.TEST_LEVEL, 1, rng), 1, 0)
	m._brains = []
	m._foe.atk_t = 9999.0
	m._me.atk_t = 9999.0
	for e in m._battle.ents:
		e.s = e.s.duplicate()
		e.s["max_hp"] = 9000000.0
		e.hp = 9000000.0
	while m._me.pos.distance_to(m._foe.pos) > float(m._me.s["range"]) + 0.1:
		await get_tree().process_frame
	await get_tree().create_timer(1.2).timeout
	var me: CharacterView = m._views[0]
	m._me.atk_t = 0.05
	var sheet := Image.create(1800, 1500, false, Image.FORMAT_RGBA8)
	var t0 := Time.get_ticks_msec()
	for i in 30:
		var img: Image = await _shot()
		img.convert(Image.FORMAT_RGBA8)
		var c := m._camera.unproject_position(me.global_position + Vector3(0, 1.0, 0))
		var crop := img.get_region(Rect2i(int(c.x) - 300, int(c.y) - 330, 640, 640).intersection(Rect2i(Vector2i.ZERO, img.get_size())))
		crop.resize(300, 300)
		sheet.blit_rect(crop, Rect2i(0, 0, 300, 300), Vector2i((i % 6) * 300, (i / 6) * 300))
		print("ATK kare %d t=%.2f" % [i, (Time.get_ticks_msec() - t0) * 0.001])
		if i == 20:
			m._me.atk_t = 9999.0
		await get_tree().create_timer(0.06).timeout
	sheet.save_png(_test_dir.path_join("saldiri_%s.png" % cls))
	get_tree().quit()


## Ses: gercek macta hangi sesler calindi, muzik degisti mi, ana cikista seviye kac dB.
func _audio_test(cls := "brute") -> void:
	var s := SoundBank.me
	await get_tree().create_timer(1.5).timeout
	print("SES menu muzigi=", s.current.get_file())
	var menu_peak := -200.0
	for i in 60:
		await get_tree().process_frame
		menu_peak = maxf(menu_peak, AudioServer.get_bus_peak_volume_left_db(0, 0))
	print("SES menu tepe %.1f dB" % menu_peak)
	m._start_ai(cls, "Test")
	var peak := -200.0
	var over := 0
	var ids: Array = GameData.CLASSES[cls]["skills"]
	var limit := Time.get_ticks_msec() + 30000
	var n := 0
	while m._in_battle and not m._battle.over and Time.get_ticks_msec() < limit:
		await get_tree().create_timer(0.1).timeout
		var level := AudioServer.get_bus_peak_volume_left_db(0, 0)
		peak = maxf(peak, level)
		over += int(level > -0.5)
		n += 1
		if n % 15 == 0:
			_press(KEY_1 + (n / 15) % mini(ids.size(), 9))
	print("SES savas muzigi=", s.current.get_file(), " sayac=", s.counts)
	print("SES savas tepe %.1f dB, kirpilmaya yakin olcum %d / %d" % [peak, over, n])
	get_tree().quit()


## Yeni ekranlar: menu, ayarlar, kurallar, yetenekler, basarimlar, karakter ve demirci, sandik, odul ekrani,
## savasta durum isaretleri ve duraklatma. --telefon ile telefon boyunda. Kareler gozle kontrol icin.
func _screens_test(phone: bool) -> void:
	if phone:
		Version.force_phone = true
		get_window().content_scale_factor = 1.4
		m._show_select()
	var p := m._profile
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	await _snap("menu.png", 1.2)
	for c: String in ["brute", "assassin"]: # menudeki sinif onizlemesi (kullanici ekran goruntusu)
		m._on_class_changed(c)
		await _snap("menu_%s.png" % c, 1.5)
	m._on_class_changed("warrior")
	var hud := m._hud
	for shot: Array in [["ayarlar", hud.screens.settings], ["kurallar", hud.screens.help], ["yetenekler", func() -> void: hud.screens.skills("brute", 5)], ["basarimlar", func() -> void: hud.screens.achievements(p)]]:
		shot[1].call()
		await _snap(shot[0] + ".png", 0.4)
		print("EKRAN %s: pencere=%s" % [shot[0], hud.has_overlay()])
		hud.close_overlay()
		await get_tree().process_frame
	print("EKRAN: pencereler kapandi=%s" % (not hud.has_overlay()))
	p.gold = 9000
	p.points = 4
	for r: int in [0, 2, 4]:
		p.bag.append(Rules.make_item(GameData.SLOTS[r % 4], 9, r, "warrior", rng))
	hud.show_character()
	await _snap("karakter.png", 0.4)
	var it := p.open_chest(rng)
	hud.show_character()
	hud.screens.reveal(p, it, hud.show_character)
	await _snap("sandik.png", 0.7)
	var bag_before := p.bag.size()
	m._on_escape()
	await get_tree().create_timer(0.2).timeout
	print("EKRAN sandik: Esc kapatti=%s esya cantada=%s" % [not hud.has_overlay(), p.bag.size() == bag_before])
	var plus_gold := p.gold
	p.upgrade("weapon")
	hud.show_character()
	await _snap("demirci.png", 0.4)
	print("EKRAN demirci: derece=%d altin dustu=%s" % [p.equipped["weapon"]["plus"], p.gold < plus_gold])
	p.stage = 10
	p.xp = Rules.xp_need(p.level) - 20
	var reward := p.grant(true, rng)
	hud.show_result(true, true, m._cls, {"reward": reward, "stats": {"dmg": 1234, "best": 456, "parry": 2, "cut": 1, "time": 47}, "ach": [GameData.ACHIEVEMENTS[0]], "note": "Galibiyet serisi: 3"})
	await _snap("odul_basi.png", 0.25)
	await _snap("odul_sonu.png", 2.4)
	print("EKRAN odul: seviye atladi=%d ganimet=%s" % [reward["levels"], not reward["loot"].is_empty()])
	m._start_ai("warrior", "Deneme")
	while m._me.pos.distance_to(m._foe.pos) > float(m._me.s["range"]) + 0.2:
		await get_tree().process_frame
	m._foe.fx.append({"type": "stun", "t": 6.0})
	m._foe.fx.append({"type": "dot", "t": 6.0, "src": 0, "tick": 1.0, "dps": 1.0})
	m._me.fx.append({"type": "buff", "t": 6.0, "atk": 0.3})
	await _snap("durum.png", 0.4)
	var t0 := Time.get_ticks_msec()
	while m._me.basic_t <= 0.0 and Time.get_ticks_msec() - t0 < 4000:
		await get_tree().process_frame
	await _snap("duz_vurus.png", 0.05) # duz vurus surerken yetenek simgelerinde X
	m._on_escape()
	await _snap("duraklat.png", 0.3)
	print("EKRAN Esc: duraklatti=%s" % m._paused)
	hud.screens.settings()
	m._on_escape()
	await get_tree().process_frame
	print("EKRAN Esc: ayar kapandi, hala duraklatildi=%s" % m._paused)
	m._on_escape()
	await get_tree().process_frame
	print("EKRAN Esc: devam etti=%s" % (not m._paused))
	m._foe.hp = 1.0
	m._me.cds.clear()
	m._me.gcd = 0.0
	m._battle.command({"ent": m._me.id, "type": "skill", "skill": m._me.skills[0]})
	var wait := 0.0
	while m._in_battle and wait < 8.0:
		wait += get_process_delta_time()
		await get_tree().process_frame
	await _snap("mac_sonu.png", 2.6)
	print("EKRAN mac sonu: hasar=%d sure=%d zaman olcegi=%.2f" % [m._stats["dmg"], int(m._clock), Engine.time_scale])
	# Test Modu: P duraklatir, "Yeniden Oyna" maci bastan acar
	m._start_test("warrior", "Deneme")
	await get_tree().create_timer(0.5).timeout
	var pkey := InputEventKey.new()
	pkey.keycode = KEY_P
	pkey.pressed = true
	m._unhandled_input(pkey)
	await _snap("test_duraklat.png", 0.2)
	var paused: bool = m._paused
	var old_battle: Battle = m._battle
	m._on_test_action("restart")
	await get_tree().create_timer(0.3).timeout
	print("EKRAN test modu: P duraklatti=%s, yeniden oyna yeni mac=%s duraklama kalkti=%s" % [paused, m._battle != old_battle and m._in_battle, not m._paused])
	get_tree().quit()


## Canli macta biri ayrilir: ayrilan yenilgi alir, kalan galibiyet ve odul alir, tekrar savas dugmesi cikmaz.
## Iki kopya: biri --net-leave=<klasor> --ev (odayi acar ve 18 sn sonra ayrilir), digeri --net-leave=<klasor>.
func _net_leave_test(as_host: bool) -> void:
	await get_tree().create_timer(1.0).timeout
	var code_file := _test_dir.path_join("kod.txt")
	if as_host:
		if FileAccess.file_exists(code_file):
			DirAccess.remove_absolute(code_file)
		m._host_room("warrior", "Giden")
		while m._net.room_code == "" or not m._net._online:
			await get_tree().process_frame
		FileAccess.open(code_file, FileAccess.WRITE).store_string(NetSession.CODE_LETTERS[m._net._broker] + m._net.room_code)
	else:
		await get_tree().create_timer(2.0).timeout
		while not FileAccess.file_exists(code_file):
			await get_tree().create_timer(0.3).timeout
		m._join_room("brute", "Kalan", FileAccess.get_file_as_string(code_file))
	var limit := 60.0
	while not m._in_battle and limit > 0.0:
		limit -= 0.1
		await get_tree().create_timer(0.1).timeout
	print("AYRILMA %s: mac basladi=%s" % ["ev" if as_host else "misafir", m._in_battle])
	for e in m._battle.ents: # kimse olmesin, mac surebilsin
		e.s = e.s.duplicate()
		e.s["max_hp"] = 9000000.0
		e.hp = 9000000.0
	if as_host:
		await get_tree().create_timer(18.0).timeout
		var losses := m._profile.losses
		m._leave_match()
		print("AYRILMA ev: yenilgi yazildi=%s menude=%s" % [m._profile.losses == losses + 1, m._battle == null])
		await get_tree().create_timer(3.0).timeout
	else:
		var before_gold := m._profile.gold
		var wins := m._profile.wins
		while m._in_battle:
			await get_tree().process_frame
		await _snap("ayrilma_sonuc.png", 0.5)
		var again := false
		for b in m._hud._root.find_children("*", "Button", true, false):
			again = again or (b as Button).text == m._hud.again_text
		print("AYRILMA misafir: galibiyet=%s odul altin=%d canli galibiyet=%d tekrar savas yok=%s sure=%d" % [m._profile.wins == wins + 1, m._profile.gold - before_gold, m._profile.online_wins, not again, int(m._clock)])
	get_tree().quit()


## Kare hizi olcumu: her sinifla 12 sn gercek bot maci (yetenek tuslari da basilir), dikey esitleme kapali.
## Ortalama kare hizi, en kotu %1 (takilma hissi), en uzun kare, 25 ms ustu takilma sayisi, cizim cagrisi ve ucgen.
## --telefon: telefon ayarlari (dusuk kalite). Telefon cizimine yakin olcum icin --rendering-method gl_compatibility.
func _perf_test(phone: bool) -> void:
	if phone:
		Version.force_phone = true
		m._low_quality = true
		m._arena.set_low_quality()
	var v := OS.get_environment("PERF_DENEME") # gecici ayristirma: ay_golge, spot_golge, golgesiz
	for l: Light3D in m._arena.find_children("*", "Light3D", true, false):
		if (v == "ay_golge" or v == "golgesiz") and l is DirectionalLight3D:
			l.shadow_enabled = false
		if (v == "spot_golge" or v == "golgesiz") and l is SpotLight3D:
			l.shadow_enabled = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await get_tree().create_timer(1.0).timeout
	var vp := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	for cls: String in GameData.CLASSES:
		m._test_immortal = true # mac olcum bitmeden bitmesin
		m._start_ai(cls, "")
		m._battle.immortal = true
		await get_tree().create_timer(1.5).timeout # yukleme ve ilk derleme takilmasi olcume girmesin
		var times: Array[float] = []
		var calls := 0.0
		var tris := 0.0
		var gpu := 0.0
		var n := 0
		var last := Time.get_ticks_usec()
		var end := Time.get_ticks_msec() + 12000
		var key := 0
		while Time.get_ticks_msec() < end:
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			times.append((now - last) / 1000.0)
			if (now - last) > 40000:
				print("  TAKILMA %s %.0f ms: kare %d, son tus %d, %s" % [cls, (now - last) / 1000.0, n, key, m._last_skill])
			last = now
			calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			tris += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
			n += 1
			if n % 90 == 0:
				_press([KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6][key % 6])
				key += 1
		var sorted := times.duplicate()
		sorted.sort()
		var total := 0.0
		for t in times:
			total += t
		var p99: float = sorted[int(sorted.size() * 0.99)]
		var spikes := times.filter(func(t: float) -> bool: return t > 25.0).size()
		print("PERF %s%s: ortalama %.0f kare/sn, en kotu %%1 %.0f kare/sn, en uzun kare %.1f ms, 25 ms ustu takilma %d, cizim cagrisi %.0f, ucgen %.0f bin, GPU %.1f ms" % [cls, " (telefon)" if phone else "", times.size() / (total / 1000.0), 1000.0 / p99, sorted[-1], spikes, calls / n, tris / n / 1000.0, gpu / n])
		m._test_immortal = false
	get_tree().quit()


## Olcum (host): katilanin yetenegi geldigi anda host neden hemen baslatamiyor?
func on_remote_skill(id: String) -> void:
	var e: Battle.Ent = m._battle.ents[1]
	if m._battle.can_cast(e, id):
		return
	var sk: Dictionary = GameData.SKILLS[id]
	var why: Array[String] = []
	if e.basic_t > 0.0:
		why.append("duz vurus %.2f" % e.basic_t)
	if e.lock > 0.0:
		why.append("kilit %.2f" % e.lock)
	if m._battle.stopped(e):
		why.append("sersem/donuk")
	if float(e.cds.get(id, 0.0)) > 0.0:
		why.append("bekleme %.2f" % float(e.cds[id]))
	if e.gcd > 0.0:
		why.append("ortak %.2f" % e.gcd)
	if e.cast_t > 0.0:
		why.append("hazirlik %.2f" % e.cast_t)
	if sk.has("range") and e.target != null and e.pos.distance_to(e.target.pos) > float(sk["range"]):
		why.append("menzil %.2f>%.2f" % [e.pos.distance_to(e.target.pos), float(sk["range"])])
	print("  HOST HEMEN BASLATAMADI %s: %s, siraya=%s" % [id, ", ".join(why), m._battle.can_queue(e, id)])
