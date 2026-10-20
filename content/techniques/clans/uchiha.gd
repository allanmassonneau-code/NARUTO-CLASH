extends RefCounted
## Technique kit: Uchiha (design bible §5, Konoha). Signature: Lecture — an
## enemy kept in the Uchiha's field of view (front cone + line of sight)
## while it casts gains Lectures ("lecture" mark, max 3, per target). A
## completed observed attack gives 0.5 Lecture (1 with the Sharingan on).
## Lectures stay refreshed while the target is in view and fade a few
## seconds after it leaves it. The signature also remembers the last enemy
## technique fully observed (shape profile for Mimétisme analytique).

const KIT_ID := &"clan_uchiha"
const SIGNATURE = UchihaSignature
const TECHNIQUES := {
	&"clan_uchiha_d_sharingan_observation": SharinganObservation,
	&"clan_uchiha_c_genjutsu_faux_pas": GenjutsuFauxPas,
	&"clan_uchiha_b_mimetisme_analytique": MimetismeAnalytique,
	&"clan_uchiha_a_sharingan_prediction": SharinganPrediction,
	&"clan_uchiha_s_susanoo_gardien_incomplet": SusanooGardienIncomplet,
}

const LECTURE := "lecture"
const LECTURE_TIME: float = 5.0
const VIEW_RANGE: float = 18.0
## cos(70°): half-angle of the field of view.
const VIEW_COS: float = 0.342
const SHARINGAN := "sharingan"
const SHARINGAN_DRAIN: float = 2.5
const ANALYSE := "analyse"
const PREDICTION := "prediction"
const SUSANOO := "susanoo"
## Seconds a recorded technique profile stays copyable.
const PROFILE_TIME: float = 8.0
const RED := Color(0.9, 0.12, 0.15)
const SPECTRAL := Color(0.65, 0.35, 1.0)
const NATURES: Array[String] = ["katon", "suiton", "raiton", "doton", "futon"]

## Whitelisted copy shapes (bible §7: profiles, never the other spell's code).
const PROJECTILE_LINE := &"PROJECTILE_LINE"
const CONE := &"CONE"
const DASH := &"DASH"
const GROUND_ZONE := &"GROUND_ZONE"


## Lecture: watches enemy casts in the field of view.
class UchihaSignature extends KitSignature:
	## Running clock (s) of this fighter.
	var clock: float = 0.0
	## enemy instance id -> {"ability", "full", "activated"}
	var watching: Dictionary = {}
	## enemy instance id -> fractional Lecture progress
	var progress: Dictionary = {}
	## Last fully observed enemy technique: {"enemy", "ability", "time"}.
	var last_seen: Dictionary = {}

	func tick(f: CombatCharacter, delta: float) -> void:
		clock += delta
		if f.is_dead() or not f.is_inside_tree():
			return
		var sharingan: bool = f.kit.has_modifier(SHARINGAN)
		for node: Node in f.get_tree().get_nodes_in_group(&"fighters"):
			var e := node as CombatCharacter
			if e == null or e.team == f.team or e.is_dead():
				continue
			var key: int = e.get_instance_id()
			var seen: bool = K.in_view(f, e)
			if seen and e.kit.marks.has(LECTURE) and e.kit.mark_source(LECTURE) == f:
				e.kit.marks[LECTURE].left = maxf(float(e.kit.marks[LECTURE].left), LECTURE_TIME)
			var w: Dictionary = watching.get(key, {})
			var ab: AbilityController = e.abilities
			if ab.is_casting() and ab.current != null:
				if w.is_empty() or w.ability != ab.current:
					if not w.is_empty():
						_finish(f, e, w)
					w = {"ability": ab.current, "full": seen, "activated": false}
					watching[key] = w
					if seen and sharingan:
						KitVisuals.fx(f, "ring", e.global_position, 0.9, RED)  # mudras read more clearly
				else:
					w.full = bool(w.full) and seen
				if ab.phase == AbilityController.Phase.ACTIVE or ab.phase == AbilityController.Phase.RECOVERY:
					w.activated = true
			elif not w.is_empty():
				watching.erase(key)
				_finish(f, e, w)

	## A watched cast ended: Lecture progress and profile record.
	func _finish(f: CombatCharacter, e: CombatCharacter, w: Dictionary) -> void:
		if not bool(w.full) or not bool(w.activated) or not is_instance_valid(e) or e.is_dead():
			return
		var gain: float = 1.0 if f.kit.has_modifier(SHARINGAN) else 0.5
		if f.kit.has_modifier(ANALYSE):
			gain += 0.5
		var key: int = e.get_instance_id()
		var p: float = float(progress.get(key, 0.0)) + gain
		var whole: int = floori(p + 0.001)
		progress[key] = p - whole
		if whole > 0:
			e.kit.add_mark(LECTURE, whole, LECTURE_TIME, 3, f, "Lecture", RED)
		var a: AbilityData = w.ability
		if a != null and a.source_id != &"":
			last_seen = {"enemy": e, "ability": a, "time": clock}


