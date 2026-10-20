extends RefCounted
## Technique kit: clan_roran (design bible). Signature: Battements and
## Postures — Roran techniques generate up to 3 Battements ("battements"
## resource, lost after 8 s out of combat) spent to empower the next fan
## move. The fan Posture (Ouverte = zone control, Fermée = precision /
## mobility) is switched by the casts themselves (Claque -> Fermée, Miroir ->
## Ouverte, the Souffles and the Danse switch on their own) and changes
## what Théâtre des mille vents does. Éventail miroir captures a Direction
## that the next Roran move adds to its own vector.

const KIT_ID := &"clan_roran"
const SIGNATURE = RoranSignature
const TECHNIQUES := {
	&"clan_roran_d_claque_d_eventail": ClaqueDEventail,
	&"clan_roran_c_trois_souffles_cadences": TroisSoufflesCadences,
	&"clan_roran_b_eventail_miroir": EventailMiroir,
	&"clan_roran_a_danse_des_quatre_rafales": DanseDesQuatreRafales,
	&"clan_roran_s_theatre_des_mille_vents": TheatreDesMilleVents,
}

const BAT := "battements"
const OUVERTE := &"ouverte"
const FERMEE := &"fermee"
const WIND := Color(0.75, 0.95, 0.85)
const FAN := Color(0.95, 0.85, 0.55)


## Battements: 0..3, lost 8 s after the last gain / spend.
class RoranSignature extends KitSignature:
	func setup(f: CombatCharacter) -> void:
		f.kit.define_resource(BAT, 3.0, "Battements", FAN, 8.0)
		if not f.has_meta("roran_posture"):
			f.set_meta("roran_posture", FERMEE)


## Shared Roran rules: Battements, Posture, captured Direction, deflection.
class K:
	static func now() -> float:
		return Time.get_ticks_msec() / 1000.0

	static func gain(t: Tk, n: int = 1) -> void:
		t.add_res(BAT, float(n))
		t.fx("sparks", t.caster.global_position, 0.6, FAN)

	static func spend(t: Tk) -> bool:
		if t.spend_res(BAT, 1.0):
			t.text(t.caster, "BATTEMENT", FAN)
			return true
		return false

	static func posture(t: Tk) -> StringName:
		return t.caster.get_meta("roran_posture", FERMEE)

	static func is_open(t: Tk) -> bool:
		return posture(t) == OUVERTE

	static func set_posture(t: Tk, p: StringName) -> void:
		t.caster.set_meta("roran_posture", p)
		t.kit().add_modifier("posture", 30.0, {"label": "Ouverte" if p == OUVERTE else "Fermée", "color": FAN})

	## Stores a captured Direction (one at a time, 4 s).
	static func store_direction(t: Tk, v: Vector3, kind: String) -> void:
		t.caster.set_meta("roran_direction", HitQuery.flat(v).normalized())
		t.caster.set_meta("roran_direction_kind", kind)
		t.kit().add_modifier("direction", 4.0, {"label": "Direction", "color": WIND})
		t.text(t.caster, "DIRECTION", WIND)

	static func take_direction(t: Tk) -> Vector3:
		if not t.kit().has_modifier("direction"):
			return Vector3.ZERO
		t.kit().remove_modifier("direction")
		return t.caster.get_meta("roran_direction", Vector3.ZERO)

	## Adds the captured Direction (if any) to a move's own vector.
	static func bend(t: Tk, d: Vector3) -> Vector3:
		var captured: Vector3 = take_direction(t)
		if captured == Vector3.ZERO:
			return d
		var out: Vector3 = HitQuery.flat(d + captured)
		return out.normalized() if out.length() > 0.1 else d

	## Small enemy projectiles in front of the caster (basic projectiles,
	## thin non-piercing technique projectiles; no beams, lobs or zones).
	static func small_projectiles(t: Tk, d: Vector3, reach: float, degrees: float) -> Array[Node3D]:
		var out: Array[Node3D] = []
		var pos: Vector3 = HitQuery.flat(t.caster.global_position)
		for node: Node in t.tree().get_nodes_in_group(&"projectiles"):
			var p := node as Projectile
			if p != null and not p.visual_only and p.team != t.caster.team and not p.has_meta("roran_deflected") \
					and _in_front(pos, d, p.global_position, reach, degrees):
				out.append(p)
		for node: Node in t.tree().get_nodes_in_group(&"tk_projectiles"):
			var tp := node as TkProjectile
			if tp != null and tp.is_alive() and tp.team != t.caster.team and not tp.pierce and not tp.lob \
					and tp.size <= 0.3 and not tp.has_meta("roran_deflected") and _in_front(pos, d, tp.global_position, reach, degrees):
				out.append(tp)
		return out

	static func _in_front(pos: Vector3, d: Vector3, at: Vector3, reach: float, degrees: float) -> bool:
		var to: Vector3 = HitQuery.flat(at) - pos
		return to.length() <= reach and (to.length() < 0.6 or d.angle_to(to) <= deg_to_rad(degrees) * 0.5)

	## Deflects a projectile sideways (not cancelled): it turns ~75° away
	## from the caster's line and no longer threatens the Roran's team.
	static func deflect(t: Tk, node: Node3D, d: Vector3) -> void:
		var pos: Vector3 = HitQuery.flat(t.caster.global_position)
		var to: Vector3 = HitQuery.flat(node.global_position) - pos
		var side: float = 1.0 if d.cross(to).y >= 0.0 else -1.0
		node.set_meta("roran_deflected", true)
		var p := node as Projectile
		if p != null:
			p.direction = p.direction.rotated(Vector3.UP, side * deg_to_rad(75.0)).normalized()
			p.team = t.caster.team
			p.source = t.caster
		var tp := node as TkProjectile
		if tp != null:
			tp.direction = tp.direction.rotated(Vector3.UP, side * deg_to_rad(75.0)).normalized()
			tp.team = t.caster.team
			tp.homing = 0.0
		t.fx("sparks", node.global_position, 0.5, WIND)

	static func capture(t: Tk, node: Node3D) -> Vector3:
		var v: Vector3 = Vector3.ZERO
		var p := node as Projectile
		if p != null:
			v = p.direction
			p.queue_free()
		var tp := node as TkProjectile
		if tp != null:
			v = tp.direction
			tp.end("blocked")
		return v


