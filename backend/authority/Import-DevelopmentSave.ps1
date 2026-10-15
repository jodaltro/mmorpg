param([Parameter(Mandatory)][string]$ExportPath,[string]$Endpoint='http://127.0.0.1:8093')
$ErrorActionPreference='Stop'
$uri=[Uri]$Endpoint
if($uri.Scheme -ne 'http' -or $uri.Host -ne '127.0.0.1' -or $uri.UserInfo -or $uri.Query -or $uri.Fragment -or $uri.AbsolutePath -ne '/') { throw 'Development import requires explicit loopback authority' }
if(!$env:MMORPG_ACCESS_TOKEN) { throw 'Set MMORPG_ACCESS_TOKEN in this process only; never paste tokens into a command argument' }
$body=Get-Content -LiteralPath $ExportPath -Raw -Encoding UTF8
$export=$body | ConvertFrom-Json
if(!$export.worldId -or !$export.name) { throw 'Export must name an explicit destination world and character' }
try {
    $result=Invoke-RestMethod -Method Post -Uri ($Endpoint.TrimEnd('/')+'/v1/development/imports') -ContentType 'application/json' -Headers @{Authorization='Bearer '+$env:MMORPG_ACCESS_TOKEN} -Body ([Text.Encoding]::UTF8.GetBytes($body))
    [pscustomobject]@{CharacterId=$result.id;WorldId=$result.worldId;Provenance=$result.provenance}
}
catch { throw 'Development import rejected or unavailable; source save unchanged. Do not print HTTP exception request headers.' }