## Shared Uchiha rules.
class K:
	static func sig(t: Tk) -> UchihaSignature:
		for s: Object in t.kit().signatures:
			if s is UchihaSignature:
				return s
		return null

	## In the field of view: front cone, range, line of sight.
	static func in_view(f: CombatCharacter, e: CombatCharacter) -> bool:
		var to: Vector3 = HitQuery.flat(e.global_position - f.global_position)
		var d: float = to.length()
		if d > VIEW_RANGE:
			return false
		if d > 1.0 and f.facing.facing_direction.dot(to / d) < VIEW_COS:
			return false
		var up: Vector3 = Vector3.UP * HitQuery.BODY_HEIGHT
		return HitQuery.raycast_world(f.get_world_3d(), f.global_position + up, e.global_position + up).is_empty()

	## Lectures of this Uchiha on `e`.
	static func lectures(t: Tk, e: CombatCharacter) -> int:
		if e == null or not is_instance_valid(e) or e.kit.mark_source(LECTURE) != t.caster:
			return 0
		return t.marks(e, LECTURE)

	## Consumes `n` Lectures of `e`; false if it has fewer.
	static func use(t: Tk, e: CombatCharacter, n: int) -> bool:
		var have: int = lectures(t, e)
		if have < n:
			return false
		if have == n:
			e.kit.consume_mark(LECTURE)
		else:
			e.kit.marks[LECTURE].stacks = have - n
			e.kit.changed.emit()
		return true

	static func give(t: Tk, e: CombatCharacter, n: int) -> void:
		if t.is_enemy(e):
			e.kit.add_mark(LECTURE, n, LECTURE_TIME, 3, t.caster, "Lecture", RED)

	## The enemy aimed at, else the nearest one in front.
	static func focus(t: Tk, radius: float = 3.0, reach: float = 12.0) -> CombatCharacter:
		var e: CombatCharacter = t.target_at_aim(radius)
		if e != null:
			return e
		var front: Array[CombatCharacter] = t.enemies_in_cone(t.origin, t.dir, reach, 90.0)
		return front[0] if not front.is_empty() else null

	## Shape profile of an observed ability: a nature technique of rank D-B
	## with a whitelisted geometry, else &"" (incompatible).
	static func profile(a: AbilityData) -> StringName:
		if a == null:
			return &""
		var parts: PackedStringArray = String(a.source_id).split("_")
		if parts.size() < 3 or not NATURES.has(parts[0]) or not (parts[1] in ["d", "c", "b"]):
			return &""
		if a.anim == &"breath":
			return CONE
		if a.anim == &"dash":
			return DASH
		match a.kind:
			AbilityData.Kind.PROJECTILE:
				return PROJECTILE_LINE
			AbilityData.Kind.MELEE_ARC:
				return CONE
			AbilityData.Kind.DASH, AbilityData.Kind.TELEPORT:
				return DASH
			AbilityData.Kind.GROUND_AREA:
				return GROUND_ZONE
			AbilityData.Kind.SCRIPTED:
				if a.technique == null or a.technique.jutsu == null:
					return &""
				var tags: Array[StringName] = a.technique.jutsu.tags
				if tags.has(&"DASH") or tags.has(&"MOVEMENT"):
					return DASH
				if tags.has(&"PROJECTILE") or tags.has(&"RANGED") or tags.has(&"HITSCAN"):
					return PROJECTILE_LINE
				if tags.has(&"AOE") or tags.has(&"CHANNELING"):
					return GROUND_ZONE
				if tags.has(&"MELEE"):
					return CONE
		return &""

	static func profile_label(p: StringName) -> String:
		match p:
			PROJECTILE_LINE:
				return "projectile"
			CONE:
				return "cône"
			DASH:
				return "dash"
			GROUND_ZONE:
				return "zone"
		return "?"

	## Extended swing: while `state.swing` is unset, the caster's basic attack
	## also reaches `only` (or anyone) up to `extra` m beyond its range.
	## Returns true if it connected.
	static func long_swing(t: Tk, state: Dictionary, only: CombatCharacter, extra: float, mult: float) -> bool:
		var ab: AbilityController = t.caster.abilities
		if not (ab.phase == AbilityController.Phase.ACTIVE and ab.current != null and ab.is_basic_attack(ab.current)):
			state.swing = false
			return false
		if state.get("swing", false):
			return false
		state.swing = true
		var reach: float = ab.current.max_range
		var pos: Vector3 = HitQuery.flat(t.caster.global_position)
		for e: CombatCharacter in t.enemies_in_cone(pos, ab.cast_direction, reach + extra, maxf(ab.current.arc_degrees, 60.0)):
			if (only == null or e == only) and t.distance(e.global_position, pos) > reach + HitQuery.HURTBOX_RADIUS:
				t.hit(e, t.dmg(mult))
				return true
		return false


