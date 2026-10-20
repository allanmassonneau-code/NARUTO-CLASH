class_name ShinobiScreen
extends Control
## Character progression screen: creation (village, clan / clanless),
## profile header, pending choices (nature, specialization, second nature,
## sub-jutsu evolution), skill trees (natures, clan), specialization,
## sub-jutsu, Tenketsu and the loadout. Every action is a request through
## the Profiles autoload; this screen never edits the profile itself.

const STATE_COLORS: Dictionary = {
	ProgressionTypes.NodeState.LOCKED_GRADE: Color(0.35, 0.35, 0.4),
	ProgressionTypes.NodeState.AVAILABLE: Color(1.0, 0.65, 0.2),
	ProgressionTypes.NodeState.SELECTED: Color(0.35, 0.9, 0.45),
	ProgressionTypes.NodeState.LOCKED_BY_CHOICE: Color(0.5, 0.2, 0.2),
	ProgressionTypes.NodeState.UNLOCKED: Color(0.35, 0.9, 0.45),
}
const STATE_LABELS: Dictionary = {
	ProgressionTypes.NodeState.LOCKED_GRADE: "Grade insuffisant",
	ProgressionTypes.NodeState.AVAILABLE: "Disponible",
	ProgressionTypes.NodeState.SELECTED: "Choisie",
	ProgressionTypes.NodeState.LOCKED_BY_CHOICE: "Verrouillée par ton choix",
	ProgressionTypes.NodeState.UNLOCKED: "Apprise",
}
const WORLD_SCENE: String = "res://world/world.tscn"
const GRADE_NAMES: Array[String] = ["Genin", "Chunin", "Konin", "Tokubetsu", "Jonin"]

## Main screen of the game (no close button, Esc does nothing).
var embedded: bool = false
## In-game overlay: shows a "Menu principal" button calling this.
var on_quit: Callable
## Extra line under the title (connection state), set by the main menu.
var status_text: String = ""
var _db: ProgressionDatabase
var _body: VBoxContainer
var _tab: String = "nature1"
var _toast: Label
var _modal: Control
# Creation wizard state.
var _new_name: String = ""
var _new_village: StringName = &"konoha"
var _new_clan: bool = true
var _new_clan_id: StringName = &""
# Appearance editor (SS character creator) state.
var _look_edit: Dictionary = {}
var _look_portrait: ShinobiPortrait
var _look_controls: VBoxContainer
var _cloth_page: int = 0


func _ready() -> void:
	_db = Profiles.db
	theme = UiStyle.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.035, 0.07, 0.97 if embedded else 0.9)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 14)
	scroll.add_child(_body)
	_toast = UiStyle.label(self, "", 18, Color.WHITE, 800)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.offset_top = -70
	_toast.offset_bottom = -30
	_toast.offset_left = -500
	_toast.offset_right = 500
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_constant_override("outline_size", 8)
	Profiles.profile_updated.connect(_on_profile_updated)
	_rebuild()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible:
		if _modal != null:
			_close_modal()
		elif not embedded:
			queue_free()
		get_viewport().set_input_as_handled()


func _on_profile_updated(_profile: CharacterProfile, result: ProgressionResult) -> void:
	if not result.ok:
		_show_toast(_error_text(result.error), Color(1.0, 0.4, 0.35))
	for event: Dictionary in result.events:
		match event.type:
			&"sub_jutsu_obtained":
				_reveal_sub_jutsu(event.sub_jutsu)
			&"promoted":
				_show_toast("PROMU %s !" % GRADE_NAMES[int(event.grade)].to_upper(), UiStyle.ACCENT)
			&"jutsu_learned":
				_show_toast("Technique apprise : %s" % _jutsu_name(event.jutsu), Color(0.5, 1.0, 0.6))
			&"appearance_changed":
				_show_toast("Apparence enregistrée.", Color(0.5, 1.0, 0.6))
			&"sub_jutsu_roll_empty":
				_show_toast("Aucune technique cachée disponible pour ce tirage.", Color(1.0, 0.8, 0.4))
	_rebuild()


# --- Layout -------------------------------------------------------------------

func _rebuild() -> void:
	for child: Node in _body.get_children():
		child.queue_free()
	_header_bar()
	var p: CharacterProfile = Profiles.profile
	if p == null:
		_creation()
		return
	_profile_header(p)
	_pending_banner(p)
	_tabs(p)
	match _tab:
		"nature1":
			_nature_tree(p, p.primary_nature, "Nature principale")
		"nature2":
			_nature_tree(p, p.secondary_nature, "Nature secondaire")
		"clan":
			_clan_tree(p)
		"spec":
			_specialization_view(p)
		"sub":
			_sub_jutsu_view(p)
		"tenketsu":
			_tenketsu_view(p)
		"loadout":
			_loadout_view(p)
		"look":
			_appearance_view(p)


