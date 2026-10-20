extends RefCounted
## Technique kit: Sub-jutsu rang A (design bible §6, "Rang A"). Sub-jutsu are
## universal (no signature): each one carries its own special rule — a
## resource tax, a health debt, a swap, a cooldown manipulation... Their
## per-technique state lives in modifiers, marks and objects. Low-level
## helpers shared with rank_s.gd live in H (chakra tax, cast hooks on a
## fighter's AbilityController, cooldown edits, Marque maudite corruption).

const KIT_ID := &"sub_rank_a"
const SIGNATURE = null
const TECHNIQUES := {
	&"sub_a_reseau_de_clones_relais": ReseauDeClonesRelais,
	&"sub_a_barriere_des_quatre_coins": BarriereDesQuatreCoins,
	&"sub_a_huit_portes_porte_de_la_vie": PorteDeLaVie,
	&"sub_a_marque_d_echange_spatio_temporel": MarqueDEchange,
	&"sub_a_surcadencage_du_reseau_de_chakra": Surcadencage,
	&"sub_a_marque_maudite_stade_i": MarqueMauditeStadeI,
	&"sub_a_orbite_des_mille_senbon": OrbiteDesMilleSenbon,
	&"sub_a_sceau_de_suppression_majeure": SceauDeSuppression,
	&"sub_a_invocation_faucon_de_relais": FauconDeRelais,
	&"sub_a_reservoir_de_chakra_scelle": ReservoirDeChakra,
}

const CURSE := Color(0.55, 0.2, 0.75)


