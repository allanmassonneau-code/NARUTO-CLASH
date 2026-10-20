extends Node3D
## Local probe: SS face shapes (baked), frontal, no animation.

const EYES: Array = ["ID_CustomEyes_M_00", "ID_CustomEyes_M_01", "ID_CustomEyes_M_03", "ID_CustomEyes_F_03", "ID_CustomEyes_F_09"]
const PAINTS: Array = ["MI_CHR_FacePaint_Naruto", "", "MI_CHR_FacePaint_Kiba", "", "MI_CHR_FacePaint_Gaara"]

func _ready() -> void:
	for i in EYES.size():
		var look := ShinobiLook.new()
		look.ss_avatar = {"seed": 7, "sex": "Female" if i >= 3 else "Male", "eye": EYES[i], "facepaint": PAINTS[i], "hair": "SK_CHR_ShortStraight_01"}
		var model := ShinobiModel.new()
		add_child(model)
		model.build(look)
		model.position.x = -1.2 + i * 0.6
		model.rotation.y = PI
		for ap: Node in model.find_children("*", "AnimationPlayer", true, false):
			(ap as AnimationPlayer).stop()
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.6, 1.25)
	cam.fov = 40
	add_child(cam)
	cam.look_at(Vector3(0, 1.55, 0))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, 180, 0)
	add_child(sun)