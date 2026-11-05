extends SceneTree
## Titan bekleme durusu: silahi iki elle, dik tutmali. Eller arasi mesafe ve on/yan goruntu.
## Kullanim: godot --path godot --resolution 960x540 --script res://tests/idle_check.gd -- <resim klasoru>


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
	var ch := Rules.new_character("A", "brute", 8, 1, RandomNumberGenerator.new())
	var e := Battle.Ent.new()
	e.ch = ch
	e.s = {"speed": 4.0, "swing": 0.7, "recover": 0.5, "max_hp": 100.0}
	var v := CharacterView.new()
	root.add_child(v)
	v.setup(ch, e)
	var hands: Array[BoneAttachment3D] = []
	for b: String in ["hand_l", "hand_r", "head"]:
		var h := BoneAttachment3D.new()
		h.bone_name = b
		v._skeleton.add_child(h)
		hands.append(h)
	var shots: Array[Image] = []
	for f in 300:
		if f in [60, 180]:
			cam.position = Vector3(0.0, 1.2, 4.0)
		elif f in [61, 181]:
			shots.append(get_root().get_texture().get_image())
			cam.position = Vector3(4.0, 1.2, 0.0)
		elif f in [63, 183]:
			shots.append(get_root().get_texture().get_image())
		cam.look_at(Vector3(0, 1.0, 0))
		await process_frame
		if f % 60 == 0:
			print("EL ARASI %.2f m, sol el y %.2f, sag el y %.2f, bas y %.2f" % [hands[0].global_position.distance_to(hands[1].global_position), hands[0].global_position.y, hands[1].global_position.y, hands[2].global_position.y])
	if out != "":
		for i in shots.size():
			shots[i].save_png(out + "/idle_%d.png" % i)
	quit()
