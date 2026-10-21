extends Node3D
## Local probe: SS chakra recovery and chakra run effects.

var _fx: Array = []
var _runner: Node3D
var _t: float = 0.0

func _ready() -> void:
	for i in 2:
		var host := Node3D.new()
		add_child(host)
		host.position = Vector3(-1.2 + i * 2.6, 0, 0)
		var look := ShinobiLook.new()
		look.ss_avatar = {"seed": 11 + i, "sex": "Male"}
		var model := ShinobiModel.new()
		host.add_child(model)
		model.build(look)
		model.rotation.y = PI - 0.4
		host.set_meta("model", model)
		_fx.append(SSChakraFx.new(host))
		if i == 1: _runner = host
	var cam := Camera3D.new()
	cam.position = Vector3(0.2, 1.6, 5.0)
	add_child(cam)
	cam.look_at(Vector3(0.2, 0.9, 0))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 160, 0)
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

func _process(d: float) -> void:
	_t += d
	_runner.position.x = 3.0 - fmod(_t * 7.0, 3.0)
	(_fx[0] as SSChakraFx).update(d, true, false)
	(_fx[1] as SSChakraFx).update(d, false, true)
	((get_child(0) as Node3D).get_meta("model") as ShinobiModel).animate(d, 0.0, &"concentrate:", Color(0.35, 0.65, 1.0, 0.18), 0.0)
	(_runner.get_meta("model") as ShinobiModel).sprinting = true
	(_runner.get_meta("model") as ShinobiModel).animate(d, 9.0, &"", Color(0.4, 0.7, 1.0, 0.2), 0.0)