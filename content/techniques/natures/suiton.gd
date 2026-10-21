extends RefCounted
## Technique kit: Suiton — vrais jutsu de Naruto Shinobi Striker.

const KIT_ID := &"suiton"
const SIGNATURE = null
const TECHNIQUES := {
	&"suiton_d_barriere_d_eau": BarriereDEau,
	&"suiton_d_pilier_d_eau": PilierDEau,
	&"suiton_c_prison_aqueuse": PrisonAqueuseClones,
	&"suiton_c_ondulation": Ondulation,
	&"suiton_b_dragon_aqueux": DragonAqueux,
	&"suiton_b_jutsu_secret_deploiement_aqueux_fatal": DeploiementAqueuxFatal,
	&"suiton_a_requin_elementaire_aqueux": RequinElementaire,
	&"suiton_a_camouflage_dans_la_brume": CamouflageBrume,
	&"suiton_s_prison_aqueuse": PrisonAqueuseGeante,
	&"suiton_s_grand_requin_aqueux": GrandRequin,
}

const WATER := Color(0.25, 0.6, 1.0)


class K:
	static func defense_down(t: Tk, e: CombatCharacter, s: float, mult: float = 1.2) -> void:
		if is_instance_valid(e) and t.is_enemy(e):
			t.debuff(e, "suiton_defense", s, {"damage_taken": mult, "label": "Défense -", "color": WATER})

	## Shark hit: reduces the target's usable ninjutsu (ninjutsu sealed).
	static func shark_bite(t: Tk, e: CombatCharacter, mult: float, seal: float) -> void:
		t.hit(e, t.dmg(mult), {"seal": seal, "push": 1.0})
		t.text(e, "SCELLÉ")


## D — Barrière d'eau (Suijinheki tranchant) : jet d'eau à haute pression qui
## blesse et réduit la défense ; au sol, un geyser jaillit en plus.
class BarriereDEau extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.25
		a.recovery_time = 0.3
		a.max_range = 9.0
		a.anim = &"breath"

	func cast(t: Tk) -> void:
		t.fx("wave", t.origin + t.dir * 4.0, 1.5, WATER)
		for e: CombatCharacter in t.line(9.0, 1.0, t.dmg(0.5)):
			K.defense_down(t, e, 4.0)
		var at: Vector3 = t.clear_point(t.origin, t.dir, 9.0)
		t.after(0.3, func(rt: Tk) -> void:
			rt.fx("column", at, 1.4, WATER)
			rt.area(at, 1.4, rt.dmg(0.35), {"launch": 0.4}))


## D — Pilier d'eau : colonne d'eau sur le lanceur qui neutralise les attaques
## (projectiles bloqués, lanceur protégé) et projette en l'air les ennemis au
## contact. Recast : la colonne se change en Dragon aqueux.
class PilierDEau extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.15
		a.recovery_time = 0.2
		a.max_range = 2.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var at: Vector3 = t.origin
		t.fx("column", at, 2.2, WATER)
		t.area(at, 2.2, t.dmg(0.5), {"launch": 0.8})
		t.buff("pilier_d_eau", 2.5, {"damage_taken": 0.2, "label": "Pilier d'eau", "color": WATER})
		var pillar: KitObject = t.object(at, {"kind": "pilier", "radius": 2.0, "lifetime": 2.5, "health": -1.0,
			"look": KitObject.Look.PILLAR, "targetable": false, "color": WATER, "blocks_projectiles": true})
		t.recast(2.5, func(rt: Tk) -> void:
			var from: Vector3 = pillar.global_position if is_instance_valid(pillar) and pillar.is_alive() else rt.origin
			if is_instance_valid(pillar) and pillar.is_alive():
				pillar.destroy("dragon")
			rt.projectile({"from": from, "speed": 18.0, "range": 13.0, "radius": 1.0, "size": 0.6, "pierce": true,
				"color": WATER, "on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
					rt.hit(e, rt.dmg(0.6), {"slow": 2.0, "push": 2.0})
					return true}))


