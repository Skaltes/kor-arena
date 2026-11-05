extends SceneTree
## Gercek isabet karesi olcumu: her saldiri/yetenek animasyonunda silah ucunun yolu kare kare izlenir.
## Rakip, karakterin onunde menzil kadar uzakta durur (govdesi 0,35 m yaricapli dik silindir, 0,6-1,8 m yukseklik).
## Yazilan zamanlar: "temas" = silah ucunun rakip govdesine ilk girdigi kare, "en yakin" = govdeye en yakin oldugu kare,
## "tepe hiz" = savurmanin en hizli ani, "durus" = tepe hizdan sonra hizin yariya dustugu an. Tablodaki "hit" ile karsilastirilir.
## Kullanim: godot --path godot --resolution 640x360 --script res://tests/hit_frames.gd [-- sinif]

const STEP := 1.0 / 60.0
const BODY_R := 0.35


func _init() -> void:
	var only: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else ""
	var root := Node3D.new()
	get_root().add_child(root)
	for cls: String in GameData.CLASSES:
		if only != "" and cls != only:
			continue
		var ch := Rules.new_character("A", cls, 8, 1, RandomNumberGenerator.new())
		var e := Battle.Ent.new()
		e.ch = ch
		e.s = {"speed": 4.0, "swing": 0.7, "recover": 0.5, "max_hp": 100.0, "range": GameData.CLASSES[cls]["range"]}
		e.face = 0.0
		var v := CharacterView.new()
		root.add_child(v)
		v.setup(ch, e)
		for i in 5:
			await process_frame
		v.set_process(false)
		var table: Dictionary = CharacterView.MX[v._weapon]
		var list: Array = []
		for a: Dictionary in table["attacks"]:
			list.append(["duz", a])
		for id: String in table["motions"]:
			list.append([id, table["motions"][id]])
		for item: Array in list:
			var m: Dictionary = item[1]
			if not m.has("hit"):
				continue
			var reach: float = GameData.SKILLS[item[0]].get("range", e.s["range"]) if item[0] != "duz" else float(e.s["range"])
			reach = minf(reach, 2.3)
			print(await _measure(v, m, reach, item[0]))
		v.queue_free()
		await process_frame
	quit()


func _measure(v: CharacterView, m: Dictionary, reach: float, id: String) -> String:
	var ap: AnimationPlayer = v._ap
	var anim: String = m["anim"]
	var length := ap.get_animation(anim).length
	ap.play(anim, 0.0, 0.0)
	var pts: Array[Vector3] = []
	var t := 0.0
	while t <= length:
		ap.seek(t, true)
		v._skeleton.force_update_all_bone_transforms()
		await process_frame
		pts.append(v.to_local(v.weapon_tip.global_position))
		t += STEP
	# karakter +Z'ye bakar (face 0)
	var foe := Vector2(0.0, reach)
	var first := -1.0
	var near := -1.0
	var best := INF
	var peak := 0.0
	var peak_t := 0.0
	var speeds: Array[float] = []
	for i in pts.size():
		var p := pts[i]
		var d := Vector2(p.x, p.z).distance_to(foe) - BODY_R
		var in_h := p.y > 0.4 and p.y < 2.0
		if in_h and d <= 0.0 and first < 0.0:
			first = i * STEP
		if in_h and d < best:
			best = d
			near = i * STEP
		var sp := 0.0 if i == 0 else (pts[i] - pts[i - 1]).length() / STEP
		speeds.append(sp)
		if sp > peak and float(i) * STEP > float(m.get("start", 0.0)):
			peak = sp
			peak_t = i * STEP
	var stop := -1.0
	for i in range(int(peak_t / STEP), speeds.size()):
		if speeds[i] < peak * 0.35:
			stop = i * STEP
			break
	return "%s %-10s %-12s uzunluk %.2f | tablo hit %.2f start %.2f | temas %s  en yakin %.2f (%.2f m)  tepe hiz %.2f (%.1f m/s)  durus %.2f" % [
		v._px, id, anim, length, float(m["hit"]), float(m.get("start", 0.0)),
		"%.2f" % first if first >= 0.0 else "YOK", near, best, peak_t, peak, stop]
