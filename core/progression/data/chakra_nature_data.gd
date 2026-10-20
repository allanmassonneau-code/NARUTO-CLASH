class_name ChakraNatureData
extends Resource
## A chakra nature and its tree: 10 techniques, 2 per rank (D, C, B, A, S).

const TECHNIQUES_PER_RANK: int = 2

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
## Design bible: kit identity and signature mechanic.
@export_multiline var identity: String = ""
@export_multiline var signature: String = ""
@export var icon: Texture2D
@export var color: Color = Color.WHITE
@export var jutsu: Array[JutsuData] = []
@export var placeholder: bool = false


func jutsu_of_rank(rank: int) -> Array[JutsuData]:
	var out: Array[JutsuData] = []
	for j: JutsuData in jutsu:
		if j.rank == rank:
			out.append(j)
	return out
