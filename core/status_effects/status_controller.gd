class_name StatusController
extends Node
## Single source of truth for every status on a character.
## Ticked by the owning character inside its physics step.

enum Type { STUN, ROOT, IMMATERIAL, COUNTER }

signal status_applied(type: Type, duration: float)
signal status_removed(type: Type)

var _remaining: Dictionary = {}  # Type -> seconds left


func apply_status(type: Type, duration: float) -> void:
	if duration <= 0.0:
		return
	_remaining[type] = maxf(_remaining.get(type, 0.0), duration)
	status_applied.emit(type, duration)


func remove_status(type: Type) -> void:
	if _remaining.erase(type):
		status_removed.emit(type)


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


func clear_all() -> void:
	for type: Type in _remaining.keys():
		remove_status(type)


func tick(delta: float) -> void:
	for type: Type in _remaining.keys():
		_remaining[type] -= delta
		if _remaining[type] <= 0.0:
			remove_status(type)


func can_move() -> bool:
	return not has_status(Type.STUN) and not has_status(Type.ROOT)


func can_act() -> bool:
	return not has_status(Type.STUN)


func describe() -> String:
	var names: PackedStringArray = []
	for type: Type in _remaining:
		names.append("%s %.1f" % [Type.keys()[type], _remaining[type]])
	return ", ".join(names)
