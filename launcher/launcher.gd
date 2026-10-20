extends Control
## Ninja Battle launcher: checks version.json on the server, downloads and
## verifies the new build if needed, then starts the game.

const LauncherConfig = preload("res://launcher_config.gd")

enum Step { CHECKING, DOWNLOADING, INSTALLING, READY, OFFLINE }

var _http: HTTPRequest
## The archive download has no total time limit (it is large); it only fails
## when no data arrives for this long.
const STALL_TIMEOUT: float = 30.0
var _stall_time: float = 0.0
var _last_bytes: int = 0
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

## Account (created / checked against the account service, UDP 7778).
const ACCOUNT_PORT: int = 7778
const ACCOUNT_FILE: String = "account.cfg"
var _user: String = ""
var _auth: String = ""
var _account_box: HBoxContainer
var _user_edit: LineEdit
var _pass_edit: LineEdit
var _account_status: Label
var _enet: ENetConnection
var _enet_peer: ENetPacketPeer
var _enet_request: Dictionary = {}
var _enet_wait: float = 0.0


func _ready() -> void:
	DisplayServer.window_set_title("Ninja Battle Launcher")
	_http = HTTPRequest.new()
	_http.timeout = 20.0
	_http.download_chunk_size = 1 << 20
	add_child(_http)
	_play.pressed.connect(_launch_game)
	_retry.pressed.connect(_check_for_update)
	_installed_version = _read_installed_version()
	_build_account_box()
	_check_for_update()


func _process(delta: float) -> void:
	_poll_account(delta)
	if _step == Step.DOWNLOADING:
		var got: int = _http.get_downloaded_bytes()
		if got != _last_bytes:
			_last_bytes = got
			_stall_time = 0.0
		else:
			_stall_time += delta
			if _stall_time >= STALL_TIMEOUT:
				_http.cancel_request()
				_http.download_file = ""
				if _http.request_completed.is_connected(_on_downloaded):
					_http.request_completed.disconnect(_on_downloaded)
				_on_offline("Download stalled (no data for %ds)." % int(STALL_TIMEOUT))
				return
		var total: int = int(_manifest.get("size", 0))
		if total > 0:
			_progress.value = 100.0 * _http.get_downloaded_bytes() / total
			_status.text = "Downloading v%s... %.1f / %.1f MB" % [_manifest.version, _http.get_downloaded_bytes() / 1048576.0, total / 1048576.0]


func _check_for_update() -> void:
	_set_step(Step.CHECKING, "Checking for updates...")
	var url: String = LauncherConfig.base_url().path_join("version.json")
	_http.download_file = ""
	_http.timeout = 20.0
	if _http.request_completed.is_connected(_on_manifest):
		_http.request_completed.disconnect(_on_manifest)
	_http.request_completed.connect(_on_manifest, CONNECT_ONE_SHOT)
	if _http.request(url) != OK:
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
	_http.timeout = 0.0  # no total limit: stalls are caught in _process
	_stall_time = 0.0
	_last_bytes = 0
	_http.request_completed.connect(_on_downloaded, CONNECT_ONE_SHOT)
	var url: String = LauncherConfig.base_url().path_join(str(_manifest.file))
	_set_step(Step.DOWNLOADING, "Downloading v%s..." % _manifest.version)
	if _http.request(url) != OK:
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
	args.append("--")
	if host != "":
		args.append("--host=%s" % host)
	if _user != "":
		args.append_array(["--account=%s" % _user, "--auth=%s" % _auth])
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


# --- Account --------------------------------------------------------------------

func _build_account_box() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(LauncherConfig.install_dir().path_join(ACCOUNT_FILE)) == OK:
		_user = str(cfg.get_value("account", "user", ""))
		_auth = str(cfg.get_value("account", "auth", ""))
	_account_box = HBoxContainer.new()
	_account_box.add_theme_constant_override("separation", 8)
	var buttons: Node = _play.get_parent()
	buttons.get_parent().add_child(_account_box)
	buttons.get_parent().move_child(_account_box, buttons.get_index())
	_account_status = Label.new()
	_account_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_account_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_refresh_account_box()


