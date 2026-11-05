extends SceneTree
## Yakin plan cekim: bir sinifin karakterini istenen hareketin istenen aninda dondurup onden ve yandan resmini kaydeder.
## Kullanim: godot --path godot --resolution 900x900 --script res://tests/view_shot.gd -- <sinif> <hareket> <saniye> <cikti.png> [bolge: tam|el|bas]


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var cls: String = a[0]
	var anim: String = a[1]
	var at := float(a[2])
	var out: String = a[3]
	var zone: String = a[4] if a.size() > 4 else "tam"
	var roll := float(a[5]) if a.size() > 5 else 0.0 # kilici el ekseni etrafinda dondurerek deneme (derece)
	var tilt := float(a[6]) if a.size() > 6 else 0.0
	var root := Node3D.new()
	get_root().add_child(root)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.32, 0.32, 0.36)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.7, 0.5, 0)
	root.add_child(sun)
	var rng := RandomNumberGenerator.new()
	var ch := Rules.new_character("A", cls, 8, 1, rng)
	var v := CharacterView.new()
	root.add_child(v)
	v.setup(ch)
	for h: Node3D in [v._hand, v._off_hand]:
		if h != null and (roll != 0.0 or tilt != 0.0):
			h.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(roll)) * Basis(Vector3.RIGHT, deg_to_rad(tilt)), Vector3.ZERO) * h.transform
	var ap: AnimationPlayer = v._ap
	ap.play(anim)
	ap.seek(at, true)
	ap.speed_scale = 0.0
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 30
	var images: Array[Image] = []
	for side in 2:
		await process_frame
		var target := v.head_position() if zone == "bas" else (v._hand.global_position if zone == "el" else (v._off_hand.global_position if zone == "sol" else v.global_position + Vector3(0, 0.95, 0)))
		var dist := 0.9 if zone != "tam" else 4.2
		var dir := Vector3(0, 0.05, 1).normalized() if side == 0 else Vector3(1, 0.05, 0).normalized()
		cam.global_position = target + dir * dist
		cam.look_at(target)
		for i in 4:
			await process_frame
		images.append(get_root().get_texture().get_image())
	var w := images[0].get_width()
	var sheet := Image.create(w * 2, images[0].get_height(), false, images[0].get_format())
	sheet.blit_rect(images[0], Rect2i(0, 0, w, images[0].get_height()), Vector2i(0, 0))
	sheet.blit_rect(images[1], Rect2i(0, 0, w, images[0].get_height()), Vector2i(w, 0))
	sheet.save_png(out)
	print("KAYDEDILDI ", out)
	quit()
