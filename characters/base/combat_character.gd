class_name CombatCharacter
extends CharacterBody3D
## Composition root of a fighter. Orchestrates components each physics tick
## and hosts the central damage pipeline (receive_hit).

signal hit_received(hit: HitData)
signal counter_triggered(hit: HitData)
signal died(character: CombatCharacter)
signal passive_triggered

enum NetMode { AUTHORITY, PUPPET, PREDICTED }

const LAYER_CHARACTERS: int = 2
const MASK_DEFAULT: int = 1 | 2
const MASK_PASS_THROUGH: int = 1
## Knockbacks faster than this stun the target if they end in a wall.
const WALL_SLAM_MIN_SPEED: float = 7.0
const WALL_SLAM_DAMAGE: float = 6.0
const WALL_SLAM_STUN: float = 0.6
## Guard (hold F): frontal hits deal a fraction of their damage and no CC.
const GUARD_MOVE_MULTIPLIER: float = 0.45
const GUARD_DAMAGE_TAKEN: float = 0.3
## Raw damage a guard absorbs before breaking (stun).
const GUARD_BREAK_DAMAGE: float = 45.0
const GUARD_BREAK_STUN: float = 1.0
## Perfect parry: LMB while guarding opens this window; an enemy basic
## attack landing in it is negated and stuns the attacker.
const PARRY_WINDOW: float = 0.22
const PARRY_COOLDOWN: float = 0.9
const PARRY_STUN: float = 1.2
const PARRY_ENERGY: float = 15.0
## Chakra gained per point of damage taken.
const DAMAGE_TAKEN_ENERGY: float = 0.2
## Concentration (hold R): immobile, chakra regenerates this many times
## faster, but hits deal more damage and break it for a moment.
const CONCENTRATE_REGEN_MULTIPLIER: float = 6.0
const CONCENTRATE_DAMAGE_TAKEN: float = 1.25
const CONCENTRATE_HIT_LOCKOUT: float = 0.6
## Jump (Space): short hop that clears ground areas.
const JUMP_DURATION: float = 0.55
const JUMP_HEIGHT: float = 1.6
const JUMP_COOLDOWN: float = 0.15
## Projection: launched fighters rise to LAUNCH_HEIGHT, each hit taken in the
## air keeps them up a little longer (capped), then they fall.
const LAUNCH_HEIGHT: float = 2.6
const LAUNCH_RISE: float = 0.2
const LAUNCH_FALL: float = 0.3
const JUGGLE_EXTEND: float = 0.45
const JUGGLE_MAX: float = 3.0
const LANDING_DAMAGE: float = 5.0
const LANDING_STUN: float = 0.4
## Melee attacks pursue a launched enemy within this range automatically.
const PURSUIT_RANGE: float = 7.0
const PURSUIT_BREAK: float = 4.0

@export var data: CharacterData
@export var controller: IntentSource
@export var team: int = 0

var controls_enabled: bool = true
## Last fighter who damaged us (kill feed credit).
var last_attacker: CombatCharacter
var guarding: bool = false
## > 0 right after a perfect parry or a guard break (presentation cue, synced).
var parry_flash: float = 0.0
var guard_break_flash: float = 0.0
var _parry_left: float = 0.0
var _parry_cooldown: float = 0.0
var _guard_absorbed: float = 0.0
var concentrating: bool = false
var _concentrate_lock: float = 0.0
## Time left in the air (> 0 while jumping).
var air_time: float = 0.0
var _jump_cooldown: float = 0.0
## Time since the current launch started (projection arc).
var _launch_elapsed: float = 0.0
var _was_launched: bool = false
## Launched enemy we are pursuing in the air (null when grounded).
var pursuing: CombatCharacter
## Substitution (Kawarimi): while armed and inside its zone, the next hit
## is negated and teleports us back to the anchor.
var substitution_armed: bool = false
var substitution_anchor: Vector3 = Vector3.ZERO
var substitution_radius: float = 0.0
var _substitution_zone: Node3D
## Naruto's active shadow clone (null when none).
var clone: ShadowClone
var _passive_used: bool = false
var _passive_timer: float = 0.0
## Who knocked us back (credited for a wall slam).
var _slam_source: CombatCharacter
## AUTHORITY: simulates (offline / server). PUPPET: mirrors snapshots.
## PREDICTED: local client fighter, predicts movement and reconciles.
var net_mode: NetMode = NetMode.AUTHORITY

