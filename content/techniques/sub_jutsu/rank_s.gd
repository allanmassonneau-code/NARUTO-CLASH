extends RefCounted
## Technique kit: Sub-jutsu rang S (design bible §6, "Rang S"). Universal
## ultimates without a signature: each one is a special rule with a real
## risk (debt, symmetric rule, setup, consent condition). Per-technique state
## lives in modifiers, marks and objects. Low-level helpers (cast hooks,
## chakra tax, cooldown edits, Marque maudite corruption) are shared with
## the rank A file: RankA.H.

const KIT_ID := &"sub_rank_s"
const SIGNATURE = null
const TECHNIQUES := {
	&"sub_s_hiraishin_reseau_des_marques": HiraishinReseau,
	&"sub_s_huit_portes_porte_de_la_vue": PorteDeLaVue,
	&"sub_s_marque_maudite_stade_ii": MarqueMauditeStadeII,
	&"sub_s_barriere_spatio_temporelle": BarriereSpatioTemporelle,
	&"sub_s_legion_des_clones_d_ombre": LegionDesClones,
	&"sub_s_sphere_spirale_effondrement": SphereSpirale,
	&"sub_s_domaine_d_extinction_du_chakra": DomaineExtinction,
	&"sub_s_transfert_celeste_interdit": TransfertCeleste,
}

const RankA := preload("res://content/techniques/sub_jutsu/rank_a.gd")
const CURSE := Color(0.55, 0.2, 0.75)


## S — Teleport network, Setup, Recast. Casting off-mark places a
## space-time mark at the aim (max 4, 45 s, 20 HP, visible) for 15 chakra
## and a 2 s cooldown. Casting with 4 marks, or aiming at one of your marks,
## opens the 6 s window (full cost / cooldown): each recast teleports to
## the unused mark nearest the aim (each mark once), keeping momentum, new
## facing toward the aim, 0.12 s materialisation immunity. Enemies never move.
class HiraishinReseau extends Technique:
	const MAX_MARKS: int = 4
	const MARK_LIFE: float = 45.0
	const WINDOW: float = 6.0
	const MARK_COST: float = 15.0
	const GOLD := Color(1.0, 0.85, 0.3)

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.15
		a.recovery_time = 0.15
		a.max_range = 14.0
		a.anim = &"throw"

	func cast(t: Tk) -> void:
		var marks: Array[KitObject] = t.objects("hiraishin")
		var on_mark: bool = false
		for m: KitObject in marks:
			if t.distance(m.global_position, t.aim) < 2.5:
				on_mark = true
		if marks.size() >= MAX_MARKS or on_mark:
			_open_window(t)
			return
		# Setup: a mark only costs a fraction of the ultimate and a short cooldown.
		t.caster.energy.restore(maxf(t.ability.energy_cost - MARK_COST, 0.0))
		RankA.H.set_cooldown(t.caster, RankA.H.slot_of(t), 2.0)
		t.fx("bolt", t.aim, 0.8, GOLD)
		t.object(t.aim, {"kind": "hiraishin", "radius": 0.7, "lifetime": MARK_LIFE, "health": 20.0,
			"look": KitObject.Look.GLYPH, "color": GOLD})
		t.text(t.caster, "MARQUE %d/%d" % [marks.size() + 1, MAX_MARKS])

	func _open_window(t: Tk) -> void:
		t.text(t.caster, "HIRAISHIN")
		t.fx("bolt", t.origin, 1.5, GOLD)
		var win: KitObject = t.object(t.origin, {"kind": "hiraishin_fenetre", "radius": 0.1, "lifetime": WINDOW,
			"look": KitObject.Look.NONE, "targetable": false})
		_arm(t, win)

	func _arm(t: Tk, win: KitObject) -> void:
		if not is_instance_valid(win) or not win.is_alive():
			return
		var left: float = win.lifetime - win.age
		if left <= 0.1 or t.objects("hiraishin").is_empty():
			win.destroy("done")
			return
		t.recast(left, func(rt: Tk) -> void: _jump(rt, win))

	func _jump(t: Tk, win: KitObject) -> void:
		var best: KitObject = null
		var best_d: float = INF
		for m: KitObject in t.objects("hiraishin"):
			var d: float = t.distance(m.global_position, t.aim)
			if d < best_d:
				best_d = d
				best = m
		if best == null:
			return
		var momentum: Vector3 = HitQuery.flat(t.caster.velocity)
		var dest: Vector3 = best.global_position
		best.destroy("used")
		RankA.H.teleport(t, t.caster, dest)
		t.fx("bolt", dest, 1.0, GOLD)
		t.caster.status.apply_status(StatusController.Type.IMMATERIAL, 0.12)
		t.caster.facing.update_aim(t.caster.global_position, t.caster.facing.aim_point)
		if momentum.length() > 0.5:
			t.caster.movement.apply_forced_motion(momentum, 0.2, true)
		_arm(t, win)


