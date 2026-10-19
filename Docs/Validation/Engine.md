# Validação do motor — 19/10/2026

Ambiente: Windows 10, Go **1.27.2** oficial (SHA-256 do zip conferido com `go.dev/dl`), instalado em `D:\tools\go`, fora do repositório. Nenhuma chamada paga ao Jev foi feita: os testes do provider usam `httptest`.

## Executado

`go vet ./...` sem avisos e `gofmt -l .` vazio. Depois, `go test -count=1 -v ./...`: **25 testes, 25 passaram**.

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

## Execuções manuais

- `worldsim simulate` com 4 jogadores roteirizados por 240 ticks, nos dois universos. Em Valdoria, o arco *A Maldição do Selo* foi concluído: origem e restauração pelo Jogador 2, capítulo coletivo por três jogadores, continuações de rival para os outros. Em Kepler-9, Primeiro Contato pelo Jogador 1 e Aliança para todos.
- `worldsim serve` real em `127.0.0.1:8095` (tick de 100 ms, conselheiro determinístico): `health`, `join`, `act`, `views` e cross-origin 403 via `curl`. O processo foi encerrado e reaberto sobre o mesmo log: voltou no tick 29 com as crenças e missões da jogadora.

## Não executado

- Chamada real ao Jev (custo; exige `OPENROUTER_API_KEY` em `engine/.env`, já copiada do arquivo local, e `-advisor jev`).
- `-race`: indisponível sem cgo/gcc nesta máquina.
- Nenhum cliente de engine (Unity/Unreal/Godot) foi conectado ainda.