var _net_target: Vector3 = Vector3.ZERO
var _net_velocity: Vector3 = Vector3.ZERO
var _net_forced: bool = false
var _net_age: float = 0.0
var _input_seq: int = 0
var _pending_inputs: Array[Dictionary] = []

@onready var movement: MovementComponent = $MovementComponent
@onready var facing: FacingComponent = $FacingComponent
@onready var health: HealthComponent = $HealthComponent
@onready var energy: EnergyComponent = $EnergyComponent
@onready var status: StatusController = $StatusController
@onready var abilities: AbilityController = $AbilityController
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var presentation: CharacterPresentation = $CharacterPresentation


func _ready() -> void:
	assert(data != null, "%s: CharacterData missing." % name)
	assert(data.movement != null, "%s: MovementData missing." % name)
	add_to_group(&"fighters")
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	wall_min_slide_angle = 0.0
	collision_layer = LAYER_CHARACTERS
	collision_mask = MASK_DEFAULT
	movement.data = data.movement
	health.setup(data.max_health)
	if data.max_chakra > 0.0:
		energy.configure_chakra(data.max_chakra, data.chakra_regen)
	else:
		energy.reset()
	abilities.setup(self, data)
	hurtbox.character = self
	_net_target = global_position
	if net_mode == NetMode.PREDICTED:
		set_pass_through(false)
	health.died.connect(_on_died)
	presentation.setup(self)


func _physics_process(delta: float) -> void:
	match net_mode:
		NetMode.PUPPET:
			_follow_server(delta)
			return
		NetMode.PREDICTED:
			_predicted_process(delta)
			return
	if is_dead():
		velocity = Vector3.ZERO
		return
	status.tick(delta)
	_tick_launch(delta)
	var intent: GameplayIntent = null
	if controls_enabled and controller != null:
		intent = controller.poll_intent()
	var can_act: bool = status.can_act()
	if intent != null and intent.has_aim_point and can_act and not abilities.is_facing_locked():
		facing.update_aim(global_position, intent.aim_point)
	_tick_guard(delta, intent, can_act)
	_tick_concentration(delta, intent, can_act)
	_tick_jump(delta, intent, can_act)
	_tick_substitution()
	abilities.tick(delta, intent if can_act and not guarding and not concentrating else null)
	energy.tick(delta, CONCENTRATE_REGEN_MULTIPLIER if concentrating else 1.0)
	var wish: Vector3 = intent.move_direction if intent != null and status.can_move() and not concentrating else Vector3.ZERO
	movement.speed_multiplier = abilities.get_move_multiplier() * status.speed_multiplier() * (GUARD_MOVE_MULTIPLIER if guarding else 1.0)
	_tick_status_effects(delta)
	var knockback_speed: float = movement.forced_speed() if movement.is_knockback else 0.0
	velocity = movement.compute_velocity(wish, delta)
	move_and_slide()
	movement.on_post_move(get_real_velocity())
	global_position.y = 0.0  # planar arena
	if knockback_speed >= WALL_SLAM_MIN_SPEED:
		_check_wall_slam()


## Knocked hard into a wall (arena wall, rock, sand wall): stun + damage.
func _check_wall_slam() -> void:
	for i in get_slide_collision_count():
		var collision: KinematicCollision3D = get_slide_collision(i)
		if collision.get_collider() is CombatCharacter:
			continue
		if collision.get_normal().dot(movement.forced_direction()) > -0.5:
			continue  # grazing the wall, not a slam
		movement.cancel_forced()
		var hit := HitData.new()
		hit.source = _slam_source if is_instance_valid(_slam_source) else null
		hit.damage = WALL_SLAM_DAMAGE
		hit.stun_duration = WALL_SLAM_STUN
		CombatFx.ring(self, global_position, 1.3, Color(1.0, 0.85, 0.4), 0.35)
		receive_hit(hit)
		return


