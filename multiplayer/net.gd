extends Node
## Autoload (Net): ENet transport, dedicated-server lobby/queue and in-match
## replication. The server simulates everything; clients send inputs and
## mirror snapshots (their own movement is predicted, see CombatCharacter).
##
## Dedicated server:  godot --headless --path <game> -- --server --mode=1v1 --port=7777

signal status_changed(text: String)
signal connection_closed(reason: String)
## Client: friend code -> "lobby" / "party" / "match" for friends on this server.
signal friends_status(status: Dictionary)
## Client: someone invites us to their party.
signal invite_received(from_name: String, party: String)

enum Fx { RING, ARC, LOG }

const PORTS: Dictionary = {"1v1": 7777, "2v2": 7778}
const SNAPSHOT_INTERVAL_TICKS: int = 2
const RETURN_TO_LOBBY_DELAY: float = 6.0
## Lets players leave the queue before being thrown into the next match.
const REQUEUE_DELAY: float = 5.0
## 2v2: a party that can't be completed with queued players gets bots after this.
const PARTY_FILL_WAIT: float = 12.0
const SERVER_IDLE_SCENE: String = "res://multiplayer/server_idle.tscn"

var server_mode: String = ""
var status_text: String = ""

var _match: MatchManager
## Client: private party joined ("" = public queue).
var party: String = ""
## Server: party code -> time (s) it got its second member.
var _party_since: Dictionary = {}
var _match_timer: float = 0.0
## Server: peer id -> {name, roster, code, party}. Insertion order = queue order.
var _peers: Dictionary = {}
var _match_peers: Array[int] = []
var _in_match: bool = false
var _tick: int = 0
var _next_entity_id: int = 1
## Client: net id -> visual-only Projectile / GroundArea.
var _entities: Dictionary = {}
## Dev/test autopilot: --autojoin=<host> --mode=<1v1|2v2> --bot-client --quit-after-match
var _autopilot: Dictionary = {}
var _accounts := AccountStore.new()


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
		GameSession.friend_code = str(args.get("code", GameSession._new_code()))
		join.call_deferred(args.autojoin, args.get("mode", "1v1"), "Bot%d" % (randi() % 1000), roster, str(args.get("party", "")))


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
	if mode == "2v2":
		_start_account_service(port)
		return
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


## The second server instance (UDP 7778) is the launcher's account service.
func _start_account_service(port: int) -> void:
	GameSession.net_role = GameSession.NetRole.SERVER
	server_mode = "accounts"
	Engine.max_fps = 30
	var service := AccountService.new()
	add_child(service)
	if service.start(port) != OK:
		push_error("Net: account service cannot listen on %d" % port)
		get_tree().quit(1)
		return
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
func c2s_hello(version: String, player_name: String, roster: int, code: String, party_code: String, token: String, queue: bool,
		user: String = "", auth: String = "") -> void:
	if not is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if version != game_version():
		s2c_error.rpc_id(sender, "Version mismatch (server %s, you %s). Update with the launcher." % [game_version(), version])
		return
	if user == "" or not _accounts.verify(user, auth):
		s2c_error.rpc_id(sender, "Compte inconnu ou mot de passe incorrect : connecte-toi depuis le launcher.")
		return
	user = AccountStore.normalize(user)
	# First login of an account: adopt the character of the old per-machine token.
	var legacy: String = "acc_" + token.sha256_text().left(20)
	if _accounts.characters(user).is_empty() and Profiles.server_load(legacy) != null:
		_accounts.add_character(user, legacy)
	_peers[sender] = {"name": player_name.left(16), "roster": clampi(roster, 0, GameSession.ROSTER_PATHS.size() - 1),
		"code": code.left(8).to_upper(), "party": party_code.left(8).to_upper(),
		"user": user, "account": "", "queue": queue}
	s2c_characters.rpc_id(sender, _character_summaries(user))
	_broadcast_lobby()
	_try_start_match()


