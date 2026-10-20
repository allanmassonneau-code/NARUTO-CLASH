extends RefCounted
## Technique kit: clan Fûma (design bible, Ame). Signature: Ancres de fil —
## up to 3 small, visible, destructible anchors ("ancre" objects, oldest
## replaced) planted on the terrain. Fûma techniques bounce on them, stretch
## cables between them or ride them. The ultimate adds 4 temporary big
## anchors ("grande_ancre") to the network. HUD mirror: active anchors.

const KIT_ID := &"clan_fuma"
const SIGNATURE = FumaSignature
const TECHNIQUES := {
	&"clan_fuma_d_shuriken_fuma_angle_mort": ShurikenAngleMort,
	&"clan_fuma_c_fil_du_chasseur": FilDuChasseur,
	&"clan_fuma_b_demon_a_quatre_lames": DemonAQuatreLames,
	&"clan_fuma_a_course_sur_cable": CourseSurCable,
	&"clan_fuma_s_toile_des_lames_cardinales": ToileDesLamesCardinales,
}

const ANCRE := "ancre"
const GRANDE := "grande_ancre"
const MAX_ANCRES: int = 3
const STEEL := Color(0.7, 0.75, 0.85)
const WIRE := Color(0.85, 0.9, 1.0, 0.6)


## HUD: number of anchors this Fûma has on the field.
class FumaSignature extends KitSignature:
	func setup(f: CombatCharacter) -> void:
		f.kit.define_resource(ANCRE, float(MAX_ANCRES), "Ancres", STEEL)

	func tick(f: CombatCharacter, _dt: float) -> void:
		var n: float = float(KitObject.find(f.get_tree(), f, &"", ANCRE).size())
		var cur: float = f.kit.res(ANCRE)
		if absf(cur - n) > 0.01:
			f.kit.add_res(ANCRE, n - cur)