## D — Toggle, Information, Ressource. Turns the Sharingan on (continuous
## chakra drain): observed attacks give a full Lecture instead of half, and
## enemy casts in view flash. Recast turns it off; Lectures already gained
## keep fading normally (a few seconds out of view).
class SharinganObservation extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.05
		a.recovery_time = 0.1
		a.cast_move_multiplier = 1.0
		a.max_range = 8.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		t.fx("ring", t.origin, 1.0, RED)
		t.text(t.caster, "SHARINGAN", RED)
		t.buff(SHARINGAN, 60.0, {"label": "Sharingan", "color": RED,
			"on_tick": func(dt: float) -> void:
				if not t.caster.energy.consume(SHARINGAN_DRAIN * dt):
					t.kit().remove_modifier(SHARINGAN),
			"on_end": func() -> void:
				t.kit().close_recast(t.id)})
		t.recast(60.0, func(rt: Tk) -> void:
			rt.kit().remove_modifier(SHARINGAN)
			rt.text(rt.caster, "OFF", RED))


## C — Illusion, Decoy, Mindgame. Spends 1 Lecture on the focused enemy: a
## fake Uchiha dashes toward the aim while the real one stays. If that enemy
## breaks the illusion it gets Flou de visée (its next homing / lock-on
## doesn't attach, or its next hit is weakened). No Lecture: a short-lived
## decoy without the Flou. (Approximation: the decoy is visible to everyone.)
class GenjutsuFauxPas extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.12
		a.recovery_time = 0.2
		a.max_range = 12.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var target: CombatCharacter = K.focus(t)
		var real: bool = target != null and K.use(t, target, 1)
		var start: Vector3 = t.origin
		var end: Vector3 = t.clear_point(t.origin, t.dir, 5.0)
		t.fx("smoke", t.origin, 0.8)
		if real:
			t.text(target, "GENJUTSU", RED)
		t.object(start, {"kind": "faux_pas", "look": KitObject.Look.DECOY, "radius": 0.6, "lifetime": 1.8 if real else 0.6,
			"health": 1.0, "color": RED,
			"on_tick": func(o: KitObject) -> void:
				o.set("global_position", start.lerp(end, clampf(o.age / 0.3, 0.0, 1.0))),
			"on_destroy": func(o: KitObject, reason: String) -> void:
				t.fx("smoke", o.global_position, 0.7)
				if reason == "destroyed" and real and t.is_enemy(target):
					_blur(t, target)})

	## Flou de visée: the next lock-on of the target fails.
	func _blur(t: Tk, target: CombatCharacter) -> void:
		t.text(target, "FLOU", RED)
		t.debuff(target, "flou_de_visee", 3.0, {"label": "Flou de visée", "color": RED, "uses": 1,
			"on_deal": func(_tg: CombatCharacter, _h: HitData, dmg: float) -> Variant:
				return dmg * 0.6,
			"on_tick": func(_dt: float) -> void:
				if not is_instance_valid(target):
					return
				for node: Node in target.get_tree().get_nodes_in_group(&"tk_projectiles"):
					var p := node as TkProjectile
					if p != null and p.caster == target and p.homing > 0.0 and p.age < 0.15:
						p.homing = 0.0
						p.homing_target = null
						target.kit.remove_modifier("flou_de_visee")
						return})


