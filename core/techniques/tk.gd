class_name Tk
extends RefCounted
## Technique API handed to Technique.cast(). Wraps the combat pipeline so a
## technique reads like its design-bible description:
##   var e := t.nearest_enemy(t.aim, 3.0)
##   t.hit(e, t.dmg(0.8), {"stun": 0.4})
##   t.mark(e, "braise", 1, 5.0, 3)
## Damage values are relative: t.dmg(1.0) = the rank's base damage scaled by
## the caster's power bonuses. See docs/TECHNIQUES_API.md.

## Base damage per rank D, C, B, A, S (t.dmg(1.0)).
const RANK_DAMAGE: Array[float] = [12.0, 16.0, 22.0, 30.0, 42.0]

var caster: CombatCharacter
var ability: AbilityData
var technique: Technique
var id: StringName
## Locked cast direction (flat, normalized) and aim point (clamped to range).
var dir: Vector3 = Vector3.FORWARD
var aim: Vector3 = Vector3.ZERO
var origin: Vector3 = Vector3.ZERO
var rank: int = 0
var color: Color = Color.WHITE


static func from_cast(ctrl: AbilityController, a: AbilityData, tech: Technique) -> Tk:
	var t := Tk.new()
	t.caster = ctrl.character
	t.ability = a
	t.technique = tech
	t.id = tech.id
	t.dir = HitQuery.flat(ctrl.cast_direction).normalized()
	if t.dir.length() < 0.5:
		t.dir = Vector3.FORWARD
	t.origin = HitQuery.flat(ctrl.character.global_position)
	t.aim = HitQuery.flat(ctrl.cast_target_point)
	t.rank = tech.jutsu.rank if tech.jutsu != null else 0
	t.color = a.color
	return t


## A context for callbacks that run later (recast, timers): refreshes the
## caster position / facing / aim.
func refreshed() -> Tk:
	var t := Tk.new()
	t.caster = caster
	t.ability = ability
	t.technique = technique
	t.id = id
	t.rank = rank
	t.color = color
	t.origin = HitQuery.flat(caster.global_position)
	t.dir = HitQuery.flat(caster.facing.facing_direction).normalized()
	var to_aim: Vector3 = HitQuery.flat(caster.facing.aim_point) - t.origin
	t.aim = t.origin + to_aim.limit_length(maxf(ability.max_range, 1.0))
	return t


func kit() -> KitState:
	return caster.kit


func tree() -> SceneTree:
	return caster.get_tree()


func alive() -> bool:
	return is_instance_valid(caster) and caster.is_inside_tree() and not caster.is_dead()


# --- Numbers ------------------------------------------------------------------------

## Damage relative to the rank's base, scaled by the caster's bonuses.
func dmg(mult: float = 1.0) -> float:
	var power: float = 1.0 + _bonus(&"jutsu_power")
	return RANK_DAMAGE[clampi(rank, 0, 4)] * mult * power


func _bonus(stat: StringName) -> float:
	return float(caster.data.stat_bonuses.get(stat, 0.0))


# --- Queries ------------------------------------------------------------------------

func is_enemy(f: CombatCharacter) -> bool:
	return f != null and is_instance_valid(f) and f.team != caster.team and not f.is_dead() and f.visible


func is_ally(f: CombatCharacter) -> bool:
	return f != null and is_instance_valid(f) and f.team == caster.team and not f.is_dead()


func fighters() -> Array[CombatCharacter]:
	var out: Array[CombatCharacter] = []
	for node: Node in tree().get_nodes_in_group(&"fighters"):
		var f := node as CombatCharacter
		if f != null and not f.is_dead() and f.is_inside_tree():
			out.append(f)
	return out


func enemies_in(center: Vector3, radius: float) -> Array[CombatCharacter]:
	var out: Array[CombatCharacter] = []
	for f: CombatCharacter in fighters():
		if f.team != caster.team and HitQuery.flat(f.global_position - center).length() <= radius + HitQuery.HURTBOX_RADIUS:
			out.append(f)
	return out


func allies_in(center: Vector3, radius: float, include_self: bool = true) -> Array[CombatCharacter]:
	var out: Array[CombatCharacter] = []
	for f: CombatCharacter in fighters():
		if f.team == caster.team and (include_self or f != caster) \
				and HitQuery.flat(f.global_position - center).length() <= radius + HitQuery.HURTBOX_RADIUS:
			out.append(f)
	return out


