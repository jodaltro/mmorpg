# Marco 02 — acontecimentos, memória e descoberta

## Fluxo

Atualização Marco 03: [JevIntegration](JevIntegration.md) descreve a seleção assíncrona de reações, registros persistidos e replay v2, mantendo estas regras de fatos/rotas. A ausência de backend/Jev descrita abaixo corresponde à entrega original do Marco 02.

`Input → intenção → OfflineAuthority / JourneySession → GameEvent validado → JourneyEngine → fatos → oportunidades elegíveis → política → validação da consequência → memória → apresentação + persistência`.

O domínio não referencia Unity, física, JSON, NPCs de cena ou transporte. `JourneyEngine` possui a memória e fornece cópias para leitura. O contrato `ApplyValidated` é a entrada **da autoridade**, não um endpoint para clientes. Nomes de fontes não comprovam autenticidade: no futuro servidor, apenas produtores internos autorizados podem emitir esses eventos.

`OfflineAuthority.HitConfirmed` só ocorre quando `ApplyDamage` aceita o dano. `JourneySession` reconhece a morte do lobo nesse callback; ataques que erram, batem em paredes ou encontram imunidade não geram derrota. A coleta exige uma derrota registrada e interação junto à amostra. Conversas, rastros e entrega exigem jogador vivo, alvo registrado, proximidade e linha de visão. Não há desbloqueio direto na UI.

## Contratos e responsabilidades

| Arquivo | Responsabilidade |
|---|---|
| `Domain/JourneyContracts.cs` | Envelope v1, payloads tipados v1, snapshot de memória, contratos de persistência/política, IDs do conteúdo |
| `Domain/JourneyEngine.cs` | Redução de fatos, conhecimento com fonte, elegibilidade, consequências validadas, idempotência, restauração |
| `Domain/WeaknessReading.cs` | Marca, duração, alcance, cooldown e bônus consumido somente no acerto confirmado |
| `Runtime/JourneySession.cs` | Autoridade offline da história; validação espacial, fatos reais, save, continuação e encontro de observação |
| `Runtime/JourneyInteractable.cs` | Tipo e alcance de uma interação; não referencia outros NPCs |
| `Runtime/JourneyInput.cs` | E, Q, Tab e N expressam intenções |
| `Runtime/JourneyHud.cs` | Diálogo, dica contextual e diário uGUI/TMP |
| `Runtime/JsonJourneyPersistence.cs` | JSON, checksum, escrita segura e recuperação; adaptador em memória para testes |
| `AgentScripts/AddForestStory.cs` | Extensão idempotente da cena existente via Pipeline |

Não existe grafo de dependências entre scripts de NPC. `ForestContent` reúne os IDs desta história, as regras estão no reducer e as consequências usam IDs de rota. A pequena história tem regras explícitas em C#, evitando um framework de quests. Parâmetros de Leitura de Fraquezas são serializados em `JourneySession`, configuráveis no Inspector e copiados para o domínio. Novas histórias podem acrescentar regras e definições sem fazer NPCs referenciarem scripts de outros NPCs.

## Memória, conhecimento e idempotência

O snapshot v1 contém histórico de entradas verificadas, fatos aceitos/derivados, oportunidades, técnicas, evidências possuídas/entregues, relações e conhecimento dos NPCs com `sourceEventId`. O jogador conhece os fatos que realizou. Um NPC conhece somente informação transferida validamente: Orin recebe os rastros na conversa; Mira recebe a amostra na entrega. Examinar rastros sozinho não informa Orin e derrotar o lobo não informa Mira.

Repetições são protegidas em três níveis: `eventId`, chaves semânticas (encontro, rastro, evidência e conversa com a mesma informação) e estado terminal da consequência. A técnica é registrada por ID, e `AbilityUnlocked` ocorre uma vez. A mesma evidência não pode ser coletada novamente depois de entregue. A segunda rota aumenta a confiança do respectivo NPC e registra seu conhecimento, mesmo se a técnica já estiver disponível.

Oportunidades: `Unknown → Available → Started → Completed`. `Closed` está previsto no contrato para conteúdo futuro; esta história não fecha rotas mutuamente. `OpportunityDiscovered` registra a passagem de desconhecida para disponível. Examinar rastros disponibiliza a rota B; compartilhar com Orin a inicia. Coletar amostra disponibiliza A; entregar inicia e conclui A no mesmo processamento validado.

## Política determinística e entrada futura do Jev

`EligibleConsequences()` gera IDs a partir de fatos e estados. `IConsequencePolicy.Select()` escolhe um ID; `Resolve()` revalida contra os candidatos atuais e aplica a consequência dentro do domínio. A política atual escolhe o primeiro candidato na ordem estável A/B. Uma resposta inventada não concede itens, técnica ou fatos.

Jev poderá substituir a seleção/ranking, recebendo um contexto limitado de fatos conhecidos e IDs elegíveis. O servidor Go continuará responsável por validar e aplicar. Uma política assíncrona exigirá revalidar a candidatura após a resposta; decisões aprovadas deverão ser persistidas pelo servidor para replay independente do modelo. O replay offline v1 usa as regras e a política determinística v1; não é um formato definitivo de event sourcing para decisões de IA.

## História e teste manual

Abra `Assets/Mmorpg/Scenes/OfflineClearing.unity` e Play. O save é carregado automaticamente. N começa uma jornada nova e limpa a memória ativa; R recarrega a cena continuando a memória salva. Não há XP, nível ou custo em pontos.

