extends RefCounted
## Technique kit: Uzumaki (design bible §5, Konoha). Signature: Glyphes — up
## to 4 active Glyphs per Uzumaki, on the ground ("glyphe" KitObjects,
## visible, destructible) or on a fighter ("glyphe" mark). Placing a 5th
## removes the oldest. Other techniques bind, link or consume them. The
## count is shown as the "glyphes" resource.

const KIT_ID := &"clan_uzumaki"
const SIGNATURE = UzumakiSignature
const TECHNIQUES := {
	&"clan_uzumaki_d_fuda_d_entrave": FudaDEntrave,
	&"clan_uzumaki_c_chaine_de_scellement": ChaineDeScellement,
	&"clan_uzumaki_b_barriere_quadrillee": BarriereQuadrillee,
	&"clan_uzumaki_a_sceau_de_renversement": SceauDeRenversement,
	&"clan_uzumaki_s_chaines_adamantines_prison_des_huit_sceaux": PrisonDesHuitSceaux,
}

const GLYPH := "glyphe"
const GLYPH_MAX: int = 4
const GLYPH_TIME: float = 12.0
const GLYPHES_RES := "glyphes"
const ENTRAVE := "entrave"
const ECHO := "echo"
const VERROU := "verrou"
const SEAL := Color(0.95, 0.3, 0.35)
const CHAIN := Color(0.4, 0.85, 1.0)


## Glyphes: HUD count of the active Glyphs.
class UzumakiSignature extends KitSignature:
	func setup(f: CombatCharacter) -> void:
		f.kit.define_resource(GLYPHES_RES, float(GLYPH_MAX), "Glyphes", SEAL)

	func tick(f: CombatCharacter, _delta: float) -> void:
		if not f.is_inside_tree() or not f.kit.resources.has(GLYPHES_RES):
			return
		var n: float = float(K.glyphs(f).size())
		if not is_equal_approx(f.kit.res(GLYPHES_RES), n):
			f.kit.resources[GLYPHES_RES].value = n
			f.kit.changed.emit()