func _refresh_account_box() -> void:
	for child: Node in _account_box.get_children():
		if child != _account_status:
			child.queue_free()
	if _account_status.get_parent() == null:
		_account_box.add_child(_account_status)
	if _user != "":
		_account_status.text = "Compte : %s" % _user
		var out := Button.new()
		out.text = "Changer de compte"
		out.pressed.connect(func() -> void:
			_user = ""
			_auth = ""
			_save_account()
			_refresh_account_box())
		_account_box.add_child(out)
		return
	_account_status.text = "Connecte-toi ou crée un compte (sinon : jeu hors ligne)."
	_user_edit = LineEdit.new()
	_user_edit.placeholder_text = "Identifiant"
	_user_edit.custom_minimum_size = Vector2(150, 0)
	_account_box.add_child(_user_edit)
	_pass_edit = LineEdit.new()
	_pass_edit.placeholder_text = "Mot de passe"
	_pass_edit.secret = true
	_pass_edit.custom_minimum_size = Vector2(150, 0)
	_account_box.add_child(_pass_edit)
	for op: Array in [["login", "Connexion"], ["register", "Créer un compte"]]:
		var b := Button.new()
		b.text = op[1]
		b.pressed.connect(_account_request.bind(op[0]))
		_account_box.add_child(b)
	_account_box.move_child(_account_status, _account_box.get_child_count() - 1)


func _account_request(op: String) -> void:
	var user: String = _user_edit.text.strip_edges().to_lower()
	var password: String = _pass_edit.text
	if user.length() < 3 or password.length() < 4:
		_account_status.text = "Identifiant (3-16 : a-z 0-9 _) et mot de passe (4+) requis."
		return
	var host: String = str(_manifest.get("server_host", ""))
	if host == "":
		_account_status.text = "Serveur inconnu : attends la vérification des mises à jour."
		return
	# Same formula as AccountStore.auth_hash in the game: the password never leaves the PC.
	var auth: String = ("ninjabattle:%s:%s" % [user, password]).sha256_text()
	_enet = ENetConnection.new()
	_enet.create_host(1, 1)
	_enet_peer = _enet.connect_to_host(host, ACCOUNT_PORT, 1)
	_enet_request = {"op": op, "user": user, "auth": auth}
	_enet_wait = 8.0
	_account_status.text = "Connexion au serveur de comptes..."


func _poll_account(delta: float) -> void:
	if _enet == null:
		return
	_enet_wait -= delta
	if _enet_wait <= 0.0:
		_account_done({"ok": false, "error": "TIMEOUT"})
		return
	var event: Array = _enet.service(0)
	match event[0]:
		ENetConnection.EVENT_CONNECT:
			_enet_peer.send(0, JSON.stringify(_enet_request).to_utf8_buffer(), ENetPacketPeer.FLAG_RELIABLE)
		ENetConnection.EVENT_RECEIVE:
			var reply: Variant = JSON.parse_string((event[1] as ENetPacketPeer).get_packet().get_string_from_utf8())
			_account_done(reply if reply is Dictionary else {"ok": false, "error": "BAD_REPLY"})
		ENetConnection.EVENT_DISCONNECT:
			_account_done({"ok": false, "error": "DISCONNECTED"})


const ACCOUNT_ERRORS: Dictionary = {"NAME_TAKEN": "Identifiant déjà pris.", "INVALID_NAME": "Identifiant invalide (3-16 : a-z 0-9 _).",
	"BAD_LOGIN": "Identifiant ou mot de passe incorrect.", "TIMEOUT": "Serveur de comptes injoignable.",
	"DISCONNECTED": "Serveur de comptes injoignable."}


func _account_done(reply: Dictionary) -> void:
	if _enet_peer != null:
		_enet_peer.peer_disconnect_now()
	_enet.destroy()
	_enet = null
	if not reply.get("ok", false):
		_account_status.text = ACCOUNT_ERRORS.get(str(reply.get("error", "")), "Erreur : %s" % reply.get("error", "?"))
		return
	_user = str(_enet_request.user)
	_auth = str(_enet_request.auth)
	_save_account()
	_refresh_account_box()


func _save_account() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("account", "user", _user)
	cfg.set_value("account", "auth", _auth)
	cfg.save(LauncherConfig.install_dir().path_join(ACCOUNT_FILE))
