class_name StatusController
extends Node
## Single source of truth for every status on a character.
## Ticked by the owning character inside its physics step.

enum Type { STUN, ROOT, IMMATERIAL, COUNTER, SLOW, HASTE, EMPOWER, REGEN, MARK, SILENCE, INCAPACITATE, BURN, DRAIN, LOCK, SEAL }

const SLOW_MULTIPLIER: float = 0.6
const HASTE_MULTIPLIER: float = 1.3
const EMPOWER_MULTIPLIER: float = 1.25
const REGEN_PER_SECOND: float = 6.0
const BURN_PER_SECOND: float = 4.0
## Eight Gates: HP lost per second while open (never lethal).
const DRAIN_PER_SECOND: float = 3.0

signal status_applied(type: Type, duration: float)
signal status_removed(type: Type)

var _remaining: Dictionary = {}  # Type -> seconds left
var _stacks: Dictionary = {}  # Type -> stack count (stacking statuses like MARK)
## Diminishing returns: a stun landing while this is > 0 lasts half as long
## (stops endless stun chains, especially in 2v2).
var _stun_resist_left: float = 0.0
const STUN_RESIST_WINDOW: float = 2.0


func apply_status(type: Type, duration: float) -> void:
	if duration <= 0.0:
		return
	if type == Type.STUN or type == Type.INCAPACITATE:
		if _stun_resist_left > 0.0:
			duration *= 0.5
		_stun_resist_left = maxf(_stun_resist_left, duration + STUN_RESIST_WINDOW)
	_remaining[type] = maxf(_remaining.get(type, 0.0), duration)
	status_applied.emit(type, duration)


## Adds stacks (capped) and refreshes the duration.
func add_stacks(type: Type, amount: int, max_stacks: int, duration: float) -> void:
	_stacks[type] = mini(get_stacks(type) + amount, max_stacks)
	_remaining[type] = duration
	status_applied.emit(type, duration)


func get_stacks(type: Type) -> int:
	return _stacks.get(type, 0) if has_status(type) else 0


func remove_status(type: Type) -> void:
	_stacks.erase(type)
	if _remaining.erase(type):
		status_removed.emit(type)


## Movement speed factor from slows / hastes.
func speed_multiplier() -> float:
	var m: float = 1.0
	if has_status(Type.SLOW):
		m *= SLOW_MULTIPLIER
	if has_status(Type.HASTE):
		m *= HASTE_MULTIPLIER
	return m


func has_status(type: Type) -> bool:
	return _remaining.has(type)


func get_remaining(type: Type) -> float:
	return _remaining.get(type, 0.0)


## Client mirror of the server value.
func sync_remaining(type: Type, remaining: float) -> void:
	if remaining > 0.0:
		_remaining[type] = remaining
	else:
		_remaining.erase(type)
		_stacks.erase(type)


func sync_stacks(type: Type, stacks: int) -> void:
	if stacks > 0:
		_stacks[type] = stacks
	else:
		_stacks.erase(type)


func clear_all() -> void:
	_stun_resist_left = 0.0
	for type: Type in _remaining.keys():
		remove_status(type)


func tick(delta: float) -> void:
	_stun_resist_left = maxf(0.0, _stun_resist_left - delta)
	for type: Type in _remaining.keys():
		_remaining[type] -= delta
		if _remaining[type] <= 0.0:
			remove_status(type)


func can_move() -> bool:
	return not has_status(Type.STUN) and not has_status(Type.ROOT) and not has_status(Type.INCAPACITATE)


func can_act() -> bool:
	return not has_status(Type.STUN) and not has_status(Type.INCAPACITATE)


## Silenced fighters can only use their basic attack.
func can_cast(slot: StringName) -> bool:
	return slot == &"lmb" or not has_status(Type.SILENCE)


func describe() -> String:
	var names: PackedStringArray = []
	for type: Type in _remaining:
		names.append("%s %.1f" % [Type.keys()[type], _remaining[type]])
	return ", ".join(names)