## Shared Uzumaki rules (Glyphs, chains, geometry).
class K:
	static func now() -> float:
		return Time.get_ticks_msec() / 1000.0

	## Every active Glyph of `c`, oldest first (KitObjects and marked fighters).
	static func glyphs(c: CombatCharacter) -> Array[Node3D]:
		var out: Array[Node3D] = []
		for o: KitObject in KitObject.find(c.get_tree(), c, &"", GLYPH):
			out.append(o)
		for node: Node in c.get_tree().get_nodes_in_group(&"fighters"):
			var f := node as CombatCharacter
			if f != null and not f.is_dead() and f.kit.marks.has(GLYPH) and f.kit.mark_source(GLYPH) == c:
				out.append(f)
		out.sort_custom(func(a: Node3D, b: Node3D) -> bool: return born(a) < born(b))
		return out

	static func born(n: Node3D) -> float:
		if n is KitObject:
			return float((n as KitObject).data.get("born", 0.0))
		var f := n as CombatCharacter
		return float(f.kit.marks[GLYPH].get("born", 0.0)) if f.kit.marks.has(GLYPH) else 0.0

	## Still a valid Glyph of `c` (alive object, or fighter still marked).
	static func valid(c: CombatCharacter, n: Variant) -> bool:
		if n == null or not is_instance_valid(n):
			return false
		if n is KitObject:
			return (n as KitObject).is_alive()
		var f := n as CombatCharacter
		return f != null and not f.is_dead() and f.kit.marks.has(GLYPH) and f.kit.mark_source(GLYPH) == c

	static func remove(n: Node3D) -> void:
		if n is KitObject:
			(n as KitObject).destroy("consumed")
		elif n is CombatCharacter:
			(n as CombatCharacter).kit.consume_mark(GLYPH)

	## Keeps at most GLYPH_MAX Glyphs (the oldest goes).
	static func cap(c: CombatCharacter) -> void:
		var all: Array[Node3D] = glyphs(c)
		while all.size() > GLYPH_MAX:
			remove(all[0])
			all.remove_at(0)

	## Ground Glyph (visible, destructible).
	static func ground(t: Tk, at: Vector3, type: String = "neutre") -> KitObject:
		var o: KitObject = t.object(at, {"kind": GLYPH, "radius": 0.8, "lifetime": GLYPH_TIME, "health": 15.0,
			"look": KitObject.Look.GLYPH, "color": SEAL, "data": {"born": now(), "type": type}})
		cap(t.caster)
		return o

	## Glyph carried by a fighter (enemy or ally).
	static func tag(t: Tk, f: CombatCharacter, type: String = "neutre") -> void:
		if f == null or f.is_dead():
			return
		t.mark(f, GLYPH, 1, GLYPH_TIME, 1, "Glyphe")
		if f.kit.marks.has(GLYPH):
			f.kit.marks[GLYPH]["born"] = now()
			f.kit.marks[GLYPH]["type"] = type
		cap(t.caster)

	## Valid Glyphs of the caster sorted by distance to `point`, within `radius`.
	static func near(t: Tk, point: Vector3, radius: float) -> Array[Node3D]:
		var out: Array[Node3D] = []
		for g: Node3D in glyphs(t.caster):
			if t.distance(g.global_position, point) <= radius:
				out.append(g)
		out.sort_custom(func(a: Node3D, b: Node3D) -> bool:
			return t.distance(a.global_position, point) < t.distance(b.global_position, point))
		return out

	static func seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
		var ab: Vector3 = HitQuery.flat(b - a)
		var ap: Vector3 = HitQuery.flat(p - a)
		var l2: float = ab.length_squared()
		var k: float = 0.0 if l2 < 0.0001 else clampf(ap.dot(ab) / l2, 0.0, 1.0)
		return (ap - ab * k).length()

	## The flat segments [p0, p1] and [a, b] cross.
	static func crosses(p0: Vector3, p1: Vector3, a: Vector3, b: Vector3) -> bool:
		var d1: float = _orient(a, b, p0)
		var d2: float = _orient(a, b, p1)
		var d3: float = _orient(p0, p1, a)
		var d4: float = _orient(p0, p1, b)
		return d1 * d2 < 0.0 and d3 * d4 < 0.0

	static func _orient(a: Vector3, b: Vector3, p: Vector3) -> float:
		return (b.x - a.x) * (p.z - a.z) - (b.z - a.z) * (p.x - a.x)

	static func line(t: Tk, col: Color) -> MeshInstance3D:
		return KitVisuals.line_visual(t.caster.get_parent(), col) if CombatFx.is_enabled() else null

	static func draw(mi: Variant, a: Vector3, b: Vector3) -> void:
		if mi != null and is_instance_valid(mi):
			(mi as MeshInstance3D).visible = true
			KitVisuals.update_line(mi, a, b)

	static func hide(mi: Variant) -> void:
		if mi != null and is_instance_valid(mi):
			(mi as MeshInstance3D).visible = false

	static func free_lines(lines: Array) -> void:
		for mi: Variant in lines:
			if mi != null and is_instance_valid(mi):
				(mi as Node).queue_free()

	## Rank S technique (ultimates are never absorbed).
	static func is_ult(a: AbilityData, id: StringName = &"") -> bool:
		if a != null and a.technique != null and a.technique.jutsu != null:
			return a.technique.jutsu.rank >= 4
		var s: String = String(a.source_id if a != null else id)
		return s.contains("_s_")

	## Neutral wave category of an ability: explosion, ligne or cone.
	static func category(a: AbilityData) -> String:
		if a == null:
			return "cone"
		match a.kind:
			AbilityData.Kind.PROJECTILE, AbilityData.Kind.DASH:
				return "ligne"
			AbilityData.Kind.GROUND_AREA:
				return "explosion"
			AbilityData.Kind.SCRIPTED:
				if a.technique != null and a.technique.jutsu != null:
					var tags: Array[StringName] = a.technique.jutsu.tags
					if tags.has(&"PROJECTILE") or tags.has(&"RANGED") or tags.has(&"HITSCAN"):
						return "ligne"
					if tags.has(&"AOE"):
						return "explosion"
		return "cone"


