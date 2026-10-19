class_name CharacterPresentation
extends Node
## Reads gameplay state and mirrors it visually. Never drives the simulation.

@export var body_mesh: MeshInstance3D
@export var visual_pivot: Node3D
@export var overhead: Label3D
@export var counter_bubble: MeshInstance3D
@export var cast_indicator: MeshInstance3D

var _character: CombatCharacter
var _material := StandardMaterial3D.new()
var _flash: float = 0.0
var _cast_mesh := ImmediateMesh.new()


func setup(character: CombatCharacter) -> void:
	_character = character
	body_mesh.material_override = _material
	character.hit_received.connect(func(_hit: HitData) -> void: _flash = 0.12)
	cast_indicator.top_level = true
	cast_indicator.mesh = _cast_mesh
	var line_mat := StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.vertex_color_use_as_albedo = true
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cast_indicator.material_override = line_mat


func _process(delta: float) -> void:
	if _character == null:
		return
	_flash = maxf(0.0, _flash - delta)
	var status: StatusController = _character.status
	var abilities: AbilityController = _character.abilities
	var color: Color = _character.data.body_color
	if _character.is_dead():
		color = Color(0.2, 0.2, 0.2)
	elif status.has_status(StatusController.Type.STUN):
		color = color.lerp(Color.YELLOW, 0.6)
	elif status.has_status(StatusController.Type.IMMATERIAL):
		color = Color(color, 0.35)
	elif abilities.phase == AbilityController.Phase.STARTUP:
		color = color.lerp(Color.WHITE, 0.35)
	if _flash > 0.0:
		color = Color(1.0, 0.25, 0.25)
	_material.albedo_color = color
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if color.a < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	visual_pivot.rotation.x = deg_to_rad(-80.0) if _character.is_dead() else 0.0
	counter_bubble.visible = status.has_status(StatusController.Type.COUNTER)
	_update_overhead()
	_update_cast_indicator()


func _update_overhead() -> void:
	var lines: PackedStringArray = ["%s  %d" % [_character.data.display_name, ceili(_character.health.current_health)]]
	var abilities: AbilityController = _character.abilities
	if abilities.is_casting():
		lines.append(abilities.current.display_name)
	var status_text: String = _character.status.describe()
	if status_text != "":
		lines.append(status_text)
	overhead.text = "\n".join(lines)


## Telegraph: during startup, show where the jutsu is aimed and how far it reaches.
func _update_cast_indicator() -> void:
	_cast_mesh.clear_surfaces()
	var abilities: AbilityController = _character.abilities
	if abilities.phase != AbilityController.Phase.STARTUP:
		return
	var a: AbilityData = abilities.current
	if a.kind != AbilityData.Kind.GROUND_AREA and a.get_reach() <= 0.0:
		return
	var origin: Vector3 = _character.global_position + Vector3.UP * 0.06
	var dir: Vector3 = _character.facing.facing_direction
	_cast_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_cast_mesh.surface_set_color(Color(a.color, 0.9))
	if a.kind == AbilityData.Kind.GROUND_AREA:
		var target: Vector3 = _character.global_position + HitQuery.flat(_character.facing.aim_point - _character.global_position).limit_length(a.max_range)
		target.y = 0.06
		for i in 32:
			var a0: float = TAU * i / 32.0
			var a1: float = TAU * (i + 1) / 32.0
			_cast_mesh.surface_add_vertex(target + Vector3(cos(a0), 0.0, sin(a0)) * a.hit_radius)
			_cast_mesh.surface_add_vertex(target + Vector3(cos(a1), 0.0, sin(a1)) * a.hit_radius)
	else:
		var side: Vector3 = dir.cross(Vector3.UP) * a.hit_radius * 0.5
		var tip: Vector3 = origin + dir * a.get_reach()
		for offset: Vector3 in [side, -side]:
			_cast_mesh.surface_add_vertex(origin + offset)
			_cast_mesh.surface_add_vertex(tip + offset)
	_cast_mesh.surface_end()