## B — Copie limitée, Adaptation, Recast. If the last fully observed enemy
## technique is a nature technique of rank B or lower and its caster has 2
## Lectures, spends them and records its shape profile (projectile line,
## cone, dash or ground zone) for 6 s; recast fires a neutral, weaker copy
## of that shape (never the original code or effects). Incompatible
## technique: +1 Lecture instead. Nothing recorded: Analyse stance (observed
## attacks give more Lecture for 5 s).
class MimetismeAnalytique extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.15
		a.recovery_time = 0.2
		a.max_range = 12.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var s: UchihaSignature = K.sig(t)
		var rec: Dictionary = s.last_seen if s != null else {}
		if not rec.is_empty() and s.clock - float(rec.time) <= PROFILE_TIME and is_instance_valid(rec.enemy):
			var src: CombatCharacter = rec.enemy
			var a: AbilityData = rec.ability
			var shape: StringName = K.profile(a)
			if shape == &"":
				s.last_seen = {}
				K.give(t, src, 1)
				t.text(src, "INCOMPATIBLE", RED)
				return
			if K.use(t, src, 2):
				s.last_seen = {}
				var copy: Dictionary = {"profile": shape, "range": a.max_range, "radius": a.hit_radius,
					"arc": a.arc_degrees, "dash": a.dash_distance}
				t.fx("ring", t.origin, 1.2, RED)
				t.text(t.caster, "COPIE", RED)
				t.buff("mimetisme", 6.0, {"label": "Copie : " + K.profile_label(shape), "color": RED})
				t.recast(6.0, func(rt: Tk) -> void:
					rt.kit().remove_modifier("mimetisme")
					_copy(rt, copy))
				return
		t.buff(ANALYSE, 5.0, {"label": "Analyse", "color": RED})
		t.fx("ring", t.origin, 1.0, RED)

	## The neutral copy: same main geometry, reduced damage, no effects.
	func _copy(t: Tk, copy: Dictionary) -> void:
		match StringName(copy.profile):
			PROJECTILE_LINE:
				t.projectile({"speed": 22.0, "range": clampf(float(copy.range), 8.0, 14.0), "radius": 0.5, "size": 0.22,
					"color": RED, "on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
						t.hit(e, t.dmg(0.55))
						return false})
			CONE:
				t.cone(clampf(float(copy.range), 3.0, 6.0), clampf(float(copy.arc), 50.0, 90.0), t.dmg(0.55))
			DASH:
				var dist: float = clampf(float(copy.dash), 4.0, 7.0)
				var from: Vector3 = t.origin
				var d: Vector3 = t.dir
				t.dash(dist, d, 0.18)
				t.line(dist, 1.0, t.dmg(0.45), {}, from, d)
			GROUND_ZONE:
				var at: Vector3 = t.aim
				var r: float = clampf(float(copy.radius), 1.8, 3.0)
				t.telegraph(at, r, 0.45, func(tt: Tk) -> void:
					tt.fx("explosion", at, r, RED)
					tt.area(at, r, tt.dmg(0.6)))


