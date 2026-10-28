# 2026-10-28 — Hospedeiro · cinco conflitos simultâneos, atenção macro, tetos de custo e Jev ao vivo

- Baseline: `main` @ `e46d3516`. Go 1.27.2, Windows 10, Ryzen 7 1700X. Mundos em memória; nenhum mundo real tocado. Chamadas reais ao Jev (liberadas por AGENTS.md); a chave nunca é registrada.
- O fingerprint do universo muda de novo (4 conflitos, 4 NPCs, 4 coortes, 4 acontecimentos, 2 regras, ação nova).

## Entregue
**Conteúdo (universo `hospedeiro`)** — cada conflito tem gatilho material, severidade, coorte, NPC nomeado, ação de jogador confirmada e respostas para o Jev:
| Conflito | Causa / severidade | Coorte | NPC | Ação do jogador |
|---|---|---|---|---|
| infecção pulmonar (já existia) | foco no pulmão / carga | neutrófilos, macrófagos | Neva, Macra | conter-infeccao-pulmonar |
| ferida na pele (novo, tecido `pele`) | `pele.ferida`≥10; sangra +1/4 ticks; ≥50 deixa invasores entrarem no sangue | plaquetas | Placa | selar-ferida-pele |
| baço congestionado | hemácias velhas ≥80 | macrófagos esplênicos (devolvem ferro à medula) | Esplena | reciclar-hemacia |
| sobrecarga hepática | toxina ≥80 (carga tóxica periódica + intestino) | hepatócitos | Kupffer | filtrar-toxina |
| disbiose intestinal | microbiota ≤25 (severidade invertida: `of`=100) | flora intestinal (converte alimento em microbiota) | — | nutrir-microbiota |
Novos acontecimentos para o diretor: ferimento, intoxicação, desequilíbrio da microbiota, hemólise. Cada NPC novo tem uma segunda tarefa de ronda, de modo que Neva, Dendra, Macra, Placa, Esplena e Kupffer têm escolha real (Rubra continua sem).

**Motor**
- `ConflictMetric.Of` (severidade invertida), `TaskDef.Conflict`.
- **Atenção macro** (`deliberation.attentionEvery`): com ≥2 crises vivas o Jev escolhe em qual o corpo se concentra; a escolha vira o foco recomendado na visão e **inclina o padrão** das tarefas que servem aquela crise (+3 de prioridade). Decisão obsoleta/morta é recusada; no prazo vale a mais grave.
- **Tetos do runner**: `MaxQuestionsPerMinute` e `MaxCostPerHour` (custo reportado pelo provedor); acima do teto a pergunta não é enviada, é contada como `Skipped` e vale o padrão; atenção > conflito > NPC têm precedência no lote.
- `MaxBatch` 32 → 64. CLI: `-max-questions-per-minute`, `-max-cost-per-hour`, relatório de sociedade e conflitos ao fim do `simulate`, contadores por tipo com `created`.

## Testes locais executados (resultado real)
`gofmt -l`, `go vet ./...` limpos; `go test ./... -count=1` todos `ok`.
- `scenarios/conflicts_multi_test.go`: **3000 ticks sem jogador** — infecção 24 instâncias/24 resolvidas, pele 29/28, baço 2/1, fígado 10/10, disbiose 8/7; nunca duas instâncias vivas da mesma causa; **até 5 crises vivas ao mesmo tempo**. Cada crise escala a crítico quando sua coorte e seu NPC são removidos e não se resolve sozinha com a causa presente (4 casos). Cada órgão aceita o feito confirmado do jogador com crédito de 2–3 pontos, evidência repetida é duplicata e cliente é rejeitado (4 casos). QA-06: com duas crises, a pergunta de atenção abre só com crises vivas, os dois jogadores veem todas as crises e o mesmo foco, a escolha move o foco e não fecha nenhuma, resposta repetida é recusada, reserva finita nunca fica negativa e musters não superam o que foi pago. Ferida sem plaquetas sangra, leva tempo e contamina o sangue por regra. Atenção inclina o padrão de uma tarefa (mundo mínimo: sem atenção vence a prioridade 5, com atenção vence a tarefa que serve a crise). **Replay de 2500 ticks com 440 respostas aceitas reproduz o digest.**
- `sim/batch_test.go`: teto de 4 perguntas/min respeitado (relógio fixo), `Skipped` contado, o mundo segue nos padrões, e um minuto depois mais perguntas são aceitas; teto de custo (US$0,05/h a US$0,01 por resposta) fecha a torneira; perguntas de atenção chegam e são aplicadas.
- Testes antigos que supunham órgãos "nus" (fígado sem filtro, cadeia intestino→fígado→rim) agora rodam num universo-variante sem as coortes (`loadWithoutPops`, que compila e reproduz sozinho).
- Defeitos achados e corrigidos nesta rodada: a flora e o acontecimento de antibiótico faziam a disbiose reabrir sem nunca resolver (o gatilho disparava a 50, a resolução exige 60 → gatilho do acontecimento agora exige 65); a flora consumia o alimento que o teste do intestino→fígado esperava (taxa reduzida).

