#!/usr/bin/env python3
"""Generates characters/<id>/<id>_data.tres (stats, kits, looks).

Balancing lives here so every kit is visible side by side. The .tres files
stay editable in the Godot inspector; re-running this overwrites them.
    python3 tools/generate_characters.py
"""
import os

ROOT = os.path.join(os.path.dirname(__file__), "..")
# Battlerite-like time-to-kill: rounds last long enough for orbs, cooldown
# trades and outplays instead of being decided by the first combo.
HEALTH_SCALE = 1.4
KIND = {"MELEE": 0, "PROJ": 1, "DASH": 2, "AREA": 3, "COUNTER": 4, "HEAL": 5, "SUMMON": 6, "TELEPORT": 7}


def c(r, g, b, a=1):
    return f"Color({r}, {g}, {b}, {a})"


def ab(name, kind, color, **kw):
    d = dict(display_name=name, kind=KIND[kind], color=color)
    d.update(kw)
    if "energy_gain_on_hit" not in d:
        ult = d.get("energy_cost", 0) >= 100
        d["energy_gain_on_hit"] = 0.0 if ult else round(4 + d.get("damage", 0) * 0.6, 1)
    return d


def combo(*hits):
    """Chains hits: hit[i].combo_next = hit[i+1]. Returns the list."""
    for i in range(len(hits) - 1):
        hits[i]["combo_next"] = hits[i + 1]
    return list(hits)


def shunshin(dist=6.0, cd=8.0):
    return ab("Shunshin", "DASH", c(0.8, 0.9, 1), anim="dash", vfx="shunshin", startup_time=0.03, active_time=0.14, recovery_time=0.08,
              cooldown=cd, dash_distance=dist, dash_immaterial=True, cast_move_multiplier=1.0,
              recovery_move_multiplier=1.0, can_cancel_during_startup=False)


def melee_hit(name, color, dmg, rng=1.9, arc=100.0, startup=0.08, rec=0.14, lunge=0.5, **kw):
    return ab(name, "MELEE", color, startup_time=startup, active_time=0.05, recovery_time=rec,
              max_range=rng, arc_degrees=arc, damage=dmg, lunge_distance=lunge,
              cast_move_multiplier=0.55, recovery_move_multiplier=0.85, combo_window=0.45, **kw)


