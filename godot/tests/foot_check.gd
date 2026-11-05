extends SceneTree
## Ayak kaymasi olcumu: her sinif kendi oyun hiziyla (+X yonune) duz kosar; yere basan ayagin dunyadaki yatay hizi olculur.
## Ayak yere bastiginda neredeyse durmali. Kayma orani = basan ayagin ortalama hizi / govdenin hizi (0 = kusursuz, 1 = paten).
## Basari: her sinifta kayma orani 0,35'ten kucuk.
## Kullanim: godot --path godot --resolution 640x640 --script res://tests/foot_check.gd -- [resim klasoru]


func _init() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(0, 1.3, 6.0)
	cam.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.7, 0.4, 0)
	root.add_child(sun)
	Engine.max_fps = 60
	var a := OS.get_cmdline_user_args()
	var out: String = a[0] if a.size() > 0 else ""
	var ok := true
	for cls: String in GameData.CLASSES:
		var ch := Rules.new_character("A", cls, 8, 1, RandomNumberGenerator.new())
		var e := Battle.Ent.new()
		e.ch = ch
		e.s = {"speed": GameData.CLASSES[cls]["speed"], "swing": 0.7, "recover": 0.5, "max_hp": 100.0}
		e.face = PI / 2.0
		e.pos = Vector2(-6.0, 0.0)
		var v := CharacterView.new()
		root.add_child(v)
		v.setup(ch, e)
		v.position = Vector3(e.pos.x, 0, e.pos.y)
		var feet: Array[BoneAttachment3D] = []
		for b: String in ["foot_l", "foot_r"]:
			var h := BoneAttachment3D.new()
			h.bone_name = b
			v._skeleton.add_child(h)
			feet.append(h)
		var speed: float = GameData.CLASSES[cls]["speed"]
		var last: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
		var samples: Array[Array] = [[], []] # [yukseklik, yatay hiz]
		var dt := 1.0 / 60.0
		var clock := Time.get_ticks_usec()
		for f in 200:
			e.moving = true
			e.pos.x += speed * dt
			await process_frame
			var now := Time.get_ticks_usec()
			dt = clampf((now - clock) / 1000000.0, 0.004, 0.05) # gercek kare suresi
			clock = now
			if out != "" and f == 150:
				cam.position = Vector3(v.position.x, 1.2, 4.5)
				await process_frame
				get_root().get_texture().get_image().save_png(out.path_join("kosu_%s.png" % cls))
			for k in 2:
				var p := feet[k].global_position
				if OS.has_environment("AYAK_DEBUG") and cls == OS.get_environment("AYAK_DEBUG") and f > 100 and f < 140 and k == 0:
					print("  f=%d y=%.3f x=%.3f z=%.3f model_x=%.3f" % [f, p.y, p.x, p.z, v.position.x])
				if f > 60: # kosu oturdu, ilk yarim saniye gecis
					samples[k].append([p.y, Vector2(p.x - last[k].x, p.z - last[k].z).length() / dt])
				last[k] = p
		# yere basan ayak = adim dongusunde ayagin en yavas oldugu bolum (en yavas %25 kare). Yukseklige bakilmaz:
		# bazi kosularda basan ayagin bilegi havadaki ayaktan yuksekte durur.
		var med := 0.0
		for k in 2:
			var sp: Array[float] = []
			for s: Array in samples[k]:
				sp.append(float(s[1]))
			sp.sort()
			var n := maxi(1, sp.size() / 4)
			var sum := 0.0
			for i in n:
				sum += sp[i]
			med += sum / n * 0.5
		var ratio := med / speed
		var good := ratio < 0.35
		ok = ok and good
		print("AYAK %s: govde %.1f m/sn, yere basan ayak %.2f m/sn, kayma orani %.2f, kosu hizi x%.2f, hareket %s -> %s" % [cls, speed, med, ratio, v._loco, v._ap.current_animation, "TAMAM" if good else "SORUN"])
		v.queue_free()
		await process_frame
	print("SONUC: ", "BASARILI" if ok else "BASARISIZ")
	quit()
