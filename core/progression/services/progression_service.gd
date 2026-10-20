class_name ProgressionService
extends RefCounted
## Authoritative progression actions: character creation, promotions and
## their rewards, natures, specialization, learning / equipping techniques,
## sub-jutsu events. Validates everything; runs on the server (or offline).
## Read-only rules live in JutsuRules, Tenketsu in TenketsuService.

var db: ProgressionDatabase
var rolls: SubJutsuRollService
var tenketsu: TenketsuService


func _init(database: ProgressionDatabase, roll_service: SubJutsuRollService = null) -> void:
	db = database
	rolls = roll_service if roll_service != null else SubJutsuRollService.new(database)
	tenketsu = TenketsuService.new(database)


# --- Creation & grades --------------------------------------------------------

## New Genin. Clan characters must pick a clan of their village.
func create_character(character_id: String, character_name: String, village_id: StringName,
		origin: ProgressionTypes.Origin, clan_id: StringName = &"") -> Dictionary:
	if db.get_village(village_id) == null:
		return {"profile": null, "result": ProgressionResult.fail(&"UNKNOWN_VILLAGE")}
	if origin == ProgressionTypes.Origin.CLAN:
		var clan: ClanData = db.get_clan(clan_id)
		if clan == null:
			return {"profile": null, "result": ProgressionResult.fail(&"UNKNOWN_CLAN")}
		if clan.village_id != village_id:
			return {"profile": null, "result": ProgressionResult.fail(&"CLAN_NOT_IN_VILLAGE")}
	elif clan_id != &"":
		return {"profile": null, "result": ProgressionResult.fail(&"CLANLESS_WITH_CLAN")}
	var profile := CharacterProfile.new()
	profile.character_id = character_id
	profile.character_name = character_name
	profile.village_id = village_id
	profile.origin = origin
	profile.clan_id = clan_id
	profile.grade = ProgressionTypes.Grade.GENIN
	var result := ProgressionResult.success()
	_apply_grade_rewards(profile, ProgressionTypes.Grade.GENIN, result)
	return {"profile": profile, "result": result}


## Experience (mob kills...). Reaching the grade's threshold promotes and
## keeps the surplus. Server / offline authority only.
func grant_xp(profile: CharacterProfile, amount: int) -> ProgressionResult:
	var result := ProgressionResult.success()
	if amount <= 0:
		return result
	profile.xp += amount
	result.add_event(&"xp_gained", {"amount": amount})
	while true:
		var data: GradeData = db.get_grade(profile.grade)
		if data == null or data.xp_to_next <= 0 or profile.xp < data.xp_to_next:
			break
		profile.xp -= data.xp_to_next
		result.events.append_array(promote(profile).events)
	var top: GradeData = db.get_grade(profile.grade)
	if top != null and top.xp_to_next <= 0:
		profile.xp = 0  # top grade: nothing more to gather
	return result


## Promotes to the next grade and grants its rewards.
func promote(profile: CharacterProfile) -> ProgressionResult:
	var next: int = db.next_grade(profile.grade)
	if next < 0:
		return ProgressionResult.fail(&"MAX_GRADE")
	profile.grade = next as ProgressionTypes.Grade
	var result := ProgressionResult.success()
	result.add_event(&"promoted", {"grade": next})
	_apply_grade_rewards(profile, next, result)
	return result


## Rewards of reaching `grade` (applied once per grade, data-driven).
func _apply_grade_rewards(profile: CharacterProfile, grade: int, result: ProgressionResult) -> void:
	if profile.rewarded_grades.has(grade):
		return
	profile.rewarded_grades.append(grade)
	var data: GradeData = db.get_grade(grade)
	if data == null:
		return
	profile.tenketsu_earned += data.tenketsu_points
	result.add_event(&"tenketsu_points", {"amount": data.tenketsu_points})
	result.add_event(&"rank_access", {"max_rank": data.max_jutsu_rank})
	for choice: int in data.granted_choices:
		if not profile.pending_choices.has(choice):
			profile.pending_choices.append(choice)
			result.add_event(&"choice_required", {"choice": choice})
	if profile.is_clan():
		return  # sub-jutsu are the clanless counterpart of the clan tree
	match data.sub_jutsu_event:
		ProgressionTypes.SubJutsuEvent.FIRST_ROLL:
			_grant_roll(profile, db.sub_jutsu_roll_ranks, result)
		ProgressionTypes.SubJutsuEvent.EVOLUTION:
			profile.pending_choices.append(ProgressionTypes.Choice.SUB_JUTSU_EVOLUTION)
			result.add_event(&"choice_required", {"choice": ProgressionTypes.Choice.SUB_JUTSU_EVOLUTION})


# --- Natures --------------------------------------------------------------------