## Jev ao vivo (reais, faturados; amostras pequenas, sem gabarito)
**Mesmas 660 decisões reais, lote × individual (`JEV_LIVE=1 ... TestLiveJevBatchComparison`, 17 s)** — agora com tamanho 64:
| Variante | válidas | latência de parede | custo por pergunta |
|---|---|---|---|
| 1.13 individual ×16 | 16/16 | p50 349 ms | US$ 0,0000256 |
| 1.13 lote ×8 / ×16 / ×32 / **×64** | todas válidas | 366 / 366 / 398 / **728 ms** | 0,0000149 / 0,0000144 / 0,0000153 / **0,0000158** |
| 1.14 individual ×16 | 16/16 | p50 344 ms | 0,0000256 |
| 1.14 lote ×8 / ×16 / ×32 / **×64** | todas válidas | 339 / 398 / 414 / **481 ms** | idem |
Lote de 64 perguntas aceito pelos dois modelos (64/64 válidas). Concordância lote×individual nas 16 comparáveis: 1.13 → 6, 10, 12, 11; 1.14 → 6, 9, 9, 12 (ruído de amostra; nenhuma variante é claramente mais consistente). Igualdade com o padrão nos lotes de 64: 61/64 (1.13) e 62/64 (1.14) — o lote grande tende a repetir o padrão, mais um motivo para não tomar "concorda com o padrão" como qualidade.

**Mundo ao vivo, 300 ticks, pace 1 s, 2 jogadores, 4 processos em paralelo:**
| Variante | crises ocorridas | perguntas cognitivas (atenção/conflito/NPC) | diferentes do padrão | custo |
|---|---|---|---|---|
| determinístico | 7 instâncias, 5 tipos | 7 / 8 / 35 | 0 | 0 |
| 1.13 individual | 1 | 0 / 1 / 4 | 2 | US$ 0,0212 |
| 1.13 lote (janela 600 ms) | 1 | 0 / 1 / 4 | 1 | US$ 0,0213 |
| 1.14 lote (janela 600 ms) | 3 | 2 / 3 / 17 | 3 | US$ 0,0221 |
Nenhuma pergunta cognitiva falhou, foi recusada ou perdeu o prazo; houve um lote real com mais de uma pergunta (1.14). **Achado:** os mundos divergem porque o **diretor com Jev escolhe "nenhum" na maior parte das vezes** (21 de 25 escolhas no 1.13, 17 de 22 no 1.14, contra 0 no determinístico), então quase não surgem crises — por isso o Jev recebeu poucas perguntas de NPC/conflito. Não é uma regressão do corpo (as sociedades continuam trabalhando em todos os casos), mas significa que a medição do valor do Jev sobre crises ainda é fraca. O custo total (~US$ 0,021) continua dominado pelas decisões antigas de design/rota.

## O que continua não feito
- **A/B cego com revisores** e qualquer métrica de "qualidade da decisão" com gabarito: não foi feito; sem gabarito não há como afirmar que o Jev decide melhor que o padrão.
- Para medir o Jev sobre crises é preciso forçar o cenário (injetar causas) em vez de depender do diretor; o diretor do Jev subproduz crises e precisaria de instrução própria ou de `AllowNone` desligado em QA.
- Scheduler por urgência/novidade além de `every`, `maxOpen`, atenção e tetos; fila persistente; custo por dia.
- Godot, Nakama, HUD e animações (P10/P10V/P11); sistemas restantes de P12 (linfonodos, cérebro, tumores); migração das dungeons; operação 24/7; stress de 180 min e 500 NPCs.
