extends Node
## Autoload (Net): ENet transport, dedicated-server lobby/queue and in-match
## replication. The server simulates everything; clients send inputs and
## mirror snapshots (their own movement is predicted, see CombatCharacter).
##
## Dedicated server:  godot --headless --path <game> -- --server --mode=1v1 --port=7777

signal status_changed(text: String)
signal connection_closed(reason: String)

enum Fx { RING, ARC, LOG }

const PORTS: Dictionary = {"1v1": 7777, "2v2": 7778}
const SNAPSHOT_INTERVAL_TICKS: int = 2
const RETURN_TO_LOBBY_DELAY: float = 6.0
## Lets players leave the queue before being thrown into the next match.
const REQUEUE_DELAY: float = 5.0
const SERVER_IDLE_SCENE: String = "res://multiplayer/server_idle.tscn"

var server_mode: String = ""
var status_text: String = ""

var _match: MatchManager
## Server: peer id -> {name:String, roster:int}. Insertion order = queue order.
var _peers: Dictionary = {}
var _match_peers: Array[int] = []
var _in_match: bool = false
var _tick: int = 0
var _next_entity_id: int = 1
## Client: net id -> visual-only Projectile / GroundArea.
var _entities: Dictionary = {}
## Dev/test autopilot: --autojoin=<host> --mode=<1v1|2v2> --bot-client --quit-after-match
var _autopilot: Dictionary = {}


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(func() -> void: _close("Connection failed."))
	multiplayer.server_disconnected.connect(func() -> void: _close("Disconnected from server."))
	var args: Dictionary = _parse_user_args()
	if args.has("server"):
		var mode: String = args.get("mode", "1v1")
		start_server(mode, int(args.get("port", PORTS.get(mode, 7777))))
	elif args.has("autojoin"):
		_autopilot = args
		var roster: int = int(args.get("roster", randi() % GameSession.ROSTER_PATHS.size()))
		join.call_deferred(args.autojoin, args.get("mode", "1v1"), "Bot%d" % (randi() % 1000), roster)


func is_server() -> bool:
	return GameSession.net_role == GameSession.NetRole.SERVER


func is_client() -> bool:
	return GameSession.net_role == GameSession.NetRole.CLIENT


func is_online() -> bool:
	return multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)


func game_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "dev"))


# --- Server -----------------------------------------------------------------

func start_server(mode: String, port: int) -> void:
	assert(PORTS.has(mode), "Unknown server mode: %s" % mode)
	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port, 16)
	if err != OK:
		push_error("Net: cannot listen on port %d (%s)" % [port, error_string(err)])
		get_tree().quit(1)
		return
	multiplayer.multiplayer_peer = peer
	GameSession.net_role = GameSession.NetRole.SERVER
	server_mode = mode
	Engine.max_fps = 60
	print("[server] %s v%s listening on UDP %d" % [mode, game_version(), port])
	get_tree().change_scene_to_file.call_deferred(SERVER_IDLE_SCENE)


func _players_needed() -> int:
	return 2 if server_mode == "1v1" else 4


