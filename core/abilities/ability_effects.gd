class_name AbilityEffects
## Generic executors, one per AbilityData.Kind. No character-specific code here:
## kit identity comes from AbilityData flags (clone mirroring, marks, zones...).


static func activate(ctrl: AbilityController, a: AbilityData) -> void:
	var c: CombatCharacter = ctrl.character
	_apply_self_buffs(c, a)
	match a.kind:
		AbilityData.Kind.MELEE_ARC:
			if c.try_pursue(ctrl):
				pass  # blinked next to a launched enemy: no lunge
			elif a.lunge_distance > 0.0:
				c.movement.apply_forced_motion(ctrl.cast_direction * (a.lunge_distance / 0.08), 0.08, true)
			var hits: Array[CombatCharacter] = []
			ctrl.pulse_count = 1
			melee_from(c, c.global_position, ctrl.cast_direction, a, 1.0, hits)
			if a.clone_mirror and is_instance_valid(c.clone):
				c.clone.mirror_melee(a, ctrl.cast_direction)
		AbilityData.Kind.PROJECTILE:
			Projectile.spawn(c, a, ctrl.cast_direction)
		AbilityData.Kind.DASH:
			if a.swap_with_clone and is_instance_valid(c.clone):
				_swap_with_clone(c)
				ctrl.end_active_early()
				return
			c.movement.apply_forced_motion(ctrl.cast_direction * (a.dash_distance / a.active_time), a.active_time, false)
			if a.dash_immaterial:
				c.status.apply_status(StatusController.Type.IMMATERIAL, a.active_time)
			c.set_pass_through(a.dash_pass_through_characters)
			if a.clone_mirror and is_instance_valid(c.clone):
				c.clone.mirror_dash(a, ctrl.cast_direction)
		AbilityData.Kind.GROUND_AREA:
			GroundArea.spawn(c, a, ctrl.cast_target_point, ctrl.cast_direction)
		AbilityData.Kind.TELEPORT:
			_teleport(ctrl, a)
		AbilityData.Kind.COUNTER:
			c.status.apply_status(StatusController.Type.COUNTER, a.active_time)
		AbilityData.Kind.SELF_HEAL:
			c.health.heal(a.heal_amount, a.true_heal)
			CombatFx.ring(c, c.global_position, 1.2, a.color, 0.4)
			if a.heal_allies_radius > 0.0:
				for node: Node in c.get_tree().get_nodes_in_group(&"fighters"):
					var ally := node as CombatCharacter
					if ally == null or ally == c or ally.team != c.team or ally.is_dead():
						continue
					if ally.global_position.distance_to(c.global_position) <= a.heal_allies_radius:
						ally.health.heal(a.heal_amount, a.true_heal)
						CombatFx.ring(c, ally.global_position, 1.0, a.color, 0.4)
		AbilityData.Kind.SUMMON_CLONE:
			c.dismiss_clone()
			var dest: Vector3 = _clear_point(c, ctrl.cast_direction, a.summon_distance)
			c.clone = ShadowClone.spawn(c, dest, a.summon_duration)
		AbilityData.Kind.SCRIPTED:
			if a.technique != null:
				a.technique.cast(Tk.from_cast(ctrl, a, a.technique))
		AbilityData.Kind.SUBSTITUTION:
			c.arm_substitution(a.substitution_radius)


