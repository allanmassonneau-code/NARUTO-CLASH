extends RefCounted
## Technique kit: clan Hoshigaki (design bible). Signature: Faim — up to 3
## charges ("faim" resource) gained by significant damage on a Trempé target,
## by interrupting a jutsu, or by hitting a target under a chakra threshold
## (0.8 s internal cooldown). Charges expire after 6 s out of combat and are
## spent by the advanced techniques. Trempé is read from any kit's soaked mark
## ("trempe"...); this kit's water sharks apply it too and leave water.

const KIT_ID := &"clan_hoshigaki"
const SIGNATURE = HoshigakiSignature
const TECHNIQUES := {
	&"clan_hoshigaki_d_morsure_du_requin": MorsureDuRequin,
	&"clan_hoshigaki_c_siphon_branchial": SiphonBranchial,
	&"clan_hoshigaki_b_requin_pisteur": RequinPisteur,
	&"clan_hoshigaki_a_frenesie_des_branchies": FrenesieDesBranchies,
	&"clan_hoshigaki_s_grand_requin_devoreur_de_chakra": GrandRequin,
}

const FAIM := "faim"
const SHARK := Color(0.3, 0.55, 0.95)
const MORSURE_ID := &"clan_hoshigaki_d_morsure_du_requin"
const SOAK_KEYS: Array[String] = ["trempe", "trempé", "soaked", "wet", "humide", "humidite"]


## Passive layer: Faim gains on aggressive pressure.
class HoshigakiSignature extends KitSignature:
	var _icd: float = 0.0

	func setup(f: CombatCharacter) -> void:
		f.kit.define_resource(FAIM, 3.0, "Faim", SHARK, 6.0)

	func tick(_f: CombatCharacter, delta: float) -> void:
		_icd = maxf(0.0, _icd - delta)

	func on_deal(f: CombatCharacter, target: CombatCharacter, hit: HitData, damage: float) -> Variant:
		if f.kit.resources.has(FAIM):
			f.kit.resources[FAIM].idle = 0.0  # still in combat: charges don't expire
		if not is_instance_valid(target) or (hit != null and hit.ability != null and hit.ability.source_id == MORSURE_ID):
			return null
		K.watch_interrupt(f, target, func() -> void:
			if _icd <= 0.0:
				_gain(f, target))
		if _icd > 0.0:
			return null
		if (damage >= 8.0 and K.soaked(target)) or K.low_chakra(target):
			_gain(f, target)
		return null

	func _gain(f: CombatCharacter, target: CombatCharacter) -> void:
		if not is_instance_valid(f):
			return
		_icd = 0.8
		K.feed(f, target)


## Shared Hoshigaki rules.
class K:
	static func soaked(e: CombatCharacter) -> bool:
		if e == null or not is_instance_valid(e):
			return false
		for key: String in SOAK_KEYS:
			if e.kit.marks.has(key) or e.kit.modifiers.has(key):
				return true
		return false

	## Chakra-mode fighter under 30 % chakra.
	static func low_chakra(e: CombatCharacter) -> bool:
		return is_instance_valid(e) and e.energy.regen_per_second > 0.0 and e.energy.get_ratio() < 0.3

	## Just spent chakra: in the middle of a technique.
	static func spent_recently(e: CombatCharacter) -> bool:
		return is_instance_valid(e) and e.abilities.is_casting() and e.abilities.current != null \
			and not e.abilities.is_basic_attack(e.abilities.current)

	## Applies Trempé (the Suiton mark key).
	static func soak(t: Tk, e: CombatCharacter, seconds: float = 4.0) -> void:
		t.mark(e, "trempe", 1, seconds, 1, "Trempé")

	static func feed(f: CombatCharacter, target: CombatCharacter) -> void:
		f.kit.add_res(FAIM, 1.0)
		if CombatFx.is_enabled() and is_instance_valid(target):
			CombatFx.damage_number(target, target.global_position + Vector3.UP * 2.6, 0.0, SHARK, "FAIM")

	## Calls `cb` if `target`'s jutsu gets interrupted by the hit being dealt.
	static func watch_interrupt(f: CombatCharacter, target: CombatCharacter, cb: Callable) -> void:
		if not is_instance_valid(target) or not target.abilities.is_casting():
			return
		var a: AbilityData = target.abilities.current
		if a == null or target.abilities.is_basic_attack(a) or target.abilities.phase == AbilityController.Phase.RECOVERY:
			return
		f.kit.after(0.05, func() -> void:
			if is_instance_valid(target) and not target.is_dead() and target.abilities.current != a \
					and not target.status.can_act():
				cb.call())

	## Water left on the ground (a water surface for every kit).
	static func water(t: Tk, at: Vector3, radius: float, lifetime: float) -> KitObject:
		return t.zone(at, radius, lifetime, {"kind": "eau", "color": SHARK, "targetable": false})

	static func water_at(t: Tk, point: Vector3) -> bool:
		for node: Node in t.tree().get_nodes_in_group(&"kit_objects"):
			var o := node as KitObject
			if o == null or not o.is_alive():
				continue
			var k: String = o.kind.to_lower()
			if (k.contains("eau") or k.contains("flaque") or k.contains("water") or k.contains("puddle") or k.contains("mare")) \
					and o.contains(point):
				return true
		return false


