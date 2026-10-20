extends RefCounted
## Technique kit: Raiton (design bible §4). Signature: Charge — a target can
## carry up to 3 Charges ("charge" mark) that expire fast. Some techniques
## consume them, others spread them. Ground residues ("residu" objects) are
## charged points too. Electric controls are very short micro-shocks that
## interrupt casts and channels (K.jolt). The signature declares the
## Condensateur resource filled by Garde statique.

const KIT_ID := &"raiton"
const SIGNATURE = RaitonSignature
const TECHNIQUES := {
	&"raiton_d_aiguille_voltaique": AiguilleVoltaique,
	&"raiton_d_pas_ionique": PasIonique,
	&"raiton_c_arc_sauteur": ArcSauteur,
	&"raiton_c_garde_statique": GardeStatique,
	&"raiton_b_lance_magnetique": LanceMagnetique,
	&"raiton_b_cage_de_foudre": CageDeFoudre,
	&"raiton_a_armure_d_eclair": ArmureDEclair,
	&"raiton_a_tonnerre_guide": TonnerreGuide,
	&"raiton_s_circuit_raijin": CircuitRaijin,
	&"raiton_s_cataclysme_de_l_orage": CataclysmeDeLOrage,
}

const CHARGE := "charge"
const CHARGE_TIME: float = 3.5
const RESIDU := "residu"
const CONDENSATEUR := "condensateur"
const VOLT := Color(0.55, 0.75, 1.0)


## Condensateur: energy stored by Garde statique (fades out of combat).
class RaitonSignature extends KitSignature:
	func setup(f: CombatCharacter) -> void:
		f.kit.define_resource(CONDENSATEUR, 60.0, "Condensateur", VOLT, 6.0)


## Shared Raiton rules.
class K:
	static func charge(t: Tk, target: CombatCharacter, n: int = 1) -> int:
		if not t.is_enemy(target):
			return 0
		return t.mark(target, CHARGE, n, CHARGE_TIME, 3, "Charge")

	static func charges(t: Tk, target: CombatCharacter) -> int:
		return t.marks(target, CHARGE)

	## Removes one Charge; returns true if there was one.
	static func take_charge(t: Tk, target: CombatCharacter) -> bool:
		if target == null or not is_instance_valid(target) or t.marks(target, CHARGE) <= 0:
			return false
		target.kit.add_mark(CHARGE, -1, 0.0, 3, t.caster)
		if t.marks(target, CHARGE) <= 0:
			target.kit.consume_mark(CHARGE)
		return true

	## Micro-shock: interrupts a cast; a channel is broken by a tiny stun.
	## Never a full stun.
	static func jolt(t: Tk, target: CombatCharacter) -> void:
		if not t.is_enemy(target):
			return
		t.fx("sparks", target.global_position, 0.6, VOLT)
		t.text(target, "SECOUSSE")
		if target.abilities.is_casting():
			target.abilities.interrupt()
		for key: String in target.kit.modifiers.keys():
			if key.begins_with("channel_"):
				t.status(target, StatusController.Type.STUN, 0.12)
				break

	## Electric residue on the ground: gives 1 Charge to each enemy crossing it.
	static func residue(t: Tk, at: Vector3, lifetime: float) -> KitObject:
		return t.object(at, {"kind": RESIDU, "radius": 0.9, "lifetime": lifetime, "look": KitObject.Look.GLYPH,
			"targetable": false, "color": VOLT, "data": {"seen": {}},
			"on_enter": func(e: CombatCharacter, o: KitObject) -> void:
				if t.is_enemy(e) and not o.data.seen.has(e.get_instance_id()):
					o.data.seen[e.get_instance_id()] = true
					charge(t, e)})

	static func residues(t: Tk) -> Array[KitObject]:
		return t.objects(RESIDU, &"")

	## Removes the slow that the DEBUFF tag adds to every hit of the ability.
	static func clean(t: Tk) -> void:
		t.ability.slow_duration = 0.0

	## Thin lightning segment (visual only).
	static func arc(t: Tk, from: Vector3, to: Vector3) -> void:
		if CombatFx.is_enabled():
			var mi := KitVisuals.line_visual(t.caster.get_parent(), VOLT)
			KitVisuals.update_line(mi, HitQuery.flat(from), HitQuery.flat(to))
			t.tree().create_timer(0.15).timeout.connect(mi.queue_free)

	static func has_los(t: Tk, from: Vector3, to: Vector3) -> bool:
		var up: Vector3 = Vector3.UP * HitQuery.BODY_HEIGHT
		return HitQuery.raycast_world(t.caster.get_world_3d(), HitQuery.flat(from) + up, HitQuery.flat(to) + up).is_empty()

	## Point beside `target` on the side `side_of` comes from, rotated 90°
	## (a predictable flank, never inside the model).
	static func flank(target: CombatCharacter, side_of: Vector3, dist: float = 1.5) -> Vector3:
		var to: Vector3 = HitQuery.flat(side_of - target.global_position)
		if to.length() < 0.1:
			to = Vector3.FORWARD
		return HitQuery.flat(target.global_position) + to.normalized().rotated(Vector3.UP, PI * 0.5) * dist


