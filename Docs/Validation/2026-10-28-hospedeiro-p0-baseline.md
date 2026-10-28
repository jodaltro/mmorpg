# 2026-10-28 — Hospedeiro P0 · radiografia e baseline

- Branch/SHA início: `main` @ `e819685f819418a8340759730a22d10b81ba6c7b`
- SO/ferramentas: Windows 10, Go 1.27.2, AMD Ryzen 7 1700X (16 threads). Godot e Nakama **não** foram executados neste item.
- Mundo: apenas local/isolado (nenhum mundo real tocado, nenhum journal de produção lido ou escrito).
- Fingerprint do universo antes: `c7dcd8a48d9676ffccef799a084925fa1308a4d0d522f0ed01139e32583faf17`

## Comandos executados (resultado real)

| Comando | Resultado |
|---|---|
| `go vet ./...` (engine) | sem saída (ok) |
| `go test ./...` (engine) | todos os pacotes `ok` |
| `worldsim validate universes/hospedeiro/universe.json` | `ok` |
| `worldsim simulate -ticks 300 -players 0 -advisor deterministic` | roda; digest `ec9dc3b5…a84f9`; diretor escolheu febre 7, infecção-pulmonar 1, refeição 8, sono 6, surto-viral 3 |
| `worldsim simulate -ticks 120 -players 3 -advisor deterministic` | roda; digest `f02a9696…58f8555` |
| `gofmt -l .` | lista 10 arquivos **já existentes** (`advisor/jev.go` e 9 testes de `scenarios`) — pendência de formatação anterior a este trabalho, não tocada |

## P0.2 — Inventário do universo `hospedeiro` (214 KB)

15 entidades de base (tecidos `medula, sangue, coracao, pulmao, aorta, figado, baco, intestino, rim`, `corpo`, `virion`, células `estroma, neva, rubra, dendra`); 3 agentes com metas (`dendra`: armar-defesa; `neva`: combater-foco; `estroma`: nutrir-nicho); 44 regras; 20 ações; 37 modelos de quest; 5 `happenings`; 5 `dungeons`; 8 passagens; 18 `spots`; 13 vitais; 12 linhagens.

**Achado importante:** `rubra` existe como entidade mas **não tem nenhum `AgentDef`** — hoje só `dendra`, `neva` e `estroma` agem. Rubra, macrófagos, plaquetas e Osteia ainda não têm rotina de motor. O Godot encarna inimigos/ambiente, não NPCs canônicos.

## P0.3 — Benchmark do tick (`engine/scenarios/bench_test.go`)

`go test ./scenarios -run xxx -bench TickNPCs -benchtime=200x` (NPCs **sintéticos** com 1 meta, `Think:1`; `Step` clona o estado, o custo inclui a cópia). Amostra de 200 iterações por linha — média, **não** p95/p99.

| NPCs extras | ns/tick | B/tick | allocs/tick |
|---|---|---|---|
| 0 | 79 688 | 29 099 | 142 |
| 10 | 79 312 | 46 361 | 213 |
| 100 | 1 373 820 | 220 993 | 815 |
| 1000 | 95 323 682 | 1 907 900 | 6 829 |

Leitura: até 10 NPCs o custo é irrelevante; de 100 para 1000 o tempo cresce ~70× para 10× NPCs, ou seja, **há um custo superlinear** (provável varredura O(n²) em percepção/observação/rotinas). Com `tickSeconds=4`, 1000 NPCs ainda cabem folgadamente, mas o orçamento de P14 deve usar coortes para população numerosa (como o plano prevê) e este custo precisa de perfil antes de subir de 1000. Não otimizado agora.
`TestBenchWorldReplays` confirma digest idêntico em duas execuções de 100 ticks com 50 NPCs sintéticos.

## P0.4/P0.5 — Passagens e dungeons

- Passagens: `sinusoide` medula→sangue, `veia_cava` sangue→coração, `arteria_pulmonar` coração→pulmão (gene `citoesqueleto-elastico`), `aorta_ascendente` coração→aorta (gene ou linhagens macrófago/neutrófilo), `arteria_hepatica` aorta→fígado, +3. Servem de base ao grafo lógico de rotas (P2).
- Sem jogadores o tick já avança regras, rotinas, boatos, diretor, agentes e quests (`engine/core/tick.go`).
- Dependências de dungeon (nada removido): Go — `core/dungeon.go`, `def.go`, `step.go`, `tick.go`, `quest.go`, `state.go`, `view.go`, `rewards.go`, `skills.go`, `builds.go`, `advisor_view.go`, `advisor/jev.go`; testes — `dungeon_test.go`, `liver_dungeon_test.go`, `organs_test.go`, `progression_rewards_test.go`, `dungeon_rewards_test.go`; Godot — `bio_dungeon*.gd`, `bio_game_server.gd`, `bio_world.gd`, `bio_hud.gd`, `bio_gate.gd`, `bio_online_client.gd`, `bio_host_sync.gd`, entre outros. Migração (P13) fica para depois da fatia vertical.

## Não executado neste item
Godot headless, Nakama/web QA, Jev ao vivo, replay de journal real (não copiado: não autorizado/necessário), perfil de CPU do custo superlinear.

Gate P0: relatório baseline honesto emitido; Go e testes anteriores mantêm comportamento (`go test ./...` ok).
