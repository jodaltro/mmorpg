# Plays several players through the Unreal client, one headless run each, so
# the same world can be compared across play styles. Movement in the level
# (vila, estrada, floresta) is real input; other regions are reported with
# ws.move, and what the game server would confirm is sent with ws.occur.
# The world engine must be serving (ideally with -advisor jev).
param(
  [string[]]$Only = @(),
  [int]$Gap = 3
)
$walkSouth = 'ws.face -90 | ws.input IA_Move 0 1 seconds=11 | ws.status | ws.status | ws.status | ws.status'
$walkNorth = 'ws.face 90 | ws.input IA_Move 0 1 seconds=12 | ws.status | ws.status | ws.status | ws.status'
$walkRoad = 'ws.face -90 | ws.input IA_Move 0 1 seconds=4 | ws.status | ws.status'
$scenarios = [ordered]@{
  # The main arc: claim the unique scenario and see what the story does next.
  ana   = "ws.status | ws.act examinar-poco | ws.status | ws.status | ws.status | ws.accept | ws.status | ws.accept | $walkSouth | ws.occur seguir-rastro | ws.status | ws.status | ws.accept | $walkNorth | ws.accept | ws.act consultar-anciao | ws.status | ws.accept | ws.act aceitar-pacto | ws.status | ws.status | ws.accept | ws.status"
  # Combat: boars, bandits, wolves.
  bruno = "ws.join bruno Bruno | ws.status | ws.accept | $walkSouth | ws.occur cacar-javali | ws.occur cacar-javali | ws.occur cacar-javali | ws.accept | ws.occur cacar-javali-branco | $walkNorth | ws.occur cacar-lobos | ws.occur defender-vila | ws.accept | ws.move estrada | ws.occur enfrentar-bandidos | ws.occur escoltar-caravana | ws.status | ws.accept | ws.status"
  # Healer and helper: never leaves the village.
  clara = "ws.join clara Clara | ws.status | ws.accept | ws.act examinar-poco | ws.act contar-veneno | ws.accept | ws.act purificar-poco | ws.act receber-bencao | ws.act agradecer-elena | ws.accept | ws.act consertar-telhado | ws.act descansar | ws.act diagnosticar | ws.accept | ws.act acalmar-doentes | ws.status | ws.status | ws.accept | ws.status"
  # Refuses everything the world offers.
  davi  = "ws.join davi Davi | ws.status | ws.decline | ws.status | ws.decline | ws.act descansar | ws.decline | $walkRoad | ws.decline | ws.status | ws.decline | ws.status | ws.decline | ws.status | ws.decline | ws.status | ws.decline | ws.status"
  # Explorer: mine, ruins, forest, the Lebrinos' den.
  elisa = "ws.join elisa Elisa | ws.status | ws.accept | ws.move mina | ws.occur minerar | ws.move ruinas | ws.occur explorar-ruinas | ws.accept | ws.move floresta | ws.occur colher-ervas-campo | ws.occur achar-crianca | ws.move toca | ws.act presentear-pipo | ws.accept | ws.status | ws.move vila | ws.act trocar-magia | ws.accept | ws.status | ws.status"
  # Craftsman: ore, forge, the masterwork.
  fabio = "ws.join fabio Fabio | ws.status | ws.accept | ws.move mina | ws.occur minerar | ws.occur minerar | ws.occur resgatar-mineiro | ws.move vila | ws.act forjar | ws.accept | ws.act contribuir-obra | ws.act consertar-telhado | ws.accept | ws.act forjar | ws.act purificar-minerio | ws.status | ws.accept | ws.status | ws.status"
}
$results = [ordered]@{}
foreach ($name in $scenarios.Keys) {
  if ($Only.Count -and $Only -notcontains $name) { continue }
  Write-Output "=== $name"
  $lines = & "$PSScriptRoot\play-test.ps1" -Commands "ws.sequence $Gap $($scenarios[$name])" -Seconds 420
  $lines | Where-Object { $_ -match 'OFFER|QUEST|SKILL|moved:|rejected|accepted|SEQUENCE' } |
    ForEach-Object { $_ -replace '^\[[^\]]+\]\[[ \d]+\]LogWorldSim: (WorldSim: )?', '' } | Write-Output
}
