# Creates WorldSimDemo from the Third Person Blueprint template that ships
# with the engine, enables the plugins we need and copies our plugin.
# Refuses to overwrite an existing project.
. "$PSScriptRoot\common.ps1"
$Template = Join-Path $UE 'Templates\TP_ThirdPersonBP'
Require $Template 'Third Person template'
if (Test-Path $ProjectDir) { throw "Project already exists: $ProjectDir" }
New-Item -ItemType Directory -Force (Split-Path $ProjectDir) | Out-Null
Copy-Item $Template $ProjectDir -Recurse
Get-ChildItem $ProjectDir -Filter *.uproject | Rename-Item -NewName 'WorldSimDemo.uproject'
# The template folder holds only its own content; the character, input and
# prototyping assets come from shared packs listed in TemplateDefs.ini
# (without them BP_ThirdPersonCharacter has no mesh and no input actions).
$defs = Join-Path $ProjectDir 'Config\TemplateDefs.ini'
foreach ($m in Select-String -Path $defs -Pattern '^SharedContentPacks=\(MountName="([^"]+)",DetailLevels=\("([^"]+)"') {
  $mount, $detail = $m.Matches[0].Groups[1].Value, $m.Matches[0].Groups[2].Value
  $src = Join-Path $UE "Templates\TemplateResources\$detail\$mount\Content"
  Require $src "shared content pack $mount"
  robocopy $src (Join-Path $ProjectDir "Content\$mount") /E /NFL /NDL /NJH /NJS /NP | Out-Null
  if ($LASTEXITCODE -ge 8) { throw "copy of $mount failed ($LASTEXITCODE)" }
  Write-Output "Shared pack: $mount ($detail)"
}
Remove-Item $defs -ErrorAction SilentlyContinue
$p = Get-Content $Project -Raw | ConvertFrom-Json
$want = 'ModelContextProtocol','AllToolsets','PythonScriptPlugin','WorldSim'
$list = @($p.Plugins | Where-Object { $_.Name -notin $want })
foreach ($n in $want) { $list += [pscustomobject]@{ Name = $n; Enabled = $true } }
$p | Add-Member -Force -NotePropertyName Plugins -NotePropertyValue $list
$p | ConvertTo-Json -Depth 10 | Set-Content $Project -Encoding utf8
# Copied, not linked (the repo is on exFAT); build.ps1 resyncs it.
& "$PSScriptRoot\sync-plugin.ps1"
# No URL in the ini: its parser treats "//" as the start of a comment.
$ini = Join-Path $ProjectDir 'Config\DefaultGame.ini'
Add-Content $ini "`n[/Script/EngineSettings.GeneralProjectSettings]`nProjectName=WorldSimDemo`n`n[/Script/WorldSim.WorldSimSettings]`nServerHost=127.0.0.1`nServerPort=8095`nPlayerId=ana`nPlayerName=Ana`nbAutoJoin=True`n"
Write-Output "Created $Project"