## S — Extreme mode, Health debt, Lockout. Gate gauge 100, drains 14/s and
## faster with each physical action (basic 4, melee jutsu 12): +60 % speed,
## tenacity, +40 % basic damage, physical startup / recovery 80 % faster;
## basic hits release a short air wave. Closing (empty gauge or recast):
## Dette corporelle drains 25 % max HP over 4 s (non-lethal, heals don't
## clear it) and dashes are locked 3 s.
class PorteDeLaVue extends Technique:
	const KEY := "porte_vue"
	const DRAIN: float = 14.0
	const JADE := Color(0.3, 0.95, 0.75)

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.45
		a.recovery_time = 0.1
		a.max_range = 1.0
		a.anim = &"guard"

	func cast(t: Tk) -> void:
		t.fx("column", t.origin, 1.6, JADE)
		t.fx("wave", t.origin, 3.0, JADE)
		t.text(t.caster, "PORTE DE LA VUE")
		var state: Dictionary = {"gauge": 100.0}
		var tok: int = RankA.H.token()
		t.buff(KEY, 15.0, {"token": tok, "speed": 1.6, "basic_damage": 1.4, "tenacity": true, "label": "Porte 100%",
			"color": JADE,
			"on_tick": func(dt: float) -> void:
				state.gauge = float(state.gauge) - DRAIN * dt
				RankA.H.quicken_physical(t.caster, dt, 0.8)
				if t.kit().modifiers.has(KEY):
					t.kit().modifiers[KEY].props.label = "Porte %d%%" % maxi(0, int(state.gauge))
				if float(state.gauge) <= 0.0:
					t.kit().remove_modifier(KEY),
			"on_deal": func(target: CombatCharacter, hit: HitData, _dmg: float) -> Variant:
				if hit != null and hit.ability != null and t.caster.abilities.is_basic_attack(hit.ability):
					_wave(t, target)
				return null,
			"on_end": func() -> void: _debt(t)})
		RankA.H.hook_mod(t.caster, &"cast_activated", KEY, tok, func(_slot: StringName, a: AbilityData) -> void:
			if t.caster.abilities.is_basic_attack(a):
				state.gauge = float(state.gauge) - 4.0
			elif RankA.H.is_physical(t.caster, a):
				state.gauge = float(state.gauge) - 12.0)
		t.recast(15.0, func(rt: Tk) -> void: rt.kit().remove_modifier(KEY))

	## Short air wave behind the struck target (deferred: not inside the hit pipeline).
	func _wave(t: Tk, target: CombatCharacter) -> void:
		t.after(0.01, func(rt: Tk) -> void:
			if not rt.is_enemy(target):
				return
			var away: Vector3 = HitQuery.flat(target.global_position - rt.caster.global_position)
			var at: Vector3 = HitQuery.flat(target.global_position) - (away.normalized() if away.length() > 0.1 else rt.dir) * 0.6
			rt.fx("wave", HitQuery.flat(target.global_position), 1.2, JADE)
			rt.area(at, 1.5, rt.dmg(0.12), {"push": 1.5}))

	func _debt(t: Tk) -> void:
		if not t.alive():
			return
		t.kit().close_recast(t.id)
		var total: float = t.caster.health.max_health * 0.25
		var f: CombatCharacter = t.caster
		t.buff("dette_corporelle", 4.0, {"label": "Dette corporelle", "color": Color(0.8, 0.2, 0.2), "speed": 0.85,
			"on_tick": func(dt: float) -> void:
				if is_instance_valid(f):
					f.health.drain(total / 4.0 * dt)})
		for slot: StringName in AbilityController.SLOTS:
			var a: AbilityData = f.abilities.get_base_ability(slot)
			if a != null and (a.kind == AbilityData.Kind.DASH or a.kind == AbilityData.Kind.TELEPORT):
				RankA.H.set_cooldown(f, slot, maxf(f.abilities.get_cooldown_left(slot), 3.0))
		t.text(f, "DETTE")


