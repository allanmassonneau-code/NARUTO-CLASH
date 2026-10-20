class_name CombatMenu
extends CanvasLayer
## In-combat technique menu (B), opened without pausing: browse the learned
## techniques by category (favorites, natures, clan, specialization,
## sub-jutsu) and place any of them on the 6-slot bar. Placing goes through
## the progression authority; cooldowns follow the technique (see
## AbilityController._stashed), so swapping never resets one.

const FAVORITES_PATH: String = "user://favorites.cfg"
const FAVORITES: int = -1
const CATEGORIES: Array = [
	["★ Favoris", FAVORITES],
	["Natures", ProgressionTypes.JutsuSource.NATURE],
	["Clan", ProgressionTypes.JutsuSource.CLAN],
	["Spécialité", ProgressionTypes.JutsuSource.SPECIALIZATION],
	["Sub-jutsu", ProgressionTypes.JutsuSource.SUB_JUTSU],
]
const BAR_KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6]
const ERRORS: Dictionary = {
	&"NOT_LEARNED": "technique pas encore apprise",
	&"PASSIVE_NOT_EQUIPPABLE": "les passifs ne s'équipent pas",
	&"NO_FREE_SLOT": "barre pleine",
	&"ALREADY_EQUIPPED": "déjà à cet emplacement",
}

var _player: CombatCharacter
var _root: PanelContainer
var _tabs: HBoxContainer
var _bar: HBoxContainer
var _list: VBoxContainer
var _status: Label
var _category: int = ProgressionTypes.JutsuSource.NATURE
var _target_slot: int = 0
var _hovered: StringName = &""
var _favorites: Array[StringName] = []
## Technique id -> cooldown Label of its row.
var _cooldown_labels: Dictionary = {}


func bind(player: CombatCharacter) -> void:
	_player = player
	layer = 5
	_load_favorites()
	if not _favorites.is_empty():
		_category = FAVORITES
	_build()
	_root.visible = false
	var input := player.controller as PlayerInputController
	if input != null:
		input.ui_blocker = self
	Profiles.profile_updated.connect(_on_profile_updated)


func is_open() -> bool:
	return _root != null and _root.visible


func toggle() -> void:
	_root.visible = not _root.visible
	_hovered = &""
	if _root.visible:
		_target_slot = _first_free_slot()
		refresh()


## PlayerInputController asks before turning a press into a cast: clicks on
## the panel and number keys over a technique belong to the menu.
func blocks_slot(slot: StringName) -> bool:
	if not is_open():
		return false
	if slot == &"lmb" or slot == &"rmb":
		return _root.get_global_rect().has_point(_root.get_global_mouse_position())
	return _hovered != &"" and ShinobiKit.JUTSU_SLOTS.has(slot)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("combat_menu"):
		toggle()
		get_viewport().set_input_as_handled()
	elif is_open() and event.is_action_pressed("ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	# Number key while hovering a technique: place it directly in that slot.
	if not is_open() or _hovered == &"":
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var slot: int = BAR_KEYS.find(key.physical_keycode)
	if slot >= 0:
		_place(_hovered, slot)
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not is_open():
		return
	for id: StringName in _cooldown_labels:
		var left: float = _player.abilities.technique_cooldown(id)
		(_cooldown_labels[id] as Label).text = ("%.1f s" % left) if left > 0.0 else ""


func refresh() -> void:
	if _root == null or not is_open() or Profiles.profile == null:
		return
	_build_tabs()
	_build_bar()
	_build_list()


# --- Actions ------------------------------------------------------------------------

func _place(id: StringName, slot: int) -> void:
	_status.text = ""
	Profiles.request({"action": "equip_jutsu_at", "jutsu": id, "slot": slot})


func _remove(slot: int) -> void:
	var bar: Array[StringName] = Profiles.profile.equipped_jutsu
	if slot < bar.size():
		Profiles.request({"action": "unequip_jutsu", "jutsu": bar[slot]})


func _toggle_favorite(id: StringName) -> void:
	if _favorites.has(id):
		_favorites.erase(id)
	else:
		_favorites.append(id)
	_save_favorites()
	refresh()


func _on_profile_updated(_profile: CharacterProfile, result: ProgressionResult) -> void:
	if not is_open():
		return
	if not result.ok:
		_status.text = "Impossible : %s" % ERRORS.get(result.error, String(result.error))
	refresh()


func _first_free_slot() -> int:
	var used: int = Profiles.profile.equipped_jutsu.size() if Profiles.profile != null else 0
	return used if used < ShinobiKit.JUTSU_SLOTS.size() else 0


# --- Build --------------------------------------------------------------------------

func _build() -> void:
	_root = PanelContainer.new()
	_root.theme = UiStyle.theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_root.offset_left = -490
	_root.offset_right = -16
	_root.offset_top = 16
	_root.offset_bottom = -150  # above the HUD bar
	_root.add_theme_stylebox_override("panel", UiStyle.panel(Color(0.05, 0.04, 0.08, 0.92), 14, Color(UiStyle.ACCENT, 0.45), 14))
	add_child(_root)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_root.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var title := UiStyle.label(head, "TECHNIQUES", 22, UiStyle.ACCENT, 900)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiStyle.label(head, "B : fermer", 13, UiStyle.MUTED, 700)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 4)
	col.add_child(_tabs)
	UiStyle.label(col, "BARRE — clic : emplacement cible  ·  clic droit : retirer", 12, UiStyle.MUTED, 700)
	_bar = HBoxContainer.new()
	_bar.add_theme_constant_override("separation", 6)
	col.add_child(_bar)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	_status = UiStyle.label(col, "", 13, Color(1.0, 0.5, 0.4), 800)
	var help := UiStyle.label(col, "Clic sur une technique : la placer dans l'emplacement cible.\nSurvol + touche 1 à 6 : la placer directement.  ★ : favori.\nLes temps de recharge sont conservés.", 12, UiStyle.MUTED, 600)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _build_tabs() -> void:
	_clear(_tabs)
	for entry: Array in CATEGORIES:
		var b := Button.new()
		b.text = entry[0]
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.button_pressed = entry[1] == _category
		b.add_theme_font_size_override("font_size", 13)
		var category: int = entry[1]
		b.pressed.connect(func() -> void:
			_category = category
			refresh())
		_tabs.add_child(b)