## Guard / perfect parry state (authoritative).
func _tick_guard(delta: float, intent: GameplayIntent, can_act: bool) -> void:
	parry_flash = maxf(0.0, parry_flash - delta)
	guard_break_flash = maxf(0.0, guard_break_flash - delta)
	_parry_left = maxf(0.0, _parry_left - delta)
	_parry_cooldown = maxf(0.0, _parry_cooldown - delta)
	guarding = intent != null and intent.guard_held and can_act and not abilities.is_casting() and not is_dead()
	if not guarding:
		_parry_left = 0.0
		_guard_absorbed = maxf(0.0, _guard_absorbed - 12.0 * delta)
		return
	if intent.pressed_slots.has(&"lmb") and _parry_cooldown <= 0.0:
		_parry_left = PARRY_WINDOW
		_parry_cooldown = PARRY_COOLDOWN


## Concentration: hold to stand still and regenerate chakra fast.
func _tick_concentration(delta: float, intent: GameplayIntent, can_act: bool) -> void:
	_concentrate_lock = maxf(0.0, _concentrate_lock - delta)
	concentrating = intent != null and intent.concentrate_held and can_act and not guarding \
		and not abilities.is_casting() and not is_airborne() and _concentrate_lock <= 0.0 and not is_dead()


func _tick_jump(delta: float, intent: GameplayIntent, can_act: bool) -> void:
	if air_time > 0.0:
		air_time = maxf(0.0, air_time - delta)
		if air_time <= 0.0:
			_jump_cooldown = JUMP_COOLDOWN
		return
	_jump_cooldown = maxf(0.0, _jump_cooldown - delta)
	if intent != null and intent.jump_pressed and can_act and status.can_move() and not guarding \
			and not concentrating and not abilities.is_casting() and _jump_cooldown <= 0.0:
		air_time = JUMP_DURATION


func is_airborne() -> bool:
	return air_time > 0.0 or is_launched() or is_instance_valid(pursuing)


func is_launched() -> bool:
	return status.has_status(StatusController.Type.LAUNCHED)


## Projection: helpless in the air for `duration`, then falls.
func launch(duration: float) -> void:
	status.apply_status(StatusController.Type.LAUNCHED, duration)
	_launch_elapsed = 0.0
	_was_launched = true
	air_time = 0.0
	concentrating = false
	guarding = false
	pursuing = null
	abilities.interrupt()
	movement.stop()


## A hit taken in the air keeps us up a little longer (capped).
func _extend_launch() -> void:
	var left: float = status.get_remaining(StatusController.Type.LAUNCHED)
	var extended: float = minf(left + JUGGLE_EXTEND, JUGGLE_MAX - _launch_elapsed)
	if extended > left:
		status.apply_status(StatusController.Type.LAUNCHED, extended)


func _tick_launch(delta: float) -> void:
	if is_launched():
		_launch_elapsed += delta
	elif _was_launched:
		_was_launched = false
		_land()
	if is_instance_valid(pursuing) and (not pursuing.is_launched() or pursuing.is_dead()
			or HitQuery.flat(pursuing.global_position - global_position).length() > PURSUIT_BREAK):
		pursuing = null


## End of a projection: thrown to the ground (small damage, short stun).
func _land() -> void:
	if is_dead():
		return
	CombatFx.ring(self, global_position, 1.4, Color(0.75, 0.65, 0.5), 0.35)
	health.apply_damage(LANDING_DAMAGE)
	if not is_dead():
		status.apply_status(StatusController.Type.STUN, LANDING_STUN)


## Called when a melee attack comes out: if a launched enemy is in reach,
## blink next to it and follow it in the air. Returns true if pursuing.
func try_pursue(ctrl: AbilityController) -> bool:
	var target: CombatCharacter = _pursuit_target(ctrl.cast_direction)
	if target == null:
		return false
	var to: Vector3 = HitQuery.flat(target.global_position - global_position)
	var dir: Vector3 = to.normalized() if to.length() > 0.05 else ctrl.cast_direction
	if to.length() > 1.3:
		CombatFx.ring(self, global_position, 0.8, Color(0.8, 0.9, 1.0), 0.25)
		global_position = target.global_position - dir * 1.1
		global_position.y = 0.0
	facing.set_direction(dir)
	ctrl.cast_direction = dir
	pursuing = target
	air_time = 0.0
	return true


