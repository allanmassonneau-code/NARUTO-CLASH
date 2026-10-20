class_name JutsuData
extends Resource
## One technique (nature, clan, specialization, sub-jutsu...). The id is the
## stable key saved in profiles; names and descriptions are display only.

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var source: ProgressionTypes.JutsuSource = ProgressionTypes.JutsuSource.NATURE
@export var rank: ProgressionTypes.Rank = ProgressionTypes.Rank.D
## Id of the nature / clan / specialization this technique belongs to.
@export var owner_id: StringName
@export var chakra_cost: float = 0.0
@export var cooldown: float = 0.0
@export var tags: Array[StringName] = []
## Design-bible tags shown to the player (French, e.g. "Projectile, Marque").
@export var design_tags: PackedStringArray = []
## Full design text: activation, real mechanic, synergies, counter-play.
@export_multiline var details: String = ""
## Other techniques (ids) that must be learned first.
@export var requirements: Array[StringName] = []
@export var passive: bool = false
## Combat definition used when the technique is equipped (optional for now).
@export var gameplay_data: AbilityData
## Placeholder content waiting for the real design data.
@export var placeholder: bool = false
