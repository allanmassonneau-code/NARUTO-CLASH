class_name HealthBar
extends Control
## Fighting-game health bar drawn in code: damage trail (recent damage
## drains slowly), recoverable health, shield overlay, 25 HP ticks.

var fill_color := Color(0.35, 0.9, 0.45)
var corner: float = 4.0
var show_ticks: bool = true
var skew: float = 0.0

var _max: float = 100.0
var _current: float = 100.0
var _recoverable: float = 0.0
var _shield: float = 0.0
var _trail: float = 100.0
var _trail_delay: float = 0.0
var _flash: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_values(current: float, maximum: float, recoverable: float, shield: float) -> void:
	if current < _current - 0.01:
		_trail_delay = 0.45
		_flash = 0.15
	elif current > _trail:
		_trail = current
	_max = maxf(maximum, 1.0)
	_current = current
	_recoverable = recoverable
	_shield = shield


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	if _trail_delay > 0.0:
		_trail_delay -= delta
	elif _trail > _current:
		_trail = maxf(_current, _trail - _max * 0.6 * delta)
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	_rect(0.0, 1.0, Color(0.02, 0.02, 0.04, 0.85))
	var cur: float = clampf(_current / _max, 0.0, 1.0)
	var rec: float = clampf((_current + _recoverable) / _max, 0.0, 1.0)
	var trail: float = clampf(_trail / _max, 0.0, 1.0)
	_rect(0.0, rec, Color(1, 1, 1, 0.22))
	_rect(cur, trail, Color(1.0, 0.92, 0.75, 0.9))
	var top: Color = fill_color.lightened(0.25)
	var bottom: Color = fill_color.darkened(0.25)
	if _flash > 0.0:
		top = top.lerp(Color.WHITE, 0.6)
	_gradient_rect(0.0, cur, top, bottom)
	if _shield > 0.0:
		var sh: float = clampf(_shield / _max, 0.0, 1.0 - cur)
		_rect(cur, cur + sh, Color(0.7, 0.85, 1.0, 0.85))
	# Gloss.
	draw_rect(Rect2(2, 1, maxf(0.0, w * cur - 4), h * 0.28), Color(1, 1, 1, 0.16))
	if show_ticks:
		var step: float = 25.0 / _max * w
		var x: float = step
		while x < w - 1.0:
			draw_line(Vector2(x, h * 0.45), Vector2(x, h), Color(0, 0, 0, 0.55), 1.0)
			x += step
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.9), false, 1.5)


func _rect(from: float, to: float, color: Color) -> void:
	if to <= from:
		return
	draw_rect(Rect2(size.x * from, 0, size.x * (to - from), size.y), color)


func _gradient_rect(from: float, to: float, top: Color, bottom: Color) -> void:
	if to <= from:
		return
	var x0: float = size.x * from
	var x1: float = size.x * to
	var pts := PackedVector2Array([Vector2(x0, 0), Vector2(x1, 0), Vector2(x1, size.y), Vector2(x0, size.y)])
	draw_polygon(pts, PackedColorArray([top, top, bottom, bottom]))
