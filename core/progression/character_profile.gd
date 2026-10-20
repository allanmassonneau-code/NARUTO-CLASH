class_name CharacterProfile
extends RefCounted
## Persistent progression state of one character. Pure data: every change
## goes through the progression services (server side), never directly.
## Serialized by id only (techniques, natures, clans...), never by name.

const SAVE_VERSION: int = 1

# Identity
var character_id: String = ""
var character_name: String = ""

# Origin
var village_id: StringName = &""
var origin: ProgressionTypes.Origin = ProgressionTypes.Origin.CLANLESS
var clan_id: StringName = &""

# Progression
var grade: ProgressionTypes.Grade = ProgressionTypes.Grade.GENIN
## Grades whose rewards were already granted (rewards are never applied twice).
var rewarded_grades: Array[int] = []
## Choices granted by grades and not made yet (ProgressionTypes.Choice).
var pending_choices: Array[int] = []
## Experience gathered in the current grade.
var xp: int = 0

# Chakra natures
var primary_nature: StringName = &""
var secondary_nature: StringName = &""
## Irreversible tree choices: nature id -> {rank (int) -> jutsu id}.
var nature_choices: Dictionary = {}

# Specialization
var specialization_id: StringName = &""

# Techniques
var learned_jutsu: Array[StringName] = []
var equipped_jutsu: Array[StringName] = []

# Sub-jutsu (clanless)
var owned_sub_jutsu: Array[StringName] = []

# Appearance (SS character creator, cosmetic only): see SSAvatars.
var appearance: Dictionary = {}

# Tenketsu
var tenketsu_earned: int = 0
## Node id -> level.
var tenketsu_levels: Dictionary = {}


func is_clan() -> bool:
	return origin == ProgressionTypes.Origin.CLAN


func knows(jutsu_id: StringName) -> bool:
	return learned_jutsu.has(jutsu_id)


func has_nature(nature_id: StringName) -> bool:
	return nature_id != &"" and (primary_nature == nature_id or secondary_nature == nature_id)


func nature_choice(nature_id: StringName, rank: int) -> StringName:
	return (nature_choices.get(nature_id, {}) as Dictionary).get(rank, &"")


func to_dict() -> Dictionary:
	var choices: Dictionary = {}
	for nature: StringName in nature_choices:
		var per_rank: Dictionary = {}
		for rank: int in nature_choices[nature]:
			per_rank[ProgressionTypes.rank_key(rank)] = String(nature_choices[nature][rank])
		choices[String(nature)] = per_rank
	return {
		"version": SAVE_VERSION,
		"identity": {"character_id": character_id, "character_name": character_name},
		"origin": {"village": String(village_id), "clan_status": ProgressionTypes.Origin.keys()[origin], "clan_id": String(clan_id)},
		"progression": {
			"grade": ProgressionTypes.grade_key(grade),
			"rewarded_grades": rewarded_grades.map(func(g: int) -> String: return ProgressionTypes.grade_key(g)),
			"pending_choices": pending_choices.map(func(c: int) -> String: return ProgressionTypes.Choice.keys()[c]),
			"xp": xp,
		},
		"chakra": {"primary_nature": String(primary_nature), "secondary_nature": String(secondary_nature), "nature_choices": choices},
		"specialization": String(specialization_id),
		"skills": {"learned": _strings(learned_jutsu), "equipped": _strings(equipped_jutsu)},
		"sub_jutsu": _strings(owned_sub_jutsu),
		"tenketsu": {"earned": tenketsu_earned, "levels": tenketsu_levels.duplicate()},
	}


static func from_dict(data: Dictionary) -> CharacterProfile:
	data = migrate(data)
	var p := CharacterProfile.new()
	var identity: Dictionary = data.get("identity", {})
	p.character_id = identity.get("character_id", "")
	p.character_name = identity.get("character_name", "")
	var origin_data: Dictionary = data.get("origin", {})
	p.village_id = StringName(origin_data.get("village", ""))
	p.origin = ProgressionTypes.Origin.get(origin_data.get("clan_status", "CLANLESS"), ProgressionTypes.Origin.CLANLESS)
	p.clan_id = StringName(origin_data.get("clan_id", ""))
	var prog: Dictionary = data.get("progression", {})
	p.grade = ProgressionTypes.Grade.get(prog.get("grade", "GENIN"), ProgressionTypes.Grade.GENIN)
	for g: String in prog.get("rewarded_grades", []):
		if ProgressionTypes.Grade.has(g):
			p.rewarded_grades.append(ProgressionTypes.Grade[g])
	for c: String in prog.get("pending_choices", []):
		if ProgressionTypes.Choice.has(c):
			p.pending_choices.append(ProgressionTypes.Choice[c])
	p.xp = int(prog.get("xp", 0))
	var chakra: Dictionary = data.get("chakra", {})
	p.primary_nature = StringName(chakra.get("primary_nature", ""))
	p.secondary_nature = StringName(chakra.get("secondary_nature", ""))
	var choices: Dictionary = chakra.get("nature_choices", {})
	for nature: String in choices:
		var per_rank: Dictionary = {}
		for rank_key: String in choices[nature]:
			if ProgressionTypes.Rank.has(rank_key):
				per_rank[ProgressionTypes.Rank[rank_key]] = StringName(choices[nature][rank_key])
		p.nature_choices[StringName(nature)] = per_rank
	p.specialization_id = StringName(data.get("specialization", ""))
	var skills: Dictionary = data.get("skills", {})
	p.learned_jutsu = _names(skills.get("learned", []))
	p.equipped_jutsu = _names(skills.get("equipped", []))
	p.owned_sub_jutsu = _names(data.get("sub_jutsu", []))
	var look: Variant = data.get("appearance", {})
	p.appearance = sanitize_appearance(look if look is Dictionary else {})
	var tenketsu: Dictionary = data.get("tenketsu", {})
	p.tenketsu_earned = int(tenketsu.get("earned", 0))
	var levels: Dictionary = tenketsu.get("levels", {})
	for node_id: Variant in levels:
		p.tenketsu_levels[StringName(str(node_id))] = int(levels[node_id])
	return p


## Keeps only known appearance keys with short string values (cosmetic data from clients).
static func sanitize_appearance(data: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: String in ["sex", "hair", "upper", "lower", "skin", "forehead", "accessory", "eye", "eye_color", "facepaint", "facepaint_color"]:
		if data.get(key) is String and (data[key] as String).length() <= 64:
			out[key] = data[key]
	for key: String in ["hair_colors", "upper_colors", "lower_colors"]:
		var ids: Variant = data.get(key)
		if ids is Array and (ids as Array).size() == 2:
			out[key] = [str(ids[0]).left(64), str(ids[1]).left(64)]
	return out


## Upgrades older save formats to SAVE_VERSION (one step per version).
static func migrate(data: Dictionary) -> Dictionary:
	var version: int = int(data.get("version", 1))
	while version < SAVE_VERSION:
		# match version: add a step here when the format changes.
		version += 1
	data["version"] = version
	return data


static func _strings(ids: Array[StringName]) -> Array:
	return ids.map(func(id: StringName) -> String: return String(id))


static func _names(values: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for v: Variant in values:
		out.append(StringName(str(v)))
	return out
