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

## j1..j6: the six technique slots of the shinobi (keys 1 to 6).
const SLOTS: Array[StringName] = [&"lmb", &"rmb", &"space", &"q", &"e", &"ult", &"j1", &"j2", &"j3", &"j4", &"j5", &"j6"]

## An input pressed this long before the character is free is still executed.
@export var input_buffer_window: float = 0.25
## Fraction of a combo hit's recovery after which the next hit may cut it short.
const COMBO_CANCEL_RATIO: float = 0.4

var character: CombatCharacter
var cooldowns_disabled: bool = false
var phase: Phase = Phase.IDLE
var current: AbilityData
var current_slot: StringName = &""
var phase_elapsed: float = 0.0
## Swings already performed by a multi-hit (flurry) jutsu this cast.
var pulse_count: int = 0
## Direction / point locked when the ability goes ACTIVE.
var cast_direction: Vector3 = Vector3.FORWARD
var cast_target_point: Vector3 = Vector3.ZERO

var _abilities: Dictionary = {}
var _cooldowns: Dictionary = {}
## Cooldowns of techniques taken off the bar (cooldown key -> seconds left),
## restored if they come back: swapping never resets a cooldown.
var _stashed: Dictionary = {}
var _buffered_slot: StringName = &""
var _buffer_left: float = 0.0
var _hit_this_cast: Array[CombatCharacter] = []
## Kakashi's copied jutsu: replaces COPY_SLOT for COPY_DURATION, one use.
const COPY_SLOT: StringName = &"e"
const COPY_DURATION: float = 10.0
var copied: AbilityData
var copied_left: float = 0.0
## Where the copy came from (fighter + slot + combo depth), for network sync.
var copied_source: CombatCharacter
var copied_source_slot: StringName = &""
var copied_depth: int = 0

## Pending combo follow-up per slot (AbilityData) and time left to use it.
var _combo_next: Dictionary = {}
var _combo_left: Dictionary = {}


func setup(owner_character: CombatCharacter, data: CharacterData) -> void:
	character = owner_character
	for slot: StringName in _abilities:
		if get_cooldown_left(slot) > 0.0:
			_stashed[cooldown_key(slot, _abilities[slot])] = get_cooldown_left(slot)
	var stashed: Dictionary = _stashed
	_abilities = data.get_ability_map()
	reset()
	for slot: StringName in _abilities:
		var key: StringName = cooldown_key(slot, _abilities[slot])
		if stashed.has(key):
			_cooldowns[slot] = stashed[key]
			stashed.erase(key)
	_stashed = stashed


## Techniques keep their cooldown by technique id, other slots by slot.
static func cooldown_key(slot: StringName, ability: AbilityData) -> StringName:
	return ability.source_id if ability != null and ability.source_id != &"" else StringName("slot:" + slot)


## Cooldown left of a technique, on the bar or not.
func technique_cooldown(source_id: StringName) -> float:
	for slot: StringName in _abilities:
		if (_abilities[slot] as AbilityData).source_id == source_id:
			return get_cooldown_left(slot)
	return _stashed.get(source_id, 0.0)


func reset() -> void:
	_cooldowns.clear()
	for slot: StringName in _abilities:
		_cooldowns[slot] = 0.0
	_stashed = {}
	_clear_cast()
	_buffered_slot = &""
	_buffer_left = 0.0
	_combo_next.clear()
	_combo_left.clear()
	_clear_copy()


func get_ability(slot: StringName) -> AbilityData:
	if slot == COPY_SLOT and copied != null:
		return copied
	return _abilities.get(slot)


func get_base_ability(slot: StringName) -> AbilityData:
	return _abilities.get(slot)


## True for any hit of the basic attack string (LMB and its combo follow-ups).
func is_basic_attack(ability: AbilityData) -> bool:
	var a: AbilityData = get_base_ability(&"lmb")
	var depth: int = 0
	while a != null and depth < 8:
		if a == ability:
			return true
		a = a.combo_next
		depth += 1
	return false


func reset_cooldown(slot: StringName) -> void:
	if _cooldowns.has(slot):
		_cooldowns[slot] = 0.0


## Copies `ability` (cast by `source`) into COPY_SLOT. Ultimates and
## counters can't be copied.
func copy_jutsu(source: CombatCharacter, ability: AbilityData) -> void:
	if ability.energy_cost >= 100.0 or ability.kind == AbilityData.Kind.COUNTER:
		return
	for slot: StringName in SLOTS:
		var depth: int = 0
		var a: AbilityData = source.abilities.get_base_ability(slot)
		while a != null:
			if a == ability:
				copied = ability
				copied_left = COPY_DURATION
				copied_source = source
				copied_source_slot = slot
				copied_depth = depth
				return
			a = a.combo_next
			depth += 1


## Client mirror of the server's copy state.
func sync_copy(source: CombatCharacter, slot: StringName, depth: int, left: float) -> void:
	if source == null or left <= 0.0:
		_clear_copy()
		return
	var a: AbilityData = source.abilities.get_base_ability(slot)
	for i in depth:
		if a != null:
			a = a.combo_next
	copied = a
	copied_left = left
	copied_source = source
	copied_source_slot = slot
	copied_depth = depth


func _clear_copy() -> void:
	copied = null
	copied_left = 0.0
	copied_source = null
	copied_source_slot = &""
	copied_depth = 0


func get_cooldown_left(slot: StringName) -> float:
	return _cooldowns.get(slot, 0.0)


