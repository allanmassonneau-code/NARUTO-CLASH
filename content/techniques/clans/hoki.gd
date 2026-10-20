extends RefCounted
## Technique kit: clan Hôki (design bible). Signature: Réactifs — one
## Préparation (Stimulant / Coagulant / Neurotoxique) lives in the Hôki's
## body at a time (caster modifier "hoki_prep", 12 s, labelled on the HUD)
## and changes what the other techniques do. Enemy toxins build a
## Saturation mark with a strict cap (5). Aiguille adaptative analyses the
## target's resistance: the matching Réactif is weakened (x0.6), any other
## one is reinforced (x1.2) while the analysis lasts.

const KIT_ID := &"clan_hoki"
const SIGNATURE = null
const TECHNIQUES := {
	&"clan_hoki_d_injection_experimentale": InjectionExperimentale,
	&"clan_hoki_c_aiguille_adaptative": AiguilleAdaptative,
	&"clan_hoki_b_greffe_reactive": GreffeReactive,
	&"clan_hoki_a_dissection_de_combat": DissectionDeCombat,
	&"clan_hoki_s_chimere_de_laboratoire": ChimereDeLaboratoire,
}

const PREP := "hoki_prep"
const PREP_TIME: float = 12.0
const STIM := "stimulant"
const COAG := "coagulant"
const NEURO := "neurotoxique"
const SAT := "saturation"
const SAT_CAP: int = 5
const SAT_TIME: float = 6.0
const ANALYSE := "hoki_analyse"
const TOXIC := Color(0.55, 0.9, 0.35)


## Shared Hôki rules.
class K:
	static func order() -> Array[String]:
		var out: Array[String] = []
		out.append(STIM)
		out.append(COAG)
		out.append(NEURO)
		return out

	static func label(p: String) -> String:
		match p:
			STIM:
				return "Stimulant"
			COAG:
				return "Coagulant"
			NEURO:
				return "Neurotoxique"
		return "Aucune"

	static func tint(p: String) -> Color:
		match p:
			STIM:
				return Color(1.0, 0.6, 0.2)
			COAG:
				return Color(0.8, 0.2, 0.25)
			NEURO:
				return Color(0.6, 0.35, 0.95)
		return TOXIC

	## Current Préparation of the caster ("" if none).
	static func prep(t: Tk) -> String:
		var m: Dictionary = t.kit().modifiers.get(PREP, {})
		return String(m.props.get("prep", "")) if not m.is_empty() else ""

	## Sets the single active Préparation (replaces the previous one).
	static func set_prep(t: Tk, p: String) -> void:
		t.buff(PREP, PREP_TIME, {"prep": p, "label": "Prép. " + label(p), "color": tint(p)})
		t.text(t.caster, label(p).to_upper(), tint(p))

	## Saturation with a strict cap; returns the new stacks.
	static func saturate(t: Tk, e: CombatCharacter, n: int) -> int:
		if not t.is_enemy(e):
			return 0
		return t.mark(e, SAT, n, SAT_TIME, SAT_CAP, "Saturation")

	## Hidden "best resistance" of a fighter: what it visibly resists, else an
	## innate category (stable per fighter).
	static func resist_of(e: CombatCharacter) -> String:
		if e.kit.has_flag("tenacity") or e.kit.has_flag("cc_immune"):
			return STIM
		if e.health.shield > 0.0 or e.status.has_status(StatusController.Type.REGEN):
			return COAG
		if e.kit.mark(SAT) >= 3:
			return NEURO
		return order()[e.get_instance_id() % 3]

	## Efficacy of the current Préparation against an analysed target.
	static func efficacy(t: Tk, e: CombatCharacter) -> float:
		if e == null or not e.kit.modifiers.has(ANALYSE):
			return 1.0
		var resist: String = String(e.kit.modifiers[ANALYSE].props.get("resist", ""))
		return 0.6 if resist == prep(t) else 1.2

	## Analysis: reveals the target's best resistance for a few seconds.
	static func analyse(t: Tk, e: CombatCharacter, seconds: float = 5.0) -> void:
		if not t.is_enemy(e):
			return
		var r: String = resist_of(e)
		t.debuff(e, ANALYSE, seconds, {"resist": r, "label": "Résiste: " + label(r), "color": tint(r)})

	static func chakra_drain(e: CombatCharacter, amount: float) -> void:
		if e != null and is_instance_valid(e) and not e.is_dead():
			e.energy.sync_state(maxf(0.0, e.energy.current_energy - amount))

	## Hit category for Chimère: "control", "projectile" or "melee".
	static func category(victim: CombatCharacter, hit: HitData) -> String:
		if hit.stun_duration > 0.0 or hit.root_duration > 0.0:
			return "control"
		var a: AbilityData = hit.ability
		if a != null and a.kind == AbilityData.Kind.PROJECTILE:
			return "projectile"
		if a != null and a.kind == AbilityData.Kind.MELEE_ARC:
			return "melee"
		if is_instance_valid(hit.source) and HitQuery.flat(hit.source.global_position - victim.global_position).length() > 4.0:
			return "projectile"
		return "melee"


