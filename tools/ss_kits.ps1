# Builds the Shinobi Striker kits of NARUTO-CLASH from tools/ss_kits.txt:
#  1. data/progression/ss_jutsu.json : the SS data of every jutsu used (French name and description from
#     L10N/fr N1_Ninjutsu, NinjutsuType, CoolTime, DisplayData power / reach, icon, SS asset folder).
#     Read from the local reference (_SS_REFERENCE\extracted\jutsu\ss_jutsu.tsv) when present, else from the
#     existing snapshot, so the content can be rebuilt without the local reference.
#  2. data/progression/content.json : every nature / clan jutsu list and the sub-jutsu replaced by the SS kits.
# Then: godot --headless --path . -s tools/build_progression_db.gd
# Usage (project root): powershell -File tools\ss_kits.ps1
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$tsv = Join-Path $root "_SS_REFERENCE\extracted\jutsu\ss_jutsu.tsv"
$snapshot = Join-Path $root "data\progression\ss_jutsu.json"
$contentPath = Join-Path $root "data\progression\content.json"

# --- Kit table ----------------------------------------------------------------------
$rows = @()
foreach ($l in Get-Content (Join-Path $PSScriptRoot "ss_kits.txt") -Encoding UTF8) {
    $l = $l.Trim()
    if ($l -eq "" -or $l.StartsWith("#")) { continue }
    $p = $l -split "\s+"
    $rows += [pscustomobject]@{ kit = $p[0]; rank = $p[1]; ss = $p[2] }
}

# --- SS data --------------------------------------------------------------------------
$ss = @{}
if (Test-Path $tsv) {
    foreach ($l in Get-Content $tsv -Encoding UTF8) {
        $p = $l -split "`t"
        if ($p.Count -lt 10) { continue }
        $ss[$p[0]] = [ordered]@{ ss_id = $p[0]; name = $p[1]; type = $p[2]; category = $p[3]; cooldown = [double]$p[4];
            power = [int]$p[5]; reach = [int]$p[6]; icon = $p[7]; asset = $p[8]; description = $p[9].Trim() }
    }
    $used = [ordered]@{}
    foreach ($r in $rows) { if ($ss.ContainsKey($r.ss)) { $used[$r.ss] = $ss[$r.ss] } else { throw "SS jutsu inconnu : $($r.ss)" } }
    [IO.File]::WriteAllText($snapshot, ($used | ConvertTo-Json -Depth 4), (New-Object Text.UTF8Encoding $false))
} else {
    $json = Get-Content $snapshot -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($prop in $json.PSObject.Properties) { $ss[$prop.Name] = $prop.Value }
}

# SS's own text for ENTRY_03 repeats Sept cieux (ENTRY_02): described from the jutsu itself.
$fixes = @{ ENTRY_03 = "Le lanceur crache plusieurs petites boules de feu qui filent vers la cible et explosent à l'impact." }
foreach ($k in $fixes.Keys) { if ($ss.ContainsKey($k)) { $ss[$k].description = $fixes[$k] } }

# --- Ids, tags, costs -----------------------------------------------------------------
function Slug([string]$s) {
    $n = $s.Normalize([Text.NormalizationForm]::FormD)
    $b = New-Object Text.StringBuilder
    foreach ($c in $n.ToCharArray()) { if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($c) -ne [Globalization.UnicodeCategory]::NonSpacingMark) { [void]$b.Append($c) } }
    $t = $b.ToString().ToLower() -replace "^(katon|suiton|raiton|doton|futon|futton|yoton|jinton|hyoton|enton|mokuton|fuinjutsu|ninpo|senpo)\s*:\s*", ""
    $t = ($t -replace "[^a-z0-9]+", "_").Trim("_")
    if ($t.Length -gt 40) { $t = $t.Substring(0, 40).TrimEnd("_") }
    return $t
}
$rankCost = @{ D = 12; C = 20; B = 28; A = 40; S = 70 }
$rankCd = @{ D = 6; C = 10; B = 14; A = 20; S = 32 }
$typeTags = @{ Melee = @("MELEE"); Ranged = @("RANGED", "PROJECTILE"); Heal = @("HEAL"); Technical = @("BUFF") }
function Entry($r, [string]$prefix) {
    $s = $ss[$r.ss]
    $id = "{0}_{1}_{2}" -f $prefix, $r.rank.ToLower(), (Slug $s.name)
    $cd = if ([double]$s.cooldown -gt 0) { [double]$s.cooldown } else { $rankCd[$r.rank] }
    $tags = @($typeTags[[string]$s.type])
    if ($s.category -eq "FinishMove") { $tags += "AOE" }
    return [ordered]@{ id = $id; name = $s.name; description = $s.description; rank = $r.rank; tags = $tags;
        chakra_cost = $rankCost[$r.rank]; cooldown = $cd; passive = $false; design_tags = @("Shinobi Striker", [string]$s.type);
        details = "Jutsu Shinobi Striker ($($s.ss_id)). $($s.description)"; ss_id = $s.ss_id; ss_icon = $s.icon }
}

