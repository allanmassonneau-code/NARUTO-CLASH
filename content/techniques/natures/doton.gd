extends RefCounted
## Technique kit: Doton (design bible §4). Signature: Strates / Fissures —
## several techniques raise temporary terrain ("Strates": KitObjects with
## data.strate, their own health, always destructible). A heavy impact on a
## Strate Fissures it (a single loss of HEAVY_IMPACT health, or a heavy Doton
## technique nearby); a second heavy impact, or a later technique, makes it
## burst / collapse. Collapses leave rubble and a Fragment (ammo for Armure
## lithique), deepen a Fosse d'argile and charge a Cœur tellurique.

const KIT_ID := &"doton"
const SIGNATURE = null
const TECHNIQUES := {
	&"doton_d_schiste_ricochet": SchisteRicochet,
	&"doton_d_ancrage_tellurique": AncrageTellurique,
	&"doton_c_mur_d_eperon": MurDEperon,
	&"doton_c_fosse_d_argile": FosseDArgile,
	&"doton_b_armure_lithique": ArmureLithique,
	&"doton_b_chambre_sismique": ChambreSismique,
	&"doton_a_faille_ascendante": FailleAscendante,
	&"doton_a_colosse_de_basalte": ColosseDeBasalte,
	&"doton_s_citadelle_mobile": CitadelleMobile,
	&"doton_s_cur_tellurique": CoeurTellurique,
}

const STONE := Color(0.62, 0.5, 0.36)
const CLAY := Color(0.55, 0.38, 0.22)
## Health lost in a single blow that counts as a heavy impact on a Strate.
const HEAVY_IMPACT: float = 10.0
const CORE_ID := &"doton_s_cur_tellurique"
const FOSSE_ID := &"doton_c_fosse_d_argile"


