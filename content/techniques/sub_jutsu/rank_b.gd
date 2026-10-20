extends RefCounted
## Technique kit: sub_rank_b (design bible §6, Rang B). Universal sub-jutsu:
## no signature resource; every per-technique state lives in marks,
## modifiers or objects. Mechanical-expression tools: recasts, decoys,
## traps, parries and information plays.

const KIT_ID := &"sub_rank_b"
const SIGNATURE = null
const TECHNIQUES := {
	&"sub_b_shunshin_double_empreinte": DoubleEmpreinte,
	&"sub_b_clone_explosif_tactique": CloneExplosif,
	&"sub_b_paume_d_absorption_de_chakra": PaumeAbsorption,
	&"sub_b_voile_de_brume_silencieuse": VoileDeBrume,
	&"sub_b_reseau_de_parchemins_explosifs": ReseauDeParchemins,
	&"sub_b_fil_de_chakra_manipulateur": FilDeChakra,
	&"sub_b_fausse_ouverture": FausseOuverture,
	&"sub_b_danse_des_cables_kunai": DanseDesCables,
	&"sub_b_pulsation_sensorielle": PulsationSensorielle,
	&"sub_b_lame_de_chakra_fluide": LameDeChakra,
	&"sub_b_substitution_a_balise": SubstitutionABalise,
	&"sub_b_sceau_d_echo_sonore": SceauDEcho,
}

const SOUND_MARK := "marque_sonore"
const TRACE := "trace_sonore"
const REVEALED := "revele"
const IMPULSION := "impulsion_lame"
const CHAKRA_BLUE := Color(0.45, 0.75, 1.0)
const MIST := Color(0.75, 0.82, 0.88)
const PAPER := Color(0.95, 0.85, 0.55)
## Kinds of KitObjects the Fil de chakra may recall as "weapons on the ground".
const WEAPON_KINDS: Array[String] = ["ancre_kunai", "kunai", "arme", "shuriken"]


## Shared helpers of the rank B sub-jutsu.
class K:
	## True when nothing of the world blocks the straight line a -> b.
	static func clear_line(t: Tk, a: Vector3, b: Vector3) -> bool:
		var up: Vector3 = Vector3.UP * HitQuery.BODY_HEIGHT
		return HitQuery.raycast_world(t.caster.get_world_3d(), HitQuery.flat(a) + up, HitQuery.flat(b) + up).is_empty()

	static func nearest_object(objs: Array[KitObject], point: Vector3) -> KitObject:
		var best: KitObject = null
		var best_d: float = INF
		for o: KitObject in objs:
			if not o.is_alive():
				continue
			var d: float = HitQuery.flat(o.global_position - point).length()
			if d < best_d:
				best_d = d
				best = o
		return best

	static func node_alive(n: Node3D) -> bool:
		if not is_instance_valid(n) or not n.is_inside_tree() or n.is_queued_for_deletion():
			return false
		if n is CombatCharacter:
			return not (n as CombatCharacter).is_dead()
		if n is KitObject:
			return (n as KitObject).is_alive()
		if n is TkProjectile:
			return (n as TkProjectile).is_alive()
		return true

	## A visible chakra thread from the caster to `target`; breaks on an
	## obstacle or beyond `max_dist`. `each.call(o)` every frame while held.
	static func thread(t: Tk, target: Node3D, life: float, max_dist: float, each: Callable) -> KitObject:
		var me: CombatCharacter = t.caster
		var line_node: MeshInstance3D = KitVisuals.line_visual(me.get_parent(), CHAKRA_BLUE) if CombatFx.is_enabled() else null
		var o: KitObject = t.object(me.global_position, {"kind": "fil", "radius": 0.1, "lifetime": life, "look": KitObject.Look.NONE,
			"targetable": false,
			"on_tick": func(obj: KitObject) -> void:
				if not is_instance_valid(me) or me.is_dead() or not K.node_alive(target):
					obj.destroy("lost")
					return
				var a: Vector3 = HitQuery.flat(me.global_position)
				var b: Vector3 = HitQuery.flat(target.global_position)
				if a.distance_to(b) > max_dist or not K.clear_line(t, a, b):
					t.fx("sparks", b, 0.5, CHAKRA_BLUE)
					obj.destroy("broken")
					return
				obj.global_position = a
				if line_node != null and is_instance_valid(line_node):
					KitVisuals.update_line(line_node, me.global_position + Vector3.UP * HitQuery.BODY_HEIGHT, target.global_position)
				if each.is_valid():
					each.call(obj),
			"on_destroy": func(_obj: KitObject, _reason: String) -> void:
				if line_node != null and is_instance_valid(line_node):
					line_node.queue_free()})
		o.data["target"] = target
		return o

	## Point toward `to` from `from`, at most `dist`, stopped by walls.
	static func placed(t: Tk, from: Vector3, to: Vector3) -> Vector3:
		var d: Vector3 = HitQuery.flat(to - from)
		if d.length() < 0.05:
			return HitQuery.flat(to)
		return t.clear_point(from, d.normalized(), d.length())

	static func is_melee(hit: HitData) -> bool:
		if hit == null or hit.ability == null or not is_instance_valid(hit.source):
			return false
		var k: AbilityData.Kind = hit.ability.kind
		if k == AbilityData.Kind.MELEE_ARC or k == AbilityData.Kind.DASH:
			return true
		return k != AbilityData.Kind.PROJECTILE and hit.source.abilities.is_basic_attack(hit.ability)


