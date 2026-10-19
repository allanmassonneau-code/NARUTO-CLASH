#!/usr/bin/env python3
"""Generates characters/<id>/<id>_data.tres (stats, kits, looks).

Balancing lives here so every kit is visible side by side. The .tres files
stay editable in the Godot inspector; re-running this overwrites them.
    python3 tools/generate_characters.py
"""
import os

ROOT = os.path.join(os.path.dirname(__file__), "..")
KIND = {"MELEE": 0, "PROJ": 1, "DASH": 2, "AREA": 3, "COUNTER": 4, "HEAL": 5}


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
    return ab("Shunshin", "DASH", c(0.8, 0.9, 1), startup_time=0.03, active_time=0.14, recovery_time=0.08,
              cooldown=cd, dash_distance=dist, dash_immaterial=True, cast_move_multiplier=1.0,
              recovery_move_multiplier=1.0, can_cancel_during_startup=False)


def melee_hit(name, color, dmg, rng=1.9, arc=100.0, startup=0.08, rec=0.14, lunge=0.5, **kw):
    return ab(name, "MELEE", color, startup_time=startup, active_time=0.05, recovery_time=rec,
              max_range=rng, arc_degrees=arc, damage=dmg, lunge_distance=lunge,
              cast_move_multiplier=0.55, recovery_move_multiplier=0.85, combo_window=0.45, **kw)


