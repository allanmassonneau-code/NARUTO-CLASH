extends Node3D
## Local probe (not committed): SS creator avatars.

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var clip: StringName = StringName(args[0]) if args.size() > 0 else &"idle"
	for i in 6:
		var look := ShinobiLook.new()
		look.ss_avatar = {"seed": 101 + i * 37}
		var fh := SSAvatars.forehead_options()
		var ac := SSAvatars.accessory_options()
		if not fh.is_empty():
			look.ss_avatar["forehead"] = fh[(i * 5) % fh.size()].material
		if not ac.is_empty():
			look.ss_avatar["accessory"] = ac[(i * 3) % ac.size()].mesh
		var model := ShinobiModel.new()
		add_child(model)
		model.build(look)
		model.position.x = -3.5 + i * 1.4
		model.rotation.y = PI + 0.3
		var aps: Array[Node] = model.find_children("*", "AnimationPlayer", true, false)
		if not aps.is_empty() and (aps[0] as AnimationPlayer).has_animation(clip):
			(aps[0] as AnimationPlayer).play(clip)
		print(SSAvatars.complete(look.ss_avatar))
	var cam := Camera3D.new()
	cam.position = Vector3(-2.1, 1.75, 1.6)
	cam.fov = 40
	add_child(cam)
	cam.look_at(Vector3(-2.1, 1.6, 0))
	var sun := DirectionalLight3D.new()
	SSGraphics.configure_sun(sun, SSEnvPresets.KONOHA_DAY)
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = SSGraphics.build_environment(SSEnvPresets.KONOHA_DAY)
	add_child(env)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	ground.mesh = plane
	ground.material_override = SSGraphics.prop_material(Color(0.43, 0.55, 0.32), &"grass")
	add_child(ground)