## B — Mobilité, Recast, Feinte. Leaves a visible footprint (only when
## grounded), blinks 5.5 m (stopped by walls). Recast within 1 s: blink back
## onto the footprint keeping the current facing. Damage / CC taken stay.
class DoubleEmpreinte extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.06
		a.recovery_time = 0.12
		a.cast_move_multiplier = 1.0
		a.max_range = 6.0
		a.anim = &"dash"

	func cast(t: Tk) -> void:
		var footprint: KitObject = null
		if not t.caster.is_airborne():
			footprint = t.object(t.origin, {"kind": "empreinte", "radius": 0.7, "lifetime": 1.4, "look": KitObject.Look.GLYPH,
				"targetable": false, "color": CHAKRA_BLUE})
		t.fx("smoke", t.origin, 0.7)
		t.blink(t.origin + t.dir * 5.5)
		if footprint == null:
			return
		t.recast(1.0, func(rt: Tk) -> void:
			if not is_instance_valid(footprint) or not footprint.is_alive():
				return
			var back: Vector3 = footprint.global_position
			footprint.destroy("used")
			rt.blink(back),
			func() -> void:
				if is_instance_valid(footprint) and footprint.is_alive():
					footprint.destroy("expired"))


## B — Decoy, Recast, Piège. A one-HP decoy runs along the cast direction,
## then mirrors the caster's movements with a 0.3 s delay (4 s). Breaks
## enemy homing locks on the caster. Recast: full explosion (push + Marque
## sonore); destroyed by an enemy: weaker explosion. Never attacks.
class CloneExplosif extends Technique:
	const DELAY_FRAMES: int = 18

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.15
		a.recovery_time = 0.2
		a.max_range = 8.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		for node: Node in t.tree().get_nodes_in_group(&"tk_projectiles"):
			var p := node as TkProjectile
			if p != null and p.is_alive() and p.team != t.caster.team and p.homing_target == t.caster:
				p.homing_target = null  # lock broken
		var trail: Array = []
		var decoy: KitObject = t.object(t.origin + t.dir * 0.8, {"kind": "clone_explosif", "radius": 0.6, "lifetime": 4.0,
			"health": 1.0, "look": KitObject.Look.DECOY, "color": Color(1.0, 0.7, 0.35),
			"data": {"trail": trail, "dir": t.dir},
			"on_tick": func(o: KitObject) -> void:
				_move(t, o),
			"on_destroy": func(o: KitObject, reason: String) -> void:
				if reason == "destroyed" and t.alive():
					_explode(t, o.global_position, false)})
		t.fx("smoke", decoy.global_position, 0.8)
		t.recast(4.0, func(rt: Tk) -> void:
			if is_instance_valid(decoy) and decoy.is_alive():
				var at: Vector3 = decoy.global_position
				decoy.destroy("detonated")
				_explode(rt, at, true))

	func _move(t: Tk, o: KitObject) -> void:
		if not is_instance_valid(t.caster):
			return
		var dt: float = o.get_physics_process_delta_time()
		var trail: Array = o.data["trail"]
		trail.append(HitQuery.flat(t.caster.global_position))
		var step: Vector3 = Vector3.ZERO
		if o.age < 1.3:
			step += (o.data["dir"] as Vector3) * 4.5 * dt
		if trail.size() > DELAY_FRAMES + 1:
			step += (trail[trail.size() - 1 - DELAY_FRAMES] as Vector3) - (trail[trail.size() - 2 - DELAY_FRAMES] as Vector3)
			trail.pop_front()
		if step.length() > 0.001:
			o.global_position = t.clear_point(o.global_position, step.normalized(), step.length())

	func _explode(t: Tk, at: Vector3, full: bool) -> void:
		var r: float = 2.6 if full else 1.8
		t.fx("explosion", at, r, Color(1.0, 0.6, 0.25))
		for e: CombatCharacter in t.area(at, r, t.dmg(0.55 if full else 0.3), {"push": 3.0 if full else 1.8}):
			t.mark(e, SOUND_MARK, 1, 4.0, 1, "Marque sonore")


