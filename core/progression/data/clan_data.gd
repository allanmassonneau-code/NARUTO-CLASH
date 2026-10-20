class_name ClanData
extends Resource
## A clan of a village and its tree: 1 technique per rank (D, C, B, A, S).

@export var id: StringName
@export var display_name: String = ""
@export var village_id: StringName
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var jutsu: Array[JutsuData] = []
@export var placeholder: bool = false
