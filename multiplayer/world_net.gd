class_name WorldNet
extends Node
## Shared open world online (persistent server, 10 players max).
##
## Owner-authoritative: each client simulates its own shinobi and sends its
## state; the server simulates the mobs and relays everything. Other players
## and the mobs are PUPPETs on a client: they follow the received states and
## replay casts for the visuals only (a puppet's hits are ignored). A hit
## landing on a puppet is forwarded to the machine that owns the target
## (CombatCharacter.receive_hit -> forward_hit), which runs it through its own
## pipeline (guard, parry, substitution...). The server grants the XP.
##
## PvP is open everywhere outside the villages, between any players (same
## village too), except members of the same party (shared team).
##
## Lives at /root/Net/World on every machine (RPC path).

signal players_changed
signal party_changed
signal invited(from_peer: int, from_name: String)
signal notice(text: String)

const MAX_PLAYERS: int = 10
const PARTY_MAX: int = 4
const STATE_INTERVAL: float = 1.0 / 15.0
const MOB_INTERVAL: float = 0.1
## Mobs farther than this from a player are not sent to it.
const INTEREST: float = 90.0
## Party members this close to a kill share its XP.
const XP_SHARE_RANGE: float = 45.0
const MOB_TEAM: int = 1
const PLAYER_TEAM_BASE: int = 1000
## Client: a mob without news for this long is hidden.
const MOB_STALE: float = 1.0

## True while an online open world runs on this machine (client or server).
static var active: bool = false
static var instance: WorldNet

var world: World
## Client: this machine's team (unique, or the party's).
var my_team: int = PLAYER_TEAM_BASE
## Client: peer -> {"name", "team", "puppet"} of the other players in the world.
var players: Dictionary = {}
## Client: party members (peer ids, me included) and the leader.
var party: Array[int] = []

# Server
var _members: Dictionary = {}  # peer -> {"name", "puppet", "party": leader peer or 0}
var _send_left: float = 0.0
var _mob_left: float = 0.0
var _gone: int = 0  # server: peer being removed (no RPC to it)
var _mob_seen: Dictionary = {}  # client: mob id -> seconds since last state


func _ready() -> void:
	instance = self


static func me() -> int:
	return instance.multiplayer.get_unique_id() if instance != null and instance.multiplayer.has_multiplayer_peer() else 0


func is_party_member(peer: int) -> bool:
	return party.has(peer)


# --- Both sides -----------------------------------------------------------------

## The world scene is ready: client joins the shared world, server starts it.
func attach(w: World) -> void:
	world = w
	active = true
	players.clear()
	party.clear()
	_mob_seen.clear()
	for i in world.mobs.size():
		_watch_mob(i)
	if Net.is_client():
		c2s_enter.rpc_id(1)
		world.player.abilities.cast_started.connect(func(_slot: StringName, a: AbilityData) -> void: _send_cast(a))
		world.player.abilities.recast_fired.connect(func(slot: StringName) -> void:
			c2s_recast.rpc_id(1, AbilityController.SLOTS.find(slot)))


func detach() -> void:
	if Net.is_client() and Net.is_online():
		c2s_leave.rpc_id(1)
	active = false
	world = null
	players.clear()
	party.clear()
	players_changed.emit()
	party_changed.emit()


func _watch_mob(id: int) -> void:
	var mob: CombatCharacter = world.mobs[id]
	if Net.is_server():
		mob.abilities.cast_started.connect(func(_slot: StringName, a: AbilityData) -> void:
			var ref: Vector2i = mob.abilities.ability_ref(a)
			for peer: int in _members:
				if _near(peer, mob.global_position):
					s2c_cast.rpc_id(peer, 1, id, ref.x, ref.y, mob.facing.aim_point))
	else:
		mob.visible = false
		_mob_seen[id] = MOB_STALE


func _process(delta: float) -> void:
	if not active or world == null:
		return
	if Net.is_server():
		_server_tick(delta)
	else:
		_client_tick(delta)


