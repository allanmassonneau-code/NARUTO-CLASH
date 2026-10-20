class_name AccountStore
extends RefCounted
## Server-side player accounts (one JSON file per account): username, salted
## password hash, character ids (MAX_CHARACTERS). The client never sends the
## password, only auth_hash(user, password); the store keeps
## sha256(salt + auth) so a stolen file doesn't reveal the auth either.

const MAX_CHARACTERS: int = 10
const DIRECTORY: String = "user://accounts"

var directory: String


func _init(dir: String = DIRECTORY) -> void:
	directory = dir


## What the launcher sends instead of the password.
static func auth_hash(user: String, password: String) -> String:
	return ("ninjabattle:%s:%s" % [normalize(user), password]).sha256_text()


static func normalize(user: String) -> String:
	return user.strip_edges().to_lower()


static func valid_name(user: String) -> bool:
	var re := RegEx.create_from_string("^[a-z0-9_]{3,16}$")
	return re.search(normalize(user)) != null


static func account_id(user: String) -> String:
	return "u_" + normalize(user)


func _path(user: String) -> String:
	return directory.path_join(normalize(user) + ".json")


func exists(user: String) -> bool:
	return valid_name(user) and FileAccess.file_exists(_path(user))


func _read(user: String) -> Dictionary:
	if not exists(user):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(_path(user)))
	return data if data is Dictionary else {}


func _write(user: String, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	var f := FileAccess.open(_path(user), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "\t"))


## "" on success, otherwise an error code.
func register(user: String, auth: String) -> String:
	if not valid_name(user):
		return "INVALID_NAME"
	if auth.length() != 64:
		return "INVALID_PASSWORD"
	if exists(user):
		return "NAME_TAKEN"
	var salt: String = Crypto.new().generate_random_bytes(16).hex_encode()
	_write(user, {"user": normalize(user), "salt": salt, "hash": (salt + auth).sha256_text(),
		"characters": [], "created": Time.get_unix_time_from_system()})
	return ""


func verify(user: String, auth: String) -> bool:
	var data: Dictionary = _read(user)
	return not data.is_empty() and (str(data.salt) + auth).sha256_text() == str(data.hash)


func characters(user: String) -> Array[String]:
	var out: Array[String] = []
	for id: Variant in _read(user).get("characters", []):
		out.append(str(id))
	return out


func add_character(user: String, character_id: String) -> bool:
	var data: Dictionary = _read(user)
	var list: Array = data.get("characters", [])
	if data.is_empty() or list.size() >= MAX_CHARACTERS or list.has(character_id):
		return false
	list.append(character_id)
	data.characters = list
	_write(user, data)
	return true


func remove_character(user: String, character_id: String) -> bool:
	var data: Dictionary = _read(user)
	var list: Array = data.get("characters", [])
	if not list.has(character_id):
		return false
	list.erase(character_id)
	data.characters = list
	_write(user, data)
	return true