## D — Self-buff, Choix modal, Ressource. Injects the next Réactif of the
## cycle (Stimulant -> Coagulant -> Neurotoxique) as the Préparation, with
## its short bonus: Stimulant = acceleration 3 s; Coagulant = next DOT /
## bleed tick halved (or a burn purged); Neurotoxique = next Hôki projectile
## more disruptive. Recast within 2 s switches to the next Réactif (the old
## bonus is replaced, never stacked). Interruptible startup.
class InjectionExperimentale extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.recovery_time = 0.15
		a.cast_move_multiplier = 0.6
		a.max_range = 1.0
		a.anim = &"heal"

	func cast(t: Tk) -> void:
		_inject(t)

	func _inject(t: Tk) -> void:
		var cycle: Array[String] = K.order()
		var cur: String = K.prep(t)
		var p: String = cycle[(cycle.find(cur) + 1) % 3] if cur != "" else STIM
		K.set_prep(t, p)
		var kit: KitState = t.kit()
		var caster: CombatCharacter = t.caster
		t.fx("sparks", t.origin, 0.8, K.tint(p))
		match p:
			STIM:
				t.buff("inj_bonus", 3.0, {"speed": 1.3, "label": "Stimulant", "color": K.tint(p)})
			COAG:
				t.buff("inj_bonus", 8.0, {"label": "Coagulant", "color": K.tint(p),
					"on_take": func(hit: HitData, dmg: float) -> Variant:
						if hit.ability == null or dmg <= 6.0:  # DOT / bleed tick
							kit.remove_modifier("inj_bonus")
							return dmg * 0.5
						return null,
					"on_tick": func(_dt: float) -> void:
						if is_instance_valid(caster) and caster.status.has_status(StatusController.Type.BURN):
							caster.status.remove_status(StatusController.Type.BURN)
							kit.remove_modifier("inj_bonus")})
			NEURO:
				t.buff("inj_bonus", 8.0, {"neuro_charge": true, "label": "Neurotoxique", "color": K.tint(p)})
		t.recast(2.0, func(rt: Tk) -> void:
			_inject(rt))