func _near(peer: int, at: Vector3) -> bool:
	var p: CombatCharacter = _members.get(peer, {}).get("puppet")
	return is_instance_valid(p) and HitQuery.flat(p.global_position - at).length() < INTEREST


# --- Hit forwarding (CombatCharacter.receive_hit / Tk) -----------------------------

## A hit on a puppet: attacker-side damage here, the rest on the target's owner.
static func forward_hit(target: CombatCharacter, hit: HitData) -> HitData.Result:
	if instance == null or not is_instance_valid(hit.source):
		return HitData.Result.IGNORED
	if instance._pvp_blocked(hit.source, target):
		return HitData.Result.IGNORED
	var ref: Vector2i = hit.source.abilities.ability_ref(hit.ability)
	var payload: Dictionary = {"d": target.attacker_damage(hit, hit.damage), "st": hit.stun_duration, "rt": hit.root_duration,
		"kv": hit.knockback_velocity, "kd": hit.knockback_duration, "ref": [ref.x, ref.y], "o": hit.opts}
	hit.source.energy.gain(hit.energy_gain)
	instance._deliver(hit.source, target, payload)
	return HitData.Result.HIT


## A technique effect (status, push, pull, heal...) on a puppet.
static func forward_effect(source: CombatCharacter, target: CombatCharacter, opts: Dictionary) -> void:
	if instance == null or instance._pvp_blocked(source, target):
		return
	instance._deliver(source, target, {"o": opts})


func _is_player(c: CombatCharacter) -> bool:
	return c != null and c.team != MOB_TEAM


## No PvP inside the villages (safe zones).
func _pvp_blocked(source: CombatCharacter, target: CombatCharacter) -> bool:
	if not _is_player(source) or not _is_player(target) or source.team == target.team:
		return false
	return World.in_village(source.global_position) or World.in_village(target.global_position)


func _deliver(source: CombatCharacter, target: CombatCharacter, payload: Dictionary) -> void:
	if world == null:
		return
	var mob_id: int = world.mobs.find(target)
	if Net.is_client():
		if mob_id >= 0:
			c2s_hit.rpc_id(1, 1, mob_id, payload)
		else:
			var peer: int = _peer_of(target)
			if peer != 0:
				c2s_hit.rpc_id(1, 0, peer, payload)
		return
	# Server: a mob hits a player.
	var src: int = world.mobs.find(source)
	var owner: int = _server_peer_of(target)
	if src >= 0 and owner != 0:
		s2c_hit.rpc_id(owner, 1, src, payload)


func _peer_of(puppet: CombatCharacter) -> int:
	for peer: int in players:
		if players[peer].puppet == puppet:
			return peer
	return 0


func _server_peer_of(puppet: CombatCharacter) -> int:
	for peer: int in _members:
		if _members[peer].puppet == puppet:
			return peer
	return 0


## Applies a forwarded hit / effect to `target` (owned here) from `source` (a puppet).
func _apply(source: CombatCharacter, target: CombatCharacter, payload: Dictionary) -> void:
	if not is_instance_valid(target) or target.is_dead() or not is_instance_valid(source):
		return
	if _pvp_blocked(source, target) or (source.team == target.team and payload.has("d")):
		return
	var opts: Dictionary = payload.get("o", {})
	if payload.has("d"):
		var hit := HitData.new()
		hit.remote = true
		hit.source = source
		var ref: Array = payload.get("ref", [-1, 0])
		hit.ability = source.abilities.ability_from_ref(Vector2i(int(ref[0]), int(ref[1])))
		hit.damage = clampf(float(payload.d), 0.0, 400.0)
		hit.stun_duration = clampf(float(payload.get("st", 0.0)), 0.0, 5.0)
		hit.root_duration = clampf(float(payload.get("rt", 0.0)), 0.0, 5.0)
		hit.knockback_velocity = payload.get("kv", Vector3.ZERO)
		hit.knockback_duration = clampf(float(payload.get("kd", 0.0)), 0.0, 2.0)
		hit.opts = opts
		if target.receive_hit(hit) != HitData.Result.HIT:
			return
	if not opts.is_empty():
		Tk.apply_opts(target, opts, HitQuery.flat(target.global_position - source.global_position).normalized())