@rpc("any_peer", "call_remote", "reliable")
func c2s_set_roster(roster: int) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if is_server() and _peers.has(sender):
		_peers[sender].roster = clampi(roster, 0, GameSession.ROSTER_PATHS.size() - 1)


func _try_start_match() -> void:
	if _in_match:
		return
	var lineup: Array[Dictionary] = _build_lineup()
	if lineup.is_empty():
		return
	_match_peers.clear()
	for entry: Dictionary in lineup:
		if entry.control == "remote":
			_match_peers.append(entry.peer)
			_party_since.erase(_peers[entry.peer].party)
	_in_match = true
	GameSession.lineup = lineup
	print("[server] match starting: %s" % [lineup.map(func(e: Dictionary) -> String: return "%s:%d" % [e.control, e.peer])])
	for i in lineup.size():
		if lineup[i].control == "remote":
			s2c_start_match.rpc_id(lineup[i].peer, lineup, i)
	get_tree().change_scene_to_file(GameSession.ARENA_SCENE)
	_broadcast_lobby()


## Parties (friends) first, then the public queue. Empty = no match yet.
func _build_lineup() -> Array[Dictionary]:
	var needed: int = _players_needed()
	var parties: Dictionary = {}  # party -> Array[int]
	var singles: Array[int] = []
	for peer_id: int in _peers:
		if not _peers[peer_id].get("queue", true):
			continue  # profile-only connection (shinobi screen), not looking for a match
		var p: String = _peers[peer_id].party
		if p == "":
			singles.append(peer_id)
		else:
			if not parties.has(p):
				var members: Array[int] = []
				parties[p] = members
			(parties[p] as Array[int]).append(peer_id)
	var now: float = Time.get_ticks_msec() / 1000.0
	for p: String in parties:
		var members: Array[int] = parties[p]
		if members.size() < 2:
			_party_since.erase(p)
			continue
		if not _party_since.has(p):
			_party_since[p] = now
		members = members.slice(0, needed)
		if needed == 2:
			return _lineup_from(members, [0, 1])
		if members.size() == 4:
			return _lineup_from(members, [0, 1, 0, 1])  # friends vs friends
		# 2-3 friends: same team (the 3rd plays against them), fill with
		# queued players, or bots once the wait is over.
		var teams: Array[int] = [0, 0]
		if members.size() == 3:
			teams.append(1)
		var fill: Array[int] = singles.slice(0, needed - members.size())
		if fill.size() < needed - members.size() and now - float(_party_since[p]) < PARTY_FILL_WAIT:
			continue
		var lineup: Array[Dictionary] = _lineup_from(members, teams)
		var counts: Array[int] = [teams.count(0), teams.count(1)]
		for i in needed - members.size():
			var team: int = 0 if counts[0] < 2 else 1
			counts[team] += 1
			if i < fill.size():
				lineup.append({"roster": _peers[fill[i]].roster, "team": team, "control": "remote", "peer": fill[i]})
			else:
				lineup.append({"roster": randi() % GameSession.ROSTER_PATHS.size(), "team": team, "control": "bot", "peer": 0})
		return lineup
	if singles.size() >= needed:
		var teams: Array[int] = []
		for i in needed:
			teams.append(i % 2)
		return _lineup_from(singles.slice(0, needed), teams)
	return []


func _lineup_from(peer_ids: Array[int], teams: Array[int]) -> Array[Dictionary]:
	var lineup: Array[Dictionary] = []
	for i in peer_ids.size():
		lineup.append({"roster": _peers[peer_ids[i]].roster, "team": teams[i], "control": "remote", "peer": peer_ids[i]})
	return lineup


func _process(delta: float) -> void:
	if not is_server() or _in_match:
		return
	_match_timer -= delta
	if _match_timer <= 0.0:
		_match_timer = 1.0
		_try_start_match()  # parties waiting for bot fill


