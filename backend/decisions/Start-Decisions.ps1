param([string]$ConfigPath = "$PSScriptRoot/config.example.json")
$ErrorActionPreference = 'Stop'
$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
Push-Location $PSScriptRoot
try {
    & go run ./cmd/server -mode $config.mode -listen $config.listen -timeout $config.timeout -minimum-confidence $config.minimumConfidence -data-dir $config.dataDirectory
    if ($LASTEXITCODE -ne 0) { throw 'Decision service stopped with an error.' }
}
finally { Pop-Location }