## C — Projectile, Debuff variable, Analyse. Thin fast needle; effect by
## Préparation: Stimulant = involuntary forward lurch; Coagulant = chakra
## regeneration halved; Neurotoxique = +2 Saturation and "Brouillé" (cast
## readability approximated as a labelled -8 % damage debuff). A Neurotoxique
## injection charge doubles the disruption. The hit reveals the target's best
## resistance (analysis, 5 s). Chimère projectile adaptation: 3 needles.
class AiguilleAdaptative extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.15
		a.recovery_time = 0.2
		a.max_range = 14.0
		a.anim = &"throw"

	func cast(t: Tk) -> void:
		var spread: Array[float] = []
		spread.append(0.0)
		if t.kit().has_modifier("chim_projectile"):
			spread.append(-10.0)
			spread.append(10.0)
		var charged: bool = bool(t.kit().modifiers.get("inj_bonus", {"props": {}}).props.get("neuro_charge", false))
		if charged:
			t.kit().remove_modifier("inj_bonus")
		for angle: float in spread:
			t.projectile({"speed": 32.0, "range": 14.0, "radius": 0.35, "size": 0.09, "color": K.tint(K.prep(t)),
				"dir": t.dir.rotated(Vector3.UP, deg_to_rad(angle)),
				"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
					_needle(t, e, charged)
					return false})

	func _needle(t: Tk, e: CombatCharacter, charged: bool) -> void:
		var eff: float = K.efficacy(t, e)
		if t.hit(e, t.dmg(0.5 * eff)) != HitData.Result.HIT:
			return
		var boost: float = eff * (1.6 if charged else 1.0)
		match K.prep(t):
			STIM:
				t.push(e, e.facing.facing_direction, 2.2 * boost, 0.25)
			COAG:
				t.debuff(e, "hoki_coag", 4.0 * boost, {"chakra_regen": 0.5, "label": "Coagulé", "color": K.tint(COAG)})
			NEURO:
				K.saturate(t, e, 2 + (1 if charged else 0))
				t.debuff(e, "hoki_brouille", 3.0 * boost, {"damage_dealt": 0.92, "label": "Brouillé", "color": K.tint(NEURO)})
			_:
				K.saturate(t, e, 1)
		if charged:
			t.status(e, StatusController.Type.SLOW, 1.0)
		K.analyse(t, e)


## B — Mutation temporaire, Réponse aux dégâts, Modal. One-charge graft for
## 6 s, chosen by the Préparation (Coagulant if none): Stimulant = reinforced
## tendons (first knockback taken x0.25, no launch); Coagulant = shell that
## fully absorbs one impact; Neurotoxique = when struck in melee, a short
## toxic mist bursts out (slow + Saturation). Wrong guess = little value.
class GreffeReactive extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.recovery_time = 0.2
		a.max_range = 1.0
		a.anim = &"guard"

	func cast(t: Tk) -> void:
		var p: String = K.prep(t)
		if p == "":
			p = COAG
		var kit: KitState = t.kit()
		var caster: CombatCharacter = t.caster
		t.fx("spikes", t.origin, 1.0, K.tint(p))
		match p:
			STIM:
				t.buff("greffe", 6.0, {"tenacity": true, "label": "Greffe: tendons", "color": K.tint(p),
					"on_take": func(_hit: HitData, _dmg: float) -> Variant:
						kit.after(0.1, func() -> void: kit.remove_modifier("greffe"))  # this hit's knockback is still reduced
						return null})
			COAG:
				t.buff("greffe", 6.0, {"label": "Greffe: carapace", "color": K.tint(p),
					"on_take": func(_hit: HitData, _dmg: float) -> Variant:
						kit.remove_modifier("greffe")
						if is_instance_valid(caster):
							KitVisuals.fx(caster, "sparks", caster.global_position, 1.0, K.tint(COAG))
						return 0.0})
			NEURO:
				t.buff("greffe", 6.0, {"label": "Greffe: brume", "color": K.tint(p),
					"on_take": func(hit: HitData, _dmg: float) -> Variant:
						if K.category(caster, hit) == "melee" or (hit.ability != null and hit.ability.kind == AbilityData.Kind.MELEE_ARC):
							kit.remove_modifier("greffe")
							kit.after(0.0, func() -> void:
								if t.alive():
									_mist(t.refreshed()))
						return null})

	func _mist(t: Tk) -> void:
		t.fx("smoke", t.origin, 2.5, K.tint(NEURO))
		t.zone(t.origin, 2.5, 2.5, {"kind": "brume", "targetable": false, "tick_interval": 0.5, "color": K.tint(NEURO),
			"on_tick": func(o: KitObject) -> void:
				for e: CombatCharacter in o.enemies_inside():
					t.status(e, StatusController.Type.SLOW, 0.6)
					K.saturate(t, e, 1)})


