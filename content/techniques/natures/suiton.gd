extends RefCounted
## Technique kit: Suiton (design bible §4). Signature: Trempé / Eau — a
## target can be Trempé ("trempe" mark, one stack, short): it is a condition
## read by the rest of the kit, never a big debuff on its own. Water surfaces
## ("eau" objects, any Suiton technique) last a few seconds: the caster
## glides faster on them (SuitonSignature) and some techniques change shape
## when they cross them. Inside a Domaine des profondeurs everyone counts as
## Trempé and the whole area counts as water.

const KIT_ID := &"suiton"
const SIGNATURE = SuitonSignature
const TECHNIQUES := {
	&"suiton_d_aiguille_de_pression": AiguilleDePression,
	&"suiton_d_pas_de_surface": PasDeSurface,
	&"suiton_c_sphere_de_rupture": SphereDeRupture,
	&"suiton_c_rideau_refringent": RideauRefringent,
	&"suiton_b_prison_aqueuse": PrisonAqueuse,
	&"suiton_b_torrent_de_renversement": TorrentDeRenversement,
	&"suiton_a_miroir_liquide": MiroirLiquide,
	&"suiton_a_maree_captive": MareeCaptive,
	&"suiton_s_leviathan_de_pression": LeviathanDePression,
	&"suiton_s_domaine_des_profondeurs": DomaineDesProfondeurs,
}

const TREMPE := "trempe"
const TREMPE_TIME: float = 4.0
const WATER := "eau"
const DOMAINE := "domaine"
const DOMAINE_ID := &"suiton_s_domaine_des_profondeurs"
const WATER_COLOR := Color(0.3, 0.6, 1.0)
const DEEP_COLOR := Color(0.1, 0.25, 0.5)


## Glide: the Suiton fighter moves faster while standing on his own water.
class SuitonSignature extends KitSignature:
	var _check: float = 0.0

	func setup(_fighter: CombatCharacter) -> void:
		_check = 0.0

	func tick(f: CombatCharacter, delta: float) -> void:
		_check -= delta
		if _check > 0.0 or not is_instance_valid(f) or f.is_dead() or not f.is_inside_tree():
			return
		_check = 0.1
		if K.on_water_of(f, f.global_position):
			f.kit.add_modifier("glisse", 0.25, {"speed": 1.3, "label": "Glisse", "color": WATER_COLOR})


## Shared Suiton rules.
class K:
	static func trempe(t: Tk, target: CombatCharacter) -> void:
		if t.is_enemy(target):
			t.mark(target, TREMPE, 1, TREMPE_TIME, 1, "Trempé")

	## Trempé, or standing in the caster's Domaine des profondeurs.
	static func is_wet(t: Tk, target: CombatCharacter) -> bool:
		if target == null or not is_instance_valid(target):
			return false
		if t.marks(target, TREMPE) > 0:
			return true
		for d: KitObject in t.objects(DOMAINE, DOMAINE_ID):
			if d.contains(target.global_position):
				return true
		return false

	## Is `point` on a water surface (or the Domaine) of fighter `f`?
	static func on_water_of(f: CombatCharacter, point: Vector3) -> bool:
		for o: KitObject in KitObject.find(f.get_tree(), f, &"", ""):
			if (o.kind == WATER or o.kind == DOMAINE) and o.contains(point):
				return true
		return false

	static func on_water(t: Tk, point: Vector3) -> bool:
		return on_water_of(t.caster, point)

	static func water(t: Tk, at: Vector3, radius: float, lifetime: float, opts: Dictionary = {}) -> KitObject:
		var o: Dictionary = opts.duplicate()
		o.kind = WATER
		o.targetable = false
		o.color = opts.get("color", WATER_COLOR)
		return t.zone(at, radius, lifetime, o)

	## Thin band of water along a segment (a chain of small puddles).
	static func strip(t: Tk, from: Vector3, to: Vector3, width: float, lifetime: float, opts: Dictionary = {}) -> void:
		var seg: Vector3 = HitQuery.flat(to - from)
		var n: int = maxi(1, ceili(seg.length() / (width * 1.5)))
		for i in n + 1:
			water(t, HitQuery.flat(from) + seg * (float(i) / float(n)), width, lifetime, opts)

	## Removes the slow that the DEBUFF tag adds to every hit of the ability.
	static func clean(t: Tk) -> void:
		t.ability.slow_duration = 0.0

	## Bends a small projectile crossing a refracting surface of normal `n`
	## centred at `center`: the deviation follows the incidence angle.
	static func refract(d: Vector3, n: Vector3, center: Vector3, point: Vector3) -> Vector3:
		var nn: Vector3 = n if d.dot(n) >= 0.0 else -n
		var inc: float = nn.signed_angle_to(d, Vector3.UP)
		var sgn: float = signf(inc)
		if absf(inc) < deg_to_rad(4.0):
			var side: Vector3 = nn.cross(Vector3.UP)
			var off: float = HitQuery.flat(point - center).dot(side)
			var probe: Vector3 = nn.rotated(Vector3.UP, deg_to_rad(40.0))
			sgn = 1.0 if (probe.dot(side) >= 0.0) == (off >= 0.0) else -1.0
		var out: float = minf(absf(inc) + deg_to_rad(40.0), deg_to_rad(80.0))
		return nn.rotated(Vector3.UP, sgn * out).normalized()


