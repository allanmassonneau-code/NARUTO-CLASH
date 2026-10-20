extends Node
## Progression system tests (spec §50 + robustness).
##   godot --headless --path . res://tests/progression_test.tscn

const G := ProgressionTypes.Grade
const R := ProgressionTypes.Rank

var _failures: int = 0
var db: ProgressionDatabase
var service: ProgressionService


func _ready() -> void:
	db = ProgressionDatabase.load_default()
	_check(db != null and db.validate().is_empty(), "progression database loads and is valid %s" % (db.validate() if db != null else []))
	service = ProgressionService.new(db, SubJutsuRollService.new(db, 1234))
	_grade_access_tests()
	_choice_tests()
	_clan_tests()
	_sub_jutsu_tests()
	_tenketsu_tests()
	_specialization_and_nature_tests()
	_robustness_tests()
	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _nature_jutsu(nature: StringName, rank: int, index: int) -> StringName:
	return db.get_nature(nature).jutsu_of_rank(rank)[index].id


func _sub_of_rank(rank: int, index: int) -> StringName:
	return db.sub_jutsu.filter(func(x: SubJutsuData) -> bool: return x.rank == rank)[index].id


func _profile(grade: int, clan: bool = false) -> CharacterProfile:
	return ProgressionDebug.make_test_profile(service, grade, clan)


func _can(p: CharacterProfile, id: StringName) -> bool:
	return JutsuRules.can_learn(db, p, db.get_jutsu(id)).ok


# Tests 1-5: rank access per grade.
func _grade_access_tests() -> void:
	var n: StringName = db.natures[0].id
	var genin := _profile(G.GENIN)
	_check(_can(genin, _nature_jutsu(n, R.D, 0)) and _can(genin, _nature_jutsu(n, R.C, 0)), "T1 Genin can learn D and C")
	_check(not _can(genin, _nature_jutsu(n, R.B, 0)) and not _can(genin, _nature_jutsu(n, R.A, 0)) and not _can(genin, _nature_jutsu(n, R.S, 0)),
		"T1 Genin cannot learn B, A, S")
	_check(_can(_profile(G.CHUNIN), _nature_jutsu(n, R.B, 0)), "T2 Chunin can learn B")
	var konin := _profile(G.KONIN)
	_check(not _can(konin, _nature_jutsu(n, R.A, 0)) and _can(konin, _nature_jutsu(n, R.B, 0)), "T3 Konin still cannot learn A")
	_check(_can(_profile(G.TOKUBETSU), _nature_jutsu(n, R.A, 0)), "T4 Tokubetsu can learn A")
	_check(_can(_profile(G.JONIN), _nature_jutsu(n, R.S, 0)), "T5 Jonin can learn S")
	var learn_s := service.learn_jutsu(genin, _nature_jutsu(n, R.S, 0))
	_check(not learn_s.ok and learn_s.error == &"RANK_LOCKED_BY_GRADE", "learning above the grade is refused by the service")


# Tests 6-7: exclusive choice per rank and per nature.
func _choice_tests() -> void:
	var p := _profile(G.TOKUBETSU)
	var a: StringName = p.primary_nature
	var b: StringName = p.secondary_nature
	_check(service.learn_jutsu(p, _nature_jutsu(a, R.D, 0)).ok, "learn D1")
	var second := service.learn_jutsu(p, _nature_jutsu(a, R.D, 1))
	_check(not second.ok and second.error == &"RANK_ALREADY_CHOSEN", "T6 cannot learn D1 and D2 of the same nature")
	_check(JutsuRules.node_state(db, p, db.get_jutsu(_nature_jutsu(a, R.D, 0))) == ProgressionTypes.NodeState.SELECTED
		and JutsuRules.node_state(db, p, db.get_jutsu(_nature_jutsu(a, R.D, 1))) == ProgressionTypes.NodeState.LOCKED_BY_CHOICE,
		"tree states: D1 SELECTED, D2 LOCKED_BY_CHOICE")
	_check(service.learn_jutsu(p, _nature_jutsu(b, R.D, 1)).ok, "T7 D1 of one nature + D2 of another is valid")
	_check(p.nature_choice(a, R.D) == _nature_jutsu(a, R.D, 0), "rank choice is stored explicitly")
	_check(JutsuRules.node_state(db, p, db.get_jutsu(_nature_jutsu(a, R.S, 0))) == ProgressionTypes.NodeState.LOCKED_GRADE,
		"S is LOCKED_GRADE for a Tokubetsu")
	var foreign: ChakraNatureData = db.natures[2]
	_check(service.learn_jutsu(p, foreign.jutsu[0].id).error == &"NATURE_NOT_OWNED", "cannot learn a nature you don't have")
	# A Jonin learns at most 5 techniques per nature.
	var jonin := _profile(G.JONIN)
	var learned: int = 0
	for jutsu: JutsuData in db.get_nature(jonin.primary_nature).jutsu:
		if service.learn_jutsu(jonin, jutsu.id).ok:
			learned += 1
	_check(learned == 5, "a Jonin can learn exactly 5 of the 10 techniques of a nature (%d)" % learned)


