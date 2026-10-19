class_name AbilityEffects
## Generic executors, one per AbilityData.Kind. No character-specific code here.


static func activate(ctrl: AbilityController, a: AbilityData) -> void:
	var c: CombatCharacter = ctrl.character
	match a.kind:
		AbilityData.Kind.MELEE_ARC:
			_melee(ctrl, a)
		AbilityData.Kind.PROJECTILE:
			Projectile.spawn(c, a, ctrl.cast_direction)
		AbilityData.Kind.DASH:
			c.movement.apply_forced_motion(ctrl.cast_direction * (a.dash_distance / a.active_time), a.active_time, false)
			if a.dash_immaterial:
				c.status.apply_status(StatusController.Type.IMMATERIAL, a.active_time)
			c.set_pass_through(a.dash_pass_through_characters)
		AbilityData.Kind.GROUND_AREA:
			GroundArea.spawn(c, a, ctrl.cast_target_point)
		AbilityData.Kind.COUNTER:
			c.status.apply_status(StatusController.Type.COUNTER, a.active_time)
		AbilityData.Kind.SELF_HEAL:
			c.health.heal(a.heal_amount, a.true_heal)
			CombatFx.ring(c, c.global_position, 1.2, a.color, 0.4)


static func tick_active(ctrl: AbilityController, a: AbilityData, _delta: float) -> void:
	if a.kind != AbilityData.Kind.DASH or not a.does_damage():
		return
	var c: CombatCharacter = ctrl.character
	var center: Vector3 = c.global_position + Vector3.UP * HitQuery.BODY_HEIGHT
	for target: CombatCharacter in HitQuery.characters_in_sphere(c.get_world_3d(), center, a.hit_radius + HitQuery.HURTBOX_RADIUS):
		if target.team == c.team:
			continue
		var result: HitData.Result = apply_hit(ctrl, a, target, ctrl.cast_direction)
		if result != HitData.Result.IGNORED:
			CombatFx.ring(c, target.global_position, 1.0, a.color, 0.25)
			if a.dash_stop_on_hit:
				c.movement.cancel_forced()
				ctrl.end_active_early()
			return


static func end_active(ctrl: AbilityController, a: AbilityData) -> void:
	var c: CombatCharacter = ctrl.character
	match a.kind:
		AbilityData.Kind.DASH:
			c.movement.cancel_forced()
			c.set_pass_through(false)
			if a.dash_immaterial:
				c.status.remove_status(StatusController.Type.IMMATERIAL)
		AbilityData.Kind.COUNTER:
			c.status.remove_status(StatusController.Type.COUNTER)


static func apply_hit(ctrl: AbilityController, a: AbilityData, target: CombatCharacter, direction: Vector3) -> HitData.Result:
	if not ctrl.register_hit(target):
		return HitData.Result.IGNORED
	return target.receive_hit(HitData.from_ability(ctrl.character, a, direction))


static func resolve_counter(ctrl: AbilityController, a: AbilityData, hit: HitData) -> void:
	var c: CombatCharacter = ctrl.character
	c.status.remove_status(StatusController.Type.COUNTER)
	c.status.apply_status(StatusController.Type.IMMATERIAL, 0.35)
	c.energy.gain(a.energy_gain_on_hit)
	if a.counter_teleport_distance > 0.0:
		var origin: Vector3 = c.global_position
		var dir: Vector3 = c.facing.facing_direction
		var dest: Vector3 = origin + dir * a.counter_teleport_distance
		var lift := Vector3.UP * HitQuery.BODY_HEIGHT
		var wall: Dictionary = HitQuery.raycast_world(c.get_world_3d(), origin + lift, dest + lift)
		if not wall.is_empty():
			dest = HitQuery.flat(wall.position) - dir * 0.6
		CombatFx.log_decoy(c, origin)
		c.global_position = Vector3(dest.x, origin.y, dest.z)
	if a.counter_stun_attacker > 0.0 and is_instance_valid(hit.source) and not hit.source.is_dead():
		hit.source.status.apply_status(StatusController.Type.STUN, a.counter_stun_attacker)
		hit.source.abilities.interrupt()
		CombatFx.ring(c, hit.source.global_position, 1.0, a.color, 0.35)
	CombatFx.ring(c, c.global_position, 1.4, a.color, 0.3)
	ctrl.end_active_early()


static func _melee(ctrl: AbilityController, a: AbilityData) -> void:
	var c: CombatCharacter = ctrl.character
	var origin: Vector3 = c.global_position
	var center: Vector3 = origin + Vector3.UP * HitQuery.BODY_HEIGHT
	var half_arc: float = deg_to_rad(a.arc_degrees) * 0.5
	CombatFx.arc(c, origin, ctrl.cast_direction, a.max_range, a.arc_degrees, a.color, 0.15)
	for target: CombatCharacter in HitQuery.characters_in_sphere(c.get_world_3d(), center, a.max_range + HitQuery.HURTBOX_RADIUS):
		if target.team == c.team:
			continue
		var to_target: Vector3 = HitQuery.flat(target.global_position - origin)
		# Inside arc, or so close that the body overlaps the swing origin.
		if to_target.length() > HitQuery.HURTBOX_RADIUS * 1.5 and ctrl.cast_direction.angle_to(to_target) > half_arc:
			continue
		apply_hit(ctrl, a, target, to_target.normalized() if to_target.length() > 0.01 else ctrl.cast_direction)
