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
var _backdrop: MenuBackdrop


func _ready() -> void:
	theme = UiStyle.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var solid := ColorRect.new()
	solid.color = Color(0.03, 0.03, 0.05)
	solid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(solid)
	_backdrop = MenuBackdrop.new()
	add_child(_backdrop)
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
	move_child(_ui, _backdrop.get_index() + 1)
	var p: CharacterProfile = Profiles.profile
	var accent: Color = ClanStyles.style(p.clan_id).color if p != null else UiStyle.ACCENT
	_backdrop.show_place(p.village_id if p != null else &"konoha", ClanStyles.spot(p.clan_id) if p != null else &"plaza", accent)
	var side := TextureRect.new()
	side.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	side.offset_right = 760
	side.stretch_mode = TextureRect.STRETCH_SCALE
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var g := Gradient.new()
	g.set_color(0, Color(0.02, 0.02, 0.04, 0.85))
	g.set_color(1, Color(0.02, 0.02, 0.04, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	side.texture = tex
	_ui.add_child(side)
	if p != null:
		var crest := UiStyle.label(_ui, ClanStyles.style(p.clan_id).crest, 560, Color(accent, 0.06), 900)
		crest.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
		crest.offset_left = -900
		crest.offset_top = -400
		crest.offset_bottom = 400
		var data := CharacterData.new()
		data.look = ShinobiKit.look_for(p)
		var portrait := ShinobiPortrait.create(data, ShinobiPortrait.Framing.FULL_BODY, Vector2i(640, 900))
		portrait.set_zoom(1.15)
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
	var title := UiStyle.label(col, "NINJA BATTLE", 96, Color.WHITE, 900)
	title.add_theme_constant_override("outline_size", 0)
	title.add_theme_constant_override("shadow_offset_y", 4)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	var rule := ColorRect.new()
	rule.color = accent
	rule.custom_minimum_size = Vector2(120, 4)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(rule)
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
	b.text = "   " + text
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(460, 62 if primary else 50)
	b.add_theme_font_size_override("font_size", 26 if primary else 20)
	b.add_theme_font_override("font", UiStyle.display(700 if primary else 600))
	var base: Color = UiStyle.ACCENT if primary else Color(1, 1, 1, 0.0)
	b.add_theme_stylebox_override("normal", _bar_style(Color(base, 0.9) if primary else Color(0.05, 0.05, 0.08, 0.55), UiStyle.ACCENT if primary else Color(1, 1, 1, 0.25)))
	b.add_theme_stylebox_override("hover", _bar_style(Color(UiStyle.ACCENT, 1.0) if primary else Color(UiStyle.ACCENT, 0.2), Color.WHITE if primary else UiStyle.ACCENT))
	b.add_theme_stylebox_override("pressed", _bar_style(UiStyle.ACCENT.darkened(0.15), Color.WHITE))
	if primary:
		b.add_theme_color_override("font_color", Color(0.06, 0.04, 0.02))
		b.add_theme_color_override("font_hover_color", Color(0.06, 0.04, 0.02))
	b.pressed.connect(callback)
	parent.add_child(b)
	return b


## Flat button with a thick accent bar on the left edge.
static func _bar_style(fill: Color, bar: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = bar
	s.border_width_left = 5
	s.set_corner_radius_all(4)
	s.content_margin_left = 18
	s.content_margin_right = 18
	return s
