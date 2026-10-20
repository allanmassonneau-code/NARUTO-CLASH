extends RefCounted
## Technique kit: Senju (design bible §5, Konoha). Signature: Vigueur — up to
## 3 charges ("vigueur" resource) gained by dealing or taking significant
## damage (internal cooldown), lost out of combat. Techniques consume 1 to 3
## Vigueurs for reinforced variants. Sceau de sève ("seve" mark) feeds
## Vigueur whenever the marked enemy hits the Senju.

const KIT_ID := &"clan_senju"
const SIGNATURE = SenjuSignature
const TECHNIQUES := {
	&"clan_senju_d_impulsion_ancestrale": ImpulsionAncestrale,
	&"clan_senju_c_poigne_de_seve": PoigneDeSeve,
	&"clan_senju_b_rempart_de_racines": RempartDeRacines,
	&"clan_senju_a_floraison_de_combat": FloraisonDeCombat,
	&"clan_senju_s_avatar_du_grand_bois": AvatarDuGrandBois,
}

const VIGUEUR := "vigueur"
const VIGUEUR_MAX: float = 3.0
## Seconds without gaining / spending before the Vigueur fades (out of combat).
const VIGUEUR_DECAY: float = 6.0
## Damage needed for a hit to count as "significant".
const SIGNIFICANT: float = 6.0
const VIGUEUR_ICD: float = 2.0
const SEVE := "seve"
const AVATAR := "avatar_grand_bois"
const GREEN := Color(0.35, 0.85, 0.35)
const WOOD := Color(0.5, 0.36, 0.2)


## Vigueur: per-fighter resource, fed by significant damage dealt / taken
## (internal cooldown) and by the Sceau de sève.
class SenjuSignature extends KitSignature:
	var _icd: float = 0.0

	func setup(f: CombatCharacter) -> void:
		f.kit.define_resource(VIGUEUR, VIGUEUR_MAX, "Vigueur", GREEN, VIGUEUR_DECAY)

	func tick(_f: CombatCharacter, delta: float) -> void:
		_icd = maxf(0.0, _icd - delta)

	func on_deal(f: CombatCharacter, _target: CombatCharacter, _hit: HitData, damage: float) -> Variant:
		_significant(f, damage)
		return null

	func on_take(f: CombatCharacter, hit: HitData, damage: float) -> Variant:
		if damage > 0.0 and is_instance_valid(hit.source) and hit.source != f:
			K.seve_trigger(f, hit.source)
		_significant(f, damage)
		return null

	func _significant(f: CombatCharacter, damage: float) -> void:
		if damage < SIGNIFICANT or not f.kit.resources.has(VIGUEUR):
			return
		f.kit.resources[VIGUEUR].idle = 0.0  # still in combat: don't fade at full charges
		if _icd <= 0.0:
			_icd = VIGUEUR_ICD
			f.kit.add_res(VIGUEUR, 1.0)


## Shared Senju rules.
class K:
	static func vigor(t: Tk) -> int:
		return floori(t.res(VIGUEUR) + 0.001)

	## Spends `n` Vigueurs if available.
	static func spend(t: Tk, n: int) -> bool:
		return vigor(t) >= n and t.spend_res(VIGUEUR, float(n))

	## Spends up to `n` whole Vigueurs; returns how many.
	static func spend_up_to(t: Tk, n: int) -> int:
		var k: int = mini(n, vigor(t))
		if k > 0:
			t.spend_res(VIGUEUR, float(k))
		return k

	## The Senju was hit by `attacker`: if it carries this Senju's Sceau de
	## sève, part of the hit becomes Vigueur; the 3rd trigger breaks the seal
	## and heals.
	static func seve_trigger(f: CombatCharacter, attacker: CombatCharacter) -> void:
		if attacker.kit.mark(SEVE) <= 0 or attacker.kit.mark_source(SEVE) != f:
			return
		var m: Dictionary = attacker.kit.marks[SEVE]
		m["triggers"] = int(m.get("triggers", 0)) + 1
		f.kit.add_res(VIGUEUR, 0.5)
		if int(m.triggers) >= 3:
			attacker.kit.consume_mark(SEVE)
			f.health.heal(f.data.max_health * 0.06)
			KitVisuals.fx(f, "burst", f.global_position, 1.0, GREEN)

	## Quadrant of `point` around `f`: 0 front, 1 left, 2 back, 3 right.
	static func quadrant(f: CombatCharacter, point: Vector3) -> int:
		var to: Vector3 = HitQuery.flat(point - f.global_position)
		if to.length() < 0.05:
			return 0
		var angle: float = f.facing.facing_direction.signed_angle_to(to.normalized(), Vector3.UP)
		return posmod(roundi(angle / (PI * 0.5)), 4)

	static func quadrant_dir(f: CombatCharacter, q: int) -> Vector3:
		return HitQuery.flat(f.facing.facing_direction).normalized().rotated(Vector3.UP, q * PI * 0.5)

	## Distance from `p` to the segment [a, b] (flat).
	static func seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
		var ab: Vector3 = HitQuery.flat(b - a)
		var ap: Vector3 = HitQuery.flat(p - a)
		var l2: float = ab.length_squared()
		var k: float = 0.0 if l2 < 0.0001 else clampf(ap.dot(ab) / l2, 0.0, 1.0)
		return (ap - ab * k).length()

	## Ground line visual (veins).
	static func ground_line(t: Tk, from: Vector3, to: Vector3) -> MeshInstance3D:
		if not CombatFx.is_enabled():
			return null
		var mi: MeshInstance3D = KitVisuals.line_visual(t.caster.get_parent(), GREEN)
		var im := mi.mesh as ImmediateMesh
		im.clear_surfaces()
		im.surface_begin(Mesh.PRIMITIVE_LINES)
		for side: float in [-0.12, 0.0, 0.12]:
			var off: Vector3 = HitQuery.flat(to - from).normalized().cross(Vector3.UP) * side
			im.surface_add_vertex(Vector3(from.x + off.x, 0.06, from.z + off.z))
			im.surface_add_vertex(Vector3(to.x + off.x, 0.06, to.z + off.z))
		im.surface_end()
		return mi


