extends RefCounted
## Technique kit: clan Sabaku (design bible). Signature: Réserve de sable —
## a per-fighter gauge ("sable") of sand floating around the fighter. Big
## attacks spend it; defences / structures ENGAGE it (KitObjects carrying
## data.sand lower the gauge's ceiling while they exist). Sand flows back
## progressively, faster when a structure is recalled (instant refund).
## Every sand hit leaves a Grain marqué ("grain" mark) that Main des dunes
## exploits.

const KIT_ID := &"clan_sabaku"
const SIGNATURE = SabakuSignature
const TECHNIQUES := {
	&"clan_sabaku_d_sable_gardien": SableGardien,
	&"clan_sabaku_c_main_des_dunes": MainDesDunes,
	&"clan_sabaku_b_cercueil_de_sable": CercueilDeSable,
	&"clan_sabaku_a_mer_de_sable_mouvante": MerDeSableMouvante,
	&"clan_sabaku_s_mausolee_du_desert": MausoleeDuDesert,
}

const SAND := "sable"
const SAND_MAX: float = 100.0
## Sand flowing back per second (up to the ceiling left by engaged sand).
const SAND_REGEN: float = 7.0
const GRAIN := "grain"
const GRAIN_TIME: float = 6.0
const SAND_COLOR := Color(0.85, 0.72, 0.45)


## Réserve de sable: declared full, regenerates toward its ceiling
## (SAND_MAX minus the sand engaged in live structures).
class SabakuSignature extends KitSignature:
	func setup(f: CombatCharacter) -> void:
		f.kit.define_resource(SAND, SAND_MAX, "Réserve", SAND_COLOR)
		f.kit.add_res(SAND, SAND_MAX)

	func tick(f: CombatCharacter, delta: float) -> void:
		if not f.kit.resources.has(SAND) or not f.is_inside_tree():
			return
		var r: Dictionary = f.kit.resources[SAND]
		var ceiling: float = maxf(0.0, SAND_MAX - K.engaged(f))
		var before: int = int(r.value)
		if r.value > ceiling:
			r.value = ceiling
		elif r.value < ceiling:
			r.value = minf(ceiling, r.value + SAND_REGEN * delta)
		if int(r.value) != before:
			f.kit.changed.emit()


## Shared Sabaku rules.
class K:
	## Sand currently engaged in the fighter's live structures.
	static func engaged(f: CombatCharacter) -> float:
		var total: float = 0.0
		for o: KitObject in KitObject.find(f.get_tree(), f, &"", ""):
			total += float(o.data.get("sand", 0.0))
		return total

	## Spends up to `amount` sand; returns the fraction actually available
	## (techniques scale with it, a dry Sabaku still casts weakly).
	static func take(t: Tk, amount: float) -> float:
		var got: float = minf(t.res(SAND), amount)
		t.add_res(SAND, -got)
		return clampf(got / amount, 0.0, 1.0) if amount > 0.0 else 1.0

	static func grain(t: Tk, e: CombatCharacter) -> void:
		if t.is_enemy(e):
			t.mark(e, GRAIN, 1, GRAIN_TIME, 1, "Grain")

	## Keeps a captured fighter (by instance id) rooted inside its prison.
	static func hold(t: Tk, eid: int) -> void:
		var e := instance_from_id(eid) as CombatCharacter
		if e != null and t.is_enemy(e):
			e.status.apply_status(StatusController.Type.ROOT, 0.15)

	static func release(eid: int) -> void:
		var e := instance_from_id(eid) as CombatCharacter
		if e != null:
			e.status.remove_status(StatusController.Type.ROOT)

	static func has_grain(t: Tk, e: CombatCharacter) -> bool:
		return e != null and t.marks(e, GRAIN) > 0


