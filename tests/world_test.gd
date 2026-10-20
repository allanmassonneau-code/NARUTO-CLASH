extends Node
## Headless open-world test: a bot-driven shinobi hunts in the world, kills
## are reported to the progression authority, XP and promotions follow.
##   godot --headless --fixed-fps 60 --path . res://tests/world_test.tscn

const FRAMES: int = 60 * 150

var _world: World
var _frames: int = 0
var _kills: int = 0
var _xp: int = 0
var _promotions: int = 0


func _ready() -> void:
	GameSession.account_token = "world_test_account"
	Profiles.use_remote(false)
	Profiles.dev_reset()
	Profiles.create("Testeur", &"konoha", ProgressionTypes.Origin.CLAN, &"clan_uchiha")
	Profiles.request({"action": "choose_primary_nature", "nature": &"katon"})
	Profiles.request({"action": "learn_jutsu", "jutsu": &"katon_d_goukakyuu"})
	Profiles.request({"action": "learn_jutsu", "jutsu": &"katon_c_haisekishou"})
	Profiles.request({"action": "learn_jutsu", "jutsu": &"clan_uchiha_d_sharingan"})
	for id: StringName in [&"katon_d_goukakyuu", &"katon_c_haisekishou", &"clan_uchiha_d_sharingan"]:
		Profiles.request({"action": "equip_jutsu", "jutsu": id})
	Profiles.profile_updated.connect(_on_update)
	_world = (load("res://world/world.tscn") as PackedScene).instantiate() as World
	add_child(_world)
	var player: CombatCharacter = _world.player
	player.controller.queue_free()
	var bot := BotController.new()
	player.add_child(bot)
	player.controller = bot
	player.health.invulnerable_debug = true
	print("[world] player kit: %s" % [player.abilities._abilities.keys()])


func _on_update(_p: CharacterProfile, r: ProgressionResult) -> void:
	for e: Dictionary in r.events:
		match e.type:
			&"xp_gained":
				_kills += 1
				_xp += int(e.amount)
			&"promoted":
				_promotions += 1


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames < FRAMES and _promotions == 0:
		return
	var p: CharacterProfile = Profiles.profile
	var ok: bool = _kills >= 3 and _xp > 0 and (_promotions > 0 or p.xp == _xp) and _world.mobs.size() >= 29
	print("[world] mobs=%d kills=%d xp=%d promotions=%d grade=%d profile_xp=%d sim=%.0fs" % [
		_world.mobs.size(), _kills, _xp, _promotions, p.grade, p.xp, _frames / 60.0])
	Profiles.dev_reset()
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
