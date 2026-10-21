extends RefCounted
## Kit clan_kugutsu : marionnettistes (jutsu Shinobi Striker).

const KIT_ID := &"clan_kugutsu"
const SIGNATURE = null
const TECHNIQUES := {
	&"clan_kugutsu_d_petrification": Petrification,
	&"clan_kugutsu_c_ranc_ur_de_la_terre_point_de_suture": PointDeSuture,
	&"clan_kugutsu_b_mille_mains": MilleMains,
	&"clan_kugutsu_a_assaut_de_rassemblement_de_limaille_de_f": LimailleDeFer,
	&"clan_kugutsu_s_arcanes_rouges_theatre_des_100_pantins": TheatreDes100Pantins,
}

const POISON := Color(0.6, 0.2, 0.8)


## Shared rules.
class K:
	## Poison (dégâts sur la durée) + soins reçus réduits de moitié.
	static func poison(t: Tk, e: CombatCharacter, seconds: float) -> void:
		if not t.is_enemy(e):
			return
		t.debuff(e, "poison_kugutsu", seconds, {"heal_taken": 0.5, "label": "Poison / anti-soin", "color": POISON})
		for i in int(seconds):
			t.after(1.0 + i, func(rt: Tk) -> void:
				if is_instance_valid(e) and rt.is_enemy(e):
					rt.hit(e, rt.dmg(0.06)))


## D — Pétrification (Technical) : fils de chakra qui immobilisent la cible ;
## coup critique (cible proche du point visé) = paralysie + permutation scellée.
class Petrification extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.recovery_time = 0.2
		a.max_range = 11.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		t.projectile({"speed": 28.0, "range": 11.0, "radius": 0.5, "size": 0.12, "color": Color(0.5, 0.8, 1.0),
			"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
				var crit: bool = t.distance(e.global_position, t.aim) < 1.2
				var opts: Dictionary = {"root": 2.0}
				if crit:
					opts = {"stun": 1.2, "seal": 3.0}
					t.text(e, "PARALYSÉ")
				t.hit(e, t.dmg(0.1), opts)
				return false})


## C — Rancœur de la Terre : Point de suture (Heal) : tentacules qui soignent
## les alliés proches et leur donnent un vol de vie temporaire.
class PointDeSuture extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.25
		a.recovery_time = 0.25
		a.max_range = 4.0
		a.anim = &"heal"

	func cast(t: Tk) -> void:
		t.fx("spikes", t.origin, 4.0, Color(0.3, 0.25, 0.2))
		for f: CombatCharacter in t.allies_in(t.origin, 4.0, true):
			t.heal(f, t.dmg(1.2))
			t.cleanse(f)
		t.buff("suture", 6.0, {"lifesteal": 0.3, "damage_taken": 0.85, "label": "Suture", "color": Color(0.6, 0.4, 0.3)})


## B — Mille Mains (Technical) : la poupée déploie une nuée de bras qui
## saisissent ; dégâts, poison, permutation scellée, soins réduits. Recast : second assaut.
class MilleMains extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.recovery_time = 0.3
		a.max_range = 9.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		_grab(t, t.origin, t.dir)
		t.recast(4.0, func(rt: Tk) -> void:
			_grab(rt, rt.origin, rt.dir))

	func _grab(t: Tk, from: Vector3, d: Vector3) -> void:
		t.fx("spikes", from + d * 4.5, 2.0, Color(0.55, 0.45, 0.35))
		for e: CombatCharacter in t.cone(9.0, 35.0, t.dmg(0.45), {"seal": 2.0, "root": 0.8}, from, d):
			if is_instance_valid(e):
				t.pull(e, from + d * 1.5, 3.0)
				K.poison(t, e, 4.0)


## A — Assaut de Rassemblement de Limaille de Fer (Ranged) : épines de fer
## aimanté ; laisse un amas au-dessus de la zone, recast = épine qui tombe.
class LimailleDeFer extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.recovery_time = 0.3
		a.max_range = 14.0
		a.anim = &"throw"

	func cast(t: Tk) -> void:
		var at: Vector3 = t.aim
		t.fx("spikes", at, 3.0, Color(0.25, 0.25, 0.3))
		for e: CombatCharacter in t.area(at, 3.0, t.dmg(0.6), {"push": 1.5, "push_from": at}):
			K.poison(t, e, 4.0)
		t.object(at, {"kind": "amas_fer", "radius": 1.0, "lifetime": 8.0, "look": KitObject.Look.ORB,
			"targetable": false, "color": Color(0.3, 0.3, 0.35)})
		t.recast(8.0, func(rt: Tk) -> void:
			for o: KitObject in rt.objects("amas_fer"):
				if not o.is_alive():
					continue
				var c: Vector3 = o.global_position
				rt.fx("column", c, 1.5, Color(0.3, 0.3, 0.35))
				for e: CombatCharacter in rt.area(c, 3.0, rt.dmg(0.35)):
					if is_instance_valid(e) and rt.distance(e.global_position, c) < 1.2:
						rt.hit(e, rt.dmg(0.35))
					K.poison(rt, e, 3.0)
				o.destroy("fallen"))


## S — Arcanes Rouges : Théâtre des 100 Pantins (FinishMove) : une centaine
## de marionnettes se jettent sur la zone ; vagues de dégâts, poison, anti-soin.
class TheatreDes100Pantins extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.5
		a.recovery_time = 0.4
		a.max_range = 14.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var at: Vector3 = t.aim
		t.fx("ring", at, 5.0, Color(0.8, 0.1, 0.1))
		for i in 5:
			t.after(0.2 * i, func(rt: Tk) -> void:
				rt.fx("spikes", at, 4.5, Color(0.6, 0.15, 0.15))
				for e: CombatCharacter in rt.area(at, 4.5, rt.dmg(0.36), {"root": 0.4}):
					if i == 0:
						K.poison(rt, e, 6.0))
