extends RefCounted
## Technique kit: Doton — vrais jutsu de Naruto Shinobi Striker.

const KIT_ID := &"doton"
const SIGNATURE = null
const TECHNIQUES := {
	&"doton_d_mur_de_boue": MurDeBoue,
	&"doton_d_solidification": Solidification,
	&"doton_c_garde_de_pierre": GardeDePierre,
	&"doton_c_voyage_souterrain": VoyageSouterrain,
	&"doton_b_souffle_du_dragon_de_terre": DragonDeTerre,
	&"doton_b_technique_de_pierre_allegee": PierreAllegee,
	&"doton_a_garde_de_pierre_alourdie": PierreAlourdie,
	&"doton_a_rocher_du_singe": RocherDuSinge,
	&"doton_s_piliers_de_la_terre": PiliersDeLaTerre,
	&"doton_s_confinement_hors_du_monde": ConfinementHorsDuMonde,
}

const EARTH := Color(0.6, 0.45, 0.28)
const DUST := Color(0.85, 0.85, 0.8)


class K:
	static func heavy(t: Tk, e: CombatCharacter, s: float, mult: float = 0.65) -> void:
		if is_instance_valid(e) and t.is_enemy(e):
			t.debuff(e, "doton_alourdi", s, {"speed": mult, "label": "Alourdi", "color": EARTH})


## D — Mur de boue (Doryūheki) : un mur de terre surgit devant le lanceur ; il
## bloque projectiles et passages jusqu'à expiration ou destruction.
class MurDeBoue extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.25
		a.recovery_time = 0.2
		a.max_range = 3.0
		a.anim = &"stomp"

	func cast(t: Tk) -> void:
		var at: Vector3 = t.origin + t.dir * 2.0
		t.fx("rocks", at, 2.0, EARTH)
		t.area(at, 1.2, t.dmg(0.3), {"push": 2.0})
		t.wall(at, t.dir.rotated(Vector3.UP, PI * 0.5), 5.0, 8.0, {"kind": "mur_de_boue", "thickness": 0.9,
			"health": 90.0, "color": EARTH})


## D — Solidification : le corps se couvre de pierre ; immobile, insensible
## aux attaques, soigné et défense accrue pendant la technique.
class Solidification extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.1
		a.recovery_time = 0.2
		a.max_range = 1.0
		a.anim = &"guard"

	func cast(t: Tk) -> void:
		t.fx("rocks", t.origin, 1.2, EARTH)
		t.buff("solidification", 2.5, {"damage_taken": 0.0, "speed": 0.0, "cc_immune": true,
			"label": "Solidifié", "color": EARTH})
		t.channel(5, 0.5, func(ct: Tk, _i: int) -> void:
			ct.heal(ct.caster, ct.dmg(0.15)), Callable(), 0.0)


## C — Garde de pierre (rocher alourdi) : alourdit les ennemis proches
## (vitesse et sauts réduits) et augmente la défense du lanceur.
class GardeDePierre extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.recovery_time = 0.2
		a.max_range = 5.0
		a.anim = &"palm"

	func cast(t: Tk) -> void:
		t.fx("dust", t.origin, 4.0, EARTH)
		for e: CombatCharacter in t.area(t.origin, 4.0, t.dmg(0.4), {"slow": 3.0}):
			K.heavy(t, e, 5.0)
		t.buff("garde_de_pierre", 6.0, {"damage_taken": 0.75, "label": "Garde de pierre", "color": EARTH})


## C — Voyage souterrain : le lanceur plonge dans le sol liquéfié ; il est
## intouchable et récupère des PV, mais ne peut attaquer, puis ressort.
class VoyageSouterrain extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.15
		a.recovery_time = 0.2
		a.max_range = 8.0
		a.anim = &"stomp"

	func cast(t: Tk) -> void:
		t.fx("dust", t.origin, 1.5, EARTH)
		t.buff("voyage_souterrain", 3.0, {"untargetable": true, "damage_taken": 0.0, "speed": 1.4,
			"basic_damage": 0.0, "label": "Sous terre", "color": EARTH})
		t.status(t.caster, StatusController.Type.IMMATERIAL, 3.0)
		t.channel(6, 0.5, func(ct: Tk, _i: int) -> void:
			ct.heal(ct.caster, ct.dmg(0.12)),
			func(dt: Tk, _completed: bool) -> void:
				dt.fx("rocks", dt.origin, 1.5, EARTH), 1.4)


## B — Souffle du dragon de terre : une tête de dragon fixe crache des balles
## de boue ; ralentit les cibles touchées.
class DragonDeTerre extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.35
		a.recovery_time = 0.25
		a.max_range = 10.0
		a.anim = &"stomp"

	func cast(t: Tk) -> void:
		var head_at: Vector3 = t.origin + t.dir * 1.5
		var aim_dir: Vector3 = t.dir
		t.fx("rocks", head_at, 1.2, EARTH)
		t.object(head_at, {"kind": "tete_dragon", "radius": 0.9, "lifetime": 3.2, "health": 50.0,
			"look": KitObject.Look.PILLAR, "color": EARTH, "tick_interval": 0.4,
			"on_tick": func(o: KitObject) -> void:
				var e: CombatCharacter = t.nearest_enemy(o.global_position, 12.0)
				var d: Vector3 = HitQuery.flat(e.global_position - o.global_position).normalized() if e != null else aim_dir
				t.projectile({"from": o.global_position, "dir": d, "speed": 20.0, "range": 11.0, "radius": 0.5,
					"size": 0.25, "color": EARTH,
					"on_hit": func(v: CombatCharacter, _p: TkProjectile) -> bool:
						t.hit(v, t.dmg(0.15), {"slow": 1.5})
						K.heavy(t, v, 2.0, 0.75)
						return false})})


