class_name ProgressionDatabase
extends Resource
## Every piece of progression content (grades, villages, natures, clans,
## specializations, Tenketsu, sub-jutsu) plus the open rules that are still
## configuration. Systems only read this; adding content = adding data.

const DEFAULT_PATH: String = "res://data/progression/progression_db.tres"

@export var grades: Array[GradeData] = []
@export var villages: Array[VillageData] = []
@export var natures: Array[ChakraNatureData] = []
@export var clans: Array[ClanData] = []
@export var specializations: Array[SpecializationData] = []
@export var tenketsu_tree: TenketsuTreeData
@export var sub_jutsu: Array[SubJutsuData] = []
## Experience granted per mob kill (mob id -> xp). The server reads it here,
## clients only report which mob they killed.
@export var mob_xp: Dictionary = {}
## Anti-abuse: kills accepted per minute for one character.
@export var max_kills_per_minute: int = 30

@export_category("Open rules (not defined by the design yet)")
## Ranks the Chunin roll and the "keep" roll draw from (weights decide rarity).
@export var sub_jutsu_roll_ranks: Array[int] = [ProgressionTypes.Rank.B, ProgressionTypes.Rank.A, ProgressionTypes.Rank.S]
## Combat slots for equipped techniques (slot system defined later).
@export var max_equipped_jutsu: int = 6
## Choosing a specialization grants its 4 skills right away.
@export var specialization_grants_skills: bool = true

var _jutsu_index: Dictionary = {}


static func load_default() -> ProgressionDatabase:
	return load(DEFAULT_PATH) as ProgressionDatabase


func get_grade(grade: int) -> GradeData:
	for g: GradeData in grades:
		if g.grade == grade:
			return g
	return null


## Next grade in the hierarchy, or -1 at the top.
func next_grade(grade: int) -> int:
	return grade + 1 if ProgressionTypes.is_valid_grade(grade + 1) else -1


func get_village(id: StringName) -> VillageData:
	for v: VillageData in villages:
		if v.id == id:
			return v
	return null


func get_nature(id: StringName) -> ChakraNatureData:
	for n: ChakraNatureData in natures:
		if n.id == id:
			return n
	return null


func get_clan(id: StringName) -> ClanData:
	for c: ClanData in clans:
		if c.id == id:
			return c
	return null


func clans_of_village(village_id: StringName) -> Array[ClanData]:
	var out: Array[ClanData] = []
	for c: ClanData in clans:
		if c.village_id == village_id:
			out.append(c)
	return out


func get_specialization(id: StringName) -> SpecializationData:
	for s: SpecializationData in specializations:
		if s.id == id:
			return s
	return null


func get_tenketsu_node(id: StringName) -> TenketsuNodeData:
	return tenketsu_tree.get_node_data(id) if tenketsu_tree != null else null


## Any technique by id (nature, clan, specialization or sub-jutsu).
func get_jutsu(id: StringName) -> JutsuData:
	if _jutsu_index.is_empty():
		_build_index()
	return _jutsu_index.get(id)


func get_sub_jutsu(id: StringName) -> SubJutsuData:
	return get_jutsu(id) as SubJutsuData


func _build_index() -> void:
	for n: ChakraNatureData in natures:
		for j: JutsuData in n.jutsu:
			_jutsu_index[j.id] = j
	for c: ClanData in clans:
		for j: JutsuData in c.jutsu:
			_jutsu_index[j.id] = j
	for s: SpecializationData in specializations:
		for j: JutsuData in s.all_skills():
			_jutsu_index[j.id] = j
	for j: SubJutsuData in sub_jutsu:
		_jutsu_index[j.id] = j


## Content errors (wrong counts, duplicate ids...). Empty = valid.
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen: Dictionary = {}
	var check_id := func(id: StringName, what: String) -> void:
		if id == &"":
			errors.append("%s without id" % what)
		elif seen.has(id):
			errors.append("duplicate id %s" % id)
		seen[id] = true
	for g in ProgressionTypes.Grade.values():
		if get_grade(g) == null:
			errors.append("missing GradeData for %s" % ProgressionTypes.grade_key(g))
	for n: ChakraNatureData in natures:
		check_id.call(n.id, "nature")
		for r in ProgressionTypes.Rank.values():
			if n.jutsu_of_rank(r).size() != ChakraNatureData.TECHNIQUES_PER_RANK:
				errors.append("nature %s: rank %s needs exactly 2 techniques" % [n.id, ProgressionTypes.rank_key(r)])
		for j: JutsuData in n.jutsu:
			check_id.call(j.id, "jutsu")
	for c: ClanData in clans:
		check_id.call(c.id, "clan")
		if get_village(c.village_id) == null:
			errors.append("clan %s: unknown village %s" % [c.id, c.village_id])
		for r in ProgressionTypes.Rank.values():
			if c.jutsu.filter(func(j: JutsuData) -> bool: return j.rank == r).size() != 1:
				errors.append("clan %s: rank %s needs exactly 1 technique" % [c.id, ProgressionTypes.rank_key(r)])
		for j: JutsuData in c.jutsu:
			check_id.call(j.id, "jutsu")
	for s: SpecializationData in specializations:
		check_id.call(s.id, "specialization")
		if s.active_skills.size() != 3 or s.passive_skill == null:
			errors.append("specialization %s needs 3 active + 1 passive" % s.id)
		for j: JutsuData in s.all_skills():
			check_id.call(j.id, "jutsu")
	for j: SubJutsuData in sub_jutsu:
		check_id.call(j.id, "sub-jutsu")
		if j.rank < ProgressionTypes.Rank.B:
			errors.append("sub-jutsu %s: rank must be B, A or S" % j.id)
	if tenketsu_tree != null:
		for node: TenketsuNodeData in tenketsu_tree.nodes:
			check_id.call(node.id, "tenketsu node")
	return errors