## D — Hitscan, Marque, Interrupt. After a short readable delay (startup),
## a very thin bolt strikes the first enemy in line: low damage + 1 Charge;
## on a target already at 3 Charges it adds nothing and jolts instead
## (interrupts a long cast without a full stun).
class AiguilleVoltaique extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.25
		a.recovery_time = 0.2
		a.max_range = 10.0
		a.anim = &"chidori"

	func cast(t: Tk) -> void:
		K.clean(t)
		var reach: float = t.distance(t.origin, t.clear_point(t.origin, t.dir, 10.0))
		var first: CombatCharacter = null
		for e: CombatCharacter in t.enemies_in_line(t.origin, t.dir, reach, 0.3):
			if first == null or t.distance(e.global_position, t.origin) < t.distance(first.global_position, t.origin):
				first = e
		if first == null:
			K.arc(t, t.origin, t.origin + t.dir * reach)
			return
		K.arc(t, t.origin, first.global_position)
		var full: bool = K.charges(t, first) >= 3
		if t.hit(first, t.dmg(0.35)) != HitData.Result.HIT:
			return
		if full:
			K.jolt(t, first)
		else:
			K.charge(t, first)


## D — Dash, Cible conditionnelle, Reposition. Short dash; ending near a
## charged target curves the end of the run around it (orbit to its flank,
## never through it). Leaves a 1 s residue at the start that charges enemies
## crossing it. No invulnerability.
class PasIonique extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.06
		a.recovery_time = 0.12
		a.cast_move_multiplier = 1.0
		a.max_range = 4.5
		a.anim = &"dash"

	func cast(t: Tk) -> void:
		K.clean(t)
		K.residue(t, t.origin, 1.0)
		var end: Vector3 = t.clear_point(t.origin, t.dir, 4.5)
		var best: CombatCharacter = null
		for e: CombatCharacter in t.enemies_in(end, 2.5):
			if K.charges(t, e) > 0 and (best == null or t.distance(e.global_position, end) < t.distance(best.global_position, end)):
				best = e
		if best == null:
			t.dash(t.distance(t.origin, end), t.dir, 0.15)
			return
		# Orbit: finish on the target's flank on the side the dash was heading.
		var to_t: Vector3 = HitQuery.flat(best.global_position - t.origin)
		var side: float = signf(to_t.signed_angle_to(t.dir, Vector3.UP))
		var around: Vector3 = (-to_t.normalized()).rotated(Vector3.UP, (1.0 if side >= 0.0 else -1.0) * PI * 0.5)
		var spot: Vector3 = HitQuery.flat(best.global_position) + around * 1.5
		var path: Vector3 = HitQuery.flat(spot - t.origin)
		if path.length() > 6.5 or path.length() < 0.3:
			t.dash(t.distance(t.origin, end), t.dir, 0.15)
			return
		t.dash(path.length(), path.normalized(), 0.17)
		t.fx("sparks", spot, 0.8, VOLT)
		t.after(0.18, func(rt: Tk) -> void:
			if is_instance_valid(best) and t.is_enemy(best):
				rt.caster.facing.set_direction(HitQuery.flat(best.global_position - rt.caster.global_position)))