CHARACTERS = {
    "naruto": dict(
        display_name="Naruto Uzumaki", body_color=c(1, 0.5, 0.05), max_health=135.0, speed=7.0,
        identity="Aggressive pressure fighter. Taijutsu strings into Rasengan, Kawarimi baits commitment.",
        look=dict(skin=c(0.98, 0.8, 0.64), top=c(1, 0.5, 0.1), top_accent=c(0.1, 0.1, 0.14), sleeves=c(1, 0.5, 0.1),
                  pants=c(1, 0.5, 0.1), accent=c(0.12, 0.12, 0.18), hair_color=c(1, 0.85, 0.2), hair=0,
                  eye_color=c(0.15, 0.45, 0.95), whiskers=True),
        kit=dict(
            lmb=combo(melee_hit("Taijutsu", c(1, 0.7, 0.3), 6.0),
                      melee_hit("Taijutsu II", c(1, 0.7, 0.3), 6.0),
                      melee_hit("Uzumaki Kick", c(1, 0.6, 0.2), 11.0, rng=2.1, startup=0.12, rec=0.3, lunge=0.9,
                                knockback_speed=10.0, knockback_duration=0.2)),
            rmb=ab("Rasengan", "DASH", c(0.3, 0.6, 1), startup_time=0.3, active_time=0.2, recovery_time=0.32, cooldown=6.0,
                   dash_distance=4.5, hit_radius=0.7, damage=24.0, knockback_speed=13.0, knockback_duration=0.24,
                   cast_move_multiplier=0.3, recovery_move_multiplier=0.5),
            space=shunshin(6.0, 7.0),
            q=ab("Kawarimi no Jutsu", "COUNTER", c(0.6, 0.4, 0.2), startup_time=0.02, active_time=0.8, recovery_time=0.15,
                 cooldown=11.0, counter_teleport_distance=4.5, cast_move_multiplier=0.4, energy_gain_on_hit=10.0,
                 can_cancel_during_startup=False),
            e=ab("Kage Bunshin Rush", "PROJ", c(1, 0.55, 0.1), startup_time=0.22, active_time=0.05, recovery_time=0.22,
                 cooldown=8.0, max_range=11.0, hit_radius=0.5, projectile_speed=14.0, damage=8.0, stun_duration=0.8,
                 cast_move_multiplier=0.4),
            ult=ab("Rasenshuriken", "PROJ", c(0.6, 0.9, 1), startup_time=0.5, active_time=0.05, recovery_time=0.35,
                   energy_cost=100.0, max_range=14.0, hit_radius=1.0, projectile_speed=16.0, damage=36.0,
                   knockback_speed=9.0, cast_move_multiplier=0.2),
        )),
    "sasuke": dict(
        display_name="Sasuke Uchiha", body_color=c(0.25, 0.35, 0.85), max_health=130.0, speed=7.1,
        identity="Precise melee duelist. Kusanagi strings, Chidori punishes, Katon zones, Sharingan reads.",
        look=dict(skin=c(0.98, 0.85, 0.74), top=c(0.9, 0.9, 0.93), top_accent=c(0.35, 0.3, 0.5), sleeves=c(0.9, 0.9, 0.93),
                  pants=c(0.2, 0.22, 0.32), accent=c(0.45, 0.3, 0.6), hair_color=c(0.08, 0.09, 0.16), hair=1,
                  eye_color=c(0.85, 0.05, 0.05), headband=False, weapon=1),
        kit=dict(
            lmb=combo(melee_hit("Kusanagi", c(0.8, 0.85, 1), 7.0, rng=2.3, arc=120.0, startup=0.09, rec=0.15, lunge=0.6),
                      melee_hit("Kusanagi II", c(0.8, 0.85, 1), 7.0, rng=2.3, arc=120.0, startup=0.09, rec=0.15, lunge=0.6),
                      melee_hit("Kusanagi Thrust", c(0.6, 0.8, 1), 12.0, rng=2.9, arc=45.0, startup=0.14, rec=0.32,
                                lunge=1.3, knockback_speed=7.0)),
            rmb=ab("Chidori", "DASH", c(0.4, 0.85, 1), startup_time=0.3, active_time=0.22, recovery_time=0.38, cooldown=7.0,
                   dash_distance=6.5, hit_radius=0.7, damage=20.0, stun_duration=0.6, cast_move_multiplier=0.3,
                   recovery_move_multiplier=0.5),
            space=shunshin(5.5, 8.0),
            q=ab("Sharingan Counter", "COUNTER", c(0.9, 0.1, 0.1), startup_time=0.02, active_time=0.9, recovery_time=0.2,
                 cooldown=12.0, counter_stun_attacker=1.2, cast_move_multiplier=0.3, energy_gain_on_hit=10.0,
                 can_cancel_during_startup=False),
            e=ab("Katon: Goukakyuu", "PROJ", c(1, 0.35, 0.1), startup_time=0.35, active_time=0.05, recovery_time=0.3,
                 cooldown=8.0, max_range=10.0, hit_radius=0.9, projectile_speed=14.0, damage=16.0, knockback_speed=5.0,
                 cast_move_multiplier=0.3),
            ult=ab("Kirin", "AREA", c(0.5, 0.8, 1), startup_time=0.4, active_time=0.05, recovery_time=0.3, energy_cost=100.0,
                   max_range=11.0, hit_radius=3.0, area_delay=1.1, damage=40.0, stun_duration=0.5, cast_move_multiplier=0.3),
        )),
    "sakura": dict(
        display_name="Sakura Haruno", body_color=c(1, 0.45, 0.7), max_health=150.0, speed=6.8,
        identity="Melee bruiser / combat healer. Heavy punches, heals limited by recoverable health.",
        look=dict(skin=c(0.99, 0.84, 0.74), top=c(0.82, 0.12, 0.2), top_accent=c(0.95, 0.95, 0.95), sleeves=c(0.99, 0.84, 0.74),
                  pants=c(0.12, 0.12, 0.15), accent=c(0.6, 0.6, 0.65), hair_color=c(1, 0.55, 0.75), hair=2,
                  eye_color=c(0.2, 0.65, 0.3), gloves=c(0.15, 0.15, 0.18), shorts=True),
        kit=dict(
            lmb=combo(melee_hit("Chakra Punch", c(1, 0.6, 0.8), 8.0, rng=2.0, arc=110.0, startup=0.12, rec=0.18),
                      melee_hit("Chakra Punch II", c(1, 0.6, 0.8), 8.0, rng=2.0, arc=110.0, startup=0.12, rec=0.18),
                      melee_hit("Shannaro!", c(1, 0.35, 0.55), 14.0, rng=2.3, arc=90.0, startup=0.18, rec=0.34, lunge=0.9,
                                knockback_speed=13.0, knockback_duration=0.25)),
            rmb=ab("Oukashou", "AREA", c(1, 0.4, 0.6), startup_time=0.25, active_time=0.05, recovery_time=0.3, cooldown=7.0,
                   max_range=5.0, hit_radius=2.2, area_delay=0.4, damage=20.0, stun_duration=0.7, cast_move_multiplier=0.3),
            space=ab("Chakra Leap", "DASH", c(1, 0.7, 0.85), startup_time=0.08, active_time=0.28, recovery_time=0.12,
                     cooldown=9.0, dash_distance=6.5, dash_immaterial=True, cast_move_multiplier=1.0,
                     can_cancel_during_startup=False),
            q=ab("Mystical Palm", "HEAL", c(0.4, 1, 0.5), startup_time=0.55, active_time=0.05, recovery_time=0.2,
                 cooldown=12.0, heal_amount=24.0, cast_move_multiplier=0.3),
            e=ab("Heel Drop", "MELEE", c(1, 0.3, 0.5), startup_time=0.22, active_time=0.05, recovery_time=0.3, cooldown=6.0,
                 max_range=2.4, arc_degrees=80.0, damage=12.0, stun_duration=0.5, lunge_distance=1.4,
                 cast_move_multiplier=0.4),
            ult=ab("Byakugou Seal", "HEAL", c(0.6, 0.3, 1), startup_time=0.5, active_time=0.05, recovery_time=0.2,
                   energy_cost=100.0, heal_amount=55.0, true_heal=True, cast_move_multiplier=0.2),
        )),
    "kakashi": dict(
        display_name="Kakashi Hatake", body_color=c(0.7, 0.72, 0.78), max_health=130.0, speed=7.0,
        identity="Versatile technical fighter. Kunai poke, Ninken roots set up Raikiri, Kamui is a delayed read.",
        look=dict(skin=c(0.95, 0.8, 0.66), top=c(0.16, 0.2, 0.35), top_accent=c(0.36, 0.45, 0.27), sleeves=c(0.16, 0.2, 0.35),
                  pants=c(0.16, 0.2, 0.35), accent=c(0.1, 0.1, 0.14), hair_color=c(0.86, 0.88, 0.92), hair=3,
                  eye_color=c(0.1, 0.1, 0.12), mask=True, flak_vest=True, gloves=c(0.12, 0.12, 0.15)),
        kit=dict(
            lmb=ab("Kunai", "PROJ", c(0.75, 0.75, 0.8), startup_time=0.1, active_time=0.03, recovery_time=0.18,
                   max_range=12.0, hit_radius=0.22, projectile_speed=28.0, damage=6.0, cast_move_multiplier=0.65),
            rmb=ab("Raikiri", "DASH", c(0.5, 0.85, 1), startup_time=0.4, active_time=0.25, recovery_time=0.4, cooldown=7.0,
                   dash_distance=7.0, hit_radius=0.7, damage=26.0, knockback_speed=8.0, cast_move_multiplier=0.25,
                   recovery_move_multiplier=0.5),
            space=shunshin(5.5, 8.0),
            q=ab("Kawarimi no Jutsu", "COUNTER", c(0.6, 0.4, 0.2), startup_time=0.02, active_time=0.7, recovery_time=0.15,
                 cooldown=11.0, counter_teleport_distance=4.0, cast_move_multiplier=0.4, energy_gain_on_hit=10.0,
                 can_cancel_during_startup=False),
            e=ab("Summoning: Ninken", "AREA", c(0.6, 0.5, 0.3), startup_time=0.2, active_time=0.05, recovery_time=0.25,
                 cooldown=10.0, max_range=9.0, hit_radius=1.6, area_delay=0.45, damage=6.0, root_duration=1.6,
                 cast_move_multiplier=0.4),
            ult=ab("Kamui", "AREA", c(0.4, 0.2, 0.6), startup_time=0.5, active_time=0.05, recovery_time=0.4,
                   energy_cost=100.0, max_range=10.0, hit_radius=2.4, area_delay=1.2, damage=45.0,
                   cast_move_multiplier=0.25),
        )),
}


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

    def emit(slot, a, idx):
        """Emits `a` (and its combo chain, last hit first) and returns its id."""
        next_id = emit(slot, a["combo_next"], idx + 1) if "combo_next" in a else None
        rid = slot if idx == 0 else f"{slot}_{idx}"
        body = f'[sub_resource type="Resource" id="{rid}"]\nscript = ExtResource("2")\nicon = ExtResource("icon_{slot}")\n'
        for k, v in a.items():
            if k != "combo_next":
                body += f"{k} = {val(v)}\n"
        if next_id:
            body += f'combo_next = SubResource("{next_id}")\n'
        subs.append(body)
        return rid

    slots = {}
    for slot, a in ch["kit"].items():
        slots[slot] = emit(slot, a[0] if isinstance(a, list) else a, 0)

    res = ['[resource]', 'script = ExtResource("1")', f'display_name = "{ch["display_name"]}"',
           f'identity = "{ch["identity"]}"', f'body_color = {ch["body_color"]}', f'max_health = {ch["max_health"]}',
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
