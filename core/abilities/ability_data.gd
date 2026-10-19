class_name AbilityData
extends Resource
## Data-driven definition of a jutsu: frame data, costs, hit properties.
## The `kind` selects a generic executor in AbilityEffects.

enum Kind { MELEE_ARC, PROJECTILE, DASH, GROUND_AREA, COUNTER, SELF_HEAL }

@export_category("Identity")
@export var display_name: String = "Jutsu"
@export var kind: Kind = Kind.MELEE_ARC
@export var color: Color = Color.WHITE

@export_category("Frame Data")
@export var startup_time: float = 0.1
## For DASH this is the dash duration; for COUNTER the counter window.
@export var active_time: float = 0.05
@export var recovery_time: float = 0.15
@export var cooldown: float = 0.0

@export_category("Movement During Cast")
@export_range(0.0, 1.0) var cast_move_multiplier: float = 0.5
@export_range(0.0, 1.0) var recovery_move_multiplier: float = 0.8

@export_category("Cancel / Interrupt")
@export var can_cancel_during_startup: bool = true
## Cooldown applied when cancelled (feint cost) or interrupted during startup.
@export var cancel_cooldown: float = 0.5

@export_category("Chakra Energy")
@export var energy_cost: float = 0.0
@export var energy_gain_on_hit: float = 5.0

@export_category("Hit")
@export var damage: float = 0.0
@export var stun_duration: float = 0.0
@export var root_duration: float = 0.0
@export var knockback_speed: float = 0.0
@export var knockback_duration: float = 0.18

@export_category("Shape")
@export var max_range: float = 2.0
@export var arc_degrees: float = 90.0
@export var hit_radius: float = 0.5

@export_category("Projectile")
@export var projectile_speed: float = 20.0
@export var projectile_piercing: bool = false

@export_category("Dash")
@export var dash_distance: float = 5.0
@export var dash_immaterial: bool = false
@export var dash_pass_through_characters: bool = true
@export var dash_stop_on_hit: bool = true

@export_category("Ground Area")
## Delay between activation and detonation (telegraph).
@export var area_delay: float = 0.6

@export_category("Counter")
@export var counter_teleport_distance: float = 0.0
@export var counter_stun_attacker: float = 0.0

@export_category("Heal")
@export var heal_amount: float = 0.0
@export var true_heal: bool = false


func does_damage() -> bool:
	return damage > 0.0 or stun_duration > 0.0 or root_duration > 0.0


## Effective threat distance from the caster (used by AI and indicators).
func get_reach() -> float:
	match kind:
		Kind.MELEE_ARC, Kind.PROJECTILE:
			return max_range
		Kind.DASH:
			return dash_distance + hit_radius
		Kind.GROUND_AREA:
			return max_range + hit_radius * 0.5
	return 0.0