## Shared Doton rules (Strates, Fissures, Fragments, Cœur charges).
class K:
	## Registers `o` as a Strate: watches heavy impacts (single health drops)
	## and turns its destruction into a collapse.
	static func strate(t: Tk, o: KitObject, fissured: bool = false) -> KitObject:
		o.data["strate"] = true
		o.data["fissured"] = fissured
		o.data["hp_seen"] = o.health
		var inner_tick: Callable = o.on_tick
		o.on_tick = func(obj: KitObject) -> void:
			K._watch(t, obj)
			if inner_tick.is_valid() and obj.is_alive():
				inner_tick.call(obj)
		var inner_destroy: Callable = o.on_destroy
		o.on_destroy = func(obj: KitObject, reason: String) -> void:
			if inner_destroy.is_valid():
				inner_destroy.call(obj, reason)
			if reason == "destroyed" or reason == "collapsed":
				K._collapsed(t, obj)
		return o

	static func _watch(t: Tk, o: KitObject) -> void:
		if o.health < 0.0:
			return
		var drop: float = float(o.data.get("hp_seen", o.health)) - o.health
		o.data["hp_seen"] = o.health
		if drop >= HEAVY_IMPACT:
			fissure(t, o)

	static func is_strate(o: KitObject) -> bool:
		return o != null and is_instance_valid(o) and o.is_alive() and bool(o.data.get("strate", false))

	static func strata(t: Tk) -> Array[KitObject]:
		var out: Array[KitObject] = []
		for o: KitObject in t.objects("", &""):
			if is_strate(o):
				out.append(o)
		return out

	## Strates plus other Doton structures (totems, golem): ricochet surfaces.
	static func structures(t: Tk) -> Array[KitObject]:
		var out: Array[KitObject] = []
		for o: KitObject in t.objects("", &""):
			if is_strate(o) or bool(o.data.get("structure", false)):
				out.append(o)
		return out

	## First heavy impact: Fissure. On a Fissured Strate: collapse.
	static func fissure(t: Tk, o: KitObject) -> void:
		if not is_strate(o):
			return
		if bool(o.data.get("fissured", false)):
			o.destroy("collapsed")
			return
		o.data["fissured"] = true
		t.fx("cracks", o.global_position, maxf(o.radius, 1.0), STONE)
		charge_cores(t, o.global_position, 1)

	## A later technique makes a Strate burst (damage around it).
	static func shatter(t: Tk, o: KitObject, mult: float) -> void:
		if not is_strate(o):
			return
		var at: Vector3 = o.global_position
		t.fx("explosion", at, 1.8, STONE)
		t.fx("rocks", at, 1.6)
		t.area(at, 1.8, t.dmg(mult))
		o.destroy("collapsed")

	## Heavy Doton impact at `at`: Fissures nearby Strates (except those of
	## `skip_technique`) and charges the Cœur.
	static func heavy_impact(t: Tk, at: Vector3, radius: float, skip_technique: StringName = &"") -> void:
		for o: KitObject in strata(t):
			if skip_technique != &"" and o.technique_id == skip_technique:
				continue
			if o.is_alive() and t.distance(o.global_position, at) <= radius + o.radius:
				fissure(t, o)
		charge_cores(t, at, 1)

	static func _collapsed(t: Tk, o: KitObject) -> void:
		if not t.alive():
			return
		var at: Vector3 = HitQuery.flat(o.global_position)
		t.fx("rocks", at, 1.5)
		t.zone(at, 1.4, 4.0, {"kind": "gravats", "color": STONE, "targetable": false,
			"on_enter": func(f: CombatCharacter, _z: KitObject) -> void:
				if t.is_enemy(f):
					t.status(f, StatusController.Type.SLOW, 1.0)})
		fragment(t, at)
		for fosse: KitObject in t.objects("fosse", FOSSE_ID):
			if fosse.contains(at):
				fosse.data["deep"] = true
				fosse.lifetime = minf(fosse.lifetime, fosse.age + 2.5)
				t.fx("implosion", fosse.global_position, 1.3, CLAY)
		charge_cores(t, at, 2)

	static func fragment(t: Tk, at: Vector3) -> KitObject:
		return t.object(at, {"kind": "fragment", "radius": 0.5, "lifetime": 10.0, "look": KitObject.Look.ORB,
			"targetable": false, "color": STONE})

	static func charge_cores(t: Tk, at: Vector3, n: int) -> void:
		for core: KitObject in t.objects("coeur", CORE_ID):
			if t.distance(core.global_position, at) <= float(core.data.get("zone", 6.0)):
				add_charge(t, core, n)

	static func add_charge(t: Tk, core: KitObject, n: int) -> void:
		core.data["charge"] = mini(int(core.data.get("charge", 0)) + n, 20)
		t.fx("ring", core.global_position, 0.8 + 0.1 * float(core.data.charge), Color(0.9, 0.6, 0.25))

	## Outward normal of a structure at `point` for something moving along `d`.
	static func normal(o: KitObject, point: Vector3, d: Vector3) -> Vector3:
		var n: Vector3
		if o.look == KitObject.Look.WALL:
			n = o.facing
		else:
			n = HitQuery.flat(point - o.global_position)
			if n.length() < 0.05:
				n = -d
		n = n.normalized()
		return -n if n.dot(d) > 0.0 else n

	static func wall_normal(t: Tk, point: Vector3, d: Vector3) -> Vector3:
		var up: Vector3 = Vector3.UP * HitQuery.BODY_HEIGHT
		var hit: Dictionary = HitQuery.raycast_world(t.caster.get_world_3d(), point - d * 1.0 + up, point + d * 1.0 + up)
		if hit.is_empty():
			return -d
		var n: Vector3 = HitQuery.flat(hit.normal)
		return n.normalized() if n.length() > 0.1 else -d

	static func reflect(d: Vector3, n: Vector3) -> Vector3:
		var r: Vector3 = HitQuery.flat(d - 2.0 * d.dot(n) * n)
		return r.normalized() if r.length() > 0.05 else -d

	static func seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
		var ab: Vector3 = HitQuery.flat(b - a)
		var ap: Vector3 = HitQuery.flat(p - a)
		var k: float = clampf(ap.dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		return (ap - ab * k).length()


## D — Projectile, Ricochet, Poke. A low stone disc (preview ring on the
## first wall it will meet); bounces once off a wall or a Doton structure,
## faster and stronger after the bounce; bouncing off a Fissured Strate
## makes it burst. Breaks on the second contact.
class SchisteRicochet extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.12
		a.recovery_time = 0.2
		a.max_range = 12.0
		a.anim = &"throw"

	func cast(t: Tk) -> void:
		var up: Vector3 = Vector3.UP * HitQuery.BODY_HEIGHT
		var preview: Dictionary = HitQuery.raycast_world(t.caster.get_world_3d(), t.origin + up, t.origin + up + t.dir * 12.0)
		if not preview.is_empty():
			t.fx("ring", HitQuery.flat(preview.position), 0.6, STONE)
		_disc(t, t.origin, t.dir, true)

	func _disc(t: Tk, from: Vector3, d: Vector3, first: bool) -> void:
		var mult: float = 0.5 if first else 0.65
		t.projectile({"from": from, "dir": d, "speed": 20.0 if first else 25.0, "range": 12.0 if first else 9.0,
			"radius": 0.5, "size": 0.2, "color": STONE,
			"on_tick": func(p: TkProjectile, _dt: float) -> void:
				if not first or p.travelled < 0.8:
					return
				var at: Vector3 = p.ground_point()
				for o: KitObject in K.structures(t):
					var touching: bool = o.contains(at) if o.look == KitObject.Look.WALL \
						else t.distance(o.global_position, at) <= o.radius + 0.3
					if not touching:
						continue
					var n: Vector3 = K.normal(o, at, p.direction)
					var out_dir: Vector3 = K.reflect(p.direction, n)
					p.end("bounce")
					if bool(o.data.get("fissured", false)):
						K.shatter(t, o, 0.5)
					_disc(t, at + n * 0.3 - out_dir * 0.5, out_dir, false)
					return,
			"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
				t.hit(e, t.dmg(mult))
				return false,
			"on_end": func(point: Vector3, p: TkProjectile, reason: String) -> void:
				if reason == "wall" and first and t.alive():
					var n: Vector3 = K.wall_normal(t, point, p.direction)
					var out_dir: Vector3 = K.reflect(p.direction, n)
					_disc(t, point + n * 0.4 - out_dir * 0.5, out_dir, false)})


## D — Stance, Anti-CC, Stockage. Anchored for 1.8 s: tenacity (forced
## movement x0.25, no launch), slow walk. Each push / shock absorbed adds
## Impact (max 5); at the end a short tremor scales with it (stun at 3+,
## Fissures nearby Strates at 2+). Damage itself is not reduced.
class AncrageTellurique extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.1
		a.recovery_time = 0.1
		a.max_range = 2.5
		a.anim = &"stomp"

	func cast(t: Tk) -> void:
		t.fx("cracks", t.origin, 1.5, STONE)
		var state: Dictionary = {"impact": 0, "forced": false}
		t.buff("ancrage", 1.8, {"tenacity": true, "speed": 0.45, "label": "Ancrage", "color": STONE,
			"on_take": func(hit: HitData, dmg: float) -> float:
				var shock: bool = hit.knockback_velocity != Vector3.ZERO or hit.stun_duration > 0.0 or dmg >= 10.0 \
					or (hit.ability != null and hit.ability.launch_duration > 0.0)
				if shock:
					state["impact"] = mini(int(state.impact) + 1, 5)
				return dmg,
			"on_tick": func(_dt: float) -> void:
				if not t.alive():
					return
				var forced: bool = t.caster.movement.is_forced() and t.caster.movement.is_knockback
				if forced and not bool(state.forced):
					state["impact"] = mini(int(state.impact) + 1, 5)
				state["forced"] = forced,
			"on_end": func() -> void:
				_release(t, state)})

	func _release(t: Tk, state: Dictionary) -> void:
		if not t.alive():
			return
		var rt: Tk = t.refreshed()
		var n: int = int(state.impact)
		var radius: float = 2.2 + 0.3 * n
		rt.fx("wave", rt.origin, radius, STONE)
		var opts: Dictionary = {"slow": 1.0}
		if n >= 3:
			opts["stun"] = 0.35
		rt.area(rt.origin, radius, rt.dmg(0.15 + 0.2 * n), opts)
		if n >= 2:
			K.heavy_impact(rt, rt.origin, radius)


## C — Terrain, Cover, Launcher. Telegraphed crack, then a slanted rock
## plate (Strate, 70 HP): blocks projectiles, crossable as a ramp (allies on
## it gain Hauteur +15 % damage, enemies climbing it are slowed). Enemies on
## top when it rises are lifted to its high side and launched. A heavy hit
## Fissures it, a second collapses it into rubble.
class MurDEperon extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.max_range = 9.0
		a.anim = &"stomp"

	func cast(t: Tk) -> void:
		var d: Vector3 = t.dir
		var at: Vector3 = t.aim
		t.fx("cracks", at, 2.0, STONE)
		t.telegraph(at, 1.4, 0.35, func(rt: Tk) -> void:
			_raise(rt, at, d))

	func _raise(t: Tk, at: Vector3, d: Vector3) -> void:
		t.fx("spikes", at, 1.6, STONE)
		for e: CombatCharacter in t.enemies_in(at, 1.2):
			t.blink(at + d * 1.1, e)
			t.hit(e, t.dmg(0.55), {"launch": 0.8})
		for ally: CombatCharacter in t.allies_in(at, 1.2):
			ally.air_time = maxf(ally.air_time, 0.5)
		var w: KitObject = t.wall(at, d, 4.0, 10.0, {"kind": "eperon", "health": 70.0, "blocks_movement": false,
			"thickness": 0.9, "color": STONE,
			"on_enter": func(f: CombatCharacter, _o: KitObject) -> void:
				if t.is_ally(f):
					f.kit.add_modifier("hauteur", 2.5, {"damage_dealt": 1.15, "label": "Hauteur", "color": STONE})
					f.air_time = maxf(f.air_time, 0.35)
				elif t.is_enemy(f):
					t.status(f, StatusController.Type.SLOW, 0.8)})
		K.strate(t, w)


## C — Zone, Piège progressif, Terrain. Softening ground: <1 s inside light
## slow, 1-2 s deeper slow, 2 s = feet stuck (root 0.6 s), then it starts
## over. Leaving resets. A Doton structure collapsing in it makes the centre
## instantly deep but shortens the pit.
class FosseDArgile extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.25
		a.max_range = 10.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		t.fx("dust", t.aim, 3.0)
		t.zone(t.aim, 3.0, 7.0, {"kind": "fosse", "color": CLAY, "targetable": false, "tick_interval": 0.25,
			"data": {"time": {}, "deep": false},
			"on_tick": func(o: KitObject) -> void:
				var times: Dictionary = o.data.time
				var now: Dictionary = {}
				for e: CombatCharacter in o.enemies_inside():
					var key: int = e.get_instance_id()
					var s: float = float(times.get(key, 0.0)) + 0.25
					if bool(o.data.deep) and t.distance(e.global_position, o.global_position) <= 1.3:
						s = maxf(s, 2.0)
					if s >= 2.0:
						t.status(e, StatusController.Type.ROOT, 0.6)
						t.text(e, "ENLISÉ")
						s = 0.8
					elif s >= 1.0:
						t.debuff(e, "argile", 0.35, {"speed": 0.5, "label": "Enlisement", "color": CLAY})
					else:
						t.debuff(e, "argile", 0.35, {"speed": 0.8, "label": "Argile", "color": CLAY})
					now[key] = s
				o.data["time"] = now})


## B — Bouclier segmenté, Ressource, Recast. Three plates orbit the caster
## for 8 s; a hit coming from a plate's side loses 60 % and breaks that
## plate, which drops a Fragment. Recast: every Fragment on the ground (any
## Doton source) flies to the aim (window reopens if there is none yet).
class ArmureLithique extends Technique:
	const LIFE: float = 8.0

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.15
		a.max_range = 14.0
		a.anim = &"guard"

	func cast(t: Tk) -> void:
		t.fx("rocks", t.origin, 1.4)
		for i in 3:
			t.object(t.origin, {"kind": "plaque", "radius": 0.4, "lifetime": LIFE, "look": KitObject.Look.PILLAR,
				"targetable": false, "color": STONE,
				"on_tick": func(o: KitObject) -> void:
					if not t.alive():
						o.destroy("caster")
						return
					var ang: float = TAU * i / 3.0 + o.age * 2.2
					o.global_position = HitQuery.flat(t.caster.global_position) + Vector3(cos(ang), 0.0, sin(ang)) * 1.1})
		t.buff("armure_lithique", LIFE, {"label": "Armure lithique", "color": STONE,
			"on_take": func(hit: HitData, dmg: float) -> float:
				return _absorb(t, hit, dmg)})
		_arm_volley(t, LIFE)

	func _absorb(t: Tk, hit: HitData, dmg: float) -> float:
		if not t.alive() or not is_instance_valid(hit.source) or hit.source == t.caster:
			return dmg
		var to: Vector3 = HitQuery.flat(hit.source.global_position - t.caster.global_position)
		if to.length() < 0.1:
			return dmg
		for p: KitObject in t.objects("plaque"):
			var pa: Vector3 = HitQuery.flat(p.global_position - t.caster.global_position)
			if pa.length() > 0.1 and pa.angle_to(to) <= deg_to_rad(50.0):
				p.destroy("broken")
				K.fragment(t, HitQuery.flat(t.caster.global_position) + pa.normalized() * 1.4)
				t.text(t.caster, "PLAQUE", STONE)
				return dmg * 0.4
		return dmg

	func _arm_volley(t: Tk, left: float) -> void:
		if left <= 0.1:
			return
		t.recast(left, func(rt: Tk) -> void:
			var frags: Array[KitObject] = rt.objects("fragment", &"")
			if frags.is_empty():
				_arm_volley(rt, rt.kit().modifier_left("armure_lithique"))
				return
			for f: KitObject in frags:
				var from: Vector3 = f.global_position
				var d: Vector3 = HitQuery.flat(rt.aim - from)
				d = d.normalized() if d.length() > 0.1 else rt.dir
				f.destroy("thrown")
				rt.projectile({"from": from - d * 0.5, "dir": d, "speed": 24.0, "range": 14.0, "radius": 0.5, "size": 0.18,
					"color": STONE,
					"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
						rt.hit(e, rt.dmg(0.4))
						return false}))


## B — Deux ancres, Zone linéaire, Pulses. First totem at the aim; recast
## places the second (auto-placed ahead if the window lapses). A seismic
## line links them and pulses every second (shock + 0.25 s stagger). A Strate
## crossed by the line amplifies the pulse x1.5 then Fissures. Destroying a
## totem ends the chamber; between pulses the line is harmless.
class ChambreSismique extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.max_range = 10.0
		a.anim = &"stomp"

	func cast(t: Tk) -> void:
		var t1: KitObject = _totem(t, t.aim, 12.0)
		var d: Vector3 = t.dir
		t.recast(4.0, func(rt: Tk) -> void:
			_second(rt, t1, rt.aim, d),
			func() -> void:
				if t.alive() and is_instance_valid(t1) and t1.is_alive():
					_second(t.refreshed(), t1, t1.global_position + d * 6.0, d))

	func _totem(t: Tk, at: Vector3, life: float) -> KitObject:
		t.fx("spikes", at, 0.8, STONE)
		return t.object(at, {"kind": "totem", "radius": 0.6, "health": 35.0, "lifetime": life, "look": KitObject.Look.PILLAR,
			"color": STONE, "data": {"structure": true}})

	func _second(t: Tk, t1v: Variant, at: Vector3, d: Vector3) -> void:
		if not is_instance_valid(t1v) or not (t1v as KitObject).is_alive():
			return
		var t1: KitObject = t1v
		var a: Vector3 = t1.global_position
		var to: Vector3 = HitQuery.flat(at - a)
		if to.length() < 2.5:
			to = d * 5.0
		to = to.limit_length(10.0)
		var b: Vector3 = t.clear_point(a, to.normalized(), to.length())
		var t2: KitObject = _totem(t, b, 8.0)
		var line_node: MeshInstance3D = null
		if CombatFx.is_enabled():
			line_node = KitVisuals.line_visual(t.caster.get_parent(), STONE)
			KitVisuals.update_line(line_node, a, b)
		t.object((a + b) * 0.5, {"kind": "chambre", "radius": 0.5, "lifetime": 7.0, "look": KitObject.Look.NONE,
			"targetable": false, "tick_interval": 1.0, "data": {"n": 0},
			"on_tick": func(o: KitObject) -> void:
				_pulse(t, o, t1, t2),
			"on_destroy": func(_o: KitObject, _reason: String) -> void:
				if line_node != null and is_instance_valid(line_node):
					line_node.queue_free()
				for tot: Variant in [t1, t2]:
					if is_instance_valid(tot) and (tot as KitObject).is_alive():
						(tot as KitObject).destroy("chamber_end")})

	func _pulse(t: Tk, o: KitObject, t1: Variant, t2: Variant) -> void:
		if not t.alive() or not is_instance_valid(t1) or not is_instance_valid(t2) \
				or not (t1 as KitObject).is_alive() or not (t2 as KitObject).is_alive():
			o.destroy("broken")
			return
		var a: Vector3 = (t1 as KitObject).global_position
		var b: Vector3 = (t2 as KitObject).global_position
		var n: int = int(o.data.n)
		o.data["n"] = n + 1
		if n == 0:
			t.fx("cracks", o.global_position, 1.0, STONE)  # arming pulse: warning only
			return
		var amp: float = 1.0
		for s: KitObject in K.strata(t):
			if K.seg_dist(s.global_position, a, b) <= s.radius + 0.5:
				amp = 1.5
				K.fissure(t, s)
		var d: Vector3 = HitQuery.flat(b - a)
		var length: float = d.length()
		if length < 0.1:
			return
		for i in 3:
			t.fx("cracks", a.lerp(b, (i + 0.5) / 3.0), 0.9, STONE)
		t.line(length, 1.2, t.dmg(0.4 * amp), {"stun": 0.25}, a, d.normalized())


## A — Ligne séquencée, Launcher, Terrain. A crack runs forward in 1.4 m
## segments; each arms (ring) then erupts after a slightly different delay:
## damage + launch (once per enemy), Fissured Strates on the way burst,
## others Fissure; every other segment leaves a pre-Fissured pillar Strate.
## Recast once: propagation stops, already armed segments erupt at once.
class FailleAscendante extends Technique:
	const STEP: float = 1.4

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.max_range = 12.0
		a.anim = &"stomp"

	func cast(t: Tk) -> void:
		var d: Vector3 = t.dir
		var start: Vector3 = t.origin + d * 1.2
		var reach: float = t.distance(start, t.clear_point(start, d, 11.0))
		var count: int = clampi(int(reach / STEP) + 1, 1, 8)
		var state: Dictionary = {"stopped": false, "hit": []}
		for i in count:
			t.after(0.11 * i, func(rt: Tk) -> void:
				if not bool(state.stopped):
					_arm(rt, start + d * STEP * i, i, state))
		t.recast(0.11 * count + 0.6, func(rt: Tk) -> void:
			state["stopped"] = true
			for s: KitObject in rt.objects("segment"):
				if s.is_alive():
					var at: Vector3 = s.global_position
					var idx: int = int(s.data.get("i", 0))
					s.destroy("recast")
					_burst(rt, at, idx, state))

	func _arm(t: Tk, at: Vector3, i: int, state: Dictionary) -> void:
		var delay: float = 0.38 + 0.06 * float(i % 3)
		t.object(at, {"kind": "segment", "radius": 0.9, "lifetime": delay, "look": KitObject.Look.RING,
			"targetable": false, "color": STONE, "data": {"i": i},
			"on_expire": func(o: KitObject) -> void:
				if t.alive():
					_burst(t, o.global_position, i, state)})

	func _burst(t: Tk, at: Vector3, i: int, state: Dictionary) -> void:
		t.fx("spikes", at, 1.1, STONE)
		var already: Array = state.hit
		for e: CombatCharacter in t.enemies_in(at, 1.1):
			if already.has(e):
				continue
			already.append(e)
			t.hit(e, t.dmg(0.75), {"launch": 0.7})
		for o: KitObject in K.strata(t):
			if o.technique_id != t.id and bool(o.data.get("fissured", false)) \
					and t.distance(o.global_position, at) <= 1.2 + o.radius:
				K.shatter(t, o, 0.6)
		K.heavy_impact(t, at, 1.2, t.id)
		if i % 2 == 0:
			K.strate(t, t.object(at, {"kind": "pilier", "radius": 0.55, "health": 30.0, "lifetime": 6.0,
				"look": KitObject.Look.PILLAR, "color": STONE}), true)


## A — Invocation, Copie d'action, Tank. A basalt golem (140 HP, blocks
## movement) rises, anchored to a 5 m zone. 0.25 s after each basic attack
## of the caster it slams in the same direction (only enemies inside its
## zone; the slam is a heavy impact). Destroyed: collapses into 4 Fragments.
class ColosseDeBasalte extends Technique:
	const ZONE: float = 5.0

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.45
		a.max_range = 6.0
		a.anim = &"stomp"

	func cast(t: Tk) -> void:
		var at: Vector3 = t.aim
		t.fx("rocks", at, 2.0)
		t.area(at, 1.6, t.dmg(0.4), {"push": 2.0})
		var anchor: KitObject = t.zone(at, ZONE, 12.0, {"kind": "zone_colosse", "look": KitObject.Look.RING,
			"targetable": false, "color": STONE})
		var ref: Dictionary = {}
		var golem: KitObject = t.object(at, {"kind": "colosse", "radius": 1.0, "health": 140.0, "lifetime": 12.0,
			"look": KitObject.Look.PILLAR, "blocks_movement": true, "color": STONE, "data": {"structure": true},
			"on_destroy": func(o: KitObject, reason: String) -> void:
				if is_instance_valid(anchor) and anchor.is_alive():
					anchor.destroy("golem_gone")
				if reason == "destroyed" and t.alive():
					var pos: Vector3 = HitQuery.flat(o.global_position)
					t.fx("rocks", pos, 2.0)
					for k in 4:
						K.fragment(t, pos + Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 4.0) * 1.5)
					K.charge_cores(t, pos, 2)})
		ref["golem"] = golem
		var on_cast := func(_slot: StringName, ability: AbilityData) -> void:
			var g: Variant = ref.get("golem")
			if not t.alive() or not is_instance_valid(g) or not (g as KitObject).is_alive():
				return
			if not t.caster.abilities.is_basic_attack(ability):
				return
			var d: Vector3 = HitQuery.flat(t.caster.abilities.cast_direction).normalized()
			t.after(0.25, func(rt: Tk) -> void:
				_slam(rt, g, at, d))
		t.caster.abilities.cast_activated.connect(on_cast)
		var caster: CombatCharacter = t.caster
		golem.tree_exiting.connect(func() -> void:
			if is_instance_valid(caster) and caster.abilities.cast_activated.is_connected(on_cast):
				caster.abilities.cast_activated.disconnect(on_cast))

	func _slam(t: Tk, gv: Variant, anchor_at: Vector3, d: Vector3) -> void:
		if not is_instance_valid(gv) or not (gv as KitObject).is_alive() or d.length() < 0.5:
			return
		var from: Vector3 = HitQuery.flat((gv as KitObject).global_position)
		t.fx("cracks", from + d * 2.0, 1.6, STONE)
		for e: CombatCharacter in t.enemies_in_cone(from, d, 3.8, 80.0):
			if t.distance(e.global_position, anchor_at) <= ZONE + HitQuery.HURTBOX_RADIUS:
				t.hit(e, t.dmg(0.45), {"push": 1.0, "push_from": from})
		K.heavy_impact(t, from + d * 2.0, 1.5)


