class_name GameplayIntent
extends RefCounted
## What the controlling agent (player, bot, network) wants to do this tick.
## Device-agnostic: the character never reads raw input directly.

## Desired planar movement in world space (x/z), length in [0, 1].
var move_direction: Vector3 = Vector3.ZERO
## World-space point the agent is aiming at, on the ground plane.
var aim_point: Vector3 = Vector3.ZERO
var has_aim_point: bool = false
## Ability slots pressed this tick (see AbilityController.SLOTS).
var pressed_slots: Array[StringName] = []
## Ability slots currently held down (hold LMB = keep attacking).
var held_slots: Array[StringName] = []
var cancel_pressed: bool = false
## Guard (F) held down.
var guard_held: bool = false


func clear_actions() -> void:
	pressed_slots.clear()
	cancel_pressed = false