# --- Server ---------------------------------------------------------------------------

func _server_tick(delta: float) -> void:
	_mob_left -= delta
	if _mob_left > 0.0:
		return
	_mob_left = MOB_INTERVAL
	for peer: int in _members:
		var data := PackedFloat32Array()
		for id in world.mobs.size():
			var mob: CombatCharacter = world.mobs[id]
			if mob.process_mode == Node.PROCESS_MODE_DISABLED or not _near(peer, mob.global_position):
				continue
			data.append(float(id))
			mob.write_world_state(data)
		if not data.is_empty():
			s2c_mobs.rpc_id(peer, data)
	var around: Array[Vector3] = []
	for peer: int in _members:
		var p: CombatCharacter = _members[peer].puppet
		if is_instance_valid(p):
			around.append(p.global_position)
	world.wake_mobs(around)


func team_of(peer: int) -> int:
	var leader: int = int(_members.get(peer, {}).get("party", 0))
	return PLAYER_TEAM_BASE + (leader if leader != 0 else peer)


func _info(peer: int) -> Dictionary:
	var m: Dictionary = _members[peer]
	var p: CharacterProfile = Profiles.server_load(Net.account_of(peer))
	return {"peer": peer, "name": m.name, "team": team_of(peer), "profile": p.to_dict() if p != null else {}}


@rpc("any_peer", "call_remote", "reliable")
func c2s_enter() -> void:
	if not Net.is_server() or world == null:
		return
	var peer: int = multiplayer.get_remote_sender_id()
	var profile: CharacterProfile = Profiles.server_load(Net.account_of(peer))
	if profile == null:
		return
	if not _members.has(peer) and _members.size() >= MAX_PLAYERS:
		s2c_full.rpc_id(peer)
		return
	_remove(peer)
	var puppet: CombatCharacter = world.add_player_puppet(profile, team_of(peer))
	_members[peer] = {"name": profile.character_name, "puppet": puppet, "party": 0}
	puppet.team = team_of(peer)
	var others: Array = []
	for other: int in _members:
		if other != peer:
			others.append(_info(other))
			s2c_player_joined.rpc_id(other, _info(peer))
	s2c_welcome.rpc_id(peer, team_of(peer), others)
	print("[world] %s entered (%d / %d)" % [profile.character_name, _members.size(), MAX_PLAYERS])


@rpc("any_peer", "call_remote", "reliable")
func c2s_leave() -> void:
	_remove(multiplayer.get_remote_sender_id())


## Server: a peer left the world (or disconnected).
func on_peer_left(peer: int) -> void:
	_remove(peer)


func _remove(peer: int) -> void:
	if not _members.has(peer):
		return
	_gone = peer
	_leave_party(peer, false)
	_gone = 0
	var puppet: CombatCharacter = _members[peer].puppet
	if is_instance_valid(puppet):
		puppet.queue_free()
	_members.erase(peer)
	for other: int in _members:
		s2c_player_left.rpc_id(other, peer)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func c2s_state(data: PackedFloat32Array) -> void:
	var peer: int = multiplayer.get_remote_sender_id()
	if not _members.has(peer) or data.size() != CombatCharacter.WORLD_STRIDE:
		return
	var puppet: CombatCharacter = _members[peer].puppet
	if is_instance_valid(puppet):
		puppet.apply_world_state(data, 0)
	for other: int in _members:
		if other != peer:
			s2c_player_state.rpc_id(other, peer, data)


@rpc("any_peer", "call_remote", "reliable")
func c2s_cast(slot_index: int, depth: int, aim: Vector3) -> void:
	var peer: int = multiplayer.get_remote_sender_id()
	if not _members.has(peer):
		return
	for other: int in _members:
		if other != peer and _near(other, aim):
			s2c_cast.rpc_id(other, 0, peer, slot_index, depth, aim)