## A — Parade avancée, Reposition, Duel. Very short prediction window on the
## focused enemy. If that enemy hits the Uchiha directly (not a posed zone)
## during it: with 2 Lectures they are spent and the hit is cut to 25 %
## (else 60 %), no stun, and the Uchiha side-steps toward the side the aim
## points at. Success: the next basic attack on that enemy reaches further.
## A hit from someone else (feint, ally) makes the window fail.
class SharinganPrediction extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.05
		a.recovery_time = 0.15
		a.cast_move_multiplier = 0.6
		a.max_range = 10.0
		a.anim = &"guard"

	func cast(t: Tk) -> void:
		var target: CombatCharacter = K.focus(t, 3.5, 10.0)
		var strong: bool = target != null and K.lectures(t, target) >= 2
		if target != null:
			t.text(target, "PRÉDICTION" if strong else "LECTURE", RED)
		t.fx("ring", t.origin, 0.8, RED)
		t.buff(PREDICTION, 0.5, {"label": "Prédiction", "color": RED,
			"on_take": func(hit: HitData, dmg: float) -> Variant:
				return _on_hit(t, target, hit, dmg)})

	func _on_hit(t: Tk, target: CombatCharacter, hit: HitData, dmg: float) -> Variant:
		if not t.kit().has_modifier(PREDICTION):
			return null
		var src: CombatCharacter = hit.source
		if not is_instance_valid(src) or src == t.caster or src.team == t.caster.team:
			return null
		if hit.ability != null and hit.ability.kind == AbilityData.Kind.GROUND_AREA:
			return null  # zones already on the ground don't trigger it
		t.kit().remove_modifier(PREDICTION)
		if target != null and src != target:
			t.text(t.caster, "RATÉ", RED)
			return null
		var mult: float = 0.6
		if K.use(t, src, 2):
			mult = 0.25
		t.buff("prediction_esquive", 0.25, {"cc_immune": true, "tenacity": true})
		t.text(t.caster, "LU", RED)
		var from: Vector3 = HitQuery.flat(src.global_position)
		t.after(0.02, func(rt: Tk) -> void:
			var side: Vector3 = HitQuery.flat(from - rt.origin).normalized().cross(Vector3.UP)
			if side.length() < 0.5:
				side = rt.dir.cross(Vector3.UP)
			var sign: float = 1.0 if HitQuery.flat(rt.aim - rt.origin).dot(side) >= 0.0 else -1.0
			rt.dash(2.6, side * sign, 0.14, true))
		var state: Dictionary = {"swing": false}
		t.buff("prediction_portee", 3.0, {"label": "Ouverture", "color": RED,
			"on_tick": func(_dt: float) -> void:
				if K.long_swing(t, state, src, 1.2, 0.3):
					t.kit().remove_modifier("prediction_portee")})
		return dmg * mult