## D — Self-buff, Ressource, Anti-slow. Removes slows / roots (never stuns or
## seals): if something was removed, tenacity + 1 Vigueur; cast with no
## debuff it is only a short burst of speed.
class ImpulsionAncestrale extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.05
		a.recovery_time = 0.1
		a.cast_move_multiplier = 1.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var removed: int = 0
		for type: StatusController.Type in [StatusController.Type.SLOW, StatusController.Type.ROOT]:
			if t.caster.status.has_status(type):
				t.caster.status.remove_status(type)
				removed += 1
		t.fx("burst", t.origin, 1.2, GREEN)
		if removed > 0:
			t.buff("impulsion", 2.0, {"tenacity": true, "speed": 1.15, "label": "Impulsion", "color": GREEN})
			t.add_res(VIGUEUR, 1.0)
			t.text(t.caster, "VIGUEUR", GREEN)
		else:
			t.buff("impulsion", 1.2, {"speed": 1.3, "label": "Élan", "color": GREEN})


## C — Mêlée, Vol de tempo, Sustain. Heavy palm: Sceau de sève on the target
## (each hit it lands on the Senju gives 0.5 Vigueur, the 3rd breaks it and
## heals — see SenjuSignature). Spending 1 Vigueur turns it into a short grab
## that kills the target's momentum.
class PoigneDeSeve extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.22
		a.recovery_time = 0.3
		a.max_range = 2.6
		a.anim = &"palm"

	func cast(t: Tk) -> void:
		var grabbed: bool = false
		var can_grab: bool = K.vigor(t) >= 1  # Vigueur held before the impact
		for e: CombatCharacter in t.melee(2.4, 80.0, t.dmg(0.8)):
			t.mark(e, SEVE, 1, 6.0, 1, "Sceau de sève")
			if e.kit.marks.has(SEVE):
				e.kit.marks[SEVE]["triggers"] = 0
			t.fx("ring", e.global_position, 0.9, GREEN)
			if can_grab and not grabbed and K.spend(t, 1):
				grabbed = true
				e.movement.cancel_forced()
				e.abilities.interrupt()
				t.hit(e, 0.0, {"stun": 0.35})
				t.pull(e, t.origin + t.dir * 1.2, 0.8)
				t.text(e, "SAISIE", GREEN)


