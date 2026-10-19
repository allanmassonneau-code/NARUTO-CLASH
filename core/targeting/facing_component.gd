class_name FacingComponent
extends Node
## Owns the character's facing (aim) direction, independent from movement.
## Gameplay reads `facing_direction`; `visual_pivot` only mirrors it.

@export var visual_pivot: Node3D
## Ignore aim points closer than this to avoid jitter under the cursor.
@export var min_aim_distance: float = 0.05

var facing_direction: Vector3 = Vector3.FORWARD
var aim_point: Vector3 = Vector3.ZERO


func update_aim(origin: Vector3, target: Vector3) -> void:
	aim_point = target
	var flat := Vector3(target.x - origin.x, 0.0, target.z - origin.z)
	if flat.length() < min_aim_distance:
		return
	facing_direction = flat.normalized()
	if visual_pivot != null:
		visual_pivot.global_basis = Basis.looking_at(facing_direction, Vector3.UP)
