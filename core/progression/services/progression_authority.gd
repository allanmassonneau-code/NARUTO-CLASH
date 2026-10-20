class_name ProgressionAuthority
extends RefCounted
## Server entry point for player progression requests:
##   CLIENT REQUEST -> validation -> modification -> save / replication.
## Clients never edit a profile; they send {"action": ..., args...} and get
## back the result (and the updated profile). Admin actions are not here.

signal profile_changed(profile: CharacterProfile, result: ProgressionResult)

var service: ProgressionService
var saves: ProgressionSaveService


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


static func _id(request: Dictionary, key: String) -> StringName:
	return StringName(str(request.get(key, "")))
