extends Node
## Headless 20v20 battle: bots fight, die, respawn and spend tickets.
##   godot --headless --fixed-fps 60 res://tests/battle_test.tscn

const FRAMES: int = 60 * 90

var _manager: MatchManager
var _frames: int = 0
var _kills: int = 0
var _start_msec: int = 0


func _ready() -> void:
	GameSession.mode = GameSession.Mode.BATTLE_20V20
	GameSession.player_index = 0
	GameSession.prepare_lineup(-1)
	var arena: Node = (load(GameSession.ARENA_SCENE) as PackedScene).instantiate()
	add_child(arena)
	_manager = arena.get_node("MatchManager") as MatchManager
	var player: CombatCharacter = _manager.player
	player.controller.queue_free()
	var bot := BotController.new()
	player.add_child(bot)
	player.controller = bot
	_manager.kill_feed.connect(func(_k: CombatCharacter, _v: CombatCharacter) -> void: _kills += 1)
	_start_msec = Time.get_ticks_msec()


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames < FRAMES and _manager.state != MatchManager.State.MATCH_OVER:
		return
	var ok: bool = _manager.fighters.size() == 40 and _kills > 5 and _manager.tickets[0] + _manager.tickets[1] < 120
	print("[battle] fighters=%d kills=%d tickets=%s state=%d sim=%.0fs real=%.1fs" % [_manager.fighters.size(), _kills,
		_manager.tickets, _manager.state, _frames / 60.0, (Time.get_ticks_msec() - _start_msec) / 1000.0])
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