## D — Hitscan court, Poke, Marque. Near-instant thin water needle: low
## damage + Trempé; on an already Trempé target it pierces to the next enemy
## behind. Fired from water it reaches farther and leaves a wake.
class AiguilleDePression extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.12
		a.recovery_time = 0.2
		a.max_range = 9.0
		a.anim = &"throw"

	func cast(t: Tk) -> void:
		K.clean(t)
		var wet_start: bool = K.on_water(t, t.origin)
		var reach: float = t.distance(t.origin, t.clear_point(t.origin, t.dir, 10.5 if wet_start else 9.0))
		var hits: Array[CombatCharacter] = t.enemies_in_line(t.origin, t.dir, reach, 0.3)
		hits.sort_custom(func(x: CombatCharacter, y: CombatCharacter) -> bool:
			return t.distance(x.global_position, t.origin) < t.distance(y.global_position, t.origin))
		_beam(t, reach)
		if wet_start:
			t.fx("wave", t.origin + t.dir * 1.0, 1.0, WATER_COLOR)
		for i in mini(hits.size(), 2):
			var e: CombatCharacter = hits[i]
			var was_wet: bool = K.is_wet(t, e)
			t.hit(e, t.dmg(0.4))
			K.trempe(t, e)
			t.fx("burst", e.global_position, 0.5, WATER_COLOR)
			if not was_wet:
				break  # only a Trempé target lets the needle through

	func _beam(t: Tk, reach: float) -> void:
		if CombatFx.is_enabled():
			var mi := KitVisuals.line_visual(t.caster.get_parent(), WATER_COLOR)
			KitVisuals.update_line(mi, t.origin, t.origin + t.dir * reach)
			t.tree().create_timer(0.15).timeout.connect(mi.queue_free)


