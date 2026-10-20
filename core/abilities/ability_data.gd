class_name AbilityData
extends Resource
## Data-driven definition of a jutsu: frame data, costs, hit properties.
## The `kind` selects a generic executor in AbilityEffects.

enum Kind { MELEE_ARC, PROJECTILE, DASH, GROUND_AREA, COUNTER, SELF_HEAL, SUMMON_CLONE, TELEPORT, SUBSTITUTION }

@export_category("Identity")
@export var display_name: String = "Jutsu"
@export var kind: Kind = Kind.MELEE_ARC
@export var color: Color = Color.WHITE
@export var icon: Texture2D
## Presentation: body pose ("jab", "kick", "slash", "palm", "chidori",
## "seal", "breath", "stomp", "throw", "guard", "heal", "dash", "leap"...).
@export var anim: StringName = &""
## Presentation: spell effect id used by SpellVfx ("rasengan", "chidori"...).
@export var vfx: StringName = &""
## Progression technique this ability was built from (keeps its cooldown
## when it moves between bar slots).
@export var source_id: StringName = &""

@export_category("Frame Data")
@export var startup_time: float = 0.1
## For DASH this is the dash duration; for COUNTER the counter window.
@export var active_time: float = 0.05
@export var recovery_time: float = 0.15
@export var cooldown: float = 0.0

@export_category("Movement During Cast")
@export_range(0.0, 1.0) var cast_move_multiplier: float = 0.5
@export_range(0.0, 1.0) var recovery_move_multiplier: float = 0.8

@export_category("Combo")
## Next hit of a basic-attack string, available for `combo_window` seconds
## after this one ends (press the same key again).
@export var combo_next: AbilityData
@export var combo_window: float = 0.45
## Short forward step when a melee hit comes out (weight / commitment).
@export var lunge_distance: float = 0.0

@export_category("Cancel / Interrupt")
@export var can_cancel_during_startup: bool = true
## Cooldown applied when cancelled (feint cost) or interrupted during startup.
@export var cancel_cooldown: float = 0.5

@export_category("Chakra Energy")
@export var energy_cost: float = 0.0
@export var energy_gain_on_hit: float = 5.0
## Stamina spent by this hit (basic attack stances).
@export var stamina_cost: float = 0.0

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
## Also heals allies within this radius (0 = self only).
@export var heal_allies_radius: float = 0.0

@export_category("On-Hit Effects")
@export var slow_duration: float = 0.0
## Stacks of MARK applied on hit (max 3, 5 s).
@export var apply_mark: int = 0
## Bonus damage per MARK stack consumed by this hit.
@export var mark_bonus_damage: float = 0.0
## Stun applied instead when 3 marks are consumed.
@export var mark_full_stun: float = 0.0
## Bonus damage against rooted targets (consumes the root).
@export var bonus_vs_rooted: float = 0.0

## Stacks of LOCK (chakra block) applied; 3 stacks silence for 1.5 s.
@export var apply_lock: int = 0
@export var silence_duration: float = 0.0
## Incapacitate (genjutsu): like a stun but broken by any damage.
@export var incapacitate_duration: float = 0.0
## Burn damage-over-time applied on hit (BURN_PER_SECOND).
@export var burn_duration: float = 0.0
## Chakra energy stolen from the target on hit.
@export var energy_drain: float = 0.0
## Applies Minato's Flying Thunder God seal on hit (SEAL, 8 s).
@export var apply_seal: bool = false

@export_category("Multi-hit")
## MELEE_ARC: number of pulses spread over active_time (flurries).
@export var multi_hits: int = 1

@export_category("Self Buffs (on activation)")
@export var buff_haste: float = 0.0
@export var buff_empower: float = 0.0
@export var buff_regen: float = 0.0
## Eight Gates style HP drain on self while buffed.
@export var buff_drain: float = 0.0
## Shield points granted on activation (absorbs damage), lasts shield_time.
@export var grant_shield: float = 0.0
@export var shield_time: float = 3.0

@export_category("Lingering Zone")
## GROUND_AREA: stays this long after detonating, ticking on enemies inside.
@export var zone_duration: float = 0.0
@export var zone_tick_damage: float = 0.0
## PROJECTILE: ground area left where it lands (e.g. burning ground).
@export var expire_zone: AbilityData
## Zone is a trap: armed after area_delay, triggers once (full hit) on the
## first enemy inside, expires after zone_duration.
@export var trap: bool = false
## Zone raises a wall (blocks movement) across the cast direction.
@export var wall_length: float = 0.0
## Zone is a Flying Thunder God kunai (teleport destination).
@export var marker: bool = false

@export_category("Counter Extras")
## Cooldown reset on a successful counter (e.g. &"rmb").
@export var counter_reset_slot: StringName = &""
@export var counter_haste: float = 0.0
## Copy the countered jutsu into the E slot for 10 s (one use).
@export var counter_copy: bool = false
## Burst around the countering fighter on trigger (Kaiten, crow clone).
@export var counter_aoe_radius: float = 0.0
@export var counter_aoe_damage: float = 0.0
@export var counter_aoe_knockback: float = 0.0
@export var counter_aoe_stun: float = 0.0

@export_category("Teleport")
## TELEPORT: "marker" (to your newest kunai), "sealed" (behind the nearest
## sealed enemy, then strike), "sealed_all" (strike every sealed enemy).
@export var teleport_mode: StringName = &""
@export var teleport_range: float = 12.0

@export_category("Shadow Clones")
## SUMMON_CLONE: clone lifetime and spawn distance.
@export var summon_duration: float = 0.0
@export var summon_distance: float = 2.5
## This melee / dash is also performed by the caster's clone (50 % damage).
@export var clone_mirror: bool = false
## DASH: swap places with the clone instead of dashing when one is out.
@export var swap_with_clone: bool = false

@export_category("Projection")
## > 0: the hit launches the target into the air for this long (it can't act;
## attacks pursue it automatically and keep it up, then it falls).
@export var launch_duration: float = 0.0

@export_category("Substitution")
## SUBSTITUTION: radius of the zone the caster must stay in for the
## substitution to stay armed.
@export var substitution_radius: float = 4.0


func does_damage() -> bool:
	return damage > 0.0 or stun_duration > 0.0 or root_duration > 0.0 or slow_duration > 0.0


## Effective threat distance from the caster (used by AI and indicators).
func get_reach() -> float:
	match kind:
		Kind.MELEE_ARC, Kind.PROJECTILE:
			return max_range
		Kind.DASH:
			return dash_distance + hit_radius
		Kind.GROUND_AREA:
			return max_range + hit_radius * 0.5
		Kind.TELEPORT:
			return teleport_range if teleport_mode != &"marker" else 0.0
	return 0.0