## B — Parade, Ressource, Anti-jutsu. 0.5 s frontal palm guard: the first
## chakra hit (technique / jutsu projectile, not physical, not ultimate) is
## partly absorbed (-65 %, only -35 % if heavy), refunds a capped share of
## its cost, and the next technique within 5 s refunds 40 % of its cost.
class PaumeAbsorption extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.05
		a.recovery_time = 0.2
		a.cast_move_multiplier = 0.4
		a.recovery_move_multiplier = 0.4
		a.max_range = 2.0
		a.anim = &"palm"

	func cast(t: Tk) -> void:
		var me: CombatCharacter = t.caster
		t.fx("ring", t.origin + t.dir * 0.6, 0.9, CHAKRA_BLUE)
		t.buff("paume_absorption", 0.5, {"speed": 0.6, "label": "Paume", "color": CHAKRA_BLUE,
			"on_take": func(hit: HitData, dmg: float) -> float:
				if not _compatible(me, hit):
					return dmg
				var heavy: bool = dmg >= 25.0
				var kept: float = dmg * (0.65 if heavy else 0.35)
				me.energy.restore(clampf(hit.ability.energy_cost * 0.5, 5.0, 18.0))
				me.kit.remove_modifier("paume_absorption")
				t.fx("implosion", me.global_position, 1.0, CHAKRA_BLUE)
				t.text(me, "ABSORBÉ", CHAKRA_BLUE)
				_mudra_discount(t)
				return kept})

	func _compatible(me: CombatCharacter, hit: HitData) -> bool:
		if hit == null or hit.ability == null or not is_instance_valid(hit.source) or hit.source == me:
			return false
		var a: AbilityData = hit.ability
		if a.kind == AbilityData.Kind.MELEE_ARC or a.kind == AbilityData.Kind.DASH or hit.source.abilities.is_basic_attack(a):
			return false  # physical
		if a.energy_cost >= 100.0 or (a.technique != null and a.technique.jutsu != null and a.technique.jutsu.rank >= 4):
			return false  # ultimate
		var to_source: Vector3 = HitQuery.flat(hit.source.global_position - me.global_position)
		return to_source.length() < 0.05 or me.facing.facing_direction.dot(to_source.normalized()) > 0.25

	func _mudra_discount(t: Tk) -> void:
		var me: CombatCharacter = t.caster
		var own: StringName = id
		t.buff("paume_mudra", 5.0, {"label": "Mudra allégé", "color": CHAKRA_BLUE,
			"on_tick": func(_dt: float) -> void:
				if not is_instance_valid(me):
					return
				var cur: AbilityData = me.abilities.current
				if cur != null and cur.source_id != &"" and cur.source_id != own \
						and me.abilities.phase != AbilityController.Phase.STARTUP:
					me.energy.restore(minf(cur.energy_cost * 0.4, 20.0))
					me.kit.remove_modifier("paume_mudra")})


## B — Zone, Vision, Son. Fixed mist (4.5 m, 7 s). Everyone inside (caster
## too) deals -40 % to targets beyond 4 m unless they carry a Trace sonore;
## homing locks on targets in the mist are lost at range. Enemies moving
## fast inside leave sound rings + Trace sonore; attacking from the mist
## reveals the attacker.
class VoileDeBrume extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.recovery_time = 0.2
		a.max_range = 9.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		t.fx("smoke", t.aim, 4.5, MIST)
		t.zone(t.aim, 4.5, 7.0, {"kind": "brume", "color": MIST, "targetable": false, "tick_interval": 0.2,
			"data": {"last": {}},
			"on_tick": func(o: KitObject) -> void:
				_tick(t, o)})

	func _tick(t: Tk, o: KitObject) -> void:
		var last: Dictionary = o.data["last"]
		for f: CombatCharacter in o.inside:
			if not is_instance_valid(f) or f.is_dead():
				continue
			var key: int = f.get_instance_id()
			var pos: Vector3 = HitQuery.flat(f.global_position)
			var moved: float = pos.distance_to(last.get(key, pos))
			last[key] = pos
			if moved > 0.9 and t.is_enemy(f):  # fast steps (> 4.5 m/s) ring out
				t.fx("ring", pos, 1.2, MIST)
				t.mark(f, TRACE, 1, 1.0, 1, "Trace sonore")
			_veil(t, f)
		for node: Node in t.tree().get_nodes_in_group(&"tk_projectiles"):
			var p := node as TkProjectile
			if p != null and p.is_alive() and is_instance_valid(p.homing_target) and o.contains(p.homing_target.global_position) \
					and HitQuery.flat(p.global_position - p.homing_target.global_position).length() > 4.0:
				p.homing_target = null

	func _veil(t: Tk, f: CombatCharacter) -> void:
		var hostile: bool = t.is_enemy(f)
		var src: CombatCharacter = t.caster
		f.kit.add_modifier("brume_voile", 0.35, {"label": "Brume", "color": MIST,
			"on_deal": func(target: CombatCharacter, _hit: HitData, dmg: float) -> float:
				if not is_instance_valid(f) or not is_instance_valid(target):
					return dmg
				if hostile and is_instance_valid(src):
					f.kit.add_mark(TRACE, 1, 1.5, 1, src, "Trace sonore", MIST)  # attacks reveal their origin
				if HitQuery.flat(target.global_position - f.global_position).length() > 4.0 and target.kit.mark(TRACE) <= 0:
					return dmg * 0.6
				return dmg})