func nearest_enemy(center: Vector3, radius: float) -> CombatCharacter:
	var best: CombatCharacter = null
	var best_d: float = radius + HitQuery.HURTBOX_RADIUS
	for f: CombatCharacter in enemies_in(center, radius):
		var d: float = HitQuery.flat(f.global_position - center).length()
		if d <= best_d:
			best = f
			best_d = d
	return best


## Enemies in a cone from `from` along `direction`.
func enemies_in_cone(from: Vector3, direction: Vector3, length: float, degrees: float) -> Array[CombatCharacter]:
	var out: Array[CombatCharacter] = []
	var half: float = deg_to_rad(degrees) * 0.5
	for f: CombatCharacter in enemies_in(from, length):
		var to: Vector3 = HitQuery.flat(f.global_position - from)
		if to.length() < HitQuery.HURTBOX_RADIUS * 1.5 or direction.angle_to(to) <= half:
			out.append(f)
	return out


## Enemies in a rectangle from `from` along `direction`.
func enemies_in_line(from: Vector3, direction: Vector3, length: float, width: float) -> Array[CombatCharacter]:
	var out: Array[CombatCharacter] = []
	var side: Vector3 = direction.cross(Vector3.UP)
	for f: CombatCharacter in enemies_in(from, length + width):
		var to: Vector3 = HitQuery.flat(f.global_position - from)
		var along: float = to.dot(direction)
		if along >= -HitQuery.HURTBOX_RADIUS and along <= length + HitQuery.HURTBOX_RADIUS \
				and absf(to.dot(side)) <= width * 0.5 + HitQuery.HURTBOX_RADIUS:
			out.append(f)
	return out


## Enemy closest to the aim point within `radius` of it (soft targeting).
func target_at_aim(radius: float = 2.5) -> CombatCharacter:
	return nearest_enemy(aim, radius)


func distance(a: Vector3, b: Vector3) -> float:
	return HitQuery.flat(a - b).length()


## Farthest walkable point toward `direction` up to `dist` (stops at walls).
func clear_point(from: Vector3, direction: Vector3, dist: float) -> Vector3:
	var start: Vector3 = from + Vector3.UP * HitQuery.BODY_HEIGHT
	var hit: Dictionary = HitQuery.raycast_world(caster.get_world_3d(), start, start + direction * dist)
	if hit.is_empty():
		return HitQuery.flat(from + direction * dist)
	return HitQuery.flat(hit.position - direction * 0.6)


# --- Hits ---------------------------------------------------------------------------

## Damages `target` through the full pipeline (guard, parry, counters,
## substitution...). opts: stun, root, slow, silence, burn, genjutsu, seal,
## push (distance, away from push_from or the caster), push_from (Vector3),
## launch (seconds), unblockable (bool: ignores guard), no_interrupt.
func hit(target: CombatCharacter, damage: float, opts: Dictionary = {}) -> HitData.Result:
	if not is_enemy(target) or _replay():
		return HitData.Result.IGNORED
	var h := HitData.new()
	h.source = caster
	h.ability = ability
	h.damage = damage
	h.stun_duration = float(opts.get("stun", 0.0))
	h.root_duration = float(opts.get("root", 0.0))
	h.energy_gain = 4.0
	h.opts = opts.duplicate()
	if opts.has("push") and not opts.has("push_from"):
		h.opts.push_from = origin
	var was_guarding: bool = target.guarding
	if opts.get("unblockable", false):
		target.guarding = false
	var result: HitData.Result = target.receive_hit(h)
	if opts.get("unblockable", false):
		target.guarding = was_guarding and not target.is_dead()
	if result != HitData.Result.HIT or target.is_dead() or _remote(target):
		return result   # a forwarded hit gets its extras on the owner's machine
	apply_opts(target, h.opts, dir)
	return result


