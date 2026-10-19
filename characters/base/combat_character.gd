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

@export var data: CharacterData
@export var controller: IntentSource
@export var team: int = 0

var controls_enabled: bool = true
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
	var intent: GameplayIntent = null
	if controls_enabled and controller != null:
		intent = controller.poll_intent()
	var can_act: bool = status.can_act()
	if intent != null and intent.has_aim_point and can_act and not abilities.is_facing_locked():
		facing.update_aim(global_position, intent.aim_point)
	abilities.tick(delta, intent if can_act else null)
	var wish: Vector3 = intent.move_direction if intent != null and status.can_move() else Vector3.ZERO
	movement.speed_multiplier = abilities.get_move_multiplier() * status.speed_multiplier()
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


## Central damage pipeline: immaterial -> counter -> modifiers (empower,
## marks, rooted bonus) -> damage -> CC -> knockback -> on-hit effects.
func receive_hit(hit: HitData) -> HitData.Result:
	if is_dead() or status.has_status(StatusController.Type.IMMATERIAL):
		return HitData.Result.IGNORED
	if status.has_status(StatusController.Type.COUNTER):
		abilities.resolve_counter(hit)
		counter_triggered.emit(hit)
		return HitData.Result.COUNTERED
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
	health.apply_damage(damage)
	if damage > 0.0:
		status.remove_status(StatusController.Type.INCAPACITATE)  # genjutsu breaks on damage
	if is_dead():
		hit_received.emit(hit)
		return HitData.Result.HIT
	if stun > 0.0:
		status.apply_status(StatusController.Type.STUN, stun)
		abilities.interrupt()
	if hit.root_duration > 0.0:
		status.apply_status(StatusController.Type.ROOT, hit.root_duration)
	if hit.knockback_velocity != Vector3.ZERO:
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
	return 11 + StatusController.Type.size() + AbilityController.SLOTS.size() + 5 + 3 + 4 + 4


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
	abilities.interrupt()
	status.clear_all()
	movement.stop()
	collision_layer = 0
	died.emit(self)
