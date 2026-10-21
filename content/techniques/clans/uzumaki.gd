extends RefCounted
## Technique kit: clan Uzumaki — Rasengan, Flying Raijin and sealing jutsu
## from Shinobi Striker (Naruto / Minato).

const KIT_ID := &"clan_uzumaki"
const SIGNATURE = null
const TECHNIQUES := {
	&"clan_uzumaki_d_orbe_tourbillonnant": OrbeTourbillonnant,
	&"clan_uzumaki_c_connexion_d_orbes_tourbillonnants": ConnexionDOrbes,
	&"clan_uzumaki_b_hiraishin": Hiraishin,
	&"clan_uzumaki_a_hiraishin_niveau_2": HiraishinNiveau2,
	&"clan_uzumaki_s_sceau_emprisonnant": SceauEmprisonnant,
}

const BLUE := Color(0.45, 0.75, 1.0)
const GOLD := Color(1.0, 0.85, 0.3)


## D — Rasengan: rush forward with the orb; on impact strong knockback and
## slow.
class OrbeTourbillonnant extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.recovery_time = 0.3
		a.max_range = 6.0
		a.anim = &"palm"

	func cast(t: Tk) -> void:
		var target: CombatCharacter = t.target_at_aim(3.0)
		var dist: float = 4.5 if target == null else clampf(t.distance(t.origin, target.global_position) - 1.0, 0.0, 6.0)
		t.dash(dist, t.dir, 0.15)
		t.after(0.16, func(rt: Tk) -> void:
			var at: Vector3 = rt.caster.global_position + rt.dir * 1.0
			rt.fx("spheres", at, 1.5, BLUE)
			rt.area(at, 1.6, rt.dmg(0.8), {"push": 6.0, "push_from": rt.caster.global_position, "slow": 2.0}))


## C — Rasengan Barrage with a clone: clone strikes in front; every enemy
## it hits then gets a Rasengan. Super armour during the attack.
class ConnexionDOrbes extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.25
		a.recovery_time = 0.3
		a.max_range = 8.0
		a.anim = &"palm"

	func cast(t: Tk) -> void:
		t.buff("connexion_armure", 1.0, {"tenacity": true, "label": "Armure", "color": BLUE})
		t.clone(t.origin + t.dir * 2.0, 1.0)
		var hits: Array[CombatCharacter] = t.line(8.0, 1.6, t.dmg(0.3), {"stun": 0.4})
		t.after(0.3, func(rt: Tk) -> void:
			for e: CombatCharacter in hits:
				if is_instance_valid(e) and rt.is_enemy(e):
					rt.fx("spheres", e.global_position, 1.3, BLUE)
					rt.hit(e, rt.dmg(0.55), {"push": 3.5, "push_from": rt.caster.global_position}))


## B — Flying Raijin: throws a marked kunai (attack/defence up); recast to
## teleport onto it.
class Hiraishin extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.1
		a.recovery_time = 0.15
		a.max_range = 14.0
		a.anim = &"throw"

	func cast(t: Tk) -> void:
		t.buff("hiraishin", 6.0, {"damage_dealt": 1.15, "damage_taken": 0.85, "label": "Hiraishin", "color": GOLD})
		t.projectile({"speed": 30.0, "range": 14.0, "radius": 0.4, "size": 0.12, "color": GOLD,
			"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
				t.hit(e, t.dmg(0.3))
				return false,
			"on_end": func(point: Vector3, _p: TkProjectile, _reason: String) -> void:
				t.object(point, {"kind": "kunai", "radius": 0.5, "lifetime": 6.0, "look": KitObject.Look.GLYPH,
					"targetable": false, "color": GOLD})})
		t.recast(6.0, func(rt: Tk) -> void:
			var kunais: Array[KitObject] = rt.objects("kunai")
			if kunais.is_empty():
				return
			var k: KitObject = kunais[kunais.size() - 1]
			if not is_instance_valid(k):
				return
			rt.fx("bolt", rt.caster.global_position, 1.0, GOLD)
			rt.blink(k.global_position)
			rt.fx("bolt", k.global_position, 1.2, GOLD)
			k.destroy("teleported"))


## A — Flying Raijin Level 2: kunai at the target; on hit, teleports above
## it and slams a Rasengan: slow and substitution sealed.
class HiraishinNiveau2 extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.15
		a.recovery_time = 0.3
		a.max_range = 12.0
		a.anim = &"throw"

	func cast(t: Tk) -> void:
		t.projectile({"speed": 32.0, "range": 12.0, "radius": 0.6, "size": 0.12, "homing": 2.0, "color": GOLD,
			"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
				t.hit(e, t.dmg(0.25), {"unblockable": true})
				t.after(0.15, func(rt: Tk) -> void:
					if not is_instance_valid(e) or not rt.is_enemy(e):
						return
					var at: Vector3 = HitQuery.flat(e.global_position)
					rt.fx("bolt", rt.caster.global_position, 1.0, GOLD)
					rt.blink(at - rt.dir * 1.0)
					rt.fx("spheres", at, 2.0, BLUE)
					rt.area(at, 2.0, rt.dmg(0.75), {"slow": 2.5, "seal": 2.5, "stun": 0.3}))
				return false})


## S (ultime SS) — Fuinjutsu Barrier Method: a seal spreads from the user,
## immobilising every enemy in range.
class SceauEmprisonnant extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.45
		a.recovery_time = 0.4
		a.max_range = 0.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		t.fx("ring", t.origin, 6.0, GOLD)
		t.zone(t.origin, 6.0, 1.0, {"kind": "sceau", "look": KitObject.Look.GLYPH, "targetable": false, "color": GOLD})
		for e: CombatCharacter in t.area(t.origin, 6.0, t.dmg(0.8), {"stun": 3.0, "seal": 4.0, "unblockable": true}):
			t.text(e, "SCELLÉ", GOLD)
			t.debuff(e, "sceau_emprisonnant", 4.0, {"damage_taken": 1.2, "label": "Sceau", "color": GOLD})