## Extras of a landed hit, and effects forwarded from another machine (open world).
static func apply_opts(target: CombatCharacter, opts: Dictionary, fallback_dir: Vector3 = Vector3.FORWARD) -> void:
	if target == null or target.is_dead():
		return
	if opts.has("slow"):
		target.status.apply_status(StatusController.Type.SLOW, float(opts.slow))
	if opts.has("silence"):
		target.status.apply_status(StatusController.Type.SILENCE, float(opts.silence))
	if opts.has("burn"):
		target.status.apply_status(StatusController.Type.BURN, float(opts.burn))
	if opts.has("genjutsu"):
		target.status.apply_status(StatusController.Type.INCAPACITATE, float(opts.genjutsu))
		target.abilities.interrupt()
	if opts.has("seal"):
		target.status.apply_status(StatusController.Type.SEAL, float(opts.seal))
	if opts.has("status_type"):
		var type: StatusController.Type = int(opts.status_type) as StatusController.Type
		if not (type == StatusController.Type.STUN and target.kit.has_flag("cc_immune")):
			target.status.apply_status(type, float(opts.status_dur))
			if type == StatusController.Type.STUN or type == StatusController.Type.INCAPACITATE:
				target.abilities.interrupt()
	if opts.has("push"):
		var direction: Vector3 = opts.push_vec if opts.has("push_vec") else HitQuery.flat(target.global_position - (opts.get("push_from", target.global_position) as Vector3))
		if direction.length() < 0.01:
			direction = fallback_dir
		var duration: float = float(opts.get("push_dur", 0.18))
		var d: float = float(opts.push) * _tenacity_of(target)
		target.movement.apply_forced_motion(HitQuery.flat(direction).normalized() * (d / duration), duration, true, true)
	if opts.has("pull_to"):
		var to: Vector3 = HitQuery.flat((opts.pull_to as Vector3) - target.global_position)
		var dist: float = float(opts.get("pull_dist", -1.0))
		var duration: float = float(opts.get("pull_dur", 0.2))
		var d: float = (to.length() - 1.0 if dist < 0.0 else minf(dist, to.length() - 1.0)) * _tenacity_of(target)
		if d > 0.05:
			target.movement.apply_forced_motion(to.normalized() * (d / duration), duration, false, true)
	if opts.has("launch") and not target.data.launch_immune and not target.kit.has_flag("tenacity") and not target.is_launched():
		target.launch(float(opts.launch))
	if opts.has("heal"):
		target.health.heal(float(opts.heal))
	if opts.has("shield"):
		target.health.add_shield(float(opts.shield), float(opts.get("shield_dur", 3.0)))


## Open world: this cast is a puppet replay (visual only, it affects no one).
func _replay() -> bool:
	return caster.net_mode == CombatCharacter.NetMode.PUPPET


## Open world: `target` is owned by another machine (effects are forwarded to it).
func _remote(target: CombatCharacter) -> bool:
	return WorldNet.active and target != null and target.net_mode == CombatCharacter.NetMode.PUPPET


## Forwards an effect to a remote target; true when the caller must stop there.
func _forwarded(target: CombatCharacter, opts: Dictionary) -> bool:
	if _replay():
		return true
	if _remote(target):
		WorldNet.forward_effect(caster, target, opts)
		return true
	return false


## Hits every enemy in a radius; returns those actually hit.
func area(center: Vector3, radius: float, damage: float, opts: Dictionary = {}) -> Array[CombatCharacter]:
	var out: Array[CombatCharacter] = []
	for e: CombatCharacter in enemies_in(center, radius):
		var o: Dictionary = opts.duplicate()
		if o.has("push") and not o.has("push_from"):
			o.push_from = center
		if hit(e, damage, o) == HitData.Result.HIT:
			out.append(e)
	KitObject.damage_objects_in(tree(), center, radius, caster.team, damage)
	return out


func cone(length: float, degrees: float, damage: float, opts: Dictionary = {}, from: Vector3 = Vector3.INF, direction: Vector3 = Vector3.ZERO) -> Array[CombatCharacter]:
	var o_from: Vector3 = origin if from == Vector3.INF else from
	var o_dir: Vector3 = dir if direction == Vector3.ZERO else direction
	if CombatFx.is_enabled():
		CombatFx.arc(caster, o_from, o_dir, length, degrees, color, 0.2)
	var out: Array[CombatCharacter] = []
	for e: CombatCharacter in enemies_in_cone(o_from, o_dir, length, degrees):
		if hit(e, damage, opts) == HitData.Result.HIT:
			out.append(e)
	KitObject.damage_objects_in(tree(), o_from + o_dir * length * 0.5, length * 0.5, caster.team, damage)
	return out


