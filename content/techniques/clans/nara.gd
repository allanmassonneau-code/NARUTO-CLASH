extends RefCounted
## Technique kit: clan_nara (design bible). Signature: Ancres d'ombre and
## Longueur d'ombre — some techniques plant shadow Anchors ("ancre" objects,
## destructible) on the ground; shadow lines link the Nara to an Anchor or to
## an enemy ("lien" tethers + "relie" mark). Walls cut lines (line of sight).
## The available shadow length ("ombre" resource, regenerates) is the main
## resource of the kit: links, stitches and the possession spend it.

const KIT_ID := &"clan_nara"
const SIGNATURE = NaraSignature
const TECHNIQUES := {
	&"clan_nara_d_fil_d_ombre": FilDOmbre,
	&"clan_nara_c_pas_jumeau": PasJumeau,
	&"clan_nara_b_couture_des_ombres": CoutureDesOmbres,
	&"clan_nara_a_possession_tactique": PossessionTactique,
	&"clan_nara_s_crepuscule_des_cent_ombres": CrepusculeDesCentOmbres,
}

const OMBRE := "ombre"
const OMBRE_MAX: float = 100.0
const RELIE := "relie"
const CHARGE := "charge_ombre"
const MAX_ANCHORS: int = 5
const SHADOW := Color(0.12, 0.1, 0.2)
const SHADOW_GLOW := Color(0.45, 0.35, 0.75)


## Longueur d'ombre: starts full, regenerates slowly (faster when no line
## is held), the domain raises the maximum temporarily.
class NaraSignature extends KitSignature:
	func setup(f: CombatCharacter) -> void:
		f.kit.define_resource(OMBRE, OMBRE_MAX, "Ombre", SHADOW_GLOW)
		f.kit.add_res(OMBRE, OMBRE_MAX)

	func tick(f: CombatCharacter, dt: float) -> void:
		if f.is_dead() or f.kit.res(OMBRE) >= f.kit.res_max(OMBRE):
			return
		var holding: bool = not KitObject.find(f.get_tree(), f, &"", "lien").is_empty()
		f.kit.resources[OMBRE].value = minf(f.kit.res(OMBRE) + dt * (4.0 if holding else 8.0), f.kit.res_max(OMBRE))


## Shared Nara rules: anchors, links, line of sight, mirror symmetry.
class K:
	static func anchors(t: Tk) -> Array[KitObject]:
		return t.objects("ancre", &"")

	## Plants a shadow Anchor (destructible). Oldest one fades beyond the cap.
	static func anchor(t: Tk, at: Vector3, lifetime: float = 14.0) -> KitObject:
		var list: Array[KitObject] = anchors(t)
		if list.size() >= MAX_ANCHORS:
			var oldest: KitObject = list[0]
			for a: KitObject in list:
				if a.age > oldest.age:
					oldest = a
			oldest.destroy("replaced")
		t.fx("smoke", at, 0.7, SHADOW)
		return t.object(at, {"kind": "ancre", "radius": 0.5, "lifetime": lifetime, "health": 20.0,
			"look": KitObject.Look.GLYPH, "color": SHADOW_GLOW})

	## True when no world obstacle cuts the segment a-b.
	static func clear(t: Tk, a: Vector3, b: Vector3) -> bool:
		var up: Vector3 = Vector3.UP * 0.4
		return HitQuery.raycast_world(t.caster.get_world_3d(), HitQuery.flat(a) + up, HitQuery.flat(b) + up).is_empty()

	## Shadow link Nara -> enemy: a tether cut by obstacles or distance. It
	## reveals the target's heading (a ring where it is going) and counts as
	## a connection for the other techniques.
	static func link(t: Tk, e: CombatCharacter, lifetime: float = 4.0, max_dist: float = 14.0) -> KitObject:
		if not t.is_enemy(e):
			return null
		for old: KitObject in t.objects("lien", &""):
			if old.data.get("target") == e:
				old.destroy("relinked")
		t.mark(e, RELIE, 1, lifetime, 1, "Relié")
		var o: KitObject = t.tether(e, max_dist, lifetime, {"interval": 0.0,
			"on_tick": func(obj: KitObject) -> void:
				if not is_instance_valid(e) or not clear(t, t.caster.global_position, e.global_position):
					obj.data["broken"] = true
					obj.destroy("cut")
					return
				obj.data["reveal"] = float(obj.data.get("reveal", 0.0)) + obj.get_physics_process_delta_time()
				if float(obj.data.reveal) >= 0.5:
					obj.data["reveal"] = 0.0
					var v: Vector3 = HitQuery.flat(e.velocity)
					if v.length() > 0.5:
						t.fx("ring", e.global_position + v.normalized() * 1.5, 0.4, SHADOW_GLOW),
			"on_break": func() -> void:
				if is_instance_valid(e):
					e.kit.consume_mark(RELIE)})
		o.kind = "lien"
		o.data["target"] = e
		return o

	static func link_of(t: Tk, e: CombatCharacter) -> KitObject:
		for l: KitObject in t.objects("lien", &""):
			if l.data.get("target") == e:
				return l
		return null

	## Linked enemy closest to `near` (within `radius`), or null.
	static func linked_target(t: Tk, near: Vector3, radius: float = 30.0) -> CombatCharacter:
		var best: CombatCharacter = null
		var best_d: float = radius
		for l: KitObject in t.objects("lien", &""):
			var e: CombatCharacter = l.data.get("target") as CombatCharacter
			if t.is_enemy(e) and t.distance(e.global_position, near) <= best_d:
				best = e
				best_d = t.distance(e.global_position, near)
		return best

	static func unlink(t: Tk, e: CombatCharacter) -> void:
		var l: KitObject = link_of(t, e)
		if l != null:
			l.destroy("released")
		if is_instance_valid(e):
			e.kit.consume_mark(RELIE)

	## Mirror of `v` across the plane perpendicular to the Nara -> target
	## axis: walking toward the target makes it walk toward the Nara,
	## sideways motion is mirrored face to face.
	static func mirror(v: Vector3, axis: Vector3) -> Vector3:
		var a: Vector3 = HitQuery.flat(axis).normalized()
		return HitQuery.flat(v - 2.0 * v.dot(a) * a)

	## A dashing fighter (dash jutsu or scripted dash, not a knockback).
	static func is_dashing(f: CombatCharacter) -> bool:
		if f.movement.is_forced() and not f.movement.is_knockback:
			return true
		return f.abilities.is_casting() and f.abilities.current != null and f.abilities.current.kind == AbilityData.Kind.DASH

	static func line_visual(t: Tk) -> MeshInstance3D:
		return KitVisuals.line_visual(t.caster.get_parent(), SHADOW_GLOW) if CombatFx.is_enabled() else null


