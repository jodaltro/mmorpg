param([string]$GoCommand = 'go',[string]$EnvFile = '')
$ErrorActionPreference = 'Stop'
if(!$EnvFile) { foreach($name in @('DATABASE_URL','SUPABASE_URL','SUPABASE_PUBLISHABLE_KEY','AUTH_MODE')) {
    if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name))) { throw "Required backend environment missing: $name" }
} } else { $EnvFile=(Resolve-Path -LiteralPath $EnvFile).Path }
Push-Location $PSScriptRoot
try {
    if($EnvFile) { & $GoCommand run ./cmd/server -env-file $EnvFile } else { & $GoCommand run ./cmd/server }
    if($LASTEXITCODE -ne 0) { throw 'Authority stopped with an error; inspect sanitized backend logs.' }
}
finally { Pop-Location }