## D — Tag, Debuff conditionnel, Setup. Short seal projectile. On an enemy:
## Glyphe d'entrave — its first dash (or blink) before expiry is cut short
## and consumes the seal; mobility is never prevented. On the ground: a
## neutral Glyph.
class FudaDEntrave extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.1
		a.recovery_time = 0.2
		a.max_range = 9.0
		a.anim = &"throw"

	func cast(t: Tk) -> void:
		t.projectile({"speed": 24.0, "range": 9.0, "radius": 0.5, "size": 0.15, "color": SEAL,
			"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
				t.hit(e, t.dmg(0.35))
				K.tag(t, e, ENTRAVE)
				_hinder(t, e)
				return false,
			"on_end": func(point: Vector3, _p: TkProjectile, reason: String) -> void:
				if reason != "hit":
					K.ground(t, point)})

	## Watches the target's mobility: one dash shortened, one blink pulled back.
	func _hinder(t: Tk, e: CombatCharacter) -> void:
		if not t.is_enemy(e):
			return
		var state: Dictionary = {"pos": HitQuery.flat(e.global_position)}
		t.debuff(e, ENTRAVE, GLYPH_TIME, {"label": "Entrave", "color": SEAL,
			"on_tick": func(_dt: float) -> void:
				_watch(t, e, state)})

	func _watch(t: Tk, e: CombatCharacter, state: Dictionary) -> void:
		if not is_instance_valid(e) or e.is_dead():
			return
		if not K.valid(t.caster, e):
			e.kit.remove_modifier(ENTRAVE)
			return
		var mv: MovementComponent = e.movement
		var p: Vector3 = HitQuery.flat(e.global_position)
		var triggered: bool = false
		if mv.is_forced() and not mv.is_knockback and mv.forced_speed() > 14.0:
			mv._forced_time_left *= 0.45  # dash shortened
			triggered = true
		elif t.distance(p, state.pos) > 2.5:
			var back: Vector3 = (state.pos as Vector3).lerp(p, 0.55)  # blink shortened
			e.global_position = Vector3(back.x, 0.0, back.z)
			triggered = true
		state.pos = HitQuery.flat(e.global_position)
		if triggered:
			e.kit.consume_mark(GLYPH)
			e.kit.remove_modifier(ENTRAVE)
			t.fx("sparks", e.global_position, 0.8, SEAL)
			t.text(e, "ENTRAVÉ", SEAL)


## C — Tether, Ancre, Recast. A chakra chain from the Uzumaki to the Glyph
## nearest the aim (ground or carried); with none in reach a chain head is
## thrown and plants a Glyph on what it reaches. Breaks beyond range or when
## the Glyph dies. Recast (after a short delay): on a ground Glyph = grapple
## to it; on a fighter = both are pulled halfway toward each other.
class ChaineDeScellement extends Technique:
	const MAX_DIST: float = 12.0

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.15
		a.recovery_time = 0.2
		a.max_range = 11.0
		a.anim = &"throw"

	func cast(t: Tk) -> void:
		var near: Array[Node3D] = K.near(t, t.aim, 3.5)
		if not near.is_empty() and t.distance(near[0].global_position, t.origin) <= MAX_DIST:
			_bind(t, near[0])
			return
		t.projectile({"speed": 28.0, "range": 11.0, "radius": 0.5, "size": 0.14, "color": CHAIN,
			"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
				t.hit(e, t.dmg(0.3))
				K.tag(t, e)
				_bind(t, e)
				return false,
			"on_end": func(point: Vector3, _p: TkProjectile, reason: String) -> void:
				if reason != "hit":
					_bind(t, K.ground(t, point))})

	func _bind(t: Tk, anchor: Node3D) -> void:
		if not t.alive() or not K.valid(t.caster, anchor):
			return
		var mi: MeshInstance3D = K.line(t, CHAIN)
		var chain: KitObject = t.object(t.caster.global_position, {"kind": "chaine", "radius": 0.1, "lifetime": 6.0,
			"look": KitObject.Look.NONE, "targetable": false, "data": {"anchor": anchor},
			"on_tick": func(o: KitObject) -> void:
				if not t.alive() or not K.valid(t.caster, anchor) \
						or t.distance(t.caster.global_position, anchor.global_position) > MAX_DIST:
					o.destroy("broken")
					return
				o.global_position = HitQuery.flat(t.caster.global_position)
				K.draw(mi, t.caster.global_position, anchor.global_position),
			"on_destroy": func(_o: KitObject, _reason: String) -> void:
				K.free_lines([mi])
				t.kit().close_recast(t.id)})
		t.after(0.3, func(rt: Tk) -> void:
			if chain.is_alive():
				rt.recast(5.5, func(r2: Tk) -> void:
					_reel(r2, chain)))

	func _reel(t: Tk, chain: KitObject) -> void:
		if not chain.is_alive():
			return
		var anchor: Node3D = chain.data.anchor
		chain.destroy("reeled")
		if not K.valid(t.caster, anchor):
			return
		var to: Vector3 = HitQuery.flat(anchor.global_position - t.origin)
		var gap: float = to.length() - 1.2
		if gap <= 0.1:
			return
		t.fx("sparks", anchor.global_position, 0.8, CHAIN)
		if anchor is KitObject:
			t.dash(gap, to.normalized(), 0.22)  # grapple: the Glyph is the heavy point
		else:
			var f := anchor as CombatCharacter
			t.dash(gap * 0.5, to.normalized(), 0.2)  # shared: both move
			t.pull(f, t.origin, gap * 0.5)
			if t.is_enemy(f):
				t.text(f, "TIRÉ", CHAIN)


