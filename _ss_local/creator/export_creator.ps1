# Exports the SS character-creator library: untinted parts + colour masks, all on the avatar (SK_CHR_Face)
# skeleton, the body with the avatar animation clips and its face morphs (eye / brow / mouth / nose shapes),
# accessories (static meshes worn on the head), and the eye / face-paint material sidecars.
# Already exported files are kept (delete one to re-export it).
param([int]$upper = 40, [int]$lower = 24, [int]$unisexHair = 40, [int]$accessories = 50)
$nsdump = Join-Path $PSScriptRoot "..\..\_SS_REFERENCE\tools\ShinobiStrikerReader\build_tool\bin\nsdump.exe"
$out = Join-Path $PSScriptRoot "parts"
New-Item -ItemType Directory -Force $out, "$out\acc" | Out-Null
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

# Body (face, hands, neck) + clips + face morphs: base shapes of eyes / brows / mouth / nose, and eye blinks
$env:NSGLB_MORPHS = '(eyes_[mw]_[a-z0-9]+(_blink[LR])?|(eyebrows|mouth|nose)_[mw]_[a-z0-9]+)'
Export $face (Join-Path $PSScriptRoot "..\characters\avatar_male\anims.txt")
Remove-Item Env:NSGLB_MORPHS

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

# Accessories: static meshes, SS pivot kept (relative to the head bone)
$env:NSSTATIC_KEEP_PIVOT = "1"
$accs = $cat.accessory | Where-Object { $_.mesh } | Sort-Object sort | Group-Object mesh | Select-Object -First $accessories | ForEach-Object { $_.Group[0] }
foreach ($a in $accs) {
    $short = ($a.mesh -split '/')[-1]
    if (Test-Path "$out\acc\$short.glb") { continue }
    & $nsdump glbstatic "$out\acc\$short.glb" $a.mesh "$out\acc\tex" 2>&1 | ForEach-Object { $_.ToString() } | Select-String "GLB static|FEHLER" | Select-Object -Last 1
}
Remove-Item Env:NSSTATIC_KEEP_PIVOT -ErrorAction SilentlyContinue

# Eyes (DT_CustomEye: first frame of the L / R eye materials + face morph) and face paints (DT_CustomFacePaint)
$eyes = @()
$row = $null; $mode = ""
foreach ($l in Get-Content (Join-Path $PSScriptRoot "tables\DT_CustomEye.txt")) {
    if ($l -match "^--- Zeile") { if ($row) { $eyes += [pscustomobject]$row }; $row = [ordered]@{ id = ""; sex = ""; sort = 0; l = ""; r = ""; morph = "" }; continue }
    if ($l -match "EyeMaterialList_L") { $mode = "l" } elseif ($l -match "EyeMaterialList_R") { $mode = "r" }
    if ($row -and $l -match "^\s+0 \(AssetObjectProperty\) = (\S+)\.\S+$" -and $row[$mode] -eq "") { $row[$mode] = $Matches[1] }
    if ($l -match "IDName .*= (\S+)") { $row.id = $Matches[1] }
    if ($l -match "EquipEnable_(\w+)") { $row.sex = $Matches[1] }
    if ($l -match "SortOrder .*= (-?\d+)") { $row.sort = [int]$Matches[1] }
}
if ($row) { $eyes += [pscustomobject]$row }
foreach ($e in $eyes) { $e.morph = (($e.l -split '/')[-1] -replace '^MI_CHR_', '' -replace '_\d+_L$', '') }
$mats = ($eyes | ForEach-Object { $_.l; $_.r }) -join ";"
& $nsdump glbmat "$out\eyes.json" $mats 2>&1 | ForEach-Object { $_.ToString() }
$paints = $cat.facepaint | Where-Object { $_.material } | Select-Object -ExpandProperty material | Sort-Object -Unique
& $nsdump glbmat "$out\facepaints.json" ($paints -join ";") 2>&1 | ForEach-Object { $_.ToString() }
[IO.File]::WriteAllText("$out\face.json", (@{ eyes = @($eyes) } | ConvertTo-Json -Depth 4))

# Face paint decals: FacePaint_Map (256x256 mask) placed on the face UV by FacePaint_UV (x, y on 256, size)
New-Item -ItemType Directory -Force "$out\tex\facepaints" | Out-Null
$decals = [ordered]@{}
foreach ($m in $paints) {
    $dump = & $nsdump paket $m 0 2>&1 | ForEach-Object { $_.ToString() }
    $tex = ($dump | Select-String "imp\s+\d+ (\S+/T_CHR_FP_[^.]+)\.\S+ \(Texture2D\)" | Select-Object -First 1)
    if (-not $tex) { continue }
    $texPath = $tex.Matches[0].Groups[1].Value
    $vals = @{}
    for ($i = 0; $i -lt $dump.Count; $i++) {
        if ($dump[$i] -match "ParameterName \(NameProperty\) = (FacePaint_UV|FacePaint_UVOffset|FacePaint_BC|FacePaint_Rot)$") { $key = $Matches[1]; if ($dump[$i + 1] -match "= ([-\d.e ]+)$") { $vals[$key] = @($Matches[1].Trim() -split "\s+" | ForEach-Object { [double]$_ }) } }
    }
    $short = ($texPath -split '/')[-1]
    if (-not (Test-Path "$out\tex\facepaints\$short.png")) { & $nsdump textur $texPath "$out\tex\facepaints\$short.png" | Out-Null }
    $decals[($m -split '/')[-1]] = [ordered]@{ map = "tex/facepaints/$short.png"; uv = $vals["FacePaint_UV"]; uv2 = $vals["FacePaint_UVOffset"]; rot = $vals["FacePaint_Rot"]; color = $vals["FacePaint_BC"] }
}
[IO.File]::WriteAllText("$out\facepaint_decals.json", ($decals | ConvertTo-Json -Depth 4))
"{0} motifs de maquillage" -f $decals.Count

"{0} pieces, {1} accessoires, {2} yeux, {3} maquillages" -f (Get-ChildItem $out -Filter *.glb).Count, (Get-ChildItem "$out\acc" -Filter *.glb).Count, $eyes.Count, $paints.Count