## D — Dash court, Mêlée, Ressource. Straight 4.5 m leap that stops on the
## first enemy (no pass-through, not invulnerable) and bites it; a Trempé
## target or one in the middle of a jutsu feeds 1 Faim. A whiff leaves the
## Hoshigaki slowed.
class MorsureDuRequin extends Technique:
	const REACH: float = 4.5

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.08
		a.recovery_time = 0.3
		a.cast_move_multiplier = 1.0
		a.max_range = REACH
		a.anim = &"dash"

	func cast(t: Tk) -> void:
		var target: CombatCharacter = null
		var best: float = INF
		for e: CombatCharacter in t.enemies_in_line(t.origin, t.dir, REACH, 1.2):
			var along: float = HitQuery.flat(e.global_position - t.origin).dot(t.dir)
			if along < best:
				best = along
				target = e
		var dist: float = REACH if target == null else maxf(0.0, best - 1.0)
		var dur: float = maxf(0.06, 0.16 * dist / REACH)
		t.dash(dist, t.dir, dur)
		t.after(dur, func(rt: Tk) -> void:
			_bite(rt, target))

	func _bite(t: Tk, target: CombatCharacter) -> void:
		var e: CombatCharacter = target
		if not t.is_enemy(e) or t.distance(e.global_position, t.origin) > 2.2:
			e = null
			var near: Array[CombatCharacter] = t.enemies_in_cone(t.origin, t.dir, 1.8, 100.0)
			if not near.is_empty():
				e = near[0]
		if e == null:
			t.buff("morsure_ratee", 0.5, {"speed": 0.5})
			return
		var hungry: bool = K.soaked(e) or K.spent_recently(e)
		t.fx("spikes", HitQuery.flat(e.global_position), 0.8, SHARK)
		if t.hit(e, t.dmg(0.7)) == HitData.Result.HIT and hungry:
			K.feed(t.caster, e)


## C — Canalisation courte, Chakra, Duel. 1 s channel on a very short cone:
## small damage and a capped chakra drain (max 16, almost nothing from a
## nearly empty target). With 1 Faim spent at cast, the drained chakra
## becomes a temporary shield instead of chakra for the caster.
class SiphonBranchial extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.15
		a.recovery_time = 0.25
		a.max_range = 2.5
		a.anim = &"palm"

	func cast(t: Tk) -> void:
		var shield_mode: bool = t.spend_res(FAIM, 1.0)
		var st: Dictionary = {"total": 0.0}
		if shield_mode:
			t.text(t.caster, "BRANCHIES", SHARK)
		t.channel(4, 0.25, func(ct: Tk, _i: int) -> void:
			ct.fx("wave", ct.origin + ct.dir * 1.2, 1.0, SHARK)
			for e: CombatCharacter in ct.enemies_in_cone(ct.origin, ct.dir, 2.3, 70.0):
				if ct.hit(e, ct.dmg(0.15)) != HitData.Result.HIT:
					continue
				var amt: float = minf(4.0, e.energy.current_energy * 0.2)
				if e.energy.get_ratio() < 0.2:
					amt *= 0.3
				amt = minf(amt, 16.0 - float(st.total))
				if amt <= 0.0 or not e.energy.consume(amt):
					continue
				st.total = float(st.total) + amt
				if shield_mode:
					ct.shield(ct.caster, amt * 1.5, 4.0)
				else:
					ct.caster.energy.restore(amt),
			Callable(), 0.3)