## B — Mur, Cover, Ressource. Telegraphed curved rampart (3 destructible
## segments facing the caster). Spends up to 3 Vigueurs: 1 = wider, 2 = side
## spur, 3 = enemies standing on the spawn area are pushed back. Never a
## closed shape.
class RempartDeRacines extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.recovery_time = 0.25
		a.max_range = 8.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var n: int = K.spend_up_to(t, 3)
		var at: Vector3 = t.aim
		var d: Vector3 = t.dir
		t.telegraph(at, 2.0 + 0.4 * n, 0.4, func(rt: Tk) -> void:
			_raise(rt, at, d, n))

	func _raise(t: Tk, at: Vector3, d: Vector3, n: int) -> void:
		const R: float = 4.0
		var half_angle: float = 0.5 if n >= 1 else 0.35
		var pivot: Vector3 = at - d * R
		var seg_len: float = R * half_angle * 1.1
		var opts: Dictionary = {"kind": "rempart", "health": 40.0, "color": WOOD, "thickness": 0.7}
		t.fx("rocks", at, 1.5)
		for i in 3:
			var dd: Vector3 = d.rotated(Vector3.UP, half_angle * (i - 1))
			t.wall(pivot + dd * R, dd, seg_len, 9.0, opts)
		if n >= 2:
			# Lateral spur at one end: an angle to hide behind, not a box.
			var end_dir: Vector3 = d.rotated(Vector3.UP, half_angle * 1.5)
			var end: Vector3 = pivot + end_dir * R
			var side: Vector3 = d.cross(Vector3.UP)
			t.wall(end + d * 0.9, side, 1.8, 9.0, opts)
		if n >= 3:
			for e: CombatCharacter in t.enemies_in(at, R * half_angle * 1.6):
				if K.seg_dist(e.global_position, pivot + d.rotated(Vector3.UP, -half_angle) * R,
						pivot + d.rotated(Vector3.UP, half_angle) * R) <= 1.2:
					t.hit(e, t.dmg(0.3), {"push": 3.0, "push_from": pivot})


## A — Zone hybride, Sustain, Root conditionnel. Destructible vital core
## growing 3 ground veins (+1 toward the aim if a Vigueur is auto-spent, +1
## toward a nearby Rempart). Allies near a vein get small heal pulses; an
## enemy crossing two different veins within 1.5 s is briefly rooted.
class FloraisonDeCombat extends Technique:
	const VEIN_LEN: float = 4.5
	const LIFE: float = 8.0

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.35
		a.max_range = 9.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var at: Vector3 = t.aim
		var dirs: Array[Vector3] = []
		for k in 3:
			dirs.append(t.dir.rotated(Vector3.UP, deg_to_rad(60.0 + 120.0 * k)))
		if K.spend(t, 1):
			dirs.append(t.dir)
			t.text(t.caster, "VEINE +1", GREEN)
		var best: KitObject = null
		for w: KitObject in t.objects("rempart", &"clan_senju_b_rempart_de_racines"):
			var dist: float = t.distance(w.global_position, at)
			if dist <= 7.0 and dist > 1.0 and (best == null or dist < t.distance(best.global_position, at)):
				best = w
		if best != null:
			dirs.append(HitQuery.flat(best.global_position - at).normalized())
		var veins: Array = []
		var lines: Array = []
		for d: Vector3 in dirs:
			var b: Vector3 = at + d * VEIN_LEN
			veins.append([at, b])
			lines.append(K.ground_line(t, at, b))
		t.fx("spikes", at, 1.5, GREEN)
		t.object(at, {"kind": "noyau_vital", "radius": 0.7, "lifetime": LIFE, "health": 45.0, "look": KitObject.Look.ORB,
			"color": GREEN, "data": {"veins": veins, "lines": lines, "cross": {}, "inside": {}, "pulse": 0.0},
			"on_tick": func(o: KitObject) -> void:
				_tick(t, o),
			"on_destroy": func(o: KitObject, _reason: String) -> void:
				for mi: Variant in o.data.lines:
					if mi != null and is_instance_valid(mi):
						(mi as Node).queue_free()})

	func _tick(t: Tk, o: KitObject) -> void:
		var veins: Array = o.data.veins
		# Heal pulses for allies near a vein (once per second).
		if o.age - float(o.data.pulse) >= 1.0:
			o.data.pulse = o.age
			for ally: CombatCharacter in t.allies_in(o.global_position, VEIN_LEN + 1.5):
				for v: Array in veins:
					if K.seg_dist(ally.global_position, v[0], v[1]) <= 1.2:
						t.heal(ally, t.dmg(0.15))
						break
		# Root: two different veins crossed in a short time.
		var cross: Dictionary = o.data.cross
		var inside: Dictionary = o.data.inside
		for e: CombatCharacter in t.enemies_in(o.global_position, VEIN_LEN + 1.0):
			var key: int = e.get_instance_id()
			var was: Array = inside.get(key, [])
			var now: Array = []
			for i in veins.size():
				if K.seg_dist(e.global_position, veins[i][0], veins[i][1]) <= 0.6:
					now.append(i)
					if not was.has(i):
						_crossed(t, o, e, i, cross)
			inside[key] = now

	func _crossed(t: Tk, o: KitObject, e: CombatCharacter, vein: int, cross: Dictionary) -> void:
		var key: int = e.get_instance_id()
		var last: Dictionary = cross.get(key, {"vein": -1, "time": -10.0, "cd": -10.0})
		if o.age < float(last.cd):
			return
		if int(last.vein) >= 0 and int(last.vein) != vein and o.age - float(last.time) <= 1.5:
			t.status(e, StatusController.Type.ROOT, 0.7)
			t.hit(e, t.dmg(0.2))
			t.fx("spikes", e.global_position, 0.8, GREEN)
			t.text(e, "ENRACINÉ", GREEN)
			cross[key] = {"vein": -1, "time": -10.0, "cd": o.age + 2.5}
			return
		cross[key] = {"vein": vein, "time": o.age, "cd": -10.0}