## S — Transformation, Mutations, Corruption. Two mutations out of three,
## chosen at launch from the situation (no picker UI): Ailes (far aim / no
## enemy close: +30 % speed and a leap toward the aim), Carapace (low HP /
## surrounded: -30 % damage taken, tenacity), Membres (enemy in reach:
## +40 % basic, +15 % damage). The gauge fills 12/s (shared Corruption
## rises too); at saturation the mode stops dead and max chakra drops
## 30 % for 8 s. Recast: stop early, no burnout.
class MarqueMauditeStadeII extends Technique:
	const KEY := "marque_maudite_2"
	const RATE: float = 12.0

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.5
		a.recovery_time = 0.15
		a.max_range = 12.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var muts: Array[String] = _choose(t)
		var state: Dictionary = {"gauge": 0.0, "saturated": false}
		var props: Dictionary = {"label": "Stade II : %s" % " + ".join(PackedStringArray(muts)), "color": CURSE}
		t.fx("spikes", t.origin, 1.6, CURSE)
		t.text(t.caster, " + ".join(PackedStringArray(muts)).to_upper())
		if muts.has("Ailes"):
			props.speed = 1.3
			t.dash(minf(5.0, t.distance(t.origin, t.aim)), t.dir, 0.25)
		if muts.has("Carapace"):
			props.damage_taken = 0.7
			props.tenacity = true
		if muts.has("Membres"):
			props.basic_damage = 1.4
			props.damage_dealt = 1.15
		props.on_tick = func(dt: float) -> void:
			state.gauge = float(state.gauge) + RATE * dt
			RankA.H.add_corruption(t.caster, 0.5 * dt)
			if float(state.gauge) >= 100.0:
				state.saturated = true
				t.kit().remove_modifier(KEY)
		props.on_end = func() -> void:
			if not t.alive():
				return
			t.kit().close_recast(t.id)
			if state.saturated:
				_burnout(t)
		RankA.H.add_corruption(t.caster, 1.0)
		t.buff(KEY, 20.0, props)
		t.recast(20.0, func(rt: Tk) -> void: rt.kit().remove_modifier(KEY))

	func _choose(t: Tk) -> Array[String]:
		var close: CombatCharacter = t.nearest_enemy(t.origin, 3.0)
		var around: int = t.enemies_in(t.origin, 5.0).size()
		var scores: Array = [
			[t.distance(t.origin, t.aim) / 12.0 + (0.4 if t.nearest_enemy(t.origin, 6.0) == null else 0.0), "Ailes"],
			[1.0 - t.caster.health.get_ratio() + 0.2 * around, "Carapace"],
			[0.5 + (0.5 if close != null else 0.0), "Membres"],
		]
		scores.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
		var out: Array[String] = []
		out.append(String(scores[0][1]))
		out.append(String(scores[1][1]))
		return out

	func _burnout(t: Tk) -> void:
		var f: CombatCharacter = t.caster
		var cut: float = floorf(f.energy.max_energy * 0.3)
		f.energy.max_energy -= cut
		f.energy.sync_state(minf(f.energy.current_energy, f.energy.max_energy))
		t.fx("implosion", t.origin, 1.5, CURSE)
		t.text(f, "SATURATION")
		var state: Dictionary = {"done": false}
		var holder: KitObject = t.object(t.origin, {"kind": "saturation", "radius": 0.1, "lifetime": 8.0,
			"look": KitObject.Look.NONE, "targetable": false})
		t.buff("saturation_maudite", 8.0, {"label": "Chakra max -30%", "color": CURSE})
		holder.tree_exiting.connect(func() -> void:
			if state.done or not is_instance_valid(f):
				return
			state.done = true
			f.energy.max_energy += cut
			f.energy.energy_changed.emit(f.energy.current_energy, f.energy.max_energy))


