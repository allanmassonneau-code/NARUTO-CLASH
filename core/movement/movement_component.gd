class_name MovementComponent
extends Node
## Owns locomotion velocity. Forced movement (dash, knockback) overrides
## player locomotion for its duration instead of writing `velocity` directly.

@export var data: MovementData

## Multiplier fed by casts / future slows & hastes. Single source: here.
var speed_multiplier: float = 1.0

var _locomotion_velocity: Vector3 = Vector3.ZERO
var _forced_velocity: Vector3 = Vector3.ZERO
var _forced_duration: float = 0.0
var _forced_time_left: float = 0.0
var _forced_decays: bool = false
## The current forced motion was inflicted by a hit (can slam into walls).
var is_knockback: bool = false


func compute_velocity(wish_direction: Vector3, delta: float) -> Vector3:
	if _forced_time_left > 0.0:
		var t: float = _forced_time_left / _forced_duration if _forced_decays else 1.0
		_forced_time_left -= delta
		if _forced_time_left <= 0.0:
			is_knockback = false
		_locomotion_velocity = Vector3.ZERO
		return _forced_velocity * t
	var target: Vector3 = wish_direction * data.move_speed * speed_multiplier
	if data.instant_response:
		_locomotion_velocity = target
	else:
		var rate: float = data.acceleration if wish_direction != Vector3.ZERO else data.deceleration
		_locomotion_velocity = _locomotion_velocity.move_toward(target, rate * delta)
	return _locomotion_velocity


## Sync after collisions so we don't keep pushing into walls.
func on_post_move(real_velocity: Vector3) -> void:
	if not is_forced():
		_locomotion_velocity = Vector3(real_velocity.x, 0.0, real_velocity.z)


## Dash (constant) or knockback (decaying) motion.
## Client reconciliation: restart prediction from the server's velocity.
func sync_velocity(server_velocity: Vector3) -> void:
	_locomotion_velocity = Vector3(server_velocity.x, 0.0, server_velocity.z)
	_forced_time_left = 0.0
	is_knockback = false


func apply_forced_motion(forced_velocity: Vector3, duration: float, decays: bool, knockback: bool = false) -> void:
	if duration <= 0.0:
		return
	is_knockback = knockback
	_forced_velocity = Vector3(forced_velocity.x, 0.0, forced_velocity.z)
	_forced_duration = duration
	_forced_time_left = duration
	_forced_decays = decays


func cancel_forced() -> void:
	_forced_time_left = 0.0
	is_knockback = false


func forced_direction() -> Vector3:
	return _forced_velocity.normalized()


## Current forced speed (0 when not forced).
func forced_speed() -> float:
	if _forced_time_left <= 0.0:
		return 0.0
	var t: float = _forced_time_left / _forced_duration if _forced_decays else 1.0
	return _forced_velocity.length() * t


func is_forced() -> bool:
	return _forced_time_left > 0.0


func stop() -> void:
	_locomotion_velocity = Vector3.ZERO
	cancel_forced()
