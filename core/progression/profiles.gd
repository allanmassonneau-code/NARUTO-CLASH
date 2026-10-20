extends Node
## Autoload (Profiles): the client's access to its shinobi profile.
## Every change is a request handled by a ProgressionAuthority:
## - online: on the game server (Net RPCs), which owns and saves the profile;
## - offline: by a local authority (same rules, saved in user://profiles).
## UI code only calls create() / request() and listens to profile_updated.

signal profile_updated(profile: CharacterProfile, result: ProgressionResult)

enum Backend { LOCAL, REMOTE }

var db: ProgressionDatabase
var profile: CharacterProfile
var backend: Backend = Backend.LOCAL

var _service: ProgressionService
var _authority: ProgressionAuthority
var _saves: ProgressionSaveService


func _ready() -> void:
	db = ProgressionDatabase.load_default()
	_service = ProgressionService.new(db)
	_saves = ProgressionSaveService.new()
	_authority = ProgressionAuthority.new(_service, _saves)
	if not Net.is_server():
		profile = _load(local_id())


## Loads a saved profile, cleaned of content that no longer exists.
func _load(character_id: String) -> CharacterProfile:
	var p: CharacterProfile = _saves.load_profile(character_id)
	if p != null and _service.prune_unknown_content(p):
		_saves.save_profile(p)
	return p


## Offline profile id (one character per machine for now).
func local_id() -> String:
	return "local_" + GameSession.account_token.left(12)


func is_remote() -> bool:
	return backend == Backend.REMOTE


func service() -> ProgressionService:
	return _service


func create(character_name: String, village_id: StringName, origin: ProgressionTypes.Origin, clan_id: StringName) -> void:
	if is_remote():
		Net.profile_create(character_name, village_id, origin, clan_id)
		return
	var created: Dictionary = _service.create_character(local_id(), character_name, village_id, origin, clan_id)
	var result: ProgressionResult = created.result
	if result.ok:
		profile = created.profile
		_saves.save_profile(profile)
	profile_updated.emit(profile, result)


## Player action (see ProgressionAuthority.handle_request for the actions).
func request(action: Dictionary) -> void:
	if is_remote():
		Net.profile_request(action)
		return
	var result: ProgressionResult = _authority.handle_request(profile, action)
	profile_updated.emit(profile, result)


## Offline test tool: grades are normally granted by the game, not requested.
func dev_promote() -> void:
	if is_remote() or profile == null:
		return
	var result: ProgressionResult = _service.promote(profile)
	_saves.save_profile(profile)
	profile_updated.emit(profile, result)


## Offline only: delete the local character.
func dev_reset() -> void:
	if is_remote():
		return
	_saves.delete_profile(local_id())
	profile = null
	profile_updated.emit(null, ProgressionResult.success())


# --- Remote backend (called by Net) -------------------------------------------

func use_remote(enabled: bool) -> void:
	backend = Backend.REMOTE if enabled else Backend.LOCAL
	if not enabled:
		profile = _load(local_id())
		profile_updated.emit(profile, ProgressionResult.success())


func apply_remote(profile_data: Dictionary, ok: bool, error: String, events: Array) -> void:
	profile = CharacterProfile.from_dict(profile_data) if not profile_data.is_empty() else null
	var result := ProgressionResult.success() if ok else ProgressionResult.fail(StringName(error))
	for e: Variant in events:
		if e is Dictionary:
			result.events.append(e)
	profile_updated.emit(profile, result)


# --- Server side ------------------------------------------------------------------

## Server: profile of an account (loaded from disk), null if none yet.
func server_load(account_id: String) -> CharacterProfile:
	return _load(account_id)


func server_create(account_id: String, character_name: String, village_id: StringName, origin: int, clan_id: StringName) -> Dictionary:
	if _load(account_id) != null:
		return {"profile": _load(account_id), "result": ProgressionResult.fail(&"ALREADY_EXISTS")}
	var created: Dictionary = _service.create_character(account_id, character_name.left(20), village_id, origin as ProgressionTypes.Origin, clan_id)
	if (created.result as ProgressionResult).ok:
		_saves.save_profile(created.profile)
	return created


func server_request(account_id: String, action: Dictionary) -> Dictionary:
	var p: CharacterProfile = _load(account_id)
	var result: ProgressionResult = _authority.handle_request(p, action)
	return {"profile": p, "result": result}
