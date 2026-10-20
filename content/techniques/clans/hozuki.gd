extends RefCounted
## Technique kit: clan Hôzuki (design bible). Signature: Hydratation — a
## 0..100 gauge ("hydratation" resource, full at the start of each round).
## Liquid forms spend it, water surfaces (any "eau" / "flaque" / "water"
## object, including the puddles this kit leaves) and Suiton hits restore it.
## Below LOW the techniques lose their liquid variants (no full charge, no
## inflated arm, short puddle form).

const KIT_ID := &"clan_hozuki"
const SIGNATURE = HozukiSignature
const TECHNIQUES := {
	&"clan_hozuki_d_corps_fluide": CorpsFluide,
	&"clan_hozuki_c_pistolet_a_eau": PistoletAEau,
	&"clan_hozuki_b_flaque_vivante": FlaqueVivante,
	&"clan_hozuki_a_bras_hydraulique": BrasHydraulique,
	&"clan_hozuki_s_demon_d_eau_corps_torrentiel": DemonDEau,
}

const HYD := "hydratation"
const HYD_MAX: float = 100.0
const LOW: float = 20.0
const WATER := Color(0.35, 0.7, 1.0)


## Passive layer: keeps the gauge, refills it after a round reset, restores
## it on water surfaces and when dealing Suiton damage.
class HozukiSignature extends KitSignature:
	func setup(f: CombatCharacter) -> void:
		f.kit.define_resource(HYD, HYD_MAX, "Hydratation", WATER, 0.0)
		K.add(f, HYD_MAX)

	func tick(f: CombatCharacter, delta: float) -> void:
		var r: Dictionary = f.kit.resources.get(HYD, {})
		if r.is_empty():
			return
		# Changed behind the kit's back = KitState.reset() of a new round: refill.
		if absf(float(r.value) - float(r.get("last_set", -1.0))) > 0.01:
			if float(r.value) <= 0.0:
				K.add(f, HYD_MAX)
			else:
				r["last_set"] = r.value
		if float(r.value) < HYD_MAX and K.water_at(f, f.global_position):
			K.add(f, 14.0 * delta)

	func on_deal(f: CombatCharacter, _target: CombatCharacter, hit: HitData, _damage: float) -> Variant:
		if hit != null and hit.ability != null and String(hit.ability.source_id).begins_with("suiton"):
			K.add(f, 5.0)
		return null


## Shared Hôzuki rules.
class K:
	static func hyd(f: CombatCharacter) -> float:
		return f.kit.res(HYD) if is_instance_valid(f) else 0.0

	static func low(f: CombatCharacter) -> bool:
		return hyd(f) < LOW

	## Every change goes through here so the signature can tell a reset apart.
	static func add(f: CombatCharacter, amount: float) -> float:
		if not is_instance_valid(f) or not f.kit.resources.has(HYD):
			return 0.0
		var v: float = f.kit.add_res(HYD, amount)
		f.kit.resources[HYD]["last_set"] = v
		return v

	## Spends up to `amount`; returns what was actually paid.
	static func spend(f: CombatCharacter, amount: float) -> float:
		var paid: float = minf(maxf(amount, 0.0), hyd(f))
		if paid > 0.0:
			add(f, -paid)
		return paid

	## Any water surface (this kit's puddles, Suiton zones of any fighter).
	static func water_at(f: CombatCharacter, point: Vector3) -> bool:
		if not is_instance_valid(f) or not f.is_inside_tree():
			return false
		for node: Node in f.get_tree().get_nodes_in_group(&"kit_objects"):
			var o := node as KitObject
			if o == null or not o.is_alive():
				continue
			var k: String = o.kind.to_lower()
			if (k.contains("eau") or k.contains("flaque") or k.contains("water") or k.contains("puddle") or k.contains("mare")) \
					and o.contains(point):
				return true
		return false

	## Water left on the ground (a water surface for every kit).
	static func puddle(t: Tk, at: Vector3, radius: float, lifetime: float) -> KitObject:
		return t.zone(at, radius, lifetime, {"kind": "eau", "color": WATER, "targetable": false})

	static func is_electric(hit: HitData) -> bool:
		if hit == null or hit.ability == null:
			return false
		var sid: String = String(hit.ability.source_id).to_lower()
		var dn: String = hit.ability.display_name.to_lower()
		return sid.contains("raiton") or sid.contains("chidori") or dn.contains("raiton") or dn.contains("chidori") \
			or dn.contains("foudre") or dn.contains("éclair")

	static func is_area(hit: HitData) -> bool:
		if hit == null or hit.ability == null:
			return false
		var a: AbilityData = hit.ability
		if a.kind == AbilityData.Kind.GROUND_AREA:
			return true
		return a.technique != null and a.technique.jutsu != null and a.technique.jutsu.tags.has(&"AOE")

	## Ends a buff / mode safely (never while the modifiers are iterated).
	static func end_mod(f: CombatCharacter, key: String) -> void:
		if is_instance_valid(f):
			f.kit.after(0.0, func() -> void:
				if is_instance_valid(f):
					f.kit.remove_modifier(key))


