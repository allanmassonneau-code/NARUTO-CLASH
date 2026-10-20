class_name TenketsuService
extends RefCounted
## Tenketsu points: spending with cost / prerequisite / max level checks,
## and the stat bonuses of the unlocked nodes.

var db: ProgressionDatabase


func _init(database: ProgressionDatabase) -> void:
	db = database


func spent_points(profile: CharacterProfile) -> int:
	var total: int = 0
	for node_id: StringName in profile.tenketsu_levels:
		var node: TenketsuNodeData = db.get_tenketsu_node(node_id)
		if node != null:
			total += node.cost * int(profile.tenketsu_levels[node_id])
	return total


func available_points(profile: CharacterProfile) -> int:
	return profile.tenketsu_earned - spent_points(profile)


func level_of(profile: CharacterProfile, node_id: StringName) -> int:
	return int(profile.tenketsu_levels.get(node_id, 0))


func can_unlock(profile: CharacterProfile, node_id: StringName) -> ProgressionResult:
	var node: TenketsuNodeData = db.get_tenketsu_node(node_id)
	if node == null:
		return ProgressionResult.fail(&"UNKNOWN_NODE")
	if level_of(profile, node_id) >= node.max_level:
		return ProgressionResult.fail(&"MAX_LEVEL")
	if available_points(profile) < node.cost:
		return ProgressionResult.fail(&"NOT_ENOUGH_POINTS")
	for req: StringName in node.prerequisites:
		if level_of(profile, req) <= 0:
			return ProgressionResult.fail(&"MISSING_PREREQUISITE", "Requires %s." % req)
	return ProgressionResult.success()


func unlock(profile: CharacterProfile, node_id: StringName) -> ProgressionResult:
	var check: ProgressionResult = can_unlock(profile, node_id)
	if not check.ok:
		return check
	profile.tenketsu_levels[node_id] = level_of(profile, node_id) + 1
	check.add_event(&"tenketsu_unlocked", {"node": node_id, "level": profile.tenketsu_levels[node_id]})
	return check


## Refund every point (admin / respec item).
func reset(profile: CharacterProfile) -> void:
	profile.tenketsu_levels.clear()


## stat id -> total bonus from unlocked nodes.
func stat_bonuses(profile: CharacterProfile) -> Dictionary:
	var out: Dictionary = {}
	for node_id: StringName in profile.tenketsu_levels:
		var node: TenketsuNodeData = db.get_tenketsu_node(node_id)
		if node == null:
			continue
		for stat: Variant in node.stat_modifiers:
			out[stat] = float(out.get(stat, 0.0)) + float(node.stat_modifiers[stat]) * int(profile.tenketsu_levels[node_id])
	return out