## S — Fortification, Terrain majeur, Reconfiguration. Four large plates
## (Strates, 110 HP) rise around the aim; the corners always stay open, so
## it is never a sealed prison. Recast every 2.5 s: the plate facing the aim
## slides 3 m along itself (open / close an angle). Almost no damage.
class CitadelleMobile extends Technique:
	const SIDE: float = 4.0

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.5
		a.max_range = 9.0
		a.anim = &"stomp"

	func cast(t: Tk) -> void:
		var c: Vector3 = t.aim
		t.fx("cracks", c, SIDE + 1.0, STONE)
		for k in 4:
			var n: Vector3 = t.dir.rotated(Vector3.UP, PI * 0.5 * k)
			var home: Vector3 = c + n * SIDE
			for e: CombatCharacter in t.enemies_in(home, 2.6):
				if t.distance(e.global_position, home) < 1.2 or absf(HitQuery.flat(e.global_position - home).dot(n)) < 0.8:
					t.hit(e, t.dmg(0.12), {"push": 1.5, "push_from": c if t.distance(e.global_position, c) > SIDE else home + n})
			var w: KitObject = t.wall(home, n, 5.0, 14.0, {"kind": "rempart", "health": 110.0, "thickness": 0.8,
				"color": STONE, "data": {"home": home, "n": n, "slid": false}})
			K.strate(t, w)
		_arm_slide(t, c, 14.0)

	func _arm_slide(t: Tk, c: Vector3, left: float) -> void:
		if left <= 0.2:
			return
		t.recast(left, func(rt: Tk) -> void:
			_slide(rt, c)
			rt.after(2.5, func(rt2: Tk) -> void:
				var rem: float = 0.0
				for w: KitObject in rt2.objects("rempart"):
					rem = maxf(rem, w.lifetime - w.age)
				_arm_slide(rt2, c, rem)))

	func _slide(t: Tk, c: Vector3) -> void:
		var want: Vector3 = HitQuery.flat(t.aim - c)
		if want.length() < 0.5:
			want = t.dir
		var best: KitObject = null
		var best_dot: float = -2.0
		for w: KitObject in t.objects("rempart"):
			var n: Vector3 = w.data.n
			var dp: float = n.dot(want.normalized())
			if dp > best_dot:
				best_dot = dp
				best = w
		if best == null:
			return
		var home: Vector3 = best.data.home
		var along: Vector3 = (best.data.n as Vector3).cross(Vector3.UP).normalized()
		var slid: bool = bool(best.data.slid)
		best.global_position = home if slid else home + along * 3.0
		best.data["slid"] = not slid
		t.fx("dust", best.global_position, 2.0)


