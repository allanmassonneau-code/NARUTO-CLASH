extends Node
## Headless regression test. Run:
##   godot --headless --fixed-fps 60 res://tests/smoke_test.tscn
## Unit checks on components, then a full bot-vs-bot 2v2 match simulation.

const MAX_SIM_FRAMES: int = 60 * 60 * 6

var _failures: int = 0
var _frames: int = 0
var _hits: int = 0
var _counters: int = 0
var _manager: MatchManager


func _ready() -> void:
	_unit_tests()
	GameSession.mode = GameSession.Mode.TEAM_2V2_VS_BOTS
	GameSession.player_index = 0
	GameSession.ally_indices = [2]
	GameSession.enemy_indices = [1, 3]
	var arena: Node = (load(GameSession.ARENA_SCENE) as PackedScene).instantiate()
	add_child(arena)
	_manager = arena.get_node("MatchManager") as MatchManager
	# Let a bot drive the "player" too, so all four fighters act.
	var player: CombatCharacter = _manager.player
	var bot := BotController.new()
	player.controller.queue_free()
	player.add_child(bot)
	player.controller = bot
	for fighter: CombatCharacter in _manager.fighters:
		fighter.hit_received.connect(func(_h: HitData) -> void: _hits += 1)
		fighter.counter_triggered.connect(func(_h: HitData) -> void: _counters += 1)
	_manager.state_changed.connect(func(_s: MatchManager.State, msg: String) -> void: print("[match] ", msg.replace("\n", " ")))


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _manager == null:
		return
	if _manager.state == MatchManager.State.MATCH_OVER or _frames >= MAX_SIM_FRAMES:
		_check(_manager.state == MatchManager.State.MATCH_OVER, "match reaches MATCH_OVER")
		_check(_hits > 20, "bots land hits (%d)" % _hits)
		print("[sim] frames=%d (%.0fs) hits=%d counters=%d scores=%s" % [_frames, _frames / 60.0, _hits, _counters, _manager.scores])
		print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
		get_tree().quit(1 if _failures > 0 else 0)


func _unit_tests() -> void:
	var health := HealthComponent.new()
	health.setup(100.0)
	health.apply_damage(40.0)
	_check(is_equal_approx(health.current_health, 60.0), "damage reduces health")
	_check(is_equal_approx(health.recoverable_health, 20.0), "half of damage is recoverable")
	health.heal(50.0)
	_check(is_equal_approx(health.current_health, 80.0), "heal capped by recoverable health")
	health.heal(50.0, true)
	_check(is_equal_approx(health.current_health, 100.0), "true heal ignores recoverable cap")
	health.free()

	var energy := EnergyComponent.new()
	energy.reset()
	_check(not energy.consume(25.0), "cannot spend energy you don't have")
	energy.gain(130.0)
	_check(is_equal_approx(energy.current_energy, 100.0), "energy clamps at max")
	_check(energy.consume(100.0) and energy.current_energy == 0.0, "ultimate consumes 100")
	energy.free()

	var status := StatusController.new()
	status.apply_status(StatusController.Type.STUN, 0.5)
	_check(not status.can_act() and not status.can_move(), "stun blocks acting and moving")
	status.tick(0.6)
	_check(status.can_act(), "stun expires")
	status.apply_status(StatusController.Type.ROOT, 1.0)
	_check(status.can_act() and not status.can_move(), "root blocks moving only")
	status.free()

	# Kawarimi: counter consumes the hit and teleports.
	var scene := load("res://characters/base/shinobi.tscn") as PackedScene
	var naruto := scene.instantiate() as CombatCharacter
	naruto.data = load("res://characters/naruto/naruto_data.tres")
	var sasuke := scene.instantiate() as CombatCharacter
	sasuke.data = load("res://characters/sasuke/sasuke_data.tres")
	sasuke.team = 1
	add_child(naruto)
	add_child(sasuke)
	naruto.global_position = Vector3.ZERO
	_check(naruto.abilities.try_cast(&"q"), "naruto starts kawarimi")
	naruto.abilities.tick(0.05, null)
	_check(naruto.status.has_status(StatusController.Type.COUNTER), "kawarimi opens counter window")
	var hit := HitData.from_ability(sasuke, sasuke.data.rmb, Vector3.FORWARD)
	_check(naruto.receive_hit(hit) == HitData.Result.COUNTERED, "hit during kawarimi is countered")
	_check(naruto.health.current_health == naruto.health.max_health, "countered hit deals no damage")
	_check(naruto.global_position.distance_to(Vector3.ZERO) > 1.0, "kawarimi teleports")
	_check(naruto.abilities.get_cooldown_left(&"q") > 0.0, "kawarimi goes on cooldown")
	# Stun interrupts a cast in startup and applies the cancel cooldown.
	_check(sasuke.abilities.try_cast(&"rmb"), "sasuke starts katon")
	var stun := HitData.new()
	stun.source = naruto
	stun.stun_duration = 0.5
	sasuke.receive_hit(stun)
	_check(not sasuke.abilities.is_casting(), "stun interrupts startup")
	_check(is_equal_approx(sasuke.abilities.get_cooldown_left(&"rmb"), sasuke.data.rmb.cancel_cooldown), "interrupt applies cancel cooldown")
	# Feint: cancel during startup.
	sasuke.status.clear_all()
	sasuke.abilities.reset()
	sasuke.abilities.try_cast(&"rmb")
	sasuke.abilities.cancel()
	_check(not sasuke.abilities.is_casting(), "katon can be cancelled (feint)")
	_kit_tests(naruto, sasuke)
	naruto.queue_free()
	sasuke.queue_free()


