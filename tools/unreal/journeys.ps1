# Compares the journeys of several players in a running world: quests and their
# states, skills, play style and story chapter (from GET /v1/views/{id}), plus
# the advisor decisions written to the command log since a byte offset.
param(
  [string[]]$Players = @('ana', 'bruno', 'clara', 'davi', 'elisa', 'fabio'),
  [string]$Server = 'http://127.0.0.1:8095',
  [string]$Log = (Join-Path $PSScriptRoot '..\..\data\valdoria.jsonl'),
  [int64]$Since = 0
)
foreach ($p in $Players) {
  try { $v = Invoke-RestMethod "$Server/v1/views/${p}?limit=1" } catch { Write-Output "== $p (not in the world)"; continue }
  $style = if ($v.style) { ($v.style.PSObject.Properties | Sort-Object Value -Descending | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ' ' } else { '-' }
  Write-Output "== $p | style: $style | region: $($v.self.region)"
  foreach ($q in $v.quests) { Write-Output ("   quest {0,-10} [{1}] {2}" -f $q.state, $q.rank, $q.title) }
  foreach ($s in $v.skills) { Write-Output ("   skill {0} ({1})" -f $s.name, $s.rarity) }
  foreach ($st in $v.story) { if ($st.pursuing) { Write-Output ("   story {0}: pursuing {1}" -f $st.arc, $st.pursuing.title) } }
}
if (Test-Path $Log) {
  $fs = [IO.File]::Open($Log, 'Open', 'Read', 'ReadWrite'); $fs.Seek($Since, 'Begin') | Out-Null
  $sr = New-Object IO.StreamReader($fs); $txt = $sr.ReadToEnd(); $sr.Close()
  $rows = $txt -split "`n" | Where-Object { $_ -match '"kind":"resolve"' } | ForEach-Object { $_ | ConvertFrom-Json }
  Write-Output "== decisions since byte $Since"
  $rows | Group-Object { ($_.decision -split ':')[0] + ' / ' + $_.provider } | ForEach-Object {
    $l = $_.Group | Where-Object latencyMs | Measure-Object latencyMs -Average -Maximum
    Write-Output ("   {0,-24} n={1,3} avg {2,5:N0} ms max {3,5:N0} ms cost US$ {4:N6}" -f $_.Name, $_.Count, $l.Average, $l.Maximum, ($_.Group | Measure-Object cost -Sum).Sum)
  }
  $rows | Where-Object { $_.decision -like 'story*' } | ForEach-Object { Write-Output ("   {0} -> {1} [{2}, conf {3}]" -f $_.decision, $_.choice, $_.provider, $_.confidence) }
  $rows | Where-Object { $_.decision -like 'offer*' } | Group-Object { ($_.decision -split ':')[1] } | ForEach-Object {
    Write-Output ("   offers to {0}: {1}" -f $_.Name, (($_.Group | ForEach-Object { ($_.choice -split '\|')[0] }) -join ', '))
  }
}