## D — Interception auto, Ressource, Recast. A sand guard (20 engaged sand)
## orbits the caster for 8 s and auto-blocks frontal projectiles (2 charges,
## 1.5 s internal delay = vulnerable window). Recast: the remaining sand is
## thrown as a directional slap (cone, push, Grain) — the guard is gone.
class SableGardien extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.1
		a.recovery_time = 0.15
		a.max_range = 4.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		for old: KitObject in t.objects("gardien"):
			old.destroy("replaced")
		var ratio: float = K.take(t, 20.0)
		var charges: int = 2 if ratio >= 0.5 else 1
		var guard: KitObject = t.object(t.origin, {"kind": "gardien", "radius": 1.6, "lifetime": 8.0, "look": KitObject.Look.RING,
			"targetable": false, "color": SAND_COLOR,
			"data": {"sand": 20.0 * ratio, "charges": charges, "ready_at": 0.0},
			"on_tick": func(o: KitObject) -> void:
				if t.alive():
					o.global_position = HitQuery.flat(t.caster.global_position),
			"on_projectile": func(_team: int, point: Vector3) -> bool:
				return _intercept(t, point)})
		t.fx("dust", t.origin, 1.6, SAND_COLOR)
		t.recast(8.0, func(rt: Tk) -> void:
			if not guard.is_alive():
				return
			var n: int = int(guard.data.get("charges", 0))
			guard.destroy("slap")
			rt.fx("wave", rt.origin + rt.dir * 2.0, 2.0, SAND_COLOR)
			for e: CombatCharacter in rt.cone(4.0, 70.0, rt.dmg(0.3 + 0.25 * n), {"push": 2.5}):
				K.grain(rt, e))

	## Frontal arc only, one block per internal delay, costs a charge.
	func _intercept(t: Tk, point: Vector3) -> bool:
		if not t.alive():
			return false
		var guard: KitObject = null
		for g: KitObject in t.objects("gardien"):
			guard = g
		if guard == null or int(guard.data.charges) <= 0 or guard.age < float(guard.data.ready_at):
			return false
		var to: Vector3 = HitQuery.flat(point - t.caster.global_position)
		if to.length() > 0.05 and t.caster.facing.facing_direction.dot(to.normalized()) < 0.25:
			return false
		guard.data.charges = int(guard.data.charges) - 1
		guard.data.sand = maxf(0.0, float(guard.data.sand) - 10.0)
		guard.data.ready_at = guard.age + 1.5
		t.fx("dust", point, 0.9, SAND_COLOR)
		if int(guard.data.charges) <= 0:
			guard.destroy("spent")
		return true


## C — Bras dirigé, Grab conditionnel, Reposition. A visible, destructible
## sand hand forms on the ground then crawls to the aim; on contact it grabs
## (light damage, brief root) and drags the target 3 m toward the caster —
## or toward a closing Cercueil. Forms much faster against a Grain target.
class MainDesDunes extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.recovery_time = 0.2
		a.max_range = 10.0
		a.anim = &"palm"

	func cast(t: Tk) -> void:
		K.take(t, 10.0)
		var target: CombatCharacter = t.target_at_aim(3.0)
		var form: float = 0.12 if K.has_grain(t, target) else 0.45
		var goal: Vector3 = t.aim
		var start: Vector3 = t.clear_point(t.origin, t.dir, 1.0)
		t.object(start, {"kind": "main", "radius": 0.9, "lifetime": form + 1.6, "health": 18.0, "look": KitObject.Look.ORB,
			"color": SAND_COLOR, "data": {"form": form},
			"on_tick": func(o: KitObject) -> void:
				if o.age < float(o.data.form):
					return
				var victim: CombatCharacter = t.nearest_enemy(o.global_position, 0.6)
				if victim != null:
					_grab(t.refreshed(), victim, o)
					return
				var to: Vector3 = HitQuery.flat(goal - o.global_position)
				if to.length() > 0.1:
					_crawl(t, o, to.normalized(), minf(11.0 * o.get_physics_process_delta_time(), to.length()))})

	## Crawls along the ground; slips around a low obstacle (±35°) if blocked.
	func _crawl(t: Tk, hand: KitObject, d: Vector3, step: float) -> void:
		var from: Vector3 = hand.global_position + Vector3.UP * 0.5
		for angle: float in [0.0, 35.0, -35.0]:
			var dd: Vector3 = d.rotated(Vector3.UP, deg_to_rad(angle))
			if HitQuery.raycast_world(t.caster.get_world_3d(), from, from + dd * (step + 0.3)).is_empty():
				hand.global_position = HitQuery.flat(hand.global_position + dd * step)
				return

	func _grab(t: Tk, e: CombatCharacter, hand: KitObject) -> void:
		var at: Vector3 = hand.global_position
		hand.destroy("grabbed")
		t.fx("dust", at, 1.0, SAND_COLOR)
		if t.hit(e, t.dmg(0.45), {"root": 0.25}) != HitData.Result.HIT:
			return
		K.grain(t, e)
		var dest: Vector3 = t.caster.global_position
		for z: KitObject in t.objects("fermeture", &"clan_sabaku_b_cercueil_de_sable"):
			if t.distance(z.global_position, e.global_position) <= 8.0:
				dest = z.global_position
		t.pull(e, dest, 3.0)


