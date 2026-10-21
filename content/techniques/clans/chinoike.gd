extends RefCounted
## Kit clan_chinoike : clan du sang (jutsu Shinobi Striker).

const KIT_ID := &"clan_chinoike"
const SIGNATURE = null
const TECHNIQUES := {
	&"clan_chinoike_d_genjutsu_sharingan": GenjutsuSharingan,
	&"clan_chinoike_c_mort_par_demembrement": MortParDemembrement,
	&"clan_chinoike_b_faucheur_d_ames": FaucheurDAmes,
	&"clan_chinoike_a_katon_futon_folie_inhabituelle": FolieInhabituelle,
	&"clan_chinoike_s_arcanes_maudites_sang_de_possession_mort": SangDePossession,
}

const BLOOD := Color(0.75, 0.05, 0.08)


## D â€” Genjutsu : Sharingan (Technical) : illusion paralysante devant soi, et
## mode Sharingan (alliÃ©s proches) qui bloque les coups et renvoie des spectres.
class GenjutsuSharingan extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.recovery_time = 0.2
		a.max_range = 7.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		t.fx("crows", t.origin + t.dir * 3.0, 2.0, BLOOD)
		t.cone(7.0, 40.0, t.dmg(0.6), {"genjutsu": 1.5, "stun": 1.0})
		for f: CombatCharacter in t.allies_in(t.origin, 5.0, true):
			if f == t.caster:
				continue
			t.status(f, StatusController.Type.COUNTER, 2.0)
		var tk: Tk = t
		t.buff("sharingan", 4.0, {"uses": 1, "label": "Sharingan", "color": BLOOD,
			"on_take": func(_hit, _dmg: float) -> float:
				var src: CombatCharacter = tk.nearest_enemy(tk.caster.global_position, 8.0) if tk.alive() else null
				if src != null:
					tk.fx("crows", src.global_position, 1.2, BLOOD)
					tk.area(src.global_position, 2.0, tk.dmg(0.3), {"root": 1.2})
				return 0.0})


## C â€” Mort par dÃ©membrement (Technical) : rotation tranchante canalisÃ©e ;
## soigne de la quantitÃ© de dÃ©gÃ¢ts infligÃ©s.
class MortParDemembrement extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.15
		a.recovery_time = 0.25
		a.max_range = 2.8
		a.anim = &"slash"

	func cast(t: Tk) -> void:
		t.channel(5, 0.25, func(ct: Tk, _i: int) -> void:
			var c: Vector3 = ct.caster.global_position
			ct.fx("wave", c, 2.8, BLOOD)
			var n: int = ct.area(c, 2.8, ct.dmg(0.2)).size()
			if n > 0:
				ct.heal(ct.caster, ct.dmg(0.2) * n), Callable(), 0.8)


## B â€” Faucheur d'Ã¢mes (Technical) : Ã©lan puis combo ; chaque coup portÃ©
## renforce les capacitÃ©s physiques (buff cumulatif jusqu'au KO).
class FaucheurDAmes extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.15
		a.recovery_time = 0.3
		a.max_range = 6.0
		a.anim = &"slash"

	func cast(t: Tk) -> void:
		t.dash(4.5, t.dir, 0.18)
		for i in 3:
			t.after(0.2 + 0.2 * i, func(rt: Tk) -> void:
				var hits: int = rt.melee(2.5, 110.0, rt.dmg(0.27), {"stun": 0.15}).size()
				if hits > 0:
					var stacks: int = rt.mark(rt.caster, "faucheur", hits, 60.0, 10, "Faucheur")
					rt.buff("faucheur", 60.0, {"damage_dealt": 1.0 + 0.04 * stacks, "speed": 1.0 + 0.02 * stacks,
						"label": "Faucheur x%d" % stacks, "color": BLOOD}))


