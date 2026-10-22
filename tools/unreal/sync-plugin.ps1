# Copies the WorldSim plugin source into the demo project. The repo lives on
# an exFAT drive, so a copy is simpler and safer than a directory link.
. "$PSScriptRoot\common.ps1"
$src = Join-Path $Repo 'clients\unreal\WorldSim'
$dst = Join-Path $ProjectDir 'Plugins\WorldSim'
New-Item -ItemType Directory -Force $dst | Out-Null
robocopy $src $dst /MIR /XD Binaries Intermediate Saved /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "plugin sync failed ($LASTEXITCODE)" }
Write-Output "synced $src -> $dst"
& "$PSScriptRoot\configure-game.ps1"