@rpc("any_peer", "call_remote", "reliable")
func c2s_recast(slot_index: int) -> void:
	var peer: int = multiplayer.get_remote_sender_id()
	for other: int in _members:
		if other != peer:
			s2c_recast.rpc_id(other, peer, slot_index)


@rpc("any_peer", "call_remote", "reliable")
func c2s_hit(target_kind: int, target_id: int, payload: Dictionary) -> void:
	var peer: int = multiplayer.get_remote_sender_id()
	if not _members.has(peer) or world == null:
		return
	if target_kind == 1:
		if target_id >= 0 and target_id < world.mobs.size():
			_apply(_members[peer].puppet, world.mobs[target_id], payload)
	elif _members.has(target_id):
		s2c_hit.rpc_id(target_id, 0, peer, payload)


## The loadout / look of a player changed: everyone rebuilds its puppet.
@rpc("any_peer", "call_remote", "reliable")
func c2s_profile_changed() -> void:
	var peer: int = multiplayer.get_remote_sender_id()
	if not _members.has(peer):
		return
	var info: Dictionary = _info(peer)
	for other: int in _members:
		if other != peer:
			s2c_player_joined.rpc_id(other, info)


## Server: a mob died; its killer (and the killer's party nearby) gets the XP.
func on_mob_killed(mob_id: StringName, mob: CombatCharacter) -> void:
	var killer: int = _server_peer_of(mob.last_attacker)
	if killer == 0:
		return
	var rewarded: Array[int] = [killer]
	var leader: int = int(_members[killer].party)
	if leader != 0:
		for peer: int in _members:
			var p: CombatCharacter = _members[peer].puppet
			if peer != killer and int(_members[peer].party) == leader and is_instance_valid(p) \
					and HitQuery.flat(p.global_position - mob.global_position).length() < XP_SHARE_RANGE:
				rewarded.append(peer)
	for peer: int in rewarded:
		Net.grant_kill(peer, mob_id)


# --- Party (server) ---------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func c2s_party_invite(target: int) -> void:
	var peer: int = multiplayer.get_remote_sender_id()
	if not _members.has(peer) or not _members.has(target) or target == peer:
		return
	var leader: int = int(_members[peer].party)
	if leader != 0 and leader == int(_members[target].party):
		return
	if leader != 0 and _party_of(leader).size() >= PARTY_MAX:
		s2c_notice.rpc_id(peer, "Groupe complet (%d max)." % PARTY_MAX)
		return
	_members[target]["invite_from"] = peer
	s2c_invited.rpc_id(target, peer, _members[peer].name)
	s2c_notice.rpc_id(peer, "Invitation envoyée à %s." % _members[target].name)


@rpc("any_peer", "call_remote", "reliable")
func c2s_party_answer(from_peer: int, accept: bool) -> void:
	var peer: int = multiplayer.get_remote_sender_id()
	if not _members.has(peer) or not _members.has(from_peer) or int(_members[peer].get("invite_from", 0)) != from_peer:
		return
	_members[peer].erase("invite_from")
	if not accept:
		s2c_notice.rpc_id(from_peer, "%s a refusé l'invitation." % _members[peer].name)
		return
	var leader: int = int(_members[from_peer].party)
	if leader == 0:
		leader = from_peer
		_members[from_peer].party = leader
	if _party_of(leader).size() >= PARTY_MAX:
		s2c_notice.rpc_id(peer, "Groupe complet.")
		return
	_leave_party(peer)
	_members[peer].party = leader
	_party_updated(leader)


@rpc("any_peer", "call_remote", "reliable")
func c2s_party_leave() -> void:
	_leave_party(multiplayer.get_remote_sender_id())


func _party_of(leader: int) -> Array[int]:
	var out: Array[int] = []
	for peer: int in _members:
		if int(_members[peer].party) == leader:
			out.append(peer)
	return out


