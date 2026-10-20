extends Node3D
## Local probe (not committed): SS figures side by side with the in-game SS materials.

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var clip: StringName = StringName(args[0]) if args.size() > 0 else &"idle"
	var x: float = -0.7
	for id: StringName in [&"naruto", &"avatar_male"]:
		var look := ShinobiLook.new()
		look.ss_model = id
		var model := ShinobiModel.new()
		add_child(model)
		model.build(look)
		model.position.x = x
		model.rotation.y = PI + 0.4
		x += 1.4
		var ap: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
		if ap.has_animation(clip):
			ap.play(clip)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.2, 4.2)
	cam.fov = 40
	add_child(cam)
	cam.look_at(Vector3(0, 1.0, 0))
	var sun := DirectionalLight3D.new()
	SSGraphics.configure_sun(sun, SSEnvPresets.KONOHA_DAY)
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = SSGraphics.build_environment(SSEnvPresets.KONOHA_DAY)
	add_child(env)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	ground.mesh = plane
	ground.material_override = SSGraphics.prop_material(Color(0.43, 0.55, 0.32), &"grass")
	add_child(ground)
