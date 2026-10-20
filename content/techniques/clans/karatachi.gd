extends RefCounted
## Technique kit: clan_karatachi (design bible, Kiri). Signature:
## Calcification — techniques plant coral Nodes ("noeud" KitObjects, 5 max
## per caster, oldest crumbles first, destructible). A Node can hang on an
## enemy as a mobile Node (follows them, drops to the ground when it
## expires). Two Nodes can be linked by a Crête; mobile Nodes make coral
## pushes on their carrier easier to orient (pushed toward the aim side).
## The HUD shows the live Node count ("noeuds" resource).

const KIT_ID := &"clan_karatachi"
const SIGNATURE = KaratachiSignature
const TECHNIQUES := {
	&"clan_karatachi_d_epine_de_corail": EpineDeCorail,
	&"clan_karatachi_c_ecaille_recifale": EcailleRecifale,
	&"clan_karatachi_b_crete_jaillissante": CreteJaillissante,
	&"clan_karatachi_a_recif_predateur": RecifPredateur,
	&"clan_karatachi_s_sanctuaire_de_la_tortue_corallienne": SanctuaireTortue,
}

const NODE := "noeud"
const MAX_NODES: int = 5
const NODE_LIFE: float = 16.0
const MOBILE_LIFE: float = 3.0
## Max distance between two Nodes for a Crête / a Récif sprout.
const LINK_RANGE: float = 13.0
const CORAL := Color(1.0, 0.48, 0.55)
const CORAL_DARK := Color(0.85, 0.3, 0.4)


## Calcification: the Node count shown on the HUD.
class KaratachiSignature extends KitSignature:
	var _acc: float = 0.0

	func setup(f: CombatCharacter) -> void:
		f.kit.define_resource("noeuds", float(MAX_NODES), "Nœuds", CORAL)

	func tick(f: CombatCharacter, delta: float) -> void:
		_acc += delta
		if _acc < 0.2 or not is_instance_valid(f) or not f.is_inside_tree():
			return
		_acc = 0.0
		var n: int = 0
		for o: KitObject in KitObject.find(f.get_tree(), f, &"", NODE):
			if not o.data.get("dying", false):
				n += 1
		var diff: float = float(n) - f.kit.res("noeuds")
		if absf(diff) > 0.01:
			f.kit.add_res("noeuds", diff)


## Shared Karatachi rules (Node network).
class K:
	## Alive Nodes of the caster (ground and mobile), any technique.
	static func nodes(t: Tk) -> Array[KitObject]:
		var out: Array[KitObject] = []
		if not is_instance_valid(t.caster) or not t.caster.is_inside_tree():
			return out
		for o: KitObject in t.objects(NODE, &""):
			if not o.data.get("dying", false):
				out.append(o)
		return out

	## Strict cap: the oldest Node crumbles to make room.
	static func make_room(t: Tk) -> void:
		var all: Array[KitObject] = nodes(t)
		while all.size() >= MAX_NODES:
			var oldest: KitObject = all[0]
			for o: KitObject in all:
				if o.age > oldest.age:
					oldest = o
			oldest.data["dying"] = true
			t.fx("dust", oldest.global_position, 0.6, CORAL_DARK)
			oldest.destroy("cap")
			all.erase(oldest)

	## Ground Node (big = planted Écaille: sturdier, wider).
	static func plant(t: Tk, at: Vector3, big: bool = false, life: float = NODE_LIFE) -> KitObject:
		if not is_instance_valid(t.caster) or not t.caster.is_inside_tree():
			return null
		make_room(t)
		t.fx("spikes", at, 1.0 if big else 0.6, CORAL)
		return t.object(at, {"kind": NODE, "radius": 1.0 if big else 0.6, "lifetime": life,
			"health": 55.0 if big else 22.0, "look": KitObject.Look.GLYPH, "color": CORAL,
			"data": {"big": big, "mobile": false}})

	## Mobile Node hooked on an enemy: follows them, drops to the ground at expiry.
	static func attach(t: Tk, e: CombatCharacter, life: float = MOBILE_LIFE) -> KitObject:
		if not t.is_enemy(e):
			return null
		make_room(t)
		t.mark(e, "corail", 1, life, 1, "Corail")
		return t.object(e.global_position, {"kind": NODE, "radius": 0.5, "lifetime": life, "look": KitObject.Look.ORB,
			"targetable": false, "color": CORAL, "data": {"mobile": true, "big": false, "target": e},
			"on_tick": func(o: KitObject) -> void:
				var tgt: Variant = o.data.get("target")
				if is_instance_valid(tgt) and tgt is CombatCharacter and t.is_enemy(tgt):
					o.global_position = HitQuery.flat((tgt as CombatCharacter).global_position)
				else:
					drop(t, o),
			"on_expire": func(o: KitObject) -> void:
				drop(t, o)})

	## The mobile Node falls: a small, short-lived ground Node.
	static func drop(t: Tk, o: KitObject) -> void:
		if o.data.get("dying", false):
			return
		o.data["dying"] = true
		var at: Vector3 = o.global_position
		var tgt: Variant = o.data.get("target")
		if is_instance_valid(tgt) and tgt is CombatCharacter:
			t.consume_mark(tgt, "corail")
		o.destroy("dropped")
		plant(t, at, false, 6.0)

	## Alive object check safe for freed captures.
	static func ok(o: Variant) -> bool:
		return o != null and is_instance_valid(o) and (o as KitObject).is_alive()

	static func is_mobile(o: KitObject) -> bool:
		return bool(o.data.get("mobile", false))

	static func closest(list: Array[KitObject], to: Vector3, exclude: KitObject = null, max_dist: float = INF) -> KitObject:
		var best: KitObject = null
		var best_d: float = max_dist
		for o: KitObject in list:
			if o == exclude or not ok(o):
				continue
			var d: float = HitQuery.flat(o.global_position - to).length()
			if d <= best_d:
				best = o
				best_d = d
		return best