static func tick_active(ctrl: AbilityController, a: AbilityData, _delta: float) -> void:
	if a.kind == AbilityData.Kind.MELEE_ARC and a.multi_hits > 1:
		# Flurry: one swing per pulse, each pulse can hit everyone again.
		var interval: float = a.active_time / a.multi_hits
		while ctrl.pulse_count < a.multi_hits and ctrl.phase_elapsed >= interval * ctrl.pulse_count:
			ctrl.pulse_count += 1
			var c0: CombatCharacter = ctrl.character
			var pulse_hits: Array[CombatCharacter] = []
			melee_from(c0, c0.global_position, ctrl.cast_direction, a, 1.0, pulse_hits)
		return
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
		CombatFx.log_decoy(c, origin)
		c.global_position = Vector3(0, origin.y, 0) + _clear_point(c, c.facing.facing_direction, a.counter_teleport_distance)
	if a.counter_stun_attacker > 0.0 and is_instance_valid(hit.source) and not hit.source.is_dead():
		hit.source.status.apply_status(StatusController.Type.STUN, a.counter_stun_attacker)
		hit.source.abilities.interrupt()
		CombatFx.ring(c, hit.source.global_position, 1.0, a.color, 0.35)
	if a.counter_reset_slot != &"":
		ctrl.reset_cooldown(a.counter_reset_slot)
	if a.counter_haste > 0.0:
		c.status.apply_status(StatusController.Type.HASTE, a.counter_haste)
	if a.counter_copy and hit.ability != null and is_instance_valid(hit.source):
		ctrl.copy_jutsu(hit.source, hit.ability)
	if a.counter_aoe_radius > 0.0:
		_counter_burst(c, a)
	CombatFx.ring(c, c.global_position, 1.4, a.color, 0.3)
	ctrl.end_active_early()


## Melee arc from any origin (the caster or its clone). `already_hit`
## de-duplicates targets for one swing.
static func melee_from(c: CombatCharacter, origin: Vector3, direction: Vector3, a: AbilityData, damage_scale: float, already_hit: Array[CombatCharacter]) -> void:
	var center: Vector3 = origin + Vector3.UP * HitQuery.BODY_HEIGHT
	var half_arc: float = deg_to_rad(a.arc_degrees) * 0.5
	CombatFx.arc(c, origin, direction, a.max_range, a.arc_degrees, a.color, 0.15)
	KitObject.damage_objects_in(c.get_tree(), origin + direction * a.max_range * 0.5, a.max_range * 0.6, c.team, a.damage * damage_scale)
	ArenaRules.hit_orb_arc(c, origin, direction, a, a.damage * damage_scale)
	for target: CombatCharacter in HitQuery.characters_in_sphere(c.get_world_3d(), center, a.max_range + HitQuery.HURTBOX_RADIUS):
		if target.team == c.team or already_hit.has(target):
			continue
		var to_target: Vector3 = HitQuery.flat(target.global_position - origin)
		# Inside arc, or so close that the body overlaps the swing origin.
		if to_target.length() > HitQuery.HURTBOX_RADIUS * 1.5 and direction.angle_to(to_target) > half_arc:
			continue
		already_hit.append(target)
		var hit := HitData.from_ability(c, a, to_target.normalized() if to_target.length() > 0.01 else direction)
		hit.damage *= damage_scale
		if damage_scale < 1.0:
			hit.energy_gain = 0.0
		target.receive_hit(hit)


static func _apply_self_buffs(c: CombatCharacter, a: AbilityData) -> void:
	if a.buff_haste > 0.0:
		c.status.apply_status(StatusController.Type.HASTE, a.buff_haste)
	if a.buff_empower > 0.0:
		c.status.apply_status(StatusController.Type.EMPOWER, a.buff_empower)
	if a.buff_regen > 0.0:
		c.status.apply_status(StatusController.Type.REGEN, a.buff_regen)
	if a.buff_drain > 0.0:
		c.status.apply_status(StatusController.Type.DRAIN, a.buff_drain)
	if a.grant_shield > 0.0:
		c.health.add_shield(a.grant_shield, a.shield_time)


## Kaiten / crow clone: damage, stun and push everyone around the fighter.
static func _counter_burst(c: CombatCharacter, a: AbilityData) -> void:
	var center: Vector3 = c.global_position + Vector3.UP * HitQuery.BODY_HEIGHT
	CombatFx.ring(c, c.global_position, a.counter_aoe_radius, a.color, 0.4)
	for target: CombatCharacter in HitQuery.characters_in_sphere(c.get_world_3d(), center, a.counter_aoe_radius + HitQuery.HURTBOX_RADIUS):
		if target.team == c.team:
			continue
		var hit := HitData.new()
		hit.source = c
		hit.damage = a.counter_aoe_damage
		hit.stun_duration = a.counter_aoe_stun
		hit.knockback_velocity = HitQuery.flat(target.global_position - c.global_position).normalized() * a.counter_aoe_knockback
		hit.knockback_duration = 0.25
		target.receive_hit(hit)