# --- Friends & parties ------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func c2s_set_party(party_code: String) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if is_server() and _peers.has(sender):
		_peers[sender].party = party_code.left(8).to_upper()
		_broadcast_lobby()
		_try_start_match()


@rpc("any_peer", "call_remote", "reliable")
func c2s_invite(code: String) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if not is_server() or not _peers.has(sender):
		return
	var target: int = _peer_by_code(code.to_upper())
	if target == 0 or target == sender:
		return
	var me: Dictionary = _peers[sender]
	if me.party == "":
		me.party = me.code  # inviting opens your party
		_broadcast_lobby()
	s2c_invite.rpc_id(target, me.name, me.party)


@rpc("any_peer", "call_remote", "reliable")
func c2s_query_friends(codes: PackedStringArray) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if not is_server() or not _peers.has(sender):
		return
	var status: Dictionary = {}
	for code: String in codes.slice(0, 50):
		var peer_id: int = _peer_by_code(code.to_upper())
		if peer_id == 0:
			continue
		var state: String = "lobby"
		if _in_match and _match_peers.has(peer_id):
			state = "match"
		elif _peers[peer_id].party != "":
			state = "party"
		status[code] = {"state": state, "name": _peers[peer_id].name}
	s2c_friends_status.rpc_id(sender, status)


func _peer_by_code(code: String) -> int:
	for peer_id: int in _peers:
		if _peers[peer_id].code == code:
			return peer_id
	return 0


# --- Shinobi profiles (server authority) -------------------------------------

func profile_create(character_name: String, village_id: StringName, origin: int, clan_id: StringName) -> void:
	if is_client() and is_online():
		c2s_profile_create.rpc_id(1, character_name, village_id, origin, clan_id)


func profile_request(action: Dictionary) -> void:
	if is_client() and is_online():
		c2s_profile_request.rpc_id(1, action)


@rpc("any_peer", "call_remote", "reliable")
func c2s_profile_get() -> void:
	var account: String = _account_of_sender()
	if account != "":
		_send_profile(multiplayer.get_remote_sender_id(), Profiles.server_load(account), ProgressionResult.success())
	else:
		c2s_characters()


@rpc("any_peer", "call_remote", "reliable")
func c2s_profile_create(character_name: String, village_id: StringName, origin: int, clan_id: StringName) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	var user: String = str(_peers.get(sender, {}).get("user", ""))
	if user == "":
		return
	if _accounts.characters(user).size() >= AccountStore.MAX_CHARACTERS:
		_send_profile(sender, null, ProgressionResult.fail(&"TOO_MANY_CHARACTERS"))
		return
	var id: String = "c_" + Crypto.new().generate_random_bytes(8).hex_encode()
	var created: Dictionary = Profiles.server_create(id, character_name, village_id, origin, clan_id)
	if (created.result as ProgressionResult).ok:
		_accounts.add_character(user, id)
		_peers[sender].account = id
	_send_profile(sender, created.profile, created.result)
	s2c_characters.rpc_id(sender, _character_summaries(user))


## Account characters: list, select (the profile then follows), delete.
@rpc("any_peer", "call_remote", "reliable")
func c2s_characters() -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	var user: String = str(_peers.get(sender, {}).get("user", ""))
	if user != "":
		s2c_characters.rpc_id(sender, _character_summaries(user))


@rpc("any_peer", "call_remote", "reliable")
func c2s_select_character(character_id: String) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	var user: String = str(_peers.get(sender, {}).get("user", ""))
	if user == "" or not _accounts.characters(user).has(character_id):
		return
	_peers[sender].account = character_id
	_send_profile(sender, Profiles.server_load(character_id), ProgressionResult.success())


@rpc("any_peer", "call_remote", "reliable")
func c2s_delete_character(character_id: String) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	var user: String = str(_peers.get(sender, {}).get("user", ""))
	if user == "" or not _accounts.remove_character(user, character_id):
		return
	Profiles.server_delete(character_id)
	if _peers[sender].account == character_id:
		_peers[sender].account = ""
		_send_profile(sender, null, ProgressionResult.success())
	s2c_characters.rpc_id(sender, _character_summaries(user))


