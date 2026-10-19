class_name BotController
extends IntentSource
## Simple combat bot. Produces the same GameplayIntent as a player, so it
## obeys every gameplay rule (cooldowns, frame data, chakra...).

@export var reaction_time: float = 0.22
@export var decision_interval: float = 0.1
@export var aim_error_degrees: float = 7.0
## Chance per decision tick to answer a detected threat with a defensive.
@export_range(0.0, 1.0) var defend_chance: float = 0.35
@export var passive: bool = false

var target: CombatCharacter

var _body: CombatCharacter
var _rng := RandomNumberGenerator.new()
var _decision_timer: float = 0.0
var _strafe_sign: float = 1.0
var _strafe_timer: float = 0.0
var _aim_error: float = 0.0
var _forced_aim: Vector3 = Vector3.ZERO
var _forced_aim_left: float = 0.0
var _preferred_range: float = -1.0


func _ready() -> void:
	_body = get_parent() as CombatCharacter
	assert(_body != null, "BotController must be a child of a CombatCharacter.")
	_rng.randomize()


func poll_intent() -> GameplayIntent:
	var delta: float = get_physics_process_delta_time()
	intent.clear_actions()
	target = _pick_target()
	if passive or target == null:
		intent.move_direction = Vector3.ZERO
		return intent
	if _preferred_range < 0.0:
		_preferred_range = _compute_preferred_range()
	var to_target: Vector3 = HitQuery.flat(target.global_position - _body.global_position)
	var dist: float = to_target.length()
	var dir: Vector3 = to_target.normalized() if dist > 0.01 else Vector3.FORWARD
	intent.move_direction = _choose_movement(dir, dist, delta)
	intent.aim_point = _choose_aim(dist, delta)
	intent.has_aim_point = true
	_decision_timer -= delta
	if _decision_timer <= 0.0:
		_decision_timer = decision_interval
		_decide(dir, dist)
	return intent


## Nearest living enemy among all fighters.
func _pick_target() -> CombatCharacter:
	var best: CombatCharacter = null
	var best_dist: float = INF
	for node: Node in get_tree().get_nodes_in_group(&"fighters"):
		var other := node as CombatCharacter
		if other == null or other.team == _body.team or other.is_dead():
			continue
		var d: float = _body.global_position.distance_squared_to(other.global_position)
		if d < best_dist:
			best_dist = d
			best = other
	return best


func _choose_movement(dir: Vector3, dist: float, delta: float) -> Vector3:
	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_timer = _rng.randf_range(0.6, 1.8)
		if _rng.randf() < 0.6:
			_strafe_sign = -_strafe_sign
	var radial: float = 0.0
	if dist > _preferred_range + 1.0:
		radial = 1.0
	elif dist < _preferred_range - 1.0:
		radial = -1.0
	var perp := Vector3(-dir.z, 0.0, dir.x) * _strafe_sign
	var move: Vector3 = dir * radial + perp * 0.7
	return move.normalized() if move.length() > 0.01 else Vector3.ZERO


func _choose_aim(dist: float, delta: float) -> Vector3:
	if _forced_aim_left > 0.0:
		_forced_aim_left -= delta
		return _forced_aim
	var lead_time: float = 0.0
	var a: AbilityData = _body.abilities.current
	if a != null and a.kind == AbilityData.Kind.PROJECTILE:
		lead_time = dist / a.projectile_speed
	var predicted: Vector3 = target.global_position + target.velocity * lead_time
	return _body.global_position + (predicted - _body.global_position).rotated(Vector3.UP, _aim_error)


func _decide(dir: Vector3, dist: float) -> void:
	if _body.abilities.is_casting():
		return
	if _sees_threat(dist) and _rng.randf() < defend_chance and _try_defend(dir):
		return
	if _try_heal(dist):
		return
	_try_attack(dir, dist)


func _sees_threat(dist: float) -> bool:
	var enemy_abilities: AbilityController = target.abilities
	if enemy_abilities.phase == AbilityController.Phase.STARTUP and enemy_abilities.phase_elapsed >= reaction_time:
		var a: AbilityData = enemy_abilities.current
		if a.does_damage() and a.kind != AbilityData.Kind.GROUND_AREA and dist <= a.get_reach() + 1.0:
			return true
	for node: Node in get_tree().get_nodes_in_group(&"projectiles"):
		var p := node as Projectile
		if p.team == _body.team or p.age < reaction_time:
			continue
		var to_me: Vector3 = HitQuery.flat(_body.global_position - p.global_position)
		if to_me.length() < 6.0 and p.direction.dot(to_me.normalized()) > 0.9:
			return true
	for node: Node in get_tree().get_nodes_in_group(&"ground_areas"):
		var area := node as GroundArea
		if area.team == _body.team or area.elapsed < reaction_time:
			continue
		if HitQuery.flat(_body.global_position - area.global_position).length() < area.ability.hit_radius + 0.6:
			return true
	return false


func _try_defend(dir: Vector3) -> bool:
	var q: AbilityData = _body.abilities.get_ability(&"q")
	if q != null and q.kind == AbilityData.Kind.COUNTER and _body.abilities.is_ready(&"q") and _rng.randf() < 0.5:
		_press(&"q")
		return true
	if _body.abilities.is_ready(&"space"):
		var perp := Vector3(-dir.z, 0.0, dir.x) * (1.0 if _rng.randf() < 0.5 else -1.0)
		_force_aim(_body.global_position + perp * 5.0, 0.3)
		_press(&"space")
		return true
	return false


func _try_heal(dist: float) -> bool:
	if _body.health.get_ratio() > 0.6 or dist < 4.0:
		return false
	for slot: StringName in [&"ult", &"q", &"e"]:
		var a: AbilityData = _body.abilities.get_ability(slot)
		if a != null and a.kind == AbilityData.Kind.SELF_HEAL and _body.abilities.is_ready(slot):
			_press(slot)
			return true
	return false


func _try_attack(dir: Vector3, dist: float) -> void:
	for slot: StringName in [&"ult", &"e", &"rmb", &"lmb"]:
		var a: AbilityData = _body.abilities.get_ability(slot)
		if a == null or not a.does_damage() or not _body.abilities.is_ready(slot):
			continue
		if dist > a.get_reach() * 0.9:
			continue
		if slot != &"lmb" and _rng.randf() < 0.35:
			continue  # don't dump every cooldown instantly
		_aim_error = deg_to_rad(_rng.randf_range(-aim_error_degrees, aim_error_degrees))
		_press(slot)
		return
	# Gap close with mobility when far from preferred range.
	if dist > _preferred_range + 5.0 and _body.abilities.is_ready(&"space") and _rng.randf() < 0.15:
		_force_aim(_body.global_position + dir * 5.0, 0.3)
		_press(&"space")


func _press(slot: StringName) -> void:
	intent.pressed_slots.append(slot)


func _force_aim(point: Vector3, duration: float) -> void:
	_forced_aim = point
	_forced_aim_left = duration


func _compute_preferred_range() -> float:
	var basic: AbilityData = _body.abilities.get_ability(&"lmb")
	if basic == null or basic.kind == AbilityData.Kind.MELEE_ARC:
		return 1.6
	return basic.max_range * 0.6