## S — Portal shield, Capture projectile, Recast. A wide portal (5 m) in
## front for 1 s: non-ultimate enemy projectiles entering it are removed
## and stored as Masse; frontal ranged non-melee, non-zone hits from 3.5 m+
## are nullified and stored too (linear techniques). Recast (5 s): exit at
## the aim, one neutral wave whose size / push / capped damage grow with
## the Masse. Nothing captured = a puff.
class BarriereSpatioTemporelle extends Technique:
	const OPEN: float = 1.0
	const WINDOW: float = 5.0
	const VOID := Color(0.6, 0.45, 1.0)

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.1
		a.recovery_time = 0.2
		a.max_range = 8.0
		a.anim = &"guard"

	func cast(t: Tk) -> void:
		var state: Dictionary = {"mass": 0}
		var facing: Vector3 = t.dir
		var portal: KitObject = t.wall(t.origin + t.dir * 1.3, t.dir, 5.0, OPEN, {"kind": "portail", "thickness": 1.2,
			"blocks_movement": false, "blocks_projectiles": true, "health": -1.0, "targetable": false, "color": VOID})
		portal.on_projectile = func(team: int, point: Vector3) -> bool: return _capture(t, state, team, point)
		t.buff("portail_st", OPEN, {"label": "Portail", "color": VOID,
			"on_take": func(hit: HitData, dmg: float) -> Variant: return _absorb_line(t, state, facing, hit, dmg)})
		t.recast(WINDOW, func(rt: Tk) -> void: _release(rt, state))

	func _capture(t: Tk, state: Dictionary, team: int, point: Vector3) -> bool:
		var best: Node3D = null
		var best_d: float = 1.5
		for group: StringName in [&"tk_projectiles", &"projectiles"]:
			for node: Node in t.tree().get_nodes_in_group(group):
				var n := node as Node3D
				if n == null or int(n.get("team")) != team:
					continue
				var d: float = t.distance(n.global_position, point)
				if d < best_d:
					best_d = d
					best = n
		if best is TkProjectile and RankA.H.is_ultimate_source((best as TkProjectile).caster, (best as TkProjectile).technique_id):
			return false
		if best is Projectile and RankA.H.is_ultimate((best as Projectile).ability):
			return false
		state.mass = int(state.mass) + 1
		t.fx("implosion", point, 0.6, VOID)
		return true

	func _absorb_line(t: Tk, state: Dictionary, facing: Vector3, hit: HitData, dmg: float) -> Variant:
		if hit == null or hit.ability == null or not is_instance_valid(hit.source) or hit.source == t.caster:
			return null
		var a: AbilityData = hit.ability
		if hit.source.abilities.is_basic_attack(a) or RankA.H.is_ultimate(a) or a.kind == AbilityData.Kind.MELEE_ARC \
				or a.kind == AbilityData.Kind.GROUND_AREA or a.kind == AbilityData.Kind.DASH:
			return null
		var to: Vector3 = HitQuery.flat(hit.source.global_position - t.caster.global_position)
		if to.length() < 3.5 or to.normalized().dot(facing) < 0.5:
			return null
		state.mass = int(state.mass) + 1
		t.fx("implosion", t.caster.global_position + facing * 1.3, 0.6, VOID)
		return 0.0 * dmg

	func _release(t: Tk, state: Dictionary) -> void:
		var mass: int = int(state.mass)
		var exit: Vector3 = t.aim
		t.object(exit, {"kind": "sortie", "radius": 1.0, "lifetime": 0.4, "look": KitObject.Look.RING, "targetable": false, "color": VOID})
		if mass <= 0:
			t.fx("smoke", exit, 0.8, VOID)
			t.text(t.caster, "VIDE")
			return
		var reach: float = minf(1.8 + 0.5 * mass, 5.0)
		t.fx("wave", exit + t.dir * reach * 0.5, reach, VOID)
		t.cone(reach, 110.0, t.dmg(minf(0.25 * mass, 1.2)), {"push": minf(2.0 + 0.8 * mass, 7.0)}, exit - t.dir * 0.5, t.dir)