## Shared low-level rules (also used by rank_s.gd). The Tk API has no
## chakra-cost / mudra-speed / cooldown hooks, so these work directly on
## the fighter's EnergyComponent and AbilityController (signals
## cast_started / cast_activated, phase_elapsed, cooldowns).
class H:
	const CORRUPTION := "corruption_maudite"

	## A technique (not a basic attack, dash or tool).
	static func is_jutsu(f: CombatCharacter, a: AbilityData) -> bool:
		if a == null or f == null or not is_instance_valid(f) or f.abilities.is_basic_attack(a):
			return false
		return a.energy_cost > 0.0 or a.source_id != &""

	static func is_ultimate(a: AbilityData) -> bool:
		if a == null:
			return false
		if a.energy_cost >= 100.0:
			return true
		return a.technique != null and a.technique.jutsu != null and a.technique.jutsu.rank >= ProgressionTypes.Rank.S

	## Ultimate status of a TkProjectile's technique, looked up on its caster.
	static func is_ultimate_source(f: CombatCharacter, technique_id: StringName) -> bool:
		if f == null or not is_instance_valid(f):
			return false
		for slot: StringName in AbilityController.SLOTS:
			var a: AbilityData = f.abilities.get_base_ability(slot)
			if a != null and a.source_id == technique_id:
				return is_ultimate(a)
		return false

	## Physical action: basic attack string or a melee technique.
	static func is_physical(f: CombatCharacter, a: AbilityData) -> bool:
		return a != null and (f.abilities.is_basic_attack(a) or a.kind == AbilityData.Kind.MELEE_ARC)

	## Calls fn(slot, ability) on each `sig` (&"cast_started" / &"cast_activated")
	## of `f` while active() is true; disconnects itself afterwards.
	static func hook(f: CombatCharacter, sig: StringName, active: Callable, fn: Callable) -> void:
		if f == null or not is_instance_valid(f) or not f.is_inside_tree():
			return
		var h := CastHook.new()
		h.active = active
		h.fn = fn
		f.add_child(h)
		f.abilities.connect(sig, h.on_cast)

	## hook() alive while modifier `key` of `f` carries `token`.
	static func hook_mod(f: CombatCharacter, sig: StringName, key: String, token: int, fn: Callable) -> void:
		hook(f, sig, func() -> bool:
			if not is_instance_valid(f) or not f.kit.modifiers.has(key):
				return false
			return int(f.kit.modifiers[key].props.get("token", -1)) == token, fn)

	static func token() -> int:
		return randi()

	## Removes up to `amount` chakra (extra cost); returns what was taken.
	static func tax(f: CombatCharacter, amount: float) -> float:
		if f == null or not is_instance_valid(f):
			return 0.0
		var take: float = minf(maxf(amount, 0.0), f.energy.current_energy)
		if take > 0.0:
			f.energy.sync_state(f.energy.current_energy - take)
		return take

	static func set_cooldown(f: CombatCharacter, slot: StringName, seconds: float) -> void:
		if slot != &"" and f.abilities._cooldowns.has(slot):
			f.abilities._cooldowns[slot] = maxf(seconds, 0.0)

	static func slot_of(t: Tk) -> StringName:
		return t.caster.abilities.slot_of(t.ability)

	## Startup / recovery of physical actions run `extra` faster.
	static func quicken_physical(f: CombatCharacter, dt: float, extra: float) -> void:
		var ab: AbilityController = f.abilities
		if ab.current == null or ab.phase == AbilityController.Phase.IDLE or ab.phase == AbilityController.Phase.ACTIVE:
			return
		if is_physical(f, ab.current):
			ab.phase_elapsed += dt * extra

	## Self-propelled dash / blink (not a knockback).
	static func is_dashing(e: CombatCharacter) -> bool:
		if e.movement.is_forced() and not e.movement.is_knockback:
			return true
		if e.abilities.is_casting() and e.abilities.current != null:
			var k: AbilityData.Kind = e.abilities.current.kind
			return k == AbilityData.Kind.DASH or k == AbilityData.Kind.TELEPORT or k == AbilityData.Kind.SUBSTITUTION
		return false

	## Instant relocation (ignores walls, unlike Tk.blink).
	static func teleport(t: Tk, f: CombatCharacter, dest: Vector3) -> void:
		if f == null or not is_instance_valid(f) or f.is_dead():
			return
		t.fx("smoke", f.global_position, 0.8)
		f.movement.stop()
		f.global_position = Vector3(dest.x, 0.0, dest.z)
		t.fx("smoke", dest, 0.8)

	static func hard_cc(e: CombatCharacter) -> bool:
		for type: StatusController.Type in [StatusController.Type.STUN, StatusController.Type.INCAPACITATE,
				StatusController.Type.LAUNCHED, StatusController.Type.ROOT]:
			if e.status.has_status(type):
				return true
		return false

	## Marque maudite Corruption (shared by Stade I and Stade II): a modifier
	## on the fighter. >= 3: chakra regen halved; >= 6: slow non-lethal HP
	## loss. Decays slowly once no curse mode is active.
	static func add_corruption(f: CombatCharacter, amount: float) -> float:
		if not f.kit.has_modifier(CORRUPTION):
			f.kit.add_modifier(CORRUPTION, 9999.0, {"value": 0.0, "chakra_regen": 1.0, "label": "Corruption 0", "color": CURSE,
				"on_tick": func(dt: float) -> void: _corruption_tick(f, dt)})
		var p: Dictionary = f.kit.modifiers[CORRUPTION].props
		p.value = float(p.value) + amount
		_corruption_refresh(p)
		return float(p.value)

	static func corruption(f: CombatCharacter) -> float:
		return float(f.kit.modifiers[CORRUPTION].props.value) if f.kit.has_modifier(CORRUPTION) else 0.0

	static func _corruption_tick(f: CombatCharacter, dt: float) -> void:
		if not is_instance_valid(f) or not f.kit.has_modifier(CORRUPTION):
			return
		var p: Dictionary = f.kit.modifiers[CORRUPTION].props
		if not (f.kit.has_modifier("marque_maudite_1") or f.kit.has_modifier("marque_maudite_2")):
			p.value = float(p.value) - 0.25 * dt
		if float(p.value) <= 0.0:
			f.kit.remove_modifier(CORRUPTION)
			return
		if float(p.value) >= 6.0:
			f.health.drain(1.5 * dt)
		_corruption_refresh(p)

	static func _corruption_refresh(p: Dictionary) -> void:
		p.chakra_regen = 0.5 if float(p.value) >= 3.0 else 1.0
		p.label = "Corruption %d" % int(p.value)


## Listener node parented to the fighter (freed with it, no reference cycle):
## forwards AbilityController cast signals while active() holds, then frees itself.
class CastHook extends Node:
	var active: Callable
	var fn: Callable

	func on_cast(slot: StringName, a: AbilityData) -> void:
		if is_queued_for_deletion():
			return
		if not bool(active.call()):
			queue_free()
			return
		fn.call(slot, a)