func choose_primary_nature(profile: CharacterProfile, nature_id: StringName) -> ProgressionResult:
	if not profile.pending_choices.has(ProgressionTypes.Choice.PRIMARY_NATURE):
		return ProgressionResult.fail(&"CHOICE_NOT_AVAILABLE")
	if db.get_nature(nature_id) == null:
		return ProgressionResult.fail(&"UNKNOWN_NATURE")
	profile.primary_nature = nature_id
	profile.pending_choices.erase(ProgressionTypes.Choice.PRIMARY_NATURE)
	var result := ProgressionResult.success()
	result.add_event(&"nature_chosen", {"slot": "primary", "nature": nature_id})
	return result


func choose_secondary_nature(profile: CharacterProfile, nature_id: StringName) -> ProgressionResult:
	if not profile.pending_choices.has(ProgressionTypes.Choice.SECONDARY_NATURE):
		return ProgressionResult.fail(&"CHOICE_NOT_AVAILABLE")
	if db.get_nature(nature_id) == null:
		return ProgressionResult.fail(&"UNKNOWN_NATURE")
	if profile.primary_nature == &"":
		return ProgressionResult.fail(&"PRIMARY_NATURE_FIRST")
	if nature_id == profile.primary_nature:
		return ProgressionResult.fail(&"SAME_AS_PRIMARY")
	profile.secondary_nature = nature_id
	profile.pending_choices.erase(ProgressionTypes.Choice.SECONDARY_NATURE)
	var result := ProgressionResult.success()
	result.add_event(&"nature_chosen", {"slot": "secondary", "nature": nature_id})
	return result


# --- Specialization ----------------------------------------------------------

func choose_specialization(profile: CharacterProfile, specialization_id: StringName) -> ProgressionResult:
	if not profile.pending_choices.has(ProgressionTypes.Choice.SPECIALIZATION):
		return ProgressionResult.fail(&"CHOICE_NOT_AVAILABLE")
	var spec: SpecializationData = db.get_specialization(specialization_id)
	if spec == null:
		return ProgressionResult.fail(&"UNKNOWN_SPECIALIZATION")
	profile.specialization_id = specialization_id
	profile.pending_choices.erase(ProgressionTypes.Choice.SPECIALIZATION)
	var result := ProgressionResult.success()
	result.add_event(&"specialization_chosen", {"specialization": specialization_id})
	if db.specialization_grants_skills:
		for skill: JutsuData in spec.all_skills():
			_add_learned(profile, skill.id)
	return result


# --- Techniques -------------------------------------------------------------------

## Learns a nature or clan technique (records the irreversible rank choice).
func learn_jutsu(profile: CharacterProfile, jutsu_id: StringName) -> ProgressionResult:
	var jutsu: JutsuData = db.get_jutsu(jutsu_id)
	var check: ProgressionResult = JutsuRules.can_learn(db, profile, jutsu)
	if not check.ok:
		return check
	if jutsu.source == ProgressionTypes.JutsuSource.NATURE:
		if not profile.nature_choices.has(jutsu.owner_id):
			profile.nature_choices[jutsu.owner_id] = {}
		profile.nature_choices[jutsu.owner_id][jutsu.rank] = jutsu.id
	_add_learned(profile, jutsu.id)
	check.add_event(&"jutsu_learned", {"jutsu": jutsu.id})
	return check


## Equipping is separate from owning: only learned techniques, limited slots.
func equip_jutsu(profile: CharacterProfile, jutsu_id: StringName) -> ProgressionResult:
	if not profile.knows(jutsu_id):
		return ProgressionResult.fail(&"NOT_LEARNED")
	if profile.equipped_jutsu.has(jutsu_id):
		return ProgressionResult.fail(&"ALREADY_EQUIPPED")
	var jutsu: JutsuData = db.get_jutsu(jutsu_id)
	if jutsu != null and jutsu.passive:
		return ProgressionResult.fail(&"PASSIVE_NOT_EQUIPPABLE")
	if profile.equipped_jutsu.size() >= db.max_equipped_jutsu:
		return ProgressionResult.fail(&"NO_FREE_SLOT")
	profile.equipped_jutsu.append(jutsu_id)
	var result := ProgressionResult.success()
	result.add_event(&"jutsu_equipped", {"jutsu": jutsu_id})
	return result


func unequip_jutsu(profile: CharacterProfile, jutsu_id: StringName) -> ProgressionResult:
	if not profile.equipped_jutsu.has(jutsu_id):
		return ProgressionResult.fail(&"NOT_EQUIPPED")
	profile.equipped_jutsu.erase(jutsu_id)
	var result := ProgressionResult.success()
	result.add_event(&"loadout_changed", {})
	return result


