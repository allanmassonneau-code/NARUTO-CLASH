extends RefCounted
## Sub-jutsu rang A — vrais jutsu universels de Shinobi Striker.

const KIT_ID := &"sub_rank_a"
const SIGNATURE = null
const TECHNIQUES := {
	&"sub_a_dragon_c2": DragonC2,
	&"sub_a_invocation_grand_serpent": GrandSerpent,
	&"sub_a_moine_souriant": MoineSouriant,
	&"sub_a_force_du_hakke_qui_detruit_les_montagnes": HakkeMontagnes,
	&"sub_a_force_d_une_centaine_canon_floral": CanonFloral,
	&"sub_a_force_d_une_centaine_lumiere_eclatante": LumiereEclatante,
	&"sub_a_chant_des_grenouilles": ChantDesGrenouilles,
	&"sub_a_kumite_de_grenouille": KumiteDeGrenouille,
	&"sub_a_energie_naturelle_concentration": EnergieNaturelle,
	&"sub_a_prisme_de_flammes_des_uchiwa": PrismeDeFlammes,
}

const CLAY := Color(0.95, 0.9, 0.75)
const SAGE := Color(0.95, 0.6, 0.2)


## Dragon d'argile invoqué qui bombarde les ennemis de mines d'argile.
class DragonC2 extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.4
		a.max_range = 6.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var at: Vector3 = t.clear_point(t.origin, t.dir, 3.0)
		t.fx("smoke", at, 2.0, CLAY)
		t.object(at, {"kind": "dragon_c2", "radius": 1.3, "lifetime": 10.0, "health": 80.0, "look": KitObject.Look.PILLAR,
			"color": CLAY, "tick_interval": 1.2,
			"on_tick": func(o: KitObject) -> void:
				var e: CombatCharacter = t.nearest_enemy(o.global_position, 12.0)
				if e == null:
					return
				t.projectile({"from": o.global_position, "lob_to": e.global_position, "speed": 14.0, "size": 0.3, "color": CLAY,
					"on_end": func(point: Vector3, _p: TkProjectile, _r: String) -> void:
						t.fx("explosion", point, 1.4)
						t.area(point, 1.4, t.dmg(0.3))})})


## Grand serpent invoqué : frappe les ennemis proches, paralyse et scelle le ninjutsu.
class GrandSerpent extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.4
		a.max_range = 4.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var at: Vector3 = t.clear_point(t.origin, t.dir, 2.5)
		t.fx("smoke", at, 2.0, Color(0.5, 0.3, 0.7))
		t.area(at, 2.5, t.dmg(0.6), {"stun": 0.5, "seal": 2.0})
		t.object(at, {"kind": "grand_serpent", "radius": 1.4, "lifetime": 8.0, "health": 100.0,
			"look": KitObject.Look.PILLAR, "color": Color(0.5, 0.3, 0.7), "tick_interval": 1.5,
			"on_tick": func(o: KitObject) -> void:
				var e: CombatCharacter = t.nearest_enemy(o.global_position, 5.0)
				if e != null:
					t.fx("spikes", e.global_position, 1.0, Color(0.5, 0.3, 0.7))
					t.hit(e, t.dmg(0.35), {"stun": 0.4, "seal": 2.0})})


## Mains de bois jaillissant sous la cible : dégâts, ralentissement, esquive réduite.
class MoineSouriant extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.max_range = 15.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var target: CombatCharacter = t.target_at_aim(3.0)
		var at: Vector3 = target.global_position if target != null else t.aim
		t.telegraph(at, 2.2, 0.45, func(rt: Tk) -> void:
			rt.fx("spikes", at, 2.2, Color(0.55, 0.4, 0.25))
			for e: CombatCharacter in rt.area(at, 2.2, rt.dmg(0.8), {"slow": 3.0}):
				rt.debuff(e, "mains_de_bois", 3.0, {"speed": 0.7, "label": "Entravé", "color": Color(0.55, 0.4, 0.25)}))


## Coup de paume qui libère une onde de chakra perçante : scelle et affaiblit.
class HakkeMontagnes extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.recovery_time = 0.35
		a.max_range = 14.0
		a.anim = &"palm"

	func cast(t: Tk) -> void:
		t.fx("wave", t.origin + t.dir * 1.5, 1.5, Color(0.7, 0.8, 1.0))
		for e: CombatCharacter in t.line(14.0, 1.4, t.dmg(0.6), {"push": 2.0, "seal": 2.0}):
			t.debuff(e, "hakke_jauge", 5.0, {"damage_dealt": 0.85, "label": "Chakra brisé"})


