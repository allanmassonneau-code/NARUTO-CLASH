class_name ProgressionAuthority
extends RefCounted
## Server entry point for player progression requests:
##   CLIENT REQUEST -> validation -> modification -> save / replication.
## Clients never edit a profile; they send {"action": ..., args...} and get
## back the result (and the updated profile). Admin actions are not here.

signal profile_changed(profile: CharacterProfile, result: ProgressionResult)

var service: ProgressionService
var saves: ProgressionSaveService
## character id -> recent kill timestamps (msec), for the rate limit.
var _kills: Dictionary = {}


func _init(progression: ProgressionService, save_service: ProgressionSaveService = null) -> void:
	service = progression
	saves = save_service


func handle_request(profile: CharacterProfile, request: Dictionary) -> ProgressionResult:
	if profile == null:
		return ProgressionResult.fail(&"NO_PROFILE")
	var result: ProgressionResult
	match str(request.get("action", "")):
		"choose_primary_nature":
			result = service.choose_primary_nature(profile, _id(request, "nature"))
		"choose_secondary_nature":
			result = service.choose_secondary_nature(profile, _id(request, "nature"))
		"choose_specialization":
			result = service.choose_specialization(profile, _id(request, "specialization"))
		"learn_jutsu":
			result = service.learn_jutsu(profile, _id(request, "jutsu"))
		"equip_jutsu":
			result = service.equip_jutsu(profile, _id(request, "jutsu"))
		"unequip_jutsu":
			result = service.unequip_jutsu(profile, _id(request, "jutsu"))
		"unlock_tenketsu":
			result = service.tenketsu.unlock(profile, _id(request, "node"))
		"sub_jutsu_keep":
			result = service.resolve_sub_jutsu_evolution(profile, true)
		"report_kill":
			result = _report_kill(profile, _id(request, "mob"))
		"sub_jutsu_sacrifice":
			result = service.resolve_sub_jutsu_evolution(profile, false, bool(request.get("confirmed", false)))
		_:
			# Promotions are granted by the game (missions, admin), never requested.
			return ProgressionResult.fail(&"UNKNOWN_ACTION")
	if result.ok:
		if saves != null:
			saves.save_profile(profile)
		profile_changed.emit(profile, result)
	return result


## XP comes from the server's mob table, never from the client; kills are
## rate limited per character.
func _report_kill(profile: CharacterProfile, mob_id: StringName) -> ProgressionResult:
	if not service.db.mob_xp.has(mob_id):
		return ProgressionResult.fail(&"UNKNOWN_MOB")
	var now: int = Time.get_ticks_msec()
	var recent: Array = (_kills.get(profile.character_id, []) as Array).filter(func(t: int) -> bool: return now - t < 60000)
	if recent.size() >= service.db.max_kills_per_minute:
		return ProgressionResult.fail(&"TOO_MANY_KILLS")
	recent.append(now)
	_kills[profile.character_id] = recent
	return service.grant_xp(profile, int(service.db.mob_xp[mob_id]))


static func _id(request: Dictionary, key: String) -> StringName:
	return StringName(str(request.get(key, "")))
