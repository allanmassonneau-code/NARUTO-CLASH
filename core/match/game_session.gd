extends Node
## Autoload (GameSession): carries menu choices into the match scene.

enum Mode { DUEL_VS_BOT, TEAM_2V2_VS_BOTS }
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

const SETTINGS_PATH: String = "user://settings.cfg"

var _roster: Array[CharacterData] = []


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		player_name = cfg.get_value("online", "name", player_name)
		server_host = cfg.get_value("online", "host", server_host)
	# The launcher passes the official server: game.exe -- --host=1.2.3.4
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--host="):
			server_host = arg.trim_prefix("--host=")


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("online", "name", player_name)
	cfg.set_value("online", "host", server_host)
	cfg.save(SETTINGS_PATH)


func get_roster() -> Array[CharacterData]:
	if _roster.is_empty():
		for path: String in ROSTER_PATHS:
			var data := load(path) as CharacterData
			assert(data != null, "Invalid roster entry: %s" % path)
			_roster.append(data)
	return _roster


func team_size() -> int:
	return 2 if mode == Mode.TEAM_2V2_VS_BOTS else 1


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
