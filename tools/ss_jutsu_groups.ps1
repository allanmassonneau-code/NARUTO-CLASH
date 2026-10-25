# Groups every Shinobi Striker jutsu (256, _SS_REFERENCE\extracted\jutsu\ss_jutsu.tsv) by chakra nature and
# by clan / lineage of the SS character who owns it, and marks where NARUTO-CLASH uses it (tools/ss_kits.txt).
# Writes data/progression/ss_jutsu_groups.json and docs/SS_JUTSU_PAR_NATURE_ET_CLAN.md.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$tsv = Join-Path $root "_SS_REFERENCE\extracted\jutsu\ss_jutsu.tsv"
$utf8 = New-Object Text.UTF8Encoding $false

# SS character of a jutsu id prefix (DLC codes from the SS figures: SK_CHR_<code>)
$chars = @{
    ENTRY = "Base (tous les ninjas)"; ADVANCED = "Base (avancé)"; BASIC = "Base"; Naruto = "Naruto Uzumaki"; Sasuke = "Sasuke Uchiha"; Sakura = "Sakura Haruno"
    Sai = "Sai"; Kakashi = "Kakashi Hatake"; Yamato = "Yamato"; Lee = "Rock Lee"; Shikamaru = "Shikamaru Nara"; Choji = "Choji Akimichi"; Hinata = "Hinata Hyuga"
    Gaara = "Gaara"; Deidara = "Deidara"; Kisame = "Kisame Hoshigaki"; Pain = "Pain"; Itachi = "Itachi Uchiha"; Kabuto = "Kabuto Yakushi"; Konan = "Konan"
    Boruto = "Boruto Uzumaki"; Sarada = "Sarada Uchiha"; Mitsuki = "Mitsuki"; Jiraiya = "Jiraiya"; Hiruzen = "Hiruzen Sarutobi"; Madara = "Madara Uchiha"
    Orochimaru = "Orochimaru"; Tobirama = "Tobirama Senju"; Obito = "Obito Uchiha"; Minato = "Minato Namikaze"; Tsunade = "Tsunade"; Hashirama = "Hashirama Senju"
    D21 = "Naruto Uzumaki (BORUTO)"; D22 = "Killer Bee"; D23 = "Sasuke Uchiha (BORUTO)"; D24 = "Mei Terumi"; D25 = "Zabuza Momochi"; D26 = "Ohnoki"; D27 = "Haku"
    D28 = "Might Guy"; D29 = "Ino Yamanaka"; D31 = "Kakashi Hatake (Double Sharingan)"; D32 = "Neji Hyuga"; D33 = "Shisui Uchiha"; D34 = "Naruto Uzumaki (Last Battle)"
    D35 = "Boruto Uzumaki (Karma)"; D41 = "Sakura Haruno (Grande Guerre)"; D42 = "Nagato (Réincarnation)"; D43 = "Itachi Uchiha (Réincarnation)"
    D44 = "Sasuke Uchiha (Last Battle)"; D45 = "Kawaki"; D51 = "Madara Uchiha (Six Chemins)"; D52 = "Temari"; D53 = "Konohamaru Sarutobi (BORUTO)"
    D54 = "Naruto Uzumaki (Mode Baryon)"; D55 = "Isshiki Otsutsuki"; D61 = "Minato Namikaze (Réincarnation)"; D62 = "Obito Uchiha (Jinchûriki de Jûbi)"
    D63 = "Kaguya Otsutsuki"; D71 = "Boruto Uzumaki (Karma, évolution)"; D72 = "Gaara (jeune)"; D73 = "Sasori"; D81 = "Kawaki (Karma, évolution)"
    D82 = "Shisui Uchiha (Susanô parfait)"; D83 = "Naruto Uzumaki (jeune)"; D84 = "Sasuke Uchiha (jeune, combat final)"; D91 = "Hidan"; D92 = "Kakuzu"
    D93 = "Personnage DLC D93"; D94 = "Kimimaro"; D101 = "Jiraiya (Mode Ermite)"; D102 = "Naruto Uzumaki (Mode Ermite)"
}
# Clan / lineage of a character (by name)
$clans = [ordered]@{
    "Uchiha" = "Uchiha|Sasuke|Itachi|Madara|Obito|Shisui|Sarada"; "Uzumaki" = "Uzumaki|Naruto|Boruto|Nagato"; "Senju" = "Senju|Hashirama|Tobirama|Tsunade"
    "Hyûga" = "Hyuga|Hinata|Neji"; "Nara" = "Nara|Shikamaru"; "Akimichi" = "Akimichi|Choji"; "Yamanaka" = "Yamanaka|Ino"; "Sarutobi" = "Sarutobi|Hiruzen|Konohamaru"
    "Namikaze" = "Namikaze|Minato"; "Hoshigaki" = "Hoshigaki|Kisame"; "Kaguya" = "Kimimaro"; "Ôtsutsuki" = "Otsutsuki|Isshiki|Kaguya"
    "Sabaku (Suna)" = "Gaara|Temari"; "Marionnettistes (Suna)" = "Sasori"; "Akatsuki" = "Deidara|Konan|Pain|Hidan|Kakuzu"; "Yuki" = "Haku"
    "Épéistes de la Brume" = "Zabuza"; "Kiri (Mei)" = "Mei Terumi"; "Iwa (Tsuchikage)" = "Ohnoki"; "Kumo (jinchûriki)" = "Killer Bee"
    "Sannin / Ermites" = "Jiraiya|Orochimaru|Mitsuki|Kabuto"; "Kara" = "Kawaki"; "Équipe Kakashi / Konoha" = "Kakashi|Sakura|Sai|Yamato|Rock Lee|Might Guy"
}
# Chakra nature (French SS name prefix, then keywords)
$natures = [ordered]@{
    "Katon (feu)" = "^Katon|Enton|\bFeu\b|Flamme|Embrasement|Balsamine|Boule de feu|Météore|Kagutsuchi|Amaterasu|Lumière céleste|Nuées ardentes|Enra|Cendres"
    "Suiton (eau)" = "^Suiton|aqueu|Requin|\bEau\b|Ondulation|Brume|Brouillard"
    "Raiton (foudre)" = "^Raiton|Foudre|Éclair|Mille oiseaux|Kirin|Chidori|Lariat|Pétrification|Inton"
    "Doton (terre)" = "^Doton|\bTerre\b|Pierre|Boue|Rocher|Jinton|Voyage souterrain|Solidification"
    "Fûton (vent)" = "^F[ûu]ton|Vent|Tornade|Orbe shuriken|Percée|Bourrasque|Rafale|Paume céleste"
    "Mokuton (bois)" = "^Mokuton|\bBois\b|Moine souriant|Forêt"; "Hyôton (glace)" = "Hyôton|Glace|Miroirs"; "Yôton (lave)" = "Yôton"; "Futton (vapeur)" = "Futton"
    "Sable" = "Sable|Mausolée|Sarcophage"; "Ombre" = "Ombre"; "Sceaux (Fûinjutsu)" = "Fûinjutsu|Sceau|Parchemin"
    "Orbe tourbillonnant (Rasengan)" = "Orbe tourbillonnant|Orbes tourbillonnants"; "Espace-temps" = "Hiraishin|Autorité divine|Limbes|Disparition|Espace"
    "Médical / soin" = "Soin|curative|Régénération|Purification|Création et le Renouveau|Limace|Pluie verte|Canon floral"
    "Taijutsu" = "Konoha|Porte|verrous|Coup de pied|Choc du cerisier|Hakke|Poing|Paume|Jeunesse|Sept cieux"
    "Invocation" = "Invocation"; "Genjutsu / pupille" = "Genjutsu|Sharingan|Byakugan|Izanami|Kotoamatsukami|Arcanes"
}
$kits = @{}
foreach ($l in Get-Content (Join-Path $PSScriptRoot "ss_kits.txt") -Encoding UTF8) {
    $l = $l.Trim(); if ($l -eq "" -or $l.StartsWith("#")) { continue }
    $p = $l -split "\s+"; if (-not $kits.ContainsKey($p[2])) { $kits[$p[2]] = @() }; $kits[$p[2]] += "$($p[0]) ($($p[1]))"
}
$rows = foreach ($l in Get-Content $tsv -Encoding UTF8) {
    $p = $l -split "`t"; if ($p.Count -lt 10) { continue }
    $prefix = ($p[0] -replace '(NJ\d.*|_\d+.*)$', '')
    $char = $(if ($chars.ContainsKey($prefix)) { $chars[$prefix] } else { $prefix })
    $nat = @($natures.Keys | Where-Object { $p[1] -match $natures[$_] })
    if ($nat.Count -eq 0) { $nat = @("Autre") }
    $clan = @($clans.Keys | Where-Object { $char -match $clans[$_] }) | Select-Object -First 1
    if (-not $clan) { $clan = $(if ($char -like "Base*") { "Base (tous les ninjas)" } else { "Autre" }) }
    [pscustomobject][ordered]@{ ss_id = $p[0]; name = $p[1]; character = $char; clan = $clan; natures = $nat; type = $p[2]; category = $p[3]
        cooldown = [double]$p[4]; power = [int]$p[5]; reach = [int]$p[6]; icon = $p[7]; description = $p[9].Trim()
        in_game = @($kits[$p[0]] | Where-Object { $_ }) }
}
$byNature = [ordered]@{}; foreach ($k in @($natures.Keys) + "Autre") { $byNature[$k] = @($rows | Where-Object { $_.natures -contains $k } | ForEach-Object ss_id) }
$byClan = [ordered]@{}; foreach ($k in ($rows | ForEach-Object clan | Sort-Object -Unique)) { $byClan[$k] = @($rows | Where-Object { $_.clan -eq $k } | ForEach-Object ss_id) }
$byChar = [ordered]@{}; foreach ($k in ($rows | ForEach-Object character | Sort-Object -Unique)) { $byChar[$k] = @($rows | Where-Object { $_.character -eq $k } | ForEach-Object ss_id) }
$json = [ordered]@{ source = "Naruto to Boruto: Shinobi Striker (DT_NinjutsuData + L10N fr N1_Ninjutsu)"; count = @($rows).Count
    by_nature = $byNature; by_clan = $byClan; by_character = $byChar; jutsu = @($rows) }
