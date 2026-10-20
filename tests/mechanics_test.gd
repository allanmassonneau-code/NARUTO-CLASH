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
	Profiles.request({"action": "learn_jutsu", "jutsu": &"katon_d_braise_tracante"})
	Profiles.request({"action": "equip_jutsu", "jutsu": &"katon_d_braise_tracante"})
	Profiles.request({"action": "learn_jutsu", "jutsu": &"katon_c_anneau_de_cendres"})
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

	# Combat menu: swapping techniques keeps cooldowns, HP and chakra.
	var abilities: AbilityController = _player.abilities
	_player.global_position = anchor
	await _wait(0.6)
	abilities.reset_cooldown(&"j1")
	energy.sync_state(energy.max_energy)
	_input.pressed.append(&"j1")
	await _wait(0.6)
	var cd: float = abilities.get_cooldown_left(&"j1")
	_check(cd > 0.0, "technique on cooldown before the swap")
	hp = _player.health.current_health
	var chakra: float = energy.current_energy
	Profiles.request({"action": "equip_jutsu_at", "jutsu": &"katon_c_anneau_de_cendres", "slot": 0})
	_check(abilities.get_ability(&"j1").source_id == &"katon_c_anneau_de_cendres", "menu places a technique in slot 1")
	_check(abilities.get_cooldown_left(&"j1") == 0.0, "the new technique is ready")
	_check(abilities.technique_cooldown(&"katon_d_braise_tracante") > cd - 0.1, "swapped-out technique keeps its cooldown")
	_check(is_equal_approx(_player.health.current_health, hp) and energy.current_energy >= chakra - 0.1, "swap keeps HP and chakra")
	Profiles.request({"action": "equip_jutsu_at", "jutsu": &"katon_d_braise_tracante", "slot": 1})
	_check(abilities.get_ability(&"j2").source_id == &"katon_d_braise_tracante" and abilities.get_cooldown_left(&"j2") > cd - 0.2,
		"cooldown follows the technique to its new slot")
	var menu: CombatMenu = _world.combat_menu
	menu.toggle()
	_check(menu.is_open(), "B opens the combat menu")
	menu.toggle()
	_check(not menu.is_open(), "and closes it")

	# Projection: launch, automatic aerial pursuit, fall.
	var launcher: AbilityData = JutsuAbilityFactory.build(Profiles.db.get_jutsu(&"katon_c_comete_incendiaire"), Profiles.db)
	_check(launcher.launch_duration > 0.0, "LAUNCH-tagged techniques project the target")
	var mob: CombatCharacter = _world.mobs[0]
	mob.controls_enabled = false
	mob.global_position = _player.global_position + Vector3(3.0, 0.0, 0.0)
	var mob_hp: float = mob.health.current_health
	var launch_hit := HitData.new()
	launch_hit.source = _player
	launch_hit.ability = launcher
	launch_hit.damage = 5.0
	mob.receive_hit(launch_hit)
	_check(mob.is_launched() and not mob.status.can_act(), "launched target can't act")
	await _wait(0.3)
	_check(mob.jump_height() > 2.0, "launched target is up in the air (%.1f)" % mob.jump_height())
	var left: float = mob.status.get_remaining(StatusController.Type.LAUNCHED)
	_input.intent.aim_point = mob.global_position
	_input.intent.has_aim_point = true
	_input.pressed.append(&"lmb")
	await _wait(0.12)
	_check(_player.pursuing == mob, "attacking pursues the launched target automatically")
	_check(HitQuery.flat(_player.global_position).distance_to(HitQuery.flat(mob.global_position)) < 1.6, "pursuit blinks next to it")
	_check(_player.jump_height() > 1.5, "the pursuer follows it in the air")
	_check(mob.status.get_remaining(StatusController.Type.LAUNCHED) > left - 0.12 + 0.2, "hits in the air keep it up")
	await _wait(3.2)
	_check(not mob.is_launched() and mob.jump_height() == 0.0, "it falls back down")
	_check(mob.status.has_status(StatusController.Type.STUN) or mob.health.current_health <= mob_hp - 5.0 - CombatCharacter.LANDING_DAMAGE,
		"landing hurts")
	_check(_player.pursuing == null and _player.jump_height() == 0.0, "the pursuer lands too")
	mob.controls_enabled = true

	# Taijutsu stance: N hits costing stamina, finisher stuns and pushes.
	await _wait(1.0)
	var step: Vector2i = _player.abilities.combo_step(&"lmb")
	_check(step == Vector2i(0, JutsuAbilityFactory.TAIJUTSU_STANCE.size()), "stance string of %d hits" % step.y)
	mob.controls_enabled = false
	mob.health.invulnerable_debug = true
	mob.status.clear_all()
	mob.global_position = _player.global_position + Vector3(1.6, 0.0, 0.0)
	_input.intent.aim_point = mob.global_position
	_input.intent.has_aim_point = true
	_input.intent.held_slots.append(&"lmb")
	var stunned_at: int = -1
	var max_step: int = 0
	for frame in 150:
		await get_tree().physics_frame
		max_step = maxi(max_step, _player.abilities.combo_step(&"lmb").x)
		if stunned_at < 0 and mob.status.has_status(StatusController.Type.STUN):
			stunned_at = frame
			_check(mob.movement.is_forced(), "the last hit pushes")
		mob.global_position = _player.global_position + Vector3(1.6, 0.0, 0.0) if stunned_at < 0 else mob.global_position
	_check(stunned_at > 0 and max_step == step.y, "the last hit of the string stuns (after %d hits)" % max_step)
	for frame in 240:
		await get_tree().physics_frame
		mob.global_position = _player.global_position + Vector3(1.6, 0.0, 0.0)
		if _player.abilities.unavailable_reason(&"lmb") == "ENDURANCE":
			break
	_check(_player.abilities.unavailable_reason(&"lmb") == "ENDURANCE", "attacking drains stamina until empty")
	_input.intent.held_slots.clear()
	await _wait(3.5)
	_check(is_equal_approx(_player.stamina, CombatCharacter.MAX_STAMINA), "stamina regenerates")
	mob.health.invulnerable_debug = false
	mob.controls_enabled = true

	# SHINOBI menu as an in-game overlay.
	_world.open_shinobi_menu()
	await _wait(0.1)
	_check(is_instance_valid(_world.shinobi_screen) and not _player.controls_enabled and _world.is_inside_tree(),
		"Esc opens the SHINOBI menu in game (world kept, controls off)")
	_world.shinobi_screen.queue_free()
	await _wait(0.1)
	_check(not is_instance_valid(_world.shinobi_screen) and _player.controls_enabled, "closing it gives control back")

	Profiles.dev_reset()
	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)