## A — Clones, Swap, Multi-position. Three fragile decoys (one hit, eat a
## projectile) in a triangle follow the caster with a lag and twitch when
## he starts a cast; no damage. Recast once: swap with the clone nearest the aim.
class ReseauDeClonesRelais extends Technique:
	const LIFE: float = 9.0

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.recovery_time = 0.15
		a.max_range = 14.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		for old: KitObject in t.objects("clone_relais"):
			old.destroy("replaced")
		t.fx("smoke", t.origin, 2.0)
		for i in 3:
			var offset: Vector3 = t.dir.rotated(Vector3.UP, PI / 3.0 + TAU / 3.0 * i) * 2.2
			var clone: KitObject = t.object(t.origin + offset, {"kind": "clone_relais", "radius": 0.5, "lifetime": LIFE,
				"health": 6.0, "look": KitObject.Look.DECOY, "color": Color(0.85, 0.85, 1.0), "data": {"offset": offset},
				"on_tick": func(o: KitObject) -> void: _follow(t, o),
				"on_destroy": func(o: KitObject, reason: String) -> void:
					if reason == "destroyed":
						t.fx("smoke", o.global_position, 0.7)})
			# A clone dies at the first serious impact: it eats one projectile.
			clone.on_projectile = func(_team: int, _point: Vector3) -> bool:
				if clone.is_alive():
					clone.destroy("destroyed")
				return true
		t.recast(LIFE, func(rt: Tk) -> void:
			var best: KitObject = null
			var best_d: float = INF
			for c: KitObject in rt.objects("clone_relais"):
				var d: float = rt.distance(c.global_position, rt.aim)
				if d < best_d:
					best_d = d
					best = c
			if best == null:
				return
			var from: Vector3 = HitQuery.flat(rt.caster.global_position)
			var to: Vector3 = best.global_position
			H.teleport(rt, rt.caster, to)
			best.global_position = from
			best.data["offset"] = from - to)

	func _follow(t: Tk, o: KitObject) -> void:
		if not t.alive():
			o.destroy("owner")
			return
		var dt: float = o.get_physics_process_delta_time()
		var target: Vector3 = HitQuery.flat(t.caster.global_position) + (o.data.offset as Vector3)
		o.global_position = o.global_position.lerp(target, clampf(dt * 4.0, 0.0, 1.0))
		# Mimic the start of the caster's animations.
		var ab: AbilityController = t.caster.abilities
		if ab.phase == AbilityController.Phase.STARTUP and ab.phase_elapsed <= dt + 0.001:
			t.fx("dust", o.global_position, 0.6)


## A — Setup, Prison ouverte, Objectif. Four pylons placed one by one
## (recasts, 5 s each); the 4th links them into a quadrilateral. Enemies
## crossing an intact side are taxed: their next jutsu within 4 s costs
## +75 % chakra (min 15). A destroyed pylon opens both its sides. Not closed
## in time = the pylons vanish.
class BarriereDesQuatreCoins extends Technique:
	const PLACE_WINDOW: float = 5.0
	const BARRIER_LIFE: float = 9.0
	const TAX_TIME: float = 4.0
	const TAX_KEY := "taxe_barriere"

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.25
		a.recovery_time = 0.15
		a.max_range = 10.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		for kind: String in ["pylone", "barriere_4c"]:
			for old: KitObject in t.objects(kind):
				old.destroy("replaced")
		_place(t, 1)

	func _place(t: Tk, n: int) -> void:
		t.fx("column", t.aim, 0.6, Color(0.5, 0.8, 1.0))
		t.object(t.aim, {"kind": "pylone", "radius": 0.5, "lifetime": 30.0, "health": 20.0, "look": KitObject.Look.PILLAR,
			"color": Color(0.5, 0.8, 1.0), "data": {"n": n}})
		if n < 4:
			t.recast(PLACE_WINDOW, func(rt: Tk) -> void: _place(rt, n + 1),
				func() -> void:
					if is_instance_valid(t.caster):
						for p: KitObject in t.objects("pylone"):
							p.destroy("unclosed"))
		else:
			_close(t)

	func _close(t: Tk) -> void:
		var pylons: Array[KitObject] = t.objects("pylone")
		if pylons.size() < 4:
			for p: KitObject in pylons:
				p.destroy("unclosed")
			t.text(t.caster, "OUVERT")
			return
		pylons.sort_custom(func(a: KitObject, b: KitObject) -> bool: return int(a.data.n) < int(b.data.n))
		var center: Vector3 = Vector3.ZERO
		for p: KitObject in pylons:
			center += p.global_position / 4.0
			p.lifetime = p.age + BARRIER_LIFE
		var reach: float = 0.0
		for p: KitObject in pylons:
			reach = maxf(reach, t.distance(p.global_position, center))
		var lines: Array = []
		if CombatFx.is_enabled():
			for i in 4:
				lines.append(KitVisuals.line_visual(t.caster.get_parent(), Color(0.5, 0.8, 1.0)))
		t.fx("ring", center, reach, Color(0.5, 0.8, 1.0))
		var barrier: KitObject = t.zone(center, reach + 1.0, BARRIER_LIFE, {"kind": "barriere_4c", "look": KitObject.Look.NONE,
			"targetable": false, "data": {"last": {}},
			"on_tick": func(o: KitObject) -> void: _tick(t, o, pylons, lines),
			"on_destroy": func(_o: KitObject, _reason: String) -> void:
				for p: KitObject in pylons:
					if is_instance_valid(p) and p.is_alive():
						p.destroy("expired")})
		barrier.tree_exiting.connect(func() -> void:
			for mi: Variant in lines:
				if is_instance_valid(mi):
					(mi as Node).queue_free())

	func _tick(t: Tk, o: KitObject, pylons: Array[KitObject], lines: Array) -> void:
		var last: Dictionary = o.data.last
		for i in 4:
			var a: KitObject = pylons[i]
			var b: KitObject = pylons[(i + 1) % 4]
			var up: bool = is_instance_valid(a) and a.is_alive() and is_instance_valid(b) and b.is_alive()
			if i < lines.size() and is_instance_valid(lines[i]):
				var mi: MeshInstance3D = lines[i]
				mi.visible = up
				if up:
					KitVisuals.update_line(mi, a.global_position + Vector3.UP * 0.8, b.global_position + Vector3.UP * 0.8)
		for e: CombatCharacter in t.fighters():
			if not t.is_enemy(e):
				continue
			var key: int = e.get_instance_id()
			var now: Vector3 = HitQuery.flat(e.global_position)
			if last.has(key) and _crossed(pylons, last[key], now):
				_taxed(t, e)
			last[key] = now

	func _crossed(pylons: Array[KitObject], from: Vector3, to: Vector3) -> bool:
		if from.distance_to(to) < 0.001:
			return false
		for i in 4:
			var a: KitObject = pylons[i]
			var b: KitObject = pylons[(i + 1) % 4]
			if not (is_instance_valid(a) and a.is_alive() and is_instance_valid(b) and b.is_alive()):
				continue  # destroyed pylon: this side is open
			var x: Variant = Geometry2D.segment_intersects_segment(Vector2(from.x, from.z), Vector2(to.x, to.z),
				Vector2(a.global_position.x, a.global_position.z), Vector2(b.global_position.x, b.global_position.z))
			if x != null:
				return true
		return false

	func _taxed(t: Tk, e: CombatCharacter) -> void:
		var tok: int = H.token()
		t.debuff(e, TAX_KEY, TAX_TIME, {"token": tok, "label": "Taxe de chakra", "color": Color(0.5, 0.8, 1.0)})
		t.fx("ring", e.global_position, 1.0, Color(0.5, 0.8, 1.0))
		t.text(e, "TAXE")
		H.hook_mod(e, &"cast_activated", TAX_KEY, tok, func(_slot: StringName, a: AbilityData) -> void:
			if H.is_jutsu(e, a):
				H.tax(e, maxf(15.0, a.energy_cost * 0.75))
				e.kit.remove_modifier(TAX_KEY))


