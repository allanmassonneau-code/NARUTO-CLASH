extends Control
## Probe: every technique's SS icon through SSIcons (local check, not exported).

func _ready() -> void:
	var grid := GridContainer.new()
	grid.columns = 20
	add_child(grid)
	var db: ProgressionDatabase = load("res://data/progression/progression_db.tres")
	var n := 0
	var missing := 0
	var list: Array = []
	for nat: ChakraNatureData in db.natures: list.append_array(nat.jutsu)
	for c: ClanData in db.clans: list.append_array(c.jutsu)
	for sj: SubJutsuData in db.sub_jutsu: list.append(sj)
	for j in list:
		n += 1
		if SSIcons.add_rect(grid, j.id, j.display_name, 38) == null:
			missing += 1
			print("NO ICON ", j.id)
	print("ICONS ", n, " missing ", missing)