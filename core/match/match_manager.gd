class_name MatchManager
extends Node
## Offline match vs bots (1v1 or 2v2). Rounds are won by eliminating the
## other team; first team to `rounds_to_win` takes the match. No respawn.

signal state_changed(state: State, message: String)
signal score_changed(scores: Array[int])

enum State { PRE_ROUND, FIGHTING, ROUND_OVER, MATCH_OVER }

const TEAM_NAMES: Array[String] = ["Konoha (you)", "Enemy"]

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

var player: CombatCharacter
var fighters: Array[CombatCharacter] = []
var state: State = State.PRE_ROUND
var scores: Array[int] = [0, 0]
var round_number: int = 0

var _timer: float = 0.0
var _spawns: Dictionary = {}  # CombatCharacter -> Marker3D


func _ready() -> void:
	assert(character_scene != null and characters_root != null, "MatchManager: missing scene refs.")
	var roster: Array[CharacterData] = GameSession.get_roster()
	player = _spawn(roster[GameSession.player_index], 0, PlayerInputController.new(), _spawn_marker(0, 0))
	for i in GameSession.ally_indices.size():
		_spawn(roster[GameSession.ally_indices[i]], 0, _make_bot(), _spawn_marker(0, i + 1))
	for i in GameSession.enemy_indices.size():
		_spawn(roster[GameSession.enemy_indices[i]], 1, _make_bot(), _spawn_marker(1, i))
	for fighter: CombatCharacter in fighters:
		var role := CharacterPresentation.Role.ALLY if fighter.team == player.team else CharacterPresentation.Role.ENEMY
		fighter.presentation.set_role(CharacterPresentation.Role.LOCAL_PLAYER if fighter == player else role)
	camera.target = player
	aim_indicator.character = player
	debug_overlay.character = player
	hud.bind(player, fighters, self)
	_start_round()


func _physics_process(delta: float) -> void:
	if _timer <= 0.0:
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
				_set_state(State.MATCH_OVER, "%s wins the match!\n[Enter] rematch   [Esc] menu" % TEAM_NAMES[winner])
			else:
				_start_round()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("match_restart") or (state == State.MATCH_OVER and event.is_action_pressed("ui_accept")):
		get_tree().reload_current_scene()
	elif event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(GameSession.MENU_SCENE)


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
	character.name = "%s_T%d_%d" % [data.display_name.replace(" ", ""), team, fighters.size()]
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
	if state != State.FIGHTING:
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