## A — Transformation, HP cost, Tempo. Telegraphed Gate: 6 s of +35 % speed,
## +15 % basic damage and physical startup / recovery 60 % faster (no bonus
## to ranged jutsu). Each second open adds Fatigue; on closing (recast or
## timeout) it becomes non-lethal HP loss (3 % max HP / s open) and a slow.
class PorteDeLaVie extends Technique:
	const KEY := "porte_vie"
	const DURATION: float = 6.0

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.4
		a.recovery_time = 0.1
		a.max_range = 1.0
		a.anim = &"guard"

	func cast(t: Tk) -> void:
		t.fx("column", t.origin, 1.2, Color(0.35, 1.0, 0.5))
		t.text(t.caster, "PORTE DE LA VIE")
		var state: Dictionary = {"fatigue": 0.0}
		t.buff(KEY, DURATION, {"speed": 1.35, "basic_damage": 1.15, "label": "Porte de la Vie", "color": Color(0.35, 1.0, 0.5),
			"on_tick": func(dt: float) -> void:
				state.fatigue = float(state.fatigue) + dt
				H.quicken_physical(t.caster, dt, 0.6),
			"on_end": func() -> void: _close(t, float(state.fatigue))})
		t.recast(DURATION, func(rt: Tk) -> void: rt.kit().remove_modifier(KEY))

	func _close(t: Tk, fatigue: float) -> void:
		if not t.alive():
			return
		t.kit().close_recast(t.id)
		t.caster.health.drain(t.caster.health.max_health * 0.03 * fatigue)
		t.status(t.caster, StatusController.Type.SLOW, 0.5 * fatigue)
		t.text(t.caster, "FATIGUE")


