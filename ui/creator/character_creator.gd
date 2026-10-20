class_name CharacterCreator
extends Control
## Full-screen character creator: Village -> Origin -> Clan -> Appearance ->
## Identity, around a large live 3D preview of the Shinobi Striker avatar.
## Clans shape the look: signature hair / skin palettes, clan colours, and
## outfits reserved to their clan or village (ClanStyles).
## Edit mode (existing character): appearance only, then save.

signal finished(created: bool)

enum Step { VILLAGE, ORIGIN, CLAN, LOOK, IDENTITY }
const STEP_NAMES: Array[String] = ["Village", "Origine", "Clan", "Apparence", "Identité"]
const LOOK_TABS: Array[String] = ["Corps", "Cheveux", "Tenue", "Accessoires"]
const SWATCH: Vector2 = Vector2(30, 30)

var edit_mode: bool = false

var _db: ProgressionDatabase
var _step: int = Step.VILLAGE
var _village: StringName = &"konoha"
var _with_clan: bool = true
var _clan: StringName = &""
var _name: String = ""
var _avatar: Dictionary = {}
var _look_tab: int = 0
var _cloth_page: int = 0

var _bg: MenuBackdrop
var _watermark: Label
var _steps_box: VBoxContainer
var _content: VBoxContainer
var _scroll: ScrollContainer
var _portrait: ShinobiPortrait
var _banner: Label
var _traits: Label
var _prev: Button
var _next: Button
var _error: Label
var _dragging: bool = false


static func open(parent: Node, edit: bool = false) -> CharacterCreator:
	var c := CharacterCreator.new()
	c.edit_mode = edit
	parent.add_child(c)
	return c


func _ready() -> void:
	_db = Profiles.db
	theme = UiStyle.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var p: CharacterProfile = Profiles.profile
	if edit_mode and p != null:
		_village = p.village_id
		_clan = p.clan_id
		_with_clan = p.clan_id != &""
		_name = p.character_name
		var start: Dictionary = p.appearance.duplicate(true)
		start["seed"] = absi(hash(p.character_id + p.character_name))
		_avatar = SSAvatars.complete(start) if SSAvatars.available() else start
		_step = Step.LOOK
	else:
		_name = GameSession.player_name if GameSession.player_name != "Player" else ""
		_avatar = SSAvatars.complete({"seed": randi()}) if SSAvatars.available() else {}
		var clans: Array = _db.clans_of_village(_village)
		_clan = clans[0].id if not clans.is_empty() else &""
		_avatar = _styled(_avatar)
	_build()
	_refresh()


# --- Layout -------------------------------------------------------------------------

func _build() -> void:
	var solid := ColorRect.new()
	solid.color = Color(0.03, 0.03, 0.05)
	solid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(solid)
	_bg = MenuBackdrop.new()
	add_child(_bg)
	_watermark = UiStyle.label(self, "", 520, Color(1, 1, 1, 0.05), 900)
	_watermark.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_watermark.offset_left = -500
	_watermark.offset_right = 200
	_watermark.offset_top = -380
	_watermark.offset_bottom = 300
	_watermark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_watermark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)
	var main := HBoxContainer.new()
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 22)
	root.add_child(main)
	# Left: title + steps.
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(250, 0)
	left.add_theme_constant_override("separation", 10)
	main.add_child(left)
	UiStyle.label(left, "NINJA BATTLE", 18, UiStyle.ACCENT, 900)
	UiStyle.label(left, "MODIFIER L'APPARENCE" if edit_mode else "CRÉATION DU SHINOBI", 26, Color.WHITE, 900)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	left.add_child(spacer)
	_steps_box = VBoxContainer.new()
	_steps_box.add_theme_constant_override("separation", 8)
	left.add_child(_steps_box)
	# Centre: 3D preview.
	var centre := VBoxContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.add_theme_constant_override("separation", 6)
	main.add_child(centre)
	var stage := Control.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.mouse_filter = Control.MOUSE_FILTER_STOP
	centre.add_child(stage)
	_portrait = ShinobiPortrait.create(_preview_data(), ShinobiPortrait.Framing.FULL_BODY, Vector2i(720, 900))
	_portrait.set_zoom(1.25)
	_portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait.flourishes = false
	stage.add_child(_portrait)
	stage.gui_input.connect(_on_stage_input)
	var hint := UiStyle.label(stage, "Glisser pour tourner", 12, Color(1, 1, 1, 0.45), 700)
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_top = -24
	hint.offset_left = -120
	hint.offset_right = 120
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner = UiStyle.label(centre, "", 24, Color.WHITE, 900)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_constant_override("outline_size", 8)
	_traits = UiStyle.label(centre, "", 14, UiStyle.MUTED, 700)
	_traits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_traits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Right: step panel.
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	panel.add_theme_stylebox_override("panel", UiStyle.panel(Color(0.05, 0.04, 0.08, 0.88), 16, Color(1, 1, 1, 0.1), 20))
	main.add_child(panel)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 12)
	_scroll.add_child(_content)
	# Bottom bar.
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	root.add_child(bar)
	_button(bar, "✕  Annuler" if edit_mode else "◀  Menu", func() -> void: _close(false), Vector2(150, 50))
	_error = UiStyle.label(bar, "", 15, Color(1.0, 0.45, 0.4), 800)
	_error.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_prev = _button(bar, "Précédent", func() -> void: _go(_step - 1), Vector2(170, 50))
	_next = _button(bar, "Suivant  ▶", _on_next, Vector2(240, 50))
	_next.add_theme_font_override("font", UiStyle.font(900))


