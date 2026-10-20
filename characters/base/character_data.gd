class_name CharacterData
extends Resource
## Static definition of a shinobi: stats + one AbilityData per input slot.

@export var display_name: String = "Shinobi"
## Shown over the head and in HUD cards.
@export var short_name: String = ""
@export_multiline var identity: String = ""
@export var body_color: Color = Color.WHITE
@export var look: ShinobiLook
@export var max_health: float = 130.0
## > 0: chakra mode (starts full, regenerates, techniques cost chakra).
@export var max_chakra: float = 0.0
## Chakra regenerated per second in chakra mode.
@export var chakra_regen: float = 0.0
@export var movement: MovementData
## Passive id handled by CombatCharacter ("kurama"...), empty = none.
@export var passive: StringName = &""
@export_multiline var passive_description: String = ""

@export_category("Abilities")
@export var lmb: AbilityData
@export var rmb: AbilityData
@export var space: AbilityData
@export var q: AbilityData
@export var e: AbilityData
@export var ult: AbilityData
@export var j1: AbilityData
@export var j2: AbilityData
@export var j3: AbilityData
@export var j4: AbilityData
@export var j5: AbilityData
@export var j6: AbilityData


func get_ability_map() -> Dictionary:
	var map: Dictionary = {}
	for slot: StringName in AbilityController.SLOTS:
		var ability: AbilityData = get(slot)
		if ability != null:
			map[slot] = ability
	return map
