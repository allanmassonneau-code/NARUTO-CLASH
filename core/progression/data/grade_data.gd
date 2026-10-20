class_name GradeData
extends Resource
## What a grade is worth: base resources, technique access and the rewards
## granted when it is reached. Balancing lives here, not in code.

@export var grade: ProgressionTypes.Grade = ProgressionTypes.Grade.GENIN
@export var display_name: String = ""
@export var base_hp: float = 100.0
@export var base_chakra: float = 100.0
## Tenketsu points granted on reaching this grade.
@export var tenketsu_points: int = 2
## Highest technique rank learnable (nature and clan trees) at this grade.
@export var max_jutsu_rank: ProgressionTypes.Rank = ProgressionTypes.Rank.C
## Choices granted on reaching this grade (ProgressionTypes.Choice values).
@export var granted_choices: Array[int] = []
## Sub-jutsu event for clanless characters.
@export var sub_jutsu_event: ProgressionTypes.SubJutsuEvent = ProgressionTypes.SubJutsuEvent.NONE
## base_hp / base_chakra are not final balancing values yet.
@export var placeholder_stats: bool = false