## D — Skillshot au sol, Tether, Setup. A thin shadow runs along the ground
## (range grows with the available shadow length). On an enemy: a 4 s link
## that reveals its heading; on a wall / at max range: an Anchor.
class FilDOmbre extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.15
		a.recovery_time = 0.2
		a.max_range = 13.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var reach: float = 7.0 + 6.0 * clampf(t.res(OMBRE) / OMBRE_MAX, 0.0, 1.0)
		t.spend_res(OMBRE, minf(10.0, t.res(OMBRE)))
		t.projectile({"speed": 22.0, "range": reach, "radius": 0.5, "size": 0.12, "color": SHADOW,
			"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
				t.hit(e, t.dmg(0.35))
				K.link(t, e, 4.0)
				return false,
			"on_end": func(point: Vector3, _p: TkProjectile, reason: String) -> void:
				if reason != "hit":
					K.anchor(t, point)})


## C — Mimétisme partiel, Recast, Duel. On a linked target (or an enemy in
## contact, linked on the spot) a 4 s mimicry: each abrupt sidestep of the
## Nara gives the target a weak impulse in the mirror direction. Recast:
## break the link and recover 15 shadow length.
class PasJumeau extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.1
		a.recovery_time = 0.15
		a.max_range = 14.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var e: CombatCharacter = K.linked_target(t, t.aim, 14.0)
		if e == null:
			var close: CombatCharacter = t.nearest_enemy(t.origin, 3.5)
			if close != null and K.clear(t, t.origin, close.global_position):
				K.link(t, close, 4.5)
				e = close
		if e == null:
			t.text(t.caster, "AUCUN LIEN", SHADOW_GLOW)
			return
		var l: KitObject = K.link_of(t, e)
		if l != null:
			l.lifetime = maxf(l.lifetime, l.age + 4.5)
		var state := {"lateral": 0.0, "cd": 0.0}
		t.fx("smoke", e.global_position, 0.8, SHADOW)
		t.buff("pas_jumeau", 4.0, {"label": "Pas jumeau", "color": SHADOW_GLOW,
			"on_tick": func(dt: float) -> void:
				state.cd = maxf(0.0, float(state.cd) - dt)
				if not t.is_enemy(e) or K.link_of(t, e) == null:
					t.kit().remove_modifier("pas_jumeau")
					return
				var axis: Vector3 = HitQuery.flat(e.global_position - t.caster.global_position)
				if axis.length() < 0.1:
					return
				var side: Vector3 = axis.normalized().cross(Vector3.UP)
				var lateral: float = HitQuery.flat(t.caster.velocity).dot(side)
				# Abrupt sidestep: lateral speed jumps (start or change of side).
				var abrupt: bool = absf(lateral) > 3.0 and (absf(float(state.lateral)) < 1.5 or signf(lateral) != signf(float(state.lateral)))
				state.lateral = lateral
				if abrupt and float(state.cd) <= 0.0:
					state.cd = 0.35
					var impulse: Vector3 = K.mirror(side * signf(lateral), axis)
					t.push(e, impulse, 1.3, 0.15)
					t.fx("dust", e.global_position, 0.6, SHADOW)})
		t.recast(4.0, func(rt: Tk) -> void:
			rt.kit().remove_modifier("pas_jumeau")
			K.unlink(rt, e)
			rt.add_res(OMBRE, 15.0)
			rt.fx("implosion", rt.caster.global_position, 0.8, SHADOW_GLOW))