func _header_bar() -> void:
	var row := HBoxContainer.new()
	_body.add_child(row)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", -6)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(titles)
	UiStyle.label(titles, "NINJA BATTLE" if embedded else "SHINOBI", 34, UiStyle.ACCENT, 900)
	var online: String = "Profil en ligne (serveur)" if Profiles.is_remote() else "Profil hors ligne"
	UiStyle.label(titles, online + ("  ·  " + status_text if status_text != "" else ""), 13, UiStyle.MUTED, 700)
	if embedded and Profiles.profile != null:
		var go := _button(row, "PARTIR À L'AVENTURE", func() -> void: get_tree().change_scene_to_file(WORLD_SCENE))
		go.add_theme_font_override("font", UiStyle.font(900))
		go.add_theme_color_override("font_color", UiStyle.ACCENT)
	if not Profiles.is_remote() and Profiles.profile != null:
		_button(row, "Promouvoir (test)", Profiles.dev_promote).tooltip_text = "Outil de test hors ligne : les grades s'obtiennent normalement en jeu."
		_button(row, "Supprimer (test)", func() -> void: _confirm("Supprimer ce personnage hors ligne ?", Profiles.dev_reset))
	if on_quit.is_valid():
		_button(row, "Menu principal", on_quit)
	if not embedded:
		_button(row, "✕  Fermer  (Échap)", queue_free)


func _profile_header(p: CharacterProfile) -> void:
	var panel := _panel(_body, UiStyle.ACCENT)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	panel.add_child(row)
	var left := VBoxContainer.new()
	row.add_child(left)
	UiStyle.label(left, p.character_name, 28, Color.WHITE, 900)
	var village: VillageData = _db.get_village(p.village_id)
	var clan: ClanData = _db.get_clan(p.clan_id)
	UiStyle.label(left, "%s  ·  %s" % [village.display_name if village else "?", ("Clan " + clan.display_name) if clan else "Sans clan"], 15, UiStyle.MUTED, 700)
	var grade := VBoxContainer.new()
	row.add_child(grade)
	UiStyle.label(grade, "GRADE", 12, UiStyle.MUTED, 800)
	UiStyle.label(grade, GRADE_NAMES[p.grade].to_upper(), 26, UiStyle.ACCENT, 900)
	var res: Dictionary = Profiles.service().max_resources(p)
	_stat(row, "PV", "%d" % roundi(res.hp), Color(0.4, 1.0, 0.5))
	_stat(row, "CHAKRA", "%d" % roundi(res.chakra), UiStyle.CHAKRA)
	_stat(row, "TENKETSU", "%d / %d" % [Profiles.service().tenketsu.available_points(p), p.tenketsu_earned], Color(1.0, 0.85, 0.4))
	var natures: String = _nature_name(p.primary_nature) + ((" + " + _nature_name(p.secondary_nature)) if p.secondary_nature != &"" else "")
	_stat(row, "NATURES", natures if natures != "" else "—", Color.WHITE)
	var spec: SpecializationData = _db.get_specialization(p.specialization_id)
	_stat(row, "SPÉCIALITÉ", spec.display_name if spec else "—", Color.WHITE)


func _pending_banner(p: CharacterProfile) -> void:
	if p.pending_choices.is_empty():
		return
	var panel := _panel(_body, Color(1.0, 0.75, 0.2))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	UiStyle.label(row, "CHOIX À FAIRE :", 16, Color(1.0, 0.85, 0.4), 900).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for choice: int in p.pending_choices:
		match choice:
			ProgressionTypes.Choice.PRIMARY_NATURE:
				_button(row, "Choisir ta nature de chakra", _choose_nature_modal.bind(false))
			ProgressionTypes.Choice.SECONDARY_NATURE:
				_button(row, "Choisir ta seconde nature", _choose_nature_modal.bind(true))
			ProgressionTypes.Choice.SPECIALIZATION:
				_button(row, "Choisir ta spécialité", _choose_specialization_modal)
			ProgressionTypes.Choice.SUB_JUTSU_EVOLUTION:
				_button(row, "Évolution du Sub-jutsu", _evolution_modal)


func _tabs(p: CharacterProfile) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_body.add_child(row)
	var tabs: Array = [["nature1", "Nature 1"]]
	if p.secondary_nature != &"" or p.grade >= ProgressionTypes.Grade.TOKUBETSU:
		tabs.append(["nature2", "Nature 2"])
	tabs.append(["clan", "Clan"] if p.is_clan() else ["sub", "Sub-jutsu"])
	tabs.append_array([["spec", "Spécialité"], ["tenketsu", "Tenketsu"], ["loadout", "Équipement"]])
	if SSAvatars.available():
		tabs.append(["look", "Apparence"])
	for t: Array in tabs:
		var b := _button(row, t[1], func() -> void:
			_tab = t[0]
			_rebuild())
		b.toggle_mode = true
		b.button_pressed = _tab == t[0]


# --- Creation -------------------------------------------------------------------

