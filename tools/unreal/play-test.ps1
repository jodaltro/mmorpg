# Runs the game headless (no window) for a few seconds with console commands
# and prints the WorldSim log lines. The world engine must be serving.
param(
  [string]$Commands = 'ws.status',
  [int]$Seconds = 20,
  [string]$Map = '/Game/ThirdPerson/Lvl_ThirdPerson'
)
. "$PSScriptRoot\common.ps1"
Require $EditorCmd 'UnrealEditor-Cmd.exe'; Require $Project 'Project'
$log = Join-Path $ProjectDir "Saved\Logs\play-test-$(Get-Date -Format yyyyMMdd-HHmmss).log"
$a = @($Project, $Map, '-game', '-nullrhi', '-unattended', '-nosplash', '-nosound', "-ExecCmds=$Commands", "-abslog=$log")
$proc = Start-Process $EditorCmd -ArgumentList $a -PassThru
Start-Sleep -Seconds $Seconds
if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force }
Select-String -Path $log -Pattern 'WorldSim' | ForEach-Object { $_.Line }
