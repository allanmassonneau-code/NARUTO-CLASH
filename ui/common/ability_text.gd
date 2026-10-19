class_name AbilityText
## Short, generated jutsu descriptions ("18 dmg · stun 0.6 s · 7 s") so the
## character select and tooltips always match the actual data.


static func summary(a: AbilityData) -> String:
	var parts: PackedStringArray = []
	match a.kind:
		AbilityData.Kind.MELEE_ARC:
			parts.append("melee" if a.multi_hits <= 1 else "%d-hit flurry" % a.multi_hits)
		AbilityData.Kind.PROJECTILE:
			parts.append("projectile %d m" % roundi(a.max_range))
		AbilityData.Kind.DASH:
			parts.append("dash %d m" % roundi(a.dash_distance) + (" · intangible" if a.dash_immaterial else ""))
		AbilityData.Kind.GROUND_AREA:
			parts.append("trap" if a.trap else ("wall" if a.wall_length > 0.0 else ("kunai marker" if a.marker else "area")))
		AbilityData.Kind.COUNTER:
			parts.append("counter %.1f s" % a.active_time)
		AbilityData.Kind.SELF_HEAL:
			if a.heal_amount > 0.0:
				parts.append("heal %d" % roundi(a.heal_amount) + (" (allies too)" if a.heal_allies_radius > 0.0 else ""))
		AbilityData.Kind.SUMMON_CLONE:
			parts.append("shadow clone %d s" % roundi(a.summon_duration))
		AbilityData.Kind.TELEPORT:
			parts.append("teleport")
	if a.damage > 0.0:
		parts.append("%d dmg" % roundi(a.damage * maxi(a.multi_hits, 1)))
	if a.stun_duration > 0.0:
		parts.append("stun %.1f s" % a.stun_duration)
	if a.root_duration > 0.0:
		parts.append("root %.1f s" % a.root_duration)
	if a.knockback_speed >= 7.0:
		parts.append("knockback")
	if a.slow_duration > 0.0:
		parts.append("slow")
	if a.silence_duration > 0.0 or a.apply_lock > 0:
		parts.append("silence" if a.silence_duration > 0.0 else "chakra block")
	if a.incapacitate_duration > 0.0:
		parts.append("genjutsu %.1f s" % a.incapacitate_duration)
	if a.burn_duration > 0.0:
		parts.append("burn")
	if a.apply_mark > 0:
		parts.append("mark")
	if a.apply_seal:
		parts.append("seal")
	if a.grant_shield > 0.0:
		parts.append("shield %d" % roundi(a.grant_shield))
	if a.buff_haste > 0.0:
		parts.append("haste")
	if a.buff_empower > 0.0:
		parts.append("empower")
	if a.zone_duration > 0.0 and not a.trap:
		parts.append("lingers %d s" % roundi(a.zone_duration))
	return " · ".join(parts)


static func cost(a: AbilityData) -> String:
	if a.energy_cost >= 100.0:
		return "ULTIMATE"
	if a.cooldown > 0.0:
		return "%s s" % (str(roundi(a.cooldown)) if is_equal_approx(a.cooldown, roundf(a.cooldown)) else "%.1f" % a.cooldown)
	if a.combo_next != null:
		var hits: int = 1
		var next: AbilityData = a.combo_next
		while next != null and hits < 8:
			hits += 1
			next = next.combo_next
		return "%d-hit combo" % hits
	return ""