# Tests 8-9 + clan tree.
func _clan_tests() -> void:
	var clan := _profile(G.JONIN, true)
	var clan_data: ClanData = db.get_clan(clan.clan_id)
	_check(clan.is_clan() and clan_data != null and clan_data.jutsu.size() == 5, "T8 a clan character has its clan tree")
	var learned: int = 0
	for jutsu: JutsuData in clan_data.jutsu:
		if service.learn_jutsu(clan, jutsu.id).ok:
			learned += 1
	_check(learned == 5, "a Jonin learns all 5 clan techniques")
	var clanless := _profile(G.JONIN, false)
	_check(not clanless.is_clan() and service.learn_jutsu(clanless, clan_data.jutsu[0].id).error == &"NOT_IN_CLAN",
		"T9 a clanless character has no clan tree")
	var genin_clan := _profile(G.GENIN, true)
	_check(service.learn_jutsu(genin_clan, db.get_clan(genin_clan.clan_id).jutsu[2].id).error == &"RANK_LOCKED_BY_GRADE",
		"clan ranks follow the grade (Genin can't learn clan B)")
	var wrong := service.create_character("x", "x", &"suna", ProgressionTypes.Origin.CLAN, &"clan_senju")
	_check(wrong.profile == null and (wrong.result as ProgressionResult).error == &"CLAN_NOT_IN_VILLAGE", "clan must belong to the village")


# Tests 10-14: sub-jutsu events.
func _sub_jutsu_tests() -> void:
	var clanless := _profile(G.GENIN, false)
	var promo := service.promote(clanless)
	_check(promo.has_event(&"sub_jutsu_obtained") and clanless.owned_sub_jutsu.size() == 1, "T10 clanless Chunin gets a sub-jutsu roll")
	var clan := _profile(G.GENIN, true)
	var clan_promo := service.promote(clan)
	_check(not clan_promo.has_event(&"sub_jutsu_obtained") and clan.owned_sub_jutsu.is_empty(), "T11 clan character gets no sub-jutsu event")
	var first: StringName = clanless.owned_sub_jutsu[0]
	ProgressionDebug.auto_choose(service, clanless)
	service.promote(clanless)  # Konin
	var to_tokubetsu := service.promote(clanless)
	_check(clanless.pending_choices.has(ProgressionTypes.Choice.SUB_JUTSU_EVOLUTION), "Tokubetsu clanless must choose the evolution")
	_check(to_tokubetsu.has_event(&"choice_required"), "evolution choice is announced")
	var keeper: CharacterProfile = CharacterProfile.from_dict(clanless.to_dict())
	var keep := service.resolve_sub_jutsu_evolution(keeper, true)
	_check(keep.ok and keeper.owned_sub_jutsu.has(first) and keeper.owned_sub_jutsu.size() == 2, "T12 keep: first sub-jutsu kept + second roll")
	# Sacrifice: force a rank B first sub-jutsu for a deterministic check.
	var sacrificer: CharacterProfile = CharacterProfile.from_dict(clanless.to_dict())
	var b_sub: StringName = _sub_of_rank(R.B, 0)
	sacrificer.owned_sub_jutsu = [b_sub] as Array[StringName]
	sacrificer.learned_jutsu.append(b_sub)
	var unconfirmed := service.resolve_sub_jutsu_evolution(sacrificer, false, false)
	_check(unconfirmed.error == &"CONFIRMATION_REQUIRED" and sacrificer.owned_sub_jutsu.has(b_sub), "sacrifice asks for confirmation")
	var sacrifice := service.resolve_sub_jutsu_evolution(sacrificer, false, true)
	var new_sub: SubJutsuData = db.get_sub_jutsu(sacrificer.owned_sub_jutsu[0]) if not sacrificer.owned_sub_jutsu.is_empty() else null
	_check(sacrifice.ok and new_sub != null and new_sub.rank == R.A, "T13 sacrifice rolls one rank higher (B -> A)")
	_check(not sacrificer.owned_sub_jutsu.has(b_sub) and not sacrificer.knows(b_sub), "T14 sacrifice really removes the old sub-jutsu")
	var top: CharacterProfile = CharacterProfile.from_dict(clanless.to_dict())
	top.owned_sub_jutsu = [_sub_of_rank(R.S, 0)] as Array[StringName]
	_check(service.resolve_sub_jutsu_evolution(top, false, true).error == &"NO_HIGHER_RANK"
		and SubJutsuRollService.higher_rank(R.S) == -1, "rank S has no higher rank (no SS invented)")
	_check(service.resolve_sub_jutsu_evolution(keeper, true).error == &"CHOICE_NOT_AVAILABLE", "evolution can't be resolved twice")
	var roll_service := SubJutsuRollService.new(db, 7)
	var ranks: Array[int] = [R.B]
	for i in 20:
		var sub: SubJutsuData = roll_service.roll(clanless, ranks)
		if sub == null or sub.rank != R.B or clanless.owned_sub_jutsu.has(sub.id):
			_check(false, "rolls respect rank and never give an owned sub-jutsu")
			break
	_check(service.learn_jutsu(clanless, _sub_of_rank(R.A, 0)).error == &"NOT_LEARNABLE", "sub-jutsu can't be learned directly")


