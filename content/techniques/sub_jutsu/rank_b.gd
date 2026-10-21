extends RefCounted
## Sub-jutsu rang B — vrais jutsu universels de Shinobi Striker.

const KIT_ID := &"sub_rank_b"
const SIGNATURE = null
const TECHNIQUES := {
	&"sub_b_eclair_de_konoha": EclairDeKonoha,
	&"sub_b_rafale_de_konoha": RafaleDeKonoha,
	&"sub_b_byakugan": Byakugan,
	&"sub_b_regeneration_secrete": RegenerationSecrete,
	&"sub_b_purification_cellulaire": PurificationCellulaire,
	&"sub_b_argile_explosive_deux_oiseaux": DeuxOiseaux,
	&"sub_b_les_poignes_du_serpent_spectral": PoignesDuSerpent,
	&"sub_b_camouflage_dans_les_cendres": CamouflageCendres,
	&"sub_b_pluie_verte_de_soutien": PluieVerte,
	&"sub_b_rugissement_de_la_jeunesse": RugissementJeunesse,
	&"sub_b_technique_du_poing_souple_soufflage_de_c": SoufflageDeCorps,
	&"sub_b_invocation_crapaud": InvocationCrapaud,
}

const HEAL_GREEN := Color(0.4, 1.0, 0.5)


## Ruée vers la cible puis coup de talon écrasant (étourdit).
class EclairDeKonoha extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.12
		a.recovery_time = 0.3
		a.max_range = 7.0
		a.anim = &"kick"

	func cast(t: Tk) -> void:
		var target: CombatCharacter = t.target_at_aim(2.5)
		var to: Vector3 = target.global_position if target != null else t.aim
		var d: float = maxf(0.0, t.distance(t.origin, to) - 1.0)
		t.dash(d, t.dir, 0.15)
		t.after(0.16, func(rt: Tk) -> void:
			rt.fx("cracks", rt.caster.global_position + rt.dir, 1.2)
			rt.melee(2.2, 90.0, rt.dmg(0.8), {"stun": 0.6}))


## Ruée, bond et coups de pied qui envoient la cible en l'air.
class RafaleDeKonoha extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.12
		a.recovery_time = 0.3
		a.max_range = 6.0
		a.anim = &"kick"

	func cast(t: Tk) -> void:
		t.dash(4.5, t.dir, 0.15)
		t.after(0.16, func(rt: Tk) -> void:
			rt.fx("wave", rt.caster.global_position, 1.8)
			for e: CombatCharacter in rt.melee(2.3, 120.0, rt.dmg(0.8)):
				rt.launch(e, 0.9))


## Byakugan : révèle les ennemis proches (marque) et booste attaque + régén.
class Byakugan extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.max_range = 20.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		t.fx("ring", t.origin, 20.0, Color(0.85, 0.85, 1.0))
		t.buff("byakugan", 10.0, {"damage_dealt": 1.2, "label": "Byakugan", "color": Color(0.85, 0.85, 1.0),
			"on_tick": func(dt: float) -> void:
				if is_instance_valid(t.caster):
					t.heal(t.caster, t.dmg(0.05) * dt)})
		for e: CombatCharacter in t.enemies_in(t.origin, 20.0):
			t.mark(e, "revele", 1, 10.0, 1, "Révélé")
			t.text(e, "RÉVÉLÉ")


## Ninjutsu médical : soin régulier + résistance aux dégâts.
class RegenerationSecrete extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.25
		a.anim = &"heal"

	func cast(t: Tk) -> void:
		t.fx("spheres", t.origin, 1.2, HEAL_GREEN)
		t.status(t.caster, StatusController.Type.REGEN, 8.0)
		t.buff("regen_secrete", 8.0, {"damage_taken": 0.8, "label": "Régénération", "color": HEAL_GREEN,
			"on_tick": func(dt: float) -> void:
				if is_instance_valid(t.caster):
					t.heal(t.caster, t.dmg(0.12) * dt)})


## Soin instantané de tous les alliés à portée + purge des altérations.
class PurificationCellulaire extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.max_range = 7.0
		a.anim = &"heal"

	func cast(t: Tk) -> void:
		t.fx("wave", t.origin, 7.0, HEAL_GREEN)
		for ally: CombatCharacter in t.allies_in(t.origin, 7.0, true):
			t.cleanse(ally, true)
			t.heal(ally, t.dmg(1.5))
		t.buff("purifie", 1.5, {"label": "Purifié", "color": HEAL_GREEN})


## Deux oiseaux d'argile guidés qui explosent à l'impact.
class DeuxOiseaux extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.25
		a.recovery_time = 0.25
		a.max_range = 18.0
		a.anim = &"throw"

	func cast(t: Tk) -> void:
		for i in 2:
			var d: Vector3 = t.dir.rotated(Vector3.UP, deg_to_rad(-15.0 + 30.0 * i))
			t.projectile({"dir": d, "speed": 15.0, "range": 18.0, "radius": 0.6, "homing": 3.0, "size": 0.3,
				"color": Color(0.95, 0.9, 0.75),
				"on_end": func(point: Vector3, _p: TkProjectile, reason: String) -> void:
					if reason == "recast":
						return
					t.fx("explosion", point, 1.6)
					t.area(point, 1.6, t.dmg(0.45))})


