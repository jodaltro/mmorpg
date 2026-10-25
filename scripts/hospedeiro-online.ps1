# Mantem o Hospedeiro online: servidor do mundo (porta 8096, modo publico, Jev) + tunel gratuito da Cloudflare + Worker apontando para ele.
#   powershell -File scripts\hospedeiro-online.ps1            # sobe e fica vigiando
#   powershell -File scripts\hospedeiro-online.ps1 -Fresh     # antes, guarda o mundo antigo e comeca um zerado
#   powershell -File scripts\hospedeiro-online.ps1 -TestReset # libera o botao de reset global para testes
#   powershell -File scripts\hospedeiro-online.ps1 -ReuseTunnel -TestReset # preserva o tunel existente
#   powershell -File scripts\hospedeiro-online.ps1 -Stop      # derruba tudo
# Pre-requisitos: engine\.env com as chaves, engine\worldsim.exe compilado, cloudflared instalado, `pip install requests boto3`.
param([switch]$Fresh, [switch]$Stop, [switch]$TestReset, [switch]$ReuseTunnel, [string]$ServerBinary = "", [string]$PythonDependencies = "D:\tools\hospedeiro-python")
$ErrorActionPreference = "Stop"
if (Test-Path $PythonDependencies) { $env:PYTHONPATH = $PythonDependencies }
$root = Split-Path $PSScriptRoot -Parent
$run = "D:\unity\hospedeiro-run"
$data = "D:\unity\hospedeiro-data"
if (-not $ServerBinary) {
    $ServerBinary = Join-Path $run "worldsim-nakama-v2.exe"
    if (-not (Test-Path $ServerBinary)) { $ServerBinary = Join-Path $run "worldsim-current.exe" }
    if (-not (Test-Path $ServerBinary)) { $ServerBinary = Join-Path $root "engine\worldsim.exe" }
}
$port = 8096
$public = "https://hospedeiro.memowhats.workers.dev"
New-Item -ItemType Directory -Force $run | Out-Null

function Stop-Port($p) {
    Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }
}
function Stop-Tunnel {
    Get-CimInstance Win32_Process -Filter "Name='cloudflared.exe'" | Where-Object { $_.CommandLine -like "*--url http://127.0.0.1:$port*" } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}
function Healthy($url, $headers = @{}) {
    try { (Invoke-WebRequest -UseBasicParsing -TimeoutSec 6 -Uri $url -Headers $headers).StatusCode -eq 200 } catch { $false }
}

$supervisorPidPath = Join-Path $run 'supervisor.pid'
if ($Stop) {
    if (Test-Path $supervisorPidPath) {
        $previousSupervisor = [int](Get-Content $supervisorPidPath)
        if ($previousSupervisor -ne $PID) { Stop-Process -Id $previousSupervisor -ErrorAction SilentlyContinue }
    }
    & (Join-Path $PSScriptRoot 'hospedeiro-nakama.ps1') -Stop
    Stop-Tunnel; Stop-Port $port; Write-Host "parado"; exit 0
}
$PID | Set-Content $supervisorPidPath

$envFile = Join-Path $root "engine\.env"
$secret = (Get-Content $envFile | Where-Object { $_ -like "HOSPEDEIRO_EDGE_SECRET=*" } | Select-Object -First 1)
if (-not $secret) { throw "HOSPEDEIRO_EDGE_SECRET nao esta em engine\.env: rode antes tools\deploy_online.py web" }
$env:HOSPEDEIRO_EDGE_SECRET = $secret.Substring("HOSPEDEIRO_EDGE_SECRET=".Length)

