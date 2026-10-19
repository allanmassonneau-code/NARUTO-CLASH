class_name GroundArea
extends Node3D
## Telegraphed delayed area: visible circle fills up, then detonates.
## With `zone_duration` it then lingers, ticking on enemies inside
## (burning ground, slowing crater).

var source: CombatCharacter
var team: int = 0
var ability: AbilityData
## Cast direction (orients walls).
var direction: Vector3 = Vector3.FORWARD
var elapsed: float = 0.0
## Client-side replica: shows the telegraph, never deals damage.
var visual_only: bool = false
var net_id: int = 0

var _fill: MeshInstance3D
var _detonated: bool = false
var _zone_left: float = 0.0
var _tick_timer: float = 0.0

const ZONE_TICK: float = 0.5


static func spawn(from: CombatCharacter, data: AbilityData, point: Vector3, dir: Vector3 = Vector3.FORWARD) -> GroundArea:
	var area := GroundArea.new()
	area.source = from
	area.team = from.team
	area.ability = data
	area.direction = HitQuery.flat(dir).normalized() if dir.length_squared() > 0.01 else Vector3.FORWARD
	from.get_parent().add_child(area)
	area.global_position = Vector3(point.x, 0.0, point.z)
	area.net_id = Net.on_entity_spawned(area, from, data, area.global_position, area.direction)
	return area


static func spawn_visual(from: CombatCharacter, data: AbilityData, point: Vector3, dir: Vector3 = Vector3.FORWARD) -> GroundArea:
	var area := GroundArea.new()
	area.source = from
	area.team = from.team
	area.ability = data
	area.direction = dir if dir.length_squared() > 0.01 else Vector3.FORWARD
	area.visual_only = true
	from.get_parent().add_child(area)
	area.global_position = point
	return area


## Newest Flying Thunder God kunai of `owner_char` (or null).
static func newest_marker(owner_char: CombatCharacter) -> GroundArea:
	var best: GroundArea = null
	for node: Node in owner_char.get_tree().get_nodes_in_group(&"markers"):
		var m := node as GroundArea
		if m != null and m.source == owner_char and not m.is_queued_for_deletion():
			if best == null or m.elapsed < best.elapsed:
				best = m
	return best


## Removes a marker after it has been used.
func consume() -> void:
	_finish()


func _ready() -> void:
	add_to_group(&"ground_areas")
	add_to_group(&"round_entities")
	if ability.marker:
		add_to_group(&"markers")
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
	if ability.wall_length > 0.0:
		_raise_wall()
	if ability.zone_duration > 0.0 and CombatFx.is_enabled():
		if _fill != null:
			_fill.visible = false
		SpellVfx.zone_visual(self)
	if visual_only:
		if ability.zone_duration <= 0.0:
			queue_free()
		return  # replicas linger until the server despawns them
	if not ability.trap and (ability.damage > 0.0 or ability.stun_duration > 0.0 or ability.root_duration > 0.0):
		_hit_inside(ability.damage, true)
	if ability.zone_duration <= 0.0:
		_finish()


func _zone_process(delta: float) -> void:
	_zone_left -= delta
	if visual_only:
		if _zone_left < -2.0:
			queue_free()  # safety if the despawn message was lost
		return
	if ability.trap:
		if _enemy_inside():
			SpellVfx.area_detonate(self, global_position, ability)
			_hit_inside(ability.damage, true)
			_finish()
			return
	elif ability.zone_tick_damage > 0.0 or ability.slow_duration > 0.0 or ability.burn_duration > 0.0:
		_tick_timer -= delta
		if _tick_timer <= 0.0:
			_tick_timer = ZONE_TICK
			_hit_inside(ability.zone_tick_damage, false)
	if _zone_left <= 0.0:
		_finish()


func _enemy_inside() -> bool:
	for node: Node in get_tree().get_nodes_in_group(&"fighters"):
		var f := node as CombatCharacter
		if f != null and f.team != team and not f.is_dead() and HitQuery.flat(f.global_position - global_position).length() <= ability.hit_radius:
			return true
	return false


## Sand wall: a solid box across the cast direction (blocks movement for
## everyone, including the client's predicted body).
func _raise_wall() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(ability.wall_length, 2.0, 0.8)
	shape.shape = box
	shape.position.y = 1.0
	body.add_child(shape)
	add_child(body)
	body.global_basis = Basis.looking_at(direction, Vector3.UP)
	if CombatFx.is_enabled():
		SpellVfx.sand_wall(self, body, ability.wall_length)


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