## B — Piège, Chaîne, Programmation. Places a destructible scroll (vulnerable
## pose); recast within 5 s: places another (max 3) if the aim is away from
## them, else detonates the scroll nearest to the aim. An explosion reaching
## another scroll's zone sets it off 0.35 s later (chain follows placement).
class ReseauDeParchemins extends Technique:
	const MAX_SCROLLS: int = 3
	const BLAST: float = 2.4

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.35
		a.recovery_time = 0.2
		a.cast_move_multiplier = 0.2
		a.max_range = 10.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		_act(t, false)

	func _act(t: Tk, from_recast: bool) -> void:
		var scrolls: Array[KitObject] = t.objects("parchemin")
		var nearest: KitObject = K.nearest_object(scrolls, t.aim)
		if nearest != null and (t.distance(nearest.global_position, t.aim) <= 2.5 or scrolls.size() >= MAX_SCROLLS):
			_detonate(t, nearest)
		else:
			if from_recast:
				t.buff("pose_parchemin", 0.3, {"speed": 0.2})  # pose time stays vulnerable
			_place(t)
		if not t.objects("parchemin").is_empty():
			t.recast(5.0, func(rt: Tk) -> void:
				_act(rt, true))

	func _place(t: Tk) -> void:
		var at: Vector3 = K.placed(t, t.origin, t.aim)
		t.fx("dust", at, 0.6, PAPER)
		t.object(at, {"kind": "parchemin", "radius": 1.0, "lifetime": 25.0, "health": 12.0, "look": KitObject.Look.GLYPH,
			"color": PAPER,
			"on_destroy": func(o: KitObject, reason: String) -> void:
				if reason == "destroyed":
					t.fx("smoke", o.global_position, 0.6)})  # destroyed by an enemy: fizzles

	func _detonate(t: Tk, scroll: KitObject) -> void:
		if not is_instance_valid(scroll) or not scroll.is_alive():
			return
		var at: Vector3 = scroll.global_position
		scroll.destroy("detonated")
		t.fx("explosion", at, BLAST, Color(1.0, 0.55, 0.2))
		t.area(at, BLAST, t.dmg(0.7), {"push": 2.0, "slow": 1.0})
		for other: KitObject in t.objects("parchemin"):
			if other.data.get("armed", false) or t.distance(other.global_position, at) > BLAST + other.radius:
				continue
			other.data["armed"] = true
			t.fx("sparks", other.global_position, 0.6, PAPER)
			t.after(0.35, func(rt: Tk) -> void:
				_detonate(rt, other))


## B — Tether, Projectile control, Utility. A short chakra thread on: an
## allied small projectile (steered toward the cursor, ~1.8 rad/s), else a
## weapon object on the ground (recalled, nicking enemies on the way), else
## a very close enemy (4 m): only disrupts a jump / dash (cancel + slow, no
## hard CC). Breaks on obstacles or distance.
class FilDeChakra extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.12
		a.recovery_time = 0.15
		a.max_range = 10.0
		a.anim = &"throw"

	func cast(t: Tk) -> void:
		var proj: Node3D = _find_projectile(t)
		if proj != null:
			_bind_projectile(t, proj)
			return
		var weapon: KitObject = _find_weapon(t)
		if weapon != null:
			_recall(t, weapon)
			return
		var e: CombatCharacter = t.nearest_enemy(t.origin, 4.0)
		if e != null and K.clear_line(t, t.origin, e.global_position):
			_bind_enemy(t, e)
			return
		t.fx("sparks", t.clear_point(t.origin, t.dir, 4.0), 0.5, CHAKRA_BLUE)  # thread finds nothing

	func _find_projectile(t: Tk) -> Node3D:
		var best: Node3D = null
		var best_d: float = INF
		for node: Node in t.tree().get_nodes_in_group(&"tk_projectiles"):
			var p := node as TkProjectile
			if p == null or not p.is_alive() or p.team != t.caster.team or p.lob or p.size > 0.35 or p.technique_id == id:
				continue
			if t.distance(p.global_position, t.origin) > 10.0:
				continue
			var d: float = t.distance(p.global_position, t.aim)
			if d < best_d:
				best_d = d
				best = p
		for node: Node in t.tree().get_nodes_in_group(&"projectiles"):
			var bp := node as Projectile
			if bp == null or bp.is_queued_for_deletion() or bp.team != t.caster.team or t.distance(bp.global_position, t.origin) > 10.0:
				continue
			var d2: float = t.distance(bp.global_position, t.aim)
			if d2 < best_d:
				best_d = d2
				best = bp
		return best

	func _find_weapon(t: Tk) -> KitObject:
		var candidates: Array[KitObject] = []
		for o: KitObject in t.objects("", &""):
			if (WEAPON_KINDS.has(o.kind) or o.data.get("weapon", false)) and t.distance(o.global_position, t.origin) <= 10.0:
				candidates.append(o)
		return K.nearest_object(candidates, t.aim)

	func _bind_projectile(t: Tk, proj: Node3D) -> void:
		var me: CombatCharacter = t.caster
		K.thread(t, proj, 1.2, 12.0, func(_o: KitObject) -> void:
			var want: Vector3 = HitQuery.flat(me.facing.aim_point - proj.global_position)
			if want.length() < 0.5:
				return
			var step: float = 1.8 * proj.get_physics_process_delta_time()
			if proj is TkProjectile:
				var tp := proj as TkProjectile
				tp.direction = tp.direction.rotated(Vector3.UP, clampf(tp.direction.signed_angle_to(want.normalized(), Vector3.UP), -step, step)).normalized()
			elif proj is Projectile:
				var bp := proj as Projectile
				bp.direction = bp.direction.rotated(Vector3.UP, clampf(bp.direction.signed_angle_to(want.normalized(), Vector3.UP), -step, step)).normalized())

	func _recall(t: Tk, weapon: KitObject) -> void:
		var me: CombatCharacter = t.caster
		var nicked: Array = []
		K.thread(t, weapon, 2.0, 12.0, func(o: KitObject) -> void:
			var to: Vector3 = HitQuery.flat(me.global_position - weapon.global_position)
			if to.length() <= 1.0:
				t.fx("sparks", me.global_position, 0.5, CHAKRA_BLUE)
				weapon.destroy("recalled")
				o.destroy("done")
				return
			weapon.global_position += to.normalized() * minf(18.0 * weapon.get_physics_process_delta_time(), to.length())
			for e: CombatCharacter in t.enemies_in(weapon.global_position, 0.8):
				if not nicked.has(e):
					nicked.append(e)
					t.hit(e, t.dmg(0.25)))

	func _bind_enemy(t: Tk, e: CombatCharacter) -> void:
		t.debuff(e, "fil_chakra", 1.5, {"label": "Fil", "color": CHAKRA_BLUE})
		K.thread(t, e, 1.5, 6.0, func(o: KitObject) -> void:
			var cur: AbilityData = e.abilities.current
			var dashing: bool = e.abilities.is_casting() and cur != null and cur.kind == AbilityData.Kind.DASH
			if not (e.is_airborne() or dashing):
				return
			if dashing:
				e.abilities.interrupt()
			e.movement.cancel_forced()
			e.movement.stop()
			t.status(e, StatusController.Type.SLOW, 0.8)
			t.text(e, "PERTURBÉ", CHAKRA_BLUE)
			t.fx("sparks", e.global_position, 0.7, CHAKRA_BLUE)
			e.kit.remove_modifier("fil_chakra")
			o.destroy("used"))


