# Shared paths for the Unreal helper scripts.
$UE = if ($env:UE_ROOT) { $env:UE_ROOT } else { 'D:\UE_5.8' }
$Editor = Join-Path $UE 'Engine\Binaries\Win64\UnrealEditor.exe'
$EditorCmd = Join-Path $UE 'Engine\Binaries\Win64\UnrealEditor-Cmd.exe'
$BuildBat = Join-Path $UE 'Engine\Build\BatchFiles\Build.bat'
$ProjectDir = if ($env:WORLDSIM_UE_PROJECT) { $env:WORLDSIM_UE_PROJECT } else { 'D:\UnrealProjects\WorldSimDemo' }
$Project = Join-Path $ProjectDir 'WorldSimDemo.uproject'
$Repo = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$Log = Join-Path $ProjectDir 'Saved\Logs\WorldSimDemo.log'
function Require($path, $what) { if (-not (Test-Path $path)) { throw "$what not found: $path" } }