## D — Projectile, Node, Terrain. Visible coral spike: on the ground it
## plants a Node; on an enemy, low damage and a mobile Node that drops to
## the ground when it expires.
class EpineDeCorail extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.15
		a.recovery_time = 0.2
		a.max_range = 12.0
		a.anim = &"throw"

	func cast(t: Tk) -> void:
		t.projectile({"speed": 24.0, "range": minf(12.0, t.distance(t.origin, t.aim) + 0.5), "radius": 0.45, "size": 0.16,
			"color": CORAL,
			"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
				t.hit(e, t.dmg(0.35))
				K.attach(t, e)
				return false,
			"on_end": func(point: Vector3, p: TkProjectile, reason: String) -> void:
				if reason != "hit":
					K.plant(t, point - p.direction * (0.4 if reason == "wall" else 0.0))})


## C — Bouclier local, Riposte, Node. A coral plate grows on the side
## aimed at cast: the first impact coming from that side (70° each way) is
## 65 % absorbed, then the plate shatters into two small Nodes and cuts a
## close attacker. Recast while intact: detach it and plant a big Node.
class EcailleRecifale extends Technique:
	const LIFE: float = 6.0

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.12
		a.recovery_time = 0.15
		a.max_range = 6.0
		a.anim = &"guard"

	func cast(t: Tk) -> void:
		var side: Vector3 = t.dir
		var st: Dictionary = {"broken": false}
		st["plate"] = t.object(t.origin + side * 0.8, {"kind": "ecaille", "radius": 0.7, "lifetime": LIFE,
			"look": KitObject.Look.WALL, "facing": side, "half_extents": Vector2(0.8, 0.15), "targetable": false,
			"color": CORAL,
			"on_tick": func(o: KitObject) -> void:
				if is_instance_valid(t.caster):
					o.global_position = HitQuery.flat(t.caster.global_position) + side * 0.8})
		t.fx("spikes", t.origin + side * 0.8, 0.8, CORAL)
		t.buff("ecaille", LIFE, {"label": "Écaille", "color": CORAL,
			"on_take": func(hit: HitData, dmg: float) -> Variant:
				if st.broken or hit == null or not is_instance_valid(hit.source) or hit.source == t.caster:
					return null
				var to: Vector3 = HitQuery.flat(hit.source.global_position - t.caster.global_position)
				if to.length() > 0.05 and side.angle_to(to.normalized()) > deg_to_rad(70.0):
					return null  # not from the protected side
				_shatter(t, st, side, hit.source)
				return dmg * 0.35})
		t.recast(LIFE, func(rt: Tk) -> void:
			if st.broken:
				return
			st.broken = true
			rt.kit().remove_modifier("ecaille")
			if K.ok(st.get("plate")):
				(st.plate as KitObject).destroy("detached")
			K.plant(rt, rt.clear_point(rt.origin, side, 1.4), true))

	func _shatter(t: Tk, st: Dictionary, side: Vector3, attacker: CombatCharacter) -> void:
		st.broken = true
		t.kit().remove_modifier("ecaille")
		t.kit().close_recast(t.id)
		var at: Vector3 = HitQuery.flat(t.caster.global_position)
		if K.ok(st.get("plate")):
			(st.plate as KitObject).destroy("shattered")
		t.fx("rocks", at + side * 0.8, 1.2, CORAL)
		var perp: Vector3 = side.cross(Vector3.UP)
		for s: float in [-1.0, 1.0]:
			K.plant(t, at + side * 1.2 + perp * 0.9 * s)
		# Riposte: shards cut a close attacker.
		if t.is_enemy(attacker) and t.distance(attacker.global_position, at) <= 3.5:
			t.hit(attacker, t.dmg(0.4), {"push": 1.5})


