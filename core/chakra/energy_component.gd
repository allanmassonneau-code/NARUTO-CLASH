class_name EnergyComponent
extends Node
## Chakra energy. Arena mode: starts empty, gained by landing hits, spent on
## chakra techniques / ultimate. Chakra mode (open world, configure_chakra):
## starts full, regenerates over time (faster while concentrating) and is
## not refilled by combat.

signal energy_changed(current: float, maximum: float)

@export var max_energy: float = 100.0

var current_energy: float = 0.0
var infinite_debug: bool = false
## Passive regeneration per second (chakra mode).
var regen_per_second: float = 0.0
var start_full: bool = false
## Scale applied to combat gains (hits dealt / taken, parries).
var combat_gain_scale: float = 1.0


func configure_chakra(maximum: float, regen: float) -> void:
	max_energy = maximum
	regen_per_second = regen
	start_full = true
	combat_gain_scale = 0.0
	reset()


func reset() -> void:
	current_energy = max_energy if start_full else 0.0
	energy_changed.emit(current_energy, max_energy)


## Combat gain (hits, parries): scaled by combat_gain_scale.
func gain(amount: float) -> void:
	restore(amount * combat_gain_scale)


## Direct gain, unaffected by combat_gain_scale.
func restore(amount: float) -> void:
	if amount <= 0.0 or current_energy >= max_energy:
		return
	current_energy = minf(current_energy + amount, max_energy)
	energy_changed.emit(current_energy, max_energy)


## Passive regeneration; `multiplier` > 1 while concentrating.
func tick(delta: float, multiplier: float = 1.0) -> void:
	if regen_per_second > 0.0:
		restore(regen_per_second * multiplier * delta)


func can_afford(cost: float) -> bool:
	return infinite_debug or current_energy >= cost


func consume(cost: float) -> bool:
	if not can_afford(cost):
		return false
	if not infinite_debug:
		current_energy -= cost
	energy_changed.emit(current_energy, max_energy)
	return true


func get_ratio() -> float:
	return current_energy / max_energy if max_energy > 0.0 else 0.0


## Client mirror of the server value.
func sync_state(value: float) -> void:
	current_energy = value
	energy_changed.emit(current_energy, max_energy)