## C — Prison aqueuse (clones) : charge qui projette des clones d'eau ;
## l'ennemi touché est enfermé dans une cage d'eau : dégâts continus,
## permutation bloquée (racine) et dégâts subis augmentés.
class PrisonAqueuseClones extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.recovery_time = 0.3
		a.max_range = 6.0
		a.anim = &"dash"

	func cast(t: Tk) -> void:
		t.dash(4.5, t.dir, 0.2)
		t.after(0.2, func(rt: Tk) -> void:
			for e: CombatCharacter in rt.melee(2.2, 100.0, rt.dmg(0.3), {"root": 2.5}):
				K.defense_down(rt, e, 3.0, 1.25)
				rt.fx("spheres", e.global_position, 1.2, WATER)
				var target: CombatCharacter = e
				rt.channel(5, 0.5, func(ct: Tk, _i: int) -> void:
					if is_instance_valid(target) and ct.is_enemy(target):
						ct.hit(target, ct.dmg(0.12)), Callable(), 1.0))


## C — Ondulation (Sazanami) : les bras s'étirent vers la cible, l'attirent et
## drainent ses PV pour soigner le lanceur.
class Ondulation extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.recovery_time = 0.3
		a.max_range = 7.0
		a.anim = &"thrust"

	func cast(t: Tk) -> void:
		for e: CombatCharacter in t.enemies_in_line(t.origin, t.dir, 7.0, 1.2):
			var dmg: float = t.dmg(0.65)
			t.hit(e, dmg)
			t.pull(e, t.origin + t.dir * 1.2)
			t.heal(t.caster, dmg * 0.6)
			t.fx("spheres", e.global_position, 0.8, WATER)
			break
		t.line(7.0, 0.6, 0.0)


## B — Dragon aqueux : dragon d'eau qui traverse les obstacles et frappe la
## cible, infligeant des dégâts et réduisant sa vitesse.
class DragonAqueux extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.4
		a.recovery_time = 0.3
		a.cast_move_multiplier = 0.2
		a.max_range = 16.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		t.projectile({"speed": 18.0, "range": 16.0, "radius": 1.1, "size": 0.65, "pierce": true, "homing": 1.2,
			"hit_in_flight": true, "color": WATER,
			"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
				t.hit(e, t.dmg(0.8), {"slow": 2.5, "push": 2.0})
				return true,
			"on_end": func(point: Vector3, _p: TkProjectile, _reason: String) -> void:
				t.fx("wave", point, 1.8, WATER)})


## B — Déploiement aqueux fatal : flaque sous le lanceur qui emprisonne les
## ennemis et les crible d'éclats de glace ; scelle les ninjutsu et augmente
## les dégâts subis.
class DeploiementAqueuxFatal extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.25
		a.recovery_time = 0.25
		a.max_range = 3.0
		a.anim = &"stomp"

	func cast(t: Tk) -> void:
		var at: Vector3 = t.origin
		t.fx("wave", at, 3.2, WATER)
		t.zone(at, 3.2, 1.2, {"kind": "flaque", "look": KitObject.Look.DISC, "targetable": false, "color": WATER})
		for e: CombatCharacter in t.area(at, 3.2, t.dmg(0.35), {"root": 1.2, "seal": 2.5}):
			K.defense_down(t, e, 4.0, 1.25)
		t.after(0.4, func(rt: Tk) -> void:
			rt.fx("spikes", at, 3.2, Color(0.75, 0.9, 1.0))
			rt.area(at, 3.2, rt.dmg(0.45)))