## S — Multi-body, Shared command, Resource split. 7 fragile clones (5 HP)
## take 45 % of the caster's current chakra as their pool. Up to 3 orders
## (recasts, 5 s each), each consuming a third of the pool; the order is
## read from the situation: clones next to an enemy -> synchronized basic
## strike; enemy under the aim -> encircle it (slow, +10 % damage taken
## while 3+ clones stand around); else -> charge the aim (contact hits).
class LegionDesClones extends Technique:
	const COUNT: int = 7
	const LIFE: float = 14.0
	const ORDER_WINDOW: float = 5.0
	const FLAME := Color(1.0, 0.6, 0.2)

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.35
		a.recovery_time = 0.2
		a.max_range = 12.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		for old: KitObject in t.objects("legion"):
			old.destroy("replaced")
		var invested: float = RankA.H.tax(t.caster, t.caster.energy.current_energy * 0.45)
		var group: Dictionary = {"pool": invested, "orders": 0}
		t.fx("smoke", t.origin, 3.0)
		for i in COUNT:
			var offset: Vector3 = t.dir.rotated(Vector3.UP, TAU * i / COUNT) * 2.0
			t.object(t.origin + offset, {"kind": "legion", "radius": 0.45, "lifetime": LIFE, "health": 5.0,
				"look": KitObject.Look.DECOY, "color": FLAME,
				"data": {"mode": "formation", "offset": offset, "goal": t.origin + offset, "target": null, "hit": []},
				"on_tick": func(o: KitObject) -> void: _move(t, o),
				"on_destroy": func(o: KitObject, _reason: String) -> void: t.fx("smoke", o.global_position, 0.6)})
		t.text(t.caster, "LÉGION")
		_arm(t, group)

	func _arm(t: Tk, group: Dictionary) -> void:
		if int(group.orders) >= 3 or t.objects("legion").is_empty():
			return
		t.recast(ORDER_WINDOW, func(rt: Tk) -> void: _order(rt, group))

	func _order(t: Tk, group: Dictionary) -> void:
		var clones: Array[KitObject] = t.objects("legion")
		if clones.is_empty():
			return
		group.orders = int(group.orders) + 1
		group.pool = float(group.pool) - float(group.pool) / float(4 - int(group.orders))
		var adjacent: int = 0
		for c: KitObject in clones:
			if t.nearest_enemy(c.global_position, 1.8) != null:
				adjacent += 1
		var target: CombatCharacter = t.target_at_aim(3.0)
		if adjacent >= 2:
			_strike(t, clones)
		elif target != null:
			_encircle(t, clones, target)
		else:
			_charge(t, clones, t.aim)
		if int(group.orders) >= 3:
			for c: KitObject in clones:
				c.lifetime = minf(c.lifetime, c.age + 2.5)  # the pool is spent: the legion fades
		_arm(t, group)

	func _charge(t: Tk, clones: Array[KitObject], at: Vector3) -> void:
		t.text(t.caster, "CHARGE")
		var side: Vector3 = t.dir.cross(Vector3.UP)
		for i in clones.size():
			var c: KitObject = clones[i]
			c.data.mode = "charge"
			c.data.goal = at + side * (float(i) - clones.size() * 0.5) * 0.6
			c.data.hit = []

	func _encircle(t: Tk, clones: Array[KitObject], target: CombatCharacter) -> void:
		t.text(target, "ENCERCLÉ")
		for i in clones.size():
			var c: KitObject = clones[i]
			c.data.mode = "encircle"
			c.data.target = target
			c.data.offset = Vector3.FORWARD.rotated(Vector3.UP, TAU * i / clones.size()) * 1.5

	func _strike(t: Tk, clones: Array[KitObject]) -> void:
		var per_target: Dictionary = {}
		for c: KitObject in clones:
			var e: CombatCharacter = t.nearest_enemy(c.global_position, 2.2)
			if e == null:
				continue
			var n: int = int(per_target.get(e.get_instance_id(), 0))
			per_target[e.get_instance_id()] = n + 1
			t.fx("burst", e.global_position, 0.6, FLAME)
			t.hit(e, t.dmg(0.2 * pow(0.8, n)))
		t.text(t.caster, "FRAPPE")

	func _move(t: Tk, o: KitObject) -> void:
		if not t.alive():
			o.destroy("owner")
			return
		var dt: float = o.get_physics_process_delta_time()
		var mode: String = o.data.mode
		var goal: Vector3 = o.data.goal
		if mode == "formation":
			goal = HitQuery.flat(t.caster.global_position) + (o.data.offset as Vector3)
		elif mode == "encircle":
			var target: CombatCharacter = o.data.target
			if not t.is_enemy(target):
				o.data.mode = "formation"
				return
			goal = HitQuery.flat(target.global_position) + (o.data.offset as Vector3)
			if t.distance(o.global_position, target.global_position) < 2.2:
				var around: int = 0
				for c: KitObject in t.objects("legion"):
					if c.data.mode == "encircle" and t.distance(c.global_position, target.global_position) < 2.2:
						around += 1
				if around >= 3:
					t.status(target, StatusController.Type.SLOW, 0.3)
					t.debuff(target, "encercle", 0.3, {"damage_taken": 1.1, "label": "Encerclé", "color": FLAME})
		o.global_position = o.global_position.move_toward(goal, 11.0 * dt)
		if mode == "charge":
			var hit: Array = o.data.hit
			for e: CombatCharacter in t.enemies_in(o.global_position, 0.6):
				if not hit.has(e):
					hit.append(e)
					t.hit(e, t.dmg(0.15), {"push": 0.8, "push_from": o.global_position})
			if o.global_position.distance_to(goal) < 0.1:
				o.data.mode = "hold"


