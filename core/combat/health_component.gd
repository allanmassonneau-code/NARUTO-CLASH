class_name HealthComponent
extends Node
## Current / max / recoverable health (Battlerite-style). Normal healing can
## only restore recoverable health; true healing ignores that limit.

signal health_changed(current: float, maximum: float, recoverable: float)
signal died

## Fraction of damage taken that becomes recoverable.
@export_range(0.0, 1.0) var recoverable_ratio: float = 0.5

var max_health: float = 100.0
var current_health: float = 100.0
var recoverable_health: float = 0.0
## Damage absorbed before health (sand armor, sand shield).
var shield: float = 0.0
var shield_left: float = 0.0
var invulnerable_debug: bool = false


func setup(maximum: float) -> void:
	max_health = maximum
	reset()


func reset() -> void:
	current_health = max_health
	recoverable_health = 0.0
	shield = 0.0
	shield_left = 0.0
	_emit()


func apply_damage(amount: float) -> float:
	if is_dead() or amount <= 0.0:
		return 0.0
	if shield > 0.0:
		var absorbed: float = minf(shield, amount)
		shield -= absorbed
		amount -= absorbed
		if amount <= 0.0:
			_emit()
			return 0.0
	var dealt: float = minf(amount, current_health)
	if invulnerable_debug:
		dealt = 0.0
	current_health -= dealt
	recoverable_health = minf(recoverable_health + dealt * recoverable_ratio, max_health - current_health)
	_emit()
	if is_dead():
		died.emit()
	return dealt


func heal(amount: float, true_heal: bool = false) -> float:
	if is_dead() or amount <= 0.0:
		return 0.0
	var cap: float = max_health - current_health
	if not true_heal:
		cap = minf(cap, recoverable_health)
	var healed: float = minf(amount, cap)
	current_health += healed
	recoverable_health = clampf(recoverable_health - healed, 0.0, max_health - current_health)
	_emit()
	return healed


func add_shield(amount: float, duration: float) -> void:
	shield = maxf(shield, amount)
	shield_left = maxf(shield_left, duration)
	_emit()


func tick_shield(delta: float) -> void:
	if shield_left > 0.0:
		shield_left -= delta
		if shield_left <= 0.0:
			shield = 0.0
			_emit()


## Damage that ignores shields and can't kill (Eight Gates drain).
func drain(amount: float) -> void:
	current_health = maxf(1.0, current_health - amount)
	_emit()


## Client mirror of the server value.
func sync_state(current: float, recoverable: float) -> void:
	current_health = current
	recoverable_health = recoverable
	_emit()


func is_dead() -> bool:
	return current_health <= 0.0


func get_ratio() -> float:
	return current_health / max_health


func _emit() -> void:
	health_changed.emit(current_health, max_health, recoverable_health)
