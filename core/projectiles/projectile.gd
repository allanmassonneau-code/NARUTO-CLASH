class_name Projectile
extends Node3D
## Generic straight-line projectile. Stops on walls, passes through immaterial
## targets, is consumed by counters.

var source: CombatCharacter
var team: int = 0
var ability: AbilityData
var direction: Vector3 = Vector3.FORWARD
var age: float = 0.0
## Client-side replica: moves and renders, never hits (the server decides).
var visual_only: bool = false
var net_id: int = 0

var _travelled: float = 0.0
var _already_hit: Array[CombatCharacter] = []


static func spawn(from: CombatCharacter, data: AbilityData, dir: Vector3) -> Projectile:
	var p := Projectile.new()
	p.source = from
	p.team = from.team
	p.ability = data
	p.direction = HitQuery.flat(dir).normalized()
	from.get_parent().add_child(p)
	p.global_position = from.global_position + Vector3.UP * HitQuery.BODY_HEIGHT + p.direction * 0.4
	p.net_id = Net.on_entity_spawned(p, from, data, p.global_position, p.direction)
	return p


static func spawn_visual(from: CombatCharacter, data: AbilityData, at: Vector3, dir: Vector3) -> Projectile:
	var p := Projectile.new()
	p.source = from
	p.team = from.team
	p.ability = data
	p.direction = dir
	p.visual_only = true
	from.get_parent().add_child(p)
	p.global_position = at
	return p


func _ready() -> void:
	add_to_group(&"projectiles")
	add_to_group(&"round_entities")
	SpellVfx.projectile_visual(self)


func _process(delta: float) -> void:
	SpellVfx.projectile_tick(self, delta)


## Client: the server says this projectile is gone (hit or wall).
func impact() -> void:
	SpellVfx.projectile_impact(self, global_position, ability)
	queue_free()


func _physics_process(delta: float) -> void:
	age += delta
	var from: Vector3 = global_position
	var step: Vector3 = direction * ability.projectile_speed * delta
	var wall: Dictionary = HitQuery.raycast_world(get_world_3d(), from, from + step)
	if not wall.is_empty():
		_expire(wall.position)
		return
	global_position = from + step
	_travelled += step.length()
	if not visual_only:
		var blocker: KitObject = KitObject.blocker_at(get_tree(), global_position, team)
		if blocker != null:
			_expire(global_position)
			return
	if visual_only:
		if _travelled >= ability.max_range:
			queue_free()
		return
	for target: CombatCharacter in HitQuery.characters_in_sphere(get_world_3d(), global_position, ability.hit_radius):
		if target.team == team or _already_hit.has(target):
			continue
		var result: HitData.Result = target.receive_hit(HitData.from_ability(source, ability, direction))
		if result == HitData.Result.IGNORED:
			continue  # immaterial: fly through
		_already_hit.append(target)
		if not ability.projectile_piercing or result == HitData.Result.COUNTERED:
			_expire(global_position)
			return
	if ArenaRules.hit_orb(source, global_position, ability.hit_radius, ability.damage):
		_expire(global_position)
		return
	if _travelled >= ability.max_range:
		_expire(global_position)


func _expire(at: Vector3) -> void:
	if visual_only:
		queue_free()  # the server's despawn triggers impact() on clients
		return
	Net.on_entity_despawned(net_id)
	SpellVfx.projectile_impact(self, at, ability)
	if ability.expire_zone != null and is_instance_valid(source):
		GroundArea.spawn(source, ability.expire_zone, at)
	queue_free()
