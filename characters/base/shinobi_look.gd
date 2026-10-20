class_name ShinobiLook
extends Resource
## Placeholder appearance built from primitives. Presentation only.

enum Hair { SPIKY, DUCK_TAIL, LONG, SWEPT, BOWL, SHORT, HIME, PINEAPPLE, PONYTAIL }
enum Weapon { NONE, SWORD, KUNAI }

@export var skin: Color = Color(0.98, 0.8, 0.65)
@export var top: Color = Color.ORANGE
## Shoulders / collar panel (Naruto's black shoulders, Sakura's collar...).
@export var top_accent: Color = Color.BLACK
@export var sleeves: Color = Color.ORANGE
@export var pants: Color = Color.ORANGE
@export var accent: Color = Color.BLACK
@export var hair_color: Color = Color.YELLOW
@export var hair: Hair = Hair.SPIKY
@export var eye_color: Color = Color(0.1, 0.15, 0.4)
## Alpha 0 = bare hands.
@export var gloves: Color = Color(0, 0, 0, 0)
@export var headband: bool = true
@export var mask: bool = false
@export var flak_vest: bool = false
@export var shorts: bool = false
@export var whiskers: bool = false
@export var weapon: Weapon = Weapon.NONE
## Long coat (Akatsuki cloak, Hokage haori). Alpha 0 = none.
@export var cloak: Color = Color(0, 0, 0, 0)
## Cloak decoration: red clouds or flame hem.
@export var cloak_pattern: StringName = &""
@export var gourd: bool = false
@export var thick_brows: bool = false
## Leg warmers (Lee). Alpha 0 = none.
@export var leg_warmers: Color = Color(0, 0, 0, 0)
## Kanji tattoo on the forehead (Gaara).
@export var forehead_mark: bool = false
@export var eye_white: bool = false
## Real Shinobi Striker model (res://_ss_local/characters/<id>, local only). Empty = the SS
## character-creation avatar (SSCharacters.DEFAULT_AVATAR); primitives when no local asset.
@export var ss_model: StringName = &""
## SS character-creator avatar (SSAvatars dictionary: parts + SS colour ids). Empty = default.
@export var ss_avatar: Dictionary = {}