## B — Ligne entre nodes, Terrain, Launcher. Picks the Node nearest the aim
## and its nearest neighbour; a ridge grows segment by segment between
## them (live positions: a mobile Node drags it along; growth stops beyond
## 13 m or if a Node dies). Enemies on a new segment are lifted and pushed
## to the nearest side (Node carriers: toward the aim side). The ridge
## stays as a low destructible obstacle. Without two Nodes: plants one.
class CreteJaillissante extends Technique:
	const SEG: float = 1.3

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.25
		a.recovery_time = 0.25
		a.max_range = 12.0
		a.anim = &"stomp"

	func cast(t: Tk) -> void:
		var all: Array[KitObject] = K.nodes(t)
		var a: KitObject = K.closest(all, t.aim)
		var b: KitObject = K.closest(all, a.global_position, a, LINK_RANGE) if a != null else null
		if a == null or b == null:
			# Not enough network: a lone Node rises at the aim.
			t.area(t.aim, 1.0, t.dmg(0.25))
			K.plant(t, t.aim)
			return
		var st: Dictionary = {"step": 0, "hit": [], "a": a, "b": b}
		t.fx("cracks", a.global_position, 1.0, CORAL)
		t.object(a.global_position, {"kind": "croissance", "radius": 0.3, "lifetime": 3.0, "look": KitObject.Look.NONE,
			"targetable": false, "tick_interval": 0.12,
			"on_tick": func(o: KitObject) -> void:
				_grow(t, o, st)})

	func _grow(t: Tk, o: KitObject, st: Dictionary) -> void:
		if not t.alive() or not K.ok(st.get("a")) or not K.ok(st.get("b")):
			o.destroy("cut")
			return
		var a: KitObject = st.a
		var b: KitObject = st.b
		var pa: Vector3 = HitQuery.flat(a.global_position)
		var pb: Vector3 = HitQuery.flat(b.global_position)
		var span: float = t.distance(pa, pb)
		if span > LINK_RANGE + 1.0 or span < 0.3:
			t.fx("dust", o.global_position, 0.8, CORAL_DARK)
			o.destroy("stretched")
			return
		var n: int = maxi(1, ceili(span / SEG))
		var i: int = int(st.step)
		if i >= n:
			o.destroy("grown")
			return
		st.step = i + 1
		var d: Vector3 = (pb - pa).normalized()
		var seg_len: float = span / float(n)
		var center: Vector3 = pa + d * seg_len * (float(i) + 0.5)
		o.global_position = center
		var perp: Vector3 = d.cross(Vector3.UP)
		t.fx("spikes", center, 0.7, CORAL)
		var clear: bool = true
		for e: CombatCharacter in t.enemies_in(center, seg_len * 0.5 + 0.5):
			if (st.hit as Array).has(e):
				continue
			(st.hit as Array).append(e)
			var side: float = signf((HitQuery.flat(e.global_position) - center).dot(perp))
			var carrier: bool = t.marks(e, "corail") > 0
			if carrier:
				side = signf((t.aim - center).dot(perp))  # easier to orient
			if side == 0.0:
				side = 1.0
			if t.hit(e, t.dmg(0.4)) == HitData.Result.HIT:
				t.launch(e, 0.6 if carrier else 0.4)
				t.push(e, perp * side, 3.0 if carrier else 2.0)
		for f: CombatCharacter in t.fighters():
			if t.distance(f.global_position, center) < seg_len * 0.5 + 0.6:
				clear = false
		t.wall(center, perp, seg_len + 0.1, 8.0, {"kind": "crete", "health": 30.0, "thickness": 0.5,
			"blocks_projectiles": false, "blocks_movement": clear, "color": CORAL})


