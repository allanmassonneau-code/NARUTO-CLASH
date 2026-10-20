extends RefCounted
## Technique kit: clan_akimichi (design bible). Signature: Calories — a
## dedicated gauge ("calories" resource) that refills slowly outside big
## spends (regen pauses 2.5 s after any spend) and when basic attacks land.
## Techniques spend different amounts; at low Calories advanced techniques
## lose variants. Techniques really change the body volume: K.set_size
## scales the hurtbox (easier to hit) and the model.

const KIT_ID := &"clan_akimichi"
const SIGNATURE = AkimichiSignature
const TECHNIQUES := {
	&"clan_akimichi_d_poing_d_expansion": PoingDExpansion,
	&"clan_akimichi_c_corps_belier": CorpsBelier,
	&"clan_akimichi_b_boulet_humain": BouletHumain,
	&"clan_akimichi_a_mode_papillon": ModePapillon,
	&"clan_akimichi_s_expansion_colossale_chute_du_titan": ChuteDuTitan,
}

const CAL := "calories"
const CAL_MAX: float = 100.0
const LOW_CAL: float = 25.0
const ORANGE := Color(1.0, 0.6, 0.25)
const WINGS := Color(1.0, 0.45, 0.7)


## Calories: regen 4/s once nothing was spent for 2.5 s; +3 per basic hit.
class AkimichiSignature extends KitSignature:
	var _last: float = 0.0
	var _pause: float = 0.0

	func setup(f: CombatCharacter) -> void:
		f.kit.define_resource(CAL, CAL_MAX, "Calories", ORANGE)
		f.kit.add_res(CAL, 60.0)
		_last = f.kit.res(CAL)

	func tick(f: CombatCharacter, dt: float) -> void:
		var v: float = f.kit.res(CAL)
		if v < _last - 0.001:
			_pause = 2.5
		_pause = maxf(0.0, _pause - dt)
		if _pause <= 0.0 and v < CAL_MAX and not f.is_dead():
			v = minf(CAL_MAX, v + 4.0 * dt)
			f.kit.resources[CAL].value = v
		_last = v

	func on_deal(f: CombatCharacter, _target: CombatCharacter, hit: HitData, _damage: float) -> Variant:
		if hit.ability != null and f.abilities.is_basic_attack(hit.ability):
			f.kit.add_res(CAL, 3.0)
			_last = f.kit.res(CAL)
		return null


## Shared Akimichi rules: body volume, butterfly widening, low Calories.
class K:
	## Sets a named size factor; the body uses the largest active one.
	static func set_size(f: CombatCharacter, key: String, s: float) -> void:
		if not is_instance_valid(f):
			return
		var sizes: Dictionary = f.get_meta("akimichi_sizes", {})
		sizes[key] = s
		f.set_meta("akimichi_sizes", sizes)
		_apply(f, sizes)

	static func clear_size(f: CombatCharacter, key: String) -> void:
		if not is_instance_valid(f):
			return
		var sizes: Dictionary = f.get_meta("akimichi_sizes", {})
		sizes.erase(key)
		f.set_meta("akimichi_sizes", sizes)
		_apply(f, sizes)

	static func _apply(f: CombatCharacter, sizes: Dictionary) -> void:
		var s: float = 1.0
		for k: String in sizes:
			s = maxf(s, float(sizes[k]))
		if is_instance_valid(f.hurtbox):
			f.hurtbox.scale = Vector3.ONE * s
		if f.presentation != null and is_instance_valid(f.presentation.visual_pivot):
			f.presentation.visual_pivot.scale = Vector3.ONE * s

	## Collisions of Akimichi techniques are slightly enlarged in Mode papillon.
	static func wide(t: Tk) -> float:
		return 1.2 if t.kit().has_modifier("papillon") else 1.0

	static func low(t: Tk) -> bool:
		return t.res(CAL) < LOW_CAL