## S — Transformation, Armure, Recast. Slow transformation spending all
## Vigueur: 1 armour segment + 1 per charge (front, left, right, back). The
## first hit from a covered direction breaks that segment instead of moving
## the Senju (tenacity); basic attacks reach further. Recast: the remaining
## segments become root arms in their directions + a finisher sized by them.
class AvatarDuGrandBois extends Technique:
	const DURATION: float = 12.0
	const ORDER: Array[int] = [0, 1, 3, 2]

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.8
		a.cast_move_multiplier = 0.2
		a.recovery_time = 0.3
		a.max_range = 8.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var spent: int = floori(t.take_all_res(VIGUEUR) + 0.001)
		var count: int = clampi(1 + spent, 1, 4)
		var state: Dictionary = {"segments": {}, "swing": false}
		for i in count:
			state.segments[ORDER[i]] = true
		t.fx("column", t.origin, 1.6, WOOD)
		t.text(t.caster, "AVATAR x%d" % count, GREEN)
		var shell: KitObject = t.object(t.origin, {"kind": "avatar", "radius": 1.5, "lifetime": DURATION, "look": KitObject.Look.RING,
			"targetable": false, "color": WOOD, "on_tick": func(o: KitObject) -> void:
				if t.alive():
					o.global_position = HitQuery.flat(t.caster.global_position)
				else:
					o.destroy("caster")})
		t.buff(AVATAR, DURATION, {"speed": 0.8, "label": "Avatar %d" % count, "color": WOOD,
			"on_take": func(hit: HitData, _damage: float) -> Variant:
				_absorb(t, state, hit)
				return null,
			"on_tick": func(_dt: float) -> void:
				_long_reach(t, state),
			"on_end": func() -> void:
				if is_instance_valid(shell):
					shell.destroy("ended")
				t.kit().close_recast(t.id)})
		t.recast(DURATION, func(rt: Tk) -> void:
			_release(rt, state))

	## A hit from a direction with an intact segment breaks it instead of
	## displacing the Senju.
	func _absorb(t: Tk, state: Dictionary, hit: HitData) -> void:
		if not is_instance_valid(hit.source) or hit.source == t.caster:
			return
		var q: int = K.quadrant(t.caster, hit.source.global_position)
		if not state.segments.get(q, false):
			return
		state.segments[q] = false
		t.buff("avatar_appui", 0.2, {"tenacity": true})
		t.fx("rocks", t.caster.global_position + K.quadrant_dir(t.caster, q) * 1.2, 1.0)
		t.text(t.caster, "SEGMENT", WOOD)
		if t.kit().modifiers.has(AVATAR):
			t.kit().modifiers[AVATAR].props.label = "Avatar %d" % _remaining(state).size()

	## Root-arm reach: a basic attack also hits enemies just beyond its range.
	func _long_reach(t: Tk, state: Dictionary) -> void:
		var ab: AbilityController = t.caster.abilities
		if ab.phase == AbilityController.Phase.ACTIVE and ab.current != null and ab.is_basic_attack(ab.current):
			if state.swing:
				return
			state.swing = true
			var reach: float = ab.current.max_range
			var pos: Vector3 = HitQuery.flat(t.caster.global_position)
			for e: CombatCharacter in t.enemies_in_cone(pos, ab.cast_direction, reach + 1.8, maxf(ab.current.arc_degrees, 60.0)):
				if t.distance(e.global_position, pos) > reach + HitQuery.HURTBOX_RADIUS:
					t.hit(e, t.dmg(0.25))
		else:
			state.swing = false

	func _remaining(state: Dictionary) -> Array[int]:
		var out: Array[int] = []
		for q: int in state.segments:
			if state.segments[q]:
				out.append(q)
		return out

	func _release(t: Tk, state: Dictionary) -> void:
		var left: Array[int] = _remaining(state)
		var n: int = left.size()
		for q: int in left:
			var d: Vector3 = K.quadrant_dir(t.caster, q)
			t.fx("spikes", t.origin + d * 3.0, 1.2, WOOD)
			t.line(6.5, 1.3, t.dmg(0.45), {"push": 2.0}, t.origin, d)
		if n > 0:
			var r: float = 2.0 + 0.8 * n
			t.fx("explosion", t.origin, r, WOOD)
			t.area(t.origin, r, t.dmg(0.3 + 0.2 * n))
		else:
			t.fx("dust", t.origin, 1.5)
		t.kit().remove_modifier(AVATAR)