## B — Stance, Counter, Mindgame. 1.3 s fake-recovery stance (slowed). If a
## melee attack starts nearby or lands, a 0.6 s recast opens: half-step
## sidestep (brief immaterial) then a counter-strike with a short stun. No
## attack: the stance ends with a real recovery (0.45 s root).
class FausseOuverture extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.1
		a.recovery_time = 0.1
		a.max_range = 3.5
		a.anim = &"guard"

	func cast(t: Tk) -> void:
		var me: CombatCharacter = t.caster
		var state: Dictionary = {"triggered": false}
		t.buff("fausse_ouverture", 1.3, {"speed": 0.7, "label": "Fausse ouverture", "color": Color(0.9, 0.8, 0.6),
			"on_tick": func(_dt: float) -> void:
				if not state.triggered:
					var attacker: CombatCharacter = _threat(t)
					if attacker != null:
						_bait(t, state, attacker),
			"on_take": func(hit: HitData, dmg: float) -> float:
				if not state.triggered and K.is_melee(hit):
					_bait(t, state, hit.source)
				return dmg,
			"on_end": func() -> void:
				if not state.triggered and is_instance_valid(me) and not me.is_dead():
					t.status(me, StatusController.Type.ROOT, 0.45)
					t.text(me, "RATÉ")})

	func _threat(t: Tk) -> CombatCharacter:
		if not is_instance_valid(t.caster):
			return null
		for e: CombatCharacter in t.enemies_in(t.caster.global_position, 3.5):
			var cur: AbilityData = e.abilities.current
			if cur == null or e.abilities.phase == AbilityController.Phase.RECOVERY:
				continue
			if cur.kind == AbilityData.Kind.MELEE_ARC or cur.kind == AbilityData.Kind.DASH:
				return e
		return null

	func _bait(t: Tk, state: Dictionary, attacker: CombatCharacter) -> void:
		state.triggered = true
		t.text(t.caster, "!", Color(1.0, 0.9, 0.4))
		t.recast(0.6, func(rt: Tk) -> void:
			_riposte(rt, attacker))

	func _riposte(t: Tk, attacker: CombatCharacter) -> void:
		var to: Vector3 = t.dir
		if is_instance_valid(attacker):
			to = HitQuery.flat(attacker.global_position - t.origin).normalized()
		var side: Vector3 = to.cross(Vector3.UP).normalized()
		t.status(t.caster, StatusController.Type.IMMATERIAL, 0.25)
		t.dash(1.4, side, 0.1)
		t.after(0.12, func(st: Tk) -> void:
			if not is_instance_valid(attacker) or not st.is_enemy(attacker) or st.distance(st.origin, attacker.global_position) > 3.8:
				return
			st.caster.facing.facing_direction = HitQuery.flat(attacker.global_position - st.origin).normalized()
			st.fx("burst", attacker.global_position, 0.9)
			st.hit(attacker, st.dmg(0.95), {"stun": 0.5}))


