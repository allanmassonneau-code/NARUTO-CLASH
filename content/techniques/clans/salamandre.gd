extends RefCounted
## Technique kit: Clan Salamandre (design bible). Signature: Contamination —
## toxic ground zones ("toxique" objects) carry a Toxicité level 1..3.
## Overlapping contaminations raise the level of the existing zone instead of
## stacking damage. Enemies standing inside accumulate Poison stacks
## (progressive damage); leaving stops the accumulation and the stacks fade.
## Clan techniques consume Toxicité (Miasme dormant) or make level-3 zones
## Suffocantes (Souffle d'Ibuse: long mudras are slowed).

const KIT_ID := &"clan_salamandre"
const SIGNATURE = null
const TECHNIQUES := {
	&"clan_salamandre_d_crachat_alcalin": CrachatAlcalin,
	&"clan_salamandre_c_salamandre_fouisseuse": SalamandreFouisseuse,
	&"clan_salamandre_b_miasme_dormant": MiasmeDormant,
	&"clan_salamandre_a_peau_venimeuse": PeauVenimeuse,
	&"clan_salamandre_s_grande_salamandre_souffle_d_ibuse": SouffleDIbuse,
}

const TOXIC := "toxique"
const POISON := "poison"
const POISON_TIME: float = 2.5
const POISON_MAX: int = 9
const MUCUS := Color(0.55, 0.85, 0.25)


## Shared Salamandre rules (Contamination / Toxicité / Poison).
class K:
	static func level_color(level: int) -> Color:
		match clampi(level, 1, 3):
			1:
				return Color(0.55, 0.8, 0.3, 0.8)
			2:
				return Color(0.45, 0.7, 0.15, 0.9)
		return Color(0.5, 0.25, 0.6, 1.0)

	## Toxic damage does not scale with the rank of the technique that made
	## the zone (an S-rank cloud is bigger, not deadlier per tick).
	static func tox_dmg(t: Tk, mult: float) -> float:
		return t.dmg(mult) * Tk.RANK_DAMAGE[1] / Tk.RANK_DAMAGE[clampi(t.rank, 0, 4)]

	## Contaminates a spot: raises the Toxicité of an overlapping zone of the
	## caster (any clan technique) or creates a new zone.
	static func contaminate(t: Tk, at: Vector3, radius: float, levels: int = 1, life: float = 8.0) -> KitObject:
		for z: KitObject in t.objects(TOXIC, &""):
			if t.distance(z.global_position, at) <= maxf(z.radius, radius) * 0.75:
				raise(t, z, levels)
				z.radius = maxf(z.radius, radius)
				z.lifetime = maxf(z.lifetime, z.age + life)
				return z
		var lvl: int = clampi(levels, 1, 3)
		return t.zone(at, radius, life, {"kind": TOXIC, "tick_interval": 0.5, "targetable": false,
			"color": level_color(lvl), "data": {"level": lvl, "suffocant_until": -1.0},
			"on_tick": func(o: KitObject) -> void:
				zone_tick(t, o)})

	static func raise(t: Tk, z: KitObject, levels: int) -> void:
		var lvl: int = mini(int(z.data.get("level", 1)) + levels, 3)
		z.data["level"] = lvl
		z.color = level_color(lvl)
		t.fx("spheres", z.global_position, z.radius, level_color(lvl))

	## Enemies inside gain Poison (one stack per level) and take damage
	## growing with their stacks. Suffocante zones also slow long mudras.
	static func zone_tick(t: Tk, o: KitObject) -> void:
		if not t.alive():
			return
		var lvl: int = int(o.data.get("level", 1))
		var suffocant: bool = float(o.data.get("suffocant_until", -1.0)) > o.age
		for e: CombatCharacter in o.enemies_inside():
			if not t.is_enemy(e):
				continue
			var stacks: int = poison(t, e, lvl)
			t.hit(e, tox_dmg(t, 0.02 * stacks))
			if suffocant:
				suffocate(t, e)

	static func poison(t: Tk, e: CombatCharacter, stacks: int) -> int:
		return t.mark(e, POISON, stacks, POISON_TIME, POISON_MAX, "Poison")

	## Suffocation: a mudra with a long startup progresses at half speed.
	static func suffocate(t: Tk, e: CombatCharacter) -> void:
		t.debuff(e, "suffocation", 0.6, {"label": "Suffocation", "color": Color(0.6, 0.3, 0.7),
			"on_tick": func(dt: float) -> void:
				if is_instance_valid(e) and e.abilities.phase == AbilityController.Phase.STARTUP \
						and e.abilities.current != null and e.abilities.current.startup_time >= 0.35:
					e.abilities.phase_elapsed -= dt * 0.5})

	## Nearest toxic zone of the caster around `at`, or null.
	static func zone_near(t: Tk, at: Vector3, reach: float) -> KitObject:
		var best: KitObject = null
		var best_d: float = INF
		for z: KitObject in t.objects(TOXIC, &""):
			var d: float = t.distance(z.global_position, at) - z.radius
			if d <= reach and d < best_d:
				best = z
				best_d = d
		return best

	static func is_melee(hit: HitData, victim: CombatCharacter) -> bool:
		if hit == null or not is_instance_valid(hit.source) or hit.source == victim:
			return false
		if hit.ability != null and (hit.ability.kind == AbilityData.Kind.MELEE_ARC or hit.source.abilities.is_basic_attack(hit.ability)):
			return true
		return hit.ability != null and hit.ability.kind != AbilityData.Kind.PROJECTILE \
			and HitQuery.flat(hit.source.global_position - victim.global_position).length() <= 2.8