## D — Parade, Ressource, Esquive partielle. 0.5 s liquid torso: the first
## direct physical hit loses 75 % of its damage, paid in Hydratation
## (proportional), and splashes a small puddle that slows nearby enemies.
## Electric hits cost extra and deal +25 %; area hits pass through. A wasted
## window costs 4 Hydratation. Dry (< 8): weaker and shorter.
class CorpsFluide extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.02
		a.recovery_time = 0.15
		a.cast_move_multiplier = 1.0
		a.max_range = 2.0
		a.anim = &"guard"

	func cast(t: Tk) -> void:
		var f: CombatCharacter = t.caster
		var dry: bool = K.hyd(f) < 8.0
		var st: Dictionary = {"used": false}
		t.fx("spheres", t.origin, 1.0, WATER)
		t.buff("corps_fluide", 0.3 if dry else 0.5, {"label": "Corps fluide", "color": WATER,
			"on_take": func(hit: HitData, dmg: float) -> float:
				if st.used or dmg <= 0.0:
					return dmg
				if K.is_electric(hit):
					st.used = true
					K.spend(f, 12.0)
					t.text(f, "COURT-CIRCUIT")
					return dmg * 1.25
				if K.is_area(hit):
					K.spend(f, minf(dmg * 0.3, 8.0))
					return dmg
				st.used = true
				var absorbed: float = dmg * (0.4 if dry else 0.75)
				var cost: float = clampf(absorbed * 0.9, 5.0, 30.0)
				var paid: float = K.spend(f, cost)
				if not dry:
					absorbed *= clampf(paid / cost, 0.3, 1.0)
				_splash(t, f)
				return dmg - absorbed,
			"on_end": func() -> void:
				if not st.used:
					K.spend(f, 4.0)})

	func _splash(t: Tk, f: CombatCharacter) -> void:
		if not is_instance_valid(f):
			return
		var at: Vector3 = HitQuery.flat(f.global_position)
		t.fx("spheres", at, 1.6, WATER)
		t.text(f, "FLUIDE", WATER)
		K.puddle(t, at, 1.5, 4.0)
		for e: CombatCharacter in t.enemies_in(at, 1.8):
			t.status(e, StatusController.Type.SLOW, 0.6)


## C — Hitscan chargé, Ressource, Recul. Press to start charging (caster
## slowed), press again to fire; fires by itself at full charge (0.8 s).
## Instant thin shot on the first enemy in line: damage grows with charge.
## Full charge: short stun and recoil slide, a real 4.5 m dash on a water
## surface; costs up to 12 Hydratation. Low Hydratation caps the charge.
class PistoletAEau extends Technique:
	const CHARGE: float = 0.8
	const RANGE: float = 14.0

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.08
		a.recovery_time = 0.2
		a.cast_move_multiplier = 0.6
		a.max_range = RANGE
		a.anim = &"throw"

	func cast(t: Tk) -> void:
		var cap: float = 0.5 if K.low(t.caster) else 1.0
		var st: Dictionary = {"c": 0.0, "fired": false}
		t.fx("ring", t.origin, 0.8, WATER)
		t.buff("pistolet_charge", CHARGE + 0.2, {"speed": 0.6, "label": "Charge", "color": WATER,
			"on_tick": func(dt: float) -> void:
				st.c = minf(float(st.c) + dt / CHARGE, cap)})
		t.recast(CHARGE, func(rt: Tk) -> void:
			_fire(rt, st),
			func() -> void:
				if t.alive():
					_fire(t.refreshed(), st))

	func _fire(t: Tk, st: Dictionary) -> void:
		if st.fired:
			return
		st.fired = true
		t.kit().remove_modifier("pistolet_charge")
		var c: float = float(st.c)
		var full: bool = c >= 0.95
		K.spend(t.caster, 4.0 + 8.0 * c)
		var end: Vector3 = t.clear_point(t.origin, t.dir, RANGE)
		var length: float = t.distance(t.origin, end)
		var target: CombatCharacter = null
		var best: float = INF
		for e: CombatCharacter in t.enemies_in_line(t.origin, t.dir, length, 0.35):
			var along: float = HitQuery.flat(e.global_position - t.origin).dot(t.dir)
			if along < best:
				best = along
				target = e
		var impact: Vector3 = end if target == null else HitQuery.flat(target.global_position)
		t.fx("bolt", impact, 0.5 + 0.5 * c, WATER)
		t.fx("burst", t.origin + t.dir * 0.8, 0.4, WATER)
		if target != null:
			var opts: Dictionary = {}
			if full:
				opts = {"stun": 0.3, "push": 1.5}
			t.hit(target, t.dmg(0.45 + 0.75 * c), opts)
		if full:
			if K.water_at(t.caster, t.origin):
				t.dash(4.5, -t.dir, 0.2)
				t.fx("wave", t.origin, 1.2, WATER)
			else:
				t.dash(1.2, -t.dir, 0.15)


