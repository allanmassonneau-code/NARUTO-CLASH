#!/usr/bin/env python3
"""Reads the game-design bible (docs/BIBLE_JUTSU.md, pandoc export of
"Bible Game Design - Jutsu, Natures, Clans, Sub-jutsu") and writes
data/progression/bible.json: natures, clans and sub-jutsu with their names,
texts and design tags, plus the engine tags / costs the combat factory uses.
tools/progression_content.py then merges it into content.json.
    pandoc bible.docx -t markdown -o docs/BIBLE_JUTSU.md
    python3 tools/bible_import.py
"""
import json, os, re, unicodedata

ROOT = os.path.join(os.path.dirname(__file__), "..")
SOURCE = os.path.join(ROOT, "docs", "BIBLE_JUTSU.md")
OUT = os.path.join(ROOT, "data", "progression", "bible.json")

# Balancing placeholders (the bible leaves numbers to balancing).
CHAKRA = {"D": 12, "C": 20, "B": 28, "A": 40, "S": 70}
COOLDOWN = {"D": 6, "C": 10, "B": 14, "A": 20, "S": 32}

# Bible tag keyword -> engine tags (JutsuAbilityFactory picks the executor).
TAG_RULES = [
    (("projectile", "skillshot", "poke", "ricochet", "tir", "lancer", "kunai", "shuriken"), ["RANGED", "PROJECTILE"]),
    (("ligne", "rayon", "laser", "perçant"), ["RANGED", "HITSCAN"]),
    (("zone", "domaine", "terrain", "piège", "trap", "cône", "mur", "node", "réseau", "propagation", "dôme",
      "aoe", "glyphe", "pluie"), ["AOE"]),
    (("mêlée", "finisher", "duel", "exécution", "combo", "stance", "corps à corps", "frappe"), ["MELEE"]),
    (("mobilité", "dash", "téléportation", "reposition", "swap", "engage", "charge"), ["MOVEMENT", "DASH"]),
    (("contrôle", "root", "tether", "chaîne", "knockback", "stun", "immobilisation", "capture", "freeze", "pull",
      "grab", "entrave"), ["CC"]),
    (("launcher", "launch"), ["LAUNCH", "CC"]),
    (("parade", "contre", "riposte"), ["COUNTER"]),
    (("cover", "défense", "bouclier", "armor", "ténacité", "protection", "anti-projectile", "barrière"), ["DEFENSIVE"]),
    (("self-buff", "buff", "transformation", "mode", "tempo", "éveil", "invocation", "summon", "decoy"), ["BUFF"]),
    (("sustain", "soin", "heal", "régénération"), ["HEAL"]),
    (("marque", "mark", "anti-heal", "debuff", "poison", "malus", "vision", "reveal", "illusion", "genjutsu"), ["DEBUFF"]),
    (("dot", "brûlure", "saignement", "hémorragie"), ["DOT"]),
    (("hitscan",), ["RANGED", "HITSCAN"]),
    (("boomerang", "rebond", "throw"), ["RANGED", "PROJECTILE"]),
    (("vague", "noyau", "détonation", "coupe", "corridor", "télégraphe", "prison"), ["AOE"]),
    (("déplacement forcé", "recul", "guard break", "prison"), ["CC"]),
    (("heavy attack",), ["MELEE"]),
    (("teleport",), ["MOVEMENT", "DASH"]),
    (("interception",), ["DEFENSIVE"]),
    (("toggle", "information", "copie", "adaptation", "avatar", "séquence", "rythme", "heat", "cooldown",
      "stored", "multi-body", "clones"), ["BUFF"]),
    (("faux", "cible"), ["DEBUFF"]),
]
LAUNCH_TEXT = re.compile(r"vers le haut|projette(?:nt)? (?:brièvement )?(?:la cible |les cibles )?en l'air|soulève", re.I)

FIELDS = {
    "Identité": "identity", "Mécanique signature": "signature", "Tags": "tags",
    "Activation et fonctionnement": "activation", "Mécanique réelle": "mechanic",
    "Synergies / intérêt": "synergies", "Contre-jeu": "counter",
}


