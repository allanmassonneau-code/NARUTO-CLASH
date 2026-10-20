extends Node
## Autoload (GameSession): carries menu choices into the match scene.

enum Mode { DUEL_VS_BOT, TEAM_2V2_VS_BOTS, BATTLE_20V20 }
enum NetRole { OFFLINE, SERVER, CLIENT }

const ROSTER_PATHS: Array[String] = [
	"res://characters/naruto/naruto_data.tres",
	"res://characters/sasuke/sasuke_data.tres",
	"res://characters/sakura/sakura_data.tres",
	"res://characters/kakashi/kakashi_data.tres",
	"res://characters/lee/lee_data.tres",
	"res://characters/gaara/gaara_data.tres",
	"res://characters/hinata/hinata_data.tres",
	"res://characters/shikamaru/shikamaru_data.tres",
	"res://characters/itachi/itachi_data.tres",
	"res://characters/minato/minato_data.tres",
]
const MENU_SCENE: String = "res://ui/menu/character_select.tscn"
const ARENA_SCENE: String = "res://arenas/playground/playground.tscn"

var mode: Mode = Mode.DUEL_VS_BOT
var player_index: int = 0
## Roster indices: [ally] for team 0 (besides the player), [enemies...] for team 1.
var ally_indices: Array[int] = []
var enemy_indices: Array[int] = [1]
var rounds_to_win: int = 3
var bot_passive: bool = false

var net_role: NetRole = NetRole.OFFLINE
## Fighters of the next match. Entries: {roster:int, team:int, control:String, peer:int}
## control = "local" (this machine's player), "bot", "remote" (server: a client).
var lineup: Array[Dictionary] = []
var local_fighter: int = 0

var player_name: String = "Shinobi"
var server_host: String = "127.0.0.1"
## Your friend code (generated once, shared with friends to add you).
var friend_code: String = ""
## Friends: Array of {code:String, name:String}.
var friends: Array[Dictionary] = []
## Secret identifying this player's account on the servers (profile owner).
var account_token: String = ""
## Options (O in game / gear button): audio and display.
var master_volume: float = 70.0
var sfx_volume: float = 80.0
var muted: bool = false
var spatial_sound: bool = true
var fullscreen: bool = false
var anti_aliasing: bool = true

const SETTINGS_PATH: String = "user://settings.cfg"

var _roster: Array[CharacterData] = []


## Display name. The project keeps its original config/name so the user data
## folder (settings, friend code) stays where it was.
const GAME_TITLE: String = "Ninja Battle"


func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_title(GAME_TITLE)
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		player_name = cfg.get_value("online", "name", player_name)
		server_host = cfg.get_value("online", "host", server_host)
		friend_code = cfg.get_value("online", "friend_code", "")
		account_token = cfg.get_value("online", "account_token", "")
		for entry: Variant in cfg.get_value("online", "friends", []):
			if entry is Dictionary:
				friends.append(entry)
		master_volume = cfg.get_value("options", "master_volume", master_volume)
		sfx_volume = cfg.get_value("options", "sfx_volume", sfx_volume)
		muted = cfg.get_value("options", "muted", muted)
		spatial_sound = cfg.get_value("options", "spatial_sound", spatial_sound)
		fullscreen = cfg.get_value("options", "fullscreen", fullscreen)
		anti_aliasing = cfg.get_value("options", "anti_aliasing", anti_aliasing)
	if friend_code == "" or account_token == "":
		if friend_code == "":
			friend_code = _new_code()
		if account_token == "":
			var crypto := Crypto.new()
			account_token = crypto.generate_random_bytes(24).hex_encode()
		save_settings()
	apply_options()
	# The launcher passes the official server: game.exe -- --host=1.2.3.4
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--host="):
			server_host = arg.trim_prefix("--host=")


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("online", "name", player_name)
	cfg.set_value("online", "host", server_host)
	cfg.set_value("online", "friend_code", friend_code)
	cfg.set_value("online", "account_token", account_token)
	cfg.set_value("online", "friends", friends)
	for key: String in ["master_volume", "sfx_volume", "muted", "spatial_sound", "fullscreen", "anti_aliasing"]:
		cfg.set_value("options", key, get(key))
	cfg.save(SETTINGS_PATH)


