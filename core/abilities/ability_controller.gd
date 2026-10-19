class_name AbilityController
extends Node
## Owns the cast lifecycle: READY -> STARTUP -> ACTIVE -> RECOVERY -> READY,
## cooldowns, input buffering, cancels and interrupts.

enum Phase { IDLE, STARTUP, ACTIVE, RECOVERY }

signal cast_started(slot: StringName, ability: AbilityData)
signal cast_activated(slot: StringName, ability: AbilityData)
signal cast_cancelled(slot: StringName, ability: AbilityData)
signal cast_interrupted(slot: StringName, ability: AbilityData)
signal cast_finished(slot: StringName, ability: AbilityData)

const SLOTS: Array[StringName] = [&"lmb", &"rmb", &"space", &"q", &"e", &"ult"]

## An input pressed this long before the character is free is still executed.
@export var input_buffer_window: float = 0.15

var character: CombatCharacter
var cooldowns_disabled: bool = false
var phase: Phase = Phase.IDLE
var current: AbilityData
var current_slot: StringName = &""
var phase_elapsed: float = 0.0
## Direction / point locked when the ability goes ACTIVE.
var cast_direction: Vector3 = Vector3.FORWARD
var cast_target_point: Vector3 = Vector3.ZERO

var _abilities: Dictionary = {}
var _cooldowns: Dictionary = {}
var _buffered_slot: StringName = &""
var _buffer_left: float = 0.0
var _hit_this_cast: Array[CombatCharacter] = []


func setup(owner_character: CombatCharacter, data: CharacterData) -> void:
	character = owner_character
	_abilities = data.get_ability_map()
	reset()


func reset() -> void:
	for slot: StringName in _abilities:
		_cooldowns[slot] = 0.0
	_clear_cast()
	_buffered_slot = &""
	_buffer_left = 0.0


func get_ability(slot: StringName) -> AbilityData:
	return _abilities.get(slot)


func get_cooldown_left(slot: StringName) -> float:
	return _cooldowns.get(slot, 0.0)


func slot_index(slot: StringName) -> int:
	return SLOTS.find(slot)


func slot_of(ability: AbilityData) -> StringName:
	for slot: StringName in _abilities:
		if _abilities[slot] == ability:
			return slot
	return &""


## Client mirror of the server cast state (no effects are executed).
func sync_state(new_phase: int, new_slot_index: int, elapsed: float, cooldowns: Array[float]) -> void:
	for i in SLOTS.size():
		if _cooldowns.has(SLOTS[i]):
			_cooldowns[SLOTS[i]] = cooldowns[i]
	if new_slot_index < 0 or new_phase == Phase.IDLE:
		_clear_cast()
		return
	phase = new_phase as Phase
	current_slot = SLOTS[new_slot_index]
	current = _abilities.get(current_slot)
	phase_elapsed = elapsed


func is_casting() -> bool:
	return phase != Phase.IDLE


func is_ready(slot: StringName) -> bool:
	var ability: AbilityData = get_ability(slot)
	return ability != null and get_cooldown_left(slot) <= 0.0 and character.energy.can_afford(ability.energy_cost)


func is_facing_locked() -> bool:
	return phase == Phase.ACTIVE or phase == Phase.RECOVERY


func get_move_multiplier() -> float:
	match phase:
		Phase.STARTUP, Phase.ACTIVE:
			return current.cast_move_multiplier
		Phase.RECOVERY:
			return current.recovery_move_multiplier
	return 1.0


func tick(delta: float, intent: GameplayIntent) -> void:
	for slot: StringName in _cooldowns:
		_cooldowns[slot] = maxf(0.0, _cooldowns[slot] - delta)
	if _buffer_left > 0.0:
		_buffer_left -= delta
		if _buffer_left <= 0.0:
			_buffered_slot = &""
	if intent != null:
		if intent.cancel_pressed:
			cancel()
		for slot: StringName in intent.pressed_slots:
			_buffered_slot = slot
			_buffer_left = input_buffer_window
	_advance(delta)
	if phase == Phase.IDLE and _buffered_slot != &"" and try_cast(_buffered_slot):
		_buffered_slot = &""
		_buffer_left = 0.0


func try_cast(slot: StringName) -> bool:
	var ability: AbilityData = get_ability(slot)
	if ability == null or phase != Phase.IDLE or character.is_dead():
		return false
	if not character.status.can_act() or not is_ready(slot):
		return false
	if ability.kind == AbilityData.Kind.DASH and character.status.has_status(StatusController.Type.ROOT):
		return false
	current = ability
	current_slot = slot
	phase = Phase.STARTUP
	phase_elapsed = 0.0
	_hit_this_cast.clear()
	cast_started.emit(slot, ability)
	if ability.startup_time <= 0.0:
		_activate()
	return true


## Voluntary cancel (feint). Only legal during startup if the jutsu allows it.
func cancel() -> void:
	if phase != Phase.STARTUP or not current.can_cancel_during_startup:
		return
	_set_cooldown(current_slot, current.cancel_cooldown)
	cast_cancelled.emit(current_slot, current)
	_clear_cast()


## Forced stop (stun, knockback, death).
func interrupt() -> void:
	if phase == Phase.IDLE:
		return
	if phase == Phase.STARTUP:
		_set_cooldown(current_slot, current.cancel_cooldown)
	elif phase == Phase.ACTIVE:
		AbilityEffects.end_active(self, current)
	cast_interrupted.emit(current_slot, current)
	_clear_cast()


## Used by effects that resolve before their active window ends (dash hit, counter).
func end_active_early() -> void:
	if phase == Phase.ACTIVE:
		_end_active()


func resolve_counter(hit: HitData) -> void:
	if phase == Phase.ACTIVE and current.kind == AbilityData.Kind.COUNTER:
		AbilityEffects.resolve_counter(self, current, hit)


## Returns false if the target was already hit by this cast.
func register_hit(target: CombatCharacter) -> bool:
	if _hit_this_cast.has(target):
		return false
	_hit_this_cast.append(target)
	return true


func _advance(delta: float) -> void:
	if phase == Phase.IDLE:
		return
	phase_elapsed += delta
	match phase:
		Phase.STARTUP:
			if phase_elapsed >= current.startup_time:
				_activate()
		Phase.ACTIVE:
			AbilityEffects.tick_active(self, current, delta)
			if phase == Phase.ACTIVE and phase_elapsed >= current.active_time:
				_end_active()
		Phase.RECOVERY:
			if phase_elapsed >= current.recovery_time:
				var slot: StringName = current_slot
				var ability: AbilityData = current
				_clear_cast()
				cast_finished.emit(slot, ability)


func _activate() -> void:
	if not character.energy.consume(current.energy_cost):
		_clear_cast()
		return
	phase = Phase.ACTIVE
	phase_elapsed = 0.0
	cast_direction = character.facing.facing_direction
	var to_aim: Vector3 = HitQuery.flat(character.facing.aim_point - character.global_position)
	cast_target_point = character.global_position + to_aim.limit_length(current.max_range)
	_set_cooldown(current_slot, current.cooldown)
	cast_activated.emit(current_slot, current)
	AbilityEffects.activate(self, current)


func _end_active() -> void:
	AbilityEffects.end_active(self, current)
	phase = Phase.RECOVERY
	phase_elapsed = 0.0


func _set_cooldown(slot: StringName, value: float) -> void:
	_cooldowns[slot] = 0.0 if cooldowns_disabled else value


func _clear_cast() -> void:
	phase = Phase.IDLE
	current = null
	current_slot = &""
	phase_elapsed = 0.0