## C — Chaîne, Propagation, Choix de cible. A bolt strikes the enemy or the
## charged ground point (residue) at the aim, then jumps to up to two new
## nearby enemies: each jump deals less but carries 1 Charge. Each target is
## hit once per cast.
class ArcSauteur extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.max_range = 9.0
		a.anim = &"chidori"

	func cast(t: Tk) -> void:
		K.clean(t)
		var done: Array[CombatCharacter] = []
		var at: Vector3 = t.aim
		var first: CombatCharacter = t.target_at_aim(2.0)
		var node: KitObject = null
		if first == null:
			for r: KitObject in K.residues(t):
				if t.distance(r.global_position, t.aim) <= 2.0 and (node == null or \
						t.distance(r.global_position, t.aim) < t.distance(node.global_position, t.aim)):
					node = r
		if first == null and node == null:
			var front: Array[CombatCharacter] = t.enemies_in_cone(t.origin, t.dir, 9.0, 40.0)
			if not front.is_empty():
				first = front[0]
		if first != null:
			at = first.global_position
			K.arc(t, t.origin, at)
			t.hit(first, t.dmg(0.6))
			K.charge(t, first)
			done.append(first)
		elif node != null:
			at = node.global_position
			K.arc(t, t.origin, at)
			t.fx("sparks", at, 0.8, VOLT)
			node.destroy("arc")
		else:
			t.fx("sparks", t.aim, 0.6, VOLT)
			return
		var mults: Array[float] = [0.45, 0.3]
		for jump in 2:
			var next: CombatCharacter = null
			for e: CombatCharacter in t.enemies_in(at, 5.0):
				if not done.has(e) and (next == null or t.distance(e.global_position, at) < t.distance(next.global_position, at)):
					next = e
			if next == null:
				break
			K.arc(t, at, next.global_position)
			t.hit(next, t.dmg(mults[jump]))
			K.charge(t, next)
			done.append(next)
			at = next.global_position


## C — Parade, Stockage, Recast. Very short frontal electric guard: direct
## hits from the front are reduced and their energy stored in the
## Condensateur. Recast: releases it as a short wave whose push grows with
## the stored energy; damage is capped.
class GardeStatique extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.02
		a.recovery_time = 0.15
		a.max_range = 3.0
		a.anim = &"guard"

	func cast(t: Tk) -> void:
		t.fx("ring", t.origin, 1.2, VOLT)
		t.buff("garde_statique", 0.6, {"speed": 0.6, "label": "Garde statique", "color": VOLT,
			"on_take": func(h: HitData, dmg: float) -> Variant:
				if not is_instance_valid(h.source) or h.source == t.caster or h.ability == null:
					return null  # persistent damage / traps without an attacker
				var to: Vector3 = HitQuery.flat(h.source.global_position - t.caster.global_position)
				if to.length() > 0.05 and t.caster.facing.facing_direction.dot(to.normalized()) < 0.3:
					return null  # from the back or the side
				t.add_res(CONDENSATEUR, dmg * 0.6)
				t.fx("sparks", t.caster.global_position, 0.8, VOLT)
				return dmg * 0.4})
		t.recast(4.6, func(rt: Tk) -> void:
			rt.kit().remove_modifier("garde_statique")
			var stored: float = rt.take_all_res(CONDENSATEUR)
			var push: float = minf(2.0 + stored * 0.15, 7.0)
			rt.fx("wave", rt.origin, 3.0, VOLT)
			for e: CombatCharacter in rt.area(rt.origin, 3.0, rt.dmg(0.4) + minf(stored * 0.5, rt.dmg(0.8)), {"push": push}):
				K.charge(rt, e))


## B — Skillshot, Pull/Push, Consommation. A thin magnetic spear hooks the
## first enemy hit. Moving towards the target pulls the caster to it,
## otherwise the target is pulled in. Every Charge consumed (up to 3)
## strengthens the displacement. No stun.
class LanceMagnetique extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.25
		a.recovery_time = 0.25
		a.max_range = 11.0
		a.anim = &"throw"

	func cast(t: Tk) -> void:
		t.projectile({"speed": 30.0, "range": 11.0, "radius": 0.4, "size": 0.18, "color": VOLT,
			"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
				_hook(t.refreshed(), e)
				return false})

	func _hook(t: Tk, e: CombatCharacter) -> void:
		if t.hit(e, t.dmg(0.6)) != HitData.Result.HIT or not t.is_enemy(e):
			return
		var n: int = mini(t.consume_mark(e, CHARGE), 3)
		var force: float = 2.5 + 1.5 * n
		K.arc(t, t.caster.global_position, e.global_position)
		var to: Vector3 = HitQuery.flat(e.global_position - t.caster.global_position)
		var vel: Vector3 = HitQuery.flat(t.caster.velocity)
		if vel.length() > 1.0 and vel.normalized().dot(to.normalized()) > 0.3:
			# Grapple: the caster flies to the target (stops beside it).
			var d: float = minf(force + 2.0, to.length() - 1.2)
			if d > 0.2:
				t.dash(d, to.normalized(), 0.2)
			t.text(t.caster, "GRAPPIN")
		else:
			t.pull(e, t.caster.global_position, force)
			t.text(e, "ATTIRÉ")