## A â€” Katon-FÃ»ton : Folie inhabituelle (Ranged) : crÃ©ature Katon (attaque
## seule les ennemis proches) ; recast = crÃ©ature FÃ»ton ; proches = fusion gÃ©ante.
class FolieInhabituelle extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.recovery_time = 0.3
		a.max_range = 12.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		_creature(t, t.aim, "katon", Color(1.0, 0.4, 0.1))
		t.recast(6.0, func(rt: Tk) -> void:
			_creature(rt, rt.aim, "futon", Color(0.7, 1.0, 0.8))
			for k: KitObject in rt.objects("katon"):
				for f: KitObject in rt.objects("futon"):
					if k.is_alive() and f.is_alive() and rt.distance(k.global_position, f.global_position) < 5.0:
						var c: Vector3 = (k.global_position + f.global_position) * 0.5
						k.destroy("fused")
						f.destroy("fused")
						_creature(rt, c, "fusion", Color(1.0, 0.2, 0.05))
						return)

	func _creature(t: Tk, at: Vector3, kind: String, col: Color) -> void:
		var big: bool = kind == "fusion"
		var reach: float = 6.0 if big else 4.5
		var o: KitObject = t.object(at, {"kind": kind, "radius": 0.8, "lifetime": 8.0, "health": 60.0,
			"look": KitObject.Look.PILLAR, "color": col, "tick_interval": 0.6,
			"on_tick": func(obj: KitObject) -> void:
				var e: CombatCharacter = t.nearest_enemy(obj.global_position, reach)
				if e == null:
					return
				var dmg: float = t.dmg(0.35 if big else 0.2)
				t.fx("explosion" if big else "ember", e.global_position, 2.5 if big else 1.0, col)
				if big:
					t.area(e.global_position, 2.5, dmg, {"burn": 2.0})
				else:
					t.hit(e, dmg, {"burn": 1.5} if kind == "katon" else {"push": 1.0})
				obj.data["dealt"] = float(obj.data.get("dealt", 0.0)) + dmg
				if float(obj.data["dealt"]) > t.dmg(3.0 if big else 1.5):
					obj.destroy("spent")})
		o.data["dealt"] = 0.0


## S â€” Arcanes Maudites : Sang de possession mortelle (FinishMove) : vole le
## sang d'un ennemi ; pendant le rituel le lanceur ne peut tomber et chaque
## dÃ©gÃ¢t reÃ§u est rÃ©percutÃ© sur la victime ; recast = s'empaler (gros dÃ©gÃ¢ts liÃ©s).
class SangDePossession extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.recovery_time = 0.3
		a.max_range = 12.0
		a.anim = &"thrust"

	func cast(t: Tk) -> void:
		var victim: CombatCharacter = t.target_at_aim(3.0)
		if victim == null:
			victim = t.nearest_enemy(t.origin, 12.0)
		if victim == null:
			t.fx("cracks", t.aim, 2.0, BLOOD)
			t.area(t.aim, 2.0, t.dmg(0.5))
			return
		t.fx("bolt", victim.global_position, 1.2, BLOOD)
		t.hit(victim, t.dmg(0.4), {"root": 1.0})
		t.mark(victim, "sang_vole", 1, 8.0, 1, "Sang volÃ©")
		t.zone(t.caster.global_position, 2.5, 8.0, {"kind": "rituel", "look": KitObject.Look.GLYPH,
			"targetable": false, "color": BLOOD})
		var tk: Tk = t
		t.buff("possession", 8.0, {"tenacity": true, "label": "Possession", "color": BLOOD,
			"on_take": func(_hit, dmg: float) -> float:
				if is_instance_valid(victim) and tk.is_enemy(victim):
					tk.hit(victim, dmg, {"unblockable": true})
				if tk.alive() and tk.caster.health.current_health - dmg < 1.0:
					return maxf(0.0, tk.caster.health.current_health - 1.0)
				return dmg})
		t.recast(8.0, func(rt: Tk) -> void:
			if not is_instance_valid(victim) or not rt.is_enemy(victim):
				return
			rt.fx("column", rt.caster.global_position, 1.2, BLOOD)
			rt.fx("column", victim.global_position, 1.5, BLOOD)
			rt.hit(victim, rt.dmg(1.6), {"unblockable": true, "stun": 0.8})
			rt.consume_mark(victim, "sang_vole")
			rt.kit().remove_modifier("possession"))
