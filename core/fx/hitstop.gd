class_name Hitstop
## Whole-game freeze for a few frames on impacts involving the local player
## (Battlerite-style "weight"). Presentation only: offline it pauses the
## simulation, online the client just freezes its view for a moment.

static var _until_msec: int = 0


static func trigger(duration: float) -> void:
	if not CombatFx.is_enabled() or Net.is_server():
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var end: int = Time.get_ticks_msec() + int(duration * 1000.0)
	if end <= _until_msec:
		return
	_until_msec = end
	Engine.time_scale = 0.03
	tree.create_timer(duration, true, false, true).timeout.connect(_release)


static func _release() -> void:
	if Time.get_ticks_msec() + 5 >= _until_msec:
		Engine.time_scale = 1.0