## B — Anchors, Mobility, Skillshot. Throws three cable kunai in a narrow fan;
## each plants where it stops (wall, or the floor at max range) as a
## destructible anchor. A kunai hitting an enemy bounces to the ground beside
## him (never grapples a player). Recast (7 s, reopened while anchors
## remain): pull to the anchor nearest the aim, or a short swing around it
## if the aim points elsewhere; each anchor allows one move.
class DanseDesCables extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.recovery_time = 0.2
		a.max_range = 12.0
		a.anim = &"throw"

	func cast(t: Tk) -> void:
		for old: KitObject in t.objects("ancre_kunai"):
			old.destroy("replaced")
		for i in 3:
			var d: Vector3 = t.dir.rotated(Vector3.UP, deg_to_rad(-10.0 + 10.0 * i))
			t.projectile({"dir": d, "speed": 30.0, "range": 11.0, "size": 0.15, "radius": 0.45,
				"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
					t.hit(e, t.dmg(0.3))
					return false,
				"on_end": func(point: Vector3, p: TkProjectile, reason: String) -> void:
					var at: Vector3 = point
					if reason == "hit":
						var side: Vector3 = p.direction.cross(Vector3.UP).normalized()
						at = t.clear_point(point, side, 1.3)
					elif reason == "wall" or reason == "blocked":
						at = point - p.direction * 0.4
					_anchor(t, at)})
		t.recast(7.0, func(rt: Tk) -> void:
			_move(rt))

	func _anchor(t: Tk, at: Vector3) -> void:
		t.object(at, {"kind": "ancre_kunai", "radius": 0.4, "lifetime": 8.0, "health": 8.0, "look": KitObject.Look.PILLAR,
			"color": Color(0.7, 0.75, 0.8), "data": {"weapon": true}})

	func _move(t: Tk) -> void:
		var anchor: KitObject = K.nearest_object(t.objects("ancre_kunai"), t.aim)
		if anchor == null:
			return
		var at: Vector3 = anchor.global_position
		anchor.destroy("used")
		var to: Vector3 = HitQuery.flat(at - t.origin)
		var d: float = to.length()
		if CombatFx.is_enabled():
			var cable := KitVisuals.line_visual(t.caster.get_parent(), Color(0.8, 0.85, 0.9))
			KitVisuals.update_line(cable, t.caster.global_position + Vector3.UP * HitQuery.BODY_HEIGHT, at + Vector3.UP * 0.5)
			t.tree().create_timer(0.25).timeout.connect(cable.queue_free)
		if d > 1.2:
			if t.distance(t.aim, at) <= 3.0 or d > 7.0:
				t.dash(d - 1.0, to.normalized(), clampf(d / 24.0, 0.12, 0.4))  # pull to the anchor
			else:
				var aim_dir: Vector3 = HitQuery.flat(t.aim - t.origin)
				var s: float = 1.0 if to.cross(aim_dir).y < 0.0 else -1.0
				var tangent: Vector3 = to.normalized().cross(Vector3.UP) * s
				t.dash(minf(d * 1.57, 6.0), tangent, 0.25)  # swing around the anchor
		if not t.objects("ancre_kunai").is_empty():
			t.recast(4.0, func(rt: Tk) -> void:
				_move(rt))


## B — Reveal, Anti-decoy, Interrupt léger. A wave (11 m, 6 m behind
## obstacles) marks enemies Révélé (3 s, strips stealth flags), flashes enemy
## objects / clones / decoys; a long channel within 3 m gets a 0.25 s jolt.
class PulsationSensorielle extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.recovery_time = 0.25
		a.max_range = 11.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		t.fx("wave", t.origin, 11.0, CHAKRA_BLUE)
		for e: CombatCharacter in t.fighters():
			if not t.is_enemy(e):
				continue
			var d: float = t.distance(t.origin, e.global_position)
			var reach: float = 11.0 if K.clear_line(t, t.origin, e.global_position) else 6.0
			if d > reach:
				continue
			t.mark(e, REVEALED, 1, 3.0, 1, "Révélé")
			t.text(e, "RÉVÉLÉ", CHAKRA_BLUE)
			for key: String in e.kit.modifiers.keys():
				var props: Dictionary = e.kit.modifiers[key].props
				if props.get("stealth", false) or props.get("invisible", false):
					e.kit.remove_modifier(key)
			if d <= 3.0 and _channelling(e):
				t.status(e, StatusController.Type.STUN, 0.25)
				t.text(e, "SECOUSSE")
		for node: Node in t.tree().get_nodes_in_group(&"kit_objects"):
			var o := node as KitObject
			if o == null or not o.is_alive() or o.team == t.caster.team or t.distance(o.global_position, t.origin) > 11.0:
				continue
			o.data["revealed"] = true
			t.fx("ring", o.global_position, o.radius + 0.4, CHAKRA_BLUE)
			if o.look == KitObject.Look.DECOY:
				t.fx("sparks", o.global_position, 0.8, CHAKRA_BLUE)
		for node: Node in t.tree().get_nodes_in_group(&"round_entities"):
			var c := node as ShadowClone
			if c != null and is_instance_valid(c.owner_character) and c.owner_character.team != t.caster.team \
					and t.distance(c.global_position, t.origin) <= 11.0:
				t.fx("ring", c.global_position, 1.0, CHAKRA_BLUE)

	func _channelling(e: CombatCharacter) -> bool:
		for key: String in e.kit.modifiers:
			if key.begins_with("channel_"):
				return true
		var cur: AbilityData = e.abilities.current
		return cur != null and e.abilities.phase == AbilityController.Phase.STARTUP and cur.startup_time >= 0.6