## D — Mêlée extensible, Sweet spot, Ressource. Slow, growing punch along a
## line (3.8 m). The fist tip is the sweet spot (strong push); too close =
## little push. If the nearest enemy stands just beyond reach, 8 Calories
## extend the arm by 1.4 m at the last moment. A whiff leaves the arm out
## (heavy slow on the caster).
class PoingDExpansion extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.38
		a.recovery_time = 0.3
		a.cast_move_multiplier = 0.2
		a.max_range = 5.2
		a.anim = &"jab"

	func cast(t: Tk) -> void:
		var width: float = 1.1 * K.wide(t)
		var reach: float = 3.8 * K.wide(t)
		var beyond: Array[CombatCharacter] = t.enemies_in_line(t.origin, t.dir, reach + 1.4, width)
		var extend: bool = false
		for e: CombatCharacter in beyond:
			if t.distance(e.global_position, t.origin) > reach:
				extend = true
		for e: CombatCharacter in beyond:
			if t.distance(e.global_position, t.origin) <= reach:
				extend = false
		if extend and t.spend_res(CAL, 8.0):
			reach += 1.4
			t.text(t.caster, "EXTENSION", ORANGE)
		t.fx("burst", t.origin + t.dir * reach, 0.8, ORANGE)
		var touched: int = 0
		for e: CombatCharacter in t.enemies_in_line(t.origin, t.dir, reach, width):
			var sweet: bool = t.distance(e.global_position, t.origin) >= reach - 1.5
			if t.hit(e, t.dmg(0.8 if sweet else 0.5), {"push": 3.5 if sweet else 0.8}) == HitData.Result.HIT:
				touched += 1
				if sweet:
					t.fx("rocks", e.global_position, 0.7, ORANGE)
		if touched == 0:
			t.buff("bras_tendu", 0.5, {"speed": 0.25, "label": "Bras tendu", "color": ORANGE})


## C — Charge, Armor, Collision. 7 m charge with a bigger torso (hurtbox
## x1.35): the first light control received is ignored (stun / root /
## knockback, damage unchanged). The first enemy hit is carried until the
## end; hitting a wall or structure ends the charge with a stronger impact
## (short 0.35 s stun, no long stun).
class CorpsBelier extends Technique:
	const SPEED: float = 15.5
	const TIME: float = 0.45

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.15
		a.recovery_time = 0.25
		a.max_range = 7.0
		a.anim = &"dash"

	func cast(t: Tk) -> void:
		var d: Vector3 = t.dir
		var state := {"carry": null, "done": false, "armor_used": false}
		K.set_size(t.caster, "belier", 1.35)
		t.caster.movement.apply_forced_motion(d * SPEED, TIME, false)
		var finish := func(wall: bool) -> void:
			if bool(state.done):
				return
			state.done = true
			var carried: CombatCharacter = state.carry as CombatCharacter
			if wall:
				t.caster.movement.cancel_forced()
				t.fx("cracks", t.caster.global_position + d * 0.8, 1.4, ORANGE)
				if t.is_enemy(carried):
					carried.movement.cancel_forced()
					t.hit(carried, t.dmg(0.7), {"stun": 0.35})
			elif t.is_enemy(carried):
				t.push(carried, d, 1.5)
			t.after(0.3, func(_rt: Tk) -> void:
				K.clear_size(t.caster, "belier"))
		var props: Dictionary = {"cc_immune": true, "label": "Bélier", "color": ORANGE}
		props["on_take"] = func(hit: HitData, _dmg: float) -> Variant:
			if bool(state.armor_used):
				return null
			if hit.stun_duration > 0.0 or hit.root_duration > 0.0 or hit.knockback_velocity != Vector3.ZERO:
				state.armor_used = true
				hit.root_duration = 0.0
				hit.knockback_velocity = Vector3.ZERO
				t.text(t.caster, "ARMURE", ORANGE)
				t.kit().after(0.0, func() -> void:
					if t.kit().modifiers.has("belier"):
						t.kit().modifiers["belier"].props["cc_immune"] = false)
			return null
		props["on_tick"] = func(_dt: float) -> void:
			if bool(state.done):
				return
			if not t.caster.movement.is_forced():
				finish.call(false)
				return
			var pos: Vector3 = HitQuery.flat(t.caster.global_position)
			var ahead: float = 1.7 if state.carry != null else 0.9
			var start: Vector3 = pos + Vector3.UP * HitQuery.BODY_HEIGHT
			if not HitQuery.raycast_world(t.caster.get_world_3d(), start, start + d * ahead).is_empty():
				finish.call(true)
				return
			var carried: CombatCharacter = state.carry as CombatCharacter
			if carried == null:
				var e: CombatCharacter = t.nearest_enemy(pos + d * 0.8, 0.9 * K.wide(t))
				if e != null and t.hit(e, t.dmg(0.45)) == HitData.Result.HIT:
					state.carry = e
					carried = e
			if t.is_enemy(carried):
				if t.distance(carried.global_position, pos + d * 1.1) > 1.8:
					state.carry = null
				else:
					carried.movement.apply_forced_motion(d * SPEED, 0.06, false)
		props["on_end"] = func() -> void:
			finish.call(false)
		t.buff("belier", TIME + 0.15, props)