## D — Mobilité, Terrain, Recast. Fast slide leaving a thin band of water
## (enemies on it become Trempé, no knockdown). Ending on existing water
## grants a very short recast for a second small step that can't go back
## over the same band. In the Domaine, the cooldown is skipped every 2.5 s.
class PasDeSurface extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.06
		a.recovery_time = 0.12
		a.cast_move_multiplier = 1.0
		a.max_range = 5.0
		a.anim = &"dash"

	func cast(t: Tk) -> void:
		var end: Vector3 = t.clear_point(t.origin, t.dir, 5.0)
		var ends_on_water: bool = K.on_water(t, end)
		var in_domaine: bool = _inside_domaine(t, t.origin)
		_slide(t, t.origin, end, t.dir)
		if ends_on_water:
			var first: Vector3 = t.dir
			t.recast(0.8, func(rt: Tk) -> void:
				var d: Vector3 = rt.dir
				# The second step can't retrace the band it just laid.
				if d.angle_to(-first) < deg_to_rad(35.0):
					var s: float = signf(first.signed_angle_to(d, Vector3.UP))
					d = (-first).rotated(Vector3.UP, (1.0 if s == 0.0 else -s) * deg_to_rad(35.0))
				var to: Vector3 = rt.clear_point(rt.origin, d, 2.8)
				_slide(rt, rt.origin, to, d))
		if in_domaine and not t.kit().has_modifier("domaine_pas"):
			t.buff("domaine_pas", 2.5, {})
			var slot: StringName = t.caster.abilities.slot_of(t.ability)
			if slot != &"":
				t.caster.abilities.reset_cooldown(slot)

	func _inside_domaine(t: Tk, at: Vector3) -> bool:
		for d: KitObject in t.objects(DOMAINE, DOMAINE_ID):
			if d.contains(at):
				return true
		return false

	func _slide(t: Tk, from: Vector3, to: Vector3, d: Vector3) -> void:
		var dist: float = t.distance(from, to)
		if dist > 0.3:
			t.dash(dist, d, 0.16)
		var soak := func(e: CombatCharacter, _o: KitObject) -> void:
			if t.is_enemy(e):
				K.trempe(t, e)
		K.strip(t, from, to, 0.7, 4.0, {"on_enter": soak})
		for e: CombatCharacter in t.enemies_in_line(from, d, dist, 1.2):
			K.trempe(t, e)


## C — Projectile, Knockback, Terrain. Slow compact sphere: bursts on the
## first enemy or on recast, after a short visible dilation, pushing everyone
## around (allies too, without damage). Crossing water makes it grow and its
## burst leaves a puddle. Trempé targets are pushed farther, no extra damage.
## Enemy projectiles can pop it.
class SphereDeRupture extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.25
		a.max_range = 12.0
		a.anim = &"throw"

	func cast(t: Tk) -> void:
		var sphere: TkProjectile = t.projectile({"speed": 7.0, "range": 12.0, "radius": 0.6, "size": 0.38,
			"color": WATER_COLOR, "data": {"grown": false},
			"on_tick": func(p: TkProjectile, _dt: float) -> void:
				if not p.data.grown and K.on_water(t, p.ground_point()):
					p.data.grown = true
					p.hit_radius = 0.9
					t.fx("ring", p.ground_point(), 1.0, WATER_COLOR)
				if _shot_down(t, p):
					p.end("destroyed"),
			"on_hit": func(_e: CombatCharacter, _p: TkProjectile) -> bool:
				return false,
			"on_end": func(point: Vector3, p: TkProjectile, reason: String) -> void:
				t.kit().close_recast(t.id)
				if reason == "destroyed":
					return
				_dilate_then_burst(t, point, bool(p.data.grown))})
		t.recast(2.0, func(_rt: Tk) -> void:
			if sphere.is_alive():
				sphere.end("recast"))

	func _shot_down(t: Tk, p: TkProjectile) -> bool:
		for node: Node in t.tree().get_nodes_in_group(&"projectiles"):
			var ep := node as Projectile
			if ep != null and ep.team != t.caster.team and t.distance(ep.global_position, p.global_position) < 0.8:
				ep.queue_free()
				return true
		for node: Node in t.tree().get_nodes_in_group(&"tk_projectiles"):
			var other := node as TkProjectile
			if other != null and other.team != t.caster.team and other.is_alive() \
					and t.distance(other.global_position, p.global_position) < 0.8:
				other.end("blocked")
				return true
		return false

	func _dilate_then_burst(t: Tk, point: Vector3, grown: bool) -> void:
		var radius: float = 2.8 if grown else 2.2
		t.fx("ring", point, radius * 0.6, WATER_COLOR)
		t.after(0.15, func(rt: Tk) -> void:
			rt.fx("wave", point, radius, WATER_COLOR)
			for e: CombatCharacter in rt.enemies_in(point, radius):
				var push: float = 5.0 if K.is_wet(rt, e) else 3.2
				rt.hit(e, rt.dmg(0.7), {"push": push, "push_from": point})
			KitObject.damage_objects_in(rt.tree(), point, radius, rt.caster.team, rt.dmg(0.7))
			for ally: CombatCharacter in rt.allies_in(point, radius, false):
				rt.push(ally, HitQuery.flat(ally.global_position - point), 2.5)
			if grown:
				K.water(rt, point, 2.0, 5.0))