## A — Two-point swap, Setup, Recast. Mark A, then recast for mark B (2.5 to
## 14 m from A). For 6 s, each recast swaps the light content of both
## doors: the caster, his shadow clone, his decoys and any projectile.
## Enemy fighters are never moved.
class MarqueDEchange extends Technique:
	const MAX_DIST: float = 14.0
	const DOOR: float = 1.4
	const SWAP_WINDOW: float = 6.0

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.15
		a.recovery_time = 0.15
		a.max_range = 14.0
		a.anim = &"throw"

	func cast(t: Tk) -> void:
		for old: KitObject in t.objects("porte_st"):
			old.destroy("replaced")
		var first: KitObject = _door(t, t.aim, 0)
		t.recast(5.0, func(rt: Tk) -> void: _second(rt, first),
			func() -> void:
				if is_instance_valid(first) and first.is_alive():
					first.destroy("unpaired"))

	func _door(t: Tk, at: Vector3, n: int) -> KitObject:
		t.fx("ring", at, DOOR, Color(1.0, 0.85, 0.35))
		return t.object(at, {"kind": "porte_st", "radius": DOOR, "lifetime": 12.0, "look": KitObject.Look.GLYPH,
			"targetable": false, "color": Color(1.0, 0.85, 0.35), "data": {"n": n}})

	func _second(t: Tk, first: KitObject) -> void:
		if not is_instance_valid(first) or not first.is_alive():
			cast(t)
			return
		var a: Vector3 = first.global_position
		var b: Vector3 = t.aim
		var to: Vector3 = HitQuery.flat(b - a)
		if to.length() > MAX_DIST:
			b = a + to.normalized() * MAX_DIST
		elif to.length() < 2.5:
			b = a + (to.normalized() if to.length() > 0.1 else t.dir) * 2.5
		var second: KitObject = _door(t, b, 1)
		first.lifetime = first.age + SWAP_WINDOW
		second.lifetime = second.age + SWAP_WINDOW
		_arm(t, first, second)

	func _arm(t: Tk, first: KitObject, second: KitObject) -> void:
		if not (is_instance_valid(second) and second.is_alive()):
			return
		var left: float = second.lifetime - second.age
		if left > 0.1:
			t.recast(left, func(rt: Tk) -> void:
				_swap(rt, first, second)
				_arm(rt, first, second))

	func _swap(t: Tk, first: KitObject, second: KitObject) -> void:
		if not (is_instance_valid(first) and first.is_alive() and is_instance_valid(second) and second.is_alive()):
			return
		var pa: Vector3 = first.global_position
		var pb: Vector3 = second.global_position
		var moves: Array = []  # [node, new_position]
		var nodes: Array[Node3D] = []
		nodes.append(t.caster)
		if is_instance_valid(t.caster.clone):
			nodes.append(t.caster.clone)
		for o: KitObject in t.objects("", &""):
			if o.look == KitObject.Look.DECOY:
				nodes.append(o)
		for group: StringName in [&"tk_projectiles", &"projectiles"]:
			for node: Node in t.tree().get_nodes_in_group(group):
				if node is Node3D and not node.is_queued_for_deletion():
					nodes.append(node as Node3D)
		for n: Node3D in nodes:
			var flat: Vector3 = HitQuery.flat(n.global_position)
			var lift: Vector3 = Vector3.UP * n.global_position.y
			if t.distance(flat, pa) <= DOOR:
				moves.append([n, pb + (flat - pa) + lift])
			elif t.distance(flat, pb) <= DOOR:
				moves.append([n, pa + (flat - pb) + lift])
		if moves.is_empty():
			t.text(t.caster, "VIDE")
			return
		t.fx("implosion", pa, DOOR, Color(1.0, 0.85, 0.35))
		t.fx("implosion", pb, DOOR, Color(1.0, 0.85, 0.35))
		for m: Array in moves:
			var n: Node3D = m[0]
			if not is_instance_valid(n):
				continue
			if n == t.caster:
				H.teleport(t, t.caster, m[1])
			else:
				n.global_position = m[1]


## A — Cooldown manipulation, Heat, Risk. For 6 s, the next non-ultimate
## jutsu gets 60 % of its cooldown back as it goes out (never the same jutsu
## twice in a row). The reset triggers Surchauffe: 6 s of +50 % chakra
## costs, and Surcadençage stays locked.
class Surcadencage extends Technique:
	const WINDOW: float = 6.0
	const REFUND: float = 0.6
	var _last_reset: StringName = &""

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.15
		a.recovery_time = 0.1
		a.max_range = 1.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		t.fx("sparks", t.origin, 1.4, Color(0.4, 0.8, 1.0))
		t.text(t.caster, "SURCADENÇAGE")
		var tok: int = H.token()
		t.buff("surcadencage", WINDOW, {"token": tok, "label": "Surcadençage", "color": Color(0.4, 0.8, 1.0)})
		H.hook_mod(t.caster, &"cast_activated", "surcadencage", tok, func(slot: StringName, a: AbilityData) -> void:
			if not H.is_jutsu(t.caster, a) or H.is_ultimate(a) or a.source_id == t.id:
				return
			var key: StringName = a.source_id if a.source_id != &"" else slot
			if key == _last_reset:
				t.text(t.caster, "DÉJÀ RELANCÉ")
				return
			_last_reset = key
			H.set_cooldown(t.caster, slot, t.caster.abilities.get_cooldown_left(slot) * (1.0 - REFUND))
			t.fx("sparks", t.caster.global_position, 1.0, Color(0.4, 0.8, 1.0))
			t.kit().remove_modifier("surcadencage")
			_overheat(t))

	func _overheat(t: Tk) -> void:
		var tok: int = H.token()
		t.buff("surchauffe", 6.0, {"token": tok, "label": "Surchauffe", "color": Color(1.0, 0.35, 0.2)})
		var own: StringName = H.slot_of(t)
		H.set_cooldown(t.caster, own, maxf(t.caster.abilities.get_cooldown_left(own), 6.0))
		H.hook_mod(t.caster, &"cast_activated", "surchauffe", tok, func(_slot: StringName, a: AbilityData) -> void:
			if H.is_jutsu(t.caster, a):
				H.tax(t.caster, a.energy_cost * 0.5))