@rpc("authority", "call_remote", "reliable")
func s2c_characters(list: Array) -> void:
	Profiles.apply_characters(list)


func _character_summaries(user: String) -> Array:
	var out: Array = []
	for id: String in _accounts.characters(user):
		var p: CharacterProfile = Profiles.server_load(id)
		if p != null:
			out.append(Profiles.summary(p))
	return out


func select_character(character_id: String) -> void:
	if is_client() and is_online():
		c2s_select_character.rpc_id(1, character_id)


func delete_character(character_id: String) -> void:
	if is_client() and is_online():
		c2s_delete_character.rpc_id(1, character_id)


@rpc("any_peer", "call_remote", "reliable")
func c2s_profile_request(action: Dictionary) -> void:
	var account: String = _account_of_sender()
	if account == "":
		return
	var handled: Dictionary = Profiles.server_request(account, action)
	_send_profile(multiplayer.get_remote_sender_id(), handled.profile, handled.result)


@rpc("authority", "call_remote", "reliable")
func s2c_profile(profile_data: Dictionary, ok: bool, error: String, events: Array) -> void:
	Profiles.apply_remote(profile_data, ok, error, events)


func _send_profile(peer_id: int, profile: CharacterProfile, result: ProgressionResult) -> void:
	s2c_profile.rpc_id(peer_id, profile.to_dict() if profile != null else {}, result.ok, String(result.error), result.events)


func _account_of_sender() -> String:
	if not is_server():
		return ""
	return str(_peers.get(multiplayer.get_remote_sender_id(), {}).get("account", ""))


@rpc("authority", "call_remote", "reliable")
func s2c_invite(from_name: String, party_code: String) -> void:
	invite_received.emit(from_name, party_code)


@rpc("authority", "call_remote", "reliable")
func s2c_friends_status(status: Dictionary) -> void:
	friends_status.emit(status)


## Client: joins / leaves (party = "") a private party on the current server.
func set_party(party_code: String) -> void:
	party = party_code
	if is_client() and is_online():
		c2s_set_party.rpc_id(1, party_code)


func invite(code: String) -> void:
	if is_client() and is_online():
		c2s_invite.rpc_id(1, code)


func query_friends(codes: PackedStringArray) -> void:
	if is_client() and is_online() and multiplayer.get_unique_id() != 1:
		c2s_query_friends.rpc_id(1, codes)


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
	var base: String = "%s server — %d connected, %s" % [server_mode, _peers.size(),
		"match in progress, %d waiting" % waiting if _in_match else "waiting for players %d/%d" % [_peers.size(), _players_needed()]]
	for peer_id: int in _peers:
		if _match_peers.has(peer_id) and _in_match:
			continue
		var text: String = base
		var p: String = _peers[peer_id].party
		if p != "":
			var names: PackedStringArray = []
			for other: int in _peers:
				if _peers[other].party == p:
					names.append(_peers[other].name)
			text = "%s server — private party [%s]: %s" % [server_mode, p, ", ".join(names)]
			if names.size() < 2:
				text += " — invite a friend"
		s2c_lobby.rpc_id(peer_id, text)


func fighter_index(c: CombatCharacter) -> int:
	return _match.fighters.find(c) if _match != null and c != null else -1


func fighter_at(index: int) -> CombatCharacter:
	if _match == null or index < 0 or index >= _match.fighters.size():
		return null
	return _match.fighters[index]


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
	_match.rules.write_header(data)
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
	if slot_index < 0:
		# Not a slot ability: a projectile's expire zone (encoded slot + 10).
		for i in AbilityController.SLOTS.size():
			var base: AbilityData = source.abilities.get_ability(AbilityController.SLOTS[i])
			if base != null and base.expire_zone == ability:
				slot_index = i + 10
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