## C — Mur, Défense, Déviation. A vertical water curtain oriented at
## placement: small projectiles (any team) crossing it are bent according
## to their incidence angle instead of being cancelled. Beams, melee and
## areas go through.
class RideauRefringent extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.15
		a.recovery_time = 0.2
		a.max_range = 6.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var at: Vector3 = t.clear_point(t.origin, t.dir, clampf(t.distance(t.origin, t.aim), 1.5, 4.0))
		var n: Vector3 = t.dir
		t.wall(at, n, 4.5, 2.5, {"kind": "rideau", "color": WATER_COLOR, "blocks_projectiles": false,
			"blocks_movement": false, "health": -1.0, "targetable": false, "thickness": 0.8, "data": {"bent": {}},
			"on_tick": func(o: KitObject) -> void:
				_refract_all(o, n)})

	func _refract_all(o: KitObject, n: Vector3) -> void:
		var bent: Dictionary = o.data.bent
		for node: Node in o.get_tree().get_nodes_in_group(&"projectiles"):
			var p := node as Projectile
			if p != null and not bent.has(p.get_instance_id()) and o.contains(p.global_position):
				bent[p.get_instance_id()] = true
				p.direction = K.refract(p.direction, n, o.global_position, p.global_position)
				CombatFx.ring(o, HitQuery.flat(p.global_position), 0.5, WATER_COLOR, 0.2)
		for node: Node in o.get_tree().get_nodes_in_group(&"tk_projectiles"):
			var tp := node as TkProjectile
			if tp == null or not tp.is_alive() or tp.lob or tp.size > 0.4 or bent.has(tp.get_instance_id()):
				continue
			if o.contains(tp.global_position):
				bent[tp.get_instance_id()] = true
				tp.homing = 0.0
				tp.direction = K.refract(tp.direction, n, o.global_position, tp.global_position)
				CombatFx.ring(o, HitQuery.flat(tp.global_position), 0.5, WATER_COLOR, 0.2)