## A — Réseau, Propagation, Piège progressif. Every Node slowly sprouts
## toward its nearest neighbour (visible lines, 2 m/s per side). When two
## sprouts meet, a coral mouth opens at the junction: it snaps once on the
## first enemy crossing it (damage + leg grab root), then remains as a
## simple obstacle. Killing a Node before the junction cuts the branch.
class RecifPredateur extends Technique:
	const GROW_SPEED: float = 2.0
	const TICK: float = 0.1

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.recovery_time = 0.25
		a.max_range = 10.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var all: Array[KitObject] = K.nodes(t)
		var pairs: Dictionary = {}
		for n: KitObject in all:
			var m: KitObject = K.closest(all, n.global_position, n, LINK_RANGE)
			if m == null:
				continue
			var ia: int = n.get_instance_id()
			var ib: int = m.get_instance_id()
			var key: String = "%d_%d" % [mini(ia, ib), maxi(ia, ib)]
			if not pairs.has(key):
				pairs[key] = [n, m]
		if pairs.is_empty():
			# No network to grow: a lone seed Node.
			K.plant(t, t.aim)
			return
		for key: String in pairs:
			var pair: Array = pairs[key]
			_sprout(t, pair[0], pair[1])

	func _sprout(t: Tk, a: KitObject, b: KitObject) -> void:
		var lines: Array = []
		if CombatFx.is_enabled():
			lines.append(KitVisuals.line_visual(t.caster.get_parent(), CORAL))
			lines.append(KitVisuals.line_visual(t.caster.get_parent(), CORAL))
		t.fx("cracks", a.global_position, 0.8, CORAL)
		t.fx("cracks", b.global_position, 0.8, CORAL)
		t.object((a.global_position + b.global_position) * 0.5, {"kind": "pousse", "radius": 0.3, "lifetime": 8.0,
			"look": KitObject.Look.NONE, "targetable": false, "tick_interval": TICK, "data": {"grown": 0.0, "a": a, "b": b},
			"on_tick": func(o: KitObject) -> void:
				if not t.alive() or not K.ok(o.data.get("a")) or not K.ok(o.data.get("b")):
					o.destroy("cut")
					return
				var pa: Vector3 = HitQuery.flat((o.data.a as KitObject).global_position)
				var pb: Vector3 = HitQuery.flat((o.data.b as KitObject).global_position)
				var span: float = t.distance(pa, pb)
				if span > LINK_RANGE + 1.0:
					o.destroy("cut")
					return
				var g: float = float(o.data.grown) + GROW_SPEED * TICK
				o.data["grown"] = g
				var d: Vector3 = (pb - pa).normalized()
				var reach: float = minf(g, span * 0.5)
				if lines.size() == 2:
					KitVisuals.update_line(lines[0], pa, pa + d * reach)
					KitVisuals.update_line(lines[1], pb, pb - d * reach)
				if g >= span * 0.5:
					_mouth(t, (pa + pb) * 0.5)
					o.destroy("joined"),
			"on_destroy": func(_o: KitObject, _reason: String) -> void:
				for l: Variant in lines:
					if is_instance_valid(l):
						(l as Node).queue_free()})

	func _mouth(t: Tk, at: Vector3) -> void:
		t.fx("spikes", at, 1.2, CORAL)
		t.object(at, {"kind": "bouche", "radius": 1.2, "lifetime": 12.0, "health": 35.0, "look": KitObject.Look.RING,
			"color": CORAL, "data": {"closed": false},
			"on_enter": func(f: CombatCharacter, o: KitObject) -> void:
				if not t.is_enemy(f) or o.data.closed:
					return
				o.data["closed"] = true
				var where: Vector3 = o.global_position
				t.fx("implosion", where, 1.2, CORAL)
				t.text(f, "SAISIE")
				t.hit(f, t.dmg(0.6), {"root": 0.8})
				o.destroy("closed")
				t.after(0.8, func(rt: Tk) -> void:
					_obstacle(rt, where))})

	## A closed mouth: plain obstacle (solid only if nobody stands in it).
	func _obstacle(t: Tk, at: Vector3) -> void:
		var clear: bool = true
		for f: CombatCharacter in t.fighters():
			if t.distance(f.global_position, at) < 1.3:
				clear = false
		t.object(at, {"kind": "recif_obstacle", "radius": 0.6, "lifetime": 6.0, "health": 40.0,
			"look": KitObject.Look.PILLAR, "color": CORAL_DARK, "blocks_movement": clear, "blocks_projectiles": true})