## A — Mode, Resource corruption, Choice. 15 s mode (recast to stop): jutsu
## +20 % damage and 40 % faster mudra (startup), but every jutsu cast adds
## 1 Corruption (H): >= 3 halves chakra regen, >= 6 drains HP slowly.
## Corruption only decays once the mode is off.
class MarqueMauditeStadeI extends Technique:
	const MODE := "marque_maudite_1"
	const DURATION: float = 15.0

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.recovery_time = 0.15
		a.max_range = 1.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		t.fx("spikes", t.origin, 1.2, CURSE)
		t.text(t.caster, "MARQUE MAUDITE")
		var tok: int = H.token()
		t.buff(MODE, DURATION, {"token": tok, "label": "Marque maudite I", "color": CURSE,
			"on_deal": func(_target: CombatCharacter, hit: HitData, dmg: float) -> Variant:
				if hit != null and H.is_jutsu(t.caster, hit.ability):
					return dmg * 1.2
				return null})
		H.add_corruption(t.caster, 1.0)
		H.hook_mod(t.caster, &"cast_started", MODE, tok, func(_slot: StringName, a: AbilityData) -> void:
			if H.is_jutsu(t.caster, a):
				t.caster.abilities.phase_elapsed += a.startup_time * 0.4)
		H.hook_mod(t.caster, &"cast_activated", MODE, tok, func(_slot: StringName, a: AbilityData) -> void:
			if H.is_jutsu(t.caster, a) and a.source_id != t.id:
				var c: float = H.add_corruption(t.caster, 1.0)
				t.fx("spikes", t.caster.global_position, 0.6 + 0.1 * c, CURSE))
		t.recast(DURATION, func(rt: Tk) -> void: rt.kit().remove_modifier(MODE))


## A — Persistent projectiles, Trigger, Anti-mobility. A ring of 36 senbon
## at the aim. Any enemy dash / blink inside fires a 3-senbon salvo from the
## closest part of the ring (walking triggers nothing). Recast: a 0.5 s
## telegraph, then the rest converge on the centre (scales with ammo).
class OrbiteDesMilleSenbon extends Technique:
	const R: float = 4.5
	const LIFE: float = 9.0
	const STEEL := Color(0.75, 0.88, 1.0)

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.recovery_time = 0.2
		a.max_range = 11.0
		a.anim = &"throw"

	func cast(t: Tk) -> void:
		for old: KitObject in t.objects("orbite"):
			old.destroy("replaced")
		t.fx("sparks", t.aim, R, STEEL)
		var ring: KitObject = t.zone(t.aim, R, LIFE, {"kind": "orbite", "look": KitObject.Look.RING, "targetable": false,
			"color": STEEL, "data": {"ammo": 36, "cd": {}, "last": {}, "closing": false},
			"on_tick": func(o: KitObject) -> void: _watch(t, o)})
		t.recast(LIFE, func(rt: Tk) -> void: _close(rt, ring))

	func _watch(t: Tk, o: KitObject) -> void:
		if o.data.closing:
			return
		var dt: float = o.get_physics_process_delta_time()
		var cds: Dictionary = o.data.cd
		var last: Dictionary = o.data.last
		for e: CombatCharacter in t.enemies_in(o.global_position, R):
			var key: int = e.get_instance_id()
			var pos: Vector3 = HitQuery.flat(e.global_position)
			var blinked: bool = last.has(key) and t.distance(pos, last[key]) > 1.2
			last[key] = pos
			cds[key] = float(cds.get(key, 0.0)) - dt
			if float(cds[key]) > 0.0 or int(o.data.ammo) <= 0:
				continue
			if blinked or H.is_dashing(e):
				cds[key] = 0.7
				_salvo(t, o, e)

	func _salvo(t: Tk, o: KitObject, e: CombatCharacter) -> void:
		var to: Vector3 = HitQuery.flat(e.global_position - o.global_position)
		var d: Vector3 = to.normalized() if to.length() > 0.1 else t.dir
		var from: Vector3 = o.global_position + d * R
		o.data.ammo = int(o.data.ammo) - 3
		var toward: Vector3 = HitQuery.flat(e.global_position - from)
		if toward.length() < 0.1:
			toward = -d
		for i in 3:
			t.projectile({"from": from - toward.normalized() * 0.5, "dir": toward.normalized().rotated(Vector3.UP, deg_to_rad(-6.0 + 6.0 * i)),
				"speed": 30.0, "range": R * 2.0 + 1.0, "radius": 0.45, "size": 0.12, "color": STEEL,
				"on_hit": func(target: CombatCharacter, _p: TkProjectile) -> bool:
					t.hit(target, t.dmg(0.22), {"slow": 0.6})
					return false})

	func _close(t: Tk, ring: KitObject) -> void:
		if not is_instance_valid(ring) or not ring.is_alive():
			return
		ring.data.closing = true
		var ammo: int = int(ring.data.ammo)
		var at: Vector3 = ring.global_position
		t.telegraph(at, R, 0.5, func(rt: Tk) -> void:
			rt.fx("implosion", at, R, STEEL)
			for e: CombatCharacter in rt.enemies_in(at, R):
				var central: bool = rt.distance(e.global_position, at) <= 1.8
				rt.hit(e, rt.dmg(minf(0.2 + 0.02 * ammo, 0.9) + (0.3 if central else 0.0)), {"slow": 1.0})
			if is_instance_valid(ring) and ring.is_alive():
				ring.destroy("closed"))


