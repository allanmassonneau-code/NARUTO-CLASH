# Builds _ss_local/creator/catalog.json from the dumped SS character-creator tables (LOCAL ONLY).
$dir = Join-Path $PSScriptRoot "tables"

function Read-Rows([string]$table) {
    $rows = @()
    $cur = $null
    $inMats = $false
    foreach ($line in Get-Content (Join-Path $dir "$table.txt")) {
        if ($line -match '^--- Zeile') { if ($cur) { $rows += $cur }; $cur = [ordered]@{ materials = @() }; $inMats = $false; continue }
        if (-not $cur) { continue }
        if ($line -match '^\s{2}(\w+) \(') { $inMats = $line -match 'RefMaterialArray \(' }
        if ($line -match '^\s{2}IDName \(NameProperty\) = (\S+)') { $cur.id = $Matches[1] }
        elseif ($line -match '^\s{2}IDPartsColorDef0? \(NameProperty\) = (\S+)') { $cur.color0 = $Matches[1] }
        elseif ($line -match '^\s{2}RefMaterial \(AssetObjectProperty\) = (/Game/\S+)') { $cur.material = ($Matches[1] -split '\.')[0] }
        elseif ($line -match '^\s{2}IDPartsColorDef1 \(NameProperty\) = (\S+)') { $cur.color1 = $Matches[1] }
        elseif ($line -match '^\s{2}IDOpenFlag \(NameProperty\) = (\S+)') { $cur.open = $Matches[1] }
        elseif ($line -match '^\s{2}RefMesh \(AssetObjectProperty\) = (/Game/\S+)') { $cur.mesh = ($Matches[1] -split '\.')[0] }
        elseif ($inMats -and $line -match '^\s{4}\d+ \(AssetObjectProperty\) = (/Game/\S+)') { $cur.materials += ($Matches[1] -split '\.')[0] }
        elseif ($line -match 'EquipEnable \(EnumProperty ENN_EquipEnableSex\) = ENN_EquipEnableSex::ENN_EquipEnable_(\w+)') { $cur.sex = $Matches[1] }
        elseif ($line -match '^\s{2}SortOrder \(IntProperty\) = (-?\d+)') { $cur.sort = [int]$Matches[1] }
    }
    if ($cur) { $rows += $cur }
    return $rows
}

function Hex([string]$bgra) {   # FColor dump order: B G R A
    $v = $bgra.Trim() -split '\s+'
    return "{0:X2}{1:X2}{2:X2}" -f [int]$v[2], [int]$v[1], [int]$v[0]
}

$colors = [ordered]@{}
$cid = $null; $base = $null
foreach ($line in Get-Content (Join-Path $dir "DT_PartsColors.txt")) {
    if ($line -match 'IDName \(NameProperty\) = (\S+)') { $cid = $Matches[1] }
    elseif ($line -match 'BaseColor \(StructProperty Color\) = (.+)$') { $base = Hex $Matches[1] }
    elseif ($line -match 'SubColor \(StructProperty Color\) = (.+)$') { $colors[$cid] = @($base, (Hex $Matches[1])) }
}

$catalog = [ordered]@{ colors = $colors }
foreach ($kv in @(@("base", "DT_CustomBase"), @("hair", "DT_CustomHair"), @("upper", "DT_CustomJacket"), @("lower", "DT_CustomPants"),
                  @("eye", "DT_CustomEye"), @("forehead", "DT_CustomForehead"), @("accessory", "DT_CustomAccessories"), @("facepaint", "DT_CustomFacePaint"))) {
    $catalog[$kv[0]] = @(Read-Rows $kv[1] | Where-Object { $_.id })
}
[IO.File]::WriteAllText((Join-Path $PSScriptRoot "catalog.json"), ($catalog | ConvertTo-Json -Depth 6))   # no BOM (Godot JSON)
foreach ($k in $catalog.Keys) { if ($k -ne "colors") { "{0,-10} {1,5} rows, {2} with mesh, {3} open" -f $k, $catalog[$k].Count, @($catalog[$k] | Where-Object { $_.mesh }).Count, @($catalog[$k] | Where-Object { $_.open -eq 'ID_Flag_Const_True' }).Count } }
"colors     $($colors.Count)"
