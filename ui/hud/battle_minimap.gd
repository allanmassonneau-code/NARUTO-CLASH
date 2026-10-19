class_name BattleMinimap
extends Control
## 20v20 minimap: field outline, bases, fighters as team dots, you in white.

const SIZE := Vector2(260, 160)

var manager: MatchManager
var player: CombatCharacter


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.03, 0.06, 0.8))
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.25), false, 1.5)
	for team in 2:
		var base: Vector2 = _to_map(Vector3(-Battlefield.BASE_X if team == 0 else Battlefield.BASE_X, 0, 0))
		draw_circle(base, 12.0, Color(UiStyle.TEAM_COLORS[team], 0.25))
	if manager == null:
		return
	for fighter: CombatCharacter in manager.fighters:
		if fighter.is_dead() or fighter == player:
			continue
		draw_circle(_to_map(fighter.global_position), 3.0, UiStyle.TEAM_COLORS[fighter.team])
	if player != null and not player.is_dead():
		var p: Vector2 = _to_map(player.global_position)
		draw_circle(p, 5.0, Color.WHITE)
		var f: Vector3 = player.facing.facing_direction
		draw_line(p, p + Vector2(f.x, f.z) * 10.0, Color.WHITE, 2.0)


func _to_map(world: Vector3) -> Vector2:
	var h: Vector2 = Battlefield.HALF_SIZE
	return Vector2((world.x + h.x) / (h.x * 2.0) * size.x, (world.z + h.y) / (h.y * 2.0) * size.y)
