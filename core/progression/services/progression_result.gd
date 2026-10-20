class_name ProgressionResult
extends RefCounted
## Outcome of a progression action: success / error code, plus the events it
## produced (rewards, choices to make, roll results) for UI and replication.

var ok: bool = true
## Stable error code (e.g. &"RANK_LOCKED_BY_GRADE"), empty on success.
var error: StringName = &""
var message: String = ""
## Each event: {"type": StringName, ...payload}.
var events: Array[Dictionary] = []


static func success(events_list: Array[Dictionary] = []) -> ProgressionResult:
	var r := ProgressionResult.new()
	r.events = events_list
	return r


static func fail(code: StringName, text: String = "") -> ProgressionResult:
	var r := ProgressionResult.new()
	r.ok = false
	r.error = code
	r.message = text if text != "" else String(code)
	return r


func add_event(type: StringName, payload: Dictionary = {}) -> void:
	var event: Dictionary = payload.duplicate()
	event["type"] = type
	events.append(event)


func has_event(type: StringName) -> bool:
	return events.any(func(e: Dictionary) -> bool: return e.type == type)