## B — Piège, Barrière conditionnelle, Contrôle. Four destructible pylons
## around a small area; after a short telegraph they link up. Crossing a
## link consumes 1 Charge for a short shock (tiny stun + interrupt);
## without Charge it only slows briefly. No physical wall; destroyed pylons
## open exits; dashes trigger links but are not cancelled.
class CageDeFoudre extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.max_range = 9.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var center: Vector3 = t.aim
		var pylons: Array[KitObject] = []
		for i in 4:
			var at: Vector3 = center + Vector3.FORWARD.rotated(Vector3.UP, PI * 0.25 + PI * 0.5 * i) * 2.8
			pylons.append(t.object(at, {"kind": "pylone", "radius": 0.45, "lifetime": 6.0, "health": t.dmg(1.2),
				"look": KitObject.Look.PILLAR, "color": VOLT}))
		t.object(center, {"kind": "cage", "radius": 2.8, "lifetime": 6.0, "look": KitObject.Look.RING,
			"targetable": false, "color": VOLT, "data": {"prev": {}, "cd": {}},
			"on_tick": func(o: KitObject) -> void:
				_tick(t, o, pylons)})

	func _tick(t: Tk, o: KitObject, pylons: Array[KitObject]) -> void:
		var alive_count: int = 0
		for p: KitObject in pylons:
			if is_instance_valid(p) and p.is_alive():
				alive_count += 1
		if alive_count == 0:
			o.destroy("open")
			return
		var armed: bool = o.age >= 0.8  # telegraph before the links appear
		if armed and not o.data.get("lit", false):
			o.data["lit"] = true
			for i in 4:
				if _alive(pylons[i]) and _alive(pylons[(i + 1) % 4]):
					K.arc(t, pylons[i].global_position, pylons[(i + 1) % 4].global_position)
		var prev: Dictionary = o.data.prev
		var cd: Dictionary = o.data.cd
		for e: CombatCharacter in t.enemies_in(o.global_position, 6.0):
			var key: int = e.get_instance_id()
			var now: Vector3 = HitQuery.flat(e.global_position)
			var before: Vector3 = prev.get(key, now)
			prev[key] = now
			if not armed or o.age < float(cd.get(key, 0.0)) or before.distance_to(now) < 0.001:
				continue
			for i in 4:
				var a: KitObject = pylons[i]
				var b: KitObject = pylons[(i + 1) % 4]
				if not _alive(a) or not _alive(b):
					continue
				if Geometry2D.segment_intersects_segment(Vector2(before.x, before.z), Vector2(now.x, now.z),
						Vector2(a.global_position.x, a.global_position.z), Vector2(b.global_position.x, b.global_position.z)) != null:
					cd[key] = o.age + 0.5
					K.arc(t, a.global_position, b.global_position)
					if K.take_charge(t, e):
						t.hit(e, t.dmg(0.35), {"stun": 0.25})
						K.jolt(t, e)
					else:
						t.status(e, StatusController.Type.SLOW, 0.6)
						t.fx("sparks", e.global_position, 0.5, VOLT)
					break

	func _alive(p: KitObject) -> bool:
		return is_instance_valid(p) and p.is_alive()


## A — Mode, Mêlée, Mobilité. Short lightning mode: faster, basic attacks
## that connect step the caster forward to stay on the target and every
## third contact applies a Charge. Continuous chakra drain; heavy hits taken
## burn the mode faster. Recast: ends it with a short pushing discharge.
class ArmureDEclair extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.max_range = 3.0
		a.anim = &"chidori"

	func cast(t: Tk) -> void:
		var state: Dictionary = {"hits": 0}
		var heavy: float = t.dmg(0.6)
		t.fx("sparks", t.origin, 1.0, VOLT)
		t.buff("armure_eclair", 6.0, {"speed": 1.35, "label": "Armure d'éclair", "color": VOLT,
			"on_deal": func(target: CombatCharacter, h: HitData, _dmg: float) -> Variant:
				if h.ability == null or not t.caster.abilities.is_basic_attack(h.ability):
					return null
				state.hits = int(state.hits) + 1
				var to: Vector3 = HitQuery.flat(target.global_position - t.caster.global_position)
				if to.length() > 1.4:
					t.dash(minf(0.7, to.length() - 1.2), to.normalized(), 0.08)
				if int(state.hits) % 3 == 0:
					K.charge(t, target)
					t.fx("sparks", target.global_position, 0.6, VOLT)
				return null,
			"on_take": func(_h: HitData, dmg: float) -> Variant:
				if dmg >= heavy and t.kit().modifiers.has("armure_eclair"):
					t.kit().modifiers["armure_eclair"].left -= 1.5
				return null,
			"on_tick": func(dt: float) -> void:
				if not t.caster.energy.consume(3.0 * dt):
					t.kit().modifiers["armure_eclair"].left = 0.0,
			"on_end": func() -> void:
				t.kit().close_recast(t.id)})
		t.recast(6.0, func(rt: Tk) -> void:
			rt.kit().remove_modifier("armure_eclair")
			rt.fx("wave", rt.origin, 2.8, VOLT)
			for e: CombatCharacter in rt.area(rt.origin, 2.8, rt.dmg(0.5), {"push": 3.5}):
				K.charge(rt, e))


