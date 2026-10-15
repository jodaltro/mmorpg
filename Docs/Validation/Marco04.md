# Marco 04 — validação executada

Executada em **13/10/2026** no Editor conectado Unity **6000.6.5f1**, CLI **1.0.0-beta.13**, Pipeline existente. Não foram atualizados Unity ou pacotes. Cena `OfflineClearing.unity` estendida incrementalmente, preservando o projeto, sample assets, combate, rotas A/B e Leitura de Fraquezas. Nenhum commit.

## Resultado final

| Verificação | Resultado executado |
|---|---|
| Unity EditMode | **59/59 aprovados**, zero falhas/ignorados |
| Unity PlayMode | **31/31 aprovados**, zero falhas/ignorados |
| Repetição completa PlayMode após isolamento de entrada | **31/31 aprovados** novamente |
| Total Unity | **90/90**, incluindo os 54 anteriores e 36 novos |
| Go automático | **26 testes principais + 8 subcasos aprovados**, zero falhas; dois testes pagos explicitamente ignorados |
| go vet | Exit 0 |
| Compilação | recompile_status completed, failed=false |
| Play ao vivo | Frames avançando: wait_for met=true, 21646 → 21682, framesObserved=2 |
| Save do jogador | Duas gerações originais preservadas, hashes idênticos; nenhum arquivo original removido |
| Chamadas reais autorizadas | **5** chamadas bem-sucedidas, incluindo três jornadas independentes na Unity e avaliação direta com três candidatos |

Evidências: [EditMode](m04-editmode.json), [PlayMode](m04-playmode.json), [repetição PlayMode](m04-playmode-repeat.json), [Go JSONL](m04-go.jsonl), [compilação](m04-recompile.json), [frames](m04-frames.json), [Console em Play](m04-console-play.json), [Console final](m04-console-final.json), [preservação de saves](m04-save-preservation.json).

`set_autotick` foi habilitado e a compilação foi iniciada/polled antes das suites; testes EditMode e PlayMode rodaram sequencialmente. As últimas duas suites PlayMode rodaram após isolar teclados/mouses nativos do Input System, com restauração ao terminar. A Console final distingue histórico antigo de groundTruth atual: não foi apagada para esconder falhas. Os erros de ferramentas e assertions listados abaixo são separados dos erros de gameplay/compilação.

## Cobertura implementada

`WorldEventTests` verifica elegibilidade e IDs de regras, AND/OR e tempo, três candidatos simultâneos, escolha independente, lista vazia, escolha Jev válida/inválida, probabilidades versus confiança, none sem bloqueio da técnica, revisão obsoleta, conhecimento privado/transmitido/público, agenda e relógios simulados, tempo real offline, gatilhos futuros de fato/conversa, invalidação regional, save/load/restart e duplicação, corrupção de projeção/fonte/auditoria, pista obrigatória, opt-in e hit de treinamento, conclusão/expiração/fechamento, limite ativo, save v2, recuperação por backup e rotas A/B.

`ThreeIndependentHistoriesProduceDifferentPersistentConsequences` executa A (investigação/alerta), B (rastreamento/vestígio) e C (esquiva/conversa/treino), salva cada histórico e repete o replay sem efeitos/decisões adicionais. `NewJourneysWithSameRevisionUseDifferentEvaluationIdsAndReloadKeepsIdentity` protege a separação de jornadas no cache.

`WorldSceneTests` usa a cena existente e **combate/interações reais**: amostra e Mira, pista espacial e Orin, preparo/esquiva aceitos, hit no boneco, rejeição de ataque comum/erro de alcance, backend desligado, expiração e nova jornada. Não injeta dano ou concede técnica pela UI. `WorldDecisionTests` verifica resultado inválido, região alterada durante resposta, sessão substituída e modo determinístico sem HTTP. Os testes Go usam httptest e diretórios temporários; regressão não usa API paga.

## Apresentação e transporte determinístico

`AddWorldEvents.Run` foi executado duas vezes via Pipeline: primeira extensão da cena limpa e segunda execução retornando “already authored; unchanged”. Quadro em (-6,2.5), vestígio em (3,2.5), referências serializadas e textos TMP existentes.

Uma instância temporária do **mesmo serviço Go** em `127.0.0.1:8092`, modo Deterministic, comprovou o transporte Unity → Go: [metadados](m04-go-transport.json). Três ataques aceitos reduziram o lobo 60 → 40 → 20 → 0: [1](m04-attack-1.json), [2](m04-attack-2.json), [3](m04-attack-3.json). Pista examinada e investigação concluída; amostra entregue, relógio avançado e aviso publicado. [Reload](m04-reload.json) preservou notice=true, executed=1, decisions=2 e abilities=1.

