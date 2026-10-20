extends Node
## Local probe (not committed): perf counters in the world or the 20v20 battle.

var _frames: int = 0
var _acc: Dictionary = {}

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0] == "battle":
		GameSession.mode = GameSession.Mode.BATTLE_20V20
		add_child((load(GameSession.ARENA_SCENE) as PackedScene).instantiate())
	else:
		add_child((load("res://world/world.tscn") as PackedScene).instantiate())

func _process(_d: float) -> void:
	_frames += 1
	if _frames < 200:
		return
	for k: String in ["dc", "obj", "prim", "fps"]:
		var v: float = 0.0
		match k:
			"dc": v = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			"obj": v = Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
			"prim": v = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
			"fps": v = Engine.get_frames_per_second()
		_acc[k] = _acc.get(k, 0.0) + v
	if _frames == 500:
		var line := "[perf]"
		for k: String in _acc:
			line += " %s=%d" % [k, int(_acc[k] / 300.0)]
		print(line)
		get_tree().quit()