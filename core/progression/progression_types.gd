class_name ProgressionTypes
## Shared enums of the shinobi progression system. Logic always works on
## these values (ordered, comparable), never on display strings.

## Grades in progression order (the int value is the order).
enum Grade { GENIN, CHUNIN, KONIN, TOKUBETSU, JONIN }
## Technique ranks, ordered D < C < B < A < S.
enum Rank { D, C, B, A, S }
enum Origin { CLAN, CLANLESS }
## Family a technique comes from (extensible: add values at the end).
enum JutsuSource { NATURE, CLAN, SPECIALIZATION, SUB_JUTSU, OTHER }
## State of a technique node in a skill tree UI.
enum NodeState { LOCKED_GRADE, AVAILABLE, SELECTED, LOCKED_BY_CHOICE, UNLOCKED }
## Sub-jutsu event granted by a grade to clanless characters.
enum SubJutsuEvent { NONE, FIRST_ROLL, EVOLUTION }
## Choices a grade asks the player to make.
enum Choice { PRIMARY_NATURE, SPECIALIZATION, SECONDARY_NATURE, SUB_JUTSU_EVOLUTION }

## Known technique tags (extensible; tags are StringNames on JutsuData).
const TAGS: Array[StringName] = [
	&"MELEE", &"RANGED", &"PROJECTILE", &"HITSCAN", &"AOE", &"MOVEMENT", &"DEFENSIVE", &"HEAL",
	&"BUFF", &"DEBUFF", &"CC", &"CHANNELING", &"COUNTER", &"DASH", &"DOT",
]


static func grade_key(grade: int) -> String:
	return Grade.keys()[grade]


static func rank_key(rank: int) -> String:
	return Rank.keys()[rank]


static func is_valid_grade(grade: int) -> bool:
	return grade >= 0 and grade < Grade.size()


static func is_valid_rank(rank: int) -> bool:
	return rank >= 0 and rank < Rank.size()