## B — Piège entre ancres, Root conditionnel. Stitches the two Anchors
## nearest to the aim (missing ends are planted: at the aim, then at the
## Nara's feet). Every 1.1 s a visible pulse runs along the segment: enemies
## on it are rooted 0.6 s. Each triggering pulse spends 12 shadow length
## (none left = harmless pulse). An Anchor destroyed or a wall cutting the
## segment ends the trap.
class CoutureDesOmbres extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.25
		a.max_range = 12.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var list: Array[KitObject] = K.anchors(t)
		list.sort_custom(func(x: KitObject, y: KitObject) -> bool:
			return t.distance(x.global_position, t.aim) < t.distance(y.global_position, t.aim))
		var ends: Array[KitObject] = []
		for a: KitObject in list:
			if ends.size() < 2:
				ends.append(a)
		if ends.is_empty():
			ends.append(K.anchor(t, t.aim))
		if ends.size() < 2:
			var other: Vector3 = t.origin if t.distance(t.origin, ends[0].global_position) > 2.0 else t.aim
			if t.distance(other, ends[0].global_position) < 2.0:
				other = ends[0].global_position + t.dir * 5.0
			ends.append(K.anchor(t, other))
		var a1: KitObject = ends[0]
		var a2: KitObject = ends[1]
		var mid: Vector3 = (a1.global_position + a2.global_position) * 0.5
		var visual: MeshInstance3D = K.line_visual(t)
		var stitch: KitObject = t.object(mid, {"kind": "couture", "radius": 0.3, "lifetime": 7.0, "look": KitObject.Look.NONE,
			"targetable": false, "tick_interval": 1.1, "color": SHADOW_GLOW,
			"on_tick": func(o: KitObject) -> void:
				if not a1.is_alive() or not a2.is_alive() or not K.clear(t, a1.global_position, a2.global_position):
					o.destroy("cut")
					return
				if o.age < 0.5:
					return
				_pulse(t, a1.global_position, a2.global_position),
			"on_destroy": func(_o: KitObject, _r: String) -> void:
				if is_instance_valid(visual):
					visual.queue_free()})
		if visual != null:
			KitVisuals.update_line(visual, a1.global_position, a2.global_position)
		stitch.data["ends"] = [a1, a2]

	func _pulse(t: Tk, p1: Vector3, p2: Vector3) -> void:
		var seg: Vector3 = HitQuery.flat(p2 - p1)
		if seg.length() < 0.2:
			return
		var d: Vector3 = seg.normalized()
		for i in 4:
			t.fx("spikes", p1 + seg * (0.125 + 0.25 * i), 0.5, SHADOW_GLOW)
		var caught: Array[CombatCharacter] = t.enemies_in_line(p1, d, seg.length(), 0.6)
		if caught.is_empty():
			return
		if not t.spend_res(OMBRE, 12.0):
			t.text(t.caster, "OMBRE ÉPUISÉE", SHADOW_GLOW)
			return
		for e: CombatCharacter in caught:
			t.hit(e, t.dmg(0.3), {"root": 0.6})
			t.text(e, "COUSU", SHADOW_GLOW)