Capturas foram inspecionadas visualmente, com texto legível e placeholders reais: [vestígios](m04-tracks.png), [diário](m04-journal.png), [quadro](m04-alert.png) e [treino real](m04-training.png). A pista não aparece no diário antes de exame; treino concluído permanece com “Técnica ainda desconhecida” na jornada C.

## Integração real Jev/OpenRouter autorizada

Autorização explícita do usuário recebida durante a execução: “voce pode usar chamadas pagas a vontade, sem limite”. A regressão automática continuou sem chamadas pagas. A instância temporária em 8092 foi reiniciada em OpenRouter com diretório próprio; o serviço do usuário em 8091 não foi interrompido. Credencial foi lida somente pelo backend, a partir do arquivo local ignorado, sem impressão de chave/headers/corpo upstream.

Modelo efetivo de todas as chamadas: **typesafe/jev-1.13-20260917**. Confidence gate desabilitado. Cada chamada teve fallback=false/TypeSafe e ID `gen-dec-*`; os validadores recusam tratar fallback como evidência real.

| Execução | Escolha | Confiança | Probabilidade da escolha | Latência | Custo informado USD |
|---|---|---|---|---|---|
| A preliminar, antes do ajuste de identidade | forest-alert | 0.80 | 0.90 | 756 ms | 0.000037800 |
| Provedor direto, três candidatos sintéticos rotulados | forest-alert | 0.33 | 0.50 | 737 ms | 0.000064974 |
| Jornada A final: investigação real/Mira | forest-alert | 0.74 | 0.87 | 696 ms | 0.000038514 |
| Jornada B final: rastros e combate real | new-threat-tracks | 0.90 | 0.95 | 418 ms | 0.000038682 |
| Jornada C final: esquiva confirmada e conversa | hunter-training | 0.72 | 0.86 | 741 ms | 0.000036036 |

**Total informado: US$ 0.000216006**, cinco chamadas novas. Latências observadas **418–756 ms**. Token inputs: 900, 1547, 917, 921, 858; outputs: 34, 52, 34, 38, 34. Valores medidos não são estimativa de custo/latência de produção.

Evidências: [A preliminar](m04-real-A-preliminary.json), [teste direto com múltiplos candidatos](m04-real-multiple-provider.txt), [A final](m04-real-A.json), [B final](m04-real-B.json), [esquiva real C: saúde 100 e uma ação verificada](m04-real-C-dodge.json), [C final](m04-real-C.json), [treino concluído](m04-real-C-completed.json), [custos](m04-real-cost-summary.json).

As três jornadas finais foram independentes, com arquivos JSON temporários separados:

- **A:** derrota, coleta e entrega reais; escolha alert; publicação após o relógio configurado; quadro lido e decisão recuperada em [reload A](m04-real-A-reload.json) / [metadados após reload](m04-real-A-after-reload.json).
- **B:** rastros e conversa reais, derrota, escolha vestígios; objeto interativo examinado, retorno a Orin e conclusão; [reload B](m04-real-B-reload.json) / [metadados após reload](m04-real-B-after-reload.json).
- **C:** preparação e esquiva confirmadas pela autoridade, informação compartilhada com Orin, escolha treino; aceitação deliberada e hit real no boneco; conclusão persistida com **zero habilidades**; [reload C](m04-real-C-reload.json) / [metadados após reload](m04-real-C-after-reload.json).

Repetição do request C no Go retornou o **mesmo ID** e não regravou o arquivo: [cache repeat](m04-real-cache-repeat.json). O uso/custo presente na resposta repetida refere-se à chamada original; não foi somado como nova cobrança. Não houve novas avaliações após os reloads.

## Falhas e reprodução, sem ocultação