## B — Mode déplacement, Inertie, Recast. Rolls as a ball for up to 5 s:
## accelerates (6 -> 13 m/s), steers toward the cursor with inertia (slower
## turns at speed), bounces off walls instead of stopping. Each enemy is
## hit once per roll. Strong CC (stun / root) stops it. Recast: circular
## braking that repels around the stop point.
class BouletHumain extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.max_range = 12.0
		a.anim = &"dash"

	func cast(t: Tk) -> void:
		var state := {"heading": t.dir, "speed": 6.0, "hit": [], "ended": false}
		K.set_size(t.caster, "boulet", 1.2)
		var finish := func(brake: bool) -> void:
			if bool(state.ended):
				return
			state.ended = true
			t.kit().remove_modifier("boulet")
			K.clear_size(t.caster, "boulet")
			if not t.alive():
				return
			t.caster.movement.cancel_forced()
			if brake:
				var at: Vector3 = HitQuery.flat(t.caster.global_position)
				t.fx("wave", at, 2.8, ORANGE)
				t.area(at, 2.8 * K.wide(t), t.dmg(0.4), {"push": 3.5})
			else:
				t.kit().close_recast(t.id)
		t.buff("boulet", 5.0, {"label": "Boulet", "color": ORANGE,
			"on_tick": func(dt: float) -> void:
				_roll(t, state, dt, finish),
			"on_end": func() -> void:
				finish.call(false)})
		t.recast(5.0, func(_rt: Tk) -> void:
			finish.call(true))

	func _roll(t: Tk, state: Dictionary, dt: float, finish: Callable) -> void:
		if bool(state.ended) or not t.alive():
			return
		if not t.caster.status.can_act() or t.caster.status.has_status(StatusController.Type.ROOT):
			finish.call(false)
			return
		var speed: float = minf(13.0, float(state.speed) + 4.0 * dt)
		var heading: Vector3 = state.heading
		var pos: Vector3 = HitQuery.flat(t.caster.global_position)
		var want: Vector3 = HitQuery.flat(t.caster.facing.aim_point - pos)
		if want.length() > 0.5:
			var turn: float = (2.6 - speed * 0.12) * dt
			var angle: float = heading.signed_angle_to(want.normalized(), Vector3.UP)
			heading = heading.rotated(Vector3.UP, clampf(angle, -turn, turn)).normalized()
		var start: Vector3 = pos + Vector3.UP * HitQuery.BODY_HEIGHT
		var wall: Dictionary = HitQuery.raycast_world(t.caster.get_world_3d(), start, start + heading * 0.9)
		if not wall.is_empty():
			var n: Vector3 = HitQuery.flat(wall.normal)
			if n.length() > 0.1:
				heading = HitQuery.flat(heading.bounce(n.normalized())).normalized()
				speed *= 0.7
				t.fx("dust", pos, 0.8, ORANGE)
		state.heading = heading
		state.speed = speed
		t.caster.movement.apply_forced_motion(heading * speed, 0.1, false)
		var already: Array = state.hit
		for e: CombatCharacter in t.enemies_in(pos, 0.9 * K.wide(t)):
			if already.has(e):
				continue
			already.append(e)
			var away: Vector3 = HitQuery.flat(e.global_position - pos).normalized() + heading
			if t.hit(e, t.dmg(0.3 + 0.035 * speed)) == HitData.Result.HIT:
				t.push(e, away, 2.5)