## A — Contrôle limité, Symétrie, Canalisation. On a linked target in range
## (without link, a thread is thrown first and the possession starts on
## hit) with >= 35 shadow length: a 3 s channel imposing movement symmetry —
## the target is slowed and dragged along the mirror of the Nara's own
## movement. It keeps its attacks; a dash cuts 1 s of the effect and slows
## it on arrival. Strict range 10 m, cut by walls, interrupted by CC.
class PossessionTactique extends Technique:
	const COST: float = 35.0
	const RANGE: float = 10.0

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.25
		a.max_range = RANGE
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		if t.res(OMBRE) < COST:
			t.text(t.caster, "OMBRE INSUFFISANTE", SHADOW_GLOW)
			return
		var e: CombatCharacter = K.linked_target(t, t.aim, 30.0)
		if e != null and t.distance(e.global_position, t.origin) <= RANGE:
			_possess(t, e)
			return
		t.projectile({"speed": 20.0, "range": RANGE, "radius": 0.5, "size": 0.14, "color": SHADOW,
			"on_hit": func(target: CombatCharacter, _p: TkProjectile) -> bool:
				K.link(t, target, 4.0, RANGE + 1.0)
				_possess(t.refreshed(), target)
				return false,
			"on_end": func(point: Vector3, _p: TkProjectile, reason: String) -> void:
				if reason != "hit":
					K.anchor(t, point)})

	func _possess(t: Tk, e: CombatCharacter) -> void:
		if not t.is_enemy(e) or not t.spend_res(OMBRE, COST):
			return
		var state := {"left": 3.0, "ended": false, "dashing": false}
		var l: KitObject = K.link_of(t, e)
		if l != null:
			l.lifetime = maxf(l.lifetime, l.age + 3.5)
		t.fx("implosion", e.global_position, 1.0, SHADOW)
		t.text(e, "POSSÉDÉ", SHADOW_GLOW)
		t.debuff(e, "possession", 3.0, {"speed": 0.45, "label": "Possession", "color": SHADOW_GLOW})
		var finish := func() -> void:
			if bool(state.ended):
				return
			state.ended = true
			if is_instance_valid(e):
				e.kit.remove_modifier("possession")
			t.kit().remove_modifier("possession_lien")
		# Per-frame symmetry while the link holds.
		t.buff("possession_lien", 3.2, {"label": "Possession", "color": SHADOW_GLOW,
			"on_tick": func(dt: float) -> void:
				if bool(state.ended):
					return
				state.left = float(state.left) - dt
				if float(state.left) <= 0.0 or not t.is_enemy(e) or K.link_of(t, e) == null \
						or t.distance(e.global_position, t.caster.global_position) > RANGE:
					finish.call()
					return
				if K.is_dashing(e):
					if not bool(state.dashing):
						state.dashing = true
						state.left = float(state.left) - 1.0
					return
				if bool(state.dashing):
					state.dashing = false
					t.status(e, StatusController.Type.SLOW, 0.6)
				var axis: Vector3 = HitQuery.flat(e.global_position - t.caster.global_position)
				var v: Vector3 = HitQuery.flat(t.caster.velocity)
				if v.length() > 0.3 and axis.length() > 0.1 and not e.movement.is_forced():
					e.move_and_collide(K.mirror(v, axis) * 0.8 * dt)})
		t.channel(6, 0.5, func(ct: Tk, _i: int) -> void:
			if bool(state.ended):
				return
			ct.fx("smoke", e.global_position if is_instance_valid(e) else ct.origin, 0.6, SHADOW)
			if not ct.spend_res(OMBRE, 4.0):
				finish.call(),
			func(_dt: Tk, _completed: bool) -> void:
				finish.call(), 0.75)