# The shared game server uses Nakama; its credentials stay outside the repository and the browser.
$nakamaRun = 'D:\unity\hospedeiro-nakama'
if (!(Get-NetTCPConnection -LocalPort 7350 -State Listen -ErrorAction SilentlyContinue)) {
    Start-Process -FilePath powershell.exe -WindowStyle Hidden -ArgumentList @('-NoProfile','-File',(Join-Path $PSScriptRoot 'hospedeiro-nakama.ps1')) -RedirectStandardOutput (Join-Path $run 'nakama-supervisor.log') -RedirectStandardError (Join-Path $run 'nakama-supervisor.err.log')
}
$nakamaKeysPath = Join-Path $nakamaRun 'keys.json'
for ($i=0; $i -lt 20 -and !(Test-Path $nakamaKeysPath); $i++) { Start-Sleep 1 }
if (!(Test-Path $nakamaKeysPath)) { throw 'Nakama credentials were not prepared; see nakama-supervisor.err.log' }
$nakamaKeys = Get-Content $nakamaKeysPath -Raw | ConvertFrom-Json
$env:HOSPEDEIRO_ADAPTER_KEY = $nakamaKeys.adapter

function Start-Server {
    Stop-Port $port
    $resetArguments = @()
    if ($TestReset) { $resetArguments = @("-test-reset") }
    Start-Process -FilePath $ServerBinary -WindowStyle Hidden `
        -ArgumentList (@("serve", "-public", "-universe", (Join-Path $root "universes\hospedeiro\universe.json"), "-data", $data, "-listen", "127.0.0.1:$port", "-advisor", "jev", "-env-file", $envFile, "-on-universe-change", "new-world", "-nakama", "http://127.0.0.1:7350") + $resetArguments) `
        -RedirectStandardOutput (Join-Path $run "server.log") -RedirectStandardError (Join-Path $run "server.err.log")
    for ($i = 0; $i -lt 30; $i++) { if (Healthy "http://127.0.0.1:$port/v1/health") { return }; Start-Sleep 1 }
    throw "o servidor nao respondeu (veja $run\server.err.log)"
}

function Start-Tunnel {
    Stop-Tunnel
    $log = Join-Path $run "tunnel.log"
    Remove-Item $log -ErrorAction SilentlyContinue
    Start-Process -FilePath "cloudflared" -WindowStyle Hidden -ArgumentList @("tunnel", "--no-autoupdate", "--url", "http://127.0.0.1:$port") -RedirectStandardError $log
    for ($i = 0; $i -lt 40; $i++) {
        Start-Sleep 1
        if (Test-Path $log) {
            $m = [regex]::Match((Get-Content $log -Raw -ErrorAction SilentlyContinue), "https://[a-z0-9-]+\.trycloudflare\.com")
            if ($m.Success) { return $m.Value }
        }
    }
    throw "o tunel nao abriu (veja $log)"
}

function Point-Worker($origin) {
    & python (Join-Path $root "clients\hospedeiro\tools\deploy_online.py") origin $origin
    if ($LASTEXITCODE -ne 0) { throw "nao consegui apontar o Worker" }

}

if ($Fresh -and (Test-Path $data)) {
    Stop-Port $port
    Start-Sleep 1
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    Rename-Item $data "hospedeiro-data-old-$stamp"
    Write-Host "mundo antigo guardado em hospedeiro-data-old-$stamp"
}

Start-Server
if ($ReuseTunnel) {
    $tunnelText = Get-Content (Join-Path $run "tunnel.log") -Raw
    $existingOrigin = [regex]::Match($tunnelText, "https://[a-z0-9-]+\.trycloudflare\.com")
    if (-not $existingOrigin.Success) { throw "tunel existente nao encontrado" }
    $origin = $existingOrigin.Value
} else {
    $origin = Start-Tunnel
    Point-Worker $origin
}
Write-Host "ONLINE: $public   (tunel: $origin)"

while ($true) {
    Start-Sleep 20
    try {
        if (-not (Healthy "http://127.0.0.1:$port/v1/health")) { Write-Host "servidor caiu: reiniciando"; Start-Server }
        if (@(Get-CimInstance Win32_Process -Filter "Name='cloudflared.exe'" | Where-Object { $_.CommandLine -like "*--url http://127.0.0.1:$port*" }).Count -eq 0) {
            Write-Host "tunel caiu: reabrindo"
            $origin = Start-Tunnel
            Point-Worker $origin
            Write-Host "ONLINE de novo: $public   (tunel: $origin)"
        }
    } catch { Write-Host "falha na vigilancia: $_" }
}