func _pursuit_target(direction: Vector3) -> CombatCharacter:
	var best: CombatCharacter = null
	var best_distance: float = PURSUIT_RANGE
	for node: Node in get_tree().get_nodes_in_group(&"fighters"):
		var other := node as CombatCharacter
		if other == null or other == self or other.team == team or other.is_dead() or not other.is_launched():
			continue
		var to: Vector3 = HitQuery.flat(other.global_position - global_position)
		var d: float = to.length()
		if d > best_distance or (d > 2.5 and direction.dot(to / d) < 0.35):
			continue  # far targets must be roughly where we aim
		best = other
		best_distance = d
	return best


## Visual height of the jump / projection arc (presentation).
func jump_height() -> float:
	if is_launched():
		var left: float = status.get_remaining(StatusController.Type.LAUNCHED)
		return LAUNCH_HEIGHT * clampf(_launch_elapsed / LAUNCH_RISE, 0.0, 1.0) * clampf(left / LAUNCH_FALL, 0.0, 1.0)
	if is_instance_valid(pursuing):
		return pursuing.jump_height()
	if air_time <= 0.0:
		return 0.0
	var t: float = 1.0 - air_time / JUMP_DURATION
	return 4.0 * JUMP_HEIGHT * t * (1.0 - t)


## Saves the current position; the next hit taken inside the zone is negated.
func arm_substitution(radius: float) -> void:
	_disarm_substitution()
	substitution_armed = true
	substitution_anchor = HitQuery.flat(global_position)
	substitution_radius = radius
	_substitution_zone = CombatFx.zone_marker(self, substitution_anchor, radius, Color(1.0, 0.8, 0.35, 0.8))
	CombatFx.ring(self, substitution_anchor, 0.8, Color(1.0, 0.85, 0.4), 0.35)


func _tick_substitution() -> void:
	if substitution_armed and HitQuery.flat(global_position).distance_to(substitution_anchor) > substitution_radius:
		CombatFx.ring(self, substitution_anchor, substitution_radius, Color(1.0, 0.35, 0.3, 0.8), 0.3)
		_disarm_substitution()


func _disarm_substitution() -> void:
	substitution_armed = false
	if is_instance_valid(_substitution_zone):
		_substitution_zone.queue_free()
	_substitution_zone = null


## Kawarimi: a log takes the hit and we reappear at the saved position.
func _trigger_substitution() -> void:
	CombatFx.log_decoy(self, global_position)
	abilities.interrupt()
	movement.stop()
	air_time = 0.0
	global_position = substitution_anchor
	velocity = Vector3.ZERO
	status.apply_status(StatusController.Type.IMMATERIAL, 0.35)
	CombatFx.ring(self, substitution_anchor, 1.2, Color(1.0, 0.85, 0.4), 0.35)
	_disarm_substitution()


func _is_frontal(hit: HitData) -> bool:
	if not is_instance_valid(hit.source) or hit.source == self:
		return false
	var to_source: Vector3 = HitQuery.flat(hit.source.global_position - global_position)
	return to_source.length() < 0.05 or facing.facing_direction.dot(to_source.normalized()) > -0.2