func _on_peer_connected(peer_id: int) -> void:
	if is_server():
		print("[server] peer %d connected" % peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	if not is_server():
		return
	print("[server] peer %d left" % peer_id)
	_peers.erase(peer_id)
	if _in_match and _match_peers.has(peer_id):
		_match_peers.erase(peer_id)
		if _match_peers.is_empty():
			_end_match()
		elif _match != null:
			_match.replace_remote_with_bot(peer_id)
	_broadcast_lobby()


@rpc("any_peer", "call_remote", "reliable")
func c2s_hello(version: String, player_name: String, roster: int) -> void:
	if not is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if version != game_version():
		s2c_error.rpc_id(sender, "Version mismatch (server %s, you %s). Update with the launcher." % [game_version(), version])
		return
	_peers[sender] = {"name": player_name.left(16), "roster": clampi(roster, 0, GameSession.ROSTER_PATHS.size() - 1)}
	_broadcast_lobby()
	_try_start_match()


@rpc("any_peer", "call_remote", "reliable")
func c2s_set_roster(roster: int) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if is_server() and _peers.has(sender):
		_peers[sender].roster = clampi(roster, 0, GameSession.ROSTER_PATHS.size() - 1)


func _try_start_match() -> void:
	if _in_match or _peers.size() < _players_needed():
		return
	_match_peers.clear()
	var lineup: Array[Dictionary] = []
	for peer_id: int in _peers.keys().slice(0, _players_needed()):
		_match_peers.append(peer_id)
		lineup.append({"roster": _peers[peer_id].roster, "team": lineup.size() % 2, "control": "remote", "peer": peer_id})
	_in_match = true
	GameSession.lineup = lineup
	print("[server] match starting: %s" % [_match_peers])
	for i in _match_peers.size():
		s2c_start_match.rpc_id(_match_peers[i], lineup, i)
	get_tree().change_scene_to_file(GameSession.ARENA_SCENE)
	_broadcast_lobby()


func _end_match() -> void:
	if not _in_match:
		return
	_in_match = false
	_match = null
	for peer_id: int in _match_peers:
		if _peers.has(peer_id):
			s2c_return_to_lobby.rpc_id(peer_id)
	_match_peers.clear()
	get_tree().change_scene_to_file(SERVER_IDLE_SCENE)
	_broadcast_lobby()
	get_tree().create_timer(REQUEUE_DELAY).timeout.connect(_try_start_match)


func _broadcast_lobby() -> void:
	if not is_server():
		return
	var waiting: int = _peers.size() - (_match_peers.size() if _in_match else 0)
	var text: String = "%s server — %d connected, %s" % [server_mode, _peers.size(),
		"match in progress, %d waiting" % waiting if _in_match else "waiting for players %d/%d" % [_peers.size(), _players_needed()]]
	for peer_id: int in _peers:
		if not _match_peers.has(peer_id) or not _in_match:
			s2c_lobby.rpc_id(peer_id, text)


func register_match(match_manager: MatchManager) -> void:
	_match = match_manager
	_tick = 0
	if is_client() and _autopilot.has("bot-client"):
		var me: CombatCharacter = match_manager.player
		me.controller.queue_free()
		var bot := BotController.new()
		me.add_child(bot)
		me.controller = bot
		match_manager.state_changed.connect(func(_s: MatchManager.State, msg: String) -> void:
			print("[client %d] %s | hp=%s" % [multiplayer.get_unique_id(), msg.replace("\n", " "), match_manager.fighters.map(func(f: CombatCharacter) -> int: return ceili(f.health.current_health))]))
	if is_server():
		match_manager.match_finished.connect(func() -> void:
			get_tree().create_timer(RETURN_TO_LOBBY_DELAY).timeout.connect(_end_match))


func _physics_process(_delta: float) -> void:
	if not is_server() or _match == null or not _in_match:
		return
	_tick += 1
	if _tick % SNAPSHOT_INTERVAL_TICKS != 0:
		return
	var data := PackedFloat32Array()
	for fighter: CombatCharacter in _match.fighters:
		var source := fighter.controller as NetworkInputSource
		fighter.write_snapshot(data, source.last_seq if source != null else 0)
	for peer_id: int in _match_peers:
		s2c_snapshot.rpc_id(peer_id, _tick, data)


func broadcast_match_state(state: int, message: String, scores: Array[int]) -> void:
	if not is_server():
		return
	for peer_id: int in _match_peers:
		s2c_match_state.rpc_id(peer_id, state, message, scores)


## Server hook: a projectile / area was spawned by the simulation.
func on_entity_spawned(entity: Node3D, source: CombatCharacter, ability: AbilityData, a: Vector3, b: Vector3) -> int:
	if not is_server() or _match == null:
		return 0
	var id: int = _next_entity_id
	_next_entity_id += 1
	var fighter_index: int = _match.fighters.find(source)
	var slot_index: int = source.abilities.slot_index(source.abilities.slot_of(ability))
	var kind: int = 0 if entity is Projectile else 1
	for peer_id: int in _match_peers:
		s2c_spawn_entity.rpc_id(peer_id, id, kind, fighter_index, slot_index, a, b)
	return id


func on_entity_despawned(id: int) -> void:
	if not is_server() or id == 0:
		return
	for peer_id: int in _match_peers:
		s2c_despawn_entity.rpc_id(peer_id, id)


## Server hook: replicate a readability FX to clients.
func broadcast_fx(kind: Fx, a: Vector3, b: Vector3, f1: float, f2: float, color: Color) -> void:
	if not is_server():
		return
	for peer_id: int in _match_peers:
		s2c_fx.rpc_id(peer_id, kind, a, b, f1, f2, color)


# --- Client -----------------------------------------------------------------

func join(host: String, mode: String, player_name: String, roster: int) -> void:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var port: int = int(_autopilot.get("port", PORTS.get(mode, 7777)))
	var err: Error = peer.create_client(host, port)
	if err != OK:
		_set_status("Cannot connect: %s" % error_string(err))
		return
	multiplayer.multiplayer_peer = peer
	GameSession.net_role = GameSession.NetRole.CLIENT
	set_meta(&"hello", [player_name, roster])
	_set_status("Connecting to %s (%s)..." % [host, mode])


func leave() -> void:
	if is_online():
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	_entities.clear()
	_match = null
	if GameSession.net_role == GameSession.NetRole.CLIENT:
		GameSession.net_role = GameSession.NetRole.OFFLINE
		GameSession.lineup.clear()
	_set_status("")


func set_roster(roster: int) -> void:
	if is_client() and is_online():
		c2s_set_roster.rpc_id(1, roster)


func send_input(seq: int, intent: GameplayIntent, aim: Vector3) -> void:
	if not is_online():
		return
	c2s_input.rpc_id(1, seq, Vector2(intent.move_direction.x, intent.move_direction.z), Vector2(aim.x, aim.z))
	for slot: StringName in intent.pressed_slots:
		c2s_press.rpc_id(1, AbilityController.SLOTS.find(slot))
	if intent.cancel_pressed:
		c2s_cancel.rpc_id(1)


func _on_connected_to_server() -> void:
	var hello: Array = get_meta(&"hello", ["Shinobi", 0])
	c2s_hello.rpc_id(1, game_version(), hello[0], hello[1])
	_set_status("Connected. Waiting for players...")


func _close(reason: String) -> void:
	var was_in_match: bool = _match != null
	leave()
	_set_status(reason)
	connection_closed.emit(reason)
	if was_in_match:
		get_tree().change_scene_to_file(GameSession.MENU_SCENE)


@rpc("authority", "call_remote", "reliable")
func s2c_lobby(text: String) -> void:
	_set_status(text)


@rpc("authority", "call_remote", "reliable")
func s2c_error(text: String) -> void:
	_close(text)


@rpc("authority", "call_remote", "reliable")
func s2c_start_match(lineup: Array[Dictionary], my_index: int) -> void:
	GameSession.lineup = lineup
	GameSession.local_fighter = my_index
	GameSession.net_role = GameSession.NetRole.CLIENT
	_entities.clear()
	_set_status("Match found!")
	get_tree().change_scene_to_file(GameSession.ARENA_SCENE)


@rpc("authority", "call_remote", "reliable")
func s2c_return_to_lobby() -> void:
	if _autopilot.has("quit-after-match"):
		print("[client %d] match over, quitting" % multiplayer.get_unique_id())
		get_tree().quit()
		return
	_match = null
	_entities.clear()
	_set_status("Back in queue. Waiting for players...")
	get_tree().change_scene_to_file(GameSession.MENU_SCENE)


@rpc("authority", "call_remote", "unreliable_ordered")
func s2c_snapshot(_server_tick: int, data: PackedFloat32Array) -> void:
	if _match == null:
		return
	var stride: int = CombatCharacter.SNAPSHOT_STRIDE
	for i in mini(_match.fighters.size(), data.size() / stride):
		_match.fighters[i].apply_snapshot(data, i * stride)


@rpc("authority", "call_remote", "reliable")
func s2c_match_state(state: int, message: String, scores: Array[int]) -> void:
	if _match != null:
		_match.apply_remote_state(state as MatchManager.State, message, scores)


@rpc("authority", "call_remote", "reliable")
func s2c_spawn_entity(id: int, kind: int, fighter_index: int, slot_index: int, a: Vector3, b: Vector3) -> void:
	if _match == null or fighter_index < 0 or fighter_index >= _match.fighters.size():
		return
	var source: CombatCharacter = _match.fighters[fighter_index]
	var ability: AbilityData = source.abilities.get_ability(AbilityController.SLOTS[slot_index])
	if ability == null:
		return
	var entity: Node3D
	if kind == 0:
		entity = Projectile.spawn_visual(source, ability, a, b)
	else:
		entity = GroundArea.spawn_visual(source, ability, a)
	_entities[id] = entity


@rpc("authority", "call_remote", "reliable")
func s2c_despawn_entity(id: int) -> void:
	var entity: Variant = _entities.get(id)
	_entities.erase(id)
	if is_instance_valid(entity):
		(entity as Node).queue_free()


@rpc("authority", "call_remote", "unreliable")
func s2c_fx(kind: int, a: Vector3, b: Vector3, f1: float, f2: float, color: Color) -> void:
	if _match == null:
		return
	var anchor: Node = _match.fighters[0]  # FX are parented next to the fighters
	match kind:
		Fx.RING:
			CombatFx.ring(anchor, a, f1, color, f2)
		Fx.ARC:
			CombatFx.arc(anchor, a, b, f1, f2, color, 0.15)
		Fx.LOG:
			CombatFx.log_decoy(anchor, a)


# --- In-match input relay (client -> server) -------------------------------

@rpc("any_peer", "call_remote", "unreliable_ordered")
func c2s_input(seq: int, move: Vector2, aim: Vector2) -> void:
	var source: NetworkInputSource = _input_source_for_sender()
	if source != null:
		source.receive_input(seq, move, aim)


@rpc("any_peer", "call_remote", "reliable")
func c2s_press(slot_index: int) -> void:
	var source: NetworkInputSource = _input_source_for_sender()
	if source != null:
		source.receive_press(slot_index)


@rpc("any_peer", "call_remote", "reliable")
func c2s_cancel() -> void:
	var source: NetworkInputSource = _input_source_for_sender()
	if source != null:
		source.receive_cancel()


func _input_source_for_sender() -> NetworkInputSource:
	if not is_server() or _match == null:
		return null
	return _match.remote_inputs.get(multiplayer.get_remote_sender_id())


func _set_status(text: String) -> void:
	status_text = text
	status_changed.emit(text)


func _parse_user_args() -> Dictionary:
	var out: Dictionary = {}
	for arg: String in OS.get_cmdline_user_args():
		var clean: String = arg.trim_prefix("--")
		var parts: PackedStringArray = clean.split("=", true, 1)
		out[parts[0]] = parts[1] if parts.size() > 1 else "true"
	return out