func _refresh() -> void:
	var accent: Color = _accent()
	_bg.show_place(_village, ClanStyles.spot(_clan_or_none()) if _step >= Step.CLAN or edit_mode else &"plaza", accent)
	_watermark.text = _crest()
	_watermark.add_theme_color_override("font_color", Color(accent, 0.1))
	var v: VillageData = _db.get_village(_village) if _db.has_method("get_village") else null
	var clan: ClanData = _db.get_clan(_clan) if _with_clan else null
	_banner.text = "%s  ·  %s" % [v.display_name if v != null else String(_village).capitalize(),
		("Clan " + clan.display_name) if clan != null else "Sans clan"]
	_banner.add_theme_color_override("font_color", accent.lightened(0.2))
	_traits.text = ClanStyles.style(_clan if _with_clan else &"").traits
	_rebuild_steps()
	_rebuild_content()
	_portrait.set_character(_preview_data())
	_prev.visible = not edit_mode and _step > Step.VILLAGE
	var last: bool = edit_mode or _step == Step.IDENTITY
	_next.text = ("ENREGISTRER" if edit_mode else "CRÉER LE PERSONNAGE") if last else "Suivant  ▶"
	_next.add_theme_color_override("font_color", UiStyle.ACCENT if last else UiStyle.TEXT)
	_error.text = ""


func _rebuild_steps() -> void:
	_clear(_steps_box)
	if edit_mode:
		_step_button(Step.LOOK, 1, true)
		return
	var n: int = 1
	for s in Step.values():
		if s == Step.CLAN and not _with_clan:
			continue
		_step_button(s, n, s <= _step)
		n += 1


func _step_button(s: int, number: int, reachable: bool) -> void:
	var current: bool = s == _step
	var b := Button.new()
	b.text = "  %d   %s" % [number, STEP_NAMES[s]]
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 48)
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = not reachable
	var border: Color = _accent() if current else Color(1, 1, 1, 0.08)
	b.add_theme_stylebox_override("normal", UiStyle.panel(Color(_accent(), 0.22) if current else Color(0.06, 0.05, 0.09, 0.8), 10, border, 10))
	b.add_theme_stylebox_override("hover", UiStyle.panel(Color(_accent(), 0.3), 10, border, 10))
	b.add_theme_stylebox_override("disabled", UiStyle.panel(Color(0.04, 0.04, 0.06, 0.6), 10, Color(1, 1, 1, 0.04), 10))
	b.add_theme_font_size_override("font_size", 17)
	b.pressed.connect(func() -> void: _go(s))
	_steps_box.add_child(b)


func _rebuild_content() -> void:
	_clear(_content)
	match _step:
		Step.VILLAGE:
			_village_step()
		Step.ORIGIN:
			_origin_step()
		Step.CLAN:
			_clan_step()
		Step.LOOK:
			_look_step()
		Step.IDENTITY:
			_identity_step()
	_scroll.scroll_vertical = 0


# --- Steps --------------------------------------------------------------------------

func _village_step() -> void:
	_title("Choisis ton village", "Ton village d'origine est définitif : il fixe tes clans possibles et ton bandeau.")
	for v: VillageData in _db.villages:
		var vs: Dictionary = ClanStyles.village(v.id)
		var clans: PackedStringArray = []
		for c: ClanData in _db.clans_of_village(v.id):
			clans.append(c.display_name)
		_card(vs.crest, v.display_name, vs.motto, "Clans : " + ", ".join(clans), vs.color, v.id == _village, func() -> void:
			if _village != v.id:
				_village = v.id
				var list: Array = _db.clans_of_village(_village)
				_clan = list[0].id if not list.is_empty() else &""
				_avatar = _styled(_avatar)
			_refresh())