func join(host: String, mode: String, player_name: String, roster: int, party_code: String = "", queue: bool = true) -> void:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var port: int = int(_autopilot.get("port", PORTS.get(mode, 7777)))
	var err: Error = peer.create_client(host, port)
	if err != OK:
		_set_status("Cannot connect: %s" % error_string(err))
		return
	multiplayer.multiplayer_peer = peer
	GameSession.net_role = GameSession.NetRole.CLIENT
	set_meta(&"hello", [player_name, roster, queue])
	party = party_code
	_set_status("Connecting to %s (%s)..." % [host, mode])


func leave() -> void:
	if is_client() and Profiles.is_remote():
		Profiles.use_remote(false)
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
	var held_mask: int = 0
	for slot: StringName in intent.held_slots:
		held_mask |= 1 << AbilityController.SLOTS.find(slot)
	if intent.guard_held:
		held_mask |= NetworkInputSource.GUARD_BIT
	if intent.concentrate_held:
		held_mask |= NetworkInputSource.CONCENTRATE_BIT
	if intent.jump_pressed:
		held_mask |= NetworkInputSource.JUMP_BIT
	c2s_input.rpc_id(1, seq, Vector2(intent.move_direction.x, intent.move_direction.z), Vector2(aim.x, aim.z), held_mask)
	for slot: StringName in intent.pressed_slots:
		c2s_press.rpc_id(1, AbilityController.SLOTS.find(slot))
	if intent.cancel_pressed:
		c2s_cancel.rpc_id(1)


func _on_connected_to_server() -> void:
	var hello: Array = get_meta(&"hello", ["Shinobi", 0])
	c2s_hello.rpc_id(1, game_version(), hello[0], hello[1], GameSession.friend_code, party, GameSession.account_token,
		bool(hello[2]) if hello.size() > 2 else true, GameSession.account_user, GameSession.account_auth)
	Profiles.use_remote(true)
	if GameSession.last_character != "":
		c2s_select_character.rpc_id(1, GameSession.last_character)
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
	var stride: int = CombatCharacter.snapshot_stride()
	var header: int = ArenaRules.HEADER_SIZE
	if data.size() < header:
		return
	_match.rules.apply_header(data)
	for i in mini(_match.fighters.size(), (data.size() - header) / stride):
		_match.fighters[i].apply_snapshot(data, header + i * stride)


@rpc("authority", "call_remote", "reliable")
func s2c_match_state(state: int, message: String, scores: Array[int]) -> void:
	if _match != null:
		_match.apply_remote_state(state as MatchManager.State, message, scores)


@rpc("authority", "call_remote", "reliable")
func s2c_spawn_entity(id: int, kind: int, fighter_index: int, slot_index: int, a: Vector3, b: Vector3) -> void:
	if _match == null or fighter_index < 0 or fighter_index >= _match.fighters.size():
		return
	var source: CombatCharacter = _match.fighters[fighter_index]
	var ability: AbilityData
	if slot_index >= 10:
		var base: AbilityData = source.abilities.get_ability(AbilityController.SLOTS[slot_index - 10])
		ability = base.expire_zone if base != null else null
	elif slot_index >= 0:
		ability = source.abilities.get_ability(AbilityController.SLOTS[slot_index])
	if ability == null:
		return
	var entity: Node3D
	if kind == 0:
		entity = Projectile.spawn_visual(source, ability, a, b)
	else:
		entity = GroundArea.spawn_visual(source, ability, a, b)
	_entities[id] = entity


@rpc("authority", "call_remote", "reliable")
func s2c_despawn_entity(id: int) -> void:
	var entity: Variant = _entities.get(id)
	_entities.erase(id)
	if is_instance_valid(entity):
		if entity is Projectile:
			(entity as Projectile).impact()
		else:
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
func c2s_input(seq: int, move: Vector2, aim: Vector2, held_mask: int) -> void:
	var source: NetworkInputSource = _input_source_for_sender()
	if source != null:
		source.receive_input(seq, move, aim, held_mask)


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
