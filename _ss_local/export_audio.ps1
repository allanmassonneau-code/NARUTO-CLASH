# Exports the Shinobi Striker sounds the game uses (SD_Default.bnk + streamed music .wem) into
# _ss_local/sfx and _ss_local/music as 16-bit WAV, plus _ss_local/sfx/catalog.json.
# Needs the local reference copy: _SS_REFERENCE\extracted\audio\SD_Default.{bnk,txt} + wem\ (see README).
# Usage (from the project root): powershell -File _ss_local\export_audio.ps1
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$ref = Join-Path $root "_SS_REFERENCE\extracted\audio"
$nsdump = Join-Path $root "_SS_REFERENCE\tools\ShinobiStrikerReader\build_tool\bin\nsdump.exe"
$sfx = Join-Path $root "_ss_local\sfx"
$music = Join-Path $root "_ss_local\music"
Add-Type -TypeDefinition ([IO.File]::ReadAllText((Join-Path $PSScriptRoot "WemAdpcm.cs")))
New-Item -ItemType Directory -Force $sfx, $music | Out-Null

# --- SoundBank listing ------------------------------------------------------------
$lines = Get-Content (Join-Path $ref "SD_Default.txt")
$mem = [Array]::FindIndex($lines, [Predicate[string]]{ param($x) $x -like "In Memory Audio*" })
$str = [Array]::FindIndex($lines, [Predicate[string]]{ param($x) $x -like "Streamed Audio*" })
$sounds = $lines[($mem + 1)..($str - 1)] | Where-Object { $_ -match "^\t\d" } | ForEach-Object {
    $p = $_ -split "`t"; [pscustomobject]@{ id = $p[1]; name = $p[2]; path = $p[5]; size = [long]("0" + ($p[$p.Count - 1] -replace "\D", "")) } }
$streamed = @{}
$lines[($str + 1)..($lines.Count - 1)] | Where-Object { $_ -match "^\t\d" } | ForEach-Object {
    $p = $_ -split "`t"; $streamed[$p[2]] = $p[1] }

$catalog = [ordered]@{ events = [ordered]@{}; tech = [ordered]@{}; music = [ordered]@{} }

function Export-Sound($s, $file) {
    $wem = Join-Path $ref "wem\$($s.id).wem"
    if (-not (Test-Path $wem)) { return $false }
    [WemAdpcm]::ToWav($wem, (Join-Path $sfx $file)) | Out-Null
    return $true
}

# Base name without the random-variant suffix (_A, _b, -001, _01).
function Base-Name($n) { return ($n -replace "([_-](\d{1,3}|[A-Za-z]))$", "") }

# Up to $max variants of the sounds whose name matches $pattern (regex), as $key__<n>.wav.
function Add-Event($key, $pattern, $max = 3, $where = $null) {
    $hits = $sounds | Where-Object { $_.name -match $pattern -and ($null -eq $where -or $_.path -match $where) } |
        Sort-Object name | Select-Object -First $max
    $files = @()
    $i = 0
    foreach ($s in $hits) {
        $f = "{0}__{1}.wav" -f $key, $i
        if (Export-Sound $s $f) { $files += $f; $i++ }
    }
    if ($files.Count -gt 0) { $catalog.events[$key] = $files } else { Write-Warning "no sound for $key ($pattern)" }
}