func _origin_step() -> void:
	_title("Ton origine", "Définitive elle aussi : elle décide de ton arbre de techniques héréditaires.")
	_card("族", "Né dans un clan", "Arbre de clan garanti : 5 techniques de clan (D → S) et une mécanique signature.",
		"Apparence marquée par le clan : couleurs, traits et tenues réservées.", _accent_for(_clan), _with_clan, func() -> void:
			_with_clan = true
			if _clan == &"":
				var list: Array = _db.clans_of_village(_village)
				_clan = list[0].id if not list.is_empty() else &""
			_avatar = _styled(_avatar)
			_refresh())
	_card("忍", "Sans clan", "Pas d'arbre de clan, mais des techniques cachées (Sub-jutsu) tirées au sort dès Chunin.",
		"Apparence entièrement libre (hors tenues réservées aux clans).", ClanStyles.NO_CLAN.color, not _with_clan, func() -> void:
			_with_clan = false
			_avatar = _styled(_avatar)
			_refresh())


func _clan_step() -> void:
	var v: VillageData = _db.get_village(_village) if _db.has_method("get_village") else null
	_title("Clans de %s" % (v.display_name if v != null else String(_village).capitalize()), "Ton clan donne ta mécanique signature et ton identité visuelle.")
	for c: ClanData in _db.clans_of_village(_village):
		var s: Dictionary = ClanStyles.style(c.id)
		var detail: String = ("Signature — " + c.signature) if c.signature != "" else c.description
		_card(s.crest, c.display_name, detail, "Traits : " + s.traits, s.color, c.id == _clan, func() -> void:
			_clan = c.id
			_avatar = _styled(_avatar)
			_refresh())


func _identity_step() -> void:
	_title("Identité", "Le nom de ton shinobi.")
	var edit := LineEdit.new()
	edit.placeholder_text = "Nom du personnage"
	edit.text = _name
	edit.max_length = 20
	edit.custom_minimum_size = Vector2(0, 50)
	edit.add_theme_font_size_override("font_size", 20)
	edit.text_changed.connect(func(t: String) -> void: _name = t)
	_content.add_child(edit)
	edit.call_deferred("grab_focus")
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel(Color(_accent(), 0.12), 12, Color(_accent(), 0.5), 16))
	_content.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	var v: VillageData = _db.get_village(_village) if _db.has_method("get_village") else null
	UiStyle.label(col, "RÉCAPITULATIF", 14, UiStyle.ACCENT, 900)
	UiStyle.label(col, "Village : " + (v.display_name if v != null else String(_village).capitalize()), 16, Color.WHITE, 800)
	var clan: ClanData = _db.get_clan(_clan) if _with_clan else null
	UiStyle.label(col, "Origine : " + (("Clan " + clan.display_name) if clan != null else "Sans clan"), 16, Color.WHITE, 800)
	if clan != null:
		for j: JutsuData in clan.jutsu:
			UiStyle.label(col, "   %s  ·  %s" % [ProgressionTypes.rank_key(j.rank), j.display_name], 14, UiStyle.MUTED, 700)
	var note := UiStyle.label(col, "Village et origine ne pourront plus changer. L'apparence reste modifiable dans le menu SHINOBI.", 13, UiStyle.MUTED, 600)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


# --- Appearance ---------------------------------------------------------------------

