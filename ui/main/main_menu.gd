extends Control
## Title screen of Ninja Battle. Without a character: "Créer un personnage"
## (full-screen CharacterCreator). With one: the shinobi on display, Play,
## SHINOBI (progression screen), Appearance, Options, Quit. Connected to the
## game server (profile only) so the profile is stored and validated
## server-side; falls back to the offline profile otherwise.

const RETRY_DELAY: float = 10.0

var _retry: Timer
var _status: String = ""
var _ui: Control
var _options: OptionsPanel


func _ready() -> void:
	theme = UiStyle.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_options = OptionsPanel.attach(self)
	SSAudio.music(&"title")
	SSAudio.ambience(&"")
	Net.status_changed.connect(_on_status)
	Net.connection_closed.connect(func(_reason: String) -> void: _retry.start())
	Profiles.profile_updated.connect(func(_p: CharacterProfile, _r: ProgressionResult) -> void: _rebuild.call_deferred())
	_retry = Timer.new()
	_retry.one_shot = true
	_retry.wait_time = RETRY_DELAY
	_retry.timeout.connect(_connect)
	add_child(_retry)
	_rebuild()
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
	_status = text.split("\n")[0].left(80) if text != "" else ""
	_rebuild()


func _rebuild() -> void:
	if is_instance_valid(_ui):
		_ui.queue_free()
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_ui)
	move_child(_ui, 0)
	var p: CharacterProfile = Profiles.profile
	var accent: Color = ClanStyles.style(p.clan_id).color if p != null else UiStyle.ACCENT
	var bg := ColorRect.new()
	bg.color = accent.darkened(0.85)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(bg)
	if p != null:
		var crest := UiStyle.label(_ui, ClanStyles.style(p.clan_id).crest, 560, Color(accent, 0.06), 900)
		crest.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
		crest.offset_left = -900
		crest.offset_top = -400
		crest.offset_bottom = 400
		var data := CharacterData.new()
		data.look = ShinobiKit.look_for(p)
		var portrait := ShinobiPortrait.create(data, ShinobiPortrait.Framing.FULL_BODY, Vector2i(640, 900))
		portrait.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
		portrait.offset_left = -760
		portrait.offset_right = -80
		_ui.add_child(portrait)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	col.offset_left = 80
	col.offset_right = 620
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	_ui.add_child(col)
	var title := UiStyle.label(col, "NINJA BATTLE", 72, UiStyle.ACCENT, 900)
	title.add_theme_constant_override("outline_size", 12)
	UiStyle.label(col, ("Profil en ligne" if Profiles.is_remote() else "Profil hors ligne") + ("  ·  " + _status if _status != "" else ""), 14, UiStyle.MUTED, 700)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 30)
	col.add_child(gap)
	if p == null:
		UiStyle.label(col, "Aucun shinobi pour l'instant.", 18, Color.WHITE, 700)
		_menu_button(col, "CRÉER UN PERSONNAGE", true, func() -> void:
			CharacterCreator.open(self).finished.connect(func(_done: bool) -> void: _rebuild()))
	else:
		var v: VillageData = Profiles.db.get_village(p.village_id)
		var clan: ClanData = Profiles.db.get_clan(p.clan_id)
		UiStyle.label(col, p.character_name, 34, Color.WHITE, 900)
		UiStyle.label(col, "%s  ·  %s  ·  %s" % [ShinobiScreen.GRADE_NAMES[p.grade], v.display_name if v != null else "",
			("Clan " + clan.display_name) if clan != null else "Sans clan"], 16, accent.lightened(0.25), 800)
		_menu_button(col, "JOUER", true, func() -> void: get_tree().change_scene_to_file(ShinobiScreen.WORLD_SCENE))
		_menu_button(col, "SHINOBI  (natures, clan, techniques)", false, _open_shinobi)
		_menu_button(col, "APPARENCE", false, func() -> void:
			CharacterCreator.open(self, true).finished.connect(func(_done: bool) -> void: _rebuild()))
	_menu_button(col, "OPTIONS", false, func() -> void: _options.toggle())
	_menu_button(col, "QUITTER", false, func() -> void: get_tree().quit())


func _open_shinobi() -> void:
	var screen := ShinobiScreen.new()
	screen.status_text = _status
	add_child(screen)
	screen.tree_exited.connect(_rebuild)


func _menu_button(parent: Control, text: String, primary: bool, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(440, 64 if primary else 50)
	b.add_theme_font_size_override("font_size", 22 if primary else 17)
	b.add_theme_font_override("font", UiStyle.font(900 if primary else 700))
	var color: Color = UiStyle.ACCENT if primary else Color(1, 1, 1, 0.12)
	b.add_theme_stylebox_override("normal", UiStyle.panel(Color(color, 0.25) if primary else Color(0.06, 0.05, 0.09, 0.85), 12, color, 18))
	b.add_theme_stylebox_override("hover", UiStyle.panel(Color(UiStyle.ACCENT, 0.32), 12, UiStyle.ACCENT, 18))
	b.add_theme_stylebox_override("pressed", UiStyle.panel(Color(UiStyle.ACCENT, 0.4), 12, UiStyle.ACCENT, 18))
	b.pressed.connect(callback)
	parent.add_child(b)
	return b
