class_name MatchManager
extends Node
## Runs a match from GameSession.lineup (1v1 / 2v2). Rounds are won by
## eliminating the other team; first to `rounds_to_win`. No respawn.
## Offline and on the server it is authoritative; on a client it only mirrors
## the state received through Net.

signal state_changed(state: State, message: String)
signal score_changed(scores: Array[int])
signal match_finished

enum State { PRE_ROUND, FIGHTING, ROUND_OVER, MATCH_OVER }

const TEAM_NAMES: Array[String] = ["Team Konoha", "Team Akatsuki"]

@export var character_scene: PackedScene
@export var characters_root: Node3D
## Holds Marker3D children named "Team<team>_<slot>".
@export var spawns_root: Node3D
@export var camera: ArenaCamera
@export var aim_indicator: AimIndicator
@export var debug_overlay: DebugOverlay
@export var hud: MatchHud
@export var pre_round_time: float = 1.5
@export var round_over_time: float = 2.0

## The fighter controlled on this machine (null on a dedicated server).
var player: CombatCharacter
var fighters: Array[CombatCharacter] = []
var state: State = State.PRE_ROUND
var scores: Array[int] = [0, 0]
var round_number: int = 0
## Server: peer id -> NetworkInputSource.
var remote_inputs: Dictionary = {}

var _timer: float = 0.0
var _spawns: Dictionary = {}  # CombatCharacter -> Marker3D


func _ready() -> void:
	assert(character_scene != null and characters_root != null, "MatchManager: missing scene refs.")
	if GameSession.net_role == GameSession.NetRole.OFFLINE and GameSession.lineup.is_empty():
		GameSession.build_offline_lineup()
	var roster: Array[CharacterData] = GameSession.get_roster()
	var team_slots: Array[int] = [0, 0]
	for i in GameSession.lineup.size():
		var entry: Dictionary = GameSession.lineup[i]
		var team: int = entry.team
		var fighter := _spawn(roster[entry.roster], team, _make_controller(i, entry), _spawn_marker(team, team_slots[team]))
		team_slots[team] += 1
		if GameSession.net_role == GameSession.NetRole.CLIENT:
			fighter.net_mode = CombatCharacter.NetMode.PREDICTED if i == GameSession.local_fighter else CombatCharacter.NetMode.PUPPET
	if GameSession.net_role != GameSession.NetRole.SERVER:
		player = fighters[GameSession.local_fighter]
		for fighter: CombatCharacter in fighters:
			var role := CharacterPresentation.Role.ALLY if fighter.team == player.team else CharacterPresentation.Role.ENEMY
			fighter.presentation.set_role(CharacterPresentation.Role.LOCAL_PLAYER if fighter == player else role)
		camera.target = player
		aim_indicator.character = player
		debug_overlay.character = player
		hud.bind(player, fighters, self)
	Net.register_match(self)
	if is_authoritative():
		_start_round()


func is_authoritative() -> bool:
	return GameSession.net_role != GameSession.NetRole.CLIENT


func _physics_process(delta: float) -> void:
	if not is_authoritative() or _timer <= 0.0:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	match state:
		State.PRE_ROUND:
			_set_controls(true)
			_set_state(State.FIGHTING, "FIGHT!")
		State.ROUND_OVER:
			if scores.max() >= GameSession.rounds_to_win:
				var winner: int = 0 if scores[0] > scores[1] else 1
				var hint: String = "[Enter] rematch   [Esc] menu" if GameSession.net_role == GameSession.NetRole.OFFLINE else "Back to lobby soon..."
				_set_state(State.MATCH_OVER, "%s wins the match!\n%s" % [TEAM_NAMES[winner], hint])
				match_finished.emit()
			else:
				_start_round()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Net.leave()
		get_tree().change_scene_to_file(GameSession.MENU_SCENE)
	elif GameSession.net_role != GameSession.NetRole.OFFLINE:
		return
	elif event.is_action_pressed("match_restart") or (state == State.MATCH_OVER and event.is_action_pressed("ui_accept")):
		get_tree().reload_current_scene()


## Client: mirror of the authoritative match state.
func apply_remote_state(new_state: State, message: String, new_scores: Array[int]) -> void:
	if new_state == State.PRE_ROUND:
		for node: Node in get_tree().get_nodes_in_group(&"round_entities"):
			node.queue_free()
	scores = new_scores
	score_changed.emit(scores)
	_set_controls(new_state == State.FIGHTING)
	_set_state(new_state, message)


## Server: a client left mid-match, a bot takes over its fighter.
func replace_remote_with_bot(peer_id: int) -> void:
	var source: NetworkInputSource = remote_inputs.get(peer_id)
	if source == null:
		return
	remote_inputs.erase(peer_id)
	var fighter := source.get_parent() as CombatCharacter
	var bot := _make_bot()
	source.queue_free()
	fighter.add_child(bot)
	fighter.controller = bot


func _make_controller(index: int, entry: Dictionary) -> IntentSource:
	match entry.control:
		"local":
			return PlayerInputController.new() if index == GameSession.local_fighter else null
		"remote":
			if GameSession.net_role == GameSession.NetRole.SERVER:
				var source := NetworkInputSource.new()
				source.peer_id = entry.peer
				remote_inputs[source.peer_id] = source
				return source
			return PlayerInputController.new() if index == GameSession.local_fighter else null
	return _make_bot() if is_authoritative() else null


func _spawn_marker(team: int, slot: int) -> Marker3D:
	return spawns_root.get_node_or_null("Team%d_%d" % [team, slot]) as Marker3D


func _make_bot() -> BotController:
	var bot := BotController.new()
	bot.passive = GameSession.bot_passive
	return bot


func _spawn(data: CharacterData, team: int, controller: IntentSource, spawn: Marker3D) -> CombatCharacter:
	assert(spawn != null, "MatchManager: missing spawn marker for team %d." % team)
	var character := character_scene.instantiate() as CombatCharacter
	character.data = data
	character.team = team
	character.name = "Fighter%d" % fighters.size()
	if controller != null:
		controller.name = "Controller"
		character.add_child(controller)
		character.controller = controller
	character.transform = spawn.global_transform
	characters_root.add_child(character)
	character.died.connect(_on_character_died)
	fighters.append(character)
	_spawns[character] = spawn
	return character


func _start_round() -> void:
	round_number += 1
	for node: Node in get_tree().get_nodes_in_group(&"round_entities"):
		node.queue_free()
	for fighter: CombatCharacter in fighters:
		fighter.reset_for_round((_spawns[fighter] as Marker3D).global_transform)
	_set_controls(false)
	_timer = pre_round_time
	_set_state(State.PRE_ROUND, "Round %d" % round_number)


func _on_character_died(_character: CombatCharacter) -> void:
	if state != State.FIGHTING or not is_authoritative():
		return
	var alive: Array[int] = [0, 0]
	for fighter: CombatCharacter in fighters:
		if not fighter.is_dead():
			alive[fighter.team] += 1
	if alive[0] > 0 and alive[1] > 0:
		return
	var winner: int = 0 if alive[0] > 0 else 1
	scores[winner] += 1
	score_changed.emit(scores)
	_set_controls(false)
	_timer = round_over_time
	_set_state(State.ROUND_OVER, "%s takes the round" % TEAM_NAMES[winner])


func _set_controls(enabled: bool) -> void:
	for fighter: CombatCharacter in fighters:
		fighter.controls_enabled = enabled


func _set_state(new_state: State, message: String) -> void:
	state = new_state
	state_changed.emit(state, message)
	Net.broadcast_match_state(state, message, scores)
