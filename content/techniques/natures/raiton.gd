extends RefCounted
## Technique kit: Raiton — vrais jutsu de Naruto Shinobi Striker.

const KIT_ID := &"raiton"
const SIGNATURE = null
const TECHNIQUES := {
	&"raiton_d_filet_de_shurikens_foudroyants": FiletFoudroyant,
	&"raiton_d_petrification": Petrification,
	&"raiton_c_mille_oiseaux": MilleOiseaux,
	&"raiton_c_lariat": Lariat,
	&"raiton_b_eclair_pourfendeur": EclairPourfendeur,
	&"raiton_b_eclairs_foudroyants": EclairsFoudroyants,
	&"raiton_a_niveaux_de_mille_oiseaux": NiveauxMilleOiseaux,
	&"raiton_a_charge_fulgurante_puissance_de_la_main_d": ChargeFulgurante,
	&"raiton_s_kirin": Kirin,
	&"raiton_s_mode_chakra": ModeChakra,
}

const BOLT := Color(0.55, 0.75, 1.0)


class K:
	static func weaken(t: Tk, e: CombatCharacter, s: float) -> void:
		if is_instance_valid(e) and t.is_enemy(e):
			t.debuff(e, "raiton_affaibli", s, {"damage_dealt": 0.8, "label": "Attaque -", "color": BOLT})

	## Chidori-style lunge: dash forward and pierce what is in front.
	static func pierce(t: Tk, dist: float, mult: float, opts: Dictionary) -> Array[CombatCharacter]:
		t.fx("sparks", t.origin, 1.0, BOLT)
		var hits: Array[CombatCharacter] = t.line(dist + 1.2, 1.4, t.dmg(mult), opts)
		t.dash(dist, t.dir, 0.18)
		for e: CombatCharacter in hits:
			t.fx("bolt", e.global_position, 1.0, BOLT)
		return hits


## D — Filet de shurikens foudroyants : un filet d'éclairs s'étend vers la
## cible ; à l'impact il la blesse, la paralyse et réduit son attaque.
class FiletFoudroyant extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.recovery_time = 0.25
		a.max_range = 14.0
		a.anim = &"throw"

	func cast(t: Tk) -> void:
		t.projectile({"speed": 22.0, "range": 14.0, "radius": 1.2, "size": 0.4, "color": BOLT,
			"on_hit": func(e: CombatCharacter, p: TkProjectile) -> bool:
				t.fx("sparks", e.global_position, 1.5, BOLT)
				for v: CombatCharacter in t.area(p.ground_point(), 1.5, t.dmg(0.4), {"stun": 0.9}):
					K.weaken(t, v, 4.0)
				return false})


## D — Pétrification (paralysie temporaire) : immobilise la cible visée ; sur
## un coup « critique » (cible déjà ralentie ou au centre), paralysie totale.
class Petrification extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.25
		a.recovery_time = 0.2
		a.max_range = 12.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var e: CombatCharacter = t.target_at_aim(3.0)
		if e == null:
			e = t.nearest_enemy(t.origin, 12.0)
		if e == null:
			t.fx("ring", t.aim, 1.5, BOLT)
			return
		var critical: bool = t.distance(e.global_position, t.aim) < 1.0
		t.fx("bolt", e.global_position, 1.0, BOLT)
		t.hit(e, t.dmg(0.05), {"stun": 1.5} if critical else {"root": 2.0})
		t.text(e, "PARALYSÉ" if critical else "IMMOBILISÉ")


## C — Mille oiseaux (Chidori) : chakra concentré dans la main, puis charge
## fulgurante qui transperce la cible.
class MilleOiseaux extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.recovery_time = 0.25
		a.max_range = 7.0
		a.anim = &"chidori"

	func cast(t: Tk) -> void:
		K.pierce(t, 6.0, 0.9, {"stun": 0.3, "push": 1.5})


## C — Lariat : bras chargés de Raiton, ruée à très grande vitesse qui
## continue un instant et repousse fortement les cibles.
class Lariat extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.recovery_time = 0.3
		a.max_range = 8.0
		a.anim = &"dash"

	func cast(t: Tk) -> void:
		var hits: Array[CombatCharacter] = t.line(8.0, 1.8, t.dmg(0.8), {"push": 5.0})
		t.dash(8.0, t.dir, 0.25)
		for e: CombatCharacter in hits:
			t.fx("sparks", e.global_position, 1.0, BOLT)


## B — Éclair pourfendeur (Raikiri) : version plus puissante du Chidori,
## charge longue qui perfore la cible.
class EclairPourfendeur extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.recovery_time = 0.25
		a.max_range = 8.0
		a.anim = &"chidori"

	func cast(t: Tk) -> void:
		K.pierce(t, 7.0, 1.0, {"stun": 0.5})


