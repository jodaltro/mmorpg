# Validação do motor — 19/10/2026

Ambiente: Windows 10, Go **1.27.2** oficial (SHA-256 do zip conferido com `go.dev/dl`), instalado em `D:\tools\go`, fora do repositório. Os testes automáticos do provider usam `httptest`. As chamadas reais ao Jev, autorizadas pelo usuário, estão na seção "Jev ao vivo".

## Executado

`go vet ./...` sem avisos e `gofmt -l .` vazio. Depois, `go test -count=1 -v ./...`: **24 testes aprovados, 1 pulado** (o teste ao vivo do Jev, que só roda com `JEV_LIVE=1`).

> Correção: a primeira versão deste registro dizia "25 testes"; a contagem real da época era 21. Os três testes do Diretor e das missões obsoletas foram acrescentados depois.

| Pacote | Teste | Prova |
|---|---|---|
| scenarios | `TestWorldLivesWithoutPlayers` | Sem jogadores: o selo rompe, a vila adoece, Orin investiga e avisa, Mira cura |
| scenarios | `TestAgentActsOnBeliefNotTruth` | Mira não age com o poço envenenado até saber; a crença guarda a fonte (`communication`, de p1); o jogador evitou o surto |
| scenarios | `TestPrivateKnowledgeAndViews` | p2 não vê crenças, fatos nem eventos privados de p1 |
| scenarios | `TestUniqueScenarioOnlyOneAdvancesTheStory` | Dois concorrentes; só p1 reivindica; p2 é superado, recebe `witnessed` e chega à missão de testemunha; o capítulo nunca é reivindicado duas vezes; o ramo é decidido no prazo |
| scenarios | `TestAdvisorChoosesStoryBranchAndIsRevalidated` | Opção inventada, origem errada e resposta atrasada são recusadas; a escolha do Jev (`pacto`) muda o ramo |
| scenarios | `TestQuestsDifferPerPlayer` | Seis jogadores, ofertas diferentes a partir dos mesmos modelos |
| scenarios | `TestStoryNeverStallsOnTransientState` | Curar o sintoma não encerra a história; o cenário continua aberto |
| scenarios | `TestReplayIsDeterministic` | Replay do log = mesmo digest; duas execuções iguais = mesmo digest |
| scenarios | `TestIdempotencyAndRevisionGuard` | Duplicata é no-op; revisão antiga, tick fora de ordem, ação de adapter por jogador e comando de agente vindo de fora são recusados |
| scenarios | `TestSecondUniverseRunsOnSameCore` | Universo orbital: crew sela o vazamento sozinha; cenário único com rival |
| scenarios | `TestValidatorRejectsBrokenUniverses` | 10 tipos de universo quebrado recusados, além de campo JSON desconhecido |
| scenarios | `TestCoreHasNoInfrastructureImports` | `core` só importa a biblioteca padrão permitida |
| sim | `TestRestartContinuesTheSameWorld` | 40 ticks + reinício + 60 ticks = 100 ticks contínuos, byte a byte; log de outro universo recusado |
| sim | `TestTornLastLineIsDiscarded` | Linha final corrompida é descartada; o mundo continua |
| sim | `TestSlowAdvisorNeverBlocksTheWorld` | Conselheiro travado: 200 comandos de jogo em menos de 1 s; padrão aplicado no prazo |
| sim | `TestAdvisorAnswerAppliedOrRejected` | Resposta válida aplicada e auditada; resposta inválida deixa o padrão agir |
| advisor | `TestJevMapsOpaqueOptionsBack` | IDs internos não chegam ao provedor; `o2` é mapeado de volta |
| advisor | `TestJevRejectsBadAnswers` | Opção desconhecida, modelo errado, confiança inválida, HTML, HTTP 500 e chave ausente são recusados |
| advisor | `TestJevTimeout` | Timeout de 50 ms respeitado |
| api | `TestCommandsAndPerObserverViews` | Contrato v1; `tick`/`resolve`/campo `damage` recusados; visões separadas; cross-origin 403 |
| api | `TestStreamPushesOnlyVisibleEvents` | O SSE de p2 recebe eventos públicos e nenhum evento privado de p1 |
| scenarios | `TestDirectorProposesHappeningsAndAdvisorPicks` | O diretor propõe acontecimentos elegíveis e `none`; um acontecimento inventado é recusado; "lobos" ocorre, é revelado e cria a missão de caça; o cooldown impede a repetição |
| scenarios | `TestDirectorDefaultsWithoutAdvisor` | Sem conselheiro, o padrão faz acontecimentos ocorrerem |
| scenarios | `TestObsoleteQuestFreesTheSlot` | A missão ativa que perdeu o sentido vira `obsolete` |
| scenarios | `TestLiveJevDecidesRealWorldDecisions` | Opt-in, com chamada real (ver abaixo) |

## Execuções manuais

- `worldsim simulate` com 4 jogadores roteirizados por 240 ticks, nos dois universos. Em Valdoria, o arco *A Maldição do Selo* foi concluído: origem e restauração pelo Jogador 2, capítulo coletivo por três jogadores, continuações de rival para os outros. Em Kepler-9, Primeiro Contato pelo Jogador 1 e Aliança para todos.
- `worldsim serve` real em `127.0.0.1:8095` (tick de 100 ms, conselheiro determinístico): `health`, `join`, `act`, `views` e cross-origin 403 via `curl`. O processo foi encerrado e reaberto sobre o mesmo log: voltou no tick 29 com as crenças e missões da jogadora.

## Jev ao vivo (chamadas reais, OpenRouter Decisions, `typesafe/jev-1.13-20260917`)

- Sonda bruta: HTTP 200 em 1,6 s; formato da resposta igual ao esperado pelo motor (`answers.choice`, `probabilities`, `confidence`, `usage.cost`, `id gen-dec-…`, `provider TypeSafe`).
- `TestLiveJevDecidesRealWorldDecisions`: 3 de 3 decisões reais (duas ofertas e um ramo de história) com escolha válida; latência de 600 a 960 ms; cerca de US$ 0,00003 por decisão. O ramo escolhido foi aplicado pelo motor.
- Mundo rodando com `-advisor jev`:

| Corrida | Decisões | Resolvidas pelo Jev no prazo | Latência média | Confiança média (world / story) | Custo |
|---|---|---|---|---|---|
| Valdoria, 120 ticks de 1 s, antes do diretor | 1 (`story`) | 1 | 926 ms | — / 0,94 | US$ 0,000031 |
| Valdoria, 150 ticks de 0,8 s | 14 (13 `world`, 1 `story`) | 14 | ~680 ms | 0,43 / 0,86 | US$ 0,00042 |
| Valdoria, 120 ticks de 0,7 s | 11 | 11 | ~635 ms | 0,43 / 0,88 | US$ 0,00033 |
| Kepler-9, 100 ticks de 0,7 s | 9 | 9 | ~645 ms | 0,31 / 0,38 | US$ 0,00025 |

Na Kepler-9 o Jev escolheu o ramo "A Ameaça", que não é o padrão determinístico, então a escolha mudou a história. A primeira sonda, com contexto mínimo, teve confiança de 0,08; depois do contexto enriquecido, as decisões de história ficaram entre 0,38 e 0,94.

Problemas encontrados nessas corridas e corrigidos: missão ativa impossível prendendo o jogador (agora `obsolete`); ações repetíveis no universo orbital (agora limitadas).

## Não executado

- `-race`: indisponível sem cgo/gcc nesta máquina.
- Nenhum cliente de engine (Unity/Unreal/Godot) foi conectado ainda.
