extends Node
## Probe: every SS sound loads; technique coverage (local check, not exported).

func _ready() -> void:
	var cat: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://_ss_local/sfx/catalog.json"))
	var bad := 0
	var n := 0
	for k: String in cat.events:
		for f: String in cat.events[k]:
			n += 1
			if load("res://_ss_local/sfx/" + f) == null: bad += 1
	for k: String in cat.tech:
		for slot: String in ["cast", "impact"]:
			for f: String in cat.tech[k][slot]:
				n += 1
				if load("res://_ss_local/sfx/" + f) == null: bad += 1
	for k: String in cat.music:
		n += 1
		var m: AudioStreamWAV = load("res://_ss_local/music/" + cat.music[k])
		if m == null: bad += 1
		else: print("MUSIC ", k, " ", snappedf(m.get_length(), 0.1), "s loop ", m.loop_mode)
	var db: ProgressionDatabase = load("res://data/progression/progression_db.tres")
	var list: Array = []
	for nat: ChakraNatureData in db.natures: list.append_array(nat.jutsu)
	for c: ClanData in db.clans: list.append_array(c.jutsu)
	for sj: SubJutsuData in db.sub_jutsu: list.append(sj)
	var cast := 0
	var impact := 0
	for j in list:
		if SSAudio.tech(j.id, "cast") != null: cast += 1
		if SSAudio.tech(j.id, "impact") != null: impact += 1
		else: print("NO IMPACT ", j.id)
	print("SOUNDS ", n, " bad ", bad, " | techs ", list.size(), " cast ", cast, " impact ", impact)
	get_tree().quit()