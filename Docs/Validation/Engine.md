# Validação do motor — 19/10/2026

Ambiente: Windows 10, Go **1.27.2** oficial (SHA-256 do zip conferido com `go.dev/dl`), instalado em `D:\tools\go`, fora do repositório. Os testes automáticos do provider usam `httptest`. As chamadas reais ao Jev, autorizadas pelo usuário, estão na seção "Jev ao vivo".

## Executado

`go vet ./...` sem avisos e `gofmt -l .` vazio. Depois, `go test -count=1 -v ./...`: **42 testes aprovados, 1 pulado** (o teste ao vivo do Jev, que só roda com `JEV_LIVE=1`).

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
| scenarios | `TestOfferReachesPlayerAnywhereWithGiver` | Mira chama o jogador mesmo na floresta; o evento traz `giver` e `region`; a oferta é retirada quando perde o sentido |
| scenarios | `TestAcceptedQuestMustBeFinished` | `abandon` recusado em Valdoria; nenhuma proposta com missão ativa; intervalo `questGap` respeitado; a próxima oferta chega depois |
| scenarios | `TestQuestEvolvesWithTheWorld` | A janela mostra rank, objetivo e recompensa; com a carga roubada, "Bandidos na estrada" (C) vira "A carga de Lia" (B) com nova meta; o cliente recebe `rankFrom`/`rank` |
| scenarios | `TestQuestFailsWhenSomeoneElseSolvesIt` | Dois procuram o Nino; quem acha conclui, o outro **falha** |
| scenarios | `TestQuestTimeLimit` | O resgate na mina falha no prazo e aplica as consequências |
| scenarios | `TestRefusalAndImmediateOffer` | Recusar o Kael derruba o respeito dele; minerar revela uma missão no mesmo passo |
| scenarios | `TestLegendaryClassIsUnique` | Só um herda a classe Ferreiro Lendário; o outro, que perseguia sem a missão, vira aprendiz (`contender`) e recebe a continuação de rank B |
| scenarios | `TestPlayStyleShapesOffers` | Minerar e forjar ensinam o estilo craft; o Jev recebe o estilo; um artesão recebe a missão de forja |
| scenarios | `TestGossipSpreadsBeliefs` | p2 chega à vila e ouve o boato do veneno (`rumor`, com quem contou), mantendo a idade da observação |
| scenarios | `TestNPCsRememberEachPlayer` | Três recusas deixam o Kael em −3 e ele para de chamar; confiança 4 com a Mira libera o segredo dela |
| scenarios | `TestDirectorPacesTension` | Crise sobe a tensão; no pico, fase "relax" e padrão mais calmo; a tensão decai |
| scenarios | `TestChanceIsDeterministicAndCalibrated` | Mesmo estado, mesmo sorteio; 10% deu entre 8% e 12% em 4.000 sorteios |
| scenarios | `TestHiddenWhiteBoarQuest` | Sinal raro só com 3 troféus e à noite; missão oculta do Sistema (rank A); o Javali Branco só aparece à noite; título raro concedido |
| scenarios | `TestHabitTeachesSkillThatChangesDeeds` | Forjar três vezes ensina Martelo Firme (janela com raridade); depois cada forja conta em dobro |
| scenarios | `TestSillySkillLeadsIntoTheMainStory` | Cinco cochilos ensinam Cochilo Estratégico; o sonho dá a pista que libera o cenário único da história principal |
| scenarios | `TestUselessSpellsFuseAndBecomeFamous` | Florescer achado por sorte; com Chá Morno e servindo chá, vira Chá de Flores (rara) e fama pública; o Tomás leva o jogador ao boato do legado |
| scenarios | `TestSkillsOpenAlternativePaths` | Remover Ferrugem purifica o minério sem a Elena; Passo Leve recupera a carga da Lia sem lutar |
| scenarios | `TestLebrinosTeachTheirOwnTechniques` | Pipo ensina Passo Leve; Sora ensina Corte Lunar (épica, aumenta o respeito); só um vira Guardião (lendária), o outro ganha Amigo dos Lebrinos |
| scenarios | `TestLiveJevDecidesRealWorldDecisions` | Opt-in, com chamada real (ver abaixo) |

### 21/10/2026 — jornadas diferentes por estilo de jogo