# Tests 15-16 + spending rules.
func _tenketsu_tests() -> void:
	var p := _profile(G.GENIN)
	_check(p.tenketsu_earned == 2, "Genin starts with its first 2 Tenketsu points")
	var ok: bool = true
	for g in range(G.CHUNIN, G.JONIN + 1):
		var before: int = p.tenketsu_earned
		service.promote(p)
		ProgressionDebug.auto_choose(service, p)
		ok = ok and p.tenketsu_earned - before == 2
	_check(ok, "T15 every grade gives exactly +2 Tenketsu")
	_check(p.tenketsu_earned == 10 and service.tenketsu.available_points(p) == 10, "T16 a Jonin has earned 10 points in total")
	var t := service.tenketsu
	_check(t.unlock(p, &"tenketsu_regeneration").error == &"MISSING_PREREQUISITE", "Tenketsu prerequisites enforced")
	for i in 3:
		t.unlock(p, &"tenketsu_vitality")
	_check(t.unlock(p, &"tenketsu_vitality").error == &"MAX_LEVEL", "Tenketsu max level enforced")
	t.unlock(p, &"tenketsu_regeneration")
	t.unlock(p, &"tenketsu_regeneration")
	for i in 3:
		t.unlock(p, &"tenketsu_flow")
	_check(t.unlock(p, &"tenketsu_iron_body").ok and t.available_points(p) == 0, "all 10 points spent")
	_check(t.unlock(p, &"tenketsu_agility").error == &"NOT_ENOUGH_POINTS", "cannot overspend Tenketsu")
	var bonus: Dictionary = t.stat_bonuses(p)
	_check(is_equal_approx(float(bonus.get(&"hp", 0.0)), 24.0), "Tenketsu stat bonuses add up")
	_check(service.max_resources(p).hp > db.get_grade(G.JONIN).base_hp, "max HP = grade base + Tenketsu")


# Tests 17-20.
func _specialization_and_nature_tests() -> void:
	var genin := _profile(G.GENIN)
	_check(service.choose_specialization(genin, &"medic").error == &"CHOICE_NOT_AVAILABLE", "Genin can't pick a specialization")
	var created: CharacterProfile = service.create_character("c", "c", &"konoha", ProgressionTypes.Origin.CLANLESS).profile
	service.choose_primary_nature(created, &"katon")
	service.promote(created)
	_check(created.pending_choices.has(ProgressionTypes.Choice.SPECIALIZATION), "Chunin is asked for a specialization")
	_check(service.choose_specialization(created, &"bulwark").ok and created.specialization_id == &"bulwark", "T17 a Chunin selects a specialization")
	_check(service.choose_specialization(created, &"medic").error == &"CHOICE_NOT_AVAILABLE" and created.specialization_id == &"bulwark",
		"T18 only one specialization")
	var bulwark: SpecializationData = db.get_specialization(&"bulwark")
	_check(created.knows(bulwark.passive_skill.id) and created.knows(bulwark.active_skills[0].id), "specialization skills are granted")
	var tokubetsu := _profile(G.TOKUBETSU)
	_check(tokubetsu.primary_nature != &"" and tokubetsu.secondary_nature != &"", "T19 a Tokubetsu can own two natures")
	var g2: CharacterProfile = service.create_character("g", "g", &"kiri", ProgressionTypes.Origin.CLANLESS).profile
	service.choose_primary_nature(g2, &"suiton")
	_check(service.choose_secondary_nature(g2, &"katon").error == &"CHOICE_NOT_AVAILABLE" and g2.secondary_nature == &"",
		"T20 a Genin can't get a second nature")
	_check(service.choose_primary_nature(g2, &"raiton").error == &"CHOICE_NOT_AVAILABLE" and g2.primary_nature == &"suiton",
		"primary nature is permanent")
	var t2: CharacterProfile = _profile(G.CHUNIN)
	service.promote(t2)
	service.promote(t2)
	_check(service.choose_secondary_nature(t2, t2.primary_nature).error == &"SAME_AS_PRIMARY", "second nature differs from the first")