## B — Invocation projectile, Tracking conditionnel, Faim. A water shark in a
## straight line; crossing a water surface or passing near a Trempé enemy
## lets it correct its course once toward that enemy. Hits soak (Trempé).
## With 1 Faim spent, it splits on impact into two lateral jaws that bite
## after a short telegraph to cover the dodges.
class RequinPisteur extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.25
		a.recovery_time = 0.3
		a.max_range = 14.0
		a.anim = &"throw"

	func cast(t: Tk) -> void:
		var split: bool = t.spend_res(FAIM, 1.0)
		t.projectile({"speed": 15.0, "range": 14.0, "radius": 0.7, "size": 0.4, "color": SHARK, "data": {"corrected": false},
			"on_tick": func(p: TkProjectile, _dt: float) -> void:
				if not is_instance_valid(t.caster):
					return
				if p.data.corrected:
					return
				var pos: Vector3 = p.ground_point()
				var prey: CombatCharacter = null
				if K.water_at(t, pos):
					var best: float = INF
					for e: CombatCharacter in t.enemies_in(pos, 8.0):
						var d: float = t.distance(e.global_position, pos) - (3.0 if K.soaked(e) else 0.0)
						if d < best:
							best = d
							prey = e
				else:
					for e: CombatCharacter in t.enemies_in(pos, 3.0):
						if K.soaked(e):
							prey = e
							break
				if prey != null:
					var to: Vector3 = HitQuery.flat(prey.global_position - pos)
					if to.length() > 0.3:
						p.direction = to.normalized()
						p.data.corrected = true
						t.fx("sparks", pos, 0.6, SHARK),
			"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
				if not is_instance_valid(t.caster):
					return false
				t.hit(e, t.dmg(0.9))
				K.soak(t, e)
				return false,
			"on_end": func(point: Vector3, p: TkProjectile, _reason: String) -> void:
				if not is_instance_valid(t.caster):
					return
				if not split:
					return
				var side: Vector3 = p.direction.cross(Vector3.UP).normalized()
				for s: float in [-1.0, 1.0]:
					var at: Vector3 = point + side * s * 1.8
					t.telegraph(at, 1.1, 0.35, func(rt: Tk) -> void:
						rt.fx("spikes", at, 1.1, SHARK)
						rt.area(at, 1.1, rt.dmg(0.5), {"slow": 1.0}))})


## A — Mode prédateur, Ressource, Anti-fuite. Spends every Faim: 2 s + 2.5 s
## per charge (duration, not damage) of faster glide. Enemy dashes leave
## chakra traces (glyphs, 3 s) at their past positions; hitting an enemy who
## left a fresh trace slows it. Interrupting a jutsu extends the mode once
## (+1.5 s).
class FrenesieDesBranchies extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.recovery_time = 0.2
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var f: CombatCharacter = t.caster
		var n: int = int(t.take_all_res(FAIM))
		var st: Dictionary = {"extended": false, "scan": 0.0}
		t.fx("spheres", t.origin, 1.5, SHARK)
		t.text(f, "FRÉNÉSIE x%d" % n, SHARK)
		t.buff("frenesie", 2.0 + 2.5 * n, {"speed": 1.3, "label": "Frénésie", "color": SHARK,
			"on_tick": func(dt: float) -> void:
				st.scan = float(st.scan) - dt
				if st.scan > 0.0 or not t.alive():
					return
				st.scan = 0.15
				for e: CombatCharacter in t.fighters():
					if t.is_enemy(e) and e.movement.is_forced() and not e.movement.is_knockback and e.movement.forced_speed() > 9.0:
						t.object(e.global_position, {"kind": "trace", "radius": 0.5, "lifetime": 3.0, "look": KitObject.Look.GLYPH,
							"targetable": false, "color": SHARK, "data": {"who": e}}),
			"on_deal": func(target: CombatCharacter, _hit: HitData, dmg: float) -> float:
				if not is_instance_valid(target):
					return dmg
				for tr: KitObject in t.objects("trace"):
					if tr.data.get("who") == target:
						target.status.apply_status(StatusController.Type.SLOW, 0.8)
						break
				if not st.extended:
					K.watch_interrupt(f, target, func() -> void:
						if not st.extended and is_instance_valid(f) and f.kit.has_modifier("frenesie"):
							st.extended = true
							f.kit.modifiers["frenesie"].left += 1.5
							t.text(f, "+FRÉNÉSIE", SHARK))
				return dmg})