func slot_index(slot: StringName) -> int:
	return SLOTS.find(slot)


func slot_of(ability: AbilityData) -> StringName:
	if ability != null and ability == copied:
		return COPY_SLOT
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
	current = get_ability(current_slot)
	phase_elapsed = elapsed


func is_casting() -> bool:
	return phase != Phase.IDLE


func is_ready(slot: StringName) -> bool:
	var ability: AbilityData = get_ability(slot)
	if ability != null and ability == copied:
		return character.energy.can_afford(ability.energy_cost)
	return ability != null and get_cooldown_left(slot) <= 0.0 and character.energy.can_afford(ability.energy_cost)


## Why the slot can't be cast right now, for the HUD: "" (castable),
## "RECHARGE" (cooldown), "CHAKRA" (not enough chakra) or "BLOQUÉ" (stunned,
## silenced, concentrating...).
func unavailable_reason(slot: StringName) -> String:
	var ability: AbilityData = get_castable(slot)
	if ability == null:
		return ""
	if get_cooldown_left(slot) > 0.0 and ability != copied:
		return "RECHARGE"
	if not character.energy.can_afford(ability.energy_cost):
		return "CHAKRA"
	if ability.stamina_cost > character.stamina:
		return "ENDURANCE"
	if character.is_dead() or not character.status.can_act() or not character.status.can_cast(slot) \
			or character.concentrating or character.guarding:
		return "BLOQUÉ"
	return ""


## Position in a combo string: x = hits already thrown (the next one is x + 1),
## y = number of hits in the string.
func combo_step(slot: StringName) -> Vector2i:
	var chain: Array[AbilityData] = []
	var a: AbilityData = get_base_ability(slot)
	while a != null and chain.size() < 16:
		chain.append(a)
		a = a.combo_next
	var next: AbilityData = _combo_next.get(slot)
	var done: int = chain.find(next) if next != null else 0
	if current_slot == slot and current != null:
		done = chain.find(current) + 1
	return Vector2i(maxi(done, 0), chain.size())


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
	for key: StringName in _stashed.keys():
		_stashed[key] -= delta
		if _stashed[key] <= 0.0:
			_stashed.erase(key)
	if copied != null:
		copied_left -= delta
		if copied_left <= 0.0 and not (current == copied and phase != Phase.IDLE):
			_clear_copy()
	for slot: StringName in _combo_left.keys():
		_combo_left[slot] -= delta
		if _combo_left[slot] <= 0.0:
			_combo_left.erase(slot)
			_combo_next.erase(slot)
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
	var wanted: StringName = _buffered_slot
	if wanted == &"" and intent != null and not intent.held_slots.is_empty():
		wanted = intent.held_slots[0]  # holding LMB keeps the string going
	if phase == Phase.RECOVERY and wanted != &"" and _can_cancel_recovery(wanted):
		_finish_recovery()
	if phase != Phase.IDLE or wanted == &"":
		return
	if try_cast(wanted) and wanted == _buffered_slot:
		_buffered_slot = &""
		_buffer_left = 0.0


## Recovery can be cut short by the next hit of a combo string, or by a
## mobility / defensive jutsu (dash out of a whiffed attack).
func _can_cancel_recovery(slot: StringName) -> bool:
	if slot == current_slot:
		return current.combo_next != null and phase_elapsed >= current.recovery_time * COMBO_CANCEL_RATIO
	var next: AbilityData = get_castable(slot)
	if next == null or next.energy_cost >= 100.0:
		return false
	match next.kind:
		AbilityData.Kind.DASH, AbilityData.Kind.TELEPORT, AbilityData.Kind.COUNTER:
			return character.status.can_cast(slot) and is_ready(slot) \
				and not (next.kind == AbilityData.Kind.DASH and character.status.has_status(StatusController.Type.ROOT))
	return false


## Ability the slot would cast right now (combo follow-up if one is pending).
func get_castable(slot: StringName) -> AbilityData:
	return _combo_next.get(slot, get_ability(slot))


func try_cast(slot: StringName) -> bool:
	var ability: AbilityData = get_castable(slot)
	if ability == null or phase != Phase.IDLE or character.is_dead():
		return false
	if not character.status.can_act() or not character.status.can_cast(slot) or not is_ready(slot):
		return false
	if ability.kind == AbilityData.Kind.DASH and character.status.has_status(StatusController.Type.ROOT):
		return false
	if ability.stamina_cost > character.stamina:
		return false
	_combo_next.erase(slot)
	_combo_left.erase(slot)
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
				_finish_recovery()


func _finish_recovery() -> void:
	var slot: StringName = current_slot
	var ability: AbilityData = current
	_clear_cast()
	if ability.combo_next != null:
		_combo_next[slot] = ability.combo_next
		_combo_left[slot] = ability.combo_window
	cast_finished.emit(slot, ability)


func _activate() -> void:
	if not character.energy.consume(current.energy_cost):
		_clear_cast()
		return
	character.spend_stamina(current.stamina_cost)
	phase = Phase.ACTIVE
	phase_elapsed = 0.0
	cast_direction = character.facing.facing_direction
	var to_aim: Vector3 = HitQuery.flat(character.facing.aim_point - character.global_position)
	cast_target_point = character.global_position + to_aim.limit_length(current.max_range)
	if current == copied:
		_clear_copy()  # one use; the slot keeps its own cooldown
	else:
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