## Central damage pipeline: immaterial -> counter -> modifiers (empower,
## marks, rooted bonus) -> damage -> CC -> knockback -> on-hit effects.
func receive_hit(hit: HitData) -> HitData.Result:
	if is_dead() or status.has_status(StatusController.Type.IMMATERIAL):
		return HitData.Result.IGNORED
	if status.has_status(StatusController.Type.COUNTER):
		abilities.resolve_counter(hit)
		counter_triggered.emit(hit)
		return HitData.Result.COUNTERED
	if is_airborne() and hit.ability != null and hit.ability.kind == AbilityData.Kind.GROUND_AREA:
		return HitData.Result.IGNORED  # jumped over it
	if substitution_armed and is_instance_valid(hit.source) and hit.source != self:
		_trigger_substitution()
		return HitData.Result.IGNORED
	if guarding and _is_frontal(hit):
		if _parry_left > 0.0 and hit.ability != null and hit.source.abilities.is_basic_attack(hit.ability):
			_perfect_parry(hit)
			return HitData.Result.COUNTERED
		return _block(hit)
	if is_instance_valid(hit.source) and hit.source != self:
		last_attacker = hit.source
	var a: AbilityData = hit.ability
	var damage: float = hit.damage
	var stun: float = hit.stun_duration
	if is_instance_valid(hit.source) and hit.source.status.has_status(StatusController.Type.EMPOWER):
		damage *= StatusController.EMPOWER_MULTIPLIER
	if a != null:
		var marks: int = status.get_stacks(StatusController.Type.MARK)
		if a.mark_bonus_damage > 0.0 and marks > 0:
			damage += a.mark_bonus_damage * marks
			if marks >= 3:
				stun = maxf(stun, a.mark_full_stun)
			status.remove_status(StatusController.Type.MARK)
		if a.bonus_vs_rooted > 0.0 and status.has_status(StatusController.Type.ROOT):
			damage += a.bonus_vs_rooted
			status.remove_status(StatusController.Type.ROOT)
	# Projection: a launched fighter stays up (no stun / knockback while in
	# the air); a launch hit sends a grounded one up.
	var aerial: bool = false
	if is_launched():
		_extend_launch()
		aerial = true
	elif a != null and a.launch_duration > 0.0 and not data.launch_immune:
		launch(a.launch_duration)
		aerial = true
	if aerial:
		stun = 0.0
	if concentrating and damage > 0.0:
		damage *= CONCENTRATE_DAMAGE_TAKEN
		concentrating = false
		_concentrate_lock = CONCENTRATE_HIT_LOCKOUT
	health.apply_damage(damage)
	if damage > 0.0:
		status.remove_status(StatusController.Type.INCAPACITATE)  # genjutsu breaks on damage
		energy.gain(damage * DAMAGE_TAKEN_ENERGY)  # comeback: getting hit charges the ultimate too
	if is_dead():
		hit_received.emit(hit)
		return HitData.Result.HIT
	if stun > 0.0:
		status.apply_status(StatusController.Type.STUN, stun)
		abilities.interrupt()
	if hit.root_duration > 0.0:
		status.apply_status(StatusController.Type.ROOT, hit.root_duration)
	if hit.knockback_velocity != Vector3.ZERO and not aerial:
		abilities.interrupt()
		movement.apply_forced_motion(hit.knockback_velocity, hit.knockback_duration, true, true)
		_slam_source = hit.source
	if a != null:
		if a.slow_duration > 0.0:
			status.apply_status(StatusController.Type.SLOW, a.slow_duration)
		if a.apply_mark > 0:
			status.add_stacks(StatusController.Type.MARK, a.apply_mark, 3, 5.0)
		if a.apply_lock > 0:
			status.add_stacks(StatusController.Type.LOCK, a.apply_lock, 3, 4.0)
			if status.get_stacks(StatusController.Type.LOCK) >= 3:
				status.remove_status(StatusController.Type.LOCK)
				status.apply_status(StatusController.Type.SILENCE, 1.5)
				abilities.interrupt()
		if a.silence_duration > 0.0:
			status.apply_status(StatusController.Type.SILENCE, a.silence_duration)
		if a.incapacitate_duration > 0.0:
			status.apply_status(StatusController.Type.INCAPACITATE, a.incapacitate_duration)
			abilities.interrupt()
		if a.burn_duration > 0.0:
			status.apply_status(StatusController.Type.BURN, a.burn_duration)
		if a.apply_seal:
			status.apply_status(StatusController.Type.SEAL, 8.0)
		if a.energy_drain > 0.0 and is_instance_valid(hit.source):
			var stolen: float = minf(a.energy_drain, energy.current_energy)
			energy.sync_state(energy.current_energy - stolen)
			hit.source.energy.gain(stolen)
	if is_instance_valid(hit.source) and hit.source != self:
		hit.source.energy.gain(hit.energy_gain)
	_check_passive()
	hit_received.emit(hit)
	return HitData.Result.HIT


