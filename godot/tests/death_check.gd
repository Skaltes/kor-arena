extends SceneTree
## Olum dusus olcumu: rakip sagda (+X) durur, son darbeyi vurur. Beden darbeden UZAGA (-X) dusmeli ve savrulmali;
## agir darbe hafif darbeden daha uzaga atmali.
## Basari: her sinifta yere inen bas, baslangic konumundan -X yonunde en az 0,5 m; agir darbede kalca daha uzakta.
## Kullanim: godot --path godot --resolution 960x540 --script res://tests/death_check.gd -- [resim klasoru]


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0] if a.size() > 0 else ""
	Engine.max_fps = 60
	var root := Node3D.new()
	get_root().add_child(root)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(0.3, 1.1, 5.0)
	cam.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.7, 0.4, 0)
	root.add_child(sun)
	var ok := true
	for cls: String in GameData.CLASSES:
		var hips: Array[float] = []
		for weight: float in [0.3, 1.4]:
			var ch := Rules.new_character("A", cls, 8, 1, RandomNumberGenerator.new())
			var e := Battle.Ent.new()
			e.ch = ch
			e.s = {"speed": 4.0, "swing": 0.7, "recover": 0.5, "max_hp": 100.0}
			e.face = PI / 2.0 # sagdaki rakibe bakar
			var v := CharacterView.new()
			root.add_child(v)
			v.setup(ch, e)
			var marks: Array[BoneAttachment3D] = []
			for b: String in ["Head", "pelvis"]:
				var h := BoneAttachment3D.new()
				h.bone_name = b
				v._skeleton.add_child(h)
				marks.append(h)
			for i in 40:
				await process_frame
			var start := marks[0].global_position
			v.react("", false, weight, Vector3(2.0, 1.0, 0.0))
			e.alive = false
			var shots: Array[Image] = []
			for f in 200:
				await process_frame
				if out != "" and weight > 1.0 and f in [0, 20, 45, 90, 199]:
					shots.append(get_root().get_texture().get_image())
			if v.cloth_sim != null:
				var low := 9.0
				for i in v._skeleton.get_bone_count():
					if v._skeleton.get_bone_name(i).begins_with("kumas_"):
						low = minf(low, (v._skeleton.global_transform * v._skeleton.get_bone_global_pose(i)).origin.y)
				print("  kumas en alcak nokta %.2f m" % low)
			var head := marks[0].global_position
			var hip := marks[1].global_position
			hips.append(hip.x)
			var good := head.x < start.x - 0.5 and head.y < 0.6
			ok = ok and good
			print("OLUM %s agirlik %.1f: bas %.2f m geriye, bas yuksekligi %.2f m, kalca x %.2f, savrulma %.2f m -> %s" % [cls, weight, start.x - head.x, head.y, hip.x, v._slide, "TAMAM" if good else "SORUN"])
			if shots.size() > 0:
				var w := shots[0].get_width()
				var sheet := Image.create(w * shots.size(), shots[0].get_height(), false, shots[0].get_format())
				for i in shots.size():
					sheet.blit_rect(shots[i], Rect2i(0, 0, w, shots[i].get_height()), Vector2i(w * i, 0))
				sheet.save_png(out.path_join("olum_%s.png" % cls))
			v.queue_free()
			await process_frame
		var further := hips[1] < hips[0] - 0.1
		ok = ok and further
		print("OLUM %s: agir darbe kalcayi %.2f m daha uzaga atti -> %s" % [cls, hips[0] - hips[1], "TAMAM" if further else "SORUN"])
	print("SONUC: ", "BASARILI" if ok else "BASARISIZ")
	quit()
