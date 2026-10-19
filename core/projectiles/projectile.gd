class_name Projectile
extends Node3D
## Generic straight-line projectile. Stops on walls, passes through immaterial
## targets, is consumed by counters.

var source: CombatCharacter
var team: int = 0
var ability: AbilityData
var direction: Vector3 = Vector3.FORWARD
var age: float = 0.0

var _travelled: float = 0.0
var _already_hit: Array[CombatCharacter] = []


static func spawn(from: CombatCharacter, data: AbilityData, dir: Vector3) -> Projectile:
	var p := Projectile.new()
	p.source = from
	p.team = from.team
	p.ability = data
	p.direction = HitQuery.flat(dir).normalized()
	from.get_parent().add_child(p)
	p.global_position = from.global_position + Vector3.UP * HitQuery.BODY_HEIGHT + p.direction * 0.4
	return p


func _ready() -> void:
	add_to_group(&"projectiles")
	add_to_group(&"round_entities")
	var mesh := SphereMesh.new()
	mesh.radius = ability.hit_radius
	mesh.height = ability.hit_radius * 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = ability.color
	mat.emission_enabled = true
	mat.emission = ability.color
	mat.emission_energy_multiplier = 0.6
	mesh.material = mat
	var view := MeshInstance3D.new()
	view.mesh = mesh
	add_child(view)


func _physics_process(delta: float) -> void:
	age += delta
	var from: Vector3 = global_position
	var step: Vector3 = direction * ability.projectile_speed * delta
	var wall: Dictionary = HitQuery.raycast_world(get_world_3d(), from, from + step)
	if not wall.is_empty():
		_expire(wall.position)
		return
	global_position = from + step
	_travelled += step.length()
	for target: CombatCharacter in HitQuery.characters_in_sphere(get_world_3d(), global_position, ability.hit_radius):
		if target.team == team or _already_hit.has(target):
			continue
		var result: HitData.Result = target.receive_hit(HitData.from_ability(source, ability, direction))
		if result == HitData.Result.IGNORED:
			continue  # immaterial: fly through
		_already_hit.append(target)
		if not ability.projectile_piercing or result == HitData.Result.COUNTERED:
			_expire(global_position)
			return
	if _travelled >= ability.max_range:
		_expire(global_position)


func _expire(at: Vector3) -> void:
	CombatFx.ring(self, HitQuery.flat(at), ability.hit_radius + 0.3, ability.color, 0.2)
	queue_free()