func _perfect_parry(hit: HitData) -> void:
	_parry_left = 0.0
	_parry_cooldown = 0.0
	_guard_absorbed = 0.0
	parry_flash = 0.4
	energy.gain(PARRY_ENERGY)
	var attacker: CombatCharacter = hit.source
	attacker.status.apply_status(StatusController.Type.STUN, PARRY_STUN)
	attacker.abilities.interrupt()
	var push: Vector3 = HitQuery.flat(attacker.global_position - global_position).normalized() * 6.0
	attacker.movement.apply_forced_motion(push, 0.15, true)
	CombatFx.ring(self, global_position, 1.6, Color(1.0, 0.95, 0.6), 0.35)
	counter_triggered.emit(hit)


## Guarded frontal hit: chip damage only, no crowd control.
func _block(hit: HitData) -> HitData.Result:
	var damage: float = hit.damage
	if is_instance_valid(hit.source) and hit.source.status.has_status(StatusController.Type.EMPOWER):
		damage *= StatusController.EMPOWER_MULTIPLIER
	health.apply_damage(damage * GUARD_DAMAGE_TAKEN)
	_guard_absorbed += damage
	if is_instance_valid(hit.source):
		hit.source.energy.gain(hit.energy_gain * 0.5)
		if hit.ability != null and hit.ability.kind == AbilityData.Kind.MELEE_ARC:
			# Striking a guard bounces the attacker back.
			var push: Vector3 = HitQuery.flat(hit.source.global_position - global_position).normalized() * 7.0
			hit.source.movement.apply_forced_motion(push, 0.14, true)
	if _guard_absorbed >= GUARD_BREAK_DAMAGE and not is_dead():
		_guard_absorbed = 0.0
		guarding = false
		guard_break_flash = 0.5
		status.apply_status(StatusController.Type.STUN, GUARD_BREAK_STUN)
		CombatFx.ring(self, global_position, 1.3, Color(1.0, 0.4, 0.3), 0.35)
	hit_received.emit(hit)
	return HitData.Result.HIT


## Damage / healing over time and passive timers (authoritative only).
func _tick_status_effects(delta: float) -> void:
	if status.has_status(StatusController.Type.REGEN):
		health.heal(StatusController.REGEN_PER_SECOND * delta, true)
	if status.has_status(StatusController.Type.BURN):
		health.apply_damage(StatusController.BURN_PER_SECOND * delta)
	if status.has_status(StatusController.Type.DRAIN):
		health.drain(StatusController.DRAIN_PER_SECOND * delta)
	health.tick_shield(delta)
	if data.passive == &"sand_armor":
		_passive_timer -= delta
		if _passive_timer <= 0.0 and health.shield <= 0.0:
			_passive_timer = 8.0
			health.add_shield(15.0, 999.0)


## Character passives triggered by state (data-driven via CharacterData.passive).
func _check_passive() -> void:
	if data.passive == &"kurama" and not _passive_used and health.get_ratio() < 0.3:
		_passive_used = true
		status.apply_status(StatusController.Type.REGEN, 4.0)
		status.apply_status(StatusController.Type.HASTE, 3.0)
		passive_triggered.emit()


func is_dead() -> bool:
	return health.is_dead()


func set_pass_through(enabled: bool) -> void:
	# The predicted client body never blocks on (lagging) remote bodies.
	collision_mask = MASK_PASS_THROUGH if enabled or net_mode == NetMode.PREDICTED else MASK_DEFAULT


