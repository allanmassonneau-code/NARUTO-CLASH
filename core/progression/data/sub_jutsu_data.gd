class_name SubJutsuData
extends JutsuData
## Hidden technique (clanless only), ranks B / A / S, obtained by rolls.

## Relative roll weight inside its rank pool (rarity).
@export var weight: float = 1.0
## Sub-jutsu ids that can't be owned together with this one.
@export var exclusions: Array[StringName] = []
## Village ids allowed to roll it (empty = every village).
@export var allowed_villages: Array[StringName] = []
## Disabled entries stay in data but never roll (events, admin grants).
@export var rollable: bool = true
