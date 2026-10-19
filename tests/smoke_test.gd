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
var _orbs: int = 0
var _slams: int = 0
var _sudden_death: bool = false


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
	_manager.state_changed.connect(func(_s: MatchManager.State, msg: String) -> void:
		print("[match] ", msg.replace("\n", " "))
		if msg == "SUDDEN DEATH":
			_sudden_death = true)
	_manager.rules.orb_taken.connect(func(_by: CombatCharacter) -> void: _orbs += 1)
	for fighter: CombatCharacter in _manager.fighters:
		fighter.hit_received.connect(func(h: HitData) -> void:
			if h.ability == null and is_equal_approx(h.stun_duration, CombatCharacter.WALL_SLAM_STUN):
				_slams += 1)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _manager == null:
		return
	if _manager.state == MatchManager.State.MATCH_OVER or _frames >= MAX_SIM_FRAMES:
		_check(_manager.state == MatchManager.State.MATCH_OVER, "match reaches MATCH_OVER")
		_check(_hits > 20, "bots land hits (%d)" % _hits)
		print("[sim] frames=%d (%.0fs) hits=%d counters=%d scores=%s orbs=%d wall_slams=%d sudden_death=%s" % [
			_frames, _frames / 60.0, _hits, _counters, _manager.scores, _orbs, _slams, _sudden_death])
		_check(_orbs > 0, "bots contest and take the chakra orb")
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
	_feel_tests(naruto, sasuke)
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
	_new_roster_tests(naruto, sasuke)


func _new_roster_tests(a: CombatCharacter, b: CombatCharacter) -> void:
	var scene := load("res://characters/base/shinobi.tscn") as PackedScene
	var hinata := scene.instantiate() as CombatCharacter
	hinata.data = load("res://characters/hinata/hinata_data.tres")
	hinata.team = 1
	add_child(hinata)
	a.status.clear_all()
	a.health.reset()
	for i in 3:
		a.receive_hit(HitData.from_ability(hinata, hinata.data.lmb, Vector3.FORWARD))
	_check(a.status.has_status(StatusController.Type.SILENCE), "3 gentle fist blocks silence")
	_check(not a.abilities.try_cast(&"rmb") and a.status.can_cast(&"lmb"), "silence blocks jutsu, not basic attacks")
	a.status.clear_all()
	var itachi := scene.instantiate() as CombatCharacter
	itachi.data = load("res://characters/itachi/itachi_data.tres")
	itachi.team = 1
	add_child(itachi)
	a.receive_hit(HitData.from_ability(itachi, itachi.data.rmb, Vector3.FORWARD))
	a.status.apply_status(StatusController.Type.INCAPACITATE, 2.0)
	var poke := HitData.new()
	poke.source = itachi
	poke.damage = 1.0
	a.receive_hit(poke)
	_check(not a.status.has_status(StatusController.Type.INCAPACITATE), "genjutsu breaks on damage")
	var gaara := scene.instantiate() as CombatCharacter
	gaara.data = load("res://characters/gaara/gaara_data.tres")
	add_child(gaara)
	gaara.health.add_shield(20.0, 3.0)
	var hit := HitData.new()
	hit.source = itachi
	hit.damage = 15.0
	gaara.receive_hit(hit)
	_check(gaara.health.current_health == gaara.health.max_health and is_equal_approx(gaara.health.shield, 5.0), "sand shield absorbs damage")
	var minato := scene.instantiate() as CombatCharacter
	minato.data = load("res://characters/minato/minato_data.tres")
	add_child(minato)
	minato.global_position = Vector3(0, 0, 6)
	b.global_position = Vector3(0, 0, -3)
	b.status.clear_all()
	b.status.apply_status(StatusController.Type.SEAL, 8.0)
	minato.abilities.try_cast(&"rmb")
	for i in 20:
		minato.abilities.tick(1.0 / 60.0, null)
	_check(minato.global_position.distance_to(b.global_position) < 1.6, "hiraishin teleports to the sealed target")
	for n: Node in [hinata, itachi, gaara, minato]:
		n.queue_free()