| Entrada | Uso |
|---|---|
| WASD / setas | Mover |
| J / clique esquerdo | Atacar |
| Espaço / Shift esquerdo | Esquivar |
| E | Interagir com alvo próximo |
| Q | Leitura de Fraquezas, quando aprendida |
| Tab | Abrir/fechar Diário de Jornada (J já é ataque) |
| R | Continuar a jornada salva, recarregando o encontro |
| N | Nova jornada, para testar outra rota |

**Caminho A:** N; derrote o lobo roxo; aproxime-se do quadrado roxo junto ao corpo e pressione E; vá até Mira em `(-5, 0)`; converse com E e pressione E novamente para entregar. A entrega válida concede Leitura de Fraquezas e confiança com Mira.

**Caminho B:** N; examine com E os rastros em `(0, 2)`; converse com Orin em `(-2, 3)`; derrote o lobo depois dessa conversa. A vitória observada concede a técnica e confiança com Orin, sem exigir coleta ou entrega.

**As duas rotas:** faça B antes da primeira derrota e depois entregue a amostra a Mira; ou faça A primeiro, examine os rastros e fale com Orin. Neste último caso Orin indica R para um segundo encontro corrompido. Vença esse encontro real para concluir B: há novo conhecimento/confiança e nenhum segundo desbloqueio.

Q marca o alvo vivo mais próximo (lobo ou boneco de treinamento), com linha de visão e até 3 unidades. A marca amarela dura 5 s; cooldown de 8 s; o próximo acerto confirmado recebe +10, limitado ao parâmetro `maximumBonus`. Erros e dano recusado não consomem a marca; expiração, alvo diferente e novo acerto sem marca não concedem bônus. Para experimentá-la após qualquer rota, use o boneco de treinamento em (-4, -2), que se recupera automaticamente; o encontro de observação de Orin também continua disponível. No Inspector, os valores estão em `ForestStory / JourneySession / Weakness Parameters`.

## Persistência e recuperação

Arquivo `Application.persistentDataPath/journey-v1.json`; `.bak` guarda a geração íntegra anterior e `.tmp` guarda a escrita em andamento. JSON usa Newtonsoft já instalado no projeto, sem `TypeNameHandling`. O envelope v1 contém JSON do snapshot e SHA-256 do conteúdo. `JsonUtility` foi descartado após teste demonstrar que ele não preserva os nulos da união de payloads.

Save: validar snapshot por replay → escrever `.tmp` → `Flush(true)` → reler/validar → `File.Replace` com backup da versão anterior íntegra, ou `File.Move` no primeiro save. Uma primária corrompida não substitui o backup íntegro durante a recuperação. Load tenta primária, backup e temporário, nessa ordem, verifica versão/checksum e reconstrói o domínio a partir das entradas. Caches persistidos precisam concordar com o replay. Se todas as gerações falharem, o HUD informa e bloqueia autosave para preservar os arquivos até N iniciar explicitamente outra jornada.

`IJourneyPersistence` permite trocar o adaptador. Um backend Go autoritativo não aceitará o JSON local como verdade. Checksum/replay detectam corrupção acidental e inconsistência, não autenticam um arquivo editado por um adversário. O histórico só é confiável porque neste protótipo é produzido pela autoridade offline.

## Limites do protótipo

- Um jogador, um lobo por encontro, um boneco reutilizável e uma história fixa; a amostra é garantida, sem RNG ou grind.
- Continuar preserva memória e consequências do encontro, mas reinicia vida, posição e cooldowns transitórios. A amostra reaparece junto ao local do lobo carregado; sua posição exata no mundo não é salva.
- O encontro adicional de Orin usa o mesmo placeholder/IA, com outro ID semântico. Não há simulação persistente do mundo inteiro.
- Autosave síncrono e replay linear são adequados ao pequeno histórico atual. Produção exigirá limites, migrações, compactação e I/O assíncrono com controle transacional.
- Recuperação usa a última geração íntegra disponível; uma falha pode perder a ação mais recente. Nova jornada substitui a primária; a geração anterior ainda pode existir no backup.
- Diálogos são textos condicionais fixos. O diário lista descobertas relevantes, sem impor cada fato como tarefa ou notificação.
- Não há integração Jev, Go ou Nakama, nem transporte, segurança multiplayer ou autoridade remota.

## Inventário da entrega

Criados: os três arquivos Domain acima; os cinco adaptadores/componentes Runtime acima; `Tests/EditMode/JourneyTests.cs`; `Tests/PlayMode/JourneySceneTests.cs`; `AgentScripts/AddForestStory.cs`; `AgentScripts/ValidateForestPlay.cs`; `Docs/EventSystem.md`; `Docs/GoEventContract.md`; `Docs/Validation/Marco02.md`; evidências `Docs/Validation/m02-*` e metadados Unity dos novos assets.

Alterados: `Runtime/OfflineAuthority.cs` (callback de acerto e bônus validado); `Runtime/ActorHealth.cs` (restauração de derrota); `Runtime/HealthHud.cs` (mensagem pós-vitória); `Runtime/Mmorpg.Runtime.asmdef` (referência ao Newtonsoft existente); `Tests/PlayMode/OfflineSceneTests.cs` (persistência isolada nos testes); `Scenes/OfflineClearing.unity` (extensão serializada); `Docs/Architecture.md`. `AGENTS.md` e `BuildOfflineScene.cs` foram preservados. Sem commit.


