# Exports the SS character-creator library (LOCAL ONLY): untinted parts + colour masks, all on the
# avatar (SK_CHR_Face) skeleton, and the body with the avatar animation clips.
param([int]$upper = 14, [int]$lower = 10, [int]$unisexHair = 12)
$nsdump = Join-Path $PSScriptRoot "..\..\_SS_REFERENCE\tools\ShinobiStrikerReader\build_tool\bin\nsdump.exe"
$out = Join-Path $PSScriptRoot "parts"
New-Item -ItemType Directory -Force $out | Out-Null
$out = (Resolve-Path $out).Path
$face = "/Game/Characters/Custom/Face/Meshes/SK_CHR_Face"
$cat = Get-Content (Join-Path $PSScriptRoot "catalog.json") -Raw | ConvertFrom-Json
$env:NSGLB_UNTINTED = "1"

function Export([string]$mesh, [string]$anims = "") {
    $short = ($mesh -split '/')[-1]
    if (Test-Path "$out\$short.glb") { return "$short (deja)" }
    $env:NSGLB_ONLY = $short
    $spec = if ($mesh -eq $face) { $face } else { "$face;$mesh" }
    $res = if ($anims) { & $nsdump glb "$out\$short.glb" $spec $anims 2>&1 } else { & $nsdump glb "$out\$short.glb" $spec 2>&1 }
    $line = $res | ForEach-Object { $_.ToString() } | Select-String "^GLB|FEHLER" | Select-Object -Last 1
    return "$short  $line"
}

# Body (face, hands, neck) + clips: reuse the avatar clip list
Export $face (Join-Path $PSScriptRoot "..\characters\avatar_male\anims.txt")

$picked = @()
foreach ($sex in @("Male", "Female")) {
    $picked += $cat.hair | Where-Object { $_.sex -eq $sex -and $_.mesh } | Group-Object mesh | ForEach-Object { $_.Group[0] }
    $picked += $cat.upper | Where-Object { $_.sex -eq $sex -and $_.mesh } | Sort-Object sort | Group-Object mesh | Select-Object -First $upper | ForEach-Object { $_.Group[0] }
    $picked += $cat.lower | Where-Object { $_.sex -eq $sex -and $_.mesh } | Sort-Object sort | Group-Object mesh | Select-Object -First $lower | ForEach-Object { $_.Group[0] }
}
$picked += $cat.hair | Where-Object { $_.sex -eq "Unisex" -and $_.mesh } | Group-Object mesh | Select-Object -First $unisexHair | ForEach-Object { $_.Group[0] }
foreach ($p in $picked) { Export $p.mesh }
Remove-Item Env:NSGLB_ONLY -ErrorAction SilentlyContinue
Remove-Item Env:NSGLB_UNTINTED -ErrorAction SilentlyContinue
"{0} pieces" -f (Get-ChildItem $out -Filter *.glb).Count
