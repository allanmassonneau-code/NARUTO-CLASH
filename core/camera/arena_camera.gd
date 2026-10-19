class_name ArenaCamera
extends Camera3D
## Fixed-angle competitive camera. Rigidly follows the target (no float),
## with an optional, very light offset toward the cursor.

@export var target: Node3D
@export_range(20.0, 89.0) var pitch_degrees: float = 58.0
@export var yaw_degrees: float = 0.0
@export var distance: float = 24.0
## 0 = locked on target. Fraction of target->cursor offset applied.
@export_range(0.0, 0.5) var cursor_offset_strength: float = 0.0
@export var max_cursor_offset: float = 3.0
## 0 = instant follow (recommended). Higher = smoothed.
@export var follow_smoothing: float = 0.0

var _focus: Vector3 = Vector3.ZERO


func _ready() -> void:
	# Target may be assigned at runtime (MatchManager).
	if target != null:
		_focus = target.global_position
	_apply()


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var desired: Vector3 = target.global_position + _cursor_offset()
	if follow_smoothing <= 0.0:
		_focus = desired
	else:
		_focus = _focus.lerp(desired, 1.0 - exp(-follow_smoothing * delta))
	_apply()


func _cursor_offset() -> Vector3:
	if cursor_offset_strength <= 0.0:
		return Vector3.ZERO
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(project_ray_origin(mouse), project_ray_normal(mouse))
	if hit == null:
		return Vector3.ZERO
	var offset: Vector3 = ((hit as Vector3) - target.global_position) * cursor_offset_strength
	offset.y = 0.0
	return offset.limit_length(max_cursor_offset)


func _apply() -> void:
	var pitch: float = deg_to_rad(pitch_degrees)
	var yaw: float = deg_to_rad(yaw_degrees)
	var back := Vector3(sin(yaw), 0.0, cos(yaw)) * cos(pitch) * distance
	global_position = _focus + back + Vector3.UP * sin(pitch) * distance
	look_at(_focus, Vector3.UP)