## B — Barrière, Réseau, Anti-projectile. Links up to 3 Glyphs near the aim
## with barrier segments (6 s). Fighters walk through; enemy projectiles
## lose 40 % speed and 35 % power per segment crossed. A carried Glyph is a
## moving vertex; a segment vanishes if a vertex dies or gets too far.
## With fewer than 2 Glyphs available, ground Glyphs are planted first.
class BarriereQuadrillee extends Technique:
	const MAX_SEG: float = 12.0

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.25
		a.recovery_time = 0.2
		a.max_range = 10.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var side: Vector3 = t.dir.cross(Vector3.UP)
		var spots: Array[Vector3] = [t.aim + side * 2.5, t.aim - side * 2.5]
		var have: Array[Node3D] = K.near(t, t.aim, MAX_SEG)
		var k: int = 0
		while have.size() + k < 2 and k < spots.size():
			K.ground(t, spots[k])
			k += 1
		var verts: Array[Node3D] = K.near(t, t.aim, MAX_SEG)
		verts = verts.slice(0, 3)
		if verts.size() < 2:
			return
		var segs: Array = [[verts[0], verts[1]]]
		if verts.size() == 3:
			segs.append([verts[1], verts[2]])
			segs.append([verts[2], verts[0]])
		var lines: Array = []
		for s: Array in segs:
			lines.append(K.line(t, SEAL))
		t.fx("ring", t.aim, 2.0, SEAL)
		t.object(t.aim, {"kind": "barriere", "look": KitObject.Look.NONE, "radius": 0.5, "lifetime": 6.0,
			"targetable": false, "data": {"segs": segs, "lines": lines, "dead": {}},
			"on_tick": func(o: KitObject) -> void:
				_tick(t, o),
			"on_destroy": func(o: KitObject, _reason: String) -> void:
				K.free_lines(o.data.lines)})

	func _tick(t: Tk, o: KitObject) -> void:
		var segs: Array = o.data.segs
		var dead: Dictionary = o.data.dead
		var live: Array[int] = []
		for i in segs.size():
			if dead.has(i):
				continue
			var a: Variant = segs[i][0]
			var b: Variant = segs[i][1]
			if not K.valid(t.caster, a) or not K.valid(t.caster, b) \
					or t.distance((a as Node3D).global_position, (b as Node3D).global_position) > MAX_SEG:
				dead[i] = true
				K.hide(o.data.lines[i])
				continue
			live.append(i)
			K.draw(o.data.lines[i], (a as Node3D).global_position, (b as Node3D).global_position)
		if live.is_empty():
			o.destroy("broken")
			return
		var oid: int = o.get_instance_id()
		for node: Node in t.tree().get_nodes_in_group(&"tk_projectiles"):
			var p := node as TkProjectile
			if p == null or p.team == t.caster.team or not p.is_alive():
				continue
			for i: int in live:
				var key: String = "uzu_%d_%d" % [oid, i]
				if not p.has_meta(key) and K.seg_dist(p.ground_point(), (segs[i][0] as Node3D).global_position,
						(segs[i][1] as Node3D).global_position) < 0.5:
					p.set_meta(key, true)
					_weaken_tk(p)
		for node: Node in t.tree().get_nodes_in_group(&"projectiles"):
			var q := node as Projectile
			if q == null or q.team == t.caster.team or q.visual_only or q.ability == null:
				continue
			var at: Vector3 = HitQuery.flat(q.global_position)
			for i: int in live:
				var key: String = "uzu_%d_%d" % [oid, i]
				if not q.has_meta(key) and K.seg_dist(at, (segs[i][0] as Node3D).global_position,
						(segs[i][1] as Node3D).global_position) < 0.5:
					q.set_meta(key, true)
					var weaker: AbilityData = q.ability.duplicate() as AbilityData
					weaker.damage *= 0.65
					weaker.projectile_speed *= 0.6
					q.ability = weaker
					t.fx("sparks", at, 0.5, SEAL)

	## Script projectile: slower, and its hits deal less (its caster gets a
	## damage modifier just for the duration of the on-hit callback).
	func _weaken_tk(p: TkProjectile) -> void:
		p.speed *= 0.6
		p.set_meta("uzu_weak", int(p.get_meta("uzu_weak", 0)) + 1)
		KitVisuals.fx(p, "sparks", p.ground_point(), 0.5, SEAL)
		if p.has_meta("uzu_wrapped"):
			return
		p.set_meta("uzu_wrapped", true)
		var original: Callable = p.on_hit
		p.on_hit = func(e: CombatCharacter, proj: TkProjectile) -> bool:
			var c: CombatCharacter = proj.caster
			var mult: float = pow(0.65, int(proj.get_meta("uzu_weak", 0)))
			if is_instance_valid(c):
				c.kit.add_modifier("barriere_affaiblie", 0.05, {"damage_dealt": mult})
			var keep: bool = false
			if original.is_valid():
				keep = bool(original.call(e, proj))
			if is_instance_valid(c):
				c.kit.remove_modifier("barriere_affaiblie")
			return keep