func _leave_party(peer: int, notify: bool = true) -> void:
	if not _members.has(peer):
		return
	var leader: int = int(_members[peer].party)
	if leader == 0:
		return
	_members[peer].party = 0
	if notify:
		_send_party(peer)
	var rest: Array[int] = _party_of(leader)
	if rest.size() == 1:   # alone: no party any more
		_members[rest[0]].party = 0
		_send_party(rest[0])
		rest.clear()
	elif leader == peer and not rest.is_empty():   # the leader left: the next one leads
		for other: int in rest:
			_members[other].party = rest[0]
		leader = rest[0]
	if not rest.is_empty():
		_party_updated(leader)


func _party_updated(leader: int) -> void:
	for peer: int in _party_of(leader):
		_send_party(peer)


## Sends a peer its party and everyone its (new) team.
func _send_party(peer: int) -> void:
	var leader: int = int(_members[peer].party)
	var list: Array = _party_of(leader) if leader != 0 else []
	s2c_party.rpc_id(peer, list, leader)
	var team: int = team_of(peer)
	var puppet: CombatCharacter = _members[peer].puppet
	if is_instance_valid(puppet):
		puppet.team = team
	for other: int in _members:
		if other != _gone:
			s2c_team.rpc_id(other, peer, team)


# --- Client ----------------------------------------------------------------------------

func _client_tick(delta: float) -> void:
	var player: CombatCharacter = world.player
	_send_left -= delta
	if _send_left <= 0.0 and is_instance_valid(player):
		_send_left = STATE_INTERVAL
		var data := PackedFloat32Array()
		player.write_world_state(data)
		c2s_state.rpc_id(1, data)
	for id: int in _mob_seen:
		_mob_seen[id] += delta
		if _mob_seen[id] > MOB_STALE:
			var mob: CombatCharacter = world.mobs[id]
			if mob.visible:
				mob.visible = false
				mob.collision_layer = 0


func _send_cast(a: AbilityData) -> void:
	var player: CombatCharacter = world.player if world != null else null
	if player == null or not Net.is_online():
		return
	var ref: Vector2i = player.abilities.ability_ref(a)
	if ref.x >= 0:
		c2s_cast.rpc_id(1, ref.x, ref.y, player.facing.aim_point)


## Local player's profile changed (loadout, look, grade): others rebuild its puppet.
func profile_changed() -> void:
	if active and Net.is_client() and Net.is_online():
		c2s_profile_changed.rpc_id(1)


func invite(peer: int) -> void:
	c2s_party_invite.rpc_id(1, peer)


func answer(from_peer: int, accept: bool) -> void:
	c2s_party_answer.rpc_id(1, from_peer, accept)


func leave_party() -> void:
	c2s_party_leave.rpc_id(1)


func _add_player(info: Dictionary) -> void:
	var peer: int = int(info.peer)
	_drop_player(peer)
	if world == null or (info.profile as Dictionary).is_empty():
		return
	var profile: CharacterProfile = CharacterProfile.from_dict(info.profile)
	var puppet: CombatCharacter = world.add_player_puppet(profile, int(info.team))
	players[peer] = {"name": str(info.name), "team": int(info.team), "puppet": puppet, "village": profile.village_id}
	_refresh_roles()
	players_changed.emit()


func _drop_player(peer: int) -> void:
	if not players.has(peer):
		return
	var puppet: CombatCharacter = players[peer].puppet
	if is_instance_valid(puppet):
		puppet.queue_free()
	players.erase(peer)


func _refresh_roles() -> void:
	for peer: int in players:
		var puppet: CombatCharacter = players[peer].puppet
		if is_instance_valid(puppet):
			puppet.team = int(players[peer].team)
			puppet.presentation.set_role(CharacterPresentation.Role.ALLY if puppet.team == my_team else CharacterPresentation.Role.ENEMY)