## D — Parade légère, Génération, Direction. Very short fan slap (2.4 m,
## Posture Fermée): light push; for 0.25 s small projectiles in front are
## deflected sideways (+1 Battement each). Hitting an enemy dead centre gives
## +1 Battement (1.5 s internal delay). Uses a captured Direction.
class ClaqueDEventail extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.08
		a.recovery_time = 0.15
		a.max_range = 2.4
		a.anim = &"slash"

	func cast(t: Tk) -> void:
		K.set_posture(t, FERMEE)
		var d: Vector3 = K.bend(t, t.dir)
		t.fx("wave", t.origin + d * 1.2, 1.3, WIND)
		for e: CombatCharacter in t.enemies_in_cone(t.origin, d, 2.4, 110.0):
			var to: Vector3 = HitQuery.flat(e.global_position - t.origin)
			var central: bool = to.length() < 0.6 or d.angle_to(to) < deg_to_rad(25.0)
			if t.hit(e, t.dmg(0.3)) != HitData.Result.HIT:
				continue
			t.push(e, d.lerp(to.normalized(), 0.5), 1.6)
			if central and K.now() - float(t.caster.get_meta("roran_claque_icd", -10.0)) >= 1.5:
				t.caster.set_meta("roran_claque_icd", K.now())
				K.gain(t)
		t.buff("claque_deviation", 0.25, {"on_tick": func(_dt: float) -> void:
			if not t.alive():
				return
			for p: Node3D in K.small_projectiles(t, d, 2.6, 120.0):
				K.deflect(t, p, d)
				K.gain(t)})