`gofmt -l .` vazio, `go vet ./...` sem avisos, `go test -count=1 -v ./...`: **44 aprovados, 1 pulado** (Jev ao vivo), 0 falhas. `worldsim validate` em Valdoria: `ok`. `worldsim simulate -advisor deterministic -players 6 -ticks 300`: 17 missões diferentes oferecidas, 16 concluídas, 8 passos de história, 36 acontecimentos; a história não travou.

| Pacote | Teste | Prova |
|---|---|---|
| scenarios | `TestPlayStylesMakeDifferentJourneys` | Cinco personas (combate, curandeira, quem recusa tudo, exploradora, artesão), cada uma num mundo próprio, 300 ticks, conselheiro determinístico. Estilo dominante = papel (combat, help, explore, craft); Jaccard das missões vistas entre pares ≤ 0,43 (limite 0,6); nenhuma habilidade rara ou acima aprendida por todas; só quem recusa tudo recebe Teimosia Lendária |

O teste revelou dois defeitos de conteúdo, corrigidos no universo (não no motor):

- **Veteranos sem missão do próprio estilo.** As missões introdutórias (`javali`, `minerio-brom`, `primeira-forja`, `martelo-incansavel`) têm objetivo absoluto, e o motor não oferece missão cujo objetivo já vale. Quem caça ou forja antes da oferta as perdia e só recebia missões de outros estilos: o caçador e o artesão viam quase o mesmo conjunto que quem recusa tudo (Jaccard 0,64 e 0,69). Novas missões repetíveis `trilha-dos-javalis` (Kael, combat) e `encomendas-brom` (Brom, craft), com contadores `hunts`/`orders` zerados no primeiro estágio, para contar só o que se faz depois de aceitar. Agora o caçador concluiu 25 missões e recusou 1 (antes 18 recusas).
- **Teimosia Lendária para quem só é exigente.** Bastavam 6 recusas, e o artesão, que recusava missões de combate, a recebia. Agora exige 6 recusas **e nenhuma missão concluída**.

Limite do modelo: as personas repetem uma rotina fixa e não perseguem o objetivo da missão aceita; como Valdoria não permite abandonar, uma missão aceita fora da rotina prende a persona até o fim.

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
| Valdoria com lugares e quem oferece, 150 ticks de 0,7 s | 16 (2 `offer`) | 16 | ~650 ms | 0,40 / 0,88; offer 0,57 | US$ 0,00048 |
| Kepler-9 com lugares, 100 ticks de 0,7 s | 10 | 10 | ~640 ms | 0,25 / 0,04 | US$ 0,00027 |

### Valdoria ampliada (26 missões, 28 ações, 11 acontecimentos, 2 arcos), 6 jogadores, 240 ticks de 0,6 s

| Corrida | Decisões | Pelo Jev no prazo | Custo | Observação |
|---|---|---|---|---|
| Sem histórico de acontecimentos | 54 (22 offer, 29 world, 2 story) | 53 | US$ 0,0020 | O Jev repetiu muito a caravana |
| Com recência por acontecimento | 53 (25 offer, 23 world, 2 story) | 50 | US$ 0,0020 | Bandidos, tempestade, desabamento e Nino apareceram; 6 falhas reais |
| Com recência e prazo de 4 ticks | 53 (23 offer, 27 world, 2 story) | 52 | US$ 0,0020 | 9 acontecimentos diferentes (máximo de 5 caravanas); os dois arcos concluídos; o herdeiro do legado mudou de jogador entre as corridas |

### Com a "mente" do mundo (6 jogadores, 240 ticks de 0,6 s, Jev)

| Medida | Antes | Depois |
|---|---|---|
| Missões diferentes oferecidas | 10 | 15 |
| Decisões de oferta pelo Jev | 23 | 28 |
| Missões ocultas oferecidas | 0 | 2 |
| Relações NPC-jogador formadas | 0 | 13 |
| Decisões do Jev no prazo | 52/53 | 57/58 |

Só 2 boatos foram ouvidos, porque a maioria dos acontecimentos já é anunciada (`reveals`); o boato pesa mais em informação privada.

### Com habilidades (6 jogadores, 300 ticks de 0,5 s, Jev)

65 de 65 decisões pelo Jev no prazo (28 offer, 35 world, 2 story), 18 missões diferentes, 39 boatos ouvidos, relações com 11 NPCs, 3 atualizações de estágio, a Feira dos Magos escolhida 3 vezes. Defeito encontrado: Sorte de Principiante (rara) aprendida por 5 de 6, porque a sorte estava na condição de descoberta. Corrigido: o validador recusa `chance` em `learn`, e a sorte foi para os efeitos das ações. Simulação de conferência: 1 de 6.