## B — Weapon enchant, Parry projectile, Recast. 6 s chakra blade (+15 %
## basic damage). A basic swing meeting a small enemy projectile in front
## splits it and stores one Impulsion; the next heavy hit (combo finisher /
## knockback / RMB) or a recast spends it on a short neutral air blade.
class LameDeChakra extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.1
		a.recovery_time = 0.1
		a.max_range = 2.0
		a.anim = &"slash"

	func cast(t: Tk) -> void:
		var me: CombatCharacter = t.caster
		t.fx("sparks", t.origin + Vector3.UP, 0.6, CHAKRA_BLUE)
		t.buff("lame_chakra", 6.0, {"basic_damage": 1.15, "label": "Lame de chakra", "color": CHAKRA_BLUE,
			"on_tick": func(_dt: float) -> void:
				if is_instance_valid(me) and not me.is_dead():
					_parry_scan(t),
			"on_deal": func(_target: CombatCharacter, hit: HitData, dmg: float) -> float:
				if is_instance_valid(me) and me.kit.has_modifier(IMPULSION) and _is_heavy(me, hit):
					_release(t.refreshed())
				return dmg})

	func _is_heavy(me: CombatCharacter, hit: HitData) -> bool:
		var a: AbilityData = hit.ability if hit != null else null
		if a == null or a.kind == AbilityData.Kind.PROJECTILE:
			return false
		if a == me.abilities.get_base_ability(&"rmb"):
			return true
		return me.abilities.is_basic_attack(a) and (a.combo_next == null or a.knockback_speed > 0.0)

	func _parry_scan(t: Tk) -> void:
		var me: CombatCharacter = t.caster
		var cur: AbilityData = me.abilities.current
		if cur == null or not me.abilities.is_basic_attack(cur) or me.abilities.phase == AbilityController.Phase.RECOVERY:
			return
		var at: Vector3 = HitQuery.flat(me.global_position)
		var front: Vector3 = HitQuery.flat(me.facing.facing_direction).normalized()
		for node: Node in t.tree().get_nodes_in_group(&"projectiles"):
			var bp := node as Projectile
			if bp != null and not bp.is_queued_for_deletion() and bp.team != me.team and _in_front(at, front, bp.global_position):
				bp.queue_free()
				_store(t, bp.global_position)
		for node: Node in t.tree().get_nodes_in_group(&"tk_projectiles"):
			var p := node as TkProjectile
			if p != null and p.is_alive() and p.team != me.team and not p.lob and p.size <= 0.3 and _in_front(at, front, p.global_position):
				p.end("blocked")
				_store(t, p.global_position)

	func _in_front(at: Vector3, front: Vector3, point: Vector3) -> bool:
		var to: Vector3 = HitQuery.flat(point) - at
		return to.length() <= 1.8 and (to.length() < 0.3 or front.dot(to.normalized()) > 0.3)

	func _store(t: Tk, where: Vector3) -> void:
		t.fx("sparks", HitQuery.flat(where), 0.6, CHAKRA_BLUE)
		t.text(t.caster, "FENDU", CHAKRA_BLUE)
		t.buff(IMPULSION, 8.0, {"label": "Impulsion", "color": CHAKRA_BLUE})
		t.recast(8.0, func(rt: Tk) -> void:
			_release(rt))

	func _release(t: Tk) -> void:
		if not t.kit().has_modifier(IMPULSION):
			return
		t.kit().remove_modifier(IMPULSION)
		t.kit().close_recast(t.id)
		t.projectile({"speed": 24.0, "range": 8.0, "size": 0.25, "radius": 0.6, "pierce": true, "color": Color(0.85, 0.95, 1.0),
			"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
				t.hit(e, t.dmg(0.6))
				return true})