CHARACTERS = {
    # NARUTO — shadow clones. The clone mirrors his taijutsu and Rasengan;
    # Space swaps places with it. Passive: Kurama's chakra when low.
    "naruto": dict(
        display_name="Naruto Uzumaki", body_color=c(1, 0.5, 0.05), max_health=135.0, speed=7.0,
        identity="Shadow-clone pressure: your clone copies your taijutsu and Rasengan, Space swaps places with it.",
        passive="kurama", passive_description="Kurama's Chakra: once per round, under 30% HP you regenerate and gain haste.",
        look=dict(skin=c(0.98, 0.8, 0.64), top=c(1, 0.5, 0.1), top_accent=c(0.1, 0.1, 0.14), sleeves=c(1, 0.5, 0.1),
                  pants=c(1, 0.5, 0.1), accent=c(0.12, 0.12, 0.18), hair_color=c(1, 0.85, 0.2), hair=0,
                  eye_color=c(0.15, 0.45, 0.95), whiskers=True),
        kit=dict(
            lmb=combo(melee_hit("Taijutsu", c(1, 0.7, 0.3), 6.0, anim="jab", clone_mirror=True),
                      melee_hit("Taijutsu II", c(1, 0.7, 0.3), 6.0, anim="hook", clone_mirror=True),
                      melee_hit("Uzumaki Kick", c(1, 0.6, 0.2), 11.0, rng=2.1, startup=0.12, rec=0.3, lunge=0.9,
                                knockback_speed=10.0, knockback_duration=0.2, anim="kick", clone_mirror=True)),
            rmb=ab("Rasengan", "DASH", c(0.3, 0.6, 1), anim="palm", vfx="rasengan", clone_mirror=True,
                   startup_time=0.3, active_time=0.2, recovery_time=0.32, cooldown=6.0,
                   dash_distance=4.5, hit_radius=0.7, damage=22.0, knockback_speed=13.0, knockback_duration=0.24,
                   cast_move_multiplier=0.3, recovery_move_multiplier=0.5),
            space=dict(shunshin(6.0, 7.0), display_name="Shunshin / Clone Swap", swap_with_clone=True),
            q=ab("Kawarimi no Jutsu", "COUNTER", c(0.6, 0.4, 0.2), anim="seal", startup_time=0.02, active_time=0.8,
                 recovery_time=0.15, cooldown=11.0, counter_teleport_distance=4.5, cast_move_multiplier=0.4,
                 energy_gain_on_hit=10.0, can_cancel_during_startup=False),
            e=ab("Kage Bunshin", "SUMMON", c(1, 0.55, 0.1), anim="seal", vfx="clone", startup_time=0.2, active_time=0.05,
                 recovery_time=0.15, cooldown=11.0, summon_duration=6.0, summon_distance=2.5, max_range=2.5,
                 cast_move_multiplier=0.5),
            ult=ab("Rasenshuriken", "PROJ", c(0.6, 0.9, 1), anim="throw", vfx="rasenshuriken", startup_time=0.5,
                   active_time=0.05, recovery_time=0.35, energy_cost=100.0, max_range=14.0, hit_radius=1.0,
                   projectile_speed=16.0, damage=36.0, knockback_speed=9.0, cast_move_multiplier=0.2),
        )),
    # SASUKE — reads. Kusanagi stacks Sharingan marks; Chidori cashes them in
    # (3 marks = long stun). A successful Sharingan counter resets Chidori.
    "sasuke": dict(
        display_name="Sasuke Uchiha", body_color=c(0.25, 0.35, 0.85), max_health=130.0, speed=7.1,
        identity="Precise duelist: Kusanagi marks, Chidori cashes the marks in, Sharingan counters reset Chidori.",
        passive="", passive_description="Sharingan marks: Kusanagi hits stack up to 3 marks on the target.",
        look=dict(skin=c(0.98, 0.85, 0.74), top=c(0.9, 0.9, 0.93), top_accent=c(0.35, 0.3, 0.5), sleeves=c(0.9, 0.9, 0.93),
                  pants=c(0.2, 0.22, 0.32), accent=c(0.45, 0.3, 0.6), hair_color=c(0.08, 0.09, 0.16), hair=1,
                  eye_color=c(0.85, 0.05, 0.05), headband=False, weapon=1),
        kit=dict(
            lmb=combo(melee_hit("Kusanagi", c(0.8, 0.85, 1), 6.0, rng=2.3, arc=120.0, startup=0.09, rec=0.15, lunge=0.6,
                                anim="slash", apply_mark=1),
                      melee_hit("Kusanagi II", c(0.8, 0.85, 1), 6.0, rng=2.3, arc=120.0, startup=0.09, rec=0.15, lunge=0.6,
                                anim="slash2", apply_mark=1),
                      melee_hit("Kusanagi Thrust", c(0.6, 0.8, 1), 10.0, rng=2.9, arc=45.0, startup=0.14, rec=0.32,
                                lunge=1.3, knockback_speed=7.0, anim="thrust", apply_mark=1)),
            rmb=ab("Chidori", "DASH", c(0.4, 0.85, 1), anim="chidori", vfx="chidori", startup_time=0.3, active_time=0.22,
                   recovery_time=0.38, cooldown=7.0, dash_distance=6.5, hit_radius=0.7, damage=14.0, stun_duration=0.3,
                   mark_bonus_damage=6.0, mark_full_stun=1.3, cast_move_multiplier=0.3, recovery_move_multiplier=0.5),
            space=shunshin(5.5, 8.0),
            q=ab("Sharingan Counter", "COUNTER", c(0.9, 0.1, 0.1), anim="guard", vfx="sharingan", startup_time=0.02,
                 active_time=0.9, recovery_time=0.2, cooldown=12.0, counter_stun_attacker=0.8, counter_reset_slot="rmb",
                 counter_haste=2.0, cast_move_multiplier=0.3, energy_gain_on_hit=10.0, can_cancel_during_startup=False),
            e=ab("Katon: Goukakyuu", "PROJ", c(1, 0.35, 0.1), anim="breath", vfx="katon", startup_time=0.35,
                 active_time=0.05, recovery_time=0.3, cooldown=9.0, max_range=9.0, hit_radius=0.9, projectile_speed=13.0,
                 damage=12.0, knockback_speed=4.0, cast_move_multiplier=0.3,
                 expire_zone=ab("Burning Ground", "AREA", c(1, 0.4, 0.1), vfx="fire_zone", area_delay=0.0, hit_radius=2.0,
                                zone_duration=3.0, zone_tick_damage=3.0, slow_duration=0.6, energy_gain_on_hit=2.0)),
            ult=ab("Kirin", "AREA", c(0.5, 0.8, 1), anim="seal", vfx="kirin", startup_time=0.4, active_time=0.05,
                   recovery_time=0.3, energy_cost=100.0, max_range=11.0, hit_radius=3.0, area_delay=1.1, damage=38.0,
                   stun_duration=0.5, mark_bonus_damage=4.0, cast_move_multiplier=0.3),
        )),
    # SAKURA — frontline medic. Okashou leaves a slowing crater, her heal
    # also heals allies, Byakugou = full heal + regen + Strength of a Hundred.
    "sakura": dict(
        display_name="Sakura Haruno", body_color=c(1, 0.45, 0.7), max_health=150.0, speed=6.8,
        identity="Frontline medic: craters that slow, heals that reach allies, Strength of a Hundred to finish.",
        passive="", passive_description="Medical ninja: Mystical Palm also heals allies within 5 m.",
        look=dict(skin=c(0.99, 0.84, 0.74), top=c(0.82, 0.12, 0.2), top_accent=c(0.95, 0.95, 0.95), sleeves=c(0.99, 0.84, 0.74),
                  pants=c(0.12, 0.12, 0.15), accent=c(0.6, 0.6, 0.65), hair_color=c(1, 0.55, 0.75), hair=2,
                  eye_color=c(0.2, 0.65, 0.3), gloves=c(0.15, 0.15, 0.18), shorts=True),
        kit=dict(
            lmb=combo(melee_hit("Chakra Punch", c(1, 0.6, 0.8), 8.0, rng=2.0, arc=110.0, startup=0.12, rec=0.18, anim="jab"),
                      melee_hit("Chakra Punch II", c(1, 0.6, 0.8), 8.0, rng=2.0, arc=110.0, startup=0.12, rec=0.18, anim="hook"),
                      melee_hit("Shannaro!", c(1, 0.35, 0.55), 14.0, rng=2.3, arc=90.0, startup=0.18, rec=0.34, lunge=0.9,
                                knockback_speed=13.0, knockback_duration=0.25, anim="thrust")),
            rmb=ab("Oukashou", "AREA", c(1, 0.4, 0.6), anim="stomp", vfx="okasho", startup_time=0.25, active_time=0.05,
                   recovery_time=0.3, cooldown=7.0, max_range=5.0, hit_radius=2.4, area_delay=0.4, damage=18.0,
                   stun_duration=0.6, zone_duration=2.5, zone_tick_damage=0.0, slow_duration=0.6, cast_move_multiplier=0.3),
            space=ab("Chakra Leap", "DASH", c(1, 0.7, 0.85), anim="leap", vfx="leap", startup_time=0.08, active_time=0.28,
                     recovery_time=0.12, cooldown=9.0, dash_distance=6.5, dash_immaterial=True, cast_move_multiplier=1.0,
                     can_cancel_during_startup=False),
            q=ab("Mystical Palm", "HEAL", c(0.4, 1, 0.5), anim="heal", vfx="heal", startup_time=0.55, active_time=0.05,
                 recovery_time=0.2, cooldown=12.0, heal_amount=22.0, heal_allies_radius=5.0, cast_move_multiplier=0.3),
            e=ab("Heel Drop", "MELEE", c(1, 0.3, 0.5), anim="stomp", vfx="stomp", startup_time=0.22, active_time=0.05,
                 recovery_time=0.3, cooldown=6.0, max_range=2.4, arc_degrees=80.0, damage=12.0, stun_duration=0.5,
                 lunge_distance=1.4, cast_move_multiplier=0.4),
            ult=ab("Byakugou: Strength of a Hundred", "HEAL", c(0.6, 0.3, 1), anim="heal", vfx="byakugou",
                   startup_time=0.5, active_time=0.05, recovery_time=0.2, energy_cost=100.0, heal_amount=40.0,
                   true_heal=True, buff_regen=6.0, buff_empower=6.0, buff_haste=3.0, cast_move_multiplier=0.2),
        )),
    # KAKASHI — copy ninja. His Sharingan counter copies the jutsu that hit
    # him into E (10 s, one use). Raikiri punishes targets rooted by Ninken.
    "kakashi": dict(
        display_name="Kakashi Hatake", body_color=c(0.7, 0.72, 0.78), max_health=130.0, speed=7.0,
        identity="Copy ninja: counter a jutsu to copy it into E; Ninken roots set up a devastating Raikiri.",
        passive="", passive_description="Copy Ninja: a successful Sharingan Copy turns E into the copied jutsu for 10 s.",
        look=dict(skin=c(0.95, 0.8, 0.66), top=c(0.16, 0.2, 0.35), top_accent=c(0.36, 0.45, 0.27), sleeves=c(0.16, 0.2, 0.35),
                  pants=c(0.16, 0.2, 0.35), accent=c(0.1, 0.1, 0.14), hair_color=c(0.86, 0.88, 0.92), hair=3,
                  eye_color=c(0.1, 0.1, 0.12), mask=True, flak_vest=True, gloves=c(0.12, 0.12, 0.15), weapon=2),
        kit=dict(
            lmb=combo(melee_hit("Kunai Slash", c(0.8, 0.82, 0.9), 6.5, rng=2.1, arc=110.0, anim="slash"),
                      melee_hit("Kunai Slash II", c(0.8, 0.82, 0.9), 6.5, rng=2.1, arc=110.0, anim="slash2"),
                      melee_hit("Raiton Palm", c(0.55, 0.85, 1), 10.0, rng=2.2, arc=70.0, startup=0.14, rec=0.3, lunge=0.9,
                                stun_duration=0.35, anim="palm")),
            rmb=ab("Raikiri", "DASH", c(0.5, 0.85, 1), anim="chidori", vfx="raikiri", startup_time=0.4, active_time=0.25,
                   recovery_time=0.4, cooldown=7.0, dash_distance=7.0, hit_radius=0.7, damage=20.0, bonus_vs_rooted=14.0,
                   knockback_speed=8.0, cast_move_multiplier=0.25, recovery_move_multiplier=0.5),
            space=shunshin(5.5, 8.0),
            q=ab("Sharingan Copy", "COUNTER", c(0.9, 0.15, 0.15), anim="guard", vfx="sharingan", startup_time=0.02,
                 active_time=0.8, recovery_time=0.15, cooldown=11.0, counter_copy=True, counter_teleport_distance=2.0,
                 cast_move_multiplier=0.4, energy_gain_on_hit=12.0, can_cancel_during_startup=False),
            e=ab("Summoning: Ninken", "AREA", c(0.6, 0.5, 0.3), anim="stomp", vfx="ninken", startup_time=0.2,
                 active_time=0.05, recovery_time=0.25, cooldown=10.0, max_range=9.0, hit_radius=1.6, area_delay=0.45,
                 damage=6.0, root_duration=1.6, cast_move_multiplier=0.4),
            ult=ab("Kamui", "AREA", c(0.4, 0.2, 0.6), anim="seal", vfx="kamui", startup_time=0.5, active_time=0.05,
                   recovery_time=0.4, energy_cost=100.0, max_range=10.0, hit_radius=2.4, area_delay=1.2, damage=45.0,
                   cast_move_multiplier=0.25),
        )),
    # ROCK LEE — pure taijutsu, no jutsu. Q opens the Eight Gates: huge
    # speed and damage while draining his own HP.
    "lee": dict(
        display_name="Rock Lee", body_color=c(0.2, 0.6, 0.25), max_health=140.0, speed=7.3,
        identity="Pure taijutsu: relentless strings, the Lotus, and the Eight Gates (power at the cost of HP).",
        passive="", passive_description="Eight Gates: opening them grants haste + 25% damage but drains HP (never lethal).",
        look=dict(skin=c(0.98, 0.82, 0.68), top=c(0.2, 0.55, 0.22), top_accent=c(0.2, 0.55, 0.22), sleeves=c(0.2, 0.55, 0.22),
                  pants=c(0.2, 0.55, 0.22), accent=c(0.75, 0.15, 0.12), hair_color=c(0.05, 0.05, 0.08), hair=4,
                  eye_color=c(0.05, 0.05, 0.08), thick_brows=True, leg_warmers=c(1.0, 0.55, 0.1), gloves=c(0.95, 0.95, 0.92)),
        kit=dict(
            lmb=combo(melee_hit("Konoha Strike", c(0.5, 1, 0.5), 5.5, startup=0.07, rec=0.12, anim="jab"),
                      melee_hit("Konoha Strike II", c(0.5, 1, 0.5), 5.5, startup=0.07, rec=0.12, anim="hook"),
                      melee_hit("Leaf Hurricane", c(0.4, 1, 0.45), 10.0, rng=2.3, arc=200.0, startup=0.11, rec=0.28, lunge=0.6,
                                knockback_speed=9.0, anim="kick")),
            rmb=ab("Primary Lotus", "DASH", c(0.4, 1, 0.5), anim="dash", vfx="lotus", startup_time=0.25, active_time=0.22,
                   recovery_time=0.4, cooldown=8.0, dash_distance=6.0, hit_radius=0.7, damage=18.0, stun_duration=0.9,
                   cast_move_multiplier=0.3, recovery_move_multiplier=0.5),
            space=ab("Dynamic Entry", "DASH", c(0.4, 1, 0.5), anim="kick", startup_time=0.1, active_time=0.24,
                     recovery_time=0.15, cooldown=7.0, dash_distance=7.5, hit_radius=0.7, damage=8.0, knockback_speed=12.0,
                     dash_stop_on_hit=True, cast_move_multiplier=1.0, can_cancel_during_startup=False),
            q=ab("Eight Gates: Open", "HEAL", c(0.35, 1, 0.45), anim="heal", vfx="gates", startup_time=0.4, active_time=0.05,
                 recovery_time=0.15, cooldown=16.0, buff_haste=6.0, buff_empower=6.0, buff_drain=6.0, cast_move_multiplier=0.3),
            e=ab("Leaf Gale", "MELEE", c(0.5, 1, 0.5), anim="kick", startup_time=0.15, active_time=0.05, recovery_time=0.25,
                 cooldown=6.0, max_range=2.4, arc_degrees=360.0, damage=9.0, slow_duration=1.2,
                 cast_move_multiplier=0.5),
            ult=ab("Morning Peacock", "MELEE", c(1, 0.55, 0.15), anim="jab", vfx="peacock", startup_time=0.35, active_time=0.9,
                   recovery_time=0.4, energy_cost=100.0, max_range=3.2, arc_degrees=100.0, damage=5.0, multi_hits=8,
                   energy_gain_on_hit=0.0, cast_move_multiplier=0.0),
        )),
    # GAARA — absolute defense. Passive sand armor shield; walls that block
    # movement; Sand Coffin roots, Sand Burial crushes rooted targets.
    "gaara": dict(
        display_name="Gaara", body_color=c(0.75, 0.25, 0.2), max_health=145.0, speed=6.5,
        identity="Absolute defense: sand armor, walls that block the arena, Sand Coffin into Sand Burial.",
        passive="sand_armor", passive_description="Sand Armor: a 15-point sand shield that rebuilds 8 s after breaking.",
        look=dict(skin=c(0.96, 0.85, 0.75), top=c(0.55, 0.15, 0.15), top_accent=c(0.3, 0.12, 0.12), sleeves=c(0.55, 0.15, 0.15),
                  pants=c(0.35, 0.18, 0.15), accent=c(0.8, 0.75, 0.65), hair_color=c(0.8, 0.18, 0.12), hair=5,
                  eye_color=c(0.35, 0.75, 0.55), headband=False, gourd=True, forehead_mark=True),
        kit=dict(
            lmb=combo(melee_hit("Sand Fist", c(0.85, 0.72, 0.45), 7.0, rng=2.8, arc=70.0, startup=0.14, rec=0.2, lunge=0.0, anim="jab"),
                      melee_hit("Sand Lash", c(0.85, 0.72, 0.45), 7.0, rng=2.8, arc=110.0, startup=0.14, rec=0.2, lunge=0.0, anim="hook"),
                      melee_hit("Sand Wave", c(0.85, 0.7, 0.4), 11.0, rng=3.2, arc=80.0, startup=0.2, rec=0.35, lunge=0.0,
                                knockback_speed=9.0, anim="thrust")),
            rmb=ab("Sand Coffin", "AREA", c(0.85, 0.72, 0.45), anim="seal", vfx="sand_coffin", startup_time=0.3,
                   active_time=0.05, recovery_time=0.3, cooldown=8.0, max_range=8.0, hit_radius=1.5, area_delay=0.55,
                   damage=8.0, root_duration=1.6, bonus_vs_rooted=0.0, cast_move_multiplier=0.3),
            space=ab("Sand Shunshin", "DASH", c(0.85, 0.72, 0.45), anim="dash", vfx="shunshin", startup_time=0.05,
                     active_time=0.18, recovery_time=0.1, cooldown=9.0, dash_distance=5.0, dash_immaterial=True,
                     cast_move_multiplier=1.0, can_cancel_during_startup=False),
            q=ab("Sand Shield", "HEAL", c(0.85, 0.72, 0.45), anim="guard", vfx="kaiten", startup_time=0.05, active_time=0.05,
                 recovery_time=0.1, cooldown=12.0, grant_shield=35.0, shield_time=3.0, cast_move_multiplier=0.6),
            e=ab("Sand Wall", "AREA", c(0.85, 0.72, 0.45), anim="seal", startup_time=0.2, active_time=0.05, recovery_time=0.2,
                 cooldown=10.0, max_range=4.0, hit_radius=0.6, area_delay=0.05, wall_length=4.0, zone_duration=4.0,
                 cast_move_multiplier=0.4),
            ult=ab("Sand Burial", "AREA", c(0.9, 0.7, 0.35), anim="seal", vfx="sand_tsunami", startup_time=0.45,
                   active_time=0.05, recovery_time=0.35, energy_cost=100.0, max_range=9.0, hit_radius=2.6, area_delay=0.8,
                   damage=26.0, bonus_vs_rooted=20.0, slow_duration=2.0, cast_move_multiplier=0.25),
        )),
    # HINATA — Gentle Fist. Palms block chakra (3 blocks = silence) and
    # steal energy; Kaiten is a counter that blasts everyone away.
    "hinata": dict(
        display_name="Hinata Hyuga", body_color=c(0.75, 0.7, 0.95), max_health=125.0, speed=7.0,
        identity="Gentle Fist: palms block chakra (3 blocks silence the target) and steal energy; Kaiten repels all.",
        passive="", passive_description="Chakra Block: Gentle Fist hits stack blocks; at 3 the target is silenced for 1.5 s.",
        look=dict(skin=c(0.99, 0.88, 0.8), top=c(0.85, 0.82, 0.92), top_accent=c(0.55, 0.45, 0.75), sleeves=c(0.85, 0.82, 0.92),
                  pants=c(0.2, 0.22, 0.4), accent=c(0.3, 0.3, 0.45), hair_color=c(0.18, 0.15, 0.35), hair=6,
                  eye_color=c(0.9, 0.88, 0.98), eye_white=True),
        kit=dict(
            lmb=combo(melee_hit("Gentle Fist", c(0.55, 0.75, 1), 5.5, rng=1.9, arc=80.0, startup=0.08, rec=0.14, anim="jab",
                                apply_lock=1, energy_drain=3.0),
                      melee_hit("Gentle Fist II", c(0.55, 0.75, 1), 5.5, rng=1.9, arc=80.0, startup=0.08, rec=0.14, anim="hook",
                                apply_lock=1, energy_drain=3.0),
                      melee_hit("Twin Palm", c(0.5, 0.7, 1), 9.0, rng=2.1, arc=70.0, startup=0.12, rec=0.28, lunge=0.8,
                                knockback_speed=8.0, anim="palm", apply_lock=1, energy_drain=5.0)),
            rmb=ab("Lion Fists", "DASH", c(0.5, 0.75, 1), anim="palm", vfx="gentle_fist", startup_time=0.28, active_time=0.2,
                   recovery_time=0.35, cooldown=7.0, dash_distance=5.0, hit_radius=0.7, damage=14.0, apply_lock=2,
                   energy_drain=10.0, cast_move_multiplier=0.3, recovery_move_multiplier=0.5),
            space=shunshin(5.5, 8.0),
            q=ab("Kaiten", "COUNTER", c(0.55, 0.75, 1), anim="guard", vfx="kaiten", startup_time=0.02, active_time=0.7,
                 recovery_time=0.2, cooldown=11.0, counter_aoe_radius=3.0, counter_aoe_damage=8.0, counter_aoe_knockback=12.0,
                 cast_move_multiplier=0.2, energy_gain_on_hit=10.0, can_cancel_during_startup=False),
            e=ab("Byakugan Focus", "HEAL", c(0.85, 0.85, 1), anim="seal", vfx="gates", startup_time=0.2, active_time=0.05,
                 recovery_time=0.1, cooldown=14.0, buff_haste=4.0, buff_empower=4.0, cast_move_multiplier=0.5),
            ult=ab("64 Palms", "MELEE", c(0.55, 0.75, 1), anim="palm", vfx="palms", startup_time=0.3, active_time=1.0,
                   recovery_time=0.35, energy_cost=100.0, max_range=2.6, arc_degrees=90.0, damage=3.5, multi_hits=10,
                   apply_lock=1, energy_drain=4.0, energy_gain_on_hit=0.0, cast_move_multiplier=0.0),
        )),
    # SHIKAMARU — strategist. Shadow Possession slides on the ground and
    # roots; Shadow Strangle punishes rooted targets; explosive-tag traps.
    "shikamaru": dict(
        display_name="Shikamaru Nara", body_color=c(0.4, 0.45, 0.35), max_health=130.0, speed=6.9,
        identity="Strategist: shadows that root, a strangle that punishes rooted targets, traps for the predictable.",
        passive="", passive_description="Shadow tactics: Shadow Strangle deals heavy bonus damage to rooted targets.",
        look=dict(skin=c(0.96, 0.82, 0.68), top=c(0.36, 0.45, 0.27), top_accent=c(0.36, 0.45, 0.27), sleeves=c(0.25, 0.3, 0.38),
                  pants=c(0.22, 0.26, 0.34), accent=c(0.15, 0.15, 0.18), hair_color=c(0.1, 0.1, 0.12), hair=7,
                  eye_color=c(0.1, 0.1, 0.12), flak_vest=True, weapon=2),
        kit=dict(
            lmb=combo(melee_hit("Trench Knife", c(0.6, 0.65, 0.75), 6.0, rng=2.0, arc=100.0, anim="slash"),
                      melee_hit("Trench Knife II", c(0.6, 0.65, 0.75), 6.0, rng=2.0, arc=100.0, anim="slash2"),
                      melee_hit("Shadow Jab", c(0.2, 0.2, 0.3), 9.0, rng=2.2, arc=60.0, startup=0.13, rec=0.28, lunge=0.7,
                                slow_duration=1.0, anim="thrust")),
            rmb=ab("Shadow Possession", "PROJ", c(0.1, 0.1, 0.15), anim="seal", vfx="shadow", startup_time=0.3,
                   active_time=0.05, recovery_time=0.35, cooldown=9.0, max_range=9.0, hit_radius=0.45, projectile_speed=11.0,
                   damage=4.0, root_duration=1.7, cast_move_multiplier=0.2),
            space=shunshin(5.0, 8.0),
            q=ab("Explosive Tag Trap", "AREA", c(1, 0.55, 0.15), anim="throw", vfx="trap", startup_time=0.15, active_time=0.05,
                 recovery_time=0.15, cooldown=9.0, max_range=6.0, hit_radius=1.4, area_delay=0.6, trap=True, zone_duration=12.0,
                 damage=14.0, stun_duration=1.0, cast_move_multiplier=0.5),
            e=ab("Shadow Strangle", "AREA", c(0.05, 0.05, 0.08), anim="seal", vfx="shadow_strangle", startup_time=0.25,
                 active_time=0.05, recovery_time=0.25, cooldown=7.0, max_range=7.0, hit_radius=1.4, area_delay=0.35,
                 damage=8.0, bonus_vs_rooted=16.0, slow_duration=1.2, cast_move_multiplier=0.3),
            ult=ab("Shadow Gathering", "AREA", c(0.05, 0.05, 0.08), anim="seal", vfx="shadow_gather", startup_time=0.45,
                   active_time=0.05, recovery_time=0.35, energy_cost=100.0, max_range=8.0, hit_radius=3.2, area_delay=0.9,
                   damage=14.0, root_duration=2.2, zone_duration=2.0, zone_tick_damage=3.0, cast_move_multiplier=0.25),
        )),
    # ITACHI — genjutsu. Tsukuyomi incapacitates until hit; Amaterasu burns
    # long; crow-clone counter stuns around; Susanoo's Totsuka seals jutsu.
    "itachi": dict(
        display_name="Itachi Uchiha", body_color=c(0.25, 0.1, 0.12), max_health=125.0, speed=7.0,
        identity="Genjutsu: Tsukuyomi locks a target until hit, Amaterasu burns, crows punish attackers, Totsuka seals.",
        passive="", passive_description="Genjutsu: Tsukuyomi incapacitates until the target takes damage — set up your burst.",
        look=dict(skin=c(0.96, 0.85, 0.76), top=c(0.12, 0.12, 0.16), top_accent=c(0.12, 0.12, 0.16), sleeves=c(0.12, 0.12, 0.16),
                  pants=c(0.15, 0.15, 0.2), accent=c(0.15, 0.15, 0.2), hair_color=c(0.06, 0.06, 0.1), hair=8,
                  eye_color=c(0.85, 0.05, 0.05), cloak=c(0.1, 0.1, 0.13), cloak_pattern="clouds", weapon=2),
        kit=dict(
            lmb=combo(melee_hit("Kunai Arc", c(0.75, 0.75, 0.8), 6.5, rng=2.1, arc=110.0, anim="slash"),
                      melee_hit("Kunai Arc II", c(0.75, 0.75, 0.8), 6.5, rng=2.1, arc=110.0, anim="slash2"),
                      melee_hit("Uchiha Kick", c(0.85, 0.2, 0.2), 9.5, rng=2.2, arc=90.0, startup=0.12, rec=0.28, lunge=0.8,
                                knockback_speed=9.0, anim="kick")),
            rmb=ab("Tsukuyomi", "MELEE", c(0.9, 0.05, 0.1), anim="seal", vfx="tsukuyomi", startup_time=0.45, active_time=0.05,
                   recovery_time=0.35, cooldown=10.0, max_range=4.5, arc_degrees=40.0, damage=4.0, incapacitate_duration=2.0,
                   cast_move_multiplier=0.2),
            space=ab("Crow Shunshin", "DASH", c(0.15, 0.1, 0.15), anim="dash", vfx="shunshin", startup_time=0.03,
                     active_time=0.15, recovery_time=0.08, cooldown=8.0, dash_distance=6.0, dash_immaterial=True,
                     cast_move_multiplier=1.0, can_cancel_during_startup=False),
            q=ab("Crow Clone", "COUNTER", c(0.2, 0.1, 0.2), anim="guard", vfx="crow", startup_time=0.02, active_time=0.8,
                 recovery_time=0.15, cooldown=12.0, counter_teleport_distance=3.5, counter_aoe_radius=2.5,
                 counter_aoe_stun=1.0, counter_aoe_damage=6.0, cast_move_multiplier=0.4, energy_gain_on_hit=10.0,
                 can_cancel_during_startup=False),
            e=ab("Amaterasu", "AREA", c(0.3, 0.05, 0.35), anim="seal", startup_time=0.35, active_time=0.05,
                 recovery_time=0.3, cooldown=10.0, max_range=8.0, hit_radius=1.5, area_delay=0.4, damage=6.0,
                 burn_duration=4.0, zone_duration=3.0, zone_tick_damage=2.0, vfx="black_fire", cast_move_multiplier=0.3),
            ult=ab("Susanoo: Totsuka Blade", "MELEE", c(0.6, 0.3, 0.95), anim="slash", vfx="susanoo", startup_time=0.5,
                   active_time=0.05, recovery_time=0.45, energy_cost=100.0, max_range=4.8, arc_degrees=120.0, damage=34.0,
                   silence_duration=2.5, knockback_speed=10.0, cast_move_multiplier=0.2),
        )),
    # MINATO — Flying Thunder God. Plant kunai and teleport to them; seal
    # enemies with strikes, then teleport behind them; the ult hits every seal.
    "minato": dict(
        display_name="Minato Namikaze", body_color=c(1, 0.85, 0.3), max_health=125.0, speed=7.2,
        identity="Flying Thunder God: plant kunai to teleport, seal enemies and appear behind them.",
        passive="", passive_description="Hiraishin seals: every third string hit and Rasengan seal the target for 8 s.",
        look=dict(skin=c(0.98, 0.84, 0.7), top=c(0.36, 0.45, 0.27), top_accent=c(0.36, 0.45, 0.27), sleeves=c(0.16, 0.2, 0.35),
                  pants=c(0.16, 0.2, 0.35), accent=c(0.1, 0.1, 0.14), hair_color=c(1, 0.86, 0.3), hair=0,
                  eye_color=c(0.2, 0.45, 0.85), flak_vest=True, cloak=c(0.95, 0.95, 0.95), cloak_pattern="flames", weapon=2),
        kit=dict(
            lmb=combo(melee_hit("Kunai Flash", c(1, 0.9, 0.4), 6.0, rng=2.0, arc=100.0, startup=0.07, rec=0.13, anim="slash"),
                      melee_hit("Kunai Flash II", c(1, 0.9, 0.4), 6.0, rng=2.0, arc=100.0, startup=0.07, rec=0.13, anim="slash2"),
                      melee_hit("Sealing Strike", c(1, 0.85, 0.3), 9.0, rng=2.2, arc=80.0, startup=0.11, rec=0.26, lunge=0.8,
                                anim="thrust", apply_seal=True)),
            rmb=ab("Hiraishin Strike", "TELEPORT", c(1, 0.9, 0.35), anim="slash", vfx="flash", teleport_mode="sealed",
                   teleport_range=12.0, startup_time=0.15, active_time=0.05, recovery_time=0.3, cooldown=6.0, max_range=2.2,
                   arc_degrees=120.0, damage=16.0, stun_duration=0.4, cast_move_multiplier=0.4),
            space=ab("Flying Thunder God", "TELEPORT", c(1, 0.9, 0.35), anim="dash", vfx="flash", teleport_mode="marker",
                     teleport_range=16.0, startup_time=0.05, active_time=0.05, recovery_time=0.1, cooldown=5.0,
                     cast_move_multiplier=1.0, can_cancel_during_startup=False),
            q=ab("Rasengan", "DASH", c(0.35, 0.65, 1), anim="palm", vfx="rasengan", startup_time=0.25, active_time=0.18,
                 recovery_time=0.3, cooldown=8.0, dash_distance=4.0, hit_radius=0.7, damage=18.0, knockback_speed=11.0,
                 apply_seal=True, cast_move_multiplier=0.3, recovery_move_multiplier=0.5),
            e=ab("Hiraishin Kunai", "AREA", c(1, 0.85, 0.3), anim="throw", vfx="kunai_marker", startup_time=0.1,
                 active_time=0.05, recovery_time=0.12, cooldown=4.0, max_range=10.0, hit_radius=0.5, area_delay=0.15,
                 marker=True, zone_duration=10.0, cast_move_multiplier=0.7),
            ult=ab("Hiraishin: Level 2", "TELEPORT", c(1, 0.9, 0.35), anim="slash", vfx="flash", teleport_mode="sealed_all",
                   teleport_range=16.0, startup_time=0.3, active_time=0.05, recovery_time=0.35, energy_cost=100.0,
                   max_range=2.4, arc_degrees=140.0, damage=24.0, stun_duration=0.8, cast_move_multiplier=0.2),
        )),
}