## C — Séquence, Choix de rythme, Recast. Up to three telegraphed breaths:
## wide & weak (Posture Ouverte) -> narrower -> thin & strong line (Posture
## Fermée). The player sets the tempo with the recast; a breath needs 0.55 s
## after the previous one — pressing earlier spends 1 Battement to fire it
## instantly with an extra function (wide = big push, medium = slow, thin =
## guard piercing), otherwise it comes out when ready. Stunned = sequence over.
class TroisSoufflesCadences extends Technique:
	const TEMPO: float = 0.55

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.12
		a.recovery_time = 0.2
		a.max_range = 7.0
		a.anim = &"slash"

	func cast(t: Tk) -> void:
		var state := {"last": K.now()}
		_breath(t, 0, false)
		_open(t, 1, state)

	func _open(t: Tk, i: int, state: Dictionary) -> void:
		if i > 2:
			return
		t.recast(2.0, func(rt: Tk) -> void:
			var since: float = K.now() - float(state.last)
			if since >= TEMPO or K.spend(rt):
				var enhanced: bool = since < TEMPO
				state.last = K.now()
				_breath(rt, i, enhanced)
				_open(rt, i + 1, state)
			else:
				state.last = K.now() + (TEMPO - since)
				rt.after(TEMPO - since, func(qt: Tk) -> void:
					if qt.caster.status.can_act():
						_breath(qt, i, false)
						_open(qt, i + 1, state)))

	func _breath(t: Tk, i: int, enhanced: bool) -> void:
		var d: Vector3 = K.bend(t, t.dir)
		var reach: float = [4.0, 5.0, 7.0][i]
		t.fx("wave", t.origin + d * reach * 0.4, [1.8, 1.2, 0.6][i], WIND)
		if i == 0:
			K.set_posture(t, OUVERTE)
		elif i == 2:
			K.set_posture(t, FERMEE)
		# Short telegraph, then the breath lands (cancelled if stunned).
		t.after(0.12, func(bt: Tk) -> void:
			if not bt.caster.status.can_act():
				return
			_land(bt, t.origin, d, i, enhanced))

	func _land(t: Tk, from: Vector3, d: Vector3, i: int, enhanced: bool) -> void:
		if i == 0:
			for e: CombatCharacter in t.cone(4.0, 110.0, t.dmg(0.35), {}, from, d):
				t.push(e, HitQuery.flat(e.global_position - from), 4.5 if enhanced else 2.0)
		elif i == 1:
			var opts: Dictionary = {"slow": 1.0} if enhanced else {}
			t.cone(5.0, 55.0, t.dmg(0.5), opts, from, d)
		else:
			t.line(7.0, 0.7, t.dmg(0.9), {"unblockable": enhanced, "push": 1.0}, from, d)


## B — Contre directionnel, Redirection, Ressource. The fan opens fully for
## 0.4 s (Posture Ouverte): a small projectile or a frontal push received is
## captured as a Direction (+1 Battement), the push itself is cancelled
## (damage unchanged). The next Roran move adds that vector to its own; a
## captured projectile can be relaunched by recast (4 s) as a neutral gust.
## No effect against heavy melee or zones.
class EventailMiroir extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.05
		a.recovery_time = 0.25
		a.max_range = 10.0
		a.anim = &"guard"

	func cast(t: Tk) -> void:
		K.set_posture(t, OUVERTE)
		var d: Vector3 = t.dir
		var state := {"done": false}
		t.fx("ring", t.origin + d * 0.8, 1.2, FAN)
		var on_capture := func(v: Vector3, kind: String) -> void:
			if bool(state.done):
				return
			state.done = true
			K.store_direction(t, v, kind)
			K.gain(t)
			t.kit().remove_modifier("miroir")
			if kind == "projectile":
				t.recast(4.0, func(rt: Tk) -> void:
					if not rt.kit().has_modifier("direction"):
						return
					rt.kit().remove_modifier("direction")
					rt.projectile({"speed": 24.0, "range": 10.0, "radius": 0.7, "size": 0.3, "color": WIND,
						"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
							rt.hit(e, rt.dmg(0.6), {"push": 2.0})
							return false}))
		t.buff("miroir", 0.4, {"label": "Miroir", "color": FAN,
			"on_tick": func(_dt: float) -> void:
				if bool(state.done) or not t.alive():
					return
				var mv: MovementComponent = t.caster.movement
				if mv.is_forced() and mv.is_knockback and mv.forced_direction().dot(d) < 0.2:
					var v: Vector3 = mv.forced_direction()
					mv.cancel_forced()
					on_capture.call(v, "push")
					return
				for p: Node3D in K.small_projectiles(t, d, 2.2, 150.0):
					on_capture.call(K.capture(t, p), "projectile")
					return,
			"on_take": func(hit: HitData, _dmg: float) -> Variant:
				if not bool(state.done) and hit.knockback_velocity != Vector3.ZERO and is_instance_valid(hit.source) \
						and HitQuery.flat(hit.source.global_position - t.caster.global_position).dot(d) > 0.0:
					var v: Vector3 = hit.knockback_velocity
					hit.knockback_velocity = Vector3.ZERO
					on_capture.call(v, "push")
				return null})


