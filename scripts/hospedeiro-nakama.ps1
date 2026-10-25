# Nakama + Godot authority. Run hidden; all logs, secrets, PostgreSQL data and binaries stay on D:.
param([switch]$LocalTest, [switch]$Stop, [string]$DatabaseEnv)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$tools = 'D:\tools\hospedeiro-online'
$run = if ($LocalTest) { 'D:\unity\hospedeiro-nakama-qa' } else { 'D:\unity\hospedeiro-nakama' }
$port = if ($LocalTest) { 7352 } else { 7350 }
$enginePort = if ($LocalTest) { 8198 } else { 8096 }
$db = if ($LocalTest) { 'hospedeiro_qa' } else { 'hospedeiro' }
New-Item -ItemType Directory -Force $run | Out-Null
$pidFile = Join-Path $run 'processes.json'
if ($Stop) {
    if (Test-Path $pidFile) {
        $saved = Get-Content $pidFile -Raw | ConvertFrom-Json
        foreach ($processId in @($saved.supervisor,$saved.nakama,$saved.game)) { if ($processId -and $processId -ne $PID) { Stop-Process -Id $processId -ErrorAction SilentlyContinue } }
    }
    exit
}
function New-Secret {
    $bytes = New-Object byte[] 32
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    return [Convert]::ToBase64String($bytes)
}
$keysFile = Join-Path $run 'keys.json'
if (!(Test-Path $keysFile)) {
    @{adapter=(New-Secret);game=(New-Secret);session=(New-Secret);refresh=(New-Secret);console=(New-Secret);http=(New-Secret)} | ConvertTo-Json | Set-Content $keysFile -Encoding UTF8
}
$keys = Get-Content $keysFile -Raw | ConvertFrom-Json
$databaseUrl = ''
$migrationUrl = ''
if ($DatabaseEnv) {
    foreach ($line in Get-Content -LiteralPath $DatabaseEnv) {
        if ($line -match '^HOSPEDEIRO_NAKAMA_DATABASE_URL=(.+)$') { $databaseUrl = $Matches[1].Trim() }
        if ($line -match '^HOSPEDEIRO_NAKAMA_MIGRATION_URL=(.+)$') { $migrationUrl = $Matches[1].Trim() }
    }
    if (!$databaseUrl -or !$migrationUrl) { throw 'DatabaseEnv needs runtime and migration URLs' }
}
$env:HOSPEDEIRO_ADAPTER_KEY = $keys.adapter
$env:HOSPEDEIRO_GAME_KEY = $keys.game
$env:HOSPEDEIRO_ENGINE_URL = "http://127.0.0.1:$enginePort"
$env:HOSPEDEIRO_NAKAMA_URL = "http://127.0.0.1:$port"
$env:HOSPEDEIRO_EDGE_SECRET = ''
if (!$LocalTest) {
    foreach ($line in Get-Content (Join-Path $root 'engine\.env')) {
        if ($line -match '^HOSPEDEIRO_EDGE_SECRET=(.+)$') { $env:HOSPEDEIRO_EDGE_SECRET = $Matches[1].Trim('"',"'") }
    }
}
if (!$databaseUrl) {
    $pg = Join-Path $tools 'pgsql\bin'
    if (!(Test-Path (Join-Path $pg 'pg_ctl.exe'))) { throw 'Install the Windows PostgreSQL and Nakama binaries with scripts/install-hospedeiro-nakama.py first.' }
    $pgData = 'D:\unity\hospedeiro-nakama-db'
    if (!(Test-Path (Join-Path $pgData 'PG_VERSION'))) {
        & (Join-Path $pg 'initdb.exe') -D $pgData -U hospedeiro -A trust --encoding=UTF8 --locale=C *> (Join-Path $run 'initdb.log')
        if ($LASTEXITCODE) { throw 'initdb failed; see initdb.log' }
    }
    & (Join-Path $pg 'pg_isready.exe') -h 127.0.0.1 -p 55432 *> $null
    if ($LASTEXITCODE) {
        & (Join-Path $pg 'pg_ctl.exe') -D $pgData -l (Join-Path $run 'postgres.log') -o '-p 55432 -h 127.0.0.1' start *> (Join-Path $run 'pg-start.log')
        if ($LASTEXITCODE) { throw 'PostgreSQL startup failed' }
    }
    & (Join-Path $pg 'psql.exe') -h 127.0.0.1 -p 55432 -U hospedeiro -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$db'" | ForEach-Object { $script:dbExists = $_.Trim() -eq '1' }
    if (!$script:dbExists) {
        & (Join-Path $pg 'createdb.exe') -h 127.0.0.1 -p 55432 -U hospedeiro $db
        if ($LASTEXITCODE) { throw 'Database creation failed' }
    }
    $databaseUrl = "hospedeiro@127.0.0.1:55432/$db"
    $migrationUrl = $databaseUrl
}
$config = @{
    name='hospedeiro'; data_dir=$run
    database=@{address=@($databaseUrl);max_open_conns=5;max_idle_conns=2}
    socket=@{address='127.0.0.1';port=$port;server_key='hospedeiro';max_message_size_bytes=262144}
    session=@{encryption_key=$keys.session;refresh_encryption_key=$keys.refresh;token_expiry_sec=3600;refresh_token_expiry_sec=86400}
    console=@{address='127.0.0.1';port=($port+20);username='admin';password=$keys.console;signing_key=$keys.console}
    runtime=@{path=(Join-Path $root 'services\nakama\modules');http_key=$keys.http;env=@("HOSPEDEIRO_GAME_KEY=$($keys.game)","HOSPEDEIRO_ADAPTER_KEY=$($keys.adapter)","HOSPEDEIRO_ENGINE_URL=$env:HOSPEDEIRO_ENGINE_URL","HOSPEDEIRO_EDGE_SECRET=$env:HOSPEDEIRO_EDGE_SECRET")}
    logger=@{level='INFO'}
}
$configFile = Join-Path $run 'config.yml'
$config.database.address = @($migrationUrl)
$config | ConvertTo-Json -Depth 8 | Set-Content $configFile -Encoding UTF8
$nakamaBin = Join-Path $tools 'nakama\nakama.exe'
& $nakamaBin migrate up --config $configFile *> (Join-Path $run 'migrate.log')
if ($LASTEXITCODE) { throw 'Nakama migration failed; see migrate.log' }
$config.database.address = @($databaseUrl)
$config | ConvertTo-Json -Depth 8 | Set-Content $configFile -Encoding UTF8
$nkProcess = Start-Process -FilePath $nakamaBin -ArgumentList @('--config',$configFile) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $run 'nakama.log') -RedirectStandardError (Join-Path $run 'nakama.err.log')
$gameArgs = @('--headless','--path', (Join-Path $root 'clients\hospedeiro'),'--script','res://server.gd')
$gameBin = 'D:\tools\godot\bin\Godot_v4.7.2-stable_win64_console.exe'
$gameProcess = Start-Process -FilePath $gameBin -ArgumentList $gameArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $run 'game.log') -RedirectStandardError (Join-Path $run 'game.err.log')
@{supervisor=$PID;nakama=$nkProcess.Id;game=$gameProcess.Id;port=$port;enginePort=$enginePort} | ConvertTo-Json | Set-Content $pidFile
Write-Host "Nakama local :$port + Godot authority started; logs in $run"
# This script is the supervisor; PostgreSQL is shared and is never killed here.
while ($true) {
    Start-Sleep -Seconds 5
    $nkProcess.Refresh(); $gameProcess.Refresh()
    if ($nkProcess.HasExited) {
        $nkProcess = Start-Process -FilePath $nakamaBin -ArgumentList @('--config',$configFile) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $run 'nakama.log') -RedirectStandardError (Join-Path $run 'nakama.err.log')
    }
    if ($gameProcess.HasExited) {
        $gameProcess = Start-Process -FilePath $gameBin -ArgumentList $gameArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $run 'game.log') -RedirectStandardError (Join-Path $run 'game.err.log')
    }
    @{supervisor=$PID;nakama=$nkProcess.Id;game=$gameProcess.Id;port=$port;enginePort=$enginePort} | ConvertTo-Json | Set-Content $pidFile
}