## B — Capture progressive, Ressource engagée, Exécution. Sends 25 sand
## around a target: a visible pre-zone closes for 0.9 s (dashable); whoever
## stays inside is locked in a destructible cocoon (stun 0.8 then rooted,
## 25 more sand engaged while it lasts). Recast: crush the cocoon (burst,
## refund) — or, before it closes, crush the pre-zone (lighter, no capture).
class CercueilDeSable extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.recovery_time = 0.25
		a.max_range = 9.0
		a.anim = &"palm"

	func cast(t: Tk) -> void:
		var ratio: float = K.take(t, 25.0)
		var target: CombatCharacter = t.target_at_aim(3.0)
		var center: Vector3 = HitQuery.flat(target.global_position) if target != null else t.aim
		var tid: int = target.get_instance_id() if target != null else 0
		var r0: float = 1.8 + 0.6 * ratio
		t.fx("dust", center, r0, SAND_COLOR)
		t.object(center, {"kind": "fermeture", "radius": r0, "lifetime": 0.9, "look": KitObject.Look.RING, "targetable": false,
			"color": SAND_COLOR, "data": {"sand": 10.0},
			"on_tick": func(o: KitObject) -> void:
				o.radius = lerpf(r0, 1.2, clampf(o.age / 0.9, 0.0, 1.0)),
			"on_expire": func(o: KitObject) -> void:
				_close(t.refreshed(), o, instance_from_id(tid) as CombatCharacter if tid != 0 else null)})
		t.recast(3.4, func(rt: Tk) -> void:
			for c: KitObject in rt.objects("cocon"):
				_crush(rt, c)
				return
			for z: KitObject in rt.objects("fermeture"):
				rt.fx("implosion", z.global_position, z.radius, SAND_COLOR)
				for e: CombatCharacter in rt.area(z.global_position, z.radius, rt.dmg(0.6)):
					K.grain(rt, e)
				z.destroy("crushed"))

	func _close(t: Tk, zone: KitObject, preferred: CombatCharacter) -> void:
		var inside: Array[CombatCharacter] = t.enemies_in(zone.global_position, zone.radius)
		if inside.is_empty():
			t.fx("dust", zone.global_position, zone.radius, SAND_COLOR)
			return
		var e: CombatCharacter = preferred if inside.has(preferred) else inside[0]
		t.fx("implosion", e.global_position, 1.2, SAND_COLOR)
		if t.hit(e, t.dmg(0.25), {"stun": 0.8}) != HitData.Result.HIT:
			return
		K.grain(t, e)
		K.take(t, 25.0)
		var eid: int = e.get_instance_id()
		t.object(e.global_position, {"kind": "cocon", "radius": 1.0, "lifetime": 2.2, "health": 35.0, "look": KitObject.Look.PILLAR,
			"color": SAND_COLOR, "data": {"sand": 25.0, "target_id": eid},
			"on_tick": func(_o: KitObject) -> void:
				K.hold(t, eid),
			"on_destroy": func(_o: KitObject, reason: String) -> void:
				if reason != "expired":
					K.release(eid)})

	func _crush(t: Tk, cocoon: KitObject) -> void:
		var raw: Variant = instance_from_id(int(cocoon.data.get("target_id", 0)))
		var at: Vector3 = cocoon.global_position
		cocoon.destroy("crushed")
		t.fx("implosion", at, 1.6, SAND_COLOR)
		t.add_res(SAND, 15.0)  # recalled structure: sand comes back faster
		if is_instance_valid(raw) and t.is_enemy(raw as CombatCharacter):
			var e := raw as CombatCharacter
			t.hit(e, t.dmg(1.1), {"unblockable": true})
			K.grain(t, e)


## A — Terrain mobile, Ressource, Surf. A large sand sea (25 sand engaged)
## drifts slowly along the cast direction and drags everyone inside with it
## (no slow, no CC). The caster surfs it (+50 % speed). Enemies running
## against the current get a Grain. Recast (repeatable): recall the sand
## behind the caster — the sea shrinks and shifts ahead, sand refunded.
class MerDeSableMouvante extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.35
		a.recovery_time = 0.25
		a.max_range = 9.0
		a.anim = &"stomp"

	func cast(t: Tk) -> void:
		var ratio: float = K.take(t, 20.0)
		var flow: Vector3 = t.dir
		t.fx("dust", t.aim, 5.0, SAND_COLOR)
		var sea: KitObject = t.zone(t.aim, 3.5 + 1.5 * ratio, 9.0, {"kind": "mer", "targetable": false, "color": SAND_COLOR,
			"data": {"sand": 25.0},
			"on_tick": func(o: KitObject) -> void:
				if not t.alive():
					return
				var caster: CombatCharacter = t.caster
				var dt: float = o.get_physics_process_delta_time()
				o.global_position += flow * 1.2 * dt
				for f: CombatCharacter in o.inside:
					if not is_instance_valid(f) or f.is_dead():
						continue
					if f == caster:
						t.buff("surf", 0.2, {"speed": 1.5, "label": "Surf", "color": SAND_COLOR})
						continue
					if f.team == caster.team:
						continue
					f.move_and_collide(flow * 1.1 * dt)
					if f.velocity.dot(flow) < -3.0 and t.marks(f, GRAIN) <= 0:
						K.grain(t, f)})
		t.recast(9.0, _recall.bind(sea))

	func _recall(t: Tk, sea: KitObject) -> void:
		if not sea.is_alive() or sea.radius <= 2.0:
			return
		var old_r: float = sea.radius
		sea.radius = maxf(2.0, old_r * 0.7)
		sea.global_position += t.dir * (old_r - sea.radius)
		var back: float = minf(10.0, float(sea.data.sand))
		sea.data.sand = float(sea.data.sand) - back
		t.add_res(SAND, back + 6.0)
		t.fx("dust", t.origin, 1.5, SAND_COLOR)
		if sea.radius > 2.0 and sea.lifetime - sea.age > 0.3:
			t.recast(sea.lifetime - sea.age, _recall.bind(sea))


