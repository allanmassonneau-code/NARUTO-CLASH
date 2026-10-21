extends RefCounted
## Kit clan Salamandre (Shinobi Striker) : huile, poison, acide et invocations.

const KIT_ID := &"clan_salamandre"
const SIGNATURE = null
const TECHNIQUES := {
	&"clan_salamandre_d_huile_du_crapaud": HuileDuCrapaud,
	&"clan_salamandre_c_invocation_salamandre": InvocationSalamandre,
	&"clan_salamandre_b_bain_d_huile_bouillante": BainHuileBouillante,
	&"clan_salamandre_a_dissolution_monstrueuse": DissolutionMonstrueuse,
	&"clan_salamandre_s_invocation_destruction_des_echoppes": DestructionDesEchoppes,
}

const OIL := Color(0.8, 0.65, 0.2)
const POISON := Color(0.55, 0.2, 0.7)
const ACID := Color(0.6, 0.9, 0.2)


## D — Crachat d'huile : ralentit et scelle les ninjutsu de la cible.
class HuileDuCrapaud extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.recovery_time = 0.25
		a.max_range = 8.0
		a.anim = &"breath"

	func cast(t: Tk) -> void:
		t.projectile({"speed": 18.0, "range": 8.0, "radius": 0.7, "size": 0.3, "color": OIL,
			"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
				t.hit(e, t.dmg(0.5), {"slow": 2.5, "seal": 2.0})
				return false,
			"on_end": func(point: Vector3, _p: TkProjectile, _reason: String) -> void:
				t.fx("smoke", point, 1.2, OIL)})


## C — Invoque une salamandre (objet destructible) qui crache du poison sur
## l'ennemi le plus proche ; le contact direct paralyse.
class InvocationSalamandre extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.35
		a.recovery_time = 0.3
		a.max_range = 5.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		t.fx("smoke", t.aim, 2.0)
		t.object(t.aim, {"kind": "salamandre", "radius": 1.0, "lifetime": 8.0, "health": 60.0, "look": KitObject.Look.PILLAR,
			"color": POISON, "tick_interval": 1.0,
			"on_enter": func(f: CombatCharacter, _o: KitObject) -> void:
				if t.is_enemy(f):
					t.hit(f, t.dmg(0.2), {"stun": 0.8}),
			"on_tick": func(o: KitObject) -> void:
				var e: CombatCharacter = t.nearest_enemy(o.global_position, 7.0)
				if e == null or not t.is_enemy(e):
					return
				var d: Vector3 = HitQuery.flat(e.global_position - o.global_position)
				if d.length() < 0.1:
					d = t.dir
				t.fx("smoke", e.global_position, 1.0, POISON)
				for v: CombatCharacter in t.cone(7.0, 40.0, t.dmg(0.3), {"silence": 0.6}, o.global_position, d.normalized()):
					t.debuff(v, "poison_salamandre", 2.0, {"damage_taken": 1.1, "label": "Poison", "color": POISON})})


## B — Feu + huile + vent avec Fukasaku et Shima : vague d'huile enflammée
## en ligne, laissant une traînée qui ralentit et brûle.
class BainHuileBouillante extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.4
		a.recovery_time = 0.35
		a.cast_move_multiplier = 0.2
		a.max_range = 10.0
		a.anim = &"breath"

	func cast(t: Tk) -> void:
		t.fx("wave", t.origin + t.dir * 4.0, 3.0, Color(1.0, 0.5, 0.1))
		t.line(10.0, 2.0, t.dmg(1.0), {"slow": 2.0, "burn": 2.0})
		for i in 3:
			var at: Vector3 = t.origin + t.dir * (2.5 + 3.0 * i)
			t.zone(at, 1.6, 5.0, {"kind": "huile_bouillante", "tick_interval": 0.5, "targetable": false, "color": OIL,
				"on_tick": func(o: KitObject) -> void:
					for e: CombatCharacter in o.enemies_inside():
						t.hit(e, t.dmg(0.08), {"slow": 0.6})})


## A — Crache trois boules d'acide qui restent au sol : dégâts et
## ralentissement au contact.
class DissolutionMonstrueuse extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.25
		a.recovery_time = 0.3
		a.max_range = 9.0
		a.anim = &"breath"

	func cast(t: Tk) -> void:
		for i in 3:
			var target: Vector3 = t.aim + t.dir.rotated(Vector3.UP, PI / 2.0) * (-1.6 + 1.6 * i)
			t.projectile({"lob_to": target, "speed": 14.0, "size": 0.35, "color": ACID,
				"on_end": func(point: Vector3, _p: TkProjectile, _reason: String) -> void:
					t.fx("burst", point, 1.3, ACID)
					t.area(point, 1.4, t.dmg(0.4), {"slow": 1.5})
					t.zone(point, 1.2, 4.0, {"kind": "acide", "tick_interval": 0.5, "targetable": false, "color": ACID,
						"on_tick": func(o: KitObject) -> void:
							for e: CombatCharacter in o.enemies_inside():
								t.hit(e, t.dmg(0.07), {"slow": 0.6})})})


## S — Un énorme crapaud tombe sur la cible : gros impact, l'onde de choc
## projette les ennemis proches dans les airs.
class DestructionDesEchoppes extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.45
		a.recovery_time = 0.4
		a.max_range = 16.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var at: Vector3 = t.aim
		t.telegraph(at, 4.0, 0.7, func(rt: Tk) -> void:
			rt.fx("smoke", at, 4.0)
			rt.fx("cracks", at, 4.5)
			rt.area(at, 2.5, rt.dmg(1.2))
			for e: CombatCharacter in rt.area(at, 5.0, rt.dmg(0.6), {"push": 2.0, "push_from": at}):
				rt.launch(e, 1.0))