## A — Mobilité séquencée, Courants, Combo. Four glided steps (90° arcs)
## around a centre at the aim, each followed by a fan strike toward the
## centre (aim inside the circle: pull in, Posture Fermée) or outward (aim
## outside: push out, Posture Ouverte). Recast during the dance: the next
## step becomes a mini-dash through the zone (costs 1 Battement). Each step
## leaves a 4 s air corridor that hastes the Roran when he crosses it again.
## First strike that lands gives 1 Battement.
class DanseDesQuatreRafales extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.15
		a.max_range = 8.0
		a.anim = &"dash"

	func cast(t: Tk) -> void:
		var center: Vector3 = t.aim
		if t.distance(center, t.origin) < 2.5:
			center = t.origin + t.dir * 3.0
		var radius: float = clampf(t.distance(center, t.origin), 2.5, 4.0)
		var state := {"center": center, "radius": radius, "cross": false, "gained": false, "step": 0}
		t.fx("ring", center, radius, WIND)
		for i in 4:
			t.after(0.45 * i, func(st: Tk) -> void:
				_step(st, state, i))
		_open(t, state)

	func _open(t: Tk, state: Dictionary) -> void:
		t.recast(1.8, func(rt: Tk) -> void:
			state.cross = true
			if int(state.step) < 3:
				_open(rt, state))

	func _step(t: Tk, state: Dictionary, i: int) -> void:
		if not t.caster.status.can_act():
			return
		state.step = i
		var center: Vector3 = state.center
		var radius: float = state.radius
		var pos: Vector3 = HitQuery.flat(t.caster.global_position)
		var offset: Vector3 = pos - center
		if offset.length() < 0.3:
			offset = -t.dir * radius
		var dest: Vector3
		if bool(state.cross) and K.spend(t):
			state.cross = false
			dest = center - offset.normalized() * radius
			var through: Vector3 = HitQuery.flat(dest - pos)
			for e: CombatCharacter in t.enemies_in_line(pos, through.normalized(), through.length(), 1.2):
				t.hit(e, t.dmg(0.5))
		else:
			dest = center + offset.normalized().rotated(Vector3.UP, PI * 0.5) * radius
		var path: Vector3 = HitQuery.flat(dest - pos)
		if path.length() > 0.2:
			t.dash(path.length(), path.normalized(), 0.22)
			_corridor(t, pos, dest)
		t.after(0.24, func(bt: Tk) -> void:
			_strike(bt, state))

	func _strike(t: Tk, state: Dictionary) -> void:
		var center: Vector3 = state.center
		var pos: Vector3 = HitQuery.flat(t.caster.global_position)
		var inward: bool = t.distance(t.aim, center) < float(state.radius)
		var to_center: Vector3 = HitQuery.flat(center - pos)
		var d: Vector3 = to_center.normalized() if to_center.length() > 0.2 else t.dir
		if not inward:
			d = -d
		d = K.bend(t, d)
		K.set_posture(t, FERMEE if inward else OUVERTE)
		t.fx("wave", pos + d * 1.4, 1.4, WIND)
		var hit_any: bool = false
		for e: CombatCharacter in t.cone(3.2, 80.0, t.dmg(0.4), {}, pos, d):
			hit_any = true
			if inward:
				t.pull(e, center, 1.5)
			else:
				t.push(e, HitQuery.flat(e.global_position - center), 2.5)
		if hit_any and not bool(state.gained):
			state.gained = true
			K.gain(t)

	func _corridor(t: Tk, from: Vector3, to: Vector3) -> void:
		var v: Vector3 = HitQuery.flat(to - from)
		t.wall((from + to) * 0.5, v.normalized().cross(Vector3.UP), v.length() + 0.6, 4.0, {"kind": "couloir",
			"thickness": 1.2, "blocks_projectiles": false, "blocks_movement": false, "health": -1.0, "targetable": false,
			"color": WIND,
			"on_enter": func(f: CombatCharacter, o: KitObject) -> void:
				if f == t.caster and o.age > 0.35:
					t.buff("courant", 1.5, {"speed": 1.35, "label": "Courant", "color": WIND})})


