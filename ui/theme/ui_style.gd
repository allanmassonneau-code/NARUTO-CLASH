class_name UiStyle
## Shared look for every UI screen: palette, fonts, panel styles, theme.

const BG := Color(0.07, 0.06, 0.1, 0.82)
const BG_SOLID := Color(0.09, 0.08, 0.13)
const BORDER := Color(1, 1, 1, 0.09)
const TEXT := Color(0.95, 0.93, 0.9)
const MUTED := Color(0.62, 0.6, 0.68)
const ACCENT := Color(1.0, 0.55, 0.12)
const CHAKRA := Color(0.3, 0.62, 1.0)
const TEAM_COLORS: Array[Color] = [Color(0.3, 0.62, 1.0), Color(1.0, 0.3, 0.25)]

static var _theme: Theme


static func font(weight: int = 600) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Segoe UI", "Inter", "Noto Sans", "Arial", "sans-serif"])
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
	t.set_stylebox("panel", "PanelContainer", panel())
	t.set_stylebox("panel", "Panel", panel())
	# Buttons
	t.set_stylebox("normal", "Button", panel(Color(0.14, 0.12, 0.2, 0.95), 10, BORDER, 14))
	t.set_stylebox("hover", "Button", panel(Color(0.2, 0.17, 0.28, 0.95), 10, Color(1, 1, 1, 0.2), 14))
	t.set_stylebox("pressed", "Button", panel(Color(ACCENT, 0.9), 10, ACCENT.lightened(0.3), 14))
	t.set_stylebox("hover_pressed", "Button", panel(Color(ACCENT.lightened(0.1), 0.95), 10, ACCENT.lightened(0.4), 14))
	t.set_stylebox("disabled", "Button", panel(Color(0.1, 0.1, 0.12, 0.6), 10, BORDER, 14))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", Color(0.1, 0.05, 0.02))
	t.set_color("font_hover_pressed_color", "Button", Color(0.1, 0.05, 0.02))
	t.set_color("font_hover_color", "Button", Color.WHITE)
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