## A — Skillshot, Chakra tax, Reveal. Slow talisman; on hit: Sceau (7 s):
## the target's jutsu cost +60 % (min 10) and every mudra pulses visibly.
## Removed by staying still 1 s, or by an ally of the target striking next
## to it (basic attack). No silence.
class SceauDeSuppression extends Technique:
	const KEY := "sceau_suppression"
	const DURATION: float = 7.0
	const PAPER := Color(0.95, 0.88, 0.55)

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.recovery_time = 0.3
		a.max_range = 13.0
		a.anim = &"throw"

	func cast(t: Tk) -> void:
		t.projectile({"speed": 9.0, "range": 13.0, "radius": 0.7, "size": 0.35, "color": PAPER,
			"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
				if t.hit(e, t.dmg(0.3)) == HitData.Result.HIT:
					_seal(t, e)
				return false})

	func _seal(t: Tk, e: CombatCharacter) -> void:
		if not t.is_enemy(e):
			return
		var tok: int = H.token()
		var state: Dictionary = {"still": 0.0, "pos": HitQuery.flat(e.global_position)}
		t.debuff(e, KEY, DURATION, {"token": tok, "label": "Sceau de suppression", "color": PAPER,
			"on_tick": func(dt: float) -> void: _tick(t, e, state, dt)})
		t.text(e, "SCELLÉ")
		H.hook_mod(e, &"cast_activated", KEY, tok, func(_slot: StringName, a: AbilityData) -> void:
			if H.is_jutsu(e, a):
				H.tax(e, maxf(10.0, a.energy_cost * 0.6)))
		H.hook_mod(e, &"cast_started", KEY, tok, func(_slot: StringName, a: AbilityData) -> void:
			if H.is_jutsu(e, a):
				t.fx("ring", e.global_position, 1.3, PAPER)
				t.text(e, "MUDRA"))

	func _tick(t: Tk, e: CombatCharacter, state: Dictionary, dt: float) -> void:
		if not is_instance_valid(e) or e.is_dead():
			return
		var pos: Vector3 = HitQuery.flat(e.global_position)
		if pos.distance_to(state.pos) > 0.15 or e.abilities.is_casting():
			state.still = 0.0
			state.pos = pos
		else:
			state.still = float(state.still) + dt
		var torn: bool = float(state.still) >= 1.0
		if not torn:
			for node: Node in e.get_tree().get_nodes_in_group(&"fighters"):
				var f := node as CombatCharacter
				if f == null or f == e or f.team != e.team or f.is_dead():
					continue
				if f.abilities.is_casting() and f.abilities.current != null and f.abilities.is_basic_attack(f.abilities.current) \
						and HitQuery.flat(f.global_position - e.global_position).length() <= 2.2:
					torn = true
		if torn:
			e.kit.remove_modifier(KEY)
			t.text(e, "ARRACHÉ")


