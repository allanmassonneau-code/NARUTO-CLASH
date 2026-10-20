extends Control
## Local probe (not committed): SHINOBI screen on the appearance tab.

func _ready() -> void:
	var s := ShinobiScreen.new()
	s.embedded = true
	s._tab = "look"
	add_child(s)