## S — Avatar défensif, Arc de garde, Recast. Spectral skeleton with its own
## integrity gauge: hits from the front arc are absorbed by it (no stun /
## reduced push), hits in the back land normally; the Uchiha is slowed. Each
## Lecture on nearby enemies is a spectral arrow; recast fires them all,
## one after the other, at their owners (homing lost without line of sight),
## then the Susanoo dissipates.
class SusanooGardienIncomplet extends Technique:
	const DURATION: float = 10.0
	const INTEGRITY: float = 70.0

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.7
		a.recovery_time = 0.3
		a.cast_move_multiplier = 0.2
		a.max_range = 14.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		t.fx("column", t.origin, 1.6, SPECTRAL)
		var guard: KitObject = t.object(t.origin, {"kind": "susanoo", "look": KitObject.Look.RING, "radius": 1.5,
			"lifetime": DURATION, "health": INTEGRITY, "targetable": false, "color": SPECTRAL, "tick_interval": 0.0,
			"on_tick": func(o: KitObject) -> void:
				if not t.alive():
					o.destroy("caster")
					return
				o.global_position = HitQuery.flat(t.caster.global_position)
				if t.kit().modifiers.has(SUSANOO):
					_relabel(t, o),
			"on_destroy": func(_o: KitObject, reason: String) -> void:
				if reason == "destroyed":
					t.text(t.caster, "SUSANOO BRISÉ", SPECTRAL)
				t.kit().close_recast(t.id)
				t.kit().remove_modifier(SUSANOO)})
		t.buff(SUSANOO, DURATION, {"speed": 0.65, "label": "Susanoo", "color": SPECTRAL,
			"on_take": func(hit: HitData, dmg: float) -> Variant:
				return _guard(t, guard, hit, dmg),
			"on_end": func() -> void:
				if is_instance_valid(guard) and guard.is_alive():
					guard.destroy("ended")})
		t.recast(DURATION, func(rt: Tk) -> void:
			_fire(rt, guard))

	func _relabel(t: Tk, o: KitObject) -> void:
		t.kit().modifiers[SUSANOO].props.label = "Susanoo %d · %d flèches" % [roundi(o.health), _arrows(t).size()]

	## Frontal arc: the gauge takes the hit.
	func _guard(t: Tk, guard: KitObject, hit: HitData, dmg: float) -> Variant:
		if not is_instance_valid(guard) or not guard.is_alive() or not is_instance_valid(hit.source) or hit.source == t.caster:
			return null
		var to: Vector3 = HitQuery.flat(hit.source.global_position - t.caster.global_position)
		if to.length() > 0.05 and t.caster.facing.facing_direction.dot(to.normalized()) < 0.5:
			return null  # back / flanks: the real body is hit
		var absorbed: float = minf(dmg, guard.health)
		t.buff("susanoo_appui", 0.15, {"tenacity": true, "cc_immune": true})
		guard.damage(absorbed)
		return dmg - absorbed

	## One target entry per Lecture of this Uchiha on enemies nearby.
	func _arrows(t: Tk) -> Array[CombatCharacter]:
		var out: Array[CombatCharacter] = []
		for e: CombatCharacter in t.enemies_in(t.caster.global_position, 14.0):
			for i in K.lectures(t, e):
				out.append(e)
		return out

	func _fire(t: Tk, guard: KitObject) -> void:
		var targets: Array[CombatCharacter] = _arrows(t)
		for e: CombatCharacter in targets:
			K.use(t, e, 1)
		for i in targets.size():
			var e: CombatCharacter = targets[i]
			t.after(0.15 * i, func(at: Tk) -> void:
				_arrow(at, e))
		if targets.is_empty():
			t.text(t.caster, "AUCUNE LECTURE", SPECTRAL)
		if is_instance_valid(guard) and guard.is_alive():
			guard.destroy("released")

	func _arrow(t: Tk, e: CombatCharacter) -> void:
		if not t.is_enemy(e):
			return
		var d: Vector3 = HitQuery.flat(e.global_position - t.origin).normalized()
		if d.length() < 0.5:
			d = t.dir
		# Line of sight broken: guidance lost.
		var steer := func(p: TkProjectile, _dt: float) -> void:
			if p.homing > 0.0 and is_instance_valid(e):
				var up: Vector3 = Vector3.UP * HitQuery.BODY_HEIGHT
				if not HitQuery.raycast_world(p.get_world_3d(), p.ground_point() + up, e.global_position + up).is_empty():
					p.homing = 0.0
		t.projectile({"dir": d, "speed": 26.0, "range": 18.0, "radius": 0.5, "homing": 4.0, "homing_target": e, "size": 0.2,
			"color": SPECTRAL, "on_tick": steer,
			"on_hit": func(target: CombatCharacter, _p: TkProjectile) -> bool:
				t.hit(target, t.dmg(0.5))
				return false})
