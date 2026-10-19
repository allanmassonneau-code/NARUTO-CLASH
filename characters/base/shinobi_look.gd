class_name ShinobiLook
extends Resource
## Placeholder appearance built from primitives. Presentation only.

enum Hair { SPIKY, DUCK_TAIL, LONG, SWEPT }

@export var skin: Color = Color(0.98, 0.8, 0.65)
@export var top: Color = Color.ORANGE
@export var sleeves: Color = Color.ORANGE
@export var pants: Color = Color.ORANGE
@export var accent: Color = Color.BLACK
@export var hair_color: Color = Color.YELLOW
@export var hair: Hair = Hair.SPIKY
@export var eye_color: Color = Color(0.1, 0.15, 0.4)
@export var headband: bool = true
@export var mask: bool = false
@export var flak_vest: bool = false