## B — Canalisation, Tether, Duel. A water jet links the caster to a close
## target; if the link holds (faster on a Trempé target) a bubble forms
## around it: strong slow, not a stun. Breaks on distance, line of sight,
## caster stunned or enough pressure on the caster. The bubble has health:
## the target's allies can break it.
class PrisonAqueuse extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.max_range = 6.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var target: CombatCharacter = t.target_at_aim(2.5)
		if target == null:
			target = t.nearest_enemy(t.origin, 6.0)
		if target == null:
			t.fx("burst", t.aim, 0.8, WATER_COLOR)
			return
		var form_time: float = 0.7 if K.is_wet(t, target) else 1.0
		var state: Dictionary = {"pressure": 0.0, "formed": false}
		var limit: float = t.dmg(1.0)
		t.buff("prison_canal", form_time + 0.3, {"speed": 0.4, "label": "Canalisation", "color": WATER_COLOR,
			"on_take": func(_h: HitData, dmg: float) -> Variant:
				state.pressure = float(state.pressure) + dmg
				return null})
		t.tether(target, 7.0, form_time + 0.3, {
			"on_tick": func(o: KitObject) -> void:
				if state.formed:
					return
				var blocked: bool = not HitQuery.raycast_world(t.caster.get_world_3d(),
					t.caster.global_position + Vector3.UP * HitQuery.BODY_HEIGHT,
					target.global_position + Vector3.UP * HitQuery.BODY_HEIGHT).is_empty()
				if blocked or not t.caster.status.can_act() or float(state.pressure) >= limit:
					o.data["broken"] = true
					o.destroy("broken")
					return
				if o.age >= form_time:
					state.formed = true
					o.destroy("formed")
					t.kit().remove_modifier("prison_canal")
					_bubble(t.refreshed(), target),
			"on_break": func() -> void:
				t.kit().remove_modifier("prison_canal")
				t.text(t.caster, "ROMPU")})

	func _bubble(t: Tk, target: CombatCharacter) -> void:
		if not t.is_enemy(target):
			return
		t.fx("spheres", target.global_position, 1.2, WATER_COLOR)
		K.trempe(t, target)
		t.object(target.global_position, {"kind": "bulle", "radius": 1.0, "lifetime": 2.5, "health": t.dmg(1.6),
			"look": KitObject.Look.ORB, "color": WATER_COLOR,
			"on_tick": func(o: KitObject) -> void:
				if not is_instance_valid(target) or not t.is_enemy(target):
					o.destroy("released")
					return
				o.global_position = HitQuery.flat(target.global_position)
				t.debuff(target, "prison_aqueuse", 0.15, {"speed": 0.3, "label": "Bulle", "color": WATER_COLOR}),
			"on_destroy": func(_o: KitObject, _r: String) -> void:
				if is_instance_valid(target):
					target.kit.remove_modifier("prison_aqueuse")})


## B — Vague, Déplacement forcé, Recast. A low wave travels in a line,
## dragging enemies slightly along (and soaking them). Recast once: the
## water flows back along its real path; enemies hit on both passes are
## briefly knocked down on the second contact.
class TorrentDeRenversement extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.max_range = 10.0
		a.anim = &"breath"

	func cast(t: Tk) -> void:
		var state: Dictionary = {"hit": {}, "end": Vector3.INF}
		var start: Vector3 = t.origin
		var d: Vector3 = t.dir
		var wave: TkProjectile = t.projectile({"speed": 11.0, "range": 10.0, "radius": 1.4, "pierce": true, "size": 0.5,
			"color": WATER_COLOR,
			"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
				state.hit[e.get_instance_id()] = true
				t.hit(e, t.dmg(0.5))
				K.trempe(t, e)
				t.push(e, d, 2.0, 0.3)
				return true,
			"on_end": func(point: Vector3, _p: TkProjectile, _reason: String) -> void:
				state.end = point})
		t.recast(4.0, func(rt: Tk) -> void:
			var from: Vector3 = wave.ground_point() if wave.is_alive() else state.end
			if wave.is_alive():
				wave.end("recast")
			if from == Vector3.INF:
				return
			var back: Vector3 = HitQuery.flat(start - from)
			if back.length() < 0.5:
				return
			rt.projectile({"from": from, "dir": back.normalized(), "speed": 11.0, "range": back.length(), "radius": 1.4,
				"pierce": true, "size": 0.5, "color": WATER_COLOR,
				"on_hit": func(e: CombatCharacter, p: TkProjectile) -> bool:
					var twice: bool = state.hit.has(e.get_instance_id())
					rt.hit(e, rt.dmg(0.4), {"stun": 0.5} if twice else {})
					if twice:
						rt.text(e, "RENVERSÉ")
					rt.push(e, p.direction, 2.0, 0.3)
					return true}))