func line(length: float, width: float, damage: float, opts: Dictionary = {}, from: Vector3 = Vector3.INF, direction: Vector3 = Vector3.ZERO) -> Array[CombatCharacter]:
	var o_from: Vector3 = origin if from == Vector3.INF else from
	var o_dir: Vector3 = dir if direction == Vector3.ZERO else direction
	if CombatFx.is_enabled():
		var mi := KitVisuals.line_visual(caster.get_parent(), color, id)
		KitVisuals.update_line(mi, o_from, o_from + o_dir * length)
		caster.get_tree().create_timer(0.2).timeout.connect(mi.queue_free)
	var out: Array[CombatCharacter] = []
	for e: CombatCharacter in enemies_in_line(o_from, o_dir, length, width):
		if hit(e, damage, opts) == HitData.Result.HIT:
			out.append(e)
	return out


## Melee swing in front of the caster (uses the caster's facing).
func melee(reach: float, degrees: float, damage: float, opts: Dictionary = {}) -> Array[CombatCharacter]:
	return cone(reach, degrees, damage, opts)


func heal(target: CombatCharacter, amount: float) -> void:
	if _forwarded(target, {"heal": amount}):
		return
	if target != null and not target.is_dead():
		amount *= target.kit.modifier_mult("heal_taken")  # anti-heal debuffs (SS "soins réduits")
		target.health.heal(amount)
		if CombatFx.is_enabled():
			CombatFx.damage_number(target, target.global_position + Vector3.UP * 2.2, amount, Color(0.4, 1.0, 0.5), "+%d" % roundi(amount))


func shield(target: CombatCharacter, amount: float, duration: float) -> void:
	if _forwarded(target, {"shield": amount, "shield_dur": duration}):
		return
	if target != null and not target.is_dead():
		target.health.add_shield(amount, duration)


func status(target: CombatCharacter, type: StatusController.Type, duration: float) -> void:
	if _forwarded(target, {"status_type": int(type), "status_dur": duration}):
		return
	if target != null and not target.is_dead():
		if type == StatusController.Type.STUN and target.kit.has_flag("cc_immune"):
			return
		target.status.apply_status(type, duration)
		if type == StatusController.Type.STUN or type == StatusController.Type.INCAPACITATE:
			target.abilities.interrupt()


## Removes light debuffs (slow, root, burn...); `hard` also stun / silence / seal.
func cleanse(target: CombatCharacter, hard: bool = false) -> int:
	var removed: int = 0
	var types: Array = [StatusController.Type.SLOW, StatusController.Type.ROOT, StatusController.Type.BURN, StatusController.Type.MARK, StatusController.Type.LOCK]
	if hard:
		types += [StatusController.Type.STUN, StatusController.Type.SILENCE, StatusController.Type.SEAL, StatusController.Type.INCAPACITATE]
	for type: StatusController.Type in types:
		if target.status.has_status(type):
			target.status.remove_status(type)
			removed += 1
	return removed


# --- Forced movement (push / pull / launch / drag) ----------------------------------

func _tenacity(target: CombatCharacter) -> float:
	return _tenacity_of(target)


static func _tenacity_of(target: CombatCharacter) -> float:
	return 0.25 if target.kit.has_flag("tenacity") else 1.0


func push(target: CombatCharacter, direction: Vector3, dist: float, duration: float = 0.18) -> void:
	if target == null or target.is_dead() or direction.length() < 0.01:
		direction = dir
	if _forwarded(target, {"push": dist, "push_vec": direction, "push_dur": duration}):
		return
	var d: float = dist * _tenacity(target)
	target.movement.apply_forced_motion(HitQuery.flat(direction).normalized() * (d / duration), duration, true, true)


func pull(target: CombatCharacter, to_point: Vector3, dist: float = -1.0, duration: float = 0.2) -> void:
	if target == null or target.is_dead():
		return
	if _forwarded(target, {"pull_to": to_point, "pull_dist": dist, "pull_dur": duration}):
		return
	var to: Vector3 = HitQuery.flat(to_point - target.global_position)
	var d: float = (to.length() - 1.0 if dist < 0.0 else minf(dist, to.length() - 1.0)) * _tenacity(target)
	if d <= 0.05:
		return
	target.movement.apply_forced_motion(to.normalized() * (d / duration), duration, false, true)


func launch(target: CombatCharacter, duration: float) -> void:
	if target == null or target.is_dead() or target.data.launch_immune or target.kit.has_flag("tenacity"):
		return
	if target.is_launched():
		return
	if _forwarded(target, {"launch": duration}):
		return
	target.launch(duration)


