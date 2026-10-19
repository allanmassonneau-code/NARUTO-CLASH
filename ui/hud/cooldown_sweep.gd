class_name CooldownSweep
extends Control
## Clockwise radial shade over an ability icon (MOBA / Battlerite style).

## 1 = fully covered (just used), 0 = ready.
var ratio: float = 0.0:
	set(value):
		if not is_equal_approx(value, ratio):
			ratio = value
			queue_redraw()
var color := Color(0.02, 0.02, 0.05, 0.74)
var radius: float = 10.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _draw() -> void:
	if ratio <= 0.001:
		return
	var center: Vector2 = size / 2.0
	var reach: float = size.length()
	var points := PackedVector2Array([center])
	var start: float = -PI / 2.0 + TAU * (1.0 - ratio)
	var steps: int = maxi(3, int(48 * ratio))
	for i in steps + 1:
		var a: float = start + TAU * ratio * float(i) / steps
		points.append(center + Vector2(cos(a), sin(a)) * reach)
	draw_colored_polygon(points, color)
	# Bright edge on the sweep line.
	draw_line(center, center + Vector2(cos(start), sin(start)) * reach, Color(1, 1, 1, 0.35), 2.0, true)