## B — Technique de pierre allégée : allège le lanceur et ses alliés proches :
## vitesse de déplacement accrue et récupération du chakra accélérée.
class PierreAllegee extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.recovery_time = 0.15
		a.max_range = 6.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		t.fx("ring", t.origin, 6.0, DUST)
		for al: CombatCharacter in t.allies_in(t.origin, 6.0, false):
			t.status(al, StatusController.Type.HASTE, 8.0)
		t.buff("pierre_allegee", 8.0, {"speed": 1.3, "chakra_regen": 1.5, "label": "Allégé", "color": DUST})


## A — Garde de pierre alourdie : alourdit fortement les ennemis proches :
## lents, chakra qui se régénère moins, coups affaiblis.
class PierreAlourdie extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.25
		a.recovery_time = 0.2
		a.max_range = 6.0
		a.anim = &"palm"

	func cast(t: Tk) -> void:
		t.fx("implosion", t.origin, 6.0, EARTH)
		for e: CombatCharacter in t.enemies_in(t.origin, 6.0):
			t.hit(e, t.dmg(0.1), {"slow": 4.0})
			t.debuff(e, "pierre_alourdie", 6.0, {"speed": 0.55, "chakra_regen": 0.5, "damage_dealt": 0.85,
				"label": "Alourdi", "color": EARTH})
			t.text(e, "ALOURDI")


## A — Rocher du singe : un rocher en forme de singe enveloppe le lanceur
## (défense, insensible aux étourdissements) qui s'élance ; recast : coup de
## poing dont la puissance croît avec le temps passé en l'air.
class RocherDuSinge extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.recovery_time = 0.25
		a.max_range = 6.0
		a.anim = &"leap"

	func cast(t: Tk) -> void:
		var started: float = Time.get_ticks_msec() / 1000.0
		t.fx("rocks", t.origin, 1.5, EARTH)
		t.buff("rocher_du_singe", 4.0, {"damage_taken": 0.7, "tenacity": true, "speed": 1.2,
			"label": "Rocher du singe", "color": EARTH})
		t.dash(4.0, t.dir, 0.3)
		t.recast(4.0, func(rt: Tk) -> void:
			var air: float = clampf(Time.get_ticks_msec() / 1000.0 - started, 0.0, 4.0)
			rt.kit().remove_modifier("rocher_du_singe")
			rt.dash(2.5, rt.dir, 0.12)
			var at: Vector3 = rt.refreshed().origin + rt.dir * 1.5
			rt.fx("explosion", at, 2.0, EARTH)
			rt.area(at, 2.2, rt.dmg(0.8 + 0.25 * air), {"push": 3.5, "stun": 0.4}),
			func() -> void:
				if not t.alive():
					return
				var et: Tk = t.refreshed()
				var at: Vector3 = et.origin + et.dir * 1.5
				et.fx("rocks", at, 2.0, EARTH)
				et.area(at, 2.0, et.dmg(0.6), {"push": 2.5}))


## S — Piliers de la terre (Landslide, ultime) : onde de choc qui fracasse le
## sol, repousse violemment les ennemis à portée et les ralentit.
class PiliersDeLaTerre extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.45
		a.recovery_time = 0.35
		a.cast_move_multiplier = 0.0
		a.max_range = 7.0
		a.anim = &"stomp"

	func cast(t: Tk) -> void:
		for i in 3:
			t.after(0.15 * i, func(rt: Tk) -> void:
				var r: float = 2.5 + 2.2 * i
				rt.fx("cracks", t.origin, r, EARTH)
				rt.fx("spikes", t.origin, r, EARTH)
				for e: CombatCharacter in rt.area(t.origin, r, rt.dmg(0.55), {"push": 4.0, "push_from": t.origin, "slow": 3.0}):
					K.heavy(rt, e, 4.0, 0.6))


## S — Jinton : Confinement hors du monde (ultime) : un cube immense surgit
## devant le lanceur, assomme ceux qu'il touche et annule les projectiles ; une
## fois formé il projette des rochers qui immobilisent.
class ConfinementHorsDuMonde extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.5
		a.recovery_time = 0.35
		a.max_range = 7.0
		a.anim = &"palm"

	func cast(t: Tk) -> void:
		var at: Vector3 = t.origin + t.dir * 4.0
		t.fx("implosion", at, 3.0, DUST)
		t.area(at, 3.0, t.dmg(1.2), {"stun": 1.5, "unblockable": true})
		t.object(at, {"kind": "cube_jinton", "radius": 3.0, "lifetime": 3.0, "health": -1.0,
			"look": KitObject.Look.ORB, "targetable": false, "color": DUST, "blocks_projectiles": true,
			"tick_interval": 0.75,
			"on_projectile": func(_team: int, _point: Vector3) -> bool:
				return true,
			"on_tick": func(o: KitObject) -> void:
				for e: CombatCharacter in t.enemies_in(o.global_position, 8.0):
					t.projectile({"from": o.global_position, "dir": HitQuery.flat(e.global_position - o.global_position).normalized(),
						"speed": 22.0, "range": 9.0, "radius": 0.6, "size": 0.35, "color": EARTH,
						"on_hit": func(v: CombatCharacter, _p: TkProjectile) -> bool:
							t.hit(v, t.dmg(0.25), {"root": 1.2})
							return false})})
