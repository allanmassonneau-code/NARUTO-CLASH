class_name TenketsuNodeData
extends Resource
## One Tenketsu node. stat_modifiers: stat id (StringName) -> bonus per level.

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
## Points per level.
@export var cost: int = 1
## Node ids that need at least one level first.
@export var prerequisites: Array[StringName] = []
@export var stat_modifiers: Dictionary = {}
@export var position_in_tree: Vector2 = Vector2.ZERO
@export var max_level: int = 1
@export var placeholder: bool = false
