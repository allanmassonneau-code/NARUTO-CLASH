extends Node
## Autoload (Profiles): the client's access to its shinobi profile.
## Every change is a request handled by a ProgressionAuthority:
## - online: on the game server (Net RPCs), which owns and saves the profile;
## - offline: by a local authority (same rules, saved in user://profiles).
## UI code only calls create() / request() and listens to profile_updated.

signal profile_updated(profile: CharacterProfile, result: ProgressionResult)
## The account's characters changed (list of summaries, see summary()).
signal characters_updated(list: Array)

const MAX_CHARACTERS: int = 10

enum Backend { LOCAL, REMOTE }

var db: ProgressionDatabase
var profile: CharacterProfile
var backend: Backend = Backend.LOCAL
## Characters of the account / of this machine (summaries).
var characters: Array = []
## Offline: id of the selected local character.
var _local_current: String = ""

var _service: ProgressionService
var _authority: ProgressionAuthority
var _saves: ProgressionSaveService


func _ready() -> void:
	db = ProgressionDatabase.load_default()
	_service = ProgressionService.new(db)
	_saves = ProgressionSaveService.new()
	_authority = ProgressionAuthority.new(_service, _saves)
	if not Net.is_server():
		_refresh_local()
		var first: String = GameSession.last_character if _has_local(GameSession.last_character) else _first_local()
		if first != "":
			_local_current = first
			profile = _load(first)


## Loads a saved profile, cleaned of content that no longer exists.
func _load(character_id: String) -> CharacterProfile:
	var p: CharacterProfile = _saves.load_profile(character_id)
	if p != null and _service.prune_unknown_content(p):
		_saves.save_profile(p)
	return p


## Offline: id of the selected local character (a new one when none).
func local_id() -> String:
	if _local_current == "":
		_local_current = "local_" + Crypto.new().generate_random_bytes(6).hex_encode()
	return _local_current


## Light description of a character for the selection screen.
static func summary(p: CharacterProfile) -> Dictionary:
	return {"id": p.character_id, "name": p.character_name, "grade": int(p.grade), "village": String(p.village_id),
		"clan": String(p.clan_id), "appearance": p.appearance.duplicate(true)}


func can_create() -> bool:
	return characters.size() < MAX_CHARACTERS


## Selects a character of the account (online: the server answers with it).
func select_character(character_id: String) -> void:
	GameSession.last_character = character_id
	GameSession.save_settings()
	if is_remote():
		Net.select_character(character_id)
		return
	if not _has_local(character_id):
		return
	_local_current = character_id
	profile = _load(character_id)
	profile_updated.emit(profile, ProgressionResult.success())


func delete_character(character_id: String) -> void:
	if is_remote():
		Net.delete_character(character_id)
		return
	_saves.delete_profile(character_id)
	if character_id == _local_current:
		_local_current = ""
		profile = null
		profile_updated.emit(null, ProgressionResult.success())
	_refresh_local()


## Online: the server's list of the account's characters.
func apply_characters(list: Array) -> void:
	characters = list
	characters_updated.emit(characters)


## Offline: characters saved on this machine (user://profiles/local_*).
func _refresh_local() -> void:
	characters = []
	var dir := DirAccess.open(_saves.directory)
	if dir != null:
		for file: String in dir.get_files():
			if file.begins_with("local_") and file.ends_with(".json"):
				var p: CharacterProfile = _load(file.trim_suffix(".json"))
				if p != null:
					characters.append(summary(p))
	characters_updated.emit(characters)


func _has_local(character_id: String) -> bool:
	return character_id != "" and characters.any(func(c: Dictionary) -> bool: return c.id == character_id)


func _first_local() -> String:
	return str(characters[0].id) if not characters.is_empty() else ""


func is_remote() -> bool:
	return backend == Backend.REMOTE


func service() -> ProgressionService:
	return _service


func create(character_name: String, village_id: StringName, origin: ProgressionTypes.Origin, clan_id: StringName) -> void:
	if is_remote():
		Net.profile_create(character_name, village_id, origin, clan_id)
		return
	if not can_create():
		profile_updated.emit(profile, ProgressionResult.fail(&"TOO_MANY_CHARACTERS"))
		return
	_local_current = ""
	var created: Dictionary = _service.create_character(local_id(), character_name, village_id, origin, clan_id)
	var result: ProgressionResult = created.result
	if result.ok:
		profile = created.profile
		_saves.save_profile(profile)
		GameSession.last_character = profile.character_id
		GameSession.save_settings()
		_refresh_local()
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
	_local_current = ""
	profile = null
	_refresh_local()
	profile_updated.emit(null, ProgressionResult.success())


# --- Remote backend (called by Net) -------------------------------------------

func use_remote(enabled: bool) -> void:
	backend = Backend.REMOTE if enabled else Backend.LOCAL
	if enabled:
		profile = null
		characters = []
	else:
		_refresh_local()
		profile = _load(_local_current) if _has_local(_local_current) else null
		profile_updated.emit(profile, ProgressionResult.success())


func apply_remote(profile_data: Dictionary, ok: bool, error: String, events: Array) -> void:
	profile = CharacterProfile.from_dict(profile_data) if not profile_data.is_empty() else null
	if profile != null:
		GameSession.last_character = profile.character_id
		GameSession.save_settings()
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


func server_delete(character_id: String) -> void:
	_saves.delete_profile(character_id)


func server_request(account_id: String, action: Dictionary) -> Dictionary:
	var p: CharacterProfile = _load(account_id)
	var result: ProgressionResult = _authority.handle_request(p, action)
	return {"profile": p, "result": result}
