# One click to play: makes sure the world server is running (Jev advisor,
# world kept in data/), then opens the game in its own window at the start
# screen (continue a character, new character, new world).
param(
  [string]$Advisor = 'jev',
  [switch]$InEditor,
  [switch]$ServerOnly
)
. "$PSScriptRoot\common.ps1"
$engine = Join-Path $Repo 'engine'
$data = Join-Path $Repo 'data'
$server = 'http://127.0.0.1:8095'
function Up { try { (Invoke-WebRequest "$server/v1/health" -UseBasicParsing -TimeoutSec 2).StatusCode -eq 200 } catch { $false } }

if (-not (Up)) {
  $go = 'D:\tools\go\bin\go.exe'
  if (-not (Test-Path $go)) { $go = 'go' }
  $exe = Join-Path $env:LOCALAPPDATA 'WorldSim\worldsim.exe'
  New-Item -ItemType Directory -Force (Split-Path $exe) | Out-Null
  New-Item -ItemType Directory -Force $data | Out-Null
  Push-Location $engine
  & $go build -o $exe ./cmd/worldsim
  if ($LASTEXITCODE -ne 0) { Pop-Location; throw 'could not build the world server' }
  # If the universe changed since the world was saved, the old world is
  # archived next to it (never deleted) and a new one starts.
  Start-Process $exe -WorkingDirectory $engine -WindowStyle Hidden `
    -RedirectStandardOutput (Join-Path $data 'server.log') -RedirectStandardError (Join-Path $data 'server-err.log') `
    -ArgumentList 'serve', '-universe', '..\universes\valdoria\universe.json', '-data', '..\data', '-tick', '1s',
      '-advisor', $Advisor, '-env-file', '.env', '-on-universe-change', 'new-world', '-listen', '127.0.0.1:8095'
  Pop-Location
  for ($i = 0; $i -lt 30 -and -not (Up); $i++) { Start-Sleep -Milliseconds 500 }
  if (-not (Up)) { throw "the world server did not start; see $data\server-err.log" }
}
Write-Output "World server: $((Invoke-WebRequest "$server/v1/health" -UseBasicParsing).Content)"

if ($ServerOnly) {
  return
} elseif ($InEditor) {
  & "$PSScriptRoot\editor.ps1"
} else {
  Require $Editor 'UnrealEditor.exe'
  Start-Process $Editor -ArgumentList "`"$Project`"", '-game', '-windowed', '-ResX=1600', '-ResY=900', '-nosplash'
  Write-Output 'Game window starting (first launch can take a minute).'
}
