# Marco 03 — evidência de validação

Executado em **13/10/2026**, projeto D:/unity/Mmorpg, Editor conectado **Unity 6000.6.5f1**, CLI **1.0.0-beta.13**, Pipeline existente **0.8.0-exp.1**. Go **1.27.2 windows/amd64** portátil, fora do repositório; módulo requer Go 1.23+. Nenhuma atualização da Unity, recriação de projeto/cena ou commit.

Atualização: após configuração da chave pelo usuário, **a validação real OpenRouter/Jev passou**, incluindo Unity, diálogo, diário, save JSON e recarga. Consulte [Marco03Real](Marco03Real.md) para IDs, probabilidades, latências, custos e evidências. A tabela abaixo preserva o resultado da entrega inicial, antes da configuração da chave.

## Resultados da entrega inicial

| Verificação | Resultado |
|---|---|
| Compilação Unity pelo Editor | completed, failed=false, compilationFailed=false |
| EditMode | **33/33 aprovados**, zero falhas/ignorados |
| PlayMode | **21/21 aprovados**, zero falhas/ignorados |
| Testes anteriores | **32 preservados**: 19 EditMode + 13 PlayMode |
| Testes acrescentados Unity | **22**: 14 EditMode + 8 PlayMode |
| Go go test -count=1 -json ./... | **14 testes principais + 6 subcasos aprovados**, zero falhas |
| Go TestManualOpenRouter | **1 ignorado**, exige opt-in e chave |
| Go go vet ./... | Executado, aprovado |
| Go go build ./cmd/server | Executado, aprovado; executável temporário fora do repo |
| Editor → serviço Go local | Executado, provedor Deterministic, resposta aplicada/persistida |
| OpenRouter/Jev real | **Não executado**: OPENROUTER_API_KEY não configurada |

Recompile e suítes foram executados em etapas pelo Editor conectado. set_autotick foi habilitado; Application.runInBackground já estava true. As suites rodaram sequencialmente, aguardando completed antes da seguinte. A implementação não depende de chave real nem chamadas pagas no CI.

## Evidências

- [Compilação final](m03-recompile.json).
- [EditMode final](m03-editmode.json) e [PlayMode final](m03-playmode.json), incluindo nomes/resultados individuais; [repetição com falha intermitente de teclado](m03-playmode-intermittent.json) e [execução isolada do teclado](m03-keyboard-isolated.json).
- [Go JSONL](m03-go-tests.jsonl) e [resumo Go](m03-go-summary.json).
- [Verificação intermediária do domínio](m03-stage-domain-editmode.json).
- [Editor → Go](m03-live-go-unity.json).
- [Frames avançando](m03-live-frames.json): 6271 → 6310, condição met, sem timeout.
- [Captura do Diário de Jornada](m03-journal.png), inspecionada visualmente.
- [Console histórico](m03-console-errors.json), [avisos observados](m03-console-warnings.json) e [status final](m03-console-status.json).

O console histórico contém uma exceção UnityConnectWebRequestException / Token Exchange de autenticação do Editor às 18:22 UTC, anterior à validação interativa Editor→Go, e a rejeição de um caminho de captura com .. às 18:43 UTC. Não são falhas do cliente OpenRouter. O status final informa compilationFailed=false e consoleErrors=0 em groundTruth. Nenhum erro de gameplay foi observado no fluxo validado; o histórico não foi apagado. A suíte também emite o aviso de física “Cannot use linearVelocity on a static body”; os testes de combate continuam aprovados. Alertas do analisador Unity sobre métricas nullable/dictionary foram corrigidos usando propriedades C# serializadas pelo adaptador JSON.

## Fluxo validado dentro do Editor

Serviço Go temporário em **127.0.0.1:8091**, modo Deterministic; healthz retornou status ok. Unity em modo OpenRouter para exercitar o transporte local. AgentScripts/ValidateJevPlay.cs recarregou a cena com persistência em memória isolada; Prepare validou rastros e conversa com Orin; três ataques reais da OfflineAuthority reduziram a vida do lobo 60 → 40 → 20 → 0. Depois ocorreram coleta, conversa e entrega válidas a Mira.

Inspect confirmou:

- decisão `det:18952eb0fd92e85843841971b24c06f2ff8263075c51845e28d8b0da4d1cb28e`;
- modelo deterministic-v1, opção mira-scientific, fallback=false, latência 0ms (resolução em memória abaixo de 1ms);
- decisão presente na memória salva e no replay;
- diálogo e Diário de Jornada correspondendo à reação persistida;
- rotas A/B Completed, confiança de Mira/Orin mantida e uma única habilidade;
- frame 11960 no momento da inspeção.

O resultado demonstra Unity → Go → memória/UI, **não uma chamada ao Jev real**. O cliente Jev foi validado contra httptest.Server; o cliente Unity contra servidores HTTP loopback simulados. O teste PlayMode com backend desligado validou combate real, fallback, persistência, diário, conversa repetida e recarga.

O serviço temporário foi encerrado e o Editor saiu do Play. O save original foi restaurado a partir da geração anterior íntegra após a validação; sua igualdade foi conferida por SHA-256. Nenhum resultado de teste substituiu a jornada do jogador. A captura inicialmente gerada pelo Pipeline sob Assets foi transferida para Docs/Validation, removendo apenas os artefatos gerados dessa captura.

## Cobertura acrescentada

