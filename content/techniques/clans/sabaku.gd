extends RefCounted
## Kit clan_sabaku — jutsu Shinobi Striker du clan Sabaku (sable).

const KIT_ID := &"clan_sabaku"
const SIGNATURE = null
const TECHNIQUES := {
	&"clan_sabaku_d_bouclier_de_sable": BouclierDeSable,
	&"clan_sabaku_c_bruine_de_sable": BruineDeSable,
	&"clan_sabaku_b_deferlante_de_sables_mouvants": DeferlanteSablesMouvants,
	&"clan_sabaku_a_sarcophage_de_sable": SarcophageDeSable,
	&"clan_sabaku_s_grand_mausolee_de_sable": GrandMausoleeDeSable,
}

const SAND := Color(0.85, 0.72, 0.45)


## D — Technical. Mur de sable qui bloque les attaques et neutralise celles des
## ennemis touchés ; la mobilité de l'utilisateur est réduite.
class BouclierDeSable extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.1
		a.recovery_time = 0.2
		a.max_range = 0.0
		a.anim = &"guard"

	func cast(t: Tk) -> void:
		t.wall(t.origin + t.dir * 1.5, t.dir, 4.0, 4.0, {"kind": "mur_sable", "color": SAND, "health": 60.0,
			"blocks_projectiles": true, "blocks_movement": true})
		t.shield(t.caster, t.dmg(1.5), 4.0)
		t.buff("bouclier_sable", 4.0, {"speed": 0.6, "label": "Bouclier de sable", "color": SAND})
		for e: CombatCharacter in t.enemies_in_cone(t.origin, t.dir, 3.0, 90.0):
			if e.abilities.is_casting():
				e.abilities.interrupt()
			t.hit(e, t.dmg(0.1), {"stun": 0.3})


## C — Ranged. Le sable devient une pluie de petits projectiles lancés
## pendant un moment ; ralentit les cibles.
class BruineDeSable extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.recovery_time = 0.25
		a.max_range = 12.0
		a.anim = &"throw"

	func cast(t: Tk) -> void:
		for i in 6:
			t.after(0.25 * i, func(rt: Tk) -> void:
				for j in 2:
					var d: Vector3 = t.dir.rotated(Vector3.UP, deg_to_rad(randf_range(-12.0, 12.0)))
					rt.projectile({"dir": d, "speed": 24.0, "range": 12.0, "radius": 0.45, "size": 0.12, "color": SAND,
						"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
							rt.hit(e, rt.dmg(0.09), {"slow": 1.5})
							return false}))


## B — Technical. Vague de sable destructrice : dégâts et ralentissement sur
## son passage. Recast : dégâts et repousse ceux encore prisonniers du sable.
class DeferlanteSablesMouvants extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.35
		a.recovery_time = 0.3
		a.max_range = 12.0
		a.anim = &"stomp"

	func cast(t: Tk) -> void:
		t.projectile({"speed": 14.0, "range": 12.0, "radius": 1.8, "pierce": true, "size": 1.0, "color": SAND,
			"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
				t.hit(e, t.dmg(0.9), {"slow": 3.0})
				t.mark(e, "sable_mouvant", 1, 3.5, 1, "Sable")
				return true})
		t.recast(3.5, func(rt: Tk) -> void:
			for e: CombatCharacter in rt.enemies_in(rt.origin, 25.0):
				if rt.consume_mark(e, "sable_mouvant") > 0:
					rt.fx("rocks", e.global_position, 1.5, SAND)
					rt.hit(e, rt.dmg(0.5), {"push": 4.0, "push_from": rt.caster.global_position}))


## A — Ranged. Main de sable qui capture et immobilise. Recast sur une cible
## capturée : Enterrement du désert, plus fort à chaque utilisation successive.
class SarcophageDeSable extends Technique:
	var _burials: int = 0

	func _reset() -> void:
		_burials = 0

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.recovery_time = 0.3
		a.max_range = 15.0
		a.anim = &"palm"

	func cast(t: Tk) -> void:
		# Enterrement du désert se réinitialise quand l'utilisateur est mis K.O.
		if not t.caster.health.died.is_connected(_reset):
			t.caster.health.died.connect(_reset)
		t.projectile({"speed": 22.0, "range": 15.0, "radius": 0.9, "size": 0.5, "color": SAND,
			"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
				t.hit(e, t.dmg(0.4), {"root": 2.5})
				t.mark(e, "capture_sable", 1, 2.5, 1, "Capturé")
				t.text(e, "CAPTURÉ")
				return false})
		t.recast(2.5, func(rt: Tk) -> void:
			for e: CombatCharacter in rt.enemies_in(rt.origin, 25.0):
				if rt.consume_mark(e, "capture_sable") > 0:
					var mult: float = 0.7 * (1.0 + 0.15 * float(mini(_burials, 5)))
					_burials += 1
					rt.fx("implosion", e.global_position, 1.6, SAND)
					rt.hit(e, rt.dmg(mult)))


## S — FinishMove. Le sable engloutit la zone et immobilise ; quand il
## disparaît, il explose pour de lourds dégâts.
class GrandMausoleeDeSable extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.5
		a.recovery_time = 0.4
		a.cast_move_multiplier = 0.0
		a.max_range = 10.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var at: Vector3 = t.aim
		t.fx("rocks", at, 4.5, SAND)
		t.area(at, 4.5, t.dmg(0.3), {"root": 2.2})
		t.zone(at, 4.5, 2.0, {"kind": "mausolee", "color": SAND, "targetable": false,
			"on_expire": func(o: KitObject) -> void:
				t.fx("explosion", o.global_position, 4.5, SAND)
				t.area(o.global_position, 4.5, t.dmg(1.5), {"launch": 0.8})})