## Signature mechanics of each kit.
func _kit_tests(naruto: CombatCharacter, sasuke: CombatCharacter) -> void:
	for c: CombatCharacter in [naruto, sasuke]:
		c.status.clear_all()
		c.abilities.reset()
		c.health.reset()
	naruto.global_position = Vector3.ZERO
	sasuke.global_position = Vector3(0, 0, -1.5)
	naruto.facing.set_direction(Vector3.FORWARD)
	# Sasuke: Kusanagi marks, Chidori consumes them.
	var slash: AbilityData = sasuke.data.lmb
	for i in 3:
		naruto.receive_hit(HitData.from_ability(sasuke, slash, Vector3.FORWARD))
	_check(naruto.status.get_stacks(StatusController.Type.MARK) == 3, "kusanagi stacks 3 sharingan marks")
	var before: float = naruto.health.current_health
	naruto.receive_hit(HitData.from_ability(sasuke, sasuke.data.rmb, Vector3.FORWARD))
	var dealt: float = before - naruto.health.current_health
	_check(is_equal_approx(dealt, sasuke.data.rmb.damage + 3.0 * sasuke.data.rmb.mark_bonus_damage), "chidori cashes in marks (%.0f dmg)" % dealt)
	_check(naruto.status.get_stacks(StatusController.Type.MARK) == 0, "marks consumed")
	_check(naruto.status.get_remaining(StatusController.Type.STUN) >= 1.2, "3 marks = long stun")
	naruto.status.clear_all()
	naruto.health.reset()
	# Naruto: clone summon + mirrored taijutsu (half damage) + swap.
	naruto.abilities.try_cast(&"e")
	for i in 30:
		naruto.abilities.tick(1.0 / 60.0, null)
	_check(is_instance_valid(naruto.clone), "kage bunshin summons a clone")
	if is_instance_valid(naruto.clone):
		naruto.clone.global_position = Vector3(0, 0, -0.5)
		sasuke.health.reset()
		var hits: Array[CombatCharacter] = []
		naruto.clone.mirror_melee(naruto.data.lmb, Vector3.FORWARD)
		_check(is_equal_approx(sasuke.health.max_health - sasuke.health.current_health, naruto.data.lmb.damage * ShadowClone.DAMAGE_SCALE), "clone mirrors taijutsu at 50%")
		var clone_pos: Vector3 = naruto.clone.global_position
		naruto.abilities.try_cast(&"space")
		for i in 10:
			naruto.abilities.tick(1.0 / 60.0, null)
		_check(naruto.global_position.distance_to(clone_pos) < 0.1, "space swaps places with the clone")
	# Kakashi: copy the countered jutsu into E.
	var kakashi := (load("res://characters/base/shinobi.tscn") as PackedScene).instantiate() as CombatCharacter
	kakashi.data = load("res://characters/kakashi/kakashi_data.tres")
	add_child(kakashi)
	kakashi.abilities.try_cast(&"q")
	kakashi.abilities.tick(0.05, null)
	kakashi.receive_hit(HitData.from_ability(sasuke, sasuke.data.e, Vector3.FORWARD))
	_check(kakashi.abilities.get_ability(&"e") == sasuke.data.e, "sharingan copy puts the jutsu in E")
	_check(kakashi.abilities.is_ready(&"e"), "copied jutsu is usable")
	# Burning ground: Katon carries a lingering zone.
	_check(sasuke.data.e.expire_zone != null and sasuke.data.e.expire_zone.zone_duration > 0.0, "katon leaves burning ground")
	# Kurama passive.
	naruto.status.clear_all()
	naruto.health.reset()
	var big := HitData.new()
	big.source = sasuke
	big.damage = naruto.health.max_health * 0.75
	naruto.receive_hit(big)
	_check(naruto.status.has_status(StatusController.Type.REGEN), "kurama chakra triggers under 30% HP")
	kakashi.queue_free()


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   ", label)
	else:
		_failures += 1
		print("  FAIL ", label)