## A — Contre, Copie, Recast. A water disc in front for a very short
## window: the first compatible enemy projectile (or ranged linear hit from
## the front) is absorbed and recorded. Recast within 4 s: fires an aqueous
## copy with the same speed / size / range profile — Suiton damage + Trempé,
## weaker than the original. Nothing caught = spell lost.
class MiroirLiquide extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.05
		a.recovery_time = 0.2
		a.max_range = 12.0
		a.anim = &"guard"

	func cast(t: Tk) -> void:
		t.caster.status.remove_status(StatusController.Type.EMPOWER)
		var state: Dictionary = {"profile": {}}
		var disc: KitObject = t.object(t.origin + t.dir * 1.2, {"kind": "miroir", "radius": 1.4, "lifetime": 0.6,
			"look": KitObject.Look.DISC, "color": WATER_COLOR, "targetable": false,
			"on_tick": func(o: KitObject) -> void:
				if state.profile.is_empty():
					o.global_position = HitQuery.flat(t.caster.global_position + t.caster.facing.facing_direction * 1.2)
					_catch_projectile(t, o, state)})
		t.buff("miroir_liquide", 0.6, {"label": "Miroir", "color": WATER_COLOR,
			"on_take": func(h: HitData, dmg: float) -> Variant:
				if not state.profile.is_empty() or not _linear_hit(t, h):
					return null
				_record(t, state, {"speed": 40.0, "size": 0.25, "range": 10.0, "pierce": false})
				h.knockback_velocity = Vector3.ZERO
				h.root_duration = 0.0
				if is_instance_valid(disc):
					disc.destroy("caught")
				return 0.0})

	func _incoming(t: Tk, pos: Vector3, d: Vector3) -> bool:
		return d.dot(HitQuery.flat(t.caster.global_position - pos).normalized()) > 0.3

	func _catch_projectile(t: Tk, o: KitObject, state: Dictionary) -> void:
		for node: Node in t.tree().get_nodes_in_group(&"projectiles"):
			var p := node as Projectile
			if p != null and p.team != t.caster.team and o.contains(p.global_position) and _incoming(t, p.global_position, p.direction) \
					and p.ability != null and p.ability.energy_cost < 70.0:
				_record(t, state, {"speed": p.ability.projectile_speed, "size": 0.28, "range": p.ability.max_range,
					"pierce": p.ability.projectile_piercing})
				p.queue_free()
				o.destroy("caught")
				return
		for node: Node in t.tree().get_nodes_in_group(&"tk_projectiles"):
			var tp := node as TkProjectile
			if tp == null or not tp.is_alive() or tp.team == t.caster.team or tp.lob or not o.contains(tp.global_position):
				continue
			if not _incoming(t, tp.global_position, tp.direction) or tp.size > 0.6:
				continue  # big invocations / ultimates can't be recorded
			_record(t, state, {"speed": tp.speed, "size": tp.size, "range": tp.max_range, "pierce": tp.pierce})
			tp.end("blocked")
			o.destroy("caught")
			return

	func _linear_hit(t: Tk, h: HitData) -> bool:
		if h.ability == null or not is_instance_valid(h.source) or h.source == t.caster:
			return false
		if h.source.abilities.is_basic_attack(h.ability) or h.ability.energy_cost >= 70.0:
			return false
		if h.ability.kind != AbilityData.Kind.PROJECTILE and h.ability.kind != AbilityData.Kind.SCRIPTED:
			return false
		var to: Vector3 = HitQuery.flat(h.source.global_position - t.caster.global_position)
		return to.length() > 3.5 and t.caster.facing.facing_direction.dot(to.normalized()) > 0.3

	func _record(t: Tk, state: Dictionary, profile: Dictionary) -> void:
		state.profile = profile
		t.kit().remove_modifier("miroir_liquide")
		t.fx("ring", t.caster.global_position, 1.4, WATER_COLOR)
		t.text(t.caster, "CAPTÉ")
		t.recast(4.0, func(rt: Tk) -> void:
			var pr: Dictionary = state.profile
			rt.fx("wave", rt.origin + rt.dir, 1.0, WATER_COLOR)
			rt.projectile({"speed": clampf(float(pr.speed), 8.0, 45.0), "range": clampf(float(pr.range), 6.0, 16.0),
				"size": clampf(float(pr.size), 0.15, 0.5), "radius": 0.6, "pierce": bool(pr.pierce), "color": WATER_COLOR,
				"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
					rt.hit(e, rt.dmg(0.8))
					K.trempe(rt, e)
					return false}))


