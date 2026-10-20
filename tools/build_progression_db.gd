extends SceneTree
## Writes data/progression/progression_db.tres: the rules given by the design
## (grades, access, rewards, villages, specializations) + PLACEHOLDER content
## (natures' techniques, clans, Tenketsu nodes, sub-jutsu, HP / chakra) that
## is clearly flagged and waits for the real data.
##   godot --headless --path . -s tools/build_progression_db.gd

const OUT: String = "res://data/progression/progression_db.tres"


func _init() -> void:
	var db := ProgressionDatabase.new()
	db.grades = _grades()
	db.villages = _villages()
	db.natures = _natures()
	db.clans = _clans(db.villages)
	db.specializations = _specializations()
	db.tenketsu_tree = _tenketsu()
	db.sub_jutsu = _sub_jutsu()
	var errors: PackedStringArray = db.validate()
	if not errors.is_empty():
		push_error("Invalid progression data:\n" + "\n".join(errors))
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUT.get_base_dir())
	var err: Error = ResourceSaver.save(db, OUT)
	print("progression db -> %s (%s)" % [OUT, error_string(err)])
	quit(0 if err == OK else 1)


# Grades: access and rewards are the design rules; HP / chakra are placeholders.
func _grades() -> Array[GradeData]:
	var rows: Array = [
		[ProgressionTypes.Grade.GENIN, "Genin", ProgressionTypes.Rank.C, [ProgressionTypes.Choice.PRIMARY_NATURE], ProgressionTypes.SubJutsuEvent.NONE, 100.0],
		[ProgressionTypes.Grade.CHUNIN, "Chunin", ProgressionTypes.Rank.B, [ProgressionTypes.Choice.SPECIALIZATION], ProgressionTypes.SubJutsuEvent.FIRST_ROLL, 120.0],
		[ProgressionTypes.Grade.KONIN, "Konin", ProgressionTypes.Rank.B, [], ProgressionTypes.SubJutsuEvent.NONE, 135.0],
		[ProgressionTypes.Grade.TOKUBETSU, "Tokubetsu", ProgressionTypes.Rank.A, [ProgressionTypes.Choice.SECONDARY_NATURE], ProgressionTypes.SubJutsuEvent.EVOLUTION, 150.0],
		[ProgressionTypes.Grade.JONIN, "Jonin", ProgressionTypes.Rank.S, [], ProgressionTypes.SubJutsuEvent.NONE, 170.0],
	]
	var out: Array[GradeData] = []
	for row: Array in rows:
		var g := GradeData.new()
		g.grade = row[0]
		g.display_name = row[1]
		g.max_jutsu_rank = row[2]
		var choices: Array[int] = []
		choices.assign(row[3])
		g.granted_choices = choices
		g.sub_jutsu_event = row[4]
		g.tenketsu_points = 2
		g.base_hp = row[5]
		g.base_chakra = row[5]
		g.placeholder_stats = true
		out.append(g)
	return out


func _villages() -> Array[VillageData]:
	var out: Array[VillageData] = []
	for row: Array in [[&"konoha", "Konoha"], [&"suna", "Suna"], [&"ame", "Ame"], [&"kiri", "Kiri"]]:
		var v := VillageData.new()
		v.id = row[0]
		v.display_name = row[1]
		out.append(v)
	return out


# PLACEHOLDER: example natures, 2 techniques per rank with generic names.
func _natures() -> Array[ChakraNatureData]:
	var out: Array[ChakraNatureData] = []
	var rows: Array = [[&"katon", "Katon", Color(1, 0.45, 0.1)], [&"suiton", "Suiton", Color(0.3, 0.6, 1)],
		[&"raiton", "Raiton", Color(0.6, 0.85, 1)], [&"doton", "Doton", Color(0.65, 0.5, 0.3)], [&"futon", "Futon", Color(0.6, 1, 0.7)]]
	for row: Array in rows:
		var n := ChakraNatureData.new()
		n.id = row[0]
		n.display_name = row[1]
		n.color = row[2]
		n.placeholder = true
		var jutsu: Array[JutsuData] = []
		for rank in ProgressionTypes.Rank.values():
			for i in 2:
				var key: String = "%s%d" % [ProgressionTypes.rank_key(rank), i + 1]
				jutsu.append(_jutsu(StringName("%s_%s" % [n.id, key.to_lower()]), "%s %s" % [n.display_name, key],
					ProgressionTypes.JutsuSource.NATURE, rank, n.id))
		n.jutsu = jutsu
		out.append(n)
	return out


