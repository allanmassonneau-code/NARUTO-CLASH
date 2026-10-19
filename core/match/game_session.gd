extends Node
## Autoload (GameSession): carries menu choices into the match scene.

enum Mode { DUEL_VS_BOT, TEAM_2V2_VS_BOTS }

const ROSTER_PATHS: Array[String] = [
	"res://characters/naruto/naruto_data.tres",
	"res://characters/sasuke/sasuke_data.tres",
	"res://characters/sakura/sakura_data.tres",
	"res://characters/kakashi/kakashi_data.tres",
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

var _roster: Array[CharacterData] = []


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
