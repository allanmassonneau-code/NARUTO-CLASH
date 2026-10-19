class_name CombatCharacter
extends CharacterBody3D
## Composition root of a fighter. Orchestrates components each physics tick
## and hosts the central damage pipeline (receive_hit).

signal hit_received(hit: HitData)
signal counter_triggered(hit: HitData)
signal died(character: CombatCharacter)

const LAYER_CHARACTERS: int = 2
const MASK_DEFAULT: int = 1 | 2
const MASK_PASS_THROUGH: int = 1

@export var data: CharacterData
@export var controller: IntentSource
@export var team: int = 0

var controls_enabled: bool = true

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
	health.died.connect(_on_died)
	presentation.setup(self)


func _physics_process(delta: float) -> void:
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
	collision_mask = MASK_PASS_THROUGH if enabled else MASK_DEFAULT


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


func _on_died() -> void:
	abilities.interrupt()
	status.clear_all()
	movement.stop()
	collision_layer = 0
	died.emit(self)