func _look_step() -> void:
	_title("Apparence", "Pièces et couleurs Shinobi Striker. Le clan impose ses traits et réserve ses tenues.")
	if not SSAvatars.available():
		UiStyle.label(_content, "Assets du créateur Shinobi Striker introuvables : apparence par défaut.", 14, Color(1.0, 0.7, 0.4), 700)
		return
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	_content.add_child(tabs)
	for i in LOOK_TABS.size():
		var b := _button(tabs, LOOK_TABS[i], func() -> void:
			_look_tab = i
			_rebuild_content(), Vector2(0, 40))
		b.toggle_mode = true
		b.button_pressed = i == _look_tab
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	match _look_tab:
		0:
			_section("Sexe")
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			_content.add_child(row)
			for sex: Array in [["Male", "Homme"], ["Female", "Femme"]]:
				var b := _button(row, sex[1], func() -> void:
					_avatar = _styled(SSAvatars.complete({"seed": randi(), "sex": sex[0], "skin": _avatar.get("skin", "")}))
					_look_changed(), Vector2(160, 44))
				b.toggle_mode = true
				b.button_pressed = _avatar.get("sex", "") == sex[0]
			_section("Peau" + ("  (traits du clan)" if _restricted("Skin") else ""))
			_swatches(ClanStyles.allowed_ids(_clan_or_none(), "Skin"), _avatar.get("skin", ""), func(id: String) -> void: _avatar.skin = id)
		1:
			_part_picker("Coiffure", "hair")
			_section("Couleur" + ("  (traits du clan)" if _restricted("Hair") else ""))
			var hair: Array[String] = ClanStyles.allowed_ids(_clan_or_none(), "Hair")
			_swatches(hair, _colour("hair", 0), func(id: String) -> void: _avatar.hair_colors = [id, id])
		2:
			_part_picker("Haut", "upper")
			_part_picker("Bas", "lower")
			var cloth: Array[String] = SSAvatars.colour_ids("Cloth")
			var pages: int = maxi(1, ceili(cloth.size() / 24.0))
			_cloth_page = clampi(_cloth_page, 0, pages - 1)
			var page: Array[String] = cloth.slice(_cloth_page * 24, (_cloth_page + 1) * 24)
			var nav := HBoxContainer.new()
			nav.add_theme_constant_override("separation", 8)
			_content.add_child(nav)
			_button(nav, "Couleurs du clan", func() -> void:
				_avatar = ClanStyles.apply(_avatar, _clan_or_none())
				_look_changed(), Vector2(0, 38))
			var spacer := Control.new()
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			nav.add_child(spacer)
			_button(nav, "◀", func() -> void:
				_cloth_page = posmod(_cloth_page - 1, pages)
				_rebuild_content(), Vector2(40, 38))
			UiStyle.label(nav, "Nuancier %d / %d" % [_cloth_page + 1, pages], 13, UiStyle.MUTED, 700)
			_button(nav, "▶", func() -> void:
				_cloth_page = posmod(_cloth_page + 1, pages)
				_rebuild_content(), Vector2(40, 38))
			for slot: Array in [["upper", "Haut"], ["lower", "Bas"]]:
				for k in 2:
					_section("%s — couleur %d" % [slot[1], k + 1])
					_swatches(page, _colour(slot[0], k), func(id: String) -> void: _set_colour(slot[0], k, id))
		3:
			var fronts: Array = [""]
			for o: Dictionary in SSAvatars.forehead_options():
				fronts.append(o.material)
			_choice_picker("Bandeau", "forehead", fronts, "Celui de la coiffure")
			var accs: Array = [""]
			for o: Dictionary in SSAvatars.accessory_options():
				accs.append(o.mesh)
			_choice_picker("Accessoire", "accessory", accs, "Aucun")
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	_content.add_child(actions)
	_button(actions, "🎲  Aléatoire (style du clan)", func() -> void:
		_avatar = _styled(SSAvatars.complete({"seed": randi(), "sex": _avatar.get("sex", "")}))
		_look_changed(), Vector2(0, 44))