## Canon floral : soigne le lanceur, boost attaque/résistance et régén des alliés.
class CanonFloral extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.max_range = 6.0
		a.anim = &"heal"

	func cast(t: Tk) -> void:
		t.fx("burst", t.origin, 6.0, Color(0.6, 0.4, 1.0))
		t.heal(t.caster, t.dmg(1.2))
		t.buff("canon_floral", 10.0, {"damage_dealt": 1.2, "damage_taken": 0.85, "chakra_regen": 1.3,
			"label": "Canon floral", "color": Color(0.6, 0.4, 1.0)})
		for ally: CombatCharacter in t.allies_in(t.origin, 6.0, true):
			t.status(ally, StatusController.Type.EMPOWER, 10.0)
			t.status(ally, StatusController.Type.REGEN, 10.0)


## Lumière éclatante : défense, force au corps à corps, contre-soin sur coup encaissé.
class LumiereEclatante extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.05
		a.anim = &"guard"

	func cast(t: Tk) -> void:
		t.fx("burst", t.origin, 1.5, Color(0.6, 0.4, 1.0))
		t.buff("lumiere_eclatante", 8.0, {"damage_taken": 0.7, "basic_damage": 1.35, "label": "Lumière éclatante",
			"color": Color(0.6, 0.4, 1.0)})
		t.buff("lumiere_contre", 1.0, {"uses": 1, "label": "Garde",
			"on_take": func(_hit: Variant, dmg: float) -> float:
				if is_instance_valid(t.caster):
					t.heal(t.caster, dmg)
				return dmg * 0.5})


## Chant des grenouilles : ondes ultrasoniques qui immobilisent ; les crapauds
## ermites (Fukusaku et Shima) restent et relancent des ondes (recast).
class ChantDesGrenouilles extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.35
		a.max_range = 12.0
		a.anim = &"breath"

	func cast(t: Tk) -> void:
		_wave(t)
		t.buff("crapauds_ermites", 8.0, {"label": "Crapauds ermites", "color": SAGE})
		t.recast(8.0, func(rt: Tk) -> void:
			_wave(rt))

	func _wave(t: Tk) -> void:
		t.fx("wave", t.origin + t.dir * 3.0, 3.0, SAGE)
		t.cone(12.0, 35.0, t.dmg(0.6), {"root": 1.5, "silence": 1.0})


## Kumite de grenouille : plongeon et impact explosif d'énergie naturelle,
## un clone enchaîne avec un Orbe tourbillonnant si la cible est touchée.
class KumiteDeGrenouille extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.25
		a.recovery_time = 0.3
		a.max_range = 7.0
		a.anim = &"leap"

	func cast(t: Tk) -> void:
		t.dash(minf(6.0, t.distance(t.origin, t.aim)), t.dir, 0.2)
		t.after(0.22, func(rt: Tk) -> void:
			var at: Vector3 = rt.caster.global_position
			rt.fx("explosion", at, 2.2, SAGE)
			var hits: Array[CombatCharacter] = rt.area(at, 2.2, rt.dmg(0.7), {"push": 2.0, "push_from": at})
			if hits.is_empty():
				return
			rt.after(0.3, func(ct: Tk) -> void:
				for e: CombatCharacter in hits:
					if is_instance_valid(e) and ct.is_enemy(e):
						ct.fx("spheres", e.global_position, 1.2, Color(0.4, 0.7, 1.0))
						ct.hit(e, ct.dmg(0.5), {"push": 3.0, "push_from": at})))


## Énergie naturelle : mode Ermite — physique amélioré, ne vacille plus.
class EnergieNaturelle extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.6
		a.cast_move_multiplier = 0.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		t.fx("column", t.origin, 1.5, SAGE)
		t.buff("mode_ermite", 12.0, {"damage_dealt": 1.25, "speed": 1.15, "tenacity": true,
			"label": "Mode Ermite", "color": SAGE})


## Prisme de flammes : barrière de feu protégeant lanceur et alliés d'une attaque, défense accrue.
class PrismeDeFlammes extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.max_range = 5.0
		a.anim = &"guard"

	func cast(t: Tk) -> void:
		t.fx("spheres", t.origin, 5.0, Color(1.0, 0.45, 0.1))
		for ally: CombatCharacter in t.allies_in(t.origin, 5.0, true):
			t.shield(ally, t.dmg(1.5), 6.0)
		t.buff("prisme_flammes", 6.0, {"damage_taken": 0.8, "label": "Prisme de flammes", "color": Color(1.0, 0.45, 0.1)})
		t.area(t.origin, 2.0, t.dmg(0.3), {"push": 2.0, "push_from": t.origin})