## Audio buses (SFX: soft compressor + light room reverb, like a mixed game)
## and display settings. Safe to call any time.
func apply_options() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var sfx: int = AudioServer.get_bus_index(&"SFX")
	if sfx < 0:
		AudioServer.add_bus()
		sfx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(sfx, &"SFX")
		AudioServer.set_bus_send(sfx, &"Master")
		var comp := AudioEffectCompressor.new()
		comp.threshold = -18.0
		comp.ratio = 3.0
		comp.attack_us = 10000.0
		comp.release_ms = 250.0
		AudioServer.add_bus_effect(sfx, comp)
		var shelf := AudioEffectHighShelfFilter.new()
		shelf.cutoff_hz = 6000.0
		shelf.gain = 0.5  # about -6 dB on the harsh highs
		AudioServer.add_bus_effect(sfx, shelf)
		var reverb := AudioEffectReverb.new()
		reverb.room_size = 0.35
		reverb.damping = 0.6
		reverb.wet = 0.12
		reverb.dry = 1.0
		AudioServer.add_bus_effect(sfx, reverb)
	AudioServer.set_bus_volume_db(0, _to_db(master_volume))
	AudioServer.set_bus_mute(0, muted)
	AudioServer.set_bus_volume_db(sfx, _to_db(sfx_volume))
	var window_mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != window_mode and not (not fullscreen and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED):
		DisplayServer.window_set_mode(window_mode)
	var viewport := get_viewport()
	viewport.msaa_3d = Viewport.MSAA_4X if anti_aliasing else Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if anti_aliasing else Viewport.SCREEN_SPACE_AA_DISABLED


static func _to_db(percent: float) -> float:
	return linear_to_db(clampf(percent / 100.0, 0.0001, 1.0))


func add_friend(code: String, friend_name: String) -> bool:
	code = code.strip_edges().to_upper()
	if code.length() < 4 or code == friend_code:
		return false
	for entry: Dictionary in friends:
		if entry.code == code:
			return false
	friends.append({"code": code, "name": friend_name if friend_name != "" else code})
	save_settings()
	return true


func remove_friend(code: String) -> void:
	for i in range(friends.size() - 1, -1, -1):
		if friends[i].code == code:
			friends.remove_at(i)
	save_settings()


## Keeps the stored name of a friend in sync with the name they play under.
func update_friend_name(code: String, friend_name: String) -> void:
	for entry: Dictionary in friends:
		if entry.code == code and entry.name != friend_name and friend_name != "":
			entry.name = friend_name
			save_settings()


static func _new_code() -> String:
	const ALPHABET: String = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var code: String = ""
	for i in 6:
		code += ALPHABET[rng.randi_range(0, ALPHABET.length() - 1)]
	return code


func get_roster() -> Array[CharacterData]:
	if _roster.is_empty():
		for path: String in ROSTER_PATHS:
			var data := load(path) as CharacterData
			assert(data != null, "Invalid roster entry: %s" % path)
			_roster.append(data)
	return _roster


func team_size() -> int:
	match mode:
		Mode.TEAM_2V2_VS_BOTS:
			return 2
		Mode.BATTLE_20V20:
			return BATTLE_TEAM_SIZE
	return 1


const BATTLE_TEAM_SIZE: int = 20


func is_battle() -> bool:
	return mode == Mode.BATTLE_20V20 and net_role == NetRole.OFFLINE


## Fills ally / enemy slots for the current mode. `opponent_index` < 0 = random.
func prepare_lineup(opponent_index: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var count: int = get_roster().size()
	ally_indices.clear()
	enemy_indices.clear()
	enemy_indices.append(opponent_index if opponent_index >= 0 else rng.randi_range(0, count - 1))
	for i in team_size() - 1:
		ally_indices.append(rng.randi_range(0, count - 1))
		enemy_indices.append(rng.randi_range(0, count - 1))
	build_offline_lineup()


func build_offline_lineup() -> void:
	net_role = NetRole.OFFLINE
	lineup.clear()
	lineup.append({"roster": player_index, "team": 0, "control": "local", "peer": 0})
	for index: int in ally_indices:
		lineup.append({"roster": index, "team": 0, "control": "bot", "peer": 0})
	for index: int in enemy_indices:
		lineup.append({"roster": index, "team": 1, "control": "bot", "peer": 0})
	local_fighter = 0