@rpc("authority", "call_remote", "reliable")
func s2c_welcome(team: int, others: Array) -> void:
	my_team = team
	if world != null and is_instance_valid(world.player):
		world.player.team = team
	for info: Dictionary in others:
		_add_player(info)
	notice.emit("Monde partagé : %d autre(s) joueur(s) en ligne." % others.size())


@rpc("authority", "call_remote", "reliable")
func s2c_full() -> void:
	notice.emit("Le monde est complet (%d joueurs) : tu joues seul pour l'instant." % MAX_PLAYERS)


@rpc("authority", "call_remote", "reliable")
func s2c_player_joined(info: Dictionary) -> void:
	var known: bool = players.has(int(info.peer))
	_add_player(info)
	if not known:
		notice.emit("%s est entré dans le monde." % info.name)


@rpc("authority", "call_remote", "reliable")
func s2c_player_left(peer: int) -> void:
	if players.has(peer):
		notice.emit("%s a quitté le monde." % players[peer].name)
	_drop_player(peer)
	players_changed.emit()


@rpc("authority", "call_remote", "unreliable_ordered")
func s2c_player_state(peer: int, data: PackedFloat32Array) -> void:
	var entry: Dictionary = players.get(peer, {})
	if entry.is_empty() or data.size() != CombatCharacter.WORLD_STRIDE:
		return
	var puppet: CombatCharacter = entry.puppet
	if is_instance_valid(puppet):
		puppet.apply_world_state(data, 0)


@rpc("authority", "call_remote", "unreliable_ordered")
func s2c_mobs(data: PackedFloat32Array) -> void:
	if world == null:
		return
	var stride: int = CombatCharacter.WORLD_STRIDE + 1
	var o: int = 0
	while o + stride <= data.size():
		var id: int = int(data[o])
		if id >= 0 and id < world.mobs.size():
			world.mobs[id].apply_world_state(data, o + 1)
			_mob_seen[id] = 0.0
		o += stride


## kind 0 = player (id = peer), 1 = mob (id = mob index).
@rpc("authority", "call_remote", "reliable")
func s2c_cast(kind: int, id: int, slot_index: int, depth: int, aim: Vector3) -> void:
	var who: CombatCharacter = _source(kind, id)
	if is_instance_valid(who) and who.visible:
		who.abilities.replay_cast(Vector2i(slot_index, depth), aim)


@rpc("authority", "call_remote", "reliable")
func s2c_recast(peer: int, slot_index: int) -> void:
	var who: CombatCharacter = _source(0, peer)
	if is_instance_valid(who):
		who.abilities.replay_recast(slot_index)


@rpc("authority", "call_remote", "reliable")
func s2c_hit(kind: int, id: int, payload: Dictionary) -> void:
	if world == null:
		return
	_apply(_source(kind, id), world.player, payload)


func _source(kind: int, id: int) -> CombatCharacter:
	if world == null:
		return null
	if kind == 1:
		return world.mobs[id] if id >= 0 and id < world.mobs.size() else null
	return players.get(id, {}).get("puppet")


@rpc("authority", "call_remote", "reliable")
func s2c_invited(from_peer: int, from_name: String) -> void:
	invited.emit(from_peer, from_name)


@rpc("authority", "call_remote", "reliable")
func s2c_notice(text: String) -> void:
	notice.emit(text)


@rpc("authority", "call_remote", "reliable")
func s2c_party(members: Array, _leader: int) -> void:
	var before: int = party.size()
	party.clear()
	for m: Variant in members:
		party.append(int(m))
	if party.is_empty() and before > 0:
		notice.emit("Tu n'es plus dans un groupe.")
	elif party.size() > before:
		notice.emit("Groupe : %d membre(s)." % party.size())
	party_changed.emit()


@rpc("authority", "call_remote", "reliable")
func s2c_team(peer: int, team: int) -> void:
	if peer == me():
		my_team = team
		if world != null and is_instance_valid(world.player):
			world.player.team = team
	elif players.has(peer):
		players[peer].team = team
	_refresh_roles()
	party_changed.emit()