## S — Domaine, Réseau automatique, Gestion de ressource. A 12 m domain for
## 10 s: shadow reserve extended (max 200, +100), 4 Anchors rise around the
## Nara and every pair of Anchors in the domain with a clear segment is
## linked into a visible mesh. Enemies crossing 2 segments within 2 s gain a
## Charge d'Ombre; at 3 their next dash is cancelled at its start and the
## charges vanish. Recast (up to 3 times): move to the Anchor nearest the
## aim (10 shadow length each).
class CrepusculeDesCentOmbres extends Technique:
	const RADIUS: float = 12.0
	const LIFE: float = 10.0

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.5
		a.max_range = RADIUS
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var center: Vector3 = t.origin
		t.fx("wave", center, RADIUS, SHADOW)
		t.kit().define_resource(OMBRE, OMBRE_MAX * 2.0, "Ombre", SHADOW_GLOW)
		t.add_res(OMBRE, 100.0)
		for i in 4:
			var at: Vector3 = t.clear_point(center, Vector3.FORWARD.rotated(Vector3.UP, PI * 0.5 * i + PI * 0.25), 6.0)
			K.anchor(t, at, LIFE)
		var domain: KitObject = t.zone(center, RADIUS, LIFE, {"kind": "crepuscule", "look": KitObject.Look.RING,
			"targetable": false, "tick_interval": 0.1, "color": SHADOW,
			"data": {"segments": [], "sides": {}, "crossings": {}, "rebuild": 0.0},
			"on_tick": func(o: KitObject) -> void:
				_mesh_tick(t, o),
			"on_destroy": func(o: KitObject, _r: String) -> void:
				for s: Dictionary in o.data.segments:
					if is_instance_valid(s.visual):
						s.visual.queue_free()
				if t.alive():
					t.kit().define_resource(OMBRE, OMBRE_MAX, "Ombre", SHADOW_GLOW)
					t.kit().resources[OMBRE].value = minf(t.res(OMBRE), OMBRE_MAX)})
		_open_hop(t, domain, 3)

	func _open_hop(t: Tk, domain: KitObject, hops: int) -> void:
		if hops <= 0:
			return
		t.recast(LIFE, func(rt: Tk) -> void:
			if not domain.is_alive():
				return
			var best: KitObject = null
			for a: KitObject in K.anchors(rt):
				if domain.contains(a.global_position) and (best == null \
						or rt.distance(a.global_position, rt.aim) < rt.distance(best.global_position, rt.aim)):
					best = a
			if best != null and rt.spend_res(OMBRE, 10.0):
				rt.blink(best.global_position + rt.dir * 0.6)
				rt.fx("smoke", best.global_position, 1.0, SHADOW)
			_open_hop(rt, domain, hops - 1))

	## Rebuilds the mesh from living Anchors, then counts segment crossings.
	func _mesh_tick(t: Tk, o: KitObject) -> void:
		o.data.rebuild = float(o.data.rebuild) - o.tick_interval
		if float(o.data.rebuild) <= 0.0:
			o.data.rebuild = 0.5
			for s: Dictionary in o.data.segments:
				if is_instance_valid(s.visual):
					s.visual.queue_free()
			var segs: Array = []
			var list: Array[KitObject] = []
			for a: KitObject in K.anchors(t):
				if o.contains(a.global_position):
					list.append(a)
			for i in list.size():
				for j in range(i + 1, list.size()):
					var p1: Vector3 = list[i].global_position
					var p2: Vector3 = list[j].global_position
					if t.distance(p1, p2) > 0.5 and K.clear(t, p1, p2):
						var vis: MeshInstance3D = K.line_visual(t)
						if vis != null:
							KitVisuals.update_line(vis, p1, p2)
						segs.append({"a": p1, "b": p2, "key": "%d_%d" % [list[i].get_instance_id(), list[j].get_instance_id()], "visual": vis})
			o.data.segments = segs
		var now: float = o.age
		for e: CombatCharacter in t.enemies_in(o.global_position, o.radius):
			var eid: int = e.get_instance_id()
			var p: Vector3 = HitQuery.flat(e.global_position)
			for s: Dictionary in o.data.segments:
				var ab: Vector3 = HitQuery.flat(s.b - s.a)
				var ap: Vector3 = p - HitQuery.flat(s.a)
				var along: float = ap.dot(ab) / maxf(ab.length_squared(), 0.01)
				var side: float = signf(ab.cross(ap).y)
				var key: String = "%d|%s" % [eid, s.key]
				var prev: float = float(o.data.sides.get(key, side))
				o.data.sides[key] = side
				if side != 0.0 and prev != 0.0 and side != prev and along >= 0.0 and along <= 1.0:
					var times: Array = o.data.crossings.get(eid, [])
					times = times.filter(func(x: float) -> bool: return now - x < 2.0)
					times.append(now)
					o.data.crossings[eid] = times
					if times.size() >= 2:
						o.data.crossings[eid] = []
						_charge(t, e)

	func _charge(t: Tk, e: CombatCharacter) -> void:
		var n: int = t.mark(e, CHARGE, 1, 6.0, 3, "Charge d'Ombre")
		t.fx("smoke", e.global_position, 0.6, SHADOW)
		if n < 3 or e.kit.has_modifier("ombre_entrave"):
			return
		t.text(e, "ENTRAVÉ", SHADOW_GLOW)
		t.debuff(e, "ombre_entrave", 6.0, {"label": "Entrave", "color": SHADOW_GLOW,
			"on_tick": func(_dt: float) -> void:
				if not is_instance_valid(e) or e.is_dead():
					return
				if K.is_dashing(e):
					e.abilities.interrupt()
					e.movement.cancel_forced()
					e.kit.consume_mark(CHARGE)
					t.fx("implosion", e.global_position, 0.8, SHADOW)
					t.text(e, "DASH ANNULÉ", SHADOW_GLOW)
					e.kit.remove_modifier("ombre_entrave")})