func _build_bar() -> void:
	_clear(_bar)
	var bar: Array[StringName] = Profiles.profile.equipped_jutsu
	for i in ShinobiKit.JUTSU_SLOTS.size():
		var id: StringName = bar[i] if i < bar.size() else &""
		var j: JutsuData = Profiles.db.get_jutsu(id) if id != &"" else null
		var cell := Button.new()
		cell.focus_mode = Control.FOCUS_NONE
		cell.custom_minimum_size = Vector2(66, 54)
		cell.clip_text = true
		cell.text = "%d\n%s" % [i + 1, _short(j.display_name) if j != null else "libre"]
		cell.add_theme_font_size_override("font_size", 11)
		var selected: bool = i == _target_slot
		var color: Color = UiStyle.ACCENT if selected else Color(1, 1, 1, 0.15)
		cell.add_theme_stylebox_override("normal", UiStyle.panel(Color(0.1, 0.08, 0.14, 0.95), 8, color, 4))
		cell.add_theme_stylebox_override("hover", UiStyle.panel(Color(0.16, 0.12, 0.2, 0.95), 8, color, 4))
		var slot: int = i
		# Deferred: the bar is rebuilt, freeing the cell handling this event.
		cell.gui_input.connect(func(event: InputEvent) -> void:
			var mb := event as InputEventMouseButton
			if mb == null or not mb.pressed:
				return
			if mb.button_index == MOUSE_BUTTON_LEFT:
				_target_slot = slot
				_build_bar.call_deferred()
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				_remove.call_deferred(slot))
		_bar.add_child(cell)


func _build_list() -> void:
	_clear(_list)
	_cooldown_labels.clear()
	var p: CharacterProfile = Profiles.profile
	var count: int = 0
	for id: StringName in p.learned_jutsu:
		var j: JutsuData = Profiles.db.get_jutsu(id)
		if j == null or j.passive:
			continue
		if _category == FAVORITES and not _favorites.has(id):
			continue
		if _category != FAVORITES and j.source != _category:
			continue
		_row(j, p.equipped_jutsu.find(id))
		count += 1
	if count == 0:
		var empty := UiStyle.label(_list, "Aucune technique ici." if _category != FAVORITES else "Aucun favori : clique sur ☆ pour en ajouter.", 14, UiStyle.MUTED, 700)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _row(j: JutsuData, slot: int) -> void:
	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var border: Color = Color(0.5, 1.0, 0.6, 0.6) if slot >= 0 else Color(1, 1, 1, 0.1)
	row.add_theme_stylebox_override("panel", UiStyle.panel(Color(0.1, 0.09, 0.14, 0.95), 8, border, 8))
	_list.add_child(row)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)
	var star := Button.new()
	star.text = "★" if _favorites.has(j.id) else "☆"
	star.flat = true
	star.focus_mode = Control.FOCUS_NONE
	star.add_theme_color_override("font_color", UiStyle.ACCENT)
	star.pressed.connect(func() -> void: _toggle_favorite.call_deferred(j.id))
	line.add_child(star)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(info)
	var name_label := UiStyle.label(info, "%s  [%s]" % [j.display_name, ProgressionTypes.rank_key(j.rank)], 15, Color.WHITE, 800)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var meta := UiStyle.label(info, "%d chakra  ·  %.0f s" % [roundi(j.chakra_cost), maxf(j.cooldown, 3.0)], 12, UiStyle.CHAKRA, 700)
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cd := UiStyle.label(line, "", 13, Color(1.0, 0.85, 0.5), 900)
	cd.custom_minimum_size = Vector2(52, 0)
	_cooldown_labels[j.id] = cd
	var badge := UiStyle.label(line, str(slot + 1) if slot >= 0 else "", 18, Color(0.5, 1.0, 0.6), 900)
	badge.custom_minimum_size = Vector2(18, 0)
	row.mouse_entered.connect(func() -> void: _hovered = j.id)
	row.mouse_exited.connect(func() -> void:
		if _hovered == j.id:
			_hovered = &"")
	row.gui_input.connect(func(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_place.call_deferred(j.id, _target_slot))


static func _short(text: String) -> String:
	return text if text.length() <= 11 else text.substr(0, 10) + "…"


static func _clear(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()


# --- Favorites (per character, local to this computer) ------------------------------

func _load_favorites() -> void:
	var cfg := ConfigFile.new()
	if Profiles.profile == null or cfg.load(FAVORITES_PATH) != OK:
		return
	for id: String in cfg.get_value(Profiles.profile.character_id, "ids", []):
		_favorites.append(StringName(id))


func _save_favorites() -> void:
	if Profiles.profile == null:
		return
	var cfg := ConfigFile.new()
	cfg.load(FAVORITES_PATH)
	var ids: PackedStringArray = []
	for id: StringName in _favorites:
		ids.append(String(id))
	cfg.set_value(Profiles.profile.character_id, "ids", ids)
	cfg.save(FAVORITES_PATH)
