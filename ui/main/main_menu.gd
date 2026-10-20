extends Control
## Entry screen of Ninja Battle: the shinobi progression screen, connected to
## the game server (profile only, no matchmaking) so the profile is stored
## and validated server-side; falls back to the offline profile otherwise.

const RETRY_DELAY: float = 10.0

var _screen: ShinobiScreen
var _retry: Timer


func _ready() -> void:
	theme = UiStyle.theme()
	_screen = ShinobiScreen.new()
	_screen.embedded = true
	add_child(_screen)
	OptionsPanel.attach(self)
	SSAudio.music(&"title")
	SSAudio.ambience(&"")
	Net.status_changed.connect(_on_status)
	Net.connection_closed.connect(func(_reason: String) -> void: _retry.start())
	_retry = Timer.new()
	_retry.one_shot = true
	_retry.wait_time = RETRY_DELAY
	_retry.timeout.connect(_connect)
	add_child(_retry)
	_connect()


func _connect() -> void:
	if Net.is_client() and Net.is_online():
		return
	if GameSession.server_host == "" or GameSession.server_host == "127.0.0.1" and not OS.has_feature("editor"):
		_on_status("Pas de serveur configuré : mode hors ligne.")
		return
	Net.join(GameSession.server_host, "1v1", GameSession.player_name, 0, "", false)


func _on_status(text: String) -> void:
	if Net.is_client() and Net.is_online():
		text = "connecté à %s" % GameSession.server_host
	_screen.status_text = text.split("\n")[0].left(80) if text != "" else ""
	_screen._rebuild()
