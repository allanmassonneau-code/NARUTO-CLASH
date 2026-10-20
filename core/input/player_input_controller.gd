class_name PlayerInputController
extends IntentSource
## Raw input -> GameplayIntent. Movement is camera-relative, aim uses a
## camera ray intersected with the ground plane. Keys are physical, so
## WASD (QWERTY) and ZQSD (AZERTY) both work out of the box.

const SLOT_ACTIONS: Dictionary = {
	&"lmb": "ability_lmb",
	&"rmb": "ability_rmb",
	&"space": "ability_space",
	&"q": "ability_q",
	&"e": "ability_e",
	&"ult": "ability_ult",
	&"j1": "jutsu_1",
	&"j2": "jutsu_2",
	&"j3": "jutsu_3",
	&"j4": "jutsu_4",
	&"j5": "jutsu_5",
	&"j6": "jutsu_6",
}

@export var camera: Camera3D
## UI that may claim a press before it becomes a cast (combat menu):
## any object with `blocks_slot(slot: StringName) -> bool`.
var ui_blocker: Object
## Two presses of the same movement key within this time = chakra sprint.
const DOUBLE_TAP_WINDOW: float = 0.3
const MOVE_ACTIONS: Array[String] = ["move_up", "move_down", "move_left", "move_right"]
var _walk: bool = false
var _last_tap_action: String = ""
var _last_tap_time: float = -10.0
## Height of the plane used for mouse aiming (arena floor).
@export var aim_plane_height: float = 0.0


func poll_intent() -> GameplayIntent:
	if camera == null:
		camera = get_viewport().get_camera_3d()
	intent.clear_actions()
	intent.move_direction = _read_move_direction()
	var aim: Variant = _read_aim_point()
	if aim != null:
		intent.aim_point = aim
		intent.has_aim_point = true
	# If the cursor ray misses the plane we keep the previous aim point.
	for slot: StringName in SLOT_ACTIONS:
		if Input.is_action_just_pressed(SLOT_ACTIONS[slot]) and not _blocked(slot):
			intent.pressed_slots.append(slot)
	intent.held_slots.clear()
	if Input.is_action_pressed(SLOT_ACTIONS[&"lmb"]) and not _blocked(&"lmb"):
		intent.held_slots.append(&"lmb")
	intent.cancel_pressed = Input.is_action_just_pressed("ability_cancel")
	intent.guard_held = Input.is_action_pressed("guard")
	intent.concentrate_held = Input.is_action_pressed("concentrate")
	intent.jump_pressed = Input.is_action_just_pressed("jump")
	if Input.is_action_just_pressed("walk_toggle"):
		_walk = not _walk
	intent.walk = _walk
	# Chakra sprint: double tap of the same movement key (any direction).
	for action: String in MOVE_ACTIONS:
		if not Input.is_action_just_pressed(action):
			continue
		var now: float = Time.get_ticks_msec() / 1000.0
		if action == _last_tap_action and now - _last_tap_time <= DOUBLE_TAP_WINDOW:
			intent.sprint_pressed = true
			_last_tap_action = ""
		else:
			_last_tap_action = action
			_last_tap_time = now
	return intent


func _blocked(slot: StringName) -> bool:
	return is_instance_valid(ui_blocker) and ui_blocker.blocks_slot(slot)


func _read_move_direction() -> Vector3:
	var input: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var dir := Vector3(input.x, 0.0, input.y)
	if camera != null:
		# Rotate by camera yaw only, so "up" is always screen-up.
		dir = dir.rotated(Vector3.UP, camera.global_rotation.y)
	return dir.limit_length(1.0)


func _read_aim_point() -> Variant:
	if camera == null:
		return null
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var origin: Vector3 = camera.project_ray_origin(mouse)
	var normal: Vector3 = camera.project_ray_normal(mouse)
	return Plane(Vector3.UP, aim_plane_height).intersects_ray(origin, normal)
