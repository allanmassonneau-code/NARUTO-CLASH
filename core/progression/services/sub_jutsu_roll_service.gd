class_name SubJutsuRollService
extends RefCounted
## Weighted sub-jutsu draws. Every roll goes through here (never a bare
## random in game logic): eligibility (rank, village, exclusions, already
## owned, requirements), weights, and a seedable RNG for tests / replays.

var db: ProgressionDatabase
var rng := RandomNumberGenerator.new()


func _init(database: ProgressionDatabase, seed_value: int = -1) -> void:
	db = database
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()


## Next rank in the B -> A -> S ladder, or -1 when there is none (S).
static func higher_rank(rank: int) -> int:
	return rank + 1 if ProgressionTypes.is_valid_rank(rank + 1) else -1


func is_eligible(profile: CharacterProfile, sub: SubJutsuData, ranks: Array[int]) -> bool:
	if not sub.rollable or not ranks.has(sub.rank) or profile.owned_sub_jutsu.has(sub.id):
		return false
	if not sub.allowed_villages.is_empty() and not sub.allowed_villages.has(profile.village_id):
		return false
	for owned: StringName in profile.owned_sub_jutsu:
		if sub.exclusions.has(owned):
			return false
		var other: SubJutsuData = db.get_sub_jutsu(owned)
		if other != null and other.exclusions.has(sub.id):
			return false
	for req: StringName in sub.requirements:
		if not profile.knows(req):
			return false
	return true


func pool(profile: CharacterProfile, ranks: Array[int]) -> Array[SubJutsuData]:
	var out: Array[SubJutsuData] = []
	for sub: SubJutsuData in db.sub_jutsu:
		if is_eligible(profile, sub, ranks):
			out.append(sub)
	return out


## Weighted draw among eligible sub-jutsu of `ranks`. Null if the pool is empty.
func roll(profile: CharacterProfile, ranks: Array[int]) -> SubJutsuData:
	var candidates: Array[SubJutsuData] = pool(profile, ranks)
	var total: float = 0.0
	for sub: SubJutsuData in candidates:
		total += maxf(sub.weight, 0.0)
	if total <= 0.0:
		return null
	var pick: float = rng.randf() * total
	for sub: SubJutsuData in candidates:
		pick -= maxf(sub.weight, 0.0)
		if pick <= 0.0:
			return sub
	return candidates.back()
