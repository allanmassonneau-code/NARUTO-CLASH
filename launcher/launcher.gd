extends Control
## Ninja Battle launcher: checks version.json on the server, downloads and
## verifies the new build if needed, then starts the game.

const LauncherConfig = preload("res://launcher_config.gd")

enum Step { CHECKING, DOWNLOADING, INSTALLING, READY, OFFLINE }

var _http: HTTPRequest
var _manifest: Dictionary = {}
var _installed_version: String = ""
var _step: Step = Step.CHECKING
var _download_path: String = ""

@onready var _status: Label = %Status
@onready var _progress: ProgressBar = %Progress
@onready var _play: Button = %Play
@onready var _retry: Button = %Retry
@onready var _news: RichTextLabel = %News
@onready var _version: Label = %Version


func _ready() -> void:
	DisplayServer.window_set_title("Ninja Battle Launcher")
	_http = HTTPRequest.new()
	_http.timeout = 20.0
	add_child(_http)
	_play.pressed.connect(_launch_game)
	_retry.pressed.connect(_check_for_update)
	_installed_version = _read_installed_version()
	_check_for_update()


func _process(_delta: float) -> void:
	if _step == Step.DOWNLOADING:
		var total: int = int(_manifest.get("size", 0))
		if total > 0:
			_progress.value = 100.0 * _http.get_downloaded_bytes() / total
			_status.text = "Downloading v%s... %.1f / %.1f MB" % [_manifest.version, _http.get_downloaded_bytes() / 1048576.0, total / 1048576.0]


func _check_for_update() -> void:
	_set_step(Step.CHECKING, "Checking for updates...")
	var url: String = LauncherConfig.base_url().path_join("version.json")
	_http.download_file = ""
	if _http.request_completed.is_connected(_on_manifest):
		_http.request_completed.disconnect(_on_manifest)
	_http.request_completed.connect(_on_manifest, CONNECT_ONE_SHOT)
	if _http.request(url, LauncherConfig.headers()) != OK:
		_on_offline("Cannot reach %s" % url)


func _on_manifest(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_on_offline("Update server unreachable (%d/%d)." % [result, code])
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary or not (parsed as Dictionary).has("version"):
		_on_offline("Invalid update manifest.")
		return
	_manifest = parsed
	_news.text = str(_manifest.get("changelog", ""))
	if _manifest.version == _installed_version and FileAccess.file_exists(_game_exe()):
		_set_step(Step.READY, "Up to date (v%s)." % _installed_version)
		return
	_start_download()


func _start_download() -> void:
	_download_path = LauncherConfig.install_dir().path_join("download.zip")
	_http.download_file = _download_path
	_http.request_completed.connect(_on_downloaded, CONNECT_ONE_SHOT)
	var url: String = LauncherConfig.base_url().path_join(str(_manifest.file))
	_set_step(Step.DOWNLOADING, "Downloading v%s..." % _manifest.version)
	if _http.request(url, LauncherConfig.headers()) != OK:
		_on_offline("Download failed to start.")


func _on_downloaded(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_http.download_file = ""
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_on_offline("Download failed (%d/%d)." % [result, code])
		return
	_set_step(Step.INSTALLING, "Verifying...")
	await get_tree().process_frame
	if _sha256(_download_path) != str(_manifest.sha256).to_lower():
		DirAccess.remove_absolute(_download_path)
		_on_offline("Downloaded file is corrupted, please retry.")
		return
	_status.text = "Installing..."
	await get_tree().process_frame
	var err: Error = _extract(_download_path, LauncherConfig.game_dir())
	DirAccess.remove_absolute(_download_path)
	if err != OK:
		_on_offline("Install failed: %s" % error_string(err))
		return
	_installed_version = str(_manifest.version)
	var f := FileAccess.open(LauncherConfig.install_dir().path_join("version.txt"), FileAccess.WRITE)
	f.store_string(_installed_version)
	f.close()
	_set_step(Step.READY, "Updated to v%s." % _installed_version)


func _on_offline(reason: String) -> void:
	var can_play: bool = FileAccess.file_exists(_game_exe())
	_set_step(Step.OFFLINE, reason + (" You can still play v%s." % _installed_version if can_play else ""))


func _launch_game() -> void:
	var args: PackedStringArray = []
	var host: String = str(_manifest.get("server_host", ""))
	if host != "":
		args.append_array(["--", "--host=%s" % host])
	var pid: int = OS.create_process(_game_exe(), args)
	if pid <= 0:
		_status.text = "Could not start the game."
		return
	get_tree().quit()


func _set_step(step: Step, text: String) -> void:
	_step = step
	_status.text = text
	_progress.visible = step == Step.DOWNLOADING or step == Step.INSTALLING
	_play.disabled = not (step == Step.READY or (step == Step.OFFLINE and FileAccess.file_exists(_game_exe())))
	_retry.visible = step == Step.OFFLINE
	_version.text = "Installed: %s" % (_installed_version if _installed_version != "" else "none")


func _game_exe() -> String:
	return LauncherConfig.game_dir().path_join(LauncherConfig.GAME_EXE)


func _read_installed_version() -> String:
	var path: String = LauncherConfig.install_dir().path_join("version.txt")
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path).strip_edges()


static func _sha256(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	while not file.eof_reached():
		ctx.update(file.get_buffer(1 << 20))
	return ctx.finish().hex_encode()


## Replaces `target` with the zip content.
static func _extract(zip_path: String, target: String) -> Error:
	var zip := ZIPReader.new()
	var err: Error = zip.open(zip_path)
	if err != OK:
		return err
	_remove_dir(target)
	DirAccess.make_dir_recursive_absolute(target)
	for entry: String in zip.get_files():
		var out_path: String = target.path_join(entry)
		if not out_path.simplify_path().begins_with(target.simplify_path()):
			continue  # refuse path traversal
		if entry.ends_with("/"):
			DirAccess.make_dir_recursive_absolute(out_path)
			continue
		DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
		var out := FileAccess.open(out_path, FileAccess.WRITE)
		if out == null:
			zip.close()
			return FileAccess.get_open_error()
		out.store_buffer(zip.read_file(entry))
		out.close()
	zip.close()
	return OK


static func _remove_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file: String in dir.get_files():
		dir.remove(file)
	for sub: String in dir.get_directories():
		_remove_dir(path.path_join(sub))
	DirAccess.remove_absolute(path)
