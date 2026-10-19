extends Node
## Every character fights a bot match (2v2 rotations) to catch kit errors.
##   godot --headless --fixed-fps 60 --path . res://tests/roster_test.tscn

const LINEUPS: Array = [[0, 4, 5, 6], [1, 7, 8, 9], [2, 5, 9, 3], [6, 8, 4, 1]]
const MAX_FRAMES: int = 60 * 50

var _index: int = -1
var _frames: int = 0
var _arena: Node
var _manager: MatchManager
var _casts: Dictionary = {}


func _ready() -> void:
	_next()


func _next() -> void:
	if _arena != null:
		_arena.queue_free()
	_index += 1
	if _index >= LINEUPS.size():
		_report()
		return
	var l: Array = LINEUPS[_index]
	GameSession.mode = GameSession.Mode.TEAM_2V2_VS_BOTS
	GameSession.player_index = l[0]
	GameSession.ally_indices = [l[1]]
	GameSession.enemy_indices = [l[2], l[3]]
	GameSession.build_offline_lineup()
	_arena = (load(GameSession.ARENA_SCENE) as PackedScene).instantiate()
	add_child(_arena)
	_manager = _arena.get_node("MatchManager") as MatchManager
	var bot := BotController.new()
	_manager.player.controller.queue_free()
	_manager.player.add_child(bot)
	_manager.player.controller = bot
	for f: CombatCharacter in _manager.fighters:
		f.energy.infinite_debug = true
		var key: String = f.data.display_name
		f.abilities.cast_activated.connect(func(slot: StringName, _a: AbilityData) -> void:
			_casts[key + ":" + slot] = _casts.get(key + ":" + slot, 0) + 1)
	_frames = 0


func _physics_process(_delta: float) -> void:
	if _manager == null:
		return
	_frames += 1
	if _frames >= MAX_FRAMES or _manager.state == MatchManager.State.MATCH_OVER:
		_manager = null
		_next.call_deferred()


func _report() -> void:
	var names: Dictionary = {}
	for k: String in _casts:
		names[k.get_slice(":", 0)] = true
	for n: String in names:
		var parts: PackedStringArray = []
		for slot: String in ["lmb", "rmb", "space", "q", "e", "ult"]:
			parts.append("%s=%d" % [slot, _casts.get(n + ":" + slot, 0)])
		print("[roster] %-18s %s" % [n, " ".join(parts)])
	print("ROSTER DONE (%d characters played)" % names.size())
	get_tree().quit()
