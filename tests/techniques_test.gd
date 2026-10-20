extends Node3D
## Headless sandbox test of every design-bible technique: each one is cast
## by a shinobi facing two dummies (then recast, then left running), and
## must produce an observable effect (damage, healing, shield, movement,
## mark, resource, modifier, object, projectile, recast window).
##   godot --headless --fixed-fps 60 --path . res://tests/techniques_test.tscn [-- kit=katon]
## Script errors are printed by the engine: CI also greps "SCRIPT ERROR".

const SHINOBI: PackedScene = preload("res://characters/base/shinobi.tscn")

var _failures: PackedStringArray = []
var _checked: int = 0
var _missing: PackedStringArray = []


func _ready() -> void:
	_run.call_deferred()


func _filter() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("kit="):
			return arg.trim_prefix("kit=")
	return ""


func _all_jutsu(db: ProgressionDatabase) -> Array[JutsuData]:
	var out: Array[JutsuData] = []
	for n: ChakraNatureData in db.natures:
		out.append_array(n.jutsu)
	for c: ClanData in db.clans:
		out.append_array(c.jutsu)
	for s: SubJutsuData in db.sub_jutsu:
		out.append(s)
	return out


func _run() -> void:
	var db: ProgressionDatabase = ProgressionDatabase.load_default()
	var only: String = _filter()
	for j: JutsuData in _all_jutsu(db):
		if only != "" and not String(j.id).contains(only):
			continue
		if not TechniqueRegistry.has(j.id):
			_missing.append(String(j.id))
			continue
		await _check(j, db)
	print("[techniques] scripted %d, missing %d, failures %d" % [_checked, _missing.size(), _failures.size()])
	if not _missing.is_empty():
		print("[techniques] not scripted yet: %s" % ", ".join(_missing))
	for f: String in _failures:
		print("  FAIL ", f)
	var ok: bool = _failures.is_empty() and (only != "" or _missing.is_empty())
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)


func _fighter(data: CharacterData, team: int, at: Vector3) -> CombatCharacter:
	var f := SHINOBI.instantiate() as CombatCharacter
	f.data = data
	f.team = team
	f.transform = Transform3D(Basis.looking_at(Vector3.LEFT if team == 1 else Vector3.RIGHT, Vector3.UP), at)
	add_child(f)
	f.controls_enabled = false
	return f


func _dummy_data(hp: float) -> CharacterData:
	var d := CharacterData.new()
	d.display_name = "Dummy"
	d.max_health = hp
	d.movement = MovementData.new()
	d.lmb = JutsuAbilityFactory.taijutsu()
	return d


func _check(j: JutsuData, db: ProgressionDatabase) -> void:
	_checked += 1
	var data := _dummy_data(400.0)
	data.display_name = "Caster"
	data.max_chakra = 300.0
	data.chakra_regen = 50.0
	if j.owner_id != &"":
		data.kits.append(j.owner_id)
	data.j1 = JutsuAbilityFactory.build(j, db)
	var caster: CombatCharacter = _fighter(data, 0, Vector3.ZERO)
	var near: CombatCharacter = _fighter(_dummy_data(400.0), 1, Vector3(3.0, 0.0, 0.0))
	var far: CombatCharacter = _fighter(_dummy_data(400.0), 1, Vector3(6.0, 0.0, 1.0))
	caster.facing.update_aim(caster.global_position, near.global_position)
	caster.facing.aim_point = near.global_position
	await get_tree().physics_frame
	var before := {"near": near.health.current_health, "far": far.health.current_health, "hp": caster.health.current_health,
		"pos": caster.global_position}
	var ok_cast: bool = caster.abilities.try_cast(&"j1")
	var seen := {"objects": 0, "projectiles": 0, "recast": false, "modifiers": false, "marks": false, "resources": false,
		"moved": false, "status": false}
	for frame in 150:
		await get_tree().physics_frame
		if frame == 40 and caster.kit.has_recast(j.id):
			seen.recast = true
			caster.abilities.try_cast(&"j1")
		_observe(caster, [near, far], before, seen)
	var dealt: float = (before.near - near.health.current_health) + (before.far - far.health.current_health)
	var effect: bool = dealt > 0.5 or seen.objects > 0 or seen.projectiles > 0 or seen.recast or seen.modifiers \
		or seen.marks or seen.resources or seen.moved or seen.status or caster.health.shield > 0.0 \
		or caster.health.current_health > before.hp + 0.5
	if not ok_cast:
		_failures.append("%s: could not be cast" % j.id)
	elif not effect:
		_failures.append("%s: no observable effect" % j.id)
	for node: Node in get_tree().get_nodes_in_group(&"round_entities"):
		node.queue_free()
	for f: CombatCharacter in [caster, near, far]:
		f.queue_free()
	await get_tree().physics_frame


func _observe(caster: CombatCharacter, enemies: Array, before: Dictionary, seen: Dictionary) -> void:
	seen.objects = maxi(seen.objects, get_tree().get_nodes_in_group(&"kit_objects").size())
	seen.projectiles = maxi(seen.projectiles, get_tree().get_nodes_in_group(&"tk_projectiles").size() + get_tree().get_nodes_in_group(&"projectiles").size())
	if not caster.kit.modifiers.is_empty():
		seen.modifiers = true
	for key: String in caster.kit.resources:
		if caster.kit.res(key) > 0.0:
			seen.resources = true
	if HitQuery.flat(caster.global_position - before.pos).length() > 0.5:
		seen.moved = true
	for e: CombatCharacter in enemies:
		if not e.kit.marks.is_empty() or not e.kit.modifiers.is_empty():
			seen.marks = true
		for type: int in [StatusController.Type.STUN, StatusController.Type.ROOT, StatusController.Type.SLOW,
				StatusController.Type.SILENCE, StatusController.Type.INCAPACITATE, StatusController.Type.LAUNCHED,
				StatusController.Type.BURN, StatusController.Type.SEAL]:
			if e.status.has_status(type):
				seen.status = true
		if e.movement.is_forced():
			seen.status = true
	for type: int in [StatusController.Type.HASTE, StatusController.Type.EMPOWER, StatusController.Type.REGEN,
			StatusController.Type.IMMATERIAL, StatusController.Type.COUNTER]:
		if caster.status.has_status(type):
			seen.status = true