## Groupe de serpents : morsure, poison sur la durée, soins réduits.
class PoignesDuSerpent extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.recovery_time = 0.25
		a.max_range = 4.0
		a.anim = &"thrust"

	func cast(t: Tk) -> void:
		t.fx("spikes", t.origin + t.dir * 2.0, 1.5, Color(0.5, 0.3, 0.7))
		for e: CombatCharacter in t.cone(4.0, 50.0, t.dmg(0.5), {"root": 0.4}):
			t.debuff(e, "venin", 5.0, {"heal_taken": 0.5, "label": "Venin", "color": Color(0.5, 0.3, 0.7)})
			t.status(e, StatusController.Type.DRAIN, 5.0)
			for i in 5:
				t.after(1.0 + i, func(rt: Tk) -> void:
					if is_instance_valid(e) and rt.is_enemy(e):
						rt.hit(e, rt.dmg(0.08)))


## Se cache dans les cendres : immatériel, purge, l'explosion de cendres frappe autour.
class CamouflageCendres extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.1
		a.max_range = 3.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		t.cleanse(t.caster, true)
		t.status(t.caster, StatusController.Type.IMMATERIAL, 1.2)
		t.fx("smoke", t.origin, 3.0, Color(0.4, 0.38, 0.36))
		t.area(t.origin, 3.0, t.dmg(0.5), {"push": 2.0, "push_from": t.origin})
		t.buff("cendres_cachette", 4.0, {"chakra_regen": 1.5, "label": "Cendres", "color": Color(0.5, 0.45, 0.4)})


## Kunai de soins projetés autour du lanceur pendant un temps : soignent les alliés.
class PluieVerte extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.anim = &"throw"

	func cast(t: Tk) -> void:
		t.zone(t.origin, 4.0, 5.0, {"kind": "pluie_verte", "color": HEAL_GREEN, "targetable": false, "tick_interval": 0.5,
			"on_tick": func(o: KitObject) -> void:
				t.fx("sparks", o.global_position, 4.0, HEAL_GREEN)
				for ally: CombatCharacter in t.allies_in(o.global_position, 4.0, true):
					t.heal(ally, t.dmg(0.15))})
		t.buff("pluie_verte", 5.0, {"chakra_regen": 1.4, "label": "Pluie verte", "color": HEAL_GREEN})


## Cri de guerre : paralyse les proches, purge les alliés, boost corps à corps.
class RugissementJeunesse extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.25
		a.max_range = 5.0
		a.anim = &"breath"

	func cast(t: Tk) -> void:
		t.fx("wave", t.origin, 5.0, Color(1.0, 0.8, 0.3))
		for e: CombatCharacter in t.enemies_in(t.origin, 5.0):
			t.hit(e, 0.0, {"stun": 1.0})
		for ally: CombatCharacter in t.allies_in(t.origin, 5.0, true):
			t.cleanse(ally)
		t.buff("jeunesse", 8.0, {"basic_damage": 1.3, "label": "Jeunesse", "color": Color(1.0, 0.8, 0.3)})


## Poing souple : rotation de chakra, purge, esquive, scelle et repousse, défense accrue.
class SoufflageDeCorps extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.1
		a.max_range = 2.5
		a.anim = &"palm"

	func cast(t: Tk) -> void:
		t.cleanse(t.caster, true)
		t.status(t.caster, StatusController.Type.IMMATERIAL, 0.6)
		t.fx("spheres", t.origin, 2.5, Color(0.7, 0.8, 1.0))
		t.area(t.origin, 2.5, t.dmg(0.8), {"seal": 2.0, "push": 2.5, "push_from": t.origin})
		t.buff("soufflage", 5.0, {"damage_taken": 0.75, "label": "Défense", "color": Color(0.7, 0.8, 1.0)})


## Invocation d'un crapaud : tire sur les ennemis (scelle le ninjutsu, affaiblit).
class InvocationCrapaud extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.35
		a.max_range = 5.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var at: Vector3 = t.clear_point(t.origin, t.dir, 2.0)
		t.fx("smoke", at, 1.5)
		t.object(at, {"kind": "crapaud", "radius": 1.0, "lifetime": 8.0, "health": 60.0, "look": KitObject.Look.PILLAR,
			"color": Color(0.9, 0.5, 0.2), "tick_interval": 1.0,
			"on_tick": func(o: KitObject) -> void:
				var e: CombatCharacter = t.nearest_enemy(o.global_position, 9.0)
				if e == null:
					return
				t.projectile({"from": o.global_position, "dir": HitQuery.flat(e.global_position - o.global_position).normalized(),
					"speed": 18.0, "range": 10.0, "radius": 0.5, "size": 0.25, "color": Color(0.6, 0.8, 1.0),
					"on_hit": func(h: CombatCharacter, _p: TkProjectile) -> bool:
						t.hit(h, t.dmg(0.25), {"stun": 0.3, "seal": 1.5})
						t.debuff(h, "crapaud_faiblesse", 3.0, {"damage_dealt": 0.8, "label": "Affaibli"})
						return false})})