## Shared Fûma rules.
class K:
	## Plants an anchor (max 3: the oldest one is pulled out).
	static func plant(t: Tk, at: Vector3) -> KitObject:
		var mine: Array[KitObject] = KitObject.find(t.tree(), t.caster, &"", ANCRE)
		while mine.size() >= MAX_ANCRES:
			var oldest: KitObject = mine[0]
			for a: KitObject in mine:
				if a.age > oldest.age:
					oldest = a
			oldest.destroy("replaced")
			mine.erase(oldest)
		t.fx("sparks", at, 0.6, STEEL)
		return t.object(at, {"kind": ANCRE, "radius": 0.45, "lifetime": 45.0, "health": 20.0,
			"look": KitObject.Look.PILLAR, "color": STEEL})

	## Every anchor of the caster's network (small and big).
	static func network(t: Tk) -> Array[KitObject]:
		var out: Array[KitObject] = KitObject.find(t.tree(), t.caster, &"", ANCRE)
		out.append_array(KitObject.find(t.tree(), t.caster, &"", GRANDE))
		return out

	static func nearest(t: Tk, point: Vector3, exclude: KitObject = null, max_d: float = INF) -> KitObject:
		var best: KitObject = null
		var best_d: float = max_d
		for a: KitObject in network(t):
			var d: float = t.distance(a.global_position, point)
			if a != exclude and d <= best_d:
				best = a
				best_d = d
		return best

	## "First nearby surface": a wall within 2.5 m if any, else the ground.
	static func surface_point(t: Tk, at: Vector3) -> Vector3:
		var start: Vector3 = HitQuery.flat(at) + Vector3.UP * HitQuery.BODY_HEIGHT
		var best: Vector3 = HitQuery.flat(at)
		var best_d: float = INF
		for i in 8:
			var d: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, TAU * float(i) / 8.0)
			var hit: Dictionary = HitQuery.raycast_world(t.caster.get_world_3d(), start, start + d * 2.5)
			if not hit.is_empty():
				var dist: float = t.distance(hit.position, at)
				if dist < best_d:
					best_d = dist
					best = HitQuery.flat(hit.position - d * 0.3)
		return best

	static func seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
		var ab: Vector3 = HitQuery.flat(b - a)
		var ap: Vector3 = HitQuery.flat(p - a)
		var k: float = clampf(ap.dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		return (ap - ab * k).length()

	static func steer(p: TkProjectile, want: Vector3, rate: float, dt: float) -> void:
		var w: Vector3 = HitQuery.flat(want)
		if w.length() < 0.05:
			return
		var angle: float = p.direction.signed_angle_to(w.normalized(), Vector3.UP)
		p.direction = p.direction.rotated(Vector3.UP, clampf(angle, -rate * dt, rate * dt)).normalized()


## D — Boomerang, Ancre, Rebond. Big wide shuriken: flies 10 m (or to a
## wall), reverses and comes back to the caster, hitting on the way out and
## again on the way back. The return bends toward an anchor it passes near.
## Recast in flight: the blade plants itself in the nearest surface and
## becomes an Ancre instead of returning (no second hit).
class ShurikenAngleMort extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.15
		a.recovery_time = 0.2
		a.max_range = 10.0
		a.anim = &"throw"

	func cast(t: Tk) -> void:
		var state: Dictionary = {"p": null}
		state.p = _fly(t, state, t.origin, t.dir, false)
		t.recast(3.0, func(rt: Tk) -> void:
			var p: TkProjectile = state.p
			if p == null or not is_instance_valid(p) or not p.is_alive():
				return
			var at: Vector3 = K.surface_point(rt, p.ground_point())
			p.end("recast")
			K.plant(rt, at))

	func _fly(t: Tk, state: Dictionary, from: Vector3, d: Vector3, returning: bool) -> TkProjectile:
		return t.projectile({"from": from, "dir": d, "speed": 20.0, "range": 60.0, "radius": 0.85, "size": 0.45,
			"pierce": true, "color": STEEL, "data": {"back": returning, "bend": null, "bent": false, "bend_until": 0.0},
			"on_tick": func(p: TkProjectile, dt: float) -> void:
				if not t.alive() or p.age > 4.0:
					p.end("range")
					return
				if not p.data.back:
					if p.travelled >= 10.0:
						_reverse(p)
					return
				var to_caster: Vector3 = HitQuery.flat(t.caster.global_position - p.global_position)
				if to_caster.length() < 1.0:
					p.end("caught")
					return
				if not p.data.bent:
					var a: KitObject = K.nearest(t, p.global_position, null, 3.0)
					if a != null:
						p.data["bent"] = true
						p.data["bend"] = a
						p.data["bend_until"] = p.age + 0.3
				var want: Vector3 = to_caster
				var a2: Variant = p.data.bend
				if a2 != null and is_instance_valid(a2) and (a2 as KitObject).is_alive() and p.age < float(p.data.bend_until):
					want = HitQuery.flat((a2 as KitObject).global_position - p.global_position)
				K.steer(p, want, 9.0, dt),
			"on_hit": func(e: CombatCharacter, p: TkProjectile) -> bool:
				t.hit(e, t.dmg(0.45 if p.data.back else 0.55))
				return true,
			"on_end": func(point: Vector3, p: TkProjectile, reason: String) -> void:
				if reason == "wall" and not p.data.back and t.alive():
					var back: Vector3 = HitQuery.flat(t.caster.global_position - point).normalized()
					state.p = _fly(t, state, point - p.direction * 0.9, back, true)
				elif reason != "recast" and state.p == p:
					t.kit().close_recast(t.id)})

	func _reverse(p: TkProjectile) -> void:
		p.data["back"] = true
		p.direction = -p.direction
		p._already.clear()  # the return can hit the same targets again


## C — Tripwire, Mobilité, Recast. Stretches a single wire (8 s) between two
## anchors (the one nearest the cursor and its nearest neighbour) or between
## an anchor and the Fûma; with no anchor, a cable kunai plants one at the
## cursor first. Enemies crossing the wire are slowed and Révélé. Recast:
## reel yourself fast to the extremity nearest the cursor, breaking the wire.
class FilDuChasseur extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.15
		a.recovery_time = 0.15
		a.max_range = 12.0
		a.anim = &"throw"

	func cast(t: Tk) -> void:
		for w: KitObject in t.objects("fil"):
			w.destroy("replaced")
		var a: KitObject = K.nearest(t, t.aim, null, 16.0)
		var b: KitObject = null
		if a == null:
			var dist: float = clampf(t.distance(t.origin, t.aim), 2.0, 12.0)
			a = K.plant(t, t.clear_point(t.origin, t.dir, dist))
		else:
			b = K.nearest(t, a.global_position, a, 14.0)
		var line_node: MeshInstance3D = KitVisuals.line_visual(t.caster.get_parent(), WIRE) if CombatFx.is_enabled() else null
		var wire: KitObject = t.object(a.global_position, {"kind": "fil", "radius": 0.1, "lifetime": 8.0,
			"look": KitObject.Look.NONE, "targetable": false, "tick_interval": 0.05,
			"data": {"a": a, "b": b, "seen": {}},
			"on_tick": func(o: KitObject) -> void:
				_tick_wire(t, o, line_node),
			"on_destroy": func(_o: KitObject, reason: String) -> void:
				if line_node != null and is_instance_valid(line_node):
					line_node.queue_free()
				if reason != "used" and is_instance_valid(t.caster):
					t.kit().close_recast(t.id)})
		_tick_wire(t, wire, line_node)
		t.recast(8.0, func(rt: Tk) -> void:
			_reel(rt, wire))

	## Endpoints of the wire, or empty if broken.
	func _ends(t: Tk, o: KitObject) -> Array[Vector3]:
		var out: Array[Vector3] = []
		var a: Variant = o.data.a
		var b: Variant = o.data.b
		if a == null or not is_instance_valid(a) or not (a as KitObject).is_alive():
			return out
		out.append(HitQuery.flat((a as KitObject).global_position))
		if b == null:
			if not t.alive():
				return [] as Array[Vector3]
			out.append(HitQuery.flat(t.caster.global_position))
		elif is_instance_valid(b) and (b as KitObject).is_alive():
			out.append(HitQuery.flat((b as KitObject).global_position))
		else:
			out.clear()
		return out

	func _tick_wire(t: Tk, o: KitObject, line_node: MeshInstance3D) -> void:
		var ends: Array[Vector3] = _ends(t, o)
		if ends.size() < 2:
			o.destroy("broken")
			return
		if line_node != null and is_instance_valid(line_node):
			KitVisuals.update_line(line_node, ends[0] + Vector3.UP * 0.8, ends[1] + Vector3.UP * 0.8)
		var mid: Vector3 = (ends[0] + ends[1]) * 0.5
		var seen: Dictionary = o.data.seen
		for e: CombatCharacter in t.enemies_in(mid, t.distance(ends[0], ends[1]) * 0.5 + 1.0):
			var key: int = e.get_instance_id()
			if K.seg_dist(e.global_position, ends[0], ends[1]) < 0.5 and o.age - float(seen.get(key, -10.0)) > 1.5:
				seen[key] = o.age
				t.status(e, StatusController.Type.SLOW, 1.0)
				t.debuff(e, "revele", 3.0, {"label": "Révélé", "color": STEEL})
				t.text(e, "RÉVÉLÉ", STEEL)
				t.fx("sparks", e.global_position, 0.5, STEEL)

	func _reel(t: Tk, wire: KitObject) -> void:
		if not is_instance_valid(wire) or not wire.is_alive():
			return
		var ends: Array[Vector3] = _ends(t, wire)
		if ends.size() < 2:
			return
		var goal: Vector3 = ends[0]
		if wire.data.b != null and t.distance(ends[1], t.aim) < t.distance(ends[0], t.aim):
			goal = ends[1]
		var to: Vector3 = HitQuery.flat(goal - t.caster.global_position)
		wire.destroy("used")
		var dist: float = to.length() - 0.8
		if dist > 0.4:
			t.dash(dist, to.normalized(), maxf(0.1, dist / 28.0))
			t.fx("dust", t.origin, 0.6, STEEL)


## B — Projectile scindé, Ricochet, Multi-angle. Big shuriken that splits into
## four blades where the recast is pressed (or on hit / wall / max range).
## Each blade seeks the anchor nearest its angle (within 40°) and ricochets
## on it once toward the nearest enemy; without anchors, a plain fan.
class DemonAQuatreLames extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.25
		a.recovery_time = 0.25
		a.max_range = 13.0
		a.anim = &"throw"

	func cast(t: Tk) -> void:
		var state: Dictionary = {"split": false}
		var big: TkProjectile = t.projectile({"speed": 18.0, "range": 13.0, "radius": 0.7, "size": 0.42, "color": STEEL,
			"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
				t.hit(e, t.dmg(0.6))
				return false,
			"on_end": func(point: Vector3, p: TkProjectile, reason: String) -> void:
				if state.split or not t.alive():
					return
				state.split = true
				var at: Vector3 = point - p.direction * 0.6 if reason == "wall" else point
				_split(t, at, p.direction)
				t.kit().close_recast(t.id)})
		t.recast(2.0, func(_rt: Tk) -> void:
			if is_instance_valid(big) and big.is_alive():
				big.end("recast"))

	func _split(t: Tk, at: Vector3, fwd: Vector3) -> void:
		t.fx("sparks", at, 1.0, STEEL)
		var used: Array[KitObject] = []
		for k in 4:
			var d: Vector3 = fwd.rotated(Vector3.UP, deg_to_rad(-45.0 + 30.0 * k))
			var anchor: KitObject = null
			var best: float = deg_to_rad(40.0)
			for a: KitObject in K.network(t):
				var to: Vector3 = HitQuery.flat(a.global_position - at)
				if to.length() < 0.8 or to.length() > 14.0 or used.has(a):
					continue
				var ang: float = d.angle_to(to)
				if ang <= best:
					best = ang
					anchor = a
			if anchor != null:
				used.append(anchor)
				d = HitQuery.flat(anchor.global_position - at).normalized()
			t.projectile({"from": at - d * 0.5, "dir": d, "speed": 22.0, "range": 14.0, "radius": 0.45, "size": 0.18,
				"color": STEEL, "data": {"anchor": anchor, "bounced": false},
				"on_tick": func(p: TkProjectile, _dt: float) -> void:
					var a: Variant = p.data.anchor
					if p.data.bounced or a == null or not is_instance_valid(a) or not (a as KitObject).is_alive():
						return
					var apos: Vector3 = (a as KitObject).global_position
					if t.distance(p.global_position, apos) < 0.7:
						p.data["bounced"] = true
						var e: CombatCharacter = t.nearest_enemy(apos, 12.0)
						p.direction = HitQuery.flat(e.global_position - apos).normalized() if e != null \
							else p.direction.rotated(Vector3.UP, PI * 0.5)
						p.travelled = 0.0
						t.fx("sparks", apos, 0.5, STEEL),
				"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
					t.hit(e, t.dmg(0.45))
					return false})


## A — Mobilité réseau, Attaque en mouvement, Skill expression. Cable mode
## (5 s, +15 % speed): glides at high speed to the anchor nearest the cursor,
## hitting enemies along the cable and throwing a light kunai at the nearest
## enemy mid-glide. Recast (reopened while the mode lasts): glide to the next
## anchor; momentum grows each transition but the anchor left is consumed.
class CourseSurCable extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.15
		a.recovery_time = 0.1
		a.max_range = 16.0
		a.anim = &"dash"

	func cast(t: Tk) -> void:
		var state: Dictionary = {"from": null, "n": 0}
		t.buff("course_cable", 5.0, {"speed": 1.15, "label": "Câble", "color": STEEL})
		_glide(t, state)
		_open(t, state, 5.0)

	func _open(t: Tk, state: Dictionary, seconds: float) -> void:
		t.recast(seconds, func(rt: Tk) -> void:
			if not rt.kit().has_modifier("course_cable"):
				return
			_glide(rt, state)
			var left: float = rt.kit().modifier_left("course_cable")
			if left > 0.1:
				_open(rt, state, left))

	func _glide(t: Tk, state: Dictionary) -> void:
		var from_anchor: Variant = state.from
		var exclude: KitObject = from_anchor as KitObject if from_anchor != null and is_instance_valid(from_anchor) else null
		var goal: KitObject = null
		for a: KitObject in K.network(t):
			if a == exclude or t.distance(a.global_position, t.origin) > 16.0 or t.distance(a.global_position, t.origin) < 1.0:
				continue
			if goal == null or t.distance(a.global_position, t.aim) < t.distance(goal.global_position, t.aim):
				goal = a
		if goal == null:
			t.text(t.caster, "PAS D'ANCRE", STEEL)
			return
		if exclude != null and exclude.is_alive():
			t.fx("sparks", exclude.global_position, 0.6, STEEL)
			exclude.destroy("consumed")
		var to: Vector3 = HitQuery.flat(goal.global_position - t.origin)
		var dist: float = to.length() - 0.7
		var d: Vector3 = to.normalized()
		var speed: float = 20.0 + 5.0 * float(state.n)
		var duration: float = maxf(0.1, dist / speed)
		var cable: MeshInstance3D = KitVisuals.line_visual(t.caster.get_parent(), WIRE) if CombatFx.is_enabled() else null
		if cable != null:
			KitVisuals.update_line(cable, t.origin + Vector3.UP, goal.global_position + Vector3.UP)
			t.tree().create_timer(duration + 0.1).timeout.connect(cable.queue_free)
		t.dash(dist, d, duration)
		t.line(dist, 1.4, t.dmg(0.4), {}, t.origin, d)
		t.after(duration * 0.5, func(kt: Tk) -> void:
			var e: CombatCharacter = kt.nearest_enemy(kt.caster.global_position, 9.0)
			if e == null:
				return
			kt.projectile({"dir": HitQuery.flat(e.global_position - kt.caster.global_position).normalized(),
				"speed": 30.0, "range": 9.0, "radius": 0.4, "size": 0.12, "homing": 2.0, "homing_target": e,
				"color": STEEL, "on_hit": func(h: CombatCharacter, _p: TkProjectile) -> bool:
					kt.hit(h, kt.dmg(0.3))
					return false}))
		state.from = goal
		state.n = int(state.n) + 1


## S — Réseau total, Lignes létales, Recast. Plants four big anchors (N/E/S/W,
## 10 s, destructible) around the target zone and links every anchor of the
## network into a web (segments up to 13 m). Each recast sends a great
## shuriken along the segment closest to the cursor (adjacent to its current
## node, never the segment it just used); it speeds up at every change.
## Broken anchors remove their routes. No automatic strikes.
class ToileDesLamesCardinales extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.4
		a.recovery_time = 0.3
		a.max_range = 11.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var center: Vector3 = t.aim
		for i in 4:
			var d: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, PI * 0.5 * float(i))
			var at: Vector3 = t.clear_point(center, d, 5.0)
			t.fx("sparks", at, 0.8, STEEL)
			t.object(at, {"kind": GRANDE, "radius": 0.6, "lifetime": 10.0, "health": 35.0,
				"look": KitObject.Look.PILLAR, "color": STEEL})
		var lines: Dictionary = {}
		var st: Dictionary = {"node": null, "last": "", "speed": 16.0, "segs": 0, "moving": false, "pending": null}
		var web: KitObject = t.object(center, {"kind": "toile", "radius": 7.0, "lifetime": 10.0, "look": KitObject.Look.NONE,
			"targetable": false, "tick_interval": 0.2,
			"on_tick": func(_o: KitObject) -> void:
				_draw(t, lines),
			"on_destroy": func(_o: KitObject, _r: String) -> void:
				for key: String in lines:
					if is_instance_valid(lines[key]):
						(lines[key] as Node).queue_free()
				lines.clear()})
		t.recast(10.0, func(rt: Tk) -> void:
			_route(rt, web, st, rt.aim))

	func _edges(t: Tk) -> Array[Array]:
		var nodes: Array[KitObject] = K.network(t)
		var out: Array[Array] = []
		for i in nodes.size():
			for j in range(i + 1, nodes.size()):
				if t.distance(nodes[i].global_position, nodes[j].global_position) <= 13.0:
					out.append([nodes[i], nodes[j]])
		return out

	func _key(a: KitObject, b: KitObject) -> String:
		var x: int = a.get_instance_id()
		var y: int = b.get_instance_id()
		return "%d:%d" % [mini(x, y), maxi(x, y)]

	func _draw(t: Tk, lines: Dictionary) -> void:
		if not CombatFx.is_enabled() or not t.alive():
			return
		var alive: Dictionary = {}
		for e: Array in _edges(t):
			var key: String = _key(e[0], e[1])
			alive[key] = true
			if not lines.has(key):
				lines[key] = KitVisuals.line_visual(t.caster.get_parent(), WIRE)
			KitVisuals.update_line(lines[key], (e[0] as KitObject).global_position + Vector3.UP * 0.8,
				(e[1] as KitObject).global_position + Vector3.UP * 0.8)
		for key: String in lines.keys():
			if not alive.has(key):
				if is_instance_valid(lines[key]):
					(lines[key] as Node).queue_free()
				lines.erase(key)

	func _reopen(t: Tk, web: KitObject, st: Dictionary) -> void:
		var left: float = web.lifetime - web.age
		if left > 0.1:
			t.recast(left, func(rt: Tk) -> void:
				_route(rt, web, st, rt.aim))

	func _route(t: Tk, web: KitObject, st: Dictionary, aim: Vector3) -> void:
		if not is_instance_valid(web) or not web.is_alive():
			return
		_reopen(t, web, st)
		if st.moving:
			st.pending = aim  # chosen now, taken at the next node
			return
		var node: KitObject = st.node if st.node != null and is_instance_valid(st.node) and (st.node as KitObject).is_alive() else null
		var best: Array = []
		var best_d: float = INF
		for e: Array in _edges(t):
			var a: KitObject = e[0]
			var b: KitObject = e[1]
			if _key(a, b) == st.last:
				continue
			if node != null and a != node and b != node:
				continue
			var d: float = K.seg_dist(aim, a.global_position, b.global_position)
			if d < best_d:
				best_d = d
				best = e
		if best.is_empty():
			t.text(t.caster, "AUCUNE ROUTE", STEEL)
			return
		var from: KitObject = best[0]
		var to: KitObject = best[1]
		if node != null:
			from = node
			to = best[1] if best[0] == node else best[0]
		elif t.distance(to.global_position, t.origin) < t.distance(from.global_position, t.origin):
			var tmp: KitObject = from
			from = to
			to = tmp
		st.last = _key(from, to)
		st.moving = true
		var seg: Vector3 = HitQuery.flat(to.global_position - from.global_position)
		var mult: float = minf(1.0, 0.55 + 0.1 * float(st.segs))
		t.projectile({"from": HitQuery.flat(from.global_position) - seg.normalized() * 0.5, "dir": seg.normalized(),
			"speed": float(st.speed), "range": seg.length(), "radius": 0.85, "size": 0.5, "pierce": true, "color": STEEL,
			"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
				t.hit(e, t.dmg(mult))
				return true,
			"on_end": func(_point: Vector3, _p: TkProjectile, reason: String) -> void:
				st.moving = false
				if reason != "range":
					st.node = null
					st.last = ""
					return
				st.node = to
				st.segs = int(st.segs) + 1
				st.speed = float(st.speed) + 6.0
				if st.pending != null and t.alive():
					var next_aim: Vector3 = st.pending
					st.pending = null
					_route(t.refreshed(), web, st, next_aim)})
