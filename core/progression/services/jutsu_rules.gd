class_name JutsuRules
## Pure rules: what a profile may learn and how a tree node should look.
## No state changes here (see ProgressionService).


## Highest rank the profile's grade gives access to.
static func max_rank(db: ProgressionDatabase, profile: CharacterProfile) -> int:
	var g: GradeData = db.get_grade(profile.grade)
	return g.max_jutsu_rank if g != null else -1


static func rank_allowed(db: ProgressionDatabase, profile: CharacterProfile, rank: int) -> bool:
	return rank <= max_rank(db, profile)


## True if some grade up to the current one granted `choice`.
static func grade_granted(db: ProgressionDatabase, profile: CharacterProfile, choice: int) -> bool:
	for g in range(profile.grade + 1):
		var data: GradeData = db.get_grade(g)
		if data != null and data.granted_choices.has(choice):
			return true
	return false


## Central check for learning a tree technique (nature or clan).
## Specialization skills and sub-jutsu are granted, not learned.
static func can_learn(db: ProgressionDatabase, profile: CharacterProfile, jutsu: JutsuData) -> ProgressionResult:
	if jutsu == null:
		return ProgressionResult.fail(&"UNKNOWN_JUTSU")
	if profile.knows(jutsu.id):
		return ProgressionResult.fail(&"ALREADY_LEARNED")
	match jutsu.source:
		ProgressionTypes.JutsuSource.NATURE:
			if not profile.has_nature(jutsu.owner_id):
				return ProgressionResult.fail(&"NATURE_NOT_OWNED")
			if profile.nature_choice(jutsu.owner_id, jutsu.rank) != &"":
				return ProgressionResult.fail(&"RANK_ALREADY_CHOSEN", "Only one technique per rank and nature.")
		ProgressionTypes.JutsuSource.CLAN:
			if not profile.is_clan() or profile.clan_id != jutsu.owner_id:
				return ProgressionResult.fail(&"NOT_IN_CLAN")
		_:
			return ProgressionResult.fail(&"NOT_LEARNABLE", "This technique is granted, not learned.")
	if not rank_allowed(db, profile, jutsu.rank):
		return ProgressionResult.fail(&"RANK_LOCKED_BY_GRADE")
	for req: StringName in jutsu.requirements:
		if not profile.knows(req):
			return ProgressionResult.fail(&"MISSING_REQUIREMENT", "Requires %s." % req)
	return ProgressionResult.success()


## UI state of a technique node in a nature or clan tree.
static func node_state(db: ProgressionDatabase, profile: CharacterProfile, jutsu: JutsuData) -> ProgressionTypes.NodeState:
	if profile.knows(jutsu.id):
		return ProgressionTypes.NodeState.SELECTED if jutsu.source == ProgressionTypes.JutsuSource.NATURE else ProgressionTypes.NodeState.UNLOCKED
	if jutsu.source == ProgressionTypes.JutsuSource.NATURE and profile.nature_choice(jutsu.owner_id, jutsu.rank) != &"":
		return ProgressionTypes.NodeState.LOCKED_BY_CHOICE
	if not rank_allowed(db, profile, jutsu.rank):
		return ProgressionTypes.NodeState.LOCKED_GRADE
	return ProgressionTypes.NodeState.AVAILABLE
