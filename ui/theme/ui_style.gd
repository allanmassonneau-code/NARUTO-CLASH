class_name UiStyle
## Shared look for every UI screen: palette, fonts, panel styles, theme.
## Palette follows the Shinobi Striker menus (T_ui_Menu_ColWindow / T_ui_Menu_Btn_*_Sel):
## charcoal windows with a light bevel, deep red selected buttons framed in gold.

const BG := Color(0.11, 0.11, 0.12, 0.88)
const BG_SOLID := Color(0.13, 0.13, 0.14)
const BORDER := Color(0.62, 0.62, 0.64, 0.35)
const SS_RED := Color(0.58, 0.16, 0.1)
const SS_GOLD := Color(0.95, 0.72, 0.05)
const SS_BLUE := Color(0.1, 0.36, 0.72)
const TEXT := Color(0.95, 0.93, 0.9)
const MUTED := Color(0.62, 0.6, 0.68)
const ACCENT := Color(1.0, 0.62, 0.12)
const CHAKRA := Color(0.3, 0.62, 1.0)
const TEAM_COLORS: Array[Color] = [Color(0.3, 0.62, 1.0), Color(1.0, 0.3, 0.25)]

static var _theme: Theme


const BODY_FONT: String = "res://assets/fonts/Inter.ttf"
const DISPLAY_FONTS: Dictionary = {500: "res://assets/fonts/Rajdhani-Medium.ttf",
	600: "res://assets/fonts/Rajdhani-SemiBold.ttf", 700: "res://assets/fonts/Rajdhani-Bold.ttf"}
static var _fonts: Dictionary = {}


## Text font: Inter (variable weight); weights >= 800 use the Rajdhani display
## face (titles, numbers). Both fall back to system fonts for kanji crests.
static func font(weight: int = 600) -> Font:
	if weight >= 800:
		return display(700)
	var key: String = "body%d" % weight
	if not _fonts.has(key):
		var base: Font = load(BODY_FONT) if ResourceLoader.exists(BODY_FONT) else null
		if base == null:
			_fonts[key] = _system(weight)
		else:
			var v := FontVariation.new()
			v.base_font = base
			v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
			v.fallbacks = [_system(weight)]
			_fonts[key] = v
	return _fonts[key]


## Display font (Rajdhani): buttons, titles, HUD numbers.
static func display(weight: int = 600) -> Font:
	var key: String = "display%d" % weight
	if not _fonts.has(key):
		var path: String = DISPLAY_FONTS.get(clampi(weight / 100 * 100, 500, 700), DISPLAY_FONTS[600])
		var base: Font = load(path) if ResourceLoader.exists(path) else null
		if base == null:
			_fonts[key] = _system(weight)
		else:
			var v := FontVariation.new()
			v.base_font = base
			v.fallbacks = [_system(weight)]
			_fonts[key] = v
	return _fonts[key]


static func _system(weight: int) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Segoe UI", "Noto Sans CJK JP", "Yu Gothic", "Meiryo", "MS Gothic", "Noto Sans", "Arial", "sans-serif"])
	f.font_weight = weight
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return f


static func panel(color: Color = BG, radius: int = 10, border: Color = BORDER, pad: float = 10.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_border_width_all(1)
	s.border_color = border
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.7
	s.content_margin_bottom = pad * 0.7
	s.anti_aliasing = true
	return s


## SS selected-button frame: thicker gold border.
static func _ss_selected(s: StyleBoxFlat) -> StyleBoxFlat:
	s.set_border_width_all(2)
	return s


static func bar_fill(color: Color, radius: int = 4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	return s


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font(600)
	t.default_font_size = 16
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.8))
	t.set_constant("outline_size", "Label", 3)
	t.set_stylebox("panel", "PanelContainer", panel(Color(0.06, 0.06, 0.09, 0.82), 12, Color(1, 1, 1, 0.08), 12))
	t.set_stylebox("panel", "Panel", panel(Color(0.06, 0.06, 0.09, 0.82), 12, Color(1, 1, 1, 0.08), 12))
	# Buttons: dark glass, thin border; accent outline on hover, accent fill when pressed / selected.
	t.set_font("font", "Button", display(600))
	t.set_font_size("font_size", "Button", 18)
	t.set_stylebox("normal", "Button", panel(Color(0.07, 0.07, 0.1, 0.82), 8, Color(1, 1, 1, 0.1), 16))
	t.set_stylebox("hover", "Button", panel(Color(ACCENT, 0.16), 8, ACCENT, 16))
	t.set_stylebox("pressed", "Button", panel(Color(ACCENT, 0.92), 8, ACCENT.lightened(0.3), 16))
	t.set_stylebox("hover_pressed", "Button", panel(Color(ACCENT.lightened(0.08), 0.95), 8, ACCENT.lightened(0.4), 16))
	t.set_stylebox("disabled", "Button", panel(Color(0.05, 0.05, 0.07, 0.5), 8, Color(1, 1, 1, 0.05), 16))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", Color(0.08, 0.05, 0.02))
	t.set_color("font_hover_pressed_color", "Button", Color(0.08, 0.05, 0.02))
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(TEXT, 0.35))
	# Line edits
	t.set_stylebox("normal", "LineEdit", panel(Color(0.05, 0.05, 0.08, 0.95), 8, BORDER, 10))
	t.set_stylebox("focus", "LineEdit", panel(Color(0.05, 0.05, 0.08, 0.95), 8, ACCENT, 10))
	t.set_color("font_color", "LineEdit", TEXT)
	# Progress bars
	t.set_stylebox("background", "ProgressBar", bar_fill(Color(0, 0, 0, 0.55)))
	t.set_stylebox("fill", "ProgressBar", bar_fill(ACCENT))
	_theme = t
	return t


static func label(parent: Node, text: String, size: int, color: Color = TEXT, weight: int = 600) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if weight != 600:
		l.add_theme_font_override("font", font(weight))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


static func bar(parent: Node, color: Color, height: float, radius: int = 4) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, height)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_theme_stylebox_override("fill", bar_fill(color, radius))
	b.add_theme_stylebox_override("background", bar_fill(Color(0, 0, 0, 0.55), radius))
	parent.add_child(b)
	return b
