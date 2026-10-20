class_name ProgressionAdmin
extends RefCounted
## Server administration tools, separate from the player actions. They skip
## the normal choice flow on purpose but still keep the data consistent.

var service: ProgressionService


func _init(progression: ProgressionService) -> void:
	service = progression


## Raises the grade step by step (rewards included) or lowers it (no refund).
func set_grade(profile: CharacterProfile, grade: int) -> ProgressionResult:
	if not ProgressionTypes.is_valid_grade(grade):
		return ProgressionResult.fail(&"UNKNOWN_GRADE")
	var result := ProgressionResult.success()
	while profile.grade < grade:
		result.events.append_array(service.promote(profile).events)
	if profile.grade > grade:
		profile.grade = grade as ProgressionTypes.Grade
		result.add_event(&"admin_demoted", {"grade": grade})
	return result


func add_jutsu(profile: CharacterProfile, jutsu_id: StringName) -> ProgressionResult:
	var jutsu: JutsuData = service.db.get_jutsu(jutsu_id)
	if jutsu == null:
		return ProgressionResult.fail(&"UNKNOWN_JUTSU")
	if jutsu is SubJutsuData:
		service.grant_sub_jutsu(profile, jutsu_id)
	elif not profile.learned_jutsu.has(jutsu_id):
		profile.learned_jutsu.append(jutsu_id)
		if jutsu.source == ProgressionTypes.JutsuSource.NATURE:
			if not profile.nature_choices.has(jutsu.owner_id):
				profile.nature_choices[jutsu.owner_id] = {}
			profile.nature_choices[jutsu.owner_id][jutsu.rank] = jutsu_id
	return ProgressionResult.success()


func remove_jutsu(profile: CharacterProfile, jutsu_id: StringName) -> ProgressionResult:
	if not profile.knows(jutsu_id):
		return ProgressionResult.fail(&"NOT_LEARNED")
	profile.learned_jutsu.erase(jutsu_id)
	profile.equipped_jutsu.erase(jutsu_id)
	profile.owned_sub_jutsu.erase(jutsu_id)
	var jutsu: JutsuData = service.db.get_jutsu(jutsu_id)
	if jutsu != null and jutsu.source == ProgressionTypes.JutsuSource.NATURE \
			and profile.nature_choice(jutsu.owner_id, jutsu.rank) == jutsu_id:
		(profile.nature_choices[jutsu.owner_id] as Dictionary).erase(jutsu.rank)  # frees the rank choice
	return ProgressionResult.success()


func give_sub_jutsu(profile: CharacterProfile, sub_id: StringName) -> ProgressionResult:
	if service.db.get_sub_jutsu(sub_id) == null:
		return ProgressionResult.fail(&"UNKNOWN_SUB_JUTSU")
	service.grant_sub_jutsu(profile, sub_id)
	return ProgressionResult.success()


func remove_sub_jutsu(profile: CharacterProfile, sub_id: StringName) -> ProgressionResult:
	if not profile.owned_sub_jutsu.has(sub_id):
		return ProgressionResult.fail(&"NOT_OWNED")
	return remove_jutsu(profile, sub_id)


## slot: "primary" or "secondary". Techniques of the old nature are kept.
func set_nature(profile: CharacterProfile, slot: String, nature_id: StringName) -> ProgressionResult:
	if nature_id != &"" and service.db.get_nature(nature_id) == null:
		return ProgressionResult.fail(&"UNKNOWN_NATURE")
	if slot == "primary":
		profile.primary_nature = nature_id
		profile.pending_choices.erase(ProgressionTypes.Choice.PRIMARY_NATURE)
	elif slot == "secondary":
		profile.secondary_nature = nature_id
		profile.pending_choices.erase(ProgressionTypes.Choice.SECONDARY_NATURE)
	else:
		return ProgressionResult.fail(&"UNKNOWN_SLOT")
	return ProgressionResult.success()


func add_tenketsu_points(profile: CharacterProfile, amount: int) -> ProgressionResult:
	profile.tenketsu_earned = maxi(0, profile.tenketsu_earned + amount)
	return ProgressionResult.success()


func reset_tenketsu(profile: CharacterProfile) -> ProgressionResult:
	service.tenketsu.reset(profile)
	return ProgressionResult.success()


## Moves the character to a clan (or clanless with &"").
func set_clan(profile: CharacterProfile, clan_id: StringName) -> ProgressionResult:
	if clan_id == &"":
		profile.origin = ProgressionTypes.Origin.CLANLESS
		profile.clan_id = &""
		return ProgressionResult.success()
	var clan: ClanData = service.db.get_clan(clan_id)
	if clan == null:
		return ProgressionResult.fail(&"UNKNOWN_CLAN")
	profile.origin = ProgressionTypes.Origin.CLAN
	profile.clan_id = clan_id
	return ProgressionResult.success()


## Human-readable build summary.
func inspect(profile: CharacterProfile) -> String:
	var db: ProgressionDatabase = service.db
	var lines: PackedStringArray = []
	lines.append("%s (%s) — %s, %s%s" % [profile.character_name, profile.character_id, profile.village_id,
		ProgressionTypes.grade_key(profile.grade), "" if not profile.is_clan() else ", clan " + String(profile.clan_id)])
	lines.append("Natures: %s / %s" % [profile.primary_nature, profile.secondary_nature])
	for nature: StringName in profile.nature_choices:
		var picks: PackedStringArray = []
		for rank: int in profile.nature_choices[nature]:
			picks.append("%s=%s" % [ProgressionTypes.rank_key(rank), profile.nature_choices[nature][rank]])
		lines.append("  %s: %s" % [nature, ", ".join(picks)])
	lines.append("Specialization: %s" % profile.specialization_id)
	lines.append("Learned: %s" % ", ".join(profile.learned_jutsu.map(func(id: StringName) -> String: return String(id))))
	lines.append("Equipped: %s" % ", ".join(profile.equipped_jutsu.map(func(id: StringName) -> String: return String(id))))
	lines.append("Sub-jutsu: %s" % ", ".join(profile.owned_sub_jutsu.map(func(id: StringName) -> String: return String(id))))
	lines.append("Tenketsu: %d earned, %d available, nodes %s" % [profile.tenketsu_earned,
		service.tenketsu.available_points(profile), profile.tenketsu_levels])
	lines.append("Pending: %s" % ", ".join(profile.pending_choices.map(func(c: int) -> String: return ProgressionTypes.Choice.keys()[c])))
	lines.append("Resources: %s" % service.max_resources(profile))
	if db.get_clan(profile.clan_id) != null and profile.origin == ProgressionTypes.Origin.CLANLESS:
		lines.append("WARNING: clanless with a clan id")
	return "\n".join(lines)