## A — Contre, Stockage, Redistribution. Large destructible Glyph: the first
## hostile projectile crossing it, zone dropped on it, or technique hitting
## an ally standing on it (halved) is absorbed and stored as one Écho
## (category explosion / ligne / cone, capped power). Ultimates are never
## absorbed. Recast: an Écho Glyph at the aim releases a neutral wave of
## that category.
class SceauDeRenversement extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.recovery_time = 0.2
		a.max_range = 9.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		t.fx("ring", t.aim, 3.0, SEAL)
		var seal: KitObject = t.object(t.aim, {"kind": "glyphe_renversement", "look": KitObject.Look.GLYPH, "radius": 3.0,
			"lifetime": 8.0, "health": 40.0, "color": SEAL, "tick_interval": 0.1, "data": {"used": false},
			"on_tick": func(o: KitObject) -> void:
				_watch(t, o)})
		seal.on_projectile = func(_team: int, point: Vector3) -> bool:
			return _projectile(t, seal, point)

	## A hostile projectile reaches the seal.
	func _projectile(t: Tk, seal: KitObject, point: Vector3) -> bool:
		if seal.data.used:
			return false
		for node: Node in t.tree().get_nodes_in_group(&"tk_projectiles"):
			var p := node as TkProjectile
			if p != null and p.team != t.caster.team and t.distance(p.global_position, point) < 1.0:
				if K.is_ult(null, p.technique_id):
					return false
				_absorb(t, seal, "ligne", t.dmg(0.8))
				return true
		for node: Node in t.tree().get_nodes_in_group(&"projectiles"):
			var q := node as Projectile
			if q != null and q.team != t.caster.team and q.ability != null and t.distance(q.global_position, point) < 1.0:
				if K.is_ult(q.ability) or q.source != null and is_instance_valid(q.source) and q.source.abilities.is_basic_attack(q.ability):
					return false
				_absorb(t, seal, "ligne", q.ability.damage)
				return true
		return false

	func _watch(t: Tk, o: KitObject) -> void:
		if o.data.used:
			return
		# Zones dropped on it.
		for node: Node in t.tree().get_nodes_in_group(&"kit_objects"):
			var z := node as KitObject
			if z != null and z != o and z.team != t.caster.team and z.is_alive() and z.age < 0.3 and z.kind != GLYPH \
					and o.contains(z.global_position) and not K.is_ult(null, z.technique_id):
				z.destroy("absorbed")
				_absorb(t, o, "explosion", t.dmg(0.8))
				return
		for node: Node in t.tree().get_nodes_in_group(&"ground_areas"):
			var g := node as GroundArea
			if g != null and g.team != t.caster.team and not g.visual_only and g.ability != null and g.elapsed < 0.3 \
					and o.contains(g.global_position) and not K.is_ult(g.ability):
				_absorb(t, o, "explosion", g.ability.damage)
				return
		# Allies standing on it: a hostile technique is halved and stored.
		for ally: CombatCharacter in o.allies_inside():
			t.debuff(ally, "renversement", 0.25, {"on_take": func(hit: HitData, dmg: float) -> Variant:
				if not o.is_alive() or o.data.used or not is_instance_valid(hit.source) or hit.source.team == t.caster.team:
					return null
				if hit.ability == null or hit.source.abilities.is_basic_attack(hit.ability) or K.is_ult(hit.ability):
					return null
				_absorb(t, o, K.category(hit.ability), dmg)
				return dmg * 0.5})

	func _absorb(t: Tk, seal: KitObject, category: String, raw: float) -> void:
		if seal.data.used:
			return
		seal.data.used = true
		var power: float = clampf(raw * 0.8, t.dmg(0.4), t.dmg(1.1))
		t.fx("implosion", seal.global_position, 2.0, SEAL)
		t.text(t.caster, "ÉCHO : " + category.to_upper(), SEAL)
		t.buff(ECHO, 12.0, {"label": "Écho : " + category, "color": SEAL, "category": category, "power": power})
		seal.destroy("absorbed")
		var release := func(rt: Tk) -> void:
			_release(rt)
		var expire := func() -> void:
			t.kit().remove_modifier(ECHO)
		t.recast(12.0, release, expire)

	func _release(t: Tk) -> void:
		if not t.kit().modifiers.has(ECHO):
			return
		var props: Dictionary = t.kit().modifiers[ECHO].props
		var category: String = props.category
		var power: float = props.power
		t.kit().remove_modifier(ECHO)
		var at: Vector3 = t.aim
		var d: Vector3 = t.dir
		t.object(at, {"kind": "glyphe_echo", "radius": 1.2, "lifetime": 0.4, "look": KitObject.Look.GLYPH, "targetable": false,
			"color": SEAL, "on_expire": func(_o: KitObject) -> void:
				if not t.alive():
					return
				if category == "explosion":
					t.fx("explosion", at, 3.0, SEAL)
					t.area(at, 3.0, power)
				elif category == "ligne":
					t.fx("wave", at, 1.5, SEAL)
					t.line(10.0, 1.2, power, {}, at, d)
				else:
					t.fx("wave", at + d * 2.0, 2.5, SEAL)
					t.cone(6.0, 70.0, power, {}, at, d)})