SHORT = {"lee": "Lee"}


def val(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, float):
        return repr(v)
    if isinstance(v, int):
        return str(v)
    if v.startswith("Color("):
        return v
    return '"' + v + '"'


def write(key, ch):
    subs, ext = [], []
    ext.append('[ext_resource type="Script" path="res://characters/base/character_data.gd" id="1"]')
    ext.append('[ext_resource type="Script" path="res://core/abilities/ability_data.gd" id="2"]')
    ext.append('[ext_resource type="Script" path="res://core/movement/movement_data.gd" id="3"]')
    ext.append('[ext_resource type="Script" path="res://characters/base/shinobi_look.gd" id="4"]')
    for slot in ch["kit"]:
        ext.append(f'[ext_resource type="Texture2D" path="res://ui/icons/{key}_{slot}.svg" id="icon_{slot}"]')

    subs.append('[sub_resource type="Resource" id="movement"]\nscript = ExtResource("3")\n'
                f'move_speed = {ch["speed"]}\nacceleration = 300.0\ndeceleration = 360.0\n')
    look = '[sub_resource type="Resource" id="look"]\nscript = ExtResource("4")\n'
    for k, v in ch["look"].items():
        look += f"{k} = {val(v)}\n"
    subs.append(look)

    NESTED = ("combo_next", "expire_zone")

    def emit(slot, a, idx, suffix=""):
        """Emits `a` (nested abilities first: combo chain, expire zone) and returns its id."""
        nested_ids = {}
        for key in NESTED:
            if key in a:
                nested_ids[key] = emit(slot, a[key], idx + 1, suffix + ("z" if key == "expire_zone" else ""))
        rid = (slot if idx == 0 else f"{slot}_{idx}") + suffix
        body = f'[sub_resource type="Resource" id="{rid}"]\nscript = ExtResource("2")\nicon = ExtResource("icon_{slot}")\n'
        for k, v in a.items():
            if k not in NESTED:
                body += f"{k} = {val(v)}\n"
        for key, nid in nested_ids.items():
            body += f'{key} = SubResource("{nid}")\n'
        subs.append(body)
        return rid

    slots = {}
    for slot, a in ch["kit"].items():
        slots[slot] = emit(slot, a[0] if isinstance(a, list) else a, 0)

    res = ['[resource]', 'script = ExtResource("1")', f'display_name = "{ch["display_name"]}"', f'short_name = "{SHORT.get(key, ch["display_name"].split(" ")[0])}"',
           f'passive = "{ch.get("passive", "")}"', f'passive_description = "{ch.get("passive_description", "")}"',
           f'identity = "{ch["identity"]}"', f'body_color = {ch["body_color"]}', f'max_health = {round(ch["max_health"] * HEALTH_SCALE)}.0',
           'movement = SubResource("movement")', 'look = SubResource("look")']
    res += [f'{slot} = SubResource("{rid}")' for slot, rid in slots.items()]
    steps = len(ext) + len(subs) + 1
    text = (f'[gd_resource type="Resource" script_class="CharacterData" load_steps={steps} format=3]\n\n'
            + "\n".join(ext) + "\n\n" + "\n".join(subs) + "\n" + "\n".join(res) + "\n")
    os.makedirs(os.path.join(ROOT, "characters", key), exist_ok=True)
    with open(os.path.join(ROOT, "characters", key, f"{key}_data.tres"), "w") as f:
        f.write(text)


if __name__ == "__main__":
    for key, ch in CHARACTERS.items():
        write(key, ch)
    print("wrote", ", ".join(CHARACTERS))