## S — Forteresse réseau, Bouclier partagé, Recast. Every Node becomes a
## linked coral pillar (no Node: one pillar in front). Allies near a pillar
## get a small shield and share incoming damage with it (40 % goes to the
## pillar, which can be focused). Recast: the reef vibrates (0.5 s), then
## each remaining pillar bursts outward in a fan of fragments — more
## pillars kept, more angles covered — and the fortress is gone.
class SanctuaireTortue extends Technique:
	const LIFE: float = 10.0
	const AURA: float = 3.5

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.4
		a.recovery_time = 0.3
		a.max_range = 10.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var pillars: Array[KitObject] = []
		for n: KitObject in K.nodes(t):
			var at: Vector3 = HitQuery.flat(n.global_position)
			var big: bool = bool(n.data.get("big", false))
			n.data["dying"] = true
			n.destroy("pillar")
			pillars.append(_pillar(t, at, big))
		if pillars.is_empty():
			pillars.append(_pillar(t, t.clear_point(t.origin, t.dir, 1.4), false))
		t.fx("wave", t.origin, 4.0, CORAL)
		_links(t, pillars)
		t.recast(LIFE, func(rt: Tk) -> void:
			_burst(rt))

	func _pillar(t: Tk, at: Vector3, big: bool) -> KitObject:
		t.fx("column", at, 1.0, CORAL)
		return t.object(at, {"kind": "pilier", "radius": 1.0 if big else 0.7, "lifetime": LIFE,
			"health": 140.0 if big else 90.0, "look": KitObject.Look.PILLAR, "color": CORAL,
			"blocks_projectiles": true, "tick_interval": 0.5,
			"on_tick": func(o: KitObject) -> void:
				if not t.alive():
					return
				var ref: Dictionary = {"pillar": o}
				for ally: CombatCharacter in t.allies_in(o.global_position, AURA):
					if not ally.kit.has_modifier("sanctuaire_lien"):
						t.shield(ally, t.dmg(0.35), 2.0)
					ally.kit.add_modifier("sanctuaire_lien", 0.7, {"label": "Sanctuaire", "color": CORAL,
						"on_take": func(_hit: HitData, dmg: float) -> Variant:
							if not K.ok(ref.get("pillar")) or dmg <= 0.0:
								return null
							(ref.pillar as KitObject).damage(dmg * 0.4)
							return dmg * 0.6})})

	## Visible links between pillars (hidden when one falls).
	func _links(t: Tk, pillars: Array[KitObject]) -> void:
		if not CombatFx.is_enabled():
			return
		var links: Array = []
		for i in pillars.size():
			for j in range(i + 1, pillars.size()):
				if t.distance(pillars[i].global_position, pillars[j].global_position) <= LINK_RANGE:
					var mi: MeshInstance3D = KitVisuals.line_visual(t.caster.get_parent(), CORAL)
					KitVisuals.update_line(mi, pillars[i].global_position, pillars[j].global_position)
					links.append([mi, pillars[i], pillars[j]])
		if links.is_empty():
			return
		t.object(t.origin, {"kind": "liens", "radius": 0.1, "lifetime": LIFE + 0.6, "look": KitObject.Look.NONE,
			"targetable": false, "tick_interval": 0.2,
			"on_tick": func(o: KitObject) -> void:
				var any: bool = false
				for l: Array in links:
					var mi: Variant = l[0]
					if not is_instance_valid(mi):
						continue
					var alive: bool = K.ok(l[1]) and K.ok(l[2])
					(mi as Node3D).visible = alive
					any = any or alive
				if not any:
					o.destroy("empty"),
			"on_destroy": func(_o: KitObject, _r: String) -> void:
				for l: Array in links:
					if is_instance_valid(l[0]):
						(l[0] as Node).queue_free()})

	func _burst(t: Tk) -> void:
		var pillars: Array[KitObject] = t.objects("pilier")
		if pillars.is_empty():
			return
		var center: Vector3 = Vector3.ZERO
		for p: KitObject in pillars:
			center += HitQuery.flat(p.global_position)
		center /= float(pillars.size())
		if pillars.size() == 1:
			center = t.origin
		# Announced: the reef vibrates.
		for p: KitObject in pillars:
			t.fx("cracks", p.global_position, 1.4, CORAL)
		t.text(t.caster, "RÉCIF")
		t.after(0.5, func(bt: Tk) -> void:
			for pv: Variant in pillars:
				if not K.ok(pv):
					continue
				var p: KitObject = pv
				var from: Vector3 = HitQuery.flat(p.global_position)
				var out: Vector3 = HitQuery.flat(from - center)
				out = out.normalized() if out.length() > 0.2 else bt.dir
				bt.fx("rocks", from, 1.2, CORAL)
				for k in 5:
					var d: Vector3 = out.rotated(Vector3.UP, deg_to_rad(-30.0 + 15.0 * k))
					bt.projectile({"from": from - d * 0.5, "dir": d, "speed": 22.0, "range": 8.0, "radius": 0.45,
						"size": 0.15, "color": CORAL,
						"on_hit": func(e: CombatCharacter, _pr: TkProjectile) -> bool:
							bt.hit(e, bt.dmg(0.4))
							return false})
				p.destroy("burst"))
