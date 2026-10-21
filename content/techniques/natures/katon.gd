extends RefCounted
## Technique kit: Katon — vrais jutsu de Naruto Shinobi Striker.

const KIT_ID := &"katon"
const SIGNATURE = null
const TECHNIQUES := {
	&"katon_d_boules_de_feu": BoulesDeFeu,
	&"katon_d_technique_de_la_balsamine": Balsamine,
	&"katon_c_boule_de_feu_supreme": BouleDeFeuSupreme,
	&"katon_c_feu_du_dragon": FeuDuDragon,
	&"katon_b_embrasement_infernal_du_dragon": EmbrasementInfernal,
	&"katon_b_nuees_ardentes": NueesArdentes,
	&"katon_a_embrasement_supreme": EmbrasementSupreme,
	&"katon_a_meteores_de_feu": MeteoresDeFeu,
	&"katon_s_grandes_boules_de_feu": GrandesBoulesDeFeu,
	&"katon_s_invocation_enra": InvocationEnra,
}

const FIRE := Color(1.0, 0.45, 0.1)


class K:
	## Small fireball that explodes on impact (or at the end of its range).
	static func fireball(t: Tk, from: Vector3, d: Vector3, rng: float, speed: float, size: float, mult: float,
			blast: float, opts: Dictionary = {}, homing: float = 0.0) -> TkProjectile:
		return t.projectile({"from": from, "dir": d, "speed": speed, "range": rng, "radius": maxf(0.4, size * 1.6),
			"size": size, "homing": homing, "color": FIRE,
			"on_end": func(point: Vector3, _p: TkProjectile, reason: String) -> void:
				if reason == "recast":
					return
				t.fx("explosion", point, blast, FIRE)
				t.area(point, blast, t.dmg(mult), opts)})


## D — Boules de feu : crache plusieurs petites boules de feu à tête
## chercheuse qui filent vers la cible et explosent à l'impact.
class BoulesDeFeu extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.recovery_time = 0.25
		a.max_range = 15.0
		a.anim = &"breath"

	func cast(t: Tk) -> void:
		for i in 3:
			t.after(0.1 * i, func(rt: Tk) -> void:
				K.fireball(rt, rt.origin, t.dir.rotated(Vector3.UP, deg_to_rad(-10.0 + 10.0 * i)), 15.0, 22.0, 0.2,
					0.25, 1.0, {}, 2.0))


## D — Balsamine (Hosenka) : salve de nombreuses boules de feu en éventail,
## redoutable à courte portée (toutes touchent au corps à corps).
class Balsamine extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.15
		a.recovery_time = 0.25
		a.max_range = 12.0
		a.anim = &"breath"

	func cast(t: Tk) -> void:
		for i in 5:
			K.fireball(t, t.origin, t.dir.rotated(Vector3.UP, deg_to_rad(-20.0 + 10.0 * i)), 12.0, 24.0, 0.18,
				0.18, 0.8, {"burn": 1.0})


## C — Boule de feu suprême : une grosse boule de feu en ligne droite qui
## explose dans une large déflagration.
class BouleDeFeuSupreme extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.35
		a.recovery_time = 0.3
		a.cast_move_multiplier = 0.3
		a.max_range = 14.0
		a.anim = &"breath"

	func cast(t: Tk) -> void:
		K.fireball(t, t.origin, t.dir, 14.0, 17.0, 0.6, 0.8, 2.6, {"burn": 2.0, "push": 1.5})