## A — Mark, Analyse avancée, Exécution conditionnelle. Short channel on a
## visible target (broken by line of sight / range). Then a 8 s Profil
## biologique records its recent behaviour (mobility, guard, jutsu spam);
## every Hôki hit on it adds Saturation and gains an effect matching the
## dominant behaviour (slow / +20 % damage / chakra drain). Reaching the
## Saturation cap triggers a Crise (no stun): lost acceleration, fragile
## guard, or chakra tax on every cast.
class DissectionDeCombat extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.15
		a.recovery_time = 0.2
		a.max_range = 11.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var target: CombatCharacter = t.target_at_aim(3.5)
		if target == null:
			target = t.nearest_enemy(t.origin, 11.0)
		if target == null:
			t.text(t.caster, "AUCUNE CIBLE")
			return
		var state := {"broken": false}
		t.debuff(target, "hoki_scan", 1.0, {"label": "Analyse...", "color": TOXIC})
		t.channel(3, 0.25, func(ct: Tk, _i: int) -> void:
			if not _visible(ct, target):
				state.broken = true
			else:
				ct.fx("sparks", target.global_position, 0.6, TOXIC),
			func(dt: Tk, completed: bool) -> void:
				if completed and not state.broken and _visible(dt, target):
					_profile(dt, target)
				elif is_instance_valid(dt.caster):
					dt.text(dt.caster, "ANALYSE ROMPUE"), 0.5)

	func _visible(t: Tk, target: Variant) -> bool:
		if not is_instance_valid(target):
			return false
		var e := target as CombatCharacter
		if not t.is_enemy(e) or t.distance(e.global_position, t.caster.global_position) > 13.0:
			return false
		var up: Vector3 = Vector3.UP * HitQuery.BODY_HEIGHT
		return HitQuery.raycast_world(t.caster.get_world_3d(), t.caster.global_position + up, e.global_position + up).is_empty()

	func _profile(t: Tk, e: CombatCharacter) -> void:
		var stats := {"move": 0.0, "guard": 0.0, "cast": 0.0, "casting": false}
		t.text(e, "PROFIL")
		t.debuff(e, "profil_bio", 8.0, {"label": "Profil biologique", "color": TOXIC,
			"on_tick": func(dt: float) -> void:
				if not is_instance_valid(e):
					return
				stats.move += HitQuery.flat(e.velocity).length() * dt / 6.0
				if e.guarding:
					stats.guard += dt
				var casting: bool = e.abilities.is_casting() and e.abilities.current != null \
					and not e.abilities.is_basic_attack(e.abilities.current)
				if casting and not stats.casting:
					stats.cast += 1.0
				stats.casting = casting})
		var caster_kit: KitState = t.kit()
		var eid: int = e.get_instance_id()
		t.buff("dissection", 8.0, {"label": "Dissection", "color": TOXIC,
			"on_deal": func(target: CombatCharacter, _hit: HitData, dmg: float) -> Variant:
				if target == null or target.get_instance_id() != eid or not target.kit.has_modifier("profil_bio"):
					return null
				var kind: String = _dominant(stats)
				var out: float = dmg
				match kind:
					"mobilite":
						target.status.apply_status(StatusController.Type.SLOW, 0.6)
					"defense":
						out = dmg * 1.2
					"spam":
						K.chakra_drain(target, 4.0)
				if K.saturate(t, target, 1) >= SAT_CAP:
					target.kit.consume_mark(SAT)
					caster_kit.after(0.0, func() -> void:
						var victim := instance_from_id(eid) as CombatCharacter
						if victim != null:
							_crisis(t, victim, kind))
				return out})

	func _dominant(stats: Dictionary) -> String:
		var best: String = "mobilite"
		var score: float = float(stats.move)
		if float(stats.guard) > score:
			best = "defense"
			score = float(stats.guard)
		if float(stats.cast) > score:
			best = "spam"
		return best

	func _crisis(t: Tk, e: CombatCharacter, kind: String) -> void:
		if not is_instance_valid(e) or not t.is_enemy(e):
			return
		t.fx("spheres", e.global_position, 1.2, TOXIC)
		match kind:
			"mobilite":
				t.text(e, "CRISE: MOBILITÉ")
				t.debuff(e, "crise", 4.0, {"speed": 0.6, "label": "Crise: mobilité", "color": TOXIC})
			"defense":
				t.text(e, "CRISE: GARDE")
				t.debuff(e, "crise", 4.0, {"damage_taken": 1.15, "label": "Crise: garde", "color": TOXIC,
					"on_tick": func(dt: float) -> void:
						if is_instance_valid(e) and e.guarding:
							e._guard_absorbed += 25.0 * dt})  # guard breaks much sooner
			_:
				t.text(e, "CRISE: CHAKRA")
				var last := {"cast": null}
				t.debuff(e, "crise", 4.0, {"chakra_regen": 0.5, "label": "Crise: chakra", "color": TOXIC,
					"on_tick": func(_dt: float) -> void:
						if not is_instance_valid(e):
							return
						var cur: AbilityData = e.abilities.current if e.abilities.is_casting() else null
						if cur != null and cur != last.cast and not e.abilities.is_basic_attack(cur):
							K.chakra_drain(e, 10.0)  # every jutsu costs more
						last.cast = cur})