## A — Grande zone, Courant, Contrôle. A circular area slowly fills with
## shallow water (announced), then every 1.5 s the caster picks a current
## direction (towards his aim): every fighter inside drifts that way —
## Trempé enemies more, the caster and allies much less. No burst; dashes
## work normally. The area counts as water.
class MareeCaptive extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.35
		a.max_range = 10.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var center: Vector3 = t.aim
		t.object(center, {"kind": "montee", "radius": 5.5, "lifetime": 1.0, "look": KitObject.Look.RING,
			"targetable": false, "color": WATER_COLOR,
			"on_expire": func(_o: KitObject) -> void:
				if t.alive():
					_flood(t.refreshed(), center)})

	func _flood(t: Tk, center: Vector3) -> void:
		t.fx("wave", center, 5.5, WATER_COLOR)
		K.water(t, center, 5.5, 7.0, {"tick_interval": 0.0, "data": {"current": Vector3.ZERO, "pick": 0.0},
			"on_tick": func(o: KitObject) -> void:
				if not t.alive():
					return
				if o.age >= float(o.data.pick):
					o.data.pick = o.age + 1.5
					var want: Vector3 = HitQuery.flat(t.caster.facing.aim_point - o.global_position)
					o.data.current = want.normalized() if want.length() > 0.5 else HitQuery.flat(t.caster.facing.facing_direction)
					t.fx("ring", o.global_position + (o.data.current as Vector3) * 3.0, 1.2, WATER_COLOR)
				var cur: Vector3 = o.data.current
				var dt: float = o.get_physics_process_delta_time()
				for f: CombatCharacter in o.inside:
					if not is_instance_valid(f) or f.is_dead() or f.movement.is_forced():
						continue
					var drift: float = 0.6
					if f.team != t.caster.team:
						drift = 2.4 if K.is_wet(t, f) else 1.6
					f.move_and_collide(cur * drift * dt)
					f.global_position.y = 0.0})