## Moves the caster (dash). Returns the expected end point.
func dash(dist: float, direction: Vector3 = Vector3.ZERO, duration: float = 0.15, immaterial: bool = false) -> Vector3:
	var d: Vector3 = dir if direction == Vector3.ZERO else HitQuery.flat(direction).normalized()
	caster.movement.apply_forced_motion(d * (dist / duration), duration, false)
	if immaterial:
		caster.status.apply_status(StatusController.Type.IMMATERIAL, duration)
	return clear_point(caster.global_position, d, dist)


## Teleports the caster (or `who`) to the nearest clear point toward `to`.
func blink(to: Vector3, who: CombatCharacter = null) -> Vector3:
	var f: CombatCharacter = caster if who == null else who
	var from: Vector3 = HitQuery.flat(f.global_position)
	var direction: Vector3 = HitQuery.flat(to - from)
	var dest: Vector3 = to if direction.length() < 0.05 else clear_point(from, direction.normalized(), direction.length())
	if CombatFx.is_enabled():
		SpellVfx.smoke(f, from, 0.7)
	f.movement.stop()
	f.global_position = Vector3(dest.x, 0.0, dest.z)
	if CombatFx.is_enabled():
		SpellVfx.smoke(f, dest, 0.7)
	return dest


# --- Spawns -------------------------------------------------------------------------

## opts: speed (18), range (ability.max_range), radius (0.6), dir, from,
## pierce, homing (rad/s, aims at target_at_aim or the nearest enemy in
## front), homing_target, lob_to (Vector3: lobbed to that point),
## hit_in_flight, hits_allies, size, color, data, on_hit(target, proj) -> bool,
## on_end(point, proj, reason), on_tick(proj, delta).
func projectile(opts: Dictionary = {}) -> TkProjectile:
	var p := TkProjectile.new()
	p.caster = caster
	p.team = caster.team
	p.technique_id = id
	p.direction = HitQuery.flat(opts.get("dir", dir)).normalized()
	p.speed = float(opts.get("speed", 18.0))
	p.max_range = float(opts.get("range", maxf(ability.max_range, 6.0)))
	p.hit_radius = float(opts.get("radius", 0.6))
	p.pierce = bool(opts.get("pierce", false))
	p.homing = float(opts.get("homing", 0.0))
	if p.homing > 0.0:
		p.homing_target = opts.get("homing_target", null)
		if p.homing_target == null:
			p.homing_target = _front_enemy(p.max_range)
	if opts.has("lob_to"):
		p.lob = true
		p.lob_to = HitQuery.flat(opts.lob_to)
		p.hit_in_flight = bool(opts.get("hit_in_flight", false))
	else:
		p.hit_in_flight = bool(opts.get("hit_in_flight", true))
	p.hits_allies = bool(opts.get("hits_allies", false))
	p.size = float(opts.get("size", 0.28))
	p.color = opts.get("color", color)
	p.on_hit = opts.get("on_hit", Callable())
	p.on_end = opts.get("on_end", Callable())
	p.on_tick = opts.get("on_tick", Callable())
	p.data = opts.get("data", {})
	var from: Vector3 = opts.get("from", origin)
	caster.get_parent().add_child(p)
	p.global_position = HitQuery.flat(from) + Vector3.UP * HitQuery.BODY_HEIGHT + p.direction * 0.5
	return p


func _front_enemy(max_range: float) -> CombatCharacter:
	var t: CombatCharacter = target_at_aim(3.0)
	if t != null:
		return t
	var cone_targets: Array[CombatCharacter] = enemies_in_cone(origin, dir, max_range, 60.0)
	return cone_targets[0] if not cone_targets.is_empty() else null