Na Kepler-9 o Jev escolheu o ramo "A Ameaça", que não é o padrão determinístico, então a escolha mudou a história. A primeira sonda, com contexto mínimo, teve confiança de 0,08; depois do contexto enriquecido, as decisões de história ficaram entre 0,38 e 0,94.

Problemas encontrados nessas corridas e corrigidos: missão ativa impossível prendendo o jogador (agora `obsolete`); ações repetíveis no universo orbital (agora limitadas).

## Não executado

- `-race`: indisponível sem cgo/gcc nesta máquina.
- Nenhum cliente de engine (Unity/Unreal/Godot) foi conectado ainda.

## 21/10/2026 — novo mundo e lista de personagens

- `store.Log.Reset` / `store.Archive`: o log atual é renomeado para `<universo>-AAAAMMDD-HHMMSS.jsonl` (sufixo `-2`, `-3` se já existir) e um novo começa; nada é apagado.
- `sim.Runner.Reset`: estado novo a partir do universo e uma geração nova; respostas do advisor de um mundo anterior são descartadas (ids de decisão repetem entre mundos).
- API v1 (aditiva): `GET /v1/players` e `POST /v1/world/reset` (exige `"confirm":"new-world"`). `serve -on-universe-change new-world` arquiva um mundo salvo com outra versão do universo.
- Testes: `TestPlayersListAndNewWorld` (lista com nome e região; reset sem confirmação → 400 e o mundo fica; reset → 0 personagens no tick 0; o mesmo id entra de novo) e `TestNewWorldArchivesTheOldOne` (o novo mundo persiste após reiniciar, tem o mesmo digest de um mundo sem antecessor, e o arquivado reabre intacto com o mesmo digest). `gofmt -l` vazio, `go vet` ok, `go test ./...` ok.


## 22/10/2026 — conhecer antes de pedir; ritmo humano

Mudança pedida pelo usuário: o mundo oferecia missões de NPC a quem acabara de entrar e não tinha feito nada, e tudo acontecia rápido demais (tick de 1 s com um universo calibrado para simulação).

- Núcleo: `acquaintance` (predicado "S conhece O"). Missão com `giver` só entra nas candidatas se o giver acreditar conhecer o jogador. `witness`: ao agir numa região, todos os perceptores ali (exceto jogadores) passam a conhecê-lo (fato no mundo + crença por observação). Boatos espalham a crença; jogadores que viajam levam a notícia. `tickSeconds`: o `serve` usa como tick padrão (o `-tick` explícito vence). `accept` virou feito contado pelo motor.
- Valdoria: `acquaintance: "met"`, `met` nos boatos (sem texto), `tickSeconds: 15`, ação `conversar` (sem efeito em relação: conhecer não é gostar), Teimosia Lendária exige 10 recusas e nenhuma missão aceita.
- Testes novos: `TestStrangerGetsNoOfferFromGivers` (60 ticks parado: nenhum NPC oferece nada) e `TestWitnessedDeedMakesPlayerKnown` (quem viu conhece, quem estava longe não; p2 ouve na vila e leva a notícia a Tomas na estrada; Mira então oferece). Testes antigos que supunham ofertas a estranhos passaram a apresentar o jogador (`meet`/`introduce`); `TestQuestsDifferPerPlayer` passou a medir pelas ofertas emitidas (uma oferta "Avise Pipo" era retirada no tick seguinte porque Pipo soube do veneno por boato, o que é o comportamento coerente). `gofmt -l` vazio, `go vet` ok, `go test ./...` ok.
- `worldsim validate` ok. `simulate -advisor jev -pace 800ms -ticks 150 -players 3`: 11 missões concluídas, 7 capítulos de história, títulos "Guardiao do Selo" e "Herdeiro do Ferreiro Lendario"; 32 decisões do Jev (17 world, 2 story, 13 offer), todas no prazo, ~0,5 s, US$ 0,0016 no total. Antes da mudança, a mesma simulação teve 19 decisões de oferta (mais idas e vindas).
- Servidor real (`serve -advisor jev`, sem `-tick`, logo 15 s): um novato ficou 95 s (7 ticks) parado sem nenhuma missão; ao `conversar` com Mira, ela ofereceu "Os aldeoes estao adoecendo" no tick seguinte. O cliente Godot (`--autotest`) seguiu passando com o clique em NPC virando `conversar`.
