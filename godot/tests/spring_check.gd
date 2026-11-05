extends SceneTree
## Darbe yay fizigi olcumu: her sinifa onden (+X'teki rakipten) darbe verilir; bas konumunun kaymasi kare kare izlenir.
## Animasyon oynatici kapatilir (bekleme durusunda kalir): olculen kayma yalnizca yayin etkisidir. Kemigi kimse yeniden
## yazmadigi icin bu ayni zamanda birikme sinamasidir: darbe bitince omurga eski duruşuna tam donmeli.
## Basari: bas darbeden UZAGA gider (-X), en buyuk kayma makul, 1,2 sn icinde durulur, titreme (yon degistirme) en cok 2,
## kalici kayma 3 mm'den az.
## Kullanim: godot --path godot --resolution 640x640 --script res://tests/spring_check.gd -- [resim klasoru]


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0] if a.size() > 0 else ""
	var root := Node3D.new()
	get_root().add_child(root)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(0, 1.3, 4.0)
	cam.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.7, 0.4, 0)
	root.add_child(sun)
	var ok := true
	for cls: String in GameData.CLASSES:
		for weight: float in [0.4, 1.4]:
			var v := CharacterView.new()
			root.add_child(v)
			v.setup(Rules.new_character("A", cls, 8, 1, RandomNumberGenerator.new()))
			for i in 30:
				await process_frame
			v._ap.active = false # bekleme durusu yerinde kalir, kimse kemigi yeniden yazmaz
			var head := BoneAttachment3D.new() # yayin uygulandigi son durusu izler
			head.bone_name = "Head"
			v._skeleton.add_child(head)
			for i in 3:
				await process_frame
			var rest := head.global_position
			v.spring.hit(v.global_position + Vector3(2.0, 0, 0), weight)
			var peak := 0.0
			var peak_b := 0.0
			var peak_x := 0.0
			var flips := 0
			var last_sign := 0.0
			var settled_at := -1.0
			var t := 0.0
			var shot_taken := false
			var d := Vector3.ZERO
			while t < 2.0:
				await process_frame
				t += 1.0 / 60.0
				d = head.global_position - rest
				peak_b = maxf(peak_b, v.spring._bend.length())
				if d.length() > peak:
					peak = d.length()
					peak_x = d.x
				var s := signf(d.x) if absf(d.x) > 0.01 else last_sign
				if last_sign != 0.0 and s != last_sign:
					flips += 1
				last_sign = s
				if d.length() >= 0.01:
					settled_at = -1.0
				elif settled_at < 0.0 and t > 0.2:
					settled_at = t
				if out != "" and not shot_taken and weight > 1.0 and t > 0.12:
					shot_taken = true
					get_root().get_texture().get_image().save_png(out.path_join("yay_%s.png" % cls))
			var good := peak_x < 0.0 and peak > 0.03 and peak < 0.45 and flips <= 2 and settled_at > 0.0 and settled_at < 1.2 and d.length() < 0.003
			ok = ok and good
			print("YAY %s agirlik %.1f: yay acisi %.2f rad, bas kaymasi %.0f cm (x %.0f cm), titreme %d, durulma %.2f sn, kalici %.1f mm -> %s" % [cls, weight, peak_b, peak * 100.0, peak_x * 100.0, flips, settled_at, d.length() * 1000.0, "TAMAM" if good else "SORUN"])
			v.queue_free()
			await process_frame
	print("SONUC: ", "BASARILI" if ok else "BASARISIZ")
	quit()