## A — Requin élémentaire aqueux : requins d'eau qui tournent autour du lanceur
## puis fondent sur la cible ; à l'impact, réduisent ses ninjutsu (sceau).
class RequinElementaire extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.recovery_time = 0.25
		a.max_range = 16.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var target: CombatCharacter = t.target_at_aim(3.0)
		if target == null:
			target = t.nearest_enemy(t.origin, 16.0)
		for i in 3:
			var d: Vector3 = t.dir.rotated(Vector3.UP, deg_to_rad(120.0 * i + 90.0))
			t.projectile({"from": t.origin + d * 1.2, "dir": d.rotated(Vector3.UP, deg_to_rad(90.0)), "speed": 14.0,
				"range": 22.0, "radius": 0.55, "size": 0.3, "homing": 0.0, "color": WATER,
				"on_tick": func(p: TkProjectile, _dt: float) -> void:
					if p.age > 0.45 and not p.data.get("go", false):
						p.data["go"] = true
						p.homing = 4.0
						if is_instance_valid(target):
							p.homing_target = target
							p.direction = HitQuery.flat(target.global_position - p.global_position).normalized()
						else:
							p.direction = t.dir,
				"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
					K.shark_bite(t, e, 0.22, 2.0)
					return false})


## A — Camouflage dans la brume (Kirigakure) : brouillard étendu ; les ennemis
## dedans sont aveuglés, ralentis et ne peuvent permuter (racine courte) ; le
## lanceur et ses alliés gagnent puissance et vitesse.
class CamouflageBrume extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.recovery_time = 0.2
		a.max_range = 3.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var at: Vector3 = t.origin
		t.fx("smoke", at, 7.0, Color(0.8, 0.85, 0.9))
		t.buff("brume_puissance", 8.0, {"damage_dealt": 1.25, "speed": 1.15, "label": "Brume", "color": WATER})
		t.zone(at, 7.0, 8.0, {"kind": "brume", "look": KitObject.Look.DISC, "targetable": false,
			"color": Color(0.8, 0.85, 0.9), "tick_interval": 0.5,
			"on_tick": func(o: KitObject) -> void:
				for e: CombatCharacter in o.enemies_inside():
					t.debuff(e, "brume_aveugle", 0.7, {"speed": 0.7, "damage_dealt": 0.85, "label": "Brume",
						"color": Color(0.6, 0.6, 0.7)})
				for al: CombatCharacter in t.allies_in(o.global_position, o.radius, false):
					t.status(al, StatusController.Type.HASTE, 0.7)})


## S — Prison aqueuse (ultime) : une boule d'eau emprisonne la cible puis
## s'étend peu à peu sur une large zone, paralysant et blessant en continu.
class PrisonAqueuseGeante extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.45
		a.recovery_time = 0.3
		a.max_range = 14.0
		a.anim = &"palm"

	func cast(t: Tk) -> void:
		var target: CombatCharacter = t.target_at_aim(3.0)
		var at: Vector3 = HitQuery.flat(target.global_position) if target != null else t.aim
		if target != null:
			t.hit(target, t.dmg(0.4), {"stun": 1.5})
		t.fx("spheres", at, 1.5, WATER)
		t.zone(at, 1.5, 5.0, {"kind": "prison_geante", "look": KitObject.Look.RING, "targetable": false,
			"color": WATER, "tick_interval": 0.5,
			"on_tick": func(o: KitObject) -> void:
				o.radius = minf(6.0, 1.5 + o.age * 1.2)
				t.fx("spheres", o.global_position, o.radius, WATER)
				for e: CombatCharacter in t.enemies_in(o.global_position, o.radius):
					t.hit(e, t.dmg(0.2), {"stun": 0.6})})


## S — Grand requin aqueux (ultime) : balle d'eau géante en forme de requin ;
## touche lourdement, explose en vague et scelle les ninjutsu.
class GrandRequin extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.55
		a.recovery_time = 0.4
		a.cast_move_multiplier = 0.0
		a.max_range = 18.0
		a.anim = &"palm"

	func cast(t: Tk) -> void:
		t.projectile({"speed": 15.0, "range": 18.0, "radius": 1.6, "size": 1.0, "homing": 0.8, "color": WATER,
			"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
				K.shark_bite(t, e, 1.2, 4.0)
				return false,
			"on_end": func(point: Vector3, _p: TkProjectile, reason: String) -> void:
				if reason == "recast":
					return
				t.fx("wave", point, 3.5, WATER)
				for e: CombatCharacter in t.area(point, 3.5, t.dmg(0.6), {"push": 3.0}):
					t.status(e, StatusController.Type.SEAL, 3.0)})
