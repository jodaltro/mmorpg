# Runs the game headless (no window) with console commands and prints the
# WorldSim log lines. The world engine must be serving.
param(
  [string]$Commands = 'ws.sequence 4 ws.status | ws.status',
  [int]$Seconds = 150,
  [string]$Map = '/Game/Valdoria/Maps/Lvl_Valdoria'
)
. "$PSScriptRoot\common.ps1"
Require $EditorCmd 'UnrealEditor-Cmd.exe'; Require $Project 'Project'
# The game must quit by itself so the log is flushed: a ws.sequence always
# ends with "quit".
if ($Commands -match '^ws\.sequence' -and $Commands -notmatch '\|\s*quit\s*$') { $Commands += ' | quit' }
$log = Join-Path $ProjectDir "Saved\Logs\play-test-$(Get-Date -Format yyyyMMdd-HHmmss).log"
# One quoted string: PowerShell 5.1 does not quote array items, which would
# split -ExecCmds at its spaces.
$a = "`"$Project`" $Map -game -nullrhi -unattended -nosplash -nosound `"-ExecCmds=$Commands`" `"-abslog=$log`""
$proc = Start-Process $EditorCmd -ArgumentList $a -PassThru -WindowStyle Hidden
if (-not $proc.WaitForExit($Seconds * 1000)) { Write-Warning "game did not quit in $Seconds s; killing it"; Stop-Process -Id $proc.Id -Force }
Select-String -Path $log -Pattern 'LogWorldSim' | ForEach-Object { $_.Line }