func _creation() -> void:
	var panel := _panel(_body, UiStyle.ACCENT)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	UiStyle.label(col, "CRÉE TON SHINOBI", 26, Color.WHITE, 900)
	UiStyle.label(col, "Ton village et ton origine sont définitifs.", 14, UiStyle.MUTED, 600)
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "Nom du personnage"
	name_edit.text = _new_name if _new_name != "" else GameSession.player_name
	name_edit.custom_minimum_size = Vector2(320, 42)
	name_edit.text_changed.connect(func(t: String) -> void: _new_name = t)
	col.add_child(name_edit)
	UiStyle.label(col, "1. VILLAGE", 15, UiStyle.ACCENT, 900)
	var villages := HBoxContainer.new()
	villages.add_theme_constant_override("separation", 10)
	col.add_child(villages)
	for v: VillageData in _db.villages:
		var b := _button(villages, v.display_name, func() -> void:
			_new_village = v.id
			_new_clan_id = &""
			_new_name = name_edit.text
			_rebuild())
		b.toggle_mode = true
		b.button_pressed = v.id == _new_village
		b.custom_minimum_size = Vector2(150, 50)
	UiStyle.label(col, "2. ORIGINE", 15, UiStyle.ACCENT, 900)
	var origins := HBoxContainer.new()
	origins.add_theme_constant_override("separation", 10)
	col.add_child(origins)
	for option: Array in [[true, "CLAN", "Arbre de clan garanti (5 techniques D → S), identité forte."],
			[false, "SANS CLAN", "Pas d'arbre de clan, mais des techniques cachées (Sub-jutsu) tirées au sort dès Chunin."]]:
		var card := _choice_card(origins, option[1], option[2], option[0] == _new_clan, func() -> void:
			_new_clan = option[0]
			_new_name = name_edit.text
			_rebuild())
		card.custom_minimum_size = Vector2(380, 0)
	if _new_clan:
		UiStyle.label(col, "3. CLAN", 15, UiStyle.ACCENT, 900)
		var grid := GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		col.add_child(grid)
		for c: ClanData in _db.clans_of_village(_new_village):
			var preview: String = c.description + "\n\n" + "\n".join(c.jutsu.map(func(j: JutsuData) -> String:
				return "%s · %s" % [ProgressionTypes.rank_key(j.rank), j.display_name]))
			var card := _choice_card(grid, c.display_name, preview, c.id == _new_clan_id, func() -> void:
				_new_clan_id = c.id
				_new_name = name_edit.text
				_rebuild())
			card.custom_minimum_size = Vector2(230, 0)
	var create := _button(col, "CRÉER LE PERSONNAGE", func() -> void:
		var n: String = name_edit.text.strip_edges()
		if n == "":
			_show_toast("Donne un nom à ton personnage.", Color(1.0, 0.4, 0.35))
			return
		if _new_clan and _new_clan_id == &"":
			_show_toast("Choisis un clan.", Color(1.0, 0.4, 0.35))
			return
		var origin: ProgressionTypes.Origin = ProgressionTypes.Origin.CLAN if _new_clan else ProgressionTypes.Origin.CLANLESS
		Profiles.create(n, _new_village, origin, _new_clan_id if _new_clan else &""))
	create.custom_minimum_size = Vector2(320, 56)
	create.add_theme_font_size_override("font_size", 20)


# --- Trees ---------------------------------------------------------------------

func _nature_tree(p: CharacterProfile, nature_id: StringName, title: String) -> void:
	var nature: ChakraNatureData = _db.get_nature(nature_id)
	if nature == null:
		var hint: String = "Choisis d'abord ta nature de chakra." if title == "Nature principale" else "La seconde nature se débloque au grade Tokubetsu."
		UiStyle.label(_body, hint, 16, UiStyle.MUTED, 700)
		return
	UiStyle.label(_body, "%s : %s — %s" % [title.to_upper(), nature.display_name.to_upper(), nature.description], 18, nature.color, 900)
	_signature(nature.identity, nature.signature, nature.color)
	UiStyle.label(_body, "Une seule technique par rang : le choix est définitif.", 13, UiStyle.MUTED, 600)
	for rank in ProgressionTypes.Rank.values():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		_body.add_child(row)
		_rank_badge(row, rank)
		var options: Array[JutsuData] = nature.jutsu_of_rank(rank)
		for i in options.size():
			if i > 0:
				UiStyle.label(row, "OU", 14, UiStyle.MUTED, 900).size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_jutsu_node(row, p, options[i])


func _clan_tree(p: CharacterProfile) -> void:
	var clan: ClanData = _db.get_clan(p.clan_id)
	if clan == null:
		return
	UiStyle.label(_body, "CLAN %s — %s" % [clan.display_name.to_upper(), clan.description], 18, UiStyle.ACCENT, 900)
	_signature(clan.identity, clan.signature, UiStyle.ACCENT)
	for rank in ProgressionTypes.Rank.values():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		_body.add_child(row)
		_rank_badge(row, rank)
		for j: JutsuData in clan.jutsu:
			if j.rank == rank:
				_jutsu_node(row, p, j)


