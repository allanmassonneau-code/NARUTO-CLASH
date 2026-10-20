class_name SpecializationData
extends Resource
## Chunin specialization: 3 active skills + 1 passive skill.

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var role: String = ""
@export var icon: Texture2D
@export var active_skills: Array[JutsuData] = []
@export var passive_skill: JutsuData
@export var placeholder: bool = false


func all_skills() -> Array[JutsuData]:
	var out: Array[JutsuData] = active_skills.duplicate()
	if passive_skill != null:
		out.append(passive_skill)
	return out
