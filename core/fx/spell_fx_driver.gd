class_name SpellFxDriver
extends Node
## Drives one effect node: calls `updater(parent, t)` each frame with t in
## 0..1 over `life` seconds, then frees the parent.

var life: float = 0.3
var updater: Callable
var _age: float = 0.0


func _process(delta: float) -> void:
	_age += delta
	var parent := get_parent() as Node3D
	if parent == null:
		queue_free()
		return
	var t: float = clampf(_age / life, 0.0, 1.0)
	if updater.is_valid():
		updater.call(parent, t)
	if _age >= life:
		parent.queue_free()
