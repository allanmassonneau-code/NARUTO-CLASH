class_name ProgressionDebug
## Test characters: build a profile at any grade (clan or clanless), making
## every pending choice automatically, and step-by-step promotions.


## Makes the pending choices with the first valid option (deterministic).
static func auto_choose(service: ProgressionService, profile: CharacterProfile) -> void:
	var db: ProgressionDatabase = service.db
	for choice: int in profile.pending_choices.duplicate():
		match choice:
			ProgressionTypes.Choice.PRIMARY_NATURE:
				service.choose_primary_nature(profile, db.natures[0].id)
			ProgressionTypes.Choice.SECONDARY_NATURE:
				service.choose_secondary_nature(profile, db.natures[1].id)
			ProgressionTypes.Choice.SPECIALIZATION:
				service.choose_specialization(profile, db.specializations[0].id)
			ProgressionTypes.Choice.SUB_JUTSU_EVOLUTION:
				service.resolve_sub_jutsu_evolution(profile, true)


static func make_test_profile(service: ProgressionService, grade: int, clan: bool) -> CharacterProfile:
	var db: ProgressionDatabase = service.db
	var village: StringName = db.villages[0].id
	var clan_id: StringName = &""
	if clan:
		clan_id = db.clans_of_village(village)[0].id
	var origin: ProgressionTypes.Origin = ProgressionTypes.Origin.CLAN if clan else ProgressionTypes.Origin.CLANLESS
	var created: Dictionary = service.create_character("test_%s_%s" % [ProgressionTypes.grade_key(grade).to_lower(),
		"clan" if clan else "clanless"], "Test", village, origin, clan_id)
	var profile: CharacterProfile = created.profile
	auto_choose(service, profile)
	while profile.grade < grade:
		service.promote(profile)
		auto_choose(service, profile)
	return profile


## Console-style commands: "promote_to_chunin" ... "promote_to_jonin".
static func run_command(service: ProgressionService, profile: CharacterProfile, command: String) -> ProgressionResult:
	if not command.begins_with("promote_to_"):
		return ProgressionResult.fail(&"UNKNOWN_COMMAND")
	var key: String = command.trim_prefix("promote_to_").to_upper()
	if not ProgressionTypes.Grade.has(key):
		return ProgressionResult.fail(&"UNKNOWN_GRADE")
	return ProgressionAdmin.new(service).set_grade(profile, ProgressionTypes.Grade[key])
