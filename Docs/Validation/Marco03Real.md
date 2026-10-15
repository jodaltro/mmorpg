# Marco 03 — validação real OpenRouter/Jev

Executada em **13/10/2026**, após configuração do .env local pelo usuário. Editor Unity **6000.6.5f1**, CLI **1.0.0-beta.13**, serviço do usuário em **127.0.0.1:8091**, modelo efetivo **typesafe/jev-1.13-20260917**.

## Duas chamadas reais aprovadas

| Fluxo | ID da decisão | Opção | Confiança | Latência | Custo informado USD |
|---|---|---|---|---|---|
| TestManualOpenRouter, provedor direto | gen-dec-1791919676-PzVMBdch40yPaoQjeJXL | mira-scientific | 0.64 | 802 ms | 0.000026754 |
| Unity → Go → OpenRouter | gen-dec-1791919788-FksqRKat7bxcHwGQvF5Y | mira-scientific | 0.51 | 695 ms | 0.000027888 |

Custo informado das duas chamadas novas desta validação: **US$ 0.000054642**. Repetições usaram a decisão persistida; o custo presente na resposta repetida corresponde à chamada original, não a uma nova avaliação.

Probabilidades da decisão recebida pela Unity: científica **0.63**, preocupação **0.24**, neutra **0.09**, desconfiança **0.04**. Uso informado: 664 tokens de entrada e 66 de saída. O teste direto informou 637 de entrada e 66 de saída. Confiança e probabilidade da opção escolhida são métricas distintas.

Evidências com somente metadados da decisão, sem credencial ou headers:

- [Teste real do provedor](m03-real-openrouter-provider.txt).
- [Metadados recebidos pela Unity](m03-real-unity-metrics.json).
- [Metadados após recarga](m03-real-reloaded-metrics.json).
- [Resposta ao repetir o pedido no backend](m03-real-backend-repeat.json).

## Validação dentro do Editor

O fluxo usou a cena existente e persistência de teste isolada, sem substituir a jornada do jogador:

1. Rastros e conversa válida com Orin.
2. Três ataques reais da OfflineAuthority: lobo 60 → 40 → 20 → 0.
3. Coleta, conversa e entrega válidas a Mira.
4. Resposta real TypeSafe/Jev aplicada, com **fallback=false**.
5. Diálogo e Diário de Jornada comparados à reação persistida; capturas inspecionadas visualmente.
6. Save JSON em diretório temporário, replay validado, conversa repetida e recarga da cena usando o mesmo arquivo.
7. Mesmo ID, escolha e metadados após a recarga, sem nova decisão agendada.
8. Repetição do request original ao Go retornou a mesma decisão; o arquivo de decisão não foi regravado.

Rotas **A/B Completed**, confiança mantida e **apenas uma habilidade** registrada. Nenhuma regra de Leitura de Fraquezas foi modificada. O validador recusa considerar fallback como sucesso de chamada real.

Evidências:

- [Frames avançando](m03-real-frames.json).
- Ataques [1](m03-real-attack-1.json), [2](m03-real-attack-2.json), [3](m03-real-attack-3.json).
- [Entrega](m03-real-delivery.json) e [verificação de UI/memória](m03-real-unity-inspect.json).
- [Persistência e recarga](m03-real-persist-reload.json), [conversa repetida](m03-real-repeat-conversation.json) e [inspeção após recarga](m03-real-reloaded-inspect.json).
- [Captura do diário](m03-real-journal.png) e [captura do diálogo](m03-real-dialogue.png).
- Console [antes](m03-real-console-before.json), [depois](m03-real-console-after.json) e [histórico de erros](m03-real-console-errors.json).

Durante o fluxo real houve **zero erros novos na Console**, compilationFailed=false e consoleErrors=0. O histórico antigo não foi apagado. O Editor saiu do Play; as gerações originais do save foram restauradas e comparadas por hash. O servidor iniciado pelo usuário permaneceu em execução.

## Regressão e alterações desta validação

Go: **17 testes principais + 6 subcasos aprovados**, zero falhas; go vet aprovado. O teste pago foi desabilitado nessa suíte de regressão e executado separadamente, com aprovação acima. [Log Go](m03-real-go-regression.jsonl).

Unity: **54/54 aprovados** — [33/33 EditMode](m03-real-editmode.json) e [21/21 PlayMode](m03-real-playmode.json), zero falhas e ignorados. Os 32 testes anteriores permanecem aprovados. [Status da Console após regressão](m03-real-console-regression.json). As suítes rodaram sequencialmente pelo Editor conectado, com set_autotick e recompile_status verificados; a compilação estava atualizada, sem falhas.

Alterado apenas o validador **AgentScripts/ValidateJevPlay.cs**, acrescentando extração segura de métricas, verificação de save JSON/replay e recarga/conversa repetida. O arquivo foi compilado e executado pelo Pipeline. Acrescentados este relatório e os artefatos m03-real-*; atualizadas as referências de JevIntegration/Marco03. Código Domain/Runtime, cenas, pacotes e versão da Unity não foram alterados nesta validação; nenhum commit foi feito.

Esta execução comprova a integração e a persistência para o contexto testado. Não calibra o gate de confiança nem estabelece distribuição de reações para todos os contextos. O gate continua desabilitado por padrão e a interface continua restrita ao protótipo local.
