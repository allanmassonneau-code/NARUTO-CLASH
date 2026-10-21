extends RefCounted
## Kit clan Kaguya (Shinobi Striker) : danses des os (Shikotsumyaku).

const KIT_ID := &"clan_kaguya"
const SIGNATURE = null
const TECHNIQUES := {
	&"clan_kaguya_d_danse_de_la_clematite": DanseClematite,
	&"clan_kaguya_c_danse_du_meleze": DanseMeleze,
	&"clan_kaguya_b_lame_des_conjures_os_et_cendre": OsEtCendre,
	&"clan_kaguya_a_crocs_de_terre_du_seigneur_legendaire": CrocsDeTerre,
	&"clan_kaguya_s_danse_des_jeunes_fougeres_arborescentes": JeunesFougeres,
}

const BONE := Color(0.95, 0.92, 0.82)
const ASH := Color(0.4, 0.38, 0.36)


## D — Fouet vertébral en arc large, puis charge avec la lance osseuse.
class DanseClematite extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.recovery_time = 0.25
		a.max_range = 5.0
		a.anim = &"slash"

	func cast(t: Tk) -> void:
		t.fx("wave", t.origin + t.dir * 1.5, 2.5, BONE)
		t.melee(4.0, 160.0, t.dmg(0.45))
		t.after(0.25, func(rt: Tk) -> void:
			rt.dash(4.0, rt.dir, 0.2)
			rt.fx("spikes", rt.caster.global_position + rt.dir, 1.2, BONE)
			rt.melee(2.2, 60.0, rt.dmg(0.4), {"push": 2.0}))


## C — Os jaillissant du corps : garde (bloque la plupart des coups), coupe
## tout autour, riposte au recast par un bond.
class DanseMeleze extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.15
		a.recovery_time = 0.2
		a.max_range = 5.0
		a.anim = &"guard"

	func cast(t: Tk) -> void:
		t.buff("meleze", 1.5, {"damage_taken": 0.2, "label": "Danse du Mélèze", "color": BONE})
		t.fx("spikes", t.origin, 2.5, BONE)
		t.area(t.origin, 2.5, t.dmg(0.4))
		t.recast(2.0, func(rt: Tk) -> void:
			var e: CombatCharacter = rt.nearest_enemy(rt.origin, 6.0)
			if e != null and rt.is_enemy(e):
				rt.dash(maxf(rt.distance(rt.origin, e.global_position) - 1.0, 0.0),
					HitQuery.flat(e.global_position - rt.origin).normalized(), 0.15)
			rt.fx("spikes", rt.caster.global_position, 2.0, BONE)
			rt.area(rt.caster.global_position, 2.2, rt.dmg(0.45), {"stun": 0.4}))


## B — Os de cendre lancé depuis la paume : dégâts continus ; en cas
## d'échec, il revient une fois vers la cible depuis une autre dimension.
class OsEtCendre extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.25
		a.recovery_time = 0.3
		a.max_range = 16.0
		a.anim = &"palm"

	func cast(t: Tk) -> void:
		var target: CombatCharacter = t.target_at_aim(3.0)
		_bone(t, t.origin, t.dir, target, true)

	func _bone(t: Tk, from: Vector3, d: Vector3, target: CombatCharacter, can_return: bool) -> void:
		t.projectile({"from": from, "dir": d, "speed": 24.0, "range": 16.0, "radius": 0.5, "size": 0.25, "color": ASH,
			"homing": 1.0, "homing_target": target,
			"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
				t.hit(e, t.dmg(0.5))
				t.fx("smoke", e.global_position, 1.0, ASH)
				t.channel(4, 0.5, func(ct: Tk, _i: int) -> void:
					if is_instance_valid(e) and ct.is_enemy(e):
						ct.hit(e, ct.dmg(0.12)), Callable(), 1.0)
				return false,
			"on_end": func(_point: Vector3, _p: TkProjectile, reason: String) -> void:
				if reason == "hit" or not can_return:
					return
				t.after(0.5, func(rt: Tk) -> void:
					var tgt: CombatCharacter = target
					if tgt == null or not is_instance_valid(tgt) or not rt.is_enemy(tgt):
						tgt = rt.nearest_enemy(rt.caster.global_position, 18.0)
					if tgt == null or not is_instance_valid(tgt):
						return
					var behind: Vector3 = tgt.global_position + HitQuery.flat(tgt.global_position - rt.caster.global_position).normalized() * 6.0
					rt.fx("implosion", behind, 1.0, ASH)
					_bone(rt, behind, HitQuery.flat(tgt.global_position - behind).normalized(), tgt, false))})


## A — Créature-chien d'os qui fonce en ligne droite puis devient un
## terrain : accélère les alliés, explose au contact des ennemis.
class CrocsDeTerre extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.recovery_time = 0.3
		a.max_range = 14.0
		a.anim = &"stomp"

	func cast(t: Tk) -> void:
		t.projectile({"speed": 16.0, "range": 14.0, "radius": 1.0, "pierce": true, "size": 0.5, "color": BONE,
			"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
				t.hit(e, t.dmg(0.4))
				return true,
			"on_end": func(point: Vector3, _p: TkProjectile, _reason: String) -> void:
				_terrain(t.refreshed(), point)})

	func _terrain(t: Tk, at: Vector3) -> void:
		t.fx("rocks", at, 2.0, BONE)
		t.zone(at, 2.5, 8.0, {"kind": "crocs_terrain", "targetable": false, "color": BONE,
			"on_enter": func(f: CombatCharacter, o: KitObject) -> void:
				if t.is_ally(f):
					t.debuff(f, "crocs_vitesse", 3.0, {"speed": 1.25, "label": "Crocs", "color": BONE})
				elif t.is_enemy(f) and not o.data.get("boom", false):
					o.data["boom"] = true
					t.fx("explosion", o.global_position, 2.5, BONE)
					t.area(o.global_position, 2.8, t.dmg(0.6), {"push": 2.0})
					o.destroy("detonated")})


## S — Forêt d'os géants jaillissant du sol : projette les ennemis dans les
## airs, puis le lanceur enchaîne d'un coup de lance osseuse.
class JeunesFougeres extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.4
		a.recovery_time = 0.4
		a.max_range = 7.0
		a.anim = &"stomp"

	func cast(t: Tk) -> void:
		for i in 6:
			var off: Vector3 = Vector3(cos(TAU * i / 6.0), 0.0, sin(TAU * i / 6.0)) * 3.5
			t.fx("spikes", t.origin + off, 1.8, BONE)
		t.fx("column", t.origin, 2.0, BONE)
		var hit: Array[CombatCharacter] = t.area(t.origin, 6.0, t.dmg(1.0), {"launch": 1.0})
		t.after(0.6, func(rt: Tk) -> void:
			var e: CombatCharacter = rt.nearest_enemy(rt.origin, 7.0)
			if e != null and is_instance_valid(e) and rt.is_enemy(e):
				rt.dash(maxf(rt.distance(rt.origin, e.global_position) - 1.0, 0.0),
					HitQuery.flat(e.global_position - rt.origin).normalized(), 0.15)
				rt.fx("spikes", e.global_position, 1.5, BONE)
				rt.hit(e, rt.dmg(0.8), {"push": 3.0})
			elif hit.is_empty():
				rt.line(5.0, 1.2, rt.dmg(0.8)))