func _jutsu_node(parent: Control, p: CharacterProfile, j: JutsuData) -> void:
	var state: ProgressionTypes.NodeState = JutsuRules.node_state(_db, p, j)
	var color: Color = STATE_COLORS[state]
	var panel := PanelContainer.new()
	var style := UiStyle.panel(Color(color.darkened(0.8), 0.95), 10, color, 12)
	style.set_border_width_all(3 if state == ProgressionTypes.NodeState.AVAILABLE else 2)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(380, 0)
	parent.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	panel.add_child(col)
	var top := HBoxContainer.new()
	col.add_child(top)
	var icon := SSIcons.add_rect(top, j.id, j.display_name, 44)
	if icon != null and state == ProgressionTypes.NodeState.LOCKED_BY_CHOICE:
		icon.modulate = Color(0.45, 0.4, 0.4)
	var name_label := UiStyle.label(top, j.display_name, 16, Color.WHITE if state != ProgressionTypes.NodeState.LOCKED_BY_CHOICE else Color(0.6, 0.5, 0.5), 800)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiStyle.label(top, STATE_LABELS[state], 12, color.lightened(0.2), 800)
	var desc := UiStyle.label(col, j.description, 13, UiStyle.MUTED, 600)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiStyle.label(col, "%d chakra  ·  %ss  ·  %s" % [roundi(j.chakra_cost), str(j.cooldown), _tag_text(j)], 11, Color(0.6, 0.7, 0.9), 700)
	_details(col, j)
	if state == ProgressionTypes.NodeState.AVAILABLE:
		var learn := _button(col, "Apprendre", func() -> void:
			var warning: String = "Apprendre %s ?" % j.display_name
			if j.source == ProgressionTypes.JutsuSource.NATURE:
				warning += "\nL'autre technique de ce rang sera définitivement verrouillée."
			_confirm(warning, func() -> void: Profiles.request({"action": "learn_jutsu", "jutsu": j.id})))
		learn.size_flags_horizontal = Control.SIZE_SHRINK_END


## Kit identity + signature mechanic from the design bible.
func _signature(identity: String, signature: String, color: Color) -> void:
	if signature != "":
		var sig := UiStyle.label(_body, "Mécanique signature — " + signature, 14, color.lightened(0.35), 800)
		sig.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if identity != "":
		var id_label := UiStyle.label(_body, identity, 13, UiStyle.MUTED, 600)
		id_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


static func _tag_text(j: JutsuData) -> String:
	if not j.design_tags.is_empty():
		return " · ".join(j.design_tags).to_upper()
	return " ".join(j.tags.map(func(t: StringName) -> String: return String(t)))


## "Détails" toggle showing the full design text (mechanic, synergies, counter).
func _details(col: VBoxContainer, j: JutsuData) -> void:
	if j.details == "":
		return
	var text := UiStyle.label(col, j.details, 12, Color(0.85, 0.83, 0.8), 600)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.visible = false
	var toggle := Button.new()
	toggle.text = "▸ Détails"
	toggle.flat = true
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	toggle.add_theme_font_size_override("font_size", 12)
	toggle.add_theme_color_override("font_color", UiStyle.ACCENT)
	toggle.pressed.connect(func() -> void:
		text.visible = not text.visible
		toggle.text = "▾ Détails" if text.visible else "▸ Détails")
	col.add_child(toggle)
	col.move_child(toggle, text.get_index())


func _rank_badge(parent: Control, rank: int) -> void:
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UiStyle.panel(Color(0.12, 0.1, 0.18), 8, UiStyle.ACCENT, 8))
	badge.custom_minimum_size = Vector2(56, 56)
	parent.add_child(badge)
	var l := UiStyle.label(badge, ProgressionTypes.rank_key(rank), 26, UiStyle.ACCENT, 900)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


# --- Specialization / sub-jutsu / Tenketsu / loadout -----------------------------

func _specialization_view(p: CharacterProfile) -> void:
	var spec: SpecializationData = _db.get_specialization(p.specialization_id)
	if spec == null:
		UiStyle.label(_body, "La spécialité se choisit au grade Chunin.", 16, UiStyle.MUTED, 700)
		return
	UiStyle.label(_body, "%s — %s" % [spec.display_name.to_upper(), spec.description], 18, UiStyle.ACCENT, 900)
	for j: JutsuData in spec.all_skills():
		_skill_line(_body, j, "PASSIF" if j.passive else "ACTIF")


func _sub_jutsu_view(p: CharacterProfile) -> void:
	UiStyle.label(_body, "TECHNIQUES CACHÉES", 18, UiStyle.ACCENT, 900)
	UiStyle.label(_body, "Premier tirage au grade Chunin, évolution au grade Tokubetsu.", 13, UiStyle.MUTED, 600)
	if p.owned_sub_jutsu.is_empty():
		UiStyle.label(_body, "Aucune technique cachée pour l'instant.", 16, UiStyle.MUTED, 700)
	for id: StringName in p.owned_sub_jutsu:
		var sub: SubJutsuData = _db.get_sub_jutsu(id)
		if sub != null:
			_skill_line(_body, sub, "RANG " + ProgressionTypes.rank_key(sub.rank))