# --- content.json ---------------------------------------------------------------------
$content = Get-Content $contentPath -Raw -Encoding UTF8 | ConvertFrom-Json
$kawarimi = @{}
foreach ($r in ($rows | Where-Object { $_.rank -eq "kawarimi" })) { $kawarimi[$r.kit] = $ss[$r.ss] }
foreach ($n in $content.natures) {
    $n.jutsu = @($rows | Where-Object { $_.kit -eq $n.id -and $_.rank -ne "kawarimi" } | ForEach-Object { Entry $_ $n.id })
    $k = $kawarimi[$n.id]
    $n | Add-Member -Force NoteProperty kawarimi ($(if ($k) { [ordered]@{ ss_id = $k.ss_id; name = $k.name; description = $k.description } } else { $null }))
}
# Identity / signature texts: the old kits' mechanics are gone; describe the SS kit instead.
function KitTexts($kit, $list) {
    $names = ($list | ForEach-Object { $_.name }) -join ", "
    $k = $kawarimi[$kit.id]
    $kit.identity = "Kit Shinobi Striker : $names."
    $kit.signature = $(if ($k) { "Substitution : $($k.name). $($k.description)" } else { "Jutsu fidèles à Shinobi Striker (recharges et effets SS)." })
}
foreach ($n in $content.natures) { KitTexts $n $n.jutsu }
foreach ($c in $content.clans) {
    $c.jutsu = @($rows | Where-Object { $_.kit -eq $c.id -and $_.rank -ne "kawarimi" } | ForEach-Object { Entry $_ $c.id })
    $k = $kawarimi[$c.id]
    $c | Add-Member -Force NoteProperty kawarimi ($(if ($k) { [ordered]@{ ss_id = $k.ss_id; name = $k.name; description = $k.description } } else { $null }))
    KitTexts $c $c.jutsu
}
$weights = @{}
foreach ($s in $content.sub_jutsu) { if ($s.weight) { $weights[$s.rank] = $s.weight } }
$content.sub_jutsu = @($rows | Where-Object { $_.kit -eq "sub" } | ForEach-Object {
    $e = Entry $_ "sub"; $e.weight = $(if ($weights[$_.rank]) { $weights[$_.rank] } else { 1 }); $e })
# Technique -> SS assets (icon, jutsu folder, type), read by SSIcons / SSAudio / SSVfxProfiles.
$assets = [ordered]@{}
foreach ($e in @($content.natures.jutsu) + @($content.clans.jutsu) + @($content.sub_jutsu)) {
    $s = $ss[$e.ss_id]
    $assets[$e.id] = [ordered]@{ ss_id = $s.ss_id; icon = $s.icon; asset = $s.asset; type = $s.type; category = $s.category; power = $s.power; reach = $s.reach }
}
foreach ($kit in $kawarimi.Keys) { $s = $kawarimi[$kit]; $assets["kawarimi_$kit"] = [ordered]@{ ss_id = $s.ss_id; icon = $s.icon; asset = $s.asset; type = $s.type; category = $s.category; name = $s.name } }
[IO.File]::WriteAllText((Join-Path $root "data\progression\ss_kit_assets.json"), ($assets | ConvertTo-Json -Depth 4), (New-Object Text.UTF8Encoding $false))
$content._comment ="Kits Shinobi Striker : tools/ss_kits.txt -> tools/ss_kits.ps1 (noms, descriptions et recharges SS)."
[IO.File]::WriteAllText($contentPath, ($content | ConvertTo-Json -Depth 8), (New-Object Text.UTF8Encoding $false))
"{0} natures, {1} clans, {2} sub-jutsu, {3} techniques" -f $content.natures.Count, $content.clans.Count, $content.sub_jutsu.Count, (($content.natures.jutsu).Count + ($content.clans.jutsu).Count + $content.sub_jutsu.Count)
