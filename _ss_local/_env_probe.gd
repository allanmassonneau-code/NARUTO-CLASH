extends Node3D
## Local probe (not committed): Konoha SS kit lineup.

func _ready() -> void:
	var names: Array = OS.get_cmdline_user_args()
	var x: float = 0.0
	var set_name: String = SSProps.KONOHA
	for n: String in names:
		if n.begins_with("set="):
			set_name = n.substr(4)
			continue
		var inst := SSProps.instance(n, set_name)
		if inst == null:
			print("missing ", n)
			continue
		var s: Vector3 = SSProps.size_of(n, set_name)
		x += s.x * 0.5
		inst.position.x = x
		add_child(inst)
		x += s.x * 0.5 + 2.0
		print(n, " ", s)
	var cam := Camera3D.new()
	cam.fov = 40
	add_child(cam)
	cam.position = Vector3(x * 0.5, x * 0.45, x * 0.75)
	cam.look_at(Vector3(x * 0.5, 2.0, 0))
	cam.far = 4000
	var sun := DirectionalLight3D.new()
	SSGraphics.configure_sun(sun, SSEnvPresets.KONOHA_DAY)
	sun.directional_shadow_max_distance = 400
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = SSGraphics.build_environment(SSEnvPresets.KONOHA_DAY)
	add_child(env)
	SSGraphics.attach_post_outline(cam)