## D — Projectile, Terrain, Corrosion. Lobbed mucus ball: Toxicité 1 puddle
## where it lands (raises an existing zone instead); a direct hit poisons and
## corrodes the target's next temporary barrier (-35 %).
class CrachatAlcalin extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.18
		a.active_time = 0.05
		a.recovery_time = 0.2
		a.max_range = 10.0
		a.anim = &"breath"

	func cast(t: Tk) -> void:
		t.projectile({"lob_to": t.aim, "speed": 11.0, "size": 0.3, "color": MUCUS,
			"on_end": func(point: Vector3, _p: TkProjectile, reason: String) -> void:
				if reason == "recast":
					return
				t.fx("burst", point, 1.0, MUCUS)
				for e: CombatCharacter in t.enemies_in(point, 0.8):
					if t.hit(e, t.dmg(0.5)) == HitData.Result.HIT:
						K.poison(t, e, 2)
						_corrode(t, e)
				K.contaminate(t, point, 1.5, 1, 7.0)})

	func _corrode(t: Tk, e: CombatCharacter) -> void:
		t.debuff(e, "corrosion", 6.0, {"label": "Corrosion", "color": MUCUS,
			"on_tick": func(_dt: float) -> void:
				if is_instance_valid(e) and e.health.shield > 0.0:
					e.health.shield *= 0.65
					t.text(e, "CORRODÉ")
					e.kit.remove_modifier("corrosion")})


## C — Summon, Déplacement souterrain, Zone. A salamander burrows toward the
## aim leaving a dust trail; on arrival it surfaces, spits a mist (+1
## Toxicité) and stays 4 s as a killable summon that puffs again if left
## alive. Recast before arrival: surfaces at once with a smaller mist.
class SalamandreFouisseuse extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.active_time = 0.05
		a.max_range = 12.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var target: Vector3 = t.aim
		t.object(t.origin + t.dir * 0.8, {"kind": "fouisseuse", "radius": 0.5, "lifetime": 6.0, "look": KitObject.Look.NONE,
			"targetable": false, "color": MUCUS, "data": {"underground": true, "trail": 0.0},
			"on_tick": func(o: KitObject) -> void:
				if not o.data.get("underground", false):
					return
				var to: Vector3 = HitQuery.flat(target - o.global_position)
				var step: float = 7.0 * o.get_physics_process_delta_time()
				if to.length() <= step:
					o.global_position = target
					_surface(t, o, false)
					return
				o.global_position += to.normalized() * step
				if o.age - float(o.data.trail) >= 0.25:
					o.data["trail"] = o.age
					t.fx("dust", o.global_position, 0.5, Color(0.5, 0.45, 0.3))})
		t.recast(1.8, func(rt: Tk) -> void:
			for o: KitObject in rt.objects("fouisseuse"):
				if o.data.get("underground", false):
					_surface(rt, o, true))

	func _surface(t: Tk, o: KitObject, early: bool) -> void:
		if not o.is_alive():
			return
		t.kit().close_recast(t.id)
		o.data["underground"] = false
		o.look = KitObject.Look.ORB
		o.targetable = true
		o.health = 30.0
		o.max_health = 30.0
		o.lifetime = o.age + 4.0
		var at: Vector3 = o.global_position
		var r: float = 1.6 if early else 2.4
		t.fx("rocks", at, 1.0)
		t.fx("smoke", at, r, MUCUS)
		for e: CombatCharacter in t.enemies_in(at, r):
			if t.hit(e, t.dmg(0.35 if early else 0.5)) == HitData.Result.HIT:
				K.poison(t, e, 1)
		K.contaminate(t, at, r, 1, 8.0)
		o.on_expire = func(obj: KitObject) -> void:
			# Left alive, the summon puffs once more before leaving.
			t.fx("smoke", obj.global_position, r, MUCUS)
			K.contaminate(t, obj.global_position, r, 1, 6.0)