# --- Combat, movement, UI, ambience -------------------------------------------------
$events = @(
    @("swing", "^Char_kunai_swing|^Char_Kunai_Swish"),
    @("swing_heavy", "^Char_Kunai_FullSwing|^Char_HiAttack"),
    @("hit", "^Char_Damage_[A-E]$", 5),
    @("hit_heavy", "^Char_damage_HitFinishReaction"),
    @("guard", "^Melee_Taijutsu_Guard_"),
    @("dash", "^Char_Dash|^Char_HiDash"),
    @("blink", "^Char_Disappear$|^Char_disappear_01"),
    @("jump", "^Char_Jump$|^Char_ContinuityJump0[12]"),
    @("chakra_jump", "^Char_Chakra_junp|^Char_ChakraJumpLoop_Start"),
    @("land", "^Char_Footstep_Land_Dirt"),
    @("roll", "^Char_Roll"),
    @("throw", "^Char_RangeAttack_Move|^Char_Paper_Swing"),
    @("kunai_hit", "^Missile_kunai_Hit_0[1-3]"),
    @("boom", "^NinjaItem_explosion_Influence"),
    @("fire", "^Ninjutsu_Common_Influence_Fire|^Ninjutsu_Common_Decal_Fire"),
    @("electric", "^Ninjutsu_Common_Influence_Spark"),
    @("charge", "^Char_ChakraJumpLoop_Charge|^UI_Ninjutsu_Charge_LevelUp"),
    @("counter", "^Char_GuardReverse|^Char_GuardBlake"),
    @("stun", "^Ninjutsu_Common_Influence_Debuff"),
    @("wall_slam", "^Char_Blown_Away|^Char_Hand_Smash_Large"),
    @("ko", "^Char_Footstep_Bodyfall_Dirt"),
    @("chakra_empty", "^Char_Chakra_Empty"),
    @("jutsu", "^Char_Jutsu"),
    @("summon", "^Ninjutsu_Kuchiyose_Invocation"),
    @("ultimate", "^Ninjutsu_Ogi_Appear"),
    @("heal", "^Ninjutsu_Healing|^Healing", 2),
    @("orb", "^UI_Scroll_Get"),
    @("orb_hit", "^UI_Skill_Stock$"),
    @("gong", "^UI_Match_Start"),
    @("tick", "^UI_Select$"),
    @("ui_ok", "^UI_OK$"),
    @("ui_cancel", "^UI_Cancel$|^UI_Return$"),
    @("ui_slide", "^UI_slide$"),
    @("ui_win", "^UI_Win$"),
    @("ui_lose", "^UI_Lose$"),
    @("ui_count", "^UI_Count$"),
    @("ui_grade_up", "^UI_Grade_Up$"),
    @("ui_buy", "^UI_Shop_Buy$"),
    @("ui_notify", "^UI_Battle_Notification$"),
    @("respawn", "^UI_Respawn_End$"),
    @("amb_village", "^Env_Ambience_KonohaVillage", 1),
    @("amb_village_night", "^Env_Ambience_Lobby_Night", 1),
    @("amb_forest", "^Env_Ambience_Forest$", 1),
    @("amb_forest_night", "^Env_Ambience_Night_Forest", 1),
    @("amb_bird", "^Env_KonohaForest_Bird_Day_a", 4),
    @("amb_village_bird", "^Env_Bird", 2),
    @("amb_insect", "^Env_KonohaForest_Insect_Day_a", 3),
    @("amb_dog", "^Env_Dog", 1),
    @("amb_stall", "^Env_Stall_Frying", 1),
    @("amb_water", "^Env_KonohaForest02_Water$|^Env_Pond", 1)
)
foreach ($e in $events) { $max = if ($e.Count -gt 2) { $e[2] } else { 3 }; Add-Event $e[0] $e[1] $max }
foreach ($surface in "Dirt", "Grass", "Wood", "Rock", "Sand", "Water", "Con") {
    Add-Event ("step_" + $surface.ToLower()) ("^Char_Footstep_Run_$surface" + "_") 4
}
if (-not $catalog.events.Contains("step_con")) { }

# --- Techniques: one SS jutsu sound folder per icon (SSIcons) ------------------------
$folders = @{}
foreach ($s in $sounds) {
    $m = [regex]::Match($s.path, "Ninjutsu_Specific\\([^\\]+)")
    if ($m.Success) { $f = $m.Groups[1].Value; if (-not $folders.ContainsKey($f)) { $folders[$f] = @() }; $folders[$f] += $s }
}
$alias = @{ "SilentStrange" = "SilentStrangle"; "DetonatingClayC2Dragon" = "C2Dragon"; "DetonatingClayTwinBird" = "DetonatingClayTwinBirds";
    "SandShowerBarrage" = "SandShower"; "TrueRasenShuriken" = "RasenSyuriken"; "EarthDragonBomb" = "EarthDragon"; "MudWall" = "Doryuheki";
    "SummonSalamandar" = "Salamandar"; "SharkBomb" = "SharkBomb"; "PhoenixFlowerNC" = "PhoenixFlower"; "FlyingRaijinLv2" = "FlyingRaijin" }
