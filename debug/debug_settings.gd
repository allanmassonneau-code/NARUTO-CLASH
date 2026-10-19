extends Node
## Central authority for debug visualisation flags (autoload: DebugSettings).
## Gameplay never reads these; only presentation/debug layers do.

signal flags_changed

var show_overlay: bool = false
var show_aim: bool = true
var show_collisions: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle_overlay"):
		show_overlay = not show_overlay
		flags_changed.emit()
	elif event.is_action_pressed("debug_toggle_aim"):
		show_aim = not show_aim
		flags_changed.emit()
	elif event.is_action_pressed("debug_toggle_collisions"):
		show_collisions = not show_collisions
		get_tree().debug_collisions_hint = show_collisions
		flags_changed.emit()