## B — Transformation, Mobilité au sol, Ambush. Becomes a visible puddle for
## 3.5 s: fast slide, passes through fighters, cannot attack (silenced, no
## damage dealt), direct hits halved. Drains Hydratation (less over water);
## electric hits deal +50 % and force the exit. Recast (or end / dry): the
## body reforms with a pushing splash, then a short reform root.
class FlaqueVivante extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.1
		a.recovery_time = 0.1
		a.cast_move_multiplier = 1.0
		a.max_range = 6.0
		a.anim = &"dash"

	func cast(t: Tk) -> void:
		var f: CombatCharacter = t.caster
		var dry: bool = K.hyd(f) < 10.0
		var duration: float = 1.2 if dry else 3.5
		var st: Dictionary = {"done": false}
		t.fx("spheres", t.origin, 1.2, WATER)
		var body: KitObject = t.object(t.origin, {"kind": "corps_liquide", "radius": 0.9, "lifetime": duration + 0.3,
			"targetable": false, "color": WATER, "on_tick": func(o: KitObject) -> void:
				if is_instance_valid(f):
					o.global_position = HitQuery.flat(f.global_position)})
		st["body"] = body
		t.buff("flaque", duration, {"speed": 1.6, "damage_dealt": 0.0, "label": "Flaque", "color": WATER,
			"on_tick": func(dt: float) -> void:
				if st.done or not is_instance_valid(f):
					return
				f.status.apply_status(StatusController.Type.SILENCE, 0.15)
				f.set_pass_through(true)
				var drain: float = 7.0 * dt * (0.4 if K.water_at(f, f.global_position) else 1.0)
				if not dry and K.spend(f, drain) < drain * 0.5:
					K.end_mod(f, "flaque"),
			"on_take": func(hit: HitData, dmg: float) -> float:
				if K.is_electric(hit):
					K.end_mod(f, "flaque")
					return dmg * 1.5
				if K.is_area(hit):
					return dmg
				return dmg * 0.5,
			"on_end": func() -> void:
				if t.alive():
					_reform(t.refreshed(), st)})
		t.recast(duration, func(rt: Tk) -> void:
			rt.kit().remove_modifier("flaque"))

	func _reform(t: Tk, st: Dictionary) -> void:
		if st.done:
			return
		st.done = true
		t.kit().close_recast(t.id)
		t.caster.set_pass_through(false)
		var body: KitObject = st.get("body")
		if is_instance_valid(body) and body.is_alive():
			body.destroy("reformed")
		t.fx("spheres", t.origin, 2.0, WATER)
		t.area(t.origin, 2.0, t.dmg(0.3), {"push": 2.5})
		t.status(t.caster, StatusController.Type.ROOT, 0.25)


## A — Mêlée chargée, Masse variable, Recast. Press to inflate the arm (up to
## 40 Hydratation over 0.9 s, caster slowed), press again to strike (auto at
## full). More water = wider, longer, stronger but slower wind-up and heavy
## recovery. A miss with >= 10 water invested opens a recast: the arm expels
## its water in a pushing jet that leaves a puddle. Dry: small fast jab.
class BrasHydraulique extends Technique:
	const INFLATE: float = 0.9
	const MAX_WATER: float = 40.0

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.1
		a.recovery_time = 0.3
		a.cast_move_multiplier = 0.7
		a.max_range = 3.5
		a.anim = &"hook"

	func cast(t: Tk) -> void:
		var f: CombatCharacter = t.caster
		var st: Dictionary = {"inv": 0.0, "done": false}
		if K.hyd(f) < 10.0:
			_strike(t, st)
			return
		t.fx("spheres", t.origin + t.dir * 0.6, 0.6, WATER)
		t.buff("bras_gonfle", INFLATE + 0.2, {"speed": 0.75, "label": "Bras", "color": WATER,
			"on_tick": func(dt: float) -> void:
				if st.done:
					return
				var want: float = minf(MAX_WATER * dt / INFLATE, MAX_WATER - float(st.inv))
				st.inv = float(st.inv) + K.spend(f, want)})
		t.recast(INFLATE, func(rt: Tk) -> void:
			_strike(rt, st),
			func() -> void:
				if t.alive():
					_strike(t.refreshed(), st))

	func _strike(t: Tk, st: Dictionary) -> void:
		if st.done:
			return
		st.done = true
		t.kit().remove_modifier("bras_gonfle")
		var inv: float = float(st.inv)
		var heavy: float = inv / MAX_WATER
		t.fx("ring", t.origin + t.dir * 1.2, 0.8 + 1.2 * heavy, WATER)
		t.after(0.08 + 0.3 * heavy, func(rt: Tk) -> void:
			var opts: Dictionary = {"push": 1.0 + 2.5 * heavy}
			if heavy > 0.6:
				opts["stun"] = 0.35
			var hits: Array[CombatCharacter] = rt.cone(2.2 + 1.6 * heavy, 70.0 + 60.0 * heavy, rt.dmg(0.7 + 0.7 * heavy), opts)
			rt.fx("spheres", rt.origin + rt.dir * (1.5 + heavy), 1.0 + heavy, WATER)
			if heavy > 0.5:
				rt.buff("bras_recuperation", 0.6, {"speed": 0.45})
			if hits.is_empty() and inv >= 10.0:
				rt.recast(1.5, func(jt: Tk) -> void:
					_jet(jt, inv)))

	func _jet(t: Tk, inv: float) -> void:
		var length: float = 5.0 + inv * 0.1
		t.fx("wave", t.origin + t.dir * length * 0.5, length * 0.5, WATER)
		t.line(length, 1.8, t.dmg(0.4), {"push": 3.5})
		K.puddle(t, t.clear_point(t.origin, t.dir, length), 1.6, 5.0)


