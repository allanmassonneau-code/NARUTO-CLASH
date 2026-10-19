#!/usr/bin/env python3
"""Generates placeholder jutsu icons (SVG) into ui/icons/.

Each icon = rounded square tinted with the jutsu colour + a white glyph.
Re-run after adding a jutsu:  python3 tools/generate_icons.py
"""
import math
import os

OUT = os.path.join(os.path.dirname(__file__), "..", "ui", "icons")

W = "#ffffff"
INK = "#1b1b24"


def star(cx, cy, r_out, r_in, n, rot=0.0):
    pts = []
    for i in range(n * 2):
        r = r_out if i % 2 == 0 else r_in
        a = rot + math.pi * i / n
        pts.append(f"{cx + r * math.sin(a):.1f},{cy - r * math.cos(a):.1f}")
    return " ".join(pts)


def spiral(cx, cy, turns, r_max, width, color):
    pts = []
    steps = int(turns * 40)
    for i in range(steps + 1):
        t = i / steps
        a = t * turns * 2 * math.pi
        r = t * r_max
        pts.append(f"{cx + r * math.cos(a):.1f},{cy + r * math.sin(a):.1f}")
    return f'<polyline points="{" ".join(pts)}" fill="none" stroke="{color}" stroke-width="{width}" stroke-linecap="round"/>'


GLYPHS = {
    "fist": f'''<rect x="38" y="44" width="52" height="40" rx="12" fill="{W}"/>
<rect x="38" y="80" width="40" height="22" rx="6" fill="{W}"/>
<path d="M52 44v20M64 44v20M76 44v20" stroke="{INK}" stroke-width="4"/>
<path d="M22 50h10M18 64h14M22 78h10" stroke="{W}" stroke-width="5" stroke-linecap="round"/>''',
    "kunai": f'''<g transform="rotate(-45 64 64)"><polygon points="64,14 76,58 64,68 52,58" fill="{W}"/>
<rect x="60" y="68" width="8" height="30" fill="{INK}" stroke="{W}" stroke-width="2"/>
<circle cx="64" cy="106" r="8" fill="none" stroke="{W}" stroke-width="5"/></g>''',
    "swirl": f'''<circle cx="64" cy="64" r="34" fill="{W}" fill-opacity="0.25"/>
{spiral(64, 64, 2.6, 34, 7, W)}''',
    "dash": f'''<path d="M30 64h46M22 46h36M22 82h36" stroke="{W}" stroke-width="7" stroke-linecap="round" stroke-opacity="0.7"/>
<polygon points="74,36 106,64 74,92 84,64" fill="{W}"/>''',
    "log": f'''<g transform="rotate(-20 64 64)"><rect x="30" y="48" width="64" height="32" rx="6" fill="#8a5a2e" stroke="{W}" stroke-width="4"/>
<ellipse cx="94" cy="64" rx="9" ry="16" fill="#c79a62" stroke="{W}" stroke-width="4"/></g>
<path d="M24 30l10 8M104 98l-10-8M28 100l10-6" stroke="{W}" stroke-width="5" stroke-linecap="round"/>''',
    "clones": f'''<g fill="{W}"><circle cx="44" cy="44" r="12"/><rect x="32" y="58" width="24" height="40" rx="10"/>
<circle cx="84" cy="44" r="12" fill-opacity="0.6"/><rect x="72" y="58" width="24" height="40" rx="10" fill-opacity="0.6"/></g>
<path d="M58 30l12 0" stroke="{W}" stroke-width="5" stroke-linecap="round"/>''',
    "rasenshuriken": f'''<polygon points="{star(64, 64, 50, 14, 4, math.pi / 4)}" fill="{W}" fill-opacity="0.85"/>
<circle cx="64" cy="64" r="16" fill="#4fa3ff" stroke="{W}" stroke-width="4"/>
{spiral(64, 64, 1.6, 14, 3, W)}''',
    "fireball": f'''<path d="M64 20c10 18 34 26 34 54a34 34 0 0 1-68 0c0-14 8-22 14-28 0 10 6 16 12 16-6-16 0-30 8-42z" fill="#ffd34d"/>
<path d="M64 52c6 10 18 14 18 28a18 18 0 0 1-36 0c0-8 6-14 10-16 0 6 4 10 8 10-2-8 0-16 0-22z" fill="{W}"/>''',
    "sharingan": f'''<ellipse cx="64" cy="64" rx="48" ry="28" fill="{W}"/>
<circle cx="64" cy="64" r="24" fill="#d01818"/><circle cx="64" cy="64" r="14" fill="none" stroke="{INK}" stroke-width="3"/>
<circle cx="64" cy="64" r="6" fill="{INK}"/>
<g fill="{INK}"><circle cx="64" cy="50" r="4"/><circle cx="76" cy="71" r="4"/><circle cx="52" cy="71" r="4"/></g>''',
    "bolt": f'''<polygon points="72,14 34,72 60,72 50,114 96,52 68,52 82,14" fill="{W}"/>''',
    "kirin": f'''<ellipse cx="64" cy="30" rx="44" ry="16" fill="{W}" fill-opacity="0.5"/>
<polygon points="70,36 46,78 64,78 54,116 90,66 72,66 82,36" fill="{W}"/>
<ellipse cx="60" cy="112" rx="34" ry="8" fill="none" stroke="{W}" stroke-width="4"/>''',
    "crack": f'''<ellipse cx="64" cy="92" rx="48" ry="16" fill="{W}" fill-opacity="0.3"/>
<path d="M64 92L50 60 60 46M64 92l22-30 -4-18M64 92l-34 4M64 92l30 12M64 92l-6 22" stroke="{W}" stroke-width="6" fill="none" stroke-linecap="round" stroke-linejoin="round"/>
<rect x="48" y="16" width="32" height="26" rx="8" fill="{W}"/>''',
    "leap": f'''<path d="M24 100 Q64 10 104 100" fill="none" stroke="{W}" stroke-width="7" stroke-dasharray="10 8" stroke-linecap="round"/>
<polygon points="104,100 88,92 104,80" fill="{W}"/><circle cx="64" cy="40" r="10" fill="{W}"/>''',
    "heal": f'''<circle cx="64" cy="64" r="38" fill="{W}" fill-opacity="0.25"/>
<path d="M64 36v56M36 64h56" stroke="{W}" stroke-width="16" stroke-linecap="round"/>''',
    "kick": f'''<path d="M28 34l34 30 h30 a10 10 0 0 1 0 20 H54 L20 52z" fill="{W}"/>
<path d="M104 56l12-8M106 74h14M104 92l12 8" stroke="{W}" stroke-width="5" stroke-linecap="round"/>''',
    "seal": f'''<polygon points="64,16 104,64 64,112 24,64" fill="none" stroke="{W}" stroke-width="7"/>
<polygon points="64,40 84,64 64,88 44,64" fill="{W}"/>''',
    "paw": f'''<g fill="{W}"><ellipse cx="64" cy="80" rx="22" ry="18"/><ellipse cx="38" cy="54" rx="9" ry="12"/>
<ellipse cx="54" cy="40" rx="9" ry="12"/><ellipse cx="74" cy="40" rx="9" ry="12"/><ellipse cx="90" cy="54" rx="9" ry="12"/></g>''',
    "kamui": f'''<circle cx="64" cy="64" r="46" fill="{INK}" fill-opacity="0.45"/>
{spiral(64, 64, 2.2, 44, 6, W)}<circle cx="64" cy="64" r="6" fill="{W}"/>''',
}