## B — Gaz, Déclencheur, Consommation de zone. Turns the toxic zone near the
## aim into a dormant, barely visible cloud. It goes off when an enemy starts
## a jutsu inside it, or on recast: the stored Toxicité becomes a cough
## (interrupts only long casts / channels, blinding slow), almost no damage.
class MiasmeDormant extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.25
		a.active_time = 0.05
		a.max_range = 11.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var zone: KitObject = K.zone_near(t, t.aim, 3.0)
		var lvl: int = 0
		var at: Vector3 = t.aim
		var r: float = 2.5
		if zone != null:
			lvl = int(zone.data.get("level", 1))
			at = zone.global_position
			r = zone.radius + 0.5
			zone.destroy("consumed")
		t.fx("smoke", at, r, Color(0.6, 0.7, 0.4, 0.4))
		t.zone(at, r, 12.0, {"kind": "miasme", "look": KitObject.Look.RING, "targetable": false,
			"tick_interval": 0.05, "color": Color(0.6, 0.75, 0.4, 0.25), "data": {"level": lvl},
			"on_tick": func(o: KitObject) -> void:
				for e: CombatCharacter in o.enemies_inside():
					if t.is_enemy(e) and e.abilities.phase == AbilityController.Phase.STARTUP:
						_trigger(t.refreshed(), o)
						return})
		t.recast(12.0, func(rt: Tk) -> void:
			for cloud: KitObject in rt.objects("miasme"):
				_trigger(rt, cloud))

	func _trigger(t: Tk, o: KitObject) -> void:
		if not o.is_alive():
			return
		t.kit().close_recast(t.id)
		var lvl: int = int(o.data.get("level", 0))
		var at: Vector3 = o.global_position
		t.fx("smoke", at, o.radius + 0.5, Color(0.55, 0.7, 0.3))
		for e: CombatCharacter in t.enemies_in(at, o.radius + 0.3):
			if t.hit(e, K.tox_dmg(t, 0.1 + 0.05 * lvl)) != HitData.Result.HIT:
				continue
			t.text(e, "TOUX")
			# Only long casts (channel or slow mudra) are broken by the cough.
			var ab: AbilityController = e.abilities
			var long_cast: bool = ab.phase == AbilityController.Phase.STARTUP and ab.current != null and ab.current.startup_time >= 0.4
			for key: String in e.kit.modifiers.keys():
				if key.begins_with("channel_"):
					long_cast = true
			if long_cast:
				t.status(e, StatusController.Type.STUN, 0.2)  # breaks the mudra / channel
			var blind: float = 1.0 + 0.5 * lvl
			t.status(e, StatusController.Type.SLOW, blind)
			t.debuff(e, "toux", blind, {"damage_dealt": 0.85, "label": "Toux (vision)", "color": Color(0.6, 0.7, 0.3)})
			if lvl > 0:
				K.poison(t, e, lvl)
		o.destroy("triggered")


