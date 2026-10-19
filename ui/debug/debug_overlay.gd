class_name DebugOverlay
extends CanvasLayer
## Combat debug overlay (F1): HP, chakra, cast phase, statuses, velocity.
## F6/F7/F8 toggle playground cheats on the local player.

@export var character: CombatCharacter

@onready var _label: Label = $Panel/Label
@onready var _panel: Control = $Panel


func _unhandled_input(event: InputEvent) -> void:
	if character == null:
		return
	if event.is_action_pressed("debug_infinite_hp"):
		character.health.invulnerable_debug = not character.health.invulnerable_debug
	elif event.is_action_pressed("debug_infinite_energy"):
		character.energy.infinite_debug = not character.energy.infinite_debug
	elif event.is_action_pressed("debug_no_cooldowns"):
		character.abilities.cooldowns_disabled = not character.abilities.cooldowns_disabled


func _process(_delta: float) -> void:
	_panel.visible = DebugSettings.show_overlay
	if not _panel.visible or character == null:
		return
	var v: Vector3 = character.velocity
	var f: Vector3 = character.facing.facing_direction
	var ab: AbilityController = character.abilities
	var cast: String = "-"
	if ab.is_casting():
		cast = "%s  %s  %.2fs" % [ab.current.display_name, AbilityController.Phase.keys()[ab.phase], ab.phase_elapsed]
	_label.text = "\n".join([
		"%s" % character.data.display_name,
		"FPS        %d  (physics %d Hz)" % [Engine.get_frames_per_second(), Engine.physics_ticks_per_second],
		"HP         %.1f / %.0f  (recoverable %.1f)" % [character.health.current_health, character.health.max_health, character.health.recoverable_health],
		"Energy     %.1f" % character.energy.current_energy,
		"Cast       %s" % cast,
		"Status     %s" % character.status.describe(),
		"Velocity   (%.2f, %.2f)  |%.2f|" % [v.x, v.z, Vector2(v.x, v.z).length()],
		"Facing     %d°" % roundi(rad_to_deg(atan2(f.x, -f.z))),
		"Cheats     [F6] inf HP %s  [F7] inf energy %s  [F8] no CD %s" % [
			_on_off(character.health.invulnerable_debug), _on_off(character.energy.infinite_debug), _on_off(ab.cooldowns_disabled)],
		"[F1] overlay  [F2] aim  [F3] collisions",
	])


func _on_off(value: bool) -> String:
	return "ON" if value else "off"