## A — Marque, Frappe retardée, Lecture. Designates a visible target: three
## storm circles appear on it one after another and strike after a regular
## delay (each can be dodged). Each Charge present at marking lets one
## strike correct its impact towards the target's last movement direction
## (consuming that Charge) — only while the caster keeps line of sight.
class TonnerreGuide extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.25
		a.max_range = 12.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		K.clean(t)
		var target: CombatCharacter = t.target_at_aim(3.0)
		if target == null:
			var front: Array[CombatCharacter] = t.enemies_in_cone(t.origin, t.dir, 12.0, 50.0)
			if not front.is_empty():
				target = front[0]
		if target == null or not K.has_los(t, t.origin, target.global_position):
			t.fx("bolt", t.aim, 0.8, VOLT)
			return
		var state: Dictionary = {"corrections": K.charges(t, target)}
		t.text(target, "ORAGE")
		for i in 3:
			if i == 0:
				_marker(t, target, state)
			else:
				t.after(0.8 * i, func(rt: Tk) -> void:
					_marker(rt, target, state))

	func _marker(t: Tk, target: CombatCharacter, state: Dictionary) -> void:
		if not is_instance_valid(target) or not t.is_enemy(target):
			return
		t.object(target.global_position, {"kind": "orage", "radius": 1.3, "lifetime": 0.8, "look": KitObject.Look.RING,
			"targetable": false, "color": VOLT,
			"on_expire": func(o: KitObject) -> void:
				if not t.alive():
					return
				var at: Vector3 = HitQuery.flat(o.global_position)
				if int(state.corrections) > 0 and is_instance_valid(target) and t.is_enemy(target) and K.has_los(t, t.caster.global_position, target.global_position):
					var moving: Vector3 = HitQuery.flat(target.velocity)
					if moving.length() > 0.5 and K.take_charge(t, target):
						state.corrections = int(state.corrections) - 1
						at += moving.normalized() * 1.3
				t.fx("bolt", at, 1.3, VOLT)
				t.area(at, 1.3, t.dmg(0.7))})


## S — Réseau, Téléportation, Combo. Every active Charge on enemies (consumed)
## and every ground residue becomes a Raijin Node for 5 s (plus one node on
## the aimed enemy or point). Recast: teleport to the unused node nearest
## the aim (short internal delay between jumps). Each node works once; an
## enemy node lands the caster on its flank with a light strike; the last
## jump releases a stronger wave.
class CircuitRaijin extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.max_range = 16.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var aimed: CombatCharacter = t.target_at_aim(2.0)
		for e: CombatCharacter in t.enemies_in(t.origin, 16.0):
			if t.consume_mark(e, CHARGE) > 0 or e == aimed:
				_node(t, e.global_position, e)
		for r: KitObject in K.residues(t):
			if t.distance(r.global_position, t.origin) <= 16.0:
				_node(t, r.global_position, null)
				r.destroy("node")
		if aimed == null:
			_node(t, t.aim, null)
		t.fx("ring", t.origin, 16.0, VOLT)
		var deadline: float = Time.get_ticks_msec() / 1000.0 + 5.0
		_open(t, deadline)

	func _node(t: Tk, at: Vector3, who: CombatCharacter) -> void:
		t.object(at, {"kind": "noeud", "radius": 0.7, "lifetime": 5.0, "look": KitObject.Look.GLYPH, "targetable": false,
			"color": Color(0.8, 0.9, 1.0), "data": {"who": who},
			"on_tick": func(o: KitObject) -> void:
				var ref: Variant = o.data.get("who")
				if ref != null:
					if not is_instance_valid(ref) or not t.is_enemy(ref as CombatCharacter):
						o.destroy("lost")
						return
					o.global_position = HitQuery.flat((ref as CombatCharacter).global_position)})

	func _open(t: Tk, deadline: float) -> void:
		var left: float = deadline - Time.get_ticks_msec() / 1000.0
		if left <= 0.05 or t.objects("noeud").is_empty():
			return
		t.recast(left, func(rt: Tk) -> void:
			_jump(rt, deadline))

	func _jump(t: Tk, deadline: float) -> void:
		var best: KitObject = null
		for o: KitObject in t.objects("noeud"):
			if best == null or t.distance(o.global_position, t.aim) < t.distance(best.global_position, t.aim):
				best = o
		if best == null:
			return
		var who: Variant = best.data.get("who")
		var from: Vector3 = t.caster.global_position
		best.destroy("used")
		if who != null and is_instance_valid(who) and t.is_enemy(who as CombatCharacter):
			var e: CombatCharacter = who
			t.blink(K.flank(e, from), t.caster)
			t.caster.facing.set_direction(HitQuery.flat(e.global_position - t.caster.global_position))
			K.arc(t, from, t.caster.global_position)
			t.hit(e, t.dmg(0.4))
		else:
			t.blink(best.global_position, t.caster)
			K.arc(t, from, t.caster.global_position)
		if t.objects("noeud").is_empty():
			# Last jump: a stronger wave.
			t.fx("wave", t.caster.global_position, 3.0, VOLT)
			t.area(t.caster.global_position, 3.0, t.dmg(0.9), {"push": 2.5})
			return
		t.after(0.25, func(rt: Tk) -> void:
			_open(rt, deadline))