## S — Charged melee projectile, Knockback, Recast. Long visible formation
## (0.75 s, interruptible), then the sphere is held 3 s while advancing
## slowly: touching an enemy (or landing a basic hit) collapses it at
## melee — 0.25 s suction, then a violent expulsion (1.6 dmg, push, short
## stun). Recast: throw it (6 m) — wider collapse, less damage.
class SphereSpirale extends Technique:
	const KEY := "sphere_spirale"
	const HOLD: float = 3.0
	const SPIRAL := Color(0.45, 0.75, 1.0)

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.75
		a.cast_move_multiplier = 0.4
		a.recovery_time = 0.15
		a.max_range = 6.0
		a.anim = &"palm"

	func cast(t: Tk) -> void:
		t.fx("spheres", t.origin + t.dir * 0.8, 0.6, SPIRAL)
		var state: Dictionary = {"done": false}
		t.buff(KEY, HOLD, {"speed": 0.7, "label": "Sphère spirale", "color": SPIRAL,
			"on_tick": func(_dt: float) -> void: _contact(t, state),
			"on_deal": func(target: CombatCharacter, hit: HitData, _dmg: float) -> Variant:
				if not state.done and hit != null and hit.ability != null and t.caster.abilities.is_basic_attack(hit.ability):
					state.done = true
					var at: Vector3 = HitQuery.flat(target.global_position)
					t.after(0.01, func(rt: Tk) -> void:
						rt.kit().remove_modifier(KEY)
						rt.kit().close_recast(rt.id)
						_collapse(rt, at, false))
				return null})
		t.recast(HOLD, func(rt: Tk) -> void: _throw(rt, state))

	func _contact(t: Tk, state: Dictionary) -> void:
		if state.done or not t.alive():
			return
		var f: CombatCharacter = t.caster
		var front: Vector3 = HitQuery.flat(f.global_position) + HitQuery.flat(f.facing.facing_direction).normalized() * 0.9
		var e: CombatCharacter = t.nearest_enemy(front, 0.8)
		if e != null:
			state.done = true
			t.kit().remove_modifier(KEY)
			t.kit().close_recast(t.id)
			_collapse(t.refreshed(), HitQuery.flat(e.global_position), false)

	func _throw(t: Tk, state: Dictionary) -> void:
		if state.done:
			return
		state.done = true
		t.kit().remove_modifier(KEY)
		t.projectile({"speed": 16.0, "range": 6.0, "radius": 0.8, "size": 0.45, "color": SPIRAL,
			"on_hit": func(_e: CombatCharacter, _p: TkProjectile) -> bool: return false,
			"on_end": func(point: Vector3, _p: TkProjectile, _reason: String) -> void: _collapse(t, point, true)})

	func _collapse(t: Tk, at: Vector3, thrown: bool) -> void:
		var r: float = 3.0 if thrown else 1.8
		t.fx("implosion", at, r, SPIRAL)
		for e: CombatCharacter in t.enemies_in(at, r + 0.5):
			t.pull(e, at, 1.2, 0.2)
		t.after(0.25, func(rt: Tk) -> void:
			rt.fx("explosion", at, r, SPIRAL)
			if thrown:
				rt.area(at, r, rt.dmg(1.0), {"push": 4.0})
			else:
				rt.area(at, r, rt.dmg(1.6), {"push": 5.5, "stun": 0.4}))


