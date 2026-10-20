class_name ProgressionSaveService
extends RefCounted
## JSON persistence of character profiles (one file per character).
## The dictionary format (CharacterProfile.to_dict) is the same one a
## database backend would store; migrations run on load.

var directory: String


func _init(save_directory: String = "user://profiles") -> void:
	directory = save_directory


func path_for(character_id: String) -> String:
	return directory.path_join("%s.json" % character_id.validate_filename())


func save_profile(profile: CharacterProfile) -> Error:
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(path_for(profile.character_id), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(profile.to_dict(), "\t"))
	return OK


func load_profile(character_id: String) -> CharacterProfile:
	var path: String = path_for(character_id)
	if not FileAccess.file_exists(path):
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return CharacterProfile.from_dict(data) if data is Dictionary else null


func delete_profile(character_id: String) -> void:
	DirAccess.remove_absolute(path_for(character_id))
