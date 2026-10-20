extends SceneTree
## Builds data/progression/progression_db.tres (the Resource the game loads)
## from data/progression/content.json (the designer-editable content, see
## tools/progression_content.py). Validates the content before saving.
##   godot --headless --path . -s tools/build_progression_db.gd

const SOURCE: String = "res://data/progression/content.json"
const OUT: String = "res://data/progression/progression_db.tres"


func _init() -> void:
	var content: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	if not content is Dictionary:
		push_error("Cannot read %s" % SOURCE)
		quit(1)
		return
	var db: ProgressionDatabase = build(content)
	var errors: PackedStringArray = db.validate()
	if not errors.is_empty():
		push_error("Invalid progression data:\n" + "\n".join(errors))
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUT.get_base_dir())
	var err: Error = ResourceSaver.save(db, OUT)
	print("progression db -> %s (%s): %d natures, %d clans, %d sub-jutsu" % [OUT, error_string(err),
		db.natures.size(), db.clans.size(), db.sub_jutsu.size()])
	quit(0 if err == OK else 1)


static func build(content: Dictionary) -> ProgressionDatabase:
	var db := ProgressionDatabase.new()
	for row: Dictionary in content.grades:
		var g := GradeData.new()
		g.grade = ProgressionTypes.Grade[row.grade]
		g.display_name = row.name
		g.max_jutsu_rank = ProgressionTypes.Rank[row.max_rank]
		var choices: Array[int] = []
		for c: String in row.choices:
			choices.append(ProgressionTypes.Choice[c])
		g.granted_choices = choices
		g.sub_jutsu_event = ProgressionTypes.SubJutsuEvent[row.sub_jutsu_event]
		g.base_hp = row.base_hp
		g.base_chakra = row.base_chakra
		g.tenketsu_points = int(row.tenketsu_points)
		g.xp_to_next = int(row.get("xp_to_next", 0))
		db.grades.append(g)
	for row: Dictionary in content.villages:
		var v := VillageData.new()
		v.id = row.id
		v.display_name = row.name
		db.villages.append(v)
	for row: Dictionary in content.natures:
		var n := ChakraNatureData.new()
		n.id = row.id
		n.display_name = row.name
		n.description = row.description
		n.color = Color(row.color)
		n.identity = row.get("identity", "")
		n.signature = row.get("signature", "")
		for j: Dictionary in row.jutsu:
			n.jutsu.append(_jutsu(j, JutsuData.new(), ProgressionTypes.JutsuSource.NATURE, n.id))
		db.natures.append(n)
	for row: Dictionary in content.clans:
		var c := ClanData.new()
		c.id = row.id
		c.display_name = row.name
		c.village_id = row.village
		c.description = row.description
		c.identity = row.get("identity", "")
		c.signature = row.get("signature", "")
		for j: Dictionary in row.jutsu:
			c.jutsu.append(_jutsu(j, JutsuData.new(), ProgressionTypes.JutsuSource.CLAN, c.id))
		db.clans.append(c)
	for row: Dictionary in content.specializations:
		var s := SpecializationData.new()
		s.id = row.id
		s.display_name = row.name
		s.role = row.role
		s.description = row.description
		for j: Dictionary in row.active:
			s.active_skills.append(_jutsu(j, JutsuData.new(), ProgressionTypes.JutsuSource.SPECIALIZATION, s.id))
		s.passive_skill = _jutsu(row.passive, JutsuData.new(), ProgressionTypes.JutsuSource.SPECIALIZATION, s.id)
		db.specializations.append(s)
	db.tenketsu_tree = TenketsuTreeData.new()
	for row: Dictionary in content.tenketsu:
		var node := TenketsuNodeData.new()
		node.id = row.id
		node.display_name = row.name
		node.description = row.description
		node.cost = int(row.cost)
		for p: String in row.prerequisites:
			node.prerequisites.append(StringName(p))
		var mods: Dictionary = {}
		for stat: String in row.modifiers:
			mods[StringName(stat)] = float(row.modifiers[stat])
		node.stat_modifiers = mods
		node.position_in_tree = Vector2(row.position[0], row.position[1])
		node.max_level = int(row.max_level)
		db.tenketsu_tree.nodes.append(node)
	for row: Dictionary in content.sub_jutsu:
		var sub := _jutsu(row, SubJutsuData.new(), ProgressionTypes.JutsuSource.SUB_JUTSU, &"") as SubJutsuData
		sub.weight = float(row.get("weight", 1.0))
		for e: String in row.get("exclusions", []):
			sub.exclusions.append(StringName(e))
		for v: String in row.get("villages", []):
			sub.allowed_villages.append(StringName(v))
		db.sub_jutsu.append(sub)
	for mob_id: String in content.get("mobs", {}):
		db.mob_xp[StringName(mob_id)] = int(content.mobs[mob_id].xp)
	var rules: Dictionary = content.get("rules", {})
	var ranks: Array[int] = []
	for r: String in rules.get("sub_jutsu_roll_ranks", ["B", "A", "S"]):
		ranks.append(ProgressionTypes.Rank[r])
	db.sub_jutsu_roll_ranks = ranks
	db.max_equipped_jutsu = int(rules.get("max_equipped_jutsu", 6))
	db.specialization_grants_skills = bool(rules.get("specialization_grants_skills", true))
	return db


static func _jutsu(row: Dictionary, j: JutsuData, source: int, owner: StringName) -> JutsuData:
	j.id = row.id
	j.display_name = row.name
	j.description = row.get("description", "")
	j.source = source
	j.rank = ProgressionTypes.Rank[row.rank]
	j.owner_id = owner
	j.chakra_cost = float(row.get("chakra_cost", 0.0))
	j.cooldown = float(row.get("cooldown", 0.0))
	for t: String in row.get("tags", []):
		j.tags.append(StringName(t))
	for r: String in row.get("requirements", []):
		j.requirements.append(StringName(r))
	j.passive = bool(row.get("passive", false))
	j.design_tags = PackedStringArray(row.get("design_tags", []))
	j.details = row.get("details", "")
	return j