## S — Zone, Branches, Consommation de marques. A storm rises slowly over a
## wide, clearly bounded area, then strikes at regular intervals: a charged
## enemy inside (or a residue), branching to other charged enemies nearby
## (each target once per strike, 1 Charge lost per hit), otherwise a random
## ground point. Unprepared, it dies out after a few dry strikes.
class CataclysmeDeLOrage extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.45
		a.max_range = 11.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		K.clean(t)
		var center: Vector3 = t.aim
		t.object(center, {"kind": "montee_orage", "radius": 8.0, "lifetime": 1.2, "look": KitObject.Look.RING,
			"targetable": false, "color": VOLT,
			"on_expire": func(_o: KitObject) -> void:
				if t.alive():
					_storm(t.refreshed(), center)})

	func _storm(t: Tk, center: Vector3) -> void:
		t.zone(center, 8.0, 6.5, {"kind": "orage", "color": Color(0.3, 0.35, 0.55), "targetable": false,
			"tick_interval": 0.6, "data": {"dry": 0, "strikes": 0},
			"on_tick": func(o: KitObject) -> void:
				if o.age < 0.1:
					return
				if not t.alive() or int(o.data.strikes) >= 10 or int(o.data.dry) >= 3:
					o.destroy("faded")
					return
				o.data.strikes = int(o.data.strikes) + 1
				if _strike(t, o):
					o.data.dry = 0
				else:
					o.data.dry = int(o.data.dry) + 1})

	## Returns true if the strike found a Charge.
	func _strike(t: Tk, o: KitObject) -> bool:
		var first: CombatCharacter = null
		for e: CombatCharacter in t.enemies_in(o.global_position, o.radius):
			if K.charges(t, e) > 0 and (first == null or K.charges(t, e) > K.charges(t, first)):
				first = e
		if first != null:
			var done: Array[CombatCharacter] = []
			var cur: CombatCharacter = first
			var mult: float = 0.6
			while cur != null:
				done.append(cur)
				t.fx("bolt", cur.global_position, 1.0, VOLT)
				t.hit(cur, t.dmg(mult))
				K.take_charge(t, cur)
				mult = 0.45
				var next: CombatCharacter = null
				for e: CombatCharacter in t.enemies_in(cur.global_position, 5.0):
					if not done.has(e) and K.charges(t, e) > 0:
						next = e
						break
				if next != null:
					K.arc(t, cur.global_position, next.global_position)
				cur = next
			return true
		for r: KitObject in K.residues(t):
			if o.contains(r.global_position):
				t.fx("bolt", r.global_position, 1.5, VOLT)
				t.area(r.global_position, 1.5, t.dmg(0.5))
				r.destroy("struck")
				return true
		var at: Vector3 = o.global_position + Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * randf() * o.radius
		t.fx("bolt", at, 1.2, VOLT)
		t.area(at, 1.2, t.dmg(0.4))
		return false
