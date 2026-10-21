# Builds the editor binaries for the demo project (compiles our plugin).
. "$PSScriptRoot\common.ps1"
& "$PSScriptRoot\sync-plugin.ps1"
Require $BuildBat 'Build.bat'; Require $Project 'Project'
& $BuildBat UnrealEditor Win64 Development "-Project=$Project" -WaitMutex -NoHotReload
exit $LASTEXITCODE