func _tenketsu_view(p: CharacterProfile) -> void:
	var t: TenketsuService = Profiles.service().tenketsu
	UiStyle.label(_body, "TENKETSU — %d point(s) disponible(s)" % t.available_points(p), 18, UiStyle.ACCENT, 900)
	UiStyle.label(_body, "+2 points à chaque grade. Un nœud demande ses prérequis.", 13, UiStyle.MUTED, 600)
	var canvas := Control.new()
	canvas.custom_minimum_size = Vector2(1100, 520)
	_body.add_child(canvas)
	var cell := Vector2(270, 125)
	for node: TenketsuNodeData in _db.tenketsu_tree.nodes:
		var level: int = t.level_of(p, node.id)
		var can: bool = t.can_unlock(p, node.id).ok
		var color: Color = Color(0.35, 0.9, 0.45) if level >= node.max_level else (Color(1.0, 0.65, 0.2) if can else (Color(0.7, 0.85, 1.0) if level > 0 else Color(0.35, 0.35, 0.4)))
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UiStyle.panel(Color(color.darkened(0.8), 0.95), 12, color, 10))
		panel.position = node.position_in_tree * cell
		panel.custom_minimum_size = Vector2(250, 105)
		canvas.add_child(panel)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		panel.add_child(col)
		UiStyle.label(col, "%s  %d/%d" % [node.display_name, level, node.max_level], 15, Color.WHITE, 800)
		var desc := UiStyle.label(col, node.description, 12, UiStyle.MUTED, 600)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if can:
			_button(col, "+1  (%d pt)" % node.cost, func() -> void: Profiles.request({"action": "unlock_tenketsu", "node": node.id}))


func _loadout_view(p: CharacterProfile) -> void:
	UiStyle.label(_body, "ÉQUIPEMENT — %d / %d techniques équipées" % [p.equipped_jutsu.size(), _db.max_equipped_jutsu], 18, UiStyle.ACCENT, 900)
	UiStyle.label(_body, "Une technique apprise n'est utilisable en combat qu'une fois équipée.", 13, UiStyle.MUTED, 600)
	for id: StringName in p.learned_jutsu:
		var j: JutsuData = _db.get_jutsu(id)
		if j == null or j.passive:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_body.add_child(row)
		var equipped: bool = p.equipped_jutsu.has(id)
		var b := _button(row, "Retirer" if equipped else "Équiper", func() -> void:
			Profiles.request({"action": "unequip_jutsu" if equipped else "equip_jutsu", "jutsu": id}))
		b.custom_minimum_size = Vector2(110, 0)
		SSIcons.add_rect(row, j.id, j.display_name, 32)
		UiStyle.label(row, "%s  [%s]" % [j.display_name, ProgressionTypes.rank_key(j.rank)], 15, Color(0.5, 1.0, 0.6) if equipped else Color.WHITE, 700)


# --- Appearance (Shinobi Striker character creator) ------------------------------

const LOOK_SLOTS: Array[Array] = [["hair", "Coiffure"], ["upper", "Haut"], ["lower", "Bas"]]
const CLOTH_PAGE: int = 30


func _appearance_view(p: CharacterProfile) -> void:
	if _look_edit.is_empty():
		var start: Dictionary = p.appearance.duplicate(true)
		start["seed"] = absi(hash(p.character_id + p.character_name))
		_look_edit = SSAvatars.complete(start)
	UiStyle.label(_body, "APPARENCE — créateur de personnage Shinobi Striker", 18, UiStyle.ACCENT, 900)
	UiStyle.label(_body, "Pièces et couleurs du jeu (local). Cosmétique : aucun effet en combat.", 13, UiStyle.MUTED, 600)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	_body.add_child(row)
	_look_portrait = ShinobiPortrait.create(_look_data(), ShinobiPortrait.Framing.FULL_BODY, Vector2i(420, 560))
	_look_portrait.custom_minimum_size = Vector2(420, 560)
	_look_portrait.flourishes = false
	row.add_child(_look_portrait)
	_look_controls = VBoxContainer.new()
	_look_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_look_controls.add_theme_constant_override("separation", 10)
	row.add_child(_look_controls)
	_look_rebuild_controls()


func _look_data() -> CharacterData:
	var data := CharacterData.new()
	data.look = ShinobiLook.new()
	data.look.ss_avatar = _look_edit.duplicate(true)
	return data


func _look_changed() -> void:
	if _look_portrait != null:
		_look_portrait.set_character(_look_data())
	_look_rebuild_controls()


