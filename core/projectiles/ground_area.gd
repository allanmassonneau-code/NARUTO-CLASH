class_name GroundArea
extends Node3D
## Telegraphed delayed area: visible circle fills up, then detonates.

var source: CombatCharacter
var team: int = 0
var ability: AbilityData
var elapsed: float = 0.0
## Client-side replica: shows the telegraph, never deals damage.
var visual_only: bool = false
var net_id: int = 0

var _fill: MeshInstance3D


static func spawn(from: CombatCharacter, data: AbilityData, point: Vector3) -> GroundArea:
	var area := GroundArea.new()
	area.source = from
	area.team = from.team
	area.ability = data
	from.get_parent().add_child(area)
	area.global_position = Vector3(point.x, 0.0, point.z)
	area.net_id = Net.on_entity_spawned(area, from, data, area.global_position, Vector3.ZERO)
	return area


static func spawn_visual(from: CombatCharacter, data: AbilityData, point: Vector3) -> GroundArea:
	var area := GroundArea.new()
	area.source = from
	area.team = from.team
	area.ability = data
	area.visual_only = true
	from.get_parent().add_child(area)
	area.global_position = point
	return area


func _ready() -> void:
	add_to_group(&"ground_areas")
	add_to_group(&"round_entities")
	if not CombatFx.is_enabled():
		return
	add_child(_make_disk(Color(ability.color, 0.18), 0.015))
	_fill = _make_disk(Color(ability.color, 0.4), 0.025)
	_fill.scale = Vector3(0.01, 1.0, 0.01)
	add_child(_fill)
	SpellVfx.area_decor(self)


func _physics_process(delta: float) -> void:
	elapsed += delta
	if _fill != null:
		var t: float = clampf(elapsed / maxf(ability.area_delay, 0.001), 0.01, 1.0)
		_fill.scale = Vector3(t, 1.0, t)
	if CombatFx.is_enabled():
		SpellVfx.area_tick(self, delta)
	if elapsed >= ability.area_delay:
		_detonate()


func _detonate() -> void:
	SpellVfx.area_detonate(self, global_position, ability)
	if visual_only:
		queue_free()
		return
	Net.on_entity_despawned(net_id)
	var center: Vector3 = global_position + Vector3.UP * HitQuery.BODY_HEIGHT
	var reach: float = ability.hit_radius + HitQuery.HURTBOX_RADIUS
	for target: CombatCharacter in HitQuery.characters_in_sphere(get_world_3d(), center, reach):
		if target.team == team:
			continue
		if HitQuery.flat(target.global_position - global_position).length() > reach:
			continue
		var dir: Vector3 = HitQuery.flat(target.global_position - global_position)
		target.receive_hit(HitData.from_ability(source, ability, dir if dir.length() > 0.01 else Vector3.FORWARD))
	queue_free()


func _make_disk(color: Color, height: float) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = ability.hit_radius
	mesh.bottom_radius = ability.hit_radius
	mesh.height = 0.01
	mesh.radial_segments = 40
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.position.y = height
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return view
