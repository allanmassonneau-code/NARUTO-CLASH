param([string]$set = "konoha")
# Re-export a Shinobi Striker environment kit (local only): one mesh path per line in kit.txt
$r = Join-Path $PSScriptRoot "..\_SS_REFERENCE\tools\ShinobiStrikerReader\build_tool\bin\nsdump.exe"
$o = Join-Path $PSScriptRoot "env\$set"
foreach ($p in Get-Content (Join-Path $o "kit.txt")) {
    if ($p.Trim() -eq "" -or $p.StartsWith("#")) { continue }
    $short = ($p -split '/')[-1]
    $line = & $r glbstatic "$o\$short.glb" $p "$o\tex" 2>&1 | ForEach-Object { $_.ToString() } | Select-String "GLB static|FEHLER" | Select-Object -Last 1
    "{0,-42} {1}" -f $short, $line
}