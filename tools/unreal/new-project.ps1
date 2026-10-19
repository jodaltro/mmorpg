# Creates WorldSimDemo from the Third Person Blueprint template that ships
# with the engine, enables the plugins we need and links our plugin.
# Refuses to overwrite an existing project.
. "$PSScriptRoot\common.ps1"
$Template = Join-Path $UE 'Templates\TP_ThirdPersonBP'
Require $Template 'Third Person template'
if (Test-Path $ProjectDir) { throw "Project already exists: $ProjectDir" }
New-Item -ItemType Directory -Force (Split-Path $ProjectDir) | Out-Null
Copy-Item $Template $ProjectDir -Recurse
Get-ChildItem $ProjectDir -Filter *.uproject | Rename-Item -NewName 'WorldSimDemo.uproject'
Remove-Item (Join-Path $ProjectDir 'Config\TemplateDefs.ini') -ErrorAction SilentlyContinue
$p = Get-Content $Project -Raw | ConvertFrom-Json
$want = 'ModelContextProtocol','AllToolsets','PythonScriptPlugin','WorldSim'
$list = @($p.Plugins | Where-Object { $_.Name -notin $want })
foreach ($n in $want) { $list += [pscustomobject]@{ Name = $n; Enabled = $true } }
$p | Add-Member -Force -NotePropertyName Plugins -NotePropertyValue $list
$p | ConvertTo-Json -Depth 10 | Set-Content $Project -Encoding utf8
New-Item -ItemType Directory -Force (Join-Path $ProjectDir 'Plugins') | Out-Null
cmd /c mklink /J (Join-Path $ProjectDir 'Plugins\WorldSim') (Join-Path $Repo 'clients\unreal\WorldSim') | Out-Null
$ini = Join-Path $ProjectDir 'Config\DefaultGame.ini'
Add-Content $ini "`n[/Script/EngineSettings.GeneralProjectSettings]`nProjectName=WorldSimDemo`n`n[/Script/WorldSim.WorldSimSettings]`nServerUrl=http://127.0.0.1:8095`nPlayerId=ana`nPlayerName=Ana`nbAutoJoin=True`n"
Write-Output "Created $Project"