## S — Construction massive, Multi-capture, Ressource. The whole Réserve
## becomes four pillars around the aim (they hold the sand). Each recast
## commands the next pillar to sweep through the centre (telegraphed line,
## compression pull). Two different sweeps on a target = Sceau
## d'ensevelissement; a third = individual sarcophagus (stun 0.8, rooted,
## destructible). Spent pillars vanish and their sand flows back slowly.
class MausoleeDuDesert extends Technique:
	const RADIUS: float = 4.5

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.5
		a.recovery_time = 0.3
		a.cast_move_multiplier = 0.2
		a.max_range = 10.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		for old: KitObject in t.objects("pilier"):
			old.destroy("replaced")
		var sand: float = t.take_all_res(SAND)
		var state := {"center": t.aim, "power": 0.6 + 0.4 * sand / SAND_MAX, "hits": {}}
		t.fx("rocks", t.aim, RADIUS, SAND_COLOR)
		for i in 4:
			var d: Vector3 = t.dir.rotated(Vector3.UP, deg_to_rad(90.0 * i))
			t.object(t.aim + d * RADIUS, {"kind": "pilier", "radius": 0.8, "lifetime": 12.0, "health": 40.0,
				"look": KitObject.Look.PILLAR, "color": SAND_COLOR, "data": {"sand": sand * 0.25, "idx": i}})
		t.recast(6.0, _sweep_next.bind(state))

	func _sweep_next(t: Tk, state: Dictionary) -> void:
		var pillars: Array[KitObject] = t.objects("pilier")
		if pillars.is_empty():
			return
		var next: KitObject = pillars[0]
		for p: KitObject in pillars:
			if int(p.data.idx) < int(next.data.idx):
				next = p
		var from: Vector3 = next.global_position
		var center: Vector3 = state.center
		var d: Vector3 = HitQuery.flat(center - from).normalized()
		var idx: int = int(next.data.idx)
		next.destroy("spent")
		t.fx("dust", from, 1.2, SAND_COLOR)
		t.telegraph(center, 1.2, 0.35, func(st: Tk) -> void:
			for k in 3:
				st.fx("dust", from + d * RADIUS * (0.5 + 0.5 * k), 1.2, SAND_COLOR)
			for e: CombatCharacter in st.enemies_in_line(from, d, RADIUS * 2.0, 2.4):
				_sweep_hit(st, e, idx, state))
		if pillars.size() > 1:
			t.recast(6.0, _sweep_next.bind(state))

	func _sweep_hit(t: Tk, e: CombatCharacter, idx: int, state: Dictionary) -> void:
		if t.hit(e, t.dmg(0.45 * float(state.power))) != HitData.Result.HIT:
			return
		K.grain(t, e)
		t.pull(e, state.center, 1.5)
		var key: int = e.get_instance_id()
		var seen: Array = state.hits.get(key, [])
		if not seen.has(idx):
			seen.append(idx)
		state.hits[key] = seen
		if seen.size() == 2:
			t.mark(e, "sceau_ensevelissement", 1, 8.0, 1, "Sceau d'ensevelissement")
			t.text(e, "SCEAU")
		elif seen.size() >= 3 and t.consume_mark(e, "sceau_ensevelissement") > 0:
			t.fx("implosion", e.global_position, 1.3, SAND_COLOR)
			t.hit(e, t.dmg(0.4 * float(state.power)), {"stun": 0.8})
			var eid: int = e.get_instance_id()
			t.object(e.global_position, {"kind": "sarcophage", "radius": 1.0, "lifetime": 1.4, "health": 30.0,
				"look": KitObject.Look.PILLAR, "color": SAND_COLOR,
				"on_tick": func(_o: KitObject) -> void:
					K.hold(t, eid),
				"on_destroy": func(_o: KitObject, _reason: String) -> void:
					K.release(eid)})
