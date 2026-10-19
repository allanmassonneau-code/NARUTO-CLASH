class_name EnergyComponent
extends Node
## Chakra energy: gained by landing hits, spent on chakra techniques / ultimate.

signal energy_changed(current: float, maximum: float)

@export var max_energy: float = 100.0

var current_energy: float = 0.0
var infinite_debug: bool = false


func reset() -> void:
	current_energy = 0.0
	energy_changed.emit(current_energy, max_energy)


func gain(amount: float) -> void:
	if amount <= 0.0:
		return
	current_energy = minf(current_energy + amount, max_energy)
	energy_changed.emit(current_energy, max_energy)


func can_afford(cost: float) -> bool:
	return infinite_debug or current_energy >= cost


func consume(cost: float) -> bool:
	if not can_afford(cost):
		return false
	if not infinite_debug:
		current_energy -= cost
	energy_changed.emit(current_energy, max_energy)
	return true
