class_name MovementData
extends Resource
## Tunable locomotion parameters. Defaults aim for near-instant response.

@export_category("Locomotion")
@export var move_speed: float = 6.5
## Units/s². Very high values = snappy, Battlerite-like starts.
@export var acceleration: float = 260.0
## Units/s². Very high values = crisp stops with no sliding.
@export var deceleration: float = 320.0
## Bypass acceleration entirely (velocity = wish * speed).
@export var instant_response: bool = false