func reset_for_round(spawn: Transform3D) -> void:
	dismiss_clone()
	last_attacker = null
	guarding = false
	parry_flash = 0.0
	guard_break_flash = 0.0
	_parry_left = 0.0
	_parry_cooldown = 0.0
	_guard_absorbed = 0.0
	concentrating = false
	_concentrate_lock = 0.0
	air_time = 0.0
	_jump_cooldown = 0.0
	_launch_elapsed = 0.0
	_was_launched = false
	pursuing = null
	_disarm_substitution()
	_passive_used = false
	_passive_timer = 0.0
	abilities.reset()
	status.clear_all()
	movement.stop()
	set_pass_through(false)
	health.reset()
	energy.reset()
	global_transform = spawn
	velocity = Vector3.ZERO
	collision_layer = LAYER_CHARACTERS
	facing.facing_direction = -spawn.basis.z
	facing.aim_point = spawn.origin - spawn.basis.z * 3.0


# --- Networking -----------------------------------------------------------

## Floats per fighter in a snapshot (see write_snapshot for the layout).
static func snapshot_stride() -> int:
	return 11 + StatusController.Type.size() + AbilityController.SLOTS.size() + 5 + 3 + 4 + 4 + 3 + 2


## Server: appends this fighter's state to a snapshot buffer.
func write_snapshot(out: PackedFloat32Array, acked_seq: int) -> void:
	var f: Vector3 = facing.facing_direction
	out.append_array([
		global_position.x, global_position.z, velocity.x, velocity.z, atan2(f.x, f.z),
		health.current_health, health.recoverable_health, energy.current_energy,
		float(abilities.phase), float(abilities.slot_index(abilities.current_slot)), abilities.phase_elapsed,
	])
	for type: int in StatusController.Type.values():
		out.append(status.get_remaining(type))
	for slot: StringName in AbilityController.SLOTS:
		out.append(abilities.get_cooldown_left(slot))
	out.append_array([1.0 if movement.is_forced() else 0.0, float(acked_seq), facing.aim_point.x, facing.aim_point.z, 1.0 if controls_enabled else 0.0])
	out.append_array([float(status.get_stacks(StatusController.Type.MARK)), float(status.get_stacks(StatusController.Type.LOCK)), health.shield])
	if is_instance_valid(clone):
		out.append_array([1.0, clone.global_position.x, clone.global_position.z, atan2(clone.facing.x, clone.facing.z)])
	else:
		out.append_array([0.0, 0.0, 0.0, 0.0])
	if abilities.copied != null:
		out.append_array([float(Net.fighter_index(abilities.copied_source)), float(abilities.slot_index(abilities.copied_source_slot)),
			float(abilities.copied_depth), abilities.copied_left])
	else:
		out.append_array([-1.0, -1.0, 0.0, 0.0])
	out.append_array([1.0 if guarding else 0.0, parry_flash, guard_break_flash])
	out.append_array([1.0 if concentrating else 0.0, air_time])


## Client: applies the state written by write_snapshot.
func apply_snapshot(data: PackedFloat32Array, o: int) -> void:
	var r := o  # read cursor
	_net_target = Vector3(data[r], 0.0, data[r + 1])
	_net_velocity = Vector3(data[r + 2], 0.0, data[r + 3])
	var angle: float = data[r + 4]
	_net_age = 0.0
	health.sync_state(data[r + 5], data[r + 6])
	energy.sync_state(data[r + 7])
	var phase: int = int(data[r + 8])
	var slot_index: int = int(data[r + 9])
	var elapsed: float = data[r + 10]
	r += 11
	var types: Array = StatusController.Type.values()
	for i in types.size():
		status.sync_remaining(types[i], data[r + i])
	r += types.size()
	var cooldowns: Array[float] = []
	for i in AbilityController.SLOTS.size():
		cooldowns.append(data[r + i])
	r += AbilityController.SLOTS.size()
	_net_forced = data[r] > 0.5
	var acked: int = int(data[r + 1])
	var aim := Vector3(data[r + 2], 0.0, data[r + 3])
	r += 5
	status.sync_stacks(StatusController.Type.MARK, int(data[r]))
	status.sync_stacks(StatusController.Type.LOCK, int(data[r + 1]))
	health.shield = data[r + 2]
	r += 3
	_sync_clone(data[r] > 0.5, Vector3(data[r + 1], 0.0, data[r + 2]), data[r + 3])
	r += 4
	var copy_source: CombatCharacter = Net.fighter_at(int(data[r]))
	var copy_slot: int = int(data[r + 1])
	abilities.sync_copy(copy_source, AbilityController.SLOTS[copy_slot] if copy_slot >= 0 else &"", int(data[r + 2]), data[r + 3])
	r += 4
	guarding = data[r] > 0.5
	parry_flash = data[r + 1]
	guard_break_flash = data[r + 2]
	r += 3
	concentrating = data[r] > 0.5
	air_time = data[r + 1]
	abilities.sync_state(phase, slot_index, elapsed, cooldowns)
	if net_mode == NetMode.PUPPET:
		facing.set_direction(Vector3(sin(angle), 0.0, cos(angle)))
		facing.aim_point = aim
		velocity = _net_velocity
	else:
		_reconcile(acked)