## A — Summon, Vision, Mobility anchor. A hawk (20 HP, can be shot down)
## hovers over the aim for 10 s and pings enemies that move within 7 m
## (imprecise ring + "Repéré" label). Recast once: dash to it; it flees.
class FauconDeRelais extends Technique:
	const LIFE: float = 10.0
	const SIGHT: float = 7.0
	const FEATHER := Color(0.75, 0.55, 0.3)

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.25
		a.recovery_time = 0.15
		a.max_range = 12.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		for old: KitObject in t.objects("faucon"):
			old.destroy("replaced")
		t.fx("crows", t.aim, 1.2, FEATHER)
		var hawk: KitObject = t.object(t.aim, {"kind": "faucon", "radius": 0.6, "lifetime": LIFE, "health": 20.0,
			"look": KitObject.Look.ORB, "color": FEATHER, "tick_interval": 1.0, "data": {"last": {}},
			"on_tick": func(o: KitObject) -> void: _ping(t, o),
			"on_destroy": func(o: KitObject, reason: String) -> void:
				if reason == "destroyed":
					t.fx("crows", o.global_position, 1.0, FEATHER)})
		t.recast(LIFE, func(rt: Tk) -> void: _anchor(rt, hawk))

	func _ping(t: Tk, o: KitObject) -> void:
		var last: Dictionary = o.data.last
		for e: CombatCharacter in t.enemies_in(o.global_position, SIGHT):
			var key: int = e.get_instance_id()
			var pos: Vector3 = HitQuery.flat(e.global_position)
			var moved: bool = not last.has(key) or t.distance(pos, last[key]) > 0.5 or e.abilities.is_casting()
			last[key] = pos
			if moved:
				var jitter: Vector3 = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
				t.fx("ring", pos + jitter, 0.9, FEATHER)
				t.debuff(e, "repere_faucon", 1.2, {"label": "Repéré", "color": FEATHER})

	func _anchor(t: Tk, hawk: KitObject) -> void:
		if not is_instance_valid(hawk) or not hawk.is_alive():
			t.text(t.caster, "FAUCON PERDU")
			return
		var to: Vector3 = HitQuery.flat(hawk.global_position - t.caster.global_position)
		var dist: float = minf(to.length(), 16.0)
		if dist > 0.5:
			t.dash(dist, to.normalized(), clampf(dist / 22.0, 0.12, 0.5))
		t.fx("crows", hawk.global_position, 1.2, FEATHER)
		hawk.destroy("fled")


## A — Stored resource, Delayed payoff, Risk. Vulnerable 1.2 s channel
## (a stun breaks it), then 40 % of current chakra is sealed away and max
## chakra drops by as much. Recast (any time within 120 s): break the
## seal — max restored, stored chakra back, 2.5 s of CC immunity (no mudra
## interruption). Window lost / death: the stored chakra is gone.
class ReservoirDeChakra extends Technique:
	const FRACTION: float = 0.4
	const HOLD: float = 120.0
	const SEAL := Color(0.4, 0.7, 1.0)

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.recovery_time = 0.15
		a.max_range = 1.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		t.fx("spheres", t.origin, 1.2, SEAL)
		t.channel(4, 0.3, func(ct: Tk, _i: int) -> void:
			ct.fx("ring", ct.caster.global_position, 1.0, SEAL),
			func(dt: Tk, completed: bool) -> void:
				if completed:
					_seal(dt)
				else:
					dt.text(dt.caster, "INTERROMPU"), 0.25)

	func _seal(t: Tk) -> void:
		var f: CombatCharacter = t.caster
		var stored: float = floorf(f.energy.current_energy * FRACTION)
		if stored < 1.0:
			t.text(f, "VIDE")
			return
		f.energy.max_energy -= stored
		f.energy.sync_state(f.energy.current_energy - stored)
		var state: Dictionary = {"stored": stored, "restored": false}
		var seal: KitObject = t.object(f.global_position, {"kind": "reservoir", "radius": 0.4, "lifetime": HOLD,
			"look": KitObject.Look.NONE, "targetable": false,
			"on_tick": func(o: KitObject) -> void:
				if is_instance_valid(f):
					o.global_position = HitQuery.flat(f.global_position)})
		# Max chakra always comes back, whatever frees the seal (break, timeout, round end).
		seal.tree_exiting.connect(func() -> void: _restore_max(f, state))
		t.buff("reservoir_scelle", HOLD, {"label": "Réservoir %d" % int(stored), "color": SEAL})
		t.text(f, "SCELLÉ")
		t.recast(HOLD, func(rt: Tk) -> void:
			_restore_max(f, state)
			f.energy.restore(float(state.stored))
			rt.kit().remove_modifier("reservoir_scelle")
			rt.buff("reservoir_brise", 2.5, {"cc_immune": true, "label": "Sceau brisé", "color": SEAL})
			rt.fx("burst", rt.origin, 1.6, SEAL)
			rt.text(rt.caster, "SCEAU BRISÉ")
			if is_instance_valid(seal) and seal.is_alive():
				seal.destroy("broken"))

	func _restore_max(f: CombatCharacter, state: Dictionary) -> void:
		if state.restored or not is_instance_valid(f):
			return
		state.restored = true
		f.energy.max_energy += float(state.stored)
		f.energy.energy_changed.emit(f.energy.current_energy, f.energy.max_energy)
