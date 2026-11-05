extends SceneTree
## Kumas sallanmasi olcumu: karakter 1 sn bekler, 1,5 sn kosar, durur, yerinde 180 derece doner ve 2 sn bekler.
## Her kumas zincirinin ucu kalcaya gore izlenir.
## Basari: kosarken uc geriye kalir (en az 3 cm), duruslarda sakin (kare basi titreme < 4 mm), hicbir an kopmaz (kalcadan
## 1,6 m'den uzak degil), bacak kemiklerinin icine girmez (en yakin mesafe > 3 cm), sonda 1 sn icinde yatisir.
## Kullanim: godot --path godot --resolution 960x540 --script res://tests/cloth_check.gd -- [resim klasoru]


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0] if a.size() > 0 else ""
	Engine.max_fps = 60
	var root := Node3D.new()
	get_root().add_child(root)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.7, 0.4, 0)
	root.add_child(sun)
	var ok := true
	for cls: String in ["assassin", "brute"]:
		var ch := Rules.new_character("A", cls, 8, 1, RandomNumberGenerator.new())
		var e := Battle.Ent.new()
		e.ch = ch
		e.s = {"speed": GameData.CLASSES[cls]["speed"], "swing": 0.7, "recover": 0.5, "max_hp": 100.0}
		e.face = PI / 2.0
		e.pos = Vector2(-3.0, 0.0)
		var v := CharacterView.new()
		root.add_child(v)
		v.setup(ch, e)
		var sk := v._skeleton
		if v.cloth_sim == null:
			print("KUMAS %s: kumas kemigi yok -> SORUN" % cls)
			ok = false
			continue
		var tips: Array[BoneAttachment3D] = []
		var names: Array[String] = []
		for i in sk.get_bone_count():
			var n := sk.get_bone_name(i)
			if n.begins_with("kumas_") and sk.find_bone(n.trim_suffix(n.get_slice("_", n.get_slice_count("_") - 1)) + str(int(n.get_slice("_", n.get_slice_count("_") - 1)) + 1)) < 0:
				var h := BoneAttachment3D.new()
				h.bone_name = n
				sk.add_child(h)
				tips.append(h)
				names.append(n)
		var pel := BoneAttachment3D.new()
		pel.bone_name = "pelvis"
		sk.add_child(pel)
		var legs: Array[BoneAttachment3D] = []
		for b: String in ["thigh_l", "calf_l", "thigh_r", "calf_r", "foot_l", "foot_r"]:
			var h := BoneAttachment3D.new()
			h.bone_name = b
			sk.add_child(h)
			legs.append(h)
		var speed: float = GameData.CLASSES[cls]["speed"]
		var rest: Array[Vector3] = []
		var prev: Array[Vector3] = []
		var prev2: Array[Vector3] = []
		var lag: Array[float] = []
		var jitter := 0.0
		var far := 0.0
		var near := 9.0
		var end_move := 0.0
		var shots: Array[Image] = []
		for f in 400:
			var phase := "bekle"
			if f >= 60 and f < 150:
				phase = "kos"
				e.moving = true
				e.pos.x += speed / 60.0
			else:
				e.moving = false
			if f >= 150 and f < 180:
				phase = "don"
				e.face = PI / 2.0 + PI * (f - 150) / 30.0
			cam.position = Vector3(v.position.x, 1.0, 3.6)
			await process_frame
			var inv := pel.global_transform.affine_inverse()
			for k in tips.size():
				var p := inv * tips[k].global_position
				if f == 59:
					rest.append(p)
				if f >= 60 and rest.size() > k:
					if phase == "kos" and f > 90:
						if lag.size() <= k:
							lag.append(0.0)
						# kalca uzayinda kosu yonu: modelin onu (+Z); geride kalma = -Z yonunde kayma
						lag[k] = maxf(lag[k], rest[k].z - p.z)
				far = maxf(far, p.length())
				if prev2.size() > k and phase == "bekle" and f < 59 and f > 20:
					jitter = maxf(jitter, (p - prev[k] * 2.0 + prev2[k]).length())
				if f >= 370 and prev.size() > k:
					end_move = maxf(end_move, (p - prev[k]).length())
				for leg in legs:
					near = minf(near, tips[k].global_position.distance_to(leg.global_position))
				if prev.size() > k:
					prev2.resize(tips.size())
					prev2[k] = prev[k]
					prev[k] = p
				else:
					prev.append(p)
			if out != "" and f in [55, 120, 165, 200]:
				shots.append(get_root().get_texture().get_image())
		var min_lag := 9.0
		for x in lag:
			min_lag = minf(min_lag, x)
		var good := min_lag > 0.03 and jitter < 0.004 and far < 1.6 and near > 0.03 and end_move < 0.004
		ok = ok and good
		print("KUMAS %s (%d zincir: %s): kosuda geride kalma en az %.0f cm, durusta titreme %.1f mm, en uzak %.2f m, bacaga en yakin %.0f cm, sondaki hareket %.1f mm/kare -> %s" % [cls, names.size(), ",".join(names), min_lag * 100.0, jitter * 1000.0, far, near * 100.0, end_move * 1000.0, "TAMAM" if good else "SORUN"])
		if shots.size() > 0:
			var w := shots[0].get_width()
			var sheet := Image.create(w * shots.size(), shots[0].get_height(), false, shots[0].get_format())
			for i in shots.size():
				sheet.blit_rect(shots[i], Rect2i(0, 0, w, shots[i].get_height()), Vector2i(w * i, 0))
			sheet.save_png(out.path_join("kumas_%s.png" % cls))
		v.queue_free()
		await process_frame
	print("SONUC: ", "BASARILI" if ok else "BASARISIZ")
	quit()