## Combat feel mechanics: hold-to-attack, recovery cancels, stun DR, orb.
func _feel_tests(a: CombatCharacter, b: CombatCharacter) -> void:
	var status := StatusController.new()
	status.apply_status(StatusController.Type.STUN, 1.0)
	status.tick(1.1)
	status.apply_status(StatusController.Type.STUN, 1.0)
	_check(is_equal_approx(status.get_remaining(StatusController.Type.STUN), 0.5), "back-to-back stuns are halved (diminishing returns)")
	status.free()

	for c: CombatCharacter in [a, b]:
		c.status.clear_all()
		c.abilities.reset()
		c.health.reset()
	a.global_position = Vector3(20, 0, 20)  # out of reach: whiffs only
	var intent := GameplayIntent.new()
	intent.held_slots.append(&"lmb")
	var casts: Array[int] = [0]
	var on_cast := func(_slot: StringName, _a: AbilityData) -> void: casts[0] += 1
	a.abilities.cast_started.connect(on_cast)
	for i in 90:
		a.abilities.tick(1.0 / 60.0, intent)
	_check(casts[0] >= 4, "holding LMB keeps attacking (%d swings in 1.5 s)" % casts[0])
	a.abilities.cast_started.disconnect(on_cast)
	a.abilities.reset()
	a.abilities.try_cast(&"lmb")
	while a.abilities.phase != AbilityController.Phase.RECOVERY:
		a.abilities.tick(1.0 / 60.0, null)
	var dash := GameplayIntent.new()
	dash.pressed_slots.append(&"space")
	a.abilities.tick(1.0 / 60.0, dash)
	_check(a.abilities.current_slot == &"space", "mobility cancels attack recovery")
	a.abilities.reset()

	# Guard: frontal hits chip, perfect parry (F + LMB) stuns basic attackers.
	b.global_position = Vector3(0, 0, -1.5)
	a.global_position = Vector3.ZERO
	a.facing.set_direction(Vector3.FORWARD)
	var guard := GameplayIntent.new()
	guard.guard_held = true
	a._tick_guard(1.0 / 60.0, guard, true)
	_check(a.guarding, "holding F guards")
	var hp0: float = a.health.current_health
	a.receive_hit(HitData.from_ability(b, b.data.rmb, Vector3.BACK))
	_check(is_equal_approx(hp0 - a.health.current_health, b.data.rmb.damage * CombatCharacter.GUARD_DAMAGE_TAKEN)
		and not a.status.has_status(StatusController.Type.STUN), "guard blocks most damage and all CC")
	guard.pressed_slots.append(&"lmb")
	a._tick_guard(1.0 / 60.0, guard, true)
	hp0 = a.health.current_health
	var parried: HitData.Result = a.receive_hit(HitData.from_ability(b, b.data.lmb.combo_next, Vector3.BACK))
	_check(parried == HitData.Result.COUNTERED and a.health.current_health == hp0 and b.status.has_status(StatusController.Type.STUN),
		"perfect parry on a basic attack stuns the attacker")
	b.status.clear_all()
	guard.pressed_slots.clear()
	for i in 60:
		a._tick_guard(1.0 / 60.0, guard, true)
	guard.pressed_slots.append(&"lmb")
	a._tick_guard(1.0 / 60.0, guard, true)
	a.receive_hit(HitData.from_ability(b, b.data.rmb, Vector3.BACK))
	_check(not b.status.has_status(StatusController.Type.STUN), "perfect parry only works on basic attacks")
	a._tick_guard(1.0 / 60.0, null, true)
	a.health.reset()
	b.health.reset()

	var rules := ArenaRules.new()
	add_child(rules)
	rules.orb_hp = ArenaRules.ORB_MAX_HP
	a.global_position = Vector3(0, 0, 1.0)
	a.health.apply_damage(40.0)
	var hp_before: float = a.health.current_health
	_check(ArenaRules.hit_orb(a, Vector3.ZERO, 0.5, ArenaRules.ORB_MAX_HP), "damaging hits strike the orb")
	_check(not rules.orb_alive() and a.health.current_health > hp_before and a.energy.current_energy >= ArenaRules.ORB_ENERGY,
		"last hit on the orb heals and grants chakra")
	rules.fight_time = ArenaRules.SUDDEN_DEATH_AT + ArenaRules.RING_CLOSE_TIME
	_check(is_equal_approx(rules.ring_radius(), ArenaRules.RING_END_RADIUS), "sudden death ring closes")
	rules.free()
	a.health.reset()
	a.energy.reset()


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   ", label)
	else:
		_failures += 1
		print("  FAIL ", label)
