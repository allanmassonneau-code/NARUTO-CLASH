class_name CharacterData
extends Resource
## Static definition of a shinobi: stats + one AbilityData per input slot.

@export var display_name: String = "Shinobi"
@export_multiline var identity: String = ""
@export var body_color: Color = Color.WHITE
@export var look: ShinobiLook
@export var max_health: float = 130.0
@export var movement: MovementData

@export_category("Abilities")
@export var lmb: AbilityData
@export var rmb: AbilityData
@export var space: AbilityData
@export var q: AbilityData
@export var e: AbilityData
@export var ult: AbilityData


func get_ability_map() -> Dictionary:
	var map: Dictionary = {}
	for slot: StringName in AbilityController.SLOTS:
		var ability: AbilityData = get(slot)
		if ability != null:
			map[slot] = ability
	return map