## Client: keeps a visual clone replica in sync with the server's clone.
func _sync_clone(active: bool, at: Vector3, angle: float) -> void:
	if not active:
		if is_instance_valid(clone):
			clone.dismiss()
		clone = null
		return
	if not is_instance_valid(clone):
		clone = ShadowClone.spawn(self, at, 999.0, true)
	clone.sync_from_snapshot(at, Vector3(sin(angle), 0.0, cos(angle)))


## Local client fighter: predicts its own locomotion, the server stays authoritative.
func _predicted_process(delta: float) -> void:
	_net_age += delta
	var intent: GameplayIntent = null
	if controls_enabled and controller != null:
		intent = controller.poll_intent()
	if intent == null:
		_follow_server(delta)
		return
	if intent.has_aim_point and status.can_act() and not abilities.is_facing_locked():
		facing.update_aim(global_position, intent.aim_point)
	_input_seq += 1
	Net.send_input(_input_seq, intent, facing.aim_point)
	if is_dead() or _net_forced or not status.can_move():
		_follow_server(delta)
		return
	var multiplier: float = abilities.get_move_multiplier() * status.speed_multiplier()
	if intent.guard_held and status.can_act() and not abilities.is_casting():
		multiplier *= GUARD_MOVE_MULTIPLIER
	elif intent.concentrate_held and status.can_act() and not abilities.is_casting():
		multiplier = 0.0
	_simulate_locomotion(intent.move_direction, multiplier, delta)
	_pending_inputs.append({"seq": _input_seq, "wish": intent.move_direction, "mult": multiplier, "dt": delta})
	if _pending_inputs.size() > 120:
		_pending_inputs.pop_front()


func _reconcile(acked_seq: int) -> void:
	while not _pending_inputs.is_empty() and int(_pending_inputs[0].seq) <= acked_seq:
		_pending_inputs.pop_front()
	if is_dead() or _net_forced or not status.can_move() or not controls_enabled:
		_pending_inputs.clear()
		return
	var predicted: Vector3 = global_position
	global_position = _net_target
	movement.sync_velocity(_net_velocity)
	for input: Dictionary in _pending_inputs:
		_simulate_locomotion(input.wish, input.mult, input.dt)
	# Hide tiny corrections: keep the visual where it was if the error is small.
	if global_position.distance_to(predicted) < 0.08:
		global_position = predicted


func _simulate_locomotion(wish: Vector3, multiplier: float, delta: float) -> void:
	movement.speed_multiplier = multiplier
	velocity = movement.compute_velocity(wish, delta)
	move_and_slide()
	movement.on_post_move(get_real_velocity())
	global_position.y = 0.0


func _follow_server(delta: float) -> void:
	_net_age += delta
	var target: Vector3 = _net_target + _net_velocity * minf(_net_age, 0.1)
	if global_position.distance_to(target) > 4.0:
		global_position = target
	else:
		global_position = global_position.lerp(target, 1.0 - exp(-20.0 * delta))
	velocity = _net_velocity


func dismiss_clone() -> void:
	if is_instance_valid(clone):
		clone.dismiss()
	clone = null


func _on_died() -> void:
	dismiss_clone()
	_disarm_substitution()
	concentrating = false
	abilities.interrupt()
	status.clear_all()
	movement.stop()
	collision_layer = 0
	died.emit(self)
