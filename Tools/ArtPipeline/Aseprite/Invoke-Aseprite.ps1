param([Parameter(ValueFromRemainingArguments=$true)][string[]]$AsepriteArguments)
$ErrorActionPreference = 'Stop'
$asepritePath = & python "$PSScriptRoot/aseprite.py" locate
if ($LASTEXITCODE -ne 0) { throw 'Aseprite detection failed' }
$process = Start-Process -FilePath $asepritePath.Trim() -ArgumentList ($AsepriteArguments | ForEach-Object { '"' + $_.Replace('"','\"') + '"' }) -Wait -PassThru -WindowStyle Hidden
if ($process.ExitCode -ne 0) { throw "Aseprite exited with $($process.ExitCode)" }