## C — Feu du dragon (Ryuka) : shuriken relié à un filin ; s'il touche, la
## cible est immobilisée puis les flammes courent le long du filin et la
## brûlent. Le filin reste et ralentit les ennemis à proximité.
class FeuDuDragon extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.recovery_time = 0.3
		a.max_range = 13.0
		a.anim = &"throw"

	func cast(t: Tk) -> void:
		var from: Vector3 = t.origin
		t.projectile({"speed": 30.0, "range": 13.0, "radius": 0.5, "size": 0.15, "color": Color(0.8, 0.8, 0.85),
			"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
				t.hit(e, t.dmg(0.2), {"root": 1.2})
				var at: Vector3 = HitQuery.flat(e.global_position)
				t.after(0.35, func(rt: Tk) -> void:
					if is_instance_valid(e) and rt.is_enemy(e):
						rt.fx("column", e.global_position, 1.2, FIRE)
						rt.line(rt.distance(from, e.global_position) + 0.5, 1.0, rt.dmg(0.25), {}, from,
							HitQuery.flat(e.global_position - from).normalized())
						rt.hit(e, rt.dmg(0.5), {"burn": 3.0}))
				_wire(t, from, at)
				return false,
			"on_end": func(point: Vector3, _p: TkProjectile, reason: String) -> void:
				if reason != "hit":
					_wire(t, from, point)})

	func _wire(t: Tk, from: Vector3, to: Vector3) -> void:
		var mid: Vector3 = (from + to) * 0.5
		var d: Vector3 = HitQuery.flat(to - from)
		var length: float = maxf(1.0, d.length())
		t.wall(mid, d.normalized() if d.length() > 0.01 else t.dir, length, 5.0, {"kind": "filin", "thickness": 0.15,
			"blocks_projectiles": false, "blocks_movement": false, "health": -1.0, "targetable": false,
			"color": Color(0.85, 0.85, 0.9), "tick_interval": 0.5,
			"on_tick": func(o: KitObject) -> void:
				for e: CombatCharacter in t.enemies_in(o.global_position, length * 0.5 + 1.0):
					t.status(e, StatusController.Type.SLOW, 0.6)})


## B — Embrasement infernal du dragon : une tête de dragon crache une série de
## flammes chargées de chakra qui éclatent en boules de feu brûlantes.
class EmbrasementInfernal extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.35
		a.recovery_time = 0.3
		a.cast_move_multiplier = 0.2
		a.max_range = 15.0
		a.anim = &"breath"

	func cast(t: Tk) -> void:
		for i in 4:
			t.after(0.15 * i, func(rt: Tk) -> void:
				K.fireball(rt, rt.origin, t.dir.rotated(Vector3.UP, deg_to_rad(randf_range(-6.0, 6.0))), 15.0,
					20.0, 0.35, 0.3, 1.6, {"burn": 2.5}))


## B — Nuées ardentes : souffle de cendres en cône qui fait tressaillir et
## aveugle (ralenti). Recast (ou n'importe quel Katon) : les cendres
## explosent et brûlent en continu.
class NueesArdentes extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.25
		a.recovery_time = 0.25
		a.max_range = 6.0
		a.anim = &"breath"

	func cast(t: Tk) -> void:
		var center: Vector3 = t.origin + t.dir * 3.5
		t.fx("smoke", center, 3.0, Color(0.4, 0.38, 0.36))
		t.cone(6.0, 60.0, t.dmg(0.2), {"stun": 0.3, "slow": 2.5})
		var ash: KitObject = t.zone(center, 3.0, 6.0, {"kind": "cendres", "look": KitObject.Look.DISC,
			"targetable": false, "color": Color(0.45, 0.42, 0.4), "tick_interval": 0.5,
			"on_tick": func(o: KitObject) -> void:
				for e: CombatCharacter in o.enemies_inside():
					t.debuff(e, "cendres_aveugle", 0.6, {"speed": 0.8, "label": "Aveuglé", "color": Color(0.5, 0.5, 0.5)})})
		t.recast(5.0, func(rt: Tk) -> void:
			if not is_instance_valid(ash) or not ash.is_alive():
				return
			var at: Vector3 = ash.global_position
			ash.destroy("ignited")
			rt.fx("explosion", at, 3.2, FIRE)
			rt.area(at, 3.2, rt.dmg(0.6), {"burn": 4.0}))