| Requisito | Evidência automatizada |
|---|---|
| Contratos e metadados | Go TestContractsRoundTrip; Unity JSON em disco, contrato HTTP local e auditoria de fallback |
| Pergunta Choice e IDs autorizados | TestBuildChoiceIncludesOnlyEligibleIDs; TestOpenRouterRequestAndAllowedSelection |
| IDs desconhecidos/inelegíveis | TestUnknownOrIneligibleIDsRejected; DecisionTests; LocalDecisionTests |
| Nenhum candidato | TestNoEligibleDoesNotCallProvider; NoCandidateBeforeValidatedDelivery |
| Repetição/persistência | Concorrência e reinício Go; quatro reações em replay; JSON; conversa/recarga de cena |
| Indisponibilidade, timeout, HTTP/JSON inválidos | httptest Go e HTTP simulado Unity; backend desligado |
| Baixa confiança e gate configurável | TestProviderFailuresFallbackAndNeverLeakCredentials; TestConfidenceGateDisabledByDefault; auditoria Unity |
| Estado obsoleto/troca de jornada | TestChangedStateConflictsAndCorruptStorageFailsClosed; DecisionTests; resultados atrasados Runtime |
| Rotas A/B e habilidade | Todos os testes anteriores, Inspector vivo e teste com backend desligado |
| Credenciais e corrupção | Erros sanitizados, teste de eco de chave fictícia, checksum Go, corrupção de armazenamento |

Os testes foram refinados durante a implementação antes dos resultados finais acima. Uma expectativa de revisão impossível no teste de replay foi corrigida; o primeiro comando Go foi repetido depois da extração completa do SDK portátil. Falhas de quoting de argumentos PowerShell da validação interativa foram corrigidas; nenhum desses comandos malsucedidos foi contabilizado como aprovação. Uma repetição da suíte apresentou falha intermitente no teste anterior KeyboardMovesAttacksAndDodgesThroughPlayerController (direção após espera de 0.05s). Esse resultado foi preservado como evidência; o teste passou isoladamente (1/1) e a repetição completa terminou com 21/21 aprovados, mantendo código e asserções originais.

## Arquivos criados e alterados

Criados:

- backend/decisions: go.mod, contracts.go, provider.go, service.go, http.go, decisions_test.go, cmd/server/main.go, config.example.json, Start-Decisions.ps1, .gitignore, examples/mira-request.json, examples/mira-response.json.
- Domain/JourneyDecisions.cs: contexto, registros, auditoria e IDs/textos fixos.
- Runtime/LocalDecisionClient.cs e Runtime/MiraDecisionOrchestrator.cs: transporte e orquestração assíncrona.
- Tests/EditMode/DecisionTests.cs e Tests/PlayMode/LocalDecisionTests.cs.
- AgentScripts/ValidateJevPlay.cs.
- Docs/JevIntegration.md, este relatório e evidências m03-* listadas acima.
- Metadados Unity gerados para os cinco novos arquivos C# sob Assets.

Alterados:

- Assets/Mmorpg/Domain/JourneyContracts.cs: lista de decisões no snapshot.
- Assets/Mmorpg/Domain/JourneyEngine.cs: elegibilidade/revalidação de reação, conhecimento, replay v1/v2 e diálogo.
- Assets/Mmorpg/Runtime/JourneySession.cs: configuração serializada e ciclo assíncrono da reação.
- Assets/Mmorpg/Runtime/JourneyHud.cs: reação persistida no diário existente.
- Docs/Architecture.md, Docs/EventSystem.md e Docs/GoEventContract.md: referências ao Marco 03, preservando a documentação dos marcos anteriores.

Arquivos existentes de testes, JsonJourneyPersistence, combate, WeaknessReading, cenas, versão do Editor e pacotes não foram modificados. O repositório já estava inteiramente não rastreado antes desta execução; nenhum arquivo foi adicionado ao index e nenhum commit foi feito.

## Execução e limites

### Acompanhamento: segredo local .env

A pedido do usuário, foi acrescentado suporte a backend/decisions/.env, ignorado pelo Git e fora dos assets Unity. O arquivo foi criado com valor vazio; nenhuma chave foi solicitada, lida em saída ou registrada. O ambiente OPENROUTER_API_KEY tem prioridade; o modo Deterministic não lê o arquivo. O teste manual opt-in também aceita esse .env. .env.example é um modelo sem credenciais.

Novos arquivos: backend/decisions/env.go, env_test.go e .env.example; arquivo local .env não versionável. Alterados: cmd/server/main.go, decisions_test.go, .gitignore raiz/backend e JevIntegration.md. Testes Go, vet e build foram executados novamente com sucesso, incluindo três novos testes de parsing, precedência/ausência e rejeição sem vazamento: **17 testes principais + 6 subcasos aprovados**, com o teste manual ainda ignorado. Nenhum código Unity foi alterado neste acompanhamento; as suítes Unity não foram reexecutadas.

Consulte [JevIntegration](../JevIntegration.md) para comandos Windows, configuração sem credenciais, exemplos, teste manual real e migração Go/Nakama.

Persistência offline e servidor consultivo local são provisórios: um processo, sem autoridade multiplayer, autenticação, quotas ou calibração de confiança. A interface não deve ser exposta diretamente aos jogadores em produção. O gate fica desabilitado por padrão. Uma falha entre cobrança e gravação pode repetir uma chamada após reinício; escolhas aplicadas seguem idempotentes. API alpha/schema e comportamento do modelo ainda precisam ser confirmados pelo teste manual com a chave no processo Go.