function Find-Folder($icon) {
    $name = if ($alias.ContainsKey($icon)) { $alias[$icon] } else { $icon -replace "^SP_", "" }
    foreach ($k in $folders.Keys) { if ($k -ieq $name) { return $k } }
    foreach ($k in $folders.Keys) { if ($k -ieq ("Ninjutsu_" + $name)) { return $k } }
    $d = [regex]::Match($name, "^(D\d+NJ)(\d)")
    if ($d.Success) {
        foreach ($k in $folders.Keys) { if ($k -ieq ("Ninjutsu_" + $d.Groups[1].Value + $d.Groups[2].Value)) { return $k } }
        foreach ($k in $folders.Keys) { if ($k -ieq ("Ninjutsu_" + $d.Groups[1].Value)) { return $k } }
    }
    return $null
}
function Pick($list, $pattern, $avoid) {
    return @($list | Where-Object { $_.name -match $pattern -and $_.name -notmatch "Loop|loop" -and $_.size -le 80000 -and ($null -eq $avoid -or $_.name -notmatch $avoid) } |
        Sort-Object name | Group-Object { Base-Name $_.name } | ForEach-Object { $_.Group[0] } | Select-Object -First 2)
}
# Keys: every SS jutsu used by the kits (asset folder and icon, data/progression/ss_kit_assets.json) and the
# fallback icons of SSIcons (per kit / per name).
$icons = @((Select-String -Path (Join-Path $root "core\graphics\ss_icons.gd") -Pattern '": "([A-Za-z0-9_]+)"' -AllMatches).Matches |
    ForEach-Object { $_.Groups[1].Value })
$kitAssets = Get-Content (Join-Path $root "data\progression\ss_kit_assets.json") -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($p in $kitAssets.PSObject.Properties) { $icons += [string]$p.Value.asset; $icons += [string]$p.Value.icon }
$icons = $icons | Where-Object { $_ } | Sort-Object -Unique
New-Item -ItemType Directory -Force (Join-Path $sfx "tech") | Out-Null
foreach ($icon in $icons) {
    $folder = Find-Folder $icon
    if ($null -eq $folder) { continue }
    $list = $folders[$folder]
    $impact = Pick $list "Hit|Explosion|Impact|Explode|Bomb|Burst|Crash|End" $null
    $cast = Pick $list "." "Hit|Explosion|Impact|Explode|Crash|End|Disappear"
    if ($cast.Count -eq 0) { $cast = Pick $list "." $null }
    $entry = [ordered]@{ folder = $folder; cast = @(); impact = @() }
    foreach ($slot in "cast", "impact") {
        $src = if ($slot -eq "cast") { $cast } else { $impact }
        $i = 0
        foreach ($s in $src) {
            $f = "tech/{0}__{1}{2}.wav" -f $folder, $slot, $i
            if (-not (Test-Path (Join-Path $sfx $f))) { if (-not (Export-Sound $s $f)) { continue } }
            $entry[$slot] += $f; $i++
        }
    }
    if ($entry.cast.Count + $entry.impact.Count -gt 0) { $catalog.tech[$icon] = $entry }
}

# --- Music (streamed .wem from the paks) ------------------------------------------
$tracks = [ordered]@{
    title = "Music_Title_LOOP"; village = "Music_KonohaVillage_WalkThrough_LOOP"; village_night = "Music_KonohaVillage_Night_WalkThrough_LOOP"
    shop = "Music_KonohaVillage_Shop"; forest = "Music_KonohaForest_WalkThrough_LOOP"; forest_battle = "Music_KonohaForest_Battle_Normal_LOOP"
    battle = "Music_KonohaVillage02_Battle_Normal_LOOP"; battle_climax = "Music_KonohaVillage02_Battle_Climax_LOOP"
    boss = "Music_Boss_Normal_LOOP"; match_start = "Music_PvP_Start"; win = "Music_Result_Win_LOOP"; lose = "Music_Result_Lose_LOOP"
}
New-Item -ItemType Directory -Force (Join-Path $ref "music") | Out-Null
foreach ($k in $tracks.Keys) {
    $name = $tracks[$k]
    $wem = Join-Path $ref "music\$name.wem"
    if (-not (Test-Path $wem)) { & $nsdump datei "NARUTO/Content/WwiseAudio/Windows/$($streamed[$name]).wem" $wem | Out-Null }
    [WemAdpcm]::ToWav($wem, (Join-Path $music "$k.wav")) | Out-Null
    $catalog.music[$k] = "$k.wav"
}

[IO.File]::WriteAllText((Join-Path $sfx "catalog.json"), ($catalog | ConvertTo-Json -Depth 6))
"events {0}  tech {1}  music {2}" -f $catalog.events.Count, $catalog.tech.Count, $catalog.music.Count