## B — Mark, Reactive swap, Terrain. A visible, destructible beacon (8 s).
## When a direct attack hits the caster, a 0.5 s recast opens: swap to the
## beacon (damage kept), leaving a smoke puff that slows nearby attackers.
## No swap if the beacon spot is occupied, too far (14 m) or out of line.
class SubstitutionABalise extends Technique:
	const BUFF := "balise_substitution"

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.15
		a.recovery_time = 0.15
		a.max_range = 10.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var me: CombatCharacter = t.caster
		for old: KitObject in t.objects("balise"):
			old.destroy("replaced")
		var beacon: KitObject = t.object(K.placed(t, t.origin, t.aim), {"kind": "balise", "radius": 0.5, "lifetime": 8.0,
			"health": 20.0, "look": KitObject.Look.GLYPH, "color": Color(1.0, 0.85, 0.4),
			"on_destroy": func(_o: KitObject, _reason: String) -> void:
				if is_instance_valid(me):
					me.kit.remove_modifier(BUFF)})
		t.buff(BUFF, 8.0, {"label": "Balise", "color": Color(1.0, 0.85, 0.4),
			"on_take": func(hit: HitData, dmg: float) -> float:
				if is_instance_valid(hit.source) and hit.source != me and hit.ability != null \
						and is_instance_valid(beacon) and beacon.is_alive():
					t.text(me, "SWAP ?", Color(1.0, 0.85, 0.4))
					t.recast(0.5, func(rt: Tk) -> void:
						_swap(rt, beacon))
				return dmg})

	func _swap(t: Tk, beacon: KitObject) -> void:
		if not is_instance_valid(beacon) or not beacon.is_alive():
			return
		var at: Vector3 = beacon.global_position
		var from: Vector3 = t.origin
		var to: Vector3 = HitQuery.flat(at - from)
		if to.length() > 14.0:
			t.text(t.caster, "TROP LOIN")
			return
		if to.length() > 0.5 and not K.clear_line(t, from, at):
			t.text(t.caster, "BLOQUÉ")
			return
		for f: CombatCharacter in t.fighters():
			if f != t.caster and not f.is_dead() and t.distance(f.global_position, at) < 0.9:
				t.text(t.caster, "OCCUPÉ")
				return
		beacon.destroy("used")
		t.kit().remove_modifier(BUFF)
		t.caster.abilities.interrupt()
		t.blink(at)
		t.status(t.caster, StatusController.Type.IMMATERIAL, 0.2)
		t.fx("smoke", from, 1.5)
		for e: CombatCharacter in t.enemies_in(from, 2.0):
			t.status(e, StatusController.Type.SLOW, 1.0)


## B — Trap, Sound, Delayed trigger. A destructible seal records the first
## jutsu cast within 7 m (anyone). Recast while it lives: it replays only
## that jutsu's sound and telegraph from the seal — no real effect — and is
## spent (one recording).
class SceauDEcho extends Technique:
	const LISTEN: float = 7.0

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.recovery_time = 0.15
		a.max_range = 9.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		for old: KitObject in t.objects("sceau_echo"):
			old.destroy("replaced")
		t.object(K.placed(t, t.origin, t.aim), {"kind": "sceau_echo", "radius": 0.5, "lifetime": 20.0, "health": 10.0,
			"look": KitObject.Look.GLYPH, "color": Color(0.7, 0.6, 1.0), "tick_interval": 0.1, "data": {"recorded": false},
			"on_tick": func(o: KitObject) -> void:
				_listen(t, o)})

	func _listen(t: Tk, o: KitObject) -> void:
		if o.data.get("recorded", false):
			return
		for f: CombatCharacter in t.fighters():
			if f.is_dead() or t.distance(f.global_position, o.global_position) > LISTEN or not f.abilities.is_casting():
				continue
			var cur: AbilityData = f.abilities.current
			if cur == null or f.abilities.is_basic_attack(cur) or cur.source_id == id:
				continue
			o.data["recorded"] = true
			o.data["sig"] = {"color": cur.color, "radius": clampf(maxf(cur.hit_radius * 2.0, cur.max_range * 0.4), 1.2, 4.0),
				"delay": clampf(cur.startup_time, 0.25, 0.8), "anim": cur.anim}
			t.fx("ring", o.global_position, 1.0, Color(0.7, 0.6, 1.0))
			t.recast(maxf(o.lifetime - o.age, 0.5), func(rt: Tk) -> void:
				_replay(rt, o))
			return

	func _replay(t: Tk, o: KitObject) -> void:
		if not is_instance_valid(o) or not o.is_alive():
			return
		var sig: Dictionary = o.data.get("sig", {})
		var at: Vector3 = o.global_position
		o.destroy("replayed")
		var col: Color = sig.get("color", Color.WHITE)
		var r: float = float(sig.get("radius", 2.0))
		Sfx.play(&"charge", at)
		t.fx("ember", at, 0.8, col)
		# Telegraph only: a ring then a harmless flash, nothing is hit.
		t.object(at, {"kind": "echo", "radius": r, "lifetime": float(sig.get("delay", 0.5)), "look": KitObject.Look.RING,
			"targetable": false, "color": col,
			"on_expire": func(e: KitObject) -> void:
				if t.alive():
					t.fx("burst", e.global_position, r, col)
					Sfx.play(&"boom", e.global_position, -6.0)})