## Persistent object. opts: radius, lifetime, health, look (KitObject.Look),
## kind, color, blocks_projectiles, blocks_movement, targetable,
## tick_interval, on_enter, on_exit, on_tick, on_expire, on_destroy,
## on_projectile, data (Dictionary).
func object(center: Vector3, opts: Dictionary = {}) -> KitObject:
	var o := KitObject.new()
	o.owner_character = caster
	o.team = caster.team
	o.technique_id = id
	o.kind = String(opts.get("kind", ""))
	o.radius = float(opts.get("radius", 2.0))
	o.lifetime = float(opts.get("lifetime", 5.0))
	o.health = float(opts.get("health", -1.0))
	o.max_health = o.health
	o.look = opts.get("look", KitObject.Look.DISC)
	o.color = opts.get("color", color)
	o.blocks_projectiles = bool(opts.get("blocks_projectiles", false))
	o.blocks_movement = bool(opts.get("blocks_movement", false))
	o.targetable = bool(opts.get("targetable", true))
	o.tick_interval = float(opts.get("tick_interval", 0.0))
	o.on_enter = opts.get("on_enter", Callable())
	o.on_exit = opts.get("on_exit", Callable())
	o.on_tick = opts.get("on_tick", Callable())
	o.on_expire = opts.get("on_expire", Callable())
	o.on_destroy = opts.get("on_destroy", Callable())
	o.on_projectile = opts.get("on_projectile", Callable())
	o.data = opts.get("data", {})
	if opts.has("facing"):
		o.facing = HitQuery.flat(opts.facing).normalized()
	if opts.has("half_extents"):
		o.half_extents = opts.half_extents
	caster.get_parent().add_child(o)
	o.global_position = HitQuery.flat(center)
	return o


## Ground zone (disc): shortcut for object() with Look.DISC.
func zone(center: Vector3, radius: float, lifetime: float, opts: Dictionary = {}) -> KitObject:
	var o: Dictionary = opts.duplicate()
	o.radius = radius
	o.lifetime = lifetime
	o.kind = opts.get("kind", "zone")
	return object(center, o)


## Wall across `direction` (perpendicular to it), blocking movement and
## projectiles unless opts say otherwise.
func wall(center: Vector3, direction: Vector3, length: float, lifetime: float, opts: Dictionary = {}) -> KitObject:
	var o: Dictionary = opts.duplicate()
	o.look = KitObject.Look.WALL
	o.facing = direction
	o.half_extents = Vector2(length * 0.5, float(opts.get("thickness", 0.6)) * 0.5)
	o.radius = length * 0.5
	o.lifetime = lifetime
	o.kind = opts.get("kind", "wall")
	o.blocks_projectiles = opts.get("blocks_projectiles", true)
	o.blocks_movement = opts.get("blocks_movement", true)
	o.health = opts.get("health", 60.0)
	return object(center, o)


## Telegraphed delayed effect: a ring at `center` for `delay` seconds, then
## `then.call(t)` (t refreshed). Returns the telegraph object.
func telegraph(center: Vector3, radius: float, delay: float, then: Callable) -> KitObject:
	return object(center, {"radius": radius, "lifetime": delay, "look": KitObject.Look.RING, "targetable": false,
		"kind": "telegraph", "on_expire": func(_o: KitObject) -> void:
			if alive():
				then.call(refreshed())})


## Link between the caster (or `a`) and `b`. Breaks beyond `max_dist` or when
## either dies. opts: on_tick(tether_obj), on_break(), lifetime, interval.
func tether(b: CombatCharacter, max_dist: float, lifetime: float, opts: Dictionary = {}, a: CombatCharacter = null) -> KitObject:
	var from_char: CombatCharacter = caster if a == null else a
	var on_break: Callable = opts.get("on_break", Callable())
	var user_tick: Callable = opts.get("on_tick", Callable())
	var line_node: MeshInstance3D = KitVisuals.line_visual(caster.get_parent(), color, id) if CombatFx.is_enabled() else null
	var o: KitObject = object(from_char.global_position, {"radius": 0.1, "lifetime": lifetime, "look": KitObject.Look.NONE,
		"targetable": false, "kind": "tether", "tick_interval": float(opts.get("interval", 0.0)),
		"on_tick": func(obj: KitObject) -> void:
			if not is_instance_valid(from_char) or not is_instance_valid(b) or from_char.is_dead() or b.is_dead() \
					or distance(from_char.global_position, b.global_position) > max_dist:
				obj.data["broken"] = true
				obj.destroy("broken")
				return
			obj.global_position = HitQuery.flat(from_char.global_position)
			if line_node != null and is_instance_valid(line_node):
				KitVisuals.update_line(line_node, from_char.global_position, b.global_position)
			if user_tick.is_valid():
				user_tick.call(obj),
		"on_destroy": func(obj: KitObject, _reason: String) -> void:
			if line_node != null and is_instance_valid(line_node):
				line_node.queue_free()
			if obj.data.get("broken", false) and on_break.is_valid():
				on_break.call()})
	o.data["target"] = b
	return o


