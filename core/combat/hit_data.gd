class_name HitData
extends RefCounted
## One hit travelling through the damage pipeline (CombatCharacter.receive_hit).

enum Result { HIT, IGNORED, COUNTERED }

var source: CombatCharacter
var ability: AbilityData
var damage: float = 0.0
var stun_duration: float = 0.0
var root_duration: float = 0.0
var knockback_velocity: Vector3 = Vector3.ZERO
var knockback_duration: float = 0.0
var energy_gain: float = 0.0
## Open world online: the hit was computed on another machine (attacker-side
## modifiers already applied) and forwarded to the target's owner.
var remote: bool = false
## Technique extras (Tk.hit opts) applied after a landed hit.
var opts: Dictionary = {}


static func from_ability(from: CombatCharacter, data: AbilityData, direction: Vector3) -> HitData:
	var hit := HitData.new()
	hit.source = from
	hit.ability = data
	hit.damage = data.damage
	hit.stun_duration = data.stun_duration
	hit.root_duration = data.root_duration
	hit.knockback_velocity = Vector3(direction.x, 0.0, direction.z).normalized() * data.knockback_speed
	hit.knockback_duration = data.knockback_duration
	hit.energy_gain = data.energy_gain_on_hit
	return hit