## Puts a technique in bar slot `slot` (0-based). Already equipped elsewhere:
## the two slots swap. Slot past the end of the bar: appended.
func equip_jutsu_at(profile: CharacterProfile, jutsu_id: StringName, slot: int) -> ProgressionResult:
	if not profile.knows(jutsu_id):
		return ProgressionResult.fail(&"NOT_LEARNED")
	var jutsu: JutsuData = db.get_jutsu(jutsu_id)
	if jutsu != null and jutsu.passive:
		return ProgressionResult.fail(&"PASSIVE_NOT_EQUIPPABLE")
	if slot < 0 or slot >= db.max_equipped_jutsu:
		return ProgressionResult.fail(&"INVALID_SLOT")
	var bar: Array[StringName] = profile.equipped_jutsu
	var current: int = bar.find(jutsu_id)
	if current == slot:
		return ProgressionResult.fail(&"ALREADY_EQUIPPED")
	if current >= 0:
		if slot < bar.size():
			bar[current] = bar[slot]
			bar[slot] = jutsu_id
		else:
			bar.remove_at(current)
			bar.append(jutsu_id)
	elif slot < bar.size():
		bar[slot] = jutsu_id
	elif bar.size() < db.max_equipped_jutsu:
		bar.append(jutsu_id)
	else:
		return ProgressionResult.fail(&"NO_FREE_SLOT")
	var result := ProgressionResult.success()
	result.add_event(&"loadout_changed", {})
	return result


func _add_learned(profile: CharacterProfile, jutsu_id: StringName) -> void:
	if not profile.learned_jutsu.has(jutsu_id):
		profile.learned_jutsu.append(jutsu_id)


# --- Sub-jutsu ----------------------------------------------------------------------

## Tokubetsu event. keep = keep the current sub-jutsu and roll a new one;
## otherwise sacrifice it (needs `confirmed`) for a roll one rank higher.
func resolve_sub_jutsu_evolution(profile: CharacterProfile, keep: bool, confirmed: bool = false) -> ProgressionResult:
	if not profile.pending_choices.has(ProgressionTypes.Choice.SUB_JUTSU_EVOLUTION):
		return ProgressionResult.fail(&"CHOICE_NOT_AVAILABLE")
	var result := ProgressionResult.success()
	if keep:
		profile.pending_choices.erase(ProgressionTypes.Choice.SUB_JUTSU_EVOLUTION)
		result.add_event(&"sub_jutsu_kept", {"sub_jutsu": profile.owned_sub_jutsu.duplicate()})
		_grant_roll(profile, db.sub_jutsu_roll_ranks, result)
		return result
	var current: SubJutsuData = sacrifice_target(profile)
	if current == null:
		return ProgressionResult.fail(&"NOTHING_TO_SACRIFICE")
	var higher: int = SubJutsuRollService.higher_rank(current.rank)
	if higher < 0:
		return ProgressionResult.fail(&"NO_HIGHER_RANK", "A rank S sub-jutsu has no higher rank.")
	if not confirmed:
		return ProgressionResult.fail(&"CONFIRMATION_REQUIRED")
	_remove_sub_jutsu(profile, current.id)
	profile.pending_choices.erase(ProgressionTypes.Choice.SUB_JUTSU_EVOLUTION)
	result.add_event(&"sub_jutsu_sacrificed", {"sub_jutsu": current.id})
	_grant_roll(profile, [higher] as Array[int], result)
	return result


## The sub-jutsu a sacrifice would remove (the first one obtained).
func sacrifice_target(profile: CharacterProfile) -> SubJutsuData:
	return db.get_sub_jutsu(profile.owned_sub_jutsu[0]) if not profile.owned_sub_jutsu.is_empty() else null


func _grant_roll(profile: CharacterProfile, ranks: Array[int], result: ProgressionResult) -> void:
	var sub: SubJutsuData = rolls.roll(profile, ranks)
	if sub == null:
		result.add_event(&"sub_jutsu_roll_empty", {"ranks": ranks})
		return
	grant_sub_jutsu(profile, sub.id)
	result.add_event(&"sub_jutsu_obtained", {"sub_jutsu": sub.id, "rank": sub.rank})


## Adds a sub-jutsu (rolls and admin grants).
func grant_sub_jutsu(profile: CharacterProfile, sub_id: StringName) -> void:
	if not profile.owned_sub_jutsu.has(sub_id):
		profile.owned_sub_jutsu.append(sub_id)
	_add_learned(profile, sub_id)


func _remove_sub_jutsu(profile: CharacterProfile, sub_id: StringName) -> void:
	profile.owned_sub_jutsu.erase(sub_id)
	profile.learned_jutsu.erase(sub_id)
	profile.equipped_jutsu.erase(sub_id)


# --- Derived stats ------------------------------------------------------------------

## Base HP / chakra of the grade plus Tenketsu bonuses (stats "hp", "chakra").
func max_resources(profile: CharacterProfile) -> Dictionary:
	var data: GradeData = db.get_grade(profile.grade)
	var bonus: Dictionary = tenketsu.stat_bonuses(profile)
	return {
		"hp": (data.base_hp if data != null else 0.0) + float(bonus.get(&"hp", 0.0)),
		"chakra": (data.base_chakra if data != null else 0.0) + float(bonus.get(&"chakra", 0.0)),
	}