## Shadow-clone style decoy body (Naruto's clone entity): mirrors melee.
func clone(at: Vector3, duration: float) -> ShadowClone:
	caster.dismiss_clone()
	caster.clone = ShadowClone.spawn(caster, HitQuery.flat(at), duration)
	return caster.clone


## Runs `pulse.call(t, i)` every `interval` for `count` pulses while the
## caster can act (channel). Caster slowed while channelling; ends early on
## stun. `done.call(t, completed)` at the end.
func channel(count: int, interval: float, pulse: Callable, done: Callable = Callable(), move_mult: float = 0.35) -> void:
	var mod_id: String = "channel_" + String(id)
	kit().add_modifier(mod_id, interval * count + 0.1, {"speed": move_mult})
	_channel_step(0, count, interval, pulse, done, mod_id)


func _channel_step(i: int, count: int, interval: float, pulse: Callable, done: Callable, mod_id: String) -> void:
	if not alive() or not caster.status.can_act():
		kit().remove_modifier(mod_id)
		if done.is_valid() and is_instance_valid(caster):
			done.call(refreshed(), false)
		return
	pulse.call(refreshed(), i)
	if i + 1 >= count:
		kit().remove_modifier(mod_id)
		if done.is_valid():
			done.call(refreshed(), true)
		return
	kit().after(interval, func() -> void: _channel_step(i + 1, count, interval, pulse, done, mod_id))


# --- Kit state ----------------------------------------------------------------------

func mark(target: CombatCharacter, key: String, stacks: int = 1, duration: float = 5.0, max_stacks: int = 3, label: String = "") -> int:
	if target == null or target.is_dead():
		return 0
	return target.kit.add_mark(key, stacks, duration, max_stacks, caster, label, color)


func marks(target: CombatCharacter, key: String) -> int:
	return target.kit.mark(key) if target != null and is_instance_valid(target) else 0


func consume_mark(target: CombatCharacter, key: String) -> int:
	return target.kit.consume_mark(key) if target != null and is_instance_valid(target) else 0


func res(key: String) -> float:
	return kit().res(key)


func add_res(key: String, amount: float) -> float:
	return kit().add_res(key, amount)


func spend_res(key: String, amount: float) -> bool:
	return kit().spend_res(key, amount)


func take_all_res(key: String) -> float:
	return kit().take_all_res(key)


## Opens a recast window on this technique: pressing it again within
## `seconds` calls `then.call(t)` (t refreshed) instead of casting.
func recast(seconds: float, then: Callable, on_expire: Callable = Callable()) -> void:
	kit().open_recast(id, seconds, func() -> void:
		if alive():
			then.call(refreshed()), on_expire)


## Buff / mode on the caster (see KitState.add_modifier for props).
func buff(key: String, seconds: float, props: Dictionary = {}) -> void:
	kit().add_modifier(key, seconds, props)


func debuff(target: CombatCharacter, key: String, seconds: float, props: Dictionary = {}) -> void:
	if target != null and not target.is_dead():
		target.kit.add_modifier(key, seconds, props)


## Runs `then.call(t)` after `seconds` (t refreshed; skipped if the caster died).
func after(seconds: float, then: Callable) -> void:
	kit().after(seconds, func() -> void:
		if alive():
			then.call(refreshed()))


## Alive objects of the caster: of this technique by default, of
## `technique`, or of any technique with technique = &"".
func objects(kind_filter: String = "", technique: StringName = &"self") -> Array[KitObject]:
	return KitObject.find(tree(), caster, id if technique == &"self" else technique, kind_filter)


# --- Feedback -----------------------------------------------------------------------

func fx(effect: String, at: Vector3, radius: float = 1.5, fx_color: Color = Color(0, 0, 0, 0)) -> void:
	KitVisuals.fx(caster, effect, at, radius, color if fx_color.a == 0.0 else fx_color, id)


func text(target: CombatCharacter, words: String, text_color: Color = Color(0, 0, 0, 0)) -> void:
	if CombatFx.is_enabled() and target != null and is_instance_valid(target):
		CombatFx.damage_number(target, target.global_position + Vector3.UP * 2.6, 0.0, color if text_color.a == 0.0 else text_color, words)