## A — Embrasement suprême (Gōka Mekkyaku) : après une charge, une immense
## vague de feu déferle devant le lanceur ; le souffle repousse les ennemis.
class EmbrasementSupreme extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.6
		a.recovery_time = 0.4
		a.cast_move_multiplier = 0.0
		a.max_range = 14.0
		a.anim = &"breath"

	func cast(t: Tk) -> void:
		for i in 3:
			t.after(0.2 * i, func(rt: Tk) -> void:
				var reach: float = 5.0 + 4.5 * i
				rt.fx("wave", t.origin + t.dir * reach * 0.6, 2.5 + i, FIRE)
				rt.cone(reach, 55.0, rt.dmg(0.4), {"burn": 2.0, "push": 2.0}, t.origin, t.dir))


## A — Météores de feu : un clone surgit dans les airs et bombarde la zone de
## boules de feu ; les ennemis doivent s'en occuper (clone ciblable) et le
## lanceur devient brièvement invulnérable.
class MeteoresDeFeu extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.25
		a.recovery_time = 0.2
		a.max_range = 12.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		t.buff("meteores_invuln", 1.5, {"untargetable": true, "damage_taken": 0.0, "label": "Invulnérable", "color": FIRE})
		var at: Vector3 = t.aim
		t.object(at, {"kind": "clone_meteores", "radius": 0.7, "lifetime": 5.0, "health": 40.0,
			"look": KitObject.Look.DECOY, "targetable": true, "color": FIRE, "tick_interval": 0.6,
			"on_tick": func(o: KitObject) -> void:
				var target: CombatCharacter = t.nearest_enemy(o.global_position, 10.0)
				var where: Vector3 = target.global_position if target != null else \
					o.global_position + Vector3(randf_range(-3.0, 3.0), 0.0, randf_range(-3.0, 3.0))
				where = HitQuery.flat(where)
				t.fx("explosion", where, 1.3, FIRE)
				t.area(where, 1.3, t.dmg(0.22))})


## S — Grandes boules de feu (ultime) : énormes boules de feu projetées devant
## le lanceur sur une zone très large, touchant de nombreuses cibles.
class GrandesBoulesDeFeu extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.5
		a.recovery_time = 0.45
		a.cast_move_multiplier = 0.0
		a.max_range = 9.0
		a.anim = &"breath"

	func cast(t: Tk) -> void:
		for i in 5:
			t.after(0.08 * i, func(rt: Tk) -> void:
				K.fireball(rt, t.origin, t.dir.rotated(Vector3.UP, deg_to_rad(-36.0 + 18.0 * i)), 8.0, 16.0, 0.8,
					0.45, 3.0, {"burn": 3.0, "push": 2.5}))
		t.cone(4.0, 90.0, t.dmg(0.4), {"burn": 2.0})


## S — Invocation : Enra (ultime) : Enra encercle les ennemis proches, brûle en
## continu, ralentit et scelle la permutation. Recast : Scellement adamantin
## — la Poigne du singe plaque les ennemis au sol.
class InvocationEnra extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.4
		a.recovery_time = 0.3
		a.max_range = 7.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var at: Vector3 = t.aim
		t.fx("ring", at, 4.5, FIRE)
		var ring: KitObject = t.zone(at, 4.5, 6.0, {"kind": "enra", "look": KitObject.Look.RING, "targetable": false,
			"color": FIRE, "tick_interval": 0.5,
			"on_tick": func(o: KitObject) -> void:
				for e: CombatCharacter in o.enemies_inside():
					t.hit(e, t.dmg(0.15), {"slow": 0.6, "seal": 0.6})})
		t.recast(6.0, func(rt: Tk) -> void:
			var c: Vector3 = ring.global_position if is_instance_valid(ring) and ring.is_alive() else at
			rt.fx("rocks", c, 4.5, Color(0.6, 0.5, 0.3))
			rt.fx("cracks", c, 4.5)
			rt.area(c, 4.5, rt.dmg(1.0), {"stun": 1.5, "unblockable": true})
			if is_instance_valid(ring) and ring.is_alive():
				ring.destroy("sealed"))
