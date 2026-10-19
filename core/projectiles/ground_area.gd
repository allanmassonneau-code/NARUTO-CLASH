class_name GroundArea
extends Node3D
## Telegraphed delayed area: visible circle fills up, then detonates.
## With `zone_duration` it then lingers, ticking on enemies inside
## (burning ground, slowing crater).

var source: CombatCharacter
var team: int = 0
var ability: AbilityData
var elapsed: float = 0.0
## Client-side replica: shows the telegraph, never deals damage.
var visual_only: bool = false
var net_id: int = 0

var _fill: MeshInstance3D
var _detonated: bool = false
var _zone_left: float = 0.0
var _tick_timer: float = 0.0

const ZONE_TICK: float = 0.5


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
	if _detonated:
		_zone_process(delta)
		return
	if _fill != null:
		var t: float = clampf(elapsed / maxf(ability.area_delay, 0.001), 0.01, 1.0)
		_fill.scale = Vector3(t, 1.0, t)
	if CombatFx.is_enabled():
		SpellVfx.area_tick(self, delta)
	if elapsed >= ability.area_delay:
		_detonate()


func _detonate() -> void:
	SpellVfx.area_detonate(self, global_position, ability)
	_detonated = true
	_zone_left = ability.zone_duration
	if ability.zone_duration > 0.0 and CombatFx.is_enabled():
		if _fill != null:
			_fill.visible = false
		SpellVfx.zone_visual(self)
	if visual_only:
		if ability.zone_duration <= 0.0:
			queue_free()
		return  # replicas linger until the server despawns them
	if ability.damage > 0.0 or ability.stun_duration > 0.0 or ability.root_duration > 0.0:
		_hit_inside(ability.damage, true)
	if ability.zone_duration <= 0.0:
		_finish()


func _zone_process(delta: float) -> void:
	_zone_left -= delta
	if visual_only:
		if _zone_left < -2.0:
			queue_free()  # safety if the despawn message was lost
		return
	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer = ZONE_TICK
		_hit_inside(ability.zone_tick_damage, false)
	if _zone_left <= 0.0:
		_finish()


func _finish() -> void:
	Net.on_entity_despawned(net_id)
	queue_free()


## Detonation hit (full HitData) or zone tick (small damage + slow, no CC).
func _hit_inside(damage: float, full_hit: bool) -> void:
	var center: Vector3 = global_position + Vector3.UP * HitQuery.BODY_HEIGHT
	var reach: float = ability.hit_radius + HitQuery.HURTBOX_RADIUS
	for target: CombatCharacter in HitQuery.characters_in_sphere(get_world_3d(), center, reach):
		if target.team == team:
			continue
		if HitQuery.flat(target.global_position - global_position).length() > reach:
			continue
		var dir: Vector3 = HitQuery.flat(target.global_position - global_position)
		var hit := HitData.from_ability(source, ability, dir if dir.length() > 0.01 else Vector3.FORWARD)
		if not full_hit:
			hit.damage = damage
			hit.stun_duration = 0.0
			hit.root_duration = 0.0
			hit.knockback_velocity = Vector3.ZERO
			hit.energy_gain *= 0.25
		target.receive_hit(hit)


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