func _part_picker(title: String, slot: String) -> void:
	var opts: Array[Dictionary] = _allowed_parts(slot)
	if opts.is_empty():
		return
	var current: int = 0
	for i in opts.size():
		if opts[i].mesh == _avatar.get(slot, ""):
			current = i
	_section(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_content.add_child(row)
	var step := func(delta: int) -> void:
		var pick: Dictionary = opts[posmod(current + delta, opts.size())]
		_avatar[slot] = pick.mesh
		if slot != "hair":
			_avatar[slot + "_colors"] = _avatar.get(slot + "_colors", [pick.color0, pick.color1])
		_look_changed()
	_button(row, "◀", step.bind(-1), Vector2(48, 44))
	var owner: Dictionary = ClanStyles.outfit_owner(opts[current].mesh) if slot != "hair" else {}
	var tag: String = ""
	if not owner.is_empty():
		var who: String = (_db.get_clan(owner.id).display_name if owner.kind == "clan" and _db.get_clan(owner.id) != null else String(owner.id).capitalize())
		tag = "   ★ " + ("clan " if owner.kind == "clan" else "") + who
	var name_label := UiStyle.label(row, "%s   (%d / %d)%s" % [_pretty(opts[current].mesh), current + 1, opts.size(), tag], 15, Color.WHITE if tag == "" else _accent().lightened(0.3), 800)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button(row, "▶", step.bind(1), Vector2(48, 44))


func _choice_picker(title: String, key: String, values: Array, empty_label: String) -> void:
	if values.size() <= 1:
		return
	var current: int = maxi(0, values.find(_avatar.get(key, "")))
	_section(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_content.add_child(row)
	var step := func(delta: int) -> void:
		var v: String = values[posmod(current + delta, values.size())]
		if v == "":
			_avatar.erase(key)
		else:
			_avatar[key] = v
		_look_changed()
	_button(row, "◀", step.bind(-1), Vector2(48, 44))
	var text: String = empty_label if values[current] == "" else _pretty(values[current])
	var label := UiStyle.label(row, "%s   (%d / %d)" % [text, current + 1, values.size()], 15, Color.WHITE, 800)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button(row, "▶", step.bind(1), Vector2(48, 44))


func _swatches(ids: Array[String], selected: String, on_pick: Callable) -> void:
	var grid := GridContainer.new()
	grid.columns = 12
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	_content.add_child(grid)
	for id: String in ids:
		var b := Button.new()
		b.custom_minimum_size = SWATCH
		b.focus_mode = Control.FOCUS_NONE
		var c: Color = SSAvatars.colour(id)
		var picked: bool = id == selected
		b.add_theme_stylebox_override("normal", UiStyle.panel(c, 6, Color.WHITE if picked else Color(0, 0, 0, 0.5), 0))
		b.add_theme_stylebox_override("hover", UiStyle.panel(c.lightened(0.15), 6, Color(1, 1, 1, 0.8), 0))
		b.pressed.connect(func() -> void:
			on_pick.call(id)
			_look_changed())
		grid.add_child(b)


# --- Avatar rules -------------------------------------------------------------------

func _clan_or_none() -> StringName:
	return _clan if _with_clan else &""


func _restricted(family: String) -> bool:
	return not ClanStyles.style(_clan_or_none()).get(family.to_lower(), []).is_empty()


## Parts of a slot this character may wear (outfits reserved to other clans /
## villages are hidden).
func _allowed_parts(slot: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for o: Dictionary in SSAvatars.options(slot, _avatar.get("sex", "Male")):
		if slot == "hair" or ClanStyles.outfit_allowed(o.mesh, _village, _clan_or_none()):
			out.append(o)
	return out


## Applies the clan look and swaps out any outfit this character can't wear.
func _styled(avatar: Dictionary) -> Dictionary:
	if avatar.is_empty() or not SSAvatars.available():
		return avatar
	var out: Dictionary = ClanStyles.apply(avatar, _clan_or_none())
	for slot: String in ["upper", "lower"]:
		if ClanStyles.outfit_allowed(str(out.get(slot, "")), _village, _clan_or_none()):
			continue
		var opts: Array[Dictionary] = _allowed_parts(slot)
		if not opts.is_empty():
			out[slot] = opts[absi(hash(str(out.get("seed", 0)) + slot)) % opts.size()].mesh
	return out


func _colour(slot: String, k: int) -> String:
	var ids: Array = _avatar.get(slot + "_colors", ["", ""])
	return str(ids[k]) if ids.size() > k else ""


func _set_colour(slot: String, k: int, id: String) -> void:
	var ids: Array = _avatar.get(slot + "_colors", ["", ""]).duplicate()
	while ids.size() < 2:
		ids.append("")
	ids[k] = id
	_avatar[slot + "_colors"] = ids


func _look_changed() -> void:
	_portrait.set_character(_preview_data())
	_rebuild_content()


func _preview_data() -> CharacterData:
	var data := CharacterData.new()
	var profile := CharacterProfile.new()
	profile.character_name = _name
	profile.village_id = _village
	profile.clan_id = _clan_or_none()
	data.look = ShinobiKit.look_for(profile)
	data.look.ss_avatar = _avatar.duplicate(true)
	return data


# --- Flow ---------------------------------------------------------------------------

func _go(s: int) -> void:
	if edit_mode:
		return
	if s == Step.CLAN and not _with_clan:
		s = Step.ORIGIN if _step > Step.CLAN else Step.LOOK
	_step = clampi(s, Step.VILLAGE, Step.IDENTITY)
	_refresh()


func _on_next() -> void:
	if edit_mode:
		_save_appearance()
		return
	if _step == Step.IDENTITY:
		_create()
		return
	if _step == Step.CLAN and _clan == &"":
		_error.text = "Choisis un clan."
		return
	_go(_step + 1)


func _create() -> void:
	_name = _name.strip_edges()
	if _name.length() < 2:
		_error.text = "Donne un nom à ton shinobi (2 caractères minimum)."
		return
	var origin: ProgressionTypes.Origin = ProgressionTypes.Origin.CLAN if _with_clan else ProgressionTypes.Origin.CLANLESS
	_next.disabled = true
	Profiles.profile_updated.connect(_on_created, CONNECT_ONE_SHOT)
	Profiles.create(_name, _village, origin, _clan_or_none())


func _on_created(profile: CharacterProfile, result: ProgressionResult) -> void:
	_next.disabled = false
	if profile == null or not result.ok:
		_error.text = "Création impossible : %s" % String(result.error)
		return
	_save_appearance()


func _save_appearance() -> void:
	if not _avatar.is_empty():
		var out: Dictionary = _avatar.duplicate(true)
		out.erase("seed")
		Profiles.request({"action": "set_appearance", "appearance": out})
	_close(true)


func _close(done: bool) -> void:
	finished.emit(done)
	queue_free()


func _on_stage_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		_dragging = mb.pressed
		_portrait.auto_sway = not mb.pressed and _portrait.auto_sway
	var motion := event as InputEventMouseMotion
	if motion != null and _dragging:
		_portrait.auto_sway = false
		_portrait.yaw += motion.relative.x * 0.5


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if not edit_mode and _step > Step.VILLAGE:
			_go(_step - 1)
		else:
			_close(false)


# --- Widgets ------------------------------------------------------------------------

func _accent() -> Color:
	if _step <= Step.ORIGIN and not edit_mode:
		return ClanStyles.village(_village).color
	return _accent_for(_clan_or_none())


func _accent_for(clan_id: StringName) -> Color:
	return ClanStyles.style(clan_id).color


func _crest() -> String:
	if _step <= Step.ORIGIN and not edit_mode:
		return ClanStyles.village(_village).crest
	return ClanStyles.style(_clan_or_none()).crest


func _title(text: String, sub: String) -> void:
	UiStyle.label(_content, text.to_upper(), 24, Color.WHITE, 900)
	var s := UiStyle.label(_content, sub, 14, UiStyle.MUTED, 600)
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _section(text: String) -> void:
	UiStyle.label(_content, text.to_upper(), 13, _accent().lightened(0.25), 900)


func _card(crest: String, title: String, body: String, foot: String, color: Color, selected: bool, on_pick: Callable) -> void:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 116)
	var border: Color = color if selected else Color(1, 1, 1, 0.08)
	b.add_theme_stylebox_override("normal", UiStyle.panel(Color(color, 0.18) if selected else Color(0.07, 0.06, 0.1, 0.9), 12, border, 0))
	b.add_theme_stylebox_override("hover", UiStyle.panel(Color(color, 0.26), 12, color, 0))
	b.add_theme_stylebox_override("pressed", UiStyle.panel(Color(color, 0.3), 12, color, 0))
	b.pressed.connect(on_pick)
	_content.add_child(b)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14
	row.offset_right = -14
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var crest_label := UiStyle.label(row, crest, 54, color, 900)
	crest_label.custom_minimum_size = Vector2(70, 0)
	crest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crest_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	UiStyle.label(col, title.to_upper() + ("   ✔" if selected else ""), 19, Color.WHITE, 900)
	for text: String in [body, foot]:
		if text == "":
			continue
		var l := UiStyle.label(col, text, 13, UiStyle.MUTED if text == foot else Color(0.88, 0.86, 0.82), 650)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.max_lines_visible = 3
	# Grow the card to its text.
	b.custom_minimum_size.y = maxf(116.0, col.get_combined_minimum_size().y + 28.0)


func _button(parent: Control, text: String, callback: Callable, min_size: Vector2 = Vector2.ZERO) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	b.pressed.connect(callback)
	parent.add_child(b)
	return b


static func _pretty(mesh: String) -> String:
	return mesh.trim_prefix("SK_CHR_").trim_prefix("SM_").trim_prefix("MI_").replace("_", " ").replace("Man ", "").replace("Woman ", "")


## Callbacks of widgets being cleared run inside their own signals: hide now
## (out of the layout), free at the end of the frame.
static func _clear(node: Node) -> void:
	for child: Node in node.get_children():
		if child is CanvasItem:
			(child as CanvasItem).hide()
		child.queue_free()
