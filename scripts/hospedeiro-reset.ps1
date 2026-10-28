# Reinicia o Hospedeiro do zero: mundo, personagens salvos no cliente e banco de dados do Nakama.
# Nada é apagado: tudo vai para D:\unity\hospedeiro-data-archive\<data>. Uso:
#   powershell -File scripts\hospedeiro-reset.ps1            # motor local novo (jogo offline no PC)
#   powershell -File scripts\hospedeiro-reset.ps1 -Online    # também recria o banco e sobe o Nakama + autoridade Godot
param([switch]$Online)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$run = 'D:\unity\hospedeiro-run'
$data = 'D:\unity\hospedeiro-data'
$nakamaDb = 'D:\unity\hospedeiro-nakama-db'
$pgBin = 'D:\tools\hospedeiro-online\pgsql\bin'
$saves = Join-Path $env:APPDATA 'Godot\app_userdata\Hospedeiro'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$archive = "D:\unity\hospedeiro-data-archive\$stamp"
New-Item -ItemType Directory -Force "$archive\world", "$archive\client" | Out-Null

# 1. Parar tudo (vigia do motor, motor, Nakama, autoridade Godot, cliente aberto, PostgreSQL). O vigia primeiro: senão ele sobe o motor de volta.
Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'hospedeiro-service' -and $_.Name -match 'powershell' -and $_.ProcessId -ne $PID } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Remove-Item "$run\service.pid", "$run\service.stop" -ErrorAction SilentlyContinue
Get-CimInstance Win32_Process | Where-Object { $_.Name -match '^(worldsim.*|nakama|Godot.*)\.exe$' -and $_.ProcessId -ne $PID } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'hospedeiro-nakama' -and $_.Name -match 'powershell' -and $_.ProcessId -ne $PID } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
if (Test-Path "$nakamaDb\postmaster.pid") { & "$pgBin\pg_ctl.exe" -D $nakamaDb stop -m immediate 2>$null | Out-Null }
Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'postgres.exe' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Sleep -Seconds 2

# 2. Arquivar o mundo, os personagens do cliente e o banco.
if (Test-Path $data) { Get-ChildItem $data -File | Move-Item -Destination "$archive\world" }
if (Test-Path $saves) { Get-ChildItem "$saves\*" -File | Where-Object { $_.Name -match '^(hospedeiro_.*|e2e_identity_.*)\.json$' } | Move-Item -Destination "$archive\client" }
$left = @(Get-ChildItem "$saves\*" -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^(hospedeiro_.*|e2e_identity_.*)\.json$' }).Count
if ($left -gt 0) { Write-Host "AVISO: $left save(s) do cliente continuam em $saves (o jogo está aberto?)" } else { Write-Host 'saves do cliente arquivados' }
if (Test-Path $nakamaDb) { Move-Item $nakamaDb "$archive\nakama-db" }
Write-Host "arquivado em $archive"

# 3. Motor novo, a partir do código atual, sob o vigia (scripts\hospedeiro-service.ps1).
$go = 'D:\tools\go\bin\go.exe'
if (Test-Path $go) { Push-Location "$repo\engine"; & $go build -o "$run\worldsim-living.exe" ./cmd/worldsim; Pop-Location }
New-Item -ItemType Directory -Force $data | Out-Null
# O vigia sobe o motor (mundo novo se o universo mudou), reinicia se ele cair e grava o estado em service-status.json.
Start-Process -FilePath powershell.exe -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "$repo\scripts\hospedeiro-service.ps1", '-OnUniverseChange', 'new-world') -WindowStyle Hidden | Out-Null
$health = $null
for ($i = 0; $i -lt 30 -and -not $health; $i++) {
    Start-Sleep -Seconds 1
    try { $health = Invoke-RestMethod -Uri 'http://127.0.0.1:8096/v1/health' -TimeoutSec 2 } catch { }
}
if ($health) { Write-Host "motor em 127.0.0.1:8096, vigiado (tick $($health.tick), status $($health.status))" } else { Write-Host "o motor não respondeu em 30 s: veja $run\service-status.json e os engine-*.err.log" }

# 4. Online (opcional): o supervisor recria o banco vazio, aplica as migrações e sobe o Nakama.
if ($Online) {
    Start-Process -FilePath powershell.exe -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "$repo\scripts\hospedeiro-nakama.ps1") -WindowStyle Hidden -RedirectStandardOutput "$run\nakama-living.out.log" -RedirectStandardError "$run\nakama-living.err.log" | Out-Null
    Write-Host 'supervisor online iniciado (banco novo)'
}
