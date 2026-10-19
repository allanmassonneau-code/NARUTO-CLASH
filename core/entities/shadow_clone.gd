class_name ShadowClone
extends Node3D
## Naruto's Kage Bunshin: a short-lived double that mirrors his melee and
## Rasengan (50 % damage). Not targetable; vanishes on timeout, swap or death.
## Simulated offline / on the server; on clients it is a visual replica
## driven by snapshots (`visual_only`).

const DAMAGE_SCALE: float = 0.5

var owner_character: CombatCharacter
var life: float = 5.0
var facing: Vector3 = Vector3.FORWARD
var visual_only: bool = false

var _model: ShinobiModel
var _dash_velocity: Vector3 = Vector3.ZERO
var _dash_left: float = 0.0
var _dash_ability: AbilityData
var _dash_hit: Array[CombatCharacter] = []
var _pose: StringName = &""
var _pose_left: float = 0.0
var _last_position: Vector3
var _speed: float = 0.0


static func spawn(owner_char: CombatCharacter, at: Vector3, duration: float, replica: bool = false) -> ShadowClone:
	var clone := ShadowClone.new()
	clone.owner_character = owner_char
	clone.life = duration
	clone.visual_only = replica
	clone.facing = owner_char.facing.facing_direction
	owner_char.get_parent().add_child(clone)
	clone.global_position = HitQuery.flat(at)
	return clone


func _ready() -> void:
	add_to_group(&"round_entities")
	_last_position = global_position
	if CombatFx.is_enabled():
		_model = ShinobiModel.new()
		add_child(_model)
		_model.build(owner_character.data.look if owner_character.data.look != null else ShinobiLook.new())
		_model.basis = Basis.looking_at(facing, Vector3.UP)
		SpellVfx.smoke(owner_character, global_position, 0.8)


func _physics_process(delta: float) -> void:
	if not visual_only:
		life -= delta
		if life <= 0.0 or owner_character == null or owner_character.is_dead():
			dismiss()
			return
		if _dash_left > 0.0:
			_dash_left -= delta
			global_position += _dash_velocity * delta
			_dash_hits()


func _process(delta: float) -> void:
	if _model == null:
		return
	_speed = lerpf(_speed, HitQuery.flat(global_position - _last_position).length() / maxf(delta, 0.001), 0.3)
	_last_position = global_position
	_pose_left -= delta
	_model.basis = Basis.looking_at(facing, Vector3.UP)
	_model.animate(delta, _speed, _pose if _pose_left > 0.0 else &"", Color(1, 0.6, 0.2, 0.12), 0.0)


## Mirrors a melee swing from the clone's position toward the nearest enemy
## (or the owner's cast direction).
func mirror_melee(a: AbilityData, direction: Vector3) -> void:
	facing = _aim_direction(direction, a.max_range + 1.0)
	_play_pose(a, 0.25)
	var hits: Array[CombatCharacter] = []
	AbilityEffects.melee_from(owner_character, global_position, facing, a, DAMAGE_SCALE, hits)


func mirror_dash(a: AbilityData, direction: Vector3) -> void:
	facing = _aim_direction(direction, a.get_reach() + 2.0)
	_play_pose(a, a.active_time + 0.15)
	_dash_ability = a
	_dash_hit.clear()
	_dash_velocity = facing * (a.dash_distance / a.active_time)
	_dash_left = a.active_time


## Replica update from a snapshot (clients).
func sync_from_snapshot(at: Vector3, new_facing: Vector3) -> void:
	global_position = global_position.lerp(HitQuery.flat(at), 0.5) if global_position.distance_to(at) < 3.0 else HitQuery.flat(at)
	if new_facing.length_squared() > 0.01:
		facing = new_facing


func dismiss() -> void:
	if CombatFx.is_enabled() and is_inside_tree():
		SpellVfx.smoke(owner_character if is_instance_valid(owner_character) else self, global_position, 0.8)
	if is_instance_valid(owner_character) and owner_character.clone == self:
		owner_character.clone = null
	queue_free()


func _dash_hits() -> void:
	var center: Vector3 = global_position + Vector3.UP * HitQuery.BODY_HEIGHT
	for target: CombatCharacter in HitQuery.characters_in_sphere(get_world_3d(), center, _dash_ability.hit_radius + HitQuery.HURTBOX_RADIUS):
		if target.team == owner_character.team or _dash_hit.has(target):
			continue
		_dash_hit.append(target)
		var hit := HitData.from_ability(owner_character, _dash_ability, _dash_velocity)
		hit.damage *= DAMAGE_SCALE
		hit.energy_gain = 0.0
		if target.receive_hit(hit) != HitData.Result.IGNORED:
			CombatFx.ring(owner_character, target.global_position, 1.0, _dash_ability.color, 0.25)
			_dash_left = 0.0
			return


func _aim_direction(fallback: Vector3, search_range: float) -> Vector3:
	var best: CombatCharacter = null
	var best_d: float = search_range
	for node: Node in get_tree().get_nodes_in_group(&"fighters"):
		var other := node as CombatCharacter
		if other == null or other.team == owner_character.team or other.is_dead():
			continue
		var d: float = global_position.distance_to(other.global_position)
		if d < best_d:
			best_d = d
			best = other
	if best != null:
		return HitQuery.flat(best.global_position - global_position).normalized()
	return fallback


func _play_pose(a: AbilityData, duration: float) -> void:
	_pose = StringName((String(a.anim) if a.anim != &"" else "jab") + ":strike")
	_pose_left = duration