# (file id, glyph, colour) — colours match the jutsu colour in the .tres files.
ICONS = {
    "naruto_lmb": ("fist", "#ffb34d"),
    "naruto_rmb": ("swirl", "#4d99ff"),
    "naruto_space": ("dash", "#9fb7d9"),
    "naruto_q": ("log", "#99663a"),
    "naruto_e": ("clones", "#ff8c1a"),
    "naruto_ult": ("rasenshuriken", "#7fd0ff"),
    "sasuke_lmb": ("kunai", "#8c8c99"),
    "sasuke_rmb": ("fireball", "#ff4d1a"),
    "sasuke_space": ("dash", "#9fb7d9"),
    "sasuke_q": ("sharingan", "#b31a1a"),
    "sasuke_e": ("bolt", "#33b3e6"),
    "sasuke_ult": ("kirin", "#6699ff"),
    "sakura_lmb": ("fist", "#ff8cc6"),
    "sakura_rmb": ("crack", "#e6668c"),
    "sakura_space": ("leap", "#ffa6cc"),
    "sakura_q": ("heal", "#4dcc66"),
    "sakura_e": ("kick", "#e6407a"),
    "sakura_ult": ("seal", "#8c4de6"),
    "kakashi_lmb": ("kunai", "#8c8c99"),
    "kakashi_rmb": ("bolt", "#4dbfff"),
    "kakashi_space": ("dash", "#9fb7d9"),
    "kakashi_q": ("log", "#99663a"),
    "kakashi_e": ("paw", "#998052"),
    "kakashi_ult": ("kamui", "#6633a6"),
}


def icon_svg(glyph: str, color: str) -> str:
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
<defs><radialGradient id="g" cx="50%" cy="35%" r="75%"><stop offset="0" stop-color="{color}"/><stop offset="1" stop-color="{INK}"/></radialGradient></defs>
<rect x="3" y="3" width="122" height="122" rx="18" fill="url(#g)" stroke="{color}" stroke-width="4"/>
{GLYPHS[glyph]}
</svg>
'''


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    for name, (glyph, color) in ICONS.items():
        with open(os.path.join(OUT, f"{name}.svg"), "w") as f:
            f.write(icon_svg(glyph, color))
    print(f"wrote {len(ICONS)} icons to {os.path.normpath(OUT)}")


if __name__ == "__main__":
    main()