## S — Invocation dirigée, Capture, Recast. A massive water serpent rises
## at the aim point and follows the cursor with inertia. Enemies it hits are
## carried inside its body for a limited time then released behind it.
## Recast: it dives into a geyser whose radius grows with the targets carried
## and water surfaces crossed (damage barely grows). Caster slowed meanwhile.
class LeviathanDePression extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.45
		a.max_range = 10.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		t.caster.status.remove_status(StatusController.Type.EMPOWER)
		t.buff("leviathan_conduite", 4.5, {"speed": 0.5, "label": "Léviathan", "color": WATER_COLOR})
		t.fx("column", t.aim, 1.5, WATER_COLOR)
		var serpent: TkProjectile = t.projectile({"from": t.aim, "speed": 8.0, "range": 40.0, "radius": 1.2, "pierce": true,
			"size": 0.6, "color": WATER_COLOR, "data": {"carried": [], "total": 0, "crossed": 0, "wet": false},
			"on_tick": func(p: TkProjectile, dt: float) -> void:
				if p.age > 4.5:
					p.end("range")
					return
				var want: Vector3 = HitQuery.flat(t.caster.facing.aim_point - p.global_position)
				if want.length() > 0.5:
					var angle: float = p.direction.signed_angle_to(want.normalized(), Vector3.UP)
					p.direction = p.direction.rotated(Vector3.UP, clampf(angle, -1.8 * dt, 1.8 * dt))
				var wet: bool = K.on_water(t, p.ground_point())
				if wet and not p.data.wet:
					p.data.crossed = int(p.data.crossed) + 1
				p.data.wet = wet
				_carry(t, p),
			"on_hit": func(e: CombatCharacter, p: TkProjectile) -> bool:
				if t.hit(e, t.dmg(0.5)) == HitData.Result.HIT and t.is_enemy(e):
					K.trempe(t, e)
					(p.data.carried as Array).append({"who": e, "until": p.age + 1.2})
					p.data.total = int(p.data.total) + 1
				return true,
			"on_end": func(point: Vector3, p: TkProjectile, reason: String) -> void:
				t.kit().remove_modifier("leviathan_conduite")
				t.kit().close_recast(t.id)
				_release_all(t, p)
				if reason == "recast":
					_geyser(t, point, int(p.data.total) + int(p.data.crossed))
				else:
					t.fx("wave", point, 1.5, WATER_COLOR)
					t.area(point, 1.5, t.dmg(0.3))})
		t.recast(4.5, func(_rt: Tk) -> void:
			if serpent.is_alive():
				serpent.end("recast"))

	func _carry(t: Tk, p: TkProjectile) -> void:
		var keep: Array = []
		for c: Dictionary in p.data.carried:
			var who: Variant = c.who
			if not is_instance_valid(who) or not t.is_enemy(who as CombatCharacter):
				continue
			var e: CombatCharacter = who
			if p.age >= float(c.until):
				_release(t, p, e)
				continue
			var to: Vector3 = HitQuery.flat(p.global_position - e.global_position)
			e.movement.apply_forced_motion(to / 0.1 + p.direction * p.speed, 0.08, false)
			keep.append(c)
		p.data.carried = keep

	func _release(t: Tk, p: TkProjectile, e: CombatCharacter) -> void:
		if t.is_enemy(e):
			t.push(e, -p.direction, 2.2, 0.2)

	func _release_all(t: Tk, p: TkProjectile) -> void:
		for c: Dictionary in p.data.carried:
			var who: Variant = c.who
			if is_instance_valid(who):
				_release(t, p, who as CombatCharacter)
		p.data.carried = []

	func _geyser(t: Tk, point: Vector3, fed: int) -> void:
		var radius: float = 2.2 + 0.5 * mini(fed, 5)
		t.fx("column", point, radius, WATER_COLOR)
		t.fx("wave", point, radius, WATER_COLOR)
		for e: CombatCharacter in t.area(point, radius, t.dmg(1.2 + 0.1 * mini(fed, 3))):
			K.trempe(t, e)
			t.launch(e, 0.8)
		K.water(t, point, radius * 0.7, 5.0)


## S — Domaine, Mobilité, Vision. Floods a wide area with dark water: all
## fighters inside count as Trempé and the whole area is water (glide).
## Enemies who move or cast inside produce ripples: a readable "Ondulation"
## debuff (+10 % damage taken) while moving, none if they stand still.
## Pas de surface skips its cooldown inside, at most every 2.5 s.
class DomaineDesProfondeurs extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.5
		a.cast_move_multiplier = 0.2
		a.max_range = 9.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		K.clean(t)
		t.caster.status.remove_status(StatusController.Type.EMPOWER)
		t.fx("wave", t.origin, 9.0, DEEP_COLOR)
		t.zone(t.origin, 9.0, 8.0, {"kind": DOMAINE, "color": DEEP_COLOR, "targetable": false, "tick_interval": 0.2,
			"on_tick": func(o: KitObject) -> void:
				for e: CombatCharacter in o.enemies_inside():
					var moving: bool = HitQuery.flat(e.velocity).length() > 1.0 or e.abilities.is_casting()
					if moving:
						t.debuff(e, "ondulation", 0.35, {"damage_taken": 1.1, "label": "Ondulation", "color": WATER_COLOR})
						if int(o.age * 5.0) % 3 == 0:
							t.fx("ring", e.global_position, 0.9, WATER_COLOR)})
