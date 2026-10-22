# Writes the demo's combat moves (valdoria-moves.ini) into the project's
# Config/DefaultGame.ini, replacing any previous Moves lines of the WorldSim
# settings section. Idempotent; called by sync-plugin.ps1.
. "$PSScriptRoot\common.ps1"
$ini = Join-Path $ProjectDir 'Config\DefaultGame.ini'
if (-not (Test-Path $ini)) { return }
$moves = Get-Content (Join-Path $PSScriptRoot 'valdoria-moves.ini') | Where-Object { $_ -match '^[\+!]?Moves=' }
$section = '[/Script/WorldSim.WorldSimSettings]'
$out = New-Object System.Collections.Generic.List[string]
$inSection = $false; $written = $false
foreach ($line in Get-Content $ini) {
  if ($line -match '^\[') {
    if ($inSection -and -not $written) { $moves | ForEach-Object { $out.Add($_) }; $written = $true }
    $inSection = ($line -eq $section)
  }
  if ($inSection -and $line -match '^[\+\-!]?Moves=') { continue }
  $out.Add($line)
}
if ($inSection -and -not $written) { $moves | ForEach-Object { $out.Add($_) }; $written = $true }
if (-not $written) { $out.Add(''); $out.Add($section); $moves | ForEach-Object { $out.Add($_) } }
Set-Content $ini $out -Encoding utf8
Write-Output "configured $($moves.Count) combat moves in $ini"