func _look_rebuild_controls() -> void:
	for child: Node in _look_controls.get_children():
		child.queue_free()
	var sex_row := HBoxContainer.new()
	sex_row.add_theme_constant_override("separation", 8)
	_look_controls.add_child(sex_row)
	UiStyle.label(sex_row, "Sexe", 15, Color.WHITE, 800).custom_minimum_size = Vector2(110, 0)
	for sex: Array in [["Male", "Homme"], ["Female", "Femme"]]:
		var b := _button(sex_row, sex[1], func() -> void:
			_look_edit = SSAvatars.complete({"seed": int(_look_edit.get("seed", 1)), "sex": sex[0], "skin": _look_edit.get("skin", "")})
			_look_changed())
		b.toggle_mode = true
		b.button_pressed = _look_edit.get("sex", "") == sex[0]
	for slot: Array in LOOK_SLOTS:
		_look_part_row(slot[0], slot[1])
	var fronts: Array = [""]
	for o: Dictionary in SSAvatars.forehead_options():
		fronts.append(o.material)
	_look_choice_row("Bandeau", "forehead", fronts, "Celui de la coiffure")
	var accs: Array = [""]
	for o: Dictionary in SSAvatars.accessory_options():
		accs.append(o.mesh)
	_look_choice_row("Accessoire", "accessory", accs, "Aucun")
	_look_swatches("Peau", SSAvatars.colour_ids("Skin"), _look_edit.get("skin", ""), func(id: String) -> void: _look_edit.skin = id)
	_look_swatches("Cheveux", SSAvatars.colour_ids("Hair").slice(0, CLOTH_PAGE), _look_colour("hair", 0), func(id: String) -> void: _set_look_colour("hair", 0, id))
	var cloth: Array[String] = SSAvatars.colour_ids("Cloth")
	var page: Array[String] = cloth.slice(_cloth_page * CLOTH_PAGE, (_cloth_page + 1) * CLOTH_PAGE)
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 8)
	_look_controls.add_child(nav)
	UiStyle.label(nav, "Tissus  %d / %d" % [_cloth_page + 1, ceili(cloth.size() / float(CLOTH_PAGE))], 13, UiStyle.MUTED, 700)
	_button(nav, "◀", func() -> void:
		_cloth_page = posmod(_cloth_page - 1, ceili(cloth.size() / float(CLOTH_PAGE)))
		_look_rebuild_controls())
	_button(nav, "▶", func() -> void:
		_cloth_page = posmod(_cloth_page + 1, ceili(cloth.size() / float(CLOTH_PAGE)))
		_look_rebuild_controls())
	for slot: Array in [["upper", "Haut"], ["lower", "Bas"]]:
		for k in 2:
			_look_swatches("%s %d" % [slot[1], k + 1], page, _look_colour(slot[0], k), func(id: String) -> void: _set_look_colour(slot[0], k, id))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	_look_controls.add_child(actions)
	_button(actions, "Aléatoire", func() -> void:
		_look_edit = SSAvatars.complete({"seed": randi()})
		_look_changed())
	var save := _button(actions, "ENREGISTRER", func() -> void:
		var out: Dictionary = _look_edit.duplicate(true)
		out.erase("seed")
		Profiles.request({"action": "set_appearance", "appearance": out}))
	save.add_theme_color_override("font_color", UiStyle.ACCENT)


func _look_part_row(slot: String, title: String) -> void:
	var opts: Array[Dictionary] = SSAvatars.options(slot, _look_edit.get("sex", "Male"))
	if opts.is_empty():
		return
	var current: int = 0
	for i in opts.size():
		if opts[i].mesh == _look_edit.get(slot, ""):
			current = i
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_look_controls.add_child(row)
	UiStyle.label(row, title, 15, Color.WHITE, 800).custom_minimum_size = Vector2(110, 0)
	var step := func(delta: int) -> void:
		var pick: Dictionary = opts[posmod(current + delta, opts.size())]
		_look_edit[slot] = pick.mesh
		_look_edit[slot + "_colors"] = [pick.color0, pick.color1]
		_look_changed()
	_button(row, "◀", step.bind(-1))
	var name_label := UiStyle.label(row, "%s   (%d / %d)" % [_part_name(opts[current].mesh), current + 1, opts.size()], 14, UiStyle.TEXT, 700)
	name_label.custom_minimum_size = Vector2(300, 0)
	_button(row, "▶", step.bind(1))


func _look_choice_row(title: String, key: String, values: Array, empty_label: String) -> void:
	if values.size() <= 1:
		return
	var current: int = maxi(0, values.find(_look_edit.get(key, "")))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_look_controls.add_child(row)
	UiStyle.label(row, title, 15, Color.WHITE, 800).custom_minimum_size = Vector2(110, 0)
	var step := func(delta: int) -> void:
		_look_edit[key] = values[posmod(current + delta, values.size())]
		_look_changed()
	_button(row, "◀", step.bind(-1))
	var v: String = values[current]
	var text: String = empty_label if v == "" else v.trim_prefix("MI_CHR_").trim_prefix("SM_CHR_").trim_prefix("SM_").replace("_", " ")
	UiStyle.label(row, "%s   (%d / %d)" % [text, current + 1, values.size()], 14, UiStyle.TEXT, 700).custom_minimum_size = Vector2(300, 0)
	_button(row, "▶", step.bind(1))


func _look_swatches(title: String, ids: Array, selected: String, on_pick: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_look_controls.add_child(row)
	UiStyle.label(row, title, 13, Color.WHITE, 800).custom_minimum_size = Vector2(110, 0)
	var grid := HFlowContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	row.add_child(grid)
	for id: String in ids:
		var b := Button.new()
		b.custom_minimum_size = Vector2(24, 24)
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = id.trim_prefix("ID_PartsColor_")
		var style := UiStyle.panel(SSAvatars.colour(id), 4, Color.WHITE if id == selected else Color(0, 0, 0, 0.6), 0)
		style.set_border_width_all(3 if id == selected else 1)
		for state: String in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(state, style)
		b.pressed.connect(func() -> void:
			on_pick.call(id)
			_look_changed())
		grid.add_child(b)


func _look_colour(slot: String, k: int) -> String:
	var ids: Array = _look_edit.get(slot + "_colors", ["", ""])
	return str(ids[k]) if ids.size() > k else ""


func _set_look_colour(slot: String, k: int, id: String) -> void:
	var ids: Array = (_look_edit.get(slot + "_colors", ["", ""]) as Array).duplicate()
	while ids.size() < 2:
		ids.append("")
	ids[k] = id
	_look_edit[slot + "_colors"] = ids


func _part_name(mesh: String) -> String:
	return mesh.trim_prefix("SK_CHR_").replace("Man_", "").replace("Woman_", "").replace("_", " ")


func _skill_line(parent: Control, j: JutsuData, tag: String) -> void:
	var panel := _panel(parent, Color(1, 1, 1, 0.2))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	panel.add_child(line)
	SSIcons.add_rect(line, j.id, j.display_name, 48)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(col)
	UiStyle.label(col, "%s   ·   %s" % [j.display_name, tag], 16, Color.WHITE, 800)
	var desc := UiStyle.label(col, j.description, 13, UiStyle.MUTED, 600)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


# --- Choice modals --------------------------------------------------------------

func _choose_nature_modal(secondary: bool) -> void:
	var col := _open_modal("CHOISIS TA %s NATURE DE CHAKRA" % ("SECONDE" if secondary else "PREMIÈRE"))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	col.add_child(grid)
	for n: ChakraNatureData in _db.natures:
		if secondary and n.id == Profiles.profile.primary_nature:
			continue
		var card := _choice_card(grid, n.display_name, n.description, false, func() -> void:
			_confirm("Choisir %s ? Ce choix est définitif." % n.display_name, func() -> void:
				_close_modal()
				Profiles.request({"action": "choose_secondary_nature" if secondary else "choose_primary_nature", "nature": n.id})))
		card.custom_minimum_size = Vector2(200, 0)


func _choose_specialization_modal() -> void:
	var col := _open_modal("CHOISIS TA SPÉCIALITÉ")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	for s: SpecializationData in _db.specializations:
		var lines: PackedStringArray = [s.role.to_upper(), s.description, ""]
		for a: JutsuData in s.active_skills:
			lines.append("• " + a.display_name)
		lines.append("Passif : " + s.passive_skill.display_name)
		var card := _choice_card(row, s.display_name, "\n".join(lines), false, func() -> void:
			_confirm("Devenir %s ? Ce choix est définitif." % s.display_name, func() -> void:
				_close_modal()
				Profiles.request({"action": "choose_specialization", "specialization": s.id})))
		card.custom_minimum_size = Vector2(260, 0)


func _evolution_modal() -> void:
	var p: CharacterProfile = Profiles.profile
	var col := _open_modal("ÉVOLUTION DU SUB-JUTSU")
	var current: SubJutsuData = Profiles.service().sacrifice_target(p)
	UiStyle.label(col, "Technique actuelle : %s" % ("%s (rang %s)" % [current.display_name, ProgressionTypes.rank_key(current.rank)] if current else "aucune"), 16, Color.WHITE, 700)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	_choice_card(row, "CONSERVER", "Conservez votre technique actuelle\net obtenez un nouveau tirage.", false, func() -> void:
		_close_modal()
		Profiles.request({"action": "sub_jutsu_keep"})).custom_minimum_size = Vector2(320, 0)
	var can_sacrifice: bool = current != null and SubJutsuRollService.higher_rank(current.rank) >= 0
	var sacrifice_text: String = "Supprimez votre technique actuelle\npour tenter d'obtenir une technique\nd'un rang supérieur." if can_sacrifice \
		else "Impossible : aucune technique de rang supérieur."
	var card := _choice_card(row, "SACRIFIER", sacrifice_text, false, func() -> void:
		if not can_sacrifice:
			return
		_confirm("Sacrifier définitivement %s ?" % current.display_name, func() -> void:
			_close_modal()
			Profiles.request({"action": "sub_jutsu_sacrifice", "confirmed": true})))
	card.custom_minimum_size = Vector2(320, 0)
	card.modulate = Color.WHITE if can_sacrifice else Color(0.6, 0.6, 0.6)


func _reveal_sub_jutsu(sub_id: StringName) -> void:
	var sub: SubJutsuData = _db.get_sub_jutsu(sub_id)
	if sub == null:
		return
	var col := _open_modal("TECHNIQUE CACHÉE")
	var rank_colors: Dictionary = {ProgressionTypes.Rank.B: Color(0.5, 0.8, 1.0), ProgressionTypes.Rank.A: Color(0.8, 0.5, 1.0), ProgressionTypes.Rank.S: Color(1.0, 0.8, 0.25)}
	var color: Color = rank_colors.get(sub.rank, Color.WHITE)
	var title := UiStyle.label(col, "SUB-JUTSU OBTENU", 18, UiStyle.MUTED, 900)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var name_label := UiStyle.label(col, sub.display_name, 40, color, 900)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_constant_override("outline_size", 10)
	var rank := UiStyle.label(col, "RANG " + ProgressionTypes.rank_key(sub.rank), 24, color, 900)
	rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var desc := UiStyle.label(col, sub.details if sub.details != "" else sub.description, 14 if sub.details != "" else 16, Color.WHITE, 600)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(620, 0)
	name_label.pivot_offset = Vector2(300, 25)
	name_label.scale = Vector2(0.2, 0.2)
	name_label.modulate.a = 0.0
	var tween := name_label.create_tween().set_parallel(true)
	tween.tween_property(name_label, "scale", Vector2.ONE, 0.7).set_delay(0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(name_label, "modulate:a", 1.0, 0.4).set_delay(0.4)
	Sfx.play(&"orb", Vector3.INF, -2.0)


# --- Widgets -----------------------------------------------------------------------

func _open_modal(title: String) -> VBoxContainer:
	_close_modal()
	_modal = ColorRect.new()
	(_modal as ColorRect).color = Color(0, 0, 0, 0.75)
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_modal)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(center)
	var panel := PanelContainer.new()
	var style := UiStyle.panel(Color(0.07, 0.06, 0.11, 0.98), 14, UiStyle.ACCENT, 22)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(600, 0)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var t := UiStyle.label(head, title, 22, UiStyle.ACCENT, 900)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(head, "✕", _close_modal)
	return col


func _close_modal() -> void:
	if _modal != null:
		_modal.queue_free()
		_modal = null


func _confirm(text: String, on_yes: Callable) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = text
	dialog.ok_button_text = "Confirmer"
	dialog.cancel_button_text = "Annuler"
	dialog.confirmed.connect(on_yes)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()


func _choice_card(parent: Control, title: String, text: String, selected: bool, on_pick: Callable) -> PanelContainer:
	var card := PanelContainer.new()
	var color: Color = UiStyle.ACCENT if selected else Color(1, 1, 1, 0.2)
	var style := UiStyle.panel(Color(0.08, 0.07, 0.12, 0.95), 12, color, 14)
	style.set_border_width_all(3 if selected else 1)
	card.add_theme_stylebox_override("panel", style)
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.gui_input.connect(func(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			on_pick.call())
	card.mouse_entered.connect(func() -> void: style.border_color = UiStyle.ACCENT.lightened(0.3))
	card.mouse_exited.connect(func() -> void: style.border_color = color)
	parent.add_child(card)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(col)
	UiStyle.label(col, title, 18, Color.WHITE, 900)
	var body := UiStyle.label(col, text, 13, UiStyle.MUTED, 600)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return card


func _panel(parent: Control, border: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel(Color(0.07, 0.06, 0.11, 0.92), 12, border, 16))
	parent.add_child(panel)
	return panel


func _stat(parent: Control, title: String, value: String, color: Color) -> void:
	var col := VBoxContainer.new()
	parent.add_child(col)
	UiStyle.label(col, title, 12, UiStyle.MUTED, 800)
	UiStyle.label(col, value, 22, color, 900)


func _button(parent: Control, text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 40)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(callback)
	parent.add_child(b)
	return b


func _show_toast(text: String, color: Color) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	_toast.modulate.a = 1.0
	var tween := _toast.create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(_toast, "modulate:a", 0.0, 0.6)


func _nature_name(id: StringName) -> String:
	var n: ChakraNatureData = _db.get_nature(id)
	return n.display_name if n != null else ""


func _jutsu_name(id: Variant) -> String:
	var j: JutsuData = _db.get_jutsu(StringName(str(id)))
	return j.display_name if j != null else str(id)


func _error_text(code: StringName) -> String:
	var texts: Dictionary = {
		&"RANK_LOCKED_BY_GRADE": "Ton grade ne permet pas encore ce rang.",
		&"RANK_ALREADY_CHOSEN": "Tu as déjà choisi une technique de ce rang.",
		&"NOT_ENOUGH_POINTS": "Pas assez de points de Tenketsu.",
		&"MISSING_PREREQUISITE": "Prérequis manquant.",
		&"NO_FREE_SLOT": "Plus d'emplacement libre : retire une technique.",
		&"ALREADY_EXISTS": "Tu as déjà un personnage.",
	}
	return texts.get(code, "Action refusée (%s)." % code)