def slug(text):
    t = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode().lower()
    return re.sub(r"_+", "_", "".join(c if c.isalnum() else "_" for c in t)).strip("_")


def clean(text):
    text = text.replace("\\'", "'").replace('\\"', '"').replace("\\", "").replace("**", "")
    return re.sub(r"\s+", " ", text).replace(" ---", " —").replace("--- ", "— ").strip()


def first_sentence(text):
    m = re.match(r"(.+?[.!?])(\s|$)", text)
    return m.group(1) if m else text


def engine_tags(entry):
    words = " ".join(entry["design_tags"]).lower()
    tags = []
    for keys, add in TAG_RULES:
        if any(k in words for k in keys):
            tags += [t for t in add if t not in tags]
    if LAUNCH_TEXT.search(entry.get("activation", "") + " " + entry.get("mechanic", "")) and "LAUNCH" not in tags:
        tags += ["LAUNCH"] + (["CC"] if "CC" not in tags else [])
    return tags or ["MELEE"]


def blocks(md):
    for block in re.split(r"\n\s*\n", md):
        line = " ".join(l.strip() for l in block.strip().splitlines())
        if line:
            yield line


def parse(md):
    natures, clans, subs = {}, {}, []
    section = village = kit = None
    sub_rank = None
    current = None  # technique being filled
    for line in blocks(md):
        h = re.match(r"^(#+)\s+(.*)$", line)
        if h:
            level, title = len(h.group(1)), clean(h.group(2))
            current = None
            if level == 1:
                section = "natures" if title.startswith("4.") else "clans" if title.startswith("5.") else \
                    "subs" if title.startswith("6.") else None
            elif level == 2 and section == "natures":
                kit = natures.setdefault(slug(title), {"name": title, "jutsu": []})
            elif level == 2 and section == "clans":
                village = slug(title)
            elif level == 3 and section == "clans":
                kit = clans.setdefault(slug(title), {"name": title, "village": village, "jutsu": []})
            elif level == 2 and section == "subs":
                sub_rank = title.split()[-1]
            continue
        head = re.match(r"^\*\*([DCBAS]) --- (.+?)\*\*$", line)
        if head and section in ("natures", "clans", "subs"):
            current = {"rank": head.group(1), "name": clean(head.group(2)), "design_tags": []}
            (subs if section == "subs" else kit["jutsu"]).append(current)
            continue
        field = re.match(r"^\*\*(.+?) :\*\*\s*(.*)$", line)
        if not field or section is None:
            continue
        key, text = FIELDS.get(clean(field.group(1))), clean(field.group(2))
        if key is None:
            continue
        if key in ("identity", "signature") and kit is not None and current is None:
            kit[key] = text.replace("Mécanique centrale — ", "")
        elif current is not None:
            if key == "tags":
                current["design_tags"] = [t.strip() for t in text.split(",") if t.strip()]
            else:
                current[key] = text
    return natures, clans, subs


def finish(j, prefix):
    j["id"] = f"{prefix}_{j['rank'].lower()}_{slug(j['name'])}"
    j["description"] = first_sentence(j.get("activation", ""))
    j["tags"] = engine_tags(j)
    j["chakra_cost"] = CHAKRA[j["rank"]]
    j["cooldown"] = COOLDOWN[j["rank"]]
    return j


def main():
    natures, clans, subs = parse(open(SOURCE, encoding="utf-8").read())
    for nid, n in natures.items():
        n["jutsu"] = [finish(j, nid) for j in n["jutsu"]]
    for cid, c in clans.items():
        c["jutsu"] = [finish(j, f"clan_{cid}") for j in c["jutsu"]]
    subs = [finish(j, "sub") for j in subs]
    counts = (sum(len(n["jutsu"]) for n in natures.values()), sum(len(c["jutsu"]) for c in clans.values()), len(subs))
    assert counts == (50, 100, 30), counts
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump({"natures": natures, "clans": clans, "sub_jutsu": subs}, f, ensure_ascii=False, indent=1)
    print("bible.json: %d nature, %d clan, %d sub-jutsu techniques" % counts)


if __name__ == "__main__":
    main()
