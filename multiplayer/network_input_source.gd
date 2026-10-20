class_name NetworkInputSource
extends IntentSource
## Server side: intent fed by a remote client's input messages.

const SLOT_ORDER: Array[StringName] = AbilityController.SLOTS
## Bit of the held mask carrying the guard key.
const GUARD_BIT: int = 1 << 20
const CONCENTRATE_BIT: int = 1 << 21
const JUMP_BIT: int = 1 << 22

var peer_id: int = 0
## Last input sequence number received (acked back in snapshots).
var last_seq: int = 0

var _pending_presses: Array[StringName] = []
var _pending_cancel: bool = false
var _pending_jump: bool = false


func receive_input(seq: int, move: Vector2, aim: Vector2, held_mask: int = 0) -> void:
	if seq <= last_seq:
		return  # out of date
	last_seq = seq
	intent.guard_held = held_mask & GUARD_BIT != 0
	intent.concentrate_held = held_mask & CONCENTRATE_BIT != 0
	_pending_jump = _pending_jump or held_mask & JUMP_BIT != 0
	intent.held_slots.clear()
	for i in SLOT_ORDER.size():
		if held_mask & (1 << i):
			intent.held_slots.append(SLOT_ORDER[i])
	intent.move_direction = Vector3(move.x, 0.0, move.y).limit_length(1.0)
	intent.aim_point = Vector3(aim.x, 0.0, aim.y)
	intent.has_aim_point = true


func receive_press(slot_index: int) -> void:
	if slot_index >= 0 and slot_index < SLOT_ORDER.size():
		_pending_presses.append(SLOT_ORDER[slot_index])


func receive_cancel() -> void:
	_pending_cancel = true


func poll_intent() -> GameplayIntent:
	intent.clear_actions()
	intent.pressed_slots.append_array(_pending_presses)
	intent.cancel_pressed = _pending_cancel
	intent.jump_pressed = _pending_jump
	_pending_jump = false
	_pending_presses.clear()
	_pending_cancel = false
	return intent
