class_name HitQuery
## Stateless physics queries used by abilities, projectiles and areas.

const WORLD_MASK: int = 1
const HURTBOX_MASK: int = 8
const HURTBOX_RADIUS: float = 0.45
const BODY_HEIGHT: float = 0.9


static func characters_in_sphere(world: World3D, center: Vector3, radius: float) -> Array[CombatCharacter]:
	var shape := SphereShape3D.new()
	shape.radius = radius
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis.IDENTITY, center)
	params.collision_mask = HURTBOX_MASK
	params.collide_with_areas = true
	params.collide_with_bodies = false
	var found: Array[CombatCharacter] = []
	for result: Dictionary in world.direct_space_state.intersect_shape(params, 16):
		var hurtbox := result.collider as Hurtbox
		if hurtbox == null or hurtbox.character == null:
			continue
		if hurtbox.character.is_dead() or found.has(hurtbox.character):
			continue
		found.append(hurtbox.character)
	return found


## Returns the ray hit against world geometry, or an empty Dictionary.
static func raycast_world(world: World3D, from: Vector3, to: Vector3) -> Dictionary:
	var params := PhysicsRayQueryParameters3D.create(from, to, WORLD_MASK)
	return world.direct_space_state.intersect_ray(params)


static func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