## S — Noyau, Stockage d'impact, Détonation. A visible, destructible Cœur
## (80 HP) with a 6 m zone. Charges from heavy hits taken by anyone in the
## zone (>= 12 damage at once), launches, Fissures and collapses (any side),
## and very slowly by itself. Recast: successive seismic rings — more
## charges = more rings and radius, damage per ring capped. Destroyed by an
## enemy: a small neutral discharge (pushes everyone) instead.
class CoeurTellurique extends Technique:
	const LIFE: float = 15.0

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.4
		a.max_range = 8.0
		a.anim = &"stomp"

	func cast(t: Tk) -> void:
		var zone: KitObject = t.zone(t.aim, 6.0, LIFE, {"kind": "zone_coeur", "look": KitObject.Look.RING,
			"targetable": false, "color": Color(0.9, 0.6, 0.25)})
		t.fx("column", t.aim, 1.0, Color(0.9, 0.6, 0.25))
		var core: KitObject = t.object(t.aim, {"kind": "coeur", "radius": 0.8, "health": 80.0, "lifetime": LIFE,
			"look": KitObject.Look.ORB, "color": Color(0.9, 0.55, 0.2), "tick_interval": 0.1,
			"data": {"charge": 0, "zone": 6.0, "hp": {}, "air": {}, "idle": 0.0},
			"on_tick": func(o: KitObject) -> void:
				_scan(t, o),
			"on_destroy": func(o: KitObject, reason: String) -> void:
				if is_instance_valid(zone) and zone.is_alive():
					zone.destroy("core_gone")
				if reason == "destroyed" and t.alive():
					_neutral_discharge(t, HitQuery.flat(o.global_position))})
		t.recast(LIFE, func(rt: Tk) -> void:
			if is_instance_valid(core) and core.is_alive():
				_release(rt, core))

	func _scan(t: Tk, core: KitObject) -> void:
		if not t.alive():
			return
		var hp: Dictionary = core.data.hp
		var air: Dictionary = core.data.air
		for f: CombatCharacter in t.fighters():
			var key: int = f.get_instance_id()
			var cur: float = f.health.current_health
			if t.distance(f.global_position, core.global_position) > float(core.data.zone):
				hp.erase(key)
				air.erase(key)
				continue
			if float(hp.get(key, cur)) - cur >= 12.0:
				K.add_charge(t, core, 1)
			hp[key] = cur
			var up: bool = f.is_launched()
			if up and not bool(air.get(key, false)):
				K.add_charge(t, core, 1)
			air[key] = up
		core.data["idle"] = float(core.data.idle) + 0.1
		if float(core.data.idle) >= 6.0:
			core.data["idle"] = 0.0
			K.add_charge(t, core, 1)

	func _release(t: Tk, core: KitObject) -> void:
		var n: int = int(core.data.charge)
		var pos: Vector3 = HitQuery.flat(core.global_position)
		core.destroy("released")
		var rings: int = clampi(1 + n / 2, 1, 6)
		var max_r: float = minf(3.0 + 0.6 * n, 11.0)
		var dmg: float = t.dmg(minf(0.35 + 0.06 * n, 0.9))
		t.fx("implosion", pos, 1.5, Color(0.9, 0.6, 0.25))
		for i in rings:
			var r_in: float = max_r * i / rings
			var r_out: float = max_r * (i + 1) / rings
			var last: bool = i == rings - 1
			t.after(0.25 * i, func(rt: Tk) -> void:
				rt.fx("wave", pos, r_out, STONE)
				for e: CombatCharacter in rt.enemies_in(pos, r_out):
					if rt.distance(e.global_position, pos) + HitQuery.HURTBOX_RADIUS < r_in:
						continue
					var opts: Dictionary = {"slow": 0.8}
					if last and n >= 6:
						opts["stun"] = 0.35
					rt.hit(e, dmg, opts))

	func _neutral_discharge(t: Tk, pos: Vector3) -> void:
		t.fx("wave", pos, 3.0, STONE)
		for f: CombatCharacter in t.fighters():
			if t.distance(f.global_position, pos) <= 3.0:
				t.push(f, HitQuery.flat(f.global_position - pos), 2.0, 0.3)