func _robustness_tests() -> void:
	var p := _profile(G.TOKUBETSU, false)
	service.learn_jutsu(p, _nature_jutsu(p.primary_nature, R.C, 1))
	_check(service.equip_jutsu(p, _nature_jutsu(p.primary_nature, R.C, 1)).ok, "learned technique can be equipped")
	_check(service.equip_jutsu(p, _nature_jutsu(p.primary_nature, R.B, 0)).error == &"NOT_LEARNED", "learned and equipped are separate")
	var passive_id: StringName = db.specializations[0].passive_skill.id
	_check(service.equip_jutsu(p, passive_id).error == &"PASSIVE_NOT_EQUIPPABLE", "passives are not equipped")
	# Slot placement (combat menu): place, swap, append, bounds.
	var c1: StringName = _nature_jutsu(p.primary_nature, R.C, 1)
	var d0: StringName = _nature_jutsu(p.primary_nature, R.D, 0)
	service.learn_jutsu(p, d0)
	_check(service.equip_jutsu_at(p, d0, 0).ok and p.equipped_jutsu == ([d0] as Array[StringName]),
		"equip_jutsu_at replaces the slot's technique")
	_check(service.equip_jutsu_at(p, c1, 4).ok and p.equipped_jutsu == ([d0, c1] as Array[StringName]), "past the bar: appended")
	_check(service.equip_jutsu_at(p, c1, 0).ok and p.equipped_jutsu == ([c1, d0] as Array[StringName]), "already equipped: slots swap")
	_check(service.equip_jutsu_at(p, c1, 6).error == &"INVALID_SLOT", "slot out of range refused")
	_check(service.equip_jutsu_at(p, passive_id, 0).error == &"PASSIVE_NOT_EQUIPPABLE", "passives can't be placed")
	_check(ProgressionAuthority.new(service).handle_request(p, {"action": "equip_jutsu_at", "jutsu": d0, "slot": 0}).ok
		and p.equipped_jutsu == ([d0, c1] as Array[StringName]), "authority handles equip_jutsu_at")
	# Save / load roundtrip.
	var saves := ProgressionSaveService.new("user://test_profiles")
	saves.save_profile(p)
	var loaded: CharacterProfile = saves.load_profile(p.character_id)
	_check(loaded != null and loaded.to_dict() == p.to_dict(), "profile save / load roundtrip is lossless")
	saves.delete_profile(p.character_id)
	# Server authority: requests are validated, unknown / promotion requests refused.
	var authority := ProgressionAuthority.new(service)
	_check(authority.handle_request(p, {"action": "promote"}).error == &"UNKNOWN_ACTION", "clients can't request promotions")
	_check(not authority.handle_request(p, {"action": "learn_jutsu", "jutsu": _nature_jutsu(p.primary_nature, R.S, 0)}).ok,
		"authority validates learn requests")
	_check(authority.handle_request(p, {"action": "learn_jutsu", "jutsu": _nature_jutsu(p.primary_nature, R.A, 1)}).ok,
		"authority applies a valid request")
	# Admin tools.
	var admin := ProgressionAdmin.new(service)
	var fresh: CharacterProfile = service.create_character("a", "a", &"ame", ProgressionTypes.Origin.CLANLESS).profile
	admin.set_grade(fresh, G.JONIN)
	_check(fresh.grade == G.JONIN and fresh.tenketsu_earned == 10, "admin set_grade promotes with rewards")
	_check(admin.add_tenketsu_points(fresh, 3).ok and fresh.tenketsu_earned == 13, "admin adds Tenketsu points")
	admin.give_sub_jutsu(fresh, _sub_of_rank(R.S, 1))
	admin.remove_sub_jutsu(fresh, _sub_of_rank(R.S, 1))
	_check(not fresh.owned_sub_jutsu.has(_sub_of_rank(R.S, 1)), "admin gives / removes sub-jutsu")
	_check(admin.inspect(fresh).contains("JONIN"), "admin inspect")
	_check(ProgressionDebug.run_command(service, _profile(G.GENIN), "promote_to_konin").ok, "debug promote_to_konin")
	# Rewards are never granted twice.
	var twice := _profile(G.CHUNIN)
	admin.set_grade(twice, G.GENIN)
	admin.set_grade(twice, G.CHUNIN)
	_check(twice.tenketsu_earned == 4, "grade rewards are not granted twice")
	_check(service.promote(_profile(G.JONIN)).error == &"MAX_GRADE", "no grade above Jonin")


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   ", label)
	else:
		_failures += 1
		print("  FAIL ", label)