## S — Domaine, Anti-cast, Symmetric rule. A 7 m domain around the caster
## for 9 s. Every jutsu cast inside adds an Extinction charge to its caster
## (owner included); at 3 charges, that fighter's next jutsu gets +1 s of
## mudra (startup) and the charges reset. Basic attacks / tools are free.
## Outside, charges drop one every 1.5 s.
class DomaineExtinction extends Technique:
	const R: float = 7.0
	const LIFE: float = 9.0
	const MARK := "extinction"
	const DELAY: float = 1.0
	const DUSK := Color(0.35, 0.25, 0.5)

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.45
		a.recovery_time = 0.2
		a.max_range = 1.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		for old: KitObject in t.objects("domaine_extinction"):
			old.destroy("replaced")
		t.fx("wave", t.origin, R, DUSK)
		var dom: KitObject = t.zone(t.origin, R, LIFE, {"kind": "domaine_extinction", "look": KitObject.Look.RING,
			"targetable": false, "tick_interval": 0.25, "color": DUSK, "data": {"out": {}},
			"on_tick": func(o: KitObject) -> void: _tick(t, o)})
		for f: CombatCharacter in t.fighters():
			_watch(t, dom, f)

	func _watch(t: Tk, dom: KitObject, f: CombatCharacter) -> void:
		var active := func() -> bool: return is_instance_valid(dom) and dom.is_alive()
		RankA.H.hook(f, &"cast_started", active, func(_slot: StringName, a: AbilityData) -> void:
			if RankA.H.is_jutsu(f, a) and f.kit.mark(MARK) >= 3:
				f.kit.consume_mark(MARK)
				f.abilities.phase_elapsed -= DELAY
				t.fx("implosion", f.global_position, 1.0, DUSK)
				t.text(f, "EXTINCTION"))
		RankA.H.hook(f, &"cast_activated", active, func(_slot: StringName, a: AbilityData) -> void:
			if RankA.H.is_jutsu(f, a) and dom.contains(f.global_position):
				t.mark(f, MARK, 1, 6.0, 3, "Extinction"))

	func _tick(t: Tk, o: KitObject) -> void:
		var out: Dictionary = o.data.out
		for f: CombatCharacter in t.fighters():
			if f.kit.mark(MARK) <= 0:
				continue
			var key: int = f.get_instance_id()
			if o.contains(f.global_position):
				f.kit.marks[MARK].left = maxf(float(f.kit.marks[MARK].left), 6.0)
				out[key] = 0.0
			else:
				out[key] = float(out.get(key, 0.0)) + 0.25
				if float(out[key]) >= 1.5:
					out[key] = 0.0
					f.kit.marks[MARK].stacks = int(f.kit.marks[MARK].stacks) - 1
					if int(f.kit.marks[MARK].stacks) <= 0:
						f.kit.consume_mark(MARK)
					f.kit.changed.emit()


