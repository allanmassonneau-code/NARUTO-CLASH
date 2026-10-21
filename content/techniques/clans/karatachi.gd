extends RefCounted
## Kit clan_karatachi (Kiri, kit de Mei) — jutsu Shinobi Striker : Pilier d'eau,
## Brouillard ingénieux, Crocs de Terre du Seigneur Légendaire, Dissolution
## monstrueuse, Invocation : Limace.

const KIT_ID := &"clan_karatachi"
const SIGNATURE = null
const TECHNIQUES := {
	&"clan_karatachi_d_pilier_d_eau": PilierDEau,
	&"clan_karatachi_c_brouillard_ingenieux": BrouillardIngenieux,
	&"clan_karatachi_b_crocs_de_terre_du_seigneur_legendaire": CrocsDeTerre,
	&"clan_karatachi_a_dissolution_monstrueuse": DissolutionMonstrueuse,
	&"clan_karatachi_s_invocation_limace": InvocationLimace,
}

const WATER := Color(0.25, 0.55, 1.0)
const ACID := Color(0.65, 0.85, 0.25)
const LAVA := Color(1.0, 0.45, 0.1)
const EARTH := Color(0.6, 0.45, 0.3)
const SLUG := Color(0.55, 0.75, 0.95)


## D — Technical (SS 2/1). Colonne d'eau sur soi : neutralise les projectiles,
## soulève les ennemis à l'apparition ; recast → Dragon aqueux.
class PilierDEau extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.recovery_time = 0.25
		a.max_range = 3.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		t.fx("column", t.origin, 2.0, WATER)
		t.area(t.origin, 2.2, t.dmg(0.8), {"launch": 0.7})
		t.object(t.origin, {"kind": "pilier_eau", "radius": 2.0, "lifetime": 3.0, "look": KitObject.Look.PILLAR,
			"color": WATER, "health": -1, "targetable": false, "blocks_projectiles": true})
		t.recast(3.0, func(rt: Tk) -> void:
			for o: KitObject in rt.objects("pilier_eau"):
				o.destroy("recast")
			rt.projectile({"speed": 20.0, "range": 16.0, "radius": 1.0, "size": 0.65, "pierce": true, "color": WATER,
				"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
					rt.hit(e, rt.dmg(0.6), {"slow": 2.0})
					return true}))


## C — Ranged (SS 5/3). Brume acide crachée en cône qui persiste : réduit la
## défense, ralentit et ronge en continu.
class BrouillardIngenieux extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.recovery_time = 0.3
		a.cast_move_multiplier = 0.3
		a.max_range = 8.0
		a.anim = &"breath"

	func cast(t: Tk) -> void:
		var center: Vector3 = t.origin + t.dir * 4.5
		t.fx("smoke", center, 3.5, ACID)
		t.cone(7.0, 55.0, t.dmg(0.4), {"slow": 2.0})
		t.zone(center, 3.5, 5.0, {"kind": "brume_acide", "color": ACID, "targetable": false, "tick_interval": 0.5,
			"on_tick": func(o: KitObject) -> void:
				for e: CombatCharacter in o.enemies_inside():
					if t.is_enemy(e):
						t.hit(e, t.dmg(0.1), {"slow": 0.7})
						t.debuff(e, "brume_acide", 1.0, {"damage_taken": 1.2, "label": "Corrodé", "color": ACID})})


## B — Ranged (SS 2/5). Créature-chien de terre lancée en ligne droite qui
## blesse au passage puis devient un terrain : accélère les alliés, explose
## au contact des ennemis.
class CrocsDeTerre extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.35
		a.recovery_time = 0.3
		a.max_range = 16.0
		a.anim = &"stomp"

	func cast(t: Tk) -> void:
		t.projectile({"speed": 16.0, "range": 16.0, "radius": 1.0, "size": 0.6, "pierce": true, "color": EARTH,
			"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
				t.hit(e, t.dmg(0.55), {"push": 1.5, "push_from": t.origin})
				t.fx("rocks", e.global_position, 0.8, EARTH)
				return true,
			"on_end": func(point: Vector3, _p: TkProjectile, _reason: String) -> void:
				_terrain(t, point)})

	func _terrain(t: Tk, at: Vector3) -> void:
		t.fx("cracks", at, 2.5, EARTH)
		t.zone(at, 2.5, 6.0, {"kind": "terrain_crocs", "color": EARTH, "targetable": false, "tick_interval": 0.3,
			"on_tick": func(o: KitObject) -> void:
				for f: CombatCharacter in o.allies_inside():
					if is_instance_valid(f):
						t.status(f, StatusController.Type.HASTE, 1.0)
				if not o.enemies_inside().is_empty() and not o.data.get("boom", false):
					o.data["boom"] = true
					t.fx("explosion", o.global_position, 2.5, EARTH)
					t.area(o.global_position, 2.8, t.dmg(0.6), {"launch": 0.5})
					o.destroy("exploded")})


## A — Ranged (SS 3/2). Crache trois boules de lave acide qui restent au sol :
## dégâts et ralentissement au contact.
class DissolutionMonstrueuse extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.recovery_time = 0.3
		a.cast_move_multiplier = 0.4
		a.max_range = 9.0
		a.anim = &"breath"

	func cast(t: Tk) -> void:
		for i in 3:
			var d: Vector3 = t.dir.rotated(Vector3.UP, deg_to_rad(-18.0 + 18.0 * i))
			t.projectile({"dir": d, "speed": 18.0, "range": 8.0, "radius": 0.6, "size": 0.35, "color": LAVA,
				"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
					t.hit(e, t.dmg(0.4), {"slow": 1.5})
					return false,
				"on_end": func(point: Vector3, _p: TkProjectile, _reason: String) -> void:
					t.fx("ember", point, 1.2, LAVA)
					t.zone(point, 1.3, 4.0, {"kind": "flaque_lave", "color": LAVA, "targetable": false,
						"tick_interval": 0.5, "on_tick": func(o: KitObject) -> void:
							for e: CombatCharacter in o.enemies_inside():
								if t.is_enemy(e):
									t.hit(e, t.dmg(0.1), {"slow": 0.8})})})


## S — Heal (SS 1/1). Invoque Katsuyu : objet-limace qui soigne et purifie
## les alliés autour, affaiblit les ennemis à portée et les paralyse par ses
## attaques ; disparaît à expiration ou détruite.
class InvocationLimace extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.5
		a.recovery_time = 0.4
		a.max_range = 3.0
		a.anim = &"heal"

	func cast(t: Tk) -> void:
		var at: Vector3 = t.origin + t.dir * 1.5
		t.fx("smoke", at, 2.0, SLUG)
		var heal_amount: float = t.dmg(0.35)
		t.heal(t.caster, heal_amount)
		t.cleanse(t.caster)
		t.object(at, {"kind": "limace", "radius": 4.5, "lifetime": 8.0, "health": 80.0, "look": KitObject.Look.DECOY,
			"color": SLUG, "targetable": true, "tick_interval": 1.0,
			"on_tick": func(o: KitObject) -> void:
				t.fx("ring", o.global_position, o.radius, SLUG)
				for f: CombatCharacter in t.allies_in(o.global_position, o.radius):
					if is_instance_valid(f):
						t.heal(f, heal_amount)
						t.cleanse(f)
				var n: int = 0
				for e: CombatCharacter in t.enemies_in(o.global_position, o.radius):
					t.debuff(e, "limace_faiblesse", 1.2, {"damage_dealt": 0.75, "label": "Affaibli", "color": SLUG})
					if n == 0:
						t.hit(e, t.dmg(0.12), {"stun": 0.5})
					n += 1})
