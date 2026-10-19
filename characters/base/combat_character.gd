class_name CombatCharacter
extends CharacterBody3D
## Composition root of a fighter. Orchestrates components each physics tick
## and hosts the central damage pipeline (receive_hit).

signal hit_received(hit: HitData)
signal counter_triggered(hit: HitData)
signal died(character: CombatCharacter)

enum NetMode { AUTHORITY, PUPPET, PREDICTED }

## Floats per fighter in a network snapshot (see write_snapshot).
const SNAPSHOT_STRIDE: int = 26
const LAYER_CHARACTERS: int = 2
const MASK_DEFAULT: int = 1 | 2
const MASK_PASS_THROUGH: int = 1

@export var data: CharacterData
@export var controller: IntentSource
@export var team: int = 0

var controls_enabled: bool = true
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
	movement.speed_multiplier = abilities.get_move_multiplier()
	velocity = movement.compute_velocity(wish, delta)
	move_and_slide()
	movement.on_post_move(get_real_velocity())
	global_position.y = 0.0  # planar arena


## Central damage pipeline: immaterial -> counter -> damage -> CC -> knockback.
func receive_hit(hit: HitData) -> HitData.Result:
	if is_dead() or status.has_status(StatusController.Type.IMMATERIAL):
		return HitData.Result.IGNORED
	if status.has_status(StatusController.Type.COUNTER):
		abilities.resolve_counter(hit)
		counter_triggered.emit(hit)
		return HitData.Result.COUNTERED
	health.apply_damage(hit.damage)
	if is_dead():
		hit_received.emit(hit)
		return HitData.Result.HIT
	if hit.stun_duration > 0.0:
		status.apply_status(StatusController.Type.STUN, hit.stun_duration)
		abilities.interrupt()
	if hit.root_duration > 0.0:
		status.apply_status(StatusController.Type.ROOT, hit.root_duration)
	if hit.knockback_velocity != Vector3.ZERO:
		abilities.interrupt()
		movement.apply_forced_motion(hit.knockback_velocity, hit.knockback_duration, true)
	if is_instance_valid(hit.source):
		hit.source.energy.gain(hit.energy_gain)
	hit_received.emit(hit)
	return HitData.Result.HIT


func is_dead() -> bool:
	return health.is_dead()


func set_pass_through(enabled: bool) -> void:
	# The predicted client body never blocks on (lagging) remote bodies.
	collision_mask = MASK_PASS_THROUGH if enabled or net_mode == NetMode.PREDICTED else MASK_DEFAULT


func reset_for_round(spawn: Transform3D) -> void:
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


## Client: applies the state written by write_snapshot.
func apply_snapshot(data: PackedFloat32Array, o: int) -> void:
	_net_target = Vector3(data[o], 0.0, data[o + 1])
	_net_velocity = Vector3(data[o + 2], 0.0, data[o + 3])
	_net_age = 0.0
	health.sync_state(data[o + 5], data[o + 6])
	energy.sync_state(data[o + 7])
	var cooldowns: Array[float] = []
	for i in AbilityController.SLOTS.size():
		cooldowns.append(data[o + 15 + i])
	abilities.sync_state(int(data[o + 8]), int(data[o + 9]), data[o + 10], cooldowns)
	var types: Array = StatusController.Type.values()
	for i in types.size():
		status.sync_remaining(types[i], data[o + 11 + i])
	_net_forced = data[o + 21] > 0.5
	if net_mode == NetMode.PUPPET:
		var angle: float = data[o + 4]
		facing.set_direction(Vector3(sin(angle), 0.0, cos(angle)))
		facing.aim_point = Vector3(data[o + 23], 0.0, data[o + 24])
		velocity = _net_velocity
	else:
		_reconcile(int(data[o + 22]))


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
	var multiplier: float = abilities.get_move_multiplier()
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


func _on_died() -> void:
	abilities.interrupt()
	status.clear_all()
	movement.stop()
	collision_layer = 0
	died.emit(self)
