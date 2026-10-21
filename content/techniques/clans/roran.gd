extends RefCounted
## Kit clan_roran — jutsu Shinobi Striker du clan du vent d'éventail.

const KIT_ID := &"clan_roran"
const SIGNATURE = null
const TECHNIQUES := {
	&"clan_roran_d_lame_du_vent": LameDuVent,
	&"clan_roran_c_paume_celeste_du_hakke": PaumeCeleste,
	&"clan_roran_b_invocation_danse_du_faucheur": DanseDuFaucheur,
	&"clan_roran_a_grande_percee": GrandePercee,
	&"clan_roran_s_grande_coupe_du_dragon": GrandeCoupeDuDragon,
}

const WIND := Color(0.7, 1.0, 0.85)


## Anti-soin partagé (soins reçus réduits, approximé par un debuff étiqueté).
class K:
	static func anti_heal(t: Tk, e: CombatCharacter, s: float) -> void:
		t.debuff(e, "anti_soin_vent", s, {"heal_taken": 0.6, "label": "Soins -", "color": WIND})


## D — Ranged. Quatre tornades qui convergent vers les cibles proches :
## dégâts, soins réduits, projection en l'air.
class LameDuVent extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.25
		a.recovery_time = 0.3
		a.max_range = 12.0
		a.anim = &"slash"

	func cast(t: Tk) -> void:
		for i in 4:
			var d: Vector3 = t.dir.rotated(Vector3.UP, deg_to_rad(-45.0 + 30.0 * i))
			t.projectile({"dir": d, "speed": 11.0, "range": 12.0, "radius": 0.8, "homing": 3.0, "size": 0.4,
				"color": WIND,
				"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
					t.hit(e, t.dmg(0.22), {"launch": 0.6})
					K.anti_heal(t, e, 4.0)
					return false})


## C — Ranged. Onde de choc à longue portée : repousse, blesse et scelle les
## ninjutsu (silence).
class PaumeCeleste extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.recovery_time = 0.25
		a.max_range = 15.0
		a.anim = &"palm"

	func cast(t: Tk) -> void:
		t.fx("wave", t.origin + t.dir, 1.5, WIND)
		t.projectile({"speed": 30.0, "range": 15.0, "radius": 1.0, "pierce": true, "size": 0.5, "color": WIND,
			"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
				t.hit(e, t.dmg(0.5), {"push": 4.0, "silence": 2.0})
				return true})


## B — Ranged. Kamatari encercle la cible en tornade : dégâts continus,
## coupe ses bonus, puis fond sur elle pour un dernier coup.
class DanseDuFaucheur extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.recovery_time = 0.3
		a.max_range = 15.0
		a.anim = &"throw"

	func cast(t: Tk) -> void:
		t.projectile({"speed": 20.0, "range": 15.0, "radius": 0.8, "homing": 4.0, "size": 0.35, "color": WIND,
			"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
				_encircle(t, e)
				return false})

	func _encircle(t: Tk, e: CombatCharacter) -> void:
		t.text(e, "KAMATARI")
		t.debuff(e, "faucheur", 3.6, {"label": "Faucheur", "color": WIND})
		K.anti_heal(t, e, 3.6)
		for i in 8:
			t.after(0.4 * (i + 1), func(rt: Tk) -> void:
				if is_instance_valid(e) and rt.is_enemy(e):
					rt.fx("dust", e.global_position, 1.2, WIND)
					rt.hit(e, rt.dmg(0.08)))
		t.after(3.6, func(rt: Tk) -> void:
			if is_instance_valid(e) and rt.is_enemy(e):
				rt.fx("burst", e.global_position, 1.5, WIND)
				rt.hit(e, rt.dmg(0.4), {"push": 2.0}))


## A — Ranged. Puissant coup de vent en ligne droite qui traverse tout :
## dégâts, suivi réduit (ralentissement) et récupération de PV réduite.
class GrandePercee extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.recovery_time = 0.3
		a.max_range = 16.0
		a.anim = &"breath"

	func cast(t: Tk) -> void:
		t.projectile({"speed": 24.0, "range": 16.0, "radius": 1.4, "pierce": true, "size": 0.9, "color": WIND,
			"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
				t.hit(e, t.dmg(0.8), {"slow": 2.0, "push": 1.5})
				K.anti_heal(t, e, 5.0)
				return true})


## S — FinishMove. Immense tornade qui aspire en continu ; les ennemis pris
## dedans subissent des dégâts, soins réduits, et ne peuvent en sortir.
class GrandeCoupeDuDragon extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.45
		a.recovery_time = 0.4
		a.max_range = 9.0
		a.anim = &"slash"

	func cast(t: Tk) -> void:
		var at: Vector3 = t.aim
		t.fx("column", at, 3.5, WIND)
		t.zone(at, 3.5, 4.0, {"kind": "tornade_dragon", "look": KitObject.Look.RING, "targetable": false,
			"tick_interval": 0.4, "color": WIND,
			"on_tick": func(o: KitObject) -> void:
				for e: CombatCharacter in t.enemies_in(o.global_position, 7.5):
					t.pull(e, o.global_position, 1.5)
				for e: CombatCharacter in o.enemies_inside():
					t.hit(e, t.dmg(0.15), {"root": 0.5})
					K.anti_heal(t, e, 2.0),
			"on_expire": func(o: KitObject) -> void:
				t.fx("explosion", o.global_position, 3.5, WIND)
				t.area(o.global_position, 3.5, t.dmg(0.4), {"launch": 0.8})})
		t.area(at, 3.5, t.dmg(0.2))