## S — Réseau, Capture progressive, Objectif. Eight destructible chakra
## spikes ring a wide area and chain to their neighbours and to the
## caster's Glyphs nearby (which reshape the prison). Every chain an enemy
## crosses adds a Verrou; 3 Verrous = brief root and reset. Chains never
## block; Verrous are dropped when leaving the area; a destroyed spike
## opens its chains.
class PrisonDesHuitSceaux extends Technique:
	const RADIUS: float = 6.5
	const LIFE: float = 9.0

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.6
		a.recovery_time = 0.3
		a.cast_move_multiplier = 0.2
		a.max_range = 10.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var center: Vector3 = t.aim
		var spikes: Array[Node3D] = []
		for i in 8:
			var at: Vector3 = center + t.dir.rotated(Vector3.UP, TAU * i / 8.0) * RADIUS
			spikes.append(t.object(at, {"kind": "pointe", "radius": 0.5, "lifetime": LIFE, "health": 30.0,
				"look": KitObject.Look.PILLAR, "color": CHAIN}))
		var edges: Array = []
		for i in 8:
			edges.append([spikes[i], spikes[(i + 1) % 8]])
		var inner: Array[Node3D] = K.near(t, center, RADIUS + 2.0)
		for g: Node3D in inner:
			var by_dist: Array[Node3D] = spikes.duplicate()
			by_dist.sort_custom(func(a: Node3D, b: Node3D) -> bool:
				return t.distance(a.global_position, g.global_position) < t.distance(b.global_position, g.global_position))
			edges.append([g, by_dist[0]])
			edges.append([g, by_dist[1]])
		for i in inner.size():
			for j in range(i + 1, inner.size()):
				if t.distance(inner[i].global_position, inner[j].global_position) <= 9.0:
					edges.append([inner[i], inner[j]])
		var lines: Array = []
		for e: Array in edges:
			lines.append(K.line(t, CHAIN))
		t.fx("spheres", center, RADIUS, CHAIN)
		t.object(center, {"kind": "prison", "look": KitObject.Look.NONE, "radius": RADIUS + 1.0, "lifetime": LIFE,
			"targetable": false, "data": {"edges": edges, "lines": lines, "spikes": spikes, "prev": {}, "cd": {}},
			"on_tick": func(o: KitObject) -> void:
				_tick(t, o),
			"on_destroy": func(o: KitObject, _reason: String) -> void:
				K.free_lines(o.data.lines)
				for s: Variant in o.data.spikes:
					if is_instance_valid(s) and (s as KitObject).is_alive():
						(s as KitObject).destroy("ended")})

	func _alive_vertex(t: Tk, n: Variant) -> bool:
		if n == null or not is_instance_valid(n):
			return false
		if n is KitObject:
			return (n as KitObject).is_alive()
		return K.valid(t.caster, n)

	func _tick(t: Tk, o: KitObject) -> void:
		var edges: Array = o.data.edges
		var live: Array[int] = []
		for i in edges.size():
			if _alive_vertex(t, edges[i][0]) and _alive_vertex(t, edges[i][1]):
				live.append(i)
				K.draw(o.data.lines[i], (edges[i][0] as Node3D).global_position, (edges[i][1] as Node3D).global_position)
			else:
				K.hide(o.data.lines[i])
		var prev: Dictionary = o.data.prev
		var cd: Dictionary = o.data.cd
		for e: CombatCharacter in t.enemies_in(o.global_position, RADIUS + 4.0):
			var key: int = e.get_instance_id()
			var cur: Vector3 = HitQuery.flat(e.global_position)
			if prev.has(key):
				for i: int in live:
					var a: Node3D = edges[i][0]
					var b: Node3D = edges[i][1]
					if a == e or b == e:
						continue
					var ck: String = "%d_%d" % [key, i]
					if o.age < float(cd.get(ck, -1.0)):
						continue
					if K.crosses(prev[key], cur, HitQuery.flat(a.global_position), HitQuery.flat(b.global_position)):
						cd[ck] = o.age + 0.15
						_lock(t, e)
			prev[key] = cur
			# Verrous expire when leaving the area.
			if t.distance(cur, o.global_position) > RADIUS + 1.0 and e.kit.mark_source(VERROU) == t.caster:
				e.kit.consume_mark(VERROU)

	func _lock(t: Tk, e: CombatCharacter) -> void:
		if not t.is_enemy(e):
			return
		var n: int = t.mark(e, VERROU, 1, 6.0, 3, "Verrou")
		t.fx("sparks", e.global_position, 0.6, CHAIN)
		if n >= 3:
			t.consume_mark(e, VERROU)
			t.status(e, StatusController.Type.ROOT, 0.9)
			t.hit(e, t.dmg(0.3))
			t.fx("spheres", e.global_position, 1.0, CHAIN)
			t.text(e, "SCELLÉ", CHAIN)