## S — Transformation, Adaptation, Choix en temps réel. 9 s mode with three
## Mutation slots, starting with no bonus. Each significant hit taken
## (projectile / melee / control) offers that adaptation for 2 s; the recast
## confirms it into a slot. An adaptation never grants immunity: that
## category deals -30 % and a Hôki attack answers it — projectile: Aiguille
## fires 3 needles; melee: spikes lash the attacker; control: stuns taken
## are halved and the next Hôki hit roots.
class ChimereDeLaboratoire extends Technique:
	const MODE: float = 9.0

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.recovery_time = 0.2
		a.max_range = 1.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var state := {"offer": "", "offer_at": -10.0, "slots": [], "lash_at": -10.0, "clock": 0.0}
		var caster: CombatCharacter = t.caster
		var kit: KitState = t.kit()
		t.fx("spheres", t.origin, 1.5, TOXIC)
		t.buff("chimere", MODE, {"label": "Chimère 0/3", "color": TOXIC,
			"on_tick": func(dt: float) -> void:
				state.clock = float(state.clock) + dt,
			"on_take": func(hit: HitData, dmg: float) -> Variant:
				if not is_instance_valid(caster) or dmg <= 0.0:
					return null
				var cat: String = K.category(caster, hit)
				var slots: Array = state.slots
				if not slots.has(cat):
					state.offer = cat
					state.offer_at = state.clock
					return null
				if cat == "melee" and is_instance_valid(hit.source) and float(state.clock) - float(state.lash_at) > 1.0:
					state.lash_at = state.clock
					var attacker: CombatCharacter = hit.source
					kit.after(0.0, func() -> void:
						if t.alive() and is_instance_valid(attacker):
							var rt: Tk = t.refreshed()
							rt.fx("spikes", attacker.global_position, 0.8, TOXIC)
							rt.hit(attacker, rt.dmg(0.25)))
				if cat == "control":
					kit.after(0.0, func() -> void:
						if is_instance_valid(caster) and caster.status.has_status(StatusController.Type.STUN):
							caster.status.sync_remaining(StatusController.Type.STUN,
								caster.status.get_remaining(StatusController.Type.STUN) * 0.5))
					t.buff("chim_riposte", MODE, {"uses": 1, "label": "Riposte", "color": TOXIC,
						"on_deal": func(target: CombatCharacter, _h: HitData, _d: float) -> Variant:
							if is_instance_valid(target) and not target.is_dead():
								target.status.apply_status(StatusController.Type.ROOT, 0.4)
							return null})
				return dmg * 0.7})
		t.recast(MODE, _confirm.bind(state))

	func _confirm(t: Tk, state: Dictionary) -> void:
		var mode: Dictionary = t.kit().modifiers.get("chimere", {})
		if mode.is_empty():
			return
		var slots: Array = state.slots
		var cat: String = String(state.offer)
		if cat != "" and float(state.clock) - float(state.offer_at) <= 2.0 and slots.size() < 3 and not slots.has(cat):
			slots.append(cat)
			state.offer = ""
			mode.props.label = "Chimère %d/3" % slots.size()
			t.buff("chim_" + cat, mode.left, {"label": "Mutation " + cat, "color": TOXIC})
			t.fx("spikes", t.origin, 1.2, TOXIC)
			t.text(t.caster, "MUTATION " + cat.to_upper(), TOXIC)
		if slots.size() < 3 and mode.left > 0.1:
			t.recast(mode.left, _confirm.bind(state))