1. **Novo teste C tentou atacar durante a janela de esquiva:** primeira PlayMode 26/27; falha na assertion de RequestAttack. A regra estava correta. O teste passou a aguardar 0.23 s de jogo, sem mudar cooldown/imunidade. [Execução inicial](m04-playmode-initial.json).
2. **Três testes antigos de teclado oscilaram:** uma regressão posterior teve 28/31. Falhas: `KeyboardInteractsOpensJournalAndNewJourneyResetsPersistentMemory`, `LearnedMarkAppliesBonusOnSuccessfulHitOnlyAndWallsBlockActivation` e `KeyboardMovesAttacksAndDodgesThroughPlayerController`. O primeiro passou na reprodução isolada. Causa provável: dispositivos nativos/foco substituindo o teclado sintético atual; não foi instrumentada a troca de Keyboard.current no frame exato, portanto a causa não é declarada como comprovada. Adicionado `SceneInputIsolation` na suíte, desabilitando apenas dispositivos Unity nativos previamente habilitados e restaurando-os ao terminar. Assertions e os 54 testes anteriores permaneceram intactos. **Duas regressões completas 31/31** após a alteração. [Falhas](m04-playmode-keyboard-failures.json), [reprodução](m04-keyboard-reproduction.json), [repetição final](m04-playmode-repeat.json).
3. **Harness manual inicial:** preparação ocorreu depois de o personagem morrer com a IA ativa; tentativa de Trace recusada. O validador passou a recarregar atores e desabilitar IA/controle na preparação. Uma tentativa de wait_for sofreu perda de aspas JSON pelo PowerShell; a invocação foi corrigida com argv via subprocess e confirmou frames avançando. O relógio simulado inicial não foi semeado com o checkpoint, deixando o primeiro avanço abaixo de dueAt; o harness passou a avançar a partir do horário salvo.
4. **Identidade entre novas jornadas:** inspeção durante a validação real revelou que uma identidade baseada apenas em ator/mundo/revisão poderia colidir no cache após N. Corrigida para primeira causa verificada + revisão; acrescentado teste de nova jornada e estabilidade após reload. A chamada A preliminar foi preservada e incluída no custo, seguida das três jornadas finais no código corrigido.
5. **Harness C manual:** primeira tentativa não confirmou esquiva, não criou fatos/decisões e não chamou Jev. O personagem ficou morto com IA ativa. Corrigida a preparação para desabilitar os componentes após carregar os novos atores e aguardar o relógio de combate, em vez de uma espera fixa em tempo real. [Falha inicial](m04-real-C-dodge-initial-failure.json). A tentativa corrigida registrou saúde 100, uma ação verificada, escolha Jev e treino concluído sem habilidade.
6. **Aviso anterior no boneco estático:** `ActorHealth` tentava atribuir linearVelocity a Rigidbody2D Static ao morrer. Ajustado para zerar velocidade somente em corpos não estáticos. Sem mudança nas regras de vida/dano; suite anterior e nova aprovadas. O histórico da Console não foi limpo.

Não foram observadas falhas nas duas regressões completas posteriores ao isolamento; isso não prova ausência de intermitência em outros ambientes/focos.

## Persistência, arquivos e limites

Save Journey v3 + WorldState v1: agenda, oportunidades, região, conhecimento, decisões e auditoria são validados por replay. Envelope/checksum/backup anteriores preservados; saves v1/v2 aceitos e técnica/rotas mantidas. Save/load com consequência pendente, corrupção/backup, idempotência após restart, decisão obsoleta, expiração e região invalidada foram executados. Nenhuma credencial é armazenada.

O Git estava em `master` **sem commits**, com o projeto inteiro não rastreado. Nenhum stage/commit foi feito. `.env` permaneceu ignorado. Manifesto completo de arquivos: [Marco04Files](Marco04Files.md). Comparação por hash confirmou nenhum arquivo original removido e nenhuma alteração de pacotes/ProjectSettings/EditorSettings/sample assets. As opções de Play foram restauradas; Editor saiu do Play e apenas a instância temporária de validação foi encerrada.

Limitações: três definições de conteúdo, placeholders, autoridade offline/consultiva, uma instância Go, UTC local adulterável, replay linear e histórico máximo 8192 comandos sem compactação. Checkpoints podem perder até cinco segundos de tempo de jogo em crash. A configuração permite no máximo três oportunidades ativas, expiração em tempo de jogo e processamento de agenda limitado/determinístico. Não há simulação regional global, Nakama, multiplayer, XP ou níveis. Dados Unity continuam **não confiáveis para multiplayer público**; futura autoridade Go precisa validar movimento, colisão, interação, hits, saúde e estado independentemente. Falha entre cobrança e gravação Go ainda pode repetir chamada paga, embora efeitos de jogo permaneçam idempotentes.

Arquitetura, contratos, diagramas e reprodução A/B/C: [WorldEventOrchestrator](../WorldEventOrchestrator.md), [Architecture](../Architecture.md), [GoEventContract](../GoEventContract.md).