## Flying Thunder God: to a kunai marker, or behind sealed enemies (striking).
static func _teleport(ctrl: AbilityController, a: AbilityData) -> void:
	var c: CombatCharacter = ctrl.character
	match a.teleport_mode:
		&"marker":
			var marker: GroundArea = GroundArea.newest_marker(c)
			if marker == null or marker.global_position.distance_to(c.global_position) > a.teleport_range:
				_blink(c, _clear_point(c, ctrl.cast_direction, 3.5))
				return
			_blink(c, marker.global_position)
			marker.consume()
		&"sealed", &"sealed_all":
			var targets: Array[CombatCharacter] = _sealed_enemies(c, a.teleport_range)
			if targets.is_empty():
				_blink(c, _clear_point(c, ctrl.cast_direction, 3.0))
				return
			if a.teleport_mode == &"sealed":
				targets = [targets[0]]
			for target: CombatCharacter in targets:
				var dir: Vector3 = HitQuery.flat(target.global_position - c.global_position).normalized()
				if dir.length_squared() < 0.01:
					dir = c.facing.facing_direction
				_blink(c, target.global_position + dir * 1.1)  # behind them
				c.facing.set_direction(-dir)
				target.status.remove_status(StatusController.Type.SEAL)
				var hits: Array[CombatCharacter] = []
				melee_from(c, c.global_position, -dir, a, 1.0, hits)


static func _blink(c: CombatCharacter, to: Vector3) -> void:
	CombatFx.ring(c, c.global_position, 0.9, Color(1.0, 0.9, 0.3), 0.3)
	c.global_position = Vector3(to.x, c.global_position.y, to.z)
	c.status.apply_status(StatusController.Type.IMMATERIAL, 0.2)
	CombatFx.ring(c, c.global_position, 0.9, Color(1.0, 0.9, 0.3), 0.3)


## Enemies carrying a SEAL within range, nearest first.
static func _sealed_enemies(c: CombatCharacter, max_range: float) -> Array[CombatCharacter]:
	var found: Array[CombatCharacter] = []
	for node: Node in c.get_tree().get_nodes_in_group(&"fighters"):
		var other := node as CombatCharacter
		if other == null or other.team == c.team or other.is_dead():
			continue
		if other.status.has_status(StatusController.Type.SEAL) and other.global_position.distance_to(c.global_position) <= max_range:
			found.append(other)
	found.sort_custom(func(x: CombatCharacter, y: CombatCharacter) -> bool:
		return x.global_position.distance_to(c.global_position) < y.global_position.distance_to(c.global_position))
	return found


static func _swap_with_clone(c: CombatCharacter) -> void:
	var here: Vector3 = c.global_position
	var there: Vector3 = c.clone.global_position
	CombatFx.log_decoy(c, here)
	c.global_position = Vector3(there.x, here.y, there.z)
	c.clone.global_position = HitQuery.flat(here)
	c.status.apply_status(StatusController.Type.IMMATERIAL, 0.25)


## Point `distance` ahead, stopped short of walls.
static func _clear_point(c: CombatCharacter, direction: Vector3, distance: float) -> Vector3:
	var origin: Vector3 = HitQuery.flat(c.global_position)
	var dest: Vector3 = origin + direction * distance
	var lift := Vector3.UP * HitQuery.BODY_HEIGHT
	var wall: Dictionary = HitQuery.raycast_world(c.get_world_3d(), origin + lift, dest + lift)
	if not wall.is_empty():
		dest = HitQuery.flat(wall.position) - direction * 0.6
	return dest