[IO.File]::WriteAllText((Join-Path $root "data\progression\ss_jutsu_groups.json"), ($json | ConvertTo-Json -Depth 6), $utf8)

$type = @{ Melee = "Corps à corps"; Ranged = "Distance"; Technical = "Technique"; Heal = "Soin" }
$cat = @{ Normal = "Normal"; FinishMove = "**Ultime**"; Kawarimi = "Substitution" }
function Table($ids) {
    $t = "| Jutsu | Perso | Type | Catégorie | Recharge | Puissance / portée | Dans NARUTO-CLASH |`n|---|---|---|---|---|---|---|`n"
    foreach ($id in $ids) {
        $r = $rows | Where-Object ss_id -eq $id
        $cd = $(if ($r.cooldown -gt 0) { "$($r.cooldown) s" } else { "jauge" })
        $t += "| $($r.name) | $($r.character) | $($type[$r.type]) | $($cat[$r.category]) | $cd | $($r.power)/5 · $($r.reach)/5 | $($r.in_game -join ', ') |`n"
    }
    return $t
}
$md = "# Jutsu de Shinobi Striker par nature et par clan`n`n"
$md += "Les $(@($rows).Count) jutsu de Shinobi Striker (noms officiels FR), regroupés par **nature de chakra** puis par **clan / lignée** du personnage SS qui les utilise. "
$md += "Un jutsu peut apparaître dans plusieurs natures (ex. Katon + Fûton). Colonne « Dans NARUTO-CLASH » : kit (rang) où il est utilisé aujourd'hui (``tools/ss_kits.txt``). "
$md += "Données complètes (descriptions, icônes) : ``data/progression/ss_jutsu_groups.json``. Régénérer : ``powershell -File tools\ss_jutsu_groups.ps1``.`n`n"
$md += "## Résumé`n`n| Nature | Jutsu |`n|---|---|`n"; foreach ($k in $byNature.Keys) { $md += "| $k | $($byNature[$k].Count) |`n" }
$md += "`n| Clan / lignée | Jutsu |`n|---|---|`n"; foreach ($k in $byClan.Keys) { $md += "| $k | $($byClan[$k].Count) |`n" }
$md += "`n# Par nature`n`n"; foreach ($k in $byNature.Keys) { if ($byNature[$k].Count) { $md += "## $k ($($byNature[$k].Count))`n`n" + (Table $byNature[$k]) + "`n" } }
$md += "# Par clan / lignée`n`n"; foreach ($k in $byClan.Keys) { $md += "## $k ($($byClan[$k].Count))`n`n" + (Table $byClan[$k]) + "`n" }
[IO.File]::WriteAllText((Join-Path $root "docs\SS_JUTSU_PAR_NATURE_ET_CLAN.md"), $md, $utf8)
"{0} jutsu ; natures : {1} ; clans : {2}" -f @($rows).Count, (($byNature.Keys | ForEach-Object { "$_=$($byNature[$_].Count)" }) -join ", "), (($byClan.Keys | ForEach-Object { "$_=$($byClan[$_].Count)" }) -join ", ")