## S — Target reposition, Ally rescue, Enemy consent condition. Marks a
## destination at the aim; recast (7 s) on the fighter nearest the aim:
## an ally (0.75 s channel, rescue) or an enemy ALREADY under hard control
## from another source (2 s channel with a long red alert on it). The
## caster being stunned or the target walking 2.5 m away breaks it; at the
## end the target is moved to the mark. Never starts an abduction alone.
class TransfertCeleste extends Technique:
	const WINDOW: float = 7.0
	const HEAVEN := Color(1.0, 0.9, 0.5)

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.recovery_time = 0.15
		a.max_range = 14.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		for old: KitObject in t.objects("transfert_dest"):
			old.destroy("replaced")
		var dest: KitObject = t.object(t.aim, {"kind": "transfert_dest", "radius": 1.0, "lifetime": WINDOW + 3.0,
			"look": KitObject.Look.GLYPH, "targetable": false, "color": HEAVEN})
		_arm(t, dest, WINDOW)

	func _arm(t: Tk, dest: KitObject, seconds: float) -> void:
		t.recast(seconds, func(rt: Tk) -> void: _begin(rt, dest),
			func() -> void:
				if is_instance_valid(dest) and dest.is_alive():
					dest.destroy("unused"))

	func _begin(t: Tk, dest: KitObject) -> void:
		if not is_instance_valid(dest) or not dest.is_alive():
			return
		var target: CombatCharacter = null
		var best_d: float = INF
		for ally: CombatCharacter in t.allies_in(t.aim, 3.0, false):
			var d: float = t.distance(ally.global_position, t.aim)
			if d < best_d:
				best_d = d
				target = ally
		var hostile: bool = false
		if target == null:
			var enemy: CombatCharacter = t.target_at_aim(3.0)
			if enemy != null and RankA.H.hard_cc(enemy):
				target = enemy
				hostile = true
		if target == null:
			t.text(t.caster, "AUCUNE CIBLE")
			var left: float = dest.lifetime - dest.age - 3.0
			if left > 0.2:
				_arm(t, dest, left)
			else:
				dest.destroy("unused")
			return
		var count: int = 8 if hostile else 3
		var to: Vector3 = dest.global_position
		var anchor: Vector3 = HitQuery.flat(target.global_position)
		dest.lifetime = dest.age + count * 0.25 + 0.5
		var alert: KitObject = t.object(anchor, {"kind": "transfert_alerte", "radius": 1.3, "lifetime": count * 0.25 + 0.3,
			"look": KitObject.Look.RING, "targetable": false, "color": Color(1.0, 0.25, 0.2) if hostile else HEAVEN})
		t.text(target, "TRANSFERT")
		t.channel(count, 0.25, func(ct: Tk, _i: int) -> void:
			ct.fx("ring", to, 1.0, HEAVEN)
			if is_instance_valid(target):
				ct.fx("ring", target.global_position, 1.3, Color(1.0, 0.25, 0.2) if hostile else HEAVEN),
			func(ct: Tk, completed: bool) -> void:
				if is_instance_valid(alert) and alert.is_alive():
					alert.destroy("done")
				var valid: bool = is_instance_valid(target) and not target.is_dead() \
					and ct.distance(target.global_position, anchor) <= 2.5
				if not completed or not valid:
					ct.text(ct.caster, "ROMPU")
					return
				RankA.H.teleport(ct, target, to)
				ct.fx("column", to, 1.0, HEAVEN), 0.2)
