extends Node
## Headless test of the shinobi combat mechanics: chakra costs and
## regeneration, concentration (hold R), jump (Space), dash (Shift) and
## substitution (Kawarimi).
##   godot --headless --fixed-fps 60 --path . res://tests/mechanics_test.tscn

class ScriptedIntent extends IntentSource:
	var pressed: Array[StringName] = []
	var jump: bool = false

	func poll_intent() -> GameplayIntent:
		intent.clear_actions()
		intent.pressed_slots.append_array(pressed)
		intent.jump_pressed = jump
		pressed.clear()
		jump = false
		return intent


var _failures: int = 0
var _world: World
var _player: CombatCharacter
var _input: ScriptedIntent


func _ready() -> void:
	GameSession.account_token = "mechanics_test_account"
	Profiles.use_remote(false)
	Profiles.dev_reset()
	Profiles.create("Testeur", &"konoha", ProgressionTypes.Origin.CLAN, &"clan_uchiha")
	Profiles.request({"action": "choose_primary_nature", "nature": &"katon"})
	Profiles.request({"action": "learn_jutsu", "jutsu": &"katon_d_goukakyuu"})
	Profiles.request({"action": "equip_jutsu", "jutsu": &"katon_d_goukakyuu"})
	_world = (load("res://world/world.tscn") as PackedScene).instantiate() as World
	add_child(_world)
	_player = _world.player
	_player.controller.queue_free()
	_input = ScriptedIntent.new()
	_player.add_child(_input)
	_player.controller = _input
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print("[%s] %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _wait(seconds: float) -> void:
	for i in roundi(seconds * 60.0):
		await get_tree().physics_frame


func _run() -> void:
	await _wait(0.2)
	var energy: EnergyComponent = _player.energy
	var expected: float = Profiles.service().max_resources(Profiles.profile).chakra
	_check(is_equal_approx(energy.max_energy, expected) and is_equal_approx(energy.current_energy, expected), "chakra pool = grade chakra, starts full")
	_check(_player.abilities.get_ability(&"space").display_name == "Dash", "Shift slot is the universal dash")
	_check(_player.abilities.get_ability(&"q").kind == AbilityData.Kind.SUBSTITUTION, "substitution slot")

	# Chakra cost.
	var jutsu: AbilityData = _player.abilities.get_ability(&"j1")
	_check(jutsu.energy_cost > 0.0, "techniques cost chakra")
	var before: float = energy.current_energy
	_input.pressed.append(&"j1")
	await _wait(0.5)
	_check(energy.current_energy <= before - jutsu.energy_cost + 3.0, "casting spends the chakra cost (%.0f -> %.0f)" % [before, energy.current_energy])
	await _wait(0.5)
	energy.sync_state(0.0)
	_player.abilities.reset_cooldown(&"j1")
	_check(_player.abilities.unavailable_reason(&"j1") == "CHAKRA", "HUD reason: not enough chakra")

	# Passive regeneration vs concentration.
	await _wait(1.0)
	var passive: float = energy.current_energy
	_check(passive > 2.0 and passive < 8.0, "passive chakra regen (%.1f/s)" % passive)
	energy.sync_state(0.0)
	_input.intent.concentrate_held = true
	_input.intent.move_direction = Vector3.RIGHT
	var pos: Vector3 = _player.global_position
	await _wait(1.0)
	_check(_player.concentrating, "holding R concentrates")
	_check(energy.current_energy > passive * 4.0, "concentration regenerates much faster (%.1f/s)" % energy.current_energy)
	_check(_player.global_position.distance_to(pos) < 0.05, "immobile while concentrating")
	var hp: float = _player.health.current_health
	var hit := HitData.new()
	hit.source = _world.mobs[0]
	hit.damage = 10.0
	_player.receive_hit(hit)
	_check(is_equal_approx(hp - _player.health.current_health, 10.0 * CombatCharacter.CONCENTRATE_DAMAGE_TAKEN), "vulnerable while concentrating")
	await _wait(0.05)
	_check(not _player.concentrating, "a hit breaks concentration")
	_input.intent.concentrate_held = false
	_input.intent.move_direction = Vector3.ZERO
	await _wait(0.8)

	# Jump.
	_input.jump = true
	await _wait(0.25)
	_check(_player.is_airborne() and _player.jump_height() > 0.5, "Space jumps")
	var area := AbilityData.new()
	area.kind = AbilityData.Kind.GROUND_AREA
	var ground := HitData.new()
	ground.source = _world.mobs[0]
	ground.ability = area
	ground.damage = 10.0
	_check(_player.receive_hit(ground) == HitData.Result.IGNORED, "airborne: ground areas miss")
	await _wait(0.5)
	_check(not _player.is_airborne(), "lands after the jump")

	# Dash.
	pos = _player.global_position
	_input.pressed.append(&"space")
	await _wait(0.05)
	_check(_player.status.has_status(StatusController.Type.IMMATERIAL), "dash is briefly invulnerable")
	await _wait(0.4)
	_check(_player.global_position.distance_to(pos) > 3.5, "dash moves (%.1f)" % _player.global_position.distance_to(pos))
	_check(_player.abilities.get_cooldown_left(&"space") > 0.0, "dash has a cooldown")

	# Substitution.
	var anchor: Vector3 = _player.global_position
	_input.pressed.append(&"q")
	await _wait(0.1)
	_check(_player.substitution_armed, "substitution armed")
	_check(_player.abilities.get_cooldown_left(&"q") > 45.0, "substitution recharges in 50 s")
	_player.global_position = anchor + Vector3(2.0, 0.0, 0.0)
	hp = _player.health.current_health
	var strike := HitData.new()
	strike.source = _world.mobs[0]
	strike.damage = 25.0
	strike.stun_duration = 1.0
	_check(_player.receive_hit(strike) == HitData.Result.IGNORED, "hit negated by the substitution")
	_check(is_equal_approx(_player.health.current_health, hp), "no damage taken")
	_check(HitQuery.flat(_player.global_position).distance_to(HitQuery.flat(anchor)) < 0.05, "teleported to the saved spot")
	_check(not _player.substitution_armed, "single use")
	_player.arm_substitution(4.0)
	_player.global_position = anchor + Vector3(6.0, 0.0, 0.0)
	await _wait(0.05)
	_check(not _player.substitution_armed, "leaving the zone cancels the substitution")

	Profiles.dev_reset()
	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)
