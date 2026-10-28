# Mantém o motor do Hospedeiro vivo neste PC: sobe, vigia e reinicia.
#   powershell -File scripts\hospedeiro-service.ps1
# O mundo só avança enquanto o PC está ligado e acordado: com o PC desligado, em
# suspensão ou sem este serviço, o tempo do mundo para (e continua do mesmo tick ao
# voltar, sem corrida para recuperar). Ver Docs/Hospedeiro/Operations.md.
#
# Reinicia o motor quando: o processo morre, ou /v1/health diz "stalled" ou não
# responde por $StallSeconds. Espera cada vez mais entre reinícios seguidos
# (2 s, 4 s ... 60 s) e volta a 2 s depois de 10 minutos estáveis. Arquivo de parada:
# D:\unity\hospedeiro-run\service.stop
param(
    [string]$Data = 'D:\unity\hospedeiro-data',
    [string]$Run = 'D:\unity\hospedeiro-run',
    [string]$Listen = '127.0.0.1:8096',
    [string]$Advisor = 'jev',
    [string]$OnUniverseChange = 'refuse',
    [int]$MaxQuestionsPerMinute = 120,
    [double]$MaxCostPerHour = 1.0,
    [int]$CheckpointEveryTicks = 450,
    [int]$StallSeconds = 90,
    [int]$PollSeconds = 10,
    [int]$KeepLogDays = 14
)
$ErrorActionPreference = 'Continue'
$repo = Split-Path -Parent $PSScriptRoot
$exe = Join-Path $Run 'worldsim-living.exe'
$statusFile = Join-Path $Run 'service-status.json'
$stopFile = Join-Path $Run 'service.stop'
$pidFile = Join-Path $Run 'service.pid'
New-Item -ItemType Directory -Force $Run, $Data | Out-Null

# Uma só instância vigiando.
if (Test-Path $pidFile) {
    $other = Get-Process -Id ([int](Get-Content $pidFile -ErrorAction SilentlyContinue)) -ErrorAction SilentlyContinue
    if ($other -and $other.Id -ne $PID) { Write-Host "já existe um serviço vigiando (pid $($other.Id))"; exit 0 }
}
Set-Content $pidFile $PID
Remove-Item $stopFile -ErrorAction SilentlyContinue

$state = [ordered]@{ servicePid = $PID; startedAt = (Get-Date).ToString('o'); restarts = 0; enginePid = 0; lastReason = 'start'; lastHealth = $null; lastOkAt = $null; delaySeconds = 2 }
function Save-Status { ($state | ConvertTo-Json -Depth 4) | Set-Content -Encoding UTF8 $statusFile }

function Start-Engine {
    if (-not (Test-Path $exe)) {
        $go = 'D:\tools\go\bin\go.exe'
        Push-Location "$repo\engine"; & $go build -o $exe ./cmd/worldsim; Pop-Location
    }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $serveArgs = @('serve', '-universe', '..\universes\hospedeiro\universe.json', '-data', $Data, '-listen', $Listen, '-advisor', $Advisor, '-env-file', '.env',
        '-on-universe-change', $OnUniverseChange, '-checkpoint-every', $CheckpointEveryTicks, '-max-questions-per-minute', $MaxQuestionsPerMinute, '-max-cost-per-hour', $MaxCostPerHour)
    Start-Process -FilePath $exe -ArgumentList $serveArgs -WorkingDirectory "$repo\engine" -WindowStyle Hidden `
        -RedirectStandardOutput (Join-Path $Run "engine-$stamp.out.log") -RedirectStandardError (Join-Path $Run "engine-$stamp.err.log") -PassThru
}

function Get-Health {
    try { return Invoke-RestMethod -Uri "http://$Listen/v1/health" -TimeoutSec 5 } catch { return $null }
}

function Stop-Engine($p) {
    if ($p -and -not $p.HasExited) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue; $p.WaitForExit(5000) | Out-Null }
}

$engine = $null
$stableSince = Get-Date
$unhealthySince = $null
try {
    while (-not (Test-Path $stopFile)) {
        if ($null -eq $engine -or $engine.HasExited) {
            $reason = if ($null -eq $engine) { 'start' } else { "o motor saiu (código $($engine.ExitCode))" }
            if ($null -ne $engine) {
                $state.restarts++
                if (((Get-Date) - $stableSince).TotalMinutes -ge 10) { $state.delaySeconds = 2 }
                $state.lastReason = $reason
                Save-Status
                Start-Sleep -Seconds $state.delaySeconds
                $state.delaySeconds = [Math]::Min(60, $state.delaySeconds * 2)
            }
            $engine = Start-Engine
            $stableSince = Get-Date
            $unhealthySince = $null
            $state.enginePid = $engine.Id
            Save-Status
            Get-ChildItem $Run -Filter 'engine-*.log' | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$KeepLogDays) } | Remove-Item -ErrorAction SilentlyContinue
        }
        Start-Sleep -Seconds $PollSeconds
        $h = Get-Health
        $state.lastHealth = if ($h) { $h.status } else { 'unreachable' }
        if ($h -and $h.status -ne 'stalled') {
            $state.lastOkAt = (Get-Date).ToString('o')
            $unhealthySince = $null
            if ($h.status -eq 'ok' -and ((Get-Date) - $stableSince).TotalMinutes -ge 10) { $state.delaySeconds = 2 }
        } else {
            if ($null -eq $unhealthySince) { $unhealthySince = Get-Date }
            if (((Get-Date) - $unhealthySince).TotalSeconds -ge $StallSeconds) {
                $state.lastReason = "motor $($state.lastHealth) por $StallSeconds s: reiniciado"
                Stop-Engine $engine
            }
        }
        Save-Status
    }
} finally {
    Stop-Engine $engine
    $state.lastReason = 'serviço parado'
    $state.enginePid = 0
    Save-Status
    Remove-Item $pidFile -ErrorAction SilentlyContinue
}
