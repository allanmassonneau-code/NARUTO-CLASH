extends Node3D
## Local probe (not committed): SS effect sprites.

var _t: float = 0.0
var _done: bool = false

func _ready() -> void:
	var cam := Camera3D.new()
	cam.position = Vector3(0, 7, 11)
	cam.fov = 45
	add_child(cam)
	cam.look_at(Vector3(0, 0.8, 0))
	var sun := DirectionalLight3D.new()
	SSGraphics.configure_sun(sun, SSEnvPresets.KONOHA_DAY)
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = SSGraphics.build_environment(SSEnvPresets.KONOHA_DAY)
	add_child(env)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	ground.mesh = plane
	ground.material_override = SSGraphics.prop_material(Color(0.43, 0.55, 0.32), &"grass")
	add_child(ground)
	var anchor := Node3D.new()
	add_child(anchor)
	var holder := Node3D.new()
	anchor.add_child(holder)
	SSVfx.for_effect(holder, "explosion", Vector3(-6, 0, 0), 1.6, Color(1.0, 0.45, 0.1))
	SSVfx.for_effect(holder, "bolt", Vector3(-3, 0, 0), 1.2, Color(0.95, 0.95, 0.4))
	SSVfx.for_effect(holder, "rocks", Vector3(0, 0, 0), 1.5, Color(0.6, 0.45, 0.25))
	SSVfx.for_effect(holder, "wave", Vector3(3, 0, 0), 1.5, Color(0.3, 0.6, 1.0))
	SSVfx.for_effect(holder, "smoke", Vector3(6, 0, 0), 1.3, Color(0.4, 0.4, 0.4))
	SSVfx.for_spell(holder, &"rasengan", Vector3(0, 1.2, 3), Color.WHITE, true)
	SSVfx.for_spell(holder, &"chidori", Vector3(-3, 1.2, 3), Color.WHITE, true)