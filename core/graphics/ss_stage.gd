class_name SSStage
extends Node
## Drop into any hand-made 3D scene (arenas, test maps): applies an SS environment preset
## to the scene's WorldEnvironment / DirectionalLight3D and converts its plain
## StandardMaterial3D to SS toon materials. Presentation only.

@export var preset: StringName = SSEnvPresets.FOREST_DAY
@export var convert_materials: bool = true
## Optional; found among the parent's children when empty.
@export var world_environment: WorldEnvironment
@export var sun: DirectionalLight3D


func _ready() -> void:
	if not CombatFx.is_enabled():
		return
	var root: Node = get_parent()
	for child: Node in root.get_children():
		if world_environment == null and child is WorldEnvironment:
			world_environment = child
		elif sun == null and child is DirectionalLight3D:
			sun = child
	if world_environment != null:
		world_environment.environment = SSGraphics.build_environment(preset)
	if sun != null:
		SSGraphics.configure_sun(sun, preset)
	if convert_materials:
		_convert.call_deferred()  # after nodes added deferred during setup (battlefield)


func _convert() -> void:
	SSGraphics.convert_tree(get_parent())