# PLACEHOLDER: one test clan per village until the clan list is given.
func _clans(villages: Array[VillageData]) -> Array[ClanData]:
	var out: Array[ClanData] = []
	for v: VillageData in villages:
		var c := ClanData.new()
		c.id = StringName("clan_placeholder_%s" % v.id)
		c.display_name = "Placeholder clan (%s)" % v.display_name
		c.village_id = v.id
		c.placeholder = true
		var jutsu: Array[JutsuData] = []
		for rank in ProgressionTypes.Rank.values():
			jutsu.append(_jutsu(StringName("%s_%s" % [c.id, ProgressionTypes.rank_key(rank).to_lower()]), "%s %s" % [c.display_name, ProgressionTypes.rank_key(rank)],
				ProgressionTypes.JutsuSource.CLAN, rank, c.id))
		c.jutsu = jutsu
		out.append(c)
	return out


# The 4 specializations are design rules; their skills are placeholders.
func _specializations() -> Array[SpecializationData]:
	var out: Array[SpecializationData] = []
	var rows: Array = [[&"medic", "Médecin", "Soins"], [&"tracker", "Traqueur", "Traque"],
		[&"fighter", "Combattant", "Dégâts"], [&"bulwark", "Rempart", "Protection"]]
	for row: Array in rows:
		var s := SpecializationData.new()
		s.id = row[0]
		s.display_name = row[1]
		s.role = row[2]
		s.placeholder = true
		var actives: Array[JutsuData] = []
		for i in 3:
			actives.append(_jutsu(StringName("%s_active_%d" % [s.id, i + 1]), "%s — actif %d" % [s.display_name, i + 1],
				ProgressionTypes.JutsuSource.SPECIALIZATION, ProgressionTypes.Rank.D, s.id))
		s.active_skills = actives
		s.passive_skill = _jutsu(StringName("%s_passive" % s.id), "%s — passif" % s.display_name, ProgressionTypes.JutsuSource.SPECIALIZATION, ProgressionTypes.Rank.D, s.id)
		s.passive_skill.passive = true
		out.append(s)
	return out


# PLACEHOLDER: a small tree to exercise costs, prerequisites and levels.
func _tenketsu() -> TenketsuTreeData:
	var tree := TenketsuTreeData.new()
	var rows: Array = [
		[&"tenketsu_vitality", "Vitalité", 1, [], {&"hp": 5.0}, Vector2(0, 0), 3],
		[&"tenketsu_flow", "Flux", 1, [], {&"chakra": 5.0}, Vector2(1, 0), 3],
		[&"tenketsu_regen", "Régénération", 2, [&"tenketsu_vitality"], {&"regen": 1.0}, Vector2(0, 1), 2],
		[&"tenketsu_swiftness", "Mobilité", 2, [&"tenketsu_flow"], {&"mobility": 0.05}, Vector2(1, 1), 2],
		[&"tenketsu_guard", "Résistance", 3, [&"tenketsu_regen", &"tenketsu_swiftness"], {&"resistance": 0.05}, Vector2(0.5, 2), 1],
	]
	var nodes: Array[TenketsuNodeData] = []
	for row: Array in rows:
		var node := TenketsuNodeData.new()
		node.id = row[0]
		node.display_name = row[1]
		node.cost = row[2]
		var prereq: Array[StringName] = []
		prereq.assign(row[3])
		node.prerequisites = prereq
		node.stat_modifiers = row[4]
		node.position_in_tree = row[5]
		node.max_level = row[6]
		node.placeholder = true
		nodes.append(node)
	tree.nodes = nodes
	return tree


# PLACEHOLDER: 3 sub-jutsu per rank, equal weights.
func _sub_jutsu() -> Array[SubJutsuData]:
	var out: Array[SubJutsuData] = []
	for rank in [ProgressionTypes.Rank.B, ProgressionTypes.Rank.A, ProgressionTypes.Rank.S]:
		for i in 3:
			var s := SubJutsuData.new()
			s.id = StringName("sub_%s_placeholder_%d" % [ProgressionTypes.rank_key(rank).to_lower(), i + 1])
			s.display_name = "Technique cachée %s%d" % [ProgressionTypes.rank_key(rank), i + 1]
			s.source = ProgressionTypes.JutsuSource.SUB_JUTSU
			s.rank = rank
			s.weight = 1.0
			s.placeholder = true
			out.append(s)
	return out


func _jutsu(id: StringName, display: String, source: int, rank: int, owner: StringName) -> JutsuData:
	var j := JutsuData.new()
	j.id = id
	j.display_name = display
	j.source = source
	j.rank = rank
	j.owner_id = owner
	j.placeholder = true
	return j