## S — Transformation, Morphologie, Ressource. Giant water body: the mode
## lasts as long as Hydratation (7/s, max 12 s): long strides, tenacity,
## -25 % damage but every hit drains extra water (double for Raiton, which
## also deals more). Basic hits send short pushing waves. Water surfaces
## refill it. Recast: all remaining water in one huge pressure jet scaling
## with the volume, ending the mode.
class DemonDEau extends Technique:
	const MAX_TIME: float = 12.0

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.45
		a.recovery_time = 0.3
		a.max_range = 16.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var f: CombatCharacter = t.caster
		var st: Dictionary = {"wave_cd": 0.0, "done": false}
		t.fx("column", t.origin, 2.0, WATER)
		t.fx("spheres", t.origin, 3.0, WATER)
		t.buff("demon_eau", MAX_TIME, {"speed": 1.35, "tenacity": true, "damage_taken": 0.75, "basic_damage": 1.25,
			"label": "Démon d'eau", "color": WATER,
			"on_tick": func(dt: float) -> void:
				st.wave_cd = float(st.wave_cd) - dt
				if not is_instance_valid(f):
					return
				K.spend(f, 7.0 * dt)
				if K.water_at(f, f.global_position):
					K.add(f, 16.0 * dt)
				if K.hyd(f) <= 0.01:
					K.end_mod(f, "demon_eau"),
			"on_take": func(hit: HitData, dmg: float) -> float:
				var electric: bool = K.is_electric(hit)
				K.spend(f, dmg * 0.6 * (2.0 if electric else 1.0))
				return dmg * (1.6 if electric else 1.0),
			"on_deal": func(target: CombatCharacter, hit: HitData, dmg: float) -> float:
				if hit != null and hit.ability != null and is_instance_valid(f) and f.abilities.is_basic_attack(hit.ability) \
						and float(st.wave_cd) <= 0.0 and is_instance_valid(target):
					st.wave_cd = 0.5
					var rt: Tk = t.refreshed()
					var d: Vector3 = HitQuery.flat(target.global_position - rt.origin).normalized()
					if d.length() < 0.5:
						d = rt.dir
					rt.fx("wave", rt.origin + d * 2.0, 1.8, WATER)
					rt.cone(4.0, 80.0, rt.dmg(0.3), {"push": 2.0}, rt.origin, d)
				return dmg,
			"on_end": func() -> void:
				_finish(t, st)})
		t.recast(MAX_TIME, func(rt: Tk) -> void:
			_jet(rt, st))

	func _jet(t: Tk, st: Dictionary) -> void:
		if st.done:
			return
		st.done = true
		var volume: float = K.spend(t.caster, K.hyd(t.caster))
		t.kit().remove_modifier("demon_eau")
		var length: float = 16.0
		t.fx("wave", t.origin + t.dir * 3.0, 2.5, WATER)
		t.fx("column", t.clear_point(t.origin, t.dir, length), 1.5, WATER)
		t.line(length, 1.8, t.dmg(0.6 + 1.4 * volume / HYD_MAX), {"push": 4.0})
		K.puddle(t, t.clear_point(t.origin, t.dir, length * 0.5), 2.0, 5.0)

	func _finish(t: Tk, st: Dictionary) -> void:
		if st.done:
			return
		st.done = true
		if is_instance_valid(t.caster):
			t.kit().close_recast(t.id)
			t.fx("spheres", HitQuery.flat(t.caster.global_position), 2.0, WATER)