## A — Transformation, Conversion HP/Calories, Tempo. Chakra wings for 8 s:
## Calories drain (12/s) for +30 % damage, +25 % basic damage and +30 %
## speed (no speed variant if started below 25 Calories). At 0 Calories the
## mode burns 5 % max HP/s instead (cannot kill). Akimichi collisions are
## enlarged x1.2 meanwhile. Recast: cut the mode at any time; ending it after
## burning HP leaves the caster exhausted (slow).
class ModePapillon extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.max_range = 1.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var low: bool = K.low(t)
		var state := {"burned": false}
		t.fx("spheres", t.origin, 1.6, WINGS)
		t.text(t.caster, "PAPILLON", WINGS)
		t.buff("papillon", 8.0, {"damage_dealt": 1.3, "basic_damage": 1.25, "speed": 1.0 if low else 1.3,
			"label": "Papillon", "color": WINGS,
			"on_tick": func(dt: float) -> void:
				if not t.alive():
					return
				if t.res(CAL) > 0.0:
					t.add_res(CAL, -12.0 * dt)
				else:
					state.burned = true
					t.caster.health.drain(t.caster.health.max_health * 0.05 * dt),
			"on_end": func() -> void:
				t.kit().close_recast(t.id)
				if bool(state.burned) and t.alive():
					t.status(t.caster, StatusController.Type.SLOW, 1.5)
					t.text(t.caster, "ÉPUISÉ", WINGS)})
		t.recast(8.0, func(rt: Tk) -> void:
			rt.kit().remove_modifier("papillon")
			rt.fx("burst", rt.origin, 1.0, WINGS))


## S — Giant form, Zone, Terrain, Finisher. Becomes gigantic (x2.2, slow,
## tenacity) and marks an impact point long in advance; all Calories are
## consumed at the cast and set the wave radius (3 -> 9 m). After 3 s (or on
## recast) he crashes onto the point: centre (2 m) = heavy capped hit +
## 0.5 s stun; edge = mostly pushed away. With >= 15 Calories the impact
## leaves a slowing crater.
class ChuteDuTitan extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.6
		a.cast_move_multiplier = 0.1
		a.max_range = 12.0
		a.anim = &"stomp"

	func cast(t: Tk) -> void:
		var cal: float = t.take_all_res(CAL)
		var radius: float = 3.0 + 6.0 * cal / CAL_MAX
		var point: Vector3 = t.aim
		var state := {"done": false}
		K.set_size(t.caster, "titan", 2.2)
		t.fx("column", t.origin, 1.5, ORANGE)
		t.buff("titan", 3.2, {"speed": 0.55, "tenacity": true, "label": "Titan", "color": ORANGE,
			"on_end": func() -> void:
				K.clear_size(t.caster, "titan")})
		var marker: KitObject = t.object(point, {"kind": "impact", "radius": radius, "lifetime": 3.0,
			"look": KitObject.Look.RING, "targetable": false, "color": ORANGE,
			"on_expire": func(_o: KitObject) -> void:
				if t.alive():
					_slam(t.refreshed(), point, radius, cal, state)})
		t.object(point, {"kind": "impact_centre", "radius": 2.0, "lifetime": 3.0, "look": KitObject.Look.DISC,
			"targetable": false, "color": Color(1.0, 0.3, 0.1)})
		t.recast(2.9, func(rt: Tk) -> void:
			_slam(rt, point, radius, cal, state)
			if marker.is_alive():
				marker.destroy("slammed"))

	func _slam(t: Tk, point: Vector3, radius: float, cal: float, state: Dictionary) -> void:
		if bool(state.done):
			return
		state.done = true
		for o: KitObject in t.objects("impact_centre"):
			o.destroy("slammed")
		t.blink(point)
		t.fx("explosion", point, radius, ORANGE)
		t.fx("cracks", point, radius * 0.7, ORANGE)
		for e: CombatCharacter in t.enemies_in(point, radius):
			var d: float = t.distance(e.global_position, point)
			if d <= 2.0:
				t.hit(e, t.dmg(1.6), {"stun": 0.5})
			else:
				var edge: float = clampf((d - 2.0) / maxf(radius - 2.0, 0.1), 0.0, 1.0)
				t.hit(e, t.dmg(0.6 - 0.3 * edge), {"push": 2.5 + 2.5 * edge, "push_from": point})
		KitObject.damage_objects_in(t.tree(), point, radius, t.caster.team, t.dmg(1.0))
		if cal >= 15.0:
			t.zone(point, radius * 0.6, 4.0, {"kind": "cratere", "targetable": false, "color": Color(0.5, 0.35, 0.2),
				"on_enter": func(f: CombatCharacter, _o: KitObject) -> void:
					if t.is_enemy(f):
						t.status(f, StatusController.Type.SLOW, 1.2)})
		t.kit().remove_modifier("titan")
		t.kit().close_recast(t.id)
