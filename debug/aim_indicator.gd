class_name AimIndicator
extends MeshInstance3D
## Debug/readability: line from character to cursor + cursor ring on the floor.

@export var character: CombatCharacter
@export var color: Color = Color(1.0, 1.0, 1.0, 0.6)
@export var ring_radius: float = 0.35
@export var height: float = 0.03

var _mesh := ImmediateMesh.new()


func _ready() -> void:
	top_level = true
	mesh = _mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(_delta: float) -> void:
	_mesh.clear_surfaces()
	if character == null or not DebugSettings.show_aim:
		return
	var from: Vector3 = character.global_position
	var to: Vector3 = character.facing.aim_point
	from.y = height
	to.y = height
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_mesh.surface_set_color(color)
	_mesh.surface_add_vertex(from)
	_mesh.surface_add_vertex(to)
	var segments: int = 24
	for i in segments:
		var a: float = TAU * i / segments
		var b: float = TAU * (i + 1) / segments
		_mesh.surface_add_vertex(to + Vector3(cos(a), 0.0, sin(a)) * ring_radius)
		_mesh.surface_add_vertex(to + Vector3(cos(b), 0.0, sin(b)) * ring_radius)
	_mesh.surface_end()