## S — Projectile massif, Absorption, Croissance. A huge, slow, piercing water
## shark (contact damage). Small enemy projectiles it meets are swallowed
## (+1 growth); big or ultimate ones are only chewed (+0.5) and keep going.
## Growth widens it and its final explosion. A destructible body (70 HP)
## follows it: breaking it fizzles the shark. Recast: dive early. The
## explosion soaks (Trempé) and leaves water.
class GrandRequin extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.5
		a.recovery_time = 0.35
		a.cast_move_multiplier = 0.3
		a.max_range = 22.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var hull: KitObject = t.object(t.origin, {"kind": "requin_corps", "radius": 1.3, "lifetime": 5.0, "health": 70.0,
			"look": KitObject.Look.NONE, "color": SHARK})
		var shark: TkProjectile = t.projectile({"speed": 6.5, "range": 22.0, "radius": 1.4, "pierce": true, "size": 0.75,
			"color": SHARK, "data": {"gauge": 0.0},
			"on_tick": func(p: TkProjectile, _dt: float) -> void:
				if not is_instance_valid(t.caster):
					return
				if is_instance_valid(hull) and hull.is_alive():
					hull.global_position = p.ground_point()
				_absorb(t, p),
			"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
				if not is_instance_valid(t.caster):
					return false
				t.hit(e, t.dmg(0.5))
				return true,
			"on_end": func(point: Vector3, p: TkProjectile, reason: String) -> void:
				if not is_instance_valid(t.caster):
					return
				if is_instance_valid(hull) and hull.is_alive():
					hull.destroy("expired")
				_explode(t, point, float(p.data.get("gauge", 0.0)), reason == "broken")})
		hull.on_destroy = func(_o: KitObject, reason: String) -> void:
			if not is_instance_valid(t.caster):
				return
			if reason == "destroyed" and is_instance_valid(shark) and shark.is_alive():
				shark.end("broken")
		t.recast(5.0, func(_rt: Tk) -> void:
			if is_instance_valid(shark) and shark.is_alive():
				shark.end("recast"))

	func _absorb(t: Tk, p: TkProjectile) -> void:
		var reach: float = p.hit_radius + 0.4
		var key: String = "chewed_%d" % p.get_instance_id()
		for node: Node in t.tree().get_nodes_in_group(&"projectiles"):
			var ep := node as Projectile
			if ep == null or ep.team == t.caster.team or ep.is_queued_for_deletion() \
					or t.distance(ep.global_position, p.global_position) > reach:
				continue
			var big: bool = ep.ability != null and (ep.ability.energy_cost >= 70.0 or ep.ability.damage >= 30.0)
			if big:
				if not ep.has_meta(key):
					ep.set_meta(key, true)
					_grow(t, p, 0.5)
			else:
				ep.queue_free()
				_grow(t, p, 1.0)
		for node: Node in t.tree().get_nodes_in_group(&"tk_projectiles"):
			var other := node as TkProjectile
			if other == null or other == p or other.team == t.caster.team or not other.is_alive() \
					or t.distance(other.global_position, p.global_position) > reach:
				continue
			var ultimate: bool = String(other.technique_id).contains("_s_")
			if ultimate or other.size >= 0.45:
				if not other.data.has(key):
					other.data[key] = true
					_grow(t, p, 0.5)
			else:
				other.end("blocked")
				_grow(t, p, 1.0)

	func _grow(t: Tk, p: TkProjectile, amount: float) -> void:
		var g: float = float(p.data.get("gauge", 0.0)) + amount
		p.data["gauge"] = g
		p.hit_radius = minf(1.4 + 0.15 * g, 2.6)
		p.size = minf(0.75 + 0.08 * g, 1.4)
		t.fx("implosion", p.ground_point(), p.hit_radius, SHARK)

	func _explode(t: Tk, point: Vector3, gauge: float, broken: bool) -> void:
		if broken:
			t.fx("burst", point, 1.5, SHARK)
			t.area(point, 1.5, t.dmg(0.3))
			return
		var radius: float = minf(2.5 + 0.45 * gauge, 6.0)
		t.fx("explosion", point, radius, SHARK)
		for e: CombatCharacter in t.area(point, radius, t.dmg(minf(1.0 + 0.15 * gauge, 2.0)), {"push": 1.5}):
			K.soak(t, e)
		K.water(t, point, radius * 0.7, 6.0)