## A — Mode défensif, Contact, Conversion. Mucus skin (8 s, gauge 100): melee
## hits taken are softened (-40 %), drain the gauge, poison the attacker and
## splash Toxicité under the caster. Ranged hits are not reduced. Recast:
## throw the remaining mucus in an arc — the leftover gauge becomes a
## contaminated zone (bigger and more toxic the fuller the gauge).
class PeauVenimeuse extends Technique:
	const MODE := "peau_venimeuse"

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.active_time = 0.05
		a.max_range = 9.0
		a.anim = &"guard"

	func cast(t: Tk) -> void:
		var state := {"gauge": 100.0, "splash": -1.0}
		t.fx("spheres", t.origin, 1.2, MUCUS)
		t.buff(MODE, 8.0, {"label": "Peau venimeuse", "color": MUCUS,
			"on_take": func(hit: HitData, dmg: float) -> Variant:
				if float(state.gauge) <= 0.0 or not K.is_melee(hit, t.caster):
					return null
				state["gauge"] = float(state.gauge) - (18.0 + dmg)
				var now: float = Time.get_ticks_msec() / 1000.0
				if now - float(state.splash) > 0.3:
					state["splash"] = now
					K.contaminate(t, t.caster.global_position, 1.3, 1, 6.0)
				if t.is_enemy(hit.source):
					K.poison(t, hit.source, 2)
				if float(state.gauge) <= 0.0:
					t.text(t.caster, "PEAU PERCÉE")
					t.after(0.0, func(rt: Tk) -> void:
						rt.kit().remove_modifier(MODE)
						rt.kit().close_recast(rt.id))
				return dmg * 0.6})
		t.recast(8.0, func(rt: Tk) -> void:
			if not rt.kit().has_modifier(MODE):
				return
			var gauge: float = maxf(float(state.gauge), 0.0)
			rt.kit().remove_modifier(MODE)
			if gauge <= 0.0:
				return
			var lvl: int = clampi(1 + int(gauge / 40.0), 1, 3)
			var r: float = 1.5 + gauge / 50.0
			rt.projectile({"lob_to": rt.aim, "speed": 13.0, "size": 0.4, "color": MUCUS,
				"on_end": func(point: Vector3, _p: TkProjectile, _reason: String) -> void:
					rt.fx("burst", point, r, MUCUS)
					for e: CombatCharacter in rt.enemies_in(point, r):
						K.poison(rt, e, lvl)
					K.contaminate(rt, point, r, lvl, 8.0)}))


## S — Invocation, Nuage mobile, Terrain majeur. Ibuse (killable summon)
## crawls slowly along the cast direction for 8 s, exhaling every second a
## cloud ahead that raises the Toxicité of what it covers; level-3 zones hit
## by the breath become Suffocantes (long mudras slowed). Single second
## command (recast): burrow, resurface ~6 m further — a gap in the cloud.
class SouffleDIbuse extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.6
		a.active_time = 0.05
		a.cast_move_multiplier = 0.2
		a.max_range = 12.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var d: Vector3 = t.dir
		t.fx("smoke", t.origin + d * 2.0, 2.5, MUCUS)
		t.object(t.origin + d * 2.0, {"kind": "ibuse", "radius": 1.4, "lifetime": 8.0, "health": 150.0,
			"look": KitObject.Look.PILLAR, "color": Color(0.45, 0.6, 0.35),
			"data": {"next_breath": 0.4, "burrow_until": -1.0},
			"on_tick": func(o: KitObject) -> void:
				var burrow_until: float = float(o.data.burrow_until)
				if burrow_until > 0.0:
					if o.age >= burrow_until:
						_resurface(t.refreshed(), o, d)
					return
				var step: float = 1.8 * o.get_physics_process_delta_time()
				var next: Vector3 = t.clear_point(o.global_position, d, step + 0.8)
				if t.distance(next, o.global_position) > step:
					o.global_position += d * step
				if o.age >= float(o.data.next_breath):
					o.data["next_breath"] = o.age + 1.0
					_breath(t, o, d)})
		t.recast(8.0, func(_rt: Tk) -> void:
			for ibuse: KitObject in t.objects("ibuse"):
				if float(ibuse.data.burrow_until) >= 0.0:
					continue
				ibuse.data["burrow_until"] = ibuse.age + 0.8
				ibuse.targetable = false
				ibuse.visible = false
				t.fx("rocks", ibuse.global_position, 1.5))

	func _breath(t: Tk, o: KitObject, d: Vector3) -> void:
		var at: Vector3 = o.global_position + d * 2.8
		t.fx("smoke", at, 3.0, MUCUS)
		for e: CombatCharacter in t.enemies_in(at, 3.0):
			t.hit(e, t.dmg(0.12))
		for z: KitObject in t.objects(TOXIC, &""):
			if int(z.data.get("level", 1)) >= 3 and t.distance(z.global_position, at) <= 3.0 + z.radius * 0.5:
				z.data["suffocant_until"] = z.age + 4.0
				t.fx("ring", z.global_position, z.radius, Color(0.6, 0.3, 0.7))
		K.contaminate(t, at, 3.0, 1, 9.0)

	func _resurface(t: Tk, o: KitObject, d: Vector3) -> void:
		var at: Vector3 = t.clear_point(o.global_position, d, 6.0)
		o.global_position = at
		o.visible = true
		o.targetable = true
		o.data["burrow_until"] = -1.0
		o.data["next_breath"] = o.age + 0.3
		t.fx("rocks", at, 2.0)
		t.area(at, 2.0, t.dmg(0.3), {"push": 2.0})