## S — Domaine, Stances, Commandes séquencées. Plants the great fan
## (destructible, 60 HP) in a 7 m domain with four materialised wind
## directions for 9 s. Recast = a command toward the direction nearest the
## cursor (one every 0.6 s): after a 0.3 s visible telegraph, Posture
## Ouverte pushes every enemy in the domain along it, Posture Fermée pulls
## the enemies on that side into the centre. 2 commands + 1 per Battement
## held at launch. Fan destroyed = domain over. No hard stun.
class TheatreDesMilleVents extends Technique:
	const RADIUS: float = 7.0
	const LIFE: float = 9.0
	const INTERVAL: float = 0.6

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.4
		a.max_range = RADIUS
		a.anim = &"stomp"

	func cast(t: Tk) -> void:
		var center: Vector3 = t.origin
		var commands: int = 2 + int(t.take_all_res(BAT))
		var state := {"left": commands, "next": K.now(), "over": false}
		t.fx("wave", center, RADIUS, WIND)
		var dirs: Array[Vector3] = [Vector3.FORWARD, Vector3.RIGHT, Vector3.BACK, Vector3.LEFT]
		for d: Vector3 in dirs:
			t.object(center + d * (RADIUS - 1.5), {"kind": "vent", "radius": 0.7, "lifetime": LIFE, "look": KitObject.Look.GLYPH,
				"targetable": false, "color": WIND})
		var domain: KitObject = t.zone(center, RADIUS, LIFE, {"kind": "theatre", "look": KitObject.Look.RING,
			"targetable": false, "color": WIND})
		t.object(center, {"kind": "eventail", "radius": 0.8, "lifetime": LIFE, "health": 60.0, "look": KitObject.Look.PILLAR,
			"color": FAN, "on_destroy": func(_o: KitObject, _r: String) -> void:
				state.over = true
				if domain.is_alive():
					domain.destroy("fan_down")
				for g: KitObject in t.objects("vent"):
					g.destroy("fan_down")
				if t.alive():
					t.kit().close_recast(t.id)})
		t.text(t.caster, "%d COMMANDES" % commands, FAN)
		_open(t, center, state)

	func _open(t: Tk, center: Vector3, state: Dictionary) -> void:
		if int(state.left) <= 0 or bool(state.over):
			return
		t.recast(LIFE, func(rt: Tk) -> void:
			if bool(state.over):
				return
			state.left = int(state.left) - 1
			var wait: float = maxf(0.0, float(state.next) - K.now())
			state.next = K.now() + wait + INTERVAL
			var d: Vector3 = _snap(HitQuery.flat(rt.aim - center))
			var open: bool = K.is_open(rt)
			rt.fx("bolt", center + d * (RADIUS - 1.5), 1.0, WIND)
			rt.after(wait + 0.3, func(ct: Tk) -> void:
				_command(ct, center, d, open, state))
			_open(rt, center, state))

	func _snap(v: Vector3) -> Vector3:
		if v.length() < 0.2:
			return Vector3.FORWARD
		if absf(v.x) > absf(v.z):
			return Vector3.RIGHT if v.x > 0.0 else Vector3.LEFT
		return Vector3.BACK if v.z > 0.0 else Vector3.FORWARD

	func _command(t: Tk, center: Vector3, d: Vector3, open: bool, state: Dictionary) -> void:
		if bool(state.over) or t.objects("eventail").is_empty():
			return
		t.fx("wave", center + d * RADIUS * 0.5, RADIUS * 0.5, WIND)
		for e: CombatCharacter in t.enemies_in(center, RADIUS):
			var rel: Vector3 = HitQuery.flat(e.global_position - center)
			if open:
				if t.hit(e, t.dmg(0.3)) == HitData.Result.HIT:
					t.push(e, d, 3.5, 0.25)
			elif rel.dot(d) > -0.5:
				if t.hit(e, t.dmg(0.3)) == HitData.Result.HIT:
					t.pull(e, center, 3.0, 0.25)