## B — Éclairs foudroyants : une vague d'eau étourdit les ennemis devant et
## les rend vulnérables ; recasts (×2) : la foudre parcourt l'eau et frappe.
class EclairsFoudroyants extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.25
		a.recovery_time = 0.2
		a.max_range = 5.0
		a.anim = &"palm"

	func cast(t: Tk) -> void:
		var at: Vector3 = t.origin + t.dir * 2.5
		t.fx("wave", at, 3.0, Color(0.3, 0.6, 1.0))
		for e: CombatCharacter in t.cone(5.0, 80.0, t.dmg(0.2), {"stun": 0.8}):
			t.debuff(e, "trempe", 4.0, {"damage_taken": 1.2, "label": "Trempé", "color": BOLT})
		t.zone(at, 3.0, 4.0, {"kind": "eau_vague", "look": KitObject.Look.DISC, "targetable": false,
			"color": Color(0.3, 0.6, 1.0)})
		_arm(t, at, 2)

	func _arm(t: Tk, at: Vector3, left: int) -> void:
		t.recast(4.0, func(rt: Tk) -> void:
			rt.fx("bolt", at, 3.0, BOLT)
			rt.area(at, 3.2, rt.dmg(0.4), {"stun": 0.2})
			if left > 1:
				_arm(rt, at, left - 1))


## A — Niveaux de Mille oiseaux (Marque maudite) : fond sur la cible et la
## transperce plusieurs fois ; si ça touche, le délai de récupération baisse.
class NiveauxMilleOiseaux extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.recovery_time = 0.3
		a.max_range = 7.0
		a.anim = &"chidori"

	func cast(t: Tk) -> void:
		var hits: Array[CombatCharacter] = K.pierce(t, 6.0, 0.5, {"stun": 0.4})
		if hits.is_empty():
			return
		var target: CombatCharacter = hits[0]
		for i in 2:
			t.after(0.2 * (i + 1), func(rt: Tk) -> void:
				if is_instance_valid(target) and rt.is_enemy(target):
					rt.fx("bolt", target.global_position, 1.0, BOLT)
					rt.hit(target, rt.dmg(0.4 if i == 0 else 0.6), {"stun": 0.3} if i == 0 else {"push": 3.0}))
		t.buff("niveaux_recup", 3.0, {"chakra_regen": 1.5, "label": "Récupération", "color": BOLT})


## A — Charge fulgurante : Puissance de la main divine : un kunai est lancé,
## puis le lanceur échange sa place avec lui et charge en Mille oiseaux.
class ChargeFulgurante extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.recovery_time = 0.2
		a.max_range = 10.0
		a.anim = &"throw"

	func cast(t: Tk) -> void:
		var kunai: KitObject = t.object(t.aim, {"kind": "kunai_divin", "radius": 0.4, "lifetime": 0.8,
			"health": -1.0, "look": KitObject.Look.GLYPH, "targetable": false, "color": BOLT,
			"on_expire": func(o: KitObject) -> void:
				var rt: Tk = t.refreshed()
				if not rt.alive():
					return
				rt.fx("sparks", rt.origin, 1.0, BOLT)
				rt.blink(o.global_position)
				var lunge: Tk = rt.refreshed()
				var e: CombatCharacter = lunge.nearest_enemy(lunge.origin, 8.0)
				if e != null:
					lunge.dir = HitQuery.flat(e.global_position - lunge.origin).normalized()
				K.pierce(lunge, 5.0, 0.9, {"stun": 0.4})})
		t.fx("ring", kunai.global_position, 0.6, BOLT)


## S — Kirin (ultime) : après un court délai, un éclair géant s'abat sur la
## zone visée et foudroie tous les ennemis dedans.
class Kirin extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.5
		a.recovery_time = 0.4
		a.max_range = 15.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var at: Vector3 = t.aim
		t.telegraph(at, 4.0, 1.0, func(rt: Tk) -> void:
			rt.fx("bolt", at, 4.0, BOLT)
			rt.fx("explosion", at, 4.0, BOLT)
			rt.fx("cracks", at, 4.0)
			rt.area(at, 4.0, rt.dmg(2.0), {"stun": 1.0, "unblockable": true}))


## S — Mode Chakra Raiton (ultime) : le corps se couvre de foudre ; vitesse
## d'attaque, de déplacement et défense augmentées, insensible au recul.
class ModeChakra extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.recovery_time = 0.2
		a.max_range = 2.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		t.fx("sparks", t.origin, 2.0, BOLT)
		t.fx("ring", t.origin, 2.5, BOLT)
		t.buff("mode_chakra_raiton", 12.0, {"speed": 1.35, "basic_damage": 1.4, "damage_taken": 0.7,
			"tenacity": true, "label": "Mode Chakra", "color": BOLT